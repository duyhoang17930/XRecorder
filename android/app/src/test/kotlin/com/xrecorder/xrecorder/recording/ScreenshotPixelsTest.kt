package com.xrecorder.xrecorder.recording

import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class ScreenshotPixelsTest {
    private fun bytes(buffer: ByteBuffer) = ByteArray(buffer.remaining()).also { buffer.get(it) }

    @Test fun stripsRowPaddingWithoutRequiringPaddingAfterLastRow() {
        val source = ByteBuffer.wrap(byteArrayOf(1,2,3,4,5,6,7,8,99,99,99,99,9,10,11,12,13,14,15,16))
        val actual = ScreenshotPixels.packedRgba(source,2,2,4,12)
        assertArrayEquals(ByteArray(16) { (it + 1).toByte() }, bytes(actual))
        assertEquals(0, source.position())
        assertEquals(20, source.limit())
    }
    @Test fun contiguousRowsHonorBufferPositionAndIgnoreTrailingBytes() {
        val source = ByteBuffer.wrap(byteArrayOf(99,99,1,2,3,4,5,6,7,8,99))
        source.position(2)
        val actual = ScreenshotPixels.packedRgba(source,1,2,4,4)
        assertArrayEquals(byteArrayOf(1,2,3,4,5,6,7,8), bytes(actual))
        assertEquals(2, source.position())
    }
    @Test fun incompleteOrInvalidPlanesAreRejectedBeforeBitmapOrOutputCreation() {
        for ((width,height,pixelStride,rowStride) in listOf(
            listOf(2,2,4,12), listOf(0,1,4,4), listOf(1,-1,4,4),
            listOf(1,1,2,4), listOf(2,1,4,4), listOf(Int.MAX_VALUE,2,4,Int.MAX_VALUE)
        )) {
            assertThrows(IllegalArgumentException::class.java) {
                ScreenshotPixels.packedRgba(ByteBuffer.allocate(4),width,height,pixelStride,rowStride)
            }
        }
    }
    @Test fun samePackingHandlesPortraitAndLandscapeRows() {
        for ((width,height) in listOf(2 to 3,3 to 2)) {
            val rowBytes = width * 4
            val stride = rowBytes + 4
            val source = ByteBuffer.allocate((height - 1) * stride + rowBytes)
            val expected = ByteArray(width * height * 4) { (it + 1).toByte() }
            for (row in 0 until height) {
                source.position(row * stride)
                source.put(expected,row * rowBytes,rowBytes)
            }
            source.rewind()
            assertArrayEquals(expected, bytes(ScreenshotPixels.packedRgba(source,width,height,4,stride)))
        }
    }
}
