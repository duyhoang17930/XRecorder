package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class FacecamGeometryTest {

    @Test
    fun calculateRotationNormalizesDegreesProperly() {
        // Portrait (0 deg display): no rotation needed on TextureView
        assertEquals(0, FacecamGeometry.calculateRotation(0))
        assertEquals(0, FacecamGeometry.calculateRotation(270, 0))
        assertEquals(0, FacecamGeometry.calculateRotation(90, 0))

        // Landscape Left (90 deg display):
        // Rotation MUST be 270 deg (prevents upside down inverted head, ensures head is at top!)
        assertEquals(270, FacecamGeometry.calculateRotation(90, isFrontCamera = true))
        assertEquals(270, FacecamGeometry.calculateRotation(270, 90, isFrontCamera = true))
        assertEquals(270, FacecamGeometry.calculateRotation(90, 90, isFrontCamera = true))
        assertEquals(270, FacecamGeometry.calculateRotation(90, isFrontCamera = false))
        assertEquals(270, FacecamGeometry.calculateRotation(90, 90, isFrontCamera = false))

        // Reverse portrait (180 deg display): 180 deg rotation
        assertEquals(180, FacecamGeometry.calculateRotation(180))
        assertEquals(180, FacecamGeometry.calculateRotation(270, 180))
        assertEquals(180, FacecamGeometry.calculateRotation(90, 180))

        // Landscape Right (270 deg display):
        // Rotation MUST be 90 deg
        assertEquals(90, FacecamGeometry.calculateRotation(270, isFrontCamera = true))
        assertEquals(90, FacecamGeometry.calculateRotation(270, 270, isFrontCamera = true))
        assertEquals(90, FacecamGeometry.calculateRotation(90, 270, isFrontCamera = true))
        assertEquals(90, FacecamGeometry.calculateRotation(270, isFrontCamera = false))
        assertEquals(90, FacecamGeometry.calculateRotation(90, 270, isFrontCamera = false))

        // Return from Landscape to Portrait (0 deg display):
        assertEquals(0, FacecamGeometry.calculateRotation(270, 0, isFrontCamera = true))
        assertEquals(0, FacecamGeometry.calculateRotation(90, 0, isFrontCamera = false))

        // Negative display rotation
        assertEquals(90, FacecamGeometry.calculateRotation(-90, isFrontCamera = true))
        assertEquals(90, FacecamGeometry.calculateRotation(-90, isFrontCamera = false))
        // Multiple full rotations
        assertEquals(0, FacecamGeometry.calculateRotation(720))
    }

    @Test
    fun landscapeCenterCropFillsBothAxesWithoutStretchForBothDirectionsAndLenses() {
        // Validate the actual order in FacecamOverlay: rotate about center, THEN scale
        // in display axes. TextureView starts with sensor-corrected content fit to W/H.
        for (sensor in listOf(0, 90, 180, 270)) {
            for (display in listOf(0, 90, 180, 270)) {
                for (front in listOf(false, true)) {
                    for ((w, h) in listOf(110f to 147f, 147f to 110f, 180f to 110f)) {
                        val t = FacecamGeometry.calculateTransform(sensor, display, w, h, 640, 480, front)
                        val sensorSwaps = sensor % 180 == 90
                        val nativeW = if (sensorSwaps) 480f else 640f
                        val nativeH = if (sensorSwaps) 640f else 480f
                        val swaps = display % 180 == 90
                        val outputW = (if (swaps) h else w) * kotlin.math.abs(t.scaleX)
                        val outputH = (if (swaps) w else h) * t.scaleY
                        val contentW = if (swaps) nativeH else nativeW
                        val contentH = if (swaps) nativeW else nativeH
                        assertEquals("uniform pixel scale s=$sensor d=$display front=$front",
                            outputW / contentW, outputH / contentH, .0001f)
                        assertTrue("fill width", outputW >= w - .001f)
                        assertTrue("fill height", outputH >= h - .001f)
                        assertTrue("minimal center crop", kotlin.math.abs(outputW - w) < .001f ||
                            kotlin.math.abs(outputH - h) < .001f)
                        assertEquals(front, t.isMirrored)
                        assertEquals(front, t.scaleX < 0)
                        // TextureView handles sensor orientation: only display compensation remains.
                        assertEquals((360 - display) % 360, t.rotation)
                    }
                }
            }
        }
    }

    @Test
    fun canonicalSizeSurvivesBothLandscapesDuplicateCallbacksAndResize() {
        val portrait = 110 to 147
        for (scale in listOf(.75f, 1f, 1.5f, 1.75f)) {
            val (pw, ph) = FacecamGeometry.scaledDimensions(portrait.first, portrait.second, scale)
            for (display in listOf(0, 90, 90, 270, 270, 180, 0, 0)) {
                val expected = if (display % 180 == 90) ph to pw else pw to ph
                assertEquals(expected, FacecamGeometry.targetDimensions(portrait.first, portrait.second, scale, display))
            }
        }
    }

    @Test
    fun normalizedDraggedPositionSurvivesResizeAndRoundTripsWithoutDrift() {
        val x = FacecamGeometry.positionFraction(613, 1080, 110)
        val y = FacecamGeometry.positionFraction(1793, 2200, 147)
        repeat(20) {
            val lx = FacecamGeometry.positionFromFraction(x, 2200, 147)
            val ly = FacecamGeometry.positionFromFraction(y, 1080, 110)
            assertTrue(lx in 0..2053)
            assertTrue(ly in 0..970)
            assertEquals(x, FacecamGeometry.positionFraction(lx, 2200, 147), .001f)
            assertEquals(y, FacecamGeometry.positionFraction(ly, 1080, 110), .001f)
            assertEquals(613, FacecamGeometry.positionFromFraction(x, 1080, 110))
            assertEquals(1793, FacecamGeometry.positionFromFraction(y, 2200, 147))
        }
        assertEquals(0, FacecamGeometry.positionFromFraction(x, 100, 147))
        assertEquals(0f, FacecamGeometry.positionFraction(50, 100, 147), 0f)
        assertEquals(0, FacecamGeometry.positionFromFraction(-1f, 1080, 110))
        assertEquals(970, FacecamGeometry.positionFromFraction(2f, 1080, 110))
    }

    @Test
    fun orientationCycleHasNoAccumulatedRotation() {
        // Simulate changing orientation multiple times: Portrait -> LandLeft -> LandRight -> Portrait
        val rot1 = FacecamGeometry.calculateRotation(0)
        val rot2 = FacecamGeometry.calculateRotation(90)
        val rot3 = FacecamGeometry.calculateRotation(270)
        val rot4 = FacecamGeometry.calculateRotation(0)
        assertEquals(0, rot1)
        assertEquals(270, rot2)
        assertEquals(90, rot3)
        assertEquals(0, rot4)
    }

    @Test
    fun testRequired12MatrixAndOrientationCombinations() {
        // 1. Sensor 90°, display 0° (Back camera portrait)
        val s90d0 = FacecamGeometry.calculateTransform(sensorOrientation = 90, displayRotationDegrees = 0, viewWidth = 110f, viewHeight = 147f, isFrontCamera = false)
        assertEquals(0, s90d0.rotation)
        assertFalse(s90d0.isMirrored)
        assertTrue(s90d0.scaleX > 0)

        // 2. Sensor 90°, display 90° (Back camera Landscape Left)
        val s90d90 = FacecamGeometry.calculateTransform(sensorOrientation = 90, displayRotationDegrees = 90, viewWidth = 110f, viewHeight = 147f, isFrontCamera = false)
        assertEquals(270, s90d90.rotation)
        assertFalse(s90d90.isMirrored)
        assertTrue(s90d90.scaleX > 0)

        // 3. Sensor 90°, display 270° (Back camera Landscape Right)
        val s90d270 = FacecamGeometry.calculateTransform(sensorOrientation = 90, displayRotationDegrees = 270, viewWidth = 110f, viewHeight = 147f, isFrontCamera = false)
        assertEquals(90, s90d270.rotation)
        assertFalse(s90d270.isMirrored)
        assertTrue(s90d270.scaleX > 0)

        // 4. Sensor 270°, display 0° (Front camera portrait)
        val s270d0 = FacecamGeometry.calculateTransform(sensorOrientation = 270, displayRotationDegrees = 0, viewWidth = 110f, viewHeight = 147f, isFrontCamera = true)
        assertEquals(0, s270d0.rotation)
        assertTrue(s270d0.isMirrored)
        assertTrue(s270d0.scaleX < 0)

        // 5. Sensor 270°, display 90° (Front camera Landscape Left)
        val s270d90 = FacecamGeometry.calculateTransform(sensorOrientation = 270, displayRotationDegrees = 90, viewWidth = 110f, viewHeight = 147f, isFrontCamera = true)
        assertEquals(270, s270d90.rotation)
        assertTrue(s270d90.isMirrored)
        assertTrue(s270d90.scaleX < 0)

        // 6. Sensor 270°, display 270° (Front camera Landscape Right)
        val s270d270 = FacecamGeometry.calculateTransform(sensorOrientation = 270, displayRotationDegrees = 270, viewWidth = 110f, viewHeight = 147f, isFrontCamera = true)
        assertEquals(90, s270d270.rotation)
        assertTrue(s270d270.isMirrored)
        assertTrue(s270d270.scaleX < 0)

        // 7. Portrait -> Landscape Right -> Portrait
        assertEquals(0, FacecamGeometry.calculateRotation(0))
        assertEquals(90, FacecamGeometry.calculateRotation(270))
        assertEquals(0, FacecamGeometry.calculateRotation(0))

        // 8. Portrait -> Landscape Left -> Portrait
        assertEquals(0, FacecamGeometry.calculateRotation(0))
        assertEquals(270, FacecamGeometry.calculateRotation(90))
        assertEquals(0, FacecamGeometry.calculateRotation(0))

        // 9. Landscape Right -> Landscape Left
        assertEquals(90, FacecamGeometry.calculateRotation(270))
        assertEquals(270, FacecamGeometry.calculateRotation(90))

        // 10. No accumulated rotation (pure function of target display degrees)
        for (i in 0 until 5) {
            assertEquals(270, FacecamGeometry.calculateRotation(90))
            assertEquals(90, FacecamGeometry.calculateRotation(270))
        }

        // 11. Mirroring independent from rotation
        val frontTrans = FacecamGeometry.calculateTransform(displayRotationDegrees = 90, viewWidth = 110f, viewHeight = 147f, isFrontCamera = true)
        val backTrans = FacecamGeometry.calculateTransform(displayRotationDegrees = 90, viewWidth = 110f, viewHeight = 147f, isFrontCamera = false)
        assertEquals(frontTrans.rotation, backTrans.rotation)
        assertTrue(frontTrans.scaleX < 0)
        assertTrue(backTrans.scaleX > 0)
        assertEquals(kotlin.math.abs(frontTrans.scaleX), backTrans.scaleX, 0.001f)

        // 12. Sensor-corrected aspect: Portrait 480/640; Landscape 640/480.
        val portraitRatio = (110f * kotlin.math.abs(s270d0.scaleX)) / (147f * s270d0.scaleY)
        val landscapeRatio = (147f * kotlin.math.abs(s270d90.scaleX)) / (110f * s270d90.scaleY)
        assertEquals(0.75f, portraitRatio, 0.005f)
        assertEquals(640f / 480f, landscapeRatio, 0.005f)
    }

    @Test
    fun calculateTransformPortraitFrontAndBackCamera() {
        // Front camera at 0 degree display rotation (Portrait):
        // Rotation MUST be 0 (never 270 or 90 to prevent sideways face orientation!)
        // Front camera MUST be mirrored (scaleX negative)
        val frontPortrait = FacecamGeometry.calculateTransform(
            sensorOrientation = 270,
            displayRotationDegrees = 0,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = true
        )
        assertEquals(0, frontPortrait.rotation)
        assertTrue(frontPortrait.isMirrored)
        // With view 110x147 and 480x640 content, center crop scales width by ~1.00227
        assertTrue(frontPortrait.scaleX < 0)
        assertEquals(-1.00227f, frontPortrait.scaleX, 0.005f)
        assertEquals(1.0f, frontPortrait.scaleY, 0.001f)

        // Back camera at 0 degree display rotation (Portrait):
        // Rotation MUST be 0, NOT mirrored (scaleX positive)
        val backPortrait = FacecamGeometry.calculateTransform(
            sensorOrientation = 90,
            displayRotationDegrees = 0,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = false
        )
        assertEquals(0, backPortrait.rotation)
        assertFalse(backPortrait.isMirrored)
        assertTrue(backPortrait.scaleX > 0)
        assertEquals(1.00227f, backPortrait.scaleX, 0.005f)
        assertEquals(1.0f, backPortrait.scaleY, 0.001f)
    }

    @Test
    fun calculateTransformLandscapeAndUpsideDown() {
        // Front camera at 90 deg display rotation (Landscape Left):
        // Rotation MUST be 270 (never 90 to prevent upside down face orientation!)
        val front90 = FacecamGeometry.calculateTransform(
            sensorOrientation = 270,
            displayRotationDegrees = 90,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = true
        )
        assertEquals(270, front90.rotation)
        assertTrue(front90.isMirrored)
        assertTrue(front90.scaleX < 0)

        // Back camera at 90 deg display rotation (Landscape Left)
        val back90 = FacecamGeometry.calculateTransform(
            sensorOrientation = 90,
            displayRotationDegrees = 90,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = false
        )
        assertEquals(270, back90.rotation)
        assertFalse(back90.isMirrored)
        assertTrue(back90.scaleX > 0)

        // Front camera at 270 deg display rotation (Landscape Right):
        // Rotation MUST be 90 (never 270 to prevent upside down face orientation!)
        val front270 = FacecamGeometry.calculateTransform(
            sensorOrientation = 270,
            displayRotationDegrees = 270,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = true
        )
        assertEquals(90, front270.rotation)
        assertTrue(front270.isMirrored)
        assertTrue(front270.scaleX < 0)

        // Back camera at 270 deg display rotation (Landscape Right)
        val back270 = FacecamGeometry.calculateTransform(
            sensorOrientation = 90,
            displayRotationDegrees = 270,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = false
        )
        assertEquals(90, back270.rotation)
        assertFalse(back270.isMirrored)
        assertTrue(back270.scaleX > 0)

        // Front camera at 180 deg display rotation (Upside down)
        val front180 = FacecamGeometry.calculateTransform(
            sensorOrientation = 270,
            displayRotationDegrees = 180,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = true
        )
        assertEquals(180, front180.rotation)
        assertTrue(front180.isMirrored)
    }

    @Test
    fun calculateTransformZeroOrInvalidDimensionsFallbacksSafely() {
        // Zero or negative view dimensions should not cause division by zero or NaN
        val zeroView = FacecamGeometry.calculateTransform(
            viewWidth = 0f,
            viewHeight = 0f,
            isFrontCamera = true
        )
        assertEquals(0, zeroView.rotation)
        assertEquals(-1.0f, zeroView.scaleX, 0.001f)
        assertEquals(1.0f, zeroView.scaleY, 0.001f)

        // Zero preview dimensions should safely fallback to default 640x480
        val zeroPreview = FacecamGeometry.calculateTransform(
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 0,
            previewHeight = 0,
            isFrontCamera = true
        )
        assertFalse(zeroPreview.scaleX.isNaN())
        assertFalse(zeroPreview.scaleY.isNaN())
        assertFalse(zeroPreview.scaleX.isInfinite())
        assertFalse(zeroPreview.scaleY.isInfinite())
    }

    @Test
    fun clampScaleValidatesNormalAndBoundaryValues() {
        assertEquals(1.0f, FacecamGeometry.clampScale(1.0f), 0.001f)
        assertEquals(FacecamGeometry.MIN_SCALE, FacecamGeometry.clampScale(0.5f), 0.001f)
        assertEquals(FacecamGeometry.MAX_SCALE, FacecamGeometry.clampScale(2.5f), 0.001f)

        // Fallbacks for invalid inputs
        assertEquals(FacecamGeometry.DEFAULT_SCALE, FacecamGeometry.clampScale(null), 0.001f)
        assertEquals(FacecamGeometry.DEFAULT_SCALE, FacecamGeometry.clampScale(Float.NaN), 0.001f)
        assertEquals(FacecamGeometry.DEFAULT_SCALE, FacecamGeometry.clampScale(0f), 0.001f)
        assertEquals(FacecamGeometry.DEFAULT_SCALE, FacecamGeometry.clampScale(-1.0f), 0.001f)
    }

    @Test
    fun scaledDimensionsComputesPixelSizesWithClamping() {
        val (w1, h1) = FacecamGeometry.scaledDimensions(110, 147, 1.0f)
        assertEquals(110, w1)
        assertEquals(147, h1)

        val (w15, h15) = FacecamGeometry.scaledDimensions(110, 147, 1.5f)
        assertEquals(165, w15)
        assertEquals(221, h15)

        val (wMin, hMin) = FacecamGeometry.scaledDimensions(10, 10, 0.5f)
        assertEquals(32, wMin)
        assertEquals(32, hMin)
    }

    @Test
    fun clampPositionKeepsFacecamWithinScreenBounds() {
        val screenW = 1080
        val screenH = 2400
        val viewW = 200
        val viewH = 300

        // In bounds
        val (x1, y1) = FacecamGeometry.clampPosition(50, 100, screenW, screenH, viewW, viewH)
        assertEquals(50, x1)
        assertEquals(100, y1)

        // Right/bottom overflow
        val (xOver, yOver) = FacecamGeometry.clampPosition(1200, 2500, screenW, screenH, viewW, viewH)
        assertEquals(880, xOver) // 1080 - 200
        assertEquals(2100, yOver) // 2400 - 300

        // Negative coordinates
        val (xNeg, yNeg) = FacecamGeometry.clampPosition(-50, -100, screenW, screenH, viewW, viewH)
        assertEquals(0, xNeg)
        assertEquals(0, yNeg)
    }

    @Test
    fun snapToEdgeSnapsToLeftOrRightScreenEdge() {
        val screenW = 1080
        val viewW = 200
        val maxX = 880

        // Closer to left edge
        assertEquals(0, FacecamGeometry.snapToEdge(100, screenW, viewW))
        assertEquals(0, FacecamGeometry.snapToEdge(400, screenW, viewW))

        // Closer to right edge
        assertEquals(maxX, FacecamGeometry.snapToEdge(500, screenW, viewW))
        assertEquals(maxX, FacecamGeometry.snapToEdge(800, screenW, viewW))
    }

    @Test
    fun validateEffectAndNames() {
        for (effect in 0..8) {
            assertEquals(effect, FacecamGeometry.validateEffect(effect))
            assertNotNull(FacecamGeometry.effectName(effect))
            assertNotEquals("Normal", FacecamGeometry.effectName(FacecamGeometry.EFFECT_MONO))
        }

        // Invalid effect modes fall back to EFFECT_OFF (0)
        assertEquals(FacecamGeometry.EFFECT_OFF, FacecamGeometry.validateEffect(null))
        assertEquals(FacecamGeometry.EFFECT_OFF, FacecamGeometry.validateEffect(-1))
        assertEquals(FacecamGeometry.EFFECT_OFF, FacecamGeometry.validateEffect(99))
    }

    @Test
    fun toggleFacingAlternatesFrontAndBack() {
        assertEquals(FacecamGeometry.LENS_FACING_BACK, FacecamGeometry.toggleFacing(FacecamGeometry.LENS_FACING_FRONT))
        assertEquals(FacecamGeometry.LENS_FACING_FRONT, FacecamGeometry.toggleFacing(FacecamGeometry.LENS_FACING_BACK))
    }

    @Test
    fun canAcceptActionValidatesStatesAndEnding() {
        for (action in listOf("switchCamera", "setEffect", "setScale", "reposition", "getState")) {
            assertTrue(FacecamGeometry.canAcceptAction(action, isEnding = false, currentState = "recording"))
            assertTrue(FacecamGeometry.canAcceptAction(action, isEnding = false, currentState = "paused"))

            // Reject when ending
            assertFalse(FacecamGeometry.canAcceptAction(action, isEnding = true, currentState = "recording"))

            // Reject in other states
            for (s in listOf("idle", "countdown", "stopping", "finalizing", "completed", "failed")) {
                assertFalse(FacecamGeometry.canAcceptAction(action, isEnding = false, currentState = s))
            }
        }
    }
}
