package cxlib

import (
	"fmt"
	"strings"
	"testing"
)

func TestTableFromCxSimple(t *testing.T) {
	src := `[users [table[name age::int]]
  alice 30
  bob 25
]`
	tbl, err := TableFromCx(src)
	if err != nil {
		t.Fatalf("TableFromCx failed: %v", err)
	}
	if tbl.RowCount() != 2 {
		t.Errorf("row_count: got %d, want 2", tbl.RowCount())
	}
	if tbl.ColCount() != 2 {
		t.Errorf("col_count: got %d, want 2", tbl.ColCount())
	}
}

func TestTableFromCxNoTableErrors(t *testing.T) {
	_, err := TableFromCx(`[product name=alice]`)
	if err == nil {
		t.Fatal("expected error on no-:table source")
	}
	if !strings.Contains(err.Error(), "no :table") {
		t.Errorf("wrong error: %v", err)
	}
}

func TestTableNewValidates(t *testing.T) {
	// (1) len mismatch
	_, err := NewTable([]string{"a", "b"}, []string{"int"}, nil)
	if err == nil || !strings.Contains(err.Error(), "len(cols)") {
		t.Errorf("expected len mismatch error, got: %v", err)
	}
	// (2) duplicate cols
	_, err = NewTable([]string{"a", "a"}, []string{"int", "int"}, nil)
	if err == nil || !strings.Contains(err.Error(), "duplicate") {
		t.Errorf("expected duplicate error, got: %v", err)
	}
	// (3) row width
	_, err = NewTable(
		[]string{"a", "b"},
		[]string{"int", "int"},
		[][]any{{1}}, // only 1 cell
	)
	if err == nil || !strings.Contains(err.Error(), "cells; expected") {
		t.Errorf("expected width error, got: %v", err)
	}
}

func TestTableRow(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a", "b"},
		[]string{"int", "string"},
		[][]any{{int64(1), "x"}, {int64(2), "y"}},
	)
	row, err := tbl.Row(0)
	if err != nil {
		t.Fatalf("Row failed: %v", err)
	}
	if row["a"] != int64(1) || row["b"] != "x" {
		t.Errorf("wrong row: %v", row)
	}
}

func TestTableRowOutOfBounds(t *testing.T) {
	tbl, _ := NewTable([]string{"a"}, []string{"int"}, [][]any{{int64(1)}})
	_, err := tbl.Row(5)
	if err == nil || !strings.Contains(err.Error(), "out of bounds") {
		t.Errorf("expected out-of-bounds error, got: %v", err)
	}
}

func TestTableColumn(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a", "b"},
		[]string{"int", "string"},
		[][]any{{int64(1), "x"}, {int64(2), "y"}},
	)
	vals, err := tbl.Column("b")
	if err != nil {
		t.Fatalf("Column failed: %v", err)
	}
	if len(vals) != 2 || vals[0] != "x" || vals[1] != "y" {
		t.Errorf("wrong column values: %v", vals)
	}
}

func TestTableSliceHeadTail(t *testing.T) {
	rows := make([][]any, 5)
	for i := range rows {
		rows[i] = []any{int64(i)}
	}
	tbl, _ := NewTable([]string{"v"}, []string{"int"}, rows)

	if tbl.Head(2).RowCount() != 2 {
		t.Error("Head(2) row count")
	}
	if tbl.Tail(2).RowCount() != 2 {
		t.Error("Tail(2) row count")
	}
	mid, _ := tbl.Slice(1, 4)
	if mid.RowCount() != 3 {
		t.Error("Slice(1,4) row count")
	}
}

func TestTableSelectReorders(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a", "b", "c"},
		[]string{"int", "int", "int"},
		[][]any{{int64(1), int64(2), int64(3)}},
	)
	sel, err := tbl.Select([]string{"c", "a"})
	if err != nil {
		t.Fatalf("Select failed: %v", err)
	}
	if sel.Cols()[0] != "c" || sel.Cols()[1] != "a" {
		t.Errorf("wrong order: %v", sel.Cols())
	}
}

