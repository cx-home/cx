package cxlib

import (
	"encoding/binary"
	"testing"
	"time"
)

// #815 — the SCALAR datetime tag (0x32) speaks data-bin.md §3.6.1:
//
//	0x32 i64 unix_nanos (8 LE) i16 offset_minutes (2 LE) u16 reserved (2, zero)
//
// This arm used to write a placeholder form — 10 zero bytes, a u16
// source-length, then the RFC3339 text. It was internally consistent, so
// Go→Go round-trips passed and Go-only flows never felt it; what it broke
// was every OTHER decoder, which reads 12 bytes and moves on. The COLUMN
// 0x32 arm (typedCells) was spec-true throughout.

// dtFrame prepends the [u32 LE size] header FromDataBin expects.
func dtFrame(payload []byte) []byte {
	out := make([]byte, 4+len(payload))
	binary.LittleEndian.PutUint32(out[:4], uint32(len(payload)))
	copy(out[4:], payload)
	return out
}

// ── (a) the wire IMAGE is the §3.6.1 12-byte form ───────────────────────────

func TestScalarDatetimeWritesTheSpecWireForm(t *testing.T) {
	// 2026-08-16T12:34:56.000000789Z — a nanosecond component the old
	// text form would have carried as characters instead of bits.
	tm := time.Date(2026, 8, 16, 12, 34, 56, 789, time.UTC)
	framed, err := encodeDataBin(tm)
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	payload := framed[4:]
	// 12-byte CXCol header, then the tag, then exactly 12 payload bytes.
	if got := len(payload); got != 12+1+12 {
		t.Fatalf("scalar datetime payload = %d bytes, want %d (§3.6.1 is fixed-width)", got, 12+1+12)
	}
	if payload[12] != tagDateTime {
		t.Fatalf("tag = 0x%02x, want 0x32", payload[12])
	}
	body := payload[13:]
	if got := int64(binary.LittleEndian.Uint64(body[0:8])); got != tm.UnixNano() {
		t.Errorf("unix_nanos = %d, want %d", got, tm.UnixNano())
	}
	if got := int16(binary.LittleEndian.Uint16(body[8:10])); got != 0 {
		t.Errorf("offset_minutes = %d, want 0 for Z", got)
	}
	if got := binary.LittleEndian.Uint16(body[10:12]); got != 0 {
		t.Errorf("reserved = 0x%04x, want 0 (§3.6.1: must be zero)", got)
	}
}

// The offset rides the transport (§3.6.1 carriage / #807(d)): unix_nanos
// stays UTC-normalized — the instant is offset-independent — and
// offset_minutes restores the LOCAL render on decode.
func TestScalarDatetimeCarriesTheOffset(t *testing.T) {
	tm := time.Date(2026, 8, 16, 12, 34, 56, 0, time.FixedZone("", -5*3600))
	framed, err := encodeDataBin(tm)
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	body := framed[4:][13:]
	if got := int64(binary.LittleEndian.Uint64(body[0:8])); got != tm.UnixNano() {
		t.Errorf("unix_nanos = %d, want the UTC-normalized instant %d", got, tm.UnixNano())
	}
	if got := int16(binary.LittleEndian.Uint16(body[8:10])); got != -300 {
		t.Errorf("offset_minutes = %d, want -300", got)
	}

	back, err := decodeDataBin(framed[4:])
	if err != nil {
		t.Fatalf("decodeDataBin: %v", err)
	}
	rt, ok := back.(time.Time)
	if !ok {
		t.Fatalf("decoded %T, want time.Time", back)
	}
	if !rt.Equal(tm) {
		t.Errorf("instant = %s, want %s", rt, tm)
	}
	if _, off := rt.Zone(); off != -5*3600 {
		t.Errorf("restored zone offset = %ds, want %ds", off, -5*3600)
	}
}

// ── (b) round-trip, including pre-1970 (negative unix_nanos) ────────────────

func TestScalarDatetimeRoundTrip(t *testing.T) {
	cases := []time.Time{
		time.Date(2026, 8, 16, 12, 34, 56, 0, time.UTC),
		time.Date(1969, 7, 20, 20, 17, 40, 0, time.UTC), // pre-epoch: negative nanos
		time.Date(2026, 1, 1, 0, 0, 0, 123456789, time.UTC),
	}
	for _, tm := range cases {
		framed, err := encodeDataBin(map[string]any{"when": tm})
		if err != nil {
			t.Fatalf("encode %s: %v", tm, err)
		}
		back, err := decodeDataBin(framed[4:])
		if err != nil {
			t.Fatalf("decode %s: %v", tm, err)
		}
		m, ok := back.(map[string]any)
		if !ok {
			t.Fatalf("decoded %T, want map", back)
		}
		got, ok := m["when"].(time.Time)
		if !ok {
			t.Fatalf("field decoded %T, want time.Time", m["when"])
		}
		if !got.Equal(tm) {
			t.Errorf("round-trip = %s, want %s", got, tm)
		}
	}
}

