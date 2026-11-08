package com.xrecorder.xrecorder.media

import android.content.*
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.MediaStore
import android.util.AtomicFile
import androidx.core.content.FileProvider
import com.xrecorder.xrecorder.recording.MediaOutput
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID
import org.json.JSONObject

/** Mutations are restricted to owned media. External folder grants remain read-only. */
class MediaActions(private val context: Context) {
    companion object {
        // Only names emitted by this trash writer belong to its cleanup policy.
        // Foreign imports/models in the directory must never become orphans.
        private val managedTrashId =
            Regex("[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}")
    }
    private val resolver = context.contentResolver
    private val directory = File(context.filesDir, "trash").apply { mkdirs() }

    private fun legacy(uri: Uri): File? {
        if (
            uri.authority != "${context.packageName}.files" ||
                uri.pathSegments.size != 2 ||
                uri.pathSegments[0] != "media"
        )
            return null
        val root = File(context.getExternalFilesDir(null), "media").canonicalFile
        val file = File(root, uri.pathSegments[1]).canonicalFile
        return file.takeIf { it.parentFile == root }
    }

    fun owned(uri: Uri): Boolean {
        if (uri.scheme != "content") return false
        if (Build.VERSION.SDK_INT < 29) return legacy(uri)?.isFile == true
        if (uri.authority != "media") return false
        return try {
            resolver
                .query(
                    uri,
                    arrayOf(
                        MediaStore.MediaColumns.OWNER_PACKAGE_NAME,
                        MediaStore.MediaColumns.IS_PENDING,
                    ),
                    null,
                    null,
                    null,
                )
                ?.use {
                    it.moveToFirst() && it.getString(0) == context.packageName && it.getInt(1) == 0
                } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun requireOwned(uri: Uri) {
        require(owned(uri)) {
            "Only app-owned media can be renamed or moved to this app's trash. Use the owning app for external files."
        }
    }

    fun rename(uri: Uri, name: String): String {
        requireOwned(uri)
        require(
            name.isNotBlank() &&
                name.length <= 120 &&
                name.none { it == '/' || it == '\\' || it.code < 32 } &&
                name != "." &&
                name != "..",
        ) {
            "Enter a filename without path separators (up to 120 characters)."
        }
        val old =
            resolver.query(uri, arrayOf("_display_name"), null, null, null)!!.use {
                check(it.moveToFirst())
                it.getString(0)
            }
        val extension = old.substringAfterLast('.', "")
        val desired =
            if (extension.isNotEmpty() && !name.endsWith(".$extension", true)) "$name.$extension"
            else name
        if (Build.VERSION.SDK_INT >= 29) {
            // Reject duplicate visible names rather than silently replacing another item.
            val collection =
                if (resolver.getType(uri)?.startsWith("video/") == true)
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            resolver
                .query(
                    collection,
                    arrayOf("_id"),
                    "owner_package_name=? AND _display_name=?",
                    arrayOf(context.packageName, desired),
                    null,
                )
                ?.use {
                    while (it.moveToNext()) require(
                        ContentUris.withAppendedId(collection, it.getLong(0)) == uri,
                    ) {
                        "Another item already uses this name."
                    }
                }
            check(
                resolver.update(
                    uri,
                    ContentValues().apply { put(MediaStore.MediaColumns.DISPLAY_NAME, desired) },
                    null,
                    null,
                ) == 1,
            )
            return uri.toString()
        }
        val file = legacy(uri)!!
        val target = File(file.parentFile, desired)
        if (file == target) return uri.toString()
        require(!target.exists()) { "Another item already uses this name." }
        check(file.renameTo(target))
        return FileProvider.getUriForFile(context, "${context.packageName}.files", target)
            .toString()
    }

    private fun metadata(id: String): File {
        require(id.matches(Regex("[a-f0-9-]{36}")))
        return File(directory, "$id.json")
    }

    private fun payload(id: String) = File(directory, "$id.bin")

    private fun write(id: String, data: JSONObject) {
        val atomic = AtomicFile(metadata(id))
        val stream = atomic.startWrite()
        try {
            stream.write(data.toString().toByteArray(Charsets.UTF_8))
            atomic.finishWrite(stream)
        } catch (e: Exception) {
            atomic.failWrite(stream)
            throw e
        }
    }

    private fun read(id: String) =
        JSONObject(
            AtomicFile(metadata(id)).openRead().use { it.readBytes().toString(Charsets.UTF_8) },
        )

    private fun hash(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun map(json: JSONObject): Map<String, Any?> =
        json.keys().asSequence().associateWith { key ->
            val value = json.get(key)
            when (value) {
                JSONObject.NULL -> null
                is JSONObject -> map(value)
                else -> value
            }
        }

    fun trash(uri: Uri, original: Map<String, Any?>): Map<String, Any?> {
        requireOwned(uri)
        val size = (original["size"] as? Number)?.toLong() ?: 0
        require(
            size > 0 && StatFs(directory.absolutePath).availableBytes > size + 64L * 1024 * 1024,
        ) {
            "Not enough private storage for a safe trash copy."
        }
        val id = UUID.randomUUID().toString()
        val part = File(directory, "$id.part")
        val file = payload(id)
        var journaled = false
        try {
            resolver.openInputStream(uri)!!.use { input ->
                FileOutputStream(part).use { out ->
                    check(input.copyTo(out) == size)
                    out.fd.sync()
                }
            }
            check(part.renameTo(file))
            val now = System.currentTimeMillis()
            val data =
                JSONObject()
                    .put("id", id)
                    .put("originalMetadata", JSONObject(original))
                    .put("deletedAt", now)
                    .put("expiresAt", now + 86400000L)
                    .put("sha256", hash(file))
            write(id, data)
            journaled = true
            val removed =
                if (Build.VERSION.SDK_INT >= 29) resolver.delete(uri, null, null) == 1
                else legacy(uri)!!.delete()
            check(removed) { "Original could not be removed. A recovery copy remains in trash." }
            return map(data)
        } catch (e: Exception) {
            if (!journaled) file.delete()
            throw e
        } finally {
            part.delete()
        }
    }

    fun listTrash(): List<Map<String, Any?>> {
        val stale = System.currentTimeMillis() - 86400000L
        directory
            .listFiles()
            ?.filter { file ->
                managedTrashId.matches(file.nameWithoutExtension) &&
                    file.lastModified() < stale &&
                    (file.extension == "part" ||
                        (file.extension == "bin" &&
                            listOf(".json", ".json.bak", ".json.new").none {
                                File(directory, file.nameWithoutExtension + it).exists()
                            }))
            }
            ?.forEach { it.delete() }
        val entries = mutableListOf<Map<String, Any?>>()
        directory
            .listFiles()
            ?.filter { it.name.endsWith(".json") || it.name.endsWith(".json.bak") }
            ?.map { it.name.removeSuffix(".bak").removeSuffix(".json") }
            ?.filter { managedTrashId.matches(it) }
            ?.distinct()
            ?.forEach { id ->
                try {
                    val data = read(id)
                    if (!payload(id).isFile) entries.add(mapOf("id" to id, "unreadable" to true))
                    else if (data.getLong("expiresAt") <= System.currentTimeMillis())
                        permanentlyDelete(id)
                    else entries.add(map(data))
                } catch (_: Exception) {
                    entries.add(mapOf("id" to id, "unreadable" to true))
                }
            }
        return entries.sortedByDescending { it["deletedAt"] as? Long ?: 0L }
    }

    fun restore(id: String): String {
        val data = read(id)
        val file = payload(id)
        data
            .optString("restoredUri")
            .takeIf { it.isNotEmpty() }
            ?.let { saved ->
                val exists = runCatching {
                    resolver.openFileDescriptor(Uri.parse(saved), "r")?.use { true } ?: false
                }
                    .getOrDefault(false)
                if (exists) return saved
            }
        require(hash(file) == data.getString("sha256")) {
            "The trash copy is damaged. It has been preserved for recovery."
        }
        val original = data.getJSONObject("originalMetadata")
        val name = original.getString("name")
        val output =
            MediaOutput(
                context,
                "Restored_${System.currentTimeMillis()}_$name",
                original.getString("mime"),
            )
        var committed: String? = null
        try {
            val fd = output.open()
            android.os.ParcelFileDescriptor.AutoCloseOutputStream(
                    android.os.ParcelFileDescriptor.dup(fd.fileDescriptor),
                )
                .use { out -> file.inputStream().use { it.copyTo(out) } }
            val uri = output.commit()
            committed = uri.toString()
            // Keep the backup until publishing is confirmed. A crash can leave a duplicate, never
            // loss.
            // Backup cleanup must never abort an already-published destination.
            runCatching {
                write(id, data.put("restoredUri", uri.toString()))
                permanentlyDelete(id)
            }
            return uri.toString()
        } catch (e: Exception) {
            if (committed == null) output.abort()
            throw e
        }
    }

    fun permanentlyDelete(id: String) {
        metadata(id) // validates opaque ID before touching a path
        val data = payload(id)
        if (data.exists()) check(data.delete()) { "Could not remove trash data." }
        val file = metadata(id)
        if (file.exists()) check(file.delete()) { "Could not remove trash metadata." }
    }
}
