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

// Streaming Table reader / writer + chunked-table one-shot
// (Phase 7.74b; spec/abi.md §2.10, capability bit 21).
//
// Convention: user-facing API exchanges UNFRAMED CXDB payload bytes
// (matching ToDataBin / extractBinPayload). The C ABI takes / returns
// framed `[u32 LE size][payload]` buffers; this binding handles the
// framing transparently.

// ToDataBinChunked encodes a CX :table-bodied root element to the CXDB
// chunked-table form (`0x63`, spec/data_bin.md §3.11). Default chunk
// policy: 2^20 rows per group with auto-zstd above 64 KiB body size.
// Returns unframed CXDB payload bytes.
func ToDataBinChunked(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_data_bin_chunked(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// frameForC prepends the [u32 LE size] header expected by the C ABI.
func frameForC(payload []byte) []byte {
	out := make([]byte, 4+len(payload))
	binary.LittleEndian.PutUint32(out[:4], uint32(len(payload)))
	copy(out[4:], payload)
	return out
}

// ── TableReader ──────────────────────────────────────────────────────────────

// TableReader is a pull-based iterator over the row groups of a
// chunked-table CXDB buffer or file descriptor. Exactly one of
// (payload, fd) must be supplied; see OpenTableReader / OpenTableReaderFD.
type TableReader struct {
	handle unsafe.Pointer
	closed bool
	// Keep the framed input alive for the reader's lifetime; libcx
	// reads from this buffer lazily for in-memory readers.
	framed []byte
}

// OpenTableReader opens a streaming reader over an unframed CXDB
// chunked-table payload. Caller must Close().
func OpenTableReader(payload []byte) (*TableReader, error) {
	if len(payload) == 0 {
		return nil, errors.New("OpenTableReader: empty input")
	}
	framed := frameForC(payload)
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_table_reader_open(
		(*C.char)(unsafe.Pointer(&framed[0])), &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cx_table_reader_open: unknown error")
	}
	return &TableReader{handle: h, framed: framed}, nil
}

// OpenTableReaderFD opens a streaming reader over a file descriptor
// positioned at the CXDB magic (no framing prefix). The caller retains
// ownership of fd and must close it after the reader is closed.
func OpenTableReaderFD(fd int) (*TableReader, error) {
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_table_reader_open_fd(C.int(fd), &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cx_table_reader_open_fd: unknown error")
	}
	return &TableReader{handle: h}, nil
}

// Schema returns the table's col-spec as unframed ast_bin payload bytes.
func (r *TableReader) Schema() ([]byte, error) {
	if r.closed || r.handle == nil {
		return nil, errors.New("TableReader: handle closed")
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_table_reader_schema(C.cx_table_reader_handle(r.handle), &errPtr))
	return extractBinPayload(raw, errPtr)
}

// Next returns the next row group as unframed `[uvarint(row_count)
// + col-payload[col_count]]` plain-body bytes (per spec/data_bin.md
// §3.11.2). Returns (nil, false, nil) on end-of-table.
func (r *TableReader) Next() ([]byte, bool, error) {
	if r.closed || r.handle == nil {
		return nil, false, nil
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_table_reader_next(C.cx_table_reader_handle(r.handle), &errPtr))
	if raw == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			r.Close()
			return nil, false, fmt.Errorf("%s", msg)
		}
		return nil, false, nil
	}
	sizeBytes := (*[4]byte)(raw)[:]
	size := binary.LittleEndian.Uint32(sizeBytes)
	payload := make([]byte, size)
	if size > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(uintptr(raw)+4)), size)
		copy(payload, src)
	}
	C.cx_free((*C.char)(raw))
	return payload, true, nil
}

// Close releases the underlying handle. Idempotent.
func (r *TableReader) Close() {
	if r.closed || r.handle == nil {
		r.closed = true
		r.handle = nil
		r.framed = nil
		return
	}
	C.cx_table_reader_close(C.cx_table_reader_handle(r.handle))
	r.closed = true
	r.handle = nil
	r.framed = nil
}

// ── TableWriter ──────────────────────────────────────────────────────────────

// TableWriter pushes row groups into a chunked-table CXDB buffer
// (in-memory) or file descriptor. One of OpenTableWriter /
// OpenTableWriterFD opens the writer.
type TableWriter struct {
	handle unsafe.Pointer
	closed bool
	fd     bool
	// Pin the col-spec frame for the C-side reference.
	colSpec []byte
}

// OpenTableWriter opens an in-memory writer with the given col-spec
// payload (unframed ast_bin from TableReader.Schema).
func OpenTableWriter(colSpecPayload []byte) (*TableWriter, error) {
	if len(colSpecPayload) == 0 {
		return nil, errors.New("OpenTableWriter: empty col-spec")
	}
	framed := frameForC(colSpecPayload)
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_table_writer_open(
		(*C.char)(unsafe.Pointer(&framed[0])), &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cx_table_writer_open: unknown error")
	}
	return &TableWriter{handle: h, colSpec: framed}, nil
}

// OpenTableWriterFD opens an fd-streaming writer. Caller retains
// ownership of fd and must close it after Close().
func OpenTableWriterFD(colSpecPayload []byte, fd int) (*TableWriter, error) {
	if len(colSpecPayload) == 0 {
		return nil, errors.New("OpenTableWriterFD: empty col-spec")
	}
	framed := frameForC(colSpecPayload)
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_table_writer_open_fd(
		(*C.char)(unsafe.Pointer(&framed[0])), C.int(fd), &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cx_table_writer_open_fd: unknown error")
	}
	return &TableWriter{handle: h, fd: true, colSpec: framed}, nil
}

// Emit appends one row group. `rowGroupPayload` is the unframed
// plain-body form (uvarint(row_count) + col-payload[col_count]).
func (w *TableWriter) Emit(rowGroupPayload []byte) error {
	if w.closed || w.handle == nil {
		return errors.New("TableWriter: handle closed")
	}
	framed := frameForC(rowGroupPayload)
	var errPtr *C.char
	C.cx_table_writer_emit_row_group(C.cx_table_writer_handle(w.handle),
		(*C.char)(unsafe.Pointer(&framed[0])), &errPtr)
	if errPtr != nil {
		msg := C.GoString(errPtr)
		C.cx_free(errPtr)
		return fmt.Errorf("%s", msg)
	}
	return nil
}

// CloseGetBytes (in-memory writers only) emits the end-of-table marker
// and returns the unframed CXDB chunked-table payload bytes.
func (w *TableWriter) CloseGetBytes() ([]byte, error) {
	if w.fd {
		return nil, errors.New("CloseGetBytes is for in-memory writers; use Close() for fd writers")
	}
	if w.closed || w.handle == nil {
		return nil, errors.New("TableWriter: handle closed")
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_table_writer_close_get_bytes(C.cx_table_writer_handle(w.handle), &errPtr))
	// V-core releases the handle inside close_get_bytes; mark closed.
	w.handle = nil
	w.closed = true
	w.colSpec = nil
	return extractBinPayload(raw, errPtr)
}

// Close releases the handle. For fd writers, flushes the end-of-table
// marker. Idempotent.
func (w *TableWriter) Close() {
	if w.closed || w.handle == nil {
		w.closed = true
		w.handle = nil
		w.colSpec = nil
		return
	}
	C.cx_table_writer_close(C.cx_table_writer_handle(w.handle))
	w.closed = true
	w.handle = nil
	w.colSpec = nil
}
