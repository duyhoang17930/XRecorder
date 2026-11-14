package com.xrecorder.xrecorder.recording

import android.content.Context
import android.media.*
import android.media.audiofx.NoiseSuppressor
import android.media.projection.MediaProjection
import android.os.Build
import java.io.File
import java.nio.ByteOrder
import java.io.IOException

/** Captures mono 48k PCM and encodes a separate AAC track for final muxing. */
class SessionAudio @JvmOverloads constructor(
    context: Context, projection: MediaProjection, val source: String,
    private val micGain: Double, private val internalGain: Double,
    noiseReduction: Boolean, val audioDucking: Boolean = false,
    val file: File, private val onFailure: () -> Unit,
    private val encodedOutput: EncodedOutput? = null
) {
    companion object {
        fun mixSample(
            mic: Short, internal: Short, micGain: Double, internalGain: Double,
            duckFactor: Float = 1.0f
        ): Short =
            (mic * micGain + internal * internalGain * duckFactor).toInt().coerceIn(-32768, 32767).toShort()
    }
    private val rate = 48000
    private val duckingEngine = AudioDuckingEngine(rate)
    private val inputFormat = AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
    private val bufferSize = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT).let {
        require(it > 0) { "Mono 48 kHz PCM input is unavailable" }
        maxOf(192000, it * 4)
    }
    private var mic: AudioRecord? = null
    private var internal: AudioRecord? = null
    private var internalReader: CapturePcmReader? = null
    private var suppression: NoiseSuppressor? = null
    @Volatile private var isPaused = false
    var paused: Boolean
        get() = isPaused
        set(value) {
            isPaused = value
            if (value) internalReader?.discardQueued()
        }
    @Volatile private var stopping = false
    @Volatile private var aborted = false
    @Volatile private var failure: Exception? = null
    @Volatile var startTimeNs = 0L
        private set
    @Volatile var micUnderrunSamples = 0L
        private set
    @Volatile var microphoneReadSamples = 0L
        private set
    @Volatile var encodedSamples = 0L
        private set
    private var worker: Thread? = null
    init {
        try {
            if (source == "microphone" || source == "mixed") {
                mic = AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.MIC).setAudioFormat(inputFormat).setBufferSizeInBytes(bufferSize).build()
                check(mic!!.state == AudioRecord.STATE_INITIALIZED)
                if (noiseReduction) {
                    require(NoiseSuppressor.isAvailable()) { "Noise reduction is unavailable" }
                    suppression = requireNotNull(NoiseSuppressor.create(mic!!.audioSessionId)) { "Noise reduction could not attach to microphone" }
                    check(suppression!!.setEnabled(true) == android.media.audiofx.AudioEffect.SUCCESS) { "Noise reduction could not be enabled" }
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
        worker = Thread({ encode() }, "recording-audio").apply { start() }
    }
    @Synchronized private fun startInputs(): Boolean {
        if (stopping) return false
        mic?.startRecording(); internal?.startRecording()
        check((mic?.recordingState ?: AudioRecord.RECORDSTATE_RECORDING) == AudioRecord.RECORDSTATE_RECORDING)
        check((internal?.recordingState ?: AudioRecord.RECORDSTATE_RECORDING) == AudioRecord.RECORDSTATE_RECORDING)
        internal?.let { recorder ->
            internalReader = CapturePcmReader(
                // Dedicated reader can wait directly for PCM instead of relying
                // on2ms sleeps to wake within the platform's64ms capture FIFO.
                // The consumer's3s source timeout and requestStop/AudioRecord.stop
                // still terminate a stalled read before its owning thread joins.
                read = { bytes, offset, count -> recorder.read(bytes, offset, count, AudioRecord.READ_BLOCKING) },
                origin = {
                    val timestamp = AudioTimestamp()
                    if (recorder.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC) == AudioRecord.SUCCESS)
                        timestamp.nanoTime - timestamp.framePosition * 1_000_000_000L / rate
                    else System.nanoTime() - 1024 * 1_000_000_000L / rate
                },
                prepareThread = { android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO) },
                discard = { paused },
            ).also { it.start() }
        }
        return true
    }
    private fun encode() {
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var muxing = false
        try {
            // Keep the existing PCM/AAC worker responsive under simultaneous
            // screen encoding and playback. Starting inputs before codec setup
            // can overflow their finite buffers before the first read.
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
            val selected = requireNotNull(CaptureConfig.aacEncoder()) { "AAC-LC mono 48 kHz / 128 kbps is unavailable" }
            val encoder = MediaCodec.createByCodecName(selected.name); codec = encoder
            val output = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4); muxer = output
            encoder.configure(MediaFormat.createAudioFormat("audio/mp4a-latm", rate, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 4096)
            }, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            if (!startInputs()) throw IOException("Audio cancelled before capture started")
            var track = -1
            var samples = 0L
            val info = MediaCodec.BufferInfo()
            fun drain(wait: Boolean): Boolean {
                while (true) {
                    val index = encoder.dequeueOutputBuffer(info, if (wait) 10000 else 0)
                    if (index == MediaCodec.INFO_TRY_AGAIN_LATER) return false
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        check(!muxing); track = output.addTrack(encoder.outputFormat); output.start(); muxing = true
                        encodedOutput?.format(encoder.outputFormat)
                    } else if (index >= 0) {
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            check(muxing)
                            val bytes = encoder.getOutputBuffer(index)!!
                            bytes.position(info.offset); bytes.limit(info.offset + info.size)
                            output.writeSampleData(track, bytes, info)
                            encodedOutput?.sample(bytes, info, startTimeNs)
                        }
                        val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        encoder.releaseOutputBuffer(index, false)
                        if (end) return true
                    }
                }
            }
            val micPcm = ShortArray(1024); val internalPcm = ShortArray(1024)
            var micCount = 0; var internalCount = 0
            var lastInputNs = System.nanoTime()
            var lastMicInputNs = lastInputNs
            var micDeadlineNs = 0L
            while (true) {
                // Accumulate partial reads independently. Never discard the longer source
                // or block forever waiting for a silent/unavailable second source.
                val micRead = if (!stopping && mic != null && micCount < 1024) mic!!.read(micPcm, micCount, 1024 - micCount, AudioRecord.READ_NON_BLOCKING) else 0
                val captured = if (internalCount == 0) internalReader?.poll() else null
                val internalRead = captured?.size ?: 0
                if (captured != null) {
                    System.arraycopy(captured, 0, internalPcm, 0, captured.size)
                    // Deadline belongs to capture arrival, not consumer wakeup:
                    // an existing backlog must drain without64ms per-block waits.
                    micDeadlineNs = internalReader!!.lastBlockReadyNs + 64_000_000L
                }
                if (stopping && internalRead == 0 && internalCount == 0) break
                if (micRead < 0 && !stopping) throw IOException("Audio capture was interrupted")
                micCount += micRead.coerceAtLeast(0); internalCount += internalRead
                microphoneReadSamples += micRead.coerceAtLeast(0)
                if (micRead > 0) lastMicInputNs = System.nanoTime()
                if (stopping && internalCount > micCount) {
                    micPcm.fill(0, micCount, internalCount)
                    micCount = internalCount
                }
                if (paused) {
                    micCount = 0; internalCount = 0; lastInputNs = System.nanoTime()
                    lastMicInputNs = lastInputNs; micDeadlineNs = 0
                    duckingEngine.reset()
                    drain(false)
                    if (captured == null) Thread.sleep(2)
                    continue
                }
                // Mixed audio follows the internal source's clock. A delayed
                // microphone must not block playback capture until its tiny OS
                // FIFO overruns. Wait at most64ms, then explicitly silence only
                // the missing microphone samples; never discard internal PCM.
                if (!stopping && mic != null && internal != null && internalCount == 1024 && micCount < 1024) {
                    val now = System.nanoTime()
                    if (now - lastMicInputNs > 3_000_000_000L) throw IOException("Microphone stopped supplying PCM")
                    if (micDeadlineNs == 0L) micDeadlineNs = now + 64_000_000L
                    if (now >= micDeadlineNs) {
                        micUnderrunSamples += 1024 - micCount
                        micPcm.fill(0, micCount, 1024)
                        micCount = 1024
                    }
                }
                if ((mic != null && micCount < 1024) || (internal != null && internalCount < 1024)) {
                    if (System.nanoTime() - lastInputNs > 3000000000L) throw IOException("An audio source stopped supplying PCM")
                    drain(false); Thread.sleep(2); continue
                }
                val count = 1024
                lastInputNs = System.nanoTime()
                if (startTimeNs == 0L) {
                    val timestamp = AudioTimestamp()
                    val primary = internal ?: mic!!
                    startTimeNs = internalReader?.originNs?.takeIf { it > 0L } ?: if (primary.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC) == AudioRecord.SUCCESS)
                        timestamp.nanoTime - timestamp.framePosition * 1000000000L / rate
                        else System.nanoTime() - count * 1000000000L / rate
                }
                var index = encoder.dequeueInputBuffer(10000)
                val inputDeadline = System.nanoTime() + 3000000000L
                while (index < 0 && !aborted) {
                    if (System.nanoTime() >= inputDeadline) throw IOException("Audio encoder stopped accepting PCM")
                    drain(false); index = encoder.dequeueInputBuffer(10000)
                }
                if (index < 0) break
                val input = encoder.getInputBuffer(index)!!.apply { clear(); order(ByteOrder.LITTLE_ENDIAN) }
                val isDuckingActive = source == "mixed" && audioDucking
                if (isDuckingActive) {
                    duckingEngine.analyzeMicFrame(micPcm, 0, count)
                }
                for (i in 0 until count) {
                    val micSample = if (mic != null) micPcm[i] else 0
                    val internalSample = if (internal != null) internalPcm[i] else 0
                    val mixed = if (isDuckingActive) {
                        duckingEngine.mixSample(micSample, internalSample, micGain, internalGain, true)
                    } else {
                        mixSample(micSample, internalSample, micGain, internalGain)
                    }
                    input.putShort(mixed)
                }
                encoder.queueInputBuffer(index,0,count*2,samples*1000000L/rate,0); samples += count
                encodedSamples = samples
                micCount = 0; internalCount = 0
                micDeadlineNs = 0
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
            requestStop()
            try { internalReader?.finish() } catch (error: Exception) { if (failure == null) failure = error }
            if (muxing) try { muxer?.stop() } catch (_: Exception) { }
            try { muxer?.release() } catch (_: Exception) { }
            try { codec?.stop() } catch (_: Exception) { }
            try { codec?.release() } catch (_: Exception) { }
            releaseInputs()
        }
    }
    @Synchronized fun requestStop() {
        stopping = true
        internalReader?.requestStop()
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
    @Synchronized private fun releaseInputs() {
        duckingEngine.reset()
        try { suppression?.release() } catch (_: Exception) { }; suppression = null
        try { mic?.release() } catch (_: Exception) { }; mic = null
        try { internal?.release() } catch (_: Exception) { }; internal = null
    }
}
