import XCTest
import CXLib

/// ID/IDREF tests for the Swift CX binding (ADR 0003).
/// Mirrors V conformance/identity.txt.
final class IdentityTests: XCTestCase {

    private func root(_ d: CXDocument) -> Element {
        for n in d.elements {
            if case .element(let e) = n { return e }
        }
        XCTFail("no root element"); fatalError()
    }

    func testIdDeclarationOnlyRoundTrips() throws {
        let cxIn = "[user #u-1 name=alice]"
        let doc = try CXDocument.parse(cxIn)
        XCTAssertEqual(root(doc).id, "u-1")
        XCTAssertEqual(doc.toCx(), cxIn)
    }

    func testIdWithAnchorCoexists() throws {
        let doc = try CXDocument.parse("[item &a #u-1 v=42]")
        let item = root(doc)
        XCTAssertEqual(item.anchor, "a")
        XCTAssertEqual(item.id, "u-1")
    }

    func testAttributeValueReferenceMarkedIsRef() throws {
        let doc = try CXDocument.parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]")
        let reviewer = doc.findFirst("reviewer")!
        let a = reviewer.attrs.first { $0.name == "assigned-to" }!
        XCTAssertTrue(a.isRef)
        XCTAssertEqual(a.value as? String, "u-1")
    }

    func testResolveIdFindsDeclaredElement() throws {
        let doc = try CXDocument.parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]")
        XCTAssertEqual(doc.resolveId("u-1")?.attr("name") as? String, "alice")
        XCTAssertEqual(doc.resolveId("u-2")?.attr("name") as? String, "bob")
        XCTAssertNil(doc.resolveId("u-3"))
    }

    func testElementsByIdBuildsFullMap() throws {
        let doc = try CXDocument.parse("[a #x v=1] [b #y v=2] [c #z v=3]")
        let m = doc.elementsById()
        XCTAssertEqual(m.count, 3)
        XCTAssertEqual(m["x"]?.name, "a")
        XCTAssertEqual(m["y"]?.name, "b")
        XCTAssertEqual(m["z"]?.name, "c")
    }

    func testQuotedAtLiteralIsNotReference() throws {
        let cxIn = "[item label='@literal']"
        let doc = try CXDocument.parse(cxIn)
        let label = root(doc).attrs.first { $0.name == "label" }!
        XCTAssertFalse(label.isRef)
        XCTAssertEqual(label.value as? String, "@literal")
        XCTAssertEqual(doc.toCx(), cxIn)
    }

    func testForwardReferenceResolves() throws {
        let doc = try CXDocument.parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]")
        let user = doc.resolveId("u-1")
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.attr("name") as? String, "alice")
    }

    func testNestedIdAndRefRoundTrip() throws {
        let cxIn = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]"
        let doc = try CXDocument.parse(cxIn)
        XCTAssertNotNil(doc.resolveId("u-1"))
        let review = doc.findFirst("review")!
        let target = review.attrs.first { $0.name == "target" }!
        XCTAssertTrue(target.isRef)
        XCTAssertEqual(target.value as? String, "u-1")
    }

    func testBodyRefSurvivesAstBinRoundTrip() throws {
        // ADR 0003 D1 / Phase 7.70: ast_bin v3 carries Element.body_ref.
        let cxIn = "[doc [section #section-3 [para See [ref @section-3].]]]"
        let doc = try CXDocument.parse(cxIn)
        let ref = doc.findFirst("ref")!
        XCTAssertEqual(ref.bodyRef, "section-3")
        XCTAssertTrue(ref.attrs.isEmpty)
        XCTAssertTrue(ref.items.isEmpty)
        XCTAssertTrue(doc.toCx().contains("[ref @section-3]"))
    }

    func testMultipleRefsToSameId() throws {
        let doc = try CXDocument.parse(
            "[users [user #u-1 name=alice] " +
                "[reviewer assigned-to=@u-1] " +
                "[approver checked-by=@u-1]]"
        )
        var count = 0
        for el in doc.findAll("reviewer") + doc.findAll("approver") {
            for a in el.attrs {
                if a.isRef && (a.value as? String) == "u-1" { count += 1 }
            }
        }
        XCTAssertEqual(count, 2)
    }
}
