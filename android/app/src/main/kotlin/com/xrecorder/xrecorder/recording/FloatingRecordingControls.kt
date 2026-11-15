package com.xrecorder.xrecorder.recording

import android.annotation.SuppressLint
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.PopupMenu
import com.xrecorder.xrecorder.R
import kotlin.math.abs

/** One service-owned window. No Activity reference, recorder, or private timer. */
internal class FloatingRecordingControls(
    private val context: Context,
    private val togglePause: () -> Unit,
    private val stop: () -> Unit,
    initialScale: Float? = null,
    initialOpacity: Float? = null,
    initialRatioX: Float? = null,
    initialRatioY: Float? = null,
    private val setDrawing: (Boolean) -> Boolean = { false },
    private val drawingState: () -> DrawingStrokeEngine.State? = { null },
    private val undoDrawing: () -> Unit = {},
    private val clearDrawing: () -> Unit = {},
    private val setDrawingStyle: (Int?, Float?) -> Unit = { _, _ -> },
    private val cameraOptions: ((View) -> Unit)? = null,
) {
    companion object {
        private const val PREFS_NAME = "3hrecorder_floating_ball"
        private const val KEY_RATIO_X = "pref_floating_ball_x_ratio"
        private const val KEY_RATIO_Y = "pref_floating_ball_y_ratio"
        private const val KEY_SCALE = "pref_floating_ball_scale"
        private const val KEY_OPACITY = "pref_floating_ball_opacity"
    }

    private val windows = context.getSystemService(WindowManager::class.java)
    private val accent = Color.rgb(255, 120, 71)

    private var userScale: Float = FloatingControlGeometry.DEFAULT_SCALE
    private var userOpacity: Float = FloatingControlGeometry.DEFAULT_OPACITY
    private var currentRatioX: Float = -1f
    private var currentRatioY: Float = -1f
    private var lastPauseCommandMs = 0L
    private var lastStopCommandMs = 0L
    private var lastAnnouncedState: String? = null
    private var displayedCollapsed: Boolean? = null

    private val root = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
    }
    @Suppress("DEPRECATION")
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
        // These flags govern input only. The opt-in controls may appear in MP4.
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.LEFT; x = dp(8); y = dp(140); title = "3HRecorder floating controls" }

    private val timer = TextView(context).apply {
        setTextColor(Color.WHITE); textSize = 14f; typeface = Typeface.MONOSPACE
        setSingleLine(true)
        gravity = Gravity.CENTER
        setPadding(dp(2), 0, dp(2), 0)
    }
    private val statusDot = View(context).apply {
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.rgb(255, 85, 85))
        }
    }
    private val statusLabel = TextView(context).apply {
        setTextColor(Color.WHITE); textSize = 11f; typeface = Typeface.DEFAULT_BOLD
        setSingleLine(true); gravity = Gravity.CENTER_VERTICAL
    }
    private val statusGroup = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        addView(statusDot, LinearLayout.LayoutParams(dp(7), dp(7)))
        addView(statusLabel, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            marginStart = dp(5)
        })
    }
    private val bubble = ImageButton(context).apply {
        setBackground(GradientDrawable().apply {
            setColor(Color.rgb(24, 24, 28)); cornerRadius = dp(24).toFloat()
            setStroke(dp(1), accent)
        })
        setImageResource(R.drawable.ic_lucide_circle_dot)
        setColorFilter(accent)
        setOnClickListener { collapsed = false; render(state, elapsed) }
    }
    private val pause = button("Pause recording", R.drawable.ic_lucide_pause) { dispatchControlCommand(true, togglePause) }
    private val stopButton = button("Stop recording", R.drawable.ic_lucide_square) { dispatchControlCommand(false, stop) }
    private val collapseButton = button("Tap to collapse floating controls", R.drawable.ic_lucide_chevron_down) {
        collapsed = true
        render(state, elapsed)
    }
    private val drawButton = button("Draw on screen", R.drawable.ic_lucide_pencil) {
        setDrawing(drawingState()?.isDrawingMode != true)
        render(state, elapsed)
    }
    private val undoButton = button("Undo drawing", R.drawable.ic_lucide_undo_2) {
        undoDrawing(); render(state, elapsed)
    }
    private val clearButton = button("Clear drawing", R.drawable.ic_lucide_trash_2) {
        clearDrawing(); render(state, elapsed)
    }
    private val styleButton = button("Drawing color and width", R.drawable.ic_lucide_palette) {
        val menu = PopupMenu(context, styleButtonAnchor())
        val colors = listOf("Orange" to DrawingStrokeEngine.DEFAULT_COLOR, "Red" to Color.RED,
            "White" to Color.WHITE, "Blue" to Color.BLUE)
        colors.forEachIndexed { index, (label, _) -> menu.menu.add(0, index, index, CaptureText.text(context, label)) }
        val widths = listOf(4f, 8f, 16f, 32f)
        widths.forEachIndexed { index, width -> menu.menu.add(1, 10 + index, 10 + index, "${width.toInt()} px") }
        menu.setOnMenuItemClickListener { item ->
            if (item.groupId == 0) setDrawingStyle(colors[item.itemId].second, null)
            else setDrawingStyle(null, widths[item.itemId - 10])
            true
        }
        menu.show()
    }
    private fun styleButtonAnchor(): View = styleButton
    private val cameraButton = button("Facecam options", R.drawable.ic_lucide_camera) {
        cameraOptions?.invoke(cameraButtonAnchor())
    }
    private fun cameraButtonAnchor(): View = cameraButton
    private val drawingPanel = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        addView(drawButton)
        addView(undoButton)
        addView(clearButton)
        addView(styleButton)
        if (cameraOptions != null) addView(cameraButton)
    }
    private val recordingPanel = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        addView(statusGroup, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, bubbleSizeForStatus()))
        addView(timer)
        addView(pause)
        addView(stopButton)
        addView(collapseButton)
    }
    private val panel = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        addView(recordingPanel, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        addView(drawingPanel, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
    }
    private var attached = false
    private var closed = false
    private var collapsed = false
    private var state = "recording"
    private var elapsed = 0L

    init {
        val saved = loadPersistedPreferences()
        userScale = if (initialScale != null && initialScale > 0f) FloatingControlGeometry.clampScale(initialScale) else saved.scale
        userOpacity = if (initialOpacity != null && initialOpacity > 0f) FloatingControlGeometry.clampOpacity(initialOpacity) else saved.opacity
        currentRatioX = if (initialRatioX != null && initialRatioX in 0f..1f) initialRatioX else saved.ratioX
        currentRatioY = if (initialRatioY != null && initialRatioY in 0f..1f) initialRatioY else saved.ratioY

        val bounds = availableBounds()
        params.x = bounds.left + dp(8)
        params.y = bounds.top + dp(140)
        applyCustomizationLayout()

        root.addView(panel)
        root.addView(bubble)
        drag(timer); drag(statusLabel); drag(bubble)
        root.setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_OUTSIDE && !collapsed) {
                collapsed = true
                render(state, elapsed)
                true
            } else false
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            view.post { reposition() }
            insets
        }
        root.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> reposition() }
    }

    private fun loadPersistedPreferences(): FloatingControlGeometry.Customization {
        return runCatching {
            val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rx = if (sp.contains(KEY_RATIO_X)) sp.getFloat(KEY_RATIO_X, -1f) else -1f
            val ry = if (sp.contains(KEY_RATIO_Y)) sp.getFloat(KEY_RATIO_Y, -1f) else -1f
            val sc = if (sp.contains(KEY_SCALE)) sp.getFloat(KEY_SCALE, FloatingControlGeometry.DEFAULT_SCALE) else FloatingControlGeometry.DEFAULT_SCALE
            val op = if (sp.contains(KEY_OPACITY)) sp.getFloat(KEY_OPACITY, FloatingControlGeometry.DEFAULT_OPACITY) else FloatingControlGeometry.DEFAULT_OPACITY
            FloatingControlGeometry.parseCustomization(rx, ry, sc, op)
        }.getOrDefault(FloatingControlGeometry.Customization())
    }

    private fun persistPreferences(ratioX: Float, ratioY: Float, scale: Float, opacity: Float) {
        runCatching {
            val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            sp.edit()
                .putFloat(KEY_RATIO_X, ratioX)
                .putFloat(KEY_RATIO_Y, ratioY)
                .putFloat(KEY_SCALE, FloatingControlGeometry.clampScale(scale))
                .putFloat(KEY_OPACITY, FloatingControlGeometry.clampOpacity(opacity))
                .apply()
        }
    }

    private fun applyCustomizationLayout() {
        val bubbleSize = maxOf(dp(48), scaledDp(48))
        val corner = scaledDp(20).toFloat()

        root.background = GradientDrawable().apply {
            setColor(Color.rgb(24, 24, 28))
            cornerRadius = corner
            setStroke(dp(1), Color.argb(72, 255, 255, 255))
        }
        panel.setPadding(dp(4), dp(2), dp(4), dp(2))

        bubble.layoutParams = LinearLayout.LayoutParams(bubbleSize, bubbleSize)
        timer.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, bubbleSize).apply {
            marginStart = dp(6)
        }
        timer.minHeight = bubbleSize
        timer.minWidth = dp(56)
        statusGroup.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, bubbleSize)
        statusDot.layoutParams = LinearLayout.LayoutParams(dp(7), dp(7))

        val availableWidth = availableSize().first
        val fontScale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        // The fixed status/timer area must still fit beside Pause, Stop, and
        // Collapse at 200% text. The drawing row separately has five buttons.
        val fixedRowWidth = dp(8 + (84f * fontScale).toInt())
        val recordingRowScale =
            (availableWidth - fixedRowWidth).toFloat() / (dp(48) * 3)
        val drawingRowScale =
            (availableWidth - dp(8)).toFloat() / (dp(48) * 5)
        val controlScale = minOf(userScale, recordingRowScale, drawingRowScale)
        val buttonSize = maxOf(
            dp(48),
            FloatingControlGeometry.scaledDimension(dp(48), controlScale),
        )
        pause.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        stopButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        collapseButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        drawButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        undoButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        clearButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        styleButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        cameraButton.layoutParams = LinearLayout.LayoutParams(buttonSize, buttonSize)
        stopButton.background = GradientDrawable().apply {
            setColor(accent)
            cornerRadius = scaledDp(14).toFloat()
        }
        stopButton.setColorFilter(Color.WHITE)

        if (currentRatioX in 0f..1f && currentRatioY in 0f..1f) {
            val bounds = availableBounds()
            params.x = FloatingControlGeometry.fromNormalizedInArea(currentRatioX, bounds.left, bounds.width, bubbleSize)
            params.y = FloatingControlGeometry.fromNormalizedInArea(currentRatioY, bounds.top, bounds.height, bubbleSize)
        }
    }

    fun applyCustomization(scale: Float? = null, opacity: Float? = null) {
        if (closed) return
        var layoutChanged = false
        if (scale != null) {
            val clampedScale = FloatingControlGeometry.clampScale(scale)
            if (clampedScale != userScale) {
                userScale = clampedScale
                layoutChanged = true
            }
        }
        if (opacity != null) {
            userOpacity = FloatingControlGeometry.clampOpacity(opacity)
        }
        if (layoutChanged) {
            applyCustomizationLayout()
        }
        persistPreferences(currentRatioX, currentRatioY, userScale, userOpacity)
        render(state, elapsed)
        reposition(force = true)
    }

    fun render(value: String, elapsedMs: Long) {
        if (closed) return
        if (!Settings.canDrawOverlays(context)) { close(); return }
        state = value; elapsed = elapsedMs
        val overlayState = FloatingControlGeometry.resolveOverlayState(
            state = value,
            elapsedMs = elapsedMs,
            canDrawOverlays = true,
            acceptedInVideo = true,
            isScreenshot = false,
            userOpacity = userOpacity
        )
        if (!overlayState.shouldShow && value in listOf("completed", "failed", "idle")) {
            close()
            return
        }
        val active = overlayState.isInteractive
        val paused = overlayState.isPaused
        val timerText = if (active) compactTime(elapsedMs) else ""
        if (timer.text.toString() != timerText) timer.text = timerText
        val accessibleStatus = when {
            paused -> "Paused"
            active -> "Recording"
            value in listOf("stopping", "finalizing") -> "Saving"
            else -> null
        }
        if (accessibleStatus != lastAnnouncedState) {
            lastAnnouncedState = accessibleStatus
            if (attached && accessibleStatus != null) {
                timer.announceForAccessibility(CaptureText.text(context, accessibleStatus))
            }
        }
        val statusLabel = accessibleStatus?.let { CaptureText.text(context, it) }.orEmpty()
        // The colored status dot carries the visual state; keep the elapsed
        // time as the only visible text in this compact row. The timer's
        // content description below retains the full state for screen readers.
        this.statusLabel.visibility = View.GONE
        val statusColor = if (paused) Color.LTGRAY else accent
        (statusDot.background as? GradientDrawable)?.setColor(statusColor)
        this.statusLabel.setTextColor(if (paused) Color.LTGRAY else Color.WHITE)
        val collapseHint = CaptureText.text(context, "Tap to collapse floating controls")
        val moveHint = CaptureText.text(context, "Drag floating controls to move")
        val timerDescription = "$statusLabel ${FloatingControlGeometry.time(elapsedMs)}. $collapseHint. $moveHint"
        timer.contentDescription = timerDescription
        pause.setImageResource(if (paused) R.drawable.ic_lucide_play else R.drawable.ic_lucide_pause)
        pause.contentDescription = CaptureText.text(context, if (paused) "Resume recording" else "Pause recording")
        pause.isEnabled = active; stopButton.isEnabled = active
        collapseButton.contentDescription = collapseHint
        collapseButton.isEnabled = true
        val drawing = drawingState()
        val drawingEnabled = drawing?.isDrawingMode == true
        drawButton.contentDescription = CaptureText.text(context, if (drawingEnabled) "Exit drawing" else "Draw on screen")
        drawButton.setImageResource(R.drawable.ic_lucide_pencil)
        drawButton.setColorFilter(if (drawingEnabled) Color.WHITE else accent)
        drawButton.background = if (drawingEnabled) GradientDrawable().apply {
            setColor(accent)
            cornerRadius = dp(14).toFloat()
        } else android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
        drawButton.isEnabled = active
        drawingPanel.visibility = if (active) View.VISIBLE else View.GONE
        undoButton.isEnabled = active && drawing?.canUndo == true
        clearButton.isEnabled = active && (drawing?.strokeCount ?: 0) > 0
        undoButton.alpha = if (undoButton.isEnabled) 1f else .45f
        clearButton.alpha = if (clearButton.isEnabled) 1f else .45f
        clearButton.background = if (clearButton.isEnabled) GradientDrawable().apply {
            setColor(Color.argb(38, 255, 120, 71))
            cornerRadius = dp(14).toFloat()
        } else android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
        styleButton.isEnabled = active
        cameraButton.isEnabled = active
        root.alpha = overlayState.alpha
        pause.alpha = overlayState.alpha; stopButton.alpha = overlayState.alpha
        collapseButton.alpha = overlayState.alpha
        updateCollapsedVisibility()
        bubble.setImageResource(when {
            !active || !paused -> R.drawable.ic_lucide_circle_dot
            else -> R.drawable.ic_lucide_pause
        })
        bubble.contentDescription = "${CaptureText.text(context, "Expand floating controls")}. $statusLabel ${FloatingControlGeometry.time(elapsedMs)}"
        if (!attached) {
            try { windows.addView(root, params); attached = true; root.requestApplyInsets() }
            catch (_: RuntimeException) { windowFailure = true; close() } // Notification controls remain available.
        }
    }

    var windowFailure: Boolean = false
        private set
    val isClosed: Boolean get() = closed

    private fun dispatchControlCommand(isPause: Boolean, action: () -> Unit) {
        val now = SystemClock.elapsedRealtime()
        val lastCommandMs = if (isPause) lastPauseCommandMs else lastStopCommandMs
        if (now - lastCommandMs < 350L) return
        if (isPause) lastPauseCommandMs = now else lastStopCommandMs = now
        action()
    }

    fun reposition(snap: Boolean = false, force: Boolean = false) {
        if (!attached || closed) return
        val bounds = availableBounds()
        val (x, y) = if (currentRatioX in 0f..1f && currentRatioY in 0f..1f && !snap) {
            FloatingControlGeometry.repositionAfterRotation(
                currentRatioX, currentRatioY, bounds.width, bounds.height, root.width, root.height, snapToEdge = false
            ).let { (x, y) -> x + bounds.left to y + bounds.top }
        } else {
            val targetX = if (snap) FloatingControlGeometry.snapInArea(params.x, bounds.left, bounds.width, root.width)
                else FloatingControlGeometry.clampInArea(params.x, bounds.left, bounds.width, root.width)
            val targetY = FloatingControlGeometry.clampInArea(params.y, bounds.top, bounds.height, root.height)
            targetX to targetY
        }
        if (x == params.x && y == params.y && !snap && !force) return
        params.x = x; params.y = y
        try {
            windows.updateViewLayout(root, params)
            if (snap) {
                currentRatioX = FloatingControlGeometry.toNormalizedInArea(params.x, bounds.left, bounds.width, root.width)
                currentRatioY = FloatingControlGeometry.toNormalizedInArea(params.y, bounds.top, bounds.height, root.height)
                persistPreferences(currentRatioX, currentRatioY, userScale, userOpacity)
            }
        } catch (_: RuntimeException) { windowFailure = true; close() }
    }

    fun close() {
        if (attached) {
            try { windows.removeViewImmediate(root) } catch (_: RuntimeException) { }
        }
        attached = false; closed = true
        root.removeAllViews()
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density + .5f).toInt()
    private fun bubbleSizeForStatus() = maxOf(dp(48), scaledDp(48))
    private fun compactTime(elapsedMs: Long): String {
        val seconds = elapsedMs.coerceAtLeast(0) / 1000
        val hours = seconds / 3600
        val minutes = seconds / 60
        val secondPart = (seconds % 60).toString().padStart(2, '0')
        return if (context.resources.configuration.fontScale >= 1.5f || availableSize().first < dp(360)) {
            if (hours > 0) "$hours:${(minutes % 60).toString().padStart(2, '0')}" else "$minutes:$secondPart"
        } else FloatingControlGeometry.time(elapsedMs)
    }
    private fun updateCollapsedVisibility() {
        if (displayedCollapsed == collapsed) return
        val firstLayout = displayedCollapsed == null
        displayedCollapsed = collapsed
        val show = if (collapsed) bubble else panel
        val hide = if (collapsed) panel else bubble
        val animate = !firstLayout && attached && Build.VERSION.SDK_INT >= 26 && ValueAnimator.areAnimatorsEnabled()
        show.animate().cancel()
        hide.animate().cancel()
        if (!animate) {
            show.alpha = 1f
            show.visibility = View.VISIBLE
            hide.alpha = 1f
            hide.visibility = View.GONE
            return
        }
        show.alpha = 0f
        show.visibility = View.VISIBLE
        show.animate().alpha(1f).setDuration(140L).start()
        hide.animate().alpha(0f).setDuration(110L).withEndAction {
            if (displayedCollapsed == collapsed) {
                hide.visibility = View.GONE
                hide.alpha = 1f
            }
        }.start()
    }
    private fun scaledDp(value: Int): Int {
        // Expanded controls must fit narrow displays, even at the largest saved scale.
        val maximum = (availableSize().first - dp(8)).toFloat() / dp(240)
        return FloatingControlGeometry.scaledDimension(dp(value), minOf(userScale, maximum))
    }

    private fun button(label: String, icon: Int, action: () -> Unit) = ImageButton(context).apply {
        layoutParams = LinearLayout.LayoutParams(scaledDp(48), scaledDp(48))
        setBackground(GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            cornerRadius = dp(14).toFloat()
        })
        setImageResource(icon); setColorFilter(accent)
        contentDescription = CaptureText.text(context, label); setOnClickListener { if (isEnabled) action() }
    }

    private data class AvailableBounds(val width: Int, val height: Int, val left: Int = 0, val top: Int = 0)

    private fun availableBounds(): AvailableBounds {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            val imeBottom = metrics.windowInsets.getInsets(WindowInsets.Type.ime()).bottom
            val bottom = maxOf(insets.bottom, imeBottom)
            return AvailableBounds(
                width = (metrics.bounds.width() - insets.left - insets.right).coerceAtLeast(0),
                height = (metrics.bounds.height() - insets.top - bottom).coerceAtLeast(0),
                left = insets.left,
                top = insets.top
            )
        }
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION") windows.defaultDisplay.getMetrics(metrics)
        return AvailableBounds(metrics.widthPixels, metrics.heightPixels)
    }

    private fun availableSize(): Pair<Int, Int> = availableBounds().let { it.width to it.height }

    @SuppressLint("ClickableViewAccessibility")
    private fun drag(view: View) {
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        view.setOnTouchListener { target, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY; startX = params.x; startY = params.y; moved = false; true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX; val dy = event.rawY - downY
                    if (!moved && (abs(dx) > slop || abs(dy) > slop)) {
                        moved = true
                        // Do not let a layout/inset callback restore the previous normalized
                        // position while WindowManager is applying this drag. The new ratios
                        // are stored once the release position has been edge-snapped.
                        currentRatioX = -1f
                        currentRatioY = -1f
                    }
                    if (moved) {
                        val bounds = availableBounds()
                        val targetX = FloatingControlGeometry.clampInArea(startX + dx.toInt(), bounds.left, bounds.width, root.width)
                        val targetY = FloatingControlGeometry.clampInArea(startY + dy.toInt(), bounds.top, bounds.height, root.height)
                        if (targetX != params.x || targetY != params.y) {
                            params.x = targetX; params.y = targetY
                            try { windows.updateViewLayout(root, params) } catch (_: RuntimeException) { windowFailure = true; close() }
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (moved) {
                        reposition(snap = true)
                    } else {
                        target.performClick()
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
}
