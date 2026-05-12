package cxlib

import (
	"encoding/binary"
	"os"
	"strings"
	"testing"
)

func assertWcode(t *testing.T, code string, err error) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected %s error, got nil", code)
	}
	if !strings.Contains(err.Error(), code) {
		t.Fatalf("expected %s in error, got %q", code, err)
	}
}

func TestEventWriterCapabilityBit(t *testing.T) {
	feat, err := FeaturesU64()
	if err != nil {
		t.Fatalf("FeaturesU64: %v", err)
	}
	if feat&(1<<27) == 0 {
		t.Fatalf("capability bit 27 (streaming-write) not advertised; got 0x%x", feat)
	}
}

func TestEventWriterMinimalCx(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := w.StartDoc(); err != nil {
		t.Fatalf("start_doc: %v", err)
	}
	if err := w.StartElement("greet", nil); err != nil {
		t.Fatalf("start_element: %v", err)
	}
	if err := w.Text("hello"); err != nil {
		t.Fatalf("text: %v", err)
	}
	if err := w.EndElement("greet"); err != nil {
		t.Fatalf("end_element: %v", err)
	}
	if err := w.EndDoc(); err != nil {
		t.Fatalf("end_doc: %v", err)
	}
	out, err := w.CloseGetBytes()
	if err != nil {
		t.Fatalf("close: %v", err)
	}
	s := string(out)
	if !strings.Contains(s, "[greet") || !strings.Contains(s, "hello") {
		t.Fatalf("unexpected output: %q", s)
	}
}

func TestEventWriterMinimalXml(t *testing.T) {
	w, err := NewEventWriter("xml")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer w.Close()
	if err := w.StartDoc(); err != nil {
		t.Fatalf("start_doc: %v", err)
	}
	if err := w.StartElement("greet", nil); err != nil {
		t.Fatalf("start_element: %v", err)
	}
	if err := w.Text("hello & welcome"); err != nil {
		t.Fatalf("text: %v", err)
	}
	if err := w.EndElement("greet"); err != nil {
		t.Fatalf("end_element: %v", err)
	}
	if err := w.EndDoc(); err != nil {
		t.Fatalf("end_doc: %v", err)
	}
	out, err := w.CloseGetBytes()
	if err != nil {
		t.Fatalf("close: %v", err)
	}
	s := string(out)
	if !strings.Contains(s, `<?xml version="1.0"?>`) {
		t.Fatalf("missing xml decl: %q", s)
	}
	if !strings.Contains(s, "<greet>") || !strings.Contains(s, "</greet>") {
		t.Fatalf("missing greet tags: %q", s)
	}
	if !strings.Contains(s, "hello &amp; welcome") {
		t.Fatalf("missing escaped text: %q", s)
	}
}

func TestEventWriterAttrs(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer w.Close()
	_ = w.StartDoc()
	if err := w.StartElement("row", []EventAttr{
		{Name: "id", Value: "1", DataType: "int"},
		{Name: "name", Value: "alice", DataType: "string"},
	}); err != nil {
		t.Fatalf("start_element with attrs: %v", err)
	}
	_ = w.EndElement("row")
	_ = w.EndDoc()
	out, err := w.CloseGetBytes()
	if err != nil {
		t.Fatalf("close: %v", err)
	}
	s := string(out)
	if !strings.Contains(s, "id=1") {
		t.Fatalf("expected id=1, got %q", s)
	}
	if !strings.Contains(s, "name=") {
		t.Fatalf("expected name=, got %q", s)
	}
}

func TestEventWriterW001(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W001", w.StartDoc())
}

func TestEventWriterW002(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	assertWcode(t, "W002", w.Text("premature"))
}

func TestEventWriterW003(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	_ = w.EndDoc()
	assertWcode(t, "W003", w.Text("post"))
}

func TestEventWriterW004(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	_ = w.StartElement("open", nil)
	assertWcode(t, "W004", w.EndDoc())
}

func TestEventWriterW005(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	_ = w.StartElement("greet", nil)
	assertWcode(t, "W005", w.EndElement("farewell"))
}

