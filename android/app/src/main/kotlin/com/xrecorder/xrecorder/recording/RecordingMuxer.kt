package com.xrecorder.xrecorder.recording

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.File
import java.nio.ByteBuffer

object RecordingMuxer {
    fun combine(video: File, audio: File, output: MediaOutput, descriptor: ParcelFileDescriptor, audioOffsetUs: Long, durationUs: Long) {
        val videoReader = MediaExtractor(); val audioReader = MediaExtractor()
        var muxer: MediaMuxer? = null; var muxing = false
        try {
            videoReader.setDataSource(video.absolutePath); audioReader.setDataSource(audio.absolutePath)
            val vIndex = (0 until videoReader.trackCount).first { videoReader.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
            val aIndex = (0 until audioReader.trackCount).first { audioReader.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
            val writer = if (Build.VERSION.SDK_INT >= 26) MediaMuxer(descriptor.fileDescriptor,MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4) else MediaMuxer(output.legacyPath!!,MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = writer
            val vTrack = writer.addTrack(videoReader.getTrackFormat(vIndex)); val aTrack = writer.addTrack(audioReader.getTrackFormat(aIndex))
            videoReader.selectTrack(vIndex); audioReader.selectTrack(aIndex); writer.start(); muxing = true
            val data = ByteBuffer.allocateDirect(16*1024*1024)
            val info = MediaCodec.BufferInfo()
            var lastVideo = -1L; var lastAudio = -1L
            while (videoReader.sampleTrackIndex >= 0 || audioReader.sampleTrackIndex >= 0) {
                val hasVideo=videoReader.sampleTrackIndex>=0;val hasAudio=audioReader.sampleTrackIndex>=0
                val vt = videoReader.sampleTime
                val at = audioReader.sampleTime + audioOffsetUs
                // AAC priming can have a negative timestamp; track index identifies EOS.
                if (hasAudio && at < 0) { audioReader.advance(); continue }
                val isVideo = hasVideo && (!hasAudio || vt <= at)
                val reader = if (isVideo) videoReader else audioReader
                val time = if (isVideo) vt else at
                if (time >= durationUs) { reader.advance(); continue }
                data.clear(); val count = reader.readSampleData(data,0)
                if (count < 0) { reader.advance(); continue }
                require(count <= data.capacity()) { "Encoded frame is too large" }
                val pts = maxOf(time, (if (isVideo) lastVideo else lastAudio)+1,0)
                info.set(0,count,pts,reader.sampleFlags and MediaCodec.BUFFER_FLAG_KEY_FRAME)
                writer.writeSampleData(if (isVideo) vTrack else aTrack,data,info)
                if (isVideo) lastVideo=pts else lastAudio=pts
                reader.advance()
            }
            require(lastVideo >= 0 && lastAudio >= 0) { "An audio/video track is empty" }
            info.set(0,0,maxOf(durationUs,lastVideo+1),MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            writer.writeSampleData(vTrack,ByteBuffer.allocate(0),info)
            writer.stop(); muxing = false
        } finally {
            if (muxing) try { muxer?.stop() } catch (_: Exception) { }
            muxer?.release(); videoReader.release(); audioReader.release()
        }
    }
}
