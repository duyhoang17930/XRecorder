package com.xrecorder.xrecorder.editor

import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.ParcelFileDescriptor
import com.xrecorder.xrecorder.recording.MediaOutput
import java.io.File

/** Transformer already muxes MP4. Publish that file without assuming an audio track exists. */
object EditorOutput {
    fun publish(source: File, output: MediaOutput) {
        require(source.length() > 0) { "The renderer produced an empty file." }
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(source.absolutePath)
            val video =
                (0 until extractor.trackCount).firstOrNull {
                    extractor
                        .getTrackFormat(it)
                        .getString(MediaFormat.KEY_MIME)
                        ?.startsWith("video/") == true
                } ?: error("The renderer produced no video track.")
            extractor.selectTrack(video)
            require(extractor.sampleTime >= 0) { "The video track is empty." }
        } finally {
            extractor.release()
        }
        val fd = output.open()
        ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(fd.fileDescriptor))
            .use { stream ->
                source.inputStream().use { it.copyTo(stream) }
                stream.flush()
            }
    }
}
