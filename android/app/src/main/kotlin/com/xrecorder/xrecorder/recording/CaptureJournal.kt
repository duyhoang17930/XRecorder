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
            CaptureState.screenshot = data.optBoolean("screenshot")
            CaptureState.output = data.optString("outputUri").takeUnless { it.isBlank() || it == "null" }
            CaptureState.error = data.optString("error").takeUnless { it.isBlank() || it == "null" }
            val config = data.optJSONObject("config")
            if (config != null) runCatching { CaptureState.config = CaptureConfig.from(value, config.keys().asSequence().associateWith { config.get(it) }) }
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
    internal fun dimensions(width: Int, height: Int, readOutput: () -> Pair<Int, Int>?): Pair<Int, Int> {
        if (width > 0 && height > 0) return width to height
        val actual = readOutput()
        return actual?.takeIf { it.first > 0 && it.second > 0 } ?: (0 to 0)
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
            File(app.getExternalFilesDir(null),"media").listFiles()?.filter { (it.name.startsWith("Recording_") && it.name.endsWith(".mp4.pending")) || it.name.matches(Regex("Screenshot_[0-9]+[.]png[.]pending")) }?.forEach { it.delete() }
        }
    }
}
