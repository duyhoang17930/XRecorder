package com.xrecorder.xrecorder.recording

import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
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
            CaptureState.output = data.optString("outputUri").takeUnless { it.isBlank() || it == "null" }
            CaptureState.error = data.optString("error").takeUnless { it.isBlank() || it == "null" }
            val config = data.optJSONObject("config")
            if (config != null) runCatching { CaptureState.config = CaptureConfig.from(value, config.keys().asSequence().associateWith { config.get(it) }) }
            if (CaptureState.busy) {
                cleanup()
                CaptureState.state = "failed"
                CaptureState.error = "Android interrupted the previous recording. Start a new session to grant capture access again."
                CaptureState.output = null
            }
            save()
        } catch (_: Exception) {
            CaptureState.state = "failed"; CaptureState.error = "The previous recording journal could not be recovered."
        }
    }
    fun save() { if (context != null) prefs.edit().putString("session", JSONObject(CaptureState.snapshot()).toString()).commit() }
    fun pending(uri: Uri) { if (context != null) check(prefs.edit().putString("pending",uri.toString()).commit()) }
    fun cleared() { if (context != null) prefs.edit().remove("pending").commit() }
    private fun cleanup() {
        val app = context!!
        val uri = prefs.getString("pending",null)?.let(Uri::parse)
        if (uri != null && Build.VERSION.SDK_INT >= 29 && uri.authority == "media") {
            app.contentResolver.query(uri,arrayOf(MediaStore.MediaColumns.IS_PENDING,MediaStore.MediaColumns.OWNER_PACKAGE_NAME),null,null,null)?.use {
                if (it.moveToFirst() && it.getInt(0) == 1 && it.getString(1) == app.packageName) app.contentResolver.delete(uri,null,null)
            }
        }
        cleared()
        // Exact session-derived filenames; never scan/delete unrelated media or exports.
        val id = CaptureState.id
        if (id.matches(Regex("[a-fA-F0-9-]{36}"))) {
            File(app.cacheDir,"capture_$id.mp4").delete()
            File(app.cacheDir,"capture_$id.m4a").delete()
        }
        if (Build.VERSION.SDK_INT < 29) {
            File(app.getExternalFilesDir(null),"media").listFiles()?.filter { it.name.startsWith("Recording_") && it.name.endsWith(".mp4.pending") }?.forEach { it.delete() }
        }
    }
}
