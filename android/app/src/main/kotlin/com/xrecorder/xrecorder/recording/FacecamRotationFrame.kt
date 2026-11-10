package com.xrecorder.xrecorder.recording

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/** Uniform camera-pixel scale, fixed mirror and continuous rotation in Display coordinates. */
internal data class FacecamRotationFrame(
    val width: Int,
    val height: Int,
    val nativeWidth: Int,
    val nativeHeight: Int,
    val mirrored: Boolean
) {
    data class Scale(val x: Float, val y: Float)

    fun scaleAt(angle: Float): Scale {
        val radians = Math.toRadians(angle.toDouble())
        val c = abs(cos(radians)).toFloat()
        val s = abs(sin(radians)).toFloat()
        // Inverse-rotate viewport corners into the camera rectangle. This covers ALL
        // corners during rotation, not just the bounding box, without black triangles.
        val fill = max((width * c + height * s) / nativeWidth,
            (width * s + height * c) / nativeHeight)
        return Scale(fill * nativeWidth / width * (if (mirrored) -1f else 1f),
            fill * nativeHeight / height)
    }

    companion object {
        // Equivalent to R(P-D) * mirror * R(-P), including non-cardinal physical angles.
        fun targetAngle(physical: Int, display: Int, mirrored: Boolean): Float =
            targetAngle(physical.toFloat(), display, mirrored)

        fun targetAngle(physical: Float, display: Int, mirrored: Boolean): Float =
            if (mirrored) 2 * physical - display else -display.toFloat()
    }
}
