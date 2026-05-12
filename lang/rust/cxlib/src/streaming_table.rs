//! Streaming Table reader / writer + chunked-table one-shot
//! (Phase 7.74b; spec/abi.md §2.10, capability bit 21).
//!
//! Convention: user-facing API exchanges UNFRAMED CXDB payload bytes.
//! The C ABI takes / returns framed `[u32 LE size][payload]` buffers;
//! this binding handles framing transparently.
//!
//! ```no_run
//! use cxlib::streaming_table::{to_data_bin_chunked, TableReader, TableWriter};
//!
//! let payload = to_data_bin_chunked("[points :table[a:int b:int] 1 2]").unwrap();
//! let mut reader = TableReader::open(&payload).unwrap();
//! let schema = reader.schema().unwrap();
//! let groups: Vec<Vec<u8>> = std::iter::from_fn(|| reader.next_row_group().transpose())
//!     .collect::<Result<_, _>>().unwrap();
//! drop(reader);
//!
//! let mut writer = TableWriter::open(&schema).unwrap();
//! for g in &groups { writer.emit(g).unwrap(); }
//! let out = writer.close_get_bytes().unwrap();
//! ```

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;

extern "C" {
    fn cx_free(s: *mut c_char);

    fn cx_to_data_bin_chunked(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    fn cx_table_reader_open    (data_bin: *const c_char, err_out: *mut *mut c_char) -> *mut c_void;
    fn cx_table_reader_open_fd (fd: c_int, err_out: *mut *mut c_char) -> *mut c_void;
    fn cx_table_reader_schema  (handle: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_table_reader_next    (handle: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_table_reader_close   (handle: *mut c_void);

    fn cx_table_writer_open           (col_spec: *const c_char, err_out: *mut *mut c_char) -> *mut c_void;
    fn cx_table_writer_open_fd        (col_spec: *const c_char, fd: c_int, err_out: *mut *mut c_char) -> *mut c_void;
    fn cx_table_writer_emit_row_group (handle: *mut c_void, payload: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_table_writer_close_get_bytes(handle: *mut c_void, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_table_writer_close          (handle: *mut c_void);
}

fn frame_for_c(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    out.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

unsafe fn copy_framed_and_free(raw: *mut c_char) -> Vec<u8> {
    let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
    let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
    let payload_ptr = (raw as *const u8).add(4);
    let bytes = std::slice::from_raw_parts(payload_ptr, size).to_vec();
    cx_free(raw);
    bytes
}

unsafe fn take_err(err_ptr: *mut c_char, default: &str) -> String {
    if err_ptr.is_null() {
        return default.to_owned();
    }
    let msg = CStr::from_ptr(err_ptr).to_string_lossy().into_owned();
    cx_free(err_ptr);
    msg
}

/// Encode a CX `:table`-bodied root element to the CXDB chunked-table
/// form (`0x63`). Returns unframed CXDB payload bytes.
pub fn to_data_bin_chunked(input: &str) -> Result<Vec<u8>, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe { cx_to_data_bin_chunked(c_input.as_ptr(), &mut err_ptr) };
    if raw.is_null() {
        return Err(unsafe { take_err(err_ptr, "cx_to_data_bin_chunked: unknown error") });
    }
    Ok(unsafe { copy_framed_and_free(raw) })
}

/// Streaming reader over the row groups of a chunked-table CXDB buffer
/// or file descriptor. Implements `Iterator<Item = Result<Vec<u8>, String>>`.
pub struct TableReader {
    handle: *mut c_void,
    closed: bool,
    // Pin the framed buffer for in-memory readers (libcx reads lazily).
    _framed: Option<Vec<u8>>,
}

// SAFETY: the handle is exclusively owned by this struct; libcx imposes
// no internal synchronization (class H per spec/abi.md §1.5.1).
// Send only — concurrent calls on the same handle are UB.
unsafe impl Send for TableReader {}

impl TableReader {
    /// Open a streaming reader over an unframed CXDB chunked-table payload.
    pub fn open(payload: &[u8]) -> Result<Self, String> {
        if payload.is_empty() {
            return Err("TableReader::open: empty input".to_owned());
        }
        crate::ensure_thread();
        let framed = frame_for_c(payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe {
            cx_table_reader_open(framed.as_ptr() as *const c_char, &mut err_ptr)
        };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_reader_open: unknown error") });
        }
        Ok(TableReader { handle: h, closed: false, _framed: Some(framed) })
    }

    /// Open a streaming reader over an open file descriptor positioned
    /// at the CXDB magic (no framing prefix). Caller retains fd ownership.
    pub fn open_fd(fd: i32) -> Result<Self, String> {
        crate::ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe { cx_table_reader_open_fd(fd as c_int, &mut err_ptr) };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_reader_open_fd: unknown error") });
        }
        Ok(TableReader { handle: h, closed: false, _framed: None })
    }

    /// Return the table's col-spec as unframed ast_bin payload bytes.
    pub fn schema(&self) -> Result<Vec<u8>, String> {
        if self.closed || self.handle.is_null() {
            return Err("TableReader: handle closed".to_owned());
        }
        crate::ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let raw = unsafe { cx_table_reader_schema(self.handle, &mut err_ptr) };
        if raw.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_reader_schema: unknown error") });
        }
        Ok(unsafe { copy_framed_and_free(raw) })
    }

    /// Pull the next row group as unframed plain-body bytes
    /// (uvarint(row_count) + col-payload[col_count]). `Ok(None)` on EOF.
    pub fn next_row_group(&mut self) -> Result<Option<Vec<u8>>, String> {
        if self.closed || self.handle.is_null() {
            return Ok(None);
        }
        crate::ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let raw = unsafe { cx_table_reader_next(self.handle, &mut err_ptr) };
        if raw.is_null() {
            if !err_ptr.is_null() {
                let msg = unsafe { take_err(err_ptr, "") };
                self.close();
                return Err(msg);
            }
            return Ok(None);
        }
        Ok(Some(unsafe { copy_framed_and_free(raw) }))
    }

    /// Release the handle. Idempotent; called on Drop.
    pub fn close(&mut self) {
        if self.closed || self.handle.is_null() {
            self.closed = true;
            self.handle = ptr::null_mut();
            return;
        }
        unsafe { cx_table_reader_close(self.handle) };
        self.closed = true;
        self.handle = ptr::null_mut();
    }
}

impl Drop for TableReader {
    fn drop(&mut self) { self.close(); }
}

impl Iterator for TableReader {
    type Item = Result<Vec<u8>, String>;
    fn next(&mut self) -> Option<Self::Item> {
        match self.next_row_group() {
            Ok(Some(b)) => Some(Ok(b)),
            Ok(None)    => None,
            Err(e)      => Some(Err(e)),
        }
    }
}

/// Streaming writer for the chunked-table CXDB format. In-memory writers
/// accumulate bytes; fd writers stream to the supplied fd.
pub struct TableWriter {
    handle: *mut c_void,
    closed: bool,
    fd_mode: bool,
    _col_spec: Option<Vec<u8>>,
}

unsafe impl Send for TableWriter {}

impl TableWriter {
    /// Open an in-memory writer with the given col-spec payload (the
    /// unframed ast_bin shape returned by `TableReader::schema`).
    pub fn open(col_spec_payload: &[u8]) -> Result<Self, String> {
        if col_spec_payload.is_empty() {
            return Err("TableWriter::open: empty col-spec".to_owned());
        }
        crate::ensure_thread();
        let framed = frame_for_c(col_spec_payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe {
            cx_table_writer_open(framed.as_ptr() as *const c_char, &mut err_ptr)
        };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_writer_open: unknown error") });
        }
        Ok(TableWriter { handle: h, closed: false, fd_mode: false, _col_spec: Some(framed) })
    }

    /// Open an fd-streaming writer. Caller retains fd ownership.
    pub fn open_fd(col_spec_payload: &[u8], fd: i32) -> Result<Self, String> {
        if col_spec_payload.is_empty() {
            return Err("TableWriter::open_fd: empty col-spec".to_owned());
        }
        crate::ensure_thread();
        let framed = frame_for_c(col_spec_payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let h = unsafe {
            cx_table_writer_open_fd(framed.as_ptr() as *const c_char, fd as c_int, &mut err_ptr)
        };
        if h.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_writer_open_fd: unknown error") });
        }
        Ok(TableWriter { handle: h, closed: false, fd_mode: true, _col_spec: Some(framed) })
    }

    /// Append one row group. `row_group_payload` is the unframed
    /// plain-body form (uvarint(row_count) + col-payload[col_count]).
    pub fn emit(&mut self, row_group_payload: &[u8]) -> Result<(), String> {
        if self.closed || self.handle.is_null() {
            return Err("TableWriter: handle closed".to_owned());
        }
        crate::ensure_thread();
        let framed = frame_for_c(row_group_payload);
        let mut err_ptr: *mut c_char = ptr::null_mut();
        unsafe {
            cx_table_writer_emit_row_group(
                self.handle, framed.as_ptr() as *const c_char, &mut err_ptr);
        }
        if !err_ptr.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_writer_emit_row_group: unknown error") });
        }
        Ok(())
    }

    /// In-memory writers only: emit end-of-table and return the unframed
    /// chunked-table payload bytes.
    pub fn close_get_bytes(mut self) -> Result<Vec<u8>, String> {
        if self.fd_mode {
            return Err("close_get_bytes is for in-memory writers; use Drop / close() for fd writers".to_owned());
        }
        if self.closed || self.handle.is_null() {
            return Err("TableWriter: handle closed".to_owned());
        }
        crate::ensure_thread();
        let mut err_ptr: *mut c_char = ptr::null_mut();
        let raw = unsafe { cx_table_writer_close_get_bytes(self.handle, &mut err_ptr) };
        // V core releases the handle inside close_get_bytes.
        self.handle = ptr::null_mut();
        self.closed = true;
        if raw.is_null() {
            return Err(unsafe { take_err(err_ptr, "cx_table_writer_close_get_bytes: unknown error") });
        }
        Ok(unsafe { copy_framed_and_free(raw) })
    }

    /// Release the handle. For fd writers, flushes the end-of-table marker.
    pub fn close(&mut self) {
        if self.closed || self.handle.is_null() {
            self.closed = true;
            self.handle = ptr::null_mut();
            return;
        }
        unsafe { cx_table_writer_close(self.handle) };
        self.closed = true;
        self.handle = ptr::null_mut();
    }
}

impl Drop for TableWriter {
    fn drop(&mut self) { self.close(); }
}
