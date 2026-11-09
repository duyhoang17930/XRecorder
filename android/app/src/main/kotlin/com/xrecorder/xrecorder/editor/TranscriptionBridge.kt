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
    private class HistoryWriteException(cause: Exception) :
        java.io.IOException("Speech history could not be saved.", cause)

    private val historyUnavailableMessage =
        "Saved speech history could not be loaded. Existing data was kept. Restart the app or restore a backup before trying again."
    private val modelStore = SpeechModels(context)
    private val models
        get() = modelStore.available

    private class Job(val id: String, val type: String, val model: String) {
        var projectId: String? = null
        var sourceSignature: String? = null
        var language = "auto"
        @Volatile var resultLanguage: String? = null
        @Volatile var detectedLanguage: String? = null
        @Volatile var errorCode: String? = null
        var allowUncertainSpeech = false
        @Volatile var noSpeechDetected = false
        @Volatile var speechActivity: SpeechActivity? = null
        @Volatile var memoryPreflight: Map<String, Long>? = null
        var createdAt = System.currentTimeMillis()
        @Volatile var state = "queued"
        @Volatile var phase = "queued"
        @Volatile var progress = 0.0
        @Volatile var cancelled = false
        @Volatile var error: String? = null
        @Volatile var segments: List<Map<String, Any>> = emptyList()
        @Volatile var elapsedMs = 0L
        @Volatile var modelLoadMs = 0L
        @Volatile var inferenceMs = 0L
        var handle = 0L
        var transformer: Transformer? = null
        var temporary: File? = null

        fun snapshot() =
            synchronized(this) {
                mapOf(
                    "id" to id,
                    "type" to type,
                    "model" to model,
                    "language" to language,
                    "contractVersion" to 2,
                    "resultLanguage" to resultLanguage,
                    "detectedLanguage" to detectedLanguage,
                    "errorCode" to errorCode,
                    "allowUncertainSpeech" to allowUncertainSpeech,
                    "noSpeechDetected" to noSpeechDetected,
                    "speechActivity" to speechActivity?.snapshot(),
                    "memoryPreflight" to memoryPreflight,
                    "projectId" to projectId,
                    "sourceSignature" to sourceSignature,
                    "createdAt" to createdAt,
                    "state" to state,
                    "phase" to phase,
                    "progress" to progress,
                    "segments" to segments,
                    "error" to error,
                    "elapsedMs" to elapsedMs,
                    "modelLoadMs" to modelLoadMs,
                    "inferenceMs" to inferenceMs,
                )
            }
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val downloads = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val jobs = ConcurrentHashMap<String, Job>()
    private val deletingModels = ConcurrentHashMap.newKeySet<String>()
    private val journal = AtomicFile(File(context.filesDir, "transcription_jobs.json"))
    @Volatile private var journalRestored = false
    @Volatile private var historyReadError = false

    init {
        worker.execute {
            try {
                if (journal.baseFile.exists() || File(journal.baseFile.path + ".bak").exists()) {
                    val decoder =
                        Charsets.UTF_8.newDecoder()
                            .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                            .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
                    val array =
                        JSONArray(
                            java.io.InputStreamReader(journal.openRead(), decoder).buffered().use {
                                it.readText()
                            },
                        )
                    for (i in 0 until array.length()) {
                        val value = array.getJSONObject(i)
                        require(value.optInt("contractVersion", 1) in 1..2) {
                            "Unsupported speech history version"
                        }
                        val job =
                            Job(
                                value.getString("id"),
                                value.getString("type"),
                                value.getString("model"),
                            )
                        job.projectId =
                            value.optString("projectId").takeIf { it.isNotEmpty() && it != "null" }
                        job.sourceSignature =
                            value.optString("sourceSignature").takeIf {
                                it.isNotEmpty() && it != "null"
                            }
                        job.createdAt = value.optLong("createdAt", 0)
                        job.language = value.optString("language", "auto")
                        job.allowUncertainSpeech = value.optBoolean("allowUncertainSpeech", false)
                        job.noSpeechDetected = value.optBoolean("noSpeechDetected", false)
                        value.optJSONObject("memoryPreflight")?.let { memory ->
                            job.memoryPreflight =
                                memory.keys().asSequence().associateWith { memory.getLong(it) }
                        }
                        value.optJSONObject("speechActivity")?.let { activity ->
                            runCatching {
                                job.speechActivity =
                                    SpeechActivity(
                                        activity.getDouble("mean"),
                                        activity.getDouble("max"),
                                        activity.getDouble("voicedRatio"),
                                        activity.getInt("longestVoicedMs"),
                                        activity.getInt("observedFrames"),
                                    )
                            }
                        }
                        job.resultLanguage =
                            value.optString("resultLanguage").takeIf {
                                it.isNotBlank() && it != "null"
                            }
                        job.detectedLanguage =
                            value.optString("detectedLanguage").takeIf {
                                it.isNotBlank() && it != "null"
                            }
                        val oldState = value.getString("state")
                        job.state =
                            if (oldState in listOf("queued", "running")) "failed" else oldState
                        job.phase = "restored"
                        job.progress = value.optDouble("progress", 0.0)
                        job.error =
                            if (job.state != oldState)
                                "Interrupted when the application stopped. Start again; your draft and media are unchanged."
                            else value.optString("error").takeIf { it != "null" && it.isNotEmpty() }
                        job.errorCode =
                            if (job.state != oldState) "interrupted"
                            else
                                value.optString("errorCode").takeIf {
                                    it.isNotBlank() && it != "null"
                                }
                        job.elapsedMs = value.optLong("elapsedMs", 0)
                        job.modelLoadMs = value.optLong("modelLoadMs", 0)
                        job.inferenceMs = value.optLong("inferenceMs", 0)
                        job.segments =
                            segments(value.optJSONArray("segments") ?: JSONArray(), 600000)
                        check(jobs.putIfAbsent(job.id, job) == null) {
                            "Duplicate speech history identity"
                        }
                    }
                }
            } catch (error: Exception) {
                // Keep unreadable/future history byte-for-byte. Never turn an
                // empty recovery result into permission to overwrite the file.
                historyReadError = true
                android.util.Log.w(
                    "TranscriptionBridge",
                    "Speech history kept read-only (${error.javaClass.simpleName})",
                )
            } finally {
                journalRestored = true
            }
        }
    }

    private fun model(id: String) = modelStore.find(id)

    private fun target(model: SpeechModel) = modelStore.file(model)

    private fun ready(model: SpeechModel) = modelStore.ready(model)

    private fun persist(completing: Job? = null, completedPhase: String = "completed") {
        synchronized(journal) {
            check(!historyReadError) { historyUnavailableMessage }
            // Snapshot inside the write lock: download and recognition workers
            // must not commit an older snapshot after a newer one. Results are
            // user data, so generating job21 must not erase the first job.
            val bytes =
                JSONArray(
                        jobs.values
                            .sortedBy { it.createdAt }
                            .map {
                                val record = it.snapshot()
                                if (it === completing)
                                    record +
                                        mapOf(
                                            "state" to "completed",
                                            "phase" to completedPhase,
                                            "progress" to 1.0,
                                        )
                                else record
                            },
                    )
                    .toString()
                    .toByteArray(Charsets.UTF_8)
            var out: java.io.FileOutputStream? = null
            var committed = false
            try {
                out = journal.startWrite()
                out.write(bytes)
                journal.finishWrite(out)
                committed = true
                check(journal.openRead().use { it.readBytes() }.contentEquals(bytes)) {
                    "Speech history read-back did not match."
                }
            } catch (e: Exception) {
                // finishWrite can return before a failed rename becomes visible.
                // Never roll back a possibly committed file after read-back.
                if (!committed && out != null) journal.failWrite(out)
                throw HistoryWriteException(e)
            }
        }
    }

    private fun replyJobs(arguments: Any?, result: MethodChannel.Result) {
        if (historyReadError) result.error("history_unavailable", historyUnavailableMessage, null)
        else if (arguments == null) result.success(jobs.values.map { it.snapshot() })
        else {
            // Keep the unfiltered legacy contract. New callers transfer at most
            // one page, selecting metadata before serializing subtitle segments.
            require(arguments is Map<*, *>) { "Invalid speech history query" }
            val requestedLimit = arguments["limit"] ?: 50
            require(requestedLimit is Number && requestedLimit.toDouble() in 1.0..100.0 &&
                requestedLimit.toDouble() == requestedLimit.toInt().toDouble()) {
                "Speech history page size must be 1 to 100"
            }
            val limit = requestedLimit.toInt()
            require(arguments["projectId"] == null || arguments["projectId"] is String)
            require(arguments["sourceSignature"] == null || arguments["sourceSignature"] is String)
            require(arguments["beforeCreatedAt"] == null || arguments["beforeCreatedAt"] is Number)
            require(arguments["beforeId"] == null || arguments["beforeId"] is String)
            val projectId = arguments["projectId"] as? String
            val signature = arguments["sourceSignature"] as? String
            val beforeTime = (arguments["beforeCreatedAt"] as? Number)?.toLong()
            val beforeId = arguments["beforeId"] as? String
            require((beforeTime == null) == (beforeId == null)) { "Incomplete speech history cursor" }
            require(beforeId == null || beforeId.isNotEmpty()) { "Invalid speech history cursor" }
            val page = jobs.values.asSequence()
                .filter { projectId == null || it.projectId == projectId }
                .filter { signature == null || it.sourceSignature == null || it.sourceSignature == signature }
                .filter {
                    beforeTime == null || it.createdAt < beforeTime ||
                        it.createdAt == beforeTime && it.id < beforeId!!
                }
                .sortedWith(compareByDescending<Job> { it.createdAt }.thenByDescending { it.id })
                .take(limit)
                .map { it.snapshot() }
                .toList()
            result.success(page)
        }
    }

    private fun persistOrWarn(job: Job) {
        try {
            persist()
        } catch (_: Exception) {
            job.errorCode = "history_write_failed"
        }
    }

    private fun completeAndPersist(job: Job, phase: String) {
        val finishing =
            synchronized(job) {
                if (job.cancelled) false
                else {
                    job.phase = "saving job history"
                    job.progress = maxOf(job.progress, .99)
                    if (job.errorCode == "history_write_failed") job.errorCode = null
                    true
                }
            }
        if (!finishing) {
            persistOrWarn(job)
            return
        }
        try {
            persist(job, phase)
        } catch (_: Exception) {
            job.errorCode = "history_write_failed"
        }
        // Completed becomes observable only after read-back succeeds or a
        // visible persistence warning has been attached to the real result.
        synchronized(job) {
            job.progress = 1.0
            job.phase = phase
            job.state = "completed"
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (
                call.method in
                    setOf(
                        "transcriptionStart",
                        "transcriptionDownloadModel",
                        "transcriptionImportModel",
                        "transcriptionDeleteModel",
                    )
            ) {
                if (!journalRestored) {
                    // The model can already be installed on the first call
                    // while its history is still restoring. Queue behind that
                    // read without blocking main or asking callers to race it.
                    worker.execute { main.post { handle(call, result) } }
                    return
                }
                if (historyReadError) {
                    result.error("history_unavailable", historyUnavailableMessage, null)
                    return
                }
            }
            when (call.method) {
                "transcriptionSpeechActivity" -> {
                    val input = call.arguments as Map<*, *>
                    val duration = (input["durationMs"] as Number).toLong()
                    val uri = Uri.parse(input["uri"] as String)
                    require(duration in 100..30000 && uri.scheme == "content")
                    worker.execute {
                        var handle = 0L
                        try {
                            val pcm =
                                SpeechAudioDecoder.decode(context, uri, duration, { false }) {}
                            handle = WhisperNative.create()
                            val values = WhisperNative.activity(handle, pcm)
                            val data = SpeechActivity.from(values).snapshot()
                            main.post { result.success(data) }
                        } catch (error: Exception) {
                            main.post { result.error("speech_activity", error.message, null) }
                        } finally {
                            if (handle != 0L) WhisperNative.destroy(handle)
                        }
                    }
                }
                "transcriptionLanguages" -> result.success(SpeechLanguages.catalog)
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
                                "supportedLanguageCount" to 99,
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
                        if (job.handle != 0L && job.state == "running") {
                            nativeTimings(job)
                            job.progress =
                                maxOf(
                                    job.progress,
                                    .25 + .74 * WhisperNative.progress(job.handle) / 100.0,
                                )
                        }
                    }
                    result.success(job.snapshot())
                }
                "transcriptionJobs" -> {
                    if (journalRestored) {
                        replyJobs(call.arguments, result)
                    } else
                        worker.execute {
                            main.post { handle(call, result) }
                        }
                }
                "transcriptionSaveHistory" -> {
                    if (historyReadError) {
                        result.error("history_unavailable", historyUnavailableMessage, null)
                        return
                    }
                    val job = jobs[call.arguments as String] ?: error("Speech job not found")
                    require(job.state !in listOf("queued", "running")) {
                        "Wait for the operation to finish."
                    }
                    worker.execute {
                        val previous = job.errorCode
                        if (previous == "history_write_failed") job.errorCode = null
                        try {
                            persist()
                            main.post { result.success(null) }
                        } catch (error: Exception) {
                            job.errorCode = previous ?: "history_write_failed"
                            main.post { result.error("history_write_failed", error.message, null) }
                        }
                    }
                }
                "transcriptionCancel" -> {
                    val job = jobs[call.arguments as String] ?: error("Speech job not found")
                    val cancellable =
                        synchronized(job) {
                            if (
                                job.state in listOf("queued", "running") &&
                                    job.phase != "saving job history"
                            ) {
                                job.cancelled = true
                                if (job.handle != 0L) WhisperNative.cancel(job.handle)
                                job.state = "cancelled"
                                job.phase = "cancelled"
                                true
                            } else false
                        }
                    if (cancellable) {
                        job.transformer?.cancel()
                        job.transformer = null
                        worker.execute {
                            job.temporary?.delete()
                            persistOrWarn(job)
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
                    require(SpeechLanguages.supports(language)) {
                        "The selected language is not supported by this speech model."
                    }
                    val duration = (value["durationMs"] as Number).toLong()
                    require(duration in 100..600000)
                    // Validate before reserving the single speech slot. A rejected
                    // URI must not leave a queued job blocking future requests.
                    val uri = Uri.parse(value["audioUri"] as String)
                    require(uri.scheme == "content") { "Choose audio from the media picker." }
                    val job = Job(id, "speech", selected.id)
                    job.language = language
                    job.allowUncertainSpeech = value["allowUncertainSpeech"] as? Boolean ?: false
                    val project = value["project"] as? Map<*, *>
                    job.projectId = project?.get("id") as? String
                    job.sourceSignature = value["sourceSignature"] as? String
                    jobs[id] = job
                    if (project != null) render(job, project, duration, language)
                    else {
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
        var installed = false
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
            installed = true
        } catch (e: Exception) {
            job.state = if (job.cancelled) "cancelled" else "failed"
            job.error = e.message
            job.errorCode = if (job.cancelled) "cancelled" else "model_install_failed"
        } finally {
            if (installed && !job.cancelled) completeAndPersist(job, "ready")
            else persistOrWarn(job)
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
                                job.errorCode =
                                    if (job.cancelled) "cancelled" else "audio_prepare_failed"
                                worker.execute {
                                    temporary.delete()
                                    persistOrWarn(job)
                                }
                            }
                        },
                    )
                    .build()
            worker.execute { persistOrWarn(job) }
            job.transformer!!.start(composition, temporary.path)
        } catch (e: Exception) {
            temporary.delete()
            job.state = "failed"
            job.error = e.message
            job.errorCode = "audio_prepare_failed"
            worker.execute { persistOrWarn(job) }
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
        var completed = false
        try {
            check(!job.cancelled)
            job.state = "running"
            job.phase = "decoding audio"
            val memory = android.app.ActivityManager.MemoryInfo()
            context.getSystemService(android.app.ActivityManager::class.java).getMemoryInfo(memory)
            val required = speechMemoryRequiredBytes(selected.id, duration, memory.threshold)
            job.memoryPreflight =
                mapOf(
                    "availableBytes" to memory.availMem,
                    "requiredBytes" to required,
                    "systemThresholdBytes" to memory.threshold,
                    "totalBytes" to memory.totalMem,
                    "pageBytes" to
                        android.system.Os.sysconf(android.system.OsConstants._SC_PAGESIZE),
                )
            persist()
            require(!memory.lowMemory && memory.availMem >= required) {
                "Not enough memory for this speech model. Choose tiny or a shorter video."
            }
            val pcm =
                SpeechAudioDecoder.decode(context, uri, duration, { job.cancelled }) {
                    job.progress = .05 + .2 * it
                }
            if (pcm.none { kotlin.math.abs(it) > 0.00001f }) {
                job.segments = emptyList()
                job.noSpeechDetected = true
                completed = true
                return
            }
            check(!job.cancelled)
            synchronized(job) { job.handle = WhisperNative.create() }
            if (pcm.size >= 16000) {
                job.phase = "checking speech activity"
                val activity = SpeechActivity.from(WhisperNative.activity(job.handle, pcm))
                job.speechActivity = activity
                job.noSpeechDetected = activity.noClearSpeech
                if (activity.noClearSpeech && !job.allowUncertainSpeech) {
                    job.segments = emptyList()
                    completed = true
                    return
                }
            }
            check(!job.cancelled)
            job.phase = "loading model on device"
            val raw =
                WhisperNative.run(
                    job.handle,
                    target(selected).path,
                    pcm,
                    language,
                    Runtime.getRuntime().availableProcessors().coerceAtMost(4),
                )
            check(!job.cancelled)
            job.resultLanguage = SpeechLanguages.code(WhisperNative.languageId(job.handle))
            job.detectedLanguage = if (language == "auto") job.resultLanguage else null
            job.segments = segments(JSONArray(raw.toString(Charsets.UTF_8)), duration)
            completed = true
        } catch (e: Exception) {
            job.state = if (job.cancelled) "cancelled" else "failed"
            job.error = e.message
            job.errorCode =
                when {
                    job.cancelled -> "cancelled"
                    e is HistoryWriteException -> "history_write_failed"
                    e is SecurityException -> "permission_denied"
                    e.message?.contains("Not enough memory", ignoreCase = true) == true ->
                        "low_memory"
                    else -> "speech_failed"
                }
        } catch (e: OutOfMemoryError) {
            job.state = "failed"
            job.error = "Not enough memory for this model. Try tiny or a shorter video."
            job.errorCode = "low_memory"
        } finally {
            synchronized(job) {
                if (job.handle != 0L) {
                    nativeTimings(job)
                    WhisperNative.destroy(job.handle)
                    job.handle = 0
                }
            }
            job.elapsedMs = System.currentTimeMillis() - began
            temporary?.delete()
            if (completed && !job.cancelled) {
                completeAndPersist(job, "completed")
            } else persistOrWarn(job)
        }
    }

    /** Called under the job lock, before releasing the native handle. */
    private fun nativeTimings(job: Job) {
        val values = WhisperNative.timings(job.handle)
        job.modelLoadMs = values[1]
        job.inferenceMs = values[2]
        if (job.state == "running" && values[0] >= 2) job.phase = "recognizing on device"
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
            val pieces = SubtitleText.chunks(text)
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