func TestEventWriterW006(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W006", w.EndElement("orphan"))
}

func TestEventWriterW008(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W008", w.Scalar("42", "not_a_type"))
}

func TestEventWriterW009AliasOnXml(t *testing.T) {
	w, err := NewEventWriter("xml")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W009", w.Alias("ref"))
}

func TestEventWriterW012(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W012", w.RowGroup([]byte{1}))
}

func TestEventWriterW013(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	assertWcode(t, "W013", w.EndTable())
}

func TestEventWriterFailClosed(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	_ = w.StartElement("a", nil)
	if err := w.EndElement("b"); err == nil {
		t.Fatalf("expected W005 from mismatched end")
	}
	// Subsequent emit should also raise (with W005 retained).
	err = w.Text("still broken")
	assertWcode(t, "W005", err)
}

func TestEventWriterChunkedTableCx(t *testing.T) {
	w, err := NewEventWriter("cx")
	if err != nil { t.Fatalf("open: %v", err) }
	defer w.Close()
	_ = w.StartDoc()
	_ = w.StartElement("points", nil)

	colSpec := make([]byte, 0, 32)
	// 2 columns: name:string (0x30), score:i32 (0x12)
	var u32 [4]byte
	binary.LittleEndian.PutUint32(u32[:], 2)
	colSpec = append(colSpec, u32[:]...)
	binary.LittleEndian.PutUint32(u32[:], 4); colSpec = append(colSpec, u32[:]...); colSpec = append(colSpec, "name"...); colSpec = append(colSpec, 0x30)
	binary.LittleEndian.PutUint32(u32[:], 5); colSpec = append(colSpec, u32[:]...); colSpec = append(colSpec, "score"...); colSpec = append(colSpec, 0x12)

	if err := w.StartTable(colSpec); err != nil {
		t.Fatalf("start_table: %v", err)
	}
	// Row group: uvarint(2) + col1 strings + col2 i32 LE
	rg := []byte{2}
	rg = append(rg, byte(5)); rg = append(rg, "alice"...)
	rg = append(rg, byte(3)); rg = append(rg, "bob"...)
	binary.LittleEndian.PutUint32(u32[:], 91); rg = append(rg, u32[:]...)
	binary.LittleEndian.PutUint32(u32[:], 88); rg = append(rg, u32[:]...)
	if err := w.RowGroup(rg); err != nil {
		t.Fatalf("row_group: %v", err)
	}
	if err := w.EndTable(); err != nil {
		t.Fatalf("end_table: %v", err)
	}
	_ = w.EndElement("points")
	_ = w.EndDoc()
	out, err := w.CloseGetBytes()
	if err != nil {
		t.Fatalf("close: %v", err)
	}
	s := string(out)
	for _, want := range []string{":table", "alice", "91"} {
		if !strings.Contains(s, want) {
			t.Fatalf("missing %q in output: %q", want, s)
		}
	}
}

func TestEventWriterFD(t *testing.T) {
	f, err := os.CreateTemp("", "cx-event-writer-fd-*")
	if err != nil { t.Fatalf("temp: %v", err) }
	defer os.Remove(f.Name())
	defer f.Close()
	w, err := NewEventWriterFD("cx", int(f.Fd()))
	if err != nil { t.Fatalf("openfd: %v", err) }
	_ = w.StartDoc()
	_ = w.StartElement("hi", nil)
	_ = w.Text("there")
	_ = w.EndElement("hi")
	_ = w.EndDoc()
	out, err := w.CloseGetBytes()
	if err != nil { t.Fatalf("close: %v", err) }
	if len(out) != 0 {
		t.Fatalf("fd writer should return empty bytes; got %q", out)
	}
	// Re-read the file contents.
	if _, err := f.Seek(0, 0); err != nil { t.Fatalf("seek: %v", err) }
	buf := make([]byte, 4096)
	n, _ := f.Read(buf)
	s := string(buf[:n])
	if !strings.Contains(s, "[hi") || !strings.Contains(s, "there") {
		t.Fatalf("unexpected fd output: %q", s)
	}
}
