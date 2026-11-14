package com.xrecorder.xrecorder.recording

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaMetadataRetriever
import android.media.MediaExtractor
import android.media.MediaFormat
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
        const val SHOW_CONTROLS = "com.xrecorder.SHOW_CONTROLS"
        const val HIDE_CONTROLS = "com.xrecorder.HIDE_CONTROLS"
        const val NOTIFICATION = 2001
        const val CHANNEL = "screen_recording"
    }
    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var video: VideoEncoder? = null
    private var liveCapture: com.xrecorder.xrecorder.live.LiveCapture? = null
    private var regionProcessor: RegionCaptureProcessor? = null
    private var completionNotice: String? = null
    private var audio: SessionAudio? = null
    private var imageReader: android.media.ImageReader? = null
    private var facecam: FacecamOverlay? = null
    private var controls: FloatingRecordingControls? = null
    private var controlsUnavailable = false
    // Permission alone is not acceptance that controls may be included in MP4.
    private var controlsAcceptedInVideo = false
    private var drawingOverlay: DrawingOverlay? = null
    private var output: MediaOutput? = null
    private var descriptor: ParcelFileDescriptor? = null
    private var videoFile: File? = null
    private var audioFile: File? = null
    private var sessionId: String? = null
    private var started = false
    private val isEnding = java.util.concurrent.atomic.AtomicBoolean(false)
    private val isFinalizing = java.util.concurrent.atomic.AtomicBoolean(false)
    private var ending = false
    private var lastStorageCheck = 0L
    private var cameraWaitStart = 0L
    private var countdownDeadlineMs = 0L

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private val shakeEngine = ShakeDetectorEngine()
    private var sensorListenerRegistered = false

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null || ending || sessionId != CaptureState.id || CaptureState.state != "recording") return
            val now = SystemClock.elapsedRealtime()
            val triggered = shakeEngine.onSensorSample(
                x = event.values[0],
                y = event.values[1],
                z = event.values[2],
                timestampMs = now,
                currentState = CaptureState.state,
                isEnding = ending
            )
            if (triggered) {
                handler.post {
                    if (!ending && sessionId == CaptureState.id && CaptureState.state == "recording") {
                        stopCapture()
                    }
                }
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }
    private val config get() = CaptureState.config
    private val tick = object : Runnable {
        override fun run() {
            if (!ending && sessionId == CaptureState.id && CaptureState.busy) {
                val now = SystemClock.elapsedRealtime()
                if (now - lastStorageCheck > 10000) {
                    lastStorageCheck = now
                    if (StatFs(cacheDir.absolutePath).availableBytes < 64L * 1024 * 1024) { stopCapture(); return }
                }
                val remaining = CaptureTiming.autoStopRemainingMs(CaptureState.state, CaptureState.elapsedActiveMs, config.durationSeconds)
                if (remaining == 0L) { stopCapture(); return }
                updateControls(); CaptureState.emit(); handler.postDelayed(this, minOf(250L, remaining ?: 250L))
            }
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate(); instance = this
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Screen recording", NotificationManager.IMPORTANCE_LOW))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val commandSessionId = intent?.getStringExtra("sessionId")
        if (action == SHOW_CONTROLS || action == HIDE_CONTROLS) {
            if (CaptureNotificationPolicy.canAcceptAction(
                    action, commandSessionId, CaptureState.id, CaptureState.state,
                    ending, CaptureState.busy, started
                ) && !CaptureState.screenshot) {
                controlsAcceptedInVideo = action == SHOW_CONTROLS && android.provider.Settings.canDrawOverlays(this)
                if (!controlsAcceptedInVideo) {
                    drawingOverlay?.setDrawingEnabled(false)
                    controls?.close(); controls = null
                }
                updateControls()
                getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(true))
            }
            return START_NOT_STICKY
        }
        if (action == PAUSE || action == RESUME) {
            if (CaptureNotificationPolicy.canAcceptAction(
                    action, commandSessionId, CaptureState.id, CaptureState.state,
                    ending, CaptureState.busy, started
                )) {
                try { setPaused(action == PAUSE) } catch (_: Exception) { fail("The encoder could not change pause state.") }
            }
            return START_NOT_STICKY
        }
        if (action == STOP) {
            if (CaptureNotificationPolicy.canAcceptAction(
                    action, commandSessionId, CaptureState.id, CaptureState.state,
                    ending, CaptureState.busy, started
                )) {
                if (CaptureState.busy) stopCapture()
                else if (!started) stopSelf()
            }
            return START_NOT_STICKY
        }
        if (projection != null || started || ending) return START_NOT_STICKY
        if (intent == null || intent.getStringExtra("sessionId") != CaptureState.id || CaptureState.state != "awaitingPermission") { stopSelf(); return START_NOT_STICKY }
        sessionId = CaptureState.id
        try {
            val notification = notification(false)
            if (Build.VERSION.SDK_INT >= 29) {
                var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                if (Build.VERSION.SDK_INT >= 30 && config.microphone) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (Build.VERSION.SDK_INT >= 30 && config.facecam) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                startForeground(NOTIFICATION, notification, types)
            } else startForeground(NOTIFICATION, notification)
            if (config.liveRequested) {
                val endpoint = requireNotNull(com.xrecorder.xrecorder.live.LiveCaptureState.take(CaptureState.id)) {
                    "The live session was interrupted. Enter the destination again."
                }
                liveCapture = com.xrecorder.xrecorder.live.LiveCapture(CaptureState.id, endpoint, config.hasAudio,
                    requestKeyFrame = { handler.post { if (!ending) video?.requestKeyFrame() } },
                    changed = { handler.post { if (sessionId == CaptureState.id) CaptureState.emit() } },
                    failed = { handler.post {
                        if (!ending && sessionId == CaptureState.id) {
                            if (started) stopCapture("Live connection ended. The local video was saved.")
                            else fail("Could not start the livestream. Check the destination and connection.")
                        }
                    } })
            }
            if (StatFs(getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath).availableBytes < 128L * 1024 * 1024) throw java.io.IOException("Low storage")
            val consent = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra("consent", Intent::class.java) else @Suppress("DEPRECATION") intent.getParcelableExtra<Intent>("consent")
            require(consent != null)
            projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(Activity.RESULT_OK, consent)
            projection!!.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() { if (!ending && sessionId == CaptureState.id) stopCapture() }
                override fun onCapturedContentResize(width: Int, height: Int) {
                    if (ending || sessionId != CaptureState.id || CaptureState.screenshot || width <= 0 || height <= 0) return
                    // Keep the existing encoder canvas/preset. Android fits captured content
                    // to its Surface without cropping; a different aspect ratio may letterbox.
                    val region = regionProcessor
                    if (region != null && (width != region.sourceWidth || height != region.sourceHeight)) {
                        // A region is tied to a physical screen coordinate system. Preserve
                        // the valid recording instead of silently capturing different pixels.
                        stopCapture("Video saved. The screen size changed; select a new region to continue.")
                        return
                    }
                    try { display?.resize(width, height, resources.displayMetrics.densityDpi) }
                    catch (_: Exception) { fail("Could not resize the captured content.") }
                }
            }, handler)
            if(config.facecam) {
                facecam = FacecamOverlay(this) { fail("Front camera unavailable or in use. Disable facecam and retry.") }
                facecam!!.show()
            }
            if (config.countdown > 0) {
                countdownDeadlineMs = SystemClock.elapsedRealtime() + config.countdown * 1000L
                CaptureState.transition("countdown"); countdown()
            } else startEncoder()
        } catch (_: Exception) { fail("Could not prepare capture. Check permissions and free storage, then retry.") }
        return START_NOT_STICKY
    }
    private fun countdown() {
        if (ending || sessionId != CaptureState.id || CaptureState.state != "countdown") return
        val remainingMs = (countdownDeadlineMs - SystemClock.elapsedRealtime()).coerceAtLeast(0)
        CaptureState.countdownRemaining = CaptureTiming.countdownSeconds(remainingMs)
        CaptureState.emit()
        if (remainingMs == 0L) { startEncoder(); return }
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(false))
        handler.postDelayed({ countdown() }, minOf(1000L, remainingMs))
    }
    private fun startEncoder() {
        if (ending || sessionId != CaptureState.id) return
        if (config.isRegion && (resources.displayMetrics.widthPixels != config.regionSourceWidth ||
                resources.displayMetrics.heightPixels != config.regionSourceHeight)) {
            fail("The screen size changed. Select the capture region again."); return
        }
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
                audio = SessionAudio(this,projection!!,config.audio,config.micGain,config.internalGain,config.noiseReduction,config.audioDucking,audioFile!!,
                    onFailure = { handler.post { fail("Audio capture was interrupted. Try a different audio source or mute.") } },
                    encodedOutput = liveCapture?.audio)
                audio!!.start()
            } else descriptor = output!!.open()
            video = VideoEncoder(descriptor!!,videoFile?.absolutePath ?: output!!.legacyPath,config.encoderName,config.width,config.height,config.bitrate,config.fps,config.mime,
                onFirstFrame = { handler.post { markRecording() } },
                onFailure = { handler.post { fail("The encoder failed. Choose a lower recording preset.") } },
                encodedOutput = liveCapture?.video)
            if (config.isRegion) {
                val metrics = resources.displayMetrics
                val sourceWidth = metrics.widthPixels
                val sourceHeight = metrics.heightPixels
                regionProcessor = RegionCaptureProcessor(this, config, sourceWidth, sourceHeight, video!!.surface,
                    onReady = { surface ->
                        if (!ending && sessionId == CaptureState.id) {
                            try {
                                display = projection!!.createVirtualDisplay("XRecorder region",sourceWidth,sourceHeight,metrics.densityDpi,
                                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,surface,null,handler)
                                started = true
                            } catch (_: Exception) { fail("Could not capture the selected screen region.") }
                        }
                    }, onFailure = { message -> fail(message) })
            } else {
                display = projection!!.createVirtualDisplay("XRecorder",config.width,config.height,resources.displayMetrics.densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,video!!.surface,null,handler)
                started = true
            }
            handler.postDelayed({ if (!ending && CaptureState.state == "starting") fail("No capture frames arrived. Check the audio source and retry.") },15000)
        } catch (_: Exception) { fail("Could not start the selected video/audio configuration. Choose a lower preset or mute.") }
    }
    private fun captureImage() {
        try {
            val metrics = resources.displayMetrics
            val width = metrics.widthPixels; val height = metrics.heightPixels
            CaptureState.width = width; CaptureState.height = height
            val reader = android.media.ImageReader.newInstance(width,height,android.graphics.PixelFormat.RGBA_8888,2)
            imageReader = reader
            reader.setOnImageAvailableListener({ source ->
                if (ending || sessionId != CaptureState.id) return@setOnImageAvailableListener
                val image = try { source.acquireLatestImage() } catch (_: Exception) {
                    fail("Screenshot frame is unavailable."); return@setOnImageAvailableListener
                } ?: return@setOnImageAvailableListener
                if (!isEnding.compareAndSet(false, true)) {
                    runCatching { image.close() }
                    return@setOnImageAvailableListener
                }
                ending = true; handler.removeCallbacksAndMessages(null)
                try {
                    // Stop projecting as soon as the one required image is acquired.
                    // Keep its reader alive until the worker has consumed that image.
                    reader.setOnImageAvailableListener(null, null)
                    display?.release(); display = null
                    projection?.stop(); projection = null
                    CaptureState.transition("finalizing")
                    getSystemService(NotificationManager::class.java).notify(NOTIFICATION,notification(false))
                    Thread({
                        var saved: String? = null
                        try {
                            image.use {
                                val plane = it.planes[0]
                                val pixels = ScreenshotPixels.packedRgba(plane.buffer,width,height,plane.pixelStride,plane.rowStride)
                                val bitmap = android.graphics.Bitmap.createBitmap(width,height,android.graphics.Bitmap.Config.ARGB_8888)
                                try {
                                    bitmap.copyPixelsFromBuffer(pixels)
                                    output = MediaOutput(this,"Screenshot_${System.currentTimeMillis()}.png","image/png",journal=true)
                                    val fd = output!!.open()
                                    ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(fd.fileDescriptor)).use { stream ->
                                        check(bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,stream)); stream.flush()
                                    }
                                    val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                    ParcelFileDescriptor.AutoCloseInputStream(ParcelFileDescriptor.dup(fd.fileDescriptor)).use { stream ->
                                        stream.channel.position(0)
                                        android.graphics.BitmapFactory.decodeStream(stream,null,bounds)
                                    }
                                    check(bounds.outMimeType == "image/png" && bounds.outWidth == width && bounds.outHeight == height) { "Invalid screenshot PNG" }
                                    saved = output!!.commit().toString()
                                } finally { bitmap.recycle() }
                            }
                        } catch (_: Exception) { retainPartial() }
                        catch (_: OutOfMemoryError) { retainPartial() }
                        handler.post {
                            release()
                            if (saved == null) CaptureState.transition("failed","Screenshot could not be saved.")
                            else { CaptureState.output = saved; CaptureState.transition("completed") }
                            stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
                        }
                    },"screenshot-save").start()
                } catch (_: Exception) {
                    runCatching { image.close() }
                    retainPartial(); release()
                    CaptureState.transition("failed", "Screenshot capture is unavailable.")
                    stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
                } catch (_: OutOfMemoryError) {
                    runCatching { image.close() }
                    retainPartial(); release()
                    CaptureState.transition("failed", "Not enough memory for the screenshot.")
                    stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
                }
            },handler)
            display = projection!!.createVirtualDisplay("XRecorder Screenshot",width,height,metrics.densityDpi,DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,reader.surface,null,handler)
            handler.postDelayed({ if (!ending) fail("No screenshot arrived. Protected screens may block capture.") },10000)
        } catch (_: Exception) { fail("Screenshot capture is unavailable.") }
        catch (_: OutOfMemoryError) { fail("Not enough memory for the screenshot.") }
    }
    private fun markRecording() {
        if (ending || sessionId != CaptureState.id || CaptureState.state != "starting") return
        if (config.hasAudio && audio?.startTimeNs == 0L) { handler.postDelayed({ markRecording() },50); return }
        CaptureState.startedAt = System.currentTimeMillis(); CaptureState.activeStart = SystemClock.elapsedRealtime()
        CaptureState.transition("recording"); handler.post(tick)
        if (config.shakeToStop) {
            registerShakeSensor()
        }
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION,notification(true))
    }
    private fun notification(active: Boolean): Notification {
        val spec = CaptureNotificationPolicy.resolve(
            isScreenshot = CaptureState.screenshot,
            state = CaptureState.state,
            countdownRemaining = CaptureState.countdownRemaining,
            active = active,
            canDrawOverlays = android.provider.Settings.canDrawOverlays(this),
            controlsAcceptedInVideo = controlsAcceptedInVideo
        )
        val open = PendingIntent.getActivity(
            this,
            CaptureNotificationPolicy.REQUEST_CODE_OPEN,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        val smallIcon = when (spec.iconType) {
            CaptureNotificationPolicy.IconType.CAMERA -> android.R.drawable.ic_menu_camera
            CaptureNotificationPolicy.IconType.VIDEO -> android.R.drawable.presence_video_online
        }
        builder.setSmallIcon(smallIcon)
            .setContentTitle(CaptureText.text(this, spec.title))
            .setContentText(CaptureText.text(this, spec.text))
            .setOngoing(spec.ongoing)
            .setContentIntent(open)
        if (spec.alertOnce) {
            builder.setOnlyAlertOnce(true)
        }
        for (action in spec.actions) {
            val pendingIntent = PendingIntent.getService(
                this,
                action.requestCode,
                Intent(this, CaptureService::class.java)
                    .setAction(action.action)
                    .putExtra("sessionId", CaptureState.id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(Notification.Action.Builder(null, CaptureText.text(this, action.title), pendingIntent).build())
        }
        return builder.build()
    }
    fun setPaused(paused: Boolean) {
        if (ending || CaptureState.state != if(paused) "recording" else "paused") return
        video!!.setPaused(paused)
        audio?.paused = paused
        if (paused) {
            CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
            unregisterShakeSensor()
        } else {
            CaptureState.activeStart = SystemClock.elapsedRealtime()
            if (config.shakeToStop) {
                registerShakeSensor()
            }
        }
        CaptureState.transition(if(paused) "paused" else "recording")
        handler.removeCallbacks(tick); handler.post(tick)
        updateControls()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION,notification(true))
    }
    private fun updateControls() {
        if (CaptureState.screenshot || controlsUnavailable || !controlsAcceptedInVideo) return
        try {
            if (controls == null && CaptureState.state in listOf("recording", "paused")) {
                // Attach ink first so the toolbar stays above its touch-consuming window.
                if (drawingOverlay == null) drawingOverlay = DrawingOverlay(this, changed = { controls?.render(CaptureState.state, CaptureState.elapsedActiveMs) })
                val sessionId = CaptureState.id
                controls = FloatingRecordingControls(
                    context = this,
                    togglePause = {
                        if (CaptureState.id == sessionId && FloatingControlGeometry.canAcceptOverlayAction("togglePause", ending, CaptureState.state)) {
                            try { setPaused(CaptureState.state == "recording") }
                            catch (_: Exception) { fail("The encoder could not change pause state.") }
                        }
                    },
                    stop = {
                        if (CaptureState.id == sessionId && FloatingControlGeometry.canAcceptOverlayAction("stop", ending, CaptureState.state)) {
                            stopCapture()
                        }
                    },
                    initialScale = CaptureState.config.floatingScale,
                    initialOpacity = CaptureState.config.floatingOpacity,
                    initialRatioX = CaptureState.config.floatingRatioX,
                    initialRatioY = CaptureState.config.floatingRatioY,
                    setDrawing = { enabled -> setDrawingEnabled(enabled) },
                    drawingState = { drawingOverlay?.session?.snapshot() },
                    undoDrawing = { undoDrawing() },
                    clearDrawing = { clearDrawing() },
                    setDrawingStyle = { color, width -> setDrawingStyle(color, width) },
                    cameraOptions = if (facecam == null) null else { anchor -> showFacecamOptions(anchor) }
                )
            }
            controls?.render(CaptureState.state, CaptureState.elapsedActiveMs)
        }
        catch (_: RuntimeException) { controls?.close(); controls = null; controlsUnavailable = true }
    }
    // Called on the main looper, like stopCapture and the screenshot listener.
    // Once a finalizer owns the output, cancellation must not race its commit.
    fun cancelCapture(): Boolean {
        if (!isEnding.compareAndSet(false, true)) return false
        ending = true
        handler.removeCallbacksAndMessages(null)
        release(); cleanupPartial(); started = false
        CaptureState.output = null
        CaptureState.transition("idle")
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
        return true
    }
    @JvmOverloads fun stopCapture(notice: String? = null) {
        if (!isEnding.compareAndSet(false, true)) return
        ending = true
        completionNotice = notice
        handler.removeCallbacksAndMessages(null)
        if (!started) {
            release(); cleanupPartial(); CaptureState.transition("idle"); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return
        }
        if (CaptureState.state == "recording") CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
        CaptureState.transition("stopping")
        updateControls()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(false))
        try { audio?.requestStop() } catch (_: Exception) { }
        try { facecam?.close() } catch (_: Exception) { }; facecam = null
        try { display?.release() } catch (_: Exception) { }; display = null
        try { projection?.stop() } catch (_: Exception) { }; projection = null
        CaptureState.transition("finalizing")
        updateControls()
        if (!isFinalizing.compareAndSet(false, true)) return
        val region = regionProcessor
        regionProcessor = null
        Thread({
            var saved: String? = null; var failed = false; var recoveredFromFailure = false
            try {
                region?.finish()
                val encoder = video!!; encoder.finish()
                val durationUs = encoder.durationUs; val videoStartNs = encoder.sourceStartNs
                video = null; started = false
                if (config.hasAudio) {
                    val input = audio!!; input.finish()
                    val audioOffsetUs = (input.startTimeNs-videoStartNs)/1000
                    CaptureJournal.finalizedStreams(durationUs, audioOffsetUs)
                    descriptor?.close(); descriptor = output!!.open()
                    RecordingMuxer.combine(videoFile!!,audioFile!!,output!!,descriptor!!,audioOffsetUs,durationUs)
                    audio = null
                }
                val metadata = MediaMetadataRetriever()
                try {
                    metadata.setDataSource(descriptor!!.fileDescriptor)
                    require((metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0) > 0)
                    if (config.hasAudio) require(metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes")
                } finally { metadata.release() }
                val tracks = MediaExtractor()
                try {
                    tracks.setDataSource(descriptor!!.fileDescriptor)
                    val formats = (0 until tracks.trackCount).map { tracks.getTrackFormat(it) }
                    val videos = formats.filter { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                    val audios = formats.filter { it.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
                    require(videos.size == 1 && audios.size == if (config.hasAudio) 1 else 0) { "Unexpected output tracks" }
                    val format = videos.single()
                    require(format.getString(MediaFormat.KEY_MIME) == config.mime &&
                        format.getInteger(MediaFormat.KEY_WIDTH) == config.width &&
                        format.getInteger(MediaFormat.KEY_HEIGHT) == config.height) { "Output does not match the recording configuration" }
                } finally { tracks.release() }
                saved = output!!.commit().toString()
            } catch (_: Exception) {
                runCatching { region?.close() }
                video?.abort(); video = null; audio?.abort(); audio = null
                retainPartial()
                saved = CaptureJournal.recoverCurrent(this)?.uri
                recoveredFromFailure = saved != null
                failed = saved == null
            } finally {
                liveCapture?.stop(); liveCapture = null
                if (!failed && !recoveredFromFailure) { videoFile?.delete(); audioFile?.delete() }
            }
            handler.post {
                if(failed) CaptureState.transition("failed","Recording could not be finalized. No incomplete output was published.")
                else { CaptureState.output = saved; CaptureState.transition("completed") }
                controls?.close(); controls = null
                android.widget.Toast.makeText(this, if (failed) "Recording could not be saved." else completionNotice ?: "Video saved",
                    if (completionNotice != null) android.widget.Toast.LENGTH_LONG else android.widget.Toast.LENGTH_SHORT).show()
                stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
            }
        },"recording-finalizer").start()
    }
    private fun retainPartial() {
        output?.retain()
        runCatching { descriptor?.close() }
        descriptor = null
        // Keep files and pending rows on unexpected failures. Explicit Cancel uses cleanupPartial.
        runCatching { CaptureJournal.retainCurrent() }
    }
    private fun cleanupPartial() {
        try { output?.abort() } catch (_: Exception) { CaptureState.error = "A partial recording needs cleanup." }
        output = null
        try { descriptor?.close() } catch (_: Exception) { }
        descriptor = null
        try { videoFile?.delete() } catch (_: Exception) { }
        videoFile = null
        try { audioFile?.delete() } catch (_: Exception) { }
        audioFile = null
    }
    private fun fail(message: String) {
        if (!isEnding.compareAndSet(false, true)) return
        ending = true
        handler.removeCallbacksAndMessages(null)
        // Freeze before releasing codecs/projection: terminal snapshots and
        // recovery journals must keep active time, excluding cleanup latency.
        val elapsedAtFailure = CaptureState.elapsedActiveMs
        release()
        CaptureState.elapsed = elapsedAtFailure
        CaptureState.transition("failed",message)
        retainPartial()
        if (!CaptureState.screenshot) {
            try { android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_LONG).show() }
            catch (_: Exception) { }
        }
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    private fun release() {
        liveCapture?.stop(); liveCapture = null
        unregisterShakeSensor()
        try { display?.release() } catch (_: Exception) { }; display = null
        try { projection?.stop() } catch (_: Exception) { }; projection = null
        try { regionProcessor?.close() } catch (_: Exception) { }; regionProcessor = null
        try { controls?.close() } catch (_: Exception) { }; controls = null
        try { drawingOverlay?.close() } catch (_: Exception) { }; drawingOverlay = null
        try { facecam?.close() } catch (_: Exception) { }; facecam = null
        try { imageReader?.close() } catch (_: Exception) { }; imageReader = null
        try { audio?.abort() } catch (_: Exception) { }; audio = null
        try { video?.abort() } catch (_: Exception) { }; video = null
        try { display?.release() } catch (_: Exception) { }; display = null
        try { projection?.stop() } catch (_: Exception) { }; projection = null
        try { descriptor?.close() } catch (_: Exception) { }; descriptor = null
    }

    private fun registerShakeSensor() {
        if (sensorListenerRegistered || !config.shakeToStop) return
        try {
            if (sensorManager == null) {
                sensorManager = getSystemService(SensorManager::class.java)
                accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            }
            accelerometer?.let {
                sensorManager?.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_GAME, handler)
                sensorListenerRegistered = true
            }
        } catch (_: Exception) { }
    }

    private fun unregisterShakeSensor() {
        if (!sensorListenerRegistered) return
        try {
            sensorManager?.unregisterListener(sensorListener)
        } catch (_: Exception) { }
        sensorListenerRegistered = false
        shakeEngine.reset()
    }
    fun updateFloatingControls(scale: Float? = null, opacity: Float? = null) {
        controls?.applyCustomization(scale, opacity)
    }
    fun setDrawingEnabled(enabled: Boolean): Boolean {
        if (ending || CaptureState.state !in listOf("recording", "paused") || CaptureState.screenshot ||
            !controlsAcceptedInVideo || !android.provider.Settings.canDrawOverlays(this)) return false
        if (drawingOverlay == null && enabled) {
            drawingOverlay = DrawingOverlay(this, changed = { controls?.render(CaptureState.state, CaptureState.elapsedActiveMs) })
        }
        return drawingOverlay?.setDrawingEnabled(enabled) ?: false
    }
    fun clearDrawing(): Boolean {
        val overlay = drawingOverlay ?: return false
        if (ending) return false
        overlay.clear()
        return true
    }
    fun undoDrawing(): Boolean {
        return drawingOverlay?.undo() ?: false
    }
    fun setDrawingStyle(color: Int?, width: Float?): Boolean {
        val overlay = drawingOverlay ?: return false
        if (ending) return false
        overlay.setStyle(color, width)
        return true
    }
    fun getDrawingState(): Map<String, Any> {
        val snapshot = drawingOverlay?.session?.snapshot()
        return mapOf(
            "enabled" to (snapshot?.isDrawingMode ?: false),
            "strokeCount" to (snapshot?.strokeCount ?: 0),
            "canUndo" to (snapshot?.canUndo ?: false),
            "color" to (snapshot?.currentColor ?: DrawingStrokeEngine.DEFAULT_COLOR),
            "width" to (snapshot?.currentWidth ?: DrawingStrokeEngine.DEFAULT_STROKE_WIDTH)
        )
    }
    private fun showFacecamOptions(anchor: android.view.View) {
        if (ending) return
        val menu = android.widget.PopupMenu(this, anchor)
        listOf("Switch camera", "Small camera", "Normal camera", "Large camera", "No camera effect", "Grayscale camera", "Sepia camera")
            .forEachIndexed { index, title -> menu.menu.add(0, index, index, CaptureText.text(this, title)) }
        menu.setOnMenuItemClickListener { item ->
            val success = when (item.itemId) {
                0 -> switchFacecamCamera()
                1 -> setFacecamScale(.75f)
                2 -> setFacecamScale(1f)
                3 -> setFacecamScale(1.5f)
                4 -> setFacecamEffect(FacecamGeometry.EFFECT_OFF)
                5 -> setFacecamEffect(FacecamGeometry.EFFECT_MONO)
                6 -> setFacecamEffect(FacecamGeometry.EFFECT_SEPIA)
                else -> false
            }
            if (!success) android.widget.Toast.makeText(this, CaptureText.text(this, "Not supported by this device or the selected mode"), android.widget.Toast.LENGTH_SHORT).show()
            true
        }
        menu.show()
    }
    fun switchFacecamCamera(): Boolean = runCatching { facecam?.switchCamera() ?: false }.getOrDefault(false)
    fun setFacecamEffect(effect: Int): Boolean = facecam?.setEffect(effect) ?: false
    fun setFacecamScale(scale: Float): Boolean {
        val camera = facecam ?: return false
        if (ending) return false
        camera.setScale(scale)
        return true
    }
    fun getFacecamState(): Map<String, Any> = mapOf(
        "ready" to (facecam?.ready ?: false),
        "lensFacing" to (facecam?.currentLensFacing ?: FacecamGeometry.LENS_FACING_FRONT),
        "effect" to (facecam?.currentEffect ?: FacecamGeometry.EFFECT_OFF),
        "scale" to (facecam?.currentScale ?: FacecamGeometry.DEFAULT_SCALE)
    )
    override fun onDestroy() {
        controls?.close(); controls = null
        drawingOverlay?.close(); drawingOverlay = null
        if (!ending && sessionId == CaptureState.id && CaptureState.busy) fail("Recording service was interrupted.")
        instance = null; handler.removeCallbacksAndMessages(null); super.onDestroy()
    }
    override fun onConfigurationChanged(config: android.content.res.Configuration) {
        super.onConfigurationChanged(config)
        facecam?.transform()
        controls?.reposition()
        drawingOverlay?.onConfigurationChanged()
    }
}
