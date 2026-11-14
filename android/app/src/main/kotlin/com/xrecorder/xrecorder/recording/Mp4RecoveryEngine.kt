package com.xrecorder.xrecorder.recording

import java.io.File
import java.io.FileInputStream
import java.io.DataInputStream
import java.nio.charset.StandardCharsets

/**
 * Pure Kotlin ISO-BMFF (MP4) container inspection and conditional recovery engine.
 *
 * Implements F53: Safe, non-destructive container validation and conditional recovery
 * under strict media preservation principles:
 * 1. Never overwrites or modifies user media in-place.
 * 2. Never invents data or produces fake 0-byte valid files.
 * 3. Accurately reports ISO-BMFF constraints when 'moov' atom is missing without sample index.
 * 4. Executes conditional recovery via isolated temporary copies with mandatory validation and rollback.
 */
object Mp4RecoveryEngine {

    data class Mp4Box(
        val type: String,
        val offset: Long,
        val size: Long,
        val headerSize: Int
    )

    enum class Mp4Status {
        VALID,
        EMPTY,
        TRUNCATED_MISSING_MOOV,
        TRUNCATED_MDAT,
        CORRUPTED
    }

    data class SessionCheckpoint(
        val sessionId: String,
        val videoFile: File?,
        val audioFile: File?,
        val hasAudio: Boolean = false,
        val configSnapshot: Map<String, Any?>? = null
    ) {
        fun canRecover(): Boolean {
            return videoFile != null && videoFile.exists() && videoFile.length() > 0L
        }
    }

    data class InspectionReport(
        val file: File,
        val fileSize: Long,
        val status: Mp4Status,
        val boxes: List<Mp4Box>,
        val hasFtyp: Boolean,
        val hasMoov: Boolean,
        val hasMdat: Boolean,
        val diagnosticMessage: String,
        val recoveryDecision: RecoveryDecision
    )

    sealed class RecoveryDecision {
        data class Skip(val reason: String) : RecoveryDecision()
        data class Unrecoverable(val reason: String, val technicalConstraint: String) : RecoveryDecision()
        data class RecoverableWithJournal(
            val sessionId: String,
            val videoTempFile: File?,
            val audioTempFile: File?
        ) : RecoveryDecision()
    }

    sealed class RecoveryResult {
        data class Success(val recoveredFile: File, val message: String) : RecoveryResult()
        data class Ignored(val reason: String) : RecoveryResult()
        data class Unrecoverable(val reason: String, val constraint: String) : RecoveryResult()
        data class Failed(val error: String) : RecoveryResult()
    }

    /**
     * Inspects the top-level ISO-BMFF box structure of an MP4 file.
     * Resilient against malformed, partial, or 0-byte files without throwing unhandled exceptions.
     */
    fun inspect(file: File, checkpoint: SessionCheckpoint? = null): InspectionReport =
        inspectSource(file, checkpoint, null)

    /** Inspect a caller-owned seekable stream without reopening a scoped-storage path. */
    fun inspect(input: FileInputStream, label: File, checkpoint: SessionCheckpoint? = null): InspectionReport =
        inspectSource(label, checkpoint, input)

