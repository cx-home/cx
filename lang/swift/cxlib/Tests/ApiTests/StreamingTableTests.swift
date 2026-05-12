import XCTest
import CXLib
import Foundation

/// Streaming Table + schema-driven + chunked-table Swift tests
/// (Phase 7.74b-cont-2). Mirrors the Python / Kotlin / Java suites:
/// 4 streaming-Table cases (in-memory round-trip, fd round-trip,
/// closed-handle, two-row-group) + 1 schema-driven round-trip.
final class StreamingTableTests: XCTestCase {

    // ── helpers ─────────────────────────────────────────────────────────────

    /// Re-prepend the [u32 LE size] frame to UNFRAMED CXDB payload bytes.
    private func reframe(_ payload: Data) -> Data {
        var out = Data(capacity: 4 + payload.count)
        var size = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &size) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    /// Six-row table with string column so cell values are distinctive
    /// in the rebuilt CX text (the chunked round-trip drops the outer
    /// element name — col-spec exchange normalizes to `_`/`table`).
    private let smallTableCx = """
        [points :table[name:string score:i32]
          alice 91
          bob 88
          carol 73
          dave 95
          eve 84
          frank 60
        ]
        """

    // ── 1. in-memory round-trip ─────────────────────────────────────────────

    func testInMemoryRoundTrip() throws {
        let payload = try CXLib.toDataBinChunked(smallTableCx)
        XCTAssertGreaterThan(payload.count, 12, "expected non-empty CXDB payload")
        let framed = reframe(payload)

        // Read all row groups.
        let reader = try TableReader(dataBin: framed)
        let schema = try reader.schema()
        XCTAssertGreaterThan(schema.count, 4, "schema must be non-empty framed ast_bin")
        var groups: [Data] = []
        for g in reader { groups.append(g) }
        reader.close()
        XCTAssertGreaterThanOrEqual(groups.count, 1, "expected at least one row group")

        // Replay through writer, verify the rebuilt buffer round-trips back to CX text.
        let writer = try TableWriter(colSpec: schema)
        for g in groups { try writer.emit(g) }
        let rebuilt = try writer.closeGetBytes()
        let cx = try CXLib.fromDataBin(rebuilt)
        // Element name drops; :table body and row data persist.
        XCTAssertTrue(cx.contains(":table"),
                      "rebuilt CX must contain :table body marker; got: \(cx)")
        for needle in ["alice", "frank", "91", "60"] {
            XCTAssertTrue(cx.contains(needle),
                          "rebuilt CX must include row value \(needle); got: \(cx)")
        }
    }

    // ── 2. fd round-trip ────────────────────────────────────────────────────

    func testFdRoundTrip() throws {
        // First read all groups + schema in-memory.
        let payload = try CXLib.toDataBinChunked(smallTableCx)
        let rIn = try TableReader(dataBin: reframe(payload))
        let schema = try rIn.schema()
        let groups = Array(rIn)
        rIn.close()

        // Stream the same groups through an fd writer; then read back via fd
        // reader and assert schema + group count match.
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cx_swift_streaming_\(UUID().uuidString).cxdb")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: outURL) }

        let outFh = try FileHandle(forWritingTo: outURL)
        let writer = try TableWriter(colSpec: schema, fd: outFh.fileDescriptor)
        for g in groups { try writer.emit(g) }
        writer.close()
        try outFh.close()

        let inFh = try FileHandle(forReadingFrom: outURL)
        defer { try? inFh.close() }
        let rOut = try TableReader(fd: inFh.fileDescriptor)
        let schemaOut = try rOut.schema()
        let groupsOut = Array(rOut)
        rOut.close()

        XCTAssertEqual(schemaOut, schema, "fd schema drift")
        XCTAssertEqual(groupsOut.count, groups.count,
                       "fd group count drift \(groupsOut.count) vs \(groups.count)")
    }

    // ── 3. closed-handle errors ─────────────────────────────────────────────

    func testClosedHandleErrors() throws {
        let payload = try CXLib.toDataBinChunked(smallTableCx)
        let framed = reframe(payload)

        let reader = try TableReader(dataBin: framed)
        reader.close()
        // Iterating a closed reader yields nil immediately; no throw expected.
        XCTAssertNil(reader.next(), "next() on closed reader should yield nil")
        // schema() on a closed reader should throw.
        XCTAssertThrowsError(try reader.schema()) { err in
            XCTAssertTrue(String(describing: err).contains("closed"),
                          "expected 'closed' in error: \(err)")
        }

        // After closeGetBytes, a writer is single-use.
        let r2 = try TableReader(dataBin: framed)
        let schema = try r2.schema()
        let groups = Array(r2)
        r2.close()

        let writer = try TableWriter(colSpec: schema)
        for g in groups { try writer.emit(g) }
        _ = try writer.closeGetBytes()
        XCTAssertThrowsError(try writer.emit(groups[0])) { err in
            XCTAssertTrue(String(describing: err).contains("closed"),
                          "expected 'closed' in error: \(err)")
        }
    }

    // ── 4. two-row-group reuse via writer pipe ──────────────────────────────

    func testEmitMultipleRowGroups() throws {
        // Build two distinct chunked sources, then concatenate their row
        // groups through a single writer that shares the col-spec.
        let cx1 = "[points :table[name:string score:i32] alice 91 bob 88]"
        let cx2 = "[points :table[name:string score:i32] carol 73 dave 95 eve 84]"
        let p1 = try CXLib.toDataBinChunked(cx1)
        let p2 = try CXLib.toDataBinChunked(cx2)

        let r1 = try TableReader(dataBin: reframe(p1))
        let schema = try r1.schema()
        let g1 = Array(r1)
        r1.close()

        let r2 = try TableReader(dataBin: reframe(p2))
        let g2 = Array(r2)
        r2.close()

        XCTAssertGreaterThanOrEqual(g1.count, 1)
        XCTAssertGreaterThanOrEqual(g2.count, 1)

        let writer = try TableWriter(colSpec: schema)
        for g in g1 { try writer.emit(g) }
        for g in g2 { try writer.emit(g) }
        let rebuilt = try writer.closeGetBytes()
        let cx = try CXLib.fromDataBin(rebuilt)
        // Both inputs' row values must appear in the merged output.
        for needle in ["alice", "bob", "carol", "dave", "eve"] {
            XCTAssertTrue(cx.contains(needle), "merged CX must include \(needle); got: \(cx)")
        }
    }

    // ── 5. schema-driven round-trip ─────────────────────────────────────────

    func testSchemaDrivenRoundTrip() throws {
        let cxText  = "[server [host \"localhost\"] [port 8080]]"
        let schema  = "[server [host :string] [port :int]]"
        let payload = try CXLib.toDataBinSchemaDriven(cxText, schema: schema)
        XCTAssertGreaterThan(payload.count, 12, "expected non-empty schema-driven payload")

        let framed = reframe(payload)
        // Decode using the same schema as a hint (handles content-hash-only refs).
        let out = try CXLib.fromDataBinSchemaDriven(framed, schemaHint: schema)
        XCTAssertTrue(out.contains("server"), "round-trip must reproduce 'server'; got: \(out)")
        XCTAssertTrue(out.contains("localhost"),
                      "round-trip must reproduce 'localhost'; got: \(out)")
        XCTAssertTrue(out.contains("8080"),
                      "round-trip must reproduce '8080'; got: \(out)")
    }
}
