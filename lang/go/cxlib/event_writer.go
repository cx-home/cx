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
	"unsafe"
)

// EventWriter is a streaming CX event writer (spec/streaming.md §6 /
// spec/abi.md §2.15). It accepts the 14 stream events and
// emits format-targeted output (cx / xml / json / yaml / toml / md).
// In v0.6.0 CX and XML output are implemented end-to-end; the other
// formats return a W009 error until their follow-up phases land.
//
// Usage (in-memory):
//
//	w, err := cxlib.NewEventWriter("cx")
//	if err != nil { panic(err) }
//	defer w.Close()
//	w.StartDoc()
//	w.StartElement("greet", nil)
//	w.Text("hello")
//	w.EndElement("greet")
//	w.EndDoc()
//	out, err := w.CloseGetBytes()  // bytes; consumes the handle
//
// Errors carry the W001-W013 prefix verbatim. The writer fails closed:
// after the first W-code, subsequent emits return the same diagnostic
// without effect.
type EventWriter struct {
	handle unsafe.Pointer
	closed bool
	fd     bool
	format string
}

// streamingWriteCapBit is bit 27 — set by libcx v0.6.0+ when the
// streaming-write API is available.
const streamingWriteCapBit = uint64(1) << 27

func hasStreamingWriteCapability() bool {
	feat, err := FeaturesU64()
	if err != nil {
		return false
	}
	return feat&streamingWriteCapBit != 0
}

// FeaturesU64 parses cx_features() into a uint64 bitmask.
func FeaturesU64() (uint64, error) {
	cstr := C.cx_features()
	if cstr == nil {
		return 0, errors.New("cx_features returned NULL")
	}
	s := C.GoString(cstr)
	var feat uint64
	if _, err := fmt.Sscanf(s, "0x%x", &feat); err != nil {
		return 0, fmt.Errorf("cx_features: bad hex %q: %v", s, err)
	}
	return feat, nil
}

// Features returns the libcx capability bitmask as a uint64. Matches
// the Python `cxlib.features()` and Rust `cxlib::features()` surface;
// returns 0 if cx_features() is unavailable or malformed (the error
// case is rare and a zero bitmask cleanly disables all capability gates).
// For explicit error handling use FeaturesU64.
func Features() uint64 {
	feat, _ := FeaturesU64()
	return feat
}

// NewEventWriter opens an in-memory event writer for the given output
// format. Caller must Close() (or drain via CloseGetBytes).
func NewEventWriter(outputFormat string) (*EventWriter, error) {
	if !hasStreamingWriteCapability() {
		return nil, errors.New("cxlib.NewEventWriter requires libcx capability bit 27 (streaming-write); not advertised")
	}
	cfmt := C.CString(outputFormat)
	defer C.free(unsafe.Pointer(cfmt))
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_events_writer_open(cfmt, &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, fmt.Errorf("cx_events_writer_open(%q): unknown error", outputFormat)
	}
	return &EventWriter{handle: h, format: outputFormat}, nil
}

// NewEventWriterFD opens an fd-streaming writer. Caller retains
// ownership of fd and must close it after the writer is closed.
func NewEventWriterFD(outputFormat string, fd int) (*EventWriter, error) {
	if !hasStreamingWriteCapability() {
		return nil, errors.New("cxlib.NewEventWriterFD requires libcx capability bit 27 (streaming-write); not advertised")
	}
	cfmt := C.CString(outputFormat)
	defer C.free(unsafe.Pointer(cfmt))
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_events_writer_open_fd(cfmt, C.int(fd), &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, fmt.Errorf("cx_events_writer_open_fd(%q): unknown error", outputFormat)
	}
	return &EventWriter{handle: h, fd: true, format: outputFormat}, nil
}

// Close releases the writer handle without finalising bytes. Idempotent.
// For fd writers, output is already flushed at each emit call.
func (w *EventWriter) Close() {
	if w.closed || w.handle == nil {
		w.closed = true
		w.handle = nil
		return
	}
	C.cx_events_writer_close(C.cx_events_writer_handle(w.handle))
	w.closed = true
	w.handle = nil
}

