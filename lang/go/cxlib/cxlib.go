// Package cxlib is a CGo binding for libcx.
package cxlib

/*
// Search: system install (make install), then repo-relative dev tree.
// Override at build time: CGO_LDFLAGS="-L/custom/path -Wl,-rpath,/custom/path"
#cgo CFLAGS:  -I${SRCDIR}/../../../include -I/usr/local/include -I/opt/homebrew/include
#cgo LDFLAGS: -lcx
#cgo darwin LDFLAGS: -L${SRCDIR}/../../../vcx/target -L${SRCDIR}/../../../dist/lib -L/usr/local/lib -L/opt/homebrew/lib -Wl,-rpath,${SRCDIR}/../../../vcx/target -Wl,-rpath,/usr/local/lib -Wl,-rpath,/opt/homebrew/lib
#cgo linux  LDFLAGS: -L${SRCDIR}/../../../vcx/target -L${SRCDIR}/../../../dist/lib -L/usr/local/lib                     -Wl,-rpath,${SRCDIR}/../../../vcx/target -Wl,-rpath,/usr/local/lib
#include "cx.h"
#include <stdlib.h>
extern char* cx_to_ast_bin(const char* input, char** err_out);
extern char* cx_to_ast_bin_with_include_root(const char* input, const char* include_root, char** err_out);
extern char* cx_to_events_bin(const char* input, char** err_out);
extern char* cx_ast_to_cx(const char* input, char** err_out);
extern char* cx_to_cx_compact(const char* input, char** err_out);
// Streaming trampoline — implemented in cxlib_stream.go via //export.
extern int cxGoStreamTrampoline(const char* bytes, size_t n, void* user);
*/
import "C"
import (
	"encoding/binary"
	"fmt"
	"runtime"
	"unsafe"
)

// init performs the process-level GC thread-init handshake (spec/abi.md §1.6).
// libcx is built against Boehm GC; cx_init enables registration of host (non-V)
// threads so a collection triggered inside a libcx call on a foreign thread
// does not abort with libgc's "Collecting from unknown thread". Idempotent.
func init() {
	C.cx_init()
}

// cxThread pins the calling goroutine to its current OS thread and registers
// that thread with libcx's Boehm GC for the duration of a libcx call, then
// returns a release func — use `defer cxThread()()`.
//
// Go's cgo executes each call on an arbitrary OS thread, and consecutive calls
// (even from one goroutine) may run on DIFFERENT threads. When libcx triggers
// a GC collection on a thread libgc has never seen, the process aborts with a
// flaky SIGSEGV ("signal arrived during cgo execution") — the exact symptom
// observed in TestProgramsConformanceCorpus. Locking + registering (idempotent;
// DUPLICATE is a no-op) guarantees the cgo call and any collection inside it
// run on a registered, non-migrating thread. (Python avoids this via the GIL +
// a single calling thread; that assumption does not hold for Go.)
func cxThread() func() {
	runtime.LockOSThread()
	C.cx_thread_register()
	return runtime.UnlockOSThread
}

func cStr(s string) *C.char {
	return C.CString(s)
}

func goStr(p *C.char) string {
	s := C.GoString(p)
	C.cx_free(p)
	return s
}

func callC(fn func(*C.char, **C.char) *C.char, input string) (string, error) {
	defer cxThread()()
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	out := fn(cs, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

func extractBinPayload(raw unsafe.Pointer, errPtr *C.char) ([]byte, error) {
	if raw == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, fmt.Errorf("unknown error")
	}
	// First 4 bytes: payload size as u32 LE
	sizeBytes := (*[4]byte)(raw)[:]
	payloadSize := binary.LittleEndian.Uint32(sizeBytes)
	// Copy payload (bytes after the 4-byte header)
	payload := make([]byte, payloadSize)
	if payloadSize > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(uintptr(raw)+4)), payloadSize)
		copy(payload, src)
	}
	C.cx_free((*C.char)(raw))
	return payload, nil
}

// ToAstBin returns the raw binary AST for a CX input string.
func ToAstBin(input string) ([]byte, error) {
	defer cxThread()()
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_ast_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// ToAstBinWithIncludeRoot is ToAstBin with opt-in ?include resolution
// per spec/include.md §1-§8 (v0.7.0 GG3 / GG4). Empty includeRoot
// disables resolution.
func ToAstBinWithIncludeRoot(input string, includeRoot string) ([]byte, error) {
	defer cxThread()()
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	cr := C.CString(includeRoot)
	defer C.free(unsafe.Pointer(cr))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_ast_bin_with_include_root(cs, cr, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// ToEventsBin returns the raw binary events for a CX input string.
func ToEventsBin(input string) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_to_events_bin(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

// ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────────

// Fmt returns the lossless canonical text CX. Preserves comments and
// other presentation; normalizes whitespace/quoting. Idempotent.
func Fmt(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_fmt(s, e) }, input)
}

// Canonical returns the strict canonical text CX. Strips presentation
// (comments, etc.) so byte-identical output corresponds to data
// equivalence.
func Canonical(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_canonical(s, e) }, input)
}

