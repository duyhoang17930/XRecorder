package com.xrecorder.xrecorder.editor

import org.json.JSONArray

/** Language identifiers come from the actual bundled engine, never UI labels. */
internal object SpeechLanguages {
    val catalog: List<Map<String, Any>> by lazy {
        val source = JSONArray(WhisperNative.languages().toString(Charsets.UTF_8))
        (0 until source.length()).map { index ->
            val value = source.getJSONObject(index)
            mapOf(
                "code" to value.getString("code"),
                "nativeCode" to value.getInt("nativeCode"),
                "englishName" to value.getString("englishName"),
                "available" to value.getBoolean("available"),
            )
        }
    }

    fun supports(code: String): Boolean =
        code == "auto" || catalog.any { it["code"] == code && it["available"] == true }

    fun code(nativeCode: Int): String? =
        catalog
            .firstOrNull { it["nativeCode"] == nativeCode && it["available"] == true }
            ?.get("code") as? String
}
