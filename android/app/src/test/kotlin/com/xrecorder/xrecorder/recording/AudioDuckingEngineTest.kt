package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import kotlin.math.sin

class AudioDuckingEngineTest {

    private lateinit var engine: AudioDuckingEngine

    @Before
    fun setUp() {
        engine = AudioDuckingEngine(
            sampleRate = 48000,
            voiceThresholdRms = 0.035f,
            minDuckFactor = 0.25f,
            attackTimeMs = 25.0f,
            holdTimeMs = 400.0f,
            releaseTimeMs = 300.0f
        )
    }

    private fun generateSineWave(amplitude: Short, frequencyHz: Float, count: Int): ShortArray {
        val samples = ShortArray(count)
        val step = 2.0 * Math.PI * frequencyHz / 48000.0
        for (i in 0 until count) {
            samples[i] = (amplitude * sin(i * step)).toInt().toShort()
        }
        return samples
    }

    @Test
    fun duckingDisabledPreservesStandardMixBitwise() {
        // When ducking is disabled, output must match SessionAudio.mixSample exactly
        val micSample: Short = 10000
        val internalSample: Short = 15000
        val mixedExpected = SessionAudio.mixSample(micSample, internalSample, 1.0, 1.0)

        val mixedActual = engine.mixSample(
            mic = micSample,
            internal = internalSample,
            micGain = 1.0,
            internalGain = 1.0,
            duckingEnabled = false
        )
        assertEquals(mixedExpected, mixedActual)
        assertEquals(1.0f, engine.currentFactor, 0.001f)
    }

    @Test
    fun silentMicKeepsFullInternalGain() {
        // Generate low background noise / silence (amplitude 200 << 32768, RMS < 0.01 < 0.035)
        val silentMic = ShortArray(1024) { 150 }
        val isVoice = engine.analyzeMicFrame(silentMic)
        assertFalse("Silent mic should not trigger voice activity", isVoice)

        val mixed = engine.mixSample(
            mic = 150,
            internal = 10000,
            micGain = 1.0,
            internalGain = 1.0,
            duckingEnabled = true
        )
        // Internal should not be attenuated
        assertEquals(1.0f, engine.currentFactor, 0.001f)
        assertEquals(10150.toShort(), mixed)
    }

    @Test
    fun activeVoiceSmoothlyAttenuatesInternalAudio() {
        // High amplitude voice-like wave: 1000 Hz at 50% full scale (RMS ~ 0.35 >> 0.035)
        val voicePcm = generateSineWave(16000.toShort(), 1000f, 1024)
        val isVoice = engine.analyzeMicFrame(voicePcm)
        assertTrue("Loud voice frame must trigger voice activity", isVoice)

        // Process samples to simulate attack smoothing
        var lastFactor = engine.currentFactor
        for (i in 0 until 5000) { // ~104ms of audio
            engine.mixSample(voicePcm[i % 1024], 10000.toShort(), 1.0, 1.0, duckingEnabled = true)
            // Factor must decrease monotonically towards minDuckFactor (0.25)
            assertTrue("Ducking factor should decrease smoothly", engine.currentFactor <= lastFactor + 0.0001f)
            lastFactor = engine.currentFactor
        }

        // After attack period, factor must reach near minDuckFactor (0.25)
        assertTrue("Duck factor should reach near 0.25", engine.currentFactor < 0.30f)
        assertTrue("Duck factor must not drop below minDuckFactor", engine.currentFactor >= 0.25f)
    }

    @Test
    fun holdAndReleaseSmoothlyRestoresInternalVolume() {
        // 1. Trigger voice
        val voicePcm = generateSineWave(16000.toShort(), 1000f, 1024)
        engine.analyzeMicFrame(voicePcm)
        for (i in 0 until 5000) {
            engine.mixSample(voicePcm[i % 1024], 10000.toShort(), 1.0, 1.0, duckingEnabled = true)
        }
        assertTrue("Duck factor should be lowered", engine.currentFactor < 0.30f)

        // 2. Voice stops, silence for 200ms (< holdTimeMs of 400ms)
        val silentPcm = ShortArray(1024)
        for (f in 0 until 9) { // ~192ms
            val activeDuringHold = engine.analyzeMicFrame(silentPcm)
            assertTrue("Voice activity state should be held during hold period", activeDuringHold)
        }
        assertTrue("Duck factor should remain low during hold period", engine.currentFactor < 0.35f)

        // 3. Silence continues for > 400ms hold time + release time (75 frames * 1024 ~ 1.6s)
        for (f in 0 until 75) {
            engine.analyzeMicFrame(silentPcm)
            for (i in 0 until 1024) {
                engine.mixSample(0, 10000.toShort(), 1.0, 1.0, duckingEnabled = true)
            }
        }
        assertFalse("Speaking should be false after hold expires", engine.isSpeaking)
        assertEquals("Duck factor should fully restore to 1.0", 1.0f, engine.currentFactor, 0.01f)
    }

    @Test
    fun processMixBlockHandlesMultiChannelOrClampingWithoutOverflow() {
        val mic = ShortArray(1024) { 30000 }
        val internal = ShortArray(1024) { 30000 }
        val output = ShortArray(1024)

        // With high gains (2.0 and 2.0), output must saturate to 32767 without wrapping or crash
        engine.processMixBlock(
            micPcm = mic,
            internalPcm = internal,
            outputPcm = output,
            count = 1024,
            micGain = 2.0,
            internalGain = 2.0,
            duckingEnabled = true
        )

        for (sample in output) {
            assertEquals(32767.toShort(), sample)
        }
    }

    @Test
    fun resetRestoresDefaultState() {
        val voicePcm = generateSineWave(16000.toShort(), 1000f, 1024)
        engine.analyzeMicFrame(voicePcm)
        for (i in 0 until 1000) {
            engine.mixSample(1000, 1000, 1.0, 1.0, true)
        }
        assertTrue(engine.isDucking)

        engine.reset()
        assertEquals(1.0f, engine.currentFactor, 0.001f)
        assertFalse(engine.isDucking)
        assertFalse(engine.isSpeaking)
    }
}
