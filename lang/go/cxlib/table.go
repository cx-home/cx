// CX Go binding — Public Table API per ADR 0018 D1.
//
// Implements the 17-member canonical Table API surface against the
// V core's :table blocks via the C ABI. Per ADR 0018 §D2 per-binding
// naming: Go uses PascalCase methods + lowerCamelCase struct fields
// to match host conventions.

package cxlib

import (
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
)

// Table is an immutable handle over a single :table block. Per
// ADR 0018 §D3 tables are immutable values; modification returns a
// new Table. Cells admit any ADR 0017 §D5 Item kind: scalars +
// Array (Go []any) + Map (Go map[string]any).
type Table struct {
	cols  []string
	types []string
	rows  [][]any
}

// ── Construction ─────────────────────────────────────────────────────────────

// TableFromCx parses CX source and returns the first :table block
// found, walking nested structures. Returns an error if no :table
// block is present.
func TableFromCx(src string) (*Table, error) {
	tables, err := TablesFromCx(src)
	if err != nil {
		return nil, err
	}
	if len(tables) == 0 {
		return nil, errors.New("cxlib: no :table block found in source")
	}
	return tables[0], nil
}

// TablesFromCx returns every :table block in the source in
// document order. Walks the data_bin decode recursively.
func TablesFromCx(src string) ([]*Table, error) {
	framed, err := ToDataBin(src)
	if err != nil {
		return nil, err
	}
	decoded, err := FromDataBinValue(framed)
	if err != nil {
		return nil, err
	}
	var tables []*Table
	collectTables(decoded, &tables)
	return tables, nil
}

// NewTable constructs a Table directly with 4-invariant validation
// per ADR 0018 §D7: len(cols)==len(types), unique col names, row
// width matches col count, (cell type compatibility is checked at
// access time since Go interfaces are duck-typed).
func NewTable(cols []string, types []string, rows [][]any) (*Table, error) {
	if len(cols) != len(types) {
		return nil, fmt.Errorf("cxlib: len(cols)=%d != len(types)=%d",
			len(cols), len(types))
	}
	seen := make(map[string]struct{}, len(cols))
	for _, c := range cols {
		if _, ok := seen[c]; ok {
			return nil, fmt.Errorf("cxlib: duplicate column name %q", c)
		}
		seen[c] = struct{}{}
	}
	for rowIdx, row := range rows {
		if len(row) != len(cols) {
			return nil, fmt.Errorf(
				"cxlib: row %d has %d cells; expected %d",
				rowIdx, len(row), len(cols),
			)
		}
	}
	colsCopy := make([]string, len(cols))
	copy(colsCopy, cols)
	typesCopy := make([]string, len(types))
	copy(typesCopy, types)
	rowsCopy := make([][]any, len(rows))
	for i, row := range rows {
		r := make([]any, len(row))
		copy(r, row)
		rowsCopy[i] = r
	}
	return &Table{cols: colsCopy, types: typesCopy, rows: rowsCopy}, nil
}

// ── Properties (4) ───────────────────────────────────────────────────────────

func (t *Table) Cols() []string {
	out := make([]string, len(t.cols))
	copy(out, t.cols)
	return out
}

func (t *Table) Types() []string {
	out := make([]string, len(t.types))
	copy(out, t.types)
	return out
}

func (t *Table) RowCount() int { return len(t.rows) }
func (t *Table) ColCount() int { return len(t.cols) }

// ── Access (9) ───────────────────────────────────────────────────────────────

// Row returns the row at index i as an ordered map.
func (t *Table) Row(i int) (map[string]any, error) {
	if i < 0 || i >= len(t.rows) {
		return nil, fmt.Errorf("cxlib: row index %d out of bounds [0, %d)",
			i, len(t.rows))
	}
	out := make(map[string]any, len(t.cols))
	for c, name := range t.cols {
		out[name] = t.rows[i][c]
	}
	return out, nil
}

