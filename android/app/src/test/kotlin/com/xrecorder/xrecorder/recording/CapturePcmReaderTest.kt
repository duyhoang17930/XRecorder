package com.xrecorder.xrecorder.recording

import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class CapturePcmReaderTest {
    @Test fun codecStallWithinThreeSecondGracePreservesAllPcmUntilConsumerResumes() {
        var position = 0
        val supplied = CountDownLatch(1)
        val reader = CapturePcmReader(read = { data, _, size ->
            if (position < 140) { data.fill(position++.toShort()); size }
            else { supplied.countDown(); 0 }
        }, origin = { 1L })
        reader.start()
        try {
            //140mono1024sample blocks represent2.987s at48kHz, still inside
            // SessionAudio's existing3s codec-input grace period.
            assertTrue(supplied.await(2, TimeUnit.SECONDS))
            for (index in 0 until 140)
                assertArrayEquals(ShortArray(1024) { index.toShort() }, reader.poll())
            assertNull(reader.poll())
        } finally { reader.finish() }
    }

    @Test fun partialReadsPreserveEverySampleAndQueuedBlocksDoNotAlias() {
        var position = 0
        val supplied = CountDownLatch(1)
        val reader = CapturePcmReader(read = { data, offset, size ->
            val count = minOf(size, 137, 2048 - position)
            if (count == 0) supplied.countDown()
            for (i in 0 until count) data[offset + i] = (position + i).toShort()
            position += count
            count
        }, origin = { 123456789L })
        reader.start()
        try {
            assertTrue(supplied.await(2, TimeUnit.SECONDS))
            val suppliedByNs = System.nanoTime()
            val first = requireNotNull(reader.poll())
            val firstReadyNs = reader.lastBlockReadyNs
            val second = requireNotNull(reader.poll())
            assertTrue(firstReadyNs > 0 && firstReadyNs <= reader.lastBlockReadyNs)
            assertTrue(reader.lastBlockReadyNs <= suppliedByNs)
            assertArrayEquals(ShortArray(1024) { it.toShort() }, first)
            assertArrayEquals(ShortArray(1024) { (it + 1024).toShort() }, second)
            assertEquals(123456789L, reader.originNs)
            assertEquals(2048L, reader.capturedSamples)
            assertEquals(0, reader.queuedBlocks)
            assertNull(reader.poll())
        } finally { reader.finish() }
    }

    @Test fun saturationFailsRatherThanDroppingOldOrNewPcm() {
        val failed = CountDownLatch(1)
        val reads = AtomicInteger()
        val reader = CapturePcmReader(read = { data, offset, size ->
            data.fill(reads.incrementAndGet().toShort(), offset, offset + size)
            size
        }, origin = { 1L }, failed = { failed.countDown() }, capacity = 1)
        reader.start()
        assertTrue(failed.await(2, TimeUnit.SECONDS))
        assertEquals(2, reads.get())
        assertThrows(IOException::class.java) { reader.poll() }
        assertThrows(IOException::class.java) { reader.finish() }
    }

    @Test fun sourceFailureIsPropagatedAndReaderTerminates() {
        val failed = CountDownLatch(1)
        val reader = CapturePcmReader(read = { _, _, _ -> -3 }, origin = { 1L },
            failed = { failed.countDown() })
        reader.start()
        assertTrue(failed.await(2, TimeUnit.SECONDS))
        assertThrows(IOException::class.java) { reader.poll() }
        assertThrows(IOException::class.java) { reader.finish() }
    }

    @Test fun stoppingAnEmptySourceDoesNotInventAudioOrFailure() {
        val entered = CountDownLatch(1)
        val reader = CapturePcmReader(read = { _, _, _ -> entered.countDown(); 0 }, origin = { 1L })
        reader.start()
        assertTrue(entered.await(2, TimeUnit.SECONDS))
        reader.finish()
        assertNull(reader.poll())
        assertEquals(0L, reader.originNs)
    }

    @Test fun pauseDiscardsQueuedAndNewBlocksWithoutReplayingThem() {
        val delivered = CountDownLatch(1)
        val discard = java.util.concurrent.atomic.AtomicBoolean(false)
        val discarded = CountDownLatch(1)
        val resumed = CountDownLatch(1)
        val phase = AtomicInteger(0)
        val reader = CapturePcmReader(read = { data, offset, size ->
            when (phase.get()) {
                0 -> { data.fill(7); phase.set(1); size }
                1 -> { delivered.countDown(); 0 }
                2 -> { data.fill(8); phase.set(3); size }
                3 -> { discarded.countDown(); 0 }
                4 -> { data.fill(9); phase.set(5); size }
                else -> { resumed.countDown(); 0 }
            }
        }, origin = { 1L }, discard = { discard.get() })
        reader.start()
        try {
            assertTrue(delivered.await(2, TimeUnit.SECONDS))
            discard.set(true)
            reader.discardQueued()
            phase.set(2)
            assertTrue(discarded.await(2, TimeUnit.SECONDS))
            assertNull(reader.poll())
            discard.set(false)
            phase.set(4)
            assertTrue(resumed.await(2, TimeUnit.SECONDS))
            assertArrayEquals(ShortArray(1024) { 9 }, reader.poll())
            assertNull(reader.poll())
        } finally { reader.finish() }
    }
}
