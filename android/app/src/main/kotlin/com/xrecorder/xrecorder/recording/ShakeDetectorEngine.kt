package com.xrecorder.xrecorder.recording

/**
 * Pure, platform-independent math and logic for Shake-to-Stop detection (F22).
 * 100% JVM unit testable without Android framework mocks or hardware sensors.
 */
internal class ShakeDetectorEngine(
    val threshold: Float = DEFAULT_THRESHOLD,
    val minPeaks: Int = DEFAULT_MIN_PEAKS,
    val timeWindowMs: Long = DEFAULT_TIME_WINDOW_MS,
    val cooldownMs: Long = DEFAULT_COOLDOWN_MS
) {
    companion object {
        const val DEFAULT_THRESHOLD = 13.0f // m/s^2 beyond gravity (~1.3g deviation)
        const val DEFAULT_MIN_PEAKS = 2
        const val DEFAULT_TIME_WINDOW_MS = 600L
        const val DEFAULT_COOLDOWN_MS = 2000L
        const val GRAVITY_EARTH = 9.80665f
    }

    private var lastPeakTimestamp = 0L
    private var lastTriggerTimestamp = 0L
    private var peakCount = 0
    private var lastDirection = 0

    val isCoolingDown: Boolean get() = (System.currentTimeMillis() - lastTriggerTimestamp) < cooldownMs

    fun reset() {
        lastPeakTimestamp = 0L
        lastTriggerTimestamp = 0L
        peakCount = 0
        lastDirection = 0
    }

    /**
     * Ingests a 3-axis accelerometer sample.
     * Returns true if a deliberate shake motion is detected and allowed by session state.
     */
    fun onSensorSample(
        x: Float,
        y: Float,
        z: Float,
        timestampMs: Long,
        currentState: String,
        isEnding: Boolean
    ): Boolean {
        if (isEnding || currentState != "recording") {
            reset()
            return false
        }

        if (lastTriggerTimestamp > 0L && (timestampMs - lastTriggerTimestamp < cooldownMs)) {
            return false
        }

        val magnitude = kotlin.math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        val netAcceleration = kotlin.math.abs(magnitude - GRAVITY_EARTH)

        if (netAcceleration >= threshold) {
            // Determine dominant directional sign along primary axis
            val direction = if (kotlin.math.abs(x) >= kotlin.math.abs(y)) {
                if (x >= 0) 1 else -1
            } else {
                if (y >= 0) 2 else -2
            }

            if (timestampMs - lastPeakTimestamp > timeWindowMs) {
                // Time window expired, start a new sequence
                peakCount = 1
                lastDirection = direction
                lastPeakTimestamp = timestampMs
            } else {
                // Within window: only count if direction reversed or changed axis
                if (direction != lastDirection) {
                    peakCount++
                    lastDirection = direction
                    lastPeakTimestamp = timestampMs

                    if (peakCount >= minPeaks) {
                        lastTriggerTimestamp = timestampMs
                        peakCount = 0
                        lastDirection = 0
                        return true
                    }
                }
            }
        }
        return false
    }

    fun canAcceptShake(currentState: String, isEnding: Boolean): Boolean =
        !isEnding && currentState == "recording"
}
