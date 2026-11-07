package com.xrecorder.xrecorder.editor

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.AtomicFile
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.*
import com.xrecorder.xrecorder.recording.MediaOutput
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/** Durable snapshots; interrupted jobs require explicit retry, never report success. */
class ExportQueue(private val context: Context) {
    companion object {
        private var instance: ExportQueue? = null

        fun get(context: Context): ExportQueue =
            instance ?: ExportQueue(context.applicationContext).also { instance = it }
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val journal = AtomicFile(File(context.filesDir, "export_jobs.json"))
    private val jobs = mutableListOf<JSONObject>()
    private var transformer: Transformer? = null
    private var active: JSONObject? = null
    private var closed = false
    private var recoveryWarning: String? = null

    init {
        if (journal.baseFile.exists() || File(journal.baseFile.path + ".bak").exists()) {
            var damaged = false
            try {
                val text =
                    journal.openRead().use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= 8 * 1024 * 1024)
                            output.write(buffer, 0, count)
                        }
                        output.toString(Charsets.UTF_8.name())
                    }
                val array = JSONArray(text)
                for (i in 0 until array.length()) try {
                    val row = array.getJSONObject(i)
                    require(row.getString("id").matches(Regex("[A-Za-z0-9_-]{1,80}")))
                    require(
                        row.getString("state") in
                            listOf(
                                "queued",
                                "running",
                                "finalizing",
                                "completed",
                                "failed",
                                "cancelled",
                            ),
                    )
                    require(row.getJSONObject("project").has("clips"))
                    jobs.add(row)
                } catch (_: Exception) {
                    damaged = true
                }
            } catch (_: Exception) {
                damaged = true
            }
            if (damaged) {
                // Copy first. If storage is exhausted, fail without replacing the
                // only history file. Editor drafts and published media are separate.
                journal.baseFile.copyTo(
                    File(
                        context.filesDir,
                        "export_jobs_recovery_${System.currentTimeMillis()}.json",
                    ),
                    false,
                )
                recoveryWarning =
                    "Some export history needs recovery. A copy has been kept. Your drafts and saved files are unchanged."
            }
        }
        jobs
            .filter { it.getString("state") in listOf("running", "queued", "finalizing") }
            .forEach {
                val pending = it.optString("pending")
                if (pending.startsWith("content://media/")) {
                    val uri = Uri.parse(pending)
                    context.contentResolver
                        .query(
                            uri,
                            arrayOf(
                                MediaStore.MediaColumns.IS_PENDING,
                                MediaStore.MediaColumns.OWNER_PACKAGE_NAME,
                            ),
                            null,
                            null,
                            null,
                        )
                        ?.use { cursor ->
                            if (
                                cursor.moveToFirst() && cursor.getString(1) == context.packageName
                            ) {
                                if (cursor.getInt(0) == 1)
                                    context.contentResolver.delete(uri, null, null)
                                else {
                                    it.put("state", "completed")
                                    it.put("uri", pending)
                                }
                            }
                        }
                }
                if (it.getString("state") != "completed") {
                    it.put("state", "failed")
                    it.put("error", "Export interrupted. Keep the app open and retry.")
                }
                temporary(it).delete()
            }
        persist()
    }

    fun diagnostics() = mapOf("warning" to recoveryWarning)

    private fun temporary(job: JSONObject): File {
        val id = job.getString("id")
        require(id.matches(Regex("[a-zA-Z0-9_-]{1,80}"))) { "Invalid export job identity." }
        return File(context.cacheDir, "export_$id.mp4")
    }

    @Synchronized
    private fun persist() {
        val stream = journal.startWrite()
        try {
            stream.write(JSONArray(jobs).toString().toByteArray())
            journal.finishWrite(stream)
        } catch (e: Exception) {
            journal.failWrite(stream)
            throw e
        }
    }

    /** Async encoder callbacks must not crash the main thread when disk writes fail. */
    private fun checkpoint(job: JSONObject): Boolean {
        return try {
            persist()
            job.remove("historyWriteFailed")
            true
        } catch (_: Exception) {
            job.put("historyWriteFailed", true)
            if (job.optString("state") == "completed") {
                job.put(
                    "warning",
                    "File saved. Export history could not be updated. Free storage before exporting again.",
                )
            } else {
                job.put("state", "failed")
                    .put("error", "Export could not be saved. Free storage and retry.")
            }
            false
        }
    }

    fun list(): String {
        val holder = ProgressHolder()
        if (transformer?.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE)
            active?.put("progress", holder.progress)
        val rows = JSONArray(jobs)
        recoveryWarning?.let { rows.put(JSONObject().put("type", "notice").put("message", it)) }
        return rows.toString()
    }

    fun enqueue(project: Map<*, *>): String {
        EditorComposition.build(project)
        val options = project["effects"] as? Map<*, *> ?: emptyMap<Any, Any>()
        EditorStorage.requireSpace(
            android.os.StatFs(context.cacheDir.path).availableBytes,
            EditorStorage.requiredBytes(
                EditorComposition.durationUs(project),
                (options["bitrate"] as? Number)?.toInt() ?: 0,
                options["format"] == "gif",
                (options["gifEdge"] as? Number)?.toInt() ?: 320,
                (options["gifFps"] as? Number)?.toInt() ?: 10,
            ),
        )
        if ((project["effects"] as? Map<*, *>)?.get("format") == "gif")
            require(EditorComposition.durationUs(project) <= 15000000) {
                "GIF export is limited to 15 seconds"
            }
        require(
            jobs.count { it.getString("state") in listOf("queued", "running", "finalizing") } < 10,
        ) {
            "The export queue is full"
        }
        val job =
            JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("project", JSONObject(project))
                .put("state", "queued")
                .put("progress", 0)
        jobs.add(job)
        try {
            persist()
        } catch (e: Exception) {
            jobs.remove(job)
            throw e
        }
        main.post { next() }
        return job.getString("id")
    }

    fun cancel(id: String) {
        val job = jobs.first { it.getString("id") == id }
        require(job.getString("state") != "finalizing") { "The finished file is being saved" }
        if (job.getString("state") !in listOf("queued", "running")) return
        if (active === job) {
            transformer?.cancel()
            transformer = null
            active = null
        }
        temporary(job).delete()
        job.put("state", "cancelled")
        persist()
        next()
    }

    fun retry(id: String) {
        val job = jobs.first { it.getString("id") == id }
        require(job.getString("state") in listOf("failed", "cancelled"))
        val previousState = job.getString("state")
        val previousProgress = job.optInt("progress")
        val previousError = job.opt("error")
        job.put("state", "queued").put("progress", 0).remove("error")
        try {
            persist()
        } catch (e: Exception) {
            job.put("state", previousState).put("progress", previousProgress)
            if (previousError != null) job.put("error", previousError)
            throw e
        }
        main.post { next() }
    }

    private fun map(json: JSONObject): Map<String, Any?> =
        json.keys().asSequence().associateWith { key -> convert(json.get(key)) }

    private fun convert(value: Any?): Any? =
        when (value) {
            is JSONObject -> map(value)
            is JSONArray -> (0 until value.length()).map { convert(value.get(it)) }
            JSONObject.NULL -> null
            else -> value
        }

    private fun next() {
        if (closed || active != null) return
        val job = jobs.firstOrNull { it.getString("state") == "queued" } ?: return
        active = job
        job.put("state", "running").put("startedAt", System.currentTimeMillis())
        if (!checkpoint(job)) {
            active = null
            return
        }
        try {
            val project = map(job.getJSONObject("project"))
            val composition = EditorComposition.build(project)
            transformer =
                Transformer.Builder(context)
                    .setEncoderFactory(EditorComposition.encoder(context, project))
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(
                        object : Transformer.Listener {
                            override fun onError(
                                composition: Composition,
                                result: ExportResult,
                                exception: ExportException,
                            ) {
                                finish(job, "failed", exception.message)
                            }

                            override fun onCompleted(
                                composition: Composition,
                                result: ExportResult,
                            ) {
                                if (active !== job) return
                                transformer = null
                                job.put("state", "finalizing")
                                if (!checkpoint(job)) {
                                    temporary(job).delete()
                                    active = null
                                    return
                                }
                                worker.execute {
                                    val gif =
                                        (project["effects"] as? Map<*, *>)?.get("format") == "gif"
                                    val output =
                                        MediaOutput(
                                            context,
                                            "Edited_${job.getString("id")}.${if(gif)"gif" else "mp4"}",
                                            if (gif) "image/gif" else "video/mp4",
                                            onPending = { uri ->
                                                val saved =
                                                    java.util.concurrent.CompletableFuture<Unit>()
                                                main.post {
                                                    try {
                                                        job.put("pending", uri.toString())
                                                        persist()
                                                        saved.complete(Unit)
                                                    } catch (e: Exception) {
                                                        saved.completeExceptionally(e)
                                                    }
                                                }
                                                saved.get()
                                            },
                                        )
                                    try {
                                        require(
                                            result.durationMs > 0 && temporary(job).length() > 0,
                                        )
                                        val durationUs = EditorComposition.durationUs(project)
                                        if (gif) {
                                            val fd = output.open()
                                            val options =
                                                project["effects"] as? Map<*, *>
                                                    ?: emptyMap<Any, Any>()
                                            android.os.ParcelFileDescriptor.AutoCloseOutputStream(
                                                    android.os.ParcelFileDescriptor.dup(
                                                        fd.fileDescriptor,
                                                    ),
                                                )
                                                .use {
                                                    GifWriter.write(
                                                        temporary(job),
                                                        durationUs,
                                                        it,
                                                        (options["gifFps"] as? Number)?.toInt()
                                                            ?: 10,
                                                        (options["gifEdge"] as? Number)?.toInt()
                                                            ?: 320,
                                                        (options["gifRepeats"] as? Number)?.toInt()
                                                            ?: 0,
                                                    )
                                                }
                                        } else EditorOutput.publish(temporary(job), output)
                                        val uri = output.commit().toString()
                                        val size = runCatching {
                                            context.contentResolver
                                                .openAssetFileDescriptor(Uri.parse(uri), "r")
                                                ?.use { it.length } ?: -1L
                                        }
                                            .getOrDefault(-1L)
                                        main.post {
                                            job.put("uri", uri).put("outputBytes", size)
                                            finish(job, "completed", null)
                                        }
                                    } catch (e: Exception) {
                                        try {
                                            output.abort()
                                        } catch (_: Exception) {}
                                        main.post { finish(job, "failed", e.message) }
                                    }
                                }
                            }
                        },
                    )
                    .build()
            transformer!!.start(composition, temporary(job).absolutePath)
        } catch (e: Exception) {
            finish(job, "failed", e.message)
        }
    }

    private fun finish(job: JSONObject, state: String, error: String?) {
        if (active !== job) return
        temporary(job).delete()
        job.put("state", state)
        job.put("progress", if (state == "completed") 100 else 0)
        if (error != null) job.put("error", error)
        job.put("finishedAt", System.currentTimeMillis())
        val durable = checkpoint(job)
        transformer = null
        active = null
        if (durable) next()
    }

    fun close() {
        closed = true
        active
            ?.takeIf { it.getString("state") == "running" }
            ?.let {
                transformer?.cancel()
                finish(it, "failed", "Export interrupted. Retry with the app open.")
            }
        worker.shutdown()
    }
}
