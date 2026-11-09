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
    val orientation: String = "automatic", val mode: String = "normal", val facecam: Boolean = false,
    val hardwareEncoding: Boolean = true,
    val cropX: Int? = null,
    val cropY: Int? = null,
    val cropWidth: Int? = null,
    val cropHeight: Int? = null,
    val floatingScale: Float = FloatingControlGeometry.DEFAULT_SCALE,
    val floatingOpacity: Float = FloatingControlGeometry.DEFAULT_OPACITY,
    val floatingRatioX: Float = -1f,
    val floatingRatioY: Float = -1f,
    val shakeToStop: Boolean = true,
    val showTouches: Boolean = false,
    val audioDucking: Boolean = false
) {
    val isRegion: Boolean get() = cropWidth != null && cropHeight != null && cropWidth > 0 && cropHeight > 0
    val microphone: Boolean get() = audio == "microphone" || audio == "mixed"
    val hasAudio: Boolean get() = audio != "mute"
    val mime: String get() = if (codec == "hevc") "video/hevc" else "video/avc"
    fun map(): Map<String, Any?> = mapOf("width" to width,"height" to height,"fps" to fps,"bitrate" to bitrate,"codec" to codec,
        "audio" to audio,"micGain" to micGain,"internalGain" to internalGain,"noiseReduction" to noiseReduction,
        "countdown" to countdown,"durationSeconds" to durationSeconds,"orientation" to orientation,"mode" to mode,
        "facecam" to facecam,"hardwareEncoding" to hardwareEncoding,"encoderName" to encoderName,
        "isRegion" to isRegion,"cropX" to cropX,"cropY" to cropY,"cropWidth" to cropWidth,"cropHeight" to cropHeight,
        "floatingScale" to floatingScale,"floatingOpacity" to floatingOpacity,"floatingRatioX" to floatingRatioX,"floatingRatioY" to floatingRatioY,
        "shakeToStop" to shakeToStop,"showTouches" to showTouches,"audioDucking" to audioDucking)
    companion object {
        fun encoders(mime: String): List<MediaCodecInfo> = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter {
            it.isEncoder && it.supportedTypes.any { type -> type.equals(mime,true) }
        }
        fun aacEncoder(): MediaCodecInfo? = encoders("audio/mp4a-latm").firstOrNull { runCatching {
            val caps = it.getCapabilitiesForType("audio/mp4a-latm")
            val audio = requireNotNull(caps.audioCapabilities)
            audio.isSampleRateSupported(48000) && audio.maxInputChannelCount >= 1 &&
                audio.bitrateRange.contains(128000) &&
                caps.profileLevels.any { profile -> profile.profile == MediaCodecInfo.CodecProfileLevel.AACObjectLC }
        }.getOrDefault(false) }
        internal fun videoBitrate(requested: Int?, automatic: Long, lower: Int, upper: Int, performance: Boolean): Int? {
            val limit = if (performance) minOf(upper,8000000) else upper
            val minimum = maxOf(lower,1)
            if (minimum > limit) return null
            val value = requested?.let { if (performance) minOf(it,8000000) else it }
                ?: automatic.coerceIn(minimum.toLong(),limit.toLong()).toInt()
            return value.takeIf { it in minimum..limit }
        }
        private fun supports(encoder: MediaCodecInfo, mime: String, width: Int, height: Int, fps: Int, bitrate: Int? = null): Boolean = runCatching {
            val caps = encoder.getCapabilitiesForType(mime)
            val video = requireNotNull(caps.videoCapabilities)
            caps.colorFormats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface) &&
                width % video.widthAlignment == 0 && height % video.heightAlignment == 0 &&
                video.areSizeAndRateSupported(width, height, fps.toDouble()) &&
                (bitrate == null || video.bitrateRange.contains(bitrate))
        }.getOrDefault(false)
        private fun fitsDisplay(context: Context?, width: Int, height: Int): Boolean {
            if (context == null) return true
            val metrics = context.resources.displayMetrics
            return maxOf(width, height) <= maxOf(metrics.widthPixels, metrics.heightPixels) &&
                minOf(width, height) <= minOf(metrics.widthPixels, metrics.heightPixels)
        }
        fun from(context: Context, values: Map<*, *>?): CaptureConfig {
            val data = values ?: emptyMap<String,Any>()
            fun number(key: String, fallback: Int) = (data[key] as? Number)?.toInt() ?: fallback
            val mode = data["mode"] as? String ?: "normal"
            require(mode in listOf("normal","performance")) { "Unsupported recording mode" }
            val rawCropX = (data["cropX"] as? Number)?.toInt()
            val rawCropY = (data["cropY"] as? Number)?.toInt()
            val rawCropW = (data["cropWidth"] as? Number)?.toInt()
            val rawCropH = (data["cropHeight"] as? Number)?.toInt()

            val metrics = context.resources.displayMetrics
            val sanitizedCrop = if (rawCropX != null && rawCropY != null && rawCropW != null && rawCropH != null) {
                RegionCropGeometry.sanitizeRegion(
                    rawCropX, rawCropY, rawCropW, rawCropH,
                    metrics.widthPixels, metrics.heightPixels
                ) ?: throw IllegalArgumentException("Selected capture region is invalid or too small. Ensure it is within screen bounds and at least 160x160.")
            } else null

            val requestedWidth = sanitizedCrop?.width ?: number("width",1280)
            val requestedHeight = sanitizedCrop?.height ?: number("height",720)
            require(requestedWidth in 160..3840 && requestedHeight in 160..3840) { "Invalid recording dimensions" }
            var longEdge = maxOf(requestedWidth,requestedHeight); var shortEdge = minOf(requestedWidth,requestedHeight)
            var fps = number("fps",30)
            require(fps in listOf(24,30,60,90,120)) { "Unsupported target FPS" }
            if (mode == "performance" && sanitizedCrop == null) { val scale = minOf(1.0,1280.0/longEdge,720.0/shortEdge); longEdge=(longEdge*scale).toInt()/2*2; shortEdge=(shortEdge*scale).toInt()/2*2; fps=minOf(fps,30) }
            val orientation = data["orientation"] as? String ?: "automatic"
            require(orientation in listOf("automatic","portrait","landscape")) { "Invalid orientation" }
            val portrait = orientation == "portrait" || (orientation == "automatic" && metrics.heightPixels > metrics.widthPixels)
            val width = sanitizedCrop?.width ?: if (portrait) shortEdge else longEdge
            val height = sanitizedCrop?.height ?: if (portrait) longEdge else shortEdge
            val codec = data["codec"] as? String ?: "avc"
            require(codec in listOf("avc","hevc")) { "Unsupported codec" }
            val mime = if(codec=="hevc") "video/hevc" else "video/avc"
            require(fitsDisplay(context, width, height)) { "Selected resolution would upscale this display. Choose a lower preset." }
            val hardwareEncoding = data["hardwareEncoding"] != false
            val requestedBitrate = (data["bitrate"] as? Number)?.toInt()?.let { if (mode == "performance") minOf(it,8000000) else it }
            val automaticBitrate = width.toLong()*height*fps/10
            val encoder = encoders(mime).sortedBy {
                if (Build.VERSION.SDK_INT >= 29 && it.isHardwareAccelerated == hardwareEncoding) 0 else 1
            }.firstOrNull { candidate ->
                supports(candidate,mime,width,height,fps,requestedBitrate) && runCatching {
                    val range = requireNotNull(candidate.getCapabilitiesForType(mime).videoCapabilities).bitrateRange
                    videoBitrate(requestedBitrate,automaticBitrate,range.lower,range.upper,mode == "performance") != null
                }.getOrDefault(false)
            } ?: throw IllegalArgumentException("This device cannot encode the selected codec/resolution/FPS/bitrate. Choose a lower preset.")
            val range = requireNotNull(encoder.getCapabilitiesForType(mime).videoCapabilities).bitrateRange
            val bitrate = requireNotNull(videoBitrate(requestedBitrate,automaticBitrate,range.lower,range.upper,mode == "performance")) { "Selected bitrate is outside encoder limits" }
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
            val rawScale = (data["floatingScale"] as? Number)?.toFloat()
            val rawOpacity = (data["floatingOpacity"] as? Number)?.toFloat()
            val rawRatioX = (data["floatingRatioX"] as? Number)?.toFloat()
            val rawRatioY = (data["floatingRatioY"] as? Number)?.toFloat()
            val floatingConfig = FloatingControlGeometry.parseCustomization(rawRatioX, rawRatioY, rawScale, rawOpacity)
            val shakeToStop = data["shakeToStop"] as? Boolean ?: true
            val showTouches = data["showTouches"] as? Boolean ?: false
            val audioDucking = data["audioDucking"] == true && audio == "mixed"

            return CaptureConfig(
                width, height, fps, bitrate, codec, encoder.name, audio,
                micGain, internalGain, noise, countdown, duration, orientation,
                mode, data["facecam"] == true, hardwareEncoding,
                cropX = sanitizedCrop?.x,
                cropY = sanitizedCrop?.y,
                cropWidth = sanitizedCrop?.width,
                cropHeight = sanitizedCrop?.height,
                floatingScale = floatingConfig.scale,
                floatingOpacity = floatingConfig.opacity,
                floatingRatioX = floatingConfig.ratioX,
                floatingRatioY = floatingConfig.ratioY,
                shakeToStop = shakeToStop,
                showTouches = showTouches,
                audioDucking = audioDucking
            )
        }
        fun capabilities(context: Context? = null): Map<String,Any> {
            val codecs = listOf("avc" to "video/avc", "hevc" to "video/hevc")
            val available = codecs.associate { (_, mime) -> mime to encoders(mime) }
            val presets = codecs.flatMap { (codec, mime) ->
                listOf(1280 to 720,1920 to 1080,2560 to 1440,3840 to 2160).filter { (w,h) -> fitsDisplay(context,w,h) }.flatMap { (w,h) ->
                    listOf(24,30,60,90,120).filter { fps ->
                        // Shared presets have no orientation field; advertise only if both fit.
                        available.getValue(mime).any { supports(it,mime,w,h,fps) } &&
                            available.getValue(mime).any { supports(it,mime,h,w,fps) }
                    }.map { fps -> mapOf("width" to w,"height" to h,"fps" to fps,"codec" to codec) }
                }
            }
            val aac = aacEncoder() != null
            return mapOf(
                "audioSources" to if (!aac) listOf("mute") else if (Build.VERSION.SDK_INT >= 29) listOf("mute","microphone","internal","mixed") else listOf("mute","microphone"),
                "noiseReduction" to NoiseSuppressor.isAvailable(),
                "hevc" to presets.any { it["codec"] == "hevc" },
                "presets" to presets,
                "encoders" to codecs.flatMap { (codec,mime) -> available.getValue(mime).map {
                    mapOf("codec" to codec,"name" to it.name,"hardwareAccelerated" to if (Build.VERSION.SDK_INT >= 29) it.isHardwareAccelerated else "unknown")
                } })
        }
        fun capabilities(): Map<String,Any> = mapOf(
            "audioSources" to if (Build.VERSION.SDK_INT >= 29) listOf("mute","microphone","internal","mixed") else listOf("mute","microphone"),
            "noiseReduction" to NoiseSuppressor.isAvailable(),
            "hevc" to encoders("video/hevc").isNotEmpty(),
            "presets" to listOf("video/avc" to "avc", "video/hevc" to "hevc").flatMap { (type, codec) ->
                val available = encoders(type)
                listOf(1280 to 720,1920 to 1080,2560 to 1440,3840 to 2160).flatMap { (w,h) ->
                    listOf(24,30,60,90,120).flatMap { fps ->
                        listOf(w to h, h to w).distinct().filter { (width,height) ->
                            available.any { e ->
                                runCatching {
                                    e.getCapabilitiesForType(type).videoCapabilities
                                        .areSizeAndRateSupported(width,height,fps.toDouble())
                                }.getOrDefault(false)
                            }
                        }.map { (width,height) ->
                            mapOf("width" to width,"height" to height,"fps" to fps,"codec" to codec)
                        }
                    }
                }
            })
    }
}
