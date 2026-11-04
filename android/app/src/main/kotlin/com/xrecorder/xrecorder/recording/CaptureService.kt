package com.xrecorder.xrecorder.recording

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaMetadataRetriever
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import com.xrecorder.xrecorder.MainActivity
import java.io.File

class CaptureService : Service() {
    companion object {
        var instance: CaptureService? = null
        const val STOP = "com.xrecorder.STOP"
        const val PAUSE = "com.xrecorder.PAUSE"
        const val RESUME = "com.xrecorder.RESUME"
        const val NOTIFICATION = 2001
        const val CHANNEL = "screen_recording"
    }
    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var video: VideoEncoder? = null
    private var audio: SessionAudio? = null
    private var imageReader: android.media.ImageReader? = null
    private var facecam: FacecamOverlay? = null
    private var output: MediaOutput? = null
    private var descriptor: ParcelFileDescriptor? = null
    private var videoFile: File? = null
    private var audioFile: File? = null
    private var started = false
    private var ending = false
    private var lastStorageCheck = 0L
    private var cameraWaitStart = 0L
    private val config get() = CaptureState.config
    private val tick = object : Runnable {
        override fun run() {
            if (!ending && CaptureState.busy) {
                val now = SystemClock.elapsedRealtime()
                if (now - lastStorageCheck > 10000) {
                    lastStorageCheck = now
                    if (StatFs(cacheDir.absolutePath).availableBytes < 64L * 1024 * 1024) { stopCapture(); return }
                }
                if (config.durationSeconds > 0 && CaptureState.state == "recording" &&
                    CaptureState.elapsed + SystemClock.elapsedRealtime() - CaptureState.activeStart >= config.durationSeconds * 1000L) { stopCapture(); return }
                CaptureState.emit(); handler.postDelayed(this, 250)
            }
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate(); instance = this
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Screen recording", NotificationManager.IMPORTANCE_LOW))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PAUSE || intent?.action == RESUME) {
            if (intent.getStringExtra("sessionId") == CaptureState.id) {
                try { setPaused(intent.action == PAUSE) } catch (_: Exception) { fail("The encoder could not change pause state.") }
            }
            return START_NOT_STICKY
        }
        if (intent?.action == STOP) {
            if (intent.getStringExtra("sessionId") == CaptureState.id && CaptureState.busy) stopCapture()
            else if (!started) stopSelf()
            return START_NOT_STICKY
        }
        if (started || ending) return START_NOT_STICKY
        if (intent == null || intent.getStringExtra("sessionId") != CaptureState.id || CaptureState.state != "awaitingPermission") { stopSelf(); return START_NOT_STICKY }
        try {
            val notification = notification(false)
            if (Build.VERSION.SDK_INT >= 29) {
                var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                if (Build.VERSION.SDK_INT >= 30 && config.microphone) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (Build.VERSION.SDK_INT >= 30 && config.facecam) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                startForeground(NOTIFICATION, notification, types)
            } else startForeground(NOTIFICATION, notification)
            if (StatFs(getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath).availableBytes < 128L * 1024 * 1024) throw java.io.IOException("Low storage")
            val consent = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra("consent", Intent::class.java) else @Suppress("DEPRECATION") intent.getParcelableExtra<Intent>("consent")
            require(consent != null)
            projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(Activity.RESULT_OK, consent)
            projection!!.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() { if (!ending) stopCapture() }
            }, handler)
            if(config.facecam) {
                facecam = FacecamOverlay(this) { fail("Front camera unavailable or in use. Disable facecam and retry.") }
                facecam!!.show()
            }
            if (config.countdown > 0) { CaptureState.transition("countdown"); countdown() } else startEncoder()
        } catch (_: Exception) { fail("Could not prepare capture. Check permissions and free storage, then retry.") }
        return START_NOT_STICKY
    }
    private fun countdown() {
        if (ending) return
        CaptureState.emit()
        handler.postDelayed({
            if (!ending) {
                CaptureState.countdownRemaining--
                if (CaptureState.countdownRemaining <= 0) startEncoder() else countdown()
            }
        },1000)
    }
    private fun startEncoder() {
        if (ending) return
        if (config.facecam && facecam?.ready != true) {
            if(cameraWaitStart==0L) cameraWaitStart=SystemClock.elapsedRealtime()
            if(SystemClock.elapsedRealtime()-cameraWaitStart>10000) { fail("No camera frames arrived. Disable facecam and retry."); return }
            handler.postDelayed({startEncoder()},100); return
        }
        CaptureState.transition("starting")
        if (CaptureState.screenshot) { captureImage(); return }
        try {
            output = MediaOutput(this,"Recording_${System.currentTimeMillis()}.mp4",journal=true)
            if (config.hasAudio) {
                videoFile = File(cacheDir,"capture_${CaptureState.id}.mp4")
                audioFile = File(cacheDir,"capture_${CaptureState.id}.m4a")
                descriptor = ParcelFileDescriptor.open(videoFile!!,ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_READ_WRITE or ParcelFileDescriptor.MODE_TRUNCATE)
                audio = SessionAudio(this,projection!!,config.audio,config.micGain,config.internalGain,config.noiseReduction,audioFile!!,
                    onFailure = { handler.post { fail("Audio capture was interrupted. Try a different audio source or mute.") } })
                audio!!.start()
            } else descriptor = output!!.open()
            video = VideoEncoder(descriptor!!,videoFile?.absolutePath ?: output!!.legacyPath,config.encoderName,config.width,config.height,config.bitrate,config.fps,config.mime,
                onFirstFrame = { handler.post { markRecording() } },
                onFailure = { handler.post { fail("The encoder failed. Choose a lower recording preset.") } })
            display = projection!!.createVirtualDisplay("XRecorder",config.width,config.height,resources.displayMetrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,video!!.surface,null,handler)
            started = true
            handler.postDelayed({ if (!ending && CaptureState.state == "starting") fail("No capture frames arrived. Check the audio source and retry.") },15000)
        } catch (_: Exception) { fail("Could not start the selected video/audio configuration. Choose a lower preset or mute.") }
    }
    private fun captureImage() {
        try {
            val metrics = resources.displayMetrics
            val width = metrics.widthPixels; val height = metrics.heightPixels
            val reader = android.media.ImageReader.newInstance(width,height,android.graphics.PixelFormat.RGBA_8888,2)
            imageReader = reader
            reader.setOnImageAvailableListener({ source ->
                val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
                if (ending) { image.close(); return@setOnImageAvailableListener }
                ending = true; handler.removeCallbacksAndMessages(null)
                CaptureState.transition("finalizing")
                Thread({
                    var saved: String? = null
                    try {
                        image.use {
                            val plane = it.planes[0]
                            val paddedWidth = plane.rowStride / plane.pixelStride
                            val padded = android.graphics.Bitmap.createBitmap(paddedWidth,height,android.graphics.Bitmap.Config.ARGB_8888)
                            padded.copyPixelsFromBuffer(plane.buffer)
                            val cropped = android.graphics.Bitmap.createBitmap(padded,0,0,width,height)
                            output = MediaOutput(this,"Screenshot_${System.currentTimeMillis()}.png","image/png",journal=true)
                            val fd = output!!.open()
                            ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(fd.fileDescriptor)).use { stream ->
                                check(cropped.compress(android.graphics.Bitmap.CompressFormat.PNG,100,stream)); stream.flush()
                            }
                            if (cropped !== padded) cropped.recycle(); padded.recycle()
                            saved = output!!.commit().toString()
                        }
                    } catch (_: Exception) { cleanupPartial() }
                    handler.post {
                        release()
                        if (saved == null) CaptureState.transition("failed","Screenshot could not be saved.")
                        else { CaptureState.output = saved; CaptureState.transition("completed") }
                        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
                    }
                },"screenshot-save").start()
            },handler)
            display = projection!!.createVirtualDisplay("XRecorder Screenshot",width,height,metrics.densityDpi,DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,reader.surface,null,handler)
            handler.postDelayed({ if (!ending) fail("No screenshot arrived. Protected screens may block capture.") },10000)
        } catch (_: Exception) { fail("Screenshot capture is unavailable.") }
    }
    private fun markRecording() {
        if (ending) return
        if (config.hasAudio && audio?.startTimeNs == 0L) { handler.postDelayed({ markRecording() },50); return }
        CaptureState.startedAt = System.currentTimeMillis(); CaptureState.activeStart = SystemClock.elapsedRealtime()
        CaptureState.transition("recording"); handler.post(tick)
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION,notification(true))
    }
    private fun notification(active: Boolean): Notification {
        val paused = CaptureState.state == "paused"
        val toggle = PendingIntent.getService(this,3,Intent(this,CaptureService::class.java).setAction(if(paused) RESUME else PAUSE).putExtra("sessionId",CaptureState.id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this,1,Intent(this,CaptureService::class.java).setAction(STOP).putExtra("sessionId",CaptureState.id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(this,2,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this,CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        if (active) builder.addAction(Notification.Action.Builder(null,if(paused) "Resume" else "Pause",toggle).build())
        return builder.setSmallIcon(android.R.drawable.presence_video_online).setContentTitle(if(paused) "Recording paused" else if(active) "Screen recording" else "Preparing screen recording")
            .setContentText(if(active) "Your screen is being captured. Tap Stop to finish." else "Waiting for capture to start.").setOngoing(true).setContentIntent(open)
            .addAction(Notification.Action.Builder(null,"Stop",stop).build()).build()
    }
    fun setPaused(paused: Boolean) {
        if (ending || CaptureState.state != if(paused) "recording" else "paused") return
        video!!.setPaused(paused)
        audio?.paused = paused
        if (paused) CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
        else CaptureState.activeStart = SystemClock.elapsedRealtime()
        CaptureState.transition(if(paused) "paused" else "recording")
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION,notification(true))
    }
    fun stopCapture() {
        if (ending) return
        ending = true; handler.removeCallbacksAndMessages(null)
        if (!started) {
            release(); cleanupPartial(); CaptureState.transition("idle"); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return
        }
        if (CaptureState.state == "recording") CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
        CaptureState.transition("stopping")
        audio?.requestStop()
        facecam?.close(); facecam = null
        display?.release(); display = null
        projection?.stop(); projection = null
        CaptureState.transition("finalizing")
        Thread({
            var saved: String? = null; var failed = false
            try {
                val encoder = video!!; encoder.finish()
                val durationUs = encoder.durationUs; val videoStartNs = encoder.sourceStartNs
                video = null; started = false
                if (config.hasAudio) {
                    val input = audio!!; input.finish()
                    descriptor?.close(); descriptor = output!!.open()
                    RecordingMuxer.combine(videoFile!!,audioFile!!,output!!,descriptor!!,(input.startTimeNs-videoStartNs)/1000,durationUs)
                    audio = null
                }
                val metadata = MediaMetadataRetriever()
                try {
                    metadata.setDataSource(descriptor!!.fileDescriptor)
                    require((metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0) > 0)
                    if (config.hasAudio) require(metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes")
                } finally { metadata.release() }
                saved = output!!.commit().toString()
            } catch (_: Exception) { video?.abort(); video = null; audio?.abort(); audio = null; cleanupPartial(); failed = true }
            finally { videoFile?.delete(); audioFile?.delete() }
            handler.post {
                if(failed) CaptureState.transition("failed","Recording could not be finalized. No incomplete output was published.")
                else { CaptureState.output = saved; CaptureState.transition("completed") }
                stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
            }
        },"recording-finalizer").start()
    }
    private fun cleanupPartial() {
        try { output?.abort() } catch (_: Exception) { CaptureState.error = "A partial recording needs cleanup." }
        try { descriptor?.close() } catch (_: Exception) { }
        videoFile?.delete(); audioFile?.delete()
    }
    private fun fail(message: String) {
        if (ending) return
        ending = true; handler.removeCallbacksAndMessages(null)
        release(); cleanupPartial(); CaptureState.transition("failed",message)
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    private fun release() {
        facecam?.close(); facecam = null
        try { imageReader?.close() } catch (_: Exception) { }; imageReader = null
        try { audio?.abort() } catch (_: Exception) { }; audio = null
        try { video?.abort() } catch (_: Exception) { }; video = null
        try { display?.release() } catch (_: Exception) { }; display = null
        try { projection?.stop() } catch (_: Exception) { }; projection = null
    }
    override fun onDestroy() {
        if (!ending && CaptureState.busy) fail("Recording service was interrupted.")
        instance = null; handler.removeCallbacksAndMessages(null); super.onDestroy()
    }
    override fun onConfigurationChanged(config: android.content.res.Configuration) { super.onConfigurationChanged(config); facecam?.transform() }
}
