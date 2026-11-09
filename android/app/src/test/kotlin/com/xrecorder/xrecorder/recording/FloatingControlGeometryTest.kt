package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class FloatingControlGeometryTest {
    @Test fun timerStopsDuringPauseAndContinuesFromAccumulatedTime() {
        val recorded = FloatingControlGeometry.elapsedMs("recording", 2000, 10000, 13500)
        assertEquals(5500L, recorded)
        assertEquals(recorded, FloatingControlGeometry.elapsedMs("paused", recorded, 10000, 50000))
        assertEquals(6500L, FloatingControlGeometry.elapsedMs("recording", recorded, 50000, 51000))
        assertEquals(6500L, FloatingControlGeometry.elapsedMs("finalizing", 6500, 50000, 90000))
    }

    @Test fun timeUsesHoursWithoutWrappingAtMidnight() {
        assertEquals("00:00:00", FloatingControlGeometry.time(-1))
        assertEquals("00:00:59", FloatingControlGeometry.time(59999))
        assertEquals("01:01:01", FloatingControlGeometry.time(3661000))
        assertEquals("25:00:00", FloatingControlGeometry.time(90000000))
    }

    @Test fun draggingClampsAfterResizeAndSnapsToNearestEdge() {
        assertEquals(0, FloatingControlGeometry.clamp(-30, 320, 200))
        assertEquals(120, FloatingControlGeometry.clamp(900, 320, 200))
        assertEquals(0, FloatingControlGeometry.snap(50, 320, 200))
        assertEquals(120, FloatingControlGeometry.snap(100, 320, 200))
        assertEquals(0, FloatingControlGeometry.snap(20, 100, 200))
        assertEquals(0, FloatingControlGeometry.clamp(20, 100, 200))
    }

    @Test fun resolveOverlayStateForRecordingShowsActiveTimer() {
        val state = FloatingControlGeometry.resolveOverlayState(
            state = "recording",
            elapsedMs = 125000,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = false
        )
        assertTrue(state.shouldShow)
        assertTrue(state.isInteractive)
        assertFalse(state.isPaused)
        assertEquals("● 00:02:05", state.statusText)
        assertEquals(1.0f, state.alpha, 0.001f)
    }

    @Test fun resolveOverlayStateForPausedShowsPausedTimer() {
        val state = FloatingControlGeometry.resolveOverlayState(
            state = "paused",
            elapsedMs = 125000,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = false
        )
        assertTrue(state.shouldShow)
        assertTrue(state.isInteractive)
        assertTrue(state.isPaused)
        assertEquals("Ⅱ 00:02:05", state.statusText)
        assertEquals(1.0f, state.alpha, 0.001f)
    }

    @Test fun resolveOverlayStateForStoppingAndFinalizingDisablesControls() {
        for (terminal in listOf("stopping", "finalizing")) {
            val state = FloatingControlGeometry.resolveOverlayState(
                state = terminal,
                elapsedMs = 125000,
                canDrawOverlays = true,
                acceptedInVideo = true,
                isScreenshot = false
            )
            assertTrue(state.shouldShow)
            assertFalse(state.isInteractive)
            assertFalse(state.isPaused)
            assertEquals("Saving…", state.statusText)
            assertEquals(0.4f, state.alpha, 0.001f)
        }
    }

    @Test fun resolveOverlayStateHidesForScreenshots() {
        val state = FloatingControlGeometry.resolveOverlayState(
            state = "recording",
            elapsedMs = 0,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = true
        )
        assertFalse(state.shouldShow)
    }

    @Test fun resolveOverlayStateHidesWhenOverlayPermissionNotGranted() {
        val state = FloatingControlGeometry.resolveOverlayState(
            state = "recording",
            elapsedMs = 0,
            canDrawOverlays = false,
            acceptedInVideo = true,
            isScreenshot = false
        )
        assertFalse(state.shouldShow)
    }

    @Test fun resolveOverlayStateHidesWhenNotAcceptedInVideo() {
        val state = FloatingControlGeometry.resolveOverlayState(
            state = "recording",
            elapsedMs = 0,
            canDrawOverlays = true,
            acceptedInVideo = false,
            isScreenshot = false
        )
        assertFalse(state.shouldShow)
    }

    @Test fun resolveOverlayStateHidesForTerminalOrIdleStates() {
        for (s in listOf("idle", "awaitingPermission", "countdown", "starting", "completed", "failed")) {
            val state = FloatingControlGeometry.resolveOverlayState(
                state = s,
                elapsedMs = 0,
                canDrawOverlays = true,
                acceptedInVideo = true,
                isScreenshot = false
            )
            assertFalse(state.shouldShow)
        }
    }

    @Test fun canAcceptOverlayActionValidatesStateAndEnding() {
        // Valid actions
        assertTrue(FloatingControlGeometry.canAcceptOverlayAction("togglePause", isEnding = false, currentState = "recording"))
        assertTrue(FloatingControlGeometry.canAcceptOverlayAction("togglePause", isEnding = false, currentState = "paused"))
        assertTrue(FloatingControlGeometry.canAcceptOverlayAction("stop", isEnding = false, currentState = "recording"))
        assertTrue(FloatingControlGeometry.canAcceptOverlayAction("stop", isEnding = false, currentState = "paused"))

        // Reject when ending
        assertFalse(FloatingControlGeometry.canAcceptOverlayAction("togglePause", isEnding = true, currentState = "recording"))
        assertFalse(FloatingControlGeometry.canAcceptOverlayAction("stop", isEnding = true, currentState = "recording"))

        // Reject in other states
        for (s in listOf("stopping", "finalizing", "completed", "failed", "countdown", "idle")) {
            assertFalse(FloatingControlGeometry.canAcceptOverlayAction("togglePause", isEnding = false, currentState = s))
            assertFalse(FloatingControlGeometry.canAcceptOverlayAction("stop", isEnding = false, currentState = s))
        }

        // Unknown actions
        assertFalse(FloatingControlGeometry.canAcceptOverlayAction("unknown", isEnding = false, currentState = "recording"))
    }

    @Test fun clampScaleValidatesNormalAndBoundaryValues() {
        assertEquals(1.0f, FloatingControlGeometry.clampScale(1.0f), 0.001f)
        assertEquals(0.8f, FloatingControlGeometry.clampScale(0.8f), 0.001f)
        assertEquals(1.25f, FloatingControlGeometry.clampScale(1.25f), 0.001f)

        // Below minimum (0.75f)
        assertEquals(0.75f, FloatingControlGeometry.clampScale(0.5f), 0.001f)
        assertEquals(0.75f, FloatingControlGeometry.clampScale(0.1f), 0.001f)

        // Above maximum (1.5f)
        assertEquals(1.5f, FloatingControlGeometry.clampScale(1.8f), 0.001f)
        assertEquals(1.5f, FloatingControlGeometry.clampScale(3.0f), 0.001f)

        // Fallbacks for invalid inputs
        assertEquals(1.0f, FloatingControlGeometry.clampScale(null), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampScale(Float.NaN), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampScale(0f), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampScale(-1.5f), 0.001f)
    }

    @Test fun clampOpacityValidatesNormalAndBoundaryValues() {
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(1.0f), 0.001f)
        assertEquals(0.7f, FloatingControlGeometry.clampOpacity(0.7f), 0.001f)
        assertEquals(0.2f, FloatingControlGeometry.clampOpacity(0.2f), 0.001f)

        // Below minimum (0.2f)
        assertEquals(0.2f, FloatingControlGeometry.clampOpacity(0.05f), 0.001f)
        assertEquals(0.2f, FloatingControlGeometry.clampOpacity(0.19f), 0.001f)

        // Above maximum (1.0f)
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(1.5f), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(2.0f), 0.001f)

        // Fallbacks for invalid inputs
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(null), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(Float.NaN), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(0f), 0.001f)
        assertEquals(1.0f, FloatingControlGeometry.clampOpacity(-0.5f), 0.001f)
    }

    @Test fun effectiveAlphaCombinesStateAndUserOpacitySafely() {
        // Recording state nominal alpha 1.0f
        assertEquals(1.0f, FloatingControlGeometry.effectiveAlpha(1.0f, 1.0f), 0.001f)
        assertEquals(0.8f, FloatingControlGeometry.effectiveAlpha(1.0f, 0.8f), 0.001f)
        assertEquals(0.5f, FloatingControlGeometry.effectiveAlpha(1.0f, 0.5f), 0.001f)
        assertEquals(0.2f, FloatingControlGeometry.effectiveAlpha(1.0f, 0.2f), 0.001f)

        // Saving state nominal alpha 0.4f
        assertEquals(0.4f, FloatingControlGeometry.effectiveAlpha(0.4f, 1.0f), 0.001f)
        assertEquals(0.32f, FloatingControlGeometry.effectiveAlpha(0.4f, 0.8f), 0.001f)
        // Coerced to minimum effective alpha 0.15f so text remains legible
        assertEquals(0.15f, FloatingControlGeometry.effectiveAlpha(0.4f, 0.2f), 0.001f)

        // Hidden state nominal alpha 0.0f
        assertEquals(0.0f, FloatingControlGeometry.effectiveAlpha(0.0f, 1.0f), 0.001f)
        assertEquals(0.0f, FloatingControlGeometry.effectiveAlpha(0.0f, 0.5f), 0.001f)
    }

    @Test fun scaledDimensionCalculatesPixelsWithClampedScale() {
        assertEquals(48, FloatingControlGeometry.scaledDimension(48, 1.0f))
        assertEquals(38, FloatingControlGeometry.scaledDimension(48, 0.8f))
        assertEquals(60, FloatingControlGeometry.scaledDimension(48, 1.25f))
        // Extreme scale clamped to 1.5
        assertEquals(72, FloatingControlGeometry.scaledDimension(48, 2.5f))
        // Extreme small scale clamped to 0.75
        assertEquals(36, FloatingControlGeometry.scaledDimension(48, 0.2f))
    }

    @Test fun normalizedCoordinateConversionBidirectional() {
        val available = 1000
        val size = 100
        val maxPos = 900

        // Normal 50%
        val ratio50 = FloatingControlGeometry.toNormalizedX(450, available, size)
        assertEquals(0.5f, ratio50, 0.001f)
        assertEquals(450, FloatingControlGeometry.fromNormalizedX(ratio50, available, size))

        // Start edge (0%)
        val ratio0 = FloatingControlGeometry.toNormalizedX(0, available, size)
        assertEquals(0.0f, ratio0, 0.001f)
        assertEquals(0, FloatingControlGeometry.fromNormalizedX(0f, available, size))

        // End edge (100%)
        val ratio100 = FloatingControlGeometry.toNormalizedX(maxPos, available, size)
        assertEquals(1.0f, ratio100, 0.001f)
        assertEquals(maxPos, FloatingControlGeometry.fromNormalizedX(1.0f, available, size))

        // Out of bounds clamp
        val ratioOverflow = FloatingControlGeometry.toNormalizedX(1500, available, size)
        assertEquals(1.0f, ratioOverflow, 0.001f)
        val ratioNegative = FloatingControlGeometry.toNormalizedX(-200, available, size)
        assertEquals(0.0f, ratioNegative, 0.001f)

        // Degenerate bounds (available <= size)
        assertEquals(0.0f, FloatingControlGeometry.toNormalizedX(50, 80, 100), 0.001f)
        assertEquals(0, FloatingControlGeometry.fromNormalizedX(0.5f, 80, 100))
    }

    @Test fun repositionAfterRotationAdaptsScreenOrientation() {
        val portraitW = 1080
        val portraitH = 2400
        val viewSize = 144

        // Position snapped to right edge in portrait (x = 1080 - 144 = 936, y = 600)
        val ratioX = FloatingControlGeometry.toNormalizedX(936, portraitW, viewSize)
        val ratioY = FloatingControlGeometry.toNormalizedY(600, portraitH, viewSize)
        assertEquals(1.0f, ratioX, 0.001f)

        // Rotate to landscape (width = 2400, height = 1080)
        val landscapeW = 2400
        val landscapeH = 1080
        val (newX, newY) = FloatingControlGeometry.repositionAfterRotation(
            ratioX, ratioY, landscapeW, landscapeH, viewSize, viewSize, snapToEdge = true
        )

        // In landscape: snapped to right edge (2400 - 144 = 2256)
        assertEquals(2256, newX)
        // In landscape: new Y is proportional to height
        val expectedLandscapeY = FloatingControlGeometry.fromNormalizedY(ratioY, landscapeH, viewSize)
        assertEquals(expectedLandscapeY, newY)
        assertTrue(newY in 0..(landscapeH - viewSize))
    }

    @Test fun parseCustomizationHandlesNullsAndOutOfRange() {
        val normal = FloatingControlGeometry.parseCustomization(0.5f, 0.7f, 1.2f, 0.85f)
        assertEquals(0.5f, normal.ratioX, 0.001f)
        assertEquals(0.7f, normal.ratioY, 0.001f)
        assertEquals(1.2f, normal.scale, 0.001f)
        assertEquals(0.85f, normal.opacity, 0.001f)

        val fallback = FloatingControlGeometry.parseCustomization(null, -1f, null, Float.NaN)
        assertEquals(-1f, fallback.ratioX, 0.001f)
        assertEquals(-1f, fallback.ratioY, 0.001f)
        assertEquals(1.0f, fallback.scale, 0.001f)
        assertEquals(1.0f, fallback.opacity, 0.001f)
    }

    @Test fun resolveOverlayStateWithCustomOpacity() {
        val recording = FloatingControlGeometry.resolveOverlayState(
            state = "recording",
            elapsedMs = 5000,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = false,
            userOpacity = 0.6f
        )
        assertTrue(recording.shouldShow)
        assertEquals(0.6f, recording.alpha, 0.001f)

        val saving = FloatingControlGeometry.resolveOverlayState(
            state = "stopping",
            elapsedMs = 5000,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = false,
            userOpacity = 0.5f
        )
        assertTrue(saving.shouldShow)
        assertEquals(0.2f, saving.alpha, 0.001f)
    }
}
