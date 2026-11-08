package com.xrecorder.xrecorder.media

import android.app.Activity
import android.content.ClipData
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.FileObserver
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Size
import androidx.core.content.FileProvider
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MediaCatalog(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        // P1 owns702-706; SupportBridge owns704. Keep P2/P3 in a separate range.
        const val PICK_FOLDER = 1701
        private const val PICK_AUDIO = 1702
        private const val PICK_MODEL = 1703
        private const val CREATE_SRT = 1704
        private const val PICK_DESTINATION = 1705
    }

    private val resolver = activity.contentResolver
    private val actions = MediaActions(activity)
    private val transfers = MediaTransfers(activity)
    private val worker = Executors.newSingleThreadExecutor()
    private val preferences = activity.getSharedPreferences("media_catalog", Context.MODE_PRIVATE)
    private var picker: MethodChannel.Result? = null
    private var subtitleBytes: ByteArray? = null
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    @Volatile private var disposed = false
    // Accessed only by the existing serial worker. No timer or database mutation.
    private val signatures = mutableMapOf<Pair<String, String?>, List<List<Any?>>>()
    private val observed = mutableSetOf<Uri>()
    private val observer =
        object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                scheduleCheck()
            }

            override fun onChange(selfChange: Boolean, uri: Uri?) {
                scheduleCheck()
            }
        }
    private var legacyObserver: FileObserver? = null
    private val checkTask = Runnable { if (!disposed) worker.execute { checkForChanges() } }

    private fun fingerprint(rows: List<Map<String, Any?>>): List<List<Any?>> = rows.map { row ->
        listOf(
            row["id"],
            row["name"],
            row["size"],
            row["modified"],
            row["created"],
            row["duration"],
            row["width"],
            row["height"],
            row["revision"],
        )
    }

    private fun scheduleCheck() {
        if (disposed) return
        handler.removeCallbacks(checkTask)
        handler.postDelayed(checkTask, 150)
    }

    private fun observe(uri: Uri) {
        if (disposed || uri in observed) return
        try {
            resolver.registerContentObserver(uri, true, observer)
            observed.add(uri)
        } catch (_: SecurityException) {
            /* Resume checks still cover readable app media. */
        } catch (_: IllegalArgumentException) {
            /* Some document providers cannot be observed. */
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        observe(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
        observe(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        if (Build.VERSION.SDK_INT < 29) {
            val directory = File(activity.getExternalFilesDir(null), "media").apply { mkdirs() }
            @Suppress("DEPRECATION")
            val watcher =
                object :
                    FileObserver(
                        directory.absolutePath,
                        FileObserver.CLOSE_WRITE or
                            FileObserver.MOVED_TO or
                            FileObserver.MOVED_FROM or
                            FileObserver.DELETE,
                    ) {
                    override fun onEvent(event: Int, path: String?) {
                        handler.post { scheduleCheck() }
                    }
                }
            legacyObserver = watcher
            watcher.startWatching()
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        handler.removeCallbacks(checkTask)
        resolver.unregisterContentObserver(observer)
        observed.clear()
        legacyObserver?.stopWatching()
        legacyObserver = null
    }

    private fun checkForChanges() {
        if (disposed) return
        var changed = false
        for ((query, previous) in signatures.toMap()) {
            val next =
                try {
                    fingerprint(readList(query.first, query.second))
                } catch (_: Exception) {
                    listOf(listOf("unavailable"))
                }
            if (next != previous) {
                signatures[query] = next
                changed = true
            }
        }
        if (changed) handler.post { if (!disposed) eventSink?.success(null) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "setAppLocale") {
            try {
                P2Locale.save(activity, call.arguments as String)
                result.success(null)
            } catch (_: Exception) {
                result.error("invalid_locale", "Unsupported app locale", null)
            }
            return
        }
        if (call.method == "shortcutStatus") {
            val manager =
                if (Build.VERSION.SDK_INT >= 26)
                    activity.getSystemService(android.content.pm.ShortcutManager::class.java)
                else null
            result.success(
                mapOf(
                    "supported" to (manager?.isRequestPinShortcutSupported == true),
                    "pinned" to (manager?.pinnedShortcuts?.map { it.id } ?: emptyList<String>()),
                    "labels" to
                        (manager?.pinnedShortcuts?.associate { it.id to it.shortLabel.toString() }
                            ?: emptyMap<String, String>()),
                ),
            )
            return
        }
        if (call.method == "pinShortcut") {
            try {
                val kind = call.arguments as String
                require(kind in listOf("video", "photo"))
                if (Build.VERSION.SDK_INT < 26) {
                    result.success(false)
                    return
                }
                val manager =
                    activity.getSystemService(android.content.pm.ShortcutManager::class.java)
                if (!manager.isRequestPinShortcutSupported) {
                    result.success(false)
                    return
                }
                val route = if (kind == "video") "editor" else "photos"
                val label =
                    P2Locale.context(activity)
                        .getString(
                            if (kind == "video") com.xrecorder.xrecorder.R.string.p2_edit_video
                            else com.xrecorder.xrecorder.R.string.p2_edit_photo,
                        )
                val intent =
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("xrecorder://app/$route"),
                        activity,
                        com.xrecorder.xrecorder.MainActivity::class.java,
                    )
                val shortcut =
                    android.content.pm.ShortcutInfo.Builder(activity, "pinned_edit_$kind")
                        .setShortLabel(label)
                        .setIcon(
                            android.graphics.drawable.Icon.createWithResource(
                                activity,
                                com.xrecorder.xrecorder.R.mipmap.ic_launcher,
                            ),
                        )
                        .setIntent(intent)
                        .build()
                result.success(manager.requestPinShortcut(shortcut, null))
            } catch (_: Exception) {
                result.error("unavailable", "This launcher could not create a shortcut", null)
            }
            return
        }
        if (call.method == "exportSrt") {
            if (picker != null) {
                result.error("busy", "A picker is already open", null)
                return
            }
            try {
                val options = call.arguments as? Map<*, *>
                val text = options?.get("text") as? String ?: call.arguments as String
                val filename =
                    options?.get("fileName") as? String
                        ?: "Subtitles_${System.currentTimeMillis()}.srt"
                require(
                    filename.isNotBlank() &&
                        filename.endsWith(".srt", ignoreCase = true) &&
                        filename.toByteArray(Charsets.UTF_8).size <= 240 &&
                        filename.none { it == '/' || it == '\\' || it.code < 32 || it.code == 127 },
                )
                require(text.isNotBlank() && text.toByteArray(Charsets.UTF_8).size <= 1048576)
                subtitleBytes = text.toByteArray(Charsets.UTF_8)
                picker = result
                activity.startActivityForResult(
                    Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .setType("application/x-subrip")
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                        .putExtra(
                            Intent.EXTRA_TITLE,
                            filename,
                        ),
                    CREATE_SRT,
                )
            } catch (_: Exception) {
                picker = null
                subtitleBytes = null
                result.error("io", "Could not open the subtitle save dialog", null)
            }
            return
        }
        if (call.method == "playbackState") {
            result.success(VideoPreviewActivity.instance?.playbackState())
            return
        }
        if (call.method == "preview" || call.method == "share") {
            try {
                val uri = Uri.parse(call.argument<String>("uri") ?: "")
                checkUri(uri)
                val mime = resolver.getType(uri) ?: throw java.io.FileNotFoundException()
                require(mime.startsWith("video/") || mime.startsWith("image/"))
                resolver.openFileDescriptor(uri, "r")!!.use {}
                if (call.method == "preview")
                    activity.startActivity(
                        Intent(activity, VideoPreviewActivity::class.java).setData(uri),
                    )
                else {
                    val intent =
                        Intent(Intent.ACTION_SEND)
                            .setType(mime)
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    intent.clipData = ClipData.newUri(resolver, "Media", uri)
                    activity.startActivity(Intent.createChooser(intent, "Share media"))
                }
                result.success(null)
            } catch (_: Exception) {
                result.error(
                    "unavailable",
                    "Could not open the player or share sheet. Check media access.",
                    null,
                )
            }
            return
        }
        if (call.method == "selectAudio" || call.method == "selectModel") {
            if (picker != null) {
                result.error("busy", "A picker is already open", null)
                return
            }
            picker = result
            try {
                activity.startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .setType(if (call.method == "selectAudio") "audio/*" else "*/*")
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                        .apply {
                            call.argument<String>("initialUri")?.let { initial ->
                                val uri = Uri.parse(initial)
                                require(uri.scheme == "content")
                                if (Build.VERSION.SDK_INT >= 26)
                                    putExtra(
                                        DocumentsContract.EXTRA_INITIAL_URI,
                                        if (DocumentsContract.isTreeUri(uri))
                                            DocumentsContract.buildDocumentUriUsingTree(
                                                uri,
                                                DocumentsContract.getTreeDocumentId(uri),
                                            )
                                        else uri,
                                    )
                            }
                        },
                    if (call.method == "selectAudio") PICK_AUDIO else PICK_MODEL,
                )
            } catch (_: Exception) {
                picker = null
                result.error("unavailable", "No audio picker is installed", null)
            }
            return
        }
        if (call.method == "selectFolder" || call.method == "selectDestination") {
            if (picker != null) {
                result.error("busy", "A folder picker is already open", null)
                return
            }
            picker = result
            try {
                val intent =
                    Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        .addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                if (Build.VERSION.SDK_INT >= 26)
                    runCatching {
                        preferences.getString("folder", null)?.let {
                            val tree = Uri.parse(it)
                            intent.putExtra(
                                DocumentsContract.EXTRA_INITIAL_URI,
                                DocumentsContract.buildDocumentUriUsingTree(
                                    tree,
                                    DocumentsContract.getTreeDocumentId(tree),
                                ),
                            )
                        }
                    }
                activity.startActivityForResult(
                    intent,
                    if (call.method == "selectDestination") PICK_DESTINATION else PICK_FOLDER,
                )
            } catch (_: Exception) {
                picker = null
                result.error("unavailable", "No folder picker is installed", null)
            }
            return
        }
        worker.execute {
            try {
                val value: Any? =
                    when (call.method) {
                        "releaseFolder" -> {
                            val uri = Uri.parse(call.arguments as String)
                            require(DocumentsContract.isTreeUri(uri))
                            resolver.persistedUriPermissions
                                .firstOrNull { it.uri == uri }
                                ?.let { grant ->
                                    val flags =
                                        (if (grant.isReadPermission)
                                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                                        else 0) or
                                            (if (grant.isWritePermission)
                                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                                            else 0)
                                    resolver.releasePersistableUriPermission(uri, flags)
                                }
                            if (preferences.getString("folder", null) == uri.toString())
                                check(preferences.edit().remove("folder").commit())
                            null
                        }
                        "transfer" ->
                            transfers.copy(
                                Uri.parse(call.argument<String>("uri")!!),
                                Uri.parse(call.argument<String>("destination")!!),
                                call.argument<Boolean>("move") == true,
                            )
                        "transferRecovery" -> transfers.recovery()
                        "folder" -> preferences.getString("folder", null)
                        "checkForChanges" -> {
                            checkForChanges()
                            null
                        }
                        "list" ->
                            list(
                                call.argument<String>("kind") ?: "video",
                                call.argument<String>("folder"),
                            )
                        "find" -> describe(Uri.parse(call.argument<String>("id") ?: ""))
                        "thumbnail" -> thumbnail(Uri.parse(call.argument<String>("uri") ?: ""))
                        "thumbnailAt" ->
                            thumbnail(
                                Uri.parse(call.argument<String>("uri") ?: ""),
                                (call.argument<Number>("timeMs")?.toLong() ?: 0).coerceIn(
                                    0,
                                    86400000L,
                                ) * 1000,
                            )
                        "storage" -> storage()
                        "rename" ->
                            actions.rename(
                                Uri.parse(call.argument<String>("uri")!!),
                                call.argument<String>("name")!!.trim(),
                            )
                        "trash" -> {
                            val uri = Uri.parse(call.argument<String>("uri")!!)
                            actions.trash(
                                uri,
                                describe(uri) ?: throw java.io.FileNotFoundException(),
                            )
                        }
                        "listTrash" -> actions.listTrash()
                        "restore" ->
                            describe(Uri.parse(actions.restore(call.argument<String>("id")!!)))
                        "permanentlyDelete" -> {
                            actions.permanentlyDelete(call.argument<String>("id")!!)
                            null
                        }
                        "imageBytes" -> {
                            val uri = Uri.parse(call.argument<String>("uri") ?: "")
                            checkUri(uri)
                            require(resolver.getType(uri)?.startsWith("image/") == true)
                            resolver.openInputStream(uri)!!.use { input ->
                                val out = ByteArrayOutputStream()
                                val buffer = ByteArray(16384)
                                while (true) {
                                    val n = input.read(buffer)
                                    if (n < 0) break
                                    require(out.size() + n <= 32 * 1024 * 1024)
                                    out.write(buffer, 0, n)
                                }
                                val bytes = out.toByteArray()
                                val bounds =
                                    BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                                require(
                                    bounds.outWidth in 1..8192 &&
                                        bounds.outHeight in 1..8192 &&
                                        bounds.outWidth.toLong() * bounds.outHeight <= 20000000L,
                                )
                                bytes
                            }
                        }
                        "readSubtitleDocument" -> {
                            val uri = Uri.parse(call.argument<String>("uri") ?: "")
                            checkUri(uri)
                            val name =
                                resolver
                                    .query(
                                        uri,
                                        arrayOf(OpenableColumns.DISPLAY_NAME),
                                        null,
                                        null,
                                        null,
                                    )
                                    ?.use { cursor ->
                                        if (cursor.moveToFirst()) cursor.getString(0) else null
                                    }
                            val bytes =
                                resolver.openInputStream(uri)!!.use { input ->
                                    val out = ByteArrayOutputStream()
                                    val buffer = ByteArray(8192)
                                    while (true) {
                                        val count = input.read(buffer)
                                        if (count < 0) break
                                        require(out.size() + count <= 1048576) {
                                            "Subtitle document is too large"
                                        }
                                        out.write(buffer, 0, count)
                                    }
                                    out.toByteArray()
                                }
                            mapOf("bytes" to bytes, "name" to name)
                        }
                        "decodePhoto" ->
                            PhotoCodec.decode(activity, Uri.parse(call.argument<String>("uri")!!))
                        "saveImage" -> {
                            var bytes =
                                call.argument<ByteArray>("bytes")
                                    ?: throw IllegalArgumentException()
                            require(bytes.size in 1..32 * 1024 * 1024)
                            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                            require(
                                bounds.outWidth > 0 &&
                                    bounds.outHeight > 0 &&
                                    bounds.outMimeType == "image/png",
                            )
                            val format = call.argument<String>("format") ?: "png"
                            require(format in listOf("png", "jpeg"))
                            val edge = call.argument<Number>("maxEdge")?.toInt() ?: 2048
                            if (format == "jpeg" || edge != 2048)
                                bytes =
                                    PhotoCodec.convert(
                                        bytes,
                                        format,
                                        call.argument<Number>("quality")?.toInt() ?: 95,
                                        edge,
                                    )
                            val output =
                                com.xrecorder.xrecorder.recording.MediaOutput(
                                    activity,
                                    "Edited_${System.currentTimeMillis()}.${if(format=="jpeg")"jpg" else "png"}",
                                    if (format == "jpeg") "image/jpeg" else "image/png",
                                )
                            try {
                                val fd = output.open()
                                android.os.ParcelFileDescriptor.AutoCloseOutputStream(
                                        android.os.ParcelFileDescriptor.dup(fd.fileDescriptor),
                                    )
                                    .use { it.write(bytes) }
                                output.commit().toString()
                            } catch (e: Exception) {
                                output.abort()
                                throw e
                            }
                        }
                        else -> {
                            activity.runOnUiThread { result.notImplemented() }
                            return@execute
                        }
                    }
                activity.runOnUiThread { result.success(value) }
            } catch (e: IllegalArgumentException) {
                activity.runOnUiThread {
                    result.error("invalid", e.message ?: "Invalid media operation.", null)
                }
            } catch (_: SecurityException) {
                activity.runOnUiThread {
                    result.error(
                        "revoked",
                        "Folder or media access was revoked. Select the folder again.",
                        null,
                    )
                }
            } catch (_: java.io.FileNotFoundException) {
                activity.runOnUiThread {
                    result.error("missing", "This media is no longer available.", null)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "io",
                        "Could not read media. Retry or select another folder.",
                        null,
                    )
                }
            }
        }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (
            request != PICK_FOLDER &&
                request != PICK_AUDIO &&
                request != PICK_MODEL &&
                request != CREATE_SRT &&
                request != PICK_DESTINATION
        )
            return false
        val result = picker ?: return true
        picker = null
        val uri = data?.data
        val srt = subtitleBytes
        subtitleBytes = null
        if (code != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        worker.execute {
            try {
                if (request == CREATE_SRT) {
                    val grants =
                        data!!.flags and
                            (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    if (
                        data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0 &&
                            grants != 0
                    ) {
                        try {
                            resolver.takePersistableUriPermission(uri, grants)
                        } catch (_: SecurityException) {
                            /* Provider may grant session access only. */
                        }
                    }
                    resolver.openOutputStream(uri, "w")!!.use {
                        it.write(srt ?: error("Subtitle data is unavailable"))
                    }
                    activity.runOnUiThread { result.success(uri.toString()) }
                    return@execute
                }
                val grants =
                    (data!!.flags and
                        (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                require(grants and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
                if (request == PICK_DESTINATION)
                    require(grants and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0) {
                        "Choose a writable destination"
                    }
                resolver.takePersistableUriPermission(uri, grants)
                if (request == PICK_AUDIO)
                    require(resolver.getType(uri)?.startsWith("audio/") == true)
                else if (
                    request == PICK_FOLDER &&
                        !preferences.edit().putString("folder", uri.toString()).commit()
                )
                    throw java.io.IOException()
                activity.runOnUiThread { result.success(uri.toString()) }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "denied",
                        "Could not retain access. Choose a supported local folder.",
                        null,
                    )
                }
            }
        }
        return true
    }

    private fun checkUri(uri: Uri) {
        require(uri.scheme == "content")
    }

    fun list(kind: String, folder: String?): List<Map<String, Any?>> {
        val rows = readList(kind, folder)
        signatures[kind to folder] = fingerprint(rows)
        if (folder != null)
            handler.post {
                if (eventSink != null)
                    runCatching {
                        val tree = Uri.parse(folder)
                        observe(tree)
                        observe(
                            DocumentsContract.buildChildDocumentsUriUsingTree(
                                tree,
                                DocumentsContract.getTreeDocumentId(tree),
                            ),
                        )
                    }
            }
        return rows
    }

    private fun readList(kind: String, folder: String?): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        if (folder != null) {
            val tree = Uri.parse(folder)
            checkUri(tree)
            if (resolver.persistedUriPermissions.none { it.uri == tree && it.isReadPermission })
                throw SecurityException()
            val pending = pendingDocumentIds()
            val children =
                DocumentsContract.buildChildDocumentsUriUsingTree(
                    tree,
                    DocumentsContract.getTreeDocumentId(tree),
                )
            resolver
                .query(
                    children,
                    arrayOf(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                        DocumentsContract.Document.COLUMN_SIZE,
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                        DocumentsContract.Document.COLUMN_FLAGS,
                    ),
                    null,
                    null,
                    null,
                )
                ?.use { c ->
                    while (c.moveToNext()) {
                        val mime = c.getString(1) ?: ""
                        val name = c.getString(2) ?: ""
                        if (
                            name.endsWith(".pending") ||
                                c.getString(0) in pending ||
                                (Build.VERSION.SDK_INT >= 29 &&
                                    (c.getInt(5) and DocumentsContract.Document.FLAG_PARTIAL) != 0)
                        )
                            continue
                        if (
                            (kind == "video" && mime.startsWith("video/")) ||
                                (kind == "image" && mime.startsWith("image/"))
                        ) {
                            val uri =
                                DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
                            items.add(
                                mapOf(
                                    "id" to uri.toString(),
                                    "uri" to uri.toString(),
                                    "name" to c.getString(2),
                                    "mime" to mime,
                                    "size" to c.getLong(3),
                                    "modified" to c.getLong(4),
                                    "created" to c.getLong(4),
                                    "source" to "imported",
                                    "folder" to folder,
                                ),
                            )
                        }
                    }
                } ?: throw java.io.IOException()
        } else if (Build.VERSION.SDK_INT >= 29) {
            val collection =
                if (kind == "video") MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val projection =
                mutableListOf(
                    "_id",
                    "_display_name",
                    "mime_type",
                    "_size",
                    "date_added",
                    "date_modified",
                    "width",
                    "height",
                )
            if (kind == "video") projection.add("duration")
            if (Build.VERSION.SDK_INT >= 30)
                projection.add(MediaStore.MediaColumns.GENERATION_MODIFIED)
            resolver
                .query(
                    collection,
                    projection.toTypedArray(),
                    "owner_package_name=? AND is_pending=0",
                    arrayOf(activity.packageName),
                    "date_added DESC",
                )
                ?.use { c ->
                    while (c.moveToNext()) {
                        val uri = ContentUris.withAppendedId(collection, c.getLong(0)).toString()
                        items.add(
                            mapOf(
                                "id" to uri,
                                "uri" to uri,
                                "name" to c.getString(1),
                                "mime" to c.getString(2),
                                "size" to c.getLong(3),
                                "created" to c.getLong(4) * 1000,
                                "modified" to c.getLong(5) * 1000,
                                "width" to c.getInt(6),
                                "height" to c.getInt(7),
                                "duration" to if (kind == "video") c.getLong(8) else null,
                                "source" to "recording",
                                "revision" to
                                    if (Build.VERSION.SDK_INT >= 30)
                                        c.getLong(
                                            c.getColumnIndexOrThrow(
                                                MediaStore.MediaColumns.GENERATION_MODIFIED,
                                            ),
                                        )
                                    else null,
                            ),
                        )
                    }
                } ?: throw java.io.IOException()
        } else {
            File(activity.getExternalFilesDir(null), "media")
                .listFiles()
                ?.filter { it.isFile }
                ?.forEach { file ->
                    val mime = legacyMediaMime(file.extension)
                    if (mime.startsWith("$kind/")) {
                        val uri =
                            FileProvider.getUriForFile(
                                    activity,
                                    "${activity.packageName}.files",
                                    file,
                                )
                                .toString()
                        items.add(
                            mapOf(
                                "id" to uri,
                                "uri" to uri,
                                "name" to file.name,
                                "mime" to mime,
                                "size" to file.length(),
                                "modified" to file.lastModified(),
                                "created" to file.lastModified(),
                                "source" to "recording",
                            ),
                        )
                    }
                }
        }
        return items.sortedByDescending { (it["created"] as? Long) ?: 0 }
    }

    private fun pendingDocumentIds(): Set<String> {
        if (Build.VERSION.SDK_INT < 29) return emptySet()
        val pending = mutableSetOf<String>()
        for (collection in
            listOf(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            )) {
            @Suppress("DEPRECATION") val uri = MediaStore.setIncludePending(collection)
            resolver
                .query(
                    uri,
                    arrayOf(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        MediaStore.MediaColumns.DISPLAY_NAME,
                    ),
                    "owner_package_name=? AND is_pending=1",
                    arrayOf(activity.packageName),
                    null,
                )
                ?.use { c ->
                    while (c.moveToNext()) pending.add("primary:${c.getString(0)}${c.getString(1)}")
                }
        }
        return pending
    }

    fun describe(uri: Uri): Map<String, Any?>? {
        if (uri.scheme != "content") return null
        val mime = resolver.getType(uri) ?: return null
        if (!mime.startsWith("video/") && !mime.startsWith("image/")) return null
        val fields =
            mutableMapOf<String, Any?>(
                "id" to uri.toString(),
                "uri" to uri.toString(),
                "mime" to mime,
                "source" to "imported",
                "created" to 0L,
                "modified" to 0L,
            )
        fields["owned"] = actions.owned(uri)
        resolver
            .query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )
            ?.use { c ->
                if (!c.moveToFirst()) return null
                fields["name"] = c.getString(0)
                fields["size"] = c.getLong(1)
            } ?: return null
        resolver.openFileDescriptor(uri, "r")?.use {} ?: return null
        if (mime.startsWith("video/")) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(activity, uri)
                fields["duration"] =
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toLongOrNull()
                fields["width"] =
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                        ?.toIntOrNull()
                fields["height"] =
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                        ?.toIntOrNull()
                val rotation =
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                        ?.toIntOrNull() ?: 0
                if (rotation == 90 || rotation == 270) {
                    val encodedWidth = fields["width"]
                    fields["width"] = fields["height"]
                    fields["height"] = encodedWidth
                }
                fields["bitrate"] =
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                        ?.toIntOrNull()
                fields["hasAudio"] =
                    retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) ==
                        "yes"
                if (Build.VERSION.SDK_INT >= 28) {
                    val frames =
                        retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
                            ?.toDoubleOrNull()
                    val duration = fields["duration"] as? Long
                    if (frames != null && duration != null && duration > 0)
                        fields["fps"] = frames * 1000 / duration
                }
            } finally {
                retriever.release()
            }
        } else {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            val orientation =
                try {
                    resolver.openInputStream(uri)?.use {
                        android.media
                            .ExifInterface(it)
                            .getAttributeInt(
                                android.media.ExifInterface.TAG_ORIENTATION,
                                android.media.ExifInterface.ORIENTATION_NORMAL,
                            )
                    } ?: android.media.ExifInterface.ORIENTATION_NORMAL
                } catch (_: java.io.IOException) {
                    android.media.ExifInterface.ORIENTATION_NORMAL
                }
            val swap = orientation in 5..8
            fields["width"] = if (swap) options.outHeight else options.outWidth
            fields["height"] = if (swap) options.outWidth else options.outHeight
        }
        return fields
    }

    private fun thumbnail(uri: Uri, timeUs: Long? = null): ByteArray {
        checkUri(uri)
        var bitmap: Bitmap? = null
        if (Build.VERSION.SDK_INT >= 29 && timeUs == null) {
            try {
                bitmap = resolver.loadThumbnail(uri, Size(320, 240), null)
            } catch (_: java.io.IOException) {}
        }
        if (bitmap == null) {
            val mime = resolver.getType(uri) ?: throw java.io.FileNotFoundException()
            if (mime.startsWith("video/")) {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(activity, uri)
                    val option =
                        if (timeUs == null) MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                        else MediaMetadataRetriever.OPTION_CLOSEST
                    bitmap =
                        if (Build.VERSION.SDK_INT >= 27)
                            retriever.getScaledFrameAtTime(timeUs ?: 0, option, 320, 240)
                        else retriever.getFrameAtTime(timeUs ?: 0, option)
                } finally {
                    retriever.release()
                }
            } else {
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
                options.inSampleSize = 1
                while (
                    options.outWidth / options.inSampleSize > 640 ||
                        options.outHeight / options.inSampleSize > 640
                ) options.inSampleSize *= 2
                options.inJustDecodeBounds = false
                bitmap =
                    resolver.openInputStream(uri)?.use {
                        BitmapFactory.decodeStream(it, null, options)
                    }
            }
        }
        val decoded = bitmap ?: throw java.io.IOException()
        val ratio = minOf(1.0, 320.0 / decoded.width, 240.0 / decoded.height)
        val scaled =
            Bitmap.createScaledBitmap(
                decoded,
                maxOf(1, (decoded.width * ratio).toInt()),
                maxOf(1, (decoded.height * ratio).toInt()),
                true,
            )
        try {
            return ByteArrayOutputStream().use { out ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 80, out)
                out.toByteArray()
            }
        } finally {
            if (scaled !== decoded) scaled.recycle()
            decoded.recycle()
        }
    }

    private fun directoryBytes(dir: File): Long =
        if (!dir.exists()) 0 else dir.walkTopDown().filter { it.isFile }.sumOf { it.length() }

    private fun storage(): Map<String, Long> =
        mapOf(
            "videos" to list("video", null).sumOf { (it["size"] as? Long) ?: 0 },
            "images" to list("image", null).sumOf { (it["size"] as? Long) ?: 0 },
            "cache" to directoryBytes(activity.cacheDir),
            "trash" to directoryBytes(File(activity.filesDir, "trash")),
            "free" to
                StatFs(
                        activity.getExternalFilesDir(null)?.absolutePath
                            ?: activity.filesDir.absolutePath,
                    )
                    .availableBytes,
        )

    fun dispose() {
        disposed = true
        onCancel(null)
        picker?.error("cancelled", "Folder selection interrupted", null)
        picker = null
        worker.shutdown()
    }
}

/** API24-28 app-file discovery must include the same image formats as MediaStore. */
internal fun legacyMediaMime(extension: String): String =
    when (extension.lowercase()) {
        "mp4" -> "video/mp4"
        "png" -> "image/png"
        "jpg",
        "jpeg" -> "image/jpeg"
        "gif" -> "image/gif"
        else -> ""
    }
