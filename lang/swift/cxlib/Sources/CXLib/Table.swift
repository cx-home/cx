// CX Swift binding — Public Table API per ADR 0018 D1.
//
// 17-member canonical Table surface against the V core's `:table` blocks
// via the C ABI. Per ADR 0018 §D2: Swift uses camelCase methods matching
// the canonical surface.

import Foundation

/// Column iterator view (returned by `Table.iterCols()`).
public struct ColumnView {
    public let name: String
    public let typeName: String
    public let values: [Any?]
}

/// Immutable handle over a single `:table` block. Implements the
/// 17-member canonical Table API (ADR 0018 §D1).
public final class Table: Sequence {
    private let _cols: [String]
    private let _types: [String]
    private let _rows: [[Any?]]

    private init(cols: [String], types: [String], rows: [[Any?]]) {
        self._cols = cols
        self._types = types
        self._rows = rows
    }

    // ── Construction ─────────────────────────────────────────────────────────

    /// Parse CX source and return the first `:table` block.
    public static func fromCx(_ src: String) throws -> Table {
        let tables = try fromCxAll(src)
        guard let first = tables.first else {
            throw CXError.parse("cxlib: no :table block found in source")
        }
        return first
    }

    /// Return every `:table` block in the source (preorder).
    public static func fromCxAll(_ src: String) throws -> [Table] {
        let payload = try CXLib.toDataBin(src)
        let decoded = try DataBin.decode(payload)
        var out: [Table] = []
        collectTables(decoded, into: &out)
        return out
    }

    /// Direct construction with 4-invariant validation per ADR 0018 §D7.
    public static func create(
        cols: [String],
        types: [String],
        rows: [[Any?]]
    ) throws -> Table {
        guard cols.count == types.count else {
            throw CXError.parse("cxlib: len(cols)=\(cols.count) != len(types)=\(types.count)")
        }
        var seen = Set<String>()
        for c in cols {
            if !seen.insert(c).inserted {
                throw CXError.parse("cxlib: duplicate column name \"\(c)\"")
            }
        }
        for (i, r) in rows.enumerated() {
            if r.count != cols.count {
                throw CXError.parse("cxlib: row \(i) has \(r.count) cells; expected \(cols.count)")
            }
        }
        return Table(cols: cols, types: types, rows: rows)
    }

    // ── Properties (4) ───────────────────────────────────────────────────────

    public var cols: [String] { _cols }
    public var types: [String] { _types }
    public var rowCount: Int { _rows.count }
    public var colCount: Int { _cols.count }

    // ── Access (9) ───────────────────────────────────────────────────────────

    public func row(_ i: Int) throws -> [String: Any?] {
        guard i >= 0 && i < _rows.count else {
            throw CXError.parse("cxlib: row index \(i) out of bounds [0, \(_rows.count))")
        }
        var out: [String: Any?] = [:]
        for c in 0 ..< _cols.count { out[_cols[c]] = _rows[i][c] }
        return out
    }

    public func column(_ name: String) throws -> [Any?] {
        guard let idx = _cols.firstIndex(of: name) else {
            throw CXError.parse("cxlib: unknown column \"\(name)\"")
        }
        return try colAt(idx)
    }

    public func colAt(_ i: Int) throws -> [Any?] {
        guard i >= 0 && i < _cols.count else {
            throw CXError.parse("cxlib: column index \(i) out of bounds [0, \(_cols.count))")
        }
        return _rows.map { $0[i] }
    }

    public func cell(_ r: Int, _ c: Int) throws -> Any? {
        guard r >= 0 && r < _rows.count else {
            throw CXError.parse("cxlib: row index \(r) out of bounds [0, \(_rows.count))")
        }
        guard c >= 0 && c < _cols.count else {
            throw CXError.parse("cxlib: column index \(c) out of bounds [0, \(_cols.count))")
        }
        return _rows[r][c]
    }

    public func cellByName(_ r: Int, _ name: String) throws -> Any? {
        guard let idx = _cols.firstIndex(of: name) else {
            throw CXError.parse("cxlib: unknown column \"\(name)\"")
        }
        return try cell(r, idx)
    }

