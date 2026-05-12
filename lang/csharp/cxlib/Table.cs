// CX C# binding — Public Table API per ADR 0018 D1.
//
// 17-member canonical Table API against the V core's :table blocks via
// the C ABI. Per ADR 0018 §D2: C# uses PascalCase methods matching the
// canonical surface.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace CX;

/// <summary>Column iterator view (returned by <see cref="Table.IterCols"/>).</summary>
public sealed class ColumnView
{
    public string Name { get; }
    public string TypeName { get; }
    public IReadOnlyList<object?> Values { get; }

    public ColumnView(string name, string typeName, IReadOnlyList<object?> values)
    {
        Name = name;
        TypeName = typeName;
        Values = values;
    }
}

/// <summary>
/// Immutable handle over a single <c>:table</c> block. Implements the
/// 17-member canonical Table API (ADR 0018 §D1) with .NET PascalCase
/// naming. Construct via <see cref="FromCx"/>, <see cref="FromCxAll"/>,
/// or <see cref="Create"/>.
/// </summary>
public sealed class Table : IEnumerable<IReadOnlyDictionary<string, object?>>
{
    private readonly string[] _cols;
    private readonly string[] _types;
    private readonly object?[][] _rows;

    private Table(string[] cols, string[] types, object?[][] rows)
    {
        _cols = cols;
        _types = types;
        _rows = rows;
    }

    // ── Construction ─────────────────────────────────────────────────────────

    /// <summary>Parse CX source and return the first <c>:table</c> block.</summary>
    public static Table FromCx(string src)
    {
        var tables = FromCxAll(src);
        if (tables.Count == 0)
            throw new InvalidOperationException("cxlib: no :table block found in source");
        return tables[0];
    }

    /// <summary>Return every <c>:table</c> block in the source (preorder).</summary>
    public static IReadOnlyList<Table> FromCxAll(string src)
    {
        var payload = CxLib.ToDataBin(src);
        var decoded = DataBin.Decode(payload);
        var out_ = new List<Table>();
        CollectTables(decoded, out_);
        return out_;
    }

    /// <summary>Direct construction with 4-invariant validation per ADR 0018 §D7.</summary>
    public static Table Create(
        IReadOnlyList<string> cols,
        IReadOnlyList<string> types,
        IReadOnlyList<IReadOnlyList<object?>> rows)
    {
        if (cols.Count != types.Count)
            throw new ArgumentException(
                $"cxlib: len(cols)={cols.Count} != len(types)={types.Count}");
        var seen = new HashSet<string>();
        foreach (var c in cols)
        {
            if (!seen.Add(c))
                throw new ArgumentException($"cxlib: duplicate column name \"{c}\"");
        }
        var rowArr = new object?[rows.Count][];
        for (int i = 0; i < rows.Count; i++)
        {
            if (rows[i].Count != cols.Count)
                throw new ArgumentException(
                    $"cxlib: row {i} has {rows[i].Count} cells; expected {cols.Count}");
            rowArr[i] = rows[i].ToArray();
        }
        return new Table(cols.ToArray(), types.ToArray(), rowArr);
    }

    // ── Properties (4) ───────────────────────────────────────────────────────

    public IReadOnlyList<string> Cols => _cols;
    public IReadOnlyList<string> Types => _types;
    public int RowCount => _rows.Length;
    public int ColCount => _cols.Length;

    // ── Access (9) ───────────────────────────────────────────────────────────

    public IReadOnlyDictionary<string, object?> Row(int i)
    {
        if (i < 0 || i >= _rows.Length)
            throw new ArgumentOutOfRangeException(nameof(i),
                $"cxlib: row index {i} out of bounds [0, {_rows.Length})");
        var d = new Dictionary<string, object?>(_cols.Length);
        for (int c = 0; c < _cols.Length; c++) d[_cols[c]] = _rows[i][c];
        return d;
    }

