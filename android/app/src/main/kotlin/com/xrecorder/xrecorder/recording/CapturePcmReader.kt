package com.xrecorder.xrecorder.recording

import java.io.IOException
import java.util.concurrent.ArrayBlockingQueue

/** Drains the small playback-capture FIFO independently of microphone/AAC work.
 * Queue saturation is an explicit failure, never a silent dropped audio block.
 * Owns only PCM and its thread; SessionAudio still owns AudioRecord and AAC.
 */
internal class CapturePcmReader(
    private val read: (ShortArray, Int, Int) -> Int,
    private val origin: () -> Long,
    private val prepareThread: () -> Unit = {},
    private val discard: () -> Boolean = { false },
    private val failed: (Exception) -> Unit = {},
    //4.096s/384KiB at48k mono. Must exceed the AAC input's3s stall
    // grace; a shorter FIFO aborts recoverable codec startup stalls early.
    capacity: Int = 192,
) {
    private data class Block(val pcm: ShortArray, val readyNs: Long)
    private val blocks = ArrayBlockingQueue<Block>(capacity)
    @Volatile private var stopping = false
    @Volatile private var failure: Exception? = null
    @Volatile var originNs = 0L
        private set
    @Volatile var capturedSamples = 0L
        private set
    val queuedBlocks: Int get() = blocks.size
    var lastBlockReadyNs = 0L
        private set
    private var worker: Thread? = null

    fun start() {
        check(worker == null)
        worker = Thread({
            try {
                prepareThread()
                var block = ShortArray(1024)
                var count = 0
                var lastReadNs = System.nanoTime()
                while (!stopping) {
                    val size = read(block, count, block.size - count)
                    if (stopping) break
                    if (size < 0 || size > block.size - count) throw IOException("Internal audio capture was interrupted")
                    if (size == 0) {
                        if (System.nanoTime() - lastReadNs > 3_000_000_000L)
                            throw IOException("Internal audio stopped supplying PCM")
                        Thread.sleep(2)
                        continue
                    }
                    lastReadNs = System.nanoTime()
                    capturedSamples += size
                    count += size
                    if (originNs == 0L) originNs = origin()
                    if (discard()) {
                        count = 0
                        blocks.clear()
                        continue
                    }
                    if (count == block.size) {
                        if (!blocks.offer(Block(block, System.nanoTime()))) throw IOException("Audio encoder cannot keep up with capture")
                        block = ShortArray(1024)
                        count = 0
                    }
                }
            } catch (error: Exception) {
                if (!stopping) {
                    failure = error
                    failed(error)
                }
            }
        }, "playback-pcm").apply { start() }
    }

    fun poll(): ShortArray? {
        failure?.let { throw it }
        val block = blocks.poll() ?: return null
        lastBlockReadyNs = block.readyNs
        return block.pcm
    }

    fun requestStop() { stopping = true }

    fun discardQueued() { blocks.clear() }

    fun finish() {
        requestStop()
        worker?.join(2000)
        check(worker?.isAlive != true) { "Internal audio reader did not stop" }
        failure?.let { throw it }
    }
}
