package cxlib

import (
	"bytes"
	"testing"
)

// Round-trip tests for the Go delimited (CSV/TSV/PSV) wrappers
// (Phase 7.67 V core; Phase 7.68 Go binding).
//
// Mirrors the eight-case shape of vcx/tests/v34_delimited_test.v.

// ── Emit ─────────────────────────────────────────────────────────────────────

func TestToCsvTableDirect(t *testing.T) {
	src := "[users [table[name::string age::int active::bool]]\n  alice 30 true\n  bob 25 false\n]"
	out, err := ToCsv(src)
	if err != nil {
		t.Fatalf("ToCsv: %v", err)
	}
	want := "name,age,active\r\nalice,30,true\r\nbob,25,false\r\n"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestToCsvRepeatedRow(t *testing.T) {
	src := "[users\n  [user id=1 name=alice admin=true]\n  [user id=2 name=bob]\n  [user id=3 name=carol admin=true]\n]"
	out, err := ToCsv(src)
	if err != nil {
		t.Fatalf("ToCsv: %v", err)
	}
	want := "id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestToCsvDottedPath(t *testing.T) {
	src := "[config\n  [server host=localhost port=8080 tls=true]\n  [logging level=info format=json]\n]"
	out, err := ToCsv(src)
	if err != nil {
		t.Fatalf("ToCsv: %v", err)
	}
	want := "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestToTsv(t *testing.T) {
	src := "[t [table[a b c]]\n  x y z\n]"
	out, err := ToTsv(src)
	if err != nil {
		t.Fatalf("ToTsv: %v", err)
	}
	if out != "a\tb\tc\r\nx\ty\tz\r\n" {
		t.Fatalf("got %q", out)
	}
}

func TestToPsv(t *testing.T) {
	src := "[t [table[a b]]\n  x y\n]"
	out, err := ToPsv(src)
	if err != nil {
		t.Fatalf("ToPsv: %v", err)
	}
	if out != "a|b\r\nx|y\r\n" {
		t.Fatalf("got %q", out)
	}
}

// ── Parse ────────────────────────────────────────────────────────────────────

func TestFromCsvAutoTypes(t *testing.T) {
	in := "name,age,active\nalice,30,true\nbob,25,false\n"
	out, err := FromCsv(in)
	if err != nil {
		t.Fatalf("FromCsv: %v", err)
	}
	want := "[table [table[name age::int active::bool]]\n  alice 30 true\n  bob 25 false\n]"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestFromCsvQuotedStaysString(t *testing.T) {
	in := "name,age\nalice,\"30\"\nbob,\"25\"\n"
	out, err := FromCsv(in)
	if err != nil {
		t.Fatalf("FromCsv: %v", err)
	}
	want := "[table [table[name age]]\n  alice 30\n  bob 25\n]"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestFromCsvEmptyCellIsNull(t *testing.T) {
	in := "name,age\nalice,30\nbob,\n"
	out, err := FromCsv(in)
	if err != nil {
		t.Fatalf("FromCsv: %v", err)
	}
	want := "[table [table[name age::int]]\n  alice 30\n  bob null\n]"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

// ── Arbitrary delimiter + data_bin one-shots ─────────────────────────────────

func TestToDelimitedSemicolon(t *testing.T) {
	src := "[t [table[a b]]\n  x y\n]"
	out, err := ToDelimited(src, ';')
	if err != nil {
		t.Fatalf("ToDelimited: %v", err)
	}
	if out != "a;b\r\nx;y\r\n" {
		t.Fatalf("got %q", out)
	}
}

func TestCsvToDataBinRoundTrip(t *testing.T) {
	payload, err := CsvToDataBin("name,age\nalice,30\nbob,25\n")
	if err != nil {
		t.Fatalf("CsvToDataBin: %v", err)
	}
	if !bytes.HasPrefix(payload, []byte("CXCol")) {
		t.Fatalf("expected CXCol magic, got %q", payload[:min(5, len(payload))])
	}
	out, err := DataBinToCsv(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToCsv: %v", err)
	}
	want := "name,age\r\nalice,30\r\nbob,25\r\n"
	if out != want {
		t.Fatalf("got %q\nwant %q", out, want)
	}
}

func TestTsvToDataBinRoundTrip(t *testing.T) {
	payload, err := TsvToDataBin("a\tb\nx\ty\n")
	if err != nil {
		t.Fatalf("TsvToDataBin: %v", err)
	}
	out, err := DataBinToTsv(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToTsv: %v", err)
	}
	if out != "a\tb\r\nx\ty\r\n" {
		t.Fatalf("got %q", out)
	}
}

func TestPsvToDataBinRoundTrip(t *testing.T) {
	payload, err := PsvToDataBin("a|b\nx|y\n")
	if err != nil {
		t.Fatalf("PsvToDataBin: %v", err)
	}
	out, err := DataBinToPsv(reframe(payload))
	if err != nil {
		t.Fatalf("DataBinToPsv: %v", err)
	}
	if out != "a|b\r\nx|y\r\n" {
		t.Fatalf("got %q", out)
	}
}
