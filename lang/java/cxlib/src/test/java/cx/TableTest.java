package cx;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

public class TableTest {

    @Test
    public void testFromCxSimple() {
        String src = "[users :table[name age:int]\n" +
                     "  alice 30\n" +
                     "  bob 25\n" +
                     "]";
        Table t = Table.fromCx(src);
        assertEquals(2, t.rowCount());
        assertEquals(2, t.colCount());
    }

    @Test
    public void testFromCxNoTableErrors() {
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class,
            () -> Table.fromCx("[product name=alice]")
        );
        assertTrue(e.getMessage().contains("no :table"));
    }

    @Test
    public void testCreateValidatesLen() {
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class,
            () -> Table.create(
                Arrays.asList("a", "b"),
                Arrays.asList("int"),
                java.util.Collections.emptyList()
            )
        );
        assertTrue(e.getMessage().contains("len(cols)"));
    }

    @Test
    public void testCreateValidatesUnique() {
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class,
            () -> Table.create(
                Arrays.asList("a", "a"),
                Arrays.asList("int", "int"),
                java.util.Collections.emptyList()
            )
        );
        assertTrue(e.getMessage().contains("duplicate"));
    }

    @Test
    public void testRowAndColumn() {
        Table t = Table.create(
            Arrays.asList("a", "b"),
            Arrays.asList("int", "string"),
            Arrays.asList(
                Arrays.asList((Object) 1L, "x"),
                Arrays.asList((Object) 2L, "y")
            )
        );
        Map<String, Object> row = t.row(0);
        assertEquals(1L, row.get("a"));
        assertEquals("x", row.get("b"));
        List<Object> col = t.column("b");
        assertEquals(Arrays.asList("x", "y"), col);
    }

    @Test
    public void testSliceHeadTail() {
        Table t = Table.create(
            Arrays.asList("v"),
            Arrays.asList("int"),
            Arrays.asList(
                Arrays.<Object>asList(1L),
                Arrays.<Object>asList(2L),
                Arrays.<Object>asList(3L),
                Arrays.<Object>asList(4L),
                Arrays.<Object>asList(5L)
            )
        );
        assertEquals(2, t.head(2).rowCount());
        assertEquals(2, t.tail(2).rowCount());
        assertEquals(3, t.slice(1, 4).rowCount());
    }

    @Test
    public void testSelectColsReorders() {
        Table t = Table.create(
            Arrays.asList("a", "b", "c"),
            Arrays.asList("int", "int", "int"),
            Arrays.asList(Arrays.<Object>asList(1L, 2L, 3L))
        );
        Table sel = t.selectCols(Arrays.asList("c", "a"));
        assertEquals(Arrays.asList("c", "a"), sel.cols());
    }

    @Test
    public void testToCx() {
        Table t = Table.create(
            Arrays.asList("a"),
            Arrays.asList("int"),
            Arrays.asList(Arrays.<Object>asList(1L))
        );
        String out = t.toCx();
        assertTrue(out.contains(":table[a:int]"));
    }

    @Test
    public void testToJson() {
        Table t = Table.create(
            Arrays.asList("a"),
            Arrays.asList("int"),
            Arrays.asList(
                Arrays.<Object>asList(1L),
                Arrays.<Object>asList(2L)
            )
        );
        String js = t.toJson();
        assertTrue(js.contains("\"a\":1"));
    }

    @Test
    public void testEquals() {
        Table a = Table.create(
            Arrays.asList("a"),
            Arrays.asList("int"),
            Arrays.asList(Arrays.<Object>asList(1L))
        );
        Table b = Table.create(
            Arrays.asList("a"),
            Arrays.asList("int"),
            Arrays.asList(Arrays.<Object>asList(1L))
        );
        assertEquals(a, b);
    }

    @Test
    public void testFromCxCollectionCells() {
        String src = "[u :table[name tags]\n" +
                     "  alice [admin, user,]\n" +
                     "]";
        Table t = Table.fromCx(src);
        Map<String, Object> row = t.row(0);
        Object tags = row.get("tags");
        assertTrue(tags instanceof List<?>, "tags should be a List, got: " + tags);
    }
}
