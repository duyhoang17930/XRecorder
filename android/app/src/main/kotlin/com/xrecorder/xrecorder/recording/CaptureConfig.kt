package com.xrecorder.xrecorder.recording

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.audiofx.NoiseSuppressor
import android.os.Build

data class CaptureConfig(
    val width: Int = 1280, val height: Int = 720, val fps: Int = 30,
    val bitrate: Int = 8000000, val codec: String = "avc", val encoderName: String = "",
    val audio: String = "mute", val micGain: Double = 1.0, val internalGain: Double = 1.0,
    val noiseReduction: Boolean = false, val countdown: Int = 0, val durationSeconds: Int = 0,
    val orientation: String = "automatic", val mode: String = "normal"
) {
    val microphone: Boolean get() = audio == "microphone" || audio == "mixed"
    val hasAudio: Boolean get() = audio != "mute"
    val mime: String get() = if (codec == "hevc") "video/hevc" else "video/avc"
    fun map(): Map<String, Any> = mapOf("width" to width,"height" to height,"fps" to fps,"bitrate" to bitrate,"codec" to codec,
        "audio" to audio,"micGain" to micGain,"internalGain" to internalGain,"noiseReduction" to noiseReduction,
        "countdown" to countdown,"durationSeconds" to durationSeconds,"orientation" to orientation,"mode" to mode)
    companion object {
        fun encoders(mime: String): List<MediaCodecInfo> = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter {
            it.isEncoder && it.supportedTypes.any { type -> type.equals(mime,true) }
        }
        fun from(context: Context, values: Map<*, *>?): CaptureConfig {
            val data = values ?: emptyMap<String,Any>()
            fun number(key: String, fallback: Int) = (data[key] as? Number)?.toInt() ?: fallback
            val mode = data["mode"] as? String ?: "normal"
            require(mode in listOf("normal","performance")) { "Unsupported recording mode" }
            val requestedWidth = number("width",1280); val requestedHeight = number("height",720)
            require(requestedWidth in 160..3840 && requestedHeight in 160..3840) { "Invalid recording dimensions" }
            var longEdge = maxOf(requestedWidth,requestedHeight); var shortEdge = minOf(requestedWidth,requestedHeight)
            var fps = number("fps",30)
            require(fps in listOf(24,30,60,90,120)) { "Unsupported target FPS" }
            if (mode == "performance") { val scale = minOf(1.0,1280.0/longEdge,720.0/shortEdge); longEdge=(longEdge*scale).toInt()/2*2; shortEdge=(shortEdge*scale).toInt()/2*2; fps=minOf(fps,30) }
            val orientation = data["orientation"] as? String ?: "automatic"
            require(orientation in listOf("automatic","portrait","landscape")) { "Invalid orientation" }
            val metrics = context.resources.displayMetrics
            val portrait = orientation == "portrait" || (orientation == "automatic" && metrics.heightPixels > metrics.widthPixels)
            val width = if (portrait) shortEdge else longEdge; val height = if (portrait) longEdge else shortEdge
            val codec = data["codec"] as? String ?: "avc"
            require(codec in listOf("avc","hevc")) { "Unsupported codec" }
            val mime = if(codec=="hevc") "video/hevc" else "video/avc"
            val encoder = encoders(mime).firstOrNull { it.getCapabilitiesForType(mime).videoCapabilities.areSizeAndRateSupported(width,height,fps.toDouble()) }
                ?: throw IllegalArgumentException("This device cannot encode the selected resolution/FPS. Choose a lower preset.")
            val range = encoder.getCapabilitiesForType(mime).videoCapabilities.bitrateRange
            var bitrate = (data["bitrate"] as? Number)?.toInt() ?: (width.toLong()*height*fps/10).coerceIn(range.lower.toLong(),range.upper.toLong()).toInt()
            if (mode == "performance") bitrate = minOf(bitrate,8000000)
            require(range.contains(bitrate)) { "Selected bitrate is outside encoder limits" }
            val audio = data["audio"] as? String ?: "mute"
            require(audio in listOf("mute","microphone","internal","mixed")) { "Unsupported audio source" }
            require(Build.VERSION.SDK_INT >= 29 || audio !in listOf("internal","mixed")) { "Internal audio requires Android 10 or later. Choose microphone or mute." }
            val micGain = (data["micGain"] as? Number)?.toDouble() ?: 1.0
            val internalGain = (data["internalGain"] as? Number)?.toDouble() ?: 1.0
            require(micGain.isFinite() && internalGain.isFinite() && micGain in 0.0..2.0 && internalGain in 0.0..2.0) { "Invalid audio gain" }
            val noise = data["noiseReduction"] == true && audio in listOf("microphone","mixed")
            require(!noise || NoiseSuppressor.isAvailable()) { "Noise reduction is unavailable. Disable it in audio settings." }
            val countdown = number("countdown",0); val duration = number("durationSeconds",0)
            require(countdown in 0..10 && duration in 0..86400) { "Invalid countdown or recording duration" }
            return CaptureConfig(width,height,fps,bitrate,codec,encoder.name,audio,micGain,internalGain,noise,countdown,duration,orientation,mode)
        }
        fun capabilities(): Map<String,Any> = mapOf(
            "audioSources" to if (Build.VERSION.SDK_INT >= 29) listOf("mute","microphone","internal","mixed") else listOf("mute","microphone"),
            "noiseReduction" to NoiseSuppressor.isAvailable(),
            "hevc" to encoders("video/hevc").isNotEmpty(),
            "presets" to listOf(1280 to 720,1920 to 1080,2560 to 1440,3840 to 2160).flatMap { (w,h) ->
                listOf(24,30,60,90,120).filter { fps -> encoders("video/avc").any { e -> val caps=e.getCapabilitiesForType("video/avc").videoCapabilities; caps.areSizeAndRateSupported(w,h,fps.toDouble()) || caps.areSizeAndRateSupported(h,w,fps.toDouble()) } }
                    .map { fps -> mapOf("width" to w,"height" to h,"fps" to fps) }
            })
    }
}
