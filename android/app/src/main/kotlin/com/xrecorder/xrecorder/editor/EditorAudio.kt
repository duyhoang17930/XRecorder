package com.xrecorder.xrecorder.editor

import androidx.media3.common.C
import androidx.media3.common.audio.*
import java.nio.ByteBuffer
import kotlin.math.*

/** PCM processing belongs to the editor, never to the recording service. */
object EditorAudio {
    fun processors(
        options: Map<*, *>,
        durationMs: Long,
        offsetMs: Long = 0,
        speed: Float = 1f,
        headroom: Float = 1f,
    ): List<AudioProcessor> {
        fun value(key: String, default: Float) = (options[key] as? Number)?.toFloat() ?: default
        val gain = value("volume", 1f)
        val pitch = value("pitch", 1f)
        val fadeIn = value("fadeInMs", 0f)
        val fadeOut = value("fadeOutMs", 0f)
        val voice = options["voice"] as? String ?: "none"
        val noise = options["noiseReduction"] == true
        require(gain.isFinite() && gain in 0f..2f && pitch in .5f..2f)
        require(fadeIn >= 0 && fadeOut >= 0 && fadeIn + fadeOut <= durationMs)
        require(voice in listOf("none", "deep", "bright", "robot"))
        val result = mutableListOf<AudioProcessor>()
        if (noise) {
            result.add(SonicAudioProcessor().apply { setOutputSampleRateHz(48000) })
            result.add(RnNoiseProcessor())
        }
        if (voice == "robot") result.add(RobotProcessor())
        val actualPitch =
            pitch *
                when (voice) {
                    "deep" -> .75f
                    "bright" -> 1.35f
                    else -> 1f
                }
        if (actualPitch != 1f) result.add(SonicAudioProcessor().apply { setPitch(actualPitch) })
        val effectiveGain = gain * headroom
        if (effectiveGain != 1f)
            result.add(
                ChannelMixingAudioProcessor().apply {
                    for (channels in 1..6) putChannelMixingMatrix(
                        ChannelMixingMatrix.createForConstantGain(channels, channels)
                            .scaleBy(effectiveGain),
                    )
                },
            )
        // GainProvider uses StreamMetadata.positionOffsetUs after seeks. Duration and
        // offsets are in output time; PCM before setSpeed is in source time.
        if (fadeIn > 0 || fadeOut > 0)
            result.add(
                GainProcessor(
                    object : GainProcessor.GainProvider {
                        override fun getGainFactorAtSamplePosition(
                            position: Long,
                            rate: Int,
                        ): Float {
                            val ms = offsetMs + position * 1000.0 / rate / speed
                            val envelope =
                                min(
                                    if (fadeIn > 0) (ms / fadeIn).coerceIn(0.0, 1.0) else 1.0,
                                    if (fadeOut > 0)
                                        ((durationMs - ms) / fadeOut).coerceIn(0.0, 1.0)
                                    else 1.0,
                                )
                            return envelope.toFloat()
                        }

                        override fun isUnityUntil(position: Long, rate: Int) =
                            if (getGainFactorAtSamplePosition(position, rate) == 1f) position + 1
                            else C.TIME_UNSET
                    },
                ),
            )
        return result
    }
}

@androidx.annotation.Keep
private object NativeDenoiser {
    init {
        System.loadLibrary("threeh_whisper")
    }

    external fun create(channels: Int): Long

    external fun process(handle: Long, samples: FloatArray)

    external fun destroy(handle: Long)
}

/**
 * RNNoise works on480 frames at48kHz. Buffer and final padding retain the exact frame count,
 * including input buffers that end in a partial10ms frame.
 */
private class RnNoiseProcessor : BaseAudioProcessor() {
    private var handle = 0L
    private var frame = FloatArray(0)
    private var pending = 0

    override fun onConfigure(format: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (
            format.sampleRate != 48000 ||
                format.channelCount !in 1..6 ||
                format.encoding !in listOf(C.ENCODING_PCM_16BIT, C.ENCODING_PCM_FLOAT)
        )
            throw AudioProcessor.UnhandledAudioFormatException(format)
        return format
    }

    override fun onFlush(metadata: AudioProcessor.StreamMetadata) {
        release()
        handle = NativeDenoiser.create(inputAudioFormat.channelCount)
        check(handle != 0L)
        frame = FloatArray(480 * inputAudioFormat.channelCount)
        pending = 0
    }

    override fun queueInput(input: ByteBuffer) {
        val channels = inputAudioFormat.channelCount
        require(input.remaining() % inputAudioFormat.bytesPerFrame == 0)
        val complete = (pending + input.remaining() / inputAudioFormat.bytesPerFrame) / 480
        val output = replaceOutputBuffer(complete * 480 * inputAudioFormat.bytesPerFrame)
        while (input.hasRemaining()) {
            repeat(channels) { c ->
                frame[pending * channels + c] =
                    if (inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT) input.float
                    else input.short / 32768f
            }
            pending++
            if (pending == 480) {
                NativeDenoiser.process(handle, frame)
                write(output, 480)
                pending = 0
            }
        }
        output.flip()
    }

    private fun write(output: ByteBuffer, frames: Int) {
        repeat(frames * inputAudioFormat.channelCount) { i ->
            val sample = frame[i].coerceIn(-1f, 1f)
            if (inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT) output.putFloat(sample)
            else output.putShort((sample * 32767).roundToInt().toShort())
        }
    }

    override fun onQueueEndOfStream() {
        if (pending == 0) return
        frame.fill(0f, pending * inputAudioFormat.channelCount)
        NativeDenoiser.process(handle, frame)
        val output = replaceOutputBuffer(pending * inputAudioFormat.bytesPerFrame)
        write(output, pending)
        pending = 0
        output.flip()
    }

    override fun onReset() {
        release()
        frame = FloatArray(0)
        pending = 0
    }

    private fun release() {
        if (handle != 0L) {
            NativeDenoiser.destroy(handle)
            handle = 0
        }
    }
}

/** Deterministic35Hz ring modulation, preserving source sample count and phase after seeks. */
private class RobotProcessor : BaseAudioProcessor() {
    private var frames = 0L

    override fun onConfigure(format: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (format.encoding != C.ENCODING_PCM_16BIT && format.encoding != C.ENCODING_PCM_FLOAT)
            throw AudioProcessor.UnhandledAudioFormatException(format)
        return format
    }

    override fun onFlush(metadata: AudioProcessor.StreamMetadata) {
        frames = metadata.positionOffsetUs * inputAudioFormat.sampleRate / 1000000
    }

    override fun queueInput(input: ByteBuffer) {
        val output = replaceOutputBuffer(input.remaining())
        while (input.remaining() >= inputAudioFormat.bytesPerFrame) {
            val modulation = cos(2 * PI * 35 * frames / inputAudioFormat.sampleRate)
            repeat(inputAudioFormat.channelCount) {
                val sample =
                    if (inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT) input.float
                    else input.short / 32768f
                val value = (sample * modulation).coerceIn(-1.0, 1.0)
                if (inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT)
                    output.putFloat(value.toFloat())
                else output.putShort((value * 32767).roundToInt().toShort())
            }
            frames++
        }
        output.flip()
    }
}
