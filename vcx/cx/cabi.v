module cx

// ── C ABI ─────────────────────────────────────────────────────────────────────
// Exports the same flat C API as the Rust libcx.so so existing C/Python/V
// consumers can switch without source changes.
//
// Build as shared library:
// v -shared -o target/libcx.so cx/ (Linux)
// v -shared -o target/libcx.dylib cx/ (macOS)
//
// All functions return a heap-allocated C string the caller must release with
// cx_free(). On error they return NULL and, if err_out != NULL, set *err_out
// to a heap-allocated error message (also released with cx_free()).

// ── helpers ───────────────────────────────────────────────────────────────────

fn c_string(s string) &char {
	buf := unsafe { malloc(s.len + 1) }
	unsafe { vmemcpy(buf, s.str, s.len + 1) }
	return unsafe { &char(buf) }
}

fn c_err(msg string, err_out &&char) &char {
	if err_out != unsafe { nil } {
		unsafe { *err_out = c_string(msg) }
	}
	return unsafe { nil }
}

// ── memory ────────────────────────────────────────────────────────────────────

@[export: 'cx_free']
pub fn cx_free(s &char) {
	unsafe { free(voidptr(s)) }
}

// ── thread init (spec/abi.md §1.6) ────────────────────────────────────────────
//
// libcx is built against Boehm GC. The default GC mode is not aware of
// host threads spawned outside the V runtime — when a non-V thread (e.g.
// a Rust cargo worker, a C# task, a Java JNI thread) calls into libcx
// and triggers a collection, libgc aborts with "Collecting from unknown
// thread". The fix is a process-level handshake plus a per-thread
// registration. These three symbols are the binding-facing API.
//
// `cx_init` — process-level: enable host-thread registration
// in libgc. Idempotent. Bindings call once at
// module load. Returns 0 on success.
// `cx_thread_register` — per-thread: register the calling thread with
// libgc so collections can stop it safely.
// Idempotent (DUPLICATE returns 0). Required for
// every host-spawned thread that will call into
// libcx; harmless on V/Python (GIL) / Go (cgo
// serialised) threads. Returns 0 on success or
// duplicate, -1 on real failure.
// `cx_thread_unregister`— per-thread: optional cleanup at thread exit.
// Returns 0 on success, -1 on failure.
//
// Stack-base detection: cx_thread_register asks libgc for the stack
// base of the current thread (`GC_get_stack_base`) so callers don't pass
// any platform-specific data.

// Thread-registration helpers live in a small C shim (gc_thread_shim.c)
// that includes <gc.h> directly. V calls the shim's nullary, struct-free
// surface — declaring libgc's `struct GC_stack_base *` from V triggers a
// type-tag collision with the upstream `gc.h` forward declarations.

#flag -I@VMODROOT/cx
#flag @VMODROOT/cx/gc_thread_shim.c
#include "gc_thread_shim.h"

fn C.cx_gc_allow_register_threads()
fn C.cx_gc_register_my_thread() int
fn C.cx_gc_unregister_my_thread() int

@[export: 'cx_init']
pub fn cx_init() int {
	C.cx_gc_allow_register_threads()
	return 0
}

@[export: 'cx_thread_register']
pub fn cx_thread_register() int {
	return C.cx_gc_register_my_thread()
}

@[export: 'cx_thread_unregister']
pub fn cx_thread_unregister() int {
	return C.cx_gc_unregister_my_thread()
}

// ── version ───────────────────────────────────────────────────────────────────

const cx_version_str = '0.6.0'
const cx_abi_version_str = '2.0'

// Capability bitmask per spec/abi.md §3. Implemented capabilities in
// this build: bits 0-5 (v1 ABI + binary AST/events + symmetric AST +
// data_bin core + data_bin one-shots), bit 6 (delimited CSV/TSV/PSV
//, Phase 7.67), bit 7 (canonical-form fmt/canonical/
// hash/eq), bits 8-9 (CXPath, streaming), bits 10-16 (v3.4 grammar
// features: :table, :decimal, :f16, boolean sigils, line comments,
// logfmt with per-line records, numeric underscores), bit 17
// (RESERVED — superseded by bit 23 Arrow D7; kept set on
// v2.x for back-compat), bit 18 (cx_diff), bit 19
// (cx_lint), bit 20 (ID/IDREF C ABI), bit
// 21 (chunked-table format `0x63` + streaming Table reader/writer per
// D1/D8 — chunked V core landed Phase 7.72, streaming Table
// V core + 10 C ABI symbols landed Phase 7.74a), bit 22 (page-compression wrapper
// `0x90` zstd v1 D2, Phase 7.72), bit 24 (schema-driven
// encoding header flag bit 1 + schema content-hash + 10 C ABI symbols
// D3/D4/D5/D6, Phase 7.73), bit 25 (schema validator
// + spec/schema.md §10 — `cx_validate` +
// `cx_validate_apply_defaults`, Phase 7.74c bootstrap; 4 of 14 rules
// implemented end-to-end), bit 26 (thread-init ABI per spec/abi.md
// §1.6 — `cx_init` / `cx_thread_register` / `cx_thread_unregister`),
// bit 27 (streaming-write API + spec/abi.md §2.15 —
// 25 C ABI symbols `cx_events_writer_*`, Phase 7.74g; CX format
// implemented end-to-end, xml/json/yaml/toml/md emits return W009
// "format not yet implemented" pending follow-up phases).
// Not yet implemented: bit 23 (Arrow C-Data interop — separate
// `libcx_arrow`).
//
// Bitmask = bits 0..22 set (0x7fffff) | bit 24 (0x1000000)
// | bit 25 (0x2000000) | bit 26 (0x4000000) | bit 27 (0x8000000)
// | bit 28 (0x10000000) | bit 29 (0x20000000) | bit 30 (0x40000000)
// = 0x5f7fffff. Bit 27 is the streaming-write API
// (`cx_events_writer_*` / spec/streaming.md §6 /
// spec/abi.md §2.15) — 25 C ABI symbols, wired in Phase 7.74g.
// Bit 28 is the CXL 1.0 evaluator (`cx_eval_cxl*` /
// spec/cxl.md / spec/abi.md §2.16) — V reference implementation
// landed alongside the bit-28 flip; cf. `vcx/cx/cxl.v`.
// Bit 29 is collection literals + CXDM v1.1 + labeled-form parser
// (/§D7/§D23 / spec/abi.md §1.5) — V parser + AST +
// canonical / hash / schema validator extensions; capability gates
// the labeled-form alias for EvalDirective.
// Bit 30 is parameterized templates / spec/abi.md
// §1.5 — V evaluator lexical-scope frames, positional template-
// invocation, W018 arg-count mismatch, `?def` 3-slot positional
// shape with legacy 2-slot auto-expansion.
const cx_features_str = '0x5f7fffff'

@[export: 'cx_version']
pub fn cx_version() &char {
	return c_string(cx_version_str)
}

// cx_abi_version returns the ABI major.minor version. Bindings call
// this on load and refuse mismatched majors per spec/abi.md §1.1.
@[export: 'cx_abi_version']
pub fn cx_abi_version() &char {
	return c_string(cx_abi_version_str)
}

// cx_features returns the capability bitmask as a NUL-terminated
// lowercase hex string per spec/abi.md §3. Bindings parse this on
// load and either degrade gracefully or refuse to load when a
// required capability is absent.
@[export: 'cx_features']
pub fn cx_features() &char {
	return c_string(cx_features_str)
}

// ── CX input ──────────────────────────────────────────────────────────────────

