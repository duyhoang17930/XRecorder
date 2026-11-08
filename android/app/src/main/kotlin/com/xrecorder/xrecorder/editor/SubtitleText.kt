package com.xrecorder.xrecorder.editor

import android.icu.text.BreakIterator
import java.util.Locale

/** Shared subtitle text boundaries, independent of interface direction/locale. */
internal object SubtitleText {
    fun requireValid(text: String, maximumUnits: Int = 2000) {
        require(text.isNotEmpty() && text.length <= maximumUnits) {
            "Subtitle text is empty or too long."
        }
        var i = 0
        while (i < text.length) {
            val c = text[i]
            require(
                !(c.code in 0..8 || c.code in 11..12 || c.code in 14..31 || c.code in 127..159),
            ) {
                "Subtitle text contains unsupported control characters."
            }
            if (Character.isHighSurrogate(c)) {
                require(i + 1 < text.length && Character.isLowSurrogate(text[i + 1])) {
                    "Subtitle text contains incomplete symbols."
                }
                i += 2
            } else {
                require(!Character.isLowSurrogate(c)) {
                    "Subtitle text contains incomplete symbols."
                }
                i++
            }
        }
        require(
            text.any {
                !it.isWhitespace() &&
                    it.code !in 0x200b..0x200f &&
                    it.code !in 0x202a..0x202e &&
                    it.code !in 0x2060..0x206f &&
                    it.code != 0xfeff
            },
        ) {
            "Enter visible subtitle text."
        }
    }

    /** Soft limit: preserve a whole grapheme instead of splitting a surrogate/ZWJ. */
    fun chunks(text: String, limit: Int = 240): List<String> {
        require(limit in 1..2000)
        requireValid(text, Int.MAX_VALUE)
        val boundaries = BreakIterator.getCharacterInstance(Locale.ROOT)
        boundaries.setText(text)
        val result = mutableListOf<String>()
        var start = 0
        var previous = boundaries.first()
        var end = boundaries.next()
        while (end != BreakIterator.DONE) {
            if (end - start > limit && previous > start) {
                result.add(text.substring(start, previous))
                start = previous
            }
            require(end - start <= 2000) { "A subtitle symbol is too long." }
            previous = end
            end = boundaries.next()
        }
        if (start < text.length) result.add(text.substring(start))
        return result
    }
}
