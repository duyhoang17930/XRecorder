package com.xrecorder.xrecorder.recording

/** Deadline arithmetic only; the existing service Handler and native session own timers. */
internal object CaptureTiming {
    fun screenshotDelay(value: Any?): Int {
        require(value == null || value is Number) { "Invalid screenshot delay" }
        val number = value as? Number
        val seconds = number?.toInt() ?: 3
        require((number == null || number.toDouble() == seconds.toDouble()) && seconds in listOf(1, 3, 5, 10)) {
            "Choose a screenshot delay of 1, 3, 5 or 10 seconds."
        }
        return seconds
    }
    fun countdownSeconds(remainingMs: Long): Int =
        ((remainingMs.coerceAtLeast(0) + 999) / 1000).toInt()

    fun autoStopRemainingMs(state: String, elapsedActiveMs: Long, durationSeconds: Int): Long? {
        if (durationSeconds <= 0 || state !in listOf("recording", "paused")) return null
        val remaining = (durationSeconds * 1000L - elapsedActiveMs.coerceAtLeast(0)).coerceAtLeast(0)
        // Pausing at/after the boundary must not defer an already-due Stop until Resume.
        return if (state == "paused" && remaining > 0) null else remaining
    }
}
