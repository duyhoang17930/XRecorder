package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class FinalizedCaptureTest {
    private val id = "3f546f07-54dd-4e53-b36a-7392ac420069"
    @Test fun restoresPositiveAndNegativeOffsetsOnlyForTheOwningSession() {
        for (offset in listOf(-200000L, 0L, 250000L)) {
            val value = FinalizedCapture(id, 4000000L, offset)
            assertEquals(value, FinalizedCapture.restore(value.map(), id))
            assertNull(FinalizedCapture.restore(value.map(), "c1c9a769-8015-4fa7-9da5-78655ee984f2"))
        }
    }
    @Test fun rejectsMissingUnboundedOrUnusableTimingAndUnsafeSessionPaths() {
        assertNull(FinalizedCapture.restore(null, id))
        assertNull(FinalizedCapture.restore(mapOf("sessionId" to id, "durationUs" to 10), id))
        for (duration in listOf(0L, -1L, 86400000001L))
            assertNull(FinalizedCapture.restore(FinalizedCapture(id, duration, 0).map(), id))
        for (offset in listOf(-60000001L, 4000000L, Long.MIN_VALUE, Long.MAX_VALUE))
            assertNull(FinalizedCapture.restore(FinalizedCapture(id, 4000000L, offset).map(), id))
        assertNull(FinalizedCapture.restore(FinalizedCapture("../other", 4000000L, 0).map(), "../other"))
    }
    @Test fun shortRecordingCanTrimAnAudioStartupLeadLongerThanItsVideo() {
        val value = FinalizedCapture(id, 314933L, -700000L)
        assertEquals(value, FinalizedCapture.restore(value.map(), id))
        assertNotNull(FinalizedCapture.restore(FinalizedCapture(id, 4000000L, -4000000L).map(), id))
        assertNull(FinalizedCapture.restore(value.map(), "c1c9a769-8015-4fa7-9da5-78655ee984f2"))
    }
}
