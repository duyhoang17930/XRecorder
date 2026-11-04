package com.xrecorder.xrecorder.editor

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.Effect
import androidx.media3.effect.Crop
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.effect.*
import androidx.media3.common.C
import androidx.media3.common.audio.*
import android.text.SpannableString
import com.google.common.collect.ImmutableList
import androidx.media3.transformer.*

/** One validated composition definition serves both native preview and export. */
object EditorComposition {
    fun build(project:Map<*,*>):Composition {
        val options=project["effects"] as? Map<*,*> ?: emptyMap<Any,Any>()
        val speed=(options["speed"] as? Number)?.toFloat() ?: 1f
        val volume=(options["volume"] as? Number)?.toFloat() ?: 1f
        val pitch=(options["pitch"] as? Number)?.toFloat() ?: 1f
        val height=(options["height"] as? Number)?.toInt() ?: 0
        val fps=(options["fps"] as? Number)?.toInt() ?: 30
        val text=options["text"] as? String ?: ""
        val filter=options["filter"] as? String ?: "none"
        val aspect=(options["aspect"] as? Number)?.toFloat() ?: 0f
        require(aspect==0f || aspect in .5f..2f)
        require(speed in .5f..2f && volume in 0f..2f && pitch in .5f..2f)
        require(height in listOf(0,480,720,1080) && fps in listOf(24,30,60) && text.length<=120)
        require(filter in listOf("none","grayscale","invert"))
        val clips=project["clips"] as? List<*> ?: error("Missing clips")
        require(clips.size in 1..30) { "Choose between one and thirty clips." }
        val items=clips.map { value ->
            val clip=value as Map<*,*>
            val uri=Uri.parse(clip["mediaId"] as String);require(uri.scheme=="content")
            val start=(clip["inMs"] as Number).toLong();val end=(clip["outMs"] as Number).toLong();val duration=(clip["sourceDurationMs"] as Number).toLong()
            require(start>=0 && end-start>=200 && end<=duration && duration<=86400000L)
            fun number(key:String,fallback:Double)=(clip[key] as? Number)?.toDouble() ?: fallback
            val left=number("cropLeft",0.0);val top=number("cropTop",0.0);val right=number("cropRight",1.0);val bottom=number("cropBottom",1.0)
            require(listOf(left,top,right,bottom).all{it.isFinite() && it in 0.0..1.0} && right-left>=.02 && bottom-top>=.02)
            val rotation=(clip["rotation"] as? Number)?.toInt() ?: 0;require(rotation in listOf(0,90,180,270))
            val effects=mutableListOf<Effect>()
            if(left!=0.0 || right!=1.0 || top!=0.0 || bottom!=1.0) effects.add(Crop((2*left-1).toFloat(),(2*right-1).toFloat(),(1-2*bottom).toFloat(),(1-2*top).toFloat()))
            if(rotation!=0) effects.add(ScaleAndRotateTransformation.Builder().setRotationDegrees(rotation.toFloat()).build())
            if(aspect>0f)effects.add(Presentation.createForAspectRatio(aspect,Presentation.LAYOUT_SCALE_TO_FIT))
            if(height>0)effects.add(Presentation.createForHeight(height))
            if(filter=="grayscale")effects.add(RgbFilter.createGrayscaleFilter())
            if(filter=="invert")effects.add(RgbFilter.createInvertedFilter())
            if(text.isNotBlank()) {
                val caption=SpannableString(text)
                caption.setSpan(android.text.style.ForegroundColorSpan(android.graphics.Color.WHITE),0,text.length,0)
                caption.setSpan(android.text.style.BackgroundColorSpan(0x99000000.toInt()),0,text.length,0)
                caption.setSpan(android.text.style.AbsoluteSizeSpan(32),0,text.length,0)
                effects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(TextOverlay.createStaticTextOverlay(caption))))
            }
            val audio=mutableListOf<AudioProcessor>()
            if(volume!=1f)audio.add(ChannelMixingAudioProcessor().apply { for(channels in 1..6)putChannelMixingMatrix(ChannelMixingMatrix.createForConstantGain(channels,channels).scaleBy(volume)) })
            if(pitch!=1f)audio.add(SonicAudioProcessor().apply{setPitch(pitch)})
            val media=MediaItem.Builder().setUri(uri).setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(end).build()).build()
            EditedMediaItem.Builder(media).setDurationUs(duration*1000).setFrameRate(fps).setSpeed(object:SpeedProvider {
                override fun getSpeed(timeUs:Long)=speed
                override fun getNextSpeedChangeTimeUs(timeUs:Long)=C.TIME_UNSET
            }).setEffects(Effects(audio,effects)).build()
        }
        val sequences=mutableListOf(EditedMediaItemSequence.withAudioAndVideoFrom(items))
        val music=options["music"] as? String ?: ""
        if(music.isNotEmpty()) {
            val uri=Uri.parse(music);require(uri.scheme=="content")
            val gain=(options["musicVolume"] as? Number)?.toFloat() ?: .5f;require(gain in 0f..1f)
            val mixer=ChannelMixingAudioProcessor().apply{for(channels in 1..6)putChannelMixingMatrix(ChannelMixingMatrix.createForConstantGain(channels,channels).scaleBy(gain))}
            val audioItem=EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(Effects(listOf(mixer),emptyList())).build()
            sequences.add(EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO)).addItem(audioItem).setIsLooping(true).build())
        }
        return Composition.Builder(sequences).build()
    }
    fun durationUs(project:Map<*,*>):Long {
        val speed=((project["effects"] as? Map<*,*>)?.get("speed") as? Number)?.toDouble() ?: 1.0
        return ((project["clips"] as List<*>).sumOf { val clip=it as Map<*,*>;((clip["outMs"] as Number).toLong()-(clip["inMs"] as Number).toLong())*1000 } / speed).toLong()
    }
}
