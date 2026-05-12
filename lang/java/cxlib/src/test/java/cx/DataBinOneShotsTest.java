package cx;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Round-trip tests for the Java data_bin one-shot wrappers
 * (Phase 7.28 V core; Phase 7.34 Java binding).
 *
 * Loaders return UNFRAMED PAYLOAD bytes (frame stripped via callBinFn).
 * Dumpers expect FRAMED input. Tests use reframe() to bridge.
 */
public class DataBinOneShotsTest {

    private static byte[] reframe(byte[] payload) {
        byte[] out = new byte[4 + payload.length];
        ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN).putInt(payload.length);
        System.arraycopy(payload, 0, out, 4, payload.length);
        return out;
    }

    // ── XML one-shot ────────────────────────────────────────────────────────

    @Test
    void xmlToDataBinReturnsCxdbPayload() {
        byte[] payload = CxLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>");
        assertTrue(payload.length > 4, "expected non-empty payload");
        assertEquals('C', payload[0]);
        assertEquals('X', payload[1]);
        assertEquals('D', payload[2]);
        assertEquals('B', payload[3]);
    }

    @Test
    void xmlRoundTripThroughDataBin() {
        byte[] payload = CxLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>");
        String out = CxLib.dataBinToXml(reframe(payload));
        assertTrue(out.contains("server"), "expected server: " + out);
        assertTrue(out.contains("localhost"), "expected localhost: " + out);
        assertTrue(out.contains("8080"), "expected 8080: " + out);
    }

    // ── JSON one-shot ────────────────────────────────────────────────────────

    @Test
    void jsonRoundTripThroughDataBin() {
        byte[] payload = CxLib.jsonToDataBin("{\"name\": \"alice\", \"id\": 1}");
        String out = CxLib.dataBinToJson(reframe(payload));
        assertTrue(out.contains("alice"), "expected alice: " + out);
        assertTrue(out.contains("1"), "expected 1: " + out);
    }

    // ── YAML one-shot ────────────────────────────────────────────────────────

    @Test
    void yamlRoundTripThroughDataBin() {
        byte[] payload = CxLib.yamlToDataBin("name: alice\nid: 1\n");
        String out = CxLib.dataBinToYaml(reframe(payload));
        assertTrue(out.contains("alice"), "expected alice: " + out);
    }

    // ── TOML one-shot ────────────────────────────────────────────────────────

    @Test
    void tomlRoundTripThroughDataBin() {
        byte[] payload = CxLib.tomlToDataBin("name = \"alice\"\nid = 1\n");
        String out = CxLib.dataBinToToml(reframe(payload));
        assertTrue(out.contains("alice"), "expected alice: " + out);
    }

    // ── Markdown one-shot ────────────────────────────────────────────────────

    @Test
    void mdRoundTripThroughDataBin() {
        byte[] payload = CxLib.mdToDataBin("# Title\n\nA paragraph.\n");
        String out = CxLib.dataBinToMd(reframe(payload));
        assertTrue(out.contains("Title"), "expected Title: " + out);
    }

    // ── Cross-format compositions ────────────────────────────────────────────

    @Test
    void xmlToDataBinToJson() {
        byte[] payload = CxLib.xmlToDataBin("<user id=\"1\" name=\"alice\"/>");
        String out = CxLib.dataBinToJson(reframe(payload));
        assertTrue(out.contains("alice"), "expected alice: " + out);
        assertTrue(out.contains("1"), "expected 1: " + out);
    }

    @Test
    void jsonToDataBinToYaml() {
        byte[] payload = CxLib.jsonToDataBin("{\"name\": \"alice\", \"active\": true}");
        String out = CxLib.dataBinToYaml(reframe(payload));
        assertTrue(out.contains("alice"), "expected alice: " + out);
    }

    @Test
    void tomlToDataBinToXml() {
        byte[] payload = CxLib.tomlToDataBin("host = \"localhost\"\nport = 8080\n");
        String out = CxLib.dataBinToXml(reframe(payload));
        assertTrue(out.contains("localhost"), "expected localhost: " + out);
        assertTrue(out.contains("8080"), "expected 8080: " + out);
    }
}
