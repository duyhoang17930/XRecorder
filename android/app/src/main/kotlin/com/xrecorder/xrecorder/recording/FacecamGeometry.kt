package com.xrecorder.xrecorder.recording

/**
 * Pure, platform-independent math and state calculations for Facecam overlay (F17) and effects (F18).
 * 100% JVM unit testable without Android framework mocks.
 */
internal object FacecamGeometry {
    const val DEFAULT_WIDTH_DP = 110
    const val DEFAULT_HEIGHT_DP = 147
    const val DEFAULT_CORNER_RADIUS_DP = 16

    const val LENS_FACING_FRONT = 0
    const val LENS_FACING_BACK = 1

    // Camera2 CaptureRequest.CONTROL_EFFECT_MODE constants
    const val EFFECT_OFF = 0
    const val EFFECT_MONO = 1
    const val EFFECT_NEGATIVE = 2
    const val EFFECT_SOLARIZE = 3
    const val EFFECT_SEPIA = 4
    const val EFFECT_POSTERIZE = 5
    const val EFFECT_WHITEBOARD = 6
    const val EFFECT_BLACKBOARD = 7
    const val EFFECT_AQUA = 8

    const val MIN_SCALE = 0.75f
    const val MAX_SCALE = 1.75f
    const val DEFAULT_SCALE = 1.0f

    data class TransformResult(
        val rotation: Int,
        val scaleX: Float,
        val scaleY: Float,
        val isMirrored: Boolean
    )

    data class State(
        val isReady: Boolean,
        val lensFacing: Int,
        val effect: Int,
        val scale: Float,
        val x: Int,
        val y: Int
    )

    fun calculateRotation(displayRotationDegrees: Int, isFrontCamera: Boolean = true): Int {
        val normalizedDisplay = ((displayRotationDegrees % 360) + 360) % 360
        return (360 - normalizedDisplay) % 360
    }

    fun calculateRotation(sensorOrientation: Int, displayRotationDegrees: Int, isFrontCamera: Boolean = true): Int {
        return calculateRotation(displayRotationDegrees, isFrontCamera)
    }

    fun calculateTransform(
        sensorOrientation: Int = 0,
        displayRotationDegrees: Int = 0,
        viewWidth: Float,
        viewHeight: Float,
        previewWidth: Int = 640,
        previewHeight: Int = 480,
        isFrontCamera: Boolean = true
    ): TransformResult {
        val rotation = calculateRotation(displayRotationDegrees, isFrontCamera)

        if (viewWidth <= 0f || viewHeight <= 0f) {
            return TransformResult(
                rotation = rotation,
                scaleX = if (isFrontCamera) -1.0f else 1.0f,
                scaleY = 1.0f,
                isMirrored = isFrontCamera
            )
        }

        val pw = if (previewWidth > 0) previewWidth else 640
        val ph = if (previewHeight > 0) previewHeight else 480
        val pLong = kotlin.math.max(pw, ph).toFloat()
        val pShort = kotlin.math.min(pw, ph).toFloat()

        var sx = 1.0f
        var sy = 1.0f

        if (rotation == 0 || rotation == 180) {
            // Portrait orientation: content aspect is pShort / pLong (e.g. 480 / 640 = 0.75)
            val contentAspect = pShort / pLong
            val viewAspect = viewWidth / viewHeight
            if (viewAspect > contentAspect) {
                // View is wider than camera stream: fit width, center crop height
                sx = 1.0f
                sy = (viewWidth * pLong) / (viewHeight * pShort)
            } else {
                // View is taller than camera stream: fit height, center crop width
                sx = (viewHeight * pShort) / (viewWidth * pLong)
                sy = 1.0f
            }
        } else {
            // Landscape orientation (90 or 270):
            // After rotating by 90/270, the stream axes are swapped relative to the view.
            // Content aspect in buffer is pShort / pLong.
            // On screen, the rotated buffer spans: width = viewHeight * (pShort / pLong), height = viewWidth * (pLong / pShort).
            // To ensure 1:1 natural aspect ratio (no stretch or squash) and full fill (Center-Crop):
            val contentAspect = pShort / pLong
            val viewAspect = viewWidth / viewHeight
            if (viewAspect > contentAspect) {
                sx = viewWidth / viewHeight
                sy = pLong / pShort
            } else {
                sx = pShort / pLong
                sy = viewHeight / viewWidth
            }
        }

        if (sx.isNaN() || sx.isInfinite()) sx = 1.0f
        if (sy.isNaN() || sy.isInfinite()) sy = 1.0f

        if (isFrontCamera) {
            sx = -sx
        }

        return TransformResult(
            rotation = rotation,
            scaleX = sx,
            scaleY = sy,
            isMirrored = isFrontCamera
        )
    }

    fun clampScale(scale: Float?): Float {
        if (scale == null || scale.isNaN() || scale <= 0f) return DEFAULT_SCALE
        return scale.coerceIn(MIN_SCALE, MAX_SCALE)
    }

    fun scaledDimensions(baseWidthPx: Int, baseHeightPx: Int, scale: Float): Pair<Int, Int> {
        val clampedScale = clampScale(scale)
        val w = (baseWidthPx * clampedScale + 0.5f).toInt().coerceAtLeast(32)
        val h = (baseHeightPx * clampedScale + 0.5f).toInt().coerceAtLeast(32)
        return w to h
    }

    fun clampPosition(x: Int, y: Int, screenWidth: Int, screenHeight: Int, viewWidth: Int, viewHeight: Int): Pair<Int, Int> {
        val maxX = (screenWidth - viewWidth).coerceAtLeast(0)
        val maxY = (screenHeight - viewHeight).coerceAtLeast(0)
        return x.coerceIn(0, maxX) to y.coerceIn(0, maxY)
    }

    fun snapToEdge(x: Int, screenWidth: Int, viewWidth: Int): Int {
        val maxX = (screenWidth - viewWidth).coerceAtLeast(0)
        val clamped = x.coerceIn(0, maxX)
        return if (clamped < maxX / 2) 0 else maxX
    }

    fun validateEffect(effect: Int?): Int {
        if (effect == null || effect !in EFFECT_OFF..EFFECT_AQUA) return EFFECT_OFF
        return effect
    }

    fun effectName(effect: Int): String = when (effect) {
        EFFECT_OFF -> "Normal"
        EFFECT_MONO -> "Mono"
        EFFECT_NEGATIVE -> "Negative"
        EFFECT_SOLARIZE -> "Solarize"
        EFFECT_SEPIA -> "Sepia"
        EFFECT_POSTERIZE -> "Posterize"
        EFFECT_WHITEBOARD -> "Whiteboard"
        EFFECT_BLACKBOARD -> "Blackboard"
        EFFECT_AQUA -> "Aqua"
        else -> "Normal"
    }

    fun toggleFacing(current: Int): Int =
        if (current == LENS_FACING_FRONT) LENS_FACING_BACK else LENS_FACING_FRONT

    fun canAcceptAction(action: String, isEnding: Boolean, currentState: String): Boolean {
        if (isEnding) return false
        return when (action) {
            "switchCamera", "setEffect", "setScale", "reposition", "getState" -> {
                currentState in listOf("recording", "paused")
            }
            else -> false
        }
    }
}