    public IReadOnlyList<object?> Column(string name)
    {
        int idx = Array.IndexOf(_cols, name);
        if (idx < 0) throw new ArgumentException($"cxlib: unknown column \"{name}\"");
        return ColAt(idx);
    }

    public IReadOnlyList<object?> ColAt(int i)
    {
        if (i < 0 || i >= _cols.Length)
            throw new ArgumentOutOfRangeException(nameof(i),
                $"cxlib: column index {i} out of bounds [0, {_cols.Length})");
        var col = new object?[_rows.Length];
        for (int r = 0; r < _rows.Length; r++) col[r] = _rows[r][i];
        return col;
    }

    public object? Cell(int r, int c)
    {
        if (r < 0 || r >= _rows.Length)
            throw new ArgumentOutOfRangeException(nameof(r),
                $"cxlib: row index {r} out of bounds [0, {_rows.Length})");
        if (c < 0 || c >= _cols.Length)
            throw new ArgumentOutOfRangeException(nameof(c),
                $"cxlib: column index {c} out of bounds [0, {_cols.Length})");
        return _rows[r][c];
    }

    public object? CellByName(int r, string name)
    {
        int idx = Array.IndexOf(_cols, name);
        if (idx < 0) throw new ArgumentException($"cxlib: unknown column \"{name}\"");
        return Cell(r, idx);
    }

    public Table Slice(int start, int end)
    {
        if (start < 0 || start > _rows.Length)
            throw new ArgumentOutOfRangeException(nameof(start),
                $"cxlib: slice start {start} out of bounds");
        if (end < start || end > _rows.Length)
            throw new ArgumentOutOfRangeException(nameof(end),
                $"cxlib: slice end {end} out of bounds (start={start})");
        var rows = new object?[end - start][];
        for (int i = 0; i < rows.Length; i++) rows[i] = (object?[])_rows[start + i].Clone();
        return new Table(_cols, _types, rows);
    }

    public Table Head(int n) => Slice(0, Math.Min(Math.Max(n, 0), _rows.Length));

    public Table Tail(int n)
    {
        int start = Math.Max(0, _rows.Length - n);
        return Slice(start, _rows.Length);
    }

    /// <summary>
    /// <c>SelectCols</c> — renamed from canonical <c>Select</c> to mirror
    /// the other bindings' rename pattern (LINQ already owns <c>Select</c>
    /// in .NET, so the rename is also defensive).
    /// </summary>
    public Table SelectCols(IReadOnlyList<string> names)
    {
        var indices = new int[names.Count];
        var newCols = new string[names.Count];
        var newTypes = new string[names.Count];
        for (int i = 0; i < names.Count; i++)
        {
            int idx = Array.IndexOf(_cols, names[i]);
            if (idx < 0) throw new ArgumentException($"cxlib: unknown column \"{names[i]}\"");
            indices[i] = idx;
            newCols[i] = _cols[idx];
            newTypes[i] = _types[idx];
        }
        var newRows = new object?[_rows.Length][];
        for (int r = 0; r < _rows.Length; r++)
        {
            var row = new object?[indices.Length];
            for (int j = 0; j < indices.Length; j++) row[j] = _rows[r][indices[j]];
            newRows[r] = row;
        }
        return new Table(newCols, newTypes, newRows);
    }

    // ── Iteration (2) ────────────────────────────────────────────────────────

