package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class FacecamRotationFrameTest {
    @Test
    fun continuousAnglesAreNotQuantizedOrRewrappedBetweenTurns() {
        for (physical in listOf(10f, 30f, 45f, 60f, 179.5f, 180.5f, 359f, 360f, 361f, 720f)) {
            assertEquals(2 * physical - 90, FacecamRotationFrame.targetAngle(physical, 90, true), 0f)
            assertEquals(-90f, FacecamRotationFrame.targetAngle(physical, 90, false), 0f)
        }
    }

    @Test
    fun nonCardinalPosesKeepGravityUprightAndMirrorInPhysicalCoordinates() {
        for (display in listOf(0, 90, 180, 270)) {
            for (physical in listOf(10f, 30f, 45.5f, 60f, 179.5f, 180.5f, 359f, 360f, 361f, 720f)) {
                for (mirror in listOf(false, true)) {
                    val (w, h) = FacecamGeometry.targetDimensions(110, 147, 1.25f, display)
                    val frame = FacecamRotationFrame(w, h, 480, 640, mirror)
                    val angle = FacecamRotationFrame.targetAngle(physical, display, mirror)
                    val scale = frame.scaleAt(angle)
                    for ((x, y) in listOf(0f to -1f, 1f to 0f)) {
                        val natural = rotate(x, y, physical)
                        val actual = rotate(natural.first * w / 480 * scale.x,
                            natural.second * h / 640 * scale.y, angle)
                        val expected = rotate(if (mirror) -x else x, y, physical - display)
                        val length = kotlin.math.hypot(actual.first, actual.second)
                        assertEquals(expected.first, actual.first / length, .0001f)
                        assertEquals(expected.second, actual.second / length, .0001f)
                    }
                }
            }
        }
    }

    @Test
    fun intermediateFramesUseUniformPixelScaleKeepMirrorAndCoverEveryViewportCorner() {
        for ((w, h) in listOf(110 to 147, 147 to 110, 165 to 221)) {
            for (mirror in listOf(false, true)) {
                val frame = FacecamRotationFrame(w, h, 480, 640, mirror)
                for (angle in 0..360 step 5) {
                    val scale = frame.scaleAt(angle.toFloat())
                    val fill = abs(scale.x) * w / 480
                    assertEquals(fill, scale.y * h / 640, .0001f)
                    assertEquals(mirror, scale.x < 0)
                    for (x in listOf(-w / 2f, w / 2f)) {
                        for (y in listOf(-h / 2f, h / 2f)) {
                            val (cx, cy) = rotate(x, y, -angle.toFloat())
                            assertTrue(abs(cx / fill) <= 240f + .001f)
                            assertTrue(abs(cy / fill) <= 320f + .001f)
                        }
                    }
                }
            }
        }
    }

    @Test
    fun animationEndpointsMatchExistingLockedOrientationTransformForBothLenses() {
        for (sensor in listOf(0, 90, 180, 270)) {
            for (display in listOf(0, 90, 180, 270)) {
                for (physical in listOf(0, 90, 180, 270)) {
                    for (front in listOf(false, true)) {
                        val (w, h) = FacecamGeometry.targetDimensions(110, 147, 1.25f, display)
                        val old = FacecamGeometry.calculatePhysicalTransform(sensor, display, physical,
                            w.toFloat(), h.toFloat(), 640, 480, front)
                        val frame = FacecamRotationFrame(w, h,
                            if (sensor % 180 == 90) 480 else 640,
                            if (sensor % 180 == 90) 640 else 480, front)
                        val angle = FacecamRotationFrame.targetAngle(physical, display, front)
                        val scale = frame.scaleAt(angle)
                        // Compare the full two basis vectors, not just width/height or angles.
                        for ((x, y) in listOf(1f to 0f, 0f to 1f)) {
                            val (rx, ry) = rotate(x * old.inputScaleX, y * old.inputScaleY,
                                old.content.rotation.toFloat())
                            val expected = rotate(rx * old.content.scaleX, ry * old.content.scaleY,
                                old.coordinateRotation.toFloat())
                            val actual = rotate(x * scale.x, y * scale.y, angle)
                            assertEquals(expected.first, actual.first, .0001f)
                            assertEquals(expected.second, actual.second, .0001f)
                        }
                    }
                }
            }
        }
    }

    private fun rotate(x: Float, y: Float, angle: Float): Pair<Float, Float> {
        val radians = Math.toRadians(angle.toDouble())
        return (x * cos(radians) - y * sin(radians)).toFloat() to
            (x * sin(radians) + y * cos(radians)).toFloat()
    }
}
