package cx;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Namespace resolution tests for the Java CX binding (ADR 0002).
 * Mirrors lang/python/test_namespaces.py.
 */
public class NamespacesTest {

    private static Element root(CXDocument d) {
        for (Node n : d.elements) if (n instanceof Element e) return e;
        throw new RuntimeException("no root element");
    }

    @Test
    void defaultNamespaceInheritsToDescendants() throws Exception {
        CXDocument doc = CXDocument.parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]");
        Element html = root(doc);
        assertEquals("html", html.localName());
        assertEquals("http://www.w3.org/1999/xhtml", html.namespaceUri());
        Element body = html.get("body");
        assertEquals("http://www.w3.org/1999/xhtml", body.namespaceUri());
    }

    @Test
    void defaultNamespaceDoesNotApplyToAttrs() throws Exception {
        CXDocument doc = CXDocument.parse("[html xmlns=urn:x id=top body]");
        Element html = root(doc);
        Attr id = html.attrs.stream().filter(a -> "id".equals(a.name)).findFirst().orElseThrow();
        assertNull(id.namespaceUri());
        assertEquals("id", id.localName());
    }

    @Test
    void prefixedElementResolves() throws Exception {
        CXDocument doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]");
        Element title = root(doc).get("dc:title");
        assertEquals("title", title.localName());
        assertEquals("http://purl.org/dc/elements/1.1/", title.namespaceUri());
    }

    @Test
    void prefixedAttributeResolves() throws Exception {
        CXDocument doc = CXDocument.parse(
            "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]"
        );
        Element link = root(doc).get("link");
        Attr href = link.attrs.stream().filter(a -> "xl:href".equals(a.name)).findFirst().orElseThrow();
        assertEquals("href", href.localName());
        assertEquals("http://www.w3.org/1999/xlink", href.namespaceUri());
    }

    @Test
    void reservedXmlPrefix() throws Exception {
        CXDocument doc = CXDocument.parse("[doc xml:base=https://example.com content]");
        Attr base = root(doc).attrs.stream().filter(a -> "xml:base".equals(a.name)).findFirst().orElseThrow();
        assertEquals(CXDocument.XML_NAMESPACE_URI, base.namespaceUri());
    }

    @Test
    void reservedCxPrefix() throws Exception {
        CXDocument doc = CXDocument.parse("[doc [cx:meta key=value]]");
        Element meta = root(doc).get("cx:meta");
        assertEquals(CXDocument.CX_NAMESPACE_URI, meta.namespaceUri());
    }

    @Test
    void undeclaredPrefixPassesThrough() throws Exception {
        CXDocument doc = CXDocument.parse("[doc [foo:bar baz]]");
        Element bar = root(doc).get("foo:bar");
        assertEquals("bar", bar.localName());
        assertNull(bar.namespaceUri());
    }

    @Test
    void redeclarationOverridesDefault() throws Exception {
        CXDocument doc = CXDocument.parse(
            "[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]"
        );
        Element html = root(doc);
        Element body = html.get("body");
        Element svg = body.get("svg");
        Element circle = svg.get("circle");
        assertEquals("http://www.w3.org/1999/xhtml", html.namespaceUri());
        assertEquals("http://www.w3.org/1999/xhtml", body.namespaceUri());
        assertEquals("http://www.w3.org/2000/svg", svg.namespaceUri());
        assertEquals("http://www.w3.org/2000/svg", circle.namespaceUri());
    }

    @Test
    void emptyUriUndeclares() throws Exception {
        CXDocument doc = CXDocument.parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]");
        Element outer = root(doc);
        Element inner = outer.get("inner");
        Element child = inner.get("child");
        assertEquals("urn:x", outer.namespaceUri());
        assertNull(inner.namespaceUri());
        assertNull(child.namespaceUri());
    }

    @Test
    void resolveIsIdempotent() throws Exception {
        CXDocument doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]");
        String first = root(doc).get("dc:title").namespaceUri();
        CXDocument.resolveNamespaces(doc);
        CXDocument.resolveNamespaces(doc);
        String second = root(doc).get("dc:title").namespaceUri();
        assertEquals(first, second);
        assertEquals("http://purl.org/dc/elements/1.1/", first);
    }

    @Test
    void xmlnsDeclarationAttrsHaveNoUri() throws Exception {
        CXDocument doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]");
        Attr decl = root(doc).attrs.stream().filter(a -> "xmlns:dc".equals(a.name)).findFirst().orElseThrow();
        assertNull(decl.namespaceUri());
        assertEquals("dc", decl.localName());
    }
}