    public func slice(_ start: Int, _ end: Int) throws -> Table {
        guard start >= 0 && start <= _rows.count else {
            throw CXError.parse("cxlib: slice start \(start) out of bounds")
        }
        guard end >= start && end <= _rows.count else {
            throw CXError.parse("cxlib: slice end \(end) out of bounds (start=\(start))")
        }
        return Table(cols: _cols, types: _types, rows: Array(_rows[start ..< end]))
    }

    public func head(_ n: Int) throws -> Table {
        return try slice(0, Swift.min(Swift.max(n, 0), _rows.count))
    }

    public func tail(_ n: Int) throws -> Table {
        let start = Swift.max(0, _rows.count - n)
        return try slice(start, _rows.count)
    }

    /// `selectCols` — renamed from canonical `select` to mirror the
    /// other bindings' rename pattern.
    public func selectCols(_ names: [String]) throws -> Table {
        var indices: [Int] = []
        var newCols: [String] = []
        var newTypes: [String] = []
        for name in names {
            guard let idx = _cols.firstIndex(of: name) else {
                throw CXError.parse("cxlib: unknown column \"\(name)\"")
            }
            indices.append(idx)
            newCols.append(_cols[idx])
            newTypes.append(_types[idx])
        }
        let newRows = _rows.map { row in indices.map { row[$0] } }
        return Table(cols: newCols, types: newTypes, rows: newRows)
    }

    // ── Iteration (2) ────────────────────────────────────────────────────────

    public func makeIterator() -> AnyIterator<[String: Any?]> {
        var i = 0
        return AnyIterator {
            guard i < self._rows.count else { return nil }
            defer { i += 1 }
            return try? self.row(i)
        }
    }

    public func iterCols() -> [ColumnView] {
        var out: [ColumnView] = []
        for i in 0 ..< _cols.count {
            out.append(ColumnView(
                name: _cols[i],
                typeName: _types[i],
                values: (try? colAt(i)) ?? []
            ))
        }
        return out
    }

    // ── Conversion (5) ───────────────────────────────────────────────────────

    public func toCx() -> String {
        var s = "[_ :table["
        for i in 0 ..< _cols.count {
            if i > 0 { s += " " }
            s += _cols[i]
            if !_types[i].isEmpty { s += ":" + _types[i] }
        }
        s += "]\n"
        for row in _rows {
            s += "  "
            for (i, v) in row.enumerated() {
                if i > 0 { s += " " }
                s += formatCxCell(v)
            }
            s += "\n"
        }
        s += "]\n"
        return s
    }

    public func toCsv(delim: Character = ",") -> String {
        var s = ""
        for (i, c) in _cols.enumerated() {
            if i > 0 { s.append(delim) }
            s += c
        }
        s += "\r\n"
        for row in _rows {
            for (i, v) in row.enumerated() {
                if i > 0 { s.append(delim) }
                s += formatCsvCell(v, delim: delim)
            }
            s += "\r\n"
        }
        return s
    }

