package com.xrecorder.xrecorder

import android.app.Activity
import android.content.Intent
import android.content.ClipData
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SupportBridge(private val activity:Activity):MethodChannel.MethodCallHandler {
    private var picker:MethodChannel.Result?=null
    private fun attachment(uri:Uri):String {
        require(uri.scheme=="content")
        val mime=activity.contentResolver.getType(uri) ?: error("Unknown attachment type")
        require(mime.startsWith("image/") || mime.startsWith("video/")){"Choose an image or video"}
        activity.contentResolver.openFileDescriptor(uri,"r")!!.use{require(it.statSize in 1..25L*1024*1024){"Choose a local attachment up to 25 MB with a known size"}}
        return mime
    }
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
        try {
            when(call.method) {
                "diagnostics" -> {
                    val info=activity.packageManager.getPackageInfo(activity.packageName,0)
                    result.success("App: ${info.versionName}\nAndroid API: ${Build.VERSION.SDK_INT}\nDevice: ${Build.MANUFACTURER} ${Build.MODEL}\nABI: ${Build.SUPPORTED_ABIS.firstOrNull()}");return
                }
                "pickAttachment" -> {
                    require(picker==null){"An attachment picker is already open"};picker=result
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").putExtra(Intent.EXTRA_MIME_TYPES,arrayOf("image/*","video/*")).addCategory(Intent.CATEGORY_OPENABLE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),704)
                    return
                }
                "share" -> {
                    val text=call.argument<String>("text") ?: "";require(text.isNotBlank() && text.length<=12000)
                    val uri=call.argument<String>("attachment")?.let{Uri.parse(it)}
                    val intent=Intent(Intent.ACTION_SEND).setType(if(uri==null)"text/plain" else attachment(uri)).putExtra(Intent.EXTRA_SUBJECT,"XRecorder support report").putExtra(Intent.EXTRA_TEXT,text)
                    if(uri!=null){intent.putExtra(Intent.EXTRA_STREAM,uri);intent.clipData=ClipData.newUri(activity.contentResolver,"Selected attachment",uri);intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)}
                    activity.startActivity(Intent.createChooser(intent,"Share support report"))
                }
                "openIssues" -> activity.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://github.com/duyhoang17930/XRecorder/issues")))
                else -> {result.notImplemented();return}
            }
            result.success(null)
        }catch(e:Exception){if(call.method=="pickAttachment")picker=null;result.error("support",e.message ?: "Could not open support action",null)}
    }
    fun onActivityResult(request:Int,code:Int,data:Intent?):Boolean {
        if(request!=704)return false
        val result=picker ?: return true;picker=null
        if(code!=Activity.RESULT_OK || data?.data==null){result.success(null);return true}
        try {val uri=data.data!!;attachment(uri);result.success(uri.toString())}catch(e:Exception){result.error("attachment",e.message,null)}
        return true
    }
    fun dispose(){picker?.error("cancelled","Attachment selection interrupted",null);picker=null}
}
