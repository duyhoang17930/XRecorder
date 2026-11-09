package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class VideoBitrateTest {
    @Test fun performanceAutoRejectsEncoderWhoseMinimumExceedsModeLimit() {
        assertNull(CaptureConfig.videoBitrate(null, 2764800L, 12000000, 24000000, true))
        // A subsequent encoder can satisfy Auto without changing the selected mode.
        assertEquals(2764800, CaptureConfig.videoBitrate(null, 2764800L, 1000000, 16000000, true))
    }
    @Test fun autoUsesIntersectionOfEncoderRangeAndPerformanceLimit() {
        assertEquals(8000000, CaptureConfig.videoBitrate(null, 20000000L, 1000000, 24000000, true))
        assertEquals(6000000, CaptureConfig.videoBitrate(null, 20000000L, 1000000, 6000000, true))
        assertEquals(4000000, CaptureConfig.videoBitrate(null, 1000000L, 4000000, 6000000, true))
        assertNull(CaptureConfig.videoBitrate(null, 1000000L, 6000000, 4000000, true))
    }
    @Test fun normalKeepsRequestedBitrateAndRejectsUnsupportedValues() {
        assertEquals(12000000, CaptureConfig.videoBitrate(12000000, 2764800L, 1000000, 24000000, false))
        assertNull(CaptureConfig.videoBitrate(25000000, 2764800L, 1000000, 24000000, false))
        assertNull(CaptureConfig.videoBitrate(0, 2764800L, 1000000, 24000000, false))
        assertNull(CaptureConfig.videoBitrate(-1, 2764800L, 1000000, 24000000, false))
    }
    @Test fun normalAutoAndExistingPerformanceCapRemainDistinct() {
        assertEquals(20000000, CaptureConfig.videoBitrate(null, 20000000L, 1000000, 24000000, false))
        assertEquals(8000000, CaptureConfig.videoBitrate(12000000, 2764800L, 1000000, 24000000, true))
        assertEquals(4000000, CaptureConfig.videoBitrate(4000000, 2764800L, 1000000, 24000000, true))
        assertNull(CaptureConfig.videoBitrate(500000, 2764800L, 1000000, 24000000, true))
    }
}
