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
    /** The app's current theme; the player always passes true. */
    private val dark: Boolean = true,
) {
    private val palette = StudioPalette.of(dark)
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
            val sheet = StudioSheet(activity, palette).header(item["name"] as? String ?: "", summary())
            for (key in options) {
                sheet.row(StudioSheetRow(icon(key), label(key), destructive = key == "trash") {
                    when (key) {
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
                })
            }
            // A row click detaches the sheet's dismiss listener, so only a
            // plain dismiss (back, outside tap) reports back here.
            sheet.show(dismissed)
        }
    }

    private fun summary(): String {
        val size = Formatter.formatShortFileSize(activity, (item["size"] as? Number)?.toLong() ?: 0)
        val duration = (item["duration"] as? Number)?.toLong() ?: return size
        val seconds = duration / 1000
        val time = if (seconds >= 3600)
            String.format(java.util.Locale.getDefault(), "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        else String.format(java.util.Locale.getDefault(), "%02d:%02d", seconds / 60, seconds % 60)
        return "$size · $time"
    }

    private fun icon(key: String): Int = when (key) {
        "rename" -> R.drawable.ic_lucide_pencil
        "edit" -> R.drawable.ic_lucide_scissors
        "info" -> R.drawable.ic_lucide_info
        "share" -> R.drawable.ic_lucide_share
        "copy" -> R.drawable.ic_lucide_folder
        "move" -> R.drawable.ic_lucide_folder_move
        else -> R.drawable.ic_lucide_trash_2
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
        StudioSheet(activity, palette).header(text(R.string.p2_info), null)
            .detail(text(R.string.p2_filename), item["name"] as? String ?: "—")
            .detail(text(R.string.p2_size), size)
            .detail(text(R.string.p2_format), item["mime"] as? String ?: "—")
            .detail(text(R.string.p2_duration), time)
            .detail(text(R.string.p2_dimensions), "${item["width"] ?: "—"} × ${item["height"] ?: "—"}")
            .show(dismissed)
    }

    private fun rename() {
        val input = EditText(activity).apply {
            setTextColor(palette.text)
            setHintTextColor(palette.muted)
            typeface = StudioType.of(activity, 500)
            backgroundTintList = android.content.res.ColorStateList.valueOf(palette.primary)
            setSingleLine(true)
            filters = arrayOf(InputFilter.LengthFilter(120))
            hint = text(R.string.p2_filename)
            setText(item["name"] as? String ?: "")
            selectAll()
        }
        val frame = android.widget.FrameLayout(activity).apply {
            setPadding(activity.dp(24), activity.dp(8), activity.dp(24), 0)
            addView(input)
        }
        val dialog = AlertDialog.Builder(activity, studioDialogTheme(dark)).setTitle(text(R.string.p2_rename))
            .setView(frame).setNegativeButton(R.string.p2_cancel, null)
            .setPositiveButton(R.string.p2_rename, null)
            .setOnDismissListener { dismissed() }.create()
        styleStudio(dialog, palette)
        dialog.onShown {
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
        AlertDialog.Builder(activity, studioDialogTheme(dark)).setTitle(text(title)).setMessage(message)
            .setNegativeButton(R.string.p2_cancel, null)
            .setPositiveButton(android.R.string.ok) { _, _ -> confirmed = true; accepted() }
            .setOnDismissListener { if (!confirmed) dismissed() }.showStudio(palette)
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
