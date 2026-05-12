package cx;

import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Streaming event writer (spec/streaming.md §6 + ADR 0011 +
 * spec/abi.md §2.15, capability bit 27). Thin wrapper around the 25
 * cx_events_writer_* C ABI symbols.
 *
 * <p>v0.6.0 implements CX and XML output formats end-to-end; json /
 * yaml / toml / md emits surface a W009 RuntimeException until their
 * follow-up phases land. The 25-symbol C ABI surface is locked at the
 * v0.6.0 boundary.
 *
 * <p>Errors throw {@link RuntimeException} carrying the W001-W013
 * prefix verbatim. The writer fails closed — once a W-code is raised,
 * subsequent emits throw the same diagnostic without effect.
 *
 * <p>Implements {@link AutoCloseable} for use with try-with-resources.
 *
 * <pre>
 * try (EventWriter w = new EventWriter("cx")) {
 *     w.startDoc();
 *     w.startElement("greet");
 *     w.text("hello");
 *     w.endElement("greet");
 *     w.endDoc();
 *     byte[] out = w.closeGetBytes();
 * }
 * </pre>
 */
public final class EventWriter implements AutoCloseable {

    private static final long CAP_BIT_STREAMING_WRITE = 1L << 27;

    private Pointer handle;
    private boolean closed;
    private final boolean fdMode;

    /** One start-element attribute. {@code dataType} empty defaults to {@code "string"}. */
    public static final class Attr {
        public final String name;
        public final String value;
        public final String dataType;
        public Attr(String name, String value)                   { this(name, value, ""); }
        public Attr(String name, String value, String dataType) {
            this.name = name; this.value = value; this.dataType = dataType == null ? "" : dataType;
        }
    }

