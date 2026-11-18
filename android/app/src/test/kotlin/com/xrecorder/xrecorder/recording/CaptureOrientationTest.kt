package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureOrientationTest {
    @Test fun portraitDisplayOverridesSavedLandscapeWithoutMutatingPreferences() {
        val saved = CaptureConfig(width = 1280, height = 720, orientation = "landscape",
            codec = "hevc", fps = 60, bitrate = 16000000, audio = "mixed", facecam = true)
        val started = saved.atDisplayOrientation(1268, 2756)
        assertEquals(saved.copy(width = 720, height = 1280, orientation = "portrait"), started)
        assertEquals(1280, saved.width)
        assertEquals("landscape", saved.orientation)
    }

    @Test fun landscapeDisplayOverridesSavedPortraitAndIsStable() {
        val saved = CaptureConfig(width = 720, height = 1280, orientation = "portrait")
        val started = saved.atDisplayOrientation(2756, 1268)
        assertEquals(saved.copy(width = 1280, height = 720, orientation = "landscape"), started)
        assertEquals(started, started.atDisplayOrientation(2756, 1268))
    }

    @Test fun facecamAndAudioDoNotChangeTheOutputOrientationPolicy() {
        for (facecam in listOf(false, true)) for (audio in listOf("mute", "microphone", "internal", "mixed")) {
            val saved = CaptureConfig(facecam = facecam, audio = audio)
            assertEquals(saved.copy(width = 720, height = 1280, orientation = "portrait"),
                saved.atDisplayOrientation(1268, 2756))
        }
    }

    @Test fun regionAndLiveKeepTheirExistingDimensionsAndPolicy() {
        val region = CaptureConfig(cropX = 0, cropY = 0, cropWidth = 640, cropHeight = 480)
        val live = CaptureConfig(liveRequested = true)
        assertSame(region, region.atDisplayOrientation(1268, 2756))
        assertSame(live, live.atDisplayOrientation(1268, 2756))
    }

    @Test fun tallPhoneGetsAScreenShapedCanvasInsteadOfSideBars() {
        val preset = CaptureConfig(width = 1080, height = 1920, orientation = "portrait")
        assertEquals(listOf(preset.copy(width = 1080, height = 2400), preset.copy(width = 864, height = 1920)),
            preset.displayShapedCandidates(1080, 2400))
        val landscape = CaptureConfig(width = 1920, height = 1080, orientation = "landscape")
        assertEquals(landscape.copy(width = 2400, height = 1080), landscape.displayShapedCandidates(2400, 1080).first())
    }

    @Test fun sixteenByNineDisplayKeepsThePresetAndRegionLiveAreUntouched() {
        assertEquals(emptyList<CaptureConfig>(), CaptureConfig(width = 720, height = 1280).displayShapedCandidates(1080, 1920))
        assertEquals(emptyList<CaptureConfig>(), CaptureConfig(cropX = 0, cropY = 0, cropWidth = 640, cropHeight = 480).displayShapedCandidates(1080, 2400))
        assertEquals(emptyList<CaptureConfig>(), CaptureConfig(liveRequested = true).displayShapedCandidates(1080, 2400))
    }
}
