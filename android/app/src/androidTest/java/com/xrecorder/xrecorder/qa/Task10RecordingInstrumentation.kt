package com.xrecorder.xrecorder.qa

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.MediaStore
import com.xrecorder.xrecorder.recording.CaptureConfig
import com.xrecorder.xrecorder.recording.CaptureJournal
import com.xrecorder.xrecorder.recording.CaptureState
import com.xrecorder.xrecorder.recording.FinalizedCapture
import com.xrecorder.xrecorder.recording.MediaOutput
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

/** Extends the existing test-only runner; the live journal/files are never replaced. */
object Task10RecordingInstrumentation {
    private fun sha(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }

    @JvmStatic fun run(runner: Instrumentation, args: Bundle) {
        val result = Bundle()
        val report = JSONObject()
        try {
            val base = runner.targetContext
            val case = requireNotNull(args.getString("task10"))
            require(case in setOf("recording-audio-lead", "recording-pending", "recording-partial", "recording-png",
                "recording-remux", "recording-remux-retry", "recording-bad-audio", "recording-wrong-session",
                "recording-session-isolation", "recording-published-retry")) { "Unknown recovery test case" }
            val namespace = "task10_r5_${System.currentTimeMillis()}_${java.util.UUID.randomUUID()}"
            val root = File(base.filesDir, namespace)
            check(root.mkdir())
            val context = object : ContextWrapper(base) {
                override fun getFilesDir(): File = root
                override fun getCacheDir(): File = File(root, "cache").apply { mkdirs() }
                override fun getApplicationContext(): Context = this
                override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                    base.getSharedPreferences("${namespace}_$name", mode)
            }
            val liveBefore = base.getSharedPreferences("capture_journal", Context.MODE_PRIVATE).all.toMap()
            fun fixture(key: String): ByteArray {
                val path = requireNotNull(args.getString(key))
                require(path.startsWith("/data/local/tmp/task10_r5_") && !path.contains(".."))
                val bytes = File(path).readBytes()
                check(sha(bytes) == args.getString("${key}Sha"))
                return bytes
            }
            val shortLead = case == "recording-audio-lead"
            val video = fixture(if (shortLead) "leadVideo" else "video")
            val audio = fixture(if (shortLead) "leadAudio" else "audio")
            val png = case == "recording-png"
            val remux = case in setOf("recording-remux", "recording-remux-retry", "recording-bad-audio", "recording-wrong-session", "recording-audio-lead")
            val publishedRetry = case == "recording-published-retry"
            val withAudio = remux || publishedRetry
            val config = CaptureConfig.from(context, mapOf(
                "width" to 720, "height" to 1280, "fps" to 30,
                "audio" to if (withAudio) "microphone" else "mute"
            ))
            CaptureState.prepare(config, png)
            val id = CaptureState.id
            val prefs = context.getSharedPreferences("capture_journal", Context.MODE_PRIVATE)
            val pending = mutableListOf<Uri>()
            fun create(name: String, bytes: ByteArray, mime: String = "video/mp4", publish: Boolean = false): Uri {
                var reference: Uri? = null
                val output = MediaOutput(context, name, mime, onPending = { reference = it; pending.add(it) })
                val descriptor = output.open()
                ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(descriptor.fileDescriptor)).use {
                    it.write(bytes); it.flush()
                }
                if (publish) output.commit() else output.retain()
                return requireNotNull(reference)
            }
            val originalBytes = when (case) {
                "recording-pending" -> video
                "recording-png" -> fixture("png")
                else -> byteArrayOf(0, 1, 2, 3, 4, 5, 6, 7)
            }
            val original = create("TASK10_R5_${id}.${if (png) "png" else "mp4"}", originalBytes,
                if (png) "image/png" else "video/mp4")
            val values = CaptureState.snapshot().toMutableMap().apply { put("state", "finalizing") }
            val edit = prefs.edit().putString("session", JSONObject(values).toString())
                .putString("pending", original.toString()).putString("pendingSessionId", id)
            var recoveryTarget: Uri? = null
            var videoFile: File? = null
            var audioFile: File? = null
            if (remux) {
                videoFile = File(context.cacheDir, "capture_$id.mp4").apply { writeBytes(video) }
                audioFile = File(context.cacheDir, "capture_$id.m4a").apply {
                    writeBytes(if (case == "recording-bad-audio") byteArrayOf(10, 20, 30) else audio)
                }
            }
            if (remux || publishedRetry) {
                val timingId = if (case == "recording-wrong-session") java.util.UUID.randomUUID().toString() else id
                val timing = if (shortLead) FinalizedCapture(timingId, requireNotNull(args.getString("leadDurationUs")).toLong(), -700000)
                    else FinalizedCapture(timingId, requireNotNull(args.getString("durationUs")).toLong(), 200000)
                edit.putString("finalized", JSONObject(timing.map()).toString())
            }
            if (case == "recording-remux-retry" || publishedRetry) {
                recoveryTarget = create("Recovered_$id.mp4", if (publishedRetry) fixture("combined") else byteArrayOf(9, 8, 7), publish = publishedRetry)
                edit.putString("recoveryPending", recoveryTarget.toString())
            }
            check(edit.commit())
            val videoHash = videoFile?.let { sha(it.readBytes()) }
            val audioHash = audioFile?.let { sha(it.readBytes()) }
            runner.runOnMainSync { CaptureJournal.initialize(context) }
            val deadline = SystemClock.elapsedRealtime() + 25000
            while (SystemClock.elapsedRealtime() < deadline) {
                val state = JSONObject(requireNotNull(prefs.getString("session", null))).getString("state")
                if (state == "completed" || state == "failed") break
                SystemClock.sleep(30)
            }
            val terminal = JSONObject(requireNotNull(prefs.getString("session", null)))
            val success = case in setOf("recording-pending", "recording-png", "recording-remux", "recording-remux-retry", "recording-published-retry", "recording-audio-lead")
            check(base.getSharedPreferences("capture_journal", Context.MODE_PRIVATE).all == liveBefore)
            check(videoFile == null || sha(videoFile.readBytes()) == videoHash)
            check(audioFile == null || sha(audioFile.readBytes()) == audioHash)
            report.put("case", case).put("sessionId", id).put("root", root.absolutePath)
                .put("originalUri", original.toString()).put("terminal", terminal)
                .put("fixturePendingUris", org.json.JSONArray(pending.map(Uri::toString)))
                .put("liveJournalUnchanged", true).put("sourceStreamsUnchanged", true)
            check(terminal.getString("state") == if (success) "completed" else "failed") { terminal.toString() }
            val checkpoint = File(context.filesDir, "capture_recovery/$id.json")
            check(checkpoint.isFile)
            val bytesAfter = context.contentResolver.openInputStream(original)!!.use { it.readBytes() }
            check(sha(bytesAfter) == sha(originalBytes))
            val uri = terminal.optString("outputUri").takeUnless { it == "null" || it.isEmpty() }
            if (success) {
                check(!prefs.contains("pending") && !prefs.contains("finalized") && !prefs.contains("recoveryPending"))
                if (case == "recording-pending" || png) check(uri == original.toString())
                if (recoveryTarget != null) check(uri == recoveryTarget.toString())
                context.contentResolver.query(Uri.parse(uri), arrayOf(MediaStore.MediaColumns.IS_PENDING), null, null, null)!!.use {
                    check(it.moveToFirst() && it.getInt(0) == 0)
                }
            } else {
                check(uri == null && prefs.getString("pending", null) == original.toString())
                context.contentResolver.query(original, arrayOf(MediaStore.MediaColumns.IS_PENDING), null, null, null)!!.use {
                    check(it.moveToFirst() && it.getInt(0) == 1)
                }
                if (case == "recording-session-isolation") {
                    runner.runOnMainSync { CaptureState.prepare(config, false) }
                    check(CaptureState.id != id && !prefs.contains("pending") && checkpoint.isFile)
                    check(sha(context.contentResolver.openInputStream(original)!!.use { it.readBytes() }) == sha(originalBytes))
                }
            }
            report.put("status", "PASS").put("case", case).put("sessionId", id).put("root", root.absolutePath)
                .put("uri", uri ?: JSONObject.NULL).put("originalUri", original.toString())
                .put("originalSha256", sha(originalBytes)).put("originalBytesUnchanged", true)
                .put("liveJournalUnchanged", true).put("sourceStreamsUnchanged", true)
                .put("checkpointRetained", true).put("terminal", terminal)
                .put("fixturePendingUris", org.json.JSONArray(pending.map(Uri::toString)))
        } catch (error: Throwable) {
            android.util.Log.e("TASK10_R5", "Recording recovery fixture failed", error)
            report.put("status", "FAIL").put("error", error.toString())
        }
        result.putString("stream", "TASK10_RECORDING_RESULT:" + report)
        runner.finish(if (report.optString("status") == "PASS") Activity.RESULT_OK else Activity.RESULT_CANCELED, result)
    }
}
