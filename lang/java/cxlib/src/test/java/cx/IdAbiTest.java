package cx;

import com.google.gson.Gson;
import com.google.gson.JsonObject;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * ID/IDREF C ABI tests for the Java CX binding (Phase 7.65, ADR 0003).
 * Mirrors the 3-case contract documented in the per-binding rollout
 * template; thin coverage of cx_id_lookup / cx_resolve_ref / cx_node_id.
 */
public class IdAbiTest {

    private static final String DOC =
        "[users\n" +
        "  [user #u-1 name=alice]\n" +
        "  [user #u-2 name=bob]\n" +
        "  [reviewer assigned-to=@u-1]\n" +
        "]";

    @Test
    void idLookupHappyPath() {
        String json = CxLib.idLookup(DOC, "u-1");
        assertNotNull(json);
        assertFalse(json.isEmpty(), "id_lookup of #u-1 should be non-empty");
        JsonObject o = new Gson().fromJson(json, JsonObject.class);
        assertEquals("Element", o.get("type").getAsString());
        assertEquals("user",    o.get("name").getAsString());
        assertEquals("u-1",     o.get("id").getAsString());
    }

    @Test
    void idLookupMissingReturnsEmpty() {
        String json = CxLib.idLookup(DOC, "does-not-exist");
        assertEquals("", json, "missing ID should yield the empty string");
    }

    @Test
    void resolveRefEqualsIdLookup() {
        String byId  = CxLib.idLookup(DOC, "u-2");
        String byRef = CxLib.resolveRef(DOC, "u-2");
        assertFalse(byId.isEmpty());
        assertEquals(byId, byRef, "resolve_ref must agree with id_lookup");
    }

    @Test
    void nodeIdAtCxpath() {
        // //user matches in document order — first user has id u-1.
        assertEquals("u-1", CxLib.nodeId(DOC, "//user"));
        // reviewer has no #id of its own.
        assertEquals("",    CxLib.nodeId(DOC, "//reviewer"));
    }
}
