package cx;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;

/**
 * Streaming-write tests for the Java binding (Phase 7.74i — Tier-2 wrappers).
 * Mirrors lang/python/test_event_writer.py and lang/go/cxlib/event_writer_test.go
 * and the Rust / C# wrappers on the same locked C ABI surface.
 */
public class EventWriterTest {

    // ── helpers ────────────────────────────────────────────────────────────

    /** 2-col col_spec wire form (spec/data_bin.md §3.10.1):
     *  name:string (0x30), score:i32 (0x12). */
    private static byte[] colSpec2() {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        u32(out, 2);
        u32(out, 4); writeAscii(out, "name");  out.write(0x30);
        u32(out, 5); writeAscii(out, "score"); out.write(0x12);
        return out.toByteArray();
    }

    /** 2-row row group: uvarint(2) + 2 strings + 2 i32 LE. */
    private static byte[] rowGroup2() {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        out.write(2);
        out.write(5); writeAscii(out, "alice");
        out.write(3); writeAscii(out, "bob");
        i32(out, 91);
        i32(out, 88);
        return out.toByteArray();
    }

    private static void u32(java.io.ByteArrayOutputStream out, int v) {
        out.write(v & 0xFF); out.write((v >> 8) & 0xFF);
        out.write((v >> 16) & 0xFF); out.write((v >> 24) & 0xFF);
    }
    private static void i32(java.io.ByteArrayOutputStream out, int v) { u32(out, v); }
    private static void writeAscii(java.io.ByteArrayOutputStream out, String s) {
        for (char c : s.toCharArray()) out.write(c & 0xFF);
    }

    private static void assertWcode(String code, Runnable r) {
        RuntimeException e = assertThrows(RuntimeException.class, r::run);
        assertTrue(e.getMessage().startsWith(code),
            "expected " + code + " prefix, got: " + e.getMessage());
    }

    // ── tests ──────────────────────────────────────────────────────────────

    @Test
    void capabilityBitAdvertised() {
        assertTrue(EventWriter.hasCapability(),
            "expected libcx to advertise capability bit 27 (streaming-write)");
    }

    @Test
    void cxMinimalRoundTrip() {
        try (EventWriter w = new EventWriter("cx")) {
            w.startDoc();
            w.startElement("greet");
            w.text("hello");
            w.endElement("greet");
            w.endDoc();
            byte[] out = w.closeGetBytes();
            String s = new String(out);
            assertTrue(s.contains("[greet"), "got: " + s);
            assertTrue(s.contains("hello"),  "got: " + s);
        }
    }

    @Test
    void cxAttrsEmitted() {
        try (EventWriter w = new EventWriter("cx")) {
            w.startDoc();
            w.startElement("book", null, null, null, List.of(
                new EventWriter.Attr("id", "b1", "string"),
                new EventWriter.Attr("yr", "2024", "int")));
            w.endElement("book");
            w.endDoc();
            String s = new String(w.closeGetBytes());
            assertTrue(s.contains("id="), "got: " + s);
            assertTrue(s.contains("b1"),  "got: " + s);
        }
    }

    @Test
    void xmlMinimalRoundTrip() {
        try (EventWriter w = new EventWriter("xml")) {
            w.startDoc();
            w.startElement("greet");
            w.text("hello");
            w.endElement("greet");
            w.endDoc();
            String s = new String(w.closeGetBytes());
            assertTrue(s.contains("<?xml version=\"1.0\"?>"), "got: " + s);
            assertTrue(s.contains("<greet>"),  "got: " + s);
            assertTrue(s.contains("hello"),    "got: " + s);
            assertTrue(s.contains("</greet>"), "got: " + s);
        }
    }

    @Test
    void w001DoubleStartDoc() {
        assertWcode("W001", () -> {
            try (EventWriter w = new EventWriter("cx")) { w.startDoc(); w.startDoc(); }
        });
    }

    @Test
    void w002TextBeforeStartDoc() {
        assertWcode("W002", () -> {
            try (EventWriter w = new EventWriter("cx")) { w.text("premature"); }
        });
    }

