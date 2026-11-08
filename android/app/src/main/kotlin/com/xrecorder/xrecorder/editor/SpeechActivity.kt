package com.xrecorder.xrecorder.editor

/** RNNoise activity evidence, not an ASR accuracy/confidence score. */
internal data class SpeechActivity(
    val mean: Double,
    val maximum: Double,
    val voicedRatio: Double,
    val longestVoicedMs: Int,
    val observedFrames: Int,
) {
    init {
        require(mean in 0.0..1.0 && maximum in 0.0..1.0 && voicedRatio in 0.0..1.0)
        require(observedFrames >= 0 && longestVoicedMs >= 0)
    }

    // Be conservative: require >=1s audio and no frame classified as speech.
    // Short/uncertain input still reaches Whisper. The user can bypass this check.
    val noClearSpeech: Boolean
        get() = observedFrames >= 90 && maximum < 0.5 && voicedRatio == 0.0

    fun snapshot() =
        mapOf(
            "mean" to mean,
            "max" to maximum,
            "voicedRatio" to voicedRatio,
            "longestVoicedMs" to longestVoicedMs,
            "observedFrames" to observedFrames,
            "noClearSpeech" to noClearSpeech,
        )

    companion object {
        fun from(values: FloatArray): SpeechActivity {
            require(values.size == 5 && values.all { it.isFinite() })
            require(values[0] in 0f..1f && values[1] in 0f..1f && values[2] in 0f..1f)
            return SpeechActivity(
                values[0].toDouble(),
                values[1].toDouble(),
                values[2].toDouble(),
                values[3].toInt(),
                values[4].toInt(),
            )
        }
    }
}
