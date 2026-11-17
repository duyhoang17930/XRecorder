package com.xrecorder.xrecorder.media

import android.app.Activity
import android.app.AlertDialog
import android.net.Uri
import android.text.InputFilter
import android.text.format.Formatter
import android.widget.EditText
import android.widget.Toast
import com.xrecorder.xrecorder.R
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Shared by the Library and player; all I/O uses the existing serial media worker. */
internal class VideoOptions(
    private val activity: Activity,
    private val catalog: MediaCatalog,
    private val edit: (Uri) -> Unit,
    private val changed: (Uri, Boolean) -> Unit = { _, _ -> },
    private val dismissed: () -> Unit = {},
) {
    private var uri = Uri.EMPTY
    private var item: Map<*, *> = emptyMap<Any, Any>()
    private var busy = false

    fun show(value: Uri) {
        if (busy || activity.isFinishing || activity.isDestroyed) return
        uri = value
        busy = true
        call("find", mapOf("id" to uri.toString())) { result ->
            busy = false
            item = result as? Map<*, *> ?: run { dismissed(); return@call }
            val options = videoOptionKeys(item["owned"] == true, (item["duration"] as? Number)?.toLong())
            var selected = false
            AlertDialog.Builder(activity)
                .setTitle(item["name"] as? String)
                .setItems(options.map { label(it) }.toTypedArray()) { _, index ->
                    selected = true
                    when (options[index]) {
                        "rename" -> rename()
                        "edit" -> edit(uri)
                        "info" -> info()
                        "share" -> call("share") { dismissed() }
                        "copy" -> transfer(false)
                        "move" -> confirm(R.string.p2_move_confirm, text(R.string.p2_move_explanation)) { transfer(true) }
                        "trash" -> confirm(R.string.p2_trash_confirm, item["name"] as? String ?: "") {
                            call("trash") { changed(uri, true); dismissed() }
                        }
                    }
                }
                .setOnDismissListener { if (!selected) dismissed() }
                .show()
        }
    }

    private fun label(key: String): String = text(when (key) {
        "rename" -> R.string.p2_rename
        "edit" -> R.string.p2_edit_video
        "info" -> R.string.p2_info
        "share" -> R.string.p2_share
        "copy" -> R.string.p2_copy
        "move" -> R.string.p2_move
        else -> R.string.p2_trash
    })
    private fun text(id: Int) = activity.getString(id)

    private fun info() {
        val size = Formatter.formatFileSize(activity, (item["size"] as? Number)?.toLong() ?: 0)
        val duration = (item["duration"] as? Number)?.toLong() ?: 0
        val seconds = duration / 1000
        val time = String.format(java.util.Locale.getDefault(), "%d:%02d:%02d.%03d", seconds / 3600, seconds / 60 % 60, seconds % 60, duration % 1000)
        val details = listOf(
            "${text(R.string.p2_filename)}: ${item["name"]}",
            "${text(R.string.p2_size)}: $size",
            "${text(R.string.p2_format)}: ${item["mime"]}",
            "${text(R.string.p2_duration)}: $time",
            "${text(R.string.p2_dimensions)}: ${item["width"] ?: "—"} × ${item["height"] ?: "—"}",
        ).joinToString("\n\n")
        AlertDialog.Builder(activity).setTitle(text(R.string.p2_info)).setMessage(details)
            .setPositiveButton(android.R.string.ok, null).setOnDismissListener { dismissed() }.show()
    }

    private fun rename() {
        val input = EditText(activity).apply {
            setSingleLine(true)
            filters = arrayOf(InputFilter.LengthFilter(120))
            hint = text(R.string.p2_filename)
            setText(item["name"] as? String ?: "")
            selectAll()
        }
        val dialog = AlertDialog.Builder(activity).setTitle(text(R.string.p2_rename))
            .setView(input).setNegativeButton(R.string.p2_cancel, null)
            .setPositiveButton(R.string.p2_rename, null)
            .setOnDismissListener { dismissed() }.create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                if (busy) return@setOnClickListener
                val name = input.text.toString().trim()
                if (name.isEmpty() || name == "." || name == ".." || name.any { it == '/' || it == '\\' || it.code < 32 }) {
                    input.error = text(R.string.p2_filename)
                    return@setOnClickListener
                }
                busy = true
                dialog.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = false
                call("rename", mapOf("uri" to uri.toString(), "name" to name), failure = { message ->
                    busy = false
                    dialog.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = true
                    input.error = message
                }) { result ->
                    busy = false
                    val next = Uri.parse(result as String)
                    changed(next, false)
                    dialog.dismiss()
                }
            }
        }
        dialog.show()
    }

    private fun confirm(title: Int, message: String, accepted: () -> Unit) {
        var confirmed = false
        AlertDialog.Builder(activity).setTitle(text(title)).setMessage(message)
            .setNegativeButton(R.string.p2_cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ -> confirmed = true; accepted() }
            .setOnDismissListener { if (!confirmed) dismissed() }.show()
    }

    private fun transfer(move: Boolean) {
        call("selectDestination", null) { destination ->
            if (destination == null) { dismissed(); return@call }
            call("transfer", mapOf("uri" to uri.toString(), "destination" to destination, "move" to move)) { result ->
                val data = result as? Map<*, *>
                // An unverified move must leave playback and the original intact.
                changed(uri, data?.get("moved") == true)
                (data?.get("warning") as? String)?.let {
                    Toast.makeText(activity, it, Toast.LENGTH_LONG).show()
                }
                dismissed()
            }
        }
    }

    private fun call(
        method: String,
        arguments: Any? = mapOf("uri" to uri.toString()),
        failure: ((String) -> Unit)? = null,
        success: (Any?) -> Unit,
    ) {
        catalog.onMethodCall(MethodCall(method, arguments), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (!activity.isFinishing && !activity.isDestroyed) success(result)
            }
            override fun error(code: String, message: String?, details: Any?) {
                if (activity.isFinishing || activity.isDestroyed) return
                val value = message ?: text(R.string.p2_preview_unavailable)
                if (failure != null) failure(value)
                else { busy = false; Toast.makeText(activity, value, Toast.LENGTH_LONG).show(); dismissed() }
            }
            override fun notImplemented() = error("unavailable", null, null)
        })
    }
}

internal fun videoOptionKeys(owned: Boolean, durationMs: Long?): List<String> = buildList {
    if (owned) add("rename")
    if (durationMs != null && durationMs >= 200) add("edit")
    add("info")
    add("share")
    add("copy")
    add("move")
    if (owned) add("trash")
}
