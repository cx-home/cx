package cx;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Streaming Table API tests for the Java binding (Phase 7.74b-cont).
 *
 * Mirrors lang/python/test_streaming_table.py:
 *   1. cx_to_data_bin_chunked one-shot round-trip.
 *   2. bytes-mode round-trip: chunked emit → reader → writer → re-decode.
 *   3. fd-mode round-trip via temp file.
 *   4. invalid framed buffer raises an error.
 */
public class StreamingTableTest {

    private static final String SIX_ROW_INPUT =
        "[points :table[name:string score:i32]\n" +
        "  alice 91\n" +
        "  bob 88\n" +
        "  carol 73\n" +
        "  dave 95\n" +
        "  eve 84\n" +
        "  frank 60\n" +
        "]";

    @Test
    void toDataBinChunkedRoundTrip() {
        byte[] framed = CxLib.toDataBinChunked(SIX_ROW_INPUT);
        assertTrue(framed.length > 4, "framed buffer should be non-empty");
        String cxText = CxLib.fromDataBin(framed);
        assertTrue(cxText.contains("alice"), "round-trip lost first row: " + cxText);
        assertTrue(cxText.contains("frank"), "round-trip lost last row: " + cxText);
    }

    @Test
    void streamingTableBytesRoundTrip() {
        byte[] framed = CxLib.toDataBinChunked(SIX_ROW_INPUT);
        byte[] schema;
        List<byte[]> groups = new ArrayList<>();
        try (TableReader r = new TableReader(framed)) {
            schema = r.schema();
            for (byte[] g = r.next(); g != null; g = r.next()) groups.add(g);
        }
        assertTrue(groups.size() >= 1, "no row groups: " + groups.size());

        byte[] out;
        try (TableWriter w = new TableWriter(schema)) {
            for (byte[] g : groups) w.emit(g);
            out = w.closeGetBytes();
        }
        assertTrue(out.length > 4, "closeGetBytes returned empty buffer");
        String cxText = CxLib.fromDataBin(out);
        assertTrue(cxText.contains("alice"), "lost first row: " + cxText);
        assertTrue(cxText.contains("frank"), "lost last row: " + cxText);
    }

    @Test
    void streamingTableFdRoundTrip() throws IOException {
        byte[] framed = CxLib.toDataBinChunked(SIX_ROW_INPUT);
        byte[] schema;
        List<byte[]> groups = new ArrayList<>();
        try (TableReader r = new TableReader(framed)) {
            schema = r.schema();
            for (byte[] g = r.next(); g != null; g = r.next()) groups.add(g);
        }

        // Java's FileDescriptor.fd is sealed by the JDK 21 module system, so
        // we use POSIX open() via JNA. Java pre-creates the file (so that
        // permissions are correct without depending on JNA's variadic mode
        // argument); POSIX open() then takes over for both write and read.
        Path fdPath = Files.createTempFile("cx_streaming_table_java_", ".cxdb");
        try {
            int wfd = Posix.LIB.open(fdPath.toString(), Posix.O_WRONLY | Posix.O_TRUNC, 0);
            assertTrue(wfd >= 0, "POSIX open(write) failed: " + wfd
                + " errno=" + Native.getLastError());
            try {
                TableWriter w = TableWriter.toFd(schema, wfd);
                try {
                    for (byte[] g : groups) w.emit(g);
                } finally {
                    w.close();   // flushes end-of-table
                }
            } finally {
                Posix.LIB.close(wfd);
            }

            assertTrue(Files.exists(fdPath), "writer did not produce file at " + fdPath);
            assertTrue(Files.size(fdPath) > 0, "writer produced empty file");
            int rfd = Posix.LIB.open(fdPath.toString(), Posix.O_RDONLY, 0);
            assertTrue(rfd >= 0, "POSIX open(read) failed: rfd=" + rfd
                + " errno=" + Native.getLastError() + " path=" + fdPath);
            byte[] roundtripSchema;
            List<byte[]> roundtripGroups = new ArrayList<>();
            try {
                try (TableReader r = TableReader.fromFd(rfd)) {
                    roundtripSchema = r.schema();
                    for (byte[] g = r.next(); g != null; g = r.next()) roundtripGroups.add(g);
                }
            } finally {
                Posix.LIB.close(rfd);
            }

            assertArrayEquals(schema, roundtripSchema, "fd schema drift");
            assertEquals(groups.size(), roundtripGroups.size(), "fd group count drift");
        } finally {
            Files.deleteIfExists(fdPath);
        }
    }

    /** Minimal POSIX bridge — Java's FileDescriptor.fd field is sealed
     *  by the JDK 21 module system, so we go through libc directly. */
    private interface Posix extends Library {
        Posix LIB = Native.load("c", Posix.class);
        boolean MAC = System.getProperty("os.name", "").toLowerCase().contains("mac");
        int O_RDONLY = 0;
        int O_WRONLY = 1;
        int O_TRUNC  = MAC ? 0x0400 : 0x0200;     // mac/BSD vs Linux
        int open (String path, int flags, int mode);
        int close(int fd);
    }

    @Test
    void readerInvalidInputRaises() {
        byte[] bad = new byte[]{0x04, 0x00, 0x00, 0x00, 'g', 'a', 'r', 'b'};
        assertThrows(RuntimeException.class, () -> {
            try (TableReader r = new TableReader(bad)) { /* no-op */ }
        });
    }

}
