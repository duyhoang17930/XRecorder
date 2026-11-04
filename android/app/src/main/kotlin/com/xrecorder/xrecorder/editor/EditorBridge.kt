package com.xrecorder.xrecorder.editor

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.*
import com.xrecorder.xrecorder.recording.MediaOutput
import io.flutter.plugin.common.*
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class EditorBridge(private val context:Context):MethodChannel.MethodCallHandler {
    private val worker=Executors.newSingleThreadExecutor()
    private val main=Handler(Looper.getMainLooper())
    private val directory=File(context.filesDir,"projects").apply{mkdirs()}
    private var probe:Transformer?=null
    private var probeResult:MethodChannel.Result?=null
    private val exports by lazy { ExportQueue.get(context) }
    private fun file(id:String):File { require(id.matches(Regex("[a-zA-Z0-9_-]{1,80}")));return File(directory,"$id.json") }
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
        if(call.method.startsWith("export")) {
            try {
                val value:Any?=when(call.method) {
                    "exportList" -> exports.list()
                    "exportStart" -> exports.enqueue(call.arguments as Map<*,*>)
                    "exportCancel" -> {exports.cancel(call.arguments as String);null}
                    "exportRetry" -> {exports.retry(call.arguments as String);null}
                    else -> {result.notImplemented();return}
                }
                result.success(value)
            }catch(e:Exception){result.error("export",e.message,null)}
            return
        }
        if(call.method=="engineProbe") { probe(call.arguments as Map<*,*>,result);return }
        worker.execute {
            try {
                val value:Any?=when(call.method) {
                    "list" -> directory.listFiles()?.filter{it.extension=="json"}?.sortedByDescending{it.lastModified()}?.map{AtomicFile(it).openRead().use{input->input.readBytes().toString(Charsets.UTF_8)}} ?: emptyList<String>()
                    "find" -> { val source=file(call.arguments as String);if(source.exists()) AtomicFile(source).openRead().use{it.readBytes().toString(Charsets.UTF_8)} else null }
                    "save" -> {
                        val document=call.arguments as String;require(document.length<=1048576)
                        val json=JSONObject(document);require(json.getInt("version")==1 && json.getJSONArray("clips").length()<=30)
                        val target=AtomicFile(file(json.getString("id")));val out=target.startWrite()
                        try { out.write(document.toByteArray(Charsets.UTF_8));target.finishWrite(out) } catch(e:Exception){target.failWrite(out);throw e};null
                    }
                    "delete" -> { AtomicFile(file(call.arguments as String)).delete();null }
                    else -> { main.post{result.notImplemented()};return@execute }
                }
                main.post{result.success(value)}
            } catch(e:Exception) { main.post{result.error("draft_io",e.message ?: "Draft could not be saved or loaded",null)} }
        }
    }
    private fun probe(project:Map<*,*>,result:MethodChannel.Result) {
        if(probe!=null) { result.error("busy","An engine verification is running",null);return }
        val temporary=File(context.cacheDir,"editor_probe_${System.currentTimeMillis()}.mp4")
        try {
            val composition=EditorComposition.build(project)
            probeResult=result
            probe=Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object:Transformer.Listener {
                    override fun onCompleted(composition:Composition,exportResult:ExportResult) {
                        worker.execute {
                            val output=MediaOutput(context,"Editor_probe_${System.currentTimeMillis()}.mp4")
                            try {
                                require(exportResult.durationMs>0 && temporary.length()>0)
                                val fd=output.open()
                                val durationUs=EditorComposition.durationUs(project)
                                com.xrecorder.xrecorder.recording.RecordingMuxer.combine(temporary,temporary,output,fd,0,durationUs)
                                val uri=output.commit().toString()
                                main.post{probe=null;probeResult?.success(uri);probeResult=null}
                            } catch(e:Exception) { output.abort();main.post{probe=null;probeResult?.error("export_failed",e.message,null);probeResult=null} }
                            finally { temporary.delete() }
                        }
                    }
                    override fun onError(composition:Composition,exportResult:ExportResult,exception:ExportException) {
                        temporary.delete();probe=null;probeResult?.error("export_failed",exception.message,null);probeResult=null
                    }
                }).build()
            probe!!.start(composition,temporary.absolutePath)
        } catch(e:Exception) { temporary.delete();probe=null;probeResult=null;result.error("editor_engine",e.message,null) }
    }
    fun dispose() { probe?.cancel();probe=null;probeResult?.error("interrupted","Editor closed during verification",null);probeResult=null;worker.shutdown() }
}
