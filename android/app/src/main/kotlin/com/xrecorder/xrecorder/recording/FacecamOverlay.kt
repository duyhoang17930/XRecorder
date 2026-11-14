package com.xrecorder.xrecorder.recording

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Matrix
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.display.DisplayManager
import android.os.*
import android.view.*
import kotlin.math.abs

/** Visible front/back camera window included by full-display MediaProjection (F17/F18). */
class FacecamOverlay(private val context: Context, private val failed: () -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = HandlerThread("facecam").apply { start() }
    private val cameraHandler = Handler(worker.looper)
    private val windows = context.getSystemService(WindowManager::class.java)
    private val cameras = context.getSystemService(CameraManager::class.java)
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
    private val texture = TextureView(context).apply { contentDescription = "Facecam preview. Drag to move camera" }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) {
                main.post { transform() }
            }
        }
    }

    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var surface: Surface? = null
    private var currentSurfaceTexture: SurfaceTexture? = null

    @Volatile private var closed = false
    @Volatile var ready = false
        private set

    var currentLensFacing = FacecamGeometry.LENS_FACING_FRONT
        private set
    var currentEffect = FacecamGeometry.EFFECT_OFF
        private set
    var currentScale = FacecamGeometry.DEFAULT_SCALE
        private set

    private var sensorOrientation = 0
    private var previewWidth = 640
    private var previewHeight = 480
    @Volatile private var supportedEffects = setOf(FacecamGeometry.EFFECT_OFF)
    private var baseWidth = dp(FacecamGeometry.DEFAULT_WIDTH_DP)
    private var baseHeight = dp(FacecamGeometry.DEFAULT_HEIGHT_DP)
    private var cornerRadius = dp(FacecamGeometry.DEFAULT_CORNER_RADIUS_DP).toFloat()

    @Suppress("DEPRECATION")
    private val params = WindowManager.LayoutParams(
        baseWidth,
        baseHeight,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
        // Allow user dragging on facecam view while passing outside touches to underlying apps
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        val (w, _) = availableSize()
        x = (w - baseWidth - dp(12)).coerceAtLeast(0)
        y = dp(100)
        title = "3HRecorder Facecam Overlay"
    }

    private fun failure() { if (!closed) main.post { if (!closed) failed() } }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density + .5f).toInt()

    fun show() {
        // Start with alpha 0f so black rectangle never flashes before first camera frame arrives
        texture.alpha = 0f
        texture.clipToOutline = true
        texture.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, cornerRadius)
            }
        }

        setupDrag(texture)

        texture.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(value: SurfaceTexture, width: Int, height: Int) {
                currentSurfaceTexture = value
                openSelectedCamera()
            }
            override fun onSurfaceTextureSizeChanged(value: SurfaceTexture, width: Int, height: Int) {
                transform()
            }
            override fun onSurfaceTextureDestroyed(value: SurfaceTexture): Boolean {
                currentSurfaceTexture = null
                return true
            }
            override fun onSurfaceTextureUpdated(value: SurfaceTexture) {
                if (!ready) {
                    ready = true
                    // First valid camera frame rendered: reveal facecam smoothly
                    main.post {
                        if (!closed) texture.alpha = 1f
                    }
                }
            }
        }

        try {
            displayManager?.registerDisplayListener(displayListener, main)
            windows.addView(texture, params)
        } catch (_: Exception) {
            failure()
        }
    }

    private fun openSelectedCamera() {
        val targetFacing = if (currentLensFacing == FacecamGeometry.LENS_FACING_FRONT) {
            CameraCharacteristics.LENS_FACING_FRONT
        } else {
            CameraCharacteristics.LENS_FACING_BACK
        }

        val cameraId = cameras.cameraIdList.firstOrNull {
            cameras.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == targetFacing
        } ?: cameras.cameraIdList.firstOrNull() ?: run {
            failure()
            return
        }

        val info = cameras.getCameraCharacteristics(cameraId)
        supportedEffects = (info.get(CameraCharacteristics.CONTROL_AVAILABLE_EFFECTS) ?: intArrayOf(0)).toSet()
        if (currentEffect !in supportedEffects) currentEffect = FacecamGeometry.EFFECT_OFF
        sensorOrientation = info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        val map = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val sizes = map?.getOutputSizes(SurfaceTexture::class.java) ?: emptyArray()
        val size = sizes.filter { it.width <= 1280 && it.height <= 720 }
            .minByOrNull { abs(it.width * it.height - 640 * 480) } ?: sizes.minByOrNull { it.width * it.height }

        val st = currentSurfaceTexture ?: return
        if (size != null) {
            previewWidth = size.width
            previewHeight = size.height
            st.setDefaultBufferSize(size.width, size.height)
        }
        main.post { transform() }

        try {
            cameras.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (closed) { camera.close(); return }
                    device = camera
                    val target = Surface(st)
                    surface = target
                    try {
                        @Suppress("DEPRECATION")
                        camera.createCaptureSession(listOf(target), object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(configured: CameraCaptureSession) {
                                if (closed) { configured.close(); return }
                                session = configured
                                applyRepeatingRequest()
                            }
                            override fun onConfigureFailed(value: CameraCaptureSession) {
                                value.close()
                                failure()
                            }
                        }, cameraHandler)
                    } catch (_: Exception) { failure() }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    failure()
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    failure()
                }
            }, cameraHandler)
        } catch (_: Exception) { failure() }
    }

    private fun applyRepeatingRequest() {
        val cam = device ?: return
        val sess = session ?: return
        val surf = surface ?: return
        try {
            val request = cam.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(surf)
                set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                if (currentEffect != FacecamGeometry.EFFECT_OFF) {
                    set(CaptureRequest.CONTROL_EFFECT_MODE, currentEffect)
                }
            }.build()
            sess.setRepeatingRequest(request, null, cameraHandler)
        } catch (_: Exception) { failure() }
    }

    fun switchCamera(): Boolean {
        if (closed) return false
        val newFacing = FacecamGeometry.toggleFacing(currentLensFacing)
        val hasOpposite = cameras.cameraIdList.any {
            val facing = if (newFacing == FacecamGeometry.LENS_FACING_FRONT) {
                CameraCharacteristics.LENS_FACING_FRONT
            } else {
                CameraCharacteristics.LENS_FACING_BACK
            }
            cameras.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == facing
        }
        if (!hasOpposite) return false

        currentLensFacing = newFacing
        ready = false
        cameraHandler.post {
            try {
                session?.close()
                device?.close()
                surface?.release()
            } catch (_: Exception) { }
            session = null
            device = null
            surface = null
            openSelectedCamera()
        }
        return true
    }

    fun setEffect(effect: Int): Boolean {
        if (closed || !ready) return false
        val validated = FacecamGeometry.validateEffect(effect)
        if (validated != effect || effect !in supportedEffects) return false
        currentEffect = validated
        cameraHandler.post {
            applyRepeatingRequest()
        }
        return true
    }

    fun setScale(scale: Float) {
        if (closed) return
        val clamped = FacecamGeometry.clampScale(scale)
        currentScale = clamped
        val (w, h) = FacecamGeometry.scaledDimensions(baseWidth, baseHeight, clamped)
        params.width = w
        params.height = h
        reposition(force = true)
        main.post { transform() }
    }

    private fun getDisplayRotationDegrees(): Int {
        val display = displayManager?.getDisplay(Display.DEFAULT_DISPLAY)
        val rotation = display?.rotation ?: try {
            @Suppress("DEPRECATION") windows.defaultDisplay.rotation
        } catch (_: Exception) {
            Surface.ROTATION_0
        }
        return when (rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
    }

    fun onConfigurationChanged() {
        main.post { transform() }
    }

    fun transform() {
        if (texture.width == 0 || texture.height == 0) return
        reposition()
        val degrees = getDisplayRotationDegrees()
        val isFront = currentLensFacing == FacecamGeometry.LENS_FACING_FRONT
        val res = FacecamGeometry.calculateTransform(
            sensorOrientation = sensorOrientation,
            displayRotationDegrees = degrees,
            viewWidth = texture.width.toFloat(),
            viewHeight = texture.height.toFloat(),
            previewWidth = previewWidth,
            previewHeight = previewHeight,
            isFrontCamera = isFront
        )
        val w = texture.width.toFloat()
        val h = texture.height.toFloat()
        val matrix = Matrix()
        if (res.rotation != 0) {
            matrix.postRotate(res.rotation.toFloat(), w / 2f, h / 2f)
        }
        if (res.scaleX != 1.0f || res.scaleY != 1.0f) {
            matrix.postScale(res.scaleX, res.scaleY, w / 2f, h / 2f)
        }
        texture.setTransform(matrix)
    }

    @JvmOverloads fun reposition(snap: Boolean = false, force: Boolean = false) {
        if (closed) return
        val (screenWidth, screenHeight) = availableSize()
        val (clampedX, clampedY) = FacecamGeometry.clampPosition(
            params.x, params.y, screenWidth, screenHeight, params.width, params.height
        )
        val finalX = if (snap) FacecamGeometry.snapToEdge(clampedX, screenWidth, params.width) else clampedX
        if (force || finalX != params.x || clampedY != params.y) {
            params.x = finalX
            params.y = clampedY
            try { windows.updateViewLayout(texture, params) } catch (_: Exception) { }
        }
    }

    private fun availableSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
            )
            return (metrics.bounds.width() - insets.left - insets.right) to
                (metrics.bounds.height() - insets.top - insets.bottom)
        }
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION") windows.defaultDisplay.getMetrics(metrics)
        return metrics.widthPixels to metrics.heightPixels
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupDrag(view: View) {
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY; startX = params.x; startY = params.y; moved = false; true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX; val dy = event.rawY - downY
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        val (width, height) = availableSize()
                        val (tx, ty) = FacecamGeometry.clampPosition(
                            startX + dx.toInt(), startY + dy.toInt(), width, height, params.width, params.height
                        )
                        if (tx != params.x || ty != params.y) {
                            params.x = tx; params.y = ty
                            try { windows.updateViewLayout(texture, params) } catch (_: Exception) { }
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (moved) {
                        reposition(snap = true)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (moved) reposition(snap = true)
                    true
                }
                else -> false
            }
        }
    }

    fun close() {
        closed = true
        try { displayManager?.unregisterDisplayListener(displayListener) } catch (_: Exception) { }
        try { windows.removeView(texture) } catch (_: Exception) { }
        cameraHandler.post {
            try { session?.close(); device?.close(); surface?.release() } catch (_: Exception) { }
            worker.quitSafely()
        }
    }
}
