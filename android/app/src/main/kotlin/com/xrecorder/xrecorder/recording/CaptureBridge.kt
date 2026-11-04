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
    companion object { const val CONSENT = 702; const val NOTIFICATIONS = 703 }
    private var requestedSession: String? = null
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> result.success(CaptureState.snapshot())
            "start" -> {
                if (CaptureState.busy) { result.error("busy", "A recording is already being prepared or captured.", null); return }
                CaptureState.prepare(); requestedSession = CaptureState.id
                try {
                    if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS)
                    else launchConsent()
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
    private fun launchConsent() {
        if (requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return
        val manager = activity.getSystemService(MediaProjectionManager::class.java)
        val intent = if (Build.VERSION.SDK_INT >= 34) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay()) else manager.createScreenCaptureIntent()
        activity.startActivityForResult(intent, CONSENT)
    }
    fun onPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATIONS) return false
        try { launchConsent() } catch (_: Exception) { CaptureState.transition("failed", "Could not open screen capture consent.") }
        return true
    }
    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != CONSENT) return false
        if (requestedSession != CaptureState.id || CaptureState.state != "awaitingPermission") return true
        requestedSession = null
        if (code != Activity.RESULT_OK || data == null) { CaptureState.transition("idle"); return true }
        try {
            val intent = Intent(activity, CaptureService::class.java).putExtra("sessionId", CaptureState.id).putExtra("consent", data)
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
        } catch (_: Exception) { CaptureState.transition("failed", "Android did not allow the recording service to start.") }
        return true
    }
}
