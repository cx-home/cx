package cx

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

/**
 * ID/IDREF tests for the Kotlin CX binding (ADR 0003).
 * Mirrors V conformance/identity.txt.
 */
class IdentityTest {

    private fun root(d: CXDocument): Element =
        d.elements.filterIsInstance<Element>().first()

    @Test fun idDeclarationOnlyRoundTrips() {
        val cxIn = "[user #u-1 name=alice]"
        val doc = CXDocument.parse(cxIn)
        assertEquals("u-1", root(doc).id)
        assertEquals(cxIn, doc.toCx())
    }

    @Test fun idWithAnchorCoexists() {
        val doc = CXDocument.parse("[item &a #u-1 v=42]")
        val item = root(doc)
        assertEquals("a", item.anchor)
        assertEquals("u-1", item.id)
    }

    @Test fun attributeValueReferenceMarkedIsRef() {
        val doc = CXDocument.parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]")
        val reviewer = doc.findFirst("reviewer")!!
        val a = reviewer.attrs.first { it.name == "assigned-to" }
        assertTrue(a.isRef)
        assertEquals("u-1", a.value)
    }

    @Test fun resolveIdFindsDeclaredElement() {
        val doc = CXDocument.parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]")
        assertEquals("alice", doc.resolveId("u-1")!!.attr("name"))
        assertEquals("bob", doc.resolveId("u-2")!!.attr("name"))
        assertNull(doc.resolveId("u-3"))
    }

    @Test fun elementsByIdBuildsFullMap() {
        val doc = CXDocument.parse("[a #x v=1] [b #y v=2] [c #z v=3]")
        val m = doc.elementsById()
        assertEquals(3, m.size)
        assertEquals("a", m["x"]!!.name)
        assertEquals("b", m["y"]!!.name)
        assertEquals("c", m["z"]!!.name)
    }

    @Test fun quotedAtLiteralIsNotReference() {
        val cxIn = "[item label='@literal']"
        val doc = CXDocument.parse(cxIn)
        val label = root(doc).attrs.first { it.name == "label" }
        assertFalse(label.isRef)
        assertEquals("@literal", label.value)
        assertEquals(cxIn, doc.toCx())
    }

    @Test fun forwardReferenceResolves() {
        val doc = CXDocument.parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]")
        val user = doc.resolveId("u-1")
        assertNotNull(user)
        assertEquals("alice", user!!.attr("name"))
    }

    @Test fun nestedIdAndRefRoundTrip() {
        val cxIn = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]"
        val doc = CXDocument.parse(cxIn)
        assertNotNull(doc.resolveId("u-1"))
        val review = doc.findFirst("review")!!
        val target = review.attrs.first { it.name == "target" }
        assertTrue(target.isRef)
        assertEquals("u-1", target.value)
    }

    @Test fun bodyRefSurvivesAstBinRoundTrip() {
        // Phase 7.70 — ast_bin v3 carries bodyRef through the V↔binding
        // boundary. The field is populated post-parse from the v3 wire
        // bytes, not re-detected from text.
        val cxIn = "[doc [section #section-3 [para See [ref @section-3].]]]"
        val doc = CXDocument.parse(cxIn)
        val section = doc.findFirst("section")!!
        val para = section.findFirst("para")!!
        val refNode = para.items.filterIsInstance<Element>().first { it.name == "ref" }
        assertEquals("section-3", refNode.bodyRef)
        assertTrue(refNode.attrs.isEmpty())
        assertTrue(refNode.items.isEmpty())
        assertTrue("[ref @section-3]" in doc.toCx())
    }

    @Test fun multipleRefsToSameId() {
        val doc = CXDocument.parse(
            "[users [user #u-1 name=alice] " +
                "[reviewer assigned-to=@u-1] " +
                "[approver checked-by=@u-1]]"
        )
        var count = 0
        for (el in doc.findAll("reviewer") + doc.findAll("approver")) {
            for (a in el.attrs) {
                if (a.isRef && a.value == "u-1") count++
            }
        }
        assertEquals(2, count)
    }
}
