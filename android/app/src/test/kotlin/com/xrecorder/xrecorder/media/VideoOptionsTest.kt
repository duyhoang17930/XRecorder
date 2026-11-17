package com.xrecorder.xrecorder.media

import org.junit.Assert.*
import org.junit.Test

class VideoOptionsTest {
    @Test fun ownedVideoOffersAllExistingActions() {
        assertEquals(listOf("rename", "edit", "info", "share", "copy", "move", "trash"), videoOptionKeys(true, 200))
    }
    @Test fun externalVideoCannotBeRenamedOrTrashed() {
        val keys = videoOptionKeys(false, 1000)
        assertFalse(keys.contains("rename"))
        assertFalse(keys.contains("trash"))
        assertTrue(keys.containsAll(listOf("edit", "info", "share", "copy", "move")))
    }
    @Test fun unknownOrShortDurationCannotCreateUnplayableProject() {
        for (duration in listOf(null, 0L, 199L)) assertFalse(videoOptionKeys(true, duration).contains("edit"))
    }
}
