package cx

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

/**
 * Namespace resolution tests for the Kotlin CX binding (ADR 0002).
 * Mirrors lang/python/test_namespaces.py.
 */
class NamespacesTest {

    private fun root(d: CXDocument): Element =
        d.elements.filterIsInstance<Element>().first()

    @Test fun defaultNamespaceInheritsToDescendants() {
        val doc = CXDocument.parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]")
        val html = root(doc)
        assertEquals("html", html.localName())
        assertEquals("http://www.w3.org/1999/xhtml", html.namespaceUri())
        assertEquals("http://www.w3.org/1999/xhtml", html.get("body")!!.namespaceUri())
    }

    @Test fun defaultNamespaceDoesNotApplyToAttrs() {
        val doc = CXDocument.parse("[html xmlns=urn:x id=top body]")
        val id = root(doc).attrs.first { it.name == "id" }
        assertNull(id.namespaceUri())
        assertEquals("id", id.localName())
    }

    @Test fun prefixedElementResolves() {
        val doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
        val title = root(doc).get("dc:title")!!
        assertEquals("title", title.localName())
        assertEquals("http://purl.org/dc/elements/1.1/", title.namespaceUri())
    }

    @Test fun prefixedAttributeResolves() {
        val doc = CXDocument.parse(
            "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]"
        )
        val href = root(doc).get("link")!!.attrs.first { it.name == "xl:href" }
        assertEquals("href", href.localName())
        assertEquals("http://www.w3.org/1999/xlink", href.namespaceUri())
    }

    @Test fun reservedXmlPrefix() {
        val doc = CXDocument.parse("[doc xml:base=https://example.com content]")
        val base = root(doc).attrs.first { it.name == "xml:base" }
        assertEquals(CXDocument.XML_NAMESPACE_URI, base.namespaceUri())
    }

    @Test fun reservedCxPrefix() {
        val doc = CXDocument.parse("[doc [cx:meta key=value]]")
        val meta = root(doc).get("cx:meta")!!
        assertEquals(CXDocument.CX_NAMESPACE_URI, meta.namespaceUri())
    }

    @Test fun undeclaredPrefix() {
        val doc = CXDocument.parse("[doc [foo:bar baz]]")
        val bar = root(doc).get("foo:bar")!!
        assertEquals("bar", bar.localName())
        assertNull(bar.namespaceUri())
    }

    @Test fun redeclarationOverridesDefault() {
        val doc = CXDocument.parse(
            "[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]"
        )
        val html = root(doc)
        val body = html.get("body")!!
        val svg = body.get("svg")!!
        val circle = svg.get("circle")!!
        assertEquals("http://www.w3.org/1999/xhtml", html.namespaceUri())
        assertEquals("http://www.w3.org/1999/xhtml", body.namespaceUri())
        assertEquals("http://www.w3.org/2000/svg", svg.namespaceUri())
        assertEquals("http://www.w3.org/2000/svg", circle.namespaceUri())
    }

    @Test fun emptyUriUndeclares() {
        val doc = CXDocument.parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]")
        val outer = root(doc)
        val inner = outer.get("inner")!!
        val child = inner.get("child")!!
        assertEquals("urn:x", outer.namespaceUri())
        assertNull(inner.namespaceUri())
        assertNull(child.namespaceUri())
    }

    @Test fun resolveIsIdempotent() {
        val doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]")
        val first = root(doc).get("dc:title")!!.namespaceUri()
        CXDocument.resolveNamespaces(doc)
        CXDocument.resolveNamespaces(doc)
        val second = root(doc).get("dc:title")!!.namespaceUri()
        assertEquals(first, second)
        assertEquals("http://purl.org/dc/elements/1.1/", first)
    }

    @Test fun xmlnsDeclarationAttrsHaveNoUri() {
        val doc = CXDocument.parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]")
        val decl = root(doc).attrs.first { it.name == "xmlns:dc" }
        assertNull(decl.namespaceUri())
        assertEquals("dc", decl.localName())
    }
}
