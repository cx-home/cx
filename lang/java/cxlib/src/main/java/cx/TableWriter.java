package cx;

import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Streaming writer for the chunked-table CXDB format
 * (Phase 7.74a; spec/abi.md §2.10, ADR 0015 D8).
 *
 * <p>The col-spec payload is the framed ast_bin shape returned by
 * {@link TableReader#schema()}. In-memory writers are completed via
 * {@link #closeGetBytes()}, which returns the full framed
 * chunked-table buffer; fd writers are completed via {@link #close()},
 * which flushes the end-of-table marker.
 *
 * <p>Implements {@link AutoCloseable} for use with try-with-resources.
 */
public final class TableWriter implements AutoCloseable {
    private Pointer handle;
    private boolean closed;
    private final boolean isFd;

    /** Open an in-memory writer; complete with {@link #closeGetBytes()}. */
    public TableWriter(byte[] colSpecPayload) {
        if (colSpecPayload == null || colSpecPayload.length == 0) {
            throw new RuntimeException("cx_table_writer_open: empty col_spec_payload");
        }
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.tableWriterOpen(colSpecPayload, err);
        if (h == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_writer_open: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        this.handle = h;
        this.isFd = false;
    }

    /** Open a streaming-fd writer; complete with {@link #close()}. */
    public static TableWriter toFd(byte[] colSpecPayload, int fd) {
        if (colSpecPayload == null || colSpecPayload.length == 0) {
            throw new RuntimeException("cx_table_writer_open_fd: empty col_spec_payload");
        }
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.tableWriterOpenFd(colSpecPayload, fd, err);
        if (h == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_writer_open_fd: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        return new TableWriter(h);
    }

    private TableWriter(Pointer h) {
        this.handle = h;
        this.isFd = true;
    }

    /** Append one row group. {@code rowGroupPayload} is the framed
     *  {@code [u32 LE size][plain body]} shape yielded by
     *  {@link TableReader#next()}. */
    public void emit(byte[] rowGroupPayload) {
        if (closed || handle == null) {
            throw new IllegalStateException("TableWriter: handle closed");
        }
        PointerByReference err = new PointerByReference();
        Pointer ret = CxLib.tableWriterEmitRowGroup(handle, rowGroupPayload, err);
        // Convention: return char* is unused on success; non-null err means failure.
        Pointer ep = err.getValue();
        if (ep != null) {
            String msg = ep.getString(0);
            CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        if (ret != null) CxLib.cxFree(ret);
    }

    /** In-memory writers only: emit end-of-table and return the complete
     *  framed chunked-table buffer. */
    public byte[] closeGetBytes() {
        if (isFd) {
            throw new IllegalStateException(
                "closeGetBytes is for in-memory writers; use close() for fd writers");
        }
        if (closed || handle == null) {
            throw new IllegalStateException("TableWriter: handle closed");
        }
        PointerByReference err = new PointerByReference();
        Pointer ptr = CxLib.tableWriterCloseGetBytes(handle, err);
        // V core releases the handle inside close_get_bytes; mark closed.
        handle = null;
        closed = true;
        if (ptr == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_writer_close_get_bytes: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        byte[] sizeBytes = ptr.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        byte[] framed = ptr.getByteArray(0, 4 + payloadSize);
        CxLib.cxFree(ptr);
        return framed;
    }

    /** Release the handle. For fd writers, flushes the end-of-table marker. */
    @Override
    public void close() {
        if (closed) return;
        closed = true;
        if (handle != null) {
            CxLib.tableWriterClose(handle);
            handle = null;
        }
    }
}