    public IEnumerator<IReadOnlyDictionary<string, object?>> GetEnumerator()
    {
        for (int i = 0; i < _rows.Length; i++) yield return Row(i);
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    public IEnumerable<ColumnView> IterCols()
    {
        for (int i = 0; i < _cols.Length; i++)
            yield return new ColumnView(_cols[i], _types[i], ColAt(i));
    }

    // ── Conversion (5) ───────────────────────────────────────────────────────

    public string ToCx()
    {
        var sb = new StringBuilder();
        sb.Append("[_ :table[");
        for (int i = 0; i < _cols.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            sb.Append(_cols[i]);
            if (!string.IsNullOrEmpty(_types[i])) { sb.Append(':'); sb.Append(_types[i]); }
        }
        sb.Append("]\n");
        foreach (var row in _rows)
        {
            sb.Append("  ");
            for (int i = 0; i < row.Length; i++)
            {
                if (i > 0) sb.Append(' ');
                sb.Append(FormatCxCell(row[i]));
            }
            sb.Append('\n');
        }
        sb.Append("]\n");
        return sb.ToString();
    }

    public string ToCsv(char delim = ',')
    {
        var sb = new StringBuilder();
        for (int i = 0; i < _cols.Length; i++)
        {
            if (i > 0) sb.Append(delim);
            sb.Append(_cols[i]);
        }
        sb.Append("\r\n");
        foreach (var row in _rows)
        {
            for (int i = 0; i < row.Length; i++)
            {
                if (i > 0) sb.Append(delim);
                sb.Append(FormatCsvCell(row[i], delim));
            }
            sb.Append("\r\n");
        }
        return sb.ToString();
    }

    public string ToJson()
    {
        return JsonSerializer.Serialize(ToDictList());
    }

    public byte[] ToDataBin() => CxLib.ToDataBin(ToCx());

    public IReadOnlyList<IReadOnlyDictionary<string, object?>> ToDictList()
    {
        var list = new List<IReadOnlyDictionary<string, object?>>(_rows.Length);
        for (int i = 0; i < _rows.Length; i++) list.Add(Row(i));
        return list;
    }

    // ── Equality ─────────────────────────────────────────────────────────────

    public override bool Equals(object? obj)
    {
        if (obj is not Table other) return false;
        if (_cols.Length != other._cols.Length) return false;
        if (_rows.Length != other._rows.Length) return false;
        for (int i = 0; i < _cols.Length; i++)
        {
            if (_cols[i] != other._cols[i]) return false;
            if (_types[i] != other._types[i]) return false;
        }
        for (int r = 0; r < _rows.Length; r++)
        {
            if (_rows[r].Length != other._rows[r].Length) return false;
            for (int c = 0; c < _rows[r].Length; c++)
            {
                if (!CellEquals(_rows[r][c], other._rows[r][c])) return false;
            }
        }
        return true;
    }

    public override int GetHashCode()
    {
        var h = new HashCode();
        foreach (var c in _cols) h.Add(c);
        foreach (var t in _types) h.Add(t);
        h.Add(_rows.Length);
        return h.ToHashCode();
    }

    // ── Internal: walk decoded data_bin value to find tables ─────────────────

    private static void CollectTables(object? value, List<Table> outList)
    {
        if (value is null) return;
        if (value is IDictionary<string, object?> dict)
        {
            foreach (var child in dict.Values) CollectTables(child, outList);
            return;
        }
        if (value is IList list)
        {
            if (LooksLikeTable(list))
            {
                var first = (IDictionary<string, object?>)list[0]!;
                var cols = first.Keys.OrderBy(k => k, StringComparer.Ordinal).ToArray();
                var types = cols.Select(_ => "").ToArray();
                var rows = new List<IReadOnlyList<object?>>(list.Count);
                foreach (var item in list)
                {
                    var d = (IDictionary<string, object?>)item!;
                    var row = new object?[cols.Length];
                    for (int c = 0; c < cols.Length; c++)
                        row[c] = d.TryGetValue(cols[c], out var v) ? v : null;
                    rows.Add(row);
                }
                outList.Add(Create(cols, types, rows));
                return;
            }
            foreach (var child in list) CollectTables(child, outList);
        }
    }

    private static bool LooksLikeTable(IList list)
    {
        if (list.Count == 0) return false;
        if (list[0] is not IDictionary<string, object?> first) return false;
        var keys = new HashSet<string>(first.Keys);
        if (keys.Count == 0) return false;
        foreach (var item in list)
        {
            if (item is not IDictionary<string, object?> d) return false;
            if (d.Count != keys.Count) return false;
            foreach (var k in d.Keys) if (!keys.Contains(k)) return false;
        }
        return true;
    }

    // ── Internal: cell formatters / equality ─────────────────────────────────

    private static string FormatCxCell(object? v)
    {
        if (v is null) return "null";
        if (v is bool b) return b ? "true" : "false";
        if (v is long l) return l.ToString(CultureInfo.InvariantCulture);
        if (v is int i) return i.ToString(CultureInfo.InvariantCulture);
        if (v is double d) return d.ToString("R", CultureInfo.InvariantCulture);
        if (v is float f) return f.ToString("R", CultureInfo.InvariantCulture);
        if (v is IList<object?> list)
        {
            var sb = new StringBuilder("[");
            for (int k = 0; k < list.Count; k++)
            {
                if (k > 0) sb.Append(", ");
                sb.Append(FormatCxCell(list[k]));
            }
            sb.Append(']');
            return sb.ToString();
        }
        if (v is IDictionary<string, object?> dict)
        {
            var keys = dict.Keys.OrderBy(k => k, StringComparer.Ordinal).ToArray();
            var sb = new StringBuilder("{");
            for (int k = 0; k < keys.Length; k++)
            {
                if (k > 0) sb.Append(", ");
                sb.Append(FormatCxKey(keys[k]));
                sb.Append(": ");
                sb.Append(FormatCxCell(dict[keys[k]]));
            }
            sb.Append('}');
            return sb.ToString();
        }
        string s = Convert.ToString(v, CultureInfo.InvariantCulture) ?? "";
        if (s.Length == 0 || NeedsQuote(s))
            return "'" + s.Replace("'", "''") + "'";
        return s;
    }

    private static bool NeedsQuote(string s)
    {
        foreach (var ch in s)
        {
            if (char.IsWhiteSpace(ch)) return true;
            if (ch == '\'' || ch == '[' || ch == ']' || ch == '(' || ch == ')'
                || ch == '{' || ch == '}' || ch == ',') return true;
        }
        return false;
    }

    private static string FormatCxKey(string k)
    {
        bool simple = k.Length > 0;
        for (int i = 0; i < k.Length && simple; i++)
        {
            char ch = k[i];
            bool ok = (ch == '_')
                || (ch >= 'a' && ch <= 'z')
                || (ch >= 'A' && ch <= 'Z')
                || (i > 0 && ch >= '0' && ch <= '9');
            if (!ok) simple = false;
        }
        if (simple) return k;
        return "'" + k.Replace("'", "''") + "'";
    }

    private static string FormatCsvCell(object? v, char delim)
    {
        if (v is null) return "";
        if (v is IDictionary<string, object?> || v is IList<object?>)
        {
            string json = JsonSerializer.Serialize(v);
            return "\"" + json.Replace("\"", "\"\"") + "\"";
        }
        if (v is bool b) return b ? "true" : "false";
        string s = Convert.ToString(v, CultureInfo.InvariantCulture) ?? "";
        if (s.IndexOf(delim) >= 0 || s.IndexOf('"') >= 0 ||
            s.IndexOf('\n') >= 0 || s.IndexOf('\r') >= 0)
        {
            return "\"" + s.Replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    private static bool CellEquals(object? a, object? b)
    {
        if (ReferenceEquals(a, b)) return true;
        if (a is null || b is null) return false;
        if (a is IList<object?> la && b is IList<object?> lb)
        {
            if (la.Count != lb.Count) return false;
            for (int i = 0; i < la.Count; i++)
                if (!CellEquals(la[i], lb[i])) return false;
            return true;
        }
        if (a is IDictionary<string, object?> da && b is IDictionary<string, object?> db)
        {
            if (da.Count != db.Count) return false;
            foreach (var kv in da)
            {
                if (!db.TryGetValue(kv.Key, out var bv)) return false;
                if (!CellEquals(kv.Value, bv)) return false;
            }
            return true;
        }
        return a.Equals(b);
    }
}
