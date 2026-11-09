package com.xrecorder.xrecorder.recording

import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Pure, platform-independent math and smoothing for audio ducking (F21).
 * Attenuates internal audio when voice activity is detected on the microphone.
 * 100% JVM unit testable without Android framework mocks.
 */
internal class AudioDuckingEngine(
    val sampleRate: Int = DEFAULT_SAMPLE_RATE,
    val voiceThresholdRms: Float = DEFAULT_VOICE_THRESHOLD_RMS,
    val minDuckFactor: Float = DEFAULT_MIN_DUCK_FACTOR,
    val attackTimeMs: Float = DEFAULT_ATTACK_TIME_MS,
    val holdTimeMs: Float = DEFAULT_HOLD_TIME_MS,
    val releaseTimeMs: Float = DEFAULT_RELEASE_TIME_MS
) {
    companion object {
        const val DEFAULT_SAMPLE_RATE = 48000
        const val DEFAULT_VOICE_THRESHOLD_RMS = 0.035f // ~ -29 dBFS
        const val DEFAULT_MIN_DUCK_FACTOR = 0.25f      // -12 dB attenuation of internal audio
        const val DEFAULT_ATTACK_TIME_MS = 25.0f       // Smooth fade down to prevent click
        const val DEFAULT_HOLD_TIME_MS = 400.0f        // Hold ducking across syllable pauses
        const val DEFAULT_RELEASE_TIME_MS = 300.0f     // Smooth fade back to normal volume

        fun calculateRms(samples: ShortArray, offset: Int = 0, count: Int = samples.size): Float {
            if (count <= 0) return 0f
            var sumSquare = 0.0
            for (i in offset until (offset + count)) {
                val normalized = samples[i].toDouble() / 32768.0
                sumSquare += normalized * normalized
            }
            return sqrt(sumSquare / count).toFloat()
        }

        fun clampSample(value: Double): Short =
            value.toInt().coerceIn(-32768, 32767).toShort()
    }

    private val attackAlpha: Float = if (attackTimeMs > 0f) {
        1.0f - exp(-1.0f / (attackTimeMs * sampleRate / 1000f))
    } else 1.0f

    private val releaseAlpha: Float = if (releaseTimeMs > 0f) {
        1.0f - exp(-1.0f / (releaseTimeMs * sampleRate / 1000f))
    } else 1.0f

    private val holdSamples: Int = (holdTimeMs * sampleRate / 1000f).toInt()

    private var currentDuckFactor = 1.0f
    private var holdCounter = 0
    private var isVoiceActive = false

    val currentFactor: Float get() = currentDuckFactor
    val isDucking: Boolean get() = currentDuckFactor < 0.99f
    val isSpeaking: Boolean get() = isVoiceActive

    fun reset() {
        currentDuckFactor = 1.0f
        holdCounter = 0
        isVoiceActive = false
    }

    /**
     * Analyzes a microphone PCM block for voice activity.
     */
    fun analyzeMicFrame(micSamples: ShortArray, offset: Int = 0, count: Int = micSamples.size): Boolean {
        val rms = calculateRms(micSamples, offset, count)
        if (rms >= voiceThresholdRms) {
            isVoiceActive = true
            holdCounter = holdSamples
        } else {
            if (holdCounter > 0) {
                holdCounter = max(0, holdCounter - count)
                isVoiceActive = true
            } else {
                isVoiceActive = false
            }
        }
        return isVoiceActive
    }

    /**
     * Mixes a single sample pair (mic + internal) applying gains and duck factor.
     */
    fun mixSample(
        mic: Short,
        internal: Short,
        micGain: Double,
        internalGain: Double,
        duckingEnabled: Boolean
    ): Short {
        if (!duckingEnabled) {
            return clampSample(mic * micGain + internal * internalGain)
        }

        val targetFactor = if (isVoiceActive) minDuckFactor else 1.0f
        val alpha = if (targetFactor < currentDuckFactor) attackAlpha else releaseAlpha
        currentDuckFactor += alpha * (targetFactor - currentDuckFactor)

        val effectiveInternal = internal * internalGain * currentDuckFactor
        val effectiveMic = mic * micGain
        return clampSample(effectiveMic + effectiveInternal)
    }

    /**
     * Processes and mixes an entire block of mic and internal PCM samples.
     */
    fun processMixBlock(
        micPcm: ShortArray,
        internalPcm: ShortArray,
        outputPcm: ShortArray,
        count: Int,
        micGain: Double,
        internalGain: Double,
        duckingEnabled: Boolean
    ) {
        if (duckingEnabled) {
            analyzeMicFrame(micPcm, 0, count)
        }
        for (i in 0 until count) {
            outputPcm[i] = mixSample(micPcm[i], internalPcm[i], micGain, internalGain, duckingEnabled)
        }
    }
}