    @Test
    void w003TextAfterEndDoc() {
        assertWcode("W003", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.endDoc(); w.text("post");
            }
        });
    }

    @Test
    void w004UnclosedElementOnEndDoc() {
        assertWcode("W004", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.startElement("open"); w.endDoc();
            }
        });
    }

    @Test
    void w005EndElementMismatch() {
        assertWcode("W005", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.startElement("greet"); w.endElement("farewell");
            }
        });
    }

    @Test
    void w006OrphanEndElement() {
        assertWcode("W006", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.endElement("orphan");
            }
        });
    }

    @Test
    void w008InvalidScalarType() {
        assertWcode("W008", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.scalar("42", "not_a_type");
            }
        });
    }

    @Test
    void w009ChunkedOnXmlTarget() {
        assertWcode("W009", () -> {
            try (EventWriter w = new EventWriter("xml")) {
                w.startDoc();
                w.startTable(new byte[]{1,0,0,0,1,0,0,0,'x',0x12});
            }
        });
    }

    @Test
    void w012OrphanRowGroup() {
        assertWcode("W012", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.rowGroup(new byte[]{1});
            }
        });
    }

    @Test
    void w013OrphanEndTable() {
        assertWcode("W013", () -> {
            try (EventWriter w = new EventWriter("cx")) {
                w.startDoc(); w.endTable();
            }
        });
    }

    @Test
    void failClosedAfterFirstWcode() {
        try (EventWriter w = new EventWriter("cx")) {
            RuntimeException e1 = assertThrows(RuntimeException.class, () -> w.text("premature"));
            assertTrue(e1.getMessage().startsWith("W002"), "got: " + e1.getMessage());
            RuntimeException e2 = assertThrows(RuntimeException.class, () -> w.text("again"));
            assertTrue(e2.getMessage().startsWith("W002"), "got: " + e2.getMessage());
        }
    }

    @Test
    void chunkedTableCxRoundTrip() {
        try (EventWriter w = new EventWriter("cx")) {
            w.startDoc();
            w.startElement("points");
            w.startTable(colSpec2());
            w.rowGroup(rowGroup2());
            w.endTable();
            w.endElement("points");
            w.endDoc();
            String s = new String(w.closeGetBytes());
            assertTrue(s.contains(":table"), "got: " + s);
            assertTrue(s.contains("alice"),  "got: " + s);
            assertTrue(s.contains("91"),     "got: " + s);
        }
    }

    /** Minimal JNA shim for libc {@code open(2)} / {@code close(2)} so the
     *  fd-writer test doesn't depend on reflective access into
     *  {@code java.io.FileDescriptor} (blocked under JPMS). */
    public interface Posix extends Library {
        Posix INSTANCE = Native.load("c", Posix.class);
        int open (String path, int flags, int mode);
        int close(int fd);
    }
    private static final int O_WRONLY = 1;
    private static final int O_CREAT  = 0x0200;  // macOS
    private static final int O_TRUNC  = 0x0400;  // macOS

    @Test
    void fdWriterPath() throws IOException {
        Path tmp = Files.createTempFile("cx_event_writer_java_", ".cx");
        try {
            int fd = Posix.INSTANCE.open(tmp.toString(),
                O_WRONLY | O_CREAT | O_TRUNC, 0644);
            assertTrue(fd >= 0, "open returned " + fd);
            try {
                try (EventWriter w = EventWriter.toFd("cx", fd)) {
                    w.startDoc();
                    w.startElement("greet");
                    w.text("hello");
                    w.endElement("greet");
                    w.endDoc();
                    byte[] bytes = w.closeGetBytes();
                    assertEquals(0, bytes.length, "fd writer should return empty bytes");
                }
            } finally {
                Posix.INSTANCE.close(fd);
            }
            String written = new String(Files.readAllBytes(tmp));
            assertTrue(written.contains("[greet"), "fd output missing [greet: " + written);
            assertTrue(written.contains("hello"),  "fd output missing hello: " + written);
        } finally {
            Files.deleteIfExists(tmp);
        }
    }
}
