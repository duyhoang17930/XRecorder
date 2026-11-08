package com.xrecorder.xrecorder.editor

import android.graphics.*
import android.text.*
import androidx.media3.effect.CanvasOverlay
import kotlin.math.*

/** Word wrapping and safe-frame fitting are shared by preview and burn-in. */
class SubtitleOverlay(
    private val cues: List<Map<*, *>>,
    private val offsetMs: Long,
    options: Map<*, *>,
) : CanvasOverlay(true) {
    private val color =
        when (options["subtitleColor"] ?: "white") {
            "white" -> Color.WHITE
            "yellow" -> Color.YELLOW
            else -> error("Unsupported subtitle color")
        }
    private val background =
        when (options["subtitleBackground"] ?: "dark") {
            "dark" -> 0xCC000000.toInt()
            "none" -> Color.TRANSPARENT
            else -> error("Unsupported subtitle background")
        }
    private val fraction =
        when (options["subtitleSize"] ?: "normal") {
            "small" -> .045f
            "normal" -> .06f
            "large" -> .08f
            else -> error("Unsupported subtitle size")
        }
    private val top =
        when (options["subtitlePosition"] ?: "bottom") {
            "bottom" -> false
            "top" -> true
            else -> error("Unsupported subtitle position")
        }
    private val paint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = this@SubtitleOverlay.color
            setShadowLayer(2f, 0f, 1f, Color.BLACK)
        }
    private val fill = Paint().apply { color = background }
    private var previous: String? = null
    private var width = 0
    private var height = 0
    private var layout: StaticLayout? = null

    override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
        canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        val ms = offsetMs + presentationTimeUs / 1000
        val cue = cues.firstOrNull {
            ms >= (it["startMs"] as Number).toLong() && ms < (it["endMs"] as Number).toLong()
        }
        val text = cue?.get("text") as? String ?: return
        val available = (canvas.width * .86f).roundToInt().coerceAtLeast(1)
        if (previous != text || width != available || height != canvas.height) {
            previous = text
            width = available
            height = canvas.height
            paint.textSize = min(canvas.width, canvas.height) * fraction
            fun build() =
                StaticLayout.Builder.obtain(text, 0, text.length, paint, available)
                    .setAlignment(Layout.Alignment.ALIGN_CENTER)
                    .setIncludePad(true)
                    .build()
            var next = build()
            while (next.height > canvas.height * .32f && paint.textSize > 2f) {
                paint.textSize *= .9f
                next = build()
            }
            layout = next
        }
        val current = layout ?: return
        val x = (canvas.width - current.width) / 2f
        val y = if (top) canvas.height * .06f else canvas.height * .94f - current.height
        canvas.save()
        canvas.translate(x, y)
        if (background != Color.TRANSPARENT)
            canvas.drawRoundRect(-4f, -2f, current.width + 4f, current.height + 2f, 4f, 4f, fill)
        current.draw(canvas)
        canvas.restore()
    }
}
