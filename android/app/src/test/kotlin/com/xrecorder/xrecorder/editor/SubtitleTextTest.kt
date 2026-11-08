package com.xrecorder.xrecorder.editor

import org.junit.Assert.*
import org.junit.Test

class SubtitleTextTest {
    @Test
    fun malformedTextFailsBeforeRendererOrPublication() {
        for (text in
            listOf(
                "a\u0000b",
                "a\u0008b",
                "a\u007fb",
                "a\ud800b",
                "a\udc00b",
                "\u200b\u2067\u2069",
            )) {
            assertThrows(IllegalArgumentException::class.java) { SubtitleText.requireValid(text) }
        }
    }

    @Test
    fun bidiCombiningAndEmojiRemainUnmodified() {
        val text = "العربية 12:30\n\u2066Video 2\u2069 · हिन्दी 👩🏽‍💻 e\u0301"
        SubtitleText.requireValid(text)
        assertTrue(text.endsWith("e\u0301"))
        assertThrows(IllegalArgumentException::class.java) {
            SubtitleText.requireValid("a".repeat(2001))
        }
    }
}
