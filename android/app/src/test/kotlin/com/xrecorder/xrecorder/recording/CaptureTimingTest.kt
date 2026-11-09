package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureTimingTest {
    @Test fun delayedCountdownUsesDeadlineRatherThanNumberOfCallbacks() {
        val deadline = 13000L
        assertEquals(3, CaptureTiming.countdownSeconds(deadline - 10000))
        assertEquals(1, CaptureTiming.countdownSeconds(deadline - 12800))
        assertEquals(0, CaptureTiming.countdownSeconds(deadline - 14000))
        assertEquals(0, CaptureTiming.countdownSeconds(0))
        assertEquals(1, CaptureTiming.countdownSeconds(1))
    }
    @Test fun activeTimeExcludesPauseAndResumesWithRemainingBudget() {
        val elapsed = FloatingControlGeometry.elapsedMs("recording", 0, 10000, 12000)
        assertEquals(3000L, CaptureTiming.autoStopRemainingMs("recording", elapsed, 5))
        val paused = FloatingControlGeometry.elapsedMs("paused", elapsed, 10000, 22000)
        assertEquals(elapsed, paused)
        assertNull(CaptureTiming.autoStopRemainingMs("paused", paused, 5))
        val resumed = FloatingControlGeometry.elapsedMs("recording", paused, 22000, 24999)
        assertEquals(1L, CaptureTiming.autoStopRemainingMs("recording", resumed, 5))
        assertEquals(0L, CaptureTiming.autoStopRemainingMs("recording", resumed + 1, 5))
    }
    @Test fun pauseAtDeadlineDoesNotPostponeStopUntilResume() {
        assertEquals(0L, CaptureTiming.autoStopRemainingMs("paused", 5000, 5))
        assertEquals(0L, CaptureTiming.autoStopRemainingMs("paused", 5300, 5))
    }
    @Test fun disabledAndTerminalSessionsHaveNoAutoStopDeadline() {
        for (state in listOf("idle", "awaitingPermission", "countdown", "starting", "stopping", "finalizing", "completed", "failed")) {
            assertNull(CaptureTiming.autoStopRemainingMs(state, 10000, 5))
        }
        assertNull(CaptureTiming.autoStopRemainingMs("recording", 10000, 0))
        assertNull(CaptureTiming.autoStopRemainingMs("recording", 10000, -1))
        assertEquals(86400000L, CaptureTiming.autoStopRemainingMs("recording", 0, 86400))
    }
}
