package cx

import com.google.gson.Gson

/**
 * CX Kotlin binding — Public Table API per ADR 0018 D1.
 *
 * 17-member canonical Table API against the V core's `:table` blocks
 * via the C ABI. Per ADR 0018 §D2: Kotlin uses camelCase methods
 * matching the canonical surface.
 */
class Table private constructor(
    private val colsArr: Array<String>,
    private val typesArr: Array<String>,
    private val rowsArr: Array<Array<Any?>>,
) : Iterable<Map<String, Any?>> {

    // ── Properties (4) ───────────────────────────────────────────────────────

    val cols: List<String> get() = colsArr.toList()
    val types: List<String> get() = typesArr.toList()
    val rowCount: Int get() = rowsArr.size
    val colCount: Int get() = colsArr.size

    // ── Access (9) ───────────────────────────────────────────────────────────

    fun row(i: Int): Map<String, Any?> {
        require(i in rowsArr.indices) {
            "cxlib: row index $i out of bounds [0, ${rowsArr.size})"
        }
        val out = LinkedHashMap<String, Any?>(colsArr.size)
        for (c in colsArr.indices) out[colsArr[c]] = rowsArr[i][c]
        return out
    }

    fun column(name: String): List<Any?> {
        val idx = colsArr.indexOf(name)
        require(idx >= 0) { "cxlib: unknown column \"$name\"" }
        return colAt(idx)
    }

    fun colAt(i: Int): List<Any?> {
        require(i in colsArr.indices) {
            "cxlib: column index $i out of bounds [0, ${colsArr.size})"
        }
        return rowsArr.map { it[i] }
    }

    fun cell(r: Int, c: Int): Any? {
        require(r in rowsArr.indices) {
            "cxlib: row index $r out of bounds [0, ${rowsArr.size})"
        }
        require(c in colsArr.indices) {
            "cxlib: column index $c out of bounds [0, ${colsArr.size})"
        }
        return rowsArr[r][c]
    }

    fun cellByName(r: Int, name: String): Any? {
        val idx = colsArr.indexOf(name)
        require(idx >= 0) { "cxlib: unknown column \"$name\"" }
        return cell(r, idx)
    }

    fun slice(start: Int, end: Int): Table {
        require(start in 0..rowsArr.size) { "cxlib: slice start $start out of bounds" }
        require(end in start..rowsArr.size) { "cxlib: slice end $end out of bounds (start=$start)" }
        val sub = Array(end - start) { i -> rowsArr[start + i].copyOf() }
        return Table(colsArr, typesArr, sub)
    }

    fun head(n: Int): Table = slice(0, minOf(maxOf(n, 0), rowsArr.size))

    fun tail(n: Int): Table {
        val start = maxOf(0, rowsArr.size - n)
        return slice(start, rowsArr.size)
    }

    /**
     * `selectCols` — renamed from canonical `select` to mirror the
     * other bindings' rename pattern. Kotlin itself has no `select`
     * conflict, but consistency wins.
     */
    fun selectCols(names: List<String>): Table {
        val indices = IntArray(names.size)
        val newCols = Array(names.size) { "" }
        val newTypes = Array(names.size) { "" }
        for ((j, name) in names.withIndex()) {
            val idx = colsArr.indexOf(name)
            require(idx >= 0) { "cxlib: unknown column \"$name\"" }
            indices[j] = idx
            newCols[j] = colsArr[idx]
            newTypes[j] = typesArr[idx]
        }
        val newRows = Array(rowsArr.size) { r ->
            Array<Any?>(indices.size) { j -> rowsArr[r][indices[j]] }
        }
        return Table(newCols, newTypes, newRows)
    }

    // ── Iteration (2) ────────────────────────────────────────────────────────

    override fun iterator(): Iterator<Map<String, Any?>> = iterator {
        for (i in rowsArr.indices) yield(row(i))
    }

    fun iterCols(): Sequence<ColumnView> = sequence {
        for (i in colsArr.indices) {
            yield(ColumnView(colsArr[i], typesArr[i], colAt(i)))
        }
    }

    // ── Conversion (5) ───────────────────────────────────────────────────────

    fun toCx(): String {
        val sb = StringBuilder()
        sb.append("[_ :table[")
        for (i in colsArr.indices) {
            if (i > 0) sb.append(' ')
            sb.append(colsArr[i])
            if (typesArr[i].isNotEmpty()) { sb.append(':'); sb.append(typesArr[i]) }
        }
        sb.append("]\n")
        for (row in rowsArr) {
            sb.append("  ")
            for (i in row.indices) {
                if (i > 0) sb.append(' ')
                sb.append(formatCxCell(row[i]))
            }
            sb.append('\n')
        }
        sb.append("]\n")
        return sb.toString()
    }

    fun toCsv(delim: Char = ','): String {
        val sb = StringBuilder()
        for (i in colsArr.indices) {
            if (i > 0) sb.append(delim)
            sb.append(colsArr[i])
        }
        sb.append("\r\n")
        for (row in rowsArr) {
            for (i in row.indices) {
                if (i > 0) sb.append(delim)
                sb.append(formatCsvCell(row[i], delim))
            }
            sb.append("\r\n")
        }
        return sb.toString()
    }

    fun toJson(): String = GSON.toJson(toDictList())

    fun toDataBin(): ByteArray = CxLib.toDataBin(toCx())

    fun toDictList(): List<Map<String, Any?>> = (0 until rowsArr.size).map { row(it) }

    // ── Equality ─────────────────────────────────────────────────────────────

    override fun equals(other: Any?): Boolean {
        if (other !is Table) return false
        if (!colsArr.contentEquals(other.colsArr)) return false
        if (!typesArr.contentEquals(other.typesArr)) return false
        if (rowsArr.size != other.rowsArr.size) return false
        for (r in rowsArr.indices) {
            if (rowsArr[r].size != other.rowsArr[r].size) return false
            for (c in rowsArr[r].indices) {
                if (!cellEquals(rowsArr[r][c], other.rowsArr[r][c])) return false
            }
        }
        return true
    }

    override fun hashCode(): Int {
        var h = colsArr.contentHashCode()
        h = 31 * h + typesArr.contentHashCode()
        h = 31 * h + rowsArr.size
        return h
    }

    companion object {
        private val GSON = Gson()

        /** Parse CX source and return the first `:table` block. */
        fun fromCx(src: String): Table {
            val tables = fromCxAll(src)
            require(tables.isNotEmpty()) { "cxlib: no :table block found in source" }
            return tables[0]
        }

        /** Return every `:table` block in the source (preorder). */
        fun fromCxAll(src: String): List<Table> {
            val payload = CxLib.toDataBin(src)
            val decoded = DataBin.decode(payload)
            val out = mutableListOf<Table>()
            collectTables(decoded, out)
            return out
        }

        /** Direct construction with 4-invariant validation per ADR 0018 §D7. */
        fun create(
            cols: List<String>,
            types: List<String>,
            rows: List<List<Any?>>,
        ): Table {
            require(cols.size == types.size) {
                "cxlib: len(cols)=${cols.size} != len(types)=${types.size}"
            }
            val seen = mutableSetOf<String>()
            for (c in cols) {
                require(seen.add(c)) { "cxlib: duplicate column name \"$c\"" }
            }
            val rowArr = Array(rows.size) { i ->
                require(rows[i].size == cols.size) {
                    "cxlib: row $i has ${rows[i].size} cells; expected ${cols.size}"
                }
                rows[i].toTypedArray()
            }
            return Table(cols.toTypedArray(), types.toTypedArray(), rowArr)
        }

        private fun collectTables(value: Any?, out: MutableList<Table>) {
            when (value) {
                null -> return
                is Map<*, *> -> for (child in value.values) collectTables(child, out)
                is List<*> -> {
                    if (looksLikeTable(value)) {
                        @Suppress("UNCHECKED_CAST")
                        val rows = value as List<Map<String, Any?>>
                        val keys = rows[0].keys.sorted()
                        val types = keys.map { "" }
                        val rowsList = rows.map { d -> keys.map { k -> d[k] } }
                        out.add(create(keys, types, rowsList))
                    } else {
                        for (child in value) collectTables(child, out)
                    }
                }
            }
        }

        private fun looksLikeTable(list: List<*>): Boolean {
            if (list.isEmpty()) return false
            val first = list[0] as? Map<*, *> ?: return false
            val keys = first.keys
            if (keys.isEmpty()) return false
            return list.all { item ->
                val m = item as? Map<*, *> ?: return false
                m.size == keys.size && m.keys.containsAll(keys)
            }
        }
    }
}

