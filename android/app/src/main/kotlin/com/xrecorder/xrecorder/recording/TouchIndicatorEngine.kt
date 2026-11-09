package com.xrecorder.xrecorder.recording

/**
 * Pure, platform-independent math and lifecycle tracking for touch indicators (F23).
 * 100% JVM unit testable without Android framework mocks.
 */
internal class TouchIndicatorEngine {
    companion object {
        const val DEFAULT_RADIUS_DP = 24
        const val FADE_DURATION_MS = 300L
        const val MAX_POINTERS = 10
    }

    data class TouchPoint(
        val pointerId: Int,
        val x: Float,
        val y: Float,
        val timestampMs: Long,
        val isDown: Boolean
    )

    private val activePoints = mutableMapOf<Int, TouchPoint>()

    fun onPointerDown(id: Int, x: Float, y: Float, timestampMs: Long): Boolean {
        if (activePoints.size >= MAX_POINTERS && !activePoints.containsKey(id)) return false
        activePoints[id] = TouchPoint(id, x, y, timestampMs, isDown = true)
        return true
    }

    fun onPointerMove(id: Int, x: Float, y: Float, timestampMs: Long): Boolean {
        if (!activePoints.containsKey(id)) return false
        activePoints[id] = TouchPoint(id, x, y, timestampMs, isDown = true)
        return true
    }

    fun onPointerUp(id: Int, timestampMs: Long): Boolean {
        val existing = activePoints[id] ?: return false
        activePoints[id] = existing.copy(isDown = false, timestampMs = timestampMs)
        return true
    }

    fun pruneExpired(nowMs: Long): Int {
        val before = activePoints.size
        activePoints.entries.removeAll { (_, point) ->
            !point.isDown && (nowMs - point.timestampMs > FADE_DURATION_MS)
        }
        return before - activePoints.size
    }

    fun getActivePoints(): List<TouchPoint> = activePoints.values.toList()

    fun reset() {
        activePoints.clear()
    }

    fun pointAlpha(point: TouchPoint, nowMs: Long): Float {
        if (point.isDown) return 1.0f
        val elapsed = nowMs - point.timestampMs
        if (elapsed >= FADE_DURATION_MS) return 0.0f
        return (1.0f - (elapsed.toFloat() / FADE_DURATION_MS)).coerceIn(0.0f, 1.0f)
    }

    /**
     * Android OS Security Architecture limits:
     * Non-accessibility third-party apps CANNOT observe arbitrary global touches
     * across other apps or system UI without privileged AccessibilityService or
     * System Developer Option 'Show taps'.
     */
    val isCrossAppTouchSupported: Boolean get() = false

    val crossAppAlternativeGuidance: String
        get() = "Android can draw touch indicators when Show taps is enabled in Developer options. Enable it manually in system Settings if available. 3HRecorder cannot observe arbitrary touches in other apps. The system indicator may appear in full-screen recordings; turn it off afterward if you do not want it."
}
