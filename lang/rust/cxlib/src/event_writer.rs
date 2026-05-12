//! Streaming-write API binding — `cxlib::event_writer::EventWriter`.
//!
//! Per spec/streaming.md §6 + ADR 0011 + spec/abi.md §2.15. Thin wrapper
//! around the 25 cx_events_writer_* C ABI symbols. The writer accepts
//! the 14 stream events defined in §1 and emits format-targeted output
//! (cx / xml / json / yaml / toml / md, selected at open time). CX and
//! XML are implemented end-to-end in v0.6.0; json / yaml / toml / md
//! emits surface a W009 error until their follow-up phases land.
//! Capability bit 27.
//!
//! Errors are returned as `Result<_, String>` carrying the W001-W013
//! prefix verbatim so callers can match on it. The writer fails closed:
//! after the first W-code, subsequent emits return the same diagnostic
//! without effect.
//!
//! ```no_run
//! use cxlib::event_writer::EventWriter;
//!
//! let mut w = EventWriter::new("cx").unwrap();
//! w.start_doc().unwrap();
//! w.start_element("greet", &[]).unwrap();
//! w.text("hello").unwrap();
//! w.end_element("greet").unwrap();
//! w.end_doc().unwrap();
//! let out = w.close_get_bytes().unwrap();
//! ```
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;

