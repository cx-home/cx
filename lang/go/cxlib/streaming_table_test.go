package cxlib

import (
	"os"
	"strings"
	"testing"
)

// Streaming Table API tests (Phase 7.74b). Mirrors the Python
// test_streaming_table.py and the V core v34_streaming_table_test.v.

const sixRowInput = `[points :table[name:string score:i32]
  alice 91
  bob 88
  carol 73
  dave 95
  eve 84
  frank 60
]`

func TestToDataBinChunkedRoundTrip(t *testing.T) {
	payload, err := ToDataBinChunked(sixRowInput)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	if len(payload) < 4 || string(payload[:4]) != "CXDB" {
		t.Fatalf("expected CXDB magic, got %d bytes", len(payload))
	}
	out, err := FromDataBin(reframe(payload))
	if err != nil {
		t.Fatalf("FromDataBin: %v", err)
	}
	if !strings.Contains(out, "alice") || !strings.Contains(out, "frank") {
		t.Fatalf("expected alice/frank in chunked round-trip, got: %s", out)
	}
}

func TestStreamingTableBytesRoundTrip(t *testing.T) {
	payload, err := ToDataBinChunked(sixRowInput)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	r, err := OpenTableReader(payload)
	if err != nil {
		t.Fatalf("OpenTableReader: %v", err)
	}
	defer r.Close()

	schema, err := r.Schema()
	if err != nil {
		t.Fatalf("Schema: %v", err)
	}
	if len(schema) == 0 {
		t.Fatalf("Schema returned empty payload")
	}

	var groups [][]byte
	for {
		g, ok, err := r.Next()
		if err != nil {
			t.Fatalf("Next: %v", err)
		}
		if !ok {
			break
		}
		groups = append(groups, g)
	}
	if len(groups) == 0 {
		t.Fatalf("expected at least one row group")
	}

	w, err := OpenTableWriter(schema)
	if err != nil {
		t.Fatalf("OpenTableWriter: %v", err)
	}
	for _, g := range groups {
		if err := w.Emit(g); err != nil {
			t.Fatalf("Emit: %v", err)
		}
	}
	out, err := w.CloseGetBytes()
	if err != nil {
		t.Fatalf("CloseGetBytes: %v", err)
	}
	cxOut, err := FromDataBin(reframe(out))
	if err != nil {
		t.Fatalf("FromDataBin(out): %v", err)
	}
	if !strings.Contains(cxOut, "alice") || !strings.Contains(cxOut, "frank") {
		t.Fatalf("expected alice/frank in streamed round-trip, got: %s", cxOut)
	}
}

func TestStreamingTableFDRoundTrip(t *testing.T) {
	payload, err := ToDataBinChunked(sixRowInput)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	r, err := OpenTableReader(payload)
	if err != nil {
		t.Fatalf("OpenTableReader: %v", err)
	}
	defer r.Close()
	schema, err := r.Schema()
	if err != nil {
		t.Fatalf("Schema: %v", err)
	}
	var groups [][]byte
	for {
		g, ok, err := r.Next()
		if err != nil {
			t.Fatalf("Next: %v", err)
		}
		if !ok {
			break
		}
		groups = append(groups, g)
	}

	tmp, err := os.CreateTemp("", "cx_streaming_table_go_*.cxdb")
	if err != nil {
		t.Fatalf("temp file: %v", err)
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	w, err := OpenTableWriterFD(schema, int(tmp.Fd()))
	if err != nil {
		tmp.Close()
		t.Fatalf("OpenTableWriterFD: %v", err)
	}
	for _, g := range groups {
		if err := w.Emit(g); err != nil {
			tmp.Close()
			t.Fatalf("Emit: %v", err)
		}
	}
	w.Close()
	tmp.Close()

	rf, err := os.Open(tmpPath)
	if err != nil {
		t.Fatalf("open temp for read: %v", err)
	}
	defer rf.Close()
	r2, err := OpenTableReaderFD(int(rf.Fd()))
	if err != nil {
		t.Fatalf("OpenTableReaderFD: %v", err)
	}
	defer r2.Close()
	rtSchema, err := r2.Schema()
	if err != nil {
		t.Fatalf("rt Schema: %v", err)
	}
	if string(rtSchema) != string(schema) {
		t.Fatalf("schema drift across fd round-trip: %d vs %d bytes",
			len(rtSchema), len(schema))
	}
	var rtGroups int
	for {
		_, ok, err := r2.Next()
		if err != nil {
			t.Fatalf("rt Next: %v", err)
		}
		if !ok {
			break
		}
		rtGroups++
	}
	if rtGroups != len(groups) {
		t.Fatalf("group count drift: %d vs %d", rtGroups, len(groups))
	}
}

func TestOpenTableReaderInvalidInput(t *testing.T) {
	_, err := OpenTableReader([]byte("garb"))
	if err == nil {
		t.Fatalf("expected error on invalid CXDB input")
	}
}
