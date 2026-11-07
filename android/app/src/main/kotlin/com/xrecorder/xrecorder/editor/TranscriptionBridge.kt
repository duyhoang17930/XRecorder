package com.xrecorder.xrecorder.editor

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import org.json.JSONArray

/** Offline-only speech jobs and checksum-verified multilingual model storage. */
class TranscriptionBridge(private val context: Context) {
    private val modelStore = SpeechModels(context)
    private val models
        get() = modelStore.available

    private class Job(val id: String, val type: String, val model: String) {
        var projectId: String? = null
        var createdAt = System.currentTimeMillis()
        @Volatile var state = "queued"
        @Volatile var phase = "queued"
        @Volatile var progress = 0.0
        @Volatile var cancelled = false
        @Volatile var error: String? = null
        @Volatile var segments: List<Map<String, Any>> = emptyList()
        @Volatile var elapsedMs = 0L
        var handle = 0L
        var transformer: Transformer? = null
        var temporary: File? = null

        fun snapshot() =
            mapOf(
                "id" to id,
                "type" to type,
                "model" to model,
                "projectId" to projectId,
                "createdAt" to createdAt,
                "state" to state,
                "phase" to phase,
                "progress" to progress,
                "segments" to segments,
                "error" to error,
                "elapsedMs" to elapsedMs,
            )
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val downloads = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val jobs = ConcurrentHashMap<String, Job>()
    private val deletingModels = ConcurrentHashMap.newKeySet<String>()
    private val journal = AtomicFile(File(context.filesDir, "transcription_jobs.json"))

    init {
        worker.execute {
            try {
                if (journal.baseFile.exists() || File(journal.baseFile.path + ".bak").exists()) {
                    val array = JSONArray(journal.openRead().bufferedReader().use { it.readText() })
                    for (i in 0 until array.length()) {
                        val value = array.getJSONObject(i)
                        val job =
                            Job(
                                value.getString("id"),
                                value.getString("type"),
                                value.getString("model"),
                            )
                        job.projectId =
                            value.optString("projectId").takeIf { it.isNotEmpty() && it != "null" }
                        job.createdAt = value.optLong("createdAt", 0)
                        val oldState = value.getString("state")
                        job.state =
                            if (oldState in listOf("queued", "running")) "failed" else oldState
                        job.phase = "restored"
                        job.progress = value.optDouble("progress", 0.0)
                        job.error =
                            if (job.state != oldState)
                                "Interrupted when the application stopped. Start again; your draft and media are unchanged."
                            else value.optString("error").takeIf { it != "null" && it.isNotEmpty() }
                        job.elapsedMs = value.optLong("elapsedMs", 0)
                        job.segments =
                            segments(value.optJSONArray("segments") ?: JSONArray(), 600000)
                        jobs.putIfAbsent(job.id, job)
                    }
                }
            } catch (_: Exception) {
                /* An unreadable ASR journal never invalidates editor drafts. */
            }
        }
    }

    private fun model(id: String) = modelStore.find(id)

    private fun target(model: SpeechModel) = modelStore.file(model)

    private fun ready(model: SpeechModel) = modelStore.ready(model)

