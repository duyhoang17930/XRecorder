package com.xrecorder.xrecorder.recording

import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import java.util.UUID

/** Only native lifecycle transitions can report an active or completed recording. */
object CaptureState : EventChannel.StreamHandler {
    var sink: EventChannel.EventSink? = null
    var id = ""
    var state = "idle"
    var startedAt = 0L
    var activeStart = 0L
    var elapsed = 0L
    var output: String? = null
    var error: String? = null
    var config = CaptureConfig()
    var countdownRemaining = 0
    var width = 0
    var height = 0
    val busy: Boolean get() = state in setOf("awaitingPermission", "countdown", "starting", "recording", "paused", "stopping", "finalizing")
    fun snapshot(): Map<String, Any?> = mapOf("id" to id, "state" to state, "startedAt" to startedAt,
        "elapsedMs" to if (state == "recording") elapsed + SystemClock.elapsedRealtime() - activeStart else elapsed,
        "outputUri" to output, "error" to error, "width" to width, "height" to height, "fps" to config.fps, "bitrate" to config.bitrate, "config" to config.map(), "countdownRemaining" to countdownRemaining)
    fun prepare(settings: CaptureConfig) { config = settings; width = settings.width; height = settings.height; countdownRemaining = settings.countdown; id = UUID.randomUUID().toString(); elapsed = 0; startedAt = 0; output = null; error = null; transition("awaitingPermission") }
    fun transition(next: String, failure: String? = null) { state = next; error = failure; sink?.success(snapshot()) }
    fun emit() { sink?.success(snapshot()) }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events; events.success(snapshot()) }
    override fun onCancel(arguments: Any?) { sink = null }
}
