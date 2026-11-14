package com.xrecorder.xrecorder.qa

import android.app.Instrumentation
import android.os.Bundle
import com.xrecorder.xrecorder.live.LiveDestinationStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore

/** Actual Android Keystore, isolated new file and alias; never touches a user's saved destination. */
object Task10LiveStoreInstrumentation {
    @JvmStatic fun run(instrumentation: Instrumentation, arguments: Bundle) {
        val passed = JSONArray()
        val result = JSONObject().put("case", "live-store")
        try {
            val attempt = requireNotNull(arguments.getString("attempt"))
            require(attempt.matches(Regex("[a-z0-9_]+")))
            val context = instrumentation.targetContext
            val directory = File(context.noBackupFilesDir, "task10_live_store_$attempt")
            check(!directory.exists() && directory.mkdir())
            val file = File(directory, "destination.enc")
            val alias = "task10.live.store.$attempt"
            val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            check(!keys.containsAlias(alias))
            val store = LiveDestinationStore(context, file, alias)
            check(store.read() == null && !file.exists() && !keys.containsAlias(alias))
            passed.put("missing_read_creates_nothing")
            val secret = "task10_store_secret_$attempt"
            val server = "rtmps://stream.example/live"
            store.save("TASK10 destination", server, secret)
            val first = file.readBytes()
            check(!String(first, Charsets.ISO_8859_1).contains(secret))
            check(!String(first, Charsets.ISO_8859_1).contains(server))
            check(store.read() == mapOf("name" to "TASK10 destination", "serverUrl" to server, "streamKey" to secret))
            check(LiveDestinationStore(context, file, alias).read() == store.read())
            passed.put("encrypted_roundtrip_and_new_instance")
            store.save("TASK10 destination", server, secret)
            val second = file.readBytes()
            check(!first.contentEquals(second))
            passed.put("fresh_random_iv")
            check(runCatching { store.save("", server, secret) }.isFailure)
            check(runCatching { store.save("TASK10", "https://stream.example/live", secret) }.isFailure)
            check(second.contentEquals(file.readBytes()))
            passed.put("invalid_save_preserves_old_destination")
            val tampered = second.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
            file.writeBytes(tampered)
            check(runCatching { store.read() }.isFailure)
            check(runCatching { store.save("replacement", server, secret) }.isFailure)
            check(tampered.contentEquals(file.readBytes()))
            passed.put("tampering_detected_and_preserved_no_implicit_overwrite")
            file.writeBytes(second)
            keys.deleteEntry(alias) // Only this newly created, positively identified QA alias.
            check(runCatching { store.read() }.isFailure)
            check(!keys.containsAlias(alias) && second.contentEquals(file.readBytes()))
            check(runCatching { store.save("replacement", server, secret) }.isFailure)
            check(!keys.containsAlias(alias) && second.contentEquals(file.readBytes()))
            passed.put("missing_key_does_not_generate_or_overwrite")
            store.forget()
            check(store.read() == null && !file.exists())
            store.save("After explicit forget", server, secret)
            check(store.read()?.get("name") == "After explicit forget")
            passed.put("explicit_forget_then_save_recovers")
            // Keep the encrypted fixture as bounded evidence. Never log its plaintext.
            result.put("fixture", "no_backup/${directory.name}/destination.enc")
                .put("bytes", file.length()).put("status", "PASS")
        } catch (error: Throwable) {
            result.put("status", "FAIL").put("errorClass", error.javaClass.simpleName)
        }
        result.put("passed", passed)
        instrumentation.finish(if (result.optString("status") == "PASS") -1 else 0,
            Bundle().apply { putString("stream", "TASK10_LIVE_RESULT:$result\n") })
    }
}
