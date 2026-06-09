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

// Schema-driven CXCol encoding (Phase 7.73 / 7.74b; spec/abi.md §2.12,
// capability bit 24). Loaders take (input, schema, refForm, nameHint)
// and return unframed CXCol payload bytes; the dumper takes a framed
// CXCol buffer + optional schema hint and returns canonical CX text.
//
// refForm: 0 = content-hash only (default; spec/core/data-bin.md §3.13.1
// tag 0x10), 1 = inline schema bytes (tag 0x11), 2 = content-hash +
// name hint (tag 0x12).

func ToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func XmlToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_xml_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func JsonToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_json_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func YamlToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_yaml_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func TomlToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_toml_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func CsvToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_csv_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func TsvToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_tsv_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}
func PsvToDataBinSchemaDriven(input, schema string, refForm int, nameHint string) ([]byte, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cSchema := C.CString(schema)
	defer C.free(unsafe.Pointer(cSchema))
	cHint := C.CString(nameHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_psv_to_data_bin_schema_driven(cInput, cSchema, C.int(refForm), cHint, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// FromDataBinSchemaDriven decodes a framed CXCol schema-driven buffer to
// canonical CX text. `schemaHint` is consulted only when the embedded
// schema reference is content-hash-only and not resolvable from the
// consumer's content-addressable store; pass "" to use embedded
// resolution.
func FromDataBinSchemaDriven(framed []byte, schemaHint string) (string, error) {
	if len(framed) == 0 {
		return "", errors.New("FromDataBinSchemaDriven: empty input")
	}
	cs := (*C.char)(unsafe.Pointer(&framed[0]))
	cHint := C.CString(schemaHint)
	defer C.free(unsafe.Pointer(cHint))
	var errPtr *C.char
	out := C.cx_from_data_bin_schema_driven(cs, cHint, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", errors.New("cx_from_data_bin_schema_driven: unknown error")
	}
	return goStr(out), nil
}
