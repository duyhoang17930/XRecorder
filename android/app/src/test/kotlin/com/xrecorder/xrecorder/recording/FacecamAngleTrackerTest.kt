package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.abs
import kotlin.math.roundToInt

/** Synthetic angle/time traces, not a replacement for physical sensor/camera tests. */
class FacecamAngleTrackerTest {
    @Test
    fun wrapsBothDirectionsWithoutAFullTurnJump() {
        for ((samples, expected) in listOf(
            listOf(350, 355, 359, 0, 1, 5, 10) to 370.0,
            listOf(10, 5, 1, 0, 359, 355, 350) to -10.0
        )) {
            val trace = Trace()
            var previous = samples.first().toDouble()
            for (physical in samples) {
                val angle = trace.sample(physical.toDouble())
                assertTrue(abs(angle - previous) < 10)
                previous = angle
            }
            trace.settle()
            assertEquals(expected, trace.tracker.angle!!, .02)
        }
    }

    @Test
    fun tracksTwoTurnsAndReversalWithoutQuantizingOrResettingPhase() {
        val trace = Trace()
        trace.sample(0.0)
        var previous = 0.0
        var intermediate = 0
        for (physical in 2..720 step 2) {
            val angle = trace.sample(physical.toDouble())
            assertTrue(angle >= previous)
            assertTrue(angle - previous < 10)
            if (abs(angle % 90) > 1) intermediate++
            previous = angle
        }
        trace.settle()
        assertEquals(720.0, trace.tracker.angle!!, .02)
        for (physical in 718 downTo 0 step 2) {
            val angle = trace.sample(physical.toDouble())
            assertTrue(abs(angle - previous) < 10)
            previous = angle
        }
        trace.settle()
        assertEquals(0.0, trace.tracker.angle!!, .02)
        assertTrue(intermediate > 300)
    }

    @Test
    fun smallAnglesRespondOnNextFrameWithoutDebounce() {
        for (physical in listOf(10.0, 30.0, 45.0, 60.0)) {
            val trace = Trace()
            trace.sample(0.0)
            val next = trace.sample(physical)
            assertTrue(next > 0)
            assertTrue(next < physical)
            trace.settle()
            assertEquals(physical, trace.tracker.angle!!, .02)
        }
    }

    @Test
    fun fastMotionHasLessTimeLagThanSlowMotionAndStopDoesNotOvershoot() {
        val slow = movingTrace(10.0, 60)
        val fast = movingTrace(360.0, 60)
        val slowLag = (30 - slow.tracker.angle!!) / 10
        val fastLag = (1080 - fast.tracker.angle!!) / 360
        assertTrue("fast lag=$fastLag slow lag=$slowLag", fastLag < slowLag)
        assertTrue("fast lag=$fastLag seconds", fastLag < .05)
        var previous = fast.tracker.angle!!
        repeat(120) {
            fast.now += fast.period
            val next = fast.tracker.advance(fast.now)!!
            assertTrue(next >= previous)
            assertTrue(next <= 1080)
            previous = next
        }
        assertEquals(1080.0, previous, .02)
    }

    @Test
    fun smoothingUsesFrameTimeAcrossDifferentRefreshCadences() {
        val results = listOf(30, 60, 90, 120).map { fps -> movingTrace(90.0, fps).tracker.angle!! }
        assertTrue("cadence results=$results", results.maxOrNull()!! - results.minOrNull()!! < 2)
    }

    @Test
    fun tenSecondsOfSmallJitterIsAttenuatedAndAnUnchangingPoseStopsRendering() {
        val trace = Trace()
        trace.sample(0.0)
        var maxError = 0.0
        repeat(600) {
            maxError = maxOf(maxError, abs(trace.sample(if (it % 2 == 0) 1.0 else -1.0)))
        }
        assertTrue("max jitter=$maxError", maxError < .3)
        trace.sample(0.0)
        trace.settle()
        assertFalse(trace.tracker.needsFrame())
        assertFalse(trace.tracker.observe(0))
    }

    @Test
    fun unknownHoldsLastFilteredValueAndReacquisitionDoesNotJump() {
        val trace = Trace()
        assertNull(trace.tracker.advance(0))
        trace.sample(0.0)
        val held = trace.sample(90.0)
        trace.tracker.observe(-1)
        repeat(10) {
            trace.now += 1_000_000_000
            assertEquals(held, trace.tracker.advance(trace.now)!!, 0.0)
            assertFalse(trace.tracker.needsFrame())
        }
        val next = trace.sample(100.0)
        assertTrue(next >= held && next < 100)
        trace.settle()
        assertEquals(100.0, trace.tracker.angle!!, .02)
    }

    @Test
    fun crossingHalfTurnKeepsDirectionAndDuplicateOrOldTimestampsAreIgnored() {
        val trace = Trace()
        trace.sample(170.0)
        var previous = 170.0
        for (physical in 171..190) {
            val angle = trace.sample(physical.toDouble())
            assertTrue(angle >= previous && angle - previous < 3)
            previous = angle
        }
        trace.tracker.observe(160) // Physical 200, pending a fresh frame.
        assertEquals(previous, trace.tracker.advance(trace.now)!!, 0.0)
        assertEquals(previous, trace.tracker.advance(trace.now - 1)!!, 0.0)
        trace.now += trace.period
        assertTrue(trace.tracker.advance(trace.now)!! > previous)
    }

    private fun movingTrace(speed: Double, fps: Int): Trace {
        val trace = Trace(fps)
        for (index in 0..fps * 3) trace.sample(speed * index / fps)
        return trace
    }

    private class Trace(fps: Int = 60) {
        val tracker = FacecamAngleTracker()
        val period = 1_000_000_000L / fps
        var now = 0L
        fun sample(physical: Double): Double {
            val listener = ((360 - physical.roundToInt() % 360) % 360 + 360) % 360
            tracker.observe(listener)
            now += period
            return tracker.advance(now)!!
        }
        fun settle() {
            repeat(240) {
                if (tracker.needsFrame()) {
                    now += period
                    tracker.advance(now)
                }
            }
            assertFalse("filter must settle", tracker.needsFrame())
        }
    }
}
