package com.xrecorder.xrecorder.editor

import android.content.Context
import android.net.Uri
import android.os.StatFs
import java.io.File
import java.net.URL
import java.security.MessageDigest

internal data class SpeechModel(val id: String, val bytes: Long, val sha256: String)

/** Keep the measured working set plus Android's own reserve available. */
internal fun speechMemoryRequiredBytes(
    model: String,
    durationMs: Long,
    systemThreshold: Long,
): Long {
    require(durationMs in 100..600000 && systemThreshold >= 0)
    val mib = 1024L * 1024
    // Measured peaks include274MiB Tiny/381MiB Base/493MiB Small on API36;
    // API37 16KB/2GiB killed Tiny at316MiB RSS. Leave allocation headroom.
    val workingMiB =
        when (model) {
            "tiny" -> 384L
            "base" -> 512L
            "small-q5_1" -> 768L
            else -> throw IllegalArgumentException("Unsupported speech model")
        }
    val buffers = durationMs * 16 * 4 * 3
    return Math.addExact(
        (workingMiB + 128) * mib + buffers,
        systemThreshold.coerceAtLeast(128 * mib),
    )
}

/** Model storage/verification is separate from speech-job and Flutter lifecycle. */
internal class SpeechModels(context: Context) {
    private val context = context.applicationContext
    private val root = File(this.context.noBackupFilesDir, "speech_models").apply { mkdirs() }
    private val preferences =
        this.context.getSharedPreferences("editor_speech_models", Context.MODE_PRIVATE)
    val available =
        listOf(
            SpeechModel(
                "tiny",
                77691713,
                "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
            ),
            SpeechModel(
                "base",
                147951465,
                "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
            ),
            SpeechModel(
                "small-q5_1",
                190085487,
                "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
            ),
        )

    fun find(id: String) =
        available.firstOrNull { it.id == id } ?: error("Choose a supported multilingual model")

    fun file(model: SpeechModel) = File(root, "ggml-${model.id}.bin")

    fun remove(model: SpeechModel) {
        val target = file(model)
        check(!target.exists() || target.delete()) { "Could not remove the selected model" }
        check(preferences.edit().remove("verified_${model.id}").commit())
    }

    fun ready(model: SpeechModel) =
        file(model).length() == model.bytes &&
            preferences.getString("verified_${model.id}", null) == model.sha256

    fun install(
        operationId: String,
        model: SpeechModel,
        source: String?,
        cancelled: () -> Boolean,
        progress: (Double) -> Unit,
        verifying: () -> Unit,
    ) {
        require(operationId.matches(Regex("[A-Za-z0-9_-]{1,80}")))
        val temporary = File(root, "$operationId.part")
        try {
            require(StatFs(root.path).availableBytes > model.bytes + 32 * 1024 * 1024) {
                "Not enough storage for the speech model. Free space and retry."
            }
            val input =
                if (source != null) {
                    val uri = Uri.parse(source)
                    require(uri.scheme == "content")
                    context.contentResolver.openInputStream(uri)
                        ?: error("Model file access was revoked")
                } else {
                    URL(
                            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${model.id}.bin",
                        )
                        .openConnection()
                        .apply {
                            connectTimeout = 15000
                            readTimeout = 5000
                        }
                        .getInputStream()
                }
            val hash = MessageDigest.getInstance("SHA-256")
            var bytes = 0L
            input.use { stream ->
                temporary.outputStream().use { out ->
                    val buffer = ByteArray(65536)
                    while (true) {
                        check(!cancelled()) { "Model operation cancelled" }
                        val count = stream.read(buffer)
                        if (count < 0) break
                        bytes += count
                        require(bytes <= model.bytes) {
                            "This file is not the selected speech model"
                        }
                        out.write(buffer, 0, count)
                        hash.update(buffer, 0, count)
                        progress(bytes.toDouble() / model.bytes * .99)
                    }
                    out.fd.sync()
                }
            }
            verifying()
            require(
                bytes == model.bytes &&
                    hash.digest().joinToString("") { "%02x".format(it) } == model.sha256,
            ) {
                "Model checksum failed. Existing models are unchanged."
            }
            check(!cancelled())
            require(temporary.renameTo(file(model))) { "Could not publish the downloaded model" }
            check(preferences.edit().putString("verified_${model.id}", model.sha256).commit())
        } finally {
            temporary.delete()
        }
    }
}

/** Handles are owned by TranscriptionBridge and released only by its worker. */
@androidx.annotation.Keep
object WhisperNative {
    init {
        System.loadLibrary("threeh_whisper")
    }

    external fun create(): Long

    external fun run(
        handle: Long,
        model: String,
        audio: FloatArray,
        language: String,
        threads: Int,
    ): ByteArray

    external fun progress(handle: Long): Int

    external fun languageId(handle: Long): Int

    external fun activity(handle: Long, audio: FloatArray): FloatArray

    external fun languages(): ByteArray

    external fun timings(handle: Long): LongArray

    external fun cancel(handle: Long)

    external fun destroy(handle: Long)
}
