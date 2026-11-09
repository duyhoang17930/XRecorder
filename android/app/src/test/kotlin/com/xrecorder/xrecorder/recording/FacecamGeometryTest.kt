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
    fun orientationMatrixPreservesAspectRatiosAndNo180Flip() {
        // Landscape Left (90 deg display) - Front Camera:
        val front90 = FacecamGeometry.calculateTransform(
            sensorOrientation = 270,
            displayRotationDegrees = 90,
            viewWidth = 110f,
            viewHeight = 147f,
            previewWidth = 640,
            previewHeight = 480,
            isFrontCamera = true
        )
        // Rotation MUST be 270 (not 90) to ensure head at top and body at bottom
        assertEquals(270, front90.rotation)
        assertTrue(front90.isMirrored)
        assertTrue(front90.scaleX < 0)
        // Effective on-screen aspect ratio must be 110.25 / 147 = 0.75 (matching 480/640)
        val onScreenWidth90 = 147f * kotlin.math.abs(front90.scaleX)
        val onScreenHeight90 = 110f * front90.scaleY
        assertEquals(110.25f, onScreenWidth90, 0.1f)
        assertEquals(147.0f, onScreenHeight90, 0.1f)
        assertEquals(0.75f, onScreenWidth90 / onScreenHeight90, 0.001f)

        // Landscape Right (270 deg display) - Front Camera:
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
        val onScreenWidth270 = 147f * kotlin.math.abs(front270.scaleX)
        val onScreenHeight270 = 110f * front270.scaleY
        assertEquals(110.25f, onScreenWidth270, 0.1f)
        assertEquals(147.0f, onScreenHeight270, 0.1f)
        assertEquals(0.75f, onScreenWidth270 / onScreenHeight270, 0.001f)
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

        // 12. Aspect ratio preservation: natural 0.75 ratio on screen in both portrait and landscape
        val portraitRatio = (110f * kotlin.math.abs(s270d0.scaleX)) / (147f * s270d0.scaleY)
        val landscapeRatio = (147f * kotlin.math.abs(s270d90.scaleX)) / (110f * s270d90.scaleY)
        assertEquals(0.75f, portraitRatio, 0.005f)
        assertEquals(0.75f, landscapeRatio, 0.005f)
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
