package cx

import org.junit.jupiter.api.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Round-trip tests for the Kotlin data_bin one-shot wrappers
 * (Phase 7.28 V core; Phase 7.35 Kotlin binding).
 *
 * Loaders return UNFRAMED PAYLOAD bytes (frame stripped via callBinFn).
 * Dumpers expect FRAMED input. Tests use reframe() to bridge.
 */
class DataBinOneShotsTest {

    private fun reframe(payload: ByteArray): ByteArray {
        val out = ByteArray(4 + payload.size)
        ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN).putInt(payload.size)
        System.arraycopy(payload, 0, out, 4, payload.size)
        return out
    }

    // ── XML one-shot ────────────────────────────────────────────────────────

    @Test fun xmlToDataBinReturnsCxdbPayload() {
        val payload = CxLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
        assertTrue(payload.size > 4, "expected non-empty payload")
        assertEquals('C'.code.toByte(), payload[0])
        assertEquals('X'.code.toByte(), payload[1])
        assertEquals('D'.code.toByte(), payload[2])
        assertEquals('B'.code.toByte(), payload[3])
    }

    @Test fun xmlRoundTripThroughDataBin() {
        val payload = CxLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
        val out = CxLib.dataBinToXml(reframe(payload))
        assertTrue(out.contains("server"), "expected server: $out")
        assertTrue(out.contains("localhost"), "expected localhost: $out")
        assertTrue(out.contains("8080"), "expected 8080: $out")
    }

    // ── JSON / YAML / TOML / MD round-trips ─────────────────────────────────

    @Test fun jsonRoundTripThroughDataBin() {
        val payload = CxLib.jsonToDataBin("""{"name": "alice", "id": 1}""")
        val out = CxLib.dataBinToJson(reframe(payload))
        assertTrue(out.contains("alice"), "expected alice: $out")
        assertTrue(out.contains("1"), "expected 1: $out")
    }

    @Test fun yamlRoundTripThroughDataBin() {
        val payload = CxLib.yamlToDataBin("name: alice\nid: 1\n")
        val out = CxLib.dataBinToYaml(reframe(payload))
        assertTrue(out.contains("alice"), "expected alice: $out")
    }

    @Test fun tomlRoundTripThroughDataBin() {
        val payload = CxLib.tomlToDataBin("name = \"alice\"\nid = 1\n")
        val out = CxLib.dataBinToToml(reframe(payload))
        assertTrue(out.contains("alice"), "expected alice: $out")
    }

    @Test fun mdRoundTripThroughDataBin() {
        val payload = CxLib.mdToDataBin("# Title\n\nA paragraph.\n")
        val out = CxLib.dataBinToMd(reframe(payload))
        assertTrue(out.contains("Title"), "expected Title: $out")
    }

    // ── Cross-format compositions ──────────────────────────────────────────

    @Test fun xmlToDataBinToJson() {
        val payload = CxLib.xmlToDataBin("<user id=\"1\" name=\"alice\"/>")
        val out = CxLib.dataBinToJson(reframe(payload))
        assertTrue(out.contains("alice"), "expected alice: $out")
        assertTrue(out.contains("1"), "expected 1: $out")
    }

    @Test fun jsonToDataBinToYaml() {
        val payload = CxLib.jsonToDataBin("""{"name": "alice", "active": true}""")
        val out = CxLib.dataBinToYaml(reframe(payload))
        assertTrue(out.contains("alice"), "expected alice: $out")
    }

    @Test fun tomlToDataBinToXml() {
        val payload = CxLib.tomlToDataBin("host = \"localhost\"\nport = 8080\n")
        val out = CxLib.dataBinToXml(reframe(payload))
        assertTrue(out.contains("localhost"), "expected localhost: $out")
        assertTrue(out.contains("8080"), "expected 8080: $out")
    }
}
