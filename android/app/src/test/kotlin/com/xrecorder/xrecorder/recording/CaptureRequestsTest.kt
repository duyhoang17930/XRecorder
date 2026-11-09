package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class CaptureRequestsTest {
    @Test fun duplicateConsentReservesBeforeFactoryAndLaunchesOnlyOnce() {
        var launches = 0
        try {
            assertTrue(CaptureRequests.launchOnce(702, "session") {
                assertTrue(CaptureRequests.awaitingResult)
                launches++
            })
            assertFalse(CaptureRequests.launchOnce(702, "session") { launches++ })
            assertEquals(1, launches)
            assertEquals("session", CaptureRequests.consumeFor(702, "session"))
            assertNull(CaptureRequests.consumeFor(702, "session"))
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun disposedOrStaleReceiverCannotConsumeCurrentConsent() {
        CaptureRequests.launch(702, "current")
        try {
            assertNull(CaptureRequests.consumeFor(702, "current", receiverActive = false))
            assertNull(CaptureRequests.consumeFor(702, "old"))
            assertNull(CaptureRequests.consumeFor(702, null))
            assertNull(CaptureRequests.consumeFor(704, "current"))
            assertTrue(CaptureRequests.awaitingResult)
            // A replacement Activity with the same pending session accepts it.
            assertEquals("current", CaptureRequests.consumeFor(702, "current"))
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun laterSessionRequiresFreshLaunchAndCannotReusePendingOwner() {
        var launches = 0
        try {
            CaptureRequests.launchOnce(702, "first") { launches++ }
            assertThrows(IllegalStateException::class.java) {
                CaptureRequests.launchOnce(702, "second") { launches++ }
            }
            assertEquals("first", CaptureRequests.consumeFor(702, "first"))
            assertTrue(CaptureRequests.launchOnce(702, "second") { launches++ })
            assertNull(CaptureRequests.consumeFor(702, "first"))
            assertEquals("second", CaptureRequests.consumeFor(702, "second"))
            assertEquals(2, launches)
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun failedLaunchReleasesOnlyItsOwnReservation() {
        try {
            assertThrows(IllegalStateException::class.java) {
                CaptureRequests.launchOnce(702, "failed") { error("Activity launch failed") }
            }
            assertFalse(CaptureRequests.awaitingResult)
            assertTrue(CaptureRequests.launchOnce(702, "retry") {})
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun cancelledDialogDrainsBeforeAFreshRequestWithoutReusingItsConsent() {
        var launches = 0
        try {
            CaptureRequests.launchOnce(702, "cancelled") { launches++ }
            assertNull(CaptureRequests.consumeFor(702, null, cancelledSession = "unrelated"))
            assertTrue(CaptureRequests.awaitingResult)
            assertEquals("cancelled", CaptureRequests.consumeFor(702, null, cancelledSession = "cancelled"))
            assertFalse(CaptureRequests.awaitingResult)
            assertTrue(CaptureRequests.launchOnce(702, "fresh") { launches++ })
            assertEquals(2, launches)
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun cancelledRequestCannotBecomeConsentForAnotherSession() {
        CaptureRequests.launch(702, "old")
        try {
            assertTrue(CaptureRequests.awaitingResult)
            assertNull(CaptureRequests.consume(704))
            assertThrows(IllegalStateException::class.java) { CaptureRequests.launch(702, "new") }
            val owner = CaptureRequests.consume(702)
            assertFalse(CaptureRequests.owns(owner, "new"))
            assertEquals("old", owner)
            assertNull(CaptureRequests.consume(702))
        } finally { CaptureRequests.consume(702) }
    }

    @Test fun recreationRetainsRequestWithoutActivityOrTokenReference() {
        CaptureRequests.launch(704, "session")
        assertEquals("session", CaptureRequests.consume(704))
        CaptureRequests.launch(702, "session")
        assertTrue(CaptureRequests.owns(CaptureRequests.consume(702), "session"))
        assertFalse(CaptureRequests.awaitingResult)
    }

    @Test fun staleOrMissingCommandsDoNotOwnCurrentSession() {
        assertFalse(CaptureRequests.owns("old", "preparing"))
        assertFalse(CaptureRequests.owns(null, "preparing"))
        assertTrue(CaptureRequests.owns("preparing", "preparing"))
    }
}
