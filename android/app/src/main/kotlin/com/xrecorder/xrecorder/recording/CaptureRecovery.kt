package com.xrecorder.xrecorder.recording

import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.StatFs
import androidx.core.content.FileProvider
import android.provider.MediaStore
import java.io.File

/** Conditional recovery of a finalized capture, never a fabricated MP4 index.
 * The caller retains all interrupted inputs before this worker inspects them.
 */
internal object CaptureRecovery {
    data class Recovered(val uri: String, val width: Int, val height: Int)

    internal fun eligible(authority: String?, owner: String?, expectedOwner: String, pending: Int): Boolean =
        authority == "media" && owner == expectedOwner && pending in 0..1

    fun recover(
        context: Context, reference: String?, config: CaptureConfig, screenshot: Boolean,
        finalized: FinalizedCapture? = null, recoveryReference: String? = null,
        onRecoveryPending: (Uri) -> Unit = {}
    ): Recovered? {
        completedCandidate(context, reference, config, screenshot)?.let { return it }
        val name = finalized?.let { "Recovered_${it.sessionId}.mp4" }
        if (name != null) completedCandidate(context, recoveryReference, config, false, name)?.let { return it }
        if (screenshot || !config.hasAudio || finalized == null) return null
        var output: MediaOutput? = null
        return runCatching {
            require(FinalizedCapture.restore(finalized.map(), finalized.sessionId) != null)
            val video = File(context.cacheDir, "capture_${finalized.sessionId}.mp4")
            val audio = File(context.cacheDir, "capture_${finalized.sessionId}.m4a")
            finalizedStream(video, true, config)
            finalizedStream(audio, false, config)
            require(StatFs(context.cacheDir.absolutePath).availableBytes > video.length() + audio.length() + 64L * 1024 * 1024)
            var target = recoveryReference?.let(Uri::parse)
            val writer = MediaOutput(context, requireNotNull(name), onPending = { uri ->
                target = uri
                onRecoveryPending(uri)
            })
            output = writer
            val descriptor = if (target == null) writer.open() else writer.resumePending(target)
            RecordingMuxer.combine(video, audio, writer, descriptor, finalized.audioOffsetUs, finalized.durationUs)
            val dimensions = validateBytes(context, requireNotNull(target), config, false)
            val uri = writer.commit()
            Recovered(uri.toString(), dimensions.first, dimensions.second)
        }.onFailure {
            // Keep both source files and this job's pending destination for retry.
            output?.retain()
            android.util.Log.w("CaptureRecovery", "Finalized stream remux failed; inputs retained", it)
        }.getOrNull()
    }

