package com.xrecorder.xrecorder.editor

import android.content.Context
import android.view.View
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.transformer.CompositionPlayer
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EditorPreviewFactory(private val messenger:BinaryMessenger):PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context:Context,id:Int,args:Any?):PlatformView=EditorPreview(context,id,messenger)
}
class EditorPreview(context:Context,id:Int,messenger:BinaryMessenger):PlatformView,MethodChannel.MethodCallHandler {
    companion object {
        private val active=mutableSetOf<EditorPreview>()
        fun pauseAll() { active.toList().forEach{it.player.pause()} }
    }
    private val player=CompositionPlayer.Builder(context).build()
    private val view=PlayerView(context).apply { useController=false;player=this@EditorPreview.player }
    private val channel=MethodChannel(messenger,"com.xrecorder/editor_preview/$id")
    private var error:String?=null
    init {
        active.add(this);channel.setMethodCallHandler(this)
        player.addListener(object:Player.Listener { override fun onPlayerError(value:PlaybackException) { error="Preview failed (${value.errorCodeName}). Check source access and device codec support." } })
    }
    override fun getView():View=view
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
        try {
            when(call.method) {
                "load" -> { error=null;player.pause();player.setComposition(EditorComposition.build(call.arguments as Map<*,*>));player.prepare() }
                "play" -> player.play()
                "pause" -> player.pause()
                "seek" -> player.seekTo((call.arguments as Number).toLong().coerceAtLeast(0))
                "state" -> { result.success(mapOf("positionMs" to player.currentPosition,"durationMs" to player.duration.coerceAtLeast(0),"playing" to player.isPlaying,"error" to error));return }
                else -> { result.notImplemented();return }
            }
            result.success(null)
        } catch(e:Exception) { result.error("editor_preview",e.message ?: "Preview unavailable",null) }
    }
    override fun dispose() { active.remove(this);channel.setMethodCallHandler(null);view.player=null;player.release() }
}
