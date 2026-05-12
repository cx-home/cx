package cx

import com.sun.jna.Pointer
import com.sun.jna.ptr.PointerByReference
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Pull-based iterator over CX streaming events backed by the
 * cx_events_open / cx_events_next / cx_events_close handle API.
 * Replaces the prior eager-buffered cx_to_events_bin path
 * (Phase 5 / CB-4).
 *
 * Usage:
 *   EventStream.open(cxStr).use { s ->
 *       for (ev in s) {
 *           if (ev.type == "StartElement") ...
 *       }
 *   }
 */
class EventStream private constructor(private var handle: Pointer?) :
    Iterable<StreamEvent>, AutoCloseable {

    private var closed = false

    companion object {
        /** Open a streaming handle for the given CX input. */
        fun open(cxStr: String): EventStream {
            val errRef = PointerByReference()
            val h = CxLib.eventsOpen(cxStr, errRef)
            if (h == null) {
                val ep = errRef.value
                val msg = ep?.getString(0) ?: "cx_events_open: unknown error"
                if (ep != null) CxLib.cxFree(ep)
                throw RuntimeException(msg)
            }
            return EventStream(h)
        }
    }

    /** Pull the next event, or null on EOF. */
    fun next(): StreamEvent? {
        if (closed || handle == null) return null
        val errRef = PointerByReference()
        val raw = CxLib.eventsNext(handle!!, errRef)
        if (raw == null) {
            // NULL with err = error; NULL with no err = EOF.
            val ep = errRef.value
            if (ep != null) {
                val msg = ep.getString(0)
                CxLib.cxFree(ep)
                close()
                throw RuntimeException(msg)
            }
            close()
            return null
        }
        val sizeBytes = raw.getByteArray(0, 4)
        val size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).int
        val payload = raw.getByteArray(4, size)
        CxLib.cxFree(raw)
        return BinaryDecoder.decodeOneEvent(payload)
    }

    override fun close() {
        if (closed) return
        closed = true
        handle?.let { CxLib.eventsClose(it) }
        handle = null
    }

    override fun iterator(): Iterator<StreamEvent> = object : Iterator<StreamEvent> {
        private var peeked: StreamEvent? = null
        private var prefetched = false

        override fun hasNext(): Boolean {
            if (!prefetched) {
                peeked = this@EventStream.next()
                prefetched = true
            }
            return peeked != null
        }

        override fun next(): StreamEvent {
            if (!hasNext()) throw NoSuchElementException()
            val ev = peeked!!
            peeked = null
            prefetched = false
            return ev
        }
    }
}
