package com.xrecorder.xrecorder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import android.content.Intent
import com.xrecorder.xrecorder.media.MediaCatalog

class MainActivity : FlutterActivity() {
    private val preferencesWorker = Executors.newSingleThreadExecutor()
    private var settingsChannel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null
    private var mediaCatalog: MediaCatalog? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (mediaCatalog?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
