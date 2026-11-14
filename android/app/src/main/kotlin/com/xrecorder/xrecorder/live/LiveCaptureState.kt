package com.xrecorder.xrecorder.live

/** The consent request's secret is memory-only and never part of a journal,
 * event, Intent, diagnostic or settings document. Process death needs new input.
 */
object LiveCaptureState {
    private var pending: Pair<String, RtmpEndpoint>? = null
    @Volatile private var owner = ""
    @Volatile private var last: Map<String, Any> = mapOf("state" to "idle")
    @Volatile private var counters: (() -> Map<String, Any>)? = null

    @Synchronized fun prepare(sessionId: String, endpoint: RtmpEndpoint?) {
        pending = endpoint?.let { sessionId to it }
        owner = sessionId
        counters = null
        last = mapOf("sessionId" to sessionId, "state" to if (endpoint == null) "idle" else "awaitingPermission")
    }

    @Synchronized fun take(sessionId: String): RtmpEndpoint? {
        if (pending?.first != sessionId) return null
        val value = pending?.second
        pending = null
        return value
    }

    fun attach(sessionId: String, value: () -> Map<String, Any>) {
        if (owner == sessionId) counters = value
    }

    fun update(sessionId: String, state: String) {
        if (owner == sessionId) last = mapOf("sessionId" to sessionId, "state" to state)
    }

    @Synchronized fun finish(sessionId: String, state: String? = null) {
        if (owner != sessionId) return
        pending = null
        val final = snapshot()
        counters = null
        last = if (state == null) final else final + ("state" to state)
    }

    fun snapshot(): Map<String, Any> = last + (counters?.invoke() ?: emptyMap())

    fun snapshotFor(sessionId: String, requested: Boolean, captureState: String): Map<String, Any> {
        val value = snapshot()
        return if (requested && value["sessionId"] != sessionId)
            mapOf("sessionId" to sessionId, "state" to if (captureState == "completed") "stopped" else "interrupted")
        else value
    }

    @Synchronized fun discardPending(sessionId: String, state: String) {
        if (pending?.first == sessionId) finish(sessionId, state)
    }
}
