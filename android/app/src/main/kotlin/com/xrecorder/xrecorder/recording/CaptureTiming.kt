package com.xrecorder.xrecorder.recording

/** Deadline arithmetic only; the existing service Handler and native session own timers. */
internal object CaptureTiming {
    fun countdownSeconds(remainingMs: Long): Int =
        ((remainingMs.coerceAtLeast(0) + 999) / 1000).toInt()

    fun autoStopRemainingMs(state: String, elapsedActiveMs: Long, durationSeconds: Int): Long? {
        if (durationSeconds <= 0 || state !in listOf("recording", "paused")) return null
        val remaining = (durationSeconds * 1000L - elapsedActiveMs.coerceAtLeast(0)).coerceAtLeast(0)
        // Pausing at/after the boundary must not defer an already-due Stop until Resume.
        return if (state == "paused" && remaining > 0) null else remaining
    }
}