@[export: 'cx_to_cx_compact']
pub fn cx_to_cx_compact(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_cx_compact(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_ast_to_cx']
pub fn cx_ast_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := ast_to_cx(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_cx']
pub fn cx_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_cx(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_xml']
pub fn cx_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_xml(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_ast']
pub fn cx_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_ast(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_json']
pub fn cx_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_json(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_yaml']
pub fn cx_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_yaml(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_toml']
pub fn cx_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_toml(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── XML input ─────────────────────────────────────────────────────────────────

@[export: 'cx_xml_to_cx']
pub fn cx_xml_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := from_xml(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_xml_to_xml']
pub fn cx_xml_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .xml, .xml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_xml_to_ast']
pub fn cx_xml_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_xml_cx(src) or { return c_err(err.msg(), err_out) }
	result := if res.is_multi {
		docs := res.multi or { return unsafe { nil } }
		emit_ast_json_docs(docs)
	} else {
		doc := res.single or { return unsafe { nil } }
		emit_ast_json(doc)
	}
	return c_string(result)
}

@[export: 'cx_xml_to_json']
pub fn cx_xml_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .xml, .json) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_xml_to_yaml']
pub fn cx_xml_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .xml, .yaml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_xml_to_toml']
pub fn cx_xml_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .xml, .toml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── JSON/YAML/TOML input (not yet implemented — return error) ─────────────────

@[export: 'cx_json_to_cx']
pub fn cx_json_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .cx) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_json_to_xml']
pub fn cx_json_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .xml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_json_to_ast']
pub fn cx_json_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_json_cx(src) or { return c_err(err.msg(), err_out) }
	result := if res.is_multi {
		docs := res.multi or { return unsafe { nil } }
		emit_ast_json_docs(docs)
	} else {
		doc := res.single or { return unsafe { nil } }
		emit_ast_json(doc)
	}
	return c_string(result)
}
@[export: 'cx_json_to_json']
pub fn cx_json_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .json) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_json_to_yaml']
pub fn cx_json_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .yaml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_json_to_toml']
pub fn cx_json_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .toml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_yaml_to_cx']
pub fn cx_yaml_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .cx) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_yaml_to_xml']
pub fn cx_yaml_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .xml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_yaml_to_ast']
pub fn cx_yaml_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_yaml_cx(src) or { return c_err(err.msg(), err_out) }
	result := if res.is_multi {
		docs := res.multi or { return unsafe { nil } }
		emit_ast_json_docs(docs)
	} else {
		doc := res.single or { return unsafe { nil } }
		emit_ast_json(doc)
	}
	return c_string(result)
}
@[export: 'cx_yaml_to_json']
pub fn cx_yaml_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .json) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_yaml_to_yaml']
pub fn cx_yaml_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .yaml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_yaml_to_toml']
pub fn cx_yaml_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .toml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_toml_to_cx']
pub fn cx_toml_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .cx) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_toml_to_xml']
pub fn cx_toml_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .xml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_toml_to_ast']
pub fn cx_toml_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_toml_cx(src) or { return c_err(err.msg(), err_out) }
	result := if res.is_multi {
		docs := res.multi or { return unsafe { nil } }
		emit_ast_json_docs(docs)
	} else {
		doc := res.single or { return unsafe { nil } }
		emit_ast_json(doc)
	}
	return c_string(result)
}
@[export: 'cx_toml_to_json']
pub fn cx_toml_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .json) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_toml_to_yaml']
pub fn cx_toml_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .yaml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}
@[export: 'cx_toml_to_toml']
pub fn cx_toml_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .toml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── MD output from other formats ─────────────────────────────────────────────

@[export: 'cx_to_md']
pub fn cx_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_md(src) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_xml_to_md']
pub fn cx_xml_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .xml, .md) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_json_to_md']
pub fn cx_json_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .json, .md) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_yaml_to_md']
pub fn cx_yaml_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .yaml, .md) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_toml_to_md']
pub fn cx_toml_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .toml, .md) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── MD input ──────────────────────────────────────────────────────────────────

@[export: 'cx_md_to_cx']
pub fn cx_md_to_cx(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .cx) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_md_to_xml']
pub fn cx_md_to_xml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .xml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_md_to_ast']
pub fn cx_md_to_ast(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_md_cx(src) or { return c_err(err.msg(), err_out) }
	result := if res.is_multi {
		docs := res.multi or { return unsafe { nil } }
		emit_ast_json_docs(docs)
	} else {
		doc := res.single or { return unsafe { nil } }
		emit_ast_json(doc)
	}
	return c_string(result)
}

@[export: 'cx_md_to_json']
pub fn cx_md_to_json(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .json) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_md_to_yaml']
pub fn cx_md_to_yaml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .yaml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_md_to_toml']
pub fn cx_md_to_toml(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .toml) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_md_to_md']
pub fn cx_md_to_md(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := convert(src, .md, .md) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── Streaming ─────────────────────────────────────────────────────────────────

@[export: 'cx_to_events']
pub fn cx_to_events(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	mut stream := new_stream_from_doc(doc)
	events := stream.collect()
	parts := events.map(event_to_json(it))
	return c_string('[${parts.join(',')}]')
}

// ── Binary protocol ───────────────────────────────────────────────────────────

@[export: 'cx_to_events_bin']
pub fn cx_to_events_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	mut stream := new_stream_from_doc(doc)
	events := stream.collect()
	buf := events_to_bin(events)
	return buf.to_heap()
}

@[export: 'cx_to_ast_bin']
pub fn cx_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	buf := doc_to_bin(doc)
	return buf.to_heap()
}

// ── Streaming C ABI (Phase 2e) ───────────────────────────────────────────────
//
// Closes audit finding CB-4 by introducing a handle-based pull API
// per spec/abi.md §2.8: cx_events_open / cx_events_next /
// cx_events_close. Bindings now hold a real handle and pull events
// one at a time, enabling lazy iteration patterns and explicit
// resource cleanup.
//
// v1 IMPLEMENTATION NOTE: the underlying parser is whole-document
// (parses the input fully before producing events). The handle
// internally holds a parsed Document plus an iteration cursor; events
// are produced on demand from the cursor. This closes the API-shape
// half of CB-4. A future minor revision will swap in an incremental
// parser, keeping this API surface unchanged. spec/governance.md §6
// flags this as a documented v1 limitation.

@[heap]
struct CxEventHandle {
mut:
	stream Stream
}

// cx_events_open: parse CX input, construct an iteration handle, and
// return it as an opaque pointer. Caller must close via
// cx_events_close to release the handle.
@[export: 'cx_events_open']
pub fn cx_events_open(input &char, err_out &&char) voidptr {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	h := &CxEventHandle{ stream: new_stream_from_doc(doc) }
	return voidptr(h)
}

// cx_events_next: pull the next event from the handle, encoded as a
// framed binary event. Returns NULL with no error to signal EOF.
// On per-event encoding failure, returns NULL with `*err_out` set.
@[export: 'cx_events_next']
pub fn cx_events_next(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_next: null handle', err_out)
	}
	mut h := unsafe { &CxEventHandle(handle) }
	ev := h.stream.next() or { return unsafe { nil } }
	mut b := BinBuf{}
	encode_event(mut b, ev)
	return b.to_heap()
}

// cx_events_close: release the handle. Safe to call on NULL (no-op).
@[export: 'cx_events_close']
pub fn cx_events_close(handle voidptr) {
	if handle == unsafe { nil } {
		return
	}
	// V's GC reclaims the @[heap] CxEventHandle once the C-side
	// reference is dropped. We zero our own knowledge of it; the
	// handle's owned Stream + Document graph become collectible.
	_ = handle
}

// ── CXPath C ABI (Phase 2d) ──────────────────────────────────────────────────
//
// Closes audit finding CB-5. Bindings can now thunk to libcx for
// CXPath evaluation instead of re-implementing the parser + matcher
// in each host language (~5000 LOC of duplication across 9 bindings).
// See spec/abi.md §2.7.

