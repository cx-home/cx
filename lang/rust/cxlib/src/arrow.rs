//! Apache Arrow C-Data interop for cxlib (Phase 7.74c-cont-bindings-multi-rust).
//!
//! Bridges CXCol chunked-tables to the Arrow C-Data ABI via libcx_arrow
//! (spec/abi.md §2.11, capability bit 0x800000). The bridge
//! handles all 9 v0.6.0 column types (int, i8, i16, i32, float, bool,
//! string, date, bytes); datetime / dictionary columns are deferred and
//! surface the V core's deferred-type error. decimal / bigint columns
//! (first-class kinds since I1 L48) are DECLARED unsupported on the
//! Arrow bridge until I5 (M23 advisory window) — they surface the V
//! core's clear not-yet-supported error; the native CXCol codec
//! (`cxlib::data_bin`, `CxValue::Decimal` / `CxValue::BigInt`) carries
//! them with full fidelity in the meantime.
//!
//! Gated behind the `arrow` Cargo feature so the default `cargo build`
//! does not require libcx_arrow or the `arrow` crate:
//!
//! ```bash
//! cargo build --features arrow
//! cargo test  --features arrow
//! ```
//!
//! Mirrors Python's `pip install cxlib[arrow]` and Go's `-tags arrow`
//! opt-in patterns. The user-facing API exchanges UNFRAMED CXCol payload
//! bytes, matching the existing Rust binding convention; the C ABI's
//! `[u32 LE size][payload]` framing is added/stripped internally.
//!
//! Example:
//!
//! ```no_run
//! use cxlib::streaming_table::to_data_bin_chunked;
//! use cxlib::arrow as cxa;
//!
//! let payload = to_data_bin_chunked(
//!     "[points [table[name::string score::int]] alice 91 bob 88]").unwrap();
//! let mut reader = cxa::export(&payload).unwrap();
//! // reader: ArrowArrayStreamReader implements RecordBatchReader.
//! let out = cxa::import_to_data_bin(reader).unwrap();
//! ```

use std::ffi::CStr;
use std::os::raw::{c_char, c_void};
use std::ptr;

use arrow::array::RecordBatchReader;
use arrow::ffi_stream::{ArrowArrayStreamReader, FFI_ArrowArrayStream};

