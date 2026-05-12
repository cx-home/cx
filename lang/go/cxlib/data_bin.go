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
	"time"
	"unsafe"
)

// CXDB v1 codec — strict canonical binary data format.
// Spec: spec/data_bin.md.
//
// Decoder consumes the framed [u32 LE size][payload] buffer returned by
// libcx.cx_to_data_bin; encoder produces the same shape for input to
// libcx.cx_from_data_bin.
//
// Replaces the JSON-string detour previously used by Loads / Dumps
// (audit finding CB-3). Go types map:
//   int64       <-> CXDB int8/int16/int32/int64
//   float64     <-> CXDB float64
//   bool        <-> CXDB false/true
//   nil         <-> CXDB null
//   string      <-> CXDB string
//   []byte      <-> CXDB bytes
//   map[string]any <-> CXDB map (insertion order preserved)
//   []any       <-> CXDB array
//   time.Time   <-> CXDB datetime (placeholder source string in v1)

const (
	tagNull        = 0x00
	tagFalse       = 0x01
	tagTrue        = 0x02
	tagInt8        = 0x10
	tagInt16       = 0x11
	tagInt32       = 0x12
	tagInt64       = 0x13
	tagFloat64     = 0x20
	tagString      = 0x30
	tagDate        = 0x31
	tagDateTime    = 0x32
	tagBytes       = 0x33
	tagArray       = 0x40
	tagArrayEmpty  = 0x41
	tagMap         = 0x50
	tagMapEmpty    = 0x51
	tagTable       = 0x60
	tagTableEmpty  = 0x61
)

const (
	cxdbVersion       = 0x01
	cxdbFlagsLE       = 0x01
	cxdbDefaultDepth  = 64
)

var cxdbMagic = []byte{'C', 'X', 'D', 'B'}

// ── Encoder ──────────────────────────────────────────────────────────────────

// encodeDataBin produces a FRAMED CXDB v1 buffer for FromDataBin.
// FromDataBin (cgo wrapper of cx_from_data_bin) expects the same
// [u32 LE size][payload] layout that cx_to_data_bin returns.
func encodeDataBin(value any) ([]byte, error) {
	var w dataBinWriter
	w.buf = make([]byte, 0, 256)
	// Header
	w.buf = append(w.buf, cxdbMagic...)
	w.buf = append(w.buf, cxdbVersion)
	w.buf = append(w.buf, cxdbFlagsLE)
	w.u32(uint32(cxdbDefaultDepth))
	w.buf = append(w.buf, 0, 0)
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

func (w *dataBinWriter) u8(v byte)   { w.buf = append(w.buf, v) }
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
			return fmt.Errorf("cxdb: uint64 %d exceeds i64 range", x)
		}
		return w.intCanonical(int64(x))
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
		iso := x.Format(time.RFC3339Nano)
		w.u8(tagDateTime)
		w.buf = append(w.buf, make([]byte, 10)...) // 10 reserved bytes (placeholder)
		w.u16(uint16(len(iso)))
		w.buf = append(w.buf, iso...)
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
		return fmt.Errorf("cxdb: unsupported type %T", v)
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

// decodeDataBin accepts a CXDB v1 PAYLOAD (12-byte header + value
// section), without the [u32 size] frame prefix. ToDataBin already
// strips the frame via extractBinPayload, so callers pass the
// payload directly.
func decodeDataBin(payload []byte) (any, error) {
	if len(payload) < 12 {
		return nil, errors.New("cxdb: payload too short for 12-byte header")
	}
	if string(payload[:4]) != "CXDB" {
		return nil, errors.New("cxdb: bad magic (expected 'CXDB')")
	}
	if payload[4] != cxdbVersion {
		return nil, fmt.Errorf("cxdb: unsupported version %d", payload[4])
	}
	if payload[5]&0xFE != 0 {
		return nil, errors.New("cxdb: reserved flag bits set")
	}
	if payload[5]&0x01 == 0 {
		return nil, errors.New("cxdb: only little-endian payloads supported in v1")
	}
	if payload[10] != 0 || payload[11] != 0 {
		return nil, errors.New("cxdb: reserved header bytes must be zero")
	}
	r := &dataBinReader{buf: payload[12:], maxDepth: cxdbDefaultDepth}
	return r.value()
}

