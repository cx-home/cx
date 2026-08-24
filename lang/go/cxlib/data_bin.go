package cxlib

/*
#include "cx.h"
#include <stdlib.h>
*/
import "C"

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"math/big"
	"strings"
	"time"
	"unsafe"

	"github.com/cockroachdb/apd/v3"
)

// CXCol v1 codec — strict canonical binary data format.
// Spec: spec/core/data-bin.md.
//
// Decoder consumes the framed [u32 LE size][payload] buffer returned by
// libcx.cx_to_data_bin; encoder produces the same shape for input to
// libcx.cx_from_data_bin.
//
// Replaces the JSON-string detour previously used by Loads / Dumps
// (audit finding CB-3). Go types map:
//   int64       <-> CXCol int8/int16/int32/int64
//   *big.Int    <-> CXCol bigint (0x18; base-10 integer image — the kind
//                  is never erased: an in-i64 bigint still rides 0x18)
//   float64     <-> CXCol float64
//   *apd.Decimal <-> CXCol decimal (0x28; FIXED-POINT base-10 image,
//                  scale preserved — "1.10" stays "1.10"; exponent form
//                  is not a legal wire image). Host type per
//                  spec/03-approved/misc/type-mapping.md: an exact
//                  decimal library, never big.Float. cockroachdb/apd/v3
//                  is the pick — shopspring/decimal's String() trims
//                  trailing zeros ("1.10" -> "1.1"), erasing scale.
//   bool        <-> CXCol false/true
//   nil         <-> CXCol null
//   string      <-> CXCol string
//   []byte      <-> CXCol bytes
//   map[string]any <-> CXCol map (insertion order preserved)
//   []any       <-> CXCol array
//   time.Time   <-> CXCol datetime (data-bin.md §3.6.1: i64 unix_nanos
//                  LE + i16 offset_minutes LE + u16 reserved — #815)

const (
	tagNull       = 0x00
	tagFalse      = 0x01
	tagTrue       = 0x02
	tagInt8       = 0x10
	tagInt16      = 0x11
	tagInt32      = 0x12
	tagInt64      = 0x13
	// I1 stream 11 (row 16, L46/L48): bigint is a SEMANTIC KIND on the
	// wire — an in-i64 bigint still encodes 0x18 (narrowing-within-kind:
	// a kind is never erased by narrowing).
	tagBigint     = 0x18
	tagFloat64    = 0x20
	tagDecimal    = 0x28
	tagString     = 0x30
	tagDate       = 0x31
	tagDateTime   = 0x32
	tagBytes      = 0x33
	tagArray      = 0x40
	tagArrayEmpty = 0x41
	tagMap        = 0x50
	tagMapEmpty   = 0x51
	tagTable      = 0x60
	tagTableEmpty = 0x61
)

const (
	cxcolVersion      = 0x01
	cxcolFlagsLE      = 0x01
	cxcolDefaultDepth = 64
	cxcolMagicLen     = 5
)

// Wire magic — 5-byte "CXCol" (0x43 0x58 0x43 0x6F 0x6C). Header is
// 12 bytes total. See spec/core/data-bin.md §3.1.
var cxcolMagic = []byte{'C', 'X', 'C', 'o', 'l'}

// ── Encoder ──────────────────────────────────────────────────────────────────

// encodeDataBin produces a FRAMED CXCol v1 buffer for FromDataBin.
// FromDataBin (cgo wrapper of cx_from_data_bin) expects the same
// [u32 LE size][payload] layout that cx_to_data_bin returns.
func encodeDataBin(value any) ([]byte, error) {
	var w dataBinWriter
	w.buf = make([]byte, 0, 256)
	// Header — 5 magic + 1 ver + 1 flags + 4 max_depth + 1 reserved = 12.
	w.buf = append(w.buf, cxcolMagic...)
	w.buf = append(w.buf, cxcolVersion)
	w.buf = append(w.buf, cxcolFlagsLE)
	w.u32(uint32(cxcolDefaultDepth))
	w.buf = append(w.buf, 0)
	if err := w.value(value); err != nil {
		return nil, err
	}
	// Frame
	out := make([]byte, 4+len(w.buf))
	binary.LittleEndian.PutUint32(out[:4], uint32(len(w.buf)))
	copy(out[4:], w.buf)
	return out, nil
}

