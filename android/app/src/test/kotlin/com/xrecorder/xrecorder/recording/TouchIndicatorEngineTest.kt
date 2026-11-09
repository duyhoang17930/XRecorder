package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class TouchIndicatorEngineTest {

    private lateinit var engine: TouchIndicatorEngine

    @Before
    fun setUp() {
        engine = TouchIndicatorEngine()
    }

    @Test
    fun tracksPointersDownAndMove() {
        val now = 1000L
        assertTrue(engine.onPointerDown(0, 100f, 200f, now))
        assertTrue(engine.onPointerDown(1, 300f, 400f, now))

        val points = engine.getActivePoints()
        assertEquals(2, points.size)

        // Move pointer 0
        assertTrue(engine.onPointerMove(0, 150f, 250f, now + 16L))
        val p0 = engine.getActivePoints().first { it.pointerId == 0 }
        assertEquals(150f, p0.x, 0.001f)
        assertEquals(250f, p0.y, 0.001f)
        assertTrue(p0.isDown)
    }

    @Test
    fun pointerUpInitiatesFadeAndPrunesAfterDuration() {
        var now = 2000L
        engine.onPointerDown(0, 100f, 100f, now)

        val pointDown = engine.getActivePoints().first { it.pointerId == 0 }
        assertEquals(1.0f, engine.pointAlpha(pointDown, now), 0.001f)

        // Pointer up at +50ms
        now += 50L
        assertTrue(engine.onPointerUp(0, now))

        val pointUp = engine.getActivePoints().first { it.pointerId == 0 }
        assertFalse(pointUp.isDown)

        // Mid-fade at +150ms (elapsed 150ms of 300ms -> alpha ~ 0.5)
        val midAlpha = engine.pointAlpha(pointUp, now + 150L)
        assertEquals(0.5f, midAlpha, 0.05f)

        // Before expiry: pruneExpired returns 0
        assertEquals(0, engine.pruneExpired(now + 200L))
        assertEquals(1, engine.getActivePoints().size)

        // After expiry (+350ms > 300ms): alpha = 0.0, prune removes it
        val endAlpha = engine.pointAlpha(pointUp, now + 350L)
        assertEquals(0.0f, endAlpha, 0.001f)
        assertEquals(1, engine.pruneExpired(now + 350L))
        assertEquals(0, engine.getActivePoints().size)
    }

    @Test
    fun enforcesMaxPointersLimit() {
        val now = 1000L
        for (i in 0 until TouchIndicatorEngine.MAX_POINTERS) {
            assertTrue(engine.onPointerDown(i, i * 10f, i * 10f, now))
        }
        assertEquals(TouchIndicatorEngine.MAX_POINTERS, engine.getActivePoints().size)

        // 11th pointer should be rejected
        assertFalse(engine.onPointerDown(99, 500f, 500f, now))
    }

    @Test
    fun resetClearsAllActivePoints() {
        engine.onPointerDown(0, 10f, 10f, 100L)
        engine.onPointerDown(1, 20f, 20f, 100L)
        assertEquals(2, engine.getActivePoints().size)

        engine.reset()
        assertEquals(0, engine.getActivePoints().size)
    }

    @Test
    fun osLimitationAndGuidanceConsistency() {
        // Must clearly document that cross-app touch tracking is NOT supported without OS Developer Options
        assertFalse(engine.isCrossAppTouchSupported)
        assertTrue(engine.crossAppAlternativeGuidance.contains("Show taps"))
        assertTrue(engine.crossAppAlternativeGuidance.contains("Developer options"))
    }
}
