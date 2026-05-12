package cx;

import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Iterator;

/**
 * Pull-based iterator over CX streaming events backed by the
 * cx_events_open / cx_events_next / cx_events_close handle API.
 * Replaces the prior eager-buffered cx_to_events_bin path
 * (Phase 5 / CB-4).
 *
 * <p>Usage:
 * <pre>
 *   try (EventStream s = EventStream.open(cxStr)) {
 *       for (StreamEvent ev : s) {
 *           if ("StartElement".equals(ev.type)) ...
 *       }
 *   }
 * </pre>
 */
public final class EventStream implements Iterable<StreamEvent>, AutoCloseable {

    private Pointer handle;
    private boolean closed = false;

    private EventStream(Pointer handle) {
        this.handle = handle;
    }

    /** Open a streaming handle for the given CX input. */
    public static EventStream open(String cxStr) {
        PointerByReference errRef = new PointerByReference();
        Pointer h = CxLib.eventsOpen(cxStr, errRef);
        if (h == null) {
            Pointer ep  = errRef.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_events_open: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        return new EventStream(h);
    }

    /** Pull the next event, or null on EOF. */
    public StreamEvent next() {
        if (closed || handle == null) return null;
        PointerByReference errRef = new PointerByReference();
        Pointer raw = CxLib.eventsNext(handle, errRef);
        if (raw == null) {
            // NULL with err = error; NULL with no err = EOF.
            Pointer ep = errRef.getValue();
            if (ep != null) {
                String msg = ep.getString(0);
                CxLib.cxFree(ep);
                close();
                throw new RuntimeException(msg);
            }
            close();
            return null;
        }
        // Read framed [u32 size][payload] from the C-owned buffer.
        byte[] sizeBytes = raw.getByteArray(0, 4);
        int size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] payload = raw.getByteArray(4, size);
        CxLib.cxFree(raw);
        return BinaryDecoder.decodeOneEvent(payload);
    }

    @Override
    public void close() {
        if (closed) return;
        closed = true;
        if (handle != null) {
            CxLib.eventsClose(handle);
            handle = null;
        }
    }

    @Override
    public Iterator<StreamEvent> iterator() {
        return new Iterator<>() {
            private StreamEvent peeked;
            private boolean prefetched = false;

            @Override
            public boolean hasNext() {
                if (!prefetched) {
                    peeked = EventStream.this.next();
                    prefetched = true;
                }
                return peeked != null;
            }

            @Override
            public StreamEvent next() {
                if (!hasNext()) throw new java.util.NoSuchElementException();
                StreamEvent ev = peeked;
                peeked = null;
                prefetched = false;
                return ev;
            }
        };
    }
}
