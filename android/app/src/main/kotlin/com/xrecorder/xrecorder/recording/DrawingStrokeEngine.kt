package com.xrecorder.xrecorder.recording

import kotlin.math.hypot

/**
 * Pure, platform-independent stroke model and engine for realtime screen annotation (F15).
 * 100% JVM unit testable without Android mocks.
 */
internal object DrawingStrokeEngine {
    const val DEFAULT_COLOR = 0xFFFF7847.toInt() // Accent #FF7847
    const val DEFAULT_STROKE_WIDTH = 8.0f
    const val MIN_STROKE_WIDTH = 2.0f
    const val MAX_STROKE_WIDTH = 64.0f

    const val FLAG_NOT_FOCUSABLE = 0x00000008
    const val FLAG_NOT_TOUCHABLE = 0x00000010
    const val FLAG_NOT_TOUCH_MODAL = 0x00000020

    data class Point(val x: Float, val y: Float)

    data class Stroke(
        val points: List<Point>,
        val color: Int,
        val width: Float,
        val isEraser: Boolean = false
    )

    data class State(
        val isDrawingMode: Boolean,
        val strokeCount: Int,
        val canUndo: Boolean,
        val currentColor: Int,
        val currentWidth: Float
    )

    fun clampWidth(width: Float?): Float {
        if (width == null || width.isNaN() || width <= 0f) return DEFAULT_STROKE_WIDTH
        return width.coerceIn(MIN_STROKE_WIDTH, MAX_STROKE_WIDTH)
    }

    fun clampColor(color: Int?): Int {
        if (color == null) return DEFAULT_COLOR
        // Ensure alpha is fully opaque if caller passed an RGB color with 0 alpha
        val alpha = (color ushr 24) and 0xFF
        return if (alpha == 0) {
            0xFF000000.toInt() or (color and 0x00FFFFFF)
        } else {
            color
        }
    }

    fun resolveWindowFlags(isDrawingMode: Boolean): Int {
        return if (isDrawingMode) {
            FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL
        } else {
            FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCHABLE
        }
    }

    fun normalizePoint(point: Point, width: Int, height: Int): Point {
        if (width <= 0 || height <= 0) return Point(0f, 0f)
        val nx = (point.x / width).coerceIn(0f, 1f)
        val ny = (point.y / height).coerceIn(0f, 1f)
        return Point(nx, ny)
    }

    fun denormalizePoint(point: Point, width: Int, height: Int): Point {
        if (width <= 0 || height <= 0) return Point(0f, 0f)
        val clampedX = if (point.x.isNaN()) 0f else point.x.coerceIn(0f, 1f)
        val clampedY = if (point.y.isNaN()) 0f else point.y.coerceIn(0f, 1f)
        return Point(clampedX * width, clampedY * height)
    }

    fun transformPointsOnRotation(
        points: List<Point>,
        oldWidth: Int,
        oldHeight: Int,
        newWidth: Int,
        newHeight: Int
    ): List<Point> {
        if (oldWidth <= 0 || oldHeight <= 0 || newWidth <= 0 || newHeight <= 0) return points
        return points.map { p ->
            val norm = normalizePoint(p, oldWidth, oldHeight)
            denormalizePoint(norm, newWidth, newHeight)
        }
    }

    fun transformStrokesOnRotation(
        strokes: List<Stroke>,
        oldWidth: Int,
        oldHeight: Int,
        newWidth: Int,
        newHeight: Int
    ): List<Stroke> {
        if (oldWidth <= 0 || oldHeight <= 0 || newWidth <= 0 || newHeight <= 0) return strokes
        return strokes.map { stroke ->
            stroke.copy(
                points = transformPointsOnRotation(stroke.points, oldWidth, oldHeight, newWidth, newHeight)
            )
        }
    }

