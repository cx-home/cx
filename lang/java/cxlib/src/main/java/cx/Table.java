// CX Java binding — Public Table API per ADR 0018 D1.
//
// Implements the 17-member canonical Table API against the V core's
// :table blocks via the C ABI. Per ADR 0018 §D2 per-binding naming:
// Java uses camelCase methods + JavaBean-ish accessors (no get-prefix
// on the canonical properties — they're properties not getters).

package cx;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;

/**
 * Immutable handle over a single :table block. Per ADR 0018 §D3
 * tables are immutable values; methods that produce a new table
 * return a fresh instance rather than mutating in place.
 */
public final class Table {
    private final List<String> cols;
    private final List<String> types;
    private final List<List<Object>> rows;

    private Table(List<String> cols, List<String> types, List<List<Object>> rows) {
        this.cols = Collections.unmodifiableList(new ArrayList<>(cols));
        this.types = Collections.unmodifiableList(new ArrayList<>(types));
        ArrayList<List<Object>> rowsCopy = new ArrayList<>(rows.size());
        for (List<Object> row : rows) {
            rowsCopy.add(Collections.unmodifiableList(new ArrayList<>(row)));
        }
        this.rows = Collections.unmodifiableList(rowsCopy);
    }

    // ── Construction ─────────────────────────────────────────────────────────

    /**
     * Parse CX source and return the first :table block found.
     * Throws IllegalArgumentException when no :table is present.
     */
    public static Table fromCx(String src) {
        List<Table> tables = fromCxAll(src);
        if (tables.isEmpty()) {
            throw new IllegalArgumentException(
                "cxlib: no :table block found in source"
            );
        }
        return tables.get(0);
    }

    /**
     * Return every :table block in the source in document order.
     */
    public static List<Table> fromCxAll(String src) {
        byte[] payload = CxLib.toDataBin(src);
        Object decoded = DataBin.decode(payload);
        List<Table> out = new ArrayList<>();
        collectTables(decoded, out);
        return out;
    }

    /**
     * Construct directly with 4-invariant validation per ADR 0018 §D7.
     */
    public static Table create(
        List<String> cols,
        List<String> types,
        List<List<Object>> rows
    ) {
        if (cols.size() != types.size()) {
            throw new IllegalArgumentException(
                "cxlib: len(cols)=" + cols.size() +
                " != len(types)=" + types.size()
            );
        }
        Set<String> seen = new HashSet<>();
        for (String c : cols) {
            if (!seen.add(c)) {
                throw new IllegalArgumentException(
                    "cxlib: duplicate column name \"" + c + "\""
                );
            }
        }
        for (int i = 0; i < rows.size(); i++) {
            if (rows.get(i).size() != cols.size()) {
                throw new IllegalArgumentException(
                    "cxlib: row " + i + " has " + rows.get(i).size() +
                    " cells; expected " + cols.size()
                );
            }
        }
        return new Table(cols, types, rows);
    }

    // ── Properties (4) ───────────────────────────────────────────────────────

    public List<String> cols() { return cols; }
    public List<String> types() { return types; }
    public int rowCount() { return rows.size(); }
    public int colCount() { return cols.size(); }

    // ── Access (9) ───────────────────────────────────────────────────────────

