package com.xrecorder.xrecorder.recording

import kotlin.math.PI
import kotlin.math.abs

/**
 * Continuous Surface-convention angle. One Euro filtering runs at render timestamps.
 * Algorithm: Casiez et al., CHI 2012, https://gery.casiez.net/1euro/ (no dependency).
 */
internal class FacecamAngleTracker {
    var angle: Double? = null
        private set
    private var input: Double? = null
    private var reliable = false
    private var previousInput: Double? = null
    private var previousFrameNanos: Long? = null
    private var velocity = 0.0
    private var lastDirection = 1.0

    fun observe(listenerDegrees: Int): Boolean {
        if (listenerDegrees !in 0..359) {
            val changed = reliable
            reliable = false
            previousFrameNanos = null
            previousInput = null
            velocity = 0.0
            return changed // Flat/unknown: hold, with no extrapolation or gyro drift.
        }
        val wrapped = ((360 - listenerDegrees) % 360).toDouble()
        val reference = if (reliable) input else angle
        var delta = if (reference == null) 0.0 else ((wrapped - reference + 180) % 360 + 360) % 360 - 180
        // Exactly half a turn is ambiguous; retain the last observed direction.
        if (abs(abs(delta) - 180.0) < .000001) delta = 180 * lastDirection
        if (abs(delta) > .000001) lastDirection = if (delta > 0) 1.0 else -1.0
        val next = if (reference == null) wrapped else reference + delta
        val changed = !reliable || input != next
        input = next
        reliable = true
        return changed
    }

    fun advance(frameNanos: Long): Double? {
        if (!reliable) return angle
        val target = input ?: return angle
        val filtered = angle
        if (filtered == null) {
            angle = target
            previousInput = target
            previousFrameNanos = frameNanos
            return target
        }
        val previousTime = previousFrameNanos
        if (previousTime != null && frameNanos <= previousTime) return angle
        // Choreographer uses a monotonic nanosecond timebase. After a pause, avoid
        // treating the entire gap as one sample and jumping straight to the new input.
        val elapsed = previousTime?.let { (frameNanos - it) / 1_000_000_000.0 }
        val dt = if (elapsed == null || elapsed > .25) 1.0 / 60.0 else elapsed
        val derivative = (target - (previousInput ?: target)) / dt
        velocity += alpha(1.0, dt) * (derivative - velocity)
        val cutoff = 1.0 + .02 * abs(velocity) // Hz; beta is in Hz / (degree/second).
        val next = filtered + alpha(cutoff, dt) * (target - filtered)
        angle = if (abs(target - next) <= SETTLED_DEGREES) {
            velocity = 0.0
            target
        } else next
        previousInput = target
        previousFrameNanos = frameNanos
        return angle
    }

    fun needsFrame(): Boolean = reliable && (angle == null || abs(input!! - angle!!) > SETTLED_DEGREES)

    private fun alpha(cutoff: Double, dt: Double) = dt / (dt + 1.0 / (2 * PI * cutoff))

    companion object {
        private const val SETTLED_DEGREES = .02
    }
}