type dataBinWriter struct {
	buf []byte
}

func (w *dataBinWriter) u8(v byte) { w.buf = append(w.buf, v) }
func (w *dataBinWriter) u16(v uint16) {
	var b [2]byte
	binary.LittleEndian.PutUint16(b[:], v)
	w.buf = append(w.buf, b[:]...)
}
func (w *dataBinWriter) u32(v uint32) {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], v)
	w.buf = append(w.buf, b[:]...)
}
func (w *dataBinWriter) i64(v int64) {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], uint64(v))
	w.buf = append(w.buf, b[:]...)
}
func (w *dataBinWriter) f64(v float64) {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], math.Float64bits(v))
	w.buf = append(w.buf, b[:]...)
}
func (w *dataBinWriter) uvarint(v uint64) {
	for v >= 0x80 {
		w.buf = append(w.buf, byte(v&0x7F)|0x80)
		v >>= 7
	}
	w.buf = append(w.buf, byte(v&0x7F))
}
func (w *dataBinWriter) stringValue(s string) {
	w.u8(tagString)
	w.stringPayload(s)
}

// stringPayload writes a length-prefixed byte payload WITHOUT a leading
// tag — the caller has already written its kind tag (0x30 / 0x28 / 0x18).
// Mirrors vcx encode_string_payload.
func (w *dataBinWriter) stringPayload(s string) {
	w.uvarint(uint64(len(s)))
	w.buf = append(w.buf, s...)
}

func (w *dataBinWriter) value(v any) error {
	switch x := v.(type) {
	case nil:
		w.u8(tagNull)
	case bool:
		if x {
			w.u8(tagTrue)
		} else {
			w.u8(tagFalse)
		}
	case int:
		return w.intCanonical(int64(x))
	case int8:
		return w.intCanonical(int64(x))
	case int16:
		return w.intCanonical(int64(x))
	case int32:
		return w.intCanonical(int64(x))
	case int64:
		return w.intCanonical(x)
	case uint:
		return w.intCanonical(int64(x))
	case uint8:
		return w.intCanonical(int64(x))
	case uint16:
		return w.intCanonical(int64(x))
	case uint32:
		return w.intCanonical(int64(x))
	case uint64:
		if x > math.MaxInt64 {
			return fmt.Errorf("cxcol: uint64 %d exceeds i64 range", x)
		}
		return w.intCanonical(int64(x))
	case *big.Int:
		// I1 L48: bigint rides 0x18 ALWAYS — even a value that fits i64
		// keeps its kind (narrowing-within-kind never erases a kind).
		if x == nil {
			w.u8(tagNull)
			return nil
		}
		w.u8(tagBigint)
		w.stringPayload(x.Text(10))
	case *apd.Decimal:
		// I1 L48: wire image is FIXED-POINT base-10 only — exponent
		// notation is not a legal wire image. apd's Text('f') renders
		// fixed-point while preserving scale ("1.10" -> "1.10";
		// 1e2 -> "100"). NaN / Infinity have no wire image.
		if x == nil {
			w.u8(tagNull)
			return nil
		}
		if x.Form != apd.Finite {
			return fmt.Errorf("cxcol: decimal must be finite; got %s (NaN/Infinity have no wire image)", x)
		}
		w.u8(tagDecimal)
		w.stringPayload(x.Text('f'))
	case float32:
		w.u8(tagFloat64)
		w.f64(float64(x))
	case float64:
		w.u8(tagFloat64)
		w.f64(x)
	case string:
		w.stringValue(x)
	case []byte:
		w.u8(tagBytes)
		w.uvarint(uint64(len(x)))
		w.buf = append(w.buf, x...)
	case time.Time:
		// data-bin.md §3.6.1: i64 unix_nanos LE + i16 offset_minutes LE +
		// u16 reserved (zero) — 12 bytes. #815: this arm wrote a PLACEHOLDER
		// form (10 zero bytes + u16 length + the RFC3339 source text). It
		// round-tripped Go→Go, so Go-only flows never felt it — but a
		// Go-written scalar datetime misparsed in every other decoder, and a
		// V-written one misparsed here. The COLUMN 0x32 arm (typedCells) was
		// always spec-true; the scalar arm now speaks the same wire.
		//
		// unix_nanos is UTC-normalized (the instant is offset-independent);
		// offset_minutes carries the zone so a decoder can restore the LOCAL
		// render (§3.6.1 transport carriage — the #807(d) reading).
		_, offSec := x.Zone()
		w.u8(tagDateTime)
		w.i64(x.UnixNano())
		w.u16(uint16(int16(offSec / 60)))
		w.u16(0)
	case map[string]any:
		if len(x) == 0 {
			w.u8(tagMapEmpty)
			return nil
		}
		w.u8(tagMap)
		w.uvarint(uint64(len(x)))
		// Note: Go map iteration is unordered. Insertion order isn't
		// preserved by standard map; consider using OrderedMap here
		// for canonical output. For now we accept Go's iteration order.
		for k, vv := range x {
			w.stringValue(k)
			if err := w.value(vv); err != nil {
				return err
			}
		}
	case []any:
		if len(x) == 0 {
			w.u8(tagArrayEmpty)
			return nil
		}
		w.u8(tagArray)
		w.uvarint(uint64(len(x)))
		for _, item := range x {
			if err := w.value(item); err != nil {
				return err
			}
		}
	default:
		return fmt.Errorf("cxcol: unsupported type %T", v)
	}
	return nil
}