// ── (c) CROSS-DECODER: a Go-written scalar datetime is read by V ────────────
//
// The real point of the fix. FromDataBin runs the V decoder through the C
// ABI, so this fails on any wire divergence between the two engines. Under
// the placeholder form V read 12 bytes of a text-carrying frame and
// reconstructed an EMPTY value — `[when]`, the instant silently gone.

func TestScalarDatetimeDecodesInV(t *testing.T) {
	tm := time.Date(2026, 8, 16, 12, 34, 56, 0, time.UTC)
	framed, err := encodeDataBin(map[string]any{"when": tm})
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	out, err := FromDataBin(framed)
	if err != nil {
		t.Fatalf("FromDataBin (the V decoder): %v", err)
	}
	if want := "[when 2026-08-16T12:34:56Z]"; out != want {
		t.Errorf("V read %q, want %q", out, want)
	}
}

func TestScalarDatetimeOffsetDecodesInV(t *testing.T) {
	tm := time.Date(2026, 8, 16, 12, 34, 56, 0, time.FixedZone("", -5*3600))
	framed, err := encodeDataBin(map[string]any{"when": tm})
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	out, err := FromDataBin(framed)
	if err != nil {
		t.Fatalf("FromDataBin (the V decoder): %v", err)
	}
	if want := "[when 2026-08-16T12:34:56-05:00]"; out != want {
		t.Errorf("V read %q, want %q", out, want)
	}
}

// ── (d) the DATE scalar (0x31) shares the reconstruction path ──────────────

func TestScalarDateDecodesInV(t *testing.T) {
	var w dataBinWriter
	w.buf = append(w.buf, cxcolMagic...)
	w.buf = append(w.buf, cxcolVersion)
	w.buf = append(w.buf, cxcolFlagsLE)
	w.u32(uint32(cxcolDefaultDepth))
	w.buf = append(w.buf, 0)
	w.u8(tagMap)
	w.uvarint(1)
	w.stringValue("on")
	w.u8(tagDate)
	w.u16(2026)
	w.u8(8)
	w.u8(16)
	out, err := FromDataBin(dtFrame(w.buf))
	if err != nil {
		t.Fatalf("FromDataBin (the V decoder): %v", err)
	}
	if want := "[on 2026-08-16]"; out != want {
		t.Errorf("V read %q, want %q", out, want)
	}
}

// ── (e) the REVERSE cross-decoder direction, unlocked by #830 ───────────────
//
// #815 could only witness Go→V: V erased the temporal kind on the way out,
// emitting the string tag 0x30 for a scalar date/datetime, so there were no
// V-written 0x31/0x32 scalars to read. With V's encoder risen to §3.6 (#830)
// the round trip closes in both directions, which is what "one wire" means.

func TestVWrittenScalarDatetimeDecodesInGo(t *testing.T) {
	payload, err := ToDataBin("[when 2026-08-16T12:34:56Z]")
	if err != nil {
		t.Fatalf("ToDataBin (the V encoder): %v", err)
	}
	// 12-byte CXCol header, 0x50 map, uvarint count, 0x30 string-key tag,
	// uvarint key len, key bytes — then the value tag.
	if got := payload[12+1+1+1+1+len("when")]; got != tagDateTime {
		t.Fatalf("V wrote tag 0x%02x for a datetime scalar, want 0x32", got)
	}
	v, err := decodeDataBin(payload)
	if err != nil {
		t.Fatalf("decodeDataBin of V bytes: %v", err)
	}
	m, ok := v.(map[string]any)
	if !ok {
		t.Fatalf("decoded %T, want map", v)
	}
	got, ok := m["when"].(time.Time)
	if !ok {
		t.Fatalf("field decoded %T, want time.Time — the kind did not survive", m["when"])
	}
	if want := time.Date(2026, 8, 16, 12, 34, 56, 0, time.UTC); !got.Equal(want) {
		t.Errorf("instant = %s, want %s", got, want)
	}
}

func TestVWrittenScalarDateDecodesInGo(t *testing.T) {
	payload, err := ToDataBin("[on 2026-08-16]")
	if err != nil {
		t.Fatalf("ToDataBin (the V encoder): %v", err)
	}
	if got := payload[12+1+1+1+1+len("on")]; got != tagDate {
		t.Fatalf("V wrote tag 0x%02x for a date scalar, want 0x31", got)
	}
	v, err := decodeDataBin(payload)
	if err != nil {
		t.Fatalf("decodeDataBin of V bytes: %v", err)
	}
	m := v.(map[string]any)
	got, ok := m["on"].(time.Time)
	if !ok {
		t.Fatalf("field decoded %T, want time.Time", m["on"])
	}
	if want := time.Date(2026, 8, 16, 0, 0, 0, 0, time.UTC); !got.Equal(want) {
		t.Errorf("date = %s, want %s", got, want)
	}
}
