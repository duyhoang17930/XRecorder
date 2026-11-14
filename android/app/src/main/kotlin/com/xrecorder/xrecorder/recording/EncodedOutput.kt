package com.xrecorder.xrecorder.recording

import android.media.MediaCodec
import android.media.MediaFormat
import java.nio.ByteBuffer

/** Optional synchronous observer. Copy samples before returning; never retain
 * codec-owned buffers or block on network I/O. Existing MP4 writer stays owner.
 */
interface EncodedOutput {
    fun format(value: MediaFormat)
    fun sample(buffer: ByteBuffer, info: MediaCodec.BufferInfo, originNs: Long)
}