func TestTableToCx(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"name", "age"},
		[]string{"", "int"},
		[][]any{{"alice", int64(30)}, {"bob", int64(25)}},
	)
	out := tbl.ToCx()
	if !strings.Contains(out, "alice 30") {
		t.Errorf("ToCx missing 'alice 30': %s", out)
	}
	// #509: ToCx must emit the CURRENT `[table[…]]` clause-child form
	// with glued `::` column types — the retired `:table[` opener with
	// single-colon types is unparseable by the live grammar.
	if !strings.Contains(out, "[table[name age::int]]") {
		t.Errorf("ToCx missing current [table[name age::int]] header: %s", out)
	}
}

// TestTableToCxRoundTrip re-parses the emitted text through the
// binding's own parse entry (TableFromCx → libcx) — a structural
// assertion that the emit is legal under the live grammar, not a
// substring pin (#509).
func TestTableToCxRoundTrip(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"name", "age"},
		[]string{"", "int"},
		[][]any{{"alice", int64(30)}, {"bob", int64(25)}},
	)
	back, err := TableFromCx(tbl.ToCx())
	if err != nil {
		t.Fatalf("ToCx output does not re-parse: %v\noutput: %s", err, tbl.ToCx())
	}
	if back.RowCount() != 2 || back.ColCount() != 2 {
		t.Fatalf("round-trip shape = %dx%d; want 2x2",
			back.RowCount(), back.ColCount())
	}
	for i, want := range []map[string]string{
		{"name": "alice", "age": "30"},
		{"name": "bob", "age": "25"},
	} {
		for col, val := range want {
			got, err := back.CellByName(i, col)
			if err != nil {
				t.Fatalf("round-trip missing column %q: %v", col, err)
			}
			if fmt.Sprintf("%v", got) != val {
				t.Errorf("round-trip cell (%d, %s) = %v; want %s",
					i, col, got, val)
			}
		}
	}
}

func TestTableToCSV(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a", "b"},
		[]string{"int", "string"},
		[][]any{{int64(1), "x"}, {int64(2), "y"}},
	)
	csv := tbl.ToCSV(',')
	if !strings.Contains(csv, "a,b") || !strings.Contains(csv, "1,x") {
		t.Errorf("ToCSV: %s", csv)
	}
}

func TestTableToJSON(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a"},
		[]string{"int"},
		[][]any{{int64(1)}, {int64(2)}},
	)
	js, err := tbl.ToJSON()
	if err != nil {
		t.Fatalf("ToJSON failed: %v", err)
	}
	if !strings.Contains(js, `"a":1`) || !strings.Contains(js, `"a":2`) {
		t.Errorf("ToJSON: %s", js)
	}
}

func TestTableToDictList(t *testing.T) {
	tbl, _ := NewTable(
		[]string{"a"},
		[]string{"int"},
		[][]any{{int64(1)}, {int64(2)}},
	)
	dl := tbl.ToDictList()
	if len(dl) != 2 {
		t.Errorf("ToDictList length: %d", len(dl))
	}
}

func TestTableEqual(t *testing.T) {
	a, _ := NewTable([]string{"a"}, []string{"int"}, [][]any{{int64(1)}})
	b, _ := NewTable([]string{"a"}, []string{"int"}, [][]any{{int64(1)}})
	c, _ := NewTable([]string{"a"}, []string{"int"}, [][]any{{int64(2)}})

	if !a.Equal(b) {
		t.Error("expected a.Equal(b)")
	}
	if a.Equal(c) {
		t.Error("expected !a.Equal(c)")
	}
}

func TestTableFromCxCollectionCells(t *testing.T) {
	src := `[u [table[name tags]]
  alice [admin, user,]
]`
	tbl, err := TableFromCx(src)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	row, _ := tbl.Row(0)
	tags, ok := row["tags"].([]any)
	if !ok {
		t.Fatalf("tags not []any: %v (type %T)", row["tags"], row["tags"])
	}
	if len(tags) != 2 || tags[0] != "admin" || tags[1] != "user" {
		t.Errorf("wrong tags: %v", tags)
	}
}
