package cx

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class TableTest {

    @Test fun testFromCxSimple() {
        val src = """
            [users :table[name age:int]
              alice 30
              bob 25
            ]
        """.trimIndent()
        val t = Table.fromCx(src)
        assertEquals(2, t.rowCount)
        assertEquals(2, t.colCount)
    }

    @Test fun testFromCxNoTableThrows() {
        val e = assertThrows<IllegalArgumentException> {
            Table.fromCx("[product name=alice]")
        }
        assertTrue(e.message!!.contains("no :table"))
    }

    @Test fun testCreateValidatesLen() {
        val e = assertThrows<IllegalArgumentException> {
            Table.create(listOf("a", "b"), listOf("int"), emptyList())
        }
        assertTrue(e.message!!.contains("len(cols)"))
    }

    @Test fun testCreateValidatesUnique() {
        val e = assertThrows<IllegalArgumentException> {
            Table.create(listOf("a", "a"), listOf("int", "int"), emptyList())
        }
        assertTrue(e.message!!.contains("duplicate"))
    }

    @Test fun testRowAndColumn() {
        val t = Table.create(
            listOf("a", "b"),
            listOf("int", "string"),
            listOf(
                listOf(1L, "x"),
                listOf(2L, "y"),
            )
        )
        val row = t.row(0)
        assertEquals(1L, row["a"])
        assertEquals("x", row["b"])
        assertEquals(listOf<Any?>("x", "y"), t.column("b"))
    }

    @Test fun testSliceHeadTail() {
        val t = Table.create(
            listOf("v"),
            listOf("int"),
            listOf(listOf(1L), listOf(2L), listOf(3L), listOf(4L), listOf(5L)),
        )
        assertEquals(2, t.head(2).rowCount)
        assertEquals(2, t.tail(2).rowCount)
        assertEquals(3, t.slice(1, 4).rowCount)
    }

    @Test fun testSelectColsReorders() {
        val t = Table.create(
            listOf("a", "b", "c"),
            listOf("int", "int", "int"),
            listOf(listOf(1L, 2L, 3L)),
        )
        val sel = t.selectCols(listOf("c", "a"))
        assertEquals(listOf("c", "a"), sel.cols)
    }

    @Test fun testIteration() {
        val t = Table.create(
            listOf("a"),
            listOf("int"),
            listOf(listOf(1L), listOf(2L)),
        )
        var sum = 0L
        for (row in t) sum += row["a"] as Long
        assertEquals(3L, sum)
    }

    @Test fun testToCx() {
        val t = Table.create(
            listOf("a"),
            listOf("int"),
            listOf(listOf(1L)),
        )
        assertTrue(t.toCx().contains(":table[a:int]"))
    }

    @Test fun testToJson() {
        val t = Table.create(
            listOf("a"),
            listOf("int"),
            listOf(listOf(1L), listOf(2L)),
        )
        assertTrue(t.toJson().contains("\"a\":1"))
    }

    @Test fun testEquals() {
        val a = Table.create(listOf("a"), listOf("int"), listOf(listOf(1L)))
        val b = Table.create(listOf("a"), listOf("int"), listOf(listOf(1L)))
        assertEquals(a, b)
    }

    @Test fun testFromCxCollectionCells() {
        val src = """
            [u :table[name tags]
              alice [admin, user,]
            ]
        """.trimIndent()
        val t = Table.fromCx(src)
        val row = t.row(0)
        assertTrue(row["tags"] is List<*>, "tags should be a List, got: ${row["tags"]}")
    }
}
