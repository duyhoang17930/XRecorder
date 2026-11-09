package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class RegionCropGeometryTest {

    @Test
    fun dpToPxConvertsAccurately() {
        assertEquals(360, RegionCropGeometry.dpToPx(120f, 3.0f))
        assertEquals(180, RegionCropGeometry.dpToPx(120f, 1.5f))
        assertEquals(120, RegionCropGeometry.dpToPx(120f, 1.0f))
        assertEquals(0, RegionCropGeometry.dpToPx(0f, 2.5f))
    }

    @Test
    fun pxToDpConvertsAccurately() {
        assertEquals(120f, RegionCropGeometry.pxToDp(360, 3.0f), 0.001f)
        assertEquals(120f, RegionCropGeometry.pxToDp(180, 1.5f), 0.001f)
        assertEquals(120f, RegionCropGeometry.pxToDp(120, 1.0f), 0.001f)
    }

    @Test
    fun sanitizeRegionValidInBoundsAligned() {
        val region = RegionCropGeometry.sanitizeRegion(
            x = 100,
            y = 200,
            width = 640,
            height = 480,
            displayWidth = 1080,
            displayHeight = 1920
        )
        assertNotNull(region)
        assertEquals(100, region!!.x)
        assertEquals(200, region.y)
        assertEquals(640, region.width)
        assertEquals(480, region.height)
    }

    @Test
    fun sanitizeRegionClampsNegativeCoordinatesToZero() {
        val region = RegionCropGeometry.sanitizeRegion(
            x = -50,
            y = -30,
            width = 500,
            height = 600,
            displayWidth = 1080,
            displayHeight = 1920
        )
        assertNotNull(region)
        assertEquals(0, region!!.x)
        assertEquals(0, region.y)
        // Width clamped from 500 - 50 = 450 (aligned to 450)
        assertEquals(450, region.width)
        // Height clamped from 600 - 30 = 570 (aligned to 570)
        assertEquals(570, region.height)
    }

    @Test
    fun sanitizeRegionClampsOverflowingCoordinatesToDisplayBounds() {
        val region = RegionCropGeometry.sanitizeRegion(
            x = 800,
            y = 1500,
            width = 500,
            height = 600,
            displayWidth = 1080,
            displayHeight = 1920
        )
        assertNotNull(region)
        assertEquals(800, region!!.x)
        assertEquals(1500, region.y)
        // 1080 - 800 = 280
        assertEquals(280, region.width)
        // 1920 - 1500 = 420
        assertEquals(420, region.height)
    }

    @Test
    fun sanitizeRegionEnforcesAlignmentToEvenNumbers() {
        val region = RegionCropGeometry.sanitizeRegion(
            x = 0,
            y = 0,
            width = 321,
            height = 481,
            displayWidth = 1080,
            displayHeight = 1920,
            alignment = 2
        )
        assertNotNull(region)
        assertEquals(320, region!!.width)
        assertEquals(480, region.height)
    }

    @Test
    fun sanitizeRegionRejectsEmptyOrNegativeDimensions() {
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 0, 480, 1080, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, 0, 1080, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, -100, 480, 1080, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, -100, 1080, 1920))
    }

    @Test
    fun sanitizeRegionRejectsCoordinatesCompletelyOutsideDisplay() {
        // Completely beyond right or bottom edge
        assertNull(RegionCropGeometry.sanitizeRegion(1080, 0, 300, 300, 1080, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 1920, 300, 300, 1080, 1920))
        // Completely beyond left or top edge
        assertNull(RegionCropGeometry.sanitizeRegion(-400, 0, 300, 300, 1080, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, -400, 300, 300, 1080, 1920))
    }

    @Test
    fun sanitizeRegionRejectsRegionSmallerThanMinimumDimension() {
        // 158 < 160 minDimension
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 158, 480, 1080, 1920, minDimension = 160))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, 158, 1080, 1920, minDimension = 160))
    }

    @Test
    fun sanitizeRegionRejectsInvalidDisplayDimensions() {
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, 480, 0, 1920))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, 480, 1080, 0))
        assertNull(RegionCropGeometry.sanitizeRegion(0, 0, 480, 480, -100, 1920))
    }

    @Test
    fun fromDpConvertsAndSanitizes() {
        val region = RegionCropGeometry.fromDp(
            dpX = 50f,
            dpY = 100f,
            dpWidth = 200f,
            dpHeight = 300f,
            density = 2.0f,
            displayWidth = 1080,
            displayHeight = 1920
        )
        assertNotNull(region)
        assertEquals(100, region!!.x)
        assertEquals(200, region.y)
        assertEquals(400, region.width)
        assertEquals(600, region.height)

        assertNull(RegionCropGeometry.fromDp(0f, 0f, 200f, 300f, 0f, 1080, 1920))
    }

    @Test
    fun normalizedCropCalculatesCorrectUvTextureCoordinates() {
        val rect = RegionCropGeometry.CropRect(x = 270, y = 480, width = 540, height = 960)
        val uv = RegionCropGeometry.normalizedCrop(rect, displayWidth = 1080, displayHeight = 1920)
        assertEquals(0.25f, uv.left, 0.001f)
        assertEquals(0.25f, uv.top, 0.001f)
        assertEquals(0.75f, uv.right, 0.001f)
        assertEquals(0.75f, uv.bottom, 0.001f)
    }

    @Test
    fun aspectRatioCalculatesAccurateRatio() {
        val rect = RegionCropGeometry.CropRect(x = 0, y = 0, width = 1280, height = 720)
        assertEquals(16.0 / 9.0, RegionCropGeometry.aspectRatio(rect), 0.001)

        val invalid = RegionCropGeometry.CropRect(x = 0, y = 0, width = 1280, height = 0)
        assertEquals(0.0, RegionCropGeometry.aspectRatio(invalid), 0.001)
    }

    @Test
    fun fitsDisplayValidatesBounds() {
        val inside = RegionCropGeometry.CropRect(x = 100, y = 100, width = 800, height = 1200)
        assertTrue(RegionCropGeometry.fitsDisplay(inside, 1080, 1920))

        val outsideRight = RegionCropGeometry.CropRect(x = 100, y = 100, width = 1000, height = 1200)
        assertFalse(RegionCropGeometry.fitsDisplay(outsideRight, 1080, 1920))

        val outsideNegative = RegionCropGeometry.CropRect(x = -10, y = 100, width = 500, height = 500)
        assertFalse(RegionCropGeometry.fitsDisplay(outsideNegative, 1080, 1920))
    }
}
