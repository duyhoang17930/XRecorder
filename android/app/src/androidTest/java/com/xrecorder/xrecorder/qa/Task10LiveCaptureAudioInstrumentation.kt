package com.xrecorder.xrecorder.qa

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.app.Instrumentation
import android.app.UiAutomation
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import com.xrecorder.xrecorder.live.LiveCaptureState
import com.xrecorder.xrecorder.media.VideoPreviewActivity
import com.xrecorder.xrecorder.recording.CaptureService
import com.xrecorder.xrecorder.recording.CaptureState
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

/** Production Flutter Start/End and normal system consent, with task media
 * played by the existing native player. No capture token or permission bypass.
 * Direct AX queries avoid UIAutomator's idle wait during a legitimate timer.
 */
object Task10LiveCaptureAudioInstrumentation {
    private class Controls(private val runner: Instrumentation) {
        val automation = runner.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES).apply {
            serviceInfo = serviceInfo.apply {
                flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            }
        }
        private fun nodes(): List<AccessibilityNodeInfo> {
            val values = mutableListOf<AccessibilityNodeInfo>()
            fun collect(node: AccessibilityNodeInfo) {
                values.add(node)
                for (i in 0 until node.childCount) node.getChild(i)?.let { collect(it) }
            }
            // The IME can become the active window while the application keeps
            // input focus. Include its visible application window too.
            val roots = automation.windows.mapNotNull { it.root }
            if (roots.isEmpty()) automation.rootInActiveWindow?.let { collect(it) }
            else roots.forEach { collect(it) }
            return values
        }
        fun find(label: String, timeout: Long = 10000): AccessibilityNodeInfo? {
            val deadline = SystemClock.elapsedRealtime() + timeout
            do {
                nodes().firstOrNull { n -> n.isVisibleToUser && n.isEnabled &&
                    (label in (n.contentDescription?.toString() ?: "").split('\n') ||
                        n.text?.toString() == label) }?.let { return it }
                SystemClock.sleep(50)
            } while (SystemClock.elapsedRealtime() < deadline)
            return null
        }
        fun click(label: String) {
            val deadline = SystemClock.elapsedRealtime() + 10000
            do {
                val candidates = nodes().filter { it.isVisibleToUser && it.isEnabled &&
                    (label in (it.contentDescription?.toString() ?: "").split('\n') || it.text?.toString() == label) }
                    .sortedBy { !it.isClickable }
                for (candidate in candidates) {
                    var node = candidate
                    while (!node.isClickable && node.parent != null) node = node.parent
                    if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                        SystemClock.sleep(250)
                        return
                    }
                }
                SystemClock.sleep(50)
            } while (SystemClock.elapsedRealtime() < deadline)
            error("Control not actionable: $label")
        }
        fun enter(hint: String, text: String) {
            val deadline = SystemClock.elapsedRealtime() + 10000
            var node: AccessibilityNodeInfo? = null
            while (node == null && SystemClock.elapsedRealtime() < deadline) {
                node = nodes().firstOrNull { it.isVisibleToUser && it.isEnabled && it.isEditable && it.hintText?.toString() == hint }
                if (node == null) SystemClock.sleep(50)
            }
            check(node != null && node.text.isNullOrEmpty()) { "Preserve existing destination; field must be empty" }
            check(node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) { "Could not focus destination field" }
            SystemClock.sleep(300)
            runner.sendStringSync(text) // Real key events; no shell/adb secret argument.
            val entered = SystemClock.elapsedRealtime() + 5000
            while (true) {
                val fresh = nodes().firstOrNull { it.isEditable && it.hintText?.toString() == hint }
                if (fresh != null && fresh.text?.length == text.length &&
                    (fresh.isPassword || fresh.text?.toString() == text)) return
                check(SystemClock.elapsedRealtime() < entered) { "Destination input was not committed: $hint" }
                SystemClock.sleep(50)
            }
        }
        fun diagnostic(): JSONObject {
            val all = nodes().filter { it.isVisibleToUser }
            val fields = org.json.JSONArray()
            all.filter { it.isEditable }.forEach { fields.put(JSONObject()
                .put("hint", it.hintText?.toString()).put("length", it.text?.length ?: 0)
                .put("password", it.isPassword).put("focused", it.isFocused)) }
            val labels = org.json.JSONArray()
            all.filter { !it.isEditable && !it.isPassword }.mapNotNull {
                (it.contentDescription ?: it.text)?.toString()
            }.filter { !it.contains("task10_capture_audio_") }.distinct().forEach { labels.put(it) }
            return JSONObject().put("fields", fields).put("visibleLabels", labels)
        }
        fun screenshot(path: File): Boolean {
            val bitmap = automation.takeScreenshot() ?: return false
            try {
                check(path.createNewFile())
                path.outputStream().use { check(bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)) }
            } finally { bitmap.recycle() }
            return true
        }
    }

    @JvmStatic fun run(runner: Instrumentation, arguments: Bundle) {
        val report = JSONObject().put("case", "live-capture-audio")
        var session: String? = null
        var player: Activity? = null
        var sourceTrack: android.media.AudioTrack? = null
        var staticSamples: ShortArray? = null
        var controls: Controls? = null
        var captureAudio: Any? = null
        val context = runner.targetContext
        fun state(): Map<String, Any?> {
            var value: Map<String, Any?> = emptyMap()
            runner.runOnMainSync { value = CaptureState.snapshot() }
            return value
        }
        fun waitFor(label: String, timeout: Long = 20000, condition: () -> Boolean) {
            val deadline = SystemClock.elapsedRealtime() + timeout
            while (!condition()) {
                check(SystemClock.elapsedRealtime() < deadline) { label }
                SystemClock.sleep(30)
            }
        }
        fun sourceHash(uri: Uri): String {
            val digest = MessageDigest.getInstance("SHA-256")
            context.contentResolver.openInputStream(uri).use { input ->
                checkNotNull(input)
                val bytes = ByteArray(65536)
                while (true) { val n = input.read(bytes); if (n < 0) break; digest.update(bytes, 0, n) }
            }
            return digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
        }
        fun audioTiming(): JSONObject {
            val value = JSONObject().put("monotonicNs", System.nanoTime()).put("captureElapsedMs", state()["elapsedMs"])
            CaptureService.instance?.let { service ->
                val field = CaptureService::class.java.getDeclaredField("video").apply { isAccessible = true }
                val video = field.get(service) as? com.xrecorder.xrecorder.recording.VideoEncoder
                if (video != null) value.put("videoSourceStartNs", video.sourceStartNs)
            }
            if (captureAudio == null) CaptureService.instance?.let { service ->
                val audioField = CaptureService::class.java.getDeclaredField("audio").apply { isAccessible = true }
                captureAudio = audioField.get(service)
            }
            val audio = captureAudio ?: return value.put("audioReleased", true)
            value.put("micUnderrunSamples", audio.javaClass.getDeclaredField("micUnderrunSamples")
                .apply { isAccessible = true }.getLong(audio))
            for (counter in listOf("microphoneReadSamples", "encodedSamples"))
                value.put(counter, audio.javaClass.getDeclaredField(counter).apply { isAccessible = true }.getLong(audio))
            val reader = audio.javaClass.getDeclaredField("internalReader").apply { isAccessible = true }.get(audio)
            if (reader != null) {
                value.put("internalReadSamples", reader.javaClass.getDeclaredField("capturedSamples").apply { isAccessible = true }.getLong(reader))
                val queue = reader.javaClass.getDeclaredField("blocks").apply { isAccessible = true }.get(reader) as java.util.concurrent.ArrayBlockingQueue<*>
                value.put("internalQueuedBlocks", queue.size)
            }
            val worker = audio.javaClass.getDeclaredField("worker").apply { isAccessible = true }.get(audio) as? Thread
            value.put("encoderWorkerStack", org.json.JSONArray(worker?.stackTrace?.take(7)?.map { "${it.className}.${it.methodName}" } ?: emptyList<String>()))
            val failure = audio.javaClass.getDeclaredField("failure").apply { isAccessible = true }.get(audio) as? Exception
            if (failure != null) value.put("failureClass", failure.javaClass.simpleName).put("failure", failure.message)
            for (name in listOf("mic", "internal")) {
                val field = audio.javaClass.getDeclaredField(name).apply { isAccessible = true }
                val recorder = field.get(audio) as? android.media.AudioRecord ?: continue
                val timestamp = android.media.AudioTimestamp()
                val status = recorder.getTimestamp(timestamp, android.media.AudioTimestamp.TIMEBASE_MONOTONIC)
                value.put(name, JSONObject().put("timestampStatus", status)
                    .put("sampleRate", recorder.sampleRate).put("channels", recorder.channelCount)
                    .put("encoding", recorder.audioFormat)
                    .put("framePosition", timestamp.framePosition).put("frameTimeNs", timestamp.nanoTime)
                    .put("bufferFrames", recorder.bufferSizeInFrames))
            }
            return value
        }
        try {
            val attempt = checkNotNull(arguments.getString("attempt"))
            require(attempt.matches(Regex("[a-z0-9_]+")))
            val source = Uri.parse(checkNotNull(arguments.getString("source")))
            require(source.toString() == "content://media/external/video/media/115")
            val expected = "8925ac2f0764e8bcdbcf1b70f5f28b373b4653f7a7aa0c8b163ebfa00001c34f"
            check(sourceHash(source) == expected)
            val sourcePlayer = arguments.getString("player") ?: "video"
            require(sourcePlayer in listOf("video", "static"))
            report.put("sourcePlayer", sourcePlayer)
            if (sourcePlayer == "static") {
                // Isolate capture from simultaneous VideoView decoder startup.
                // Reuse the real speech decoder, prepare before capture, and
                // retain the exact PCM sent to Android AudioTrack as oracle.
                val decoded = com.xrecorder.xrecorder.editor.SpeechAudioDecoder.decode(
                    context, source, 11036, { false }, {})
                staticSamples = ShortArray(decoded.size) { (decoded[it].coerceIn(-1f, 1f) * 32767).toInt().toShort() }
                val bytes = java.nio.ByteBuffer.allocate(decoded.size * 2).order(java.nio.ByteOrder.LITTLE_ENDIAN)
                bytes.asShortBuffer().put(staticSamples!!)
                val file = File(context.filesDir, "task10_audio_${attempt}_source.pcm")
                check(file.createNewFile())
                file.writeBytes(bytes.array())
                report.put("sourcePcmBytes", bytes.capacity()).put("sourcePcmRate", 16000)
                    .put("sourcePcmSha256", MessageDigest.getInstance("SHA-256").digest(bytes.array())
                        .joinToString("") { "%02x".format(it.toInt() and 255) })
            }
            check(!File(context.noBackupFilesDir, "live_destination_v1.enc").exists())
            runner.startActivitySync(Intent().setClassName(context.packageName, "${context.packageName}.MainActivity")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            check(!CaptureState.busy && CaptureService.instance == null)
            val ui = Controls(runner)
            controls = ui
            ui.click("Create")
            ui.click("Livestream")
            ui.enter("Server URL", "rtmp://10.0.2.2:19350/live")
            // Even the synthetic key is generated in-app, never in adb arguments.
            ui.enter("Stream key", "task10_capture_audio_$attempt")
            ui.click("Start livestream")
            waitFor("Capture consent was not requested", 10000) { state()["state"] == "awaitingPermission" }
            session = state()["id"] as String
            report.put("sessionId", session)
            if (arguments.getString("denyFirstConsent") == "true") {
                val deniedId = session
                report.put("deniedScreenshot", ui.screenshot(File(context.filesDir, "task10_audio_${attempt}_denied.png")))
                ui.click("Cancel") // Normal Android MediaProjection denial.
                waitFor("Denied consent did not return to idle") { state()["state"] == "idle" }
                check(state()["outputUri"] == null && CaptureService.instance == null)
                report.put("deniedCapture", JSONObject(state()))
                ui.click("Start livestream")
                waitFor("Retry did not request fresh consent", 10000) { state()["state"] == "awaitingPermission" }
                session = state()["id"] as String
                check(session != deniedId)
                report.put("sessionId", session).put("deniedConsentSessionId", deniedId)
                    .put("normalConsentDenialAndRetry", true)
            }
            if (ui.find("Share one app", 2000) != null) {
                ui.click("Share one app")
                ui.click("Share entire screen")
            }
            check(ui.find("Share screen") != null) { "Normal system capture consent required" }
            report.put("consentScreenshot", ui.screenshot(File(context.filesDir, "task10_audio_${attempt}_consent.png")))
            ui.click("Share screen")
            waitFor("Recording did not start") { state()["state"] == "recording" }
            check(CaptureState.config.audio == "mixed") { "Preserve preferences; Mixed Stream fixture required" }
            report.put("initialAudioTiming", audioTiming())
            waitFor("Live transport did not connect") { LiveCaptureState.snapshot()["state"] == "live" }
            waitFor("Live did not send its first actual audio/video packets") {
                val live = LiveCaptureState.snapshot()
                (live["sentVideoFrames"] as? Number)?.toLong()?.let { it > 0 } == true &&
                    (live["sentAudioFrames"] as? Number)?.toLong()?.let { it > 0 } == true
            }
            // Same app-owned player/Intent used by Library Preview. Playback
            // entry itself is a native integration call, not an asserted UI tap.
            if (sourcePlayer == "video") {
                player = runner.startActivitySync(Intent(context, VideoPreviewActivity::class.java)
                    .setData(source).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } else {
                val samples = checkNotNull(staticSamples)
                sourceTrack = android.media.AudioTrack.Builder()
                    .setAudioAttributes(android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
                    .setAudioFormat(android.media.AudioFormat.Builder().setSampleRate(16000)
                        .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO).build())
                    .setTransferMode(android.media.AudioTrack.MODE_STATIC)
                    .setBufferSizeInBytes(samples.size * 2).build()
                check(sourceTrack!!.write(samples, 0, samples.size) == samples.size)
                sourceTrack!!.play()
            }
            var playback: Map<String, Any> = emptyMap()
            fun currentPlayback(): Map<String, Any> {
                val track = sourceTrack
                if (track != null) return mapOf("positionMs" to track.playbackHeadPosition.toLong()*1000/16000,
                    "durationMs" to checkNotNull(staticSamples).size.toLong()*1000/16000,
                    "playing" to (track.playState == android.media.AudioTrack.PLAYSTATE_PLAYING))
                var value: Map<String, Any> = emptyMap()
                runner.runOnMainSync { value = VideoPreviewActivity.instance?.playbackState() ?: emptyMap() }
                return value
            }
            waitFor("Production player did not play") {
                playback = currentPlayback()
                playback["playing"] == true && (playback["positionMs"] as Number).toLong() > 0 &&
                    playback["renderedFirstFrame"] != false
            }
            report.put("initialPlayback", JSONObject(playback)).put("playbackStartMonotonicNs", System.nanoTime())
            report.put("playbackStartCaptureMs", state()["elapsedMs"])
            val audioTimeline = org.json.JSONArray()
            report.put("audioTimeline", audioTimeline)
            val playbackDeadline = SystemClock.elapsedRealtime() + 7500
            while (SystemClock.elapsedRealtime() < playbackDeadline) {
                audioTimeline.put(audioTiming())
                check(CaptureState.id == session && CaptureState.busy) { "Capture ended during playback: ${audioTiming()}" }
                SystemClock.sleep(500)
            }
            report.put("audioTimeline", audioTimeline)
            playback = currentPlayback()
            check((playback["positionMs"] as Number).toLong() >= 6000 && playback["playing"] == true)
            report.put("playback", JSONObject(playback)).put("liveBeforeEnd", JSONObject(LiveCaptureState.snapshot()))
            report.put("playerScreenshot", ui.screenshot(File(context.filesDir, "task10_audio_${attempt}_player.png")))
            sourceTrack?.pause()
            if (arguments.getString("failAfterPlayback") == "true") {
                if (arguments.getString("pauseBeforeFailure") == "true") {
                    runner.runOnMainSync { checkNotNull(CaptureService.instance).setPaused(true) }
                    waitFor("Owned capture did not pause") { state()["state"] == "paused" }
                    val pausedElapsed = (state()["elapsedMs"] as Number).toLong()
                    SystemClock.sleep(1200)
                    check((state()["elapsedMs"] as Number).toLong() == pausedElapsed)
                    report.put("pausedBeforeFailure", true).put("pausedDurationMs", 1200)
                }
                val before = (state()["elapsedMs"] as Number).toLong()
                report.put("elapsedBeforeInjectedFailureMs", before)
                check(before >= 6000)
                runner.runOnMainSync {
                    val service = checkNotNull(CaptureService.instance)
                    CaptureService::class.java.getDeclaredMethod("fail", String::class.java)
                        .apply { isAccessible = true }
                        .invoke(service, "Audio capture was interrupted. Try a different audio source or mute.")
                }
                waitFor("Injected failure did not terminate") { state()["state"] == "failed" }
                val failed = state()
                report.put("capture", JSONObject(failed))
                val elapsed = (failed["elapsedMs"] as Number).toLong()
                check(elapsed in before..(before+500)) { "Failure lost active duration: $before -> $elapsed" }
                SystemClock.sleep(300)
                check((state()["elapsedMs"] as Number).toLong() == elapsed) { "Terminal duration kept running" }
                check(failed["outputUri"] == null && !CaptureState.busy)
                val prefs = context.getSharedPreferences("capture_journal", android.content.Context.MODE_PRIVATE)
                val persisted = JSONObject(checkNotNull(prefs.getString("session", null)))
                check(persisted.getString("id") == session && persisted.getLong("elapsedMs") == elapsed)
                val checkpoint = File(context.filesDir, "capture_recovery/$session.json")
                check(checkpoint.isFile) { "Failed capture inputs were not retained" }
                val retained = JSONObject(checkpoint.readText())
                check(retained.getJSONObject("session").getLong("elapsedMs") == elapsed)
                check(retained.getJSONObject("session").getString("state") == "failed")
                report.put("retainedCheckpoint", retained)
                    .put("status", "PASS").put("sourceByteExact", sourceHash(source) == expected)
                    .put("scope", "Normal-consent real capture, injected owned-session failure; duration freezes and persists; no output success")
            } else {
            runner.runOnMainSync {
                context.startActivity(Intent().setClassName(context.packageName, "${context.packageName}.MainActivity")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                player?.finish()
            }
            check(CaptureState.id == session && CaptureState.busy)
            waitFor("Main livestream navigation did not return", 15000) {
                check(CaptureState.id == session && CaptureState.busy)
                ui.find("End livestream", 50) != null || ui.find("Create", 50) != null
            }
            // MainActivity may be recreated while the native player is in
            // front. Reopen the existing session through the real Create flow
            // instead of assuming the in-memory Flutter route survived.
            if (ui.find("End livestream", 200) == null) {
                ui.click("Create")
                ui.click("Livestream")
                report.put("reopenedLiveRoute", true)
            }
            check(CaptureState.id == session && CaptureState.busy)
            ui.click("End livestream")
            waitFor("Recording did not publish", 30000) { state()["state"] == "completed" }
            check(!CaptureState.output.isNullOrBlank())
            check(sourceHash(source) == expected)
            report.put("status", "PASS").put("sessionId", session).put("capture", JSONObject(state()))
                .put("sourceByteExact", true).put("sourceUri", source.toString())
                .put("scope", "Real Flutter Start/End + normal consent + $sourcePlayer player integration; independent file/audio validation required")
            }
        } catch (error: Throwable) {
            report.put("status", "FAIL").put("errorClass", error.javaClass.simpleName)
                .put("error", error.message ?: "Native capture test failed").put("captureAtFailure", JSONObject(state()))
            report.put("audioAtFailure", audioTiming())
            controls?.let {
                report.put("uiDiagnostic", it.diagnostic())
                val attempt = arguments.getString("attempt") ?: "unknown"
                report.put("failureScreenshot", it.screenshot(File(context.filesDir, "task10_audio_${attempt}_failure.png")))
            }
        } finally {
            runCatching { sourceTrack?.stop() }
            runCatching { sourceTrack?.release() }
            if (session != null && CaptureState.id == session && CaptureState.state == "awaitingPermission")
                controls?.automation?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK)
            runner.runOnMainSync {
                player?.finish()
                if (session != null && CaptureState.id == session && CaptureState.busy) CaptureService.instance?.stopCapture()
            }
            val deadline = SystemClock.elapsedRealtime() + 10000
            while (session != null && CaptureState.id == session && CaptureState.busy && SystemClock.elapsedRealtime() < deadline)
                SystemClock.sleep(30)
            report.put("cleanupCapture", JSONObject(state()))
        }
        runner.finish(if (report.optString("status") == "PASS") -1 else 0,
            Bundle().apply { putString("stream", "TASK10_LIVE_RESULT:$report\n") })
    }
}
