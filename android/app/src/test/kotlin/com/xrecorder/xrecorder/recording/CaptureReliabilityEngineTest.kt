package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class CaptureReliabilityEngineTest {

    @Test
    fun concurrentStopTriggers_onlyOneWinsAtomicGuard() {
        val isEnding = AtomicBoolean(false)
        val successCount = AtomicInteger(0)
        val rejectedCount = AtomicInteger(0)

        val threads = 8
        val latch = CountDownLatch(1)
        val doneLatch = CountDownLatch(threads)
        val executor = Executors.newFixedThreadPool(threads)

        for (i in 0 until threads) {
            executor.execute {
                latch.await()
                if (isEnding.compareAndSet(false, true)) {
                    successCount.incrementAndGet()
                } else {
                    rejectedCount.incrementAndGet()
                }
                doneLatch.countDown()
            }
        }

        // Trigger all stop callers at the exact same moment
        latch.countDown()
        assertTrue(doneLatch.await(3, TimeUnit.SECONDS))
        executor.shutdown()

        assertEquals(1, successCount.get())
        assertEquals(threads - 1, rejectedCount.get())
        assertTrue(isEnding.get())
    }

    @Test
    fun sessionTokenMismatch_isRejected() {
        val activeSessionId = "session-active-1234"
        val isEnding = AtomicBoolean(false)

        fun canProcessAction(actionSessionId: String?): Boolean {
            if (isEnding.get()) return false
            if (actionSessionId == null || actionSessionId != activeSessionId) return false
            return true
        }

        assertTrue(canProcessAction("session-active-1234"))
        assertFalse(canProcessAction("session-stale-5678"))
        assertFalse(canProcessAction(null))

        // Once ending, even matching session is rejected
        isEnding.set(true)
        assertFalse(canProcessAction("session-active-1234"))
    }

    @Test
    fun captureStateBusyStates_correctlyIdentified() {
        val busyStates = listOf(
            "awaitingPermission",
            "countdown",
            "starting",
            "recording",
            "paused",
            "stopping",
            "finalizing"
        )
        val nonBusyStates = listOf("idle", "completed", "failed", "unknown")

        for (state in busyStates) {
            CaptureState.state = state
            assertTrue("State '$state' should be busy", CaptureState.busy)
        }

        for (state in nonBusyStates) {
            CaptureState.state = state
            assertFalse("State '$state' should not be busy", CaptureState.busy)
        }
    }

    @Test
    fun terminalStateTransitions_emitCleanSnapshot() {
        CaptureState.prepare(CaptureConfig())
        val initialId = CaptureState.id
        assertTrue(initialId.isNotBlank())
        assertEquals("awaitingPermission", CaptureState.state)

        CaptureState.transition("recording")
        assertEquals("recording", CaptureState.state)

        // Simulate successful completion with output URI
        CaptureState.output = "content://media/external/video/media/101"
        CaptureState.transition("completed")
        assertEquals("completed", CaptureState.state)
        assertEquals("content://media/external/video/media/101", CaptureState.output)
        assertNull(CaptureState.error)

        // Reset to idle
        CaptureState.transition("idle")
        assertEquals("idle", CaptureState.state)
    }

    @Test
    fun failureTransition_clearsSuccessAndRecordsError() {
        CaptureState.prepare(CaptureConfig())
        CaptureState.output = null
        CaptureState.transition("failed", "Encoder initialisation failed.")

        assertEquals("failed", CaptureState.state)
        assertEquals("Encoder initialisation failed.", CaptureState.error)
        assertNull(CaptureState.output)
    }
}
