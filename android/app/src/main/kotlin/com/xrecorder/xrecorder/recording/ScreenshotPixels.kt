package com.xrecorder.xrecorder.recording

import java.nio.ByteBuffer

/** Validates and packs ImageReader RGBA rows; final-row padding need not be present. */
internal object ScreenshotPixels {
    fun packedRgba(source: ByteBuffer, width: Int, height: Int, pixelStride: Int, rowStride: Int): ByteBuffer {
        require(width > 0 && height > 0 && pixelStride == 4) { "Invalid RGBA screenshot dimensions/stride" }
        val rowBytes = width.toLong() * 4
        val size = rowBytes * height
        require(size <= Int.MAX_VALUE && rowStride >= rowBytes) { "Invalid screenshot row size" }
        val required = (height - 1).toLong() * rowStride + rowBytes
        require(source.remaining().toLong() >= required) { "Incomplete screenshot frame" }
        val rows = source.slice()
        if (rowStride.toLong() == rowBytes) {
            rows.limit(size.toInt())
            return rows
        }
        val packed = ByteBuffer.allocate(size.toInt())
        repeat(height) { row ->
            val offset = row * rowStride
            rows.limit(offset + rowBytes.toInt()); rows.position(offset)
            packed.put(rows)
        }
        packed.flip()
        return packed
    }
}