// cx_select: parse CX input, evaluate `expr` against the parsed
// Document, and return the FIRST matching element as a framed
// binary AST. Returns NULL with no error if there's no match.
@[export: 'cx_select']
pub fn cx_select(input &char, expr &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	expr_str := unsafe { cstring_to_vstring(expr) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	// Pre-validate expr so a CXPath syntax error is reported via err_out
	// instead of crashing the host process via the panicking V API.
	cxpath_parse(expr_str) or { return c_err(err.msg(), err_out) }
	match_elem := doc.select(expr_str) or { return unsafe { nil } }
	wrapped := Document{ elements: [Node(match_elem)] }
	return doc_to_bin(wrapped).to_heap()
}

// cx_select_all: parse CX input, evaluate `expr`, and return ALL
// matches wrapped in a synthetic root Element named `cx:results`.
// Returns a framed binary AST. Empty result set returns the
// synthetic root with no children.
@[export: 'cx_select_all']
pub fn cx_select_all(input &char, expr &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	expr_str := unsafe { cstring_to_vstring(expr) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	cxpath_parse(expr_str) or { return c_err(err.msg(), err_out) }
	matches := doc.select_all(expr_str)
	mut items := []Node{cap: matches.len}
	for e in matches {
		items << Node(e)
	}
	wrapper := Element{ name: 'cx:results', items: items }
	wrapped := Document{ elements: [Node(wrapper)] }
	return doc_to_bin(wrapped).to_heap()
}

// cx_select_all_paths: parse CX input, evaluate `expr`, and return the
// structural PATHS of every match (preorder, same as cx_select_all).
//
// Bindings use this for transform_all: navigate to each path in their
// own AST, apply f to detached copies, and substitute back. Lets
// bindings drop their CXPath parser/evaluator and reuse only their
// existing tree-mutation utilities. See spec/abi.md §2.7.
//
// Output is a framed [u32 LE size][payload] buffer; payload is:
// [u32 n_paths]
// for each path:
// [u32 depth][u32 idx_0][u32 idx_1]...[u32 idx_{depth-1}]
//
// All integers little-endian. Indices are 0-based positions in
// Document.elements (depth 0) then Element.items (deeper).
@[export: 'cx_select_all_paths']
pub fn cx_select_all_paths(input &char, expr &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	expr_str := unsafe { cstring_to_vstring(expr) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	cxpath_parse(expr_str) or { return c_err(err.msg(), err_out) }
	paths := doc.select_all_paths(expr_str)
	bytes := encode_select_paths_payload(paths)
	return framed_bytes_to_heap(bytes)
}

fn encode_select_paths_payload(paths [][]int) []u8 {
	mut total := 4 // n_paths
	for p in paths {
		total += 4 + p.len * 4
	}
	mut payload := []u8{cap: total}
	cabi_append_u32(mut payload, u32(paths.len))
	for p in paths {
		cabi_append_u32(mut payload, u32(p.len))
		for idx in p {
			cabi_append_u32(mut payload, u32(idx))
		}
	}
	// Frame [u32 LE size][payload]
	mut framed := []u8{cap: 4 + payload.len}
	cabi_append_u32(mut framed, u32(payload.len))
	framed << payload
	return framed
}

fn cabi_append_u32(mut buf []u8, v u32) {
	buf << u8(v & 0xFF)
	buf << u8((v >> 8) & 0xFF)
	buf << u8((v >> 16) & 0xFF)
	buf << u8((v >> 24) & 0xFF)
}

// ── Canonical-form C ABI (spec/abi.md §2.6) ──────────────────────────────────
//
// Four convenience symbols for tooling: cx_fmt (lossless canonical),
// cx_canonical (strict canonical), cx_hash (SHA-256 hex of strict
// canonical bytes), cx_eq ("1" iff strict canonical(a) == strict
// canonical(b)). Per spec/canonical.md.

@[export: 'cx_fmt']
pub fn cx_fmt(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	out := cx_text_fmt(src) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

@[export: 'cx_canonical']
pub fn cx_canonical(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	out := cx_text_canonical(src) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

@[export: 'cx_hash']
pub fn cx_hash(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	out := cx_text_hash(src) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

@[export: 'cx_eq']
pub fn cx_eq(a &char, b &char, err_out &&char) &char {
	a_str := unsafe { cstring_to_vstring(a) }
	b_str := unsafe { cstring_to_vstring(b) }
	eq := cx_text_eq(a_str, b_str) or { return c_err(err.msg(), err_out) }
	return c_string(if eq { '1' } else { '0' })
}

// ── cx diff C ABI (internal design record) ───────────────────────────
//
// One symbol — cx_diff — returns the diff result as a string in one of
// three formats per the `format` argument: "unified", "json", "summary".
// Bindings call this from their `diff(a, b)` wrapper and surface the
// returned text as-is. Empty result == data-equivalent inputs.

@[export: 'cx_diff']
pub fn cx_diff(a &char, b &char, format &char, err_out &&char) &char {
	a_str := unsafe { cstring_to_vstring(a) }
	b_str := unsafe { cstring_to_vstring(b) }
	fmt_str := unsafe { cstring_to_vstring(format) }
	changes := cx_text_diff(a_str, b_str) or { return c_err(err.msg(), err_out) }
	out := match fmt_str {
		'unified' { diff_render_unified(changes, false) }
		'json' { diff_render_json(changes) }
		'summary' { diff_render_summary(changes) }
		else { return c_err('cx_diff: unknown format "${fmt_str}" (use unified|json|summary)', err_out) }
	}
	return c_string(out)
}

// ── cx lint C ABI (internal design record) ───────────────────────────
//
// One symbol — cx_lint — runs all enabled checks on the input and returns
// the rendered output in one of three formats per the `format` argument:
// "text", "json", or "summary". The `disabled` argument is a comma-
// separated list of check IDs to suppress (empty string = run all).

@[export: 'cx_lint']
pub fn cx_lint(input &char, format &char, disabled &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	fmt_str := unsafe { cstring_to_vstring(format) }
	dis_str := unsafe { cstring_to_vstring(disabled) }
	disabled_list := if dis_str == '' { []string{} } else { dis_str.split(',') }
	opts := LintOptions{ disabled: disabled_list, only: '' }
	findings := cx_text_lint(src, opts) or { return c_err(err.msg(), err_out) }
	out := match fmt_str {
		'text' { lint_render_text(findings) }
		'json' { lint_render_json(findings) }
		'summary' { lint_render_summary(findings) }
		else { return c_err('cx_lint: unknown format "${fmt_str}" (use text|json|summary)', err_out) }
	}
	return c_string(out)
}

// ── Symmetric binary AST C ABI (Phase 2c) ────────────────────────────────────
//
// Closes audit findings CB-1 (output: Document → format) and CB-2
// (input: format → AST). Bindings now consume non-CX inputs once via
// the binary AST and emit non-CX outputs from a binary AST in memory,
// avoiding both the JSON-AST re-parse and the CX-text round-trip.

// 5 new input symbols: <format> → binary AST.

@[export: 'cx_xml_to_ast_bin']
pub fn cx_xml_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_xml_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('parse_xml: no document', err_out) }
	return doc_to_bin(doc).to_heap()
}

@[export: 'cx_json_to_ast_bin']
pub fn cx_json_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_json_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('parse_json: no document', err_out) }
	return doc_to_bin(doc).to_heap()
}

@[export: 'cx_yaml_to_ast_bin']
pub fn cx_yaml_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_yaml_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('parse_yaml: no document', err_out) }
	return doc_to_bin(doc).to_heap()
}

@[export: 'cx_toml_to_ast_bin']
pub fn cx_toml_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_toml_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('parse_toml: no document', err_out) }
	return doc_to_bin(doc).to_heap()
}

@[export: 'cx_md_to_ast_bin']
pub fn cx_md_to_ast_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_md_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('parse_md: no document', err_out) }
	return doc_to_bin(doc).to_heap()
}

// 6 new output symbols: binary AST → <format>.

@[export: 'cx_ast_bin_to_cx']
pub fn cx_ast_bin_to_cx(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_cx(doc))
}

@[export: 'cx_ast_bin_to_xml']
pub fn cx_ast_bin_to_xml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_xml(doc))
}

@[export: 'cx_ast_bin_to_json']
pub fn cx_ast_bin_to_json(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_semantic_json(doc))
}

@[export: 'cx_ast_bin_to_yaml']
pub fn cx_ast_bin_to_yaml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_yaml(doc))
}

@[export: 'cx_ast_bin_to_toml']
pub fn cx_ast_bin_to_toml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_toml(doc))
}

@[export: 'cx_ast_bin_to_md']
pub fn cx_ast_bin_to_md(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := bin_to_doc(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_md(doc))
}

// ── CXDB v1 — strict canonical binary data format (Phase 2b.6) ───────────────

