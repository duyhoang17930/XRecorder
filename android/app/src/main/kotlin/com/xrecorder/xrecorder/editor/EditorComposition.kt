package com.xrecorder.xrecorder.editor

import android.net.Uri
import android.text.SpannableString
import androidx.media3.common.C
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.audio.*
import androidx.media3.effect.*
import androidx.media3.effect.Crop
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.*
import com.google.common.collect.ImmutableList

/** One validated composition definition serves both native preview and export. */
object EditorComposition {
    /** ASR consumes the identical edited audio without rendering video frames. */
    fun audioOnly(project: Map<*, *>): Composition {
        val source = build(project)
        val clips = project["clips"] as List<*>
        val speed = ((project["effects"] as? Map<*, *>)?.get("speed") as? Number)?.toDouble() ?: 1.0
        return Composition.Builder(
                source.sequences.mapIndexed { sequenceIndex, sequence ->
                    val builder =
                        EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO))
                            .setIsLooping(sequence.isLooping)
                    sequence.editedMediaItems.forEachIndexed { index, item ->
                        val clip = if (sequenceIndex == 0) clips[index] as Map<*, *> else null
                        if (clip?.get("isImage") == true) {
                            val duration =
                                (((clip["outMs"] as Number).toLong() -
                                        (clip["inMs"] as Number).toLong()) * 1000 / speed)
                                    .toLong()
                            builder.addGap(duration)
                        } else
                            builder.addItem(
                                item
                                    .buildUpon()
                                    .setRemoveVideo(true)
                                    .setEffects(Effects(item.effects.audioProcessors, emptyList()))
                                    .build(),
                            )
                    }
                    builder.build()
                },
            )
            .setEffects(Effects(source.effects.audioProcessors, emptyList()))
            .build()
    }

    fun encoder(context: android.content.Context, project: Map<*, *>): DefaultEncoderFactory {
        val bitrate = ((project["effects"] as? Map<*, *>)?.get("bitrate") as? Number)?.toInt() ?: 0
        require(bitrate in listOf(0, 1000000, 2000000, 4000000, 8000000))
        val builder = DefaultEncoderFactory.Builder(context)
        if (bitrate > 0)
            builder.setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(bitrate).build(),
            )
        return builder.build()
    }

    fun build(project: Map<*, *>): Composition {
        val options = project["effects"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val speed = (options["speed"] as? Number)?.toFloat() ?: 1f
        val volume = (options["volume"] as? Number)?.toFloat() ?: 1f
        val pitch = (options["pitch"] as? Number)?.toFloat() ?: 1f
        val height = (options["height"] as? Number)?.toInt() ?: 0
        val fps = (options["fps"] as? Number)?.toInt() ?: 30
        val text = options["text"] as? String ?: ""
        val filter = options["filter"] as? String ?: "none"
        val aspect = (options["aspect"] as? Number)?.toFloat() ?: 0f
        require((options["format"] ?: "mp4") in listOf("mp4", "gif"))
        require(((options["gifFps"] as? Number)?.toInt() ?: 10) in listOf(5, 10, 20))
        require(((options["gifEdge"] as? Number)?.toInt() ?: 320) in listOf(160, 320, 480))
        require(((options["gifRepeats"] as? Number)?.toInt() ?: 0) in 0..20)
        require(aspect == 0f || aspect in .5f..2f)
        require(speed in .5f..2f && volume in 0f..2f && pitch in .5f..2f)
        require(
            height in listOf(0, 480, 720, 1080) && fps in listOf(24, 30, 60) && text.length <= 120,
        )
        require(filter in listOf("none", "grayscale", "invert"))
        val clips = project["clips"] as? List<*> ?: error("Missing clips")
        require(clips.size in 1..30) { "Choose between one and thirty clips." }
        val subtitles = (options["subtitles"] as? List<*>)?.map { it as Map<*, *> } ?: emptyList()
        require(subtitles.size <= 200)
        var previousEnd = 0L
        val totalMs = durationUs(project) / 1000
        val tracks = (options["audioTracks"] as? List<*>)?.map { it as Map<*, *> } ?: emptyList()
        require(tracks.size <= 8) { "At most eight audio tracks are supported." }
        val music = options["music"] as? String ?: ""
        val musicGain =
            if (music.isEmpty()) 0f else (options["musicVolume"] as? Number)?.toFloat() ?: .5f
        // Reserve headroom when mixing. The same gains are used by preview/export.
        val headroom =
            if (tracks.isEmpty() && music.isEmpty()) 1f
            else
                1f /
                    maxOf(
                        1f,
                        volume +
                            musicGain +
                            tracks
                                .sumOf { ((it["volume"] as? Number)?.toDouble() ?: 1.0) }
                                .toFloat(),
                    )
        subtitles.forEach { cue ->
            val start = (cue["startMs"] as Number).toLong()
            val end = (cue["endMs"] as Number).toLong()
            val content = cue["text"] as String
            SubtitleText.requireValid(content)
            require(
                start >= previousEnd &&
                    end > start &&
                    end <= totalMs &&
                    content.isNotBlank() &&
                    content.length <= 2000,
            ) {
                "Subtitles must fit the timeline without overlapping."
            }
            previousEnd = end
        }
        var timelineSourceMs = 0L
        val items = clips.map { value ->
            val clip = value as Map<*, *>
            val uri = Uri.parse(clip["mediaId"] as String)
            require(uri.scheme == "content")
            val start = (clip["inMs"] as Number).toLong()
            val end = (clip["outMs"] as Number).toLong()
            val duration = (clip["sourceDurationMs"] as Number).toLong()
            require(start >= 0 && end - start >= 200 && end <= duration && duration <= 86400000L)
            val offsetMs = (timelineSourceMs / speed).toLong()
            timelineSourceMs += end - start
            fun number(key: String, fallback: Double) =
                (clip[key] as? Number)?.toDouble() ?: fallback
            val left = number("cropLeft", 0.0)
            val top = number("cropTop", 0.0)
            val right = number("cropRight", 1.0)
            val bottom = number("cropBottom", 1.0)
            require(
                listOf(left, top, right, bottom).all { it.isFinite() && it in 0.0..1.0 } &&
                    right - left >= .02 &&
                    bottom - top >= .02,
            )
            val rotation = (clip["rotation"] as? Number)?.toInt() ?: 0
            require(rotation in listOf(0, 90, 180, 270))
            val effects = mutableListOf<Effect>()
            if (left != 0.0 || right != 1.0 || top != 0.0 || bottom != 1.0)
                effects.add(
                    Crop(
                        (2 * left - 1).toFloat(),
                        (2 * right - 1).toFloat(),
                        (1 - 2 * bottom).toFloat(),
                        (1 - 2 * top).toFloat(),
                    ),
                )
            if (rotation != 0)
                effects.add(
                    ScaleAndRotateTransformation.Builder()
                        .setRotationDegrees(rotation.toFloat())
                        .build(),
                )
            if (clip["flipH"] == true || clip["flipV"] == true)
                effects.add(
                    ScaleAndRotateTransformation.Builder()
                        .setScale(
                            if (clip["flipH"] == true) -1f else 1f,
                            if (clip["flipV"] == true) -1f else 1f,
                        )
                        .build(),
                )
            if (aspect > 0f)
                effects.add(
                    Presentation.createForAspectRatio(aspect, Presentation.LAYOUT_SCALE_TO_FIT),
                )
            if (height > 0) effects.add(Presentation.createForHeight(height))
            if (filter == "grayscale") effects.add(RgbFilter.createGrayscaleFilter())
            if (filter == "invert") effects.add(RgbFilter.createInvertedFilter())
            if (text.isNotBlank()) {
                val caption = SpannableString(text)
                caption.setSpan(
                    android.text.style.ForegroundColorSpan(android.graphics.Color.WHITE),
                    0,
                    text.length,
                    0,
                )
                caption.setSpan(
                    android.text.style.BackgroundColorSpan(0x99000000.toInt()),
                    0,
                    text.length,
                    0,
                )
                caption.setSpan(android.text.style.AbsoluteSizeSpan(32), 0, text.length, 0)
                effects.add(
                    OverlayEffect(
                        ImmutableList.of<TextureOverlay>(
                            TextOverlay.createStaticTextOverlay(caption),
                        ),
                    ),
                )
            }
            val layers = (options["layers"] as? List<*>)?.map { it as Map<*, *> } ?: emptyList()
            if (layers.isNotEmpty())
                effects.add(
                    OverlayEffect(ImmutableList.of<TextureOverlay>(EditorLayers(layers, offsetMs))),
                )
            if (subtitles.isNotEmpty()) {
                effects.add(
                    OverlayEffect(
                        ImmutableList.of<TextureOverlay>(
                            SubtitleOverlay(subtitles, offsetMs, options),
                        ),
                    ),
                )
            }
            val audio = EditorAudio.processors(options, totalMs, offsetMs, speed, headroom)
            val image = clip["isImage"] == true
            val mediaBuilder = MediaItem.Builder().setUri(uri)
            if (image) mediaBuilder.setImageDurationMs(end - start)
            else
                mediaBuilder.setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(start)
                        .setEndPositionMs(end)
                        .build(),
                )
            EditedMediaItem.Builder(mediaBuilder.build())
                .setDurationUs((if (image) end - start else duration) * 1000)
                .setFrameRate(fps)
                .setSpeed(
                    object : SpeedProvider {
                        override fun getSpeed(timeUs: Long) = speed

                        override fun getNextSpeedChangeTimeUs(timeUs: Long) = C.TIME_UNSET
                    },
                )
                .setEffects(Effects(audio, effects))
                .build()
        }
        val sequences = mutableListOf(EditedMediaItemSequence.withAudioAndVideoFrom(items))
        tracks.forEach { track ->
            val uri = Uri.parse(track["uri"] as String)
            require(uri.scheme == "content")
            fun number(key: String, default: Long = 0) =
                (track[key] as? Number)?.toLong() ?: default
            val start = number("inMs")
            val end = number("outMs")
            val offset = number("offsetMs")
            val source = number("sourceDurationMs", end)
            require(
                start >= 0 &&
                    end > start &&
                    end <= source &&
                    source <= 86400000 &&
                    offset >= 0 &&
                    offset < totalMs,
            )
            val length = minOf(end - start, totalMs - offset)
            val media =
                MediaItem.Builder()
                    .setUri(uri)
                    .setClippingConfiguration(
                        MediaItem.ClippingConfiguration.Builder()
                            .setStartPositionMs(start)
                            .setEndPositionMs(start + length)
                            .build(),
                    )
                    .build()
            val audioItem =
                EditedMediaItem.Builder(media)
                    .setDurationUs(source * 1000)
                    .setRemoveVideo(true)
                    .setEffects(
                        Effects(
                            EditorAudio.processors(track, length, headroom = headroom),
                            emptyList(),
                        ),
                    )
                    .build()
            val sequence = EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO))
            if (offset > 0) sequence.addGap(offset * 1000)
            sequence.addItem(audioItem)
            // Explicit silence holds the sequence to the video endpoint and
            // avoids changing the duration when an additional track is shorter.
            if (offset + length < totalMs) sequence.addGap((totalMs - offset - length) * 1000)
            sequences.add(sequence.build())
        }
        if (music.isNotEmpty()) {
            val uri = Uri.parse(music)
            require(uri.scheme == "content")
            val gain = (options["musicVolume"] as? Number)?.toFloat() ?: .5f
            require(gain in 0f..1f)
            val mixer =
                ChannelMixingAudioProcessor().apply {
                    for (channels in 1..6) putChannelMixingMatrix(
                        ChannelMixingMatrix.createForConstantGain(channels, channels)
                            .scaleBy(gain * headroom),
                    )
                }
            val audioItem =
                EditedMediaItem.Builder(MediaItem.fromUri(uri))
                    .setEffects(Effects(listOf(mixer), emptyList()))
                    .build()
            sequences.add(
                EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO))
                    .addItem(audioItem)
                    .setIsLooping(true)
                    .build(),
            )
        }
        val builder = Composition.Builder(sequences)
        if (tracks.isNotEmpty() || music.isNotEmpty()) {
            // Apply after the mixer, including Sonic/RNNoise drains and gaps.
            // CompositionPlayer and Transformer receive the same endpoint.
            builder.setEffects(
                Effects(listOf(TimelineAudioLimit(durationUs(project))), emptyList()),
            )
        }
        return builder.build()
    }

    fun durationUs(project: Map<*, *>): Long {
        val speed = ((project["effects"] as? Map<*, *>)?.get("speed") as? Number)?.toDouble() ?: 1.0
        return ((project["clips"] as List<*>).sumOf {
                val clip = it as Map<*, *>
                ((clip["outMs"] as Number).toLong() - (clip["inMs"] as Number).toLong()) * 1000
            } / speed)
            .toLong()
    }
}