func (w *dataBinWriter) intCanonical(v int64) error {
	switch {
	case v >= -128 && v <= 127:
		w.u8(tagInt8)
		w.buf = append(w.buf, byte(v))
	case v >= -32768 && v <= 32767:
		w.u8(tagInt16)
		w.u16(uint16(v))
	case v >= -2147483648 && v <= 2147483647:
		w.u8(tagInt32)
		w.u32(uint32(v))
	default:
		w.u8(tagInt64)
		w.i64(v)
	}
	return nil
}

// ── Decoder ──────────────────────────────────────────────────────────────────

type dataBinReader struct {
	buf      []byte
	pos      int
	depth    int
	maxDepth int
}

// decodeDataBin accepts a CXCol v1 PAYLOAD (12-byte header + value
// section), without the [u32 size] frame prefix. ToDataBin already
// strips the frame via extractBinPayload, so callers pass the
// payload directly.
func decodeDataBin(payload []byte) (any, error) {
	if len(payload) < 12 {
		return nil, errors.New("cxcol: payload too short for 12-byte header")
	}
	if string(payload[:cxcolMagicLen]) != "CXCol" {
		return nil, errors.New("cxcol: bad magic (expected 'CXCol')")
	}
	if payload[cxcolMagicLen] != cxcolVersion {
		return nil, fmt.Errorf("cxcol: unsupported version %d", payload[cxcolMagicLen])
	}
	if payload[6]&0xFE != 0 {
		return nil, errors.New("cxcol: reserved flag bits set")
	}
	if payload[6]&0x01 == 0 {
		return nil, errors.New("cxcol: only little-endian payloads supported in v1")
	}
	// bytes 7-10 max_depth (u32 LE); byte 11 reserved (must be zero).
	if payload[11] != 0 {
		return nil, errors.New("cxcol: reserved header byte must be zero")
	}
	r := &dataBinReader{buf: payload[12:], maxDepth: cxcolDefaultDepth}
	return r.value()
}

func (r *dataBinReader) take(n int) ([]byte, error) {
	if r.pos+n > len(r.buf) {
		return nil, fmt.Errorf("cxcol: %d bytes requested, %d remaining", n, len(r.buf)-r.pos)
	}
	out := r.buf[r.pos : r.pos+n]
	r.pos += n
	return out, nil
}

func (r *dataBinReader) u8() (byte, error) {
	if r.pos >= len(r.buf) {
		return 0, errors.New("cxcol: unexpected end of input")
	}
	v := r.buf[r.pos]
	r.pos++
	return v, nil
}

