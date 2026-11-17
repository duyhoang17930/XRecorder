package com.xrecorder.xrecorder.media

import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Mirrors lib/core/ui/theme/colors.dart so native surfaces match the Flutter UI. */
internal data class StudioPalette(
    val surface: Int,
    val elevated: Int,
    val primary: Int,
    val primaryForeground: Int,
    val warning: Int,
    val text: Int,
    val muted: Int,
    val border: Int,
    val dark: Boolean,
) {
    companion object {
        val dark = StudioPalette(
            surface = 0xFF141A26.toInt(), elevated = 0xFF242D3E.toInt(),
            primary = 0xFFFF7948.toInt(), primaryForeground = 0xFF391300.toInt(),
            warning = 0xFFFF8490.toInt(), text = 0xFFF5F7FC.toInt(),
            muted = 0xFFA6B0C3.toInt(), border = 0xFF303B50.toInt(), dark = true,
        )
        val light = StudioPalette(
            surface = 0xFFFFFFFF.toInt(), elevated = 0xFFE7ECF5.toInt(),
            primary = 0xFFA83A12.toInt(), primaryForeground = 0xFFFFFFFF.toInt(),
            warning = 0xFFB3263A.toInt(), text = 0xFF182033.toInt(),
            muted = 0xFF526078.toInt(), border = 0xFFD5DDEA.toInt(), dark = false,
        )
        fun of(dark: Boolean) = if (dark) this.dark else light
    }
}

/** The app's single UI family, read from the Flutter asset bundle. */
internal object StudioType {
    private var base: Typeface? = null
    private fun base(context: Context): Typeface = base ?: try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Manrope.ttf")
    } catch (_: Exception) {
        Typeface.DEFAULT
    }.also { base = it }

    fun of(context: Context, weight: Int): Typeface {
        val font = base(context)
        return if (Build.VERSION.SDK_INT >= 28) Typeface.create(font, weight, false)
        else Typeface.create(font, if (weight >= 600) Typeface.BOLD else Typeface.NORMAL)
    }
}

internal fun Context.dp(value: Int): Int =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

internal fun withAlpha(color: Int, alpha: Float) =
    Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

internal fun Context.studioText(
    value: CharSequence,
    sizeSp: Float,
    color: Int,
    weight: Int = 400,
    maxLines: Int = Int.MAX_VALUE,
) = TextView(this).apply {
    text = value
    setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
    setTextColor(color)
    typeface = StudioType.of(context, weight)
    if (maxLines != Int.MAX_VALUE) {
        this.maxLines = maxLines
        ellipsize = TextUtils.TruncateAt.END
    }
}

/** One row of a [StudioSheet]: icon tile, label and an optional destructive tint. */
internal data class StudioSheetRow(
    val icon: Int,
    val label: String,
    val destructive: Boolean = false,
    val onClick: () -> Unit,
)

/**
 * A bottom sheet in the app's style: rounded top, drag handle, header and
 * icon-tile rows. Used by the Library "…" button and the player menu so both
 * show the same actions with the same look.
 */
