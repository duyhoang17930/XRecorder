package com.xrecorder.xrecorder.editor

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.Effect
import androidx.media3.effect.Crop
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.*

/** One validated composition definition serves both native preview and export. */
object EditorComposition {
    fun build(project:Map<*,*>):Composition {
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
            val media=MediaItem.Builder().setUri(uri).setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(end).build()).build()
            EditedMediaItem.Builder(media).setDurationUs(duration*1000).setEffects(Effects(emptyList(),effects)).build()
        }
        return Composition.Builder(EditedMediaItemSequence.withAudioAndVideoFrom(items)).build()
    }
}