func (r *dataBinReader) u16() (uint16, error) {
	bs, err := r.take(2)
	if err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint16(bs), nil
}

func (r *dataBinReader) u32() (uint32, error) {
	bs, err := r.take(4)
	if err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint32(bs), nil
}

func (r *dataBinReader) uvarint() (uint64, error) {
	var x uint64
	var shift uint
	for i := 0; i < 5; i++ {
		b, err := r.u8()
		if err != nil {
			return 0, err
		}
		if b < 0x80 {
			if i == 4 && b > 0x0F {
				return 0, errors.New("cxcol: varint overflow")
			}
			if i > 0 && b == 0 {
				return 0, errors.New("cxcol: non-canonical varint (extra zero byte)")
			}
			return x | (uint64(b) << shift), nil
		}
		x |= uint64(b&0x7F) << shift
		shift += 7
	}
	return 0, errors.New("cxcol: varint exceeds 5 bytes")
}

func (r *dataBinReader) stringPayload() (string, error) {
	n, err := r.uvarint()
	if err != nil {
		return "", err
	}
	bs, err := r.take(int(n))
	if err != nil {
		return "", err
	}
	return string(bs), nil
}

func (r *dataBinReader) value() (any, error) {
	r.depth++
	if r.depth > r.maxDepth {
		return nil, fmt.Errorf("cxcol: recursion depth exceeds limit (%d)", r.maxDepth)
	}
	defer func() { r.depth-- }()

	tag, err := r.u8()
	if err != nil {
		return nil, err
	}
	switch tag {
	case tagNull:
		return nil, nil
	case tagFalse:
		return false, nil
	case tagTrue:
		return true, nil
	case tagInt8:
		bs, err := r.take(1)
		if err != nil {
			return nil, err
		}
		return int64(int8(bs[0])), nil
	case tagInt16:
		bs, err := r.take(2)
		if err != nil {
			return nil, err
		}
		return int64(int16(binary.LittleEndian.Uint16(bs))), nil
	case tagInt32:
		bs, err := r.take(4)
		if err != nil {
			return nil, err
		}
		return int64(int32(binary.LittleEndian.Uint32(bs))), nil
	case tagInt64:
		bs, err := r.take(8)
		if err != nil {
			return nil, err
		}
		return int64(binary.LittleEndian.Uint64(bs)), nil
	case tagBigint:
		// I1 L48: base-10 integer image, same length-prefixed payload
		// shape as string. Narrowing-within-kind: an in-i64 value may
		// still ride 0x18 — the host type is *big.Int either way.
		s, err := r.stringPayload()
		if err != nil {
			return nil, err
		}
		n, ok := new(big.Int).SetString(s, 10)
		if !ok {
			return nil, fmt.Errorf("cxcol: bad bigint image %q (want base-10 integer)", s)
		}
		return n, nil
	case tagDecimal:
		// I1 L48: FIXED-POINT base-10 image; exponent form is not a
		// legal wire image. apd preserves the parsed scale ("1.10" ->
		// coefficient 110, exponent -2; Text('f') yields "1.10").
		s, err := r.stringPayload()
		if err != nil {
			return nil, err
		}
		if strings.ContainsAny(s, "eE") {
			return nil, fmt.Errorf("cxcol: decimal image %q uses exponent form (wire image is fixed-point base-10 only)", s)
		}
		d, _, derr := apd.NewFromString(s)
		if derr != nil {
			return nil, fmt.Errorf("cxcol: bad decimal image %q: %v", s, derr)
		}
		if d.Form != apd.Finite {
			return nil, fmt.Errorf("cxcol: decimal image %q is not a finite fixed-point number", s)
		}
		return d, nil
	case tagFloat64:
		bs, err := r.take(8)
		if err != nil {
			return nil, err
		}
		return math.Float64frombits(binary.LittleEndian.Uint64(bs)), nil
	case tagString:
		return r.stringPayload()
	case tagBytes:
		n, err := r.uvarint()
		if err != nil {
			return nil, err
		}
		bs, err := r.take(int(n))
		if err != nil {
			return nil, err
		}
		out := make([]byte, len(bs))
		copy(out, bs)
		return out, nil
	case tagDate:
		bs, err := r.take(4)
		if err != nil {
			return nil, err
		}
		year := int(int16(binary.LittleEndian.Uint16(bs[:2])))
		return time.Date(year, time.Month(bs[2]), int(bs[3]), 0, 0, 0, 0, time.UTC), nil
	case tagDateTime:
		// data-bin.md §3.6.1 — 12 bytes: i64 unix_nanos LE, i16
		// offset_minutes LE, u16 reserved. #815: the pre-§3.6.1 placeholder
		// form this used to read (10 zero bytes + u16 source-length + RFC3339
		// text) is NOT a legal wire image, and it is not dual-accepted — the
		// cutover IS the fix.
		bs, err := r.take(12)
		if err != nil {
			return nil, err
		}
		ns := int64(binary.LittleEndian.Uint64(bs[0:8]))
		off := int16(binary.LittleEndian.Uint16(bs[8:10]))
		loc := time.UTC
		if off != 0 {
			loc = time.FixedZone("", int(off)*60)
		}
		return time.Unix(ns/1e9, ns%1e9).In(loc), nil
	case tagArray:
		count, err := r.uvarint()
		if err != nil {
			return nil, err
		}
		if count == 0 {
			return nil, errors.New("cxcol: array tag 0x40 with count=0; use 0x41 for empty")
		}
		out := make([]any, 0, count)
		for i := uint64(0); i < count; i++ {
			item, err := r.value()
			if err != nil {
				return nil, err
			}
			out = append(out, item)
		}
		return out, nil
	case tagArrayEmpty:
		return []any{}, nil
	case tagMap:
		count, err := r.uvarint()
		if err != nil {
			return nil, err
		}
		if count == 0 {
			return nil, errors.New("cxcol: map tag 0x50 with count=0; use 0x51 for empty")
		}
		out := make(map[string]any, count)
		for i := uint64(0); i < count; i++ {
			keyTag, err := r.u8()
			if err != nil {
				return nil, err
			}
			if keyTag != tagString {
				return nil, fmt.Errorf("cxcol: map key must be string; got 0x%02x", keyTag)
			}
			key, err := r.stringPayload()
			if err != nil {
				return nil, err
			}
			val, err := r.value()
			if err != nil {
				return nil, err
			}
			out[key] = val
		}
		return out, nil
	case tagMapEmpty:
		return map[string]any{}, nil
	case tagTable, tagTableEmpty:
		return r.tablePayload(tag)
	default:
		return nil, fmt.Errorf("cxcol: unknown tag 0x%02x at offset %d", tag, r.pos-1)
	}
}

