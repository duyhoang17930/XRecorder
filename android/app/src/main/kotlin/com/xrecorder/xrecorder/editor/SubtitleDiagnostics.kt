package com.xrecorder.xrecorder.editor

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import java.io.ByteArrayOutputStream

/** Read-only renderer probes share the exact overlay used by preview/export. */
internal object SubtitleDiagnostics {
    private fun png(overlay: SubtitleOverlay, width: Int, height: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        return try {
            overlay.onDraw(Canvas(bitmap), 500000)
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }

    fun probe(input: Map<*, *>): Map<String, Any> {
        val text = input["text"] as String
        val chunkText = input["chunkText"] as String
        SubtitleText.requireValid(text)
        SubtitleText.requireValid(chunkText)
        val cues = listOf(mapOf("startMs" to 0, "endMs" to 1000, "text" to text))
        val options =
            (input["options"] as? Map<*, *>)
                ?: mapOf("subtitleColor" to "white", "subtitleBackground" to "none")
        val overlay = SubtitleOverlay(cues, 0, options)
        val first = png(overlay, 640, 180)
        val reused = png(overlay, 640, 360)
        val fresh = png(SubtitleOverlay(cues, 0, options), 640, 360)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val clusters = (input["glyphClusters"] as? List<*>)?.map { it as String } ?: emptyList()
        require(clusters.size <= 40 && clusters.all { it.length <= 100 })
        return mapOf(
            "first" to first,
            "reused" to reused,
            "fresh" to fresh,
            "chunks" to SubtitleText.chunks(chunkText),
            "glyphs" to clusters.map { mapOf("text" to it, "supported" to paint.hasGlyph(it)) },
        )
    }
}
