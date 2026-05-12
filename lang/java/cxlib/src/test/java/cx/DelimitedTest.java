package cx;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Round-trip tests for the Java delimited (CSV/TSV/PSV) wrappers
 * (Phase 7.67 V core; Phase 7.68 Java binding).
 *
 * Mirrors the 12-case shape of lang/python/test_delimited.py.
 *
 * Loaders return UNFRAMED PAYLOAD bytes (frame stripped via callBinFn).
 * Dumpers expect FRAMED input. Tests use reframe() to bridge.
 */
public class DelimitedTest {

    private static byte[] reframe(byte[] payload) {
        byte[] out = new byte[4 + payload.length];
        ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN).putInt(payload.length);
        System.arraycopy(payload, 0, out, 4, payload.length);
        return out;
    }

    // ── Emit ────────────────────────────────────────────────────────────────

    @Test
    void emitTableDirect() {
        String src = "[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]";
        String out = CxLib.toCsv(src);
        assertEquals("name,age,active\r\nalice,30,true\r\nbob,25,false\r\n", out);
    }

    @Test
    void emitRepeatedRow() {
        String src = "[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]";
        String out = CxLib.toCsv(src);
        assertEquals("id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n", out);
    }

    @Test
    void emitDottedPath() {
        String src = "[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]";
        String out = CxLib.toCsv(src);
        String expected = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n";
        assertEquals(expected, out);
    }

    @Test
    void emitTsv() {
        String src = "[t :table[a b c]\n  x y z\n]";
        String out = CxLib.toTsv(src);
        assertEquals("a\tb\tc\r\nx\ty\tz\r\n", out);
    }

    @Test
    void emitPsv() {
        String src = "[t :table[a b]\n  x y\n]";
        String out = CxLib.toPsv(src);
        assertEquals("a|b\r\nx|y\r\n", out);
    }

    // ── Parse ───────────────────────────────────────────────────────────────

    @Test
    void parseCsvBasicAutotypes() {
        String csvIn = "name,age,active\nalice,30,true\nbob,25,false\n";
        String out = CxLib.fromCsv(csvIn);
        String expected = "[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]";
        assertEquals(expected, out);
    }

    @Test
    void parseQuotedStaysString() {
        String csvIn = "name,age\nalice,\"30\"\nbob,\"25\"\n";
        String out = CxLib.fromCsv(csvIn);
        String expected = "[table :table[name age]\n  alice 30\n  bob 25\n]";
        assertEquals(expected, out);
    }

    @Test
    void parseEmptyCellIsNull() {
        String csvIn = "name,age\nalice,30\nbob,\n";
        String out = CxLib.fromCsv(csvIn);
        String expected = "[table :table[name age:int]\n  alice 30\n  bob null\n]";
        assertEquals(expected, out);
    }

    // ── Arbitrary delimiter + data_bin one-shots ────────────────────────────

    @Test
    void toDelimitedArbitrary() {
        String src = "[t :table[a b]\n  x y\n]";
        String out = CxLib.toDelimited(src, ';');
        assertEquals("a;b\r\nx;y\r\n", out);
    }

    @Test
    void csvToDataBinRoundTrip() {
        byte[] payload = CxLib.csvToDataBin("name,age\nalice,30\nbob,25\n");
        assertTrue(payload.length > 4, "expected non-empty payload");
        assertEquals('C', payload[0]);
        assertEquals('X', payload[1]);
        assertEquals('D', payload[2]);
        assertEquals('B', payload[3]);
        String out = CxLib.dataBinToCsv(reframe(payload));
        assertEquals("name,age\r\nalice,30\r\nbob,25\r\n", out);
    }

    @Test
    void tsvToDataBinRoundTrip() {
        byte[] payload = CxLib.tsvToDataBin("a\tb\nx\ty\n");
        String out = CxLib.dataBinToTsv(reframe(payload));
        assertEquals("a\tb\r\nx\ty\r\n", out);
    }

    @Test
    void psvToDataBinRoundTrip() {
        byte[] payload = CxLib.psvToDataBin("a|b\nx|y\n");
        String out = CxLib.dataBinToPsv(reframe(payload));
        assertEquals("a|b\r\nx|y\r\n", out);
    }
}
