package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureJournalTest {
    @Test fun preservesCapturedDimensionsWithoutReadingOrChangingOutput() {
        assertEquals(720 to 1456, CaptureJournal.dimensions(720, 1456) {
            error("A valid journal must not reopen its output")
        })
    }
    @Test fun oldOrZeroDimensionsUseActualOutputBoundsAsAPair() {
        for ((width, height) in listOf(0 to 0, 720 to 0, -1 to 1456)) {
            assertEquals(1440 to 2960, CaptureJournal.dimensions(width, height) { 1440 to 2960 })
        }
    }
    @Test fun unavailableOrInvalidOutputDimensionsRemainUnknown() {
        for (actual in listOf(null, 0 to 0, 720 to -1)) {
            assertEquals(0 to 0, CaptureJournal.dimensions(0, 0) { actual })
        }
    }
}
