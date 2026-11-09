package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class ShakeDetectorEngineTest {

    private lateinit var engine: ShakeDetectorEngine

    @Before
    fun setUp() {
        engine = ShakeDetectorEngine(
            threshold = 13.0f,
            minPeaks = 2,
            timeWindowMs = 600L,
            cooldownMs = 2000L
        )
    }

    @Test
    fun gentleMovementDoesNotTriggerShake() {
        // Normal gravity on flat surface: z = 9.8 m/s^2, net = 0
        assertFalse(engine.onSensorSample(0f, 0f, 9.8f, 1000L, "recording", false))

        // Gentle walking / slight tilt (net acceleration ~ 3-4 m/s^2 < 13.0 m/s^2)
        assertFalse(engine.onSensorSample(2f, 3f, 10f, 1100L, "recording", false))
        assertFalse(engine.onSensorSample(-2f, -3f, 10f, 1200L, "recording", false))
        assertFalse(engine.onSensorSample(3f, 2f, 9f, 1300L, "recording", false))
    }

    @Test
    fun deliberateShakeTriggersExactlyOnce() {
        var now = 1000L

        // Peak 1: strong acceleration rightwards along X-axis (total > 23 m/s^2 -> net > 13)
        val p1 = engine.onSensorSample(24f, 0f, 0f, now, "recording", false)
        assertFalse("First peak should not trigger yet", p1)

        // Peak 2: strong acceleration reversed leftwards along X-axis within 600ms
        now += 200L
        val p2 = engine.onSensorSample(-24f, 0f, 0f, now, "recording", false)
        assertTrue("Second reversed peak within time window must trigger shake stop", p2)

        // Peak 3 right after (e.g. 50ms later): MUST be debounced by cooldown
        now += 50L
        val p3 = engine.onSensorSample(24f, 0f, 0f, now, "recording", false)
        assertFalse("Subsequent peak within cooldown period must be debounced", p3)
    }

    @Test
    fun subsequentSamplesWithinCooldownAreIgnored() {
        var now = 5000L
        // Trigger shake
        engine.onSensorSample(25f, 0f, 0f, now, "recording", false)
        now += 150L
        val triggered = engine.onSensorSample(-25f, 0f, 0f, now, "recording", false)
        assertTrue(triggered)

        // Violent shaking for next 1500ms
        for (offset in listOf(100L, 300L, 600L, 1000L, 1500L, 1999L)) {
            val res = engine.onSensorSample(25f, 0f, 0f, now + offset, "recording", false)
            assertFalse("Sample at +${offset}ms must be ignored during cooldown", res)
        }

        // After cooldown expires (2000ms), a new deliberate shake sequence CAN trigger again
        now += 2100L
        engine.onSensorSample(25f, 0f, 0f, now, "recording", false)
        now += 150L
        val triggeredAfterCooldown = engine.onSensorSample(-25f, 0f, 0f, now, "recording", false)
        assertTrue("New shake sequence after cooldown expires should trigger", triggeredAfterCooldown)
    }

    @Test
    fun singleUnidirectionalSpikeDoesNotTrigger() {
        var now = 10000L
        // Only one directional acceleration (e.g. picking up phone fast or putting it down)
        assertFalse(engine.onSensorSample(30f, 0f, 0f, now, "recording", false))

        // Time window expires without reversal
        now += 800L // > 600ms window
        assertFalse(engine.onSensorSample(30f, 0f, 0f, now, "recording", false))
    }

    @Test
    fun doesNotTriggerWhenNotRecordingOrEnding() {
        val now = 2000L
        // Idle
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "idle", false))
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "idle", false))

        // Paused
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "paused", false))
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "paused", false))

        // Countdown
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "countdown", false))
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "countdown", false))

        // Stopping / Finalizing
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "stopping", false))
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "finalizing", false))

        // isEnding = true
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "recording", true))
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "recording", true))
    }

    @Test
    fun resetClearsStateAndPendingPeaks() {
        val now = 3000L
        // Peak 1
        assertFalse(engine.onSensorSample(25f, 0f, 0f, now, "recording", false))

        // Reset
        engine.reset()

        // Opposite peak after reset should be treated as peak 1, not peak 2
        assertFalse(engine.onSensorSample(-25f, 0f, 0f, now + 100L, "recording", false))
    }

    @Test
    fun canAcceptShakeValidatesOnlyActiveRecording() {
        assertTrue(engine.canAcceptShake("recording", false))
        assertFalse(engine.canAcceptShake("recording", true))
        assertFalse(engine.canAcceptShake("paused", false))
        assertFalse(engine.canAcceptShake("idle", false))
        assertFalse(engine.canAcceptShake("stopping", false))
        assertFalse(engine.canAcceptShake("finalizing", false))
    }
}
