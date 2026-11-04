package com.xrecorder.xrecorder.recording

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.os.*
import android.view.*

/** Visible front-camera window included by full-display MediaProjection. */
class FacecamOverlay(private val context: Context, private val failed: () -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = HandlerThread("facecam").apply { start() }
    private val cameraHandler = Handler(worker.looper)
    private val windows = context.getSystemService(WindowManager::class.java)
    private val cameras = context.getSystemService(CameraManager::class.java)
    private val texture = TextureView(context)
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var surface: Surface? = null
    @Volatile private var closed = false
    @Volatile var ready = false
        private set
    private var sensorOrientation = 0
    private fun failure() { if (!closed) main.post { if (!closed) failed() } }
    fun show() {
        val cameraId = cameras.cameraIdList.firstOrNull {
            cameras.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
        } ?: throw IllegalStateException("No front camera")
        val info = cameras.getCameraCharacteristics(cameraId)
        sensorOrientation = info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        val sizes = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!.getOutputSizes(SurfaceTexture::class.java)
        val size = sizes.filter { it.width <= 1280 && it.height <= 720 }.minByOrNull { kotlin.math.abs(it.width*it.height-640*480) } ?: sizes.minBy { it.width*it.height }
        texture.surfaceTextureListener = object: TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(value: SurfaceTexture, width: Int, height: Int) {
                value.setDefaultBufferSize(size.width,size.height); transform()
                try {
                    cameras.openCamera(cameraId,object: CameraDevice.StateCallback() {
                        override fun onOpened(camera: CameraDevice) {
                            if (closed) { camera.close(); return }
                            device = camera; val target = Surface(value); surface = target
                            try {
                                @Suppress("DEPRECATION")
                                camera.createCaptureSession(listOf(target),object: CameraCaptureSession.StateCallback() {
                                    override fun onConfigured(configured: CameraCaptureSession) {
                                        if(closed) { configured.close(); return }; session = configured
                                        try {
                                            val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                                                addTarget(target); set(CaptureRequest.CONTROL_MODE,CaptureRequest.CONTROL_MODE_AUTO)
                                            }.build()
                                            configured.setRepeatingRequest(request,null,cameraHandler)
                                        } catch (_: Exception) { failure() }
                                    }
                                    override fun onConfigureFailed(value: CameraCaptureSession) { value.close(); failure() }
                                },cameraHandler)
                            } catch (_: Exception) { failure() }
                        }
                        override fun onDisconnected(camera: CameraDevice) { camera.close(); failure() }
                        override fun onError(camera: CameraDevice,error: Int) { camera.close(); failure() }
                    },cameraHandler)
                } catch (_: Exception) { failure() }
            }
            override fun onSurfaceTextureSizeChanged(value: SurfaceTexture,width: Int,height: Int) { transform() }
            override fun onSurfaceTextureDestroyed(value: SurfaceTexture) = true
            override fun onSurfaceTextureUpdated(value: SurfaceTexture) { ready = true }
        }
        val density=context.resources.displayMetrics.density
        @Suppress("DEPRECATION")
        val type=if(Build.VERSION.SDK_INT>=26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
        windows.addView(texture,WindowManager.LayoutParams((110*density).toInt(),(147*density).toInt(),type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,android.graphics.PixelFormat.TRANSLUCENT).apply {
            gravity=Gravity.TOP or Gravity.END; x=(12*density).toInt(); y=(100*density).toInt()
        })
    }
    fun transform() {
        if(texture.width==0 || texture.height==0) return
        @Suppress("DEPRECATION") val degrees=windows.defaultDisplay.rotation*90
        val rotation=(sensorOrientation+degrees)%360
        val w=texture.width.toFloat(); val h=texture.height.toFloat()
        texture.setTransform(Matrix().apply {
            postRotate(rotation.toFloat(),w/2,h/2)
            if(rotation==90 || rotation==270) postScale(w/h,h/w,w/2,h/2)
            postScale(-1f,1f,w/2,h/2)
        })
    }
    fun close() {
        closed=true
        try { windows.removeView(texture) } catch (_: Exception) { }
        cameraHandler.post {
            try { session?.close(); device?.close(); surface?.release() } catch (_: Exception) { }
            worker.quitSafely()
        }
    }
}
