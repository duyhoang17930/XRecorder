package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureNotificationPolicyTest {

    @Test
    fun resolveRecordingShowsPauseAndStopActions() {
        val spec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "recording",
            countdownRemaining = 0,
            active = true,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Screen recording", spec.title)
        assertEquals("Your screen is being captured. Tap Stop to finish.", spec.text)
        assertEquals(CaptureNotificationPolicy.IconType.VIDEO, spec.iconType)
        assertTrue(spec.ongoing)
        assertTrue(spec.alertOnce)
        assertEquals(2, spec.actions.size)
        assertEquals(CaptureService.PAUSE, spec.actions[0].action)
        assertEquals("Pause", spec.actions[0].title)
        assertEquals(CaptureNotificationPolicy.REQUEST_CODE_PAUSE, spec.actions[0].requestCode)
        assertEquals(CaptureService.STOP, spec.actions[1].action)
        assertEquals("Stop", spec.actions[1].title)
        assertEquals(CaptureNotificationPolicy.REQUEST_CODE_STOP, spec.actions[1].requestCode)
    }

    @Test
    fun resolveRecordingWithOverlaysShowsVisibilityToggle() {
        val showControlsSpec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "recording",
            countdownRemaining = 0,
            active = true,
            canDrawOverlays = true,
            controlsAcceptedInVideo = false
        )
        assertEquals(3, showControlsSpec.actions.size)
        assertEquals(CaptureService.PAUSE, showControlsSpec.actions[0].action)
        assertEquals(CaptureService.SHOW_CONTROLS, showControlsSpec.actions[1].action)
        assertEquals("Show controls in video", showControlsSpec.actions[1].title)
        assertEquals(CaptureNotificationPolicy.REQUEST_CODE_VISIBILITY, showControlsSpec.actions[1].requestCode)
        assertEquals(CaptureService.STOP, showControlsSpec.actions[2].action)

        val hideControlsSpec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "recording",
            countdownRemaining = 0,
            active = true,
            canDrawOverlays = true,
            controlsAcceptedInVideo = true
        )
        assertEquals(3, hideControlsSpec.actions.size)
        assertEquals(CaptureService.HIDE_CONTROLS, hideControlsSpec.actions[1].action)
        assertEquals("Hide controls", hideControlsSpec.actions[1].title)
    }

    @Test
    fun resolvePausedShowsResumeAndStopActions() {
        val spec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "paused",
            countdownRemaining = 0,
            active = true,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Recording paused", spec.title)
        assertEquals("Recording is paused. Tap Resume to continue.", spec.text)
        assertEquals(CaptureNotificationPolicy.IconType.VIDEO, spec.iconType)
        assertTrue(spec.ongoing)
        assertTrue(spec.alertOnce)
        assertEquals(2, spec.actions.size)
        assertEquals(CaptureService.RESUME, spec.actions[0].action)
        assertEquals("Resume", spec.actions[0].title)
        assertEquals(CaptureNotificationPolicy.REQUEST_CODE_RESUME, spec.actions[0].requestCode)
        assertEquals(CaptureService.STOP, spec.actions[1].action)
        assertEquals("Stop", spec.actions[1].title)
    }

    @Test
    fun resolveCountdownShowsSecondsAndCancelAction() {
        val spec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "countdown",
            countdownRemaining = 3,
            active = false,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Recording in 3s", spec.title)
        assertEquals("Recording will start automatically.", spec.text)
        assertEquals(CaptureNotificationPolicy.IconType.VIDEO, spec.iconType)
        assertTrue(spec.ongoing)
        assertTrue(spec.alertOnce)
        assertEquals(1, spec.actions.size)
        assertEquals(CaptureService.STOP, spec.actions[0].action)
        assertEquals("Cancel", spec.actions[0].title)
        assertEquals(CaptureNotificationPolicy.REQUEST_CODE_STOP, spec.actions[0].requestCode)
    }

    @Test
    fun resolveStartingShowsPreparingAndCancelAction() {
        val spec = CaptureNotificationPolicy.resolve(
            isScreenshot = false,
            state = "starting",
            countdownRemaining = 0,
            active = false,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Preparing screen recording", spec.title)
        assertEquals("Waiting for capture to start.", spec.text)
        assertEquals(1, spec.actions.size)
        assertEquals(CaptureService.STOP, spec.actions[0].action)
        assertEquals("Cancel", spec.actions[0].title)
    }

    @Test
    fun resolveStoppingAndFinalizingHidesAllActionsToPreventStaleClicks() {
        for (state in listOf("stopping", "finalizing")) {
            val spec = CaptureNotificationPolicy.resolve(
                isScreenshot = false,
                state = state,
                countdownRemaining = 0,
                active = false,
                canDrawOverlays = true,
                controlsAcceptedInVideo = true
            )
            assertEquals("Saving recording", spec.title)
            assertEquals("Processing and saving video...", spec.text)
            assertEquals(CaptureNotificationPolicy.IconType.VIDEO, spec.iconType)
            assertTrue(spec.ongoing)
            assertTrue(spec.alertOnce)
            assertTrue(spec.actions.isEmpty())
        }
    }

    @Test
    fun resolveScreenshotStates() {
        val countdownSpec = CaptureNotificationPolicy.resolve(
            isScreenshot = true,
            state = "countdown",
            countdownRemaining = 2,
            active = false,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Screenshot in 2s", countdownSpec.title)
        assertEquals("One image. Capture ends automatically.", countdownSpec.text)
        assertEquals(CaptureNotificationPolicy.IconType.CAMERA, countdownSpec.iconType)
        assertEquals(1, countdownSpec.actions.size)
        assertEquals(CaptureService.STOP, countdownSpec.actions[0].action)
        assertEquals("Cancel", countdownSpec.actions[0].title)

        val finalizingSpec = CaptureNotificationPolicy.resolve(
            isScreenshot = true,
            state = "finalizing",
            countdownRemaining = 0,
            active = false,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Saving screenshot", finalizingSpec.title)
        assertEquals("Saving image...", finalizingSpec.text)
        assertEquals(CaptureNotificationPolicy.IconType.CAMERA, finalizingSpec.iconType)
        assertTrue(finalizingSpec.actions.isEmpty())

        val otherSpec = CaptureNotificationPolicy.resolve(
            isScreenshot = true,
            state = "starting",
            countdownRemaining = 0,
            active = false,
            canDrawOverlays = false,
            controlsAcceptedInVideo = false
        )
        assertEquals("Taking screenshot", otherSpec.title)
        assertTrue(otherSpec.actions.isEmpty())
    }

    @Test
    fun canAcceptActionValidatesPauseTransitions() {
        val session = "test-session"
        // Valid pause
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = session,
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))

        // Reject pause if already paused (idempotent double-tap prevention)
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = session,
            currentSessionId = session,
            state = "paused",
            ending = false,
            busy = true,
            started = true
        ))

        // Reject pause if ending or stopping
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = session,
            currentSessionId = session,
            state = "recording",
            ending = true,
            busy = true,
            started = true
        ))
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = session,
            currentSessionId = session,
            state = "stopping",
            ending = false,
            busy = true,
            started = true
        ))

        // Reject pause if session mismatch or null
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = "old-session",
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.PAUSE,
            commandSessionId = null,
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
    }

    @Test
    fun canAcceptActionValidatesResumeTransitions() {
        val session = "test-session"
        // Valid resume
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.RESUME,
            commandSessionId = session,
            currentSessionId = session,
            state = "paused",
            ending = false,
            busy = true,
            started = true
        ))

        // Reject resume if already recording (idempotent double-tap prevention)
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.RESUME,
            commandSessionId = session,
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))

        // Reject resume if ending or stopping
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.RESUME,
            commandSessionId = session,
            currentSessionId = session,
            state = "paused",
            ending = true,
            busy = true,
            started = true
        ))
    }

    @Test
    fun canAcceptActionValidatesStopTransitions() {
        val session = "test-session"
        // Valid stop while busy and not ending
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = session,
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = session,
            currentSessionId = session,
            state = "paused",
            ending = false,
            busy = true,
            started = true
        ))
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = session,
            currentSessionId = session,
            state = "countdown",
            ending = false,
            busy = true,
            started = false
        ))

        // Reject stop if already ending (idempotent double-tap prevention)
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = session,
            currentSessionId = session,
            state = "stopping",
            ending = true,
            busy = true,
            started = true
        ))

        // Accept stop if idle and not started to clean up orphaned service
        assertTrue(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = null,
            currentSessionId = "",
            state = "idle",
            ending = false,
            busy = false,
            started = false
        ))

        // Reject stop if session mismatch
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = CaptureService.STOP,
            commandSessionId = "old-session",
            currentSessionId = session,
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
    }

    @Test
    fun canAcceptActionRejectsUnknownOrNullActions() {
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = null,
            commandSessionId = "session",
            currentSessionId = "session",
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
        assertFalse(CaptureNotificationPolicy.canAcceptAction(
            action = "com.xrecorder.UNKNOWN",
            commandSessionId = "session",
            currentSessionId = "session",
            state = "recording",
            ending = false,
            busy = true,
            started = true
        ))
    }
}
