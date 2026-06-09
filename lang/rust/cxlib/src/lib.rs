pub mod ast;
pub mod atom;
pub mod binary;
pub mod code;
pub mod data_bin;
pub mod event_writer;
pub mod fixtures;
pub mod idioms;
pub mod schema_driven;
pub mod stream;
pub mod streaming_table;
pub mod validate;
pub mod table;

// Layer-1 atom re-exports — keep the top-level surface flat
// per spec/bindings.md (Rust uses snake_case + free functions at the
// crate root for the Layer-1 primitives).
pub use atom::{Atom, is_atom, atom_name};

#[cfg(feature = "arrow")]
pub mod arrow;

#[cfg(feature = "parquet")]
pub mod parquet;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;

// ── C declarations ─────────────────────────────────────────────────────────────

extern "C" {
    // Thread-init handshake (spec/abi.md §1.6, capability bit 26).
    // See ensure_thread() below — the binding calls cx_init once at first
    // use and cx_thread_register once per OS worker thread that touches
    // libcx. Without this, cargo's test harness aborts with
    // "Collecting from unknown thread" on the first GC cycle from a
    // non-main thread. Returns 0 on success / duplicate-registration,
    // -1 on real failure.
    fn cx_init() -> std::os::raw::c_int;
    fn cx_thread_register() -> std::os::raw::c_int;
    fn cx_thread_unregister() -> std::os::raw::c_int;

    fn cx_free(s: *mut c_char);
    fn cx_version() -> *mut c_char;
    fn cx_abi_version() -> *mut c_char;
    fn cx_features() -> *mut c_char;

    // CX input
    fn cx_to_cx         (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_cx_compact (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_to_cx     (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // v0.7.6 CX code evaluator family (spec/abi.md §2.16.1).
    // Replaces cx_eval / cx_eval_streaming retired in Phase 7. The
    // Rust binding only links the *_with_len + *_streaming variants —
    // the NUL-terminated `cx_code_eval` symbol is exposed by libcx
    // but never used here (we always have an explicit length and
    // bytes may contain NULs per spec/abi.md §2.14).
    fn cx_code_eval_with_len(
        input: *const c_char,        input_len: usize,
        program: *const c_char,      program_len: usize,
        output_target: *const c_char,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;
    fn cx_code_eval_streaming(
        input: *const c_char,        input_len: usize,
        program: *const c_char,      program_len: usize,
        output_target: *const c_char,
        write_cb: extern "C" fn(*const c_char, usize, *mut c_void) -> c_int,
        user: *mut c_void,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;
    // v0.7.6 program diagram renderer (spec/abi.md §2.16.2, gate 17).
    // Error wire format: in-band CXERnnnn:msg in the returned string.
    // Symbol name on the C side is `cx_code_diagram`; aliased on the
    // Rust side to avoid a collision with the public `cx_code_diagram`
    // wrapper free function below.
    #[link_name = "cx_code_diagram"]
    fn ffi_cx_code_diagram(
        source: *const c_char, source_len: usize,
        format: *const c_char, format_len: usize,
    ) -> *mut c_char;
    // v0.8.0 cx_code_tree (Phase 2.11, cap bit 32).
    // Returns heap-allocated UTF-8 JSON; caller frees via cx_free.
    // `out_len` (if non-NULL) receives the byte length of the JSON
    // payload (NUL terminator NOT included). On error returns NULL
    // and sets `*out_len = 0`. Aliased on the Rust side for the same
    // reason as `ffi_cx_code_diagram`.
    #[link_name = "cx_code_tree"]
    fn ffi_cx_code_tree(
        source: *const c_char, source_len: usize,
        out_len: *mut usize,
    ) -> *mut c_char;

    // XML input
    fn cx_xml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // JSON input
    fn cx_json_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // YAML input
    fn cx_yaml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // TOML input
    fn cx_toml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Binary output (CX input only)
    fn cx_to_ast_bin   (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_ast_bin_with_include_root(
        input: *const c_char, include_root: *const c_char, err_out: *mut *mut c_char,
    ) -> *mut c_char;
    fn cx_to_events_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // (CXPath path-tracking C ABI cx_select_all_paths was retired at
    // v0.7.6 Phase 7. Equivalent: cx_code_eval with a `//path` CXPath
    // value — see vcx/README.md migration table.)

    // Phase 5 / CB-1 — ast_bin → text format
    fn cx_ast_bin_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 5 / CB-2 — text → ast_bin (returns framed binary)
    fn cx_xml_to_ast_bin (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 5 / CB-4 — events handle API
    fn cx_events_open (input: *const c_char, err_out: *mut *mut c_char) -> *mut std::ffi::c_void;
    fn cx_events_next (handle: *mut std::ffi::c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_close(handle: *mut std::ffi::c_void);

    // Phase 6 — canonical-form tooling (spec/abi.md §2.6)
    fn cx_fmt      (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_canonical(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_hash     (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_eq       (a: *const c_char, b: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.47 — cx diff. format = "unified" | "json" | "summary".
    fn cx_diff     (a: *const c_char, b: *const c_char, format: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.49 — cx lint. format = "text" | "json" | "summary".
    fn cx_lint     (input: *const c_char, format: *const c_char, disabled: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.65 — ID/IDREF C ABI.
    fn cx_id_lookup  (input: *const c_char, id: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_resolve_ref(input: *const c_char, r#ref: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    // (cx_node_id was retired at v0.7.6 Phase 7 alongside CXPath. The
    // equivalent in v0.8.0 is cx_code_eval with a `//pattern` CXPath
    // value, then reading @id from each match.)

}

/// Internal helper: free a `*mut c_char` previously returned by libcx.
pub(crate) unsafe fn free_libcx_string(ptr: *mut c_char) {
    cx_free(ptr);
}

// ── Thread-init handshake (spec/abi.md §1.6) ─────────────────────────────────

/// Run libcx's thread-init handshake for the current thread. Cheap on
/// every call after the first per-thread call: a single `Once` check
/// plus a thread-local boolean.
///
/// Must be called before any other `cx_*` FFI invocation on a host
/// thread that wasn't spawned by V's runtime (cargo test workers,
/// rayon workers, application thread pools, etc.). Calling on a thread
/// that doesn't strictly need it is a no-op at libgc level.
///
/// Registration is auto-released at thread exit via a thread-local
/// `Drop` guard — Boehm GC would otherwise retain the now-dead pthread
/// in its tracked-thread list and abort with "thread_suspend failed"
/// the next time the GC marker tried to stop the world (manifests
/// quickly under cargo's `--test-threads=1` test harness, which spawns
/// a fresh worker per test).
struct ThreadGuard;
impl Drop for ThreadGuard {
    fn drop(&mut self) {
        unsafe { cx_thread_unregister(); }
    }
}

#[inline]
pub(crate) fn ensure_thread() {
    static INIT: std::sync::Once = std::sync::Once::new();
    INIT.call_once(|| { unsafe { cx_init(); } });
    thread_local! {
        static GUARD: ThreadGuard = {
            unsafe { cx_thread_register(); }
            ThreadGuard
        };
    }
    GUARD.with(|_| ());
}

// ── Phase 5 helpers ──────────────────────────────────────────────────────────

/// Call a cx_ast_bin_to_<format> function with FRAMED binary AST input.
pub(crate) fn call_ast_bin_to_text(ast_bin: &[u8], fn_name: &str) -> Result<String, String> {
    if ast_bin.is_empty() {
        return Err("ast_bin_to_*: empty input".to_owned());
    }
    ensure_thread();
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe {
        let p = ast_bin.as_ptr() as *const c_char;
        match fn_name {
            "cx_ast_bin_to_cx"   => cx_ast_bin_to_cx  (p, &mut err_ptr),
            "cx_ast_bin_to_xml"  => cx_ast_bin_to_xml (p, &mut err_ptr),
            "cx_ast_bin_to_json" => cx_ast_bin_to_json(p, &mut err_ptr),
            "cx_ast_bin_to_yaml" => cx_ast_bin_to_yaml(p, &mut err_ptr),
            "cx_ast_bin_to_toml" => cx_ast_bin_to_toml(p, &mut err_ptr),
            other => return Err(format!("unknown ast_bin_to_* function: {}", other)),
        }
    };
    if raw.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(raw).to_string_lossy().into_owned() };
    unsafe { cx_free(raw) };
    Ok(s)
}

/// Call a cx_<format>_to_ast_bin function and return the AST bin
/// payload (frame stripped).
pub(crate) fn call_text_to_ast_bin(input: &str, fn_name: &str) -> Result<Vec<u8>, String> {
    ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw_ptr: *mut c_char = unsafe {
        match fn_name {
            "cx_xml_to_ast_bin"  => cx_xml_to_ast_bin (c_input.as_ptr(), &mut err_ptr),
            "cx_json_to_ast_bin" => cx_json_to_ast_bin(c_input.as_ptr(), &mut err_ptr),
            "cx_yaml_to_ast_bin" => cx_yaml_to_ast_bin(c_input.as_ptr(), &mut err_ptr),
            "cx_toml_to_ast_bin" => cx_toml_to_ast_bin(c_input.as_ptr(), &mut err_ptr),
            other => return Err(format!("unknown text_to_ast_bin function: {}", other)),
        }
    };
    if raw_ptr.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let payload = unsafe {
        let hdr = std::slice::from_raw_parts(raw_ptr as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let payload_ptr = raw_ptr.add(4) as *const u8;
        let bytes = std::slice::from_raw_parts(payload_ptr, size).to_vec();
        cx_free(raw_ptr);
        bytes
    };
    Ok(payload)
}

// ── Events handle API (Phase 5 / CB-4) ───────────────────────────────────────

/// Pull-based iterator over CX streaming events backed by the
/// cx_events_open / cx_events_next / cx_events_close handle API.
/// Replaces the prior eager-buffered cx_to_events_bin path.
pub struct EventStream {
    handle: *mut std::ffi::c_void,
    closed: bool,
}

impl EventStream {
    /// Open a streaming handle for the given CX input.
    pub fn open(input: &str) -> Result<Self, String> {
        ensure_thread();
        let c_input = CString::new(input).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe { cx_events_open(c_input.as_ptr(), &mut err_ptr) };
        if h.is_null() {
            if err_ptr.is_null() {
                return Err("cx_events_open: unknown error".to_owned());
            }
            let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
            unsafe { cx_free(err_ptr) };
            return Err(msg);
        }
        Ok(EventStream { handle: h, closed: false })
    }

    /// Pull the next event. Returns `Ok(None)` on EOF.
    pub fn next_event(&mut self) -> Result<Option<stream::StreamEvent>, String> {
        if self.closed || self.handle.is_null() {
            return Ok(None);
        }
        ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let raw = unsafe { cx_events_next(self.handle, &mut err_ptr) };
        if raw.is_null() {
            // NULL with err = error; NULL without err = EOF.
            if !err_ptr.is_null() {
                let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
                unsafe { cx_free(err_ptr) };
                self.close();
                return Err(msg);
            }
            self.close();
            return Ok(None);
        }
        let payload = unsafe {
            let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
            let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
            let payload_ptr = raw.add(4) as *const u8;
            let bytes = std::slice::from_raw_parts(payload_ptr, size).to_vec();
            cx_free(raw);
            bytes
        };
        Ok(Some(binary::decode_one_event(&payload)?))
    }

    /// Release the underlying handle. Idempotent; called automatically on Drop.
    pub fn close(&mut self) {
        if self.closed || self.handle.is_null() {
            self.closed = true;
            self.handle = ptr::null_mut();
            return;
        }
        unsafe { cx_events_close(self.handle) };
        self.closed = true;
        self.handle = ptr::null_mut();
    }
}

impl Drop for EventStream {
    fn drop(&mut self) { self.close(); }
}

// (select_all_paths helper retired at v0.7.6 Phase 7 alongside CXPath.
// Equivalent: build a `//pattern` CXPath value and eval it
// with eval_code.)

// ── internal helpers ───────────────────────────────────────────────────────────

type CxFn = unsafe extern "C" fn(*const c_char, *mut *mut c_char) -> *mut c_char;

fn call(f: CxFn, input: &str) -> Result<String, String> {
    ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { f(c_input.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

/// Call a binary C function and return the payload bytes.
///
/// The C function returns a buffer with layout:
///   [u32 LE: payload_size][payload bytes]
/// This helper reads `payload_size` bytes starting at offset 4, frees the C
/// buffer, and returns the payload as a `Vec<u8>`.
pub(crate) fn call_bin(input: &str, func: &str) -> Result<Vec<u8>, String> {
    ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw_ptr: *mut c_char = unsafe {
        match func {
            "cx_to_ast_bin"    => cx_to_ast_bin   (c_input.as_ptr(), &mut err_ptr),
            "cx_to_events_bin" => cx_to_events_bin(c_input.as_ptr(), &mut err_ptr),
            other => return Err(format!("unknown binary function: {}", other)),
        }
    };
    extract_bin_payload(raw_ptr, err_ptr)
}

/// call_bin_with_include_root: parse + resolve includes via the
/// spec/include.md §1-§8 engine (v0.7.0 GG4). Empty include_root is
/// a no-op equivalent to call_bin(input, "cx_to_ast_bin").
pub(crate) fn call_bin_with_include_root(input: &str, include_root: &str) -> Result<Vec<u8>, String> {
    ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let c_root = CString::new(include_root).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw_ptr: *mut c_char = unsafe {
        cx_to_ast_bin_with_include_root(c_input.as_ptr(), c_root.as_ptr(), &mut err_ptr)
    };
    extract_bin_payload(raw_ptr, err_ptr)
}

fn extract_bin_payload(raw_ptr: *mut c_char, err_ptr: *mut c_char) -> Result<Vec<u8>, String> {
    if raw_ptr.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let payload = unsafe {
        let hdr = std::slice::from_raw_parts(raw_ptr as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let payload_ptr = raw_ptr.add(4) as *const u8;
        let bytes = std::slice::from_raw_parts(payload_ptr, size).to_vec();
        cx_free(raw_ptr);
        bytes
    };
    Ok(payload)
}

// ── version + capability bitmask ──────────────────────────────────────────────

pub fn version() -> String {
    ensure_thread();
    unsafe {
        let ptr = cx_version();
        let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        cx_free(ptr);
        s
    }
}

/// Returns libcx's ABI major.minor version string (e.g., `"2.0"`).
/// Bindings call this on load and refuse mismatched majors per
/// spec/abi.md §1.1.
pub fn abi_version() -> String {
    ensure_thread();
    unsafe {
        let ptr = cx_abi_version();
        let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        cx_free(ptr);
        s
    }
}

/// Returns the libcx capability bitmask as a u64. Parses the
/// NUL-terminated lowercase hex string from `cx_features()` per
/// spec/abi.md §3. Returns 0 on parse failure (zero bitmask cleanly
/// disables every capability gate; for explicit error handling see
/// the per-capability probes in this module).
///
/// To check for atom support (cap bit 33):
///
/// ```ignore
/// if cxlib::features() & (1u64 << 33) != 0 { /* atoms available */ }
/// ```
pub fn features() -> u64 {
    ensure_thread();
    let s = unsafe {
        let ptr = cx_features();
        let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        cx_free(ptr);
        s
    };
    // Strip leading `0x` if present, then parse as hex.
    let trimmed = s.strip_prefix("0x").unwrap_or(&s);
    u64::from_str_radix(trimmed, 16).unwrap_or(0)
}

// ── public API ─────────────────────────────────────────────────────────────────

macro_rules! wrap {
    ($($pub_name:ident => $c_name:ident;)*) => {
        $(
            pub fn $pub_name(input: &str) -> Result<String, String> {
                call($c_name, input)
            }
        )*
    };
}

wrap! {
    // CX input
    to_cx         => cx_to_cx;
    to_cx_compact => cx_to_cx_compact;
    ast_to_cx     => cx_ast_to_cx;
    to_xml  => cx_to_xml;
    to_ast  => cx_to_ast;
    to_json => cx_to_json;
    to_yaml => cx_to_yaml;
    to_toml => cx_to_toml;

    // XML input
    xml_to_cx   => cx_xml_to_cx;
    xml_to_xml  => cx_xml_to_xml;
    xml_to_ast  => cx_xml_to_ast;
    xml_to_json => cx_xml_to_json;
    xml_to_yaml => cx_xml_to_yaml;
    xml_to_toml => cx_xml_to_toml;

    // JSON input
    json_to_cx   => cx_json_to_cx;
    json_to_xml  => cx_json_to_xml;
    json_to_ast  => cx_json_to_ast;
    json_to_json => cx_json_to_json;
    json_to_yaml => cx_json_to_yaml;
    json_to_toml => cx_json_to_toml;

    // YAML input
    yaml_to_cx   => cx_yaml_to_cx;
    yaml_to_xml  => cx_yaml_to_xml;
    yaml_to_ast  => cx_yaml_to_ast;
    yaml_to_json => cx_yaml_to_json;
    yaml_to_yaml => cx_yaml_to_yaml;
    yaml_to_toml => cx_yaml_to_toml;

    // TOML input
    toml_to_cx   => cx_toml_to_cx;
    toml_to_xml  => cx_toml_to_xml;
    toml_to_ast  => cx_toml_to_ast;
    toml_to_json => cx_toml_to_json;
    toml_to_yaml => cx_toml_to_yaml;
    toml_to_toml => cx_toml_to_toml;
}

// ── binary API ─────────────────────────────────────────────────────────────────

/// Parse a CX string into a `Document` AST via the binary protocol.
/// Runs `ast::resolve_namespaces` on the decoded document so accessors
/// `Element::local_name()` / `Element::namespace_uri()` (and the same
/// on `Attr`) return the resolved expanded-name fields.
pub fn parse(cx_str: &str) -> Result<ast::Document, String> {
    let data = call_bin(cx_str, "cx_to_ast_bin")?;
    let mut doc = binary::decode_ast(&data)?;
    ast::resolve_namespaces(&mut doc);
    Ok(doc)
}

// ── Phase 6 / canonical-form tooling (spec/abi.md §2.6) ──────────────────────

/// Lossless canonical text CX. Preserves comments/anchors; normalizes
/// presentation. Idempotent: `fmt(fmt(x)) == fmt(x)`.
pub fn fmt(input: &str) -> Result<String, String> { call(cx_fmt, input) }

/// Strict canonical text CX. Strips presentation; byte-identical for
/// data-equivalent inputs.
pub fn canonical(input: &str) -> Result<String, String> { call(cx_canonical, input) }

/// SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes.
pub fn hash(input: &str) -> Result<String, String> { call(cx_hash, input) }

/// True iff `strict-canonical(a) == strict-canonical(b)`.
pub fn eq(a: &str, b: &str) -> Result<bool, String> {
    ensure_thread();
    let ca = CString::new(a).map_err(|e| e.to_string())?;
    let cb = CString::new(b).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { cx_eq(ca.as_ptr(), cb.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s == "1")
}

/// Style + correctness warnings. `format` is `"text"`, `"json"`, or
/// `"summary"`. `disabled` is a comma-separated list of check IDs to
/// suppress (`""` runs all). Empty result means no findings.
pub fn lint(input: &str, format: &str, disabled: &str) -> Result<String, String> {
    ensure_thread();
    let ci = CString::new(input).map_err(|e| e.to_string())?;
    let cf = CString::new(format).map_err(|e| e.to_string())?;
    let cd = CString::new(disabled).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { cx_lint(ci.as_ptr(), cf.as_ptr(), cd.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

/// Semantic diff between two CX inputs, walking the strict-canonical
/// forms. `format` is `"unified"`, `"json"`, or `"summary"`. Empty
/// result means data-equivalent.
pub fn diff(a: &str, b: &str, format: &str) -> Result<String, String> {
    ensure_thread();
    let ca = CString::new(a).map_err(|e| e.to_string())?;
    let cb = CString::new(b).map_err(|e| e.to_string())?;
    let cf = CString::new(format).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { cx_diff(ca.as_ptr(), cb.as_ptr(), cf.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

// ── Phase 7.65 / ID/IDREF C ABI ───────────────────────────────────

/// Shared shape for the three ID/IDREF wrappers: takes two strings and an
/// err pointer, returns `Ok(None)` for empty result, `Ok(Some(s))` for a
/// non-empty result, and `Err(...)` on parse/cxpath error.
fn call_id_abi(
    f: unsafe extern "C" fn(*const c_char, *const c_char, *mut *mut c_char) -> *mut c_char,
    input: &str,
    arg2: &str,
) -> Result<Option<String>, String> {
    ensure_thread();
    let ci = CString::new(input).map_err(|e| e.to_string())?;
    let ca = CString::new(arg2).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { f(ci.as_ptr(), ca.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    if s.is_empty() { Ok(None) } else { Ok(Some(s)) }
}

/// Evaluate a CX code program against an optional input document
/// and return the rendered output. `output_target` may be `""`
/// (default `"text"`) or one of `"text"` / `"cx"` / `"json"` /
/// `"yaml"` / `"xml"` / `"csv"` / `"tsv"` / `"mermaid"` (the last
/// renders the program AST per spec/code.md §10.1.2).
///
/// Binary-safe per spec/abi.md §2.14: routes through
/// `cx_code_eval_with_len`. NUL bytes in input or program are
/// preserved.
pub fn eval_code(input: &str, program: &str, output_target: &str) -> Result<String, String> {
    ensure_thread();
    let ct = CString::new(output_target).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe {
        cx_code_eval_with_len(
            input.as_ptr() as *const c_char, input.len(),
            program.as_ptr() as *const c_char, program.len(),
            ct.as_ptr(),
            &mut err_ptr,
        )
    };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("cx_code_eval: unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

/// Evaluate a v0.7.6 CX program with pull-based incremental output.
/// `on_chunk` is invoked with each output chunk as a `&[u8]`;
/// returning `Err(_)` aborts evaluation cleanly.
///
/// Routes through `cx_code_eval_streaming` per spec/abi.md
/// §2.16.1. The user closure is passed through the `user` pointer
/// wrapped as `*mut StreamState`; the exported trampoline
/// `rust_stream_trampoline` unwraps and dispatches per chunk.
pub fn eval_code_streaming<F>(
    input: &str,
    program: &str,
    output_target: &str,
    mut on_chunk: F,
) -> Result<(), String>
where
    F: FnMut(&[u8]) -> Result<(), String>,
{
    ensure_thread();
    let ct = CString::new(output_target).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let mut state: StreamState = StreamState {
        cb: &mut on_chunk as &mut dyn FnMut(&[u8]) -> Result<(), String>,
        captured_err: None,
    };
    let user_ptr = &mut state as *mut StreamState as *mut c_void;
    unsafe {
        cx_code_eval_streaming(
            input.as_ptr() as *const c_char, input.len(),
            program.as_ptr() as *const c_char, program.len(),
            ct.as_ptr(),
            rust_stream_trampoline,
            user_ptr,
            &mut err_ptr,
        );
    }
    if !err_ptr.is_null() {
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    if let Some(e) = state.captured_err {
        return Err(e);
    }
    Ok(())
}

/// Render a CX source as a diagram (cap bit 31).
/// The returned text is a Mermaid `flowchart TD` with the original
/// source embedded as `%%cx:<base64>%%` for round-trip recovery
/// (gate-9 contract).
///
/// `format` MUST be `"mermaid"` at v0.8.0; other formats return
/// `CXER0001` (SVG/PNG go through the CLI tier per audit §D5).
/// Error wire format: in-band `CXERnnnn:msg` in the returned
/// string — callers detect by prefix and the result is re-mapped
/// to `Err("cx-err:CXERnnnn:msg")` for parity with the other
/// helpers in this module.
///
/// Canonical v0.8.0 name: mirrors the C ABI
/// symbol `cx_code_diagram` directly so Layer-1 conformance
/// fixtures (`conformance/binding_api.txt`) bind against the
/// shared vocabulary.
pub fn cx_code_diagram(source: &str, format: &str) -> Result<String, String> {
    ensure_thread();
    let raw = unsafe {
        ffi_cx_code_diagram(
            source.as_ptr() as *const c_char, source.len(),
            format.as_ptr() as *const c_char, format.len(),
        )
    };
    if raw.is_null() {
        return Err("cx_code_diagram: unknown error".to_owned());
    }
    let s = unsafe { CStr::from_ptr(raw).to_string_lossy().into_owned() };
    unsafe { cx_free(raw) };
    if s.starts_with("CXER") {
        return Err(format!("cx-err:{}", s));
    }
    Ok(s)
}

/// JSON projection of the parsed CX source (cap
/// bit 32). Each node carries
/// `{kind, name?, value?, loc:{start,end}, children?}`; the `loc`
/// byte offsets index into the original UTF-8 source so the
/// playground bidirectional selection bridge can wire against
/// stable contracts.
///
/// The Phase 2.11 stub returns a single-root element with
/// `loc:{0,len(source)}`; this wrapper is forward-compatible with
/// both the stub and the eventual full walker.
///
/// Returns `Err` on allocation failure (NULL return) or invalid
/// JSON payload (defensive — the V emitter guarantees well-formed
/// JSON).
pub fn cx_code_tree(source: &str) -> Result<serde_json::Value, String> {
    ensure_thread();
    let mut out_len: usize = 0;
    let raw = unsafe {
        ffi_cx_code_tree(
            source.as_ptr() as *const c_char, source.len(),
            &mut out_len as *mut usize,
        )
    };
    if raw.is_null() {
        return Err("cx_code_tree: NULL return (allocation failure)".to_owned());
    }
    // Slice by out_len to be NUL-safe in case the JSON ever embeds
    // NUL bytes (it shouldn't, but the C ABI returns the length so
    // we honour it).
    let payload: &[u8] = if out_len == 0 {
        unsafe { CStr::from_ptr(raw).to_bytes() }
    } else {
        unsafe { std::slice::from_raw_parts(raw as *const u8, out_len) }
    };
    let text = std::str::from_utf8(payload)
        .map_err(|e| format!("cx_code_tree: payload is not valid UTF-8: {}", e))?
        .to_owned();
    unsafe { cx_free(raw) };
    serde_json::from_str::<serde_json::Value>(&text)
        .map_err(|e| format!("cx_code_tree: payload is not valid JSON: {}", e))
}

/// Re-export of `eval_code` under the canonical name
/// (`cx_code_eval`) for Layer-1 vocabulary symmetry with
/// `cx_code_diagram` / `cx_code_tree`. Identical semantics —
/// routes through `cx_code_eval_with_len`.
#[inline]
pub fn cx_code_eval(input: &str, program: &str, output_target: &str) -> Result<String, String> {
    eval_code(input, program, output_target)
}

/// Backward-compat alias for `cx_code_diagram` — the v0.7.6 Rust
/// surface exposed `program_diagram`. Removed name from spec at
/// v0.8.0; kept here as a thin forward to ease
/// migration of existing test files (`tests/program_eval.rs`).
#[deprecated(since = "0.8.0", note = "renamed to cx_code_diagram")]
#[inline]
pub fn program_diagram(source: &str, format: &str) -> Result<String, String> {
    cx_code_diagram(source, format)
}

struct StreamState<'a> {
    cb: &'a mut dyn FnMut(&[u8]) -> Result<(), String>,
    captured_err: Option<String>,
}

extern "C" fn rust_stream_trampoline(
    bytes: *const c_char,
    n: usize,
    user: *mut c_void,
) -> c_int {
    if user.is_null() {
        return 1;
    }
    let state = unsafe { &mut *(user as *mut StreamState) };
    if state.captured_err.is_some() {
        return 1;
    }
    let slice = unsafe { std::slice::from_raw_parts(bytes as *const u8, n) };
    match (state.cb)(slice) {
        Ok(()) => 0,
        Err(e) => {
            state.captured_err = Some(e);
            1
        }
    }
}

/// Find the element declaring `#id` in `input`. Returns the AST-JSON
/// encoding of that element, or `Ok(None)` when no such ID exists.
pub fn id_lookup(input: &str, id: &str) -> Result<Option<String>, String> {
    call_id_abi(cx_id_lookup, input, id)
}

/// Resolve an IDREF to its declaring element. Observationally equivalent
/// to `id_lookup` — refs and IDs share a namespace; the separate symbol
/// exists for binding-side vocabulary clarity.
pub fn resolve_ref(input: &str, r#ref: &str) -> Result<Option<String>, String> {
    call_id_abi(cx_resolve_ref, input, r#ref)
}

// (node_id retired at v0.7.6 Phase 7. Equivalent: eval a `//pattern`
// CXPath value via eval_code, then read @id on each match.)

/// Parse a CX string into a stream of `StreamEvent`s.
///
/// v3.4 (Phase 5 / CB-4): pulls events one-by-one via the
/// `cx_events_open` / `cx_events_next` / `cx_events_close` handle API.
/// Replaces the prior eager-buffered `cx_to_events_bin` path. For true
/// pull-based streaming with caller-controlled cancellation, use
/// `EventStream::open` + `.next_event()` + `.close()` directly.
pub fn stream(cx_str: &str) -> Result<Vec<stream::StreamEvent>, String> {
    let mut s = EventStream::open(cx_str)?;
    let mut events = Vec::new();
    while let Some(ev) = s.next_event()? {
        events.push(ev);
    }
    Ok(events)
}