extern "C" {
    fn cx_free(s: *mut c_char);
    fn cx_features() -> *mut c_char;

    fn cx_events_writer_open
        (output_format: *const c_char, err_out: *mut *mut c_char) -> *mut c_void;
    fn cx_events_writer_open_fd
        (output_format: *const c_char, fd: c_int, err_out: *mut *mut c_char) -> *mut c_void;

    fn cx_events_writer_close_get_bytes
        (h: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_close(h: *mut c_void);

    fn cx_events_writer_start_doc
        (h: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_end_doc
        (h: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;

    fn cx_events_writer_start_element_with_len
        (h: *mut c_void, name: *const c_char, anchor: *const c_char,
         data_type: *const c_char, merge: *const c_char,
         attrs_payload: *const c_char, attrs_len: usize,
         err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_end_element
        (h: *mut c_void, name: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    fn cx_events_writer_text
        (h: *mut c_void, value: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_scalar
        (h: *mut c_void, data_type: *const c_char, value: *const c_char,
         err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_comment
        (h: *mut c_void, value: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_pi
        (h: *mut c_void, target: *const c_char, data: *const c_char,
         err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_entity_ref
        (h: *mut c_void, name: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_raw_text
        (h: *mut c_void, value: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_alias
        (h: *mut c_void, name: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    fn cx_events_writer_start_table_with_len
        (h: *mut c_void, col_spec_payload: *const c_char, col_spec_len: usize,
         err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_row_group_with_len
        (h: *mut c_void, row_group_payload: *const c_char, row_group_len: usize,
         err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_events_writer_end_table
        (h: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
}

const CAP_BIT_STREAMING_WRITE: u64 = 1u64 << 27;

fn features_u64() -> u64 {
    crate::ensure_thread();
    unsafe {
        let raw = cx_features();
        if raw.is_null() { return 0; }
        let s = CStr::from_ptr(raw).to_string_lossy().into_owned();
        // cx_features returns a static string per V cabi; do not cx_free.
        let s = s.trim_start_matches("0x");
        u64::from_str_radix(s, 16).unwrap_or(0)
    }
}

fn has_streaming_write_capability() -> bool {
    features_u64() & CAP_BIT_STREAMING_WRITE != 0
}

fn frame_for_c(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    out.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

unsafe fn take_err(err_ptr: *mut c_char, default: &str) -> String {
    if err_ptr.is_null() { return default.to_owned(); }
    let msg = CStr::from_ptr(err_ptr).to_string_lossy().into_owned();
    cx_free(err_ptr);
    msg
}

unsafe fn diag_from_ret(ret: *mut c_char, err_ptr: *mut c_char) -> Result<(), String> {
    if !ret.is_null() {
        let msg = CStr::from_ptr(ret).to_string_lossy().into_owned();
        cx_free(ret);
        if !err_ptr.is_null() { cx_free(err_ptr); }
        return Err(msg);
    }
    if !err_ptr.is_null() {
        let msg = CStr::from_ptr(err_ptr).to_string_lossy().into_owned();
        cx_free(err_ptr);
        return Err(msg);
    }
    Ok(())
}

/// One start-element attribute. `value` is rendered as a string; `data_type`
/// selects the wire-type tag (`""` defaults to `"string"`).
#[derive(Debug, Clone, Default)]
pub struct EventAttr {
    pub name: String,
    pub value: String,
    pub data_type: String,
}

impl EventAttr {
    pub fn new(name: impl Into<String>, value: impl Into<String>) -> Self {
        Self { name: name.into(), value: value.into(), data_type: String::new() }
    }
    pub fn typed(name: impl Into<String>, value: impl Into<String>, data_type: impl Into<String>) -> Self {
        Self { name: name.into(), value: value.into(), data_type: data_type.into() }
    }
}

fn encode_attrs_payload(attrs: &[EventAttr]) -> Option<Vec<u8>> {
    if attrs.is_empty() { return None; }
    let mut out = Vec::with_capacity(2 + attrs.len() * 16);
    out.extend_from_slice(&(attrs.len() as u16).to_le_bytes());
    let enc_lp = |out: &mut Vec<u8>, s: &str| {
        out.extend_from_slice(&(s.len() as u32).to_le_bytes());
        out.extend_from_slice(s.as_bytes());
    };
    for a in attrs {
        let typ = if a.data_type.is_empty() { "string" } else { a.data_type.as_str() };
        enc_lp(&mut out, &a.name);
        enc_lp(&mut out, &a.value);
        enc_lp(&mut out, typ);
        out.push(0); // is_ref
    }
    Some(out)
}

/// Optional fields passed to `start_element_opts`. All fields default to
/// `None` / empty.
#[derive(Debug, Default, Clone)]
pub struct StartElementOpts<'a> {
    pub anchor: Option<&'a str>,
    pub data_type: Option<&'a str>,
    pub merge: Option<&'a str>,
    pub attrs: &'a [EventAttr],
}

/// Thread-local streaming event writer (spec/streaming.md §6.2 — class H).
/// `Drop` releases the handle. `close_get_bytes` consumes the writer and
/// returns the accumulated bytes (empty for fd writers).
pub struct EventWriter {
    handle: *mut c_void,
    closed: bool,
    fd_mode: bool,
    _format: String,
}

// SAFETY: class H per spec/abi.md §1.5.1. Handle is owned by this struct;
// no internal synchronization, but distinct handles on distinct threads
// are safe.
unsafe impl Send for EventWriter {}

impl EventWriter {
    /// Open an in-memory writer for the given output format.
    pub fn new(output_format: &str) -> Result<Self, String> {
        if !has_streaming_write_capability() {
            return Err("cxlib::EventWriter requires libcx capability bit 27 \
                        (streaming-write; v0.6.0+). cx_features did not advertise it.".to_owned());
        }
        crate::ensure_thread();
        let c_fmt = CString::new(output_format).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe { cx_events_writer_open(c_fmt.as_ptr(), &mut err_ptr) };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_events_writer_open: unknown error") });
        }
        Ok(EventWriter { handle: h, closed: false, fd_mode: false, _format: output_format.to_owned() })
    }

    /// Open an fd-streaming writer. Caller retains fd ownership; close the
    /// fd after the writer is dropped.
    pub fn with_fd(output_format: &str, fd: i32) -> Result<Self, String> {
        if !has_streaming_write_capability() {
            return Err("cxlib::EventWriter::with_fd requires libcx capability bit 27 \
                        (streaming-write; v0.6.0+). cx_features did not advertise it.".to_owned());
        }
        crate::ensure_thread();
        let c_fmt = CString::new(output_format).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe { cx_events_writer_open_fd(c_fmt.as_ptr(), fd as c_int, &mut err_ptr) };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_events_writer_open_fd: unknown error") });
        }
        Ok(EventWriter { handle: h, closed: false, fd_mode: true, _format: output_format.to_owned() })
    }

    fn live(&self) -> Result<*mut c_void, String> {
        if self.closed || self.handle.is_null() {
            return Err("EventWriter: handle closed".to_owned());
        }
        Ok(self.handle)
    }

    /// Finalise the writer and return the accumulated output bytes.
    /// For fd writers the returned buffer is empty (output already flushed).
    /// Implicitly emits EndDoc — returns a W004 error if elements / table
    /// remain open. Consumes the writer.
    pub fn close_get_bytes(mut self) -> Result<Vec<u8>, String> {
        if self.closed || self.handle.is_null() {
            return Err("EventWriter: already closed".to_owned());
        }
        crate::ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let raw = unsafe { cx_events_writer_close_get_bytes(self.handle, &mut err_ptr) };
        let old = self.handle;
        self.handle = ptr::null_mut();
        self.closed = true;
        if raw.is_null() {
            unsafe { cx_events_writer_close(old) };
            return Err(unsafe { take_err(err_ptr, "cx_events_writer_close_get_bytes: unknown error") });
        }
        let bytes = unsafe {
            let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
            let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
            let payload = if size == 0 {
                Vec::new()
            } else {
                std::slice::from_raw_parts((raw as *const u8).add(4), size).to_vec()
            };
            cx_free(raw);
            payload
        };
        unsafe { cx_events_writer_close(old) };
        let _ = self.fd_mode;
        Ok(bytes)
    }

    /// Release the handle without finalising output. Idempotent; called on Drop.
    pub fn close(&mut self) {
        if self.closed || self.handle.is_null() {
            self.closed = true;
            self.handle = ptr::null_mut();
            return;
        }
        unsafe { cx_events_writer_close(self.handle) };
        self.closed = true;
        self.handle = ptr::null_mut();
    }

    // ── lifecycle emits ────────────────────────────────────────────────────

    pub fn start_doc(&mut self) -> Result<(), String> {
        let h = self.live()?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_start_doc(h, &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn end_doc(&mut self) -> Result<(), String> {
        let h = self.live()?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_end_doc(h, &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    /// Emit a StartElement with optional attributes. For anchor / data_type /
    /// merge, use [`start_element_opts`].
    pub fn start_element(&mut self, name: &str, attrs: &[EventAttr]) -> Result<(), String> {
        self.start_element_opts(name, &StartElementOpts { attrs, ..Default::default() })
    }

    pub fn start_element_opts(&mut self, name: &str, opts: &StartElementOpts<'_>) -> Result<(), String> {
        let h = self.live()?;
        let c_name   = CString::new(name).map_err(|e| e.to_string())?;
        let c_anchor = opts.anchor.map(|s| CString::new(s).unwrap());
        let c_dt     = opts.data_type.map(|s| CString::new(s).unwrap());
        let c_merge  = opts.merge.map(|s| CString::new(s).unwrap());
        let raw_payload = encode_attrs_payload(opts.attrs);
        let framed = raw_payload.as_ref().map(|p| frame_for_c(p));

        let mut err_ptr: *mut c_char = ptr::null_mut();
        let (attrs_ptr, attrs_len) = match &framed {
            Some(buf) => (buf.as_ptr() as *const c_char, buf.len()),
            None      => (ptr::null(), 0),
        };
        let ret = unsafe {
            cx_events_writer_start_element_with_len(
                h,
                c_name.as_ptr(),
                c_anchor.as_ref().map(|c| c.as_ptr()).unwrap_or(ptr::null()),
                c_dt.as_ref().map(|c| c.as_ptr()).unwrap_or(ptr::null()),
                c_merge.as_ref().map(|c| c.as_ptr()).unwrap_or(ptr::null()),
                attrs_ptr, attrs_len,
                &mut err_ptr,
            )
        };
        // Keep `framed` alive across the call.
        let _ = framed;
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn end_element(&mut self, name: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_name = CString::new(name).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_end_element(h, c_name.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn text(&mut self, value: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_val = CString::new(value).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_text(h, c_val.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    /// Emit a typed scalar. Pass `data_type=""` for `"string"`.
    pub fn scalar(&mut self, value: &str, data_type: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_val = CString::new(value).map_err(|e| e.to_string())?;
        let c_dt = if data_type.is_empty() { None } else { Some(CString::new(data_type).map_err(|e| e.to_string())?) };
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe {
            cx_events_writer_scalar(h,
                c_dt.as_ref().map(|c| c.as_ptr()).unwrap_or(ptr::null()),
                c_val.as_ptr(), &mut err_ptr)
        };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn comment(&mut self, value: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_val = CString::new(value).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_comment(h, c_val.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    /// Emit a processing instruction. `data` may be empty.
    pub fn pi(&mut self, target: &str, data: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_t = CString::new(target).map_err(|e| e.to_string())?;
        let c_d = if data.is_empty() { None } else { Some(CString::new(data).map_err(|e| e.to_string())?) };
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe {
            cx_events_writer_pi(h, c_t.as_ptr(),
                c_d.as_ref().map(|c| c.as_ptr()).unwrap_or(ptr::null()),
                &mut err_ptr)
        };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn entity_ref(&mut self, name: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_n = CString::new(name).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_entity_ref(h, c_n.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn raw_text(&mut self, value: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_v = CString::new(value).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_raw_text(h, c_v.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn alias(&mut self, name: &str) -> Result<(), String> {
        let h = self.live()?;
        let c_n = CString::new(name).map_err(|e| e.to_string())?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_alias(h, c_n.as_ptr(), &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    /// Open a chunked table. `col_spec_payload` is the unframed column-spec
    /// wire form (spec/data_bin.md §3.10.1):
    /// `[u32 LE count] ([u32 LE name_len] name [u8 type_code])*`.
    pub fn start_table(&mut self, col_spec_payload: &[u8]) -> Result<(), String> {
        let h = self.live()?;
        let framed = frame_for_c(col_spec_payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe {
            cx_events_writer_start_table_with_len(
                h, framed.as_ptr() as *const c_char, framed.len(), &mut err_ptr)
        };
        let _ = framed;
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    /// Append a row group. `payload` is the unframed §3.11.2 plain body:
    /// `uvarint(row_count) + col-payload[col_count]`.
    pub fn row_group(&mut self, payload: &[u8]) -> Result<(), String> {
        let h = self.live()?;
        let framed = frame_for_c(payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe {
            cx_events_writer_row_group_with_len(
                h, framed.as_ptr() as *const c_char, framed.len(), &mut err_ptr)
        };
        let _ = framed;
        unsafe { diag_from_ret(ret, err_ptr) }
    }

    pub fn end_table(&mut self) -> Result<(), String> {
        let h = self.live()?;
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let ret = unsafe { cx_events_writer_end_table(h, &mut err_ptr) };
        unsafe { diag_from_ret(ret, err_ptr) }
    }
}

impl Drop for EventWriter {
    fn drop(&mut self) { self.close(); }
}

/// Whether libcx advertises the streaming-write capability bit (27).
pub fn has_capability() -> bool { has_streaming_write_capability() }