    private fun completedCandidate(
        context: Context, reference: String?, config: CaptureConfig, screenshot: Boolean, expectedName: String? = null
    ): Recovered? {
        if (reference == null) return null
        return runCatching {
            val original = Uri.parse(reference)
            val resolver = context.contentResolver
            var legacyFile: File? = null
            val uri: Uri
            val pending: Int
            if (Build.VERSION.SDK_INT >= 29) {
                require(original.scheme == "content" && original.authority == "media")
                pending = resolver.query(original, arrayOf(
                    MediaStore.MediaColumns.OWNER_PACKAGE_NAME, MediaStore.MediaColumns.IS_PENDING,
                    MediaStore.MediaColumns.DISPLAY_NAME
                ), null, null, null)?.use { cursor ->
                    require(cursor.moveToFirst())
                    val value = cursor.getInt(1)
                    require(eligible(original.authority, cursor.getString(0), context.packageName, value))
                    require(expectedName == null || cursor.getString(2) == expectedName)
                    value
                } ?: return null
                uri = original
            } else {
                require(original.scheme == "file")
                val source = File(requireNotNull(original.path)).canonicalFile
                val directory = File(context.getExternalFilesDir(null), "media").canonicalFile
                require(source.parentFile == directory && source.name.endsWith(".pending"))
                require(source.name.matches(Regex("(Recording_[0-9]+[.]mp4|Screenshot_[0-9]+[.]png|Recovered_[a-fA-F0-9-]{36}[.]mp4)[.]pending")))
                require(expectedName == null || source.name == "$expectedName.pending")
                legacyFile = if (source.exists()) source else File(directory, source.name.removeSuffix(".pending"))
                require(legacyFile.isFile)
                pending = if (source.exists()) 1 else 0
                uri = Uri.fromFile(legacyFile)
            }
            val dimensions = validateBytes(context, uri, config, screenshot)
            val published = if (legacyFile != null) {
                var file = legacyFile
                if (pending == 1) {
                    val destination = File(file.parentFile, file.name.removeSuffix(".pending"))
                    require(!destination.exists() && file.renameTo(destination))
                    file = destination
                }
                FileProvider.getUriForFile(context, "${context.packageName}.files", file)
            } else {
                if (pending == 1) require(resolver.update(uri, ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }, null, null) == 1)
                uri
            }
            Recovered(published.toString(), dimensions.first, dimensions.second)
        }.onFailure {
            android.util.Log.w("CaptureRecovery", "Finalized capture validation failed; inputs retained", it)
        }.getOrNull()
    }

    private fun finalizedStream(file: File, video: Boolean, config: CaptureConfig) {
        require(file.isFile && Mp4RecoveryEngine.inspect(file).status == Mp4RecoveryEngine.Mp4Status.VALID)
        val reader = MediaExtractor()
        try {
            reader.setDataSource(file.absolutePath)
            require(reader.trackCount == 1)
            val format = reader.getTrackFormat(0)
            require(format.getString(MediaFormat.KEY_MIME) == if (video) config.mime else "audio/mp4a-latm")
            if (video) require(format.getInteger(MediaFormat.KEY_WIDTH) == config.width &&
                format.getInteger(MediaFormat.KEY_HEIGHT) == config.height)
            reader.selectTrack(0)
            require(reader.sampleTrackIndex >= 0)
        } finally { reader.release() }
    }

    private fun validateBytes(context: Context, uri: Uri, config: CaptureConfig, screenshot: Boolean): Pair<Int, Int> {
        val resolver = context.contentResolver
        return if (screenshot) {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
                require(bounds.outMimeType == "image/png" && bounds.outWidth > 0 && bounds.outHeight > 0)
                val sample = BitmapFactory.Options().apply {
                    inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / 256)
                }
                val bitmap = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, sample) }
                requireNotNull(bitmap).recycle()
                bounds.outWidth to bounds.outHeight
        } else {
                resolver.openFileDescriptor(uri, "r")?.use { descriptor ->
                    require(descriptor.statSize > 0)
                    // Inspect the same seekable descriptor without duplicating a large file.
                    val report = android.os.ParcelFileDescriptor.AutoCloseInputStream(
                        android.os.ParcelFileDescriptor.dup(descriptor.fileDescriptor)
                    ).use { input -> Mp4RecoveryEngine.inspect(input, File("/proc/self/fd/${descriptor.fd}")) }
                    require(report.status == Mp4RecoveryEngine.Mp4Status.VALID) { report.diagnosticMessage }
                    val extractor = MediaExtractor()
                    try {
                        extractor.setDataSource(descriptor.fileDescriptor)
                        val formats = (0 until extractor.trackCount).map { extractor.getTrackFormat(it) }
                        val video = formats.filter { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                        val audio = formats.filter { it.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
                        require(video.size == 1 && audio.size == if (config.hasAudio) 1 else 0)
                        require(video.single().getString(MediaFormat.KEY_MIME) == config.mime)
                        require(video.single().getInteger(MediaFormat.KEY_WIDTH) == config.width &&
                            video.single().getInteger(MediaFormat.KEY_HEIGHT) == config.height)
                    } finally { extractor.release() }
                    val metadata = MediaMetadataRetriever()
                    try {
                        metadata.setDataSource(descriptor.fileDescriptor)
                        require((metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0) > 0)
                        val frame = metadata.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        requireNotNull(frame).recycle()
                    } finally { metadata.release() }
                    config.width to config.height
                } ?: error("Capture output cannot be opened")
            }
    }
}
