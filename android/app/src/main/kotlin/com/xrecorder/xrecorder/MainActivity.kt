package com.xrecorder.xrecorder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import android.content.Intent
import com.xrecorder.xrecorder.media.MediaCatalog
import com.xrecorder.xrecorder.recording.CaptureBridge
import com.xrecorder.xrecorder.recording.CaptureState
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val preferencesWorker = Executors.newSingleThreadExecutor()
    private var settingsChannel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null
    private var mediaCatalog: MediaCatalog? = null
    private var captureBridge: CaptureBridge? = null
    private var captureChannel: MethodChannel? = null
    private var captureEvents: EventChannel? = null
    private var editorBridge: com.xrecorder.xrecorder.editor.EditorBridge? = null
    private var editorChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        editorBridge=com.xrecorder.xrecorder.editor.EditorBridge(applicationContext)
        editorChannel=MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.xrecorder/editor").also{it.setMethodCallHandler(editorBridge)}
        flutterEngine.platformViewsController.registry.registerViewFactory("com.xrecorder/editor_preview",com.xrecorder.xrecorder.editor.EditorPreviewFactory(flutterEngine.dartExecutor.binaryMessenger))
        com.xrecorder.xrecorder.recording.CaptureJournal.initialize(applicationContext)
        captureBridge = CaptureBridge(this)
        captureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xrecorder/capture")
        captureChannel?.setMethodCallHandler(captureBridge)
        captureEvents = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xrecorder/capture/events")
        captureEvents?.setStreamHandler(CaptureState)
        mediaCatalog = MediaCatalog(this)
        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xrecorder/media")
        mediaChannel?.setMethodCallHandler(mediaCatalog)
        val appContext = applicationContext
        settingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xrecorder/settings")
        settingsChannel?.setMethodCallHandler { call, result ->
            if (call.method != "read" && call.method != "write") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val document = call.arguments as? String
            if (call.method == "write" && document == null) {
                result.error("invalid_settings", "Expected a settings document", null)
                return@setMethodCallHandler
            }
            preferencesWorker.execute {
                try {
                    val preferences = appContext.getSharedPreferences("app_settings", MODE_PRIVATE)
                    if (call.method == "read") {
                        val saved = preferences.getString("document", null)
                        runOnUiThread { result.success(saved) }
                    } else {
                        // Commit off the UI thread; acknowledge only after durable storage.
                        val committed = preferences.edit().putString("document", document).commit()
                        runOnUiThread {
                            if (committed) result.success(null)
                            else result.error("settings_write_failed", "Could not save preferences", null)
                        }
                    }
                } catch (_: Exception) {
                    runOnUiThread { result.error("settings_io_failed", "Preferences are unavailable", null) }
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        editorChannel?.setMethodCallHandler(null);editorBridge?.dispose();editorBridge=null;editorChannel=null
        captureChannel?.setMethodCallHandler(null)
        captureEvents?.setStreamHandler(null)
        captureChannel = null
        captureEvents = null
        captureBridge = null
        CaptureState.sink = null
        mediaChannel?.setMethodCallHandler(null)
        mediaChannel = null
        mediaCatalog?.dispose()
        mediaCatalog = null
        settingsChannel?.setMethodCallHandler(null)
        settingsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        preferencesWorker.shutdown()
        super.onDestroy()
    }
    override fun onPause() { com.xrecorder.xrecorder.editor.EditorPreview.pauseAll();super.onPause() }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (captureBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        if (mediaCatalog?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (captureBridge?.onPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
