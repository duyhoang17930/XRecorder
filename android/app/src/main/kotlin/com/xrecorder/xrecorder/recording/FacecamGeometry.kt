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

    data class PhysicalTransform(
        val content: TransformResult,
        val inputScaleX: Float,
        val inputScaleY: Float,
        val coordinateRotation: Int
    )

    /** OrientationEventListener is clockwise; Surface rotation uses the opposite convention. */
    fun physicalRotation(orientation: Int, previous: Int?): Int? {
        if (orientation !in 0..359) return previous // Unknown (e.g. flat): retain last valid pose.
        val degrees = normalizeDegrees(360 - orientation)
        if (previous != null) {
            val difference = normalizeDegrees(degrees - previous)
            val distance = kotlin.math.min(difference, 360 - difference)
            if (distance < 60) return previous // 45-degree boundary + 15-degree hysteresis.
        }
        return normalizeDegrees(((degrees + 45) / 90) * 90)
    }

    // P and D use Surface degrees. Compose R(P-D) * mirror * R(-P), with crop in
    // physically upright coordinates. Mirroring in locked Display axes instead can
    // invert gravity when P and D differ by a quarter turn.
    fun calculatePhysicalTransform(
        sensorOrientation: Int,
        displayRotationDegrees: Int,
        physicalRotationDegrees: Int,
        viewWidth: Float,
        viewHeight: Float,
        previewWidth: Int,
        previewHeight: Int,
        isFrontCamera: Boolean
    ): PhysicalTransform {
        val relative = normalizeDegrees(physicalRotationDegrees - displayRotationDegrees)
        val swapped = relative % 180 == 90
        val physicalWidth = if (swapped) viewHeight else viewWidth
        val physicalHeight = if (swapped) viewWidth else viewHeight
        return PhysicalTransform(
            calculateTransform(sensorOrientation, physicalRotationDegrees, physicalWidth, physicalHeight,
                previewWidth, previewHeight, isFrontCamera),
            if (viewWidth > 0f) physicalWidth / viewWidth else 1f,
            if (viewHeight > 0f) physicalHeight / viewHeight else 1f,
            relative
        )
    }

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
        // Both lens facings arrive in natural orientation via SurfaceTexture/TextureView.
        // Sensor/lens compensation belongs to that producer transform, not a second rotation.
        return calculateRotation(displayRotationDegrees, isFrontCamera)
    }

    fun calculateTransform(
        sensorOrientation: Int = 90,
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
        // TextureView already applies the sensor-to-natural-orientation transform.
        // Use sensor parity for the natural buffer dimensions; do NOT rotate by it again.
        val sensorSwapsAxes = normalizeDegrees(sensorOrientation) % 180 == 90
        val naturalWidth = (if (sensorSwapsAxes) ph else pw).toFloat()
        val naturalHeight = (if (sensorSwapsAxes) pw else ph).toFloat()
        val displaySwapsAxes = rotation % 180 == 90
        val contentWidth = if (displaySwapsAxes) naturalHeight else naturalWidth
        val contentHeight = if (displaySwapsAxes) naturalWidth else naturalHeight
        val fill = kotlin.math.max(viewWidth / contentWidth, viewHeight / contentHeight)
        // Matrix.postRotate then postScale scales in DISPLAY axes. Undo TextureView's
        // nonuniform fit and center-crop with one uniform camera-pixel scale.
        var sx = fill * contentWidth / (if (displaySwapsAxes) viewHeight else viewWidth)
        val sy = fill * contentHeight / (if (displaySwapsAxes) viewWidth else viewHeight)

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

    private fun normalizeDegrees(degrees: Int) = ((degrees % 360) + 360) % 360

    fun targetDimensions(portraitWidth: Int, portraitHeight: Int, scale: Float, displayDegrees: Int): Pair<Int, Int> {
        val portrait = scaledDimensions(portraitWidth, portraitHeight, scale)
        return if (normalizeDegrees(displayDegrees) % 180 == 90) portrait.second to portrait.first else portrait
    }

    fun positionFraction(position: Int, screenSize: Int, viewSize: Int): Float {
        val room = (screenSize - viewSize).coerceAtLeast(0)
        return if (room == 0) 0f else position.coerceIn(0, room).toFloat() / room
    }

    fun positionFromFraction(fraction: Float, screenSize: Int, viewSize: Int): Int =
        (fraction.coerceIn(0f, 1f) * (screenSize - viewSize).coerceAtLeast(0) + .5f).toInt()

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