func (r *dataBinReader) tablePayload(tag byte) (any, error) {
	if tag == tagTableEmpty {
		return []any{}, nil
	}
	colCount, err := r.uvarint()
	if err != nil {
		return nil, err
	}
	cols := make([]string, colCount)
	codes := make([]byte, colCount)
	for i := uint64(0); i < colCount; i++ {
		keyTag, err := r.u8()
		if err != nil {
			return nil, err
		}
		if keyTag != tagString {
			return nil, fmt.Errorf("cxcol: table column name must be string; got 0x%02x", keyTag)
		}
		name, err := r.stringPayload()
		if err != nil {
			return nil, err
		}
		code, err := r.u8() // §3.10.3 column type code (payload contract)
		if err != nil {
			return nil, err
		}
		if code == 0x82 { // §3.10.1 declared-name annotation (#807(c))
			annTag, err := r.u8()
			if err != nil {
				return nil, err
			}
			if annTag != tagString {
				return nil, fmt.Errorf("cxcol: declared-name annotation must carry a string; got 0x%02x", annTag)
			}
			// The declared spelling is a CX-render concern; this
			// projection surfaces values, so the name is consumed and
			// the payload-driving code follows.
			if _, err := r.stringPayload(); err != nil {
				return nil, err
			}
			code, err = r.u8()
			if err != nil {
				return nil, err
			}
			if code == 0x82 {
				return nil, fmt.Errorf("cxcol: duplicate declared-name annotation in col-spec")
			}
		}
		codes[i] = code
		cols[i] = name
	}
	rowCount, err := r.uvarint()
	if err != nil {
		return nil, err
	}
	rows := make([]any, rowCount)
	for i := uint64(0); i < rowCount; i++ {
		rows[i] = make(map[string]any, colCount)
	}
	for col := uint64(0); col < colCount; col++ {
		cells, err := r.columnPayload(codes[col], int(rowCount))
		if err != nil {
			return nil, err
		}
		for row := uint64(0); row < rowCount; row++ {
			rows[row].(map[string]any)[cols[col]] = cells[row]
		}
	}
	return rows, nil
}