// cx_to_data_bin: parse CX text and return CXDB v1 strict-canonical
// bytes per spec/data_bin.md. Output framed as [u32 LE size][payload];
// caller reads the first 4 bytes for size, then the payload, frees
// the buffer with cx_free. See spec/abi.md §2.4.
@[export: 'cx_to_data_bin']
pub fn cx_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

// cx_from_data_bin: decode CXDB v1 framed bytes and return canonical
// CX text. Input must be the framed layout [u32 LE size][payload]
// produced by cx_to_data_bin. The function reads size from the first
// 4 bytes; null-termination is not required.
@[export: 'cx_from_data_bin']
pub fn cx_from_data_bin(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	out := from_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

// ── CXDB schema-driven encoding C ABI ( D3, Phase 7.73) ─────────────
//
// 10 symbols enable schema-driven CXDB encoding (header flag bit 1) per
// spec/data_bin.md §3.13. Each loader takes the source text plus a
// `.cxs` schema text and emits CXDB framed bytes with the schema
// reference embedded (content-hash form by default; the optional
// `ref_form` argument selects 0 = content-hash / 1 = inline schema /
// 2 = content-hash + name hint per §3.13.1). The dumper takes the
// framed bytes plus a schema hint and returns canonical CX text.
// Capability bit 24 (`0x1000000`) signals support; bindings query
// `cx_features` and refuse to call these symbols when unset.

fn schema_ref_form_from_int(form i32) SchemaRefForm {
	return match form {
		1 { SchemaRefForm.inline_schema }
		2 { SchemaRefForm.hash_with_name }
		else { SchemaRefForm.hash_only }
	}
}

@[export: 'cx_to_data_bin_schema_driven']
pub fn cx_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_xml_to_data_bin_schema_driven']
pub fn cx_xml_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	doc := parse_xml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_json_to_data_bin_schema_driven']
pub fn cx_json_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	doc := parse_json(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_yaml_to_data_bin_schema_driven']
pub fn cx_yaml_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	doc := parse_yaml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_toml_to_data_bin_schema_driven']
pub fn cx_toml_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	doc := parse_toml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_md_to_data_bin_schema_driven']
pub fn cx_md_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	res := parse_md_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('cx_md_to_data_bin_schema_driven: multi-doc unsupported', err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_csv_to_data_bin_schema_driven']
pub fn cx_csv_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	mut opts := default_parse_options()
	opts.delimiter = `,`
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_tsv_to_data_bin_schema_driven']
pub fn cx_tsv_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	mut opts := default_parse_options()
	opts.delimiter = u8(`\t`)
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_psv_to_data_bin_schema_driven']
pub fn cx_psv_to_data_bin_schema_driven(input &char, schema &char, ref_form i32, name_hint &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	schema_text := unsafe { cstring_to_vstring(schema) }
	hint := unsafe { cstring_to_vstring(name_hint) }
	mut opts := default_parse_options()
	opts.delimiter = `|`
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: schema_ref_form_from_int(ref_form), name_hint: hint) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_from_data_bin_schema_driven']
pub fn cx_from_data_bin_schema_driven(input &char, schema_hint &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	hint := unsafe { cstring_to_vstring(schema_hint) }
	doc := parse_data_bin_schema_driven(bytes, hint) or { return c_err(err.msg(), err_out) }
	return c_string(emit_cx(doc))
}

// cx_to_data_bin_chunked: parse CX text whose root is a single
// :table-bodied element and emit the CXDB chunked-table form (`0x63`)
// per spec/data_bin.md §3.11. Default chunk policy: 2^20 rows per
// group with auto-zstd above 64 KiB body size. Output is framed
// `[u32 LE size][payload]`. See spec/abi.md §2.10 (capability bit 21).
@[export: 'cx_to_data_bin_chunked']
pub fn cx_to_data_bin_chunked(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin_chunked(doc, ChunkedEmitOptions{}) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(bytes)
}

// framed_bytes_to_heap copies a V []u8 (already framed by emit_data_bin)
// into a malloc'd buffer for return through the C ABI. Caller frees
// with cx_free.
fn framed_bytes_to_heap(bytes []u8) &char {
	size := bytes.len
	raw := unsafe { &u8(malloc(size)) }
	unsafe {
		if size > 0 {
			vmemcpy(voidptr(raw), voidptr(bytes.data), size)
		}
	}
	return unsafe { &char(raw) }
}

// framed_input_to_bytes reads a [u32 LE size][payload] buffer from a
// C-side &char. The whole framed buffer (header + payload) is copied
// into a V []u8 for use by parse_data_bin. All pointer-deref work is
// kept inside the function's unsafe blocks so callers can use it as
// a regular `!` returner.
//
// SECURITY NOTE: this implicit-length form trusts the 4-byte size
// header. Callers passing arbitrary non-CXDB bytes (or a NUL-terminated
// C string) trigger an OOB read sized by whatever the first 4 bytes
// happen to look like. Bindings landing post-v0.6.0 should call the
// `_with_len` variants instead, which validate against an explicit
// caller-supplied length. Originals stay for back-compat through 1.0;
// removal at 2.0 (per spec/abi.md §1.1 versioning policy).
fn framed_input_to_bytes(input &char) ![]u8 {
	if input == unsafe { nil } {
		return error('cx_from_data_bin: null input')
	}
	mut size := u32(0)
	unsafe {
		p := &u8(input)
		size = u32(p[0]) | (u32(p[1]) << 8) | (u32(p[2]) << 16) | (u32(p[3]) << 24)
	}
	mut out := []u8{len: int(size) + 4}
	unsafe {
		p := &u8(input)
		vmemcpy(voidptr(out.data), voidptr(p), int(size) + 4)
	}
	return out
}

// framed_input_to_bytes_with_len validates the caller-supplied length
// against the embedded size header before copying. Returns an error
// when the header disagrees with `total_len` or when `total_len < 4`.
// The wire content (including the framing prefix) is copied verbatim.
fn framed_input_to_bytes_with_len(input &char, total_len usize) ![]u8 {
	if input == unsafe { nil } {
		return error('framed_input_with_len: null input')
	}
	if total_len < 4 {
		return error('framed_input_with_len: total_len ${total_len} < 4 (size header)')
	}
	mut size := u32(0)
	unsafe {
		p := &u8(input)
		size = u32(p[0]) | (u32(p[1]) << 8) | (u32(p[2]) << 16) | (u32(p[3]) << 24)
	}
	if u64(size) + 4 != u64(total_len) {
		return error('framed_input_with_len: size header (${size}) + 4 != total_len (${total_len})')
	}
	mut out := []u8{len: int(total_len)}
	unsafe {
		p := &u8(input)
		vmemcpy(voidptr(out.data), voidptr(p), int(total_len))
	}
	return out
}

// ── CXDB v1 — one-shot loaders/dumpers (Phase 7.28) ──────────────────────────
//
// Per spec/abi.md §2.4–§2.5, these symbols compose existing format
// parsers with emit_data_bin (loaders) and parse_data_bin with the
// existing format emitters (dumpers). They close the v2-required gap
// previously flagged in cx_features bit 5. Each loader/dumper is a
// thin composition; the heavy lifting lives in the per-format
// parsers and emitters that already ship.

// ── loaders: <fmt> text → CXDB v1 framed bytes ───────────────────────────────

@[export: 'cx_xml_to_data_bin']
pub fn cx_xml_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse_xml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_json_to_data_bin']
pub fn cx_json_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse_json(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_yaml_to_data_bin']
pub fn cx_yaml_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse_yaml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_toml_to_data_bin']
pub fn cx_toml_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse_toml(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

@[export: 'cx_md_to_data_bin']
pub fn cx_md_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	res := parse_md_cx(src) or { return c_err(err.msg(), err_out) }
	doc := res.single or { return c_err('cx_md_to_data_bin: multi-document markdown not supported', err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

// ── dumpers: CXDB v1 framed bytes → <fmt> text ───────────────────────────────

@[export: 'cx_data_bin_to_xml']
pub fn cx_data_bin_to_xml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_xml(doc))
}

@[export: 'cx_data_bin_to_json']
pub fn cx_data_bin_to_json(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_semantic_json(doc))
}

@[export: 'cx_data_bin_to_yaml']
pub fn cx_data_bin_to_yaml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_yaml(doc))
}

@[export: 'cx_data_bin_to_toml']
pub fn cx_data_bin_to_toml(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_toml(doc))
}

@[export: 'cx_data_bin_to_md']
pub fn cx_data_bin_to_md(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(emit_md(doc))
}

// ── Delimited (CSV / TSV / PSV / arbitrary single-char) C ABI ────────────────
//
// Per internal design record and spec/conversions.md §8.
// `delim` is a single byte (any byte except `\r \n " ' \\`); pass `,`, `\t`,
// or `|` for CSV / TSV / PSV. The cx_to_csv / cx_from_csv / cx_to_tsv /
// cx_to_psv aliases keep the historical short symbol names from the v3.4
// abi.md table and forward to cx_to_delimited / cx_from_delimited.

@[export: 'cx_to_delimited']
pub fn cx_to_delimited(input &char, delim u8, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := to_delimited(src, delim) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_from_delimited']
pub fn cx_from_delimited(input &char, delim u8, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	s := from_delimited(src, delim) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_to_csv']
pub fn cx_to_csv(input &char, err_out &&char) &char {
	return cx_to_delimited(input, `,`, err_out)
}

@[export: 'cx_from_csv']
pub fn cx_from_csv(input &char, err_out &&char) &char {
	return cx_from_delimited(input, `,`, err_out)
}

@[export: 'cx_to_tsv']
pub fn cx_to_tsv(input &char, err_out &&char) &char {
	return cx_to_delimited(input, u8(`\t`), err_out)
}

@[export: 'cx_from_tsv']
pub fn cx_from_tsv(input &char, err_out &&char) &char {
	return cx_from_delimited(input, u8(`\t`), err_out)
}

@[export: 'cx_to_psv']
pub fn cx_to_psv(input &char, err_out &&char) &char {
	return cx_to_delimited(input, `|`, err_out)
}

@[export: 'cx_from_psv']
pub fn cx_from_psv(input &char, err_out &&char) &char {
	return cx_from_delimited(input, `|`, err_out)
}

// data_bin one-shots for delimited per spec/conversions.md §8.4.
// Cover the three named-delimiter variants; arbitrary single-char
// callers compose cx_to_delimited / cx_from_delimited with
// cx_to_data_bin / cx_from_data_bin themselves.

@[export: 'cx_csv_to_data_bin']
pub fn cx_csv_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	mut opts := default_parse_options()
	opts.delimiter = `,`
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	return framed_bytes_to_heap(emit_data_bin(doc))
}

@[export: 'cx_tsv_to_data_bin']
pub fn cx_tsv_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	mut opts := default_parse_options()
	opts.delimiter = u8(`\t`)
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	return framed_bytes_to_heap(emit_data_bin(doc))
}

@[export: 'cx_psv_to_data_bin']
pub fn cx_psv_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	mut opts := default_parse_options()
	opts.delimiter = `|`
	doc := parse_delimited(src, opts) or { return c_err(err.msg(), err_out) }
	return framed_bytes_to_heap(emit_data_bin(doc))
}

