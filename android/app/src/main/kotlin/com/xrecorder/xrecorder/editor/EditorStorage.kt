package com.xrecorder.xrecorder.editor

/** Conservative scratch+publish reserve. Kept independent of StatFs for boundary tests. */
object EditorStorage {
    fun requiredBytes(
        durationUs: Long,
        bitrate: Int = 0,
        gif: Boolean = false,
        gifEdge: Int = 320,
        gifFps: Int = 10,
    ): Long {
        require(
            durationUs in 1..86400000000 && bitrate >= 0 && gifEdge in 1..480 && gifFps in 1..20,
        )
        val seconds = (durationUs + 999999) / 1000000
        val encoded =
            seconds * (if (bitrate > 0) bitrate.toLong() else 8000000L) / 8 + seconds * 32000
        val destination = if (gif) seconds * gifEdge * gifEdge * gifFps * 2L else encoded
        return encoded + destination + 32L * 1024 * 1024
    }

    fun requireSpace(free: Long, required: Long) {
        require(free >= required) {
            "Not enough storage for export and its safe copy. Free space or choose a smaller output."
        }
    }
}
