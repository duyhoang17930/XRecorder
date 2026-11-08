package com.xrecorder.xrecorder.media

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.graphics.Color
import android.widget.*

/** Android's player owns the playback clock; no simulated Flutter progress. */
class VideoPreviewActivity:Activity() {
    override fun attachBaseContext(base: Context) { super.attachBaseContext(P2Locale.context(base)) }
    companion object { var instance:VideoPreviewActivity?=null }
    private lateinit var video:VideoView
    private var position=0
    override fun onCreate(state:Bundle?) {
        super.onCreate(state)
        instance=this
        position=state?.getInt("position") ?: 0
        val uri=intent.data
        if(uri?.scheme!="content") { finish();return }
        video=VideoView(this).apply { layoutDirection = android.view.View.LAYOUT_DIRECTION_LTR }
        val root=FrameLayout(this).apply { setBackgroundColor(Color.BLACK);addView(video,FrameLayout.LayoutParams(-1,-1,android.view.Gravity.CENTER)) }
        setContentView(root)
        val controls=MediaController(this).apply { setAnchorView(video) };video.setMediaController(controls)
        video.setOnPreparedListener { video.seekTo(position);video.start();controls.show(3000) }
        video.setOnErrorListener { _,_,_ -> Toast.makeText(this,getString(com.xrecorder.xrecorder.R.string.p2_preview_unavailable),Toast.LENGTH_LONG).show();finish();true }
        video.setVideoURI(uri)
    }
    override fun onPause() { if(::video.isInitialized) { position=video.currentPosition;video.pause() };super.onPause() }
    override fun onSaveInstanceState(out:Bundle) { out.putInt("position",if(::video.isInitialized) video.currentPosition else position);super.onSaveInstanceState(out) }
    fun playbackState():Map<String,Any> = if(::video.isInitialized) mapOf("positionMs" to video.currentPosition,"durationMs" to video.duration,"playing" to video.isPlaying) else emptyMap()
    override fun onDestroy() { if(instance===this) instance=null;if(::video.isInitialized) video.stopPlayback();super.onDestroy() }
}