extern "C" {
    fn cx_free(s: *mut c_char);
    fn cx_features() -> *mut c_char;

    fn cx_arrow_features() -> *mut c_char;
    fn cx_arrow_version() -> *mut c_char;
    fn cx_arrow_free(p: *mut c_void);

    fn cx_arrow_export_open(
        data_bin: *const c_char,
        arrow_array_stream_out: *mut c_void,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;

    fn cx_arrow_import_to_data_bin(
        arrow_array_stream_in: *mut c_void,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;
}

// ── helpers ──────────────────────────────────────────────────────────────────

fn frame_for_c(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    out.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

unsafe fn take_err(err_ptr: *mut c_char, default: &str) -> String {
    if err_ptr.is_null() {
        return default.to_owned();
    }
    let msg = CStr::from_ptr(err_ptr).to_string_lossy().into_owned();
    cx_free(err_ptr);
    msg
}

/// libcx convention: the capability-bitmask C strings carry an optional
/// `0x` prefix (`'0x800000'`). Strip before parsing.
fn parse_hex_bitmask(s: &str) -> u64 {
    let s = s.trim_start_matches("0x").trim_start_matches("0X");
    u64::from_str_radix(s, 16).unwrap_or(0)
}

unsafe fn read_cx_string(p: *mut c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    let s = CStr::from_ptr(p).to_string_lossy().into_owned();
    cx_free(p);
    Some(s)
}

// ── public API ───────────────────────────────────────────────────────────────

/// True iff the Arrow bridge is compiled in. Under the `arrow` Cargo
/// feature this is always `true` — libcx_arrow MUST be linkable or the
/// binary fails to load. There is no graceful runtime fallback; build
/// without `--features arrow` to skip Arrow entirely.
pub fn available() -> bool { true }

/// libcx_arrow capability bitmask (spec/abi.md §2.11). Currently always
/// `0x800000` (bit 23) when libcx_arrow loads.
pub fn features() -> u64 {
    crate::ensure_thread();
    let raw = unsafe { cx_arrow_features() };
    let s = unsafe { read_cx_string(raw) }.unwrap_or_default();
    parse_hex_bitmask(&s)
}

/// libcx_arrow build version string.
pub fn version() -> String {
    crate::ensure_thread();
    let raw = unsafe { cx_arrow_version() };
    unsafe { read_cx_string(raw) }.unwrap_or_default()
}

/// Bitwise OR of libcx and libcx_arrow capability bitmasks. Mirrors
/// Python's `cxlib.arrow.merged_features()`.
pub fn merged_features() -> u64 {
    crate::ensure_thread();
    let raw = unsafe { cx_features() };
    let base = unsafe { read_cx_string(raw) }
        .map(|s| parse_hex_bitmask(&s))
        .unwrap_or(0);
    base | features()
}

/// Decode an UNFRAMED CXCol chunked-table payload as an Arrow stream
/// reader. Ownership of the underlying `FFI_ArrowArrayStream` callbacks
/// moves into the returned reader, which releases them on drop.
///
/// Memory: cxlib copies the input into a stream-owned buffer; the caller
/// may release `payload` immediately after this call returns.
pub fn export(payload: &[u8]) -> Result<ArrowArrayStreamReader, String> {
    if payload.is_empty() {
        return Err("cxlib::arrow::export: empty input".to_owned());
    }
    crate::ensure_thread();
    let framed = frame_for_c(payload);

    // Allocate a zeroed FFI_ArrowArrayStream on the heap so libcx_arrow
    // can populate its callbacks. The struct is `#[repr(C)]` so its
    // layout matches the Arrow C-Data ABI.
    let stream_box = Box::new(FFI_ArrowArrayStream::empty());
    let stream_ptr = Box::into_raw(stream_box);

    let mut err_ptr: *mut c_char = ptr::null_mut();
    unsafe {
        cx_arrow_export_open(
            framed.as_ptr() as *const c_char,
            stream_ptr as *mut c_void,
            &mut err_ptr,
        );
    }
    if !err_ptr.is_null() {
        // Drop the empty stream box (no callbacks to release).
        drop(unsafe { Box::from_raw(stream_ptr) });
        let msg = unsafe { take_err(err_ptr, "cx_arrow_export_open: unknown error") };
        return Err(msg);
    }

    // Take ownership back; ArrowArrayStreamReader::try_new consumes it
    // by value and the FFI struct's release callback fires on drop.
    let stream = unsafe { *Box::from_raw(stream_ptr) };
    ArrowArrayStreamReader::try_new(stream)
        .map_err(|e| format!("cxlib::arrow::export: try_new: {e}"))
}

/// Drain a `RecordBatchReader` into UNFRAMED CXCol chunked-table bytes.
/// The reader is consumed; its callbacks are released by libcx via the
/// moved `FFI_ArrowArrayStream`.
pub fn import_to_data_bin<R>(reader: R) -> Result<Vec<u8>, String>
where
    R: RecordBatchReader + Send + 'static,
{
    crate::ensure_thread();
    let mut stream = FFI_ArrowArrayStream::new(Box::new(reader));
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let addr = unsafe {
        cx_arrow_import_to_data_bin(
            &mut stream as *mut FFI_ArrowArrayStream as *mut c_void,
            &mut err_ptr,
        )
    };
    // libcx_arrow consumes the FFI struct via the C-Data move semantics
    // (release callback nulled), so dropping `stream` after this call is
    // a no-op on success. On failure the struct is still our problem;
    // letting it drop naturally invokes its release callback.
    if addr.is_null() {
        let msg = unsafe { take_err(err_ptr, "cx_arrow_import_to_data_bin: unknown error") };
        return Err(msg);
    }
    // Returned buffer is `[u32 LE size][payload]`. Convention for this
    // binding is UNFRAMED (matches streaming_table::to_data_bin_chunked).
    let out = unsafe {
        let hdr = std::slice::from_raw_parts(addr as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let payload_ptr = (addr as *const u8).add(4);
        let bytes = std::slice::from_raw_parts(payload_ptr, size).to_vec();
        cx_arrow_free(addr as *mut c_void);
        bytes
    };
    Ok(out)
}

// W2 v0.7.0: Arrow IPC stream format read/write.
// Delegates to arrow::ipc's StreamWriter / StreamReader, which
// handle flatbuffer encoding/decoding. CX never touches flatbuffer
// bytes directly — IPC codec lives in each language's Arrow library
// by Apache Arrow convention.

/// Convert framed CXCol chunked-table bytes to Arrow IPC stream bytes
/// suitable for writing to a `.arrow` file or piping into another
/// Arrow IPC consumer.
pub fn to_ipc(payload: &[u8]) -> Result<Vec<u8>, String> {
    use arrow::ipc::writer::StreamWriter;
    let mut reader = export(payload)?;
    let schema = reader.schema();
    let mut buf: Vec<u8> = Vec::new();
    {
        let mut writer = StreamWriter::try_new(&mut buf, &schema)
            .map_err(|e| format!("to_ipc: writer init: {e}"))?;
        while let Some(batch) = reader.next() {
            let batch = batch.map_err(|e| format!("to_ipc: next batch: {e}"))?;
            writer.write(&batch).map_err(|e| format!("to_ipc: write: {e}"))?;
        }
        writer.finish().map_err(|e| format!("to_ipc: finish: {e}"))?;
    }
    Ok(buf)
}

/// Convert Arrow IPC stream bytes (the byte stream a `.arrow` file
/// would contain) to framed CXCol chunked-table bytes.
pub fn from_ipc(ipc_bytes: &[u8]) -> Result<Vec<u8>, String> {
    use arrow::ipc::reader::StreamReader;
    // import_to_data_bin moves the reader into an FFI_ArrowArrayStream,
    // which demands 'static — so the cursor must own its bytes.
    let cursor = std::io::Cursor::new(ipc_bytes.to_vec());
    let reader = StreamReader::try_new(cursor, None)
        .map_err(|e| format!("from_ipc: reader init: {e}"))?;
    import_to_data_bin(reader)
}
