package com.xrecorder.xrecorder.media

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowInsets
import com.xrecorder.xrecorder.R
import android.widget.*

/** Android's player owns the playback clock; no simulated Flutter progress. */
class VideoPreviewActivity:Activity() {
    override fun attachBaseContext(base: Context) { super.attachBaseContext(P2Locale.context(base)) }
    companion object { var instance:VideoPreviewActivity?=null }
    private lateinit var video:VideoView
    private var playbackControls:MediaController?=null
    private var position=0
    override fun onCreate(state:Bundle?) {
        super.onCreate(state)
        instance=this
        position=state?.getInt("position") ?: 0
        val uri=intent.data
        if(uri?.scheme!="content") { finish();return }
        video=VideoView(this).apply { layoutDirection = android.view.View.LAYOUT_DIRECTION_LTR }
        val root=FrameLayout(this).apply { setBackgroundColor(Color.BLACK);addView(video,FrameLayout.LayoutParams(-1,-1,android.view.Gravity.CENTER)) }
        val back = ImageButton(this).apply {
            id = R.id.p2_player_back
            contentDescription = getString(R.string.p2_back)
            setImageResource(R.drawable.p2_chevron_back)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(184, 0, 0, 0))
                setStroke(dp(1), Color.argb(72, 255, 255, 255))
            }
            setOnClickListener { finish() }
        }
        root.addView(back, FrameLayout.LayoutParams(dp(48), dp(48), Gravity.TOP or Gravity.LEFT))
        root.setOnApplyWindowInsetsListener { _, insets ->
            val top: Int
            val left: Int
            if (Build.VERSION.SDK_INT >= 30) {
                val safe = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                top = safe.top
                left = safe.left
            } else {
                @Suppress("DEPRECATION")
                top = maxOf(insets.systemWindowInsetTop, if (Build.VERSION.SDK_INT >= 28) insets.displayCutout?.safeInsetTop ?: 0 else 0)
                @Suppress("DEPRECATION")
                left = maxOf(insets.systemWindowInsetLeft, if (Build.VERSION.SDK_INT >= 28) insets.displayCutout?.safeInsetLeft ?: 0 else 0)
            }
            back.layoutParams = (back.layoutParams as FrameLayout.LayoutParams).apply {
                topMargin = top + dp(8)
                leftMargin = left + dp(8)
            }
            insets
        }
        setContentView(root)
        root.requestApplyInsets()
        val controls=object : MediaController(this) {
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) finish()
                    return true
                }
                return super.dispatchKeyEvent(event)
            }
        }.apply {
            setAnchorView(video)
            if(Build.VERSION.SDK_INT>=33) addOnAttachStateChangeListener(ControllerBackHandler { finish() })
        };video.setMediaController(controls)
        playbackControls=controls
        video.setOnPreparedListener { if(!isFinishing && !isDestroyed) { video.seekTo(position);video.start();controls.show(3000) } }
        video.setOnErrorListener { _,_,_ -> Toast.makeText(this,getString(com.xrecorder.xrecorder.R.string.p2_preview_unavailable),Toast.LENGTH_LONG).show();finish();true }
        video.setVideoURI(uri)
    }
    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + .5f).toInt()
    override fun finish() { playbackControls?.hide();releasePlayback();super.finish() }
    override fun onPause() { playbackControls?.hide();if(::video.isInitialized) { position=video.currentPosition;video.pause() };super.onPause() }
    override fun onSaveInstanceState(out:Bundle) { out.putInt("position",if(::video.isInitialized) video.currentPosition else position);super.onSaveInstanceState(out) }
    fun playbackState():Map<String,Any> = if(::video.isInitialized) mapOf("positionMs" to video.currentPosition,"durationMs" to video.duration,"playing" to video.isPlaying) else emptyMap()
    private fun releasePlayback() {
        // Finishing can precede Android's onDestroy by several seconds. Stop
        // the actual decoder before dropping its live-owner reference.
        if(::video.isInitialized) video.stopPlayback()
        if(instance===this) instance=null
    }
    override fun onDestroy() { releasePlayback();super.onDestroy() }

    // Keep API33 classes isolated from the API24-32 controller path.
    @android.annotation.TargetApi(33)
    private class ControllerBackHandler(close:()->Unit):android.view.View.OnAttachStateChangeListener {
        private var dispatcher:android.window.OnBackInvokedDispatcher?=null
        private val callback=android.window.OnBackInvokedCallback { close() }
        private var attached:android.view.View?=null
        private val register=Runnable {
            val view=attached
            if(view?.isAttachedToWindow==true) dispatcher=view.findOnBackInvokedDispatcher()?.also {
                it.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_OVERLAY,callback)
            }
        }
        override fun onViewAttachedToWindow(view:android.view.View) {
            // MediaController owns a floating window. Its dispatcher receives
            // predictive Back before the Activity's legacy key-event path.
            // Wait for ViewRoot attachment to expose that window dispatcher.
            attached=view
            view.post(register)
        }
        override fun onViewDetachedFromWindow(view:android.view.View) {
            view.removeCallbacks(register)
            dispatcher?.unregisterOnBackInvokedCallback(callback)
            dispatcher=null
            attached=null
        }
    }
}
