package com.xrecorder.xrecorder.media

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Process
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.AtomicFile
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.UUID
import org.json.JSONObject

/**
 * A move deletes its source only after the destination has been read back and hash-verified, and
 * only with an actual write grant (or app ownership).
 */
class MediaTransfers(private val context: Context) {
    private val resolver = context.contentResolver
    private val journal = AtomicFile(File(context.filesDir, "media_transfer.json"))

    private fun write(value: JSONObject) {
        val out = journal.startWrite()
        try {
            out.write(value.toString().toByteArray())
            journal.finishWrite(out)
        } catch (e: Exception) {
            journal.failWrite(out)
            throw e
        }
    }

    private fun input(uri: Uri): InputStream {
        val virtual =
            if (DocumentsContract.isDocumentUri(context, uri))
                resolver
                    .query(uri, arrayOf(DocumentsContract.Document.COLUMN_FLAGS), null, null, null)
                    ?.use {
                        it.moveToFirst() &&
                            it.getLong(0) and
                                DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT.toLong() != 0L
                    } ?: false
            else false
        return if (virtual) {
            val mime =
                resolver.getStreamTypes(uri, "*/*")?.firstOrNull()
                    ?: error("This virtual document cannot be read as a file")
            resolver.openTypedAssetFileDescriptor(uri, mime, null)!!.createInputStream()
        } else resolver.openInputStream(uri) ?: error("Source is unavailable")
    }

    private fun digest(uri: Uri): String {
        val hash = MessageDigest.getInstance("SHA-256")
        input(uri).use { stream ->
            val buffer = ByteArray(65536)
            while (true) {
                val n = stream.read(buffer)
                if (n < 0) break
                hash.update(buffer, 0, n)
            }
        }
        return hash.digest().joinToString("") { "%02x".format(it) }
    }

    fun copy(source: Uri, tree: Uri, move: Boolean): Map<String, Any?> {
        require(
            source.scheme == "content" &&
                tree.scheme == "content" &&
                DocumentsContract.isTreeUri(tree),
        )
        val parent =
            DocumentsContract.buildDocumentUriUsingTree(
                tree,
                DocumentsContract.getTreeDocumentId(tree),
            )
        require(resolver.persistedUriPermissions.any { it.uri == tree && it.isWritePermission }) {
            "Destination access was disconnected. Choose it again."
        }
        require(
            context.checkUriPermission(
                parent,
                Process.myPid(),
                Process.myUid(),
                android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            ) == PackageManager.PERMISSION_GRANTED,
        ) {
            "Destination write permission was revoked. Choose it again."
        }
        val name =
            resolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            } ?: "media"
        require(name.length <= 240 && name.none { it == '/' || it == '\\' || it.code < 32 })
        val mime = resolver.getType(source) ?: "application/octet-stream"
        val safeName = "3H_${UUID.randomUUID().toString().take(8)}_$name"
        val record =
            JSONObject()
                .put("source", source.toString())
                .put("move", move)
                .put("state", "preparing")
                .put("name", safeName)
        write(record)
        var target: Uri? = null
        var verified = false
        try {
            target =
                DocumentsContract.createDocument(resolver, parent, mime, "$safeName.pending")
                    ?: error("This folder does not allow creating files")
            write(record.put("destination", target.toString()).put("state", "copying"))
            val hash = MessageDigest.getInstance("SHA-256")
            var bytes = 0L
            input(source).use { stream ->
                resolver.openOutputStream(target, "w")!!.use { out ->
                    val buffer = ByteArray(65536)
                    while (true) {
                        val n = stream.read(buffer)
                        if (n < 0) break
                        out.write(buffer, 0, n)
                        hash.update(buffer, 0, n)
                        bytes += n
                    }
                }
            }
            require(bytes > 0) { "The source is empty" }
            val expected = hash.digest().joinToString("") { "%02x".format(it) }
            require(digest(target) == expected && digest(source) == expected) {
                "Verification failed or the source changed. Original preserved."
            }
            verified = true
            write(record.put("state", "verified").put("sha256", expected).put("bytes", bytes))
            var moved = false
            var warning: String? = null
            val published = runCatching {
                DocumentsContract.renameDocument(resolver, target, safeName)
            }
                .getOrNull()
            if (published != null) {
                target = published
                write(record.put("destination", target.toString()).put("state", "published"))
            } else
                warning =
                    "Copy verified and retained with a .pending name. This provider cannot rename it. Original kept."
            if (move && published != null) {
                // No URI string-prefix checks: let Android's provider enforce the
                // selected grant. MediaStore consent remains a separate OS flow.
                try {
                    moved =
                        when {
                            MediaActions(context).owned(source) ->
                                resolver.delete(source, null, null) == 1
                            DocumentsContract.isDocumentUri(context, source) &&
                                context.checkUriPermission(
                                    source,
                                    Process.myPid(),
                                    Process.myUid(),
                                    android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                                ) == PackageManager.PERMISSION_GRANTED ->
                                DocumentsContract.deleteDocument(resolver, source)
                            else -> false
                        }
                    if (!moved)
                        warning =
                            "Copy verified. Original kept because Android did not grant permission to remove it."
                } catch (_: Exception) {
                    warning = "Copy verified. Original kept because it could not be removed."
                }
            }
            write(record.put("state", "completed").put("moved", moved))
            return mapOf(
                "uri" to target.toString(),
                "moved" to moved,
                "verified" to true,
                "bytes" to bytes,
                "warning" to warning,
            )
        } catch (e: Exception) {
            // Only a newly-created, unverified destination can be removed here.
            if (!verified && target != null)
                runCatching { DocumentsContract.deleteDocument(resolver, target) }
            runCatching { write(record.put("state", "failed").put("sourcePreserved", !verified)) }
            throw e
        }
    }

    fun recovery(): Map<String, Any?>? {
        if (!journal.baseFile.exists() && !File(journal.baseFile.path + ".bak").exists())
            return null
        val value = JSONObject(journal.openRead().bufferedReader().use { it.readText() })
        return value.keys().asSequence().associateWith {
            value.get(it).takeUnless { v -> v == JSONObject.NULL }
        }
    }
}
