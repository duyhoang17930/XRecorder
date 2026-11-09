package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets

class Mp4RecoveryEngineTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun createBox(type: String, payload: ByteArray): ByteArray {
        val size = 8 + payload.size
        val buffer = ByteBuffer.allocate(size)
        buffer.putInt(size)
        buffer.put(type.toByteArray(StandardCharsets.ISO_8859_1))
        buffer.put(payload)
        return buffer.array()
    }

    private fun create64BitBox(type: String, payload: ByteArray): ByteArray {
        val size = 16 + payload.size
        val buffer = ByteBuffer.allocate(size)
        buffer.putInt(1) // Marker for 64-bit size
        buffer.put(type.toByteArray(StandardCharsets.ISO_8859_1))
        buffer.putLong(size.toLong())
        buffer.put(payload)
        return buffer.array()
    }

    @Test
    fun emptyFile_isDetectedAsEmpty_andUnrecoverable() {
        val file = tempFolder.newFile("empty.mp4")
        val report = Mp4RecoveryEngine.inspect(file)

        assertEquals(Mp4RecoveryEngine.Mp4Status.EMPTY, report.status)
        assertEquals(0L, report.fileSize)
        assertFalse(report.hasFtyp)
        assertFalse(report.hasMoov)
        assertFalse(report.hasMdat)
        assertTrue(report.recoveryDecision is Mp4RecoveryEngine.RecoveryDecision.Unrecoverable)

        val unrecoverable = report.recoveryDecision as Mp4RecoveryEngine.RecoveryDecision.Unrecoverable
        assertTrue(unrecoverable.reason.contains("empty", ignoreCase = true))

        val result = Mp4RecoveryEngine.attemptRecovery(file, tempFolder.newFile("out.mp4"))
        assertTrue(result is Mp4RecoveryEngine.RecoveryResult.Unrecoverable)
    }

    @Test
    fun fileSmallerThanHeader_isDetectedAsCorrupted() {
        val file = tempFolder.newFile("tiny.mp4")
        file.writeBytes(byteArrayOf(0x00, 0x00, 0x00, 0x04)) // Only 4 bytes

        val report = Mp4RecoveryEngine.inspect(file)
        assertEquals(Mp4RecoveryEngine.Mp4Status.CORRUPTED, report.status)
        assertEquals(4L, report.fileSize)
        assertTrue(report.recoveryDecision is Mp4RecoveryEngine.RecoveryDecision.Unrecoverable)
    }

    @Test
    fun validMp4WithMoovAndMdat_isDetectedAsValid_andSkipsRepair() {
        val file = tempFolder.newFile("valid.mp4")
        FileOutputStream(file).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(createBox("mdat", ByteArray(100) { 0x55.toByte() }))
            fos.write(createBox("moov", ByteArray(80) { 0xAA.toByte() }))
        }

        val report = Mp4RecoveryEngine.inspect(file)
        assertEquals(Mp4RecoveryEngine.Mp4Status.VALID, report.status)
        assertTrue(report.hasFtyp)
        assertTrue(report.hasMdat)
        assertTrue(report.hasMoov)
        assertEquals(3, report.boxes.size)
        assertTrue(report.recoveryDecision is Mp4RecoveryEngine.RecoveryDecision.Skip)

        val outputFile = File(tempFolder.root, "out.mp4")
        val result = Mp4RecoveryEngine.attemptRecovery(file, outputFile)
        assertTrue(result is Mp4RecoveryEngine.RecoveryResult.Ignored)
        assertFalse(outputFile.exists()) // Must not produce duplicate or modify
    }

    @Test
    fun truncatedMp4MissingMoov_withoutCheckpoint_isUnrecoverableWithIsoBmffExplanation() {
        val file = tempFolder.newFile("interrupted.mp4")
        FileOutputStream(file).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(createBox("mdat", ByteArray(500) { 0x12.toByte() }))
            // Process killed before moov was written!
        }

        val report = Mp4RecoveryEngine.inspect(file, checkpoint = null)
        assertEquals(Mp4RecoveryEngine.Mp4Status.TRUNCATED_MISSING_MOOV, report.status)
        assertTrue(report.hasFtyp)
        assertTrue(report.hasMdat)
        assertFalse(report.hasMoov)
        assertTrue(report.recoveryDecision is Mp4RecoveryEngine.RecoveryDecision.Unrecoverable)

        val decision = report.recoveryDecision as Mp4RecoveryEngine.RecoveryDecision.Unrecoverable
        assertTrue(decision.technicalConstraint.contains("MediaMuxer"))
        assertTrue(decision.reason.contains("moov") || decision.technicalConstraint.contains("moov"))

        val target = File(tempFolder.root, "target.mp4")
        val originalLength = file.length()
        assertTrue(originalLength > 0L)
        val result = Mp4RecoveryEngine.attemptRecovery(file, target, checkpoint = null)
        assertTrue(result is Mp4RecoveryEngine.RecoveryResult.Unrecoverable)
        assertFalse(target.exists())
        assertEquals(originalLength, file.length()) // Original file remains untouched!
    }

    @Test
    fun truncatedMp4_withValidCheckpoint_recoversToIsolatedTargetAndValidates() {
        val corruptedFile = tempFolder.newFile("incomplete.mp4")
        FileOutputStream(corruptedFile).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(createBox("mdat", ByteArray(300)))
        }

        // Surviving video stream in cache
        val videoTemp = tempFolder.newFile("capture_video.mp4")
        FileOutputStream(videoTemp).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(createBox("mdat", ByteArray(200)))
            fos.write(createBox("moov", ByteArray(150)))
        }

        val checkpoint = Mp4RecoveryEngine.SessionCheckpoint(
            sessionId = "session-1234",
            videoFile = videoTemp,
            audioFile = null,
            hasAudio = false
        )

        val report = Mp4RecoveryEngine.inspect(corruptedFile, checkpoint)
        assertEquals(Mp4RecoveryEngine.Mp4Status.TRUNCATED_MISSING_MOOV, report.status)
        assertTrue(report.recoveryDecision is Mp4RecoveryEngine.RecoveryDecision.RecoverableWithJournal)

        val targetFile = File(tempFolder.root, "recovered_output.mp4")
        val result = Mp4RecoveryEngine.attemptRecovery(
            corruptedFile = corruptedFile,
            outputFile = targetFile,
            checkpoint = checkpoint
        )

        assertTrue(result is Mp4RecoveryEngine.RecoveryResult.Success)
        assertTrue(targetFile.exists())
        val recoveredReport = Mp4RecoveryEngine.inspect(targetFile)
        assertEquals(Mp4RecoveryEngine.Mp4Status.VALID, recoveredReport.status)
    }

    @Test
    fun recoveryWithInvalidRemuxOutput_rollsBackAndPreservesOriginal() {
        val corruptedFile = tempFolder.newFile("incomplete2.mp4")
        FileOutputStream(corruptedFile).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(createBox("mdat", ByteArray(300)))
        }

        val videoTemp = tempFolder.newFile("video_temp2.mp4")
        videoTemp.writeBytes(ByteArray(50) { 0x01.toByte() })

        val checkpoint = Mp4RecoveryEngine.SessionCheckpoint(
            sessionId = "session-5678",
            videoFile = videoTemp,
            audioFile = null
        )

        val targetFile = File(tempFolder.root, "final_target.mp4")
        // Custom remuxer that writes corrupted bytes instead of valid MP4
        val result = Mp4RecoveryEngine.attemptRecovery(
            corruptedFile = corruptedFile,
            outputFile = targetFile,
            checkpoint = checkpoint,
            remuxer = { _, _, target ->
                target.writeBytes(byteArrayOf(0x00, 0x00, 0x00, 0x04)) // corrupted
                true
            }
        )

        assertTrue(result is Mp4RecoveryEngine.RecoveryResult.Failed)
        assertFalse(targetFile.exists()) // Rolled back!
        // No lingering .tmp files
        val tempFiles = tempFolder.root.listFiles { f -> f.name.contains(".recovery_") }
        assertTrue(tempFiles.isNullOrEmpty())
    }

    @Test
    fun handles64BitExtendedBoxSize() {
        val file = tempFolder.newFile("extended64.mp4")
        FileOutputStream(file).use { fos ->
            fos.write(createBox("ftyp", "isom\u0000\u0000\u0002\u0000".toByteArray(StandardCharsets.ISO_8859_1)))
            fos.write(create64BitBox("mdat", ByteArray(40)))
            fos.write(createBox("moov", ByteArray(50)))
        }

        val report = Mp4RecoveryEngine.inspect(file)
        assertEquals(Mp4RecoveryEngine.Mp4Status.VALID, report.status)
        assertEquals(3, report.boxes.size)
        val mdatBox = report.boxes[1]
        assertEquals("mdat", mdatBox.type)
        assertEquals(56L, mdatBox.size)
        assertEquals(16, mdatBox.headerSize)
    }
}
