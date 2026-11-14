package com.xrecorder.xrecorder.recording

import org.junit.Assert.assertEquals
import org.junit.Test

class CaptureConfigRestoreTest {
    @Test fun restoresEveryHistoricalFieldWithoutQueryingCurrentDisplayOrEncoders() {
        val original = CaptureConfig(
            width = 3840, height = 2160, fps = 60, bitrate = 24000000,
            codec = "hevc", encoderName = "historical.encoder", audio = "mixed",
            micGain = 1.2, internalGain = 0.8, noiseReduction = true,
            countdown = 3, durationSeconds = 600, orientation = "landscape", mode = "normal",
            facecam = true, hardwareEncoding = false,
            cropX = 20, cropY = 40, cropWidth = 320, cropHeight = 640,
            floatingScale = 1.2f, floatingOpacity = 0.7f, floatingRatioX = 0.2f, floatingRatioY = 0.8f,
            shakeToStop = false, showTouches = true, audioDucking = true
        )
        assertEquals(original, CaptureConfig.restore(original.map()))
    }

    @Test fun olderSnapshotsUseExistingDefaultsForMissingFields() {
        assertEquals(CaptureConfig(), CaptureConfig.restore(emptyMap<String, Any>()))
        assertEquals(5, CaptureConfig.restore(mapOf("countdown" to 5L)).countdown)
    }
}
