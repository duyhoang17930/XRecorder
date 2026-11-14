package com.xrecorder.xrecorder.live

import org.junit.Assert.*
import org.junit.Test

class RtmpEndpointTest {
    @Test fun localAndSecureServersKeepTheirExplicitEndpoint() {
        val local = RtmpEndpoint.parse("rtmp://10.0.2.2:19350/live/", "fixture-key")
        assertEquals("rtmp://10.0.2.2:19350/live/fixture-key", local.publishUrl)
        assertFalse(local.secure)
        val secure = RtmpEndpoint.parse("rtmps://example.com:443/app", "secret?token=123")
        assertTrue(secure.secure)
        assertEquals("example.com", secure.host)
        assertFalse(secure.toString().contains("secret"))
        assertFalse(secure.toString().contains("123"))
    }

    @Test fun malformedServerNeverLeaksSuppliedCredentials() {
        for (server in listOf("https://example.com/live", "rtmp://example.com", "rtmp://name:secret@example.com/live", "rtmp://example.com:0/live", "rtmp://example.com:65536/live", "rtmp://example.com/live?secret=1", "rtmp://example.com/live#secret")) {
            val error = runCatching { RtmpEndpoint.parse(server, "private-key") }.exceptionOrNull()
            assertTrue(error is IllegalArgumentException)
            assertFalse(error!!.message.orEmpty().contains("secret"))
            assertFalse(error.message.orEmpty().contains("private-key"))
        }
    }

    @Test fun malformedKeyIsRejectedWithoutEchoingIt() {
        for (key in listOf("", "bad secret", "secret#fragment", "bad%secret", "secret\nembedded", "secret".repeat(400))) {
            val error = runCatching { RtmpEndpoint.parse("rtmps://example.com/app", key) }.exceptionOrNull()
            assertTrue(error is IllegalArgumentException)
            assertFalse(error!!.message.orEmpty().contains("secret"))
        }
    }
}