    private fun inspectSource(file: File, checkpoint: SessionCheckpoint?, source: FileInputStream?): InspectionReport {
        val size = source?.channel?.size() ?: if (file.exists()) file.length() else 0L

        if ((source == null && !file.exists()) || size == 0L) {
            val decision = RecoveryDecision.Unrecoverable(
                reason = "File is empty or does not exist.",
                technicalConstraint = "Zero-byte file contains no compressed bitstream payload."
            )
            return InspectionReport(
                file = file,
                fileSize = size,
                status = Mp4Status.EMPTY,
                boxes = emptyList(),
                hasFtyp = false,
                hasMoov = false,
                hasMdat = false,
                diagnosticMessage = "File length is 0 bytes. Media recovery is impossible without payload.",
                recoveryDecision = decision
            )
        }

        if (size < 8L) {
            val decision = RecoveryDecision.Unrecoverable(
                reason = "File size ($size bytes) is smaller than minimum 8-byte container box header.",
                technicalConstraint = "Under ISO-BMFF specification (ISO/IEC 14496-12), box header requires minimum 4-byte size and 4-byte type."
            )
            return InspectionReport(
                file = file,
                fileSize = size,
                status = Mp4Status.CORRUPTED,
                boxes = emptyList(),
                hasFtyp = false,
                hasMoov = false,
                hasMdat = false,
                diagnosticMessage = "File header is corrupted or incomplete.",
                recoveryDecision = decision
            )
        }

        val boxes = mutableListOf<Mp4Box>()
        var readError = false

        try {
            val input = source ?: FileInputStream(file)
            try {
                val raf = DataInputStream(input)
                var offset = 0L
                while (offset + 8L <= size) {
                    input.channel.position(offset)
                    val rawSize = raf.readInt().toLong() and 0xFFFFFFFFL
                    val typeBytes = ByteArray(4)
                    val readType = raf.read(typeBytes)
                    if (readType != 4) {
                        readError = true
                        break
                    }
                    val type = String(typeBytes, StandardCharsets.ISO_8859_1)

                    var headerSize = 8
                    val actualSize = when (rawSize) {
                        1L -> {
                            if (offset + 16L > size) {
                                readError = true
                                break
                            }
                            headerSize = 16
                            raf.readLong()
                        }
                        0L -> {
                            size - offset
                        }
                        else -> rawSize
                    }

                    if (actualSize < headerSize || (rawSize != 0L && offset + actualSize > size)) {
                        boxes.add(Mp4Box(type, offset, actualSize, headerSize))
                        readError = true
                        break
                    }

                    boxes.add(Mp4Box(type, offset, actualSize, headerSize))
                    offset += actualSize
                    if (rawSize == 0L) break
                }
            } finally {
                if (source == null) input.close()
            }
        } catch (_: Exception) {
            readError = true
        }

        val hasFtyp = boxes.any { it.type == "ftyp" }
        val hasMoov = boxes.any { it.type == "moov" }
        val hasMdat = boxes.any { it.type == "mdat" }

        val status: Mp4Status
        val message: String
        val decision: RecoveryDecision

        if (hasMoov && hasMdat && !readError) {
            status = Mp4Status.VALID
            message = "File contains valid 'moov' metadata and 'mdat' media payload. Container structure is complete."
            decision = RecoveryDecision.Skip("File is already complete and playable; no repair needed.")
        } else if (hasMdat && !hasMoov) {
            status = Mp4Status.TRUNCATED_MISSING_MOOV
            message = "File contains 'mdat' payload but lacks 'moov' metadata box. Process was interrupted before MediaMuxer finalization."
            decision = if (checkpoint != null && checkpoint.canRecover()) {
                RecoveryDecision.RecoverableWithJournal(
                    sessionId = checkpoint.sessionId,
                    videoTempFile = checkpoint.videoFile,
                    audioTempFile = checkpoint.audioFile
                )
            } else {
                RecoveryDecision.Unrecoverable(
                    reason = "Interrupted MP4 recording missing 'moov' atom.",
                    technicalConstraint = "Standard Android MediaMuxer constructs sample tables (stbl/stsz/stco/stts) in volatile memory and only writes the 'moov' atom upon clean finalization. If unfinalized, sample offsets are lost. Unrecoverable without bitstream parser or donor index."
                )
            }
        } else if (hasFtyp && !hasMdat && !hasMoov) {
            status = Mp4Status.TRUNCATED_MDAT
            message = "File contains 'ftyp' header but no media payload ('mdat') or movie metadata ('moov') was written."
            decision = RecoveryDecision.Unrecoverable(
                reason = "No media payload was written to container.",
                technicalConstraint = "Encoder terminated before any sample frames could be written."
            )
        } else {
            status = Mp4Status.CORRUPTED
            message = "Container header does not conform to ISO-BMFF specification or has truncated box sizes."
            decision = RecoveryDecision.Unrecoverable(
                reason = "Corrupted container header.",
                technicalConstraint = "File lacks valid 'ftyp' or recognized ISO-BMFF atoms."
            )
        }

        return InspectionReport(
            file = file,
            fileSize = size,
            status = status,
            boxes = boxes,
            hasFtyp = hasFtyp,
            hasMoov = hasMoov,
            hasMdat = hasMdat,
            diagnosticMessage = message,
            recoveryDecision = decision
        )
    }

    /**
     * Executes conditional recovery on a file according to strict media preservation rules:
     * - If valid: ignores/skips.
     * - If unrecoverable: returns failure without modifying the file.
     * - If recoverable with checkpoint: performs copy/remux on an isolated temp file,
     *   validates the result, and rolls back if validation fails.
     */
    fun attemptRecovery(
        corruptedFile: File,
        outputFile: File,
        checkpoint: SessionCheckpoint? = null,
        remuxer: ((video: File, audio: File?, target: File) -> Boolean)? = null
    ): RecoveryResult {
        val report = inspect(corruptedFile, checkpoint)
        when (val decision = report.recoveryDecision) {
            is RecoveryDecision.Skip -> {
                return RecoveryResult.Ignored(decision.reason)
            }
            is RecoveryDecision.Unrecoverable -> {
                return RecoveryResult.Unrecoverable(decision.reason, decision.technicalConstraint)
            }
            is RecoveryDecision.RecoverableWithJournal -> {
                val video = decision.videoTempFile
                if (video == null || !video.exists() || video.length() == 0L) {
                    return RecoveryResult.Failed("Video source file from checkpoint is missing or empty.")
                }

                val parent = outputFile.parentFile ?: video.parentFile ?: File(".")
                val tempOutput = File(parent, "${outputFile.name}.recovery_${System.currentTimeMillis()}.tmp")

                try {
                    val success = if (remuxer != null) {
                        remuxer(video, decision.audioTempFile, tempOutput)
                    } else {
                        video.copyTo(tempOutput, overwrite = true)
                        tempOutput.exists() && tempOutput.length() > 0L
                    }

                    if (!success || !tempOutput.exists() || tempOutput.length() == 0L) {
                        tempOutput.delete()
                        return RecoveryResult.Failed("Remuxing from checkpoint failed.")
                    }

                    // Verify output structure
                    val verifyReport = inspect(tempOutput)
                    if (verifyReport.status != Mp4Status.VALID) {
                        tempOutput.delete()
                        return RecoveryResult.Failed("Recovered file verification failed: ${verifyReport.diagnosticMessage}")
                    }

                    // Promoted atomically
                    if (outputFile.exists()) outputFile.delete()
                    if (!tempOutput.renameTo(outputFile)) {
                        tempOutput.copyTo(outputFile, overwrite = true)
                        tempOutput.delete()
                    }
                    return RecoveryResult.Success(outputFile, "Successfully recovered MP4 from checkpoint streams.")
                } catch (e: Exception) {
                    tempOutput.delete()
                    return RecoveryResult.Failed("Recovery failed with exception: ${e.message}")
                }
            }
        }
    }
}
