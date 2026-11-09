package com.xrecorder.xrecorder.editor

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.BufferedOutputStream
import java.io.File
import java.io.OutputStream
import kotlin.math.roundToInt

/** Bounded GIF89a writer, RGB332 palette and fixed-width LZW runs. No third-party encoder. */
object GifWriter {
    fun write(
        video: File,
        durationUs: Long,
        out: OutputStream,
        fps: Int = 10,
        maxEdge: Int = 320,
        repeats: Int = 0,
    ) {
        require(durationUs in 200_000..15_000_000) { "GIF export is limited to 15 seconds" }
        require(fps in listOf(5, 10, 20) && maxEdge in listOf(160, 320, 480) && repeats in 0..20)

        val intervalUs = 1_000_000L / fps
        val reader = MediaMetadataRetriever()
        val buffered = BufferedOutputStream(out, 64 * 1024)
        fun word(value: Int) {
            buffered.write(value and 255)
            buffered.write(value shr 8 and 255)
        }

        fun frameAt(timeUs: Long): Bitmap? =
            if (Build.VERSION.SDK_INT >= 27) {
                reader.getScaledFrameAtTime(
                    timeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                    maxEdge,
                    maxEdge,
                )
            } else {
                reader.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
            }

        try {
            reader.setDataSource(video.absolutePath)
            val first = frameAt(0) ?: error("Cannot decode GIF frames")
            val scale = minOf(1.0, maxEdge.toDouble() / maxOf(first.width, first.height))
            val width = (first.width * scale).roundToInt().coerceAtLeast(1)
            val height = (first.height * scale).roundToInt().coerceAtLeast(1)
            first.recycle()

            buffered.write("GIF89a".toByteArray())
            word(width)
            word(height)
            buffered.write(byteArrayOf(0xf7.toByte(), 0, 0))
            for (index in 0..255) {
                buffered.write(((index shr 5) and 7) * 255 / 7)
                buffered.write(((index shr 2) and 7) * 255 / 7)
                buffered.write((index and 3) * 255 / 3)
            }
            buffered.write(byteArrayOf(0x21, 0xff.toByte(), 11))
            buffered.write("NETSCAPE2.0".toByteArray())
            buffered.write(byteArrayOf(3, 1))
            word(repeats)
            buffered.write(0)

            var timeUs = 0L
            while (timeUs < durationUs) {
                val frame = frameAt(timeUs) ?: error("Cannot decode GIF frame")
                val scaled =
                    if (frame.width == width && frame.height == height) frame
                    else Bitmap.createScaledBitmap(frame, width, height, true)
                val pixels = IntArray(width * height)
                scaled.getPixels(pixels, 0, width, 0, 0, width, height)
                if (scaled !== frame) scaled.recycle()
                frame.recycle()

                buffered.write(byteArrayOf(0x21, 0xf9.toByte(), 4, 4))
                word(((minOf(intervalUs, durationUs - timeUs) + 9_999) / 10_000).toInt())
                buffered.write(byteArrayOf(0, 0))
                buffered.write(0x2c)
                word(0)
                word(0)
                word(width)
                word(height)
                buffered.write(0)
                buffered.write(8)

                val bytes = java.io.ByteArrayOutputStream()
                var bits = 0
                var bitCount = 0
                fun code(value: Int) {
                    bits = bits or (value shl bitCount)
                    bitCount += 9
                    while (bitCount >= 8) {
                        bytes.write(bits and 255)
                        bits = bits ushr 8
                        bitCount -= 8
                    }
                }

                var run = 0
                code(256)
                for (pixel in pixels) {
                    if (run == 200) {
                        code(256)
                        run = 0
                    }
                    code(
                        ((pixel shr 16 and 255) shr 5 shl 5) or
                            ((pixel shr 8 and 255) shr 5 shl 2) or
                            ((pixel and 255) shr 6),
                    )
                    run++
                }
                code(257)
                if (bitCount > 0) bytes.write(bits and 255)
                val data = bytes.toByteArray()
                var offset = 0
                while (offset < data.size) {
                    val size = minOf(255, data.size - offset)
                    buffered.write(size)
                    buffered.write(data, offset, size)
                    offset += size
                }
                buffered.write(0)
                timeUs += intervalUs
            }
            buffered.write(0x3b)
            buffered.flush()
        } finally {
            reader.release()
        }
    }
}
