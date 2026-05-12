import XCTest
import CXLib
import Foundation

/// Round-trip tests for the Swift data_bin one-shot wrappers
/// (Phase 7.28 V core; Phase 7.36 Swift binding).
///
/// Loaders return UNFRAMED PAYLOAD bytes (frame stripped via _callBin).
/// Dumpers expect FRAMED input. Tests use reframe() to bridge.
final class DataBinOneShotsTests: XCTestCase {

    private func reframe(_ payload: Data) -> Data {
        var out = Data(capacity: 4 + payload.count)
        var size = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &size) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    // ── XML one-shot ────────────────────────────────────────────────────────

    func testXmlToDataBinReturnsCxdbPayload() throws {
        let payload = try CXLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
        XCTAssertGreaterThan(payload.count, 4, "expected non-empty payload")
        let magic = String(data: payload.prefix(4), encoding: .ascii)
        XCTAssertEqual(magic, "CXDB")
    }

    func testXmlRoundTripThroughDataBin() throws {
        let payload = try CXLib.xmlToDataBin("<server><host>localhost</host><port>8080</port></server>")
        let out = try CXLib.dataBinToXml(reframe(payload))
        XCTAssertTrue(out.contains("server"), "expected server: \(out)")
        XCTAssertTrue(out.contains("localhost"), "expected localhost: \(out)")
        XCTAssertTrue(out.contains("8080"), "expected 8080: \(out)")
    }

    // ── JSON / YAML / TOML / MD round-trips ─────────────────────────────────

    func testJsonRoundTripThroughDataBin() throws {
        let payload = try CXLib.jsonToDataBin(#"{"name": "alice", "id": 1}"#)
        let out = try CXLib.dataBinToJson(reframe(payload))
        XCTAssertTrue(out.contains("alice"), "expected alice: \(out)")
        XCTAssertTrue(out.contains("1"), "expected 1: \(out)")
    }

    func testYamlRoundTripThroughDataBin() throws {
        let payload = try CXLib.yamlToDataBin("name: alice\nid: 1\n")
        let out = try CXLib.dataBinToYaml(reframe(payload))
        XCTAssertTrue(out.contains("alice"), "expected alice: \(out)")
    }

    func testTomlRoundTripThroughDataBin() throws {
        let payload = try CXLib.tomlToDataBin("name = \"alice\"\nid = 1\n")
        let out = try CXLib.dataBinToToml(reframe(payload))
        XCTAssertTrue(out.contains("alice"), "expected alice: \(out)")
    }

    func testMdRoundTripThroughDataBin() throws {
        let payload = try CXLib.mdToDataBin("# Title\n\nA paragraph.\n")
        let out = try CXLib.dataBinToMd(reframe(payload))
        XCTAssertTrue(out.contains("Title"), "expected Title: \(out)")
    }

    // ── Cross-format compositions ──────────────────────────────────────────

    func testXmlToDataBinToJson() throws {
        let payload = try CXLib.xmlToDataBin(#"<user id="1" name="alice"/>"#)
        let out = try CXLib.dataBinToJson(reframe(payload))
        XCTAssertTrue(out.contains("alice"), "expected alice: \(out)")
        XCTAssertTrue(out.contains("1"), "expected 1: \(out)")
    }

    func testJsonToDataBinToYaml() throws {
        let payload = try CXLib.jsonToDataBin(#"{"name": "alice", "active": true}"#)
        let out = try CXLib.dataBinToYaml(reframe(payload))
        XCTAssertTrue(out.contains("alice"), "expected alice: \(out)")
    }

    func testTomlToDataBinToXml() throws {
        let payload = try CXLib.tomlToDataBin("host = \"localhost\"\nport = 8080\n")
        let out = try CXLib.dataBinToXml(reframe(payload))
        XCTAssertTrue(out.contains("localhost"), "expected localhost: \(out)")
        XCTAssertTrue(out.contains("8080"), "expected 8080: \(out)")
    }
}