    fun canAcceptAction(action: String, isEnding: Boolean, currentState: String): Boolean {
        if (isEnding) return false
        return when (action) {
            "setDrawingEnabled", "clearDrawing", "undoDrawing", "setDrawingStyle", "getDrawingState" -> {
                currentState in listOf("recording", "paused")
            }
            else -> false
        }
    }

    /** Stateful stroke accumulator and history manager. */
    class Session(
        var currentColor: Int = DEFAULT_COLOR,
        var currentWidth: Float = DEFAULT_STROKE_WIDTH
    ) {
        var isDrawingMode: Boolean = false
            private set

        private val completedStrokes = mutableListOf<Stroke>()
        private val currentPoints = mutableListOf<Point>()
        private val undoHistory = mutableListOf<Stroke>()

        val strokes: List<Stroke>
            get() = synchronized(this) { completedStrokes.toList() }

        val activeStrokePoints: List<Point>
            get() = synchronized(this) { currentPoints.toList() }

        val strokeCount: Int
            get() = synchronized(this) { completedStrokes.size }

        val canUndo: Boolean
            get() = synchronized(this) { completedStrokes.isNotEmpty() }

        fun setDrawingMode(enabled: Boolean): Boolean {
            synchronized(this) {
                if (isDrawingMode == enabled) return false
                isDrawingMode = enabled
                if (!enabled && currentPoints.isNotEmpty()) {
                    endStroke()
                }
                return true
            }
        }

        fun setStyle(color: Int? = null, width: Float? = null) {
            synchronized(this) {
                if (color != null) currentColor = clampColor(color)
                if (width != null) currentWidth = clampWidth(width)
            }
        }

        fun startStroke(x: Float, y: Float, isEraser: Boolean = false): Boolean {
            synchronized(this) {
                if (!isDrawingMode) return false
                currentPoints.clear()
                currentPoints.add(Point(x, y))
                return true
            }
        }

        fun addPoint(x: Float, y: Float, minDistancePx: Float = 1.0f): Boolean {
            synchronized(this) {
                if (!isDrawingMode || currentPoints.isEmpty()) return false
                val last = currentPoints.last()
                val dist = hypot((x - last.x).toDouble(), (y - last.y).toDouble()).toFloat()
                if (dist >= minDistancePx) {
                    currentPoints.add(Point(x, y))
                    return true
                }
                return false
            }
        }

        fun endStroke(isEraser: Boolean = false): Stroke? {
            synchronized(this) {
                if (currentPoints.isEmpty()) return null
                val stroke = Stroke(
                    points = currentPoints.toList(),
                    color = currentColor,
                    width = currentWidth,
                    isEraser = isEraser
                )
                completedStrokes.add(stroke)
                currentPoints.clear()
                undoHistory.clear()
                return stroke
            }
        }

        fun undo(): Boolean {
            synchronized(this) {
                if (completedStrokes.isEmpty()) return false
                val removed = completedStrokes.removeAt(completedStrokes.size - 1)
                undoHistory.add(removed)
                return true
            }
        }

        fun clear(): Int {
            synchronized(this) {
                val count = completedStrokes.size
                completedStrokes.clear()
                currentPoints.clear()
                undoHistory.clear()
                return count
            }
        }

        fun repositionOrRotate(oldWidth: Int, oldHeight: Int, newWidth: Int, newHeight: Int) {
            synchronized(this) {
                if (completedStrokes.isEmpty()) return
                val transformed = transformStrokesOnRotation(
                    completedStrokes, oldWidth, oldHeight, newWidth, newHeight
                )
                completedStrokes.clear()
                completedStrokes.addAll(transformed)
            }
        }

        fun snapshot(): State {
            synchronized(this) {
                return State(
                    isDrawingMode = isDrawingMode,
                    strokeCount = completedStrokes.size,
                    canUndo = completedStrokes.isNotEmpty(),
                    currentColor = currentColor,
                    currentWidth = currentWidth
                )
            }
        }
    }
}
