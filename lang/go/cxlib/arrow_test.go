//go:build arrow

package cxlib

import (
	"bytes"
	"testing"
	"time"

	"github.com/apache/arrow/go/v18/arrow"
	"github.com/apache/arrow/go/v18/arrow/array"
	"github.com/apache/arrow/go/v18/arrow/memory"
)

// dateDays computes Arrow date32 (days since 1970-01-01 UTC).
func dateDays(y int, m time.Month, d int) arrow.Date32 {
	return arrow.Date32FromTime(time.Date(y, m, d, 0, 0, 0, 0, time.UTC))
}

// Apache Arrow C-Data interop tests for lang/go/cxlib
// (Phase 7.74c-cont-bindings-multi-go).
//
// Mirrors lang/python/test_arrow.py:
//   - Round-trip per supported v0.6.0 column type: int / i8 / i16 / i32 /
//     float / bool / string / date / bytes (9 tests).
//   - datetime column round-trips as Arrow timestamp[ns, UTC].
//   - Arrow-table → CXDB → Arrow-table inverse round-trip.
//   - Capability + version smoke tests.
//
// Run:  go test -tags arrow ./lang/go/cxlib/...

func readAll(t *testing.T, payload []byte) []arrow.Record {
	t.Helper()
	rdr, err := ArrowExport(payload)
	if err != nil {
		t.Fatalf("ArrowExport: %v", err)
	}
	defer rdr.Release()
	var recs []arrow.Record
	for rdr.Next() {
		rec := rdr.Record()
		rec.Retain()
		recs = append(recs, rec)
	}
	if err := rdr.Err(); err != nil {
		t.Fatalf("reader error: %v", err)
	}
	return recs
}

func releaseAll(recs []arrow.Record) {
	for _, r := range recs {
		r.Release()
	}
}

func concatColumn(recs []arrow.Record, idx int) arrow.Array {
	// Collapse a single-column chunked stream to a slice for assertions.
	// Returns nil if recs is empty.
	if len(recs) == 0 {
		return nil
	}
	if len(recs) == 1 {
		col := recs[0].Column(idx)
		col.Retain()
		return col
	}
	arrs := make([]arrow.Array, len(recs))
	for i, r := range recs {
		arrs[i] = r.Column(idx)
	}
	// For test simplicity the round-trip helpers use one row group, so
	// we don't implement multi-chunk concat.
	panic("concatColumn: unexpected multi-record stream")
}

func TestArrowAvailability(t *testing.T) {
	if !ArrowAvailable() {
		t.Fatal("ArrowAvailable should be true under -tags arrow")
	}
	if got := ArrowFeatures(); got != 0x800000 {
		t.Fatalf("ArrowFeatures = 0x%x; want 0x800000", got)
	}
	if v := ArrowVersion(); v != "0.6.0" {
		t.Fatalf("ArrowVersion = %q; want %q", v, "0.6.0")
	}
	if ArrowMergedFeatures()&0x800000 == 0 {
		t.Fatal("ArrowMergedFeatures should have bit 23 set")
	}
}

func TestArrowRoundTripInt(t *testing.T) {
	src := "[stats :table[score:int]\n  100\n  -1\n  9223372036854775807\n  -9223372036854775808\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	if len(recs) != 1 {
		t.Fatalf("want 1 record, got %d", len(recs))
	}
	col := recs[0].Column(0).(*array.Int64)
	want := []int64{100, -1, 9223372036854775807, -9223372036854775808}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %d want %d", i, col.Value(i), v)
		}
	}
	// inverse direction
	rdr2, err := ArrowExport(payload)
	if err != nil {
		t.Fatalf("ArrowExport (for inverse): %v", err)
	}
	out, err := ArrowImportToDataBin(rdr2)
	if err != nil {
		t.Fatalf("ArrowImportToDataBin: %v", err)
	}
	recs2 := readAll(t, out)
	defer releaseAll(recs2)
	col2 := recs2[0].Column(0).(*array.Int64)
	for i, v := range want {
		if col2.Value(i) != v {
			t.Fatalf("inverse row %d: got %d want %d", i, col2.Value(i), v)
		}
	}
}

