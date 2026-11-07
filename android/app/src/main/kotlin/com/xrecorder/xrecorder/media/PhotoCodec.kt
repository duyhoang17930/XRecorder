package com.xrecorder.xrecorder.media

import android.content.Context
import android.graphics.*
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import java.io.ByteArrayOutputStream
import kotlin.math.*

/** Normalize orientation once and convert wide-gamut inputs into an sRGB copy. */
object PhotoCodec {
    fun decode(context: Context, uri: Uri): ByteArray {
        require(uri.scheme == "content")
        val bitmap =
            if (Build.VERSION.SDK_INT >= 28) {
                ImageDecoder.decodeBitmap(
                    ImageDecoder.createSource(context.contentResolver, uri),
                ) { decoder, info, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
                    val scale = min(1.0, 2048.0 / max(info.size.width, info.size.height))
                    decoder.setTargetSize(
                        max(1, (info.size.width * scale).roundToInt()),
                        max(1, (info.size.height * scale).roundToInt()),
                    )
                }
            } else {
                val resolver = context.contentResolver
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                resolver.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, bounds) }
                require(bounds.outWidth > 0 && bounds.outHeight > 0)
                var sample = 1
                while (max(bounds.outWidth, bounds.outHeight) / sample > 2048) sample *= 2
                val options =
                    BitmapFactory.Options().apply {
                        inSampleSize = sample
                        inPreferredConfig = Bitmap.Config.ARGB_8888
                        if (Build.VERSION.SDK_INT >= 26)
                            inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.SRGB)
                    }
                val decoded =
                    resolver.openInputStream(uri)!!.use {
                        BitmapFactory.decodeStream(it, null, options)
                    } ?: error("Unsupported image")
                val orientation =
                    try {
                        resolver.openInputStream(uri)!!.use {
                            ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
                        }
                    } catch (_: Exception) {
                        1
                    }
                val matrix = Matrix()
                when (orientation) {
                    2 -> matrix.setScale(-1f, 1f)
                    3 -> matrix.setRotate(180f)
                    4 -> matrix.setScale(1f, -1f)
                    5 -> {
                        matrix.setRotate(90f)
                        matrix.postScale(-1f, 1f)
                    }
                    6 -> matrix.setRotate(90f)
                    7 -> {
                        matrix.setRotate(-90f)
                        matrix.postScale(-1f, 1f)
                    }
                    8 -> matrix.setRotate(-90f)
                }
                Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                    .also { if (it !== decoded) decoded.recycle() }
            }
        return try {
            encode(bitmap, "png", 100, 2048)
        } finally {
            bitmap.recycle()
        }
    }

    fun convert(bytes: ByteArray, format: String, quality: Int, edge: Int): ByteArray {
        require(
            format in listOf("png", "jpeg") &&
                quality in 60..100 &&
                edge in listOf(480, 720, 1080, 2048),
        )
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        require(bounds.outWidth in 1..2048 && bounds.outHeight in 1..2048)
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: error("Invalid image")
        return try {
            encode(bitmap, format, quality, edge)
        } finally {
            bitmap.recycle()
        }
    }

    private fun encode(bitmap: Bitmap, format: String, quality: Int, edge: Int): ByteArray {
        val ratio = min(1.0, edge.toDouble() / max(bitmap.width, bitmap.height))
        val width = max(1, (bitmap.width * ratio).roundToInt())
        val height = max(1, (bitmap.height * ratio).roundToInt())
        val target =
            if (Build.VERSION.SDK_INT >= 26)
                Bitmap.createBitmap(
                    width,
                    height,
                    Bitmap.Config.ARGB_8888,
                    format != "jpeg",
                    ColorSpace.get(ColorSpace.Named.SRGB),
                )
            else Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(target)
            if (format == "jpeg") canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(
                bitmap,
                null,
                Rect(0, 0, width, height),
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
            return ByteArrayOutputStream().use { out ->
                check(
                    target.compress(
                        if (format == "jpeg") Bitmap.CompressFormat.JPEG
                        else Bitmap.CompressFormat.PNG,
                        quality,
                        out,
                    ),
                )
                out.toByteArray()
            }
        } finally {
            target.recycle()
        }
    }
}
