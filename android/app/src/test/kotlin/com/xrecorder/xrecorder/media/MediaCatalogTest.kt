package com.xrecorder.xrecorder.media

import org.junit.Assert.*
import org.junit.Test

class MediaCatalogTest {
    @Test
    fun legacyPhotoDiscoveryIncludesExportedGifAndJpeg() {
        val files = listOf("gif", "GIF", "jpeg", "JPG", "png", "mp4", "part")
        val photos = files.filter { legacyMediaMime(it).startsWith("image/") }
        assertEquals(listOf("gif", "GIF", "jpeg", "JPG", "png"), photos)
        assertEquals(listOf("mp4"), files.filter { legacyMediaMime(it).startsWith("video/") })
    }
}
