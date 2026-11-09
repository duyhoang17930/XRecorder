package com.xrecorder.xrecorder.editor

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.transformer.Effects
import androidx.media3.transformer.TransformerUtil
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.*
import org.junit.Test

class TimelineAudioLimitTest {
    @Test
    fun trimsMixedTailWithoutChangingPrefixAndConsumesAllInput() {
        val processor = TimelineAudioLimit(4000000)
        processor.configure(AudioProcessor.AudioFormat(48000, 2, C.ENCODING_PCM_16BIT))
        processor.flush(AudioProcessor.StreamMetadata.DEFAULT)
        val input = ByteBuffer.allocateDirect(195840 * 4).order(ByteOrder.nativeOrder())
        repeat(195840 * 2) { input.putShort((it % 32000).toShort()) }
        input.flip()
        processor.queueInput(input)
        assertFalse(input.hasRemaining())
        val output = processor.output
        assertEquals(192000 * 4, output.remaining())
        repeat(192000 * 2) { assertEquals((it % 32000).toShort(), output.short) }
        // Media3 feeds the shared EMPTY_BUFFER while a mixer is draining.
        // Never attempt EMPTY_BUFFER.put(EMPTY_BUFFER).
        processor.queueInput(AudioProcessor.EMPTY_BUFFER)
        assertFalse(processor.output.hasRemaining())
        processor.queueEndOfStream()
        assertFalse(processor.output.hasRemaining())
        assertTrue(processor.isEnded)
        assertEquals(1000000000L, processor.getDurationAfterProcessorApplied(1000000000))
        assertFalse(TransformerUtil.containsSpeedChangingEffects(
            Effects(listOf(processor), emptyList()), false,
        ))
    }

    @Test
    fun seekAndFlushUseOutputTimelineAndNeverPadShortAudio() {
        val processor = TimelineAudioLimit(4000000)
        processor.configure(AudioProcessor.AudioFormat(44100, 1, C.ENCODING_PCM_FLOAT))
        val seek = AudioProcessor.StreamMetadata.Builder().setPositionOffsetUs(1250000).build()
        processor.flush(seek)
        val input = ByteBuffer.allocateDirect(44100 * 3 * 4).order(ByteOrder.nativeOrder())
        processor.queueInput(input)
        assertEquals(121275 * 4, processor.output.remaining())
        processor.flush(AudioProcessor.StreamMetadata.DEFAULT)
        processor.queueInput(ByteBuffer.allocateDirect(100 * 4))
        assertEquals(100 * 4, processor.output.remaining())
        processor.queueEndOfStream()
        assertFalse(processor.output.hasRemaining())
        processor.flush(AudioProcessor.StreamMetadata.Builder().setPositionOffsetUs(5000000).build())
        processor.queueInput(ByteBuffer.allocateDirect(100 * 4))
        assertFalse(processor.output.hasRemaining())
        processor.reset()
    }
}