/** Column iterator view. */
data class ColumnView(val name: String, val typeName: String, val values: List<Any?>)

// ── Internal: cell formatters / equality ────────────────────────────────────

private fun formatCxCell(v: Any?): String {
    return when (v) {
        null -> "null"
        is Boolean -> if (v) "true" else "false"
        is Long, is Int, is Short, is Byte -> v.toString()
        is Double, is Float -> v.toString()
        is List<*> -> v.joinToString(prefix = "[", postfix = "]", separator = ", ") { formatCxCell(it) }
        is Map<*, *> -> {
            @Suppress("UNCHECKED_CAST")
            val m = v as Map<String, Any?>
            m.entries.sortedBy { it.key }.joinToString(prefix = "{", postfix = "}", separator = ", ") {
                "${formatCxKey(it.key)}: ${formatCxCell(it.value)}"
            }
        }
        else -> {
            val s = v.toString()
            if (s.isEmpty() || s.any { it.isWhitespace() || it in "'[](){},"}) {
                "'" + s.replace("'", "''") + "'"
            } else s
        }
    }
}

private fun formatCxKey(k: String): String {
    val simple = k.isNotEmpty() && k.withIndex().all { (i, ch) ->
        ch == '_' ||
            ch in 'a'..'z' || ch in 'A'..'Z' ||
            (i > 0 && ch in '0'..'9')
    }
    return if (simple) k else "'" + k.replace("'", "''") + "'"
}

private fun formatCsvCell(v: Any?, delim: Char): String {
    if (v == null) return ""
    if (v is Map<*, *> || v is List<*>) {
        val json = Gson().toJson(v)
        return "\"" + json.replace("\"", "\"\"") + "\""
    }
    if (v is Boolean) return if (v) "true" else "false"
    val s = v.toString()
    if (s.contains(delim) || s.contains('"') || s.contains('\n') || s.contains('\r')) {
        return "\"" + s.replace("\"", "\"\"") + "\""
    }
    return s
}

private fun cellEquals(a: Any?, b: Any?): Boolean {
    if (a === b) return true
    if (a == null || b == null) return false
    if (a is List<*> && b is List<*>) {
        if (a.size != b.size) return false
        for (i in a.indices) if (!cellEquals(a[i], b[i])) return false
        return true
    }
    if (a is Map<*, *> && b is Map<*, *>) {
        if (a.size != b.size) return false
        for ((k, v) in a) {
            if (!b.containsKey(k)) return false
            if (!cellEquals(v, b[k])) return false
        }
        return true
    }
    return a == b
}