func TestArrowRoundTripI8(t *testing.T) {
	src := "[stats :table[v:i8]\n  -128\n  -1\n  0\n  127\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Int8)
	want := []int8{-128, -1, 0, 127}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %d want %d", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripI16(t *testing.T) {
	src := "[stats :table[v:i16]\n  -32768\n  -1\n  0\n  32767\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Int16)
	want := []int16{-32768, -1, 0, 32767}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %d want %d", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripI32(t *testing.T) {
	src := "[stats :table[v:i32]\n  -2147483648\n  -1\n  0\n  2147483647\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Int32)
	want := []int32{-2147483648, -1, 0, 2147483647}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %d want %d", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripFloat(t *testing.T) {
	src := "[stats :table[v:float]\n  0.0\n  -1.5\n  3.14159\n  1e100\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Float64)
	if col.Value(0) != 0.0 {
		t.Fatalf("row 0: got %v want 0.0", col.Value(0))
	}
	if col.Value(1) != -1.5 {
		t.Fatalf("row 1: got %v want -1.5", col.Value(1))
	}
	if d := col.Value(2) - 3.14159; d > 1e-9 || d < -1e-9 {
		t.Fatalf("row 2: got %v want ~3.14159", col.Value(2))
	}
	if col.Value(3) != 1e100 {
		t.Fatalf("row 3: got %v want 1e100", col.Value(3))
	}
}

func TestArrowRoundTripBool(t *testing.T) {
	src := "[flags :table[v:bool]\n  true\n  false\n  true\n  false\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Boolean)
	want := []bool{true, false, true, false}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %v want %v", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripString(t *testing.T) {
	src := "[names :table[v:string]\n  alice\n  bob\n  carol\n  unicode-é-é-ñ\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.String)
	want := []string{"alice", "bob", "carol", "unicode-é-é-ñ"}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %q want %q", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripDate(t *testing.T) {
	src := "[evts :table[when:date]\n  2026-05-09\n  1970-01-01\n  9999-12-31\n  1900-01-01\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(0).(*array.Date32)
	want := []arrow.Date32{
		dateDays(2026, 5, 9),
		dateDays(1970, 1, 1),
		dateDays(9999, 12, 31),
		dateDays(1900, 1, 1),
	}
	for i, v := range want {
		if col.Value(i) != v {
			t.Fatalf("row %d: got %d want %d", i, col.Value(i), v)
		}
	}
}

func TestArrowRoundTripBytes(t *testing.T) {
	src := "[blobs :table[name:string blob:bytes]\n  alpha \"A1B2\"\n  beta \"FF00DE\"\n  empty \"\"\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)
	col := recs[0].Column(1).(*array.Binary)
	if col.Len() != 3 {
		t.Fatalf("blob col len = %d; want 3", col.Len())
	}
	// Round-trip via Import → Export must preserve the column.
	rdr2, err := ArrowExport(payload)
	if err != nil {
		t.Fatalf("ArrowExport (for inverse): %v", err)
	}
	out, err := ArrowImportToDataBin(rdr2)
	if err != nil {
		t.Fatalf("ArrowImportToDataBin: %v", err)
	}
	recs2 := readAll(t, out)
	defer releaseAll(recs2)
	col2 := recs2[0].Column(1).(*array.Binary)
	for i := 0; i < col.Len(); i++ {
		if !bytes.Equal(col.Value(i), col2.Value(i)) {
			t.Fatalf("blob row %d differs after round-trip: %x vs %x",
				i, col.Value(i), col2.Value(i))
		}
	}
}

