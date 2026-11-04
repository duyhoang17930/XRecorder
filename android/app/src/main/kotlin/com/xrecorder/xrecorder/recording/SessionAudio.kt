package com.xrecorder.xrecorder.recording

import android.content.Context
import android.media.*
import android.media.audiofx.NoiseSuppressor
import android.media.projection.MediaProjection
import android.os.Build
import java.io.File
import java.nio.ByteOrder

/** Captures mono 48k PCM and encodes a separate AAC track for final muxing. */
class SessionAudio(
    context: Context, projection: MediaProjection, source: String,
    private val micGain: Double, private val internalGain: Double,
    noiseReduction: Boolean, val file: File, private val onFailure: () -> Unit
) {
    private val rate = 48000
    private val inputFormat = AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
    private val bufferSize = maxOf(192000, AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT) * 4)
    private var mic: AudioRecord? = null
    private var internal: AudioRecord? = null
    private var suppression: NoiseSuppressor? = null
    @Volatile var paused = false
    @Volatile private var stopping = false
    @Volatile private var aborted = false
    @Volatile private var failure: Exception? = null
    @Volatile var startTimeNs = 0L
        private set
    private var worker: Thread? = null
    init {
        try {
            if (source == "microphone" || source == "mixed") {
                mic = AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.MIC).setAudioFormat(inputFormat).setBufferSizeInBytes(bufferSize).build()
                check(mic!!.state == AudioRecord.STATE_INITIALIZED)
                if (noiseReduction) {
                    require(NoiseSuppressor.isAvailable()) { "Noise reduction is unavailable" }
                    suppression = NoiseSuppressor.create(mic!!.audioSessionId)?.apply { enabled = true }
                }
            }
            if (source == "internal" || source == "mixed") {
                require(Build.VERSION.SDK_INT >= 29) { "Internal audio requires Android 10" }
                val capture = AudioPlaybackCaptureConfiguration.Builder(projection).addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME).addMatchingUsage(AudioAttributes.USAGE_UNKNOWN).build()
                internal = AudioRecord.Builder().setAudioPlaybackCaptureConfig(capture).setAudioFormat(inputFormat).setBufferSizeInBytes(bufferSize).build()
                check(internal!!.state == AudioRecord.STATE_INITIALIZED)
            }
            require(mic != null || internal != null)
        } catch (e: Exception) { releaseInputs(); throw e }
    }
    fun start() {
        try {
            mic?.startRecording(); internal?.startRecording()
            check((mic?.recordingState ?: AudioRecord.RECORDSTATE_RECORDING) == AudioRecord.RECORDSTATE_RECORDING)
            check((internal?.recordingState ?: AudioRecord.RECORDSTATE_RECORDING) == AudioRecord.RECORDSTATE_RECORDING)
            worker = Thread({ encode() }, "recording-audio").apply { start() }
        } catch (e: Exception) { releaseInputs(); throw e }
    }
    private fun encode() {
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var muxing = false
        try {
            val encoder = MediaCodec.createEncoderByType("audio/mp4a-latm"); codec = encoder
            val output = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4); muxer = output
            encoder.configure(MediaFormat.createAudioFormat("audio/mp4a-latm", rate, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 4096)
            }, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            var track = -1
            var samples = 0L
            val info = MediaCodec.BufferInfo()
            fun drain(wait: Boolean): Boolean {
                while (true) {
                    val index = encoder.dequeueOutputBuffer(info, if (wait) 10000 else 0)
                    if (index == MediaCodec.INFO_TRY_AGAIN_LATER) return false
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        check(!muxing); track = output.addTrack(encoder.outputFormat); output.start(); muxing = true
                    } else if (index >= 0) {
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            check(muxing)
                            val bytes = encoder.getOutputBuffer(index)!!
                            bytes.position(info.offset); bytes.limit(info.offset + info.size)
                            output.writeSampleData(track, bytes, info)
                        }
                        val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        encoder.releaseOutputBuffer(index, false)
                        if (end) return true
                    }
                }
            }
            val micPcm = ShortArray(1024); val internalPcm = ShortArray(1024)
            while (!stopping) {
                val micCount = mic?.read(micPcm, 0, 1024, AudioRecord.READ_BLOCKING) ?: 1024
                val internalCount = internal?.read(internalPcm, 0, 1024, AudioRecord.READ_BLOCKING) ?: 1024
                if (stopping) break
                if (micCount < 0 || internalCount < 0) throw java.io.IOException("Audio capture was interrupted")
                val count = minOf(micCount, internalCount)
                if (count == 0 || paused) continue
                if (startTimeNs == 0L) {
                    val timestamp = AudioTimestamp()
                    val primary = internal ?: mic!!
                    startTimeNs = if (primary.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC) == AudioRecord.SUCCESS)
                        timestamp.nanoTime - timestamp.framePosition * 1000000000L / rate
                        else System.nanoTime() - count * 1000000000L / rate
                }
                var index = encoder.dequeueInputBuffer(10000)
                while (index < 0 && !stopping) { drain(false); index = encoder.dequeueInputBuffer(10000) }
                if (index < 0) break
                val input = encoder.getInputBuffer(index)!!.apply { clear(); order(ByteOrder.LITTLE_ENDIAN) }
                for (i in 0 until count) {
                    val value = (if (mic != null) micPcm[i] * micGain else 0.0) + (if (internal != null) internalPcm[i] * internalGain else 0.0)
                    input.putShort(value.toInt().coerceIn(-32768,32767).toShort())
                }
                encoder.queueInputBuffer(index,0,count*2,samples*1000000L/rate,0); samples += count
                drain(false)
            }
            if (aborted) throw java.io.IOException("Audio cancelled")
            val deadline = System.nanoTime() + 5000000000L
            var eosSent = false; var done = false
            while (!done && System.nanoTime() < deadline) {
                if (!eosSent) {
                    val index = encoder.dequeueInputBuffer(10000)
                    if (index >= 0) { encoder.queueInputBuffer(index,0,0,samples*1000000L/rate,MediaCodec.BUFFER_FLAG_END_OF_STREAM); eosSent = true }
                }
                done = drain(true)
            }
            check(done && muxing && samples > 0) { "Audio did not finalize" }
            output.stop(); muxing = false
        } catch (e: Exception) { failure = e; if (!aborted) onFailure() }
        finally {
            if (muxing) try { muxer?.stop() } catch (_: Exception) { }
            try { muxer?.release() } catch (_: Exception) { }
            try { codec?.stop() } catch (_: Exception) { }
            try { codec?.release() } catch (_: Exception) { }
            releaseInputs()
        }
    }
    fun requestStop() {
        stopping = true
        try { mic?.stop() } catch (_: Exception) { }
        try { internal?.stop() } catch (_: Exception) { }
    }
    fun finish() {
        requestStop()
        worker?.join(8000)
        if (worker?.isAlive == true) { aborted = true; throw java.io.IOException("Audio did not stop") }
        failure?.let { throw it }
    }
    fun abort() { aborted = true; try { finish() } catch (_: Exception) { }; if (worker == null) releaseInputs() }
    private fun releaseInputs() {
        suppression?.release(); suppression = null
        mic?.release(); mic = null
        internal?.release(); internal = null
    }
}
