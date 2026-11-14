package com.xrecorder.xrecorder.live

import android.media.MediaCodec
import android.media.MediaFormat
import com.xrecorder.xrecorder.recording.EncodedOutput
import java.nio.ByteBuffer

/** Shares the capture session's actual encoded packets; no parallel encoder. */
class LiveCapture(
    private val sessionId: String,
    endpoint: RtmpEndpoint,
    private val hasAudio: Boolean,
    requestKeyFrame: () -> Unit,
    private val changed: () -> Unit,
    private val failed: () -> Unit,
) {
    private val epochNs = System.nanoTime()
    private var videoFormat: MediaFormat? = null
    private var audioFormat: MediaFormat? = null
    @Volatile private var started = false
    @Volatile private var stopped = false
    private val transport = RtmpTransport(endpoint, requestKeyFrame) { state ->
        LiveCaptureState.update(sessionId, state)
        changed()
        if (state in listOf("connection_failed", "authentication_failed")) failed()
    }

    init {
        LiveCaptureState.update(sessionId, "preparing")
        LiveCaptureState.attach(sessionId) {
            // RtmpTransport remains idle until both encoder formats arrive.
            if (started) transport.snapshot() else mapOf("state" to if (stopped) "stopped" else "preparing")
        }
    }

    val video: EncodedOutput = sink(true)
    val audio: EncodedOutput = sink(false)

    private fun sink(video: Boolean) = object : EncodedOutput {
        override fun format(value: MediaFormat) = acceptFormat(value, video)
        override fun sample(buffer: ByteBuffer, info: MediaCodec.BufferInfo, originNs: Long) {
            if (stopped || originNs <= 0) return
            try {
                val aligned = MediaCodec.BufferInfo().apply {
                    set(info.offset, info.size, info.presentationTimeUs + (originNs - epochNs) / 1000, info.flags)
                }
                if (video) transport.video(buffer, aligned) else transport.audio(buffer, aligned)
            } catch (_: Exception) { fail() }
        }
    }

    @Synchronized private fun acceptFormat(value: MediaFormat, video: Boolean) {
        if (stopped) return
        if (video) videoFormat = value else audioFormat = value
        if (started || videoFormat == null || hasAudio && audioFormat == null) return
        try {
            started = true
            transport.start(videoFormat!!, if (hasAudio) audioFormat else null)
        } catch (_: Exception) { fail() }
    }

    private fun fail() {
        if (stopped) return
        stopped = true
        transport.stop()
        LiveCaptureState.finish(sessionId, "configuration_failed")
        changed()
        failed()
    }

    @Synchronized fun stop() {
        if (stopped) return
        stopped = true
        transport.stop()
        LiveCaptureState.finish(sessionId)
    }
}
