package com.xrecorder.xrecorder.recording

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.ColorInfo
import androidx.media3.common.DebugViewProvider
import androidx.media3.common.Effect
import androidx.media3.common.Format
import androidx.media3.common.SurfaceInfo
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.VideoFrameProcessor
import androidx.media3.effect.Crop
import androidx.media3.effect.DefaultVideoFrameProcessor
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit

/** Reuses the editor's Media3 GPU crop engine before the existing recording encoder. */
class RegionCaptureProcessor(
    context: Context, config: CaptureConfig,
    val sourceWidth: Int, val sourceHeight: Int,
    output: Surface, onReady: (Surface) -> Unit, onFailure: (String) -> Unit
) : AutoCloseable {
    private val main = Handler(Looper.getMainLooper())
    private val ended = CountDownLatch(1)
    @Volatile private var closed = false
    @Volatile private var failure: Exception? = null
    private val processor: VideoFrameProcessor

    init {
        val rectangle = RegionCropGeometry.CropRect(
            requireNotNull(config.cropX), requireNotNull(config.cropY),
            requireNotNull(config.cropWidth), requireNotNull(config.cropHeight)
        )
        require(RegionCropGeometry.fitsDisplay(rectangle, sourceWidth, sourceHeight))
        val bounds = RegionCropGeometry.normalizedCrop(rectangle, sourceWidth, sourceHeight)
        processor = DefaultVideoFrameProcessor.Factory.Builder().build().create(
            context.applicationContext, DebugViewProvider.NONE, ColorInfo.SDR_BT709_LIMITED,
            true, Executor { it.run() }, object : VideoFrameProcessor.Listener {
                override fun onInputStreamRegistered(inputType: Int, format: Format, effects: List<Effect>) {
                    // Surface creation alone does not mean its input format/default
                    // buffer size is configured. Connect the producer only after registration.
                    main.post { if (!closed) onReady(processor.inputSurface) }
                }
                override fun onError(exception: VideoFrameProcessingException) {
                    failure = exception
                    ended.countDown()
                    main.post { if (!closed) onFailure("The selected region could not be processed. Choose another region and retry.") }
                }
                override fun onEnded() { ended.countDown() }
            }
        )
        try {
            processor.setOutputSurfaceInfo(SurfaceInfo(output, config.width, config.height, 0, true))
            processor.registerInputStream(
                VideoFrameProcessor.INPUT_TYPE_SURFACE_AUTOMATIC_FRAME_REGISTRATION,
                Format.Builder().setWidth(sourceWidth).setHeight(sourceHeight)
                    .setPixelWidthHeightRatio(1f).setColorInfo(ColorInfo.SDR_BT709_LIMITED).build(),
                listOf(Crop(2 * bounds.left - 1, 2 * bounds.right - 1,
                    1 - 2 * bounds.bottom, 1 - 2 * bounds.top)), 0
            )
        } catch (error: Exception) {
            processor.release()
            throw error
        }
    }

    /** Called by the finalizer worker after the projection producer has stopped. */
    fun finish() {
        try {
            processor.signalEndOfInput()
            check(ended.await(5, TimeUnit.SECONDS)) { "Region frames did not drain" }
            failure?.let { throw it }
        } finally { close() }
    }

    override fun close() {
        if (closed) return
        closed = true
        main.removeCallbacksAndMessages(null)
        processor.release()
    }
}
