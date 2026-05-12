import XCTest
import CXLib
import Foundation

/// ID/IDREF C ABI wrapper tests (Phase 7.65, ADR 0003).
/// Exercises CXLib.idLookup / .resolveRef / .nodeId.
final class IdAbiTests: XCTestCase {

    private static let doc = """
    [users
      [user #u-1 name=alice]
      [user #u-2 name=bob]
      [reviewer assigned-to=@u-1]
    ]
    """

    /// Parse JSON text into a [String: Any] dictionary.
    private func parseJsonObject(_ s: String) throws -> [String: Any] {
        let data = s.data(using: .utf8)!
        let any = try JSONSerialization.jsonObject(with: data)
        guard let obj = any as? [String: Any] else {
            XCTFail("expected JSON object, got: \(s)"); fatalError()
        }
        return obj
    }

    func testIdLookupHappyPath() throws {
        let result = try CXLib.idLookup(Self.doc, "u-1")
        XCTAssertNotNil(result)
        let obj = try parseJsonObject(result!)
        XCTAssertEqual(obj["type"] as? String, "Element")
        XCTAssertEqual(obj["name"] as? String, "user")
        XCTAssertEqual(obj["id"] as? String, "u-1")
    }

    func testIdLookupMissingReturnsNil() throws {
        let result = try CXLib.idLookup(Self.doc, "does-not-exist")
        XCTAssertNil(result)
    }

    func testResolveRefEqualsIdLookup() throws {
        let viaId  = try CXLib.idLookup(Self.doc, "u-2")
        let viaRef = try CXLib.resolveRef(Self.doc, "u-2")
        XCTAssertNotNil(viaId)
        XCTAssertNotNil(viaRef)
        XCTAssertEqual(viaId, viaRef)
    }

    func testNodeIdAtCxpath() throws {
        XCTAssertEqual(try CXLib.nodeId(Self.doc, "//user"), "u-1")
        XCTAssertNil(try CXLib.nodeId(Self.doc, "//reviewer"))
    }
}
