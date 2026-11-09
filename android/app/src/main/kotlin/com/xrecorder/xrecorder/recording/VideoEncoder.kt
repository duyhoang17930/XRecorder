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
    width: Int, height: Int, bitrate: Int, private val fps: Int, private val mime: String = "video/avc",
    private val onFirstFrame: () -> Unit, private val onFailure: () -> Unit
) {
    companion object {
        // Translate encoder-relative PTS into the monotonic clock used by pause ranges.
        fun captureTimeNs(ptsUs: Long, originUs: Long, sourceStartNs: Long): Long =
            sourceStartNs + (ptsUs - originUs) * 1000
    }
    private val codec = MediaCodec.createByCodecName(encoderName)
    private val muxer: MediaMuxer
    val surface: Surface
    @Volatile private var aborted = false
    @Volatile private var failure: Exception? = null
    @Volatile private var stopTimeNs = 0L
    @Volatile var sourceStartNs = 0L
        private set
    @Volatile var durationUs = 0L
        private set
    private val worker: Thread
    private val pauseRanges = mutableListOf<Pair<Long, Long>>()
    private var pauseStartNs = 0L
    @Synchronized fun setPaused(paused: Boolean) {
        if (paused == (pauseStartNs != 0L)) return
        val now = System.nanoTime()
        codec.setParameters(android.os.Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_SUSPEND, if (paused) 1 else 0) })
        if (paused) pauseStartNs = now else {
            pauseRanges.add(pauseStartNs to now); pauseStartNs = 0
            codec.setParameters(android.os.Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        }
    }
    @Synchronized private fun pausedBefore(timeNs: Long): Long =
        pauseRanges.sumOf { (start, end) -> (minOf(timeNs,end)-start).coerceAtLeast(0) } +
            if (pauseStartNs != 0L) (timeNs-pauseStartNs).coerceAtLeast(0) else 0L
    init {
        muxer = try {
            if (Build.VERSION.SDK_INT >= 26) MediaMuxer(descriptor.fileDescriptor, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            else MediaMuxer(requireNotNull(legacyPath), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (e: Exception) {
            runCatching { codec.release() }
            throw e
        }
        var inputSurface: Surface? = null
        try {
            val format = MediaFormat.createVideoFormat(mime, width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 1000000L / fps)
                if (Build.VERSION.SDK_INT >= 29) setFloat(MediaFormat.KEY_MAX_FPS_TO_ENCODER, fps.toFloat())
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = codec.createInputSurface().also { inputSurface = it }
            codec.start()
        } catch (e: Exception) {
            runCatching { inputSurface?.release() }
            runCatching { codec.release() }
            runCatching { muxer.release() }
            throw e
        }
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
                        if (originPts < 0) { originPts = info.presentationTimeUs; firstFrameNs = System.nanoTime(); sourceStartNs = if (kotlin.math.abs(originPts * 1000 - firstFrameNs) < 60000000000L) originPts * 1000 else firstFrameNs }
                        // Keep spacing above the MP4 track's timestamp quantization (often 90 kHz).
                        // Some encoders drain queued repeat frames across suspend/resume.
                        info.presentationTimeUs = maxOf(if(lastPts < 0) 0 else lastPts + 1000, info.presentationTimeUs - originPts - pausedBefore(captureTimeNs(info.presentationTimeUs, originPts, sourceStartNs)) / 1000)
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
                        val duration = maxOf(lastPts + 1000000L / fps, (stopTimeNs - firstFrameNs - pausedBefore(stopTimeNs)) / 1000)
                        durationUs = duration
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