@[export: 'cx_data_bin_to_csv']
pub fn cx_data_bin_to_csv(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	mut opts := default_emit_options()
	opts.delimiter = `,`
	s := emit_delimited(doc, opts) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_data_bin_to_tsv']
pub fn cx_data_bin_to_tsv(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	mut opts := default_emit_options()
	opts.delimiter = u8(`\t`)
	s := emit_delimited(doc, opts) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

@[export: 'cx_data_bin_to_psv']
pub fn cx_data_bin_to_psv(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	doc := parse_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	mut opts := default_emit_options()
	opts.delimiter = `|`
	s := emit_delimited(doc, opts) or { return c_err(err.msg(), err_out) }
	return c_string(s)
}

// ── ID / IDREF C ABI (internal design record) ──────────────────────
//
// Three symbols expose the document-scope ID resolution surface to
// bindings that prefer string-in/string-out queries over the ast_bin
// round-trip (already in place since Phase 7.62). All three parse the
// input on each call; bindings caching repeated lookups should hold
// the parsed document via the binding's Document API instead.
//
// Empty return string with err_out unset means "not found" (no such
// declaration / no ID at the targeted node). Non-empty err_out means
// the input failed to parse or the cxpath was malformed.

// cx_id_lookup: find the element declaring `#id` and return its
// AST-JSON encoding. Empty result == no such ID in the document.
@[export: 'cx_id_lookup']
pub fn cx_id_lookup(input &char, id &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	id_str := unsafe { cstring_to_vstring(id) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	elem := doc.resolve_id(id_str) or { return c_string('') }
	return c_string(emit_ast_json_element(elem))
}

// cx_resolve_ref: follow a bare `@ref` reference to its declaring
// element and return its AST-JSON encoding. Refs and IDs share a
// namespace, so this is observationally equivalent to cx_id_lookup;
// the separate symbol matches the vocabulary (declaration
// vs reference) and keeps binding-side wrapper code self-documenting.
@[export: 'cx_resolve_ref']
pub fn cx_resolve_ref(input &char, ref &char, err_out &&char) &char {
	return cx_id_lookup(input, ref, err_out)
}

// cx_node_id: return the syntactic ID of the element selected by
// `cxpath`. Empty result means either the cxpath matched no element
// or the matched element has no ID. cxpath syntax per spec/cxpath.md.
@[export: 'cx_node_id']
pub fn cx_node_id(input &char, cxpath &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	path := unsafe { cstring_to_vstring(cxpath) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	elem := doc.select(path) or { return c_string('') }
	if eid := elem.id {
		return c_string(eid)
	}
	return c_string('')
}

// ── Streaming Table reader / writer ( D8, spec/abi.md §2.10) ─────────
//
// 10 handle-based C ABI symbols pull / push one row group at a time
// over the chunked-table wire format (`0x63`). Memory use is bounded
// by the largest single row group plus a constant overhead.
// Capability bit 21 (`0x200000`) signals reader / writer support;
// already set on this build (Phase 7.72 reserved the bit alongside
// the chunked-table format itself).
//
// In-memory variants consume / produce the framed
// `[u32 LE size][CXDB payload]` form used elsewhere in this ABI; fd
// variants operate on bare CXDB bytes (the file's length is implicit
// from the fd, and streaming writers cannot prefix their output with
// a size unknown until end-of-table). See data_bin_streaming.v for
// the full discussion.

// cx_table_reader_open: open a streaming reader over a framed CXDB
// chunked-table buffer. Returns an opaque handle the caller must
// release via cx_table_reader_close.
@[export: 'cx_table_reader_open']
pub fn cx_table_reader_open(data_bin &char, err_out &&char) voidptr {
	bytes := framed_input_to_bytes(data_bin) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	r := new_table_reader_bytes(bytes) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(r)
}

// cx_table_reader_open_fd: open a streaming reader over an open file
// descriptor positioned at the CXDB magic (no framing prefix).
@[export: 'cx_table_reader_open_fd']
pub fn cx_table_reader_open_fd(fd int, err_out &&char) voidptr {
	r := new_table_reader_fd(fd) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(r)
}

// cx_table_reader_schema: return the table's col-spec as framed
// ast_bin (Element with `:table` body declaring the columns; no rows).
@[export: 'cx_table_reader_schema']
pub fn cx_table_reader_schema(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_table_reader_schema: null handle', err_out)
	}
	r := unsafe { &CxTableReader(handle) }
	bytes := r.schema_bytes() or { return c_err(err.msg(), err_out) }
	return framed_bytes_to_heap(bytes)
}

// cx_table_reader_next: pull the next row group as a framed
// `[u32 LE size][plain body bytes]` buffer. Returns NULL with
// *err_out == NULL on end-of-table; NULL with err_out set on error.
@[export: 'cx_table_reader_next']
pub fn cx_table_reader_next(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_table_reader_next: null handle', err_out)
	}
	mut r := unsafe { &CxTableReader(handle) }
	bytes := r.next_row_group_framed() or {
		return c_err(err.msg(), err_out)
	}
	if bytes.len == 0 {
		return unsafe { nil } // EOF
	}
	return framed_bytes_to_heap(bytes)
}

// cx_table_reader_close: release the reader handle. Safe on NULL.
@[export: 'cx_table_reader_close']
pub fn cx_table_reader_close(handle voidptr) {
	if handle == unsafe { nil } { return }
	mut r := unsafe { &CxTableReader(handle) }
	r.reader_close()
}

// cx_table_writer_open: open an in-memory writer with the supplied
// col-spec (framed ast_bin, same shape cx_table_reader_schema returns).
@[export: 'cx_table_writer_open']
pub fn cx_table_writer_open(col_spec_payload &char, err_out &&char) voidptr {
	col_spec := framed_input_to_bytes(col_spec_payload) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	w := new_table_writer_bytes(col_spec) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

// cx_table_writer_open_fd: open an fd-streaming writer with the
// supplied col-spec. The header + col-spec bytes are flushed to the
// fd at open time so partial writes are observable.
@[export: 'cx_table_writer_open_fd']
pub fn cx_table_writer_open_fd(col_spec_payload &char, fd int, err_out &&char) voidptr {
	col_spec := framed_input_to_bytes(col_spec_payload) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	w := new_table_writer_fd(col_spec, fd) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

// cx_table_writer_emit_row_group: append one row group. The payload
// is in §3.11.2 plain-body format (uvarint(row_count) + col-payloads
// column-major); the writer wraps it in body-tag 0x01 or 0x90 per its
// default policy. Returns NULL on success with err_out unset; NULL on
// error with err_out set. (No success-payload return; the chunked
// stream is opaque between emit calls.)
@[export: 'cx_table_writer_emit_row_group']
pub fn cx_table_writer_emit_row_group(handle voidptr, row_group_payload &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_table_writer_emit_row_group: null handle', err_out)
	}
	bytes := framed_input_to_bytes(row_group_payload) or {
		return c_err(err.msg(), err_out)
	}
	mut w := unsafe { &CxTableWriter(handle) }
	// Strip the 4-byte framing prefix from the payload before handing
	// to the V core (the writer takes the bare plain-body form).
	if bytes.len < 4 {
		return c_err('cx_table_writer_emit_row_group: payload too short', err_out)
	}
	body := bytes[4..]
	w.emit_row_group_payload(body) or { return c_err(err.msg(), err_out) }
	return unsafe { nil }
}

// cx_table_writer_close_get_bytes: emit end-of-table, return the
// complete framed buffer. In-memory writers only.
@[export: 'cx_table_writer_close_get_bytes']
pub fn cx_table_writer_close_get_bytes(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_table_writer_close_get_bytes: null handle', err_out)
	}
	mut w := unsafe { &CxTableWriter(handle) }
	bytes := w.close_get_bytes() or { return c_err(err.msg(), err_out) }
	return framed_bytes_to_heap(bytes)
}

// cx_table_writer_close: release the writer handle. For fd writers,
// flushes the end-of-table marker. Safe on NULL.
@[export: 'cx_table_writer_close']
pub fn cx_table_writer_close(handle voidptr) {
	if handle == unsafe { nil } { return }
	mut w := unsafe { &CxTableWriter(handle) }
	w.writer_close() or { /* fd flush failed; nothing more we can do here */ }
}

// ── Schema validator C ABI ( + spec/schema.md §10.2, Phase 7.74c) ───
//
// Two symbols expose the schema validator to bindings. Both return a
// length-prefixed diagnostic payload in the wire format described in
// spec/schema.md §10.2:
//
// [u32 LE size] framing prefix (matches CXDB convention)
// [u32 LE diag_count]
// { diagnostic } * diag_count
//
// Each diagnostic is:
//
// [u32 LE line] 0 if unavailable
// [u32 LE col] 0 if unavailable
// [u32 LE error_code] numeric form of the S-prefix code
// (e.g. "S002" → 2, "S017" → 17)
// [u8 severity] 0=info, 1=warn, 2=error (matches Severity enum)
// [u32 LE message_len]
// [message_utf8]
//
// On schema-load failure (malformed `.cxs`), the symbols return NULL
// and set *err_out. A document with zero diagnostics returns a
// non-NULL buffer with diag_count=0; this lets callers distinguish
// "validated cleanly" from "couldn't validate at all."
//
// `cx_validate_apply_defaults` additionally writes the modified
// document (canonical CX text) to *modified_doc_out, mirroring
// spec/schema.md §11. Caller frees both outputs with cx_free.

// parse_error_code_prefix returns the ASCII letter namespace tag from a
// rule code (`'S'` for `S006`, `'W'` for `W001`, `'D'` for `D003`). Returns
// 0x00 when the code is empty, malformed, or uses an unrecognised prefix.
// Per spec/abi.md §2.13 / spec/schema.md §10.2 (Phase 7.74f), bindings
// route diagnostics on this byte rather than reconstructing the prefix
// client-side.
fn parse_error_code_prefix(code string) u8 {
	if code.len < 2 { return 0 }
	c := code[0]
	if c != `S` && c != `W` && c != `D` { return 0 }
	return c
}

fn parse_error_code_numeric(code string) u32 {
	if code.len < 2 { return 0 }
	if parse_error_code_prefix(code) == 0 { return 0 }
	mut n := u32(0)
	for i in 1 .. code.len {
		c := code[i]
		if c < `0` || c > `9` { return 0 }
		n = n * 10 + u32(c - `0`)
	}
	return n
}

fn encode_diagnostics_payload(diags []Diagnostic) []u8 {
	mut out := []u8{cap: 64 + diags.len * 32}
	encode_u32_le(mut out, u32(diags.len))
	for d in diags {
		encode_u32_le(mut out, u32(d.line))
		encode_u32_le(mut out, u32(d.col))
		out << parse_error_code_prefix(d.code)
		encode_u32_le(mut out, parse_error_code_numeric(d.code))
		out << u8(int(d.severity))
		encode_u32_le(mut out, u32(d.message.len))
		out << d.message.bytes()
	}
	mut framed := []u8{cap: 4 + out.len}
	encode_u32_le(mut framed, u32(out.len))
	framed << out
	return framed
}

@[export: 'cx_validate']
pub fn cx_validate(doc_input &char, schema_input &char, err_out &&char) &char {
	doc_src := unsafe { cstring_to_vstring(doc_input) }
	schema_src := unsafe { cstring_to_vstring(schema_input) }
	doc := parse(doc_src) or { return c_err(err.msg(), err_out) }
	report := validate(doc, schema_src, ValidateOptions{}) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(encode_diagnostics_payload(report.diagnostics))
}

@[export: 'cx_validate_apply_defaults']
pub fn cx_validate_apply_defaults(doc_input &char, schema_input &char, modified_doc_out &&char, err_out &&char) &char {
	doc_src := unsafe { cstring_to_vstring(doc_input) }
	schema_src := unsafe { cstring_to_vstring(schema_input) }
	doc := parse(doc_src) or { return c_err(err.msg(), err_out) }
	report := validate_with_defaults(doc, schema_src, ValidateOptions{}) or {
		return c_err(err.msg(), err_out)
	}
	if modified_doc_out != unsafe { nil } {
		out_doc := report.modified_doc or { Document{} }
		unsafe { *modified_doc_out = c_string(emit_cx(out_doc)) }
	}
	return framed_bytes_to_heap(encode_diagnostics_payload(report.diagnostics))
}

// ── Explicit-length C ABI variants (Phase 7.74c, v0.6.0 hardening) ──────────
//
// These `_with_len` symbols validate a caller-supplied byte count
// against the framed input's embedded size header before reading,
// closing the OOB-read footgun the implicit-length originals expose
// when handed non-CXDB bytes. Bindings landing post-v0.6.0 SHOULD
// call these in preference to the implicit-length forms; the
// originals stay for back-compat through 1.0 per spec/abi.md §1.1.
//
// The `_with_len` variants exist for every C ABI symbol that takes
// framed CXDB bytes as `const char*`. New format-specific decoders
// (cx_from_data_bin_xml_with_len etc.) follow the same pattern when
// the original lands.

@[export: 'cx_from_data_bin_with_len']
pub fn cx_from_data_bin_with_len(input &char, total_len usize, err_out &&char) &char {
	bytes := framed_input_to_bytes_with_len(input, total_len) or {
		return c_err(err.msg(), err_out)
	}
	out := from_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

@[export: 'cx_table_reader_open_with_len']
pub fn cx_table_reader_open_with_len(data_bin &char, total_len usize, err_out &&char) voidptr {
	bytes := framed_input_to_bytes_with_len(data_bin, total_len) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	r := new_table_reader_bytes(bytes) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(r)
}

@[export: 'cx_table_writer_open_with_len']
pub fn cx_table_writer_open_with_len(col_spec_payload &char, total_len usize, err_out &&char) voidptr {
	col_spec := framed_input_to_bytes_with_len(col_spec_payload, total_len) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	w := new_table_writer_bytes(col_spec) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

@[export: 'cx_table_writer_open_fd_with_len']
pub fn cx_table_writer_open_fd_with_len(col_spec_payload &char, total_len usize, fd int, err_out &&char) voidptr {
	col_spec := framed_input_to_bytes_with_len(col_spec_payload, total_len) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	w := new_table_writer_fd(col_spec, fd) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

@[export: 'cx_table_writer_emit_row_group_with_len']
pub fn cx_table_writer_emit_row_group_with_len(handle voidptr, row_group_payload &char, total_len usize, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_table_writer_emit_row_group_with_len: null handle', err_out)
	}
	bytes := framed_input_to_bytes_with_len(row_group_payload, total_len) or {
		return c_err(err.msg(), err_out)
	}
	mut w := unsafe { &CxTableWriter(handle) }
	if bytes.len < 4 {
		return c_err('cx_table_writer_emit_row_group_with_len: payload too short', err_out)
	}
	body := bytes[4..]
	w.emit_row_group_payload(body) or { return c_err(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_validate_with_len']
pub fn cx_validate_with_len(doc_input &char, doc_len usize, schema_input &char, schema_len usize, err_out &&char) &char {
	doc_src := vstring_from_bytes_or_empty(doc_input, doc_len)
	schema_src := vstring_from_bytes_or_empty(schema_input, schema_len)
	doc := parse(doc_src) or { return c_err(err.msg(), err_out) }
	report := validate(doc, schema_src, ValidateOptions{}) or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(encode_diagnostics_payload(report.diagnostics))
}

@[export: 'cx_validate_apply_defaults_with_len']
pub fn cx_validate_apply_defaults_with_len(doc_input &char, doc_len usize, schema_input &char, schema_len usize, modified_doc_out &&char, err_out &&char) &char {
	doc_src := vstring_from_bytes_or_empty(doc_input, doc_len)
	schema_src := vstring_from_bytes_or_empty(schema_input, schema_len)
	doc := parse(doc_src) or { return c_err(err.msg(), err_out) }
	report := validate_with_defaults(doc, schema_src, ValidateOptions{}) or {
		return c_err(err.msg(), err_out)
	}
	if modified_doc_out != unsafe { nil } {
		out_doc := report.modified_doc or { Document{} }
		unsafe { *modified_doc_out = c_string(emit_cx(out_doc)) }
	}
	return framed_bytes_to_heap(encode_diagnostics_payload(report.diagnostics))
}

// vstring_from_bytes_or_empty wraps `unsafe { tos(...) }` so that a
// nil pointer with zero length (which Go's cgo binding emits for
// empty input) returns an empty string instead of panicking inside
// V's `tos()`. The Python binding always passes a non-nil pointer
// to "" with len=0, so it never triggered this path; the Go binding
// passes nil for empty input.
@[inline]
fn vstring_from_bytes_or_empty(input &char, length usize) string {
	if input == unsafe { nil } || length == 0 {
		return ''
	}
	return unsafe { tos(voidptr(input), int(length)) }
}

// ── Streaming-write API (spec/abi.md §2.15, ) ────────────────────────
//
// 25 C ABI symbols total — 8 lifecycle + 17 emit. Capability bit 27
// (`0x8000000`) signals support; bindings probe `cx_features` before
// calling. Each emit returns NULL on success or a heap-allocated
// diagnostic string in the return value plus a UTF-8 message in
// err_out on failure. Diagnostic codes use the W namespace per the
// prefix-marker convention (`'W'` = 0x57 — schema validator §2.13
// shares the wire format).
//
// Phase 7.74g lands the V core + 25 ABI symbols. CX output format is
// implemented end-to-end. xml/json/yaml/toml/md emits return W009
// "format not yet implemented" pending follow-up phases; the symbols
// + capability bit are part of the v0.6.0 ABI lock so
// adopters can probe and rely on them once each format ships.

// vstring_from_cstr_or_empty wraps a C string pointer that may be
// NULL. Used by streaming-write open variants which accept optional
// pointer fields (anchor / merge / data_type / shape_input).
@[inline]
fn vstring_from_cstr_or_empty(input &char) string {
	if input == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(input) }
}

// optstr_from_cstr returns none for NULL, else a Some(string).
@[inline]
fn optstr_from_cstr(input &char) ?string {
	if input == unsafe { nil } {
		return none
	}
	return unsafe { cstring_to_vstring(input) }
}

@[inline]
fn bytes_from_cstr_len(input &char, total_len usize) []u8 {
	if input == unsafe { nil } || total_len == 0 {
		return []u8{}
	}
	mut out := []u8{len: int(total_len)}
	unsafe { vmemcpy(out.data, voidptr(input), int(total_len)) }
	return out
}

// ── Lifecycle (8 symbols) ────────────────────────────────────────────────────

@[export: 'cx_events_writer_open']
pub fn cx_events_writer_open(output_format &char, err_out &&char) voidptr {
	fmt := unsafe { cstring_to_vstring(output_format) }
	w := new_events_writer_bytes(fmt) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

@[export: 'cx_events_writer_open_fd']
pub fn cx_events_writer_open_fd(output_format &char, fd int, err_out &&char) voidptr {
	fmt := unsafe { cstring_to_vstring(output_format) }
	w := new_events_writer_fd(fmt, fd) or {
		_ = c_err(err.msg(), err_out)
		return unsafe { nil }
	}
	return voidptr(w)
}

// (The `cx_events_writer_open_shaped*` exports — 4 variants — were
// removed 2026-05-10 when was superseded by . CXL
// is the only output-shape mechanism; see `cx_eval_cxl*` below and
// `spec/abi.md §2.16`. The W011 "shape engine not yet implemented"
// path no longer exists.)

// cx_events_writer_close_get_bytes: in-memory writers — emit implicit
// EndDoc (W004 if elements remain unclosed), then return the accumulated
// output buffer wrapped in the standard CXDB-style `[u32 LE size][payload]`
// frame so per-binding wrappers can recover the byte length without a
// separate length parameter. fd writers return a 4-byte buffer with
// size=0 (payload already flushed to fd). Caller frees with cx_free.
@[export: 'cx_events_writer_close_get_bytes']
pub fn cx_events_writer_close_get_bytes(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_close_get_bytes: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	bytes := w.close_get_bytes() or {
		return c_err(err.msg(), err_out)
	}
	return framed_bytes_to_heap(frame_payload(bytes))
}

@[export: 'cx_events_writer_close']
pub fn cx_events_writer_close(handle voidptr) {
	if handle == unsafe { nil } {
		return
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	w.writer_close()
}

// ── Per-event emit (17 symbols) ──────────────────────────────────────────────

@[inline]
fn writer_emit_result(emit_err string, err_out &&char) &char {
	if emit_err.len == 0 {
		return unsafe { nil }
	}
	if err_out != unsafe { nil } {
		unsafe { *err_out = c_string(emit_err) }
	}
	return c_string(emit_err)
}

@[export: 'cx_events_writer_start_doc']
pub fn cx_events_writer_start_doc(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_start_doc: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	w.emit_start_doc() or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_end_doc']
pub fn cx_events_writer_end_doc(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_end_doc: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	w.emit_end_doc() or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

// emit_start_element implicit-len helper: attrs_payload is a bare
// CXDB-style buffer with a 4-byte LE size prefix. The `_with_len`
// variant validates against caller-supplied size.
@[export: 'cx_events_writer_start_element']
pub fn cx_events_writer_start_element(handle voidptr, name &char, anchor &char, data_type &char, merge &char, attrs_payload &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_start_element: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	nm := unsafe { cstring_to_vstring(name) }
	anch := optstr_from_cstr(anchor)
	dt := optstr_from_cstr(data_type)
	mg := optstr_from_cstr(merge)
	mut payload := []u8{}
	if attrs_payload != unsafe { nil } {
		framed := framed_input_to_bytes(attrs_payload) or {
			return writer_emit_result('W007: malformed attrs_payload header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_start_element(nm, anch, dt, mg, payload) or {
		return writer_emit_result(err.msg(), err_out)
	}
	return unsafe { nil }
}

@[export: 'cx_events_writer_start_element_with_len']
pub fn cx_events_writer_start_element_with_len(handle voidptr, name &char, anchor &char, data_type &char, merge &char, attrs_payload &char, attrs_len usize, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_start_element_with_len: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	nm := unsafe { cstring_to_vstring(name) }
	anch := optstr_from_cstr(anchor)
	dt := optstr_from_cstr(data_type)
	mg := optstr_from_cstr(merge)
	mut payload := []u8{}
	if attrs_payload != unsafe { nil } && attrs_len > 0 {
		framed := framed_input_to_bytes_with_len(attrs_payload, attrs_len) or {
			return writer_emit_result('W007: malformed attrs_payload header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_start_element(nm, anch, dt, mg, payload) or {
		return writer_emit_result(err.msg(), err_out)
	}
	return unsafe { nil }
}

@[export: 'cx_events_writer_end_element']
pub fn cx_events_writer_end_element(handle voidptr, name &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_end_element: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	nm := unsafe { cstring_to_vstring(name) }
	w.emit_end_element(nm) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_text']
pub fn cx_events_writer_text(handle voidptr, value &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_text: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	v := unsafe { cstring_to_vstring(value) }
	w.emit_text(v) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_scalar']
pub fn cx_events_writer_scalar(handle voidptr, data_type &char, value &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_scalar: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	dt := optstr_from_cstr(data_type)
	v := unsafe { cstring_to_vstring(value) }
	w.emit_scalar(dt, v) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_comment']
pub fn cx_events_writer_comment(handle voidptr, value &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_comment: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	v := unsafe { cstring_to_vstring(value) }
	w.emit_comment(v) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_pi']
pub fn cx_events_writer_pi(handle voidptr, target &char, data &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_pi: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	t := unsafe { cstring_to_vstring(target) }
	d := optstr_from_cstr(data)
	w.emit_pi(t, d) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_entity_ref']
pub fn cx_events_writer_entity_ref(handle voidptr, name &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_entity_ref: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	nm := unsafe { cstring_to_vstring(name) }
	w.emit_entity_ref(nm) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_raw_text']
pub fn cx_events_writer_raw_text(handle voidptr, value &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_raw_text: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	v := unsafe { cstring_to_vstring(value) }
	w.emit_raw_text(v) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_alias']
pub fn cx_events_writer_alias(handle voidptr, name &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_alias: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	nm := unsafe { cstring_to_vstring(name) }
	w.emit_alias(nm) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_start_table']
pub fn cx_events_writer_start_table(handle voidptr, col_spec_payload &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_start_table: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	mut payload := []u8{}
	if col_spec_payload != unsafe { nil } {
		framed := framed_input_to_bytes(col_spec_payload) or {
			return writer_emit_result('W007: malformed col_spec header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_start_table(payload) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_start_table_with_len']
pub fn cx_events_writer_start_table_with_len(handle voidptr, col_spec_payload &char, col_spec_len usize, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_start_table_with_len: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	mut payload := []u8{}
	if col_spec_payload != unsafe { nil } && col_spec_len > 0 {
		framed := framed_input_to_bytes_with_len(col_spec_payload, col_spec_len) or {
			return writer_emit_result('W007: malformed col_spec header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_start_table(payload) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_row_group']
pub fn cx_events_writer_row_group(handle voidptr, row_group_payload &char, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_row_group: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	mut payload := []u8{}
	if row_group_payload != unsafe { nil } {
		framed := framed_input_to_bytes(row_group_payload) or {
			return writer_emit_result('W007: malformed row-group header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_row_group(payload) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_row_group_with_len']
pub fn cx_events_writer_row_group_with_len(handle voidptr, row_group_payload &char, row_group_len usize, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_row_group_with_len: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	mut payload := []u8{}
	if row_group_payload != unsafe { nil } && row_group_len > 0 {
		framed := framed_input_to_bytes_with_len(row_group_payload, row_group_len) or {
			return writer_emit_result('W007: malformed row-group header: ${err.msg()}', err_out)
		}
		payload = framed[4..].clone()
	}
	w.emit_row_group(payload) or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

@[export: 'cx_events_writer_end_table']
pub fn cx_events_writer_end_table(handle voidptr, err_out &&char) &char {
	if handle == unsafe { nil } {
		return c_err('cx_events_writer_end_table: null handle', err_out)
	}
	mut w := unsafe { &CxEventsWriter(handle) }
	w.emit_end_table() or { return writer_emit_result(err.msg(), err_out) }
	return unsafe { nil }
}

// ── CXL evaluator (spec/abi.md §2.16, capability bit 28) ────────────────────
//
// Three symbols / spec/abi.md §2.16:
// cx_eval_cxl — NUL-terminated one-shot
// cx_eval_cxl_with_len — explicit-length one-shot (binary-safe)
// cx_eval_cxl_streaming — pull-based incremental emit (W012 v0.6.0
// stub — composes with the chunked-table
// reader and streaming-write API; lands
// at v0.6.1+ once the CXL 1.0 evaluator
// stabilises).
//
// W-codes:
// W012 — CXL evaluator returns this when streaming is requested or
// when a CXL 3.1+ directive is invoked at a v0.6.0 (CXL 1.0)
// evaluator (`[?let]`, `[?fn]`, `[?match]`, `[?try]`).
// W013 — Reserved for v0.7.0+ structured error codes per spec/cxl.md §2.5.

@[export: 'cx_eval_cxl']
pub fn cx_eval_cxl(cx_input &char, cxl_program &char, output_target &char, err_out &&char) &char {
	if cx_input == unsafe { nil } || cxl_program == unsafe { nil } {
		return c_err('cx_eval_cxl: cx_input and cxl_program must be non-NULL', err_out)
	}
	input := unsafe { cstring_to_vstring(cx_input) }
	prog := unsafe { cstring_to_vstring(cxl_program) }
	target := if output_target == unsafe { nil } {
		''
	} else {
		unsafe { cstring_to_vstring(output_target) }
	}
	out := eval_cxl(input, prog, target) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

@[export: 'cx_eval_cxl_with_len']
pub fn cx_eval_cxl_with_len(cx_input &char, cx_len usize,
		cxl_program &char, prog_len usize,
		output_target &char, err_out &&char) &char {
	if cx_input == unsafe { nil } || cxl_program == unsafe { nil } {
		return c_err('cx_eval_cxl_with_len: cx_input and cxl_program must be non-NULL', err_out)
	}
	input := unsafe { tos(&u8(cx_input), int(cx_len)) }
	prog := unsafe { tos(&u8(cxl_program), int(prog_len)) }
	target := if output_target == unsafe { nil } {
		''
	} else {
		unsafe { cstring_to_vstring(output_target) }
	}
	out := eval_cxl(input, prog, target) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

// cx_eval_cxl_streaming: v0.6.0 reserves the symbol and returns W012.
// The streaming variant composes with the chunked-table reader and the
// streaming-write API for memory-bounded evaluation of multi-GB inputs;
// shipping it requires the per-event evaluator skeleton, which lands
// post-v0.6.0 once the CXL 1.0 directive set is locked in conformance.
@[export: 'cx_eval_cxl_streaming']
pub fn cx_eval_cxl_streaming(cx_input &char, cxl_program &char, output_target &char,
		write_cb voidptr, user voidptr, err_out &&char) &char {
	_ = cx_input
	_ = cxl_program
	_ = output_target
	_ = write_cb
	_ = user
	return c_err('W012: cx_eval_cxl_streaming not yet implemented (v0.6.0 stub; see spec/cxl.md §6 streaming)', err_out)
}

