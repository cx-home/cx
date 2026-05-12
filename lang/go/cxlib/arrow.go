//go:build arrow

// Apache Arrow C-Data interop for cxlib (Phase 7.74c-cont-bindings-multi-go).
//
// Bridges CXDB chunked-tables to Arrow ArrowArrayStream via libcx_arrow
// (spec/abi.md §2.11, ADR 0015 D9, capability bit 0x800000). The bridge
// handles all 9 v0.6.0 column types (int, i8, i16, i32, float, bool,
// string, date, bytes); datetime / decimal / dictionary columns are
// deferred and surface the V core's deferred-type error.
//
// Gated behind the `arrow` build tag so the default `go build` does not
// require libcx_arrow or the Apache Arrow Go module:
//
//	go build -tags arrow ./...
//	go test  -tags arrow ./...
//
// Mirrors Python's `pip install cxlib[arrow]` opt-in pattern.
package cxlib

/*
#cgo CFLAGS:  -I${SRCDIR}/../../../include -I/usr/local/include -I/opt/homebrew/include
#cgo darwin LDFLAGS: -lcx_arrow -L${SRCDIR}/../../../vcx/target -L${SRCDIR}/../../../dist/lib -L/usr/local/lib -L/opt/homebrew/lib -Wl,-rpath,${SRCDIR}/../../../vcx/target -Wl,-rpath,/usr/local/lib -Wl,-rpath,/opt/homebrew/lib
#cgo linux  LDFLAGS: -lcx_arrow -L${SRCDIR}/../../../vcx/target -L${SRCDIR}/../../../dist/lib -L/usr/local/lib                     -Wl,-rpath,${SRCDIR}/../../../vcx/target -Wl,-rpath,/usr/local/lib

#include "cx.h"
#include <stdlib.h>

extern char* cx_arrow_export_open(const char* data_bin, void* arrow_array_stream_out, char** err_out);
extern char* cx_arrow_import_to_data_bin(void* arrow_array_stream_in, char** err_out);
extern char* cx_arrow_features(void);
extern char* cx_arrow_version(void);
extern void  cx_arrow_free(void* p);
*/
import "C"

import (
	"encoding/binary"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"unsafe"

	"github.com/apache/arrow/go/v18/arrow/array"
	"github.com/apache/arrow/go/v18/arrow/cdata"
)

// parseHexBitmask accepts the libcx convention of optional `0x` prefix.
func parseHexBitmask(s string) uint64 {
	s = strings.TrimPrefix(strings.TrimPrefix(s, "0x"), "0X")
	v, err := strconv.ParseUint(s, 16, 64)
	if err != nil {
		return 0
	}
	return v
}

// ArrowAvailable reports whether the Arrow bridge is compiled in.
// In the Go binding the surface is gated by the `arrow` build tag —
// when this file is part of the build, libcx_arrow MUST be linkable
// or the binary fails to load. There is no graceful runtime fallback;
// build without `-tags arrow` to skip Arrow.
func ArrowAvailable() bool { return true }

// ArrowFeatures returns the libcx_arrow capability bitmask. Currently
// always 0x800000 (bit 23) when libcx_arrow loads.
func ArrowFeatures() uint64 {
	cs := C.cx_arrow_features()
	if cs == nil {
		return 0
	}
	return parseHexBitmask(C.GoString(cs))
}

// ArrowVersion returns the libcx_arrow build version string.
func ArrowVersion() string {
	cs := C.cx_arrow_version()
	if cs == nil {
		return ""
	}
	return C.GoString(cs)
}

// ArrowMergedFeatures returns the bitwise OR of libcx and libcx_arrow
// feature bitmasks. Mirrors Python's cxlib.arrow.merged_features().
func ArrowMergedFeatures() uint64 {
	var base uint64
	cs := C.cx_features()
	if cs != nil {
		base = parseHexBitmask(C.GoString(cs))
		C.cx_free(cs)
	}
	return base | ArrowFeatures()
}

// ArrowExport decodes UNFRAMED CXDB chunked-table bytes as an Arrow
// RecordReader. libcx populates the caller-allocated ArrowArrayStream;
// ownership of the stream callbacks moves into the returned reader,
// which releases them on Release / drop.
//
// Memory: cxlib copies the input into a stream-owned buffer; the caller
// may release `payload` immediately. The returned reader owns the
// underlying ArrowArrayStream.
func ArrowExport(payload []byte) (array.RecordReader, error) {
	if len(payload) == 0 {
		return nil, errors.New("cxlib: ArrowExport: empty input")
	}
	framed := frameForC(payload)
	var stream cdata.CArrowArrayStream
	var errPtr *C.char
	C.cx_arrow_export_open(
		(*C.char)(unsafe.Pointer(&framed[0])),
		unsafe.Pointer(&stream),
		&errPtr,
	)
	if errPtr != nil {
		msg := C.GoString(errPtr)
		C.cx_free(errPtr)
		return nil, fmt.Errorf("%s", msg)
	}
	rdr, err := cdata.ImportCRecordReader(&stream, nil)
	if err != nil {
		return nil, fmt.Errorf("cxlib: ArrowExport: ImportCRecordReader: %w", err)
	}
	// nativeCRecordBatchReader satisfies array.RecordReader (Next / Record /
	// Err / Schema / Retain / Release) in addition to the arrio.Reader the
	// public signature advertises.
	out, ok := rdr.(array.RecordReader)
	if !ok {
		return nil, fmt.Errorf(
			"cxlib: ArrowExport: imported reader does not satisfy array.RecordReader (got %T)",
			rdr)
	}
	return out, nil
}

// ArrowImportToDataBin drains an Arrow RecordReader into UNFRAMED CXDB
// chunked-table bytes. The reader is consumed; on success its callbacks
// are released by libcx via the moved ArrowArrayStream.
func ArrowImportToDataBin(reader array.RecordReader) ([]byte, error) {
	if reader == nil {
		return nil, errors.New("cxlib: ArrowImportToDataBin: nil reader")
	}
	var stream cdata.CArrowArrayStream
	cdata.ExportRecordReader(reader, &stream)
	var errPtr *C.char
	addr := unsafe.Pointer(C.cx_arrow_import_to_data_bin(
		unsafe.Pointer(&stream), &errPtr))
	if addr == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, errors.New("cxlib: ArrowImportToDataBin: unknown error")
	}
	sizeBytes := (*[4]byte)(addr)[:]
	size := binary.LittleEndian.Uint32(sizeBytes)
	out := make([]byte, size)
	if size > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(uintptr(addr)+4)), size)
		copy(out, src)
	}
	C.cx_arrow_free(addr)
	return out, nil
}
