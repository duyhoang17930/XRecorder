package com.xrecorder.xrecorder.recording

object CaptureNotificationPolicy {
    const val REQUEST_CODE_STOP = 1
    const val REQUEST_CODE_OPEN = 2
    const val REQUEST_CODE_PAUSE = 3
    const val REQUEST_CODE_RESUME = 4
    const val REQUEST_CODE_VISIBILITY = 5

    enum class IconType {
        CAMERA,
        VIDEO
    }

    data class ActionSpec(
        val action: String,
        val title: String,
        val requestCode: Int
    )

    data class NotificationSpec(
        val title: String,
        val text: String,
        val iconType: IconType,
        val ongoing: Boolean,
        val alertOnce: Boolean,
        val actions: List<ActionSpec>
    )

    fun resolve(
        isScreenshot: Boolean,
        state: String,
        countdownRemaining: Int,
        active: Boolean,
        canDrawOverlays: Boolean,
        controlsAcceptedInVideo: Boolean
    ): NotificationSpec {
        if (isScreenshot) {
            val title = when (state) {
                "countdown" -> "Screenshot in ${countdownRemaining}s"
                "finalizing" -> "Saving screenshot"
                else -> "Taking screenshot"
            }
            val text = when (state) {
                "finalizing" -> "Saving image..."
                else -> "One image. Capture ends automatically."
            }
            val actions = mutableListOf<ActionSpec>()
            if (state == "countdown") {
                actions.add(ActionSpec(CaptureService.STOP, "Cancel", REQUEST_CODE_STOP))
            }
            return NotificationSpec(
                title = title,
                text = text,
                iconType = IconType.CAMERA,
                ongoing = true,
                alertOnce = true,
                actions = actions
            )
        }

        val title: String
        val text: String
        val actions = mutableListOf<ActionSpec>()

        when (state) {
            "countdown" -> {
                title = "Recording in ${countdownRemaining}s"
                text = "Recording will start automatically."
                actions.add(ActionSpec(CaptureService.STOP, "Cancel", REQUEST_CODE_STOP))
            }
            "starting", "awaitingPermission" -> {
                title = "Preparing screen recording"
                text = "Waiting for capture to start."
                actions.add(ActionSpec(CaptureService.STOP, "Cancel", REQUEST_CODE_STOP))
            }
            "recording" -> {
                title = "Screen recording"
                text = "Your screen is being captured. Tap Stop to finish."
                if (active) {
                    actions.add(ActionSpec(CaptureService.PAUSE, "Pause", REQUEST_CODE_PAUSE))
                    if (canDrawOverlays) {
                        actions.add(ActionSpec(
                            if (controlsAcceptedInVideo) CaptureService.HIDE_CONTROLS else CaptureService.SHOW_CONTROLS,
                            if (controlsAcceptedInVideo) "Hide controls" else "Show controls in video",
                            REQUEST_CODE_VISIBILITY
                        ))
                    }
                    actions.add(ActionSpec(CaptureService.STOP, "Stop", REQUEST_CODE_STOP))
                }
            }
            "paused" -> {
                title = "Recording paused"
                text = "Recording is paused. Tap Resume to continue."
                if (active) {
                    actions.add(ActionSpec(CaptureService.RESUME, "Resume", REQUEST_CODE_RESUME))
                    if (canDrawOverlays) {
                        actions.add(ActionSpec(
                            if (controlsAcceptedInVideo) CaptureService.HIDE_CONTROLS else CaptureService.SHOW_CONTROLS,
                            if (controlsAcceptedInVideo) "Hide controls" else "Show controls in video",
                            REQUEST_CODE_VISIBILITY
                        ))
                    }
                    actions.add(ActionSpec(CaptureService.STOP, "Stop", REQUEST_CODE_STOP))
                }
            }
            "stopping", "finalizing" -> {
                title = "Saving recording"
                text = "Processing and saving video..."
                // No interactive actions during stopping / finalizing to prevent stale actions
            }
            else -> {
                title = "Screen recording"
                text = "Waiting for capture to start."
            }
        }

        return NotificationSpec(
            title = title,
            text = text,
            iconType = IconType.VIDEO,
            ongoing = true,
            alertOnce = true,
            actions = actions
        )
    }

    /**
     * Determines whether an incoming intent action should be accepted and processed.
     */
    fun canAcceptAction(
        action: String?,
        commandSessionId: String?,
        currentSessionId: String,
        state: String,
        ending: Boolean,
        busy: Boolean,
        started: Boolean
    ): Boolean {
        if (action == null) return false
        val ownsSession = CaptureRequests.owns(commandSessionId, currentSessionId)
        return when (action) {
            CaptureService.PAUSE -> ownsSession && !ending && state == "recording"
            CaptureService.RESUME -> ownsSession && !ending && state == "paused"
            CaptureService.STOP -> (ownsSession && busy && !ending) || (!busy && !started)
            CaptureService.SHOW_CONTROLS, CaptureService.HIDE_CONTROLS ->
                ownsSession && !ending && state in listOf("recording", "paused")
            else -> false
        }
    }
}
