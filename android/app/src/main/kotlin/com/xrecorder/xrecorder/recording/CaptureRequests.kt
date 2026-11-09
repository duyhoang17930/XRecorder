package com.xrecorder.xrecorder.recording

/** Main-looper request ownership; survives Activity recreation, never stores consent. */
object CaptureRequests {
    private var pending: Pair<Int, String>? = null
    val awaitingResult: Boolean get() = pending != null

    fun launch(code: Int, sessionId: String) {
        check(pending == null) { "An Android permission result is still pending" }
        pending = code to sessionId
    }

    fun launchOnce(code: Int, sessionId: String, action: () -> Unit): Boolean {
        if (pending == (code to sessionId)) return false
        launch(code, sessionId)
        try { action() }
        catch (e: Exception) { consumeFor(code, sessionId); throw e }
        return true
    }

    fun consumeFor(code: Int, receiverSession: String?, receiverActive: Boolean = true, cancelledSession: String? = null): String? {
        val request = pending ?: return null
        if (!receiverActive || !owns(receiverSession ?: cancelledSession, request.second)) return null
        return consume(code)
    }

    fun consume(code: Int): String? {
        val request = pending ?: return null
        if (request.first != code) return null
        pending = null
        return request.second
    }

    fun owns(commandId: String?, sessionId: String): Boolean =
        commandId != null && commandId.isNotEmpty() && commandId == sessionId
}
