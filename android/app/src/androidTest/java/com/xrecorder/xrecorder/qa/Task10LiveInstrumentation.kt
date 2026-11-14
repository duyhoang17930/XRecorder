package com.xrecorder.xrecorder.qa

import android.app.Instrumentation
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import com.xrecorder.xrecorder.live.RtmpEndpoint
import com.xrecorder.xrecorder.live.RtmpTransport
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.util.Collections

/** Existing task-owned encoded media -> real local RTMP receiver; no capture token. */
object Task10LiveInstrumentation {
    @JvmStatic fun run(instrumentation: Instrumentation, arguments: Bundle) {
        if (arguments.getString("task10") == "live-capture-audio") {
            Task10LiveCaptureAudioInstrumentation.run(instrumentation, arguments)
            return
        }
        if (arguments.getString("task10") == "live-store") {
            Task10LiveStoreInstrumentation.run(instrumentation, arguments)
            return
        }
        val result = JSONObject().put("case", arguments.getString("task10"))
        val states = Collections.synchronizedList(mutableListOf<String>())
        var transport: RtmpTransport? = null
        val extractor = MediaExtractor()
        try {
            require(arguments.getString("task10") in listOf("live-transport", "live-refused", "live-cancel", "live-reconnect"))
            val context = instrumentation.targetContext
            val source = requireNotNull(arguments.getString("source"))
            require(source.startsWith("content://media/"))
            extractor.setDataSource(context, Uri.parse(source), null)
            val video = (0 until extractor.trackCount).first {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == "video/avc"
            }
            val audio = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == "audio/mp4a-latm"
            }
            val attempt = requireNotNull(arguments.getString("attempt"))
            require(attempt.matches(Regex("[a-z0-9_]+")))
            // Do not pass even a synthetic key through adb shell arguments:
            // API37's adbd itself logs the complete command line.
            val endpoint = RtmpEndpoint.parse(
                requireNotNull(arguments.getString("server")),
                "task10_secret_probe_$attempt",
            )
            val live = RtmpTransport(endpoint, changed = { states.add(it) })
            transport = live
            live.start(extractor.getTrackFormat(video), audio?.let { extractor.getTrackFormat(it) })
            val case = arguments.getString("task10")
            if (case == "live-cancel") {
                live.stop()
                SystemClock.sleep(1500)
                check(live.state == "stopped")
            } else if (case == "live-refused") {
                val deadline = SystemClock.elapsedRealtime() + 30000
                while (live.state !in listOf("connection_failed", "authentication_failed") &&
                    SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(20)
                check(live.state == "connection_failed") { "Connection failure did not terminate" }
                check((live.snapshot()["retries"] as Int) == 2)
            } else {
                val deadline = SystemClock.elapsedRealtime() + 15000
                while (live.state != "live" && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(20)
                check(live.state == "live") { "Local receiver did not accept the stream" }
                extractor.selectTrack(video)
                audio?.let { extractor.selectTrack(it) }
                val bytes = ByteBuffer.allocateDirect(2 * 1024 * 1024)
                val start = SystemClock.elapsedRealtimeNanos()
                var videos = 0
                var audios = 0
                var cycle = 0
                val reconnect = case == "live-reconnect"
                while (cycle < if (reconnect) 3 else 1) {
                    if (extractor.sampleTrackIndex < 0 || extractor.sampleTime >= 8000000) {
                        cycle++
                        if (cycle >= if (reconnect) 3 else 1) break
                        extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                        continue
                    }
                    // MediaExtractor may seek to a negative AAC priming
                    // packet. Do not replay it at each synthetic8s seam.
                    if (extractor.sampleTime < 0) { extractor.advance(); continue }
                    val pts = extractor.sampleTime + cycle * 8000000L
                    val remaining = (start + pts * 1000 - SystemClock.elapsedRealtimeNanos()) / 1000000
                    if (remaining > 0) SystemClock.sleep(remaining)
                    bytes.clear()
                    val size = extractor.readSampleData(bytes, 0)
                    if (size < 0) break
                    check(size <= bytes.capacity())
                    val info = MediaCodec.BufferInfo().apply {
                        set(0, size, pts, if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0)
                            MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                    }
                    if (extractor.sampleTrackIndex == video) { live.video(bytes, info); videos++ }
                    else { live.audio(bytes, info); audios++ }
                    check(live.state == "live" || reconnect && live.state == "reconnecting") {
                        "Local stream disconnected while sending: ${live.state}"
                    }
                    extractor.advance()
                }
                SystemClock.sleep(700)
                result.put("submittedVideo", videos).put("submittedAudio", audios)
                if (reconnect) {
                    check(synchronized(states) { states.count { it == "live" } } == 2) { "A second successful connection was not observed" }
                    check((live.snapshot()["retries"] as Int) in 1..2) { "Reconnect did not use the bounded retry path" }
                    check(live.state == "live") { "Reconnect did not remain connected" }
                }
                check((live.snapshot()["sentVideoFrames"] as Long) > 10)
                check(audio == null || (live.snapshot()["sentAudioFrames"] as Long) > 10)
            }
            result.put("transport", JSONObject(live.snapshot()))
            result.put("sourceUri", source).put("status", "PASS")
        } catch (error: Throwable) {
            result.put("status", "FAIL").put("errorClass", error.javaClass.simpleName)
                .put("error", error.message ?: "Native live test failed")
        } finally {
            transport?.stop()
            extractor.release()
        }
        result.put("states", JSONArray(states.toList()))
        val output = Bundle().apply { putString("stream", "TASK10_LIVE_RESULT:$result\n") }
        instrumentation.finish(if (result.optString("status") == "PASS") -1 else 0, output)
    }
}
