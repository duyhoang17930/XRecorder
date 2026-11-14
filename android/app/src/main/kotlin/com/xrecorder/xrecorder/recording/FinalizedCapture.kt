package com.xrecorder.xrecorder.recording

/** Timing belongs to one pair of finalized encoder files, never to a later session. */
data class FinalizedCapture(val sessionId: String, val durationUs: Long, val audioOffsetUs: Long) {
    fun map(): Map<String, Any> = mapOf(
        "sessionId" to sessionId, "durationUs" to durationUs, "audioOffsetUs" to audioOffsetUs
    )

    companion object {
        fun restore(values: Map<*, *>?, expectedSession: String): FinalizedCapture? {
            if (!expectedSession.matches(Regex("[a-fA-F0-9-]{36}")) || values == null) return null
            val session = values["sessionId"] as? String ?: return null
            val duration = (values["durationUs"] as? Number)?.toLong() ?: return null
            val offset = (values["audioOffsetUs"] as? Number)?.toLong() ?: return null
            if (session != expectedSession || duration !in 1..86_400_000_000L ||
                // Audio starts before the first video frame. Its startup lead can
                // exceed a very short video's whole duration; the muxer trims it.
                // Capture startup times out after15s; retain a bounded60s margin.
                offset < -60_000_000L || offset >= duration) return null
            return FinalizedCapture(session, duration, offset)
        }
    }
}
