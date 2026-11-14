package com.xrecorder.xrecorder.qa

import android.app.Activity
import android.app.Instrumentation
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.view.Surface
import com.xrecorder.xrecorder.recording.CaptureConfig
import com.xrecorder.xrecorder.recording.MediaOutput
import com.xrecorder.xrecorder.recording.RegionCaptureProcessor
import com.xrecorder.xrecorder.recording.VideoEncoder
import org.json.JSONObject
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Synthetic RGBA surface -> actual production crop -> actual recording encoder. */
object Task10RegionInstrumentation {
    @JvmStatic fun run(runner: Instrumentation, args: Bundle) {
        val result = Bundle()
        val report = JSONObject()
        var processor: RegionCaptureProcessor? = null
        var encoder: VideoEncoder? = null
        var output: MediaOutput? = null
        try {
            val case = requireNotNull(args.getString("task10"))
            val portrait = case == "region-portrait"
            val width = if (portrait) 480 else 640
            val height = if (portrait) 640 else 480
            val origin = when (case) {
                "region-red", "region-portrait" -> 24 to 40
                "region-green" -> 360 to 40
                "region-blue" -> 24 to 280
                "region-yellow" -> 360 to 280
                else -> error("Unknown region fixture")
            }
            val context = runner.targetContext
            val liveBefore = context.getSharedPreferences("capture_journal", 0).all.toMap()
            val root = File(context.filesDir, "task10_r4_${System.currentTimeMillis()}_${java.util.UUID.randomUUID()}")
            check(root.mkdir())
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint()
            canvas.drawColor(Color.RED)
            paint.color = Color.GREEN; canvas.drawRect(width / 2f, 0f, width.toFloat(), height / 2f, paint)
            paint.color = Color.BLUE; canvas.drawRect(0f, height / 2f, width / 2f, height.toFloat(), paint)
            paint.color = Color.YELLOW; canvas.drawRect(width / 2f, height / 2f, width.toFloat(), height.toFloat(), paint)
            paint.color = Color.WHITE
            for (x in 0 until width step 32) canvas.drawRect(x.toFloat(), 0f, x + 2f, height.toFloat(), paint)
            paint.color = Color.BLACK
            for (y in 0 until height step 32) canvas.drawRect(0f, y.toFloat(), width.toFloat(), y + 2f, paint)
            File(root, "source.png").outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            val config = CaptureConfig.from(context, mapOf(
                "cropX" to origin.first, "cropY" to origin.second, "cropWidth" to 200, "cropHeight" to 160,
                "fps" to 30, "audio" to "mute", "bitrate" to 2000000
            ))
            var pending: Uri? = null
            val destination = MediaOutput(context, "TASK10_R4_${case}_${System.currentTimeMillis()}.mp4", onPending = { pending = it })
            output = destination
            val descriptor = destination.open()
            val first = CountDownLatch(1)
            val ready = CountDownLatch(1)
            val surface = AtomicReference<Surface>()
            val failure = AtomicReference<String>()
            val video = VideoEncoder(descriptor, destination.legacyPath, config.encoderName, config.width, config.height,
                config.bitrate, config.fps, config.mime, { first.countDown() }, { failure.set("encoder") })
            encoder = video
            runner.runOnMainSync {
                processor = RegionCaptureProcessor(context, config, width, height, video.surface,
                    { surface.set(it); ready.countDown() }, { failure.set(it); ready.countDown() })
            }
            check(ready.await(8, TimeUnit.SECONDS) && surface.get() != null) { "Crop input not ready: ${failure.get()}" }
            repeat(5) {
                val input = surface.get().lockCanvas(null)
                check(input.width == width && input.height == height) { "Input buffer ${input.width}x${input.height} does not match registered ${width}x${height}" }
                input.drawBitmap(bitmap, 0f, 0f, null)
                surface.get().unlockCanvasAndPost(input)
                SystemClock.sleep(100)
            }
            bitmap.recycle()
            check(first.await(8, TimeUnit.SECONDS)) { "No encoded crop frame: ${failure.get()}" }
            processor!!.finish(); processor = null
            video.finish(); encoder = null
            check(failure.get() == null) { failure.get() }
            val uri = destination.commit()
            check(context.getSharedPreferences("capture_journal", 0).all == liveBefore)
            report.put("status", "PASS").put("case", case).put("uri", uri.toString())
                .put("source", File(root, "source.png").absolutePath).put("sourceWidth", width).put("sourceHeight", height)
                .put("cropX", origin.first).put("cropY", origin.second).put("width", config.width).put("height", config.height)
                .put("liveJournalUnchanged", true)
        } catch (error: Throwable) {
            android.util.Log.e("TASK10_R4", "Region pipeline fixture failed", error)
            runCatching { processor?.close() }
            runCatching { encoder?.abort() }
            output?.retain()
            report.put("status", "FAIL").put("error", error.toString())
        }
        result.putString("stream", "TASK10_REGION_RESULT:" + report)
        runner.finish(if (report.optString("status") == "PASS") Activity.RESULT_OK else Activity.RESULT_CANCELED, result)
    }
}
