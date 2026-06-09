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

// ── WASM-only: arena sizing + reset ────────────────────────────
//
// These two symbols are part of the libcx-wasm playground subset
// (16-symbol table). They exist on every build for ABI
// symmetry; the native `cx` binary treats them as no-ops because its
// Boehm GC build handles memory itself. The WASM build pairs them with
// V's `-prealloc` arena to give the JS wrapper a programmatic way to
// (a) request a larger arena before the next evaluation and (b) clear
// arena state without tearing down the WebAssembly.Instance.
//
// Today the V `-prealloc` arena is sized at compile time and never
// resized; the JS wrapper's documented "release memory" path is to
// drop the WebAssembly.Instance and recreate it (see 
// §D5 `cxlib.reset()`). These C ABI hooks reserve the surface so a
// future build that wires arena lifecycle to the V runtime can land
// without an ABI break.
//
// Legacy consumers shouldn't call these. Bindings that probe
// `cx_features` will see no capability bit allocated to them — they
// are not part of the parity matrix.

@[export: 'cx_wasm_set_arena_size']
pub fn cx_wasm_set_arena_size(bytes u32) int {
	// Reserved for future arena lifecycle wiring;
	// today the V `-prealloc` arena is sized at build time so we
	// just accept the value and report success. The hand-written
	// JS wrapper exposes this as `cxlib.setArenaSize(bytes)` per
	// Uses `u32` rather than `u64` so the symbol is
	// JS-callable directly (wasm32 i64 round-trips through JS as
	// BigInt). 4 GiB ceiling matches wasm32's linear-memory cap.
	_ := bytes
	return 0
}

@[export: 'cx_wasm_reset']
pub fn cx_wasm_reset() int {
	// No-op today. The documented reset path is JS-side instance
	// re-instantiation. Reserved for future arena
	// lifecycle wiring.
	return 0
}

// ── version ───────────────────────────────────────────────────────────────────

const cx_version_str = '0.8.0'
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
// | bit 31 (0x80000000) | bit 32 (0x100000000) | bit 33 (0x200000000)
// = 0x3df7fffff. Bit 27 is the streaming-write API
// (`cx_events_writer_*` / spec/streaming.md §6 /
// spec/abi.md §2.15) — 25 C ABI symbols, wired in Phase 7.74g.
// Bit 28 is the CX code evaluator (`cx_code_eval*` /
// spec/code.md / spec/abi.md §2.16.1) — replaces the legacy
// `cx_eval*` POC surface at Phase 7.3; cf. `vcx/code/cabi.v`.
// Bit 29 is collection literals + CXDM v1.1 + labeled-form parser
// (/§D7/§D23 / spec/abi.md §1.5) — V parser + AST +
// canonical / hash / schema validator extensions; capability gates
// the labeled-form alias for EvalDirective.
// Bit 30 is parameterized templates / spec/abi.md
// §1.5 — V evaluator lexical-scope frames, positional template-
// invocation, W018 arg-count mismatch, `?def` 3-slot positional
// shape with legacy 2-slot auto-expansion.
// Bit 31 is the v0.8.0 CX program diagram renderer
// (`cx_code_diagram` / spec/abi.md §2.16.2) — Mermaid
// emit from the wasm-safe path with auto-detection
// (`flowchart TD` for code sources containing a top-level
// EvalDirective, `erDiagram` for data sources). SVG/PNG remain
// CLI-only (graphviz shell-out). Exported from `vcx/code/cabi.v`
// per import-cycle constraints; cap bit advertised here because
// `cx_features` is the single capability-bitmask surface per
// spec/abi.md §3.
// Bit 32 is the v0.8.0 CX code tree projection
// (`cx_code_tree` /) — new C ABI symbol
// returning JSON projection of the parsed source; every node
// carries `{kind, name?, value?, loc:{start,end}, children?}`
// with UTF-8 byte offsets into the original source. Enables
// the bidirectional selection bridge between the playground
// tree pane and source pane without further ABI
// plumbing. Re-framed at v0.8.0 (the earlier
// gate-17 framing — "no new C ABI; JS-side `cx_to_json` walk"
// — never shipped). Phase 2.11 lands a stub returning a
// minimal-shape JSON for the source's root element; (Q) agent
// fills in the real walker contract.
// Bit 33 is atom scalar kind (`spec/core/ast.md`, `spec/core/ast-bin.md`).
// Set when the binding parses, evaluates, renders, and round-trips
// `:NAME` atom literals through ast_bin with type-strict equality
// (atom never equals same-named string per §D2). V native impl landed
// this session (vcx/code/parser.v parse_atom_literal + vcx/cx/ast.v
// ScalarType.atom_type); Tier-1 binding catchup tracked in
// spec/misc/parity-matrix.md.
const cx_features_str = '0x3df7fffff'

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

