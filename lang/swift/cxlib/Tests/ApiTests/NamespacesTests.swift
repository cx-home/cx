import XCTest
import CXLib

/// Namespace resolution tests for the Swift CX binding (ADR 0002).
/// Mirrors lang/python/test_namespaces.py.
final class NamespacesTests: XCTestCase {

    private func root(_ d: CXDocument) -> Element {
        for n in d.elements {
            if case .element(let e) = n { return e }
        }
        XCTFail("no root element"); fatalError()
    }

    func testDefaultNamespaceInheritsToDescendants() throws {
        let doc = try CXDocument.parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]")
        let html = root(doc)
        XCTAssertEqual(html.localName(), "html")
        XCTAssertEqual(html.namespaceUri(), "http://www.w3.org/1999/xhtml")
        let body = html.get("body")!
        XCTAssertEqual(body.namespaceUri(), "http://www.w3.org/1999/xhtml")
    }

    func testDefaultNamespaceDoesNotApplyToAttrs() throws {
        let doc = try CXDocument.parse("[html xmlns=urn:x id=top body]")
        let id = root(doc).attrs.first { $0.name == "id" }!
        XCTAssertNil(id.namespaceUri())
        XCTAssertEqual(id.localName(), "id")
    }

    func testPrefixedElementResolves() throws {
        let doc = try CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
        let title = root(doc).get("dc:title")!
        XCTAssertEqual(title.localName(), "title")
        XCTAssertEqual(title.namespaceUri(), "http://purl.org/dc/elements/1.1/")
    }

    func testPrefixedAttributeResolves() throws {
        let doc = try CXDocument.parse(
            "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]"
        )
        let href = root(doc).get("link")!.attrs.first { $0.name == "xl:href" }!
        XCTAssertEqual(href.localName(), "href")
        XCTAssertEqual(href.namespaceUri(), "http://www.w3.org/1999/xlink")
    }

    func testReservedXmlPrefix() throws {
        let doc = try CXDocument.parse("[doc xml:base=https://example.com content]")
        let base = root(doc).attrs.first { $0.name == "xml:base" }!
        XCTAssertEqual(base.namespaceUri(), CXDocument.xmlNamespaceUri)
    }

    func testReservedCxPrefix() throws {
        let doc = try CXDocument.parse("[doc [cx:meta key=value]]")
        let meta = root(doc).get("cx:meta")!
        XCTAssertEqual(meta.namespaceUri(), CXDocument.cxNamespaceUri)
    }

    func testUndeclaredPrefix() throws {
        let doc = try CXDocument.parse("[doc [foo:bar baz]]")
        let bar = root(doc).get("foo:bar")!
        XCTAssertEqual(bar.localName(), "bar")
        XCTAssertNil(bar.namespaceUri())
    }

    func testRedeclarationOverridesDefault() throws {
        let doc = try CXDocument.parse(
            "[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]"
        )
        let html = root(doc)
        let body = html.get("body")!
        let svg = body.get("svg")!
        let circle = svg.get("circle")!
        XCTAssertEqual(html.namespaceUri(), "http://www.w3.org/1999/xhtml")
        XCTAssertEqual(body.namespaceUri(), "http://www.w3.org/1999/xhtml")
        XCTAssertEqual(svg.namespaceUri(), "http://www.w3.org/2000/svg")
        XCTAssertEqual(circle.namespaceUri(), "http://www.w3.org/2000/svg")
    }

    func testEmptyUriUndeclares() throws {
        let doc = try CXDocument.parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]")
        let outer = root(doc)
        let inner = outer.get("inner")!
        let child = inner.get("child")!
        XCTAssertEqual(outer.namespaceUri(), "urn:x")
        XCTAssertNil(inner.namespaceUri())
        XCTAssertNil(child.namespaceUri())
    }

    func testResolveIsIdempotent() throws {
        let doc = try CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
        let first = root(doc).get("dc:title")!.namespaceUri()
        CXDocument.resolveNamespaces(doc)
        CXDocument.resolveNamespaces(doc)
        let second = root(doc).get("dc:title")!.namespaceUri()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first, "http://purl.org/dc/elements/1.1/")
    }

    func testXmlnsDeclarationAttrsHaveNoUri() throws {
        let doc = try CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]")
        let decl = root(doc).attrs.first { $0.name == "xmlns:dc" }!
        XCTAssertNil(decl.namespaceUri())
        XCTAssertEqual(decl.localName(), "dc")
    }
}