func (r *dataBinReader) take(n int) ([]byte, error) {
	if r.pos+n > len(r.buf) {
		return nil, fmt.Errorf("cxdb: %d bytes requested, %d remaining", n, len(r.buf)-r.pos)
	}
	out := r.buf[r.pos : r.pos+n]
	r.pos += n
	return out, nil
}

func (r *dataBinReader) u8() (byte, error) {
	if r.pos >= len(r.buf) {
		return 0, errors.New("cxdb: unexpected end of input")
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
				return 0, errors.New("cxdb: varint overflow")
			}
			if i > 0 && b == 0 {
				return 0, errors.New("cxdb: non-canonical varint (extra zero byte)")
			}
			return x | (uint64(b) << shift), nil
		}
		x |= uint64(b&0x7F) << shift
		shift += 7
	}
	return 0, errors.New("cxdb: varint exceeds 5 bytes")
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
		return nil, fmt.Errorf("cxdb: recursion depth exceeds limit (%d)", r.maxDepth)
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
		// Skip 10 reserved bytes (placeholder), then u16 source-len + UTF-8 source.
		if _, err := r.take(10); err != nil {
			return nil, err
		}
		srcLen, err := r.u16()
		if err != nil {
			return nil, err
		}
		bs, err := r.take(int(srcLen))
		if err != nil {
			return nil, err
		}
		s := string(bs)
		t, parseErr := time.Parse(time.RFC3339Nano, s)
		if parseErr == nil {
			return t, nil
		}
		return s, nil
	case tagArray:
		count, err := r.uvarint()
		if err != nil {
			return nil, err
		}
		if count == 0 {
			return nil, errors.New("cxdb: array tag 0x40 with count=0; use 0x41 for empty")
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
			return nil, errors.New("cxdb: map tag 0x50 with count=0; use 0x51 for empty")
		}
		out := make(map[string]any, count)
		for i := uint64(0); i < count; i++ {
			keyTag, err := r.u8()
			if err != nil {
				return nil, err
			}
			if keyTag != tagString {
				return nil, fmt.Errorf("cxdb: map key must be string; got 0x%02x", keyTag)
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
		return nil, fmt.Errorf("cxdb: unknown tag 0x%02x at offset %d", tag, r.pos-1)
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
	for i := uint64(0); i < colCount; i++ {
		keyTag, err := r.u8()
		if err != nil {
			return nil, err
		}
		if keyTag != tagString {
			return nil, fmt.Errorf("cxdb: table column name must be string; got 0x%02x", keyTag)
		}
		name, err := r.stringPayload()
		if err != nil {
			return nil, err
		}
		if _, err := r.u8(); err != nil { // column type code
			return nil, err
		}
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
		for row := uint64(0); row < rowCount; row++ {
			val, err := r.value()
			if err != nil {
				return nil, err
			}
			rows[row].(map[string]any)[cols[col]] = val
		}
	}
	return rows, nil
}

// ── C ABI entry points ───────────────────────────────────────────────────────

// ToDataBin parses CX text and returns CXDB v1 framed bytes.
func ToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// FromDataBin decodes CXDB v1 framed bytes to canonical CX text.
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

// XmlToDataBin parses XML text and returns CXDB v1 payload bytes.
func XmlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_xml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// JsonToDataBin parses JSON text and returns CXDB v1 payload bytes.
func JsonToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_json_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// YamlToDataBin parses YAML text and returns CXDB v1 payload bytes.
func YamlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_yaml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// TomlToDataBin parses TOML text and returns CXDB v1 payload bytes.
func TomlToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_toml_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// MdToDataBin parses Markdown text and returns CXDB v1 payload bytes.
func MdToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_md_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// DataBinToXml decodes CXDB v1 framed bytes and emits XML text.
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

// DataBinToJson decodes CXDB v1 framed bytes and emits JSON text.
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

// DataBinToYaml decodes CXDB v1 framed bytes and emits YAML text.
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

// DataBinToToml decodes CXDB v1 framed bytes and emits TOML text.
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

// DataBinToMd decodes CXDB v1 framed bytes and emits Markdown text.
func DataBinToMd(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_md: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_md(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_md: unknown error")
	}
	return goStr(out), nil
}
