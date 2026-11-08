package com.xrecorder.xrecorder.editor

import org.junit.Assert.*
import org.junit.Test

class SpeechMemoryTest {
    private val mib = 1024L * 1024

    @Test
    fun preservesSystemReserveInsteadOfSpendingAllAvailableRam() {
        val required = speechMemoryRequiredBytes("tiny", 1000, 315 * mib)
        assertEquals((384 + 128 + 315) * mib + 192000, required)
        // The old192MiB check accepted this constrained budget despite the
        // measured316MiB RSS/LOW_MEMORY exit on the2GiB16KB runtime.
        assertTrue(192 * mib < 500 * mib)
        assertTrue(required > 500 * mib)
    }

    @Test
    fun accountsForModelAndLongAudioAndChangingSystemPressure() {
        val tiny = speechMemoryRequiredBytes("tiny", 100, 0)
        assertTrue(speechMemoryRequiredBytes("base", 100, 0) > tiny)
        assertTrue(
            speechMemoryRequiredBytes("small-q5_1", 100, 0) >
                speechMemoryRequiredBytes("base", 100, 0),
        )
        assertTrue(speechMemoryRequiredBytes("tiny", 600000, 0) - tiny > 100 * mib)
        assertTrue(speechMemoryRequiredBytes("tiny", 100, 512 * mib) > tiny)
    }

    @Test
    fun rejectsInvalidInputsAndOverflow() {
        assertThrows(IllegalArgumentException::class.java) {
            speechMemoryRequiredBytes("unknown", 1000, 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            speechMemoryRequiredBytes("tiny", 99, 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            speechMemoryRequiredBytes("tiny", 600001, 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            speechMemoryRequiredBytes("tiny", 1000, -1)
        }
        assertThrows(ArithmeticException::class.java) {
            speechMemoryRequiredBytes("tiny", 1000, Long.MAX_VALUE)
        }
    }
}
