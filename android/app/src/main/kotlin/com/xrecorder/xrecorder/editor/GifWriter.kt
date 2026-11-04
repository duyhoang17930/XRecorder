package com.xrecorder.xrecorder.editor

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.OutputStream
import kotlin.math.roundToInt

/** Bounded GIF89a writer, RGB332 palette and fixed-width LZW runs. No third-party encoder. */
object GifWriter {
    fun write(video:File,durationUs:Long,out:OutputStream) {
        require(durationUs in 200000..15000000){"GIF export is limited to 15 seconds"}
        val reader=MediaMetadataRetriever()
        fun word(value:Int){out.write(value and 255);out.write(value shr 8 and 255)}
        try {
            reader.setDataSource(video.absolutePath)
            val first=reader.getFrameAtTime(0,MediaMetadataRetriever.OPTION_CLOSEST) ?: error("Cannot decode GIF frames")
            val scale=320.0/maxOf(first.width,first.height)
            val width=(first.width*minOf(scale,1.0)).roundToInt().coerceAtLeast(1)
            val height=(first.height*minOf(scale,1.0)).roundToInt().coerceAtLeast(1);first.recycle()
            out.write("GIF89a".toByteArray());word(width);word(height);out.write(byteArrayOf(0xf7.toByte(),0,0))
            for(i in 0..255){out.write(((i shr 5) and 7)*255/7);out.write(((i shr 2) and 7)*255/7);out.write((i and 3)*255/3)}
            out.write(byteArrayOf(0x21,0xff.toByte(),11));out.write("NETSCAPE2.0".toByteArray());out.write(byteArrayOf(3,1,0,0,0))
            var time=0L
            while(time<durationUs) {
                val frame=reader.getFrameAtTime(time,MediaMetadataRetriever.OPTION_CLOSEST) ?: error("Cannot decode GIF frame")
                val scaled=Bitmap.createScaledBitmap(frame,width,height,true)
                val pixels=IntArray(width*height);scaled.getPixels(pixels,0,width,0,0,width,height)
                if(scaled!==frame)scaled.recycle();frame.recycle()
                out.write(byteArrayOf(0x21,0xf9.toByte(),4,4));word(((minOf(100000L,durationUs-time)+9999)/10000).toInt());out.write(byteArrayOf(0,0))
                out.write(0x2c);word(0);word(0);word(width);word(height);out.write(0);out.write(8)
                val bytes=java.io.ByteArrayOutputStream();var bits=0;var count=0
                fun code(value:Int){bits=bits or (value shl count);count+=9;while(count>=8){bytes.write(bits and 255);bits=bits ushr 8;count-=8}}
                var run=0;code(256)
                for(pixel in pixels){if(run==200){code(256);run=0};code(((pixel shr 16 and 255) shr 5 shl 5) or ((pixel shr 8 and 255) shr 5 shl 2) or ((pixel and 255) shr 6));run++}
                code(257);if(count>0)bytes.write(bits and 255)
                val data=bytes.toByteArray();var offset=0
                while(offset<data.size){val size=minOf(255,data.size-offset);out.write(size);out.write(data,offset,size);offset+=size};out.write(0)
                time+=100000
            }
            out.write(0x3b)
        } finally {reader.release()}
    }
}
