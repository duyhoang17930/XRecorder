package com.xrecorder.xrecorder.recording

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CaptureBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val capabilitiesWorker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pendingCapabilities = mutableSetOf<MethodChannel.Result>()
    private var disposed = false
    companion object { const val CONSENT = 702; const val NOTIFICATIONS = 703; const val AUDIO_PERMISSION = 704; const val CAMERA_PERMISSION = 705; const val OVERLAY_PERMISSION = 706; const val CONTROLS_OVERLAY_PERMISSION = 707 }
    private var requestedSession: String? = CaptureState.id.takeIf { CaptureState.state == "awaitingPermission" }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { result.error("cancelled", "Capture screen closed.", null); return }
        when (call.method) {
            "capabilities" -> {
                pendingCapabilities.add(result)
                capabilitiesWorker.execute {
                    val value = runCatching { CaptureConfig.capabilities(activity) + mapOf(
                        "facecam" to hasFrontCamera(),
                        "displayWidth" to activity.resources.displayMetrics.widthPixels,
                        "displayHeight" to activity.resources.displayMetrics.heightPixels
                    ) }
                    main.post {
                        if (pendingCapabilities.remove(result)) {
                            value.fold({ result.success(it) }, { result.error("unavailable", "Could not check device capabilities. Try again.", null) })
                        }
                    }
                }
            }
            "current" -> result.success(CaptureState.snapshot())
            "liveStatus" -> result.success(com.xrecorder.xrecorder.live.LiveCaptureState.snapshotFor(CaptureState.id, CaptureState.config.liveRequested, CaptureState.state))
            "liveDestination", "saveLiveDestination", "forgetLiveDestination" -> {
                // Reuse the serialized worker and engine-disposal result guard. Keystore/IO
                // must not block the main thread or echo credentials in errors.
                val args = call.arguments as? Map<*, *>
                pendingCapabilities.add(result)
                capabilitiesWorker.execute {
                    val value = runCatching {
                        val store = com.xrecorder.xrecorder.live.LiveDestinationStore(activity)
                        when (call.method) {
                            "liveDestination" -> store.read()
                            "saveLiveDestination" -> {
                                store.save(args?.get("name") as? String ?: "", args?.get("serverUrl") as? String ?: "", args?.get("streamKey") as? String ?: "")
                                true
                            }
                            else -> { store.forget(); true }
                        }
                    }
                    main.post {
                        if (pendingCapabilities.remove(result)) value.fold(
                            { result.success(it) },
                            { result.error("destination_unavailable", "Could not access the saved livestream destination. Try again.", null) },
                        )
                    }
                }
            }
            "pause", "resume" -> {
                if (call.argument<String>("sessionId") != CaptureState.id) { result.error("stale_session", "This session is no longer active.", null); return }
                try { CaptureService.instance?.setPaused(call.method == "pause"); result.success(CaptureState.snapshot()) }
                catch (_: Exception) { result.error("unavailable", "This encoder could not change pause state.", null) }
            }
            "start", "screenshot" -> {
                if (CaptureState.busy || CaptureRequests.awaitingResult || CaptureService.instance != null) { result.error("busy", "A recording is already being prepared or captured.", null); return }
                val live = try {
                    val args = call.arguments as? Map<*, *>
                    if (call.method == "start" && args?.get("liveServer") != null)
                        com.xrecorder.xrecorder.live.RtmpEndpoint.parse(args["liveServer"] as String, args["liveKey"] as? String ?: "")
                    else null
                } catch (_: Exception) { result.error("invalid_live", "Enter a valid RTMP/RTMPS server URL and stream key.", null); return }
                val config = try { if(call.method == "screenshot")
                    CaptureConfig(countdown=CaptureTiming.screenshotDelay((call.arguments as? Map<*, *>)?.get("countdown") ?: savedScreenshotDelay()))
                    else CaptureConfig.from(activity, call.arguments as? Map<*,*>).copy(liveRequested = live != null) }
                    catch (e: Exception) { result.error("unsupported", e.message ?: "Unsupported capture settings", null); return }
                if (live != null && config.codec != "avc") { result.error("unsupported", "Choose H264 in recording settings before livestreaming.", null); return }
                if (config.facecam && !hasFrontCamera()) { result.error("unavailable","This device has no available front camera. Disable facecam to record.",null); return }
                try {
                    if (live != null) CaptureState.prepareLive(config, live)
                    else CaptureState.prepare(config, call.method == "screenshot")
                    requestedSession = CaptureState.id
                    if (!CaptureState.screenshot && Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                        requestPermission(Manifest.permission.POST_NOTIFICATIONS, NOTIFICATIONS)
                    else ensureAudioPermission()
                    result.success(CaptureState.snapshot())
                } catch (_: Exception) {
                    CaptureState.transition("failed", "Screen capture consent is unavailable.")
                    result.error("unavailable", "Screen capture consent is unavailable.", null)
                }
            }
            "stop", "cancel" -> {
                if (call.argument<String>("sessionId") != CaptureState.id) { result.error("stale_session", "This session is no longer active.", null); return }
                if (CaptureState.state == "awaitingPermission") { requestedSession = null; CaptureState.transition("idle") }
                else if (call.method == "cancel" && CaptureState.busy) {
                    val service = CaptureService.instance
                    if (service == null) { result.error("unavailable", "Capture service is unavailable.", null); return }
                    if (!service.cancelCapture()) { result.error("too_late", "Capture is already being saved.", null); return }
                }
                else if (call.method == "stop") CaptureService.instance?.stopCapture()
                result.success(CaptureState.snapshot())
            }
            "updateFloatingBall" -> {
                val args = call.arguments as? Map<*, *>
                val scale = (args?.get("scale") as? Number)?.toFloat()
                val opacity = (args?.get("opacity") as? Number)?.toFloat()
                CaptureService.instance?.updateFloatingControls(scale, opacity)
                result.success(true)
            }
            "setDrawingEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = CaptureService.instance?.setDrawingEnabled(enabled) ?: false
                result.success(success)
            }
            "clearDrawing" -> {
                val success = CaptureService.instance?.clearDrawing() ?: false
                result.success(success)
            }
            "undoDrawing" -> {
                val success = CaptureService.instance?.undoDrawing() ?: false
                result.success(success)
            }
            "setDrawingStyle" -> {
                val args = call.arguments as? Map<*, *>
                val color = (args?.get("color") as? Number)?.toInt()
                val width = (args?.get("width") as? Number)?.toFloat()
                val success = CaptureService.instance?.setDrawingStyle(color, width) ?: false
                result.success(success)
            }
            "getDrawingState" -> {
                val state = CaptureService.instance?.getDrawingState() ?: mapOf(
                    "enabled" to false,
                    "strokeCount" to 0,
                    "canUndo" to false,
                    "color" to DrawingStrokeEngine.DEFAULT_COLOR,
                    "width" to DrawingStrokeEngine.DEFAULT_STROKE_WIDTH
                )
                result.success(state)
            }
            "switchFacecamCamera" -> {
                val success = CaptureService.instance?.switchFacecamCamera() ?: false
                result.success(success)
            }
            "setFacecamEffect" -> {
                val effect = call.argument<Int>("effect") ?: FacecamGeometry.EFFECT_OFF
                val success = CaptureService.instance?.setFacecamEffect(effect) ?: false
                result.success(success)
            }
            "setFacecamScale" -> {
                val scale = (call.argument<Number>("scale"))?.toFloat() ?: FacecamGeometry.DEFAULT_SCALE
                val success = CaptureService.instance?.setFacecamScale(scale) ?: false
                result.success(success)
            }
            "getFacecamState" -> {
                val state = CaptureService.instance?.getFacecamState() ?: mapOf(
                    "ready" to false,
                    "lensFacing" to FacecamGeometry.LENS_FACING_FRONT,
                    "effect" to FacecamGeometry.EFFECT_OFF,
                    "scale" to FacecamGeometry.DEFAULT_SCALE
                )
                result.success(state)
            }
            else -> result.notImplemented()
        }
    }
    fun dispose() {
        disposed = true
        pendingCapabilities.toList().forEach { it.error("cancelled", "Capture screen closed.", null) }
        pendingCapabilities.clear()
        capabilitiesWorker.shutdownNow()
    }
    private fun requestPermission(permission: String, code: Int) {
        CaptureRequests.launchOnce(code, CaptureState.id) {
            activity.requestPermissions(arrayOf(permission), code)
        }
    }
    private fun openActivity(code: Int, createIntent: () -> Intent) {
        CaptureRequests.launchOnce(code, CaptureState.id) {
            activity.startActivityForResult(createIntent(), code)
        }
    }
    private fun ensureAudioPermission() {
        if (disposed || requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return
        if (CaptureState.config.hasAudio && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
            requestPermission(Manifest.permission.RECORD_AUDIO, AUDIO_PERMISSION)
        else ensureCameraPermission()
    }
    private fun hasFrontCamera(): Boolean = try {
        val manager=activity.getSystemService(android.hardware.camera2.CameraManager::class.java)
        manager.cameraIdList.any { manager.getCameraCharacteristics(it).get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)==android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT }
    } catch (_: Exception) { false }
    private fun ensureCameraPermission() {
        if (disposed || requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return
        // Optional recording controls must not force an overlay permission trip.
        // Without overlay access the existing notification controls remain usable.
        if (!CaptureState.config.facecam) { launchConsent(); return }
        if (!android.provider.Settings.canDrawOverlays(activity)) {
            openActivity(OVERLAY_PERMISSION) { Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,android.net.Uri.parse("package:${activity.packageName}")) }
        } else if(activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermission(Manifest.permission.CAMERA, CAMERA_PERMISSION)
        } else launchConsent()
    }
    private fun launchConsent() {
        if (disposed || requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return
        openActivity(CONSENT) {
            val manager = activity.getSystemService(MediaProjectionManager::class.java)
            // Reserve before creating the one-shot intent; never retain it for another session.
            // Video uses the system selector. Screenshots retain whole-screen capture.
            if (Build.VERSION.SDK_INT >= 34 && (CaptureState.screenshot || CaptureState.config.isRegion || CaptureState.config.facecam)) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay()) else manager.createScreenCaptureIntent()
        }
    }
    private fun savedScreenshotDelay(): Int = runCatching {
        val document = activity.getSharedPreferences("app_settings", android.content.Context.MODE_PRIVATE).getString("document", null)
        val saved = document?.let { org.json.JSONObject(it).optJSONObject("values")?.optString("screenshotDelay") }
        saved?.removeSuffix("s")?.toIntOrNull()?.takeIf { it in listOf(1, 3, 5, 10) } ?: 3
    }.getOrDefault(3)
    private fun consumeResult(code: Int): String? = CaptureRequests.consumeFor(
        code, requestedSession, receiverActive = !disposed,
        // Cancel clears requestedSession, but its system dialog must still drain.
        // The callback's state/owner checks below prevent using that old consent.
        cancelledSession = CaptureState.id.takeUnless { CaptureState.busy }
    )
    fun onPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATIONS && requestCode != AUDIO_PERMISSION && requestCode != CAMERA_PERMISSION) return false
        val sessionId = consumeResult(requestCode) ?: return true
        if (disposed || sessionId != CaptureState.id || requestedSession != sessionId || CaptureState.state != "awaitingPermission") return true
        if (requestCode == AUDIO_PERMISSION && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestedSession = null; CaptureState.transition("failed", "Audio permission was denied. Select mute to record without audio."); return true
        }
        if (requestCode == CAMERA_PERMISSION && activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestedSession=null; CaptureState.transition("failed","Camera permission was denied. Disable facecam to continue."); return true
        }
        try { if (requestCode == NOTIFICATIONS) ensureAudioPermission() else ensureCameraPermission() }
        catch (_: Exception) { CaptureState.transition("failed", "Could not open screen capture consent.") }
        return true
    }
    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request !in listOf(CONSENT, OVERLAY_PERMISSION, CONTROLS_OVERLAY_PERMISSION)) return false
        val sessionId = consumeResult(request) ?: return true
        if (disposed || sessionId != CaptureState.id || requestedSession != sessionId || CaptureState.state != "awaitingPermission") return true
        if (request == CONTROLS_OVERLAY_PERMISSION) {
            // Grant is optional. Back/deny still continues with notification controls.
            if (requestedSession == CaptureState.id && CaptureState.state == "awaitingPermission") {
                try { launchConsent() }
                catch (_: Exception) { CaptureState.transition("failed", "Could not open screen capture consent.") }
            }
            return true
        }
        if (request == OVERLAY_PERMISSION) {
            if (CaptureState.state != "awaitingPermission") return true
            if (!android.provider.Settings.canDrawOverlays(activity)) { requestedSession=null; CaptureState.transition("failed","Floating camera access was not granted. Disable facecam to record without it.") }
            else try { ensureCameraPermission() } catch (_: Exception) { CaptureState.transition("failed","Camera permission is unavailable.") }
            return true
        }
        if (request != CONSENT) return false
        if (requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return true
        requestedSession = null
        if (code != Activity.RESULT_OK || data == null) { com.xrecorder.xrecorder.live.LiveCaptureState.finish(CaptureState.id, "cancelled"); CaptureState.transition("idle"); return true }
        try {
            val intent = Intent(activity, CaptureService::class.java).putExtra("sessionId", CaptureState.id).putExtra("consent", data)
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
            // One-shot capture: leave our controls behind, then count down in the service.
            // No overlay/accessibility permission and no projection token reuse.
            if ((CaptureState.screenshot || CaptureState.config.isRegion || CaptureState.config.liveRequested) && !activity.moveTaskToBack(true)) {
                CaptureService.instance?.stopCapture()
                CaptureState.transition("failed", "Could not switch screens for capture. Try again.")
            }
        } catch (_: Exception) { CaptureState.transition("failed", "Android did not allow the recording service to start.") }
        return true
    }
}
