package com.xrecorder.xrecorder.recording

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import com.xrecorder.xrecorder.R
import com.xrecorder.xrecorder.media.StudioType

/**
 * Dropdown for the floating recording controls, drawn in the same dark,
 * rounded style as the controls themselves instead of the platform's
 * default PopupMenu. Groups options under small headers and ticks the
 * current choice, so "None" under "Color filter" reads as a filter choice.
 */
internal class FloatingMenu(private val context: Context) {
    data class Item(
        val label: String,
        val selected: Boolean = false,
        val icon: Int? = null,
        val swatch: Int? = null,
        val destructive: Boolean = false,
        val action: () -> Unit,
    )
    data class Section(val title: String?, val items: List<Item>)

    private val surface = Color.rgb(24, 24, 28)
    private val border = Color.argb(72, 255, 255, 255)
    private val text = Color.rgb(245, 247, 252)
    private val muted = Color.rgb(166, 176, 195)
    private val accent = Color.rgb(255, 120, 71)
    private val danger = Color.rgb(255, 132, 144)

    fun show(anchor: View, sections: List<Section>): PopupWindow {
        val list = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(6), dp(6), dp(6))
        }
        val popup = PopupWindow(context)
        sections.forEachIndexed { index, section ->
            if (index > 0) list.addView(View(context).apply { setBackgroundColor(Color.argb(28, 255, 255, 255)) },
                LinearLayout.LayoutParams(-1, dp(1)).apply { setMargins(dp(10), dp(6), dp(10), dp(6)) })
            section.title?.let { title ->
                list.addView(label(title.uppercase(), 11f, muted, 600).apply {
                    letterSpacing = .08f
                    setPadding(dp(12), dp(6), dp(12), dp(4))
                })
            }
            section.items.forEach { item -> list.addView(row(item) { popup.dismiss(); item.action() }) }
        }
        popup.apply {
            contentView = ScrollView(context).apply {
                isVerticalScrollBarEnabled = false
                addView(list)
                background = GradientDrawable().apply {
                    setColor(surface); cornerRadius = dp(20).toFloat(); setStroke(dp(1), border)
                }
                clipToOutline = true
            }
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            width = dp(232)
            height = ViewGroup.LayoutParams.WRAP_CONTENT
            elevation = dp(12).toFloat()
            isFocusable = true
            isOutsideTouchable = true
        }
        popup.showAsDropDown(anchor, 0, dp(6))
        return popup
    }

    private fun row(item: Item, onClick: () -> Unit) = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        minimumHeight = dp(44)
        setPadding(dp(12), dp(4), dp(12), dp(4))
        isClickable = true
        isSelected = item.selected
        contentDescription = item.label
        val fill = GradientDrawable().apply {
            cornerRadius = dp(12).toFloat()
            setColor(if (item.selected) Color.argb(36, 255, 120, 71) else Color.TRANSPARENT)
        }
        val mask = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(Color.WHITE) }
        background = RippleDrawable(ColorStateList.valueOf(Color.argb(40, 255, 255, 255)), fill, mask)
        setOnClickListener { onClick() }

        val ink = when { item.destructive -> danger; item.selected -> accent; else -> text }
        when {
            item.swatch != null -> addView(View(context).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL; setColor(item.swatch); setStroke(dp(1), border)
                }
            }, LinearLayout.LayoutParams(dp(16), dp(16)).apply { marginEnd = dp(12) })
            item.icon != null -> addView(ImageView(context).apply {
                setImageResource(item.icon); setColorFilter(ink)
            }, LinearLayout.LayoutParams(dp(18), dp(18)).apply { marginEnd = dp(12) })
        }
        addView(label(item.label, 14f, ink, if (item.selected) 600 else 500),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        if (item.selected) addView(ImageView(context).apply {
            setImageResource(R.drawable.ic_lucide_check); setColorFilter(accent)
        }, LinearLayout.LayoutParams(dp(18), dp(18)).apply { marginStart = dp(8) })
    }

    private fun label(value: String, sizeSp: Float, color: Int, weight: Int) = TextView(context).apply {
        text = value
        setTextColor(color)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        typeface = StudioType.of(context, weight)
        maxLines = 2
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density + .5f).toInt()
}