// §3.10.3 typed column payloads (stream 17 W3 — the lattice rise:
// per-column TYPED payloads, no per-cell tags; 0x80 nullable bitmap
// wrapper; 0x81 mixed per-row tagged; 0x01 bit-packed bool).
func (r *dataBinReader) columnPayload(code byte, n int) ([]any, error) {
	switch code {
	case 0x00: // all-null
		out := make([]any, n)
		return out, nil
	case 0x81: // mixed — per-row tagged
		out := make([]any, n)
		for i := 0; i < n; i++ {
			v, err := r.value()
			if err != nil {
				return nil, err
			}
			out[i] = v
		}
		return out, nil
	case 0x80: // nullable wrapper
		inner, err := r.u8()
		if err != nil {
			return nil, err
		}
		bitmap, err := r.take((n + 7) / 8)
		if err != nil {
			return nil, err
		}
		nNonNull := 0
		for i := 0; i < n; i++ {
			if (bitmap[i/8]>>(i%8))&1 == 0 {
				nNonNull++
			}
		}
		nonnull, err := r.typedCells(inner, nNonNull)
		if err != nil {
			return nil, err
		}
		out := make([]any, n)
		vi := 0
		for i := 0; i < n; i++ {
			if (bitmap[i/8]>>(i%8))&1 == 1 {
				out[i] = nil
			} else {
				out[i] = nonnull[vi]
				vi++
			}
		}
		return out, nil
	}
	return r.typedCells(code, n)
}

func (r *dataBinReader) typedCells(code byte, n int) ([]any, error) {
	out := make([]any, 0, n)
	switch code {
	case 0x01: // bool — bit-packed LSB-first (§3.10.4)
		bits, err := r.take((n + 7) / 8)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			out = append(out, (bits[i/8]>>(i%8))&1 == 1)
		}
	case 0x10, 0x14:
		raw, err := r.take(n)
		if err != nil {
			return nil, err
		}
		for _, b := range raw {
			if code == 0x10 {
				out = append(out, int64(int8(b)))
			} else {
				out = append(out, int64(b))
			}
		}
	case 0x11, 0x15:
		raw, err := r.take(2 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			v := binary.LittleEndian.Uint16(raw[2*i:])
			if code == 0x11 {
				out = append(out, int64(int16(v)))
			} else {
				out = append(out, int64(v))
			}
		}
	case 0x12, 0x16:
		raw, err := r.take(4 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			v := binary.LittleEndian.Uint32(raw[4*i:])
			if code == 0x12 {
				out = append(out, int64(int32(v)))
			} else {
				out = append(out, int64(v))
			}
		}
	case 0x13, 0x17:
		raw, err := r.take(8 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			out = append(out, int64(binary.LittleEndian.Uint64(raw[8*i:])))
		}
	case 0x20:
		raw, err := r.take(8 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			out = append(out, math.Float64frombits(binary.LittleEndian.Uint64(raw[8*i:])))
		}
	case 0x21:
		raw, err := r.take(4 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			out = append(out, float64(math.Float32frombits(binary.LittleEndian.Uint32(raw[4*i:]))))
		}
	case 0x22:
		raw, err := r.take(2 * n)
		if err != nil {
			return nil, err
		}
		for i := 0; i < n; i++ {
			out = append(out, f16BitsToF64(binary.LittleEndian.Uint16(raw[2*i:])))
		}
	case 0x18, 0x28, 0x30, 0x33, 0x70: // bigint/decimal/string/bytes/atom — length-prefixed
		for i := 0; i < n; i++ {
			s, err := r.stringPayload()
			if err != nil {
				return nil, err
			}
			out = append(out, s)
		}
	case 0x31: // date — 4 bytes y16/m/d
		for i := 0; i < n; i++ {
			bs, err := r.take(4)
			if err != nil {
				return nil, err
			}
			y := int16(binary.LittleEndian.Uint16(bs[0:2]))
			out = append(out, fmt.Sprintf("%04d-%02d-%02d", y, bs[2], bs[3]))
		}
	case 0x32: // datetime — 12 bytes (ns i64 + offset i16 + reserved)
		for i := 0; i < n; i++ {
			bs, err := r.take(12)
			if err != nil {
				return nil, err
			}
			ns := int64(binary.LittleEndian.Uint64(bs[0:8]))
			// #807(d): offset_minutes rides the transport — render the
			// local form (Z07:00 prints 'Z' at offset 0, ±hh:mm else).
			off := int16(binary.LittleEndian.Uint16(bs[8:10]))
			loc := time.UTC
			if off != 0 {
				loc = time.FixedZone("", int(off)*60)
			}
			out = append(out, time.Unix(ns/1e9, ns%1e9).In(loc).Format("2006-01-02T15:04:05.999999999Z07:00"))
		}
	default:
		return nil, fmt.Errorf("cxcol: unknown column type code 0x%02x", code)
	}
	return out, nil
}

