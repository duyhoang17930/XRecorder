package com.xrecorder.xrecorder.recording

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.io.File

/** Bounded local journal. Contains output references, never projection consent. */
object CaptureJournal {
    private var context: Context? = null
    private val prefs get() = context!!.getSharedPreferences("capture_journal", Context.MODE_PRIVATE)
    fun initialize(value: Context) {
        if (context != null) return
        context = value.applicationContext
        val saved = prefs.getString("session", null) ?: return
        try {
            val data = JSONObject(saved)
            CaptureState.id = data.optString("id")
            CaptureState.state = data.optString("state", "idle")
            CaptureState.elapsed = data.optLong("elapsedMs")
            CaptureState.startedAt = data.optLong("startedAt")
            CaptureState.screenshot = data.optBoolean("screenshot")
            CaptureState.countdownRemaining = data.optInt("countdownRemaining")
            CaptureState.output = data.optString("outputUri").takeUnless { it.isBlank() || it == "null" }
            CaptureState.error = data.optString("error").takeUnless { it.isBlank() || it == "null" }
            val config = data.optJSONObject("config")
            if (config != null) CaptureState.config = CaptureConfig.restore(config.keys().asSequence().associateWith { config.get(it) })
            val dimensions = dimensions(
                data.optInt("width", if (CaptureState.screenshot) 0 else CaptureState.config.width),
                data.optInt("height", if (CaptureState.screenshot) 0 else CaptureState.config.height)
            ) {
                if (!CaptureState.screenshot || CaptureState.state != "completed") null
                else CaptureState.output?.let { output ->
                    runCatching {
                        val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        value.contentResolver.openInputStream(Uri.parse(output))?.use {
                            android.graphics.BitmapFactory.decodeStream(it, null, bounds)
                        }
                        if (bounds.outMimeType == "image/png") bounds.outWidth to bounds.outHeight else null
                    }.getOrNull()
                }
            }
            CaptureState.width = dimensions.first
            CaptureState.height = dimensions.second
            if (CaptureState.busy || (CaptureState.state == "failed" && (finalized() != null || prefs.contains("pending") || prefs.contains("recoveryPending")))) {
                retainInterruptedInputs()
                val sessionId = CaptureState.id
                val pending = prefs.getString("pending", null)
                val configSnapshot = CaptureState.config
                val screenshot = CaptureState.screenshot
                CaptureState.transition("finalizing")
                Thread({
                    val recovered = recover(value.applicationContext, pending, configSnapshot, screenshot, sessionId)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        if (CaptureState.id != sessionId || CaptureState.state != "finalizing") return@post
                        if (recovered != null) {
                            CaptureState.output = recovered.uri
                            CaptureState.width = recovered.width
                            CaptureState.height = recovered.height
                            CaptureState.transition("completed")
                        } else {
                            CaptureState.output = null
                            CaptureState.transition("failed", "Android interrupted the previous recording. Recovery inputs were kept. Start a new session to grant capture access again.")
                        }
                    }
                }, "capture-recovery").start()
            }
            // Do not rewrite idle/terminal journals merely because the app was opened.
        } catch (_: Exception) {
            CaptureState.state = "failed"; CaptureState.error = "The previous recording journal could not be recovered."
        }
    }
    internal fun dimensions(width: Int, height: Int, readOutput: () -> Pair<Int, Int>?): Pair<Int, Int> {
        if (width > 0 && height > 0) return width to height
        val actual = readOutput()
        return actual?.takeIf { it.first > 0 && it.second > 0 } ?: (0 to 0)
    }
    fun save() {
        if (context == null) return
        val edit = prefs.edit().putString("session", JSONObject(CaptureState.snapshot()).toString())
        // Clear the publication reference in the same transaction as completed.
        if (CaptureState.state == "completed") {
            edit.remove("pending").remove("pendingSessionId").remove("finalized").remove("recoveryPending")
        }
        edit.commit()
    }
    fun pending(uri: Uri) {
        if (context != null) check(prefs.edit().putString("pending", uri.toString())
            .putString("pendingSessionId", CaptureState.id).commit())
    }
    fun cleared() {
        if (context != null) prefs.edit().remove("pending").remove("pendingSessionId")
            .remove("finalized").remove("recoveryPending").commit()
    }
    fun beforeNewSession() {
        if (context == null) return
        retainInterruptedInputs()
        check(prefs.edit().remove("pending").remove("pendingSessionId")
            .remove("finalized").remove("recoveryPending").commit())
    }
    fun finalizedStreams(durationUs: Long, audioOffsetUs: Long) {
        if (context == null) return
        val value = FinalizedCapture(CaptureState.id, durationUs, audioOffsetUs)
        require(FinalizedCapture.restore(value.map(), CaptureState.id) != null)
        check(prefs.edit().putString("finalized", JSONObject(value.map()).toString()).commit())
    }
    private fun finalized(): FinalizedCapture? = runCatching {
        val value = JSONObject(prefs.getString("finalized", null) ?: return null)
        FinalizedCapture.restore(value.keys().asSequence().associateWith { value.get(it) }, CaptureState.id)
    }.getOrNull()
    fun retainCurrent() { if (context != null) retainInterruptedInputs() }
    internal fun recoverCurrent(value: Context): CaptureRecovery.Recovered? =
        recover(value, prefs.getString("pending", null), CaptureState.config, CaptureState.screenshot, CaptureState.id)

    private fun recover(value: Context, pending: String?, config: CaptureConfig, screenshot: Boolean, sessionId: String): CaptureRecovery.Recovered? {
        // Older journals lack pendingSessionId; a new session always clears that legacy reference first.
        val owner = prefs.getString("pendingSessionId", sessionId)
        val timing = finalized()
        return CaptureRecovery.recover(value, pending.takeIf { owner == sessionId }, config, screenshot,
            timing, prefs.getString("recoveryPending", null)) { uri ->
            check(prefs.edit().putString("recoveryPending", uri.toString()).commit())
        }
    }
    /** Preserve the exact interrupted session before a future capture replaces pending prefs.
     * Missing moov/sample tables are not repairable merely by deleting the input.
     * Recovery may inspect these files later; opening the app must not destroy them.
     */
    private fun retainInterruptedInputs() {
        val app = context!!
        val id = CaptureState.id
        if (!id.matches(Regex("[a-fA-F0-9-]{36}"))) return
        val pending = prefs.getString("pending", null)
        val video = File(app.cacheDir, "capture_$id.mp4")
        val audio = File(app.cacheDir, "capture_$id.m4a")
        if (pending == null && !video.exists() && !audio.exists()) return
        val directory = File(app.filesDir, "capture_recovery")
        check(directory.isDirectory || directory.mkdirs()) { "Cannot preserve capture recovery checkpoint" }
        val checkpoint = File(directory, "$id.json")
        // Keep the first record, and update a separate durable latest snapshot
        // when recovery has since created another pending destination.
        val destination = if (checkpoint.exists()) File(directory, "$id.latest.json") else checkpoint
        val document = JSONObject().apply {
            put("version", 1)
            put("session", JSONObject(CaptureState.snapshot()))
            put("pendingUri", pending ?: JSONObject.NULL)
            put("pendingSessionId", prefs.getString("pendingSessionId", id))
            val rawTiming = prefs.getString("finalized", null)
            put("finalized", runCatching { rawTiming?.let(::JSONObject) }.getOrNull() ?: JSONObject.NULL)
            put("finalizedRaw", rawTiming ?: JSONObject.NULL)
            put("recoveryPending", prefs.getString("recoveryPending", null) ?: JSONObject.NULL)
            put("videoPath", video.absolutePath)
            put("audioPath", audio.absolutePath)
        }
        val atomic = android.util.AtomicFile(destination)
        val stream = atomic.startWrite()
        try {
            stream.write(document.toString().toByteArray(Charsets.UTF_8))
            atomic.finishWrite(stream)
        } catch (error: Exception) {
            atomic.failWrite(stream)
            throw error
        }
        // No delete/clear: incomplete content and the original journal references survive.
        // Do not scan legacy media directories or remove other sessions' .pending files.
    }
}
