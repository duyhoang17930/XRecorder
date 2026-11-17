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

    /** Uses the typical phone sensor orientation for callers without camera metadata. */
    fun calculateRotation(displayRotationDegrees: Int, isFrontCamera: Boolean = true): Int =
        calculateRotation(
            sensorOrientation = if (isFrontCamera) 270 else 90,
            displayRotationDegrees = displayRotationDegrees,
            isFrontCamera = isFrontCamera
        )

    fun calculateRotation(sensorOrientation: Int, displayRotationDegrees: Int, isFrontCamera: Boolean = true): Int {
        val sensor = ((sensorOrientation % 360) + 360) % 360
        val display = ((displayRotationDegrees % 360) + 360) % 360
        // Camera2 buffers need opposite display compensation by facing.
        val displayDirection = if (isFrontCamera) 1 else -1
        return ((sensor - display * displayDirection) % 360 + 360) % 360
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
        // TextureView already compensates sensor orientation and front-camera mirroring.
        // Apply only display compensation; repeating either transform reverses the preview.
        val rotation = ((-displayRotationDegrees % 360) + 360) % 360
        if (viewWidth <= 0f || viewHeight <= 0f) {
            return TransformResult(rotation, 1f, 1f, isFrontCamera)
        }
        val pw = if (previewWidth > 0) previewWidth.toFloat() else 640f
        val ph = if (previewHeight > 0) previewHeight.toFloat() else 480f
        val sensorSwapsAxes = sensorOrientation % 180 != 0
        val naturalWidth = if (sensorSwapsAxes) ph else pw
        val naturalHeight = if (sensorSwapsAxes) pw else ph
        val swapsAxes = rotation % 180 != 0
        val contentWidth = if (swapsAxes) naturalHeight else naturalWidth
        val contentHeight = if (swapsAxes) naturalWidth else naturalHeight
        val fill = maxOf(viewWidth / contentWidth, viewHeight / contentHeight)
        // postRotate precedes postScale in FacecamOverlay: undo TextureView's
        // stretch using the rotated view axes, preserving the existing center crop.
        val rotatedWidth = if (swapsAxes) viewHeight else viewWidth
        val rotatedHeight = if (swapsAxes) viewWidth else viewHeight
        val sx = contentWidth * fill / rotatedWidth
        val sy = contentHeight * fill / rotatedHeight
        return TransformResult(rotation, sx, sy, isFrontCamera)
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