// CloseGetBytes finalises the writer and returns the accumulated output.
// For fd writers the returned slice is empty (output already flushed).
// Implicitly emits EndDoc — returns a W004 error if elements / table
// remain open. Consumes the writer; subsequent calls error.
func (w *EventWriter) CloseGetBytes() ([]byte, error) {
	if w.closed || w.handle == nil {
		return nil, errors.New("EventWriter: already closed")
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_events_writer_close_get_bytes(C.cx_events_writer_handle(w.handle), &errPtr))
	old := C.cx_events_writer_handle(w.handle)
	w.handle = nil
	w.closed = true
	if raw == nil {
		// Release V-side resources on error path.
		C.cx_events_writer_close(old)
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cx_events_writer_close_get_bytes: unknown error")
	}
	// Framed [u32 LE size][payload]; unwrap.
	sizeBytes := (*[4]byte)(raw)[:]
	size := binary.LittleEndian.Uint32(sizeBytes)
	payload := make([]byte, size)
	if size > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(uintptr(raw)+4)), size)
		copy(payload, src)
	}
	C.cx_free((*C.char)(raw))
	// Idempotent release of the V-side handle.
	C.cx_events_writer_close(old)
	return payload, nil
}

// ── emit helpers ────────────────────────────────────────────────────────────

func diagFromRet(ret *C.char, errPtr *C.char) error {
	if ret != nil {
		msg := C.GoString(ret)
		C.cx_free(ret)
		if errPtr != nil {
			C.cx_free(errPtr)
		}
		return fmt.Errorf("%s", msg)
	}
	if errPtr != nil {
		msg := C.GoString(errPtr)
		C.cx_free(errPtr)
		return fmt.Errorf("%s", msg)
	}
	return nil
}

// optCString returns a *C.char allocated for `s` plus a free-fn pinned
// to the caller's defer scope. When `p == nil` is desired (nullable
// strings), pass an empty pointer instead — we use NULL for empty
// optional fields to match the V parser's "optstr none" semantics.
func optCString(s *string) (*C.char, func()) {
	if s == nil {
		return nil, func() {}
	}
	c := C.CString(*s)
	return c, func() { C.free(unsafe.Pointer(c)) }
}

func (w *EventWriter) liveHandle() (C.cx_events_writer_handle, error) {
	if w.closed || w.handle == nil {
		return nil, errors.New("EventWriter: handle closed")
	}
	return C.cx_events_writer_handle(w.handle), nil
}

// ── lifecycle emits ─────────────────────────────────────────────────────────

func (w *EventWriter) StartDoc() error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	var errPtr *C.char
	ret := C.cx_events_writer_start_doc(h, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) EndDoc() error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	var errPtr *C.char
	ret := C.cx_events_writer_end_doc(h, &errPtr)
	return diagFromRet(ret, errPtr)
}

// EventAttr is one start-element attribute. Value is rendered as a
// string; DataType selects the wire type tag (int/float/bool/null/
// string/etc.). Empty DataType → "string". Named EventAttr (not Attr)
// to avoid collision with the AST-layer Attr type.
type EventAttr struct {
	Name     string
	Value    string
	DataType string
}

func encodeAttrsPayload(attrs []EventAttr) []byte {
	if len(attrs) == 0 {
		return nil
	}
	out := make([]byte, 0, 2+len(attrs)*16)
	var hdr [2]byte
	binary.LittleEndian.PutUint16(hdr[:], uint16(len(attrs)))
	out = append(out, hdr[:]...)
	encLP := func(s string) {
		var sz [4]byte
		binary.LittleEndian.PutUint32(sz[:], uint32(len(s)))
		out = append(out, sz[:]...)
		out = append(out, s...)
	}
	for _, a := range attrs {
		typ := a.DataType
		if typ == "" {
			typ = "string"
		}
		encLP(a.Name)
		encLP(a.Value)
		encLP(typ)
		out = append(out, 0) // is_ref
	}
	return out
}

// StartElement emits a StartElement event. `attrs` may be nil. Optional
// anchor/dataType/merge are passed via pointer; pass nil for absent.
func (w *EventWriter) StartElement(name string, attrs []EventAttr) error {
	return w.StartElementOpts(name, nil, nil, nil, attrs)
}

