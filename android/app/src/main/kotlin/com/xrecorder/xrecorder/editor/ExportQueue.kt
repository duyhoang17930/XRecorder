package com.xrecorder.xrecorder.editor

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.AtomicFile
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.*
import com.xrecorder.xrecorder.recording.MediaOutput
import com.xrecorder.xrecorder.recording.RecordingMuxer
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Durable snapshots; interrupted jobs require explicit retry, never report success. */
class ExportQueue(private val context: Context) {
    companion object {
        private var instance:ExportQueue?=null
        fun get(context:Context):ExportQueue=instance ?: ExportQueue(context.applicationContext).also{instance=it}
    }
    private val main=Handler(Looper.getMainLooper())
    private val worker=Executors.newSingleThreadExecutor()
    private val journal=AtomicFile(File(context.filesDir,"export_jobs.json"))
    private val jobs=mutableListOf<JSONObject>()
    private var transformer:Transformer?=null
    private var active:JSONObject?=null
    private var closed=false
    init {
        if(journal.baseFile.exists()) {
            val array=JSONArray(journal.openRead().use{it.readBytes().toString(Charsets.UTF_8)})
            for(i in 0 until array.length()) jobs.add(array.getJSONObject(i))
        }
        jobs.filter{it.getString("state") in listOf("running","queued","finalizing")}.forEach {
            val pending=it.optString("pending")
            if(pending.startsWith("content://media/")) {
                val uri=Uri.parse(pending)
                context.contentResolver.query(uri,arrayOf(MediaStore.MediaColumns.IS_PENDING,MediaStore.MediaColumns.OWNER_PACKAGE_NAME),null,null,null)?.use{cursor->
                    if(cursor.moveToFirst() && cursor.getString(1)==context.packageName) {
                        if(cursor.getInt(0)==1) context.contentResolver.delete(uri,null,null)
                        else { it.put("state","completed");it.put("uri",pending) }
                    }
                }
            }
            if(it.getString("state")!="completed") { it.put("state","failed");it.put("error","Export interrupted. Keep the app open and retry.") }
            temporary(it).delete()
        }
        persist()
    }
    private fun temporary(job:JSONObject)=File(context.cacheDir,"export_${job.getString("id")}.mp4")
    @Synchronized private fun persist() {
        val stream=journal.startWrite()
        try { stream.write(JSONArray(jobs).toString().toByteArray());journal.finishWrite(stream) }
        catch(e:Exception){journal.failWrite(stream);throw e}
    }
    fun list():String {
        val holder=ProgressHolder()
        if(transformer?.getProgress(holder)==Transformer.PROGRESS_STATE_AVAILABLE) active?.put("progress",holder.progress)
        return JSONArray(jobs).toString()
    }
    fun enqueue(project:Map<*,*>):String {
        EditorComposition.build(project)
        if((project["effects"] as? Map<*,*>)?.get("format")=="gif") require(EditorComposition.durationUs(project)<=15000000){"GIF export is limited to 15 seconds"}
        require(jobs.count{it.getString("state") in listOf("queued","running","finalizing")}<10){"The export queue is full"}
        val job=JSONObject().put("id",UUID.randomUUID().toString()).put("project",JSONObject(project)).put("state","queued").put("progress",0)
        jobs.add(job);persist();main.post{next()};return job.getString("id")
    }
    fun cancel(id:String) {
        val job=jobs.first{it.getString("id")==id}
        require(job.getString("state")!="finalizing"){"The finished file is being saved"}
        if(job.getString("state") !in listOf("queued","running")) return
        if(active===job){transformer?.cancel();transformer=null;active=null}
        temporary(job).delete();job.put("state","cancelled");persist();next()
    }
    fun retry(id:String) {
        val job=jobs.first{it.getString("id")==id}
        require(job.getString("state") in listOf("failed","cancelled"))
        job.put("state","queued").put("progress",0).remove("error");persist();main.post{next()}
    }
    private fun map(json:JSONObject):Map<String,Any?> = json.keys().asSequence().associateWith{key->convert(json.get(key))}
    private fun convert(value:Any?):Any?=when(value){ is JSONObject->map(value);is JSONArray->(0 until value.length()).map{convert(value.get(it))};JSONObject.NULL->null;else->value }
    private fun next() {
        if(closed || active!=null) return
        val job=jobs.firstOrNull{it.getString("state")=="queued"} ?: return
        active=job;job.put("state","running");persist()
        try {
            val project=map(job.getJSONObject("project"))
            val composition=EditorComposition.build(project)
            transformer=Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object:Transformer.Listener {
                    override fun onError(composition:Composition,result:ExportResult,exception:ExportException){finish(job,"failed",exception.message)}
                    override fun onCompleted(composition:Composition,result:ExportResult) {
                        transformer=null;job.put("state","finalizing");persist()
                        worker.execute {
                            val gif=(project["effects"] as? Map<*,*>)?.get("format")=="gif"
                            val output=MediaOutput(context,"Edited_${job.getString("id")}.${if(gif)"gif" else "mp4"}",if(gif)"image/gif" else "video/mp4",onPending={uri->
                                val saved=java.util.concurrent.CompletableFuture<Unit>()
                                main.post { try{job.put("pending",uri.toString());persist();saved.complete(Unit)}catch(e:Exception){saved.completeExceptionally(e)} }
                                saved.get()
                            })
                            try {
                                require(result.durationMs>0 && temporary(job).length()>0)
                                val durationUs=EditorComposition.durationUs(project)
                                if(gif) {
                                    val fd=output.open()
                                    android.os.ParcelFileDescriptor.AutoCloseOutputStream(android.os.ParcelFileDescriptor.dup(fd.fileDescriptor)).use{GifWriter.write(temporary(job),durationUs,it)}
                                } else RecordingMuxer.combine(temporary(job),temporary(job),output,output.open(),0,durationUs)
                                val uri=output.commit().toString()
                                main.post{job.put("uri",uri);finish(job,"completed",null)}
                            } catch(e:Exception) { try{output.abort()}catch(_:Exception){};main.post{finish(job,"failed",e.message)} }
                        }
                    }
                }).build()
            transformer!!.start(composition,temporary(job).absolutePath)
        } catch(e:Exception){finish(job,"failed",e.message)}
    }
    private fun finish(job:JSONObject,state:String,error:String?) {
        temporary(job).delete();job.put("state",state);job.put("progress",if(state=="completed")100 else 0)
        if(error!=null)job.put("error",error)
        persist();transformer=null;active=null;next()
    }
    fun close() {
        closed=true
        active?.takeIf{it.getString("state")=="running"}?.let { transformer?.cancel();finish(it,"failed","Export interrupted. Retry with the app open.") }
        worker.shutdown()
    }
}
