package cxlib

/*
#include "cx.h"
#include <stdlib.h>
*/
import "C"

import (
	"encoding/binary"
	"fmt"
	"unsafe"
)

// CX schema validator binding — `cx_validate` + `cx_validate_apply_defaults`.
//
// Per spec/schema.md §10 + spec/abi.md §2.13. The C ABI
// returns a framed binary diagnostics payload:
//
//   [u32 LE total_size]
//   [u32 LE diag_count]
//   diagnostic* {
//     [u32 line] [u32 col]
//     [u8 prefix]                    // 'S'/'W'/'D'; 0x00 = no prefix
//     [u32 error_code]
//     [u8 severity]                  // 0=info, 1=warn, 2=error
//     [u32 message_len] [message_utf8]
//   }
//
// The prefix byte is the ASCII rule-code namespace tag — `S` for the
// schema validator, `W` for streaming-write, `D` for the
// future data validator. Bindings render the public Code string as
// `<prefix><numeric:03d>` (e.g. `"S006"`, `"W001"`); a `0x00` prefix
// renders the numeric without a letter. See spec/abi.md §2.13 /
// spec/schema.md §10.2.

type Severity uint8

const (
	SeverityInfo  Severity = 0
	SeverityWarn  Severity = 1
	SeverityError Severity = 2
)

func (s Severity) String() string {
	switch s {
	case SeverityInfo:
		return "info"
	case SeverityWarn:
		return "warn"
	case SeverityError:
		return "error"
	}
	return "unknown"
}

// Diagnostic is one validation finding. Code is the spec rule id (e.g. "S002").
type Diagnostic struct {
	Code     string
	Severity Severity
	Message  string
	Line     int
	Col      int
}

// ValidationReport carries all diagnostics from one validate() call,
// in document order. ModifiedDoc is populated only by ValidateWithDefaults.
type ValidationReport struct {
	Diagnostics []Diagnostic
	ModifiedDoc string
}

func (r *ValidationReport) IsValid() bool {
	for _, d := range r.Diagnostics {
		if d.Severity == SeverityError {
			return false
		}
	}
	return true
}

func (r *ValidationReport) ErrorCount() int {
	n := 0
	for _, d := range r.Diagnostics {
		if d.Severity == SeverityError {
			n++
		}
	}
	return n
}

func (r *ValidationReport) WarnCount() int {
	n := 0
	for _, d := range r.Diagnostics {
		if d.Severity == SeverityWarn {
			n++
		}
	}
	return n
}

func (r *ValidationReport) InfoCount() int {
	n := 0
	for _, d := range r.Diagnostics {
		if d.Severity == SeverityInfo {
			n++
		}
	}
	return n
}

func (r *ValidationReport) ErrorCodes() []string {
	out := make([]string, 0, len(r.Diagnostics))
	for _, d := range r.Diagnostics {
		if d.Severity == SeverityError {
			out = append(out, d.Code)
		}
	}
	return out
}

// parseDiagPayload decodes the unframed [u32 count][diagnostic*] body.
// `payload` is what extractBinPayload returns (size header stripped).
func parseDiagPayload(payload []byte) []Diagnostic {
	if len(payload) < 4 {
		return nil
	}
	count := binary.LittleEndian.Uint32(payload[0:4])
	out := make([]Diagnostic, 0, count)
	off := 4
	for i := uint32(0); i < count; i++ {
		if off+18 > len(payload) {
			return out
		}
		line := binary.LittleEndian.Uint32(payload[off : off+4])
		off += 4
		col := binary.LittleEndian.Uint32(payload[off : off+4])
		off += 4
		prefix := payload[off]
		off++
		code := binary.LittleEndian.Uint32(payload[off : off+4])
		off += 4
		sev := payload[off]
		off++
		mlen := binary.LittleEndian.Uint32(payload[off : off+4])
		off += 4
		if off+int(mlen) > len(payload) {
			return out
		}
		msg := string(payload[off : off+int(mlen)])
		off += int(mlen)
		out = append(out, Diagnostic{
			Code:     formatCode(prefix, code),
			Severity: Severity(sev),
			Message:  msg,
			Line:     int(line),
			Col:      int(col),
		})
	}
	return out
}

// formatCode renders a diagnostic's public Code string from the wire-format
// prefix byte + numeric error code per spec/abi.md §2.13. A 0x00 prefix
// (namespace unspecified) renders as the numeric only.
func formatCode(prefix byte, numeric uint32) string {
	if prefix == 0 {
		return fmt.Sprintf("%03d", numeric)
	}
	return fmt.Sprintf("%c%03d", prefix, numeric)
}

// Validate parses doc + schema as CX text, runs the validator, and
// returns a ValidationReport. Schema-load errors (missing [schema of=...] header,
// unknown anchor, etc.) surface as a single error-severity Diagnostic,
// not as a Go error. Returns a Go error only on malformed CX input.
func Validate(doc, schema string) (*ValidationReport, error) {
	docB := []byte(doc)
	schemaB := []byte(schema)
	var docPtr *C.char
	if len(docB) > 0 {
		docPtr = (*C.char)(unsafe.Pointer(&docB[0]))
	}
	var schemaPtr *C.char
	if len(schemaB) > 0 {
		schemaPtr = (*C.char)(unsafe.Pointer(&schemaB[0]))
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_validate_with_len(
		docPtr, C.size_t(len(docB)),
		schemaPtr, C.size_t(len(schemaB)),
		&errPtr,
	))
	payload, err := extractBinPayload(raw, errPtr)
	if err != nil {
		return nil, err
	}
	return &ValidationReport{Diagnostics: parseDiagPayload(payload)}, nil
}

// ValidateWithDefaults is like Validate, but additionally returns the
// default-applied document via report.ModifiedDoc. ModifiedDoc is empty
// when the schema declares no defaults.
func ValidateWithDefaults(doc, schema string) (*ValidationReport, error) {
	docB := []byte(doc)
	schemaB := []byte(schema)
	var docPtr *C.char
	if len(docB) > 0 {
		docPtr = (*C.char)(unsafe.Pointer(&docB[0]))
	}
	var schemaPtr *C.char
	if len(schemaB) > 0 {
		schemaPtr = (*C.char)(unsafe.Pointer(&schemaB[0]))
	}
	var errPtr, modifiedPtr *C.char
	raw := unsafe.Pointer(C.cx_validate_apply_defaults_with_len(
		docPtr, C.size_t(len(docB)),
		schemaPtr, C.size_t(len(schemaB)),
		&modifiedPtr, &errPtr,
	))
	payload, err := extractBinPayload(raw, errPtr)
	if err != nil {
		return nil, err
	}
	report := &ValidationReport{Diagnostics: parseDiagPayload(payload)}
	if modifiedPtr != nil {
		report.ModifiedDoc = C.GoString(modifiedPtr)
		C.cx_free(modifiedPtr)
	}
	return report, nil
}