internal class StudioSheet(
    private val activity: Activity,
    private val palette: StudioPalette,
) {
    private val dialog = Dialog(activity)
    private val body = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }

    fun header(title: String, subtitle: String?): StudioSheet {
        body.addView(activity.studioText(title, 16f, palette.text, 700, maxLines = 2).apply {
            setPadding(activity.dp(24), 0, activity.dp(24), 0)
        })
        if (!subtitle.isNullOrEmpty()) {
            body.addView(activity.studioText(subtitle, 13f, palette.muted, 500, maxLines = 1).apply {
                setPadding(activity.dp(24), activity.dp(2), activity.dp(24), 0)
            })
        }
        body.addView(View(activity).apply { setBackgroundColor(palette.border) },
            LinearLayout.LayoutParams(-1, 1).apply {
                setMargins(activity.dp(24), activity.dp(16), activity.dp(24), activity.dp(8))
            })
        return this
    }

    fun row(row: StudioSheetRow): StudioSheet {
        val ink = if (row.destructive) palette.warning else palette.primary
        val label = if (row.destructive) palette.warning else palette.text
        val item = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = activity.dp(56)
            setPadding(activity.dp(20), activity.dp(6), activity.dp(20), activity.dp(6))
            isClickable = true
            isFocusable = true
            contentDescription = row.label
            background = RippleDrawable(ColorStateList.valueOf(withAlpha(ink, .16f)), null,
                ColorDrawable(Color.WHITE))
            setOnClickListener {
                dialog.setOnDismissListener(null)
                dialog.dismiss()
                row.onClick()
            }
        }
        val tile = FrameLayout(activity).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(withAlpha(ink, if (palette.dark) .16f else .10f))
            }
            addView(ImageView(activity).apply {
                setImageResource(row.icon)
                imageTintList = ColorStateList.valueOf(ink)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, FrameLayout.LayoutParams(activity.dp(20), activity.dp(20), Gravity.CENTER))
        }
        item.addView(tile, LinearLayout.LayoutParams(activity.dp(40), activity.dp(40)))
        item.addView(activity.studioText(row.label, 15f, label, 600, maxLines = 2).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(0, -2, 1f).apply { marginStart = activity.dp(14) })
        body.addView(item, LinearLayout.LayoutParams(-1, -2))
        return this
    }

    /** Label/value pairs, e.g. media details. */
    fun detail(label: String, value: String): StudioSheet {
        val item = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(activity.dp(24), activity.dp(8), activity.dp(24), activity.dp(8))
        }
        item.addView(activity.studioText(label, 12f, palette.muted, 600))
        item.addView(activity.studioText(value, 15f, palette.text, 500).apply { setTextIsSelectable(true) })
        body.addView(item)
        return this
    }

    fun show(dismissed: () -> Unit) {
        val sheet = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(palette.surface)
                val r = activity.dp(28).toFloat()
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            }
            clipToOutline = true
        }
        // The handle is a real grip: drag the sheet down to dismiss it.
        val grip = FrameLayout(activity).apply {
            addView(View(activity).apply {
                background = GradientDrawable().apply {
                    cornerRadius = activity.dp(2).toFloat()
                    setColor(withAlpha(palette.muted, .5f))
                }
            }, FrameLayout.LayoutParams(activity.dp(36), activity.dp(4), Gravity.CENTER))
            var startY = 0f
            setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    android.view.MotionEvent.ACTION_DOWN -> { startY = event.rawY; true }
                    android.view.MotionEvent.ACTION_MOVE -> {
                        sheet.translationY = (event.rawY - startY).coerceAtLeast(0f); true
                    }
                    android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                        if (sheet.translationY > sheet.height * .25f) {
                            sheet.animate().translationY(sheet.height.toFloat()).setDuration(150)
                                .withEndAction { dialog.dismiss() }.start()
                        } else {
                            sheet.animate().translationY(0f).setDuration(150).start()
                        }
                        true
                    }
                    else -> false
                }
            }
        }
        sheet.addView(grip, LinearLayout.LayoutParams(-1, activity.dp(32)).apply {
            setMargins(0, activity.dp(4), 0, activity.dp(8))
        })
        sheet.addView(ScrollView(activity).apply {
            isVerticalScrollBarEnabled = false
            addView(body)
        }, LinearLayout.LayoutParams(-1, -2))
        val bottomPad = activity.dp(16)
        sheet.setPadding(0, 0, 0, bottomPad)
        sheet.setOnApplyWindowInsetsListener { view, insets ->
            @Suppress("DEPRECATION")
            val nav = if (Build.VERSION.SDK_INT >= 30)
                insets.getInsets(WindowInsets.Type.navigationBars()).bottom
            else insets.systemWindowInsetBottom
            view.setPadding(0, 0, 0, bottomPad + nav)
            insets
        }
        dialog.requestWindowFeature(android.view.Window.FEATURE_NO_TITLE)
        dialog.setContentView(sheet)
        dialog.setCanceledOnTouchOutside(true)
        dialog.setOnDismissListener { dismissed() }
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setGravity(Gravity.BOTTOM)
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setDimAmount(.6f)
            addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            setWindowAnimations(android.R.style.Animation_InputMethod)
            // Draw under the navigation bar; the sheet pads itself.
            if (Build.VERSION.SDK_INT >= 30) setDecorFitsSystemWindows(false)
            navigationBarColor = palette.surface
            // Cap the height so long menus scroll instead of covering the screen.
            decorView.post {
                val max = (activity.resources.displayMetrics.heightPixels * .85f).toInt()
                if (decorView.height > max) setLayout(ViewGroup.LayoutParams.MATCH_PARENT, max)
            }
        }
        dialog.show()
    }
}

/** Platform alert dialogs restyled to the same surface, radius, font and accent. */
internal fun AlertDialog.Builder.showStudio(palette: StudioPalette): AlertDialog =
    create().also { styleStudio(it, palette); it.show() }

internal fun styleStudio(dialog: AlertDialog, palette: StudioPalette) {
    val context = dialog.context
    dialog.setOnShowListener(chain(dialog) {
        dialog.window?.setBackgroundDrawable(GradientDrawable().apply {
            setColor(palette.surface)
            cornerRadius = context.dp(28).toFloat()
        })
        val font = StudioType.of(context, 700)
        for (which in listOf(AlertDialog.BUTTON_POSITIVE, AlertDialog.BUTTON_NEGATIVE, AlertDialog.BUTTON_NEUTRAL)) {
            dialog.getButton(which)?.apply {
                setTextColor(palette.primary)
                typeface = font
                isAllCaps = false
            }
        }
        dialog.findViewById<TextView>(android.R.id.message)?.apply {
            setTextColor(palette.muted)
            typeface = StudioType.of(context, 400)
        }
        val titleId = context.resources.getIdentifier("alertTitle", "id", "android")
        if (titleId != 0) dialog.findViewById<TextView>(titleId)?.apply {
            setTextColor(palette.text)
            typeface = StudioType.of(context, 700)
        }
    })
}

/** Keeps an OnShowListener a caller set before or after styling. */
private val showListeners = java.util.WeakHashMap<AlertDialog, android.content.DialogInterface.OnShowListener>()

private fun chain(dialog: AlertDialog, style: () -> Unit) =
    android.content.DialogInterface.OnShowListener { d ->
        style()
        showListeners[dialog]?.onShow(d)
    }

/** Use instead of setOnShowListener on a dialog styled with [styleStudio]. */
internal fun AlertDialog.onShown(listener: android.content.DialogInterface.OnShowListener) {
    showListeners[this] = listener
}

internal fun studioDialogTheme(dark: Boolean) =
    if (dark) android.R.style.Theme_Material_Dialog_Alert else android.R.style.Theme_Material_Light_Dialog_Alert