// cx_to_cx_with_include_root: parse CX text with opt-in spec/include.md
// resolution (GG3) then re-emit the resolved document as
// canonical CX text. NULL / empty `include_root` is a no-op
// equivalent to `cx_to_cx` (directives preserved).
@[export: 'cx_to_cx_with_include_root']
pub fn cx_to_cx_with_include_root(input &char, include_root &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	root_str := if isnil(include_root) {
		''
	} else {
		unsafe { cstring_to_vstring(include_root) }
	}
	doc := parse_with_include_root(src, root_str) or { return c_err(err.msg(), err_out) }
	return c_string(emit_cx(doc))
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
	doc := parse_to_doc('json', src) or { return c_err(err.msg(), err_out) }
	return c_string(emit_ast_json(doc))
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

// cx_to_ast_bin_with_include_root: same as cx_to_ast_bin but with
// opt-in `?include` resolution per spec/include.md §2.2 (GG3
// / GG4). NULL or empty `include_root` disables resolution.
// Capability bit 28 widened semantics per EE3 Amendment
// #2 R2 signals presence.
@[export: 'cx_to_ast_bin_with_include_root']
pub fn cx_to_ast_bin_with_include_root(input &char, include_root &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	root_str := if isnil(include_root) {
		''
	} else {
		unsafe { cstring_to_vstring(include_root) }
	}
	doc := parse_with_include_root(src, root_str) or { return c_err(err.msg(), err_out) }
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

// ── CXPath C ABI (RETIRED, Phase 7) ────────────────────────────────────
//
// CX code is the unified pattern/query/transform language per
// Bindings query/transform documents via `cx_code_eval*`
// with a `[?for pattern :yield expr]` program — see `spec/code.md §5`.

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
	doc := parse_to_doc('json', src) or { return c_err(err.msg(), err_out) }
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

// Output symbols: binary AST → <format>.

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

// ── CXCol v1 — strict canonical binary data format (Phase 2b.6) ───────────────

// cx_to_data_bin: parse CX text and return CXCol v1 strict-canonical
// bytes per spec/core/data-bin.md. Output framed as [u32 LE size][payload];
// caller reads the first 4 bytes for size, then the payload, frees
// the buffer with cx_free. See spec/abi.md §2.4.
@[export: 'cx_to_data_bin']
pub fn cx_to_data_bin(input &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	doc := parse(src) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

// cx_to_data_bin_with_include_root: same as cx_to_data_bin but with
// opt-in `?include` resolution per spec/include.md §2.2 (GG3).
// NULL or empty `include_root`
// disables resolution (matches the default of cx_to_data_bin).
// Non-empty `include_root` must be an absolute path; relative paths
// are resolved against the current working directory before being
// passed through to the resolver.
//
// Errors: any of the E901-E911 codes per spec/include.md §8 surface
// through `err_out` with the cx-err: prefix.
//
// Capability bit 28 (widened per EE3 Amendment
// #2 R2) signals presence; bindings query `cx_features` and may
// degrade to cx_to_data_bin when bit 28 is clear (older libcx).
@[export: 'cx_to_data_bin_with_include_root']
pub fn cx_to_data_bin_with_include_root(input &char, include_root &char, err_out &&char) &char {
	src := unsafe { cstring_to_vstring(input) }
	root_str := if isnil(include_root) {
		''
	} else {
		unsafe { cstring_to_vstring(include_root) }
	}
	doc := parse_with_include_root(src, root_str) or { return c_err(err.msg(), err_out) }
	bytes := emit_data_bin(doc)
	return framed_bytes_to_heap(bytes)
}

// cx_from_data_bin: decode CXCol v1 framed bytes and return canonical
// CX text. Input must be the framed layout [u32 LE size][payload]
// produced by cx_to_data_bin. The function reads size from the first
// 4 bytes; null-termination is not required.
@[export: 'cx_from_data_bin']
pub fn cx_from_data_bin(input &char, err_out &&char) &char {
	bytes := framed_input_to_bytes(input) or { return c_err(err.msg(), err_out) }
	out := from_data_bin(bytes) or { return c_err(err.msg(), err_out) }
	return c_string(out)
}

// ── CXCol schema-driven encoding C ABI ( D3, Phase 7.73) ─────────────
//
// 10 symbols enable schema-driven CXCol encoding (header flag bit 1) per
// spec/core/data-bin.md §3.13. Each loader takes the source text plus a
// `.cxs` schema text and emits CXCol framed bytes with the schema
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
	doc := parse_to_doc('json', src) or { return c_err(err.msg(), err_out) }
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
// :table-bodied element and emit the CXCol chunked-table form (`0x63`)
// per spec/core/data-bin.md §3.11. Default chunk policy: 2^20 rows per
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
// header. Callers passing arbitrary non-CXCol bytes (or a NUL-terminated
// C string) trigger an OOB read sized by whatever the first 4 bytes
// happen to look like. Newer bindings should call the
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

// ── CXCol v1 — one-shot loaders/dumpers (Phase 7.28) ──────────────────────────
//
// Per spec/abi.md §2.4–§2.5, these symbols compose existing format
// parsers with emit_data_bin (loaders) and parse_data_bin with the
// existing format emitters (dumpers). They close the v2-required gap
// previously flagged in cx_features bit 5. Each loader/dumper is a
// thin composition; the heavy lifting lives in the per-format
// parsers and emitters that already ship.

// ── loaders: <fmt> text → CXCol v1 framed bytes ───────────────────────────────

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
	doc := parse_to_doc('json', src) or { return c_err(err.msg(), err_out) }
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

// ── dumpers: CXCol v1 framed bytes → <fmt> text ───────────────────────────────

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
// `[u32 LE size][CXCol payload]` form used elsewhere in this ABI; fd
// variants operate on bare CXCol bytes (the file's length is implicit
// from the fd, and streaming writers cannot prefix their output with
// a size unknown until end-of-table). See data_bin_streaming.v for
// the full discussion.

// cx_table_reader_open: open a streaming reader over a framed CXCol
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
// descriptor positioned at the CXCol magic (no framing prefix).
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
// [u32 LE size] framing prefix (matches CXCol convention)
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

// ── Explicit-length C ABI variants (Phase 7.74c hardening) ──────────────────
//
// These `_with_len` symbols validate a caller-supplied byte count
// against the framed input's embedded size header before reading,
// closing the OOB-read footgun the implicit-length originals expose
// when handed non-CXCol bytes. Newer bindings SHOULD
// call these in preference to the implicit-length forms; the
// originals stay for back-compat through 1.0 per spec/abi.md §1.1.
//
// The `_with_len` variants exist for every C ABI symbol that takes
// framed CXCol bytes as `const char*`. New format-specific decoders
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
// + capability bit are part of the ABI lock so
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
// removed 2026-05-10 when was superseded by . CX code
// is the only output-shape mechanism; see `cx_code_eval*` below and
// `spec/abi.md §2.16`. The W011 "shape engine not yet implemented"
// path no longer exists.)

// cx_events_writer_close_get_bytes: in-memory writers — emit implicit
// EndDoc (W004 if elements remain unclosed), then return the accumulated
// output buffer wrapped in the standard CXCol-style `[u32 LE size][payload]`
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
// CXCol-style buffer with a 4-byte LE size prefix. The `_with_len`
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

// ── Legacy cx_eval* family (RETIRED, Phase 7) ───────────────────────────────
//
// The `cx_eval` / `cx_eval_with_len` / `cx_eval_streaming`
// symbols were the POC entry-points for the cxl evaluator
// (vcx/cx/cxl.v, deleted in this phase). They are removed in
// Phase 7. The replacement is the
// `cx_code_eval*` family exported from `vcx/code/cabi.v`
// — see `spec/abi.md §2.16.1` and `spec/audits/code_abi_v1.md`.
//
// This is a hard rename with no deprecated alias: FFI consumers do
// a single substitution `cx_eval` → `cx_code_eval` and rebuild.
// No released binary carries both names.

// ── v0.8.0 cx_code_tree (Phase 2.11 /) ─────────────────────
//
// New C ABI symbol exported at v0.8.0 (two-export carve-out,
// JSON contract, cap-bit framing per spec/core/ast.md). Returns a JSON
// projection of the parsed source where every node carries
// `{kind, name?, value?, loc:{start,end}, children?}` — the `loc`
// byte offsets enable the bidirectional selection bridge between
// the playground tree pane and source pane (D5) without further
// ABI plumbing.
//
// **Phase 2.11 stub.** This export is wired in `vcx/cx/` (here, not
// `vcx/code/`) so it composes against the host data model without
// re-opening the import cycle that drove `cx_code_eval*` /
// `cx_code_diagram` into `vcx/code/cabi.v`. The full tree-walker
// implementation depends on (Q) agent's `vcx/cx/code_diagram.v`
// landing (see brief Phase 2.10) — until then, this returns a
// minimal-shape JSON object describing the source as a single root
// element with `loc:{start:0,end:source_len}`. The shape is
// schema-correct (required fields present, no
// extraneous fields, `loc.end - loc.start` resolves to the source
// substring length) so playground glue + binding tests can wire
// against the stable contract before the walker lands. Replace the
// stub body with a call to `cx.code_tree(src_v)` once the V-side
// implementation appears in this module.
//
// Signature:
//   const char* cx_code_tree(const char* source, size_t source_len,
//                            size_t* out_len);
//
// Returns: heap-allocated UTF-8 JSON; caller frees via `cx_free`.
// `out_len` (if non-NULL) receives the byte length of the JSON
// payload (NUL terminator NOT included), matching the v0.8.0
// length-out-parameter convention. On error, returns NULL and (if
// `out_len` non-NULL) sets `*out_len = 0`. Cap bit 32
// (`0x100000000`) advertises this symbol; bindings probe
// `cx_features` and degrade gracefully when unset.

@[export: 'cx_code_tree']
pub fn cx_code_tree(source &char, source_len usize, out_len &usize) &char {
	// Empty / NULL input returns a minimal shape with loc.{start,end} = 0
	// so the JSON-parser side of the binding always sees a well-formed
	// object (every node has {kind, loc}).
	if source == unsafe { nil } || source_len == 0 {
		empty := '{"kind":"element","name":"root","loc":{"start":0,"end":0},"children":[]}'
		if out_len != unsafe { nil } {
			unsafe { *out_len = usize(empty.len) }
		}
		return c_string(empty)
	}
	// Phase 2.11 finish: invoke the real walker. The walker scans the
	// source text directly and emits the JSON tree.
	src := unsafe { tos(&u8(source), int(source_len)) }
	json := code_tree(src) or {
		// Defensive: walker is non-raising in practice; surface as
		// the empty-root shape rather than NULL so bindings never see
		// a partial document.
		end := int(source_len)
		fallback := '{"kind":"element","name":"root","loc":{"start":0,"end":${end}},"children":[]}'
		if out_len != unsafe { nil } {
			unsafe { *out_len = usize(fallback.len) }
		}
		return c_string(fallback)
	}
	// Avoid pointer-aliasing risk by detaching the bytes from `src`.
	out := json.clone()
	if out_len != unsafe { nil } {
		unsafe { *out_len = usize(out.len) }
	}
	return c_string(out)
}

