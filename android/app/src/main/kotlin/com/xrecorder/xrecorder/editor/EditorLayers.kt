package com.xrecorder.xrecorder.editor

import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.media3.effect.CanvasOverlay
import kotlin.math.*

/** Resolution-independent editor layers. Output coordinates have a top-left origin. */
class EditorLayers(private val layers: List<Map<*, *>>, private val offsetMs: Long) :
    CanvasOverlay(true) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG)

    init {
        require(layers.size <= 40)
        layers.forEach { l ->
            require(l["kind"] in listOf("text", "sticker", "drawing"))
            require(n(l, "startMs", 0.0) >= 0 && n(l, "endMs", 0.0) > n(l, "startMs", 0.0))
            require(
                n(l, "x", .5) in 0.0..1.0 &&
                    n(l, "y", .5) in 0.0..1.0 &&
                    n(l, "scale", 1.0) in .1..4.0,
            )
            require(n(l, "rotation", 0.0) in -360.0..360.0)
            require(n(l, "fontSize", .07) in 0.02..0.3 && n(l, "strokeWidth", .012) in 0.002..0.08)
            require((l["text"] as? String ?: "").length <= 2000)
            require(((l["points"] as? List<*>)?.size ?: 0) <= 2048)
            (l["points"] as? List<*>)?.forEach { p ->
                if (p != null) {
                    val xy = p as List<*>
                    require(
                        xy.size == 2 &&
                            xy.all {
                                (it as Number).toDouble().isFinite() && it.toDouble() in 0.0..1.0
                            },
                    )
                }
            }
        }
    }

    override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
        canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        val ms = offsetMs + presentationTimeUs / 1000
        for (l in layers) {
            if (ms < n(l, "startMs", 0.0) || ms >= n(l, "endMs", 0.0)) continue
            val width = canvas.width.toFloat()
            val height = canvas.height.toFloat()
            val unit = min(width, height)
            canvas.save()
            canvas.translate((n(l, "x", .5) * width).toFloat(), (n(l, "y", .5) * height).toFloat())
            canvas.rotate(n(l, "rotation", 0.0).toFloat())
            val scale = n(l, "scale", 1.0).toFloat()
            canvas.scale(scale, scale)
            paint.color = (l["color"] as? Number)?.toInt() ?: Color.WHITE
            paint.style = Paint.Style.FILL
            when (l["kind"]) {
                "text" -> {
                    textPaint.color = paint.color
                    textPaint.textSize = (unit * n(l, "fontSize", .07)).toFloat()
                    val text = l["text"] as? String ?: ""
                    val layout =
                        StaticLayout.Builder.obtain(
                                text,
                                0,
                                text.length,
                                textPaint,
                                (width * .8f).toInt().coerceAtLeast(1),
                            )
                            .setAlignment(Layout.Alignment.ALIGN_CENTER)
                            .setIncludePad(true)
                            .build()
                    canvas.translate(-layout.width / 2f, -layout.height / 2f)
                    val background = (l["background"] as? Number)?.toInt() ?: Color.TRANSPARENT
                    if (Color.alpha(background) > 0) {
                        paint.color = background
                        canvas.drawRect(
                            0f,
                            0f,
                            layout.width.toFloat(),
                            layout.height.toFloat(),
                            paint,
                        )
                    }
                    layout.draw(canvas)
                }
                "sticker" -> {
                    val size = unit * .12f
                    val path = Path()
                    when (l["sticker"] as? String ?: "star") {
                        "circle" -> canvas.drawCircle(0f, 0f, size, paint)
                        "heart" -> {
                            path.moveTo(0f, size)
                            path.cubicTo(
                                -size * 2,
                                -size * .3f,
                                -size,
                                -size * 1.6f,
                                0f,
                                -size * .6f,
                            )
                            path.cubicTo(size, -size * 1.6f, size * 2, -size * .3f, 0f, size)
                            canvas.drawPath(path, paint)
                        }
                        else -> {
                            for (i in 0..9) {
                                val angle = -PI / 2 + i * PI / 5
                                val radius = if (i % 2 == 0) size else size * .42f
                                val x = (cos(angle) * radius).toFloat()
                                val y = (sin(angle) * radius).toFloat()
                                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                            }
                            path.close()
                            canvas.drawPath(path, paint)
                        }
                    }
                }
                "drawing" -> {
                    paint.style = Paint.Style.STROKE
                    paint.strokeWidth = (unit * n(l, "strokeWidth", .012)).toFloat()
                    paint.strokeCap = Paint.Cap.ROUND
                    paint.strokeJoin = Paint.Join.ROUND
                    val path = Path()
                    var first = true
                    (l["points"] as? List<*>)?.forEach { point ->
                        if (point == null) first = true
                        else {
                            val xy = point as List<*>
                            val x = ((xy[0] as Number).toFloat() - .5f) * unit
                            val y = ((xy[1] as Number).toFloat() - .5f) * unit
                            if (first) path.moveTo(x, y) else path.lineTo(x, y)
                            first = false
                        }
                    }
                    canvas.drawPath(path, paint)
                }
            }
            canvas.restore()
        }
    }

    private fun n(l: Map<*, *>, key: String, fallback: Double): Double {
        val value = (l[key] as? Number)?.toDouble() ?: fallback
        require(value.isFinite())
        return value
    }
}