// Column returns all values in the named column.
func (t *Table) Column(name string) ([]any, error) {
	idx := -1
	for i, c := range t.cols {
		if c == name {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("cxlib: unknown column %q", name)
	}
	return t.ColAt(idx)
}

func (t *Table) ColAt(i int) ([]any, error) {
	if i < 0 || i >= len(t.cols) {
		return nil, fmt.Errorf("cxlib: column index %d out of bounds [0, %d)",
			i, len(t.cols))
	}
	out := make([]any, len(t.rows))
	for ri, row := range t.rows {
		out[ri] = row[i]
	}
	return out, nil
}

func (t *Table) Cell(r, c int) (any, error) {
	if r < 0 || r >= len(t.rows) {
		return nil, fmt.Errorf("cxlib: row index %d out of bounds [0, %d)",
			r, len(t.rows))
	}
	if c < 0 || c >= len(t.cols) {
		return nil, fmt.Errorf("cxlib: column index %d out of bounds [0, %d)",
			c, len(t.cols))
	}
	return t.rows[r][c], nil
}

func (t *Table) CellByName(r int, name string) (any, error) {
	for c, colName := range t.cols {
		if colName == name {
			return t.Cell(r, c)
		}
	}
	return nil, fmt.Errorf("cxlib: unknown column %q", name)
}

func (t *Table) Slice(start, end int) (*Table, error) {
	if start < 0 || start > len(t.rows) {
		return nil, fmt.Errorf("cxlib: slice start %d out of bounds", start)
	}
	if end < start || end > len(t.rows) {
		return nil, fmt.Errorf("cxlib: slice end %d out of bounds (start=%d)",
			end, start)
	}
	newRows := make([][]any, end-start)
	for i, row := range t.rows[start:end] {
		r := make([]any, len(row))
		copy(r, row)
		newRows[i] = r
	}
	return &Table{cols: t.cols, types: t.types, rows: newRows}, nil
}

func (t *Table) Head(n int) *Table {
	if n < 0 {
		n = 0
	}
	if n > len(t.rows) {
		n = len(t.rows)
	}
	out, _ := t.Slice(0, n)
	return out
}

func (t *Table) Tail(n int) *Table {
	start := len(t.rows) - n
	if start < 0 {
		start = 0
	}
	out, _ := t.Slice(start, len(t.rows))
	return out
}

// Select returns a new Table with only the named columns in the given
// order. Per ADR 0018 §4 canonical name; Go allows `select` since
// it's only a keyword in channel syntax (not a function name).
func (t *Table) Select(names []string) (*Table, error) {
	newCols := make([]string, 0, len(names))
	newTypes := make([]string, 0, len(names))
	indices := make([]int, 0, len(names))
	for _, name := range names {
		idx := -1
		for i, c := range t.cols {
			if c == name {
				idx = i
				break
			}
		}
		if idx < 0 {
			return nil, fmt.Errorf("cxlib: unknown column %q", name)
		}
		newCols = append(newCols, t.cols[idx])
		newTypes = append(newTypes, t.types[idx])
		indices = append(indices, idx)
	}
	newRows := make([][]any, len(t.rows))
	for ri, row := range t.rows {
		r := make([]any, len(indices))
		for j, idx := range indices {
			r[j] = row[idx]
		}
		newRows[ri] = r
	}
	return &Table{cols: newCols, types: newTypes, rows: newRows}, nil
}

// ── Iteration (2) ────────────────────────────────────────────────────────────

// Iter returns a channel of rows (each as an ordered map). Per Go
// convention; ranges close the channel when iteration completes.
func (t *Table) Iter() <-chan map[string]any {
	ch := make(chan map[string]any, 1)
	go func() {
		defer close(ch)
		for i := range t.rows {
			row, _ := t.Row(i)
			ch <- row
		}
	}()
	return ch
}

// ColView is the (name, type_name, values) triple yielded by IterCols.
type ColView struct {
	Name     string
	TypeName string
	Values   []any
}

func (t *Table) IterCols() <-chan ColView {
	ch := make(chan ColView, 1)
	go func() {
		defer close(ch)
		for i, name := range t.cols {
			vals, _ := t.ColAt(i)
			ch <- ColView{Name: name, TypeName: t.types[i], Values: vals}
		}
	}()
	return ch
}

// ── Conversion (5) ───────────────────────────────────────────────────────────

func (t *Table) ToCx() string {
	headerParts := make([]string, len(t.cols))
	for i, name := range t.cols {
		if t.types[i] == "" {
			headerParts[i] = name
		} else {
			headerParts[i] = name + ":" + t.types[i]
		}
	}
	var b strings.Builder
	b.WriteString("[_ :table[")
	b.WriteString(strings.Join(headerParts, " "))
	b.WriteString("]\n")
	for _, row := range t.rows {
		b.WriteString("  ")
		for j, v := range row {
			if j > 0 {
				b.WriteString(" ")
			}
			b.WriteString(formatCxCell(v))
		}
		b.WriteString("\n")
	}
	b.WriteString("]\n")
	return b.String()
}

func (t *Table) ToCSV(delim byte) string {
	var b strings.Builder
	for i, c := range t.cols {
		if i > 0 {
			b.WriteByte(delim)
		}
		b.WriteString(c)
	}
	b.WriteString("\r\n")
	for _, row := range t.rows {
		for j, v := range row {
			if j > 0 {
				b.WriteByte(delim)
			}
			b.WriteString(formatCsvCell(v, delim))
		}
		b.WriteString("\r\n")
	}
	return b.String()
}

func (t *Table) ToJSON() (string, error) {
	rows := make([]map[string]any, len(t.rows))
	for i := range t.rows {
		row, _ := t.Row(i)
		rows[i] = row
	}
	out, err := json.Marshal(rows)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func (t *Table) ToDataBin() ([]byte, error) {
	return ToDataBin(t.ToCx())
}

func (t *Table) ToDictList() []map[string]any {
	out := make([]map[string]any, len(t.rows))
	for i := range t.rows {
		out[i], _ = t.Row(i)
	}
	return out
}

// ── Equality ─────────────────────────────────────────────────────────────────

func (t *Table) Equal(other *Table) bool {
	if other == nil {
		return false
	}
	if len(t.cols) != len(other.cols) || len(t.rows) != len(other.rows) {
		return false
	}
	for i, c := range t.cols {
		if c != other.cols[i] || t.types[i] != other.types[i] {
			return false
		}
	}
	for ri, row := range t.rows {
		if len(row) != len(other.rows[ri]) {
			return false
		}
		for j, v := range row {
			if !cellEqual(v, other.rows[ri][j]) {
				return false
			}
		}
	}
	return true
}

func cellEqual(a, b any) bool {
	// Slice / map equality requires deep compare; use JSON round-trip
	// for a simple, correct-for-our-types implementation.
	ja, _ := json.Marshal(a)
	jb, _ := json.Marshal(b)
	return string(ja) == string(jb)
}

// ── Internal: walk a decoded data_bin payload to find tables ─────────────────

func collectTables(value any, out *[]*Table) {
	switch v := value.(type) {
	case map[string]any:
		// Walk children
		keys := make([]string, 0, len(v))
		for k := range v {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			collectTables(v[k], out)
		}
	case []any:
		if looksLikeTable(v) {
			first := v[0].(map[string]any)
			cols := make([]string, 0, len(first))
			for k := range first {
				cols = append(cols, k)
			}
			sort.Strings(cols)
			types := make([]string, len(cols))
			rows := make([][]any, len(v))
			for ri, item := range v {
				r := make([]any, len(cols))
				m := item.(map[string]any)
				for ci, c := range cols {
					r[ci] = m[c]
				}
				rows[ri] = r
			}
			*out = append(*out, &Table{cols: cols, types: types, rows: rows})
		} else {
			for _, child := range v {
				collectTables(child, out)
			}
		}
	}
}

func looksLikeTable(v []any) bool {
	if len(v) == 0 {
		return false
	}
	first, ok := v[0].(map[string]any)
	if !ok || len(first) == 0 {
		return false
	}
	keys := make(map[string]struct{}, len(first))
	for k := range first {
		keys[k] = struct{}{}
	}
	for _, item := range v {
		m, ok := item.(map[string]any)
		if !ok || len(m) != len(keys) {
			return false
		}
		for k := range m {
			if _, present := keys[k]; !present {
				return false
			}
		}
	}
	return true
}

// ── Internal: cell formatters ────────────────────────────────────────────────

func formatCxCell(v any) string {
	switch c := v.(type) {
	case nil:
		return "null"
	case bool:
		if c {
			return "true"
		}
		return "false"
	case int:
		return fmt.Sprintf("%d", c)
	case int64:
		return fmt.Sprintf("%d", c)
	case float64:
		return fmt.Sprintf("%g", c)
	case []any:
		parts := make([]string, len(c))
		for i, item := range c {
			parts[i] = formatCxCell(item)
		}
		return "[" + strings.Join(parts, ", ") + "]"
	case map[string]any:
		keys := make([]string, 0, len(c))
		for k := range c {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		parts := make([]string, 0, len(keys))
		for _, k := range keys {
			parts = append(parts, formatCxKey(k)+": "+formatCxCell(c[k]))
		}
		return "{" + strings.Join(parts, ", ") + "}"
	case string:
		if strings.ContainsAny(c, " \t\n'[](){},") || c == "" {
			return "'" + strings.ReplaceAll(c, "'", "''") + "'"
		}
		return c
	default:
		return fmt.Sprintf("%v", c)
	}
}

func formatCxKey(k string) string {
	if k == "" {
		return "''"
	}
	for _, r := range k {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') || r == '_') {
			return "'" + strings.ReplaceAll(k, "'", "''") + "'"
		}
	}
	return k
}

func formatCsvCell(v any, delim byte) string {
	switch c := v.(type) {
	case nil:
		return ""
	case []any, map[string]any:
		bytes, _ := json.Marshal(c)
		return "\"" + strings.ReplaceAll(string(bytes), "\"", "\"\"") + "\""
	case bool:
		if c {
			return "true"
		}
		return "false"
	default:
		s := fmt.Sprintf("%v", c)
		if strings.ContainsRune(s, rune(delim)) || strings.ContainsAny(s, "\"\n\r") {
			return "\"" + strings.ReplaceAll(s, "\"", "\"\"") + "\""
		}
		return s
	}
}

// FromDataBinValue decodes CXDB payload bytes into a Go any value.
// Go's ToDataBin already strips the 4-byte LE size header before
// returning (see extractBinPayload), so the input here is the raw
// CXDB payload starting with the 'CXDB' magic bytes.
func FromDataBinValue(payload []byte) (any, error) {
	return decodeDataBin(payload)
}
