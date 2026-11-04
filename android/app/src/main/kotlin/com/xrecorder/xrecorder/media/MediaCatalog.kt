package com.xrecorder.xrecorder.media

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Size
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MediaCatalog(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object { const val PICK_FOLDER = 701 }
    private val resolver = activity.contentResolver
    private val worker = Executors.newSingleThreadExecutor()
    private val preferences = activity.getSharedPreferences("media_catalog", Context.MODE_PRIVATE)
    private var picker: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "selectFolder") {
            if (picker != null) { result.error("busy", "A folder picker is already open", null); return }
            picker = result
            try {
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION), PICK_FOLDER)
            } catch (_: Exception) { picker = null; result.error("unavailable", "No folder picker is installed", null) }
            return
        }
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "folder" -> preferences.getString("folder", null)
                    "list" -> list(call.argument<String>("kind") ?: "video", call.argument<String>("folder"))
                    "find" -> describe(Uri.parse(call.argument<String>("id") ?: ""))
                    "thumbnail" -> thumbnail(Uri.parse(call.argument<String>("uri") ?: ""))
                    "storage" -> storage()
                    else -> { activity.runOnUiThread { result.notImplemented() }; return@execute }
                }
                activity.runOnUiThread { result.success(value) }
            } catch (_: SecurityException) {
                activity.runOnUiThread { result.error("revoked", "Folder or media access was revoked. Select the folder again.", null) }
            } catch (_: java.io.FileNotFoundException) {
                activity.runOnUiThread { result.error("missing", "This media is no longer available.", null) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("io", "Could not read media. Retry or select another folder.", null) }
            }
        }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != PICK_FOLDER) return false
        val result = picker ?: return true
        picker = null
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        worker.execute {
            try {
                resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (!preferences.edit().putString("folder", uri.toString()).commit()) throw java.io.IOException()
                activity.runOnUiThread { result.success(uri.toString()) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("denied", "Could not retain access. Choose a supported local folder.", null) }
            }
        }
        return true
    }

    private fun checkUri(uri: Uri) { require(uri.scheme == "content") }

    fun list(kind: String, folder: String?): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        if (folder != null) {
            val tree = Uri.parse(folder)
            checkUri(tree)
            if (resolver.persistedUriPermissions.none { it.uri == tree && it.isReadPermission }) throw SecurityException()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val mime = c.getString(1) ?: ""
                    if ((kind == "video" && mime.startsWith("video/")) || (kind == "image" && mime.startsWith("image/"))) {
                        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
                        items.add(mapOf("id" to uri.toString(), "uri" to uri.toString(), "name" to c.getString(2),
                            "mime" to mime, "size" to c.getLong(3), "modified" to c.getLong(4), "created" to c.getLong(4),
                            "source" to "imported", "folder" to folder))
                    }
                }
            } ?: throw java.io.IOException()
        } else if (Build.VERSION.SDK_INT >= 29) {
            val collection = if (kind == "video") MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val projection = mutableListOf("_id", "_display_name", "mime_type", "_size", "date_added", "date_modified", "width", "height")
            if (kind == "video") projection.add("duration")
            resolver.query(collection, projection.toTypedArray(), "owner_package_name=? AND is_pending=0",
                arrayOf(activity.packageName), "date_added DESC")?.use { c ->
                while (c.moveToNext()) {
                    val uri = ContentUris.withAppendedId(collection, c.getLong(0)).toString()
                    items.add(mapOf("id" to uri, "uri" to uri, "name" to c.getString(1), "mime" to c.getString(2),
                        "size" to c.getLong(3), "created" to c.getLong(4) * 1000, "modified" to c.getLong(5) * 1000,
                        "width" to c.getInt(6), "height" to c.getInt(7), "duration" to if (kind == "video") c.getLong(8) else null,
                        "source" to "recording"))
                }
            } ?: throw java.io.IOException()
        } else {
            File(activity.getExternalFilesDir(null), "media").listFiles()?.filter { it.isFile }?.forEach { file ->
                val mime = when (file.extension.lowercase()) { "mp4" -> "video/mp4"; "png" -> "image/png"; "jpg", "jpeg" -> "image/jpeg"; else -> "" }
                if (mime.startsWith("$kind/")) {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", file).toString()
                    items.add(mapOf("id" to uri, "uri" to uri, "name" to file.name, "mime" to mime, "size" to file.length(),
                        "modified" to file.lastModified(), "created" to file.lastModified(), "source" to "recording"))
                }
            }
        }
        return items.sortedByDescending { (it["created"] as? Long) ?: 0 }
    }

    fun describe(uri: Uri): Map<String, Any?>? {
        if (uri.scheme != "content") return null
        val mime = resolver.getType(uri) ?: return null
        if (!mime.startsWith("video/") && !mime.startsWith("image/")) return null
        val fields = mutableMapOf<String, Any?>("id" to uri.toString(), "uri" to uri.toString(), "mime" to mime,
            "source" to "imported", "created" to 0L, "modified" to 0L)
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (!c.moveToFirst()) return null
            fields["name"] = c.getString(0); fields["size"] = c.getLong(1)
        } ?: return null
        resolver.openFileDescriptor(uri, "r")?.use {} ?: return null
        if (mime.startsWith("video/")) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(activity, uri)
                fields["duration"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                fields["width"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
                fields["height"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
                fields["bitrate"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull()
            } finally { retriever.release() }
        }
        return fields
    }

    private fun thumbnail(uri: Uri): ByteArray {
        checkUri(uri)
        var bitmap: Bitmap? = null
        if (Build.VERSION.SDK_INT >= 29) {
            try { bitmap = resolver.loadThumbnail(uri, Size(320, 240), null) } catch (_: java.io.IOException) { }
        }
        if (bitmap == null) {
            val mime = resolver.getType(uri) ?: throw java.io.FileNotFoundException()
            if (mime.startsWith("video/")) {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(activity, uri)
                    bitmap = if (Build.VERSION.SDK_INT >= 27) retriever.getScaledFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 320, 240)
                        else retriever.getFrameAtTime(0)
                } finally { retriever.release() }
            } else {
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
                options.inSampleSize = 1
                while (options.outWidth / options.inSampleSize > 640 || options.outHeight / options.inSampleSize > 640) options.inSampleSize *= 2
                options.inJustDecodeBounds = false
                bitmap = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            }
        }
        val decoded = bitmap ?: throw java.io.IOException()
        val ratio = minOf(1.0, 320.0 / decoded.width, 240.0 / decoded.height)
        val scaled = Bitmap.createScaledBitmap(decoded, maxOf(1, (decoded.width * ratio).toInt()), maxOf(1, (decoded.height * ratio).toInt()), true)
        try { return ByteArrayOutputStream().use { out -> scaled.compress(Bitmap.CompressFormat.JPEG, 80, out); out.toByteArray() } }
        finally { if (scaled !== decoded) scaled.recycle(); decoded.recycle() }
    }

    private fun directoryBytes(dir: File): Long = if (!dir.exists()) 0 else dir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
    private fun storage(): Map<String, Long> = mapOf(
        "videos" to list("video", null).sumOf { (it["size"] as? Long) ?: 0 },
        "images" to list("image", null).sumOf { (it["size"] as? Long) ?: 0 },
        "cache" to directoryBytes(activity.cacheDir), "trash" to directoryBytes(File(activity.filesDir, "trash")),
        "free" to StatFs(activity.getExternalFilesDir(null)?.absolutePath ?: activity.filesDir.absolutePath).availableBytes)

    fun dispose() { picker?.error("cancelled", "Folder selection interrupted", null); picker = null; worker.shutdown() }
}
