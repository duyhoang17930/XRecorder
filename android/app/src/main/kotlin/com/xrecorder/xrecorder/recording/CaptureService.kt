package com.xrecorder.xrecorder.recording

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodecList
import android.media.MediaMetadataRetriever
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import com.xrecorder.xrecorder.MainActivity

class CaptureService : Service() {
    companion object {
        var instance: CaptureService? = null
        const val STOP = "com.xrecorder.STOP"
        const val NOTIFICATION = 2001
        const val CHANNEL = "screen_recording"
    }
    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var video: VideoEncoder? = null
    private var output: MediaOutput? = null
    private var descriptor: ParcelFileDescriptor? = null
    private var started = false
    private var ending = false
    private val tick = object : Runnable {
        override fun run() { if (CaptureState.busy) { CaptureState.emit(); handler.postDelayed(this, 1000) } }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate(); instance = this
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Screen recording", NotificationManager.IMPORTANCE_LOW))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            if (intent.getStringExtra("sessionId") == CaptureState.id) stopCapture()
            else if (!started) stopSelf()
            return START_NOT_STICKY
        }
        if (started || ending) return START_NOT_STICKY
        if (intent == null || intent.getStringExtra("sessionId") != CaptureState.id || CaptureState.state != "awaitingPermission") { stopSelf(); return START_NOT_STICKY }
        try {
            val notification = notification(false)
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            else startForeground(NOTIFICATION, notification)
            CaptureState.transition("starting")
            if (StatFs(getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath).availableBytes < 64L * 1024 * 1024) throw java.io.IOException("Low storage")
            val consent = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra("consent", Intent::class.java) else @Suppress("DEPRECATION") intent.getParcelableExtra<Intent>("consent")
            require(consent != null)
            projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(Activity.RESULT_OK, consent)
            projection!!.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() { if (!ending) stopCapture() }
            }, handler)
            val metrics = resources.displayMetrics
            val encoder = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.firstOrNull { it.isEncoder && it.supportedTypes.any { type -> type.equals("video/avc", true) } }
                ?: throw IllegalStateException("No H.264 encoder is available")
            val caps = encoder.getCapabilitiesForType("video/avc").videoCapabilities
            var size: Pair<Int, Int>? = null
            for (longEdge in listOf(1280, 960, 640)) {
                val scale = minOf(1.0, longEdge.toDouble() / maxOf(metrics.widthPixels, metrics.heightPixels))
                val width = maxOf(caps.widthAlignment, ((metrics.widthPixels * scale).toInt() / caps.widthAlignment) * caps.widthAlignment)
                val height = maxOf(caps.heightAlignment, ((metrics.heightPixels * scale).toInt() / caps.heightAlignment) * caps.heightAlignment)
                if (caps.areSizeAndRateSupported(width, height, 30.0)) { size = width to height; break }
            }
            val dimensions = size ?: throw IllegalStateException("No supported recording size was found")
            CaptureState.width = dimensions.first; CaptureState.height = dimensions.second
            output = MediaOutput(this, "Recording_${System.currentTimeMillis()}.mp4")
            descriptor = output!!.open()
            video = VideoEncoder(descriptor!!, output!!.legacyPath, encoder.name, dimensions.first, dimensions.second,
                8000000.coerceIn(caps.bitrateRange.lower, caps.bitrateRange.upper), 30,
                onFirstFrame = { handler.post {
                    if (!ending) {
                        CaptureState.startedAt = System.currentTimeMillis(); CaptureState.activeStart = SystemClock.elapsedRealtime()
                        CaptureState.transition("recording"); handler.post(tick)
                        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(true))
                    }
                } },
                onFailure = { handler.post { fail("The encoder failed. No recording was published.") } })
            display = projection!!.createVirtualDisplay("XRecorder", dimensions.first, dimensions.second, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, video!!.surface, null, handler)
            started = true
            handler.postDelayed({ if (!ending && CaptureState.state == "starting") fail("No screen frames arrived. Try recording again.") }, 15000)
        } catch (_: Exception) { fail("Could not start screen recording. Check encoder support and available storage, then try again.") }
        return START_NOT_STICKY
    }
    private fun notification(active: Boolean): Notification {
        val stop = PendingIntent.getService(this, 1, Intent(this, CaptureService::class.java).setAction(STOP).putExtra("sessionId", CaptureState.id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(this, 2, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.presence_video_online).setContentTitle(if (active) "Screen recording" else "Preparing screen recording")
            .setContentText(if (active) "Your screen is being captured. Tap Stop to finish." else "Waiting for the encoder to start.").setOngoing(true).setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build()).build()
    }
    fun stopCapture() {
        if (ending) return
        if (!started) { fail("Recording stopped before any frames were saved."); return }
        ending = true
        if (CaptureState.state == "recording") CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
        CaptureState.transition("stopping")
        handler.removeCallbacks(tick)
        display?.release(); display = null
        projection?.stop(); projection = null
        CaptureState.transition("finalizing")
        Thread({
            var saved: String? = null
            var failed = false
            try {
                video?.finish(); video = null; started = false
                val metadata = MediaMetadataRetriever()
                try {
                    metadata.setDataSource(descriptor!!.fileDescriptor)
                    require((metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0) > 0)
                } finally { metadata.release() }
                saved = output!!.commit().toString()
            } catch (_: Exception) { video?.abort(); video = null; cleanupPartial(); failed = true }
            handler.post {
                if (failed) CaptureState.transition("failed", "Recording could not be finalized. The incomplete output was not published.")
                else { CaptureState.output = saved; CaptureState.transition("completed") }
                stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
            }
        }, "recording-finalizer").start()
    }

    private fun cleanupPartial() { try { output?.abort() } catch (_: Exception) { CaptureState.error = "A partial recording needs cleanup." } }
    private fun fail(message: String) {
        if (ending) return
        ending = true; handler.removeCallbacks(tick)
        release(); cleanupPartial(); CaptureState.transition("failed", message)
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    private fun release() {
        try { video?.abort() } catch (_: Exception) { }; video = null
        try { display?.release() } catch (_: Exception) { }; display = null
        try { projection?.stop() } catch (_: Exception) { }; projection = null
    }
    override fun onDestroy() {
        if (!ending && CaptureState.busy) fail("Recording service was interrupted.")
        instance = null; handler.removeCallbacksAndMessages(null); super.onDestroy()
    }
}
