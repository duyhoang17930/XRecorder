package com.xrecorder.xrecorder.editor

import android.content.Context
import android.media.*
import android.net.Uri
import java.nio.ByteOrder
import kotlin.math.*

/**
 * MediaCodec PCM -> mono 16 kHz, continuous interpolation across buffer boundaries. ASR has a
 * bounded ten-minute input; no capture permissions or AudioRecord.
 */
object SpeechAudioDecoder {
    fun decode(
        context: Context,
        uri: Uri,
        durationMs: Long,
        cancelled: () -> Boolean,
        progress: (Double) -> Unit,
    ): FloatArray {
        require(durationMs in 1..600000) { "Use videos up to ten minutes for on-device subtitles." }
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            extractor.setDataSource(context, uri, null)
            val index =
                (0 until extractor.trackCount).firstOrNull {
                    extractor
                        .getTrackFormat(it)
                        .getString(MediaFormat.KEY_MIME)
                        ?.startsWith("audio/") == true
                } ?: error("This media has no audio track.")
            extractor.selectTrack(index)
            val format = extractor.getTrackFormat(index)
            format.setInteger(
                MediaFormat.KEY_PCM_ENCODING,
                androidx.media3.common.C.ENCODING_PCM_16BIT,
            )
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            decoder = codec
            codec.configure(format, null, null, 0)
            codec.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = androidx.media3.common.C.ENCODING_PCM_16BIT
            val maxSamples = (durationMs * 16 + 16000).toInt()
            val output = FloatArray(maxSamples)
            var count = 0
            var frame = 0L
            var next = 0.0
            var previous = 0f
            var inputDone = false
            var outputDone = false
            val info = MediaCodec.BufferInfo()
            var idle = 0
            while (!outputDone) {
                check(!cancelled()) { "Transcription cancelled" }
                var advanced = false
                if (!inputDone) {
                    val id = codec.dequeueInputBuffer(10000)
                    if (id >= 0) {
                        val buffer = codec.getInputBuffer(id)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                id,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(id, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                        advanced = true
                    }
                }
                when (val id = codec.dequeueOutputBuffer(info, 10000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val actual = codec.outputFormat
                        rate = actual.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = actual.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        encoding =
                            if (actual.containsKey(MediaFormat.KEY_PCM_ENCODING))
                                actual.getInteger(MediaFormat.KEY_PCM_ENCODING)
                            else androidx.media3.common.C.ENCODING_PCM_16BIT
                        require(
                            rate in 8000..192000 && channels in 1..8 && encoding in listOf(2, 4),
                        ) {
                            "Unsupported decoded speech format"
                        }
                    }
                    else ->
                        if (id >= 0) {
                            val buffer = codec.getOutputBuffer(id)!!.order(ByteOrder.nativeOrder())
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            val bytes = if (encoding == 4) 4 else 2
                            while (buffer.remaining() >= channels * bytes) {
                                var mono = 0f
                                repeat(channels) {
                                    mono +=
                                        if (encoding == 4) buffer.float else buffer.short / 32768f
                                }
                                mono /= channels
                                while (next <= frame) {
                                    require(count < maxSamples) {
                                        "Decoded speech exceeds the supported duration"
                                    }
                                    output[count++] =
                                        if (frame == 0L) mono
                                        else
                                            previous +
                                                (mono - previous) * (next - (frame - 1)).toFloat()
                                    next += rate / 16000.0
                                }
                                previous = mono
                                frame++
                            }
                            progress(
                                (info.presentationTimeUs / 1000.0 / durationMs).coerceIn(0.0, 1.0),
                            )
                            outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            codec.releaseOutputBuffer(id, false)
                            advanced = true
                        }
                }
                idle = if (advanced) 0 else idle + 1
                check(idle < 1500) { "Audio decoder stopped responding" }
            }
            require(count >= 1600) { "Audio is too short for speech recognition." }
            return output.copyOf(count)
        } finally {
            try {
                decoder?.stop()
            } catch (_: Exception) {}
            decoder?.release()
            extractor.release()
        }
    }
}
