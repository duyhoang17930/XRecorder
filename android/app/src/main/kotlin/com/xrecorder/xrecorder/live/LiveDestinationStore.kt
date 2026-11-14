package com.xrecorder.xrecorder.live

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** One explicitly saved destination. Never part of preferences, backup or capture journals. */
class LiveDestinationStore(
    context: Context,
    file: File = File(context.noBackupFilesDir, "live_destination_v1.enc"),
    private val alias: String = "3hrecorder.live.destination.v1",
) {
    private val atomic = AtomicFile(file)
    private fun storedFilesExist() = listOf("", ".bak", ".new").any { File(atomic.baseFile.path + it).exists() }

    companion object {
        // AtomicFile does not provide locking, including across bridge instances.
        private val lock = Any()
        private const val LIMIT = 65536
        private val header = byteArrayOf(0x33, 0x48, 0x4c, 0x01)
    }

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        check(create) { "Saved destination is unavailable." }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build())
        }.generateKey()
    }

    fun read(): Map<String, String>? = synchronized(lock) { readLocked() }

    private fun readLocked(): Map<String, String>? {
        if (!storedFilesExist()) return null
        // Preserve an interrupted first write without a committed base/backup.
        check(atomic.baseFile.exists() || File(atomic.baseFile.path + ".bak").exists())
        val bytes = atomic.openRead().use { it.readBytesBounded() }
        check(bytes.size >= 32 && bytes.copyOfRange(0, 4).contentEquals(header))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(4, 16)))
        cipher.updateAAD(header)
        val json = JSONObject(String(cipher.doFinal(bytes.copyOfRange(16, bytes.size)), Charsets.UTF_8))
        val name = json.getString("name")
        val server = json.getString("serverUrl")
        val secret = json.getString("streamKey")
        validate(name, server, secret)
        return mapOf("name" to name, "serverUrl" to server, "streamKey" to secret)
    }

    private fun java.io.InputStream.readBytesBounded(): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            val count = read(buffer)
            if (count < 0) return out.toByteArray()
            check(out.size() + count <= LIMIT)
            out.write(buffer, 0, count)
        }
    }

    private fun validate(name: String, server: String, secret: String) {
        require(name.isNotBlank() && name.length <= 80 && name.none { Character.isISOControl(it) })
        require(server.length <= 4096)
        RtmpEndpoint.parse(server, secret)
    }

    fun save(name: String, server: String, secret: String) = synchronized(lock) {
        validate(name.trim(), server.trim(), secret.trim())
        // An unreadable saved credential is retained until an explicit Forget.
        readLocked()
        val plain = JSONObject().put("name", name.trim()).put("serverUrl", server.trim())
            .put("streamKey", secret.trim()).toString().toByteArray(Charsets.UTF_8)
        check(plain.size + 32 <= LIMIT)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        check(cipher.iv.size == 12)
        cipher.updateAAD(header)
        val encrypted = cipher.doFinal(plain)
        val out = atomic.startWrite()
        try {
            out.write(header)
            out.write(cipher.iv)
            out.write(encrypted)
            atomic.finishWrite(out)
        } catch (error: Exception) {
            atomic.failWrite(out)
            throw error
        }
    }

    /** Only called after an explicit confirmation; never clears other application data. */
    fun forget() = synchronized(lock) {
        atomic.delete()
        check(!storedFilesExist())
    }
}
