package com.xrecorder.xrecorder.editor

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.*
import com.xrecorder.xrecorder.recording.MediaOutput
import io.flutter.plugin.common.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import org.json.JSONObject

class EditorBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val directory = File(context.filesDir, "projects").apply { mkdirs() }
    private var probe: Transformer? = null
    private var probeResult: MethodChannel.Result? = null
    private val exports by lazy { ExportQueue.get(context) }
    private val transcription by lazy { TranscriptionBridge(context) }

    private fun file(id: String): File {
        require(id.matches(Regex("[a-zA-Z0-9_-]{1,80}")))
        return File(directory, "$id.json")
    }

    private fun readDraft(source: File): String? {
        // AtomicFile can recover a legacy .bak even when the base file is absent.
        if (!source.exists() && !File(source.path + ".bak").exists()) return null
        return AtomicFile(source).openRead().use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(out.size() + count <= 1048576) { "The draft is larger than supported." }
                out.write(buffer, 0, count)
            }
            out.toString(Charsets.UTF_8.name())
        }
    }

    private fun listDrafts(): List<String> {
        val candidates =
            directory
                .listFiles()
                ?.filter {
                    it.isFile && (it.name.endsWith(".json") || it.name.endsWith(".json.bak"))
                }
                ?.map { File(directory, it.name.removeSuffix(".bak")) }
                ?.filter { it.name.removeSuffix(".json").matches(Regex("[a-zA-Z0-9_-]{1,80}")) }
                ?.distinctBy { it.name }
                ?.sortedByDescending {
                    maxOf(it.lastModified(), File(it.path + ".bak").lastModified())
                } ?: emptyList()
        return candidates.map { source ->
            try {
                readDraft(source) ?: "{\"version\":-1}"
            } catch (_: Exception) {
                "{\"version\":-1}"
            } // Counted/reported by Dart; source remains intact.
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method.startsWith("transcription")) {
            transcription.handle(call, result)
            return
        }
        if (call.method.startsWith("export")) {
            try {
                val value: Any? =
                    when (call.method) {
                        "exportList" -> exports.list()
                        "exportDiagnostics" -> exports.diagnostics()
                        "exportStart" -> exports.enqueue(call.arguments as Map<*, *>)
                        "exportCancel" -> {
                            exports.cancel(call.arguments as String)
                            null
                        }
                        "exportRetry" -> {
                            exports.retry(call.arguments as String)
                            null
                        }
                        else -> {
                            result.notImplemented()
                            return
                        }
                    }
                result.success(value)
            } catch (e: Exception) {
                result.error("export", e.message, null)
            }
            return
        }
        if (call.method == "engineProbe") {
            probe(call.arguments as Map<*, *>, result)
            return
        }
        worker.execute {
            try {
                val value: Any? =
                    when (call.method) {
                        "audioInfo" -> {
                            val uri = android.net.Uri.parse(call.arguments as String)
                            require(uri.scheme == "content")
                            val reader = android.media.MediaMetadataRetriever()
                            try {
                                reader.setDataSource(context, uri)
                                mapOf(
                                    "durationMs" to
                                        (reader
                                            .extractMetadata(
                                                android.media.MediaMetadataRetriever
                                                    .METADATA_KEY_DURATION,
                                            )
                                            ?.toLong() ?: error("Audio duration is unavailable")),
                                )
                            } finally {
                                reader.release()
                            }
                        }
                        "list" -> listDrafts()
                        "find" -> readDraft(file(call.arguments as String))
                        "save" -> {
                            val document = call.arguments as String
                            require(document.length <= 1048576)
                            val bytes = document.toByteArray(Charsets.UTF_8)
                            require(bytes.size <= 1048576) { "The draft is larger than supported." }
                            val json = JSONObject(document)
                            require(
                                json.getInt("version") == 1 &&
                                    json.getJSONArray("clips").length() <= 30,
                            )
                            val target = AtomicFile(file(json.getString("id")))
                            val out = target.startWrite()
                            try {
                                out.write(bytes)
                                target.finishWrite(out)
                            } catch (e: Exception) {
                                target.failWrite(out)
                                throw e
                            }
                            null
                        }
                        "delete" -> {
                            AtomicFile(file(call.arguments as String)).delete()
                            null
                        }
                        else -> {
                            main.post { result.notImplemented() }
                            return@execute
                        }
                    }
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post {
                    result.error(
                        if (call.method == "audioInfo") "audio_info" else "draft_io",
                        e.message ?: "Draft could not be saved or loaded",
                        null,
                    )
                }
            }
        }
    }

    private fun probe(project: Map<*, *>, result: MethodChannel.Result) {
        if (probe != null) {
            result.error("busy", "An engine verification is running", null)
            return
        }
        val temporary = File(context.cacheDir, "editor_probe_${System.currentTimeMillis()}.mp4")
        try {
            val composition = EditorComposition.build(project)
            probeResult = result
            probe =
                Transformer.Builder(context)
                    .setEncoderFactory(EditorComposition.encoder(context, project))
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(
                        object : Transformer.Listener {
                            override fun onCompleted(
                                composition: Composition,
                                exportResult: ExportResult,
                            ) {
                                worker.execute {
                                    val output =
                                        MediaOutput(
                                            context,
                                            "Editor_probe_${System.currentTimeMillis()}.mp4",
                                        )
                                    try {
                                        require(
                                            exportResult.durationMs > 0 && temporary.length() > 0,
                                        )
                                        EditorOutput.publish(temporary, output)
                                        val uri = output.commit().toString()
                                        main.post {
                                            probe = null
                                            probeResult?.success(uri)
                                            probeResult = null
                                        }
                                    } catch (e: Exception) {
                                        output.abort()
                                        main.post {
                                            probe = null
                                            probeResult?.error("export_failed", e.message, null)
                                            probeResult = null
                                        }
                                    } finally {
                                        temporary.delete()
                                    }
                                }
                            }

                            override fun onError(
                                composition: Composition,
                                exportResult: ExportResult,
                                exception: ExportException,
                            ) {
                                temporary.delete()
                                probe = null
                                probeResult?.error("export_failed", exception.message, null)
                                probeResult = null
                            }
                        },
                    )
                    .build()
            probe!!.start(composition, temporary.absolutePath)
        } catch (e: Exception) {
            temporary.delete()
            probe = null
            probeResult = null
            result.error("editor_engine", e.message, null)
        }
    }

    fun dispose() {
        probe?.cancel()
        probe = null
        probeResult?.error("interrupted", "Editor closed during verification", null)
        probeResult = null
        transcription.dispose()
        worker.shutdown()
    }
}