// Hash returns the SHA-256 hex (64 lowercase hex chars) of the strict
// canonical bytes.
func Hash(input string) (string, error) {
	return callC(func(s *C.char, e **C.char) *C.char { return C.cx_hash(s, e) }, input)
}

// Eq reports whether strict-canonical(a) == strict-canonical(b).
func Eq(a, b string) (bool, error) {
	cs := C.CString(a)
	defer C.free(unsafe.Pointer(cs))
	cs2 := C.CString(b)
	defer C.free(unsafe.Pointer(cs2))
	var errPtr *C.char
	out := C.cx_eq(cs, cs2, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return false, fmt.Errorf("%s", msg)
		}
		return false, fmt.Errorf("unknown error")
	}
	return goStr(out) == "1", nil
}

// Diff returns the semantic diff between two CX inputs. format is
// "unified", "json", or "summary". Empty result means data-equivalent.
func Diff(a, b, format string) (string, error) {
	cs := C.CString(a)
	defer C.free(unsafe.Pointer(cs))
	cs2 := C.CString(b)
	defer C.free(unsafe.Pointer(cs2))
	cs3 := C.CString(format)
	defer C.free(unsafe.Pointer(cs3))
	var errPtr *C.char
	out := C.cx_diff(cs, cs2, cs3, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	return goStr(out), nil
}

// Lint runs style + correctness checks on the input. format is
// "text", "json", or "summary". disabled is a comma-separated list
// of check IDs to suppress ("" runs all). Empty result means no
// findings.
func Lint(input, format, disabled string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	cs2 := C.CString(format)
	defer C.free(unsafe.Pointer(cs2))
	cs3 := C.CString(disabled)
	defer C.free(unsafe.Pointer(cs3))
	var errPtr *C.char
	out := C.cx_lint(cs, cs2, cs3, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	return goStr(out), nil
}

// IDLookup finds the element declaring `#id` in `input` and returns
// its AST-JSON encoding. Empty result means no such ID. Stateless
// wrapper around cx_id_lookup; for repeated lookups against the same
// document, prefer Document.ResolveID() / ElementsByID().
func IDLookup(input, id string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	cs2 := C.CString(id)
	defer C.free(unsafe.Pointer(cs2))
	var errPtr *C.char
	out := C.cx_id_lookup(cs, cs2, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	return goStr(out), nil
}

// ResolveRef follows a bare `@ref` reference to its declaring element
// and returns its AST-JSON encoding. Refs and IDs share a namespace,
// so this is observationally equivalent to IDLookup.
func ResolveRef(input, ref string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	cs2 := C.CString(ref)
	defer C.free(unsafe.Pointer(cs2))
	var errPtr *C.char
	out := C.cx_resolve_ref(cs, cs2, &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	return goStr(out), nil
}

// NodeID was a cxpath-driven ID lookup retired at v0.7.6 (Phase 7)
// alongside the rest of the cxpath C ABI. Equivalent behaviour: run
// a `//pattern` CXPath value (or `[?for [pattern $m] :yield $m]`)
// via EvalCode to locate the element, then read its @id attribute.
// See spec/code.md §5 + §10.4.7 and the migration table in
// lang/go/cxlib/README.md.

// ── Phase 5 / CB-1 / CB-2 helpers ────────────────────────────────────────────

// callBinTextOut calls a cx_ast_bin_to_<format> function with FRAMED
// binary AST input and returns the text result.
func callBinTextOut(astBin []byte, fn func(*C.char, **C.char) *C.char) (string, error) {
	if len(astBin) == 0 {
		return "", fmt.Errorf("ast_bin_to_*: empty input")
	}
	defer cxThread()()
	var errPtr *C.char
	out := fn((*C.char)(unsafe.Pointer(&astBin[0])), &errPtr)
	if out == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return "", fmt.Errorf("%s", msg)
		}
		return "", fmt.Errorf("unknown error")
	}
	return goStr(out), nil
}

func astBinToCx(astBin []byte) (string, error) {
	return callBinTextOut(astBin, func(s *C.char, e **C.char) *C.char { return C.cx_ast_bin_to_cx(s, e) })
}
func astBinToXml(astBin []byte) (string, error) {
	return callBinTextOut(astBin, func(s *C.char, e **C.char) *C.char { return C.cx_ast_bin_to_xml(s, e) })
}
func astBinToJson(astBin []byte) (string, error) {
	return callBinTextOut(astBin, func(s *C.char, e **C.char) *C.char { return C.cx_ast_bin_to_json(s, e) })
}
func astBinToYaml(astBin []byte) (string, error) {
	return callBinTextOut(astBin, func(s *C.char, e **C.char) *C.char { return C.cx_ast_bin_to_yaml(s, e) })
}
func astBinToToml(astBin []byte) (string, error) {
	return callBinTextOut(astBin, func(s *C.char, e **C.char) *C.char { return C.cx_ast_bin_to_toml(s, e) })
}

// callTextToAstBin invokes a cx_<fmt>_to_ast_bin function and returns
// the raw AST bin payload (frame stripped).
func callTextToAstBin(input string, fn func(*C.char, **C.char) *C.char) ([]byte, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	raw := unsafe.Pointer(fn(cs, &errPtr))
	return extractBinPayload(raw, errPtr)
}

func xmlToAstBin(input string) ([]byte, error) {
	return callTextToAstBin(input, func(s *C.char, e **C.char) *C.char { return C.cx_xml_to_ast_bin(s, e) })
}
func jsonToAstBin(input string) ([]byte, error) {
	return callTextToAstBin(input, func(s *C.char, e **C.char) *C.char { return C.cx_json_to_ast_bin(s, e) })
}
func yamlToAstBin(input string) ([]byte, error) {
	return callTextToAstBin(input, func(s *C.char, e **C.char) *C.char { return C.cx_yaml_to_ast_bin(s, e) })
}
func tomlToAstBin(input string) ([]byte, error) {
	return callTextToAstBin(input, func(s *C.char, e **C.char) *C.char { return C.cx_toml_to_ast_bin(s, e) })
}

// ── Phase 5 / CB-4 — events handle API ──────────────────────────────────────

// EventStream is a pull-based iterator over CX streaming events,
// backed by the cx_events_open / cx_events_next / cx_events_close
// handle API. Replaces the prior eager-buffered cx_to_events_bin path.
type EventStream struct {
	handle unsafe.Pointer
	closed bool
}

// OpenEvents creates a streaming handle for the given CX input.
// Caller must Close().
func OpenEvents(input string) (*EventStream, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var errPtr *C.char
	h := unsafe.Pointer(C.cx_events_open(cs, &errPtr))
	if h == nil {
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			return nil, fmt.Errorf("%s", msg)
		}
		return nil, fmt.Errorf("cx_events_open: unknown error")
	}
	return &EventStream{handle: h}, nil
}

// Next returns the next event. Returns (zero, false, nil) on EOF.
func (s *EventStream) Next() (StreamEvent, bool, error) {
	if s.closed || s.handle == nil {
		return StreamEvent{}, false, nil
	}
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_events_next(C.cx_events_handle(s.handle), &errPtr))
	if raw == nil {
		// NULL with err = error; NULL with no err = EOF.
		if errPtr != nil {
			msg := C.GoString(errPtr)
			C.cx_free(errPtr)
			s.Close()
			return StreamEvent{}, false, fmt.Errorf("%s", msg)
		}
		s.Close()
		return StreamEvent{}, false, nil
	}
	// Read framed [u32 size][payload] from the C-owned buffer.
	sizeBytes := (*[4]byte)(raw)[:]
	size := binary.LittleEndian.Uint32(sizeBytes)
	payload := make([]byte, size)
	if size > 0 {
		src := unsafe.Slice((*byte)(unsafe.Pointer(uintptr(raw)+4)), size)
		copy(payload, src)
	}
	C.cx_free((*C.char)(raw))
	evt, err := decodeOneEvent(&binBuf{data: payload})
	if err != nil {
		return StreamEvent{}, false, err
	}
	return evt, true, nil
}

