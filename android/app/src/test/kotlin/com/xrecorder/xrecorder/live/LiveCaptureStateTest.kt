package com.xrecorder.xrecorder.live

import org.junit.Assert.*
import org.junit.Test

class LiveCaptureStateTest {
    @Test fun lostProcessCannotReportAnOldNetworkConnectionAsLive() {
        LiveCaptureState.prepare("previous-process", null)
        assertEquals("interrupted", LiveCaptureState.snapshotFor("restored-session", true, "failed")["state"])
        assertEquals("stopped", LiveCaptureState.snapshotFor("restored-session", true, "completed")["state"])
        assertEquals("idle", LiveCaptureState.snapshotFor("normal-recording", false, "recording")["state"])
    }
    @Test fun oneShotSecretIsAbsentFromPublicStateAndConsumedOnlyByItsOwner() {
        val endpoint = RtmpEndpoint.parse("rtmps://example.com/app", "private-token")
        LiveCaptureState.prepare("owned", endpoint)
        assertFalse(LiveCaptureState.snapshot().toString().contains("private-token"))
        assertNull(LiveCaptureState.take("old-session"))
        assertSame(endpoint, LiveCaptureState.take("owned"))
        assertNull(LiveCaptureState.take("owned"))
        LiveCaptureState.finish("owned", "stopped")
    }

    @Test fun cancelledConsentDiscardsItsSecretWithoutLeavingAnActiveSession() {
        LiveCaptureState.prepare("cancelled", RtmpEndpoint.parse("rtmp://example.com/app", "secret"))
        LiveCaptureState.discardPending("cancelled", "cancelled")
        assertNull(LiveCaptureState.take("cancelled"))
        assertEquals("cancelled", LiveCaptureState.snapshot()["state"])
    }

    @Test fun latePreviousSessionCallbacksCannotConsumeOrReplaceTheNewRequest() {
        val endpoint = RtmpEndpoint.parse("rtmps://example.com/app", "new-token")
        LiveCaptureState.prepare("old", endpoint)
        LiveCaptureState.prepare("new", endpoint)
        LiveCaptureState.update("old", "connection_failed")
        LiveCaptureState.finish("old", "stopped")
        LiveCaptureState.discardPending("old", "cancelled")
        assertEquals("awaitingPermission", LiveCaptureState.snapshot()["state"])
        assertEquals("new", LiveCaptureState.snapshot()["sessionId"])
        assertSame(endpoint, LiveCaptureState.take("new"))
        LiveCaptureState.finish("new", "stopped")
    }
}
