package cx;

import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Iterator;
import java.util.NoSuchElementException;

/**
 * Streaming reader over a chunked-table CXDB buffer or fd
 * (Phase 7.74a; spec/abi.md §2.10, ADR 0015 D8).
 *
 * <p>{@link #next()} returns each row group as framed
 * {@code [u32 LE size][plain body]} bytes (compressed groups are
 * decompressed by the V core before return), or {@code null} on EOF.
 *
 * <p>Wire conventions:
 * <ul>
 *   <li>The {@code byte[]} ctor consumes a framed
 *       {@code [u32 LE size][CXDB payload]} buffer.</li>
 *   <li>The fd ctor consumes a bare CXDB stream (no size prefix).</li>
 * </ul>
 *
 * <p>Implements {@link AutoCloseable} for use with try-with-resources.
 */
public final class TableReader implements AutoCloseable, Iterable<byte[]> {
    private Pointer handle;
    private boolean closed;

    /** Open from a framed CXDB chunked-table buffer. */
    public TableReader(byte[] framedDataBin) {
        if (framedDataBin == null || framedDataBin.length == 0) {
            throw new RuntimeException("cx_table_reader_open: empty input");
        }
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.tableReaderOpen(framedDataBin, err);
        if (h == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_reader_open: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        this.handle = h;
    }

    /** Open from a file descriptor positioned at the start of a bare CXDB stream. */
    public static TableReader fromFd(int fd) {
        PointerByReference err = new PointerByReference();
        Pointer h = CxLib.tableReaderOpenFd(fd, err);
        if (h == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_reader_open_fd: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        TableReader r = new TableReader();
        r.handle = h;
        return r;
    }

    private TableReader() {}

    /** Return the table's col-spec as framed ast_bin. */
    public byte[] schema() {
        ensureOpen();
        PointerByReference err = new PointerByReference();
        Pointer ptr = CxLib.tableReaderSchema(handle, err);
        if (ptr == null) {
            Pointer ep  = err.getValue();
            String  msg = (ep != null) ? ep.getString(0) : "cx_table_reader_schema: unknown error";
            if (ep != null) CxLib.cxFree(ep);
            throw new RuntimeException(msg);
        }
        byte[] framed = readFramed(ptr);
        CxLib.cxFree(ptr);
        return framed;
    }

    /** Pull the next row group as framed bytes. Returns {@code null} on
     *  EOF; throws {@link RuntimeException} on error. */
    public byte[] next() {
        if (closed || handle == null) return null;
        PointerByReference err = new PointerByReference();
        Pointer ptr = CxLib.tableReaderNext(handle, err);
        if (ptr == null) {
            Pointer ep  = err.getValue();
            if (ep != null) {
                String msg = ep.getString(0);
                CxLib.cxFree(ep);
                close();
                throw new RuntimeException(msg);
            }
            return null;            // EOF (err unset)
        }
        byte[] framed = readFramed(ptr);
        CxLib.cxFree(ptr);
        return framed;
    }

    @Override
    public void close() {
        if (closed) return;
        closed = true;
        if (handle != null) {
            CxLib.tableReaderClose(handle);
            handle = null;
        }
    }

    @Override
    public Iterator<byte[]> iterator() {
        return new Iterator<byte[]>() {
            byte[] peeked = null;
            boolean fetched = false;

            private void ensureFetched() {
                if (!fetched) { peeked = next(); fetched = true; }
            }

            @Override public boolean hasNext() {
                ensureFetched();
                return peeked != null;
            }
            @Override public byte[] next() {
                ensureFetched();
                if (peeked == null) throw new NoSuchElementException();
                byte[] out = peeked;
                peeked = null;
                fetched = false;
                return out;
            }
        };
    }

    private void ensureOpen() {
        if (closed || handle == null) {
            throw new IllegalStateException("TableReader: handle closed");
        }
    }

    private static byte[] readFramed(Pointer ptr) {
        byte[] sizeBytes = ptr.getByteArray(0, 4);
        int payloadSize = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).getInt();
        return ptr.getByteArray(0, 4 + payloadSize);
    }
}
