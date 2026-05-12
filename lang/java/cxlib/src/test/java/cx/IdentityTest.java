package cx;

import java.util.Map;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * ID/IDREF tests for the Java CX binding (ADR 0003).
 * Mirrors V conformance/identity.txt and lang/python/test_identity.py.
 */
public class IdentityTest {

    private static Element root(CXDocument d) {
        for (Node n : d.elements) if (n instanceof Element e) return e;
        throw new RuntimeException("no root element");
    }

    @Test
    void idDeclarationOnlyRoundTrips() throws Exception {
        String in = "[user #u-1 name=alice]";
        CXDocument doc = CXDocument.parse(in);
        assertEquals("u-1", root(doc).id);
        assertEquals(in, doc.toCx());
    }

    @Test
    void idWithAnchorCoexists() throws Exception {
        CXDocument doc = CXDocument.parse("[item &a #u-1 v=42]");
        Element item = root(doc);
        assertEquals("a", item.anchor);
        assertEquals("u-1", item.id);
    }

    @Test
    void attributeValueReferenceMarkedIsRef() throws Exception {
        CXDocument doc = CXDocument.parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]");
        Element reviewer = doc.findFirst("reviewer");
        Attr a = reviewer.attrs.stream().filter(x -> "assigned-to".equals(x.name)).findFirst().orElseThrow();
        assertTrue(a.isRef);
        assertEquals("u-1", a.value);
    }

    @Test
    void resolveIdFindsDeclaredElement() throws Exception {
        CXDocument doc = CXDocument.parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]");
        assertEquals("alice", doc.resolveId("u-1").attr("name"));
        assertEquals("bob", doc.resolveId("u-2").attr("name"));
        assertNull(doc.resolveId("u-3"));
    }

    @Test
    void elementsByIdBuildsFullMap() throws Exception {
        CXDocument doc = CXDocument.parse("[a #x v=1] [b #y v=2] [c #z v=3]");
        Map<String, Element> m = doc.elementsById();
        assertEquals(3, m.size());
        assertEquals("a", m.get("x").name);
        assertEquals("b", m.get("y").name);
        assertEquals("c", m.get("z").name);
    }

    @Test
    void quotedAtLiteralIsNotReference() throws Exception {
        String in = "[item label='@literal']";
        CXDocument doc = CXDocument.parse(in);
        Attr label = root(doc).attrs.stream().filter(a -> "label".equals(a.name)).findFirst().orElseThrow();
        assertFalse(label.isRef);
        assertEquals("@literal", label.value);
        assertEquals(in, doc.toCx());
    }

    @Test
    void forwardReferenceResolves() throws Exception {
        CXDocument doc = CXDocument.parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]");
        Element user = doc.resolveId("u-1");
        assertNotNull(user);
        assertEquals("alice", user.attr("name"));
    }

    @Test
    void nestedIdAndRefRoundTrip() throws Exception {
        String in = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]";
        CXDocument doc = CXDocument.parse(in);
        assertNotNull(doc.resolveId("u-1"));
        Element review = doc.findFirst("review");
        Attr target = review.attrs.stream().filter(a -> "target".equals(a.name)).findFirst().orElseThrow();
        assertTrue(target.isRef);
        assertEquals("u-1", target.value);
    }

    @Test
    void bodyRefSurvivesAstBinRoundTrip() throws Exception {
        // Phase 7.70 — ast_bin v3 carries body_ref through the V↔binding
        // boundary. The field is populated post-parse from the v3 wire
        // bytes, not re-detected from text.
        String cxIn = "[doc [section #section-3 [para See [ref @section-3].]]]";
        CXDocument doc = CXDocument.parse(cxIn);
        Element section = doc.findFirst("section");
        Element para = section.findFirst("para");
        Element refNode = null;
        for (Node n : para.items) {
            if (n instanceof Element e && "ref".equals(e.name)) { refNode = e; break; }
        }
        assertNotNull(refNode);
        assertEquals("section-3", refNode.bodyRef);
        assertTrue(refNode.attrs.isEmpty());
        assertTrue(refNode.items.isEmpty());
        assertTrue(doc.toCx().contains("[ref @section-3]"));
    }

    @Test
    void multipleRefsToSameId() throws Exception {
        CXDocument doc = CXDocument.parse(
            "[users [user #u-1 name=alice] "
            + "[reviewer assigned-to=@u-1] "
            + "[approver checked-by=@u-1]]");
        long count = 0;
        for (Element el : doc.findAll("reviewer")) {
            for (Attr a : el.attrs) if (a.isRef && "u-1".equals(a.value)) count++;
        }
        for (Element el : doc.findAll("approver")) {
            for (Attr a : el.attrs) if (a.isRef && "u-1".equals(a.value)) count++;
        }
        assertEquals(2, count);
    }
}
