package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class AudioVideoMathTest {
    @Test fun independentGainAndMuteDoNotChangeOtherSource() {
        assertEquals(1500.toShort(), SessionAudio.mixSample(1000, 2000, 0.5, 0.5))
        assertEquals(1000.toShort(), SessionAudio.mixSample(1000, 2000, 1.0, 0.0))
        assertEquals(2000.toShort(), SessionAudio.mixSample(1000, 2000, 0.0, 1.0))
        assertEquals(0.toShort(), SessionAudio.mixSample(1000, 2000, 0.0, 0.0))
    }
    @Test fun mixedPcmSaturatesRatherThanWrapping() {
        assertEquals(32767.toShort(), SessionAudio.mixSample(30000, 30000, 2.0, 2.0))
        assertEquals((-32768).toShort(), SessionAudio.mixSample(-30000, -30000, 2.0, 2.0))
        assertEquals(0.toShort(), SessionAudio.mixSample(30000, -30000, 1.0, 1.0))
    }
    @Test fun relativeEncoderClockUsesMonotonicPauseClock() {
        val source = 900_000_000_000L
        assertEquals(source, VideoEncoder.captureTimeNs(0, 0, source))
        assertEquals(source + 5_000_000_000L, VideoEncoder.captureTimeNs(5_000_000, 0, source))
        assertEquals(source + 5_000_000_000L, VideoEncoder.captureTimeNs(905_000_000, 900_000_000, source))
    }
    @Test fun duckFactorAttenuatesOnlyInternalSource() {
        // mic = 1000, internal = 4000. Normal mix = 5000.
        // With duckFactor = 0.25, internal becomes 1000 -> mix = 2000.
        assertEquals(2000.toShort(), SessionAudio.mixSample(1000, 4000, 1.0, 1.0, 0.25f))
        // With duckFactor = 0.0, internal is completely muted -> mix = 1000.
        assertEquals(1000.toShort(), SessionAudio.mixSample(1000, 4000, 1.0, 1.0, 0.0f))
        // With duckFactor = 1.0, internal is untouched -> mix = 5000.
        assertEquals(5000.toShort(), SessionAudio.mixSample(1000, 4000, 1.0, 1.0, 1.0f))
    }
}
