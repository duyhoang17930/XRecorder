package com.xrecorder.xrecorder.recording

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File

/** Never expose a partly written recording as a finished media item. */
class MediaOutput(private val context: Context, val name: String, val mime: String = "video/mp4") {
    private var pendingUri: Uri? = null
    private var temporary: File? = null
    private var descriptor: ParcelFileDescriptor? = null
    private var committed = false
    fun open(): ParcelFileDescriptor {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, if (mime.startsWith("video/")) "Movies/XRecorder" else "Pictures/XRecorder")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection = if (mime.startsWith("video/")) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            pendingUri = context.contentResolver.insert(collection, values) ?: throw java.io.IOException("Cannot create output")
            CaptureJournal.pending(pendingUri!!)
            descriptor = context.contentResolver.openFileDescriptor(pendingUri!!, "rw") ?: throw java.io.IOException("Cannot open output")
        } else {
            val directory = File(context.getExternalFilesDir(null), "media").apply { mkdirs() }
            temporary = File(directory, "$name.pending")
            descriptor = ParcelFileDescriptor.open(temporary!!, ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_READ_WRITE or ParcelFileDescriptor.MODE_TRUNCATE)
        }
        return descriptor!!
    }
    val legacyPath: String? get() = temporary?.absolutePath
    fun commit(): Uri {
        require(!committed)
        val size = descriptor?.statSize ?: 0
        descriptor?.close(); descriptor = null
        if (size <= 0) throw java.io.IOException("Recording is empty")
        val uri = if (Build.VERSION.SDK_INT >= 29) {
            val uri = pendingUri ?: throw java.io.IOException("Output missing")
            if (context.contentResolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) != 1) throw java.io.IOException("Cannot publish output")
            uri
        } else {
            val file = temporary ?: throw java.io.IOException("Output missing")
            val published = File(file.parentFile, name)
            if (published.exists() || !file.renameTo(published)) throw java.io.IOException("Cannot publish output")
            temporary = published
            FileProvider.getUriForFile(context, "${context.packageName}.files", published)
        }
        committed = true
        CaptureJournal.cleared()
        return uri
    }
    fun abort() {
        try { descriptor?.close() } catch (_: Exception) { }
        descriptor = null
        if (committed) return
        pendingUri?.let { context.contentResolver.delete(it, null, null) }
        temporary?.let { if (it.exists() && !it.delete()) throw java.io.IOException("Could not remove partial media") }
        CaptureJournal.cleared()
    }
}