// f16BitsToF64 converts IEEE-754 binary16 bits to float64.
func f16BitsToF64(h uint16) float64 {
	sign := uint32(h&0x8000) << 16
	exp := int32((h >> 10) & 0x1F)
	mant := uint32(h & 0x3FF)
	var bits uint32
	switch {
	case exp == 0 && mant == 0:
		bits = sign
	case exp == 0:
		e := int32(-1)
		m := mant
		for (m & 0x400) == 0 {
			m <<= 1
			e--
		}
		m &= 0x3FF
		bits = sign | uint32(127-15+e+1)<<23 | (m << 13)
	case exp == 31:
		bits = sign | 0x7F800000 | (mant << 13)
	default:
		bits = sign | uint32(exp-15+127)<<23 | (mant << 13)
	}
	return float64(math.Float32frombits(bits))
}

// ── C ABI entry points ───────────────────────────────────────────────────────

// ToDataBin parses CX text and returns CXCol v1 framed bytes.
func ToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// FromDataBin decodes CXCol v1 framed bytes to canonical CX text.
func FromDataBin(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_from_data_bin: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_from_data_bin(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_from_data_bin: unknown error")
	}
	return goStr(out), nil
}

// ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ────
//
// Each loader composes a per-format parser with emit_data_bin (returns
// payload bytes via extractBinPayload, matching ToDataBin's convention).
// Each dumper composes parse_data_bin with a per-format emitter
// (expects framed input — caller must prepend the [u32 LE size] header,
// matching FromDataBin's convention).

// XmlToDataBin parses XML text and returns CXCol v1 payload bytes.
func XmlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_xml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// JsonToDataBin parses JSON text and returns CXCol v1 payload bytes.
func JsonToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_json_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// YamlToDataBin parses YAML text and returns CXCol v1 payload bytes.
func YamlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_yaml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// TomlToDataBin parses TOML text and returns CXCol v1 payload bytes.
func TomlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_toml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// DataBinToXml decodes CXCol v1 framed bytes and emits XML text.
func DataBinToXml(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_xml: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_xml(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_xml: unknown error")
	}
	return goStr(out), nil
}

// DataBinToJson decodes CXCol v1 framed bytes and emits JSON text.
func DataBinToJson(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_json: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_json(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_json: unknown error")
	}
	return goStr(out), nil
}

// DataBinToYaml decodes CXCol v1 framed bytes and emits YAML text.
func DataBinToYaml(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_yaml: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_yaml(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_yaml: unknown error")
	}
	return goStr(out), nil
}

// DataBinToToml decodes CXCol v1 framed bytes and emits TOML text.
func DataBinToToml(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_toml: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_toml(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_toml: unknown error")
	}
	return goStr(out), nil
}
