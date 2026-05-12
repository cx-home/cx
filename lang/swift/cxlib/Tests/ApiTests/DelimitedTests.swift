import XCTest
import CXLib
import Foundation

/// Round-trip tests for the Swift delimited (CSV/TSV/PSV) wrappers
/// (Phase 7.67 V core; Phase 7.68 Swift binding).
///
/// Mirrors lang/python/test_delimited.py case-for-case.
final class DelimitedTests: XCTestCase {

    private func reframe(_ payload: Data) -> Data {
        var out = Data(capacity: 4 + payload.count)
        var size = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &size) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    // ── Emit ────────────────────────────────────────────────────────────────

    func testEmitTableDirect() throws {
        let src = "[users :table[name:string age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
        let out = try CXLib.toCsv(src)
        XCTAssertEqual(out, "name,age,active\r\nalice,30,true\r\nbob,25,false\r\n")
    }

    func testEmitRepeatedRow() throws {
        let src = "[users\n  [user id=1 name=alice +admin]\n  [user id=2 name=bob]\n  [user id=3 name=carol +admin]\n]"
        let out = try CXLib.toCsv(src)
        XCTAssertEqual(out, "id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n")
    }

    func testEmitDottedPath() throws {
        let src = "[config\n  [server host=localhost port=8080 +tls]\n  [logging level=info format=json]\n]"
        let out = try CXLib.toCsv(src)
        let expected = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n"
        XCTAssertEqual(out, expected)
    }

    func testEmitTsv() throws {
        let src = "[t :table[a b c]\n  x y z\n]"
        let out = try CXLib.toTsv(src)
        XCTAssertEqual(out, "a\tb\tc\r\nx\ty\tz\r\n")
    }

    func testEmitPsv() throws {
        let src = "[t :table[a b]\n  x y\n]"
        let out = try CXLib.toPsv(src)
        XCTAssertEqual(out, "a|b\r\nx|y\r\n")
    }

    // ── Parse ───────────────────────────────────────────────────────────────

    func testParseCsvBasicAutotypes() throws {
        let csvIn = "name,age,active\nalice,30,true\nbob,25,false\n"
        let out = try CXLib.fromCsv(csvIn)
        let expected = "[table :table[name age:int active:bool]\n  alice 30 true\n  bob 25 false\n]"
        XCTAssertEqual(out, expected)
    }

    func testParseQuotedStaysString() throws {
        let csvIn = "name,age\nalice,\"30\"\nbob,\"25\"\n"
        let out = try CXLib.fromCsv(csvIn)
        let expected = "[table :table[name age]\n  alice 30\n  bob 25\n]"
        XCTAssertEqual(out, expected)
    }

    func testParseEmptyCellIsNull() throws {
        let csvIn = "name,age\nalice,30\nbob,\n"
        let out = try CXLib.fromCsv(csvIn)
        let expected = "[table :table[name age:int]\n  alice 30\n  bob null\n]"
        XCTAssertEqual(out, expected)
    }

    // ── Arbitrary delimiter + data_bin one-shots ────────────────────────────

    func testToDelimitedArbitrary() throws {
        let src = "[t :table[a b]\n  x y\n]"
        let out = try CXLib.toDelimited(src, delim: ";")
        XCTAssertEqual(out, "a;b\r\nx;y\r\n")
    }

    func testCsvToDataBinRoundTrip() throws {
        let payload = try CXLib.csvToDataBin("name,age\nalice,30\nbob,25\n")
        let magic = String(data: payload.prefix(4), encoding: .ascii)
        XCTAssertEqual(magic, "CXDB")
        let out = try CXLib.dataBinToCsv(reframe(payload))
        XCTAssertEqual(out, "name,age\r\nalice,30\r\nbob,25\r\n")
    }

    func testTsvToDataBinRoundTrip() throws {
        let payload = try CXLib.tsvToDataBin("a\tb\nx\ty\n")
        let out = try CXLib.dataBinToTsv(reframe(payload))
        XCTAssertEqual(out, "a\tb\r\nx\ty\r\n")
    }

    func testPsvToDataBinRoundTrip() throws {
        let payload = try CXLib.psvToDataBin("a|b\nx|y\n")
        let out = try CXLib.dataBinToPsv(reframe(payload))
        XCTAssertEqual(out, "a|b\r\nx|y\r\n")
    }
}
