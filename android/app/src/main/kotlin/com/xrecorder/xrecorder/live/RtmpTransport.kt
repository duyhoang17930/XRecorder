package com.xrecorder.xrecorder.live

import android.media.MediaCodec
import android.media.MediaFormat
import com.pedro.common.ConnectChecker
import com.pedro.rtmp.rtmp.RtmpClient
import java.nio.ByteBuffer

/** Bounded, nonblocking transport for the app's existing H264/AAC encoders.
 * Owns network resources only. It never owns media files or permission tokens.
 */
class RtmpTransport(
    private val endpoint: RtmpEndpoint,
    private val requestKeyFrame: () -> Unit = {},
    private val changed: (String) -> Unit,
) {
    @Volatile var state = "idle"
        private set
    @Volatile var bitrate = 0L
        private set
    @Volatile private var closed = false
    @Volatile private var firstVideoUs = -1L
    private var started = false
    private var retry = 0
    private val client: RtmpClient = RtmpClient(object : ConnectChecker {
        override fun onConnectionStarted(url: String) {
            if (!closed) update(if (retry == 0) "connecting" else "reconnecting")
        }
        override fun onConnectionSuccess() {
            if (closed) { client.disconnect(); return }
            firstVideoUs = -1
            update("live")
            requestKeyFrame()
        }
        override fun onConnectionFailed(reason: String) {
            if (closed) return
            if (retry < 2 && client.shouldRetry(reason)) {
                retry++
                firstVideoUs = -1
                update("reconnecting")
                client.reConnect(retry * 1000L)
            } else fail("connection_failed")
        }
        override fun onDisconnect() { if (!closed) fail("connection_failed") }
        override fun onAuthError() { if (!closed) fail("authentication_failed") }
        override fun onAuthSuccess() = Unit
        override fun onNewBitrate(bitrate: Long) { this@RtmpTransport.bitrate = bitrate }
    }).apply {
        tlsHostVerification = true
        socketTimeout = 5000
        setReTries(2)
        resizeCache(90)
        setLogs(false)
    }

    private fun update(value: String) {
        state = value
        changed(value)
    }

    private fun fail(value: String) {
        closed = true
        update(value)
        client.disconnect()
    }

    @Synchronized fun start(video: MediaFormat, audio: MediaFormat? = null) {
        check(!started && !closed) { "The live transport has already started." }
        require(video.getString(MediaFormat.KEY_MIME) == "video/avc") { "Live requires H264 video." }
        val sps = requireNotNull(video.getByteBuffer("csd-0")) { "Missing H264 configuration." }
        val pps = requireNotNull(video.getByteBuffer("csd-1")) { "Missing H264 configuration." }
        client.setVideoResolution(video.getInteger(MediaFormat.KEY_WIDTH), video.getInteger(MediaFormat.KEY_HEIGHT))
        client.setFps(if (video.containsKey(MediaFormat.KEY_FRAME_RATE)) video.getInteger(MediaFormat.KEY_FRAME_RATE) else 30)
        client.setVideoInfo(sps.duplicate(), pps.duplicate(), null)
        client.setOnlyVideo(audio == null)
        if (audio != null) {
            require(audio.getString(MediaFormat.KEY_MIME) == "audio/mp4a-latm") { "Live requires AAC audio." }
            val channels = audio.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            require(channels in 1..2) { "Live supports mono or stereo audio." }
            client.setAudioInfo(audio.getInteger(MediaFormat.KEY_SAMPLE_RATE), channels == 2)
        }
        started = true
        update("connecting")
        client.connect(endpoint.publishUrl)
    }

    /** RootEncoder copies into its bounded trySend queue before this returns. */
    fun video(buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (closed || state != "live" || info.size <= 0 || info.presentationTimeUs < 0) return
        if (firstVideoUs < 0) {
            if (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME == 0) return
            firstVideoUs = info.presentationTimeUs
        }
        send(buffer, info, true)
    }

    fun audio(buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (closed || state != "live" || firstVideoUs < 0 || info.size <= 0) return
        send(buffer, info, false)
    }

    private fun send(buffer: ByteBuffer, info: MediaCodec.BufferInfo, video: Boolean) {
        val relative = info.presentationTimeUs - firstVideoUs
        if (relative < 0 || info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) return
        val bytes = buffer.duplicate().apply { position(info.offset); limit(info.offset + info.size) }.slice()
        val sample = MediaCodec.BufferInfo().apply { set(0, info.size, relative, info.flags) }
        if (video) client.sendVideo(bytes, sample) else client.sendAudio(bytes, sample)
    }

    fun snapshot(): Map<String, Any> = mapOf(
        "state" to state, "bitrate" to bitrate, "retries" to retry,
        "sentVideoFrames" to client.sentVideoFrames, "sentAudioFrames" to client.sentAudioFrames,
        "droppedVideoFrames" to client.droppedVideoFrames, "droppedAudioFrames" to client.droppedAudioFrames,
        "sentBytes" to client.bytesSend, "queuedBytes" to client.getQueueBytesOut(),
    )

    @Synchronized fun stop() {
        if (closed) return
        closed = true
        update("stopped")
        client.disconnect()
    }
}
