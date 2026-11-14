package com.xrecorder.xrecorder.recording

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager

/**
 * Transparent full-screen overlay for drawing and screen annotation during active capture (F15).
 * Owned strictly by CaptureService, isolated from underlying apps when disabled via FLAG_NOT_TOUCHABLE.
 */
internal class DrawingOverlay(
    private val context: Context,
    val session: DrawingStrokeEngine.Session = DrawingStrokeEngine.Session(),
    private val changed: () -> Unit = {}
) {
    private val windows = context.getSystemService(WindowManager::class.java)

    private val strokePaint = Paint().apply {
        isAntiAlias = true
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private var viewWidth: Int = 0
    private var viewHeight: Int = 0
    private var attached = false
    private var closed = false

    @Suppress("DEPRECATION")
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
        DrawingStrokeEngine.resolveWindowFlags(false),
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        title = "3HRecorder Drawing Overlay"
        // Android 12+ blocks pass-through touches under opaque overlay windows.
        // Keep existing ink visible at the platform's permitted obscuring opacity.
        alpha = if (Build.VERSION.SDK_INT >= 31)
            context.getSystemService(android.hardware.input.InputManager::class.java).maximumObscuringOpacityForTouch
            else 1f
    }

    private val canvasView = @SuppressLint("ViewConstructor") object : View(context) {
        init {
            setBackgroundColor(0) // Completely transparent background
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (oldw > 0 && oldh > 0 && (w != oldw || h != oldh)) {
                session.repositionOrRotate(oldw, oldh, w, h)
            }
            viewWidth = w
            viewHeight = h
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)

            // Draw all completed strokes
            for (stroke in session.strokes) {
                if (stroke.points.isEmpty()) continue
                drawStrokePoints(canvas, stroke.points, stroke.color, stroke.width)
            }

            // Draw active in-progress stroke
            val active = session.activeStrokePoints
            if (active.isNotEmpty()) {
                drawStrokePoints(canvas, active, session.currentColor, session.currentWidth)
            }
        }

        private fun drawStrokePoints(canvas: Canvas, points: List<DrawingStrokeEngine.Point>, color: Int, width: Float) {
            strokePaint.color = color
            strokePaint.strokeWidth = width

            if (points.size == 1) {
                val dot = points[0]
                canvas.drawCircle(dot.x, dot.y, width / 2f, strokePaint.apply { style = Paint.Style.FILL })
                strokePaint.style = Paint.Style.STROKE
                return
            }

            val path = Path()
            val first = points[0]
            path.moveTo(first.x, first.y)
            for (i in 1 until points.size) {
                val p = points[i]
                path.lineTo(p.x, p.y)
            }
            canvas.drawPath(path, strokePaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (!session.isDrawingMode) return false

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    session.startStroke(event.x, event.y)
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val historySize = event.historySize
                    for (h in 0 until historySize) {
                        session.addPoint(event.getHistoricalX(h), event.getHistoricalY(h))
                    }
                    session.addPoint(event.x, event.y)
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    session.endStroke()
                    invalidate()
                    changed()
                    return true
                }
                MotionEvent.ACTION_CANCEL -> {
                    session.endStroke()
                    invalidate()
                    changed()
                    return true
                }
                else -> return false
            }
        }
    }

    init {
        ensureAttached()
    }

    private fun ensureAttached() {
        if (closed || attached) return
        if (!Settings.canDrawOverlays(context)) return
        try {
            windows.addView(canvasView, params)
            attached = true
        } catch (_: RuntimeException) {
            closed = true
        }
    }

    fun setDrawingEnabled(enabled: Boolean): Boolean {
        if (closed) return false
        ensureAttached()
        if (!attached) return false

        session.setDrawingMode(enabled)
        params.flags = DrawingStrokeEngine.resolveWindowFlags(enabled)
        params.alpha = if (enabled || Build.VERSION.SDK_INT < 31) 1f else
            context.getSystemService(android.hardware.input.InputManager::class.java).maximumObscuringOpacityForTouch
        try {
            windows.updateViewLayout(canvasView, params)
            canvasView.invalidate()
            return true
        } catch (_: RuntimeException) {
            close()
            return false
        }
    }

    fun undo(): Boolean {
        if (closed) return false
        val changed = session.undo()
        if (changed) {
            canvasView.invalidate()
            this.changed()
        }
        return changed
    }

    fun clear(): Int {
        if (closed) return 0
        val count = session.clear()
        canvasView.invalidate()
        changed()
        return count
    }

    fun setStyle(color: Int? = null, width: Float? = null) {
        session.setStyle(color, width)
    }

    fun onConfigurationChanged() {
        if (closed || !attached) return
        val (width, height) = availableSize()
        if (viewWidth > 0 && viewHeight > 0 && (width != viewWidth || height != viewHeight)) {
            session.repositionOrRotate(viewWidth, viewHeight, width, height)
            viewWidth = width
            viewHeight = height
            canvasView.invalidate()
        }
    }

    fun close() {
        if (attached) {
            try {
                windows.removeViewImmediate(canvasView)
            } catch (_: RuntimeException) { }
        }
        attached = false
        closed = true
        session.clear()
    }

    private fun availableSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
            )
            return (metrics.bounds.width() - insets.left - insets.right) to
                (metrics.bounds.height() - insets.top - insets.bottom)
        }
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION") windows.defaultDisplay.getMetrics(metrics)
        return metrics.widthPixels to metrics.heightPixels
    }
}