func (w *EventWriter) StartElementOpts(name string, anchor, dataType, merge *string, attrs []EventAttr) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cn := C.CString(name)
	defer C.free(unsafe.Pointer(cn))
	ca, freeA := optCString(anchor)
	defer freeA()
	cd, freeD := optCString(dataType)
	defer freeD()
	cm, freeM := optCString(merge)
	defer freeM()

	raw := encodeAttrsPayload(attrs)
	var attrsPtr *C.char
	var attrsLen C.size_t
	if raw != nil {
		framed := frameForC(raw)
		attrsPtr = (*C.char)(unsafe.Pointer(&framed[0]))
		attrsLen = C.size_t(len(framed))
		// Pin framed for the duration of the C call via the closure.
		defer func() { _ = framed }()
	}
	var errPtr *C.char
	ret := C.cx_events_writer_start_element_with_len(h, cn, ca, cd, cm, attrsPtr, attrsLen, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) EndElement(name string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cn := C.CString(name)
	defer C.free(unsafe.Pointer(cn))
	var errPtr *C.char
	ret := C.cx_events_writer_end_element(h, cn, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) Text(value string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cv := C.CString(value)
	defer C.free(unsafe.Pointer(cv))
	var errPtr *C.char
	ret := C.cx_events_writer_text(h, cv, &errPtr)
	return diagFromRet(ret, errPtr)
}

// Scalar emits a typed scalar. Pass dataType="" for an inferred string.
func (w *EventWriter) Scalar(value, dataType string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cv := C.CString(value)
	defer C.free(unsafe.Pointer(cv))
	var cdt *C.char
	if dataType != "" {
		cdt = C.CString(dataType)
		defer C.free(unsafe.Pointer(cdt))
	}
	var errPtr *C.char
	ret := C.cx_events_writer_scalar(h, cdt, cv, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) Comment(value string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cv := C.CString(value)
	defer C.free(unsafe.Pointer(cv))
	var errPtr *C.char
	ret := C.cx_events_writer_comment(h, cv, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) PI(target, data string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	ct := C.CString(target)
	defer C.free(unsafe.Pointer(ct))
	var cd *C.char
	if data != "" {
		cd = C.CString(data)
		defer C.free(unsafe.Pointer(cd))
	}
	var errPtr *C.char
	ret := C.cx_events_writer_pi(h, ct, cd, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) EntityRef(name string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cn := C.CString(name)
	defer C.free(unsafe.Pointer(cn))
	var errPtr *C.char
	ret := C.cx_events_writer_entity_ref(h, cn, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) RawText(value string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cv := C.CString(value)
	defer C.free(unsafe.Pointer(cv))
	var errPtr *C.char
	ret := C.cx_events_writer_raw_text(h, cv, &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) Alias(name string) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	cn := C.CString(name)
	defer C.free(unsafe.Pointer(cn))
	var errPtr *C.char
	ret := C.cx_events_writer_alias(h, cn, &errPtr)
	return diagFromRet(ret, errPtr)
}

// StartTable opens a chunked table. `colSpecPayload` is the unframed
// column-spec wire form per spec/core/data-bin.md §3.10.1:
//
//	[u32 LE count] ([u32 LE name_len] name [u8 type_code])*
func (w *EventWriter) StartTable(colSpecPayload []byte) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	framed := frameForC(colSpecPayload)
	var errPtr *C.char
	ret := C.cx_events_writer_start_table_with_len(h,
		(*C.char)(unsafe.Pointer(&framed[0])), C.size_t(len(framed)), &errPtr)
	return diagFromRet(ret, errPtr)
}

// RowGroup appends a row group. `payload` is the unframed §3.11.2 plain
// body: `uvarint(row_count) + col-payload[col_count]`.
func (w *EventWriter) RowGroup(payload []byte) error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	framed := frameForC(payload)
	var errPtr *C.char
	ret := C.cx_events_writer_row_group_with_len(h,
		(*C.char)(unsafe.Pointer(&framed[0])), C.size_t(len(framed)), &errPtr)
	return diagFromRet(ret, errPtr)
}

func (w *EventWriter) EndTable() error {
	h, e := w.liveHandle()
	if e != nil {
		return e
	}
	var errPtr *C.char
	ret := C.cx_events_writer_end_table(h, &errPtr)
	return diagFromRet(ret, errPtr)
}
