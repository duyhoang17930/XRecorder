package com.xrecorder.xrecorder.recording

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CaptureBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object { const val CONSENT = 702; const val NOTIFICATIONS = 703; const val AUDIO_PERMISSION = 704; const val CAMERA_PERMISSION = 705; const val OVERLAY_PERMISSION = 706 }
    private var requestedSession: String? = CaptureState.id.takeIf { CaptureState.state == "awaitingPermission" }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(CaptureConfig.capabilities() + mapOf("facecam" to hasFrontCamera()))
            "current" -> result.success(CaptureState.snapshot())
            "pause", "resume" -> {
                if (call.argument<String>("sessionId") != CaptureState.id) { result.error("stale_session", "This session is no longer active.", null); return }
                try { CaptureService.instance?.setPaused(call.method == "pause"); result.success(CaptureState.snapshot()) }
                catch (_: Exception) { result.error("unavailable", "This encoder could not change pause state.", null) }
            }
            "start", "screenshot" -> {
                if (CaptureState.busy) { result.error("busy", "A recording is already being prepared or captured.", null); return }
                val config = try { if(call.method == "screenshot") CaptureConfig(countdown=3) else CaptureConfig.from(activity, call.arguments as? Map<*,*>) }
                    catch (e: Exception) { result.error("unsupported", e.message ?: "Unsupported capture settings", null); return }
                CaptureState.screenshot = call.method == "screenshot"
                if (config.facecam && !hasFrontCamera()) { result.error("unavailable","This device has no available front camera. Disable facecam to record.",null); return }
                CaptureState.prepare(config); requestedSession = CaptureState.id
                try {
                    if (!CaptureState.screenshot && Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS)
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
                else CaptureService.instance?.stopCapture()
                result.success(CaptureState.snapshot())
            }
            else -> result.notImplemented()
        }
    }
    private fun ensureAudioPermission() {
        if (CaptureState.config.hasAudio && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), AUDIO_PERMISSION)
        else ensureCameraPermission()
    }
    private fun hasFrontCamera(): Boolean = try {
        val manager=activity.getSystemService(android.hardware.camera2.CameraManager::class.java)
        manager.cameraIdList.any { manager.getCameraCharacteristics(it).get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)==android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT }
    } catch (_: Exception) { false }
    private fun ensureCameraPermission() {
        if (!CaptureState.config.facecam) { launchConsent(); return }
        if (!android.provider.Settings.canDrawOverlays(activity)) {
            activity.startActivityForResult(Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,android.net.Uri.parse("package:${activity.packageName}")),OVERLAY_PERMISSION)
        } else if(activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.CAMERA),CAMERA_PERMISSION)
        } else launchConsent()
    }
    private fun launchConsent() {
        if (requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return
        val manager = activity.getSystemService(MediaProjectionManager::class.java)
        val intent = if (Build.VERSION.SDK_INT >= 34) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay()) else manager.createScreenCaptureIntent()
        activity.startActivityForResult(intent, CONSENT)
    }
    fun onPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATIONS && requestCode != AUDIO_PERMISSION && requestCode != CAMERA_PERMISSION) return false
        if (CaptureState.state != "awaitingPermission") return true
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
        if (request == OVERLAY_PERMISSION) {
            if (CaptureState.state != "awaitingPermission") return true
            if (!android.provider.Settings.canDrawOverlays(activity)) { requestedSession=null; CaptureState.transition("failed","Floating camera access was not granted. Disable facecam to record without it.") }
            else try { ensureCameraPermission() } catch (_: Exception) { CaptureState.transition("failed","Camera permission is unavailable.") }
            return true
        }
        if (request != CONSENT) return false
        if (requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return true
        requestedSession = null
        if (code != Activity.RESULT_OK || data == null) { CaptureState.transition("idle"); return true }
        try {
            val intent = Intent(activity, CaptureService::class.java).putExtra("sessionId", CaptureState.id).putExtra("consent", data)
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
            // One-shot capture: leave our controls behind, then count down in the service.
            // No overlay/accessibility permission and no projection token reuse.
            if (CaptureState.screenshot && !activity.moveTaskToBack(true)) {
                CaptureService.instance?.stopCapture()
                CaptureState.transition("failed", "Could not switch screens for the screenshot. Try again.")
            }
        } catch (_: Exception) { CaptureState.transition("failed", "Android did not allow the recording service to start.") }
        return true
    }
}
