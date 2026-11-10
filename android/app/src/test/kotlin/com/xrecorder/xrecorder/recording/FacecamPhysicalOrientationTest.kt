package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/** Geometry only; these tests do not stand in for live camera/MediaProjection verification. */
class FacecamPhysicalOrientationTest {
    @Test
    fun listenerAnglesUseSurfaceConventionAndRetainUnknownPose() {
        assertEquals(0, FacecamGeometry.physicalRotation(0, null))
        // Android: left edge at the top = listener 90, Surface.ROTATION_270.
        assertEquals(270, FacecamGeometry.physicalRotation(90, null))
        assertEquals(180, FacecamGeometry.physicalRotation(180, null))
        assertEquals(90, FacecamGeometry.physicalRotation(270, null))
        assertNull(FacecamGeometry.physicalRotation(-1, null))
        assertEquals(270, FacecamGeometry.physicalRotation(-1, 270))
        assertEquals(0, FacecamGeometry.physicalRotation(359, 0))
    }

    @Test
    fun hysteresisRejectsBoundaryNoiseInBothDirectionsIncludingWraparound() {
        for (pose in listOf(0, 90, 180, 270)) {
            for (offset in listOf(-59, -46, -45, -44, 0, 44, 45, 46, 59)) {
                val listener = (360 - pose - offset + 720) % 360
                assertEquals(pose, FacecamGeometry.physicalRotation(listener, pose))
            }
            assertEquals((pose + 90) % 360,
                FacecamGeometry.physicalRotation((360 - pose - 60 + 720) % 360, pose))
            assertEquals((pose + 270) % 360,
                FacecamGeometry.physicalRotation((360 - pose + 60 + 720) % 360, pose))
        }
        var pose: Int? = null
        for (expected in listOf(0, 90, 90, 270, 270, 180, 0, 0)) {
            pose = FacecamGeometry.physicalRotation((360 - expected) % 360, pose)
            assertEquals(expected, pose)
        }
    }

    @Test
    fun matchingPhysicalAndDisplayPosePreservesExistingTransform() {
        for (degrees in listOf(0, 90, 180, 270)) {
            val (w, h) = FacecamGeometry.targetDimensions(110, 147, 1f, degrees)
            for (front in listOf(false, true)) {
                val existing = FacecamGeometry.calculateTransform(270, degrees, w.toFloat(), h.toFloat(), 640, 480, front)
                val updated = FacecamGeometry.calculatePhysicalTransform(270, degrees, degrees,
                    w.toFloat(), h.toFloat(), 640, 480, front)
                assertEquals(existing, updated.content)
                assertEquals(1f, updated.inputScaleX, 0f)
                assertEquals(1f, updated.inputScaleY, 0f)
                assertEquals(0, updated.coordinateRotation)
            }
        }
    }

    @Test
    fun lockedDisplayMatrixKeepsGravityUprightMirrorHorizontalAndPixelsUniform() {
        // Includes all seven requested lock/physical combinations, both landscape directions,
        // both lenses, four sensor orientations and user resize; no camera hardware is mocked.
        for (display in listOf(0, 90, 180, 270)) {
            for (physical in listOf(0, 90, 180, 270)) {
                for (front in listOf(false, true)) {
                    for (sensor in listOf(0, 90, 180, 270)) {
                        for (scale in listOf(.75f, 1f, 1.75f)) {
                            val (w, h) = FacecamGeometry.targetDimensions(110, 147, scale, display)
                            val t = FacecamGeometry.calculatePhysicalTransform(sensor, display, physical,
                                w.toFloat(), h.toFloat(), 640, 480, front)
                            val nativeW = if (sensor % 180 == 90) 480f else 640f
                            val nativeH = if (sensor % 180 == 90) 640f else 480f
                            fun map(v: Vector): Vector {
                                // TextureView first fits the sensor-corrected buffer to its bounds.
                                val fitted = Vector(v.x * w / nativeW, v.y * h / nativeH)
                                val input = Vector(fitted.x * t.inputScaleX, fitted.y * t.inputScaleY)
                                val rotated = input.rotate(t.content.rotation)
                                return Vector(rotated.x * t.content.scaleX, rotated.y * t.content.scaleY)
                                    .rotate(t.coordinateRotation)
                            }
                            // Gravity in sensor-corrected natural coordinates, independent of lock.
                            val head = map(Vector(0f, -1f).rotate(physical))
                            val expectedHead = Vector(0f, -1f).rotate(physical - display)
                            assertDirection(expectedHead, head)
                            val right = map(Vector(1f, 0f).rotate(physical))
                            val expectedRight = Vector(if (front) -1f else 1f, 0f).rotate(physical - display)
                            assertDirection(expectedRight, right)
                            val x = map(Vector(1f, 0f))
                            val y = map(Vector(0f, 1f))
                            assertEquals(x.length(), y.length(), .0001f)
                            assertEquals(0f, x.x * y.x + x.y * y.y, .0001f)
                            val outputW = abs(x.x) * nativeW + abs(y.x) * nativeH
                            val outputH = abs(x.y) * nativeW + abs(y.y) * nativeH
                            assertTrue(outputW >= w - .001f)
                            assertTrue(outputH >= h - .001f)
                            assertTrue(abs(outputW - w) < .001f || abs(outputH - h) < .001f)
                            val physicalSize = FacecamGeometry.targetDimensions(110, 147, scale, physical)
                            assertEquals(physicalSize.first.toFloat(), w * t.inputScaleX, .001f)
                            assertEquals(physicalSize.second.toFloat(), h * t.inputScaleY, .001f)
                        }
                    }
                }
            }
        }
    }

    private fun assertDirection(expected: Vector, actual: Vector) {
        assertEquals(expected.x, actual.x / actual.length(), .0001f)
        assertEquals(expected.y, actual.y / actual.length(), .0001f)
    }

    private data class Vector(val x: Float, val y: Float) {
        fun length() = hypot(x, y)
        fun rotate(degrees: Int): Vector {
            val radians = Math.toRadians(degrees.toDouble())
            return Vector((x * cos(radians) - y * sin(radians)).toFloat(),
                (x * sin(radians) + y * cos(radians)).toFloat())
        }
    }
}
