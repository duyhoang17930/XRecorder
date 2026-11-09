package com.xrecorder.xrecorder.recording

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
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

    private val root = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
    }
    @Suppress("DEPRECATION")
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
        // These flags govern input only. The opt-in controls may appear in MP4.
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.LEFT; x = dp(8); y = dp(140); title = "3HRecorder floating controls" }

    private val timer = TextView(context).apply {
        setTextColor(Color.WHITE); textSize = 14f; typeface = Typeface.MONOSPACE
        gravity = Gravity.CENTER
        setPadding(dp(4), 0, dp(4), 0)
        setOnClickListener { collapsed = true; render(state, elapsed) }
    }
    private val bubble = TextView(context).apply {
        setTextColor(accent); textSize = 20f; gravity = Gravity.CENTER
        setOnClickListener { collapsed = false; render(state, elapsed) }
    }
    private val pause = button("Pause recording", android.R.drawable.ic_media_pause) { togglePause() }
    private val stopButton = button("Stop recording", android.R.drawable.ic_menu_close_clear_cancel) { stop() }
    private val panel = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        addView(timer)
        addView(pause)
        addView(stopButton)
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

        applyCustomizationLayout()

        root.addView(panel)
        root.addView(bubble)
        drag(timer); drag(bubble)
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
        val bubbleSize = scaledDp(48)
        val timerWidth = scaledDp(96)
        val corner = scaledDp(20).toFloat()
        val stopIconSize = scaledDp(16)

        root.background = GradientDrawable().apply {
            setColor(Color.rgb(24, 24, 28))
            cornerRadius = corner
            setStroke(dp(1), accent)
        }

        bubble.layoutParams = LinearLayout.LayoutParams(bubbleSize, bubbleSize)
        timer.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, bubbleSize)
        timer.minHeight = bubbleSize
        timer.minWidth = timerWidth

        pause.layoutParams = LinearLayout.LayoutParams(bubbleSize, bubbleSize)
        stopButton.layoutParams = LinearLayout.LayoutParams(bubbleSize, bubbleSize)
        stopButton.setImageDrawable(GradientDrawable().apply {
            setColor(accent)
            setSize(stopIconSize, stopIconSize)
        })

        if (currentRatioX in 0f..1f && currentRatioY in 0f..1f) {
            val (width, height) = availableSize()
            params.x = FloatingControlGeometry.fromNormalizedX(currentRatioX, width, bubbleSize)
            params.y = FloatingControlGeometry.fromNormalizedY(currentRatioY, height, bubbleSize)
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
        timer.text = if (active) SpannableString(overlayState.statusText).apply {
            setSpan(ForegroundColorSpan(accent), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        } else "Saving…"
        timer.contentDescription = "${if (paused) "Paused" else if (active) "Recording" else "Saving"} ${FloatingControlGeometry.time(elapsedMs)}. Tap to collapse, drag to move controls"
        pause.setImageResource(if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause)
        pause.contentDescription = if (paused) "Resume recording" else "Pause recording"
        pause.isEnabled = active; stopButton.isEnabled = active
        root.alpha = overlayState.alpha
        pause.alpha = overlayState.alpha; stopButton.alpha = overlayState.alpha
        root.setPadding(if (collapsed) 0 else dp(4), 0, if (collapsed) 0 else dp(4), 0)
        panel.visibility = if (collapsed) View.GONE else View.VISIBLE
        bubble.visibility = if (collapsed) View.VISIBLE else View.GONE
        bubble.text = if (!active) "…" else if (paused) "Ⅱ" else "●"
        bubble.contentDescription = "Expand recording controls. ${FloatingControlGeometry.time(elapsedMs)}"
        if (!attached) {
            try { windows.addView(root, params); attached = true }
            catch (_: RuntimeException) { closed = true } // Notification controls remain available.
        }
    }

    fun reposition(snap: Boolean = false, force: Boolean = false) {
        if (!attached || closed) return
        val (width, height) = availableSize()
        val (x, y) = if (currentRatioX in 0f..1f && currentRatioY in 0f..1f && !snap) {
            FloatingControlGeometry.repositionAfterRotation(
                currentRatioX, currentRatioY, width, height, root.width, root.height, snapToEdge = false
            )
        } else {
            val targetX = if (snap) FloatingControlGeometry.snap(params.x, width, root.width)
                else FloatingControlGeometry.clamp(params.x, width, root.width)
            val targetY = FloatingControlGeometry.clamp(params.y, height, root.height)
            targetX to targetY
        }
        if (x == params.x && y == params.y && !snap && !force) return
        params.x = x; params.y = y
        try {
            windows.updateViewLayout(root, params)
            if (snap) {
                currentRatioX = FloatingControlGeometry.toNormalizedX(params.x, width, root.width)
                currentRatioY = FloatingControlGeometry.toNormalizedY(params.y, height, root.height)
                persistPreferences(currentRatioX, currentRatioY, userScale, userOpacity)
            }
        } catch (_: RuntimeException) { close() }
    }

    fun close() {
        if (attached) {
            try { windows.removeViewImmediate(root) } catch (_: RuntimeException) { }
        }
        attached = false; closed = true
        root.removeAllViews()
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density + .5f).toInt()
    private fun scaledDp(value: Int) = FloatingControlGeometry.scaledDimension(dp(value), userScale)

    private fun button(label: String, icon: Int, action: () -> Unit) = ImageButton(context).apply {
        layoutParams = LinearLayout.LayoutParams(scaledDp(48), scaledDp(48))
        setBackgroundColor(Color.TRANSPARENT); setImageResource(icon); setColorFilter(accent)
        contentDescription = label; setOnClickListener { if (isEnabled) action() }
    }

    private fun availableSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windows.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            return (metrics.bounds.width() - insets.left - insets.right) to
                (metrics.bounds.height() - insets.top - insets.bottom)
        }
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION") windows.defaultDisplay.getMetrics(metrics)
        return metrics.widthPixels to metrics.heightPixels
    }

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
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        val (width, height) = availableSize()
                        val targetX = FloatingControlGeometry.clamp(startX + dx.toInt(), width, root.width)
                        val targetY = FloatingControlGeometry.clamp(startY + dy.toInt(), height, root.height)
                        if (targetX != params.x || targetY != params.y) {
                            params.x = targetX; params.y = targetY
                            try { windows.updateViewLayout(root, params) } catch (_: RuntimeException) { close() }
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
