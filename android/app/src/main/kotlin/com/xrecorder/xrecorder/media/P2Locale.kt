package com.xrecorder.xrecorder.media

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Native resource context only: never changes application locales or recreates capture. */
internal object P2Locale {
    private val supported =
        setOf("en", "vi", "es", "pt-BR", "fr", "de", "id", "ja", "ko", "zh-Hans", "hi", "ar")

    fun save(context: Context, tag: String) {
        require(tag in supported)
        context
            .getSharedPreferences("p2_locale", Context.MODE_PRIVATE)
            .edit()
            .putString("tag", tag)
            .apply()
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            // Only mutable P2 editor shortcuts; capture shortcuts belong to P1.
            // A launcher/rate-limit failure must not reject the chosen UI locale.
            runCatching {
                val manager =
                    context.getSystemService(android.content.pm.ShortcutManager::class.java)
                val localized = P2Locale.context(context)
                val updates =
                    manager.pinnedShortcuts
                        .filter {
                            !it.isImmutable &&
                                it.id in setOf("pinned_edit_video", "pinned_edit_photo")
                        }
                        .map { shortcut ->
                            val label =
                                localized.getString(
                                    if (shortcut.id == "pinned_edit_video")
                                        com.xrecorder.xrecorder.R.string.p2_edit_video
                                    else com.xrecorder.xrecorder.R.string.p2_edit_photo,
                                )
                            android.content.pm.ShortcutInfo.Builder(context, shortcut.id)
                                .setShortLabel(label)
                                .setLongLabel(label)
                                .build()
                        }
                if (updates.isNotEmpty()) manager.updateShortcuts(updates)
            }
                .onFailure {
                    android.util.Log.w(
                        "P2Locale",
                        "Editor shortcut labels could not be refreshed",
                        it,
                    )
                }
        }
    }

    fun context(base: Context): Context {
        val tag =
            base.getSharedPreferences("p2_locale", Context.MODE_PRIVATE).getString("tag", null)
                ?: return base
        if (tag !in supported) return base
        val locale = Locale.forLanguageTag(tag)
        val configuration =
            Configuration(base.resources.configuration).apply {
                setLocale(locale)
                setLayoutDirection(locale)
            }
        return base.createConfigurationContext(configuration)
    }
}
