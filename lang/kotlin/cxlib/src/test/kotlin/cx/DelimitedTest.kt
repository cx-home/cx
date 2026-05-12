package cx

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Round-trip tests for the Kotlin delimited (CSV/TSV/PSV) wrappers
 * (Phase 7.67 V core; Phase 7.68 Kotlin binding).
 *
 * Mirrors lang/python/test_delimited.py — same 12 cases byte-exact.
 *
 * Loaders return UNFRAMED PAYLOAD bytes (frame stripped via callBinFn).
 * Dumpers expect FRAMED input. Tests use reframe() to bridge.
 */
class DelimitedTest {

    private fun reframe(payload: ByteArray): ByteArray {
        val out = ByteArray(4 + payload.size)
        ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN).putInt(payload.size)
        System.arraycopy(payload, 0, out, 4, payload.size)
        return out
    }

    // ── Emit (5) ─────────────────────────────────────────────────────────────

    @Test fun emitTableDirect() {
        val src = "[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
        val out = CxLib.toCsv(src)
        assertEquals("name,age,active\r\nalice,30,true\r\nbob,25,false\r\n", out)
    }

    @Test fun emitRepeatedRow() {
        val src = "[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]"
        val out = CxLib.toCsv(src)
        assertEquals("id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n", out)
    }

    @Test fun emitDottedPath() {
        val src = "[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]"
        val out = CxLib.toCsv(src)
        val expected = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n"
        assertEquals(expected, out)
    }

    @Test fun emitTsv() {
        val src = "[t :table[a b c]\n  x y z\n]"
        val out = CxLib.toTsv(src)
        assertEquals("a\tb\tc\r\nx\ty\tz\r\n", out)
    }

    @Test fun emitPsv() {
        val src = "[t :table[a b]\n  x y\n]"
        val out = CxLib.toPsv(src)
        assertEquals("a|b\r\nx|y\r\n", out)
    }

    // ── Parse (3) ────────────────────────────────────────────────────────────

    @Test fun parseCsvBasicAutotypes() {
        val csvIn = "name,age,active\nalice,30,true\nbob,25,false\n"
        val out = CxLib.fromCsv(csvIn)
        val expected = "[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
        assertEquals(expected, out)
    }

    @Test fun parseQuotedStaysString() {
        val csvIn = "name,age\nalice,\"30\"\nbob,\"25\"\n"
        val out = CxLib.fromCsv(csvIn)
        val expected = "[table :table[name age]\n  alice 30\n  bob 25\n]"
        assertEquals(expected, out)
    }

    @Test fun parseEmptyCellIsNull() {
        val csvIn = "name,age\nalice,30\nbob,\n"
        val out = CxLib.fromCsv(csvIn)
        val expected = "[table :table[name age:int]\n  alice 30\n  bob null\n]"
        assertEquals(expected, out)
    }

    // ── Arbitrary delimiter + data_bin one-shots (4) ─────────────────────────

    @Test fun toDelimitedArbitrary() {
        val src = "[t :table[a b]\n  x y\n]"
        val out = CxLib.toDelimited(src, ';')
        assertEquals("a;b\r\nx;y\r\n", out)
    }

    @Test fun csvToDataBinRoundTrip() {
        val payload = CxLib.csvToDataBin("name,age\nalice,30\nbob,25\n")
        assertTrue(payload.size > 4, "expected non-empty payload")
        assertEquals('C'.code.toByte(), payload[0])
        assertEquals('X'.code.toByte(), payload[1])
        assertEquals('D'.code.toByte(), payload[2])
        assertEquals('B'.code.toByte(), payload[3])
        val out = CxLib.dataBinToCsv(reframe(payload))
        assertEquals("name,age\r\nalice,30\r\nbob,25\r\n", out)
    }

    @Test fun tsvToDataBinRoundTrip() {
        val payload = CxLib.tsvToDataBin("a\tb\nx\ty\n")
        val out = CxLib.dataBinToTsv(reframe(payload))
        assertEquals("a\tb\r\nx\ty\r\n", out)
    }

    @Test fun psvToDataBinRoundTrip() {
        val payload = CxLib.psvToDataBin("a|b\nx|y\n")
        val out = CxLib.dataBinToPsv(reframe(payload))
        assertEquals("a|b\r\nx|y\r\n", out)
    }
}
