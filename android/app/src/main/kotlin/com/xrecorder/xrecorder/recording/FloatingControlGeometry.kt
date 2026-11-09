package com.xrecorder.xrecorder.recording

import java.util.Locale

/** Pure display calculations; recording time remains owned by CaptureState. */
internal object FloatingControlGeometry {
    data class OverlayState(
        val shouldShow: Boolean,
        val isInteractive: Boolean,
        val isPaused: Boolean,
        val statusText: String,
        val alpha: Float
    )

    data class Customization(
        val ratioX: Float = -1f,
        val ratioY: Float = -1f,
        val scale: Float = DEFAULT_SCALE,
        val opacity: Float = DEFAULT_OPACITY
    )

    const val DEFAULT_SCALE = 1.0f
    const val MIN_SCALE = 0.75f
    const val MAX_SCALE = 1.5f

    const val DEFAULT_OPACITY = 1.0f
    const val MIN_OPACITY = 0.2f
    const val MAX_OPACITY = 1.0f

    const val MIN_EFFECTIVE_ALPHA = 0.15f

    fun elapsedMs(state: String, elapsed: Long, activeStart: Long, now: Long): Long =
        (elapsed + if (state == "recording") (now - activeStart).coerceAtLeast(0) else 0).coerceAtLeast(0)

    fun time(elapsedMs: Long): String {
        val seconds = elapsedMs.coerceAtLeast(0) / 1000
        return String.format(Locale.ROOT, "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    fun clamp(position: Int, available: Int, size: Int): Int = position.coerceIn(0, (available - size).coerceAtLeast(0))

    fun snap(x: Int, available: Int, size: Int): Int {
        val end = (available - size).coerceAtLeast(0)
        return if (clamp(x, available, size) < end / 2) 0 else end
    }

    fun clampScale(scale: Float?): Float {
        if (scale == null || scale.isNaN() || scale <= 0f) return DEFAULT_SCALE
        return scale.coerceIn(MIN_SCALE, MAX_SCALE)
    }

    fun clampOpacity(opacity: Float?): Float {
        if (opacity == null || opacity.isNaN() || opacity <= 0f) return DEFAULT_OPACITY
        return opacity.coerceIn(MIN_OPACITY, MAX_OPACITY)
    }

    fun effectiveAlpha(stateAlpha: Float, userOpacity: Float = DEFAULT_OPACITY): Float {
        if (stateAlpha <= 0f) return 0f
        val clampedOpacity = clampOpacity(userOpacity)
        val combined = stateAlpha * clampedOpacity
        return combined.coerceIn(MIN_EFFECTIVE_ALPHA, 1.0f)
    }

    fun scaledDimension(basePx: Int, scale: Float): Int {
        val clampedScale = clampScale(scale)
        return (basePx * clampedScale + 0.5f).toInt().coerceAtLeast(1)
    }

    fun toNormalizedX(x: Int, availableWidth: Int, viewWidth: Int): Float {
        val maxX = (availableWidth - viewWidth).coerceAtLeast(0)
        if (maxX == 0) return 0f
        return (clamp(x, availableWidth, viewWidth).toFloat() / maxX).coerceIn(0f, 1f)
    }

    fun toNormalizedY(y: Int, availableHeight: Int, viewHeight: Int): Float {
        val maxY = (availableHeight - viewHeight).coerceAtLeast(0)
        if (maxY == 0) return 0f
        return (clamp(y, availableHeight, viewHeight).toFloat() / maxY).coerceIn(0f, 1f)
    }

    fun fromNormalizedX(ratio: Float, availableWidth: Int, viewWidth: Int): Int {
        val maxX = (availableWidth - viewWidth).coerceAtLeast(0)
        if (maxX == 0) return 0
        val safeRatio = if (ratio.isNaN()) 0f else ratio.coerceIn(0f, 1f)
        return (safeRatio * maxX + 0.5f).toInt().coerceIn(0, maxX)
    }

    fun fromNormalizedY(ratio: Float, availableHeight: Int, viewHeight: Int): Int {
        val maxY = (availableHeight - viewHeight).coerceAtLeast(0)
        if (maxY == 0) return 0
        val safeRatio = if (ratio.isNaN()) 0f else ratio.coerceIn(0f, 1f)
        return (safeRatio * maxY + 0.5f).toInt().coerceIn(0, maxY)
    }

    fun repositionAfterRotation(
        ratioX: Float,
        ratioY: Float,
        availableWidth: Int,
        availableHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
        snapToEdge: Boolean = true
    ): Pair<Int, Int> {
        val rawX = fromNormalizedX(ratioX, availableWidth, viewWidth)
        val rawY = fromNormalizedY(ratioY, availableHeight, viewHeight)
        val clampedY = clamp(rawY, availableHeight, viewHeight)
        val adjustedX = if (snapToEdge) snap(rawX, availableWidth, viewWidth) else clamp(rawX, availableWidth, viewWidth)
        return adjustedX to clampedY
    }

    fun parseCustomization(
        ratioX: Float?,
        ratioY: Float?,
        scale: Float?,
        opacity: Float?
    ): Customization {
        val clampedScale = clampScale(scale)
        val clampedOpacity = clampOpacity(opacity)
        val safeRatioX = if (ratioX != null && !ratioX.isNaN() && ratioX in 0f..1f) ratioX else -1f
        val safeRatioY = if (ratioY != null && !ratioY.isNaN() && ratioY in 0f..1f) ratioY else -1f
        return Customization(safeRatioX, safeRatioY, clampedScale, clampedOpacity)
    }

    fun resolveOverlayState(
        state: String,
        elapsedMs: Long,
        canDrawOverlays: Boolean,
        acceptedInVideo: Boolean,
        isScreenshot: Boolean,
        userOpacity: Float = DEFAULT_OPACITY
    ): OverlayState {
        if (isScreenshot || !canDrawOverlays || !acceptedInVideo) {
            return OverlayState(shouldShow = false, isInteractive = false, isPaused = false, statusText = "", alpha = 0f)
        }
        val nominalAlpha = when (state) {
            "recording", "paused" -> 1.0f
            "stopping", "finalizing" -> 0.4f
            else -> 0f
        }
        val alpha = effectiveAlpha(nominalAlpha, userOpacity)
        return when (state) {
            "recording" -> OverlayState(
                shouldShow = true,
                isInteractive = true,
                isPaused = false,
                statusText = "● ${time(elapsedMs)}",
                alpha = alpha
            )
            "paused" -> OverlayState(
                shouldShow = true,
                isInteractive = true,
                isPaused = true,
                statusText = "Ⅱ ${time(elapsedMs)}",
                alpha = alpha
            )
            "stopping", "finalizing" -> OverlayState(
                shouldShow = true,
                isInteractive = false,
                isPaused = false,
                statusText = "Saving…",
                alpha = alpha
            )
            else -> OverlayState(
                shouldShow = false,
                isInteractive = false,
                isPaused = false,
                statusText = "",
                alpha = 0f
            )
        }
    }

    fun canAcceptOverlayAction(action: String, isEnding: Boolean, currentState: String): Boolean {
        if (isEnding) return false
        return when (action) {
            "togglePause", "stop" -> currentState in listOf("recording", "paused")
            else -> false
        }
    }
}