    private fun persist() {
        val bytes =
            JSONArray(jobs.values.sortedBy { it.createdAt }.takeLast(20).map { it.snapshot() })
                .toString()
                .toByteArray()
        synchronized(journal) {
            val out = journal.startWrite()
            try {
                out.write(bytes)
                journal.finishWrite(out)
            } catch (e: Exception) {
                journal.failWrite(out)
                throw e
            }
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "transcriptionDeleteModel" -> {
                    val selected = model(call.arguments as String)
                    require(
                        jobs.values.none {
                            it.model == selected.id && it.state in listOf("queued", "running")
                        },
                    ) {
                        "This model is in use. Wait or cancel the operation first."
                    }
                    require(deletingModels.add(selected.id)) { "Model removal is already running" }
                    downloads.execute {
                        try {
                            modelStore.remove(selected)
                            main.post { result.success(null) }
                        } catch (e: Exception) {
                            main.post { result.error("model_io", e.message, null) }
                        } finally {
                            deletingModels.remove(selected.id)
                        }
                    }
                }
                "transcriptionAvailability" ->
                    result.success(if (models.any { ready(it) }) "onDevice" else "notConfigured")
                "transcriptionModels" ->
                    result.success(
                        models.map {
                            mapOf(
                                "id" to it.id,
                                "bytes" to it.bytes,
                                "installed" to ready(it),
                                "multilingual" to true,
                            )
                        },
                    )
                "transcriptionPoll" -> {
                    val job = jobs[call.arguments as String] ?: error("Speech job not found")
                    job.transformer?.let { renderer ->
                        val holder = ProgressHolder()
                        if (renderer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE)
                            job.progress = maxOf(job.progress, .05 * holder.progress / 100.0)
                    }
                    synchronized(job) {
                        if (job.handle != 0L && job.state == "running")
                            job.progress =
                                maxOf(
                                    job.progress,
                                    .25 + .74 * WhisperNative.progress(job.handle) / 100.0,
                                )
                    }
                    result.success(job.snapshot())
                }
                "transcriptionJobs" ->
                    worker.execute {
                        val values = jobs.values.map { it.snapshot() }
                        main.post { result.success(values) }
                    }
                "transcriptionCancel" -> {
                    val job = jobs[call.arguments as String] ?: error("Speech job not found")
                    if (job.state in listOf("queued", "running")) {
                        job.cancelled = true
                        synchronized(job) { if (job.handle != 0L) WhisperNative.cancel(job.handle) }
                        job.transformer?.cancel()
                        job.transformer = null
                        job.state = "cancelled"
                        job.phase = "cancelled"
                        worker.execute {
                            job.temporary?.delete()
                            persist()
                        }
                    }
                    result.success(null)
                }
                "transcriptionDownloadModel",
                "transcriptionImportModel" -> {
                    val value = call.arguments as Map<*, *>
                    val selected = model(value["model"] as String)
                    require(
                        jobs.values.none {
                            it.type == "model" && it.state in listOf("queued", "running")
                        },
                    ) {
                        "A model operation is already running"
                    }
                    val job = Job("model_${System.currentTimeMillis()}", "model", selected.id)
                    jobs[job.id] = job
                    downloads.execute {
                        install(
                            job,
                            selected,
                            if (call.method == "transcriptionImportModel") value["uri"] as String
                            else null,
                        )
                    }
                    result.success(job.id)
                }
                "transcriptionStart" -> {
                    val value = call.arguments as Map<*, *>
                    val selected = model(value["model"] as? String ?: "tiny")
                    require(selected.id !in deletingModels) { "Wait for model removal to finish" }
                    require(ready(selected)) { "Download or import the multilingual model first." }
                    require(
                        jobs.values.none {
                            it.type == "speech" && it.state in listOf("queued", "running")
                        },
                    ) {
                        "Speech recognition is already running"
                    }
                    val id = value["operationId"] as String
                    require(id.matches(Regex("[A-Za-z0-9_-]{1,80}")) && !jobs.containsKey(id))
                    val language = value["language"] as? String ?: "auto"
                    require(language in listOf("vi", "en", "auto"))
                    val duration = (value["durationMs"] as Number).toLong()
                    require(duration in 100..600000)
                    val job = Job(id, "speech", selected.id)
                    jobs[id] = job
                    val project = value["project"] as? Map<*, *>
                    job.projectId = project?.get("id") as? String
                    if (project != null) render(job, project, duration, language)
                    else {
                        val uri = Uri.parse(value["audioUri"] as String)
                        require(uri.scheme == "content")
                        worker.execute { recognize(job, selected, uri, duration, language, null) }
                    }
                    result.success(id)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("transcription", e.message, null)
        }
    }

    private fun install(job: Job, selected: SpeechModel, source: String?) {
        try {
            job.state = "running"
            job.phase = "downloading"
            persist()
            modelStore.install(
                job.id,
                selected,
                source,
                { job.cancelled },
                { job.progress = it },
                { job.phase = "verifying" },
            )
            job.progress = 1.0
            job.state = "completed"
            job.phase = "ready"
        } catch (e: Exception) {
            job.state = if (job.cancelled) "cancelled" else "failed"
            job.error = e.message
        } finally {
            try {
                persist()
            } catch (_: Exception) {}
        }
    }

    private fun render(job: Job, project: Map<*, *>, duration: Long, language: String) {
        val temporary = File(context.cacheDir, "${job.id}_speech.mp4")
        job.temporary = temporary
        try {
            job.state = "running"
            job.phase = "preparing edited audio"
            val composition = EditorComposition.audioOnly(project)
            job.transformer =
                Transformer.Builder(context)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(
                        object : Transformer.Listener {
                            override fun onCompleted(
                                composition: Composition,
                                exportResult: ExportResult,
                            ) {
                                job.transformer = null
                                worker.execute {
                                    recognize(
                                        job,
                                        model(job.model),
                                        Uri.fromFile(temporary),
                                        duration,
                                        language,
                                        temporary,
                                    )
                                }
                            }

                            override fun onError(
                                composition: Composition,
                                exportResult: ExportResult,
                                exception: ExportException,
                            ) {
                                job.transformer = null
                                job.state = if (job.cancelled) "cancelled" else "failed"
                                job.error = exception.message
                                worker.execute {
                                    temporary.delete()
                                    persist()
                                }
                            }
                        },
                    )
                    .build()
            worker.execute { persist() }
            job.transformer!!.start(composition, temporary.path)
        } catch (e: Exception) {
            temporary.delete()
            job.state = "failed"
            job.error = e.message
            worker.execute { persist() }
        }
    }

    private fun recognize(
        job: Job,
        selected: SpeechModel,
        uri: Uri,
        duration: Long,
        language: String,
        temporary: File?,
    ) {
        val began = System.currentTimeMillis()
        try {
            check(!job.cancelled)
            job.state = "running"
            job.phase = "decoding audio"
            persist()
            val memory = android.app.ActivityManager.MemoryInfo()
            context.getSystemService(android.app.ActivityManager::class.java).getMemoryInfo(memory)
            val reserveMiB =
                when (selected.id) {
                    "tiny" -> 192L
                    "base" -> 320L
                    else -> 640L
                }
            val required = reserveMiB * 1024 * 1024 + duration * 16 * 4 * 3
            require(!memory.lowMemory && memory.availMem >= required) {
                "Not enough memory for this speech model. Choose tiny or a shorter video."
            }
            val pcm =
                SpeechAudioDecoder.decode(context, uri, duration, { job.cancelled }) {
                    job.progress = .05 + .2 * it
                }
            if(pcm.none{kotlin.math.abs(it)>0.00001f}){
                job.segments=emptyList();job.progress=1.0;job.state="completed";job.phase="completed"
                return
            }
            check(!job.cancelled)
            job.phase = "recognizing on device"
            synchronized(job) { job.handle = WhisperNative.create() }
            val raw =
                WhisperNative.run(
                    job.handle,
                    target(selected).path,
                    pcm,
                    language,
                    Runtime.getRuntime().availableProcessors().coerceAtMost(4),
                )
            check(!job.cancelled)
            job.segments = segments(JSONArray(raw.toString(Charsets.UTF_8)), duration)
            job.progress = 1.0
            job.state = "completed"
            job.phase = "completed"
        } catch (e: Exception) {
            job.state = if (job.cancelled) "cancelled" else "failed"
            job.error = e.message
        } catch (e: OutOfMemoryError) {
            job.state = "failed"
            job.error = "Not enough memory for this model. Try tiny or a shorter video."
        } finally {
            synchronized(job) {
                if (job.handle != 0L) {
                    WhisperNative.destroy(job.handle)
                    job.handle = 0
                }
            }
            job.elapsedMs = System.currentTimeMillis() - began
            temporary?.delete()
            try {
                persist()
            } catch (_: Exception) {}
        }
    }

    private fun segments(array: JSONArray, duration: Long): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        var previous = 0L
        for (i in 0 until array.length()) {
            val value = array.getJSONObject(i)
            val start = maxOf(previous, value.getLong("startMs")).coerceAtMost(duration)
            val end = value.getLong("endMs").coerceIn(start, duration)
            val text = value.getString("text").trim()
            if (end <= start || text.isEmpty()) continue
            // whisper max_len bounds normal segments. Defensively split unusually
            // long text into timed portions rather than discarding recognized words.
            val pieces = text.chunked(240)
            pieces.forEachIndexed { p, content ->
                val a = start + (end - start) * p / pieces.size
                val b = start + (end - start) * (p + 1) / pieces.size
                if (b > a) result.add(mapOf("startMs" to a, "endMs" to b, "text" to content))
            }
            previous = end
        }
        require(result.size <= 200) { "More than 200 subtitle segments. Use a shorter video." }
        return result
    }

    fun dispose() {
        jobs.values
            .filter { it.state in listOf("queued", "running") }
            .forEach { job ->
                job.cancelled = true
                job.transformer?.cancel()
                synchronized(job) { if (job.handle != 0L) WhisperNative.cancel(job.handle) }
            }
        worker.shutdown()
        downloads.shutdown()
    }
}
