package cxlib

/*
#include "cx.h"
#include <stdlib.h>
*/
import "C"
import (
	"errors"
	"fmt"
	"unsafe"
)

// Delimited (CSV/TSV/PSV/arbitrary) C ABI bindings per
// spec/conversions.md §8.
// Phase 7.68 — wraps the V core delimited engine that landed in Phase 7.67.

// ToDelimited encodes CX text to delimited text using delim as the
// field separator. Per, delim must be any single byte
// except '\r' '\n' '"' '\” '\\'.
func ToDelimited(input string, delim byte) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	out := C.cx_to_delimited(cs, C.char(delim), &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_to_delimited: unknown error")
	}
	return goStr(out), nil
}

// FromDelimited decodes delimited text to canonical CX. Auto-typing
// applies; quoted cells stay :string.
func FromDelimited(input string, delim byte) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	out := C.cx_from_delimited(cs, C.char(delim), &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_from_delimited: unknown error")
	}
	return goStr(out), nil
}

// ToCsv encodes CX text to CSV (RFC 4180 default).
func ToCsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_to_csv(s, e) }, input)
}

// FromCsv decodes CSV text to canonical CX.
func FromCsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_from_csv(s, e) }, input)
}

// ToTsv encodes CX text to TSV (tab-separated).
func ToTsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_to_tsv(s, e) }, input)
}

// FromTsv decodes TSV text to canonical CX.
func FromTsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_from_tsv(s, e) }, input)
}

// ToPsv encodes CX text to PSV (pipe-separated).
func ToPsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_to_psv(s, e) }, input)
}

// FromPsv decodes PSV text to canonical CX.
func FromPsv(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_from_psv(s, e) }, input)
}

// CsvToDataBin parses CSV text and returns CXCol v1 payload bytes
// (unframed, matching ToDataBin's convention).
func CsvToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_csv_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// TsvToDataBin parses TSV text and returns CXCol v1 payload bytes.
func TsvToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_tsv_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// PsvToDataBin parses PSV text and returns CXCol v1 payload bytes.
func PsvToDataBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_psv_to_data_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// DataBinToCsv decodes CXCol v1 framed bytes and emits CSV text.
func DataBinToCsv(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_csv: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_csv(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_csv: unknown error")
	}
	return goStr(out), nil
}

// DataBinToTsv decodes CXCol v1 framed bytes and emits TSV text.
func DataBinToTsv(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_tsv: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_tsv(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_tsv: unknown error")
	}
	return goStr(out), nil
}

// DataBinToPsv decodes CXCol v1 framed bytes and emits PSV text.
func DataBinToPsv(framed []byte) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("cx_data_bin_to_psv: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	var errPtr *C.char
	out := C.cx_data_bin_to_psv(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_data_bin_to_psv: unknown error")
	}
	return goStr(out), nil
}
