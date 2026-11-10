package com.xrecorder.xrecorder

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Owns only the first-run welcome state; it never edits the settings document. */
internal class OnboardingPreferencesBridge(context: Context) :
    MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("read", "savePage", "complete")) {
            result.notImplemented()
            return
        }
        worker.execute {
            try {
                val preferences =
                    appContext.getSharedPreferences("onboarding_state", Context.MODE_PRIVATE)
                val value = when (call.method) {
                    "read" -> read(preferences)
                    "savePage" -> savePage(preferences, call.arguments)
                    "complete" -> complete(preferences)
                    else -> error("unreachable")
                }
                mainHandler.post { result.success(value) }
            } catch (error: IllegalArgumentException) {
                mainHandler.post {
                    result.error("invalid_onboarding_state", "Invalid onboarding state", null)
                }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("onboarding_storage_failed", "Could not save onboarding state", null)
                }
            }
        }
    }

    private fun read(preferences: android.content.SharedPreferences): Map<String, Any> {
        if (!preferences.contains(KEY_COMPLETED)) {
            val completed = hasExistingUserData()
            val stored =
                preferences.edit()
                    .putBoolean(KEY_COMPLETED, completed)
                    .putInt(KEY_PAGE, 0)
                    .commit()
            check(stored) { "Onboarding state could not be initialized" }
        }
        return mapOf(
            "completed" to preferences.getBoolean(KEY_COMPLETED, false),
            "page" to preferences.getInt(KEY_PAGE, 0).coerceIn(0, LAST_PAGE),
        )
    }

    private fun savePage(
        preferences: android.content.SharedPreferences,
        argument: Any?,
    ): Any? {
        val page = argument as? Int ?: throw IllegalArgumentException("Expected page number")
        require(page in 0..LAST_PAGE)
        check(preferences.edit().putInt(KEY_PAGE, page).commit())
        return null
    }

    private fun complete(preferences: android.content.SharedPreferences): Any? {
        check(
            preferences.edit()
                .putBoolean(KEY_COMPLETED, true)
                .putInt(KEY_PAGE, LAST_PAGE)
                .commit(),
        )
        return null
    }

    /** Existing installs skip the tour; fresh installs see it once. */
    private fun hasExistingUserData(): Boolean {
        val packageInfo =
            if (Build.VERSION.SDK_INT >= 33) {
                appContext.packageManager.getPackageInfo(
                    appContext.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                appContext.packageManager.getPackageInfo(appContext.packageName, 0)
            }
        if (packageInfo.firstInstallTime < packageInfo.lastUpdateTime) return true

        val settings = appContext.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
        if (settings.contains("document")) return true
        val locale = appContext.getSharedPreferences("p2_locale", Context.MODE_PRIVATE)
        if (locale.contains("tag")) return true

        val preferenceFiles = File(appContext.applicationInfo.dataDir, "shared_prefs")
        if (preferenceFiles.listFiles().orEmpty().any { it.name != PREFS_FILE && it.isFile }) {
            return true
        }
        val privateRoots = listOf(appContext.filesDir, appContext.noBackupFilesDir, appContext.databasePathRoot())
        return privateRoots.any { root -> root.exists() && root.walkTopDown().any { it.isFile } }
    }

    fun dispose() {
        worker.shutdown()
    }

    private fun Context.databasePathRoot(): File = getDatabasePath(".onboarding_probe").parentFile!!

    private companion object {
        const val KEY_COMPLETED = "completed"
        const val KEY_PAGE = "page"
        const val LAST_PAGE = 2
        const val PREFS_FILE = "onboarding_state.xml"
    }
}