    public Map<String, Object> row(int i) {
        if (i < 0 || i >= rows.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: row index " + i + " out of bounds [0, " + rows.size() + ")"
            );
        }
        LinkedHashMap<String, Object> out = new LinkedHashMap<>();
        List<Object> r = rows.get(i);
        for (int c = 0; c < cols.size(); c++) {
            out.put(cols.get(c), r.get(c));
        }
        return out;
    }

    public List<Object> column(String name) {
        int idx = cols.indexOf(name);
        if (idx < 0) {
            throw new IllegalArgumentException(
                "cxlib: unknown column \"" + name + "\""
            );
        }
        return colAt(idx);
    }

    public List<Object> colAt(int i) {
        if (i < 0 || i >= cols.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: column index " + i + " out of bounds [0, " + cols.size() + ")"
            );
        }
        List<Object> out = new ArrayList<>(rows.size());
        for (List<Object> row : rows) {
            out.add(row.get(i));
        }
        return out;
    }

    public Object cell(int r, int c) {
        if (r < 0 || r >= rows.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: row index " + r + " out of bounds [0, " + rows.size() + ")"
            );
        }
        if (c < 0 || c >= cols.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: column index " + c + " out of bounds [0, " + cols.size() + ")"
            );
        }
        return rows.get(r).get(c);
    }

    public Object cellByName(int r, String name) {
        int idx = cols.indexOf(name);
        if (idx < 0) {
            throw new IllegalArgumentException(
                "cxlib: unknown column \"" + name + "\""
            );
        }
        return cell(r, idx);
    }

    public Table slice(int start, int end) {
        if (start < 0 || start > rows.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: slice start " + start + " out of bounds"
            );
        }
        if (end < start || end > rows.size()) {
            throw new IndexOutOfBoundsException(
                "cxlib: slice end " + end + " out of bounds (start=" + start + ")"
            );
        }
        return new Table(cols, types,
            new ArrayList<>(rows.subList(start, end)));
    }

    public Table head(int n) {
        int end = Math.min(Math.max(n, 0), rows.size());
        return slice(0, end);
    }

    public Table tail(int n) {
        int start = Math.max(0, rows.size() - n);
        return slice(start, rows.size());
    }

    /**
     * Returns a new Table with only the named columns in the given order.
     * Renamed from canonical `select` to avoid shadowing the (uncommon but
     * possible) java.nio.channels.Selector pattern; Java doesn't reserve
     * `select`, but `selectCols` is clearer for readers.
     */
    public Table selectCols(List<String> names) {
        List<Integer> indices = new ArrayList<>(names.size());
        List<String> newCols = new ArrayList<>(names.size());
        List<String> newTypes = new ArrayList<>(names.size());
        for (String name : names) {
            int idx = cols.indexOf(name);
            if (idx < 0) {
                throw new IllegalArgumentException(
                    "cxlib: unknown column \"" + name + "\""
                );
            }
            indices.add(idx);
            newCols.add(cols.get(idx));
            newTypes.add(types.get(idx));
        }
        List<List<Object>> newRows = new ArrayList<>(rows.size());
        for (List<Object> row : rows) {
            List<Object> newRow = new ArrayList<>(indices.size());
            for (int idx : indices) {
                newRow.add(row.get(idx));
            }
            newRows.add(newRow);
        }
        return new Table(newCols, newTypes, newRows);
    }

    // ── Iteration (2) ────────────────────────────────────────────────────────

    /**
     * Returns an iterable of rows (each as an ordered map).
     * Java's `Iterable<Map<String, Object>>` enables `for (Map row : t.iter())`.
     */
    public Iterable<Map<String, Object>> iter() {
        return () -> new java.util.Iterator<Map<String, Object>>() {
            int i = 0;
            @Override public boolean hasNext() { return i < rows.size(); }
            @Override public Map<String, Object> next() { return row(i++); }
        };
    }

    /**
     * Yields (name, type_name, values) per column in declaration order.
     */
    public Iterable<ColumnView> iterCols() {
        return () -> new java.util.Iterator<ColumnView>() {
            int i = 0;
            @Override public boolean hasNext() { return i < cols.size(); }
            @Override public ColumnView next() {
                ColumnView cv = new ColumnView(
                    cols.get(i), types.get(i), colAt(i)
                );
                i++;
                return cv;
            }
        };
    }

    /**
     * (name, type_name, values) triple per ADR 0018 §3.3.
     */
    public static final class ColumnView {
        public final String name;
        public final String typeName;
        public final List<Object> values;
        public ColumnView(String name, String typeName, List<Object> values) {
            this.name = name;
            this.typeName = typeName;
            this.values = values;
        }
    }

    // ── Conversion (5) ───────────────────────────────────────────────────────

    public String toCx() {
        StringBuilder header = new StringBuilder();
        for (int i = 0; i < cols.size(); i++) {
            if (i > 0) header.append(' ');
            header.append(cols.get(i));
            if (!types.get(i).isEmpty()) {
                header.append(':').append(types.get(i));
            }
        }
        StringBuilder out = new StringBuilder();
        out.append("[_ :table[").append(header).append("]\n");
        for (List<Object> row : rows) {
            out.append("  ");
            for (int j = 0; j < row.size(); j++) {
                if (j > 0) out.append(' ');
                out.append(formatCxCell(row.get(j)));
            }
            out.append('\n');
        }
        out.append("]\n");
        return out.toString();
    }

    public String toCsv(char delim) {
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < cols.size(); i++) {
            if (i > 0) out.append(delim);
            out.append(cols.get(i));
        }
        out.append("\r\n");
        for (List<Object> row : rows) {
            for (int j = 0; j < row.size(); j++) {
                if (j > 0) out.append(delim);
                out.append(formatCsvCell(row.get(j), delim));
            }
            out.append("\r\n");
        }
        return out.toString();
    }

    public String toJson() {
        StringBuilder out = new StringBuilder();
        out.append('[');
        boolean firstRow = true;
        for (List<Object> row : rows) {
            if (!firstRow) out.append(',');
            firstRow = false;
            out.append('{');
            for (int j = 0; j < cols.size(); j++) {
                if (j > 0) out.append(',');
                out.append(jsonString(cols.get(j)))
                   .append(':')
                   .append(formatJsonCell(row.get(j)));
            }
            out.append('}');
        }
        out.append(']');
        return out.toString();
    }

    public byte[] toDataBin() {
        return CxLib.toDataBin(toCx());
    }

    public List<Map<String, Object>> toDictList() {
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (int i = 0; i < rows.size(); i++) {
            out.add(row(i));
        }
        return out;
    }

    // ── Equality ─────────────────────────────────────────────────────────────

    @Override
    public boolean equals(Object o) {
        if (!(o instanceof Table)) return false;
        Table t = (Table) o;
        return cols.equals(t.cols) && types.equals(t.types) && rows.equals(t.rows);
    }

    @Override
    public int hashCode() {
        return Objects.hash(cols, types, rows);
    }

    @Override
    public String toString() {
        return "Table(cols=" + cols + ", types=" + types +
            ", rows=" + rows.size() + ")";
    }

    // ── Internal: walk a decoded data_bin Value to find tables ───────────────

    @SuppressWarnings("unchecked")
    private static void collectTables(Object value, List<Table> out) {
        if (value instanceof Map<?, ?>) {
            Map<String, Object> m = (Map<String, Object>) value;
            for (Object child : m.values()) {
                collectTables(child, out);
            }
        } else if (value instanceof List<?>) {
            List<Object> list = (List<Object>) value;
            if (looksLikeTable(list)) {
                Map<String, Object> first = (Map<String, Object>) list.get(0);
                List<String> cols = new ArrayList<>(first.keySet());
                Collections.sort(cols);
                List<String> types = new ArrayList<>(cols.size());
                for (int i = 0; i < cols.size(); i++) types.add("");
                List<List<Object>> rows = new ArrayList<>(list.size());
                for (Object item : list) {
                    Map<String, Object> m = (Map<String, Object>) item;
                    List<Object> row = new ArrayList<>(cols.size());
                    for (String c : cols) row.add(m.get(c));
                    rows.add(row);
                }
                out.add(new Table(cols, types, rows));
            } else {
                for (Object child : list) {
                    collectTables(child, out);
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static boolean looksLikeTable(List<Object> value) {
        if (value.isEmpty()) return false;
        if (!(value.get(0) instanceof Map<?, ?>)) return false;
        Map<String, Object> first = (Map<String, Object>) value.get(0);
        if (first.isEmpty()) return false;
        Set<String> keys = first.keySet();
        for (Object item : value) {
            if (!(item instanceof Map<?, ?>)) return false;
            Map<String, Object> m = (Map<String, Object>) item;
            if (!m.keySet().equals(keys)) return false;
        }
        return true;
    }

    // ── Internal: cell formatters ────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private static String formatCxCell(Object v) {
        if (v == null) return "null";
        if (v instanceof Boolean) return ((Boolean) v) ? "true" : "false";
        if (v instanceof Number) return v.toString();
        if (v instanceof List<?>) {
            StringBuilder out = new StringBuilder("[");
            List<Object> list = (List<Object>) v;
            for (int i = 0; i < list.size(); i++) {
                if (i > 0) out.append(", ");
                out.append(formatCxCell(list.get(i)));
            }
            return out.append("]").toString();
        }
        if (v instanceof Map<?, ?>) {
            Map<String, Object> m = (Map<String, Object>) v;
            // Lex-sorted keys per ADR 0017 §D14 canonical
            TreeMap<String, Object> sorted = new TreeMap<>(m);
            StringBuilder out = new StringBuilder("{");
            boolean first = true;
            for (Map.Entry<String, Object> e : sorted.entrySet()) {
                if (!first) out.append(", ");
                first = false;
                out.append(formatCxKey(e.getKey()))
                   .append(": ")
                   .append(formatCxCell(e.getValue()));
            }
            return out.append("}").toString();
        }
        // String — quote if special chars present
        String s = v.toString();
        if (s.isEmpty() || s.matches(".*[\\s'\\[\\](){}{,].*")) {
            return "'" + s.replace("'", "''") + "'";
        }
        return s;
    }

    private static String formatCxKey(String k) {
        if (k.isEmpty() || !k.matches("^[a-zA-Z_][a-zA-Z0-9_]*$")) {
            return "'" + k.replace("'", "''") + "'";
        }
        return k;
    }

    private static String formatCsvCell(Object v, char delim) {
        if (v == null) return "";
        if (v instanceof List<?> || v instanceof Map<?, ?>) {
            String json = formatJsonCell(v);
            return "\"" + json.replace("\"", "\"\"") + "\"";
        }
        if (v instanceof Boolean) return ((Boolean) v) ? "true" : "false";
        String s = v.toString();
        if (s.indexOf(delim) >= 0 || s.indexOf('"') >= 0 ||
            s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0) {
            return "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    @SuppressWarnings("unchecked")
    private static String formatJsonCell(Object v) {
        if (v == null) return "null";
        if (v instanceof Boolean) return ((Boolean) v) ? "true" : "false";
        if (v instanceof Number) return v.toString();
        if (v instanceof List<?>) {
            StringBuilder out = new StringBuilder("[");
            List<Object> list = (List<Object>) v;
            for (int i = 0; i < list.size(); i++) {
                if (i > 0) out.append(',');
                out.append(formatJsonCell(list.get(i)));
            }
            return out.append(']').toString();
        }
        if (v instanceof Map<?, ?>) {
            StringBuilder out = new StringBuilder("{");
            Map<String, Object> m = (Map<String, Object>) v;
            boolean first = true;
            for (Map.Entry<String, Object> e : m.entrySet()) {
                if (!first) out.append(',');
                first = false;
                out.append(jsonString(e.getKey()))
                   .append(':')
                   .append(formatJsonCell(e.getValue()));
            }
            return out.append('}').toString();
        }
        return jsonString(v.toString());
    }

    private static String jsonString(String s) {
        StringBuilder out = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"':  out.append("\\\""); break;
                case '\\': out.append("\\\\"); break;
                case '\n': out.append("\\n"); break;
                case '\r': out.append("\\r"); break;
                case '\t': out.append("\\t"); break;
                default:
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
            }
        }
        return out.append('"').toString();
    }
}
