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
    private val texture = TextureView(context)
    // Sensor tracking and VSYNC rendering are independent of locked Activity orientation.
    private val angleTracker = FacecamAngleTracker()
    private val choreographer = Choreographer.getInstance()
    private var framePending = false
    private var renderedFrame: FacecamRotationFrame? = null
    private var lastAppliedFrame: FacecamRotationFrame? = null
    private var renderedAngle: Float? = null
    private var displayDegrees = 0
    private val previewMatrix = Matrix()
    private val renderCallback = Choreographer.FrameCallback { frameNanos ->
        framePending = false
        if (!closed && currentSurfaceTexture != null) {
            val frame = renderedFrame
            if (frame != null) {
                val physical = angleTracker.advance(frameNanos) ?: displayDegrees.toDouble()
                // Retain unwrapped Double phase in the tracker; normalize only for the
                // equivalent final matrix so Float precision does not degrade over many turns.
                val angle = FacecamRotationFrame.targetAngle((physical % 360.0).toFloat(), displayDegrees, frame.mirrored)
                applyRotationFrame(frame, angle)
                if (angleTracker.needsFrame()) requestRender()
            }
        }
    }

    private fun requestRender() {
        if (closed || framePending || renderedFrame == null || currentSurfaceTexture == null) return
        framePending = true
        choreographer.postFrameCallback(renderCallback)
    }

    private fun stopRendering() {
        choreographer.removeFrameCallback(renderCallback)
        framePending = false
        renderedFrame = null
        lastAppliedFrame = null
    }

    private fun observeOrientation(orientation: Int) {
        if (!closed && angleTracker.observe(orientation)) requestRender()
    }

    private val orientationListener = object : OrientationEventListener(context) {
        override fun onOrientationChanged(orientation: Int) {
            if (Looper.myLooper() == main.looper) observeOrientation(orientation)
            else main.post { observeOrientation(orientation) }
        }
    }

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
    private var previewIsFront = true
    private var previewWidth = 640
    private var previewHeight = 480
    // Canonical Portrait size, independent of the current window dimensions/rotation.
    private val baseWidth = dp(FacecamGeometry.DEFAULT_WIDTH_DP)
    private val baseHeight = dp(FacecamGeometry.DEFAULT_HEIGHT_DP)
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

    private var layoutScreen = availableSize()
    private var layoutRotation: Int? = null
    private var layoutGeneration = 0
    private var positionX = FacecamGeometry.positionFraction(params.x, layoutScreen.first, params.width)
    private var positionY = FacecamGeometry.positionFraction(params.y, layoutScreen.second, params.height)

    private fun rememberPosition() {
        positionX = FacecamGeometry.positionFraction(params.x, layoutScreen.first, params.width)
        positionY = FacecamGeometry.positionFraction(params.y, layoutScreen.second, params.height)
    }

    private fun updateGeometry(degrees: Int) {
        val screen = availableSize()
        val (width, height) = FacecamGeometry.targetDimensions(baseWidth, baseHeight, currentScale, degrees)
        val rotated = layoutRotation != null && (layoutRotation != degrees || layoutScreen != screen)
        val x = if (rotated) FacecamGeometry.positionFromFraction(positionX, screen.first, width) else params.x
        val y = if (rotated) FacecamGeometry.positionFromFraction(positionY, screen.second, height) else params.y
        val (clampedX, clampedY) = FacecamGeometry.clampPosition(x, y, screen.first, screen.second, width, height)
        val resized = params.width != width || params.height != height
        val initial = layoutRotation == null
        val changed = resized || params.x != clampedX || params.y != clampedY
        if (rotated) layoutGeneration++ // Ignore stale drag deltas from the previous coordinate system.
        params.width = width
        params.height = height
        params.x = clampedX
        params.y = clampedY
        layoutScreen = screen
        layoutRotation = degrees
        // Keep unrounded normalized coordinates across duplicate callbacks and rotation cycles.
        if (!rotated && (initial || resized)) rememberPosition()
        if (changed && texture.isAttachedToWindow) {
            try { windows.updateViewLayout(texture, params) } catch (_: Exception) { }
        }
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
                lastAppliedFrame = null
                transform()
                openSelectedCamera()
            }
            override fun onSurfaceTextureSizeChanged(value: SurfaceTexture, width: Int, height: Int) {
                transform()
            }
            override fun onSurfaceTextureDestroyed(value: SurfaceTexture): Boolean {
                currentSurfaceTexture = null
                stopRendering()
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
            updateGeometry(getDisplayRotationDegrees())
            displayManager?.registerDisplayListener(displayListener, main)
            windows.addView(texture, params)
            if (orientationListener.canDetectOrientation()) orientationListener.enable()
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
        sensorOrientation = info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        previewIsFront = info.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
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
        if (closed) return false
        val validated = FacecamGeometry.validateEffect(effect)
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
        if (closed) return
        val degrees = getDisplayRotationDegrees()
        // Only actual Display/resize changes affect WindowManager bounds. Sensor samples
        // bypass this method entirely and update only the render-layer matrix at VSYNC.
        updateGeometry(degrees)
        if (texture.width != params.width || texture.height != params.height) {
            stopRendering()
            return
        }
        val sensorSwaps = sensorOrientation % 180 == 90
        renderedFrame = FacecamRotationFrame(texture.width, texture.height,
            if (sensorSwaps) previewHeight else previewWidth,
            if (sensorSwaps) previewWidth else previewHeight, previewIsFront)
        displayDegrees = degrees
        requestRender()
    }

    private fun applyRotationFrame(frame: FacecamRotationFrame, angle: Float) {
        if (closed || !texture.isAttachedToWindow) return
        val previous = renderedAngle
        if (lastAppliedFrame == frame && previous != null && abs(previous - angle) < .001f) return
        val scale = frame.scaleAt(angle)
        previewMatrix.reset()
        previewMatrix.postTranslate(-frame.width / 2f, -frame.height / 2f)
        previewMatrix.postScale(scale.x, scale.y)
        previewMatrix.postRotate(angle)
        previewMatrix.postTranslate(frame.width / 2f, frame.height / 2f)
        texture.setTransform(previewMatrix)
        renderedAngle = angle
        lastAppliedFrame = frame
    }

    fun reposition(snap: Boolean = false) {
        if (closed) return
        val (screenWidth, screenHeight) = availableSize()
        val (clampedX, clampedY) = FacecamGeometry.clampPosition(
            params.x, params.y, screenWidth, screenHeight, params.width, params.height
        )
        val finalX = if (snap) FacecamGeometry.snapToEdge(clampedX, screenWidth, params.width) else clampedX
        if (finalX != params.x || clampedY != params.y) {
            params.x = finalX
            params.y = clampedY
            try { windows.updateViewLayout(texture, params) } catch (_: Exception) { }
        }
        rememberPosition()
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
        var dragGeneration = 0
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragGeneration = layoutGeneration
                    downX = event.rawX; downY = event.rawY; startX = params.x; startY = params.y; moved = false; true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (dragGeneration != layoutGeneration) return@setOnTouchListener true
                    val dx = event.rawX - downX; val dy = event.rawY - downY
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        val (width, height) = availableSize()
                        val (tx, ty) = FacecamGeometry.clampPosition(
                            startX + dx.toInt(), startY + dy.toInt(), width, height, params.width, params.height
                        )
                        if (tx != params.x || ty != params.y) {
                            params.x = tx; params.y = ty
                            rememberPosition()
                            try { windows.updateViewLayout(texture, params) } catch (_: Exception) { }
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (moved && dragGeneration == layoutGeneration) {
                        reposition(snap = true)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (moved && dragGeneration == layoutGeneration) reposition(snap = true)
                    true
                }
                else -> false
            }
        }
    }

    fun close() {
        closed = true
        orientationListener.disable()
        stopRendering()
        try { displayManager?.unregisterDisplayListener(displayListener) } catch (_: Exception) { }
        try { windows.removeView(texture) } catch (_: Exception) { }
        cameraHandler.post {
            try { session?.close(); device?.close(); surface?.release() } catch (_: Exception) { }
            worker.quitSafely()
        }
    }
}
