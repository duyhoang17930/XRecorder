package com.xrecorder.xrecorder.live

import java.net.URI

/** Secret stays in memory; neither toString nor validation failures echo it. */
class RtmpEndpoint private constructor(
    internal val publishUrl: String,
    val host: String,
    val secure: Boolean,
) {
    override fun toString() = "RtmpEndpoint(host=$host, secure=$secure, key=hidden)"

    companion object {
        fun parse(server: String, streamKey: String): RtmpEndpoint {
            val uri = try { URI(server.trim()) } catch (_: Exception) {
                throw IllegalArgumentException("Enter a valid RTMP or RTMPS server URL.")
            }
            require(uri.scheme in listOf("rtmp", "rtmps") && !uri.host.isNullOrBlank() &&
                uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
                (uri.port == -1 || uri.port in 1..65535) &&
                !uri.rawPath.isNullOrBlank() && uri.rawPath.trim('/') != "") {
                "Enter a server URL with an application path and no credentials."
            }
            val key = streamKey.trim()
            require(key.length in 1..2048 && key.all { it.code in 33..126 && it != '#' }) {
                "Enter a valid stream key without spaces."
            }
            val publish = server.trim().trimEnd('/') + "/" + key
            val checked = try { URI(publish) } catch (_: Exception) {
                throw IllegalArgumentException("Enter a valid stream key.")
            }
            require(checked.host == uri.host && checked.rawFragment == null) {
                "Enter a valid stream key."
            }
            return RtmpEndpoint(publish, uri.host, uri.scheme == "rtmps")
        }
    }
}
