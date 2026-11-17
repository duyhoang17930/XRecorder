package com.xrecorder.xrecorder.media

import android.app.Activity
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import android.widget.VideoView
import com.xrecorder.xrecorder.R

/**
 * Full-screen player in the app's style. Android's VideoView owns the
 * playback clock; the overlay only reflects and commands it.
 */
class VideoPreviewActivity : Activity() {
    override fun attachBaseContext(base: Context) { super.attachBaseContext(P2Locale.context(base)) }
    companion object { var instance: VideoPreviewActivity? = null }

    private val palette = StudioPalette.dark
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var video: VideoView
    private lateinit var catalog: MediaCatalog
    private lateinit var topBar: LinearLayout
    private lateinit var bottomBar: LinearLayout
    private lateinit var center: LinearLayout
    private lateinit var playButton: ImageButton
    private lateinit var title: TextView
    private lateinit var elapsed: TextView
    private lateinit var total: TextView
    private lateinit var seek: SeekBar
    private var position = 0
    private var optionsOpen = false
    private var controlsVisible = true
    private var seeking = false

    private val hideControls = Runnable { if (video.isPlaying && !seeking && !optionsOpen) setControls(false) }
    private val progress = object : Runnable {
        override fun run() {
            if (::video.isInitialized && !seeking) updateProgress()
            handler.postDelayed(this, 250)
        }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        instance = this
        catalog = MediaCatalog(this)
        position = state?.getInt("position") ?: 0
        val uri = intent.data
        if (uri?.scheme != "content") { finish(); return }
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.BLACK
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.BLACK

        video = VideoView(this).apply { layoutDirection = View.LAYOUT_DIRECTION_LTR }
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            addView(video, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))
        }
        // Taps anywhere outside the controls toggle them, like other players.
        root.setOnClickListener { setControls(!controlsVisible) }

        topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = scrim(GradientDrawable.Orientation.TOP_BOTTOM)
        }
        val back = circleButton(R.drawable.p2_chevron_back, getString(R.string.p2_back)).apply {
            id = R.id.p2_player_back
            setOnClickListener { finish() }
        }
        title = studioText(displayName(uri), 16f, palette.text, 700, maxLines = 1)
        val more = circleButton(R.drawable.p2_more, getString(R.string.p2_info)).apply {
            id = R.id.p2_player_more
            setOnClickListener { openOptions() }
        }
        topBar.addView(back, LinearLayout.LayoutParams(dp(48), dp(48)))
        topBar.addView(title, LinearLayout.LayoutParams(0, -2, 1f).apply {
            marginStart = dp(12); marginEnd = dp(12)
        })
        topBar.addView(more, LinearLayout.LayoutParams(dp(48), dp(48)))
        root.addView(topBar, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))

        center = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val rewind = circleButton(R.drawable.ic_lucide_rewind_10, "−10 s").apply {
            setOnClickListener { skip(-10_000) }
        }
        playButton = ImageButton(this).apply {
            setImageResource(R.drawable.ic_lucide_play)
            imageTintList = ColorStateList.valueOf(palette.primaryForeground)
            scaleType = android.widget.ImageView.ScaleType.CENTER
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(palette.primary) }
            setPadding(dp(18), dp(18), dp(18), dp(18))
            setOnClickListener { togglePlayback() }
        }
        val forward = circleButton(R.drawable.ic_lucide_forward_10, "+10 s").apply {
            setOnClickListener { skip(10_000) }
        }
        center.addView(rewind, LinearLayout.LayoutParams(dp(52), dp(52)))
        center.addView(playButton, LinearLayout.LayoutParams(dp(72), dp(72)).apply {
            marginStart = dp(32); marginEnd = dp(32)
        })
        center.addView(forward, LinearLayout.LayoutParams(dp(52), dp(52)))
        root.addView(center, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))

        bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = scrim(GradientDrawable.Orientation.BOTTOM_TOP)
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }
        seek = SeekBar(this).apply {
            progressTintList = ColorStateList.valueOf(palette.primary)
            progressBackgroundTintList = ColorStateList.valueOf(withAlpha(Color.WHITE, .3f))
            thumbTintList = ColorStateList.valueOf(palette.primary)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar, value: Int, fromUser: Boolean) {
                    if (fromUser) elapsed.text = clock(value)
                }
                override fun onStartTrackingTouch(bar: SeekBar) { seeking = true; handler.removeCallbacks(hideControls) }
                override fun onStopTrackingTouch(bar: SeekBar) {
                    seeking = false
                    video.seekTo(bar.progress)
                    scheduleHide()
                }
            })
        }
        val times = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        elapsed = studioText("00:00", 12f, palette.text, 600)
        total = studioText("00:00", 12f, palette.muted, 600).apply { gravity = Gravity.END }
        times.addView(elapsed, LinearLayout.LayoutParams(0, -2, 1f))
        times.addView(total, LinearLayout.LayoutParams(0, -2, 1f))
        bottomBar.addView(seek, LinearLayout.LayoutParams(-1, dp(36)))
        bottomBar.addView(times, LinearLayout.LayoutParams(-1, -2).apply {
            marginStart = dp(16); marginEnd = dp(16)
        })
        root.addView(bottomBar, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))

        root.setOnApplyWindowInsetsListener { _, insets ->
            @Suppress("DEPRECATION")
            val safe = if (Build.VERSION.SDK_INT >= 30)
                insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()).let {
                    intArrayOf(it.left, it.top, it.right, it.bottom)
                }
            else intArrayOf(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            topBar.setPadding(safe[0] + dp(12), safe[1] + dp(8), safe[2] + dp(12), dp(24))
            bottomBar.setPadding(safe[0] + dp(8), dp(24), safe[2] + dp(8), safe[3] + dp(16))
            insets
        }
        setContentView(root)
        root.requestApplyInsets()

        video.setOnPreparedListener {
            if (isFinishing || isDestroyed) return@setOnPreparedListener
            seek.max = video.duration.coerceAtLeast(0)
            total.text = clock(video.duration)
            video.seekTo(position)
            video.start()
            updatePlayIcon()
            setControls(true)
        }
        video.setOnCompletionListener { updatePlayIcon(); setControls(true) }
        video.setOnErrorListener { _, _, _ ->
            Toast.makeText(this, getString(R.string.p2_preview_unavailable), Toast.LENGTH_LONG).show()
            finish(); true
        }
        video.setVideoURI(uri)
        handler.post(progress)
    }

    private fun openOptions() {
        if (optionsOpen) return
        optionsOpen = true
        handler.removeCallbacks(hideControls)
        VideoOptions(this, catalog,
            edit = {
                setResult(RESULT_OK, android.content.Intent().putExtra("editUri", it.toString()))
                finish()
            },
            changed = { next, removed ->
                if (removed) finish()
                else if (next != intent.data) {
                    position = video.currentPosition
                    intent.data = next
                    title.text = displayName(next)
                    video.setVideoURI(next)
                }
            },
            dismissed = { optionsOpen = false; scheduleHide() },
            dark = true,
        ).show(intent.data!!)
    }

    private fun togglePlayback() {
        if (video.isPlaying) video.pause() else video.start()
        updatePlayIcon()
        if (video.isPlaying) scheduleHide() else handler.removeCallbacks(hideControls)
    }

    private fun skip(deltaMs: Int) {
        val duration = video.duration.coerceAtLeast(0)
        video.seekTo((video.currentPosition + deltaMs).coerceIn(0, duration))
        updateProgress()
        scheduleHide()
    }

    private fun setControls(visible: Boolean) {
        controlsVisible = visible
        for (view in listOf(topBar, center, bottomBar)) {
            view.animate().cancel()
            if (visible) {
                view.visibility = View.VISIBLE
                view.animate().alpha(1f).setDuration(150).start()
            } else {
                view.animate().alpha(0f).setDuration(200).withEndAction { view.visibility = View.GONE }.start()
            }
        }
        if (visible) scheduleHide()
    }

    private fun scheduleHide() {
        handler.removeCallbacks(hideControls)
        handler.postDelayed(hideControls, 3000)
    }

    private fun updateProgress() {
        val duration = video.duration
        if (duration > 0 && seek.max != duration) { seek.max = duration; total.text = clock(duration) }
        seek.progress = video.currentPosition
        elapsed.text = clock(video.currentPosition)
        updatePlayIcon()
    }

    private fun updatePlayIcon() {
        val playing = video.isPlaying
        playButton.setImageResource(if (playing) R.drawable.ic_lucide_pause else R.drawable.ic_lucide_play)
        playButton.contentDescription = getString(if (playing) R.string.p2_pause else R.string.p2_play)
    }

    private fun clock(ms: Int): String {
        val seconds = (ms.coerceAtLeast(0) / 1000)
        return if (seconds >= 3600)
            String.format(java.util.Locale.ROOT, "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        else String.format(java.util.Locale.ROOT, "%02d:%02d", seconds / 60, seconds % 60)
    }

    private fun displayName(uri: Uri): String = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: ""
    } catch (_: Exception) { "" }

    private fun circleButton(icon: Int, description: String) = ImageButton(this).apply {
        setImageResource(icon)
        imageTintList = ColorStateList.valueOf(Color.WHITE)
        contentDescription = description
        scaleType = android.widget.ImageView.ScaleType.CENTER
        setPadding(dp(12), dp(12), dp(12), dp(12))
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.argb(140, 0, 0, 0))
            setStroke(dp(1), Color.argb(56, 255, 255, 255))
        }
    }

    private fun scrim(direction: GradientDrawable.Orientation) =
        GradientDrawable(direction, intArrayOf(Color.argb(190, 0, 0, 0), Color.TRANSPARENT))

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + .5f).toInt()

    override fun finish() { releasePlayback(); super.finish() }
    override fun onPause() {
        if (::video.isInitialized) { position = video.currentPosition; video.pause(); updatePlayIcon() }
        super.onPause()
    }
    override fun onSaveInstanceState(out: Bundle) {
        out.putInt("position", if (::video.isInitialized) video.currentPosition else position)
        super.onSaveInstanceState(out)
    }
    fun playbackState(): Map<String, Any> =
        if (::video.isInitialized) mapOf("positionMs" to video.currentPosition, "durationMs" to video.duration, "playing" to video.isPlaying)
        else emptyMap()
    private fun releasePlayback() {
        handler.removeCallbacksAndMessages(null)
        // Finishing can precede Android's onDestroy by several seconds. Stop
        // the actual decoder before dropping its live-owner reference.
        if (::video.isInitialized) video.stopPlayback()
        if (instance === this) instance = null
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (!catalog.onActivityResult(requestCode, resultCode, data)) super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() { releasePlayback(); if (::catalog.isInitialized) catalog.dispose(); super.onDestroy() }
}