    /** Open an in-memory writer for the given output format. */
    public EventWriter(String outputFormat) {
        if ((CxLib.features() & CAP_BIT_STREAMING_WRITE) == 0) {
            throw new RuntimeException(
                "cx.EventWriter requires libcx capability bit 27 (streaming-write; v0.6.0+).");
        }
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.eventsWriterOpen(outputFormat, err);
        if (h == null) {
            Pointer ep = err.getValue();
            String msg = (ep != null) ? ep.getString(0) : "cx_events_writer_open: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        this.handle = h;
        this.fdMode = false;
    }

    private EventWriter(Pointer h, boolean fdMode) { this.handle = h; this.fdMode = fdMode; }

    /** Open an fd-streaming writer. Caller retains fd ownership. */
    public static EventWriter toFd(String outputFormat, int fd) {
        if ((CxLib.features() & CAP_BIT_STREAMING_WRITE) == 0) {
            throw new RuntimeException(
                "cx.EventWriter.toFd requires libcx capability bit 27 (streaming-write; v0.6.0+).");
        }
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.eventsWriterOpenFd(outputFormat, fd, err);
        if (h == null) {
            Pointer ep = err.getValue();
            String msg = (ep != null) ? ep.getString(0) : "cx_events_writer_open_fd: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        return new EventWriter(h, true);
    }

    /** Whether libcx advertises capability bit 27 (streaming-write). */
    public static boolean hasCapability() {
        return (CxLib.features() & CAP_BIT_STREAMING_WRITE) != 0;
    }

    private Pointer live(String op) {
        if (closed || handle == null) {
            throw new IllegalStateException("EventWriter." + op + ": handle closed");
        }
        return handle;
    }

    private static void throwIfDiag(Pointer ret, Pointer errPtr, String op) {
        if (ret != null) {
            String msg = ret.getString(0);
            CxLib.cxFree(ret);
            if (errPtr != null) CxLib.cxFree(errPtr);
            throw new RuntimeException(msg);
        }
        if (errPtr != null) {
            String msg = errPtr.getString(0);
            CxLib.cxFree(errPtr);
            throw new RuntimeException(msg);
        }
    }

    /**
     * Finalise the writer and return the accumulated output bytes. For
     * fd writers the returned array is empty (output already flushed).
     * Implicitly emits EndDoc — throws W004 if elements / table remain
     * open. Consumes the writer.
     */
    public byte[] closeGetBytes() {
        Pointer h = live("closeGetBytes");
        PointerByReference err = new PointerByReference();
        Pointer raw = CxLib.eventsWriterCloseGetBytes(h, err);
        Pointer old = handle;
        handle = null;
        closed = true;
        if (raw == null) {
            CxLib.eventsWriterClose(old);
            Pointer ep = err.getValue();
            String msg = (ep != null) ? ep.getString(0) : "cx_events_writer_close_get_bytes: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        byte[] sizeBytes = raw.getByteArray(0, 4);
        int size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] payload = size == 0 ? new byte[0] : raw.getByteArray(4, size);
        CxLib.cxFree(raw);
        CxLib.eventsWriterClose(old);
        // suppress unused warning on fdMode
        if (fdMode && payload.length != 0) {
            // fd writers return empty; this branch shouldn't trip in practice
        }
        return payload;
    }

    /** Release the handle without finalising output. Idempotent. */
    @Override
    public void close() {
        if (closed) return;
        closed = true;
        if (handle != null) {
            CxLib.eventsWriterClose(handle);
            handle = null;
        }
    }

    // ── lifecycle emits ─────────────────────────────────────────────────────

    public void startDoc() {
        Pointer h = live("startDoc");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterStartDoc(h, err);
        throwIfDiag(ret, err.getValue(), "start_doc");
    }

    public void endDoc() {
        Pointer h = live("endDoc");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterEndDoc(h, err);
        throwIfDiag(ret, err.getValue(), "end_doc");
    }

    /** Emit a StartElement with no anchor / data_type / merge / attrs. */
    public void startElement(String name) {
        startElement(name, null, null, null, null);
    }

    /**
     * Emit a StartElement. Any of {@code anchor}, {@code dataType},
     * {@code merge} may be null (absent). {@code attrs} may be null
     * or empty.
     */
    public void startElement(String name, String anchor, String dataType,
                             String merge, List<Attr> attrs) {
        Pointer h = live("startElement");
        byte[] framed = null;
        if (attrs != null && !attrs.isEmpty()) {
            byte[] raw = encodeAttrsPayload(attrs);
            framed = frame(raw);
        }
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterStartElementWithLen(
            h, name, anchor, dataType, merge,
            framed, framed == null ? 0L : (long) framed.length,
            err);
        throwIfDiag(ret, err.getValue(), "start_element");
    }

    public void endElement(String name) {
        Pointer h = live("endElement");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterEndElement(h, name, err);
        throwIfDiag(ret, err.getValue(), "end_element");
    }

    public void text(String value) {
        Pointer h = live("text");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterText(h, value, err);
        throwIfDiag(ret, err.getValue(), "text");
    }

    /** Emit a typed scalar. {@code dataType} empty defaults to {@code "string"}. */
    public void scalar(String value, String dataType) {
        Pointer h = live("scalar");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterScalar(h,
            (dataType == null || dataType.isEmpty()) ? null : dataType, value, err);
        throwIfDiag(ret, err.getValue(), "scalar");
    }

    public void comment(String value) {
        Pointer h = live("comment");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterComment(h, value, err);
        throwIfDiag(ret, err.getValue(), "comment");
    }

    public void pi(String target, String data) {
        Pointer h = live("pi");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterPi(h, target,
            (data == null || data.isEmpty()) ? null : data, err);
        throwIfDiag(ret, err.getValue(), "pi");
    }

    public void entityRef(String name) {
        Pointer h = live("entityRef");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterEntityRef(h, name, err);
        throwIfDiag(ret, err.getValue(), "entity_ref");
    }

    public void rawText(String value) {
        Pointer h = live("rawText");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterRawText(h, value, err);
        throwIfDiag(ret, err.getValue(), "raw_text");
    }

    public void alias(String name) {
        Pointer h = live("alias");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterAlias(h, name, err);
        throwIfDiag(ret, err.getValue(), "alias");
    }

    /**
     * Open a chunked table. {@code colSpecPayload} is the unframed column-
     * spec wire form per spec/data_bin.md §3.10.1:
     * {@code [u32 LE count] ([u32 LE name_len] name [u8 type_code])*}.
     */
    public void startTable(byte[] colSpecPayload) {
        Pointer h = live("startTable");
        byte[] framed = frame(colSpecPayload);
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterStartTableWithLen(h, framed, (long) framed.length, err);
        throwIfDiag(ret, err.getValue(), "start_table");
    }

    /**
     * Append a row group. {@code payload} is the unframed §3.11.2 plain
     * body: {@code uvarint(row_count) + col-payload[col_count]}.
     */
    public void rowGroup(byte[] payload) {
        Pointer h = live("rowGroup");
        byte[] framed = frame(payload);
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterRowGroupWithLen(h, framed, (long) framed.length, err);
        throwIfDiag(ret, err.getValue(), "row_group");
    }

    public void endTable() {
        Pointer h = live("endTable");
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.eventsWriterEndTable(h, err);
        throwIfDiag(ret, err.getValue(), "end_table");
    }

    // ── helpers ────────────────────────────────────────────────────────────

    private static byte[] frame(byte[] payload) {
        ByteBuffer bb = ByteBuffer.allocate(4 + payload.length).order(ByteOrder.LITTLE_ENDIAN);
        bb.putInt(payload.length);
        bb.put(payload);
        return bb.array();
    }

    private static byte[] encodeAttrsPayload(List<Attr> attrs) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(attrs.size() & 0xFF);
        out.write((attrs.size() >> 8) & 0xFF);
        for (Attr a : attrs) {
            String typ = a.dataType.isEmpty() ? "string" : a.dataType;
            encLp(out, a.name);
            encLp(out, a.value);
            encLp(out, typ);
            out.write(0); // is_ref
        }
        return out.toByteArray();
    }

    private static void encLp(ByteArrayOutputStream out, String s) {
        byte[] b = s.getBytes(StandardCharsets.UTF_8);
        out.write(b.length & 0xFF);
        out.write((b.length >> 8)  & 0xFF);
        out.write((b.length >> 16) & 0xFF);
        out.write((b.length >> 24) & 0xFF);
        try { out.write(b); } catch (java.io.IOException e) { throw new RuntimeException(e); }
    }
}
