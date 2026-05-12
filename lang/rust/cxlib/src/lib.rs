pub mod ast;
pub mod binary;
pub mod cxpath;
pub mod data_bin;
pub mod event_writer;
pub mod schema_driven;
pub mod stream;
pub mod streaming_table;
pub mod validate;
pub mod table;

#[cfg(feature = "arrow")]
pub mod arrow;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
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

    fn cx_free(s: *mut c_char);
    fn cx_version() -> *mut c_char;

    // CX input
    fn cx_to_cx         (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_cx_compact (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_to_cx     (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // CXL evaluator (capability bit 28; spec/cxl.md)
    fn cx_eval_cxl(
        input: *const c_char,
        program: *const c_char,
        output_target: *const c_char,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;

    // XML input
    fn cx_xml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // JSON input
    fn cx_json_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // YAML input
    fn cx_yaml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // TOML input
    fn cx_toml_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // MD input
    fn cx_md_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_ast (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Binary output (CX input only)
    fn cx_to_ast_bin   (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_events_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // CXPath path-tracking C ABI (Phase 4 / CB-5).
    fn cx_select_all_paths(input: *const c_char, expr: *const c_char,
                           err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 5 / CB-1 — ast_bin → text format
    fn cx_ast_bin_to_cx  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_ast_bin_to_md  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 5 / CB-2 — text → ast_bin (returns framed binary)
    fn cx_xml_to_ast_bin (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_ast_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_ast_bin  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 5 / CB-4 — events handle API
    fn cx_events_open (input: *const c_char, err_out: *mut *mut c_char) -> *mut std::ffi::c_void;
    fn cx_events_next (handle: *mut std::ffi::c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_close(handle: *mut std::ffi::c_void);

    // Phase 6 — canonical-form tooling (spec/abi.md §2.6)
    fn cx_fmt      (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_canonical(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_hash     (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_eq       (a: *const c_char, b: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.47 — cx diff (ADR 0012). format = "unified" | "json" | "summary".
    fn cx_diff     (a: *const c_char, b: *const c_char, format: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.49 — cx lint (ADR 0013). format = "text" | "json" | "summary".
    fn cx_lint     (input: *const c_char, format: *const c_char, disabled: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Phase 7.65 — ID/IDREF C ABI (ADR 0003).
    fn cx_id_lookup  (input: *const c_char, id: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_resolve_ref(input: *const c_char, r#ref: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_node_id    (input: *const c_char, cxpath: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

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
#[inline]
pub(crate) fn ensure_thread() {
    static INIT: std::sync::Once = std::sync::Once::new();
    INIT.call_once(|| { unsafe { cx_init(); } });
    thread_local! {
        static REGISTERED: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
    }
    REGISTERED.with(|c| {
        if !c.get() {
            unsafe { cx_thread_register(); }
            c.set(true);
        }
    });
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
            "cx_ast_bin_to_md"   => cx_ast_bin_to_md  (p, &mut err_ptr),
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
            "cx_md_to_ast_bin"   => cx_md_to_ast_bin  (c_input.as_ptr(), &mut err_ptr),
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

/// Call cx_select_all_paths and decode the framed [u32 size][payload]
/// output into a list of structural paths. Each path is a `Vec<usize>`
/// of 0-based indices: first into Document.elements, subsequent into
/// Element.items. Match order is preorder (same as cx_select_all).
pub(crate) fn select_all_paths(cx_text: &str, expr: &str) -> Result<Vec<Vec<usize>>, String> {
    ensure_thread();
    let c_input = CString::new(cx_text).map_err(|e| e.to_string())?;
    let c_expr  = CString::new(expr).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw_ptr: *mut c_char = unsafe {
        cx_select_all_paths(c_input.as_ptr(), c_expr.as_ptr(), &mut err_ptr)
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
    if payload.len() < 4 {
        return Err("cx_select_all_paths: payload too short".to_owned());
    }
    let n_paths = u32::from_le_bytes([payload[0], payload[1], payload[2], payload[3]]) as usize;
    let mut off = 4;
    let mut out = Vec::with_capacity(n_paths);
    for i in 0..n_paths {
        if off + 4 > payload.len() {
            return Err(format!("cx_select_all_paths: truncated path[{}] depth", i));
        }
        let depth = u32::from_le_bytes([
            payload[off], payload[off+1], payload[off+2], payload[off+3],
        ]) as usize;
        off += 4;
        if off + 4 * depth > payload.len() {
            return Err(format!("cx_select_all_paths: truncated path[{}] indices", i));
        }
        let mut path = Vec::with_capacity(depth);
        for _ in 0..depth {
            let v = u32::from_le_bytes([
                payload[off], payload[off+1], payload[off+2], payload[off+3],
            ]) as usize;
            path.push(v);
            off += 4;
        }
        out.push(path);
    }
    Ok(out)
}

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
    if raw_ptr.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    // Read the 4-byte length prefix then copy payload bytes.
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

// ── version ────────────────────────────────────────────────────────────────────

pub fn version() -> String {
    ensure_thread();
    unsafe {
        let ptr = cx_version();
        let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        cx_free(ptr);
        s
    }
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
    to_md   => cx_to_md;

    // XML input
    xml_to_cx   => cx_xml_to_cx;
    xml_to_xml  => cx_xml_to_xml;
    xml_to_ast  => cx_xml_to_ast;
    xml_to_json => cx_xml_to_json;
    xml_to_yaml => cx_xml_to_yaml;
    xml_to_toml => cx_xml_to_toml;
    xml_to_md   => cx_xml_to_md;

    // JSON input
    json_to_cx   => cx_json_to_cx;
    json_to_xml  => cx_json_to_xml;
    json_to_ast  => cx_json_to_ast;
    json_to_json => cx_json_to_json;
    json_to_yaml => cx_json_to_yaml;
    json_to_toml => cx_json_to_toml;
    json_to_md   => cx_json_to_md;

    // YAML input
    yaml_to_cx   => cx_yaml_to_cx;
    yaml_to_xml  => cx_yaml_to_xml;
    yaml_to_ast  => cx_yaml_to_ast;
    yaml_to_json => cx_yaml_to_json;
    yaml_to_yaml => cx_yaml_to_yaml;
    yaml_to_toml => cx_yaml_to_toml;
    yaml_to_md   => cx_yaml_to_md;

    // TOML input
    toml_to_cx   => cx_toml_to_cx;
    toml_to_xml  => cx_toml_to_xml;
    toml_to_ast  => cx_toml_to_ast;
    toml_to_json => cx_toml_to_json;
    toml_to_yaml => cx_toml_to_yaml;
    toml_to_toml => cx_toml_to_toml;
    toml_to_md   => cx_toml_to_md;

    // MD input
    md_to_cx   => cx_md_to_cx;
    md_to_xml  => cx_md_to_xml;
    md_to_ast  => cx_md_to_ast;
    md_to_json => cx_md_to_json;
    md_to_yaml => cx_md_to_yaml;
    md_to_toml => cx_md_to_toml;
    md_to_md   => cx_md_to_md;
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
///
/// Per `spec/decisions/0013-cx-lint.md`.
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
///
/// Per `spec/decisions/0012-cx-diff.md`.
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

// ── Phase 7.65 / ID/IDREF C ABI (ADR 0003) ───────────────────────────────────

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

/// Evaluate a CXL program against a CX context document and return the
/// rendered output. `output_target` may be `""` (honour the program's
/// `[?cx output-target=…]` directive, default `"text"`) or one of
/// `"text"` / `"cx"` / `"html"` at CXL 1.0 (v0.6.0).
pub fn eval_cxl(input: &str, program: &str, output_target: &str) -> Result<String, String> {
    ensure_thread();
    let ci = CString::new(input).map_err(|e| e.to_string())?;
    let cp = CString::new(program).map_err(|e| e.to_string())?;
    let ct = CString::new(output_target).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { cx_eval_cxl(ci.as_ptr(), cp.as_ptr(), ct.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err("cx_eval_cxl: unknown error".to_owned());
        }
        let msg = unsafe { CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
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

/// Run CXPath `cxpath` against `input` and return the syntactic ID of
/// the matched element. Returns `Ok(None)` when nothing matched or the
/// matched element has no ID.
pub fn node_id(input: &str, cxpath: &str) -> Result<Option<String>, String> {
    call_id_abi(cx_node_id, input, cxpath)
}

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