// Close releases the underlying handle. Idempotent.
func (s *EventStream) Close() {
	if s.closed || s.handle == nil {
		s.closed = true
		s.handle = nil
		return
	}
	C.cx_events_close(C.cx_events_handle(s.handle))
	s.closed = true
	s.handle = nil
}

// Version returns the library version string.
func Version() string {
	ptr := C.cx_version()
	s := C.GoString(ptr)
	C.cx_free(ptr)
	return s
}

// CX input
func ToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToCxCompact(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_cx_compact(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func AstToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_ast_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToXml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_xml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToAst(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_ast(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToJson(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_json(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToYaml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_yaml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func ToToml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_to_toml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

// EvalCode evaluates a CX program against an optional input document
// per spec/code.md and returns the rendered output. `input` may be
// empty when the program doesn't consume the implicit `$doc` binding
// (e.g. `[?for $i :in (1,2,3) :yield $i]`). `outputTarget` is one of
// "text" (default when ""), "cx", "json", "yaml", "xml", "csv", "tsv"
// (always available); "html" / "svg" / "mermaid" return
// CXER0001 until the Phase 4 reference renderer lands.
//
// Routes through cx_code_eval_with_len so non-NUL-terminated input
// flows through unchanged (spec/abi.md §2.14). Error wire format is
// `CXERnnnn:msg` per spec/audits/code_abi_v1.md D3.
func EvalCode(input, program, outputTarget string) (string, error) {
	defer cxThread()()
	cin := C.CString(input)
	defer C.free(unsafe.Pointer(cin))
	cprog := C.CString(program)
	defer C.free(unsafe.Pointer(cprog))
	ctgt := C.CString(outputTarget)
	defer C.free(unsafe.Pointer(ctgt))
	var ep *C.char
	out := C.cx_code_eval_with_len(
		cin, C.size_t(len(input)),
		cprog, C.size_t(len(program)),
		ctgt,
		&ep,
	)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("cx_code_eval: unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

// EvalCodeStreaming evaluates a CX program with pull-based
// incremental output. `onChunk` is invoked with each output chunk;
// returning a non-nil error aborts evaluation cleanly. Concatenating
// every chunk yields the same bytes EvalCode would return — per
// the spec/audits/code_abi_v1.md §3.3 byte-equivalence contract.
//
// cgo callback note: C function pointers can't be Go closures
// directly, so the caller's onChunk is registered in a process-wide
// dispatch table keyed by a uint64 token. The token is passed
// through cx_code_eval_streaming's user pointer, and the exported
// cxGoStreamTrampoline (in cxlib_stream.go) looks up the closure per
// invocation. The token slot is freed when EvalCodeStreaming
// returns regardless of outcome.
func EvalCodeStreaming(input, program, outputTarget string,
	onChunk func(chunk []byte) error) error {
	defer cxThread()()
	token, cleanup := registerStreamCallback(onChunk)
	defer cleanup()
	cin := C.CString(input)
	defer C.free(unsafe.Pointer(cin))
	cprog := C.CString(program)
	defer C.free(unsafe.Pointer(cprog))
	ctgt := C.CString(outputTarget)
	defer C.free(unsafe.Pointer(ctgt))
	var ep *C.char
	C.cx_code_eval_streaming(
		cin, C.size_t(len(input)),
		cprog, C.size_t(len(program)),
		ctgt,
		C.cx_code_write_cb(C.cxGoStreamTrampoline),
		unsafe.Pointer(uintptr(token)),
		&ep,
	)
	if ep != nil {
		m := C.GoString(ep)
		C.cx_free(ep)
		return fmt.Errorf("%s", m)
	}
	return streamCallbackError(token)
}

// XML input
func XmlToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func XmlToXml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_xml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func XmlToAst(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_ast(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func XmlToJson(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_json(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func XmlToYaml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_yaml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func XmlToToml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_xml_to_toml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

// JSON input
func JsonToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func JsonToXml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_xml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func JsonToAst(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_ast(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func JsonToJson(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_json(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func JsonToYaml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_yaml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func JsonToToml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_json_to_toml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

// YAML input
func YamlToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func YamlToXml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_xml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func YamlToAst(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_ast(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func YamlToJson(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_json(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func YamlToYaml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_yaml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func YamlToToml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_yaml_to_toml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}

// TOML input
func TomlToCx(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_cx(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func TomlToXml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_xml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func TomlToAst(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_ast(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func TomlToJson(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_json(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func TomlToYaml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_yaml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
func TomlToToml(input string) (string, error) {
	cs := C.CString(input)
	defer C.free(unsafe.Pointer(cs))
	var ep *C.char
	out := C.cx_toml_to_toml(cs, &ep)
	if out == nil {
		if ep != nil {
			m := C.GoString(ep)
			C.cx_free(ep)
			return "", fmt.Errorf("%s", m)
		}
		return "", fmt.Errorf("unknown error")
	}
	s := C.GoString(out)
	C.cx_free(out)
	return s, nil
}
