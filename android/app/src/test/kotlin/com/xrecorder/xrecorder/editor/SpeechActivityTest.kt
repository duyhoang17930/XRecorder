package com.xrecorder.xrecorder.editor

import org.junit.Assert.*
import org.junit.Test

class SpeechActivityTest {
    @Test
    fun measuredSpeechAndNoiseStayOnDifferentPaths() {
        // Actual API36 probe: quietest speech activity was Chinese, not noise.
        assertFalse(SpeechActivity(0.3629, 0.9999, 0.357, 430, 1028).noClearSpeech)
        // Real Vietnamese with added 5dB white noise still contains speech.
        assertFalse(SpeechActivity(0.45, 1.0, 0.454, 790, 1100).noClearSpeech)
        assertTrue(SpeechActivity(0.0169, 0.325, 0.0, 0, 590).noClearSpeech)
        assertTrue(SpeechActivity(0.0607, 0.4193, 0.0, 0, 590).noClearSpeech)
    }

    @Test
    fun shortOrUncertainInputMustNotBeSilentlyDiscarded() {
        assertFalse(SpeechActivity(0.0, 0.0, 0.0, 0, 20).noClearSpeech)
        assertFalse(SpeechActivity(0.1, 0.6, 0.01, 10, 590).noClearSpeech)
        assertThrows(IllegalArgumentException::class.java) {
            SpeechActivity.from(floatArrayOf(Float.NaN, 0f, 0f, 0f, 0f))
        }
    }
}
