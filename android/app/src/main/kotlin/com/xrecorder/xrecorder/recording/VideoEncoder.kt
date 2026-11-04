package com.xrecorder.xrecorder.recording

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.ParcelFileDescriptor
import android.view.Surface
import java.nio.ByteBuffer

/** Drains actual encoder packets; the MP4 timeline includes the final static frame. */
class VideoEncoder(
    descriptor: ParcelFileDescriptor, legacyPath: String?, encoderName: String,
    width: Int, height: Int, bitrate: Int, private val fps: Int,
    private val onFirstFrame: () -> Unit, private val onFailure: () -> Unit
) {
    private val codec = MediaCodec.createByCodecName(encoderName)
    private val muxer = if (Build.VERSION.SDK_INT >= 26) MediaMuxer(descriptor.fileDescriptor, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        else MediaMuxer(requireNotNull(legacyPath), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    val surface: Surface
    @Volatile private var aborted = false
    @Volatile private var failure: Exception? = null
    @Volatile private var stopTimeNs = 0L
    private val worker: Thread
    init {
        try {
            val format = MediaFormat.createVideoFormat("video/avc", width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 1000000L / fps)
                if (Build.VERSION.SDK_INT >= 29) setFloat(MediaFormat.KEY_MAX_FPS_TO_ENCODER, fps.toFloat())
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = codec.createInputSurface()
            codec.start()
        } catch (e: Exception) { codec.release(); muxer.release(); throw e }
        worker = Thread({ drain() }, "screen-encoder").apply { start() }
    }
    private fun drain() {
        var muxing = false
        var track = -1
        var originPts = -1L
        var firstFrameNs = 0L
        var lastPts = -1L
        val info = MediaCodec.BufferInfo()
        try {
            while (!aborted) {
                val index = codec.dequeueOutputBuffer(info, 10000)
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    check(!muxing)
                    track = muxer.addTrack(codec.outputFormat); muxer.start(); muxing = true
                } else if (index >= 0) {
                    val buffer = codec.getOutputBuffer(index) ?: throw IllegalStateException("Encoder output missing")
                    if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                        check(muxing)
                        if (originPts < 0) { originPts = info.presentationTimeUs; firstFrameNs = System.nanoTime() }
                        info.presentationTimeUs = maxOf(lastPts + 1, info.presentationTimeUs - originPts)
                        buffer.position(info.offset); buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                        if (lastPts < 0) onFirstFrame()
                        lastPts = info.presentationTimeUs
                    }
                    val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(index, false)
                    if (end) {
                        check(lastPts >= 0) { "No video frames were encoded" }
                        // Public MediaMuxer EOS semantics preserve the static tail of a recording.
                        val duration = maxOf(lastPts + 1000000L / fps, (stopTimeNs - firstFrameNs) / 1000)
                        val endInfo = MediaCodec.BufferInfo().apply { set(0, 0, duration, MediaCodec.BUFFER_FLAG_END_OF_STREAM) }
                        muxer.writeSampleData(track, ByteBuffer.allocate(0), endInfo)
                        break
                    }
                }
            }
            if (aborted) throw java.io.IOException("Encoding cancelled")
            check(muxing)
            muxer.stop(); muxing = false
        } catch (e: Exception) {
            failure = e
            if (!aborted) onFailure()
        } finally {
            if (muxing) try { muxer.stop() } catch (_: Exception) { }
            try { muxer.release() } catch (_: Exception) { }
            try { codec.stop() } catch (_: Exception) { }
            codec.release(); surface.release()
        }
    }
    fun finish() {
        failure?.let { throw it }
        stopTimeNs = System.nanoTime()
        codec.signalEndOfInputStream()
        worker.join(10000)
        if (worker.isAlive) { aborted = true; worker.join(2000); throw java.io.IOException("Encoder did not finish in time") }
        failure?.let { throw it }
    }
    fun abort() { aborted = true; if (Thread.currentThread() !== worker) worker.join(2000) }
}
