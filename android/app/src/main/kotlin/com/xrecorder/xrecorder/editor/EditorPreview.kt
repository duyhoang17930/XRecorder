package com.xrecorder.xrecorder.editor

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.transformer.CompositionPlayer
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EditorPreviewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView =
        EditorPreview(context, id, messenger)
}

class EditorPreview(context: Context, id: Int, messenger: BinaryMessenger) :
    PlatformView, MethodChannel.MethodCallHandler {
    companion object {
        private val active = mutableSetOf<EditorPreview>()
        private val retiring = mutableSetOf<CompositionPlayer>()
        private var releaseFailures = 0
        private var loads = 0

        fun loadCount(): Int = loads

        fun activeCount(): Int = active.size + retiring.size

        fun releaseFailureCount(): Int = releaseFailures

        fun pauseAll() {
            active.toList().forEach { it.player?.pause() }
        }
    }

    // CompositionPlayer 1.11 cannot fully release a never-loaded composition.
    // Allocate only after validating a load, not when a route creates a view.
    private var player: CompositionPlayer? = null
    private val view =
        PlayerView(context).apply {
            useController = false
        }
    private val channel = MethodChannel(messenger, "com.xrecorder/editor_preview/$id")
    private var error: String? = null
    private var disposing = false
    private var renderedFirstFrame = false

    init {
        active.add(this)
        channel.setMethodCallHandler(this)
    }

    private fun createPlayer(): CompositionPlayer =
        CompositionPlayer.Builder(view.context).build().also { created ->
            renderedFirstFrame = false
            created.addListener(
                object : Player.Listener {
                    override fun onRenderedFirstFrame() {
                        if (player === created) renderedFirstFrame = true
                    }

                    override fun onPlayerError(value: PlaybackException) {
                        if (disposing || created in retiring) {
                            releaseFailures++
                            android.util.Log.w(
                                "EditorPreviewRelease",
                                "Playback thread at release failure: " +
                                    created.playbackLooper.thread.stackTrace.joinToString("\n"),
                            )
                        }
                        error =
                            "Preview failed (${value.errorCodeName}). Check source access and device codec support."
                    }
                },
            )
            player = created
            view.player = created
        }

    override fun getView(): View = view

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "load" -> {
                    val composition = EditorComposition.build(call.arguments as Map<*, *>)
                    loads++
                    val failuresBefore = releaseFailures
                    releasePlayer()
                    check(releaseFailures == failuresBefore) {
                        "The previous preview could not close."
                    }
                    val current = createPlayer()
                    error = null
                    current.setComposition(composition)
                    current.prepare()
                }
                "play" -> player?.play()
                "pause" -> player?.pause()
                "seek" -> player?.seekTo((call.arguments as Number).toLong().coerceAtLeast(0))
                "state" -> {
                    result.success(
                        mapOf(
                            "positionMs" to (player?.currentPosition ?: 0L),
                            "durationMs" to (player?.duration ?: 0L).coerceAtLeast(0),
                            "playing" to (player?.isPlaying ?: false),
                            "playbackState" to (player?.playbackState ?: Player.STATE_IDLE),
                            "renderedFirstFrame" to renderedFirstFrame,
                            "surfaceShown" to (view.videoSurfaceView?.isShown ?: false),
                            "surfaceWidth" to (view.videoSurfaceView?.width ?: 0),
                            "surfaceHeight" to (view.videoSurfaceView?.height ?: 0),
                            "error" to error,
                            "width" to (player?.videoSize?.width ?: 0),
                            "height" to (player?.videoSize?.height ?: 0),
                            "pixelRatio" to (player?.videoSize?.pixelWidthHeightRatio ?: 1f),
                        ),
                    )
                    return
                }
                else -> {
                    result.notImplemented()
                    return
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("editor_preview", e.message ?: "Preview unavailable", null)
        }
    }

    private fun releasePlayer() {
        val current = player ?: return
        disposing = true
        try {
            // A changed composition needs a fresh video/audio graph. Detach its
            // SurfaceView before release so pending seeks cannot stall it.
            current.pause()
            current.stop()
            view.player = null
            current.release()
        } finally {
            player = null
            disposing = false
        }
    }

    override fun dispose() {
        active.remove(this)
        channel.setMethodCallHandler(null)
        val current = player ?: return
        player = null
        retiring.add(current)
        current.pause()
        current.stop()
        view.player = null
        // A seek/reset and stop enqueue work on Media3's playback looper. Its
        // release has a short blocking timeout; don't start that wait while
        // those earlier tasks are still queued. Drain asynchronously so Android
        // can also finish removing the platform SurfaceView on the main looper.
        val main = Handler(Looper.getMainLooper())
        val release = Runnable {
            disposing = true
            try {
                current.release()
            } catch (error: Exception) {
                releaseFailures++
                android.util.Log.w("EditorPreviewRelease", "Player release failed", error)
            } finally {
                retiring.remove(current)
                disposing = false
            }
        }
        if (!Handler(current.playbackLooper).post { main.post(release) }) {
            main.post(release)
        }
    }
}
