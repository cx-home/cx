package cx

import com.google.gson.JsonParser
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

/**
 * ID/IDREF C ABI tests for the Kotlin CX binding (Phase 7.65, ADR 0003).
 * Mirrors the Python/Go reference impls.
 */
class IdAbiTest {

    private val doc = """
        [users
          [user #u-1 name=alice]
          [user #u-2 name=bob]
          [reviewer assigned-to=@u-1]
        ]
    """.trimIndent()

    @Test fun idLookupHappyPath() {
        val out = CxLib.idLookup(doc, "u-1")
        assertNotNull(out)
        assertTrue(out.isNotEmpty(), "expected non-empty result")
        val obj = JsonParser.parseString(out).asJsonObject
        assertEquals("Element", obj["type"].asString)
        assertEquals("user",    obj["name"].asString)
        assertEquals("u-1",     obj["id"].asString)
    }

    @Test fun idLookupMissingReturnsEmpty() {
        val out = CxLib.idLookup(doc, "does-not-exist")
        assertEquals("", out)
    }

    @Test fun resolveRefEqualsIdLookup() {
        val viaId  = CxLib.idLookup(doc, "u-2")
        val viaRef = CxLib.resolveRef(doc, "u-2")
        assertTrue(viaId.isNotEmpty())
        assertEquals(viaId, viaRef)
    }

    @Test fun nodeIdAtCxpath() {
        assertEquals("u-1", CxLib.nodeId(doc, "//user"))
        assertEquals("",    CxLib.nodeId(doc, "//reviewer"))
    }
}