func TestArrowRoundTripDatetime(t *testing.T) {
	src := "[evts :table[when:datetime]\n" +
		"  2024-01-15T12:34:56Z\n" +
		"  2025-06-30T23:00:00+02:00\n" +
		"  1970-01-01T00:00:00Z\n" +
		"  1900-01-01T00:00:00Z\n]"
	payload, err := ToDataBinChunked(src)
	if err != nil {
		t.Fatalf("ToDataBinChunked: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)

	field := recs[0].Schema().Field(0)
	ts, ok := field.Type.(*arrow.TimestampType)
	if !ok {
		t.Fatalf("col type = %T; want *arrow.TimestampType", field.Type)
	}
	if ts.Unit != arrow.Nanosecond || ts.TimeZone != "UTC" {
		t.Fatalf("col type = %s; want timestamp[ns, UTC]", ts)
	}

	col := recs[0].Column(0).(*array.Timestamp)
	// CXDB strict-canonical normalizes offsets to UTC on the wire, so the
	// +02:00 row arrives as 21:00:00 UTC.
	want := []time.Time{
		time.Date(2024, 1, 15, 12, 34, 56, 0, time.UTC),
		time.Date(2025, 6, 30, 21, 0, 0, 0, time.UTC),
		time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(1900, 1, 1, 0, 0, 0, 0, time.UTC),
	}
	for i, w := range want {
		got := time.Unix(0, int64(col.Value(i))).UTC()
		if !got.Equal(w) {
			t.Fatalf("row %d: got %s want %s", i, got, w)
		}
	}

	// Inverse: arrow → CXDB → arrow round-trip preserves equality.
	rdr2, err := ArrowExport(payload)
	if err != nil {
		t.Fatalf("ArrowExport (for inverse): %v", err)
	}
	out, err := ArrowImportToDataBin(rdr2)
	if err != nil {
		t.Fatalf("ArrowImportToDataBin: %v", err)
	}
	recs2 := readAll(t, out)
	defer releaseAll(recs2)
	col2 := recs2[0].Column(0).(*array.Timestamp)
	for i := 0; i < col.Len(); i++ {
		if col.Value(i) != col2.Value(i) {
			t.Fatalf("ns row %d: got %d want %d", i, col2.Value(i), col.Value(i))
		}
	}
}

func TestArrowInverseFromGoBuiltTable(t *testing.T) {
	// Build an Arrow record directly (no CXDB starting point) and verify
	// the inverse direction: arrow → CXDB → arrow re-decode → equality.
	pool := memory.NewGoAllocator()
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "name", Type: arrow.BinaryTypes.String},
		{Name: "score", Type: arrow.PrimitiveTypes.Int64},
		{Name: "ratio", Type: arrow.PrimitiveTypes.Float64},
	}, nil)
	bld := array.NewRecordBuilder(pool, schema)
	defer bld.Release()
	bld.Field(0).(*array.StringBuilder).AppendValues(
		[]string{"alice", "bob", "carol"}, nil)
	bld.Field(1).(*array.Int64Builder).AppendValues(
		[]int64{91, 88, 73}, nil)
	bld.Field(2).(*array.Float64Builder).AppendValues(
		[]float64{0.91, 0.88, 0.73}, nil)
	rec := bld.NewRecord()
	defer rec.Release()

	rdr, err := array.NewRecordReader(schema, []arrow.Record{rec})
	if err != nil {
		t.Fatalf("NewRecordReader: %v", err)
	}
	defer rdr.Release()

	payload, err := ArrowImportToDataBin(rdr)
	if err != nil {
		t.Fatalf("ArrowImportToDataBin: %v", err)
	}
	recs := readAll(t, payload)
	defer releaseAll(recs)

	if got := recs[0].NumRows(); got != 3 {
		t.Fatalf("NumRows = %d; want 3", got)
	}
	names := recs[0].Column(0).(*array.String)
	scores := recs[0].Column(1).(*array.Int64)
	ratios := recs[0].Column(2).(*array.Float64)
	wantNames := []string{"alice", "bob", "carol"}
	wantScores := []int64{91, 88, 73}
	wantRatios := []float64{0.91, 0.88, 0.73}
	for i := 0; i < 3; i++ {
		if names.Value(i) != wantNames[i] {
			t.Fatalf("name[%d] = %q; want %q", i, names.Value(i), wantNames[i])
		}
		if scores.Value(i) != wantScores[i] {
			t.Fatalf("score[%d] = %d; want %d", i, scores.Value(i), wantScores[i])
		}
		if ratios.Value(i) != wantRatios[i] {
			t.Fatalf("ratio[%d] = %v; want %v", i, ratios.Value(i), wantRatios[i])
		}
	}
}

func TestArrowExportRejectsInvalidInput(t *testing.T) {
	if _, err := ArrowExport(nil); err == nil {
		t.Fatal("ArrowExport(nil): want error")
	}
	if _, err := ArrowExport([]byte("garb")); err == nil {
		t.Fatal("ArrowExport(garbage): want error")
	}
}

func TestArrowImportToDataBinRejectsNil(t *testing.T) {
	if _, err := ArrowImportToDataBin(nil); err == nil {
		t.Fatal("ArrowImportToDataBin(nil): want error")
	}
}