    public func toJson() throws -> String {
        let list = toDictList()
        let normalized = list.map { dict -> [String: Any] in
            var out: [String: Any] = [:]
            for (k, v) in dict { out[k] = v ?? NSNull() }
            return out
        }
        let data = try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    public func toDataBin() throws -> Data {
        return try CXLib.toDataBin(toCx())
    }

    public func toDictList() -> [[String: Any?]] {
        var out: [[String: Any?]] = []
        for i in 0 ..< _rows.count {
            if let r = try? row(i) { out.append(r) }
        }
        return out
    }

    // ── Equality ─────────────────────────────────────────────────────────────

    public func equals(_ other: Table) -> Bool {
        if _cols != other._cols { return false }
        if _types != other._types { return false }
        if _rows.count != other._rows.count { return false }
        for r in 0 ..< _rows.count {
            if _rows[r].count != other._rows[r].count { return false }
            for c in 0 ..< _rows[r].count {
                if !cellEquals(_rows[r][c], other._rows[r][c]) { return false }
            }
        }
        return true
    }
}

// ── Internal: walk decoded data_bin value to find tables ────────────────────

private func collectTables(_ value: Any?, into out: inout [Table]) {
    if value == nil { return }
    if let dict = value as? [String: Any] {
        for child in dict.values { collectTables(child, into: &out) }
        return
    }
    if let list = value as? [Any] {
        if looksLikeTable(list) {
            let rows = list.compactMap { $0 as? [String: Any] }
            let keys = rows[0].keys.sorted()
            let types = Array(repeating: "", count: keys.count)
            let rowVals = rows.map { d -> [Any?] in
                keys.map { k -> Any? in
                    if let v = d[k] {
                        if v is NSNull { return nil }
                        return v
                    }
                    return nil
                }
            }
            if let t = try? Table.create(cols: keys, types: types, rows: rowVals) {
                out.append(t)
            }
            return
        }
        for child in list { collectTables(child, into: &out) }
    }
}

private func looksLikeTable(_ list: [Any]) -> Bool {
    if list.isEmpty { return false }
    guard let first = list[0] as? [String: Any] else { return false }
    let keys = Set(first.keys)
    if keys.isEmpty { return false }
    for item in list {
        guard let d = item as? [String: Any] else { return false }
        if d.count != keys.count { return false }
        for k in d.keys { if !keys.contains(k) { return false } }
    }
    return true
}

// ── Internal: cell formatters / equality ────────────────────────────────────

private func formatCxCell(_ v: Any?) -> String {
    guard let v = v else { return "null" }
    if let b = v as? Bool { return b ? "true" : "false" }
    if let i = v as? Int { return String(i) }
    if let i = v as? Int64 { return String(i) }
    if let d = v as? Double { return String(d) }
    if let f = v as? Float { return String(f) }
    if let list = v as? [Any?] {
        return "[" + list.map { formatCxCell($0) }.joined(separator: ", ") + "]"
    }
    if let list = v as? [Any] {
        return "[" + list.map { formatCxCell($0) }.joined(separator: ", ") + "]"
    }
    if let dict = v as? [String: Any?] {
        let keys = dict.keys.sorted()
        return "{" + keys.map { "\(formatCxKey($0)): \(formatCxCell(dict[$0] ?? nil))" }.joined(separator: ", ") + "}"
    }
    if let dict = v as? [String: Any] {
        let keys = dict.keys.sorted()
        return "{" + keys.map { "\(formatCxKey($0)): \(formatCxCell(dict[$0]))" }.joined(separator: ", ") + "}"
    }
    let s = "\(v)"
    if s.isEmpty || s.contains(where: { $0.isWhitespace || "'[](){},".contains($0) }) {
        return "'" + s.replacingOccurrences(of: "'", with: "''") + "'"
    }
    return s
}

private func formatCxKey(_ k: String) -> String {
    var simple = !k.isEmpty
    for (i, ch) in k.enumerated() {
        let ok = ch == "_" || ch.isLetter || (i > 0 && ch.isNumber)
        if !ok { simple = false; break }
    }
    if simple { return k }
    return "'" + k.replacingOccurrences(of: "'", with: "''") + "'"
}

private func formatCsvCell(_ v: Any?, delim: Character) -> String {
    guard let v = v else { return "" }
    if v is [Any] || v is [String: Any] || v is [Any?] || v is [String: Any?] {
        let data = (try? JSONSerialization.data(withJSONObject: v, options: [])) ?? Data()
        let s = String(decoding: data, as: UTF8.self)
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    if let b = v as? Bool { return b ? "true" : "false" }
    let s = "\(v)"
    if s.contains(delim) || s.contains("\"") || s.contains("\n") || s.contains("\r") {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return s
}

private func cellEquals(_ a: Any?, _ b: Any?) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    if let la = a as? [Any?], let lb = b as? [Any?] {
        if la.count != lb.count { return false }
        for i in 0 ..< la.count { if !cellEquals(la[i], lb[i]) { return false } }
        return true
    }
    if let la = a as? [Any], let lb = b as? [Any] {
        if la.count != lb.count { return false }
        for i in 0 ..< la.count { if !cellEquals(la[i], lb[i]) { return false } }
        return true
    }
    if let da = a as? [String: Any], let db = b as? [String: Any] {
        if da.count != db.count { return false }
        for (k, v) in da { if !cellEquals(v, db[k]) { return false } }
        return true
    }
    if let ai = a as? Int, let bi = b as? Int { return ai == bi }
    if let al = a as? Int64, let bl = b as? Int64 { return al == bl }
    if let ad = a as? Double, let bd = b as? Double { return ad == bd }
    if let ab = a as? Bool, let bb = b as? Bool { return ab == bb }
    if let astr = a as? String, let bstr = b as? String { return astr == bstr }
    return false
}
