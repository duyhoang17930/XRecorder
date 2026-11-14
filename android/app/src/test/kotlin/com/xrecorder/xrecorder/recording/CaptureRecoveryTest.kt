package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureRecoveryTest {
    @Test fun acceptsOnlyAppOwnedMediaRowsInKnownPublicationStates() {
        for (pending in listOf(0, 1)) assertTrue(CaptureRecovery.eligible("media", "app", "app", pending))
        for (pending in listOf(-1, 2)) assertFalse(CaptureRecovery.eligible("media", "app", "app", pending))
    }
    @Test fun neverRecoversOtherAppsOrDocumentProviders() {
        for (owner in listOf(null, "", "another.app")) assertFalse(CaptureRecovery.eligible("media", owner, "app", 1))
        for (authority in listOf(null, "", "documents", "app.files")) assertFalse(CaptureRecovery.eligible(authority, "app", "app", 1))
    }
}
