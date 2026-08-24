//! CX schema validator binding — `cx_validate` + `cx_validate_apply_defaults`.
//!
//! Per spec/schema.md §10 + spec/abi.md §2.13. The C ABI
//! returns a framed binary diagnostics payload:
//!
//! ```text
//!   [u32 LE total_size]
//!   [u32 LE diag_count]
//!   diagnostic* {
//!     [u32 line] [u32 col] [u32 error_code]
//!     [u8 severity]                  // 0=info, 1=warn, 2=error
//!     [u32 message_len] [message_utf8]
//!   }
//! ```
//!
//! The wire format encodes only the numeric portion of the rule code;
//! v0.6.0 emits S001-S020 from the schema validator, so this binding
//! reconstructs the public Code string with an "S" prefix. When the
//! data validator lands and emits D-codes, the V side will gain a
//! prefix marker on the wire format and this binding will route on it.

use std::os::raw::c_char;
use std::ptr;

use crate::{ensure_thread, free_libcx_string};

extern "C" {
    fn cx_validate_with_len(
        doc_input: *const c_char, doc_len: usize,
        schema_input: *const c_char, schema_len: usize,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;

    fn cx_validate_apply_defaults_with_len(
        doc_input: *const c_char, doc_len: usize,
        schema_input: *const c_char, schema_len: usize,
        modified_doc_out: *mut *mut c_char,
        err_out: *mut *mut c_char,
    ) -> *mut c_char;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    Info,
    Warn,
    Error,
}

impl Severity {
    fn from_u8(v: u8) -> Self {
        match v {
            0 => Severity::Info,
            1 => Severity::Warn,
            _ => Severity::Error,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Diagnostic {
    pub code:     String,
    pub severity: Severity,
    pub message:  String,
    pub line:     u32,
    pub col:      u32,
}

#[derive(Debug, Clone, Default)]
pub struct ValidationReport {
    pub diagnostics:  Vec<Diagnostic>,
    pub modified_doc: String,
}

impl ValidationReport {
    pub fn is_valid(&self) -> bool {
        !self.diagnostics.iter().any(|d| d.severity == Severity::Error)
    }

    pub fn error_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.severity == Severity::Error).count()
    }

    pub fn warn_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.severity == Severity::Warn).count()
    }

    pub fn info_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.severity == Severity::Info).count()
    }

    pub fn error_codes(&self) -> Vec<String> {
        self.diagnostics.iter()
            .filter(|d| d.severity == Severity::Error)
            .map(|d| d.code.clone())
            .collect()
    }
}

/// Validate `doc` against `schema`. Schema-load errors (missing
/// `[schema of=...]` header, unknown anchor, etc.) surface as a single error-severity
/// Diagnostic in the returned report, not as a Rust `Err`. Returns
/// `Err` only when the document text is malformed CX.
pub fn validate(doc: &str, schema: &str) -> Result<ValidationReport, String> {
    ensure_thread();
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe {
        cx_validate_with_len(
            doc.as_ptr() as *const c_char, doc.len(),
            schema.as_ptr() as *const c_char, schema.len(),
            &mut err_ptr,
        )
    };
    let payload = extract_framed_payload(raw, err_ptr)?;
    Ok(ValidationReport {
        diagnostics: parse_diag_payload(&payload),
        modified_doc: String::new(),
    })
}

/// Validate and additionally apply schema-driven defaults. The
/// returned report's `modified_doc` carries the canonical CX text of
/// the document with defaults inserted (empty when the schema declares
/// no defaults).
pub fn validate_apply_defaults(doc: &str, schema: &str) -> Result<ValidationReport, String> {
    ensure_thread();
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let mut modified_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe {
        cx_validate_apply_defaults_with_len(
            doc.as_ptr() as *const c_char, doc.len(),
            schema.as_ptr() as *const c_char, schema.len(),
            &mut modified_ptr, &mut err_ptr,
        )
    };
    let payload = extract_framed_payload(raw, err_ptr)?;
    let modified = if modified_ptr.is_null() {
        String::new()
    } else {
        let s = unsafe { std::ffi::CStr::from_ptr(modified_ptr).to_string_lossy().into_owned() };
        unsafe { free_libcx_string(modified_ptr) };
        s
    };
    Ok(ValidationReport {
        diagnostics: parse_diag_payload(&payload),
        modified_doc: modified,
    })
}

/// Strip the framed-payload size header and copy the body bytes out,
/// freeing the libcx-owned buffer. On NULL return propagates `*err_out`.
fn extract_framed_payload(raw: *mut c_char, err_ptr: *mut c_char) -> Result<Vec<u8>, String> {
    if raw.is_null() {
        if err_ptr.is_null() {
            return Err("cx_validate: unknown error".to_owned());
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { free_libcx_string(err_ptr) };
        return Err(msg);
    }
    let payload = unsafe {
        let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let body_ptr = (raw as *const u8).add(4);
        let bytes = std::slice::from_raw_parts(body_ptr, size).to_vec();
        free_libcx_string(raw);
        bytes
    };
    Ok(payload)
}

fn parse_diag_payload(payload: &[u8]) -> Vec<Diagnostic> {
    if payload.len() < 4 {
        return Vec::new();
    }
    let count = u32::from_le_bytes([payload[0], payload[1], payload[2], payload[3]]);
    let mut out = Vec::with_capacity(count as usize);
    let mut off = 4usize;
    for _ in 0..count {
        if off + 18 > payload.len() {
            return out;
        }
        let line = u32::from_le_bytes([payload[off], payload[off+1], payload[off+2], payload[off+3]]);
        off += 4;
        let col = u32::from_le_bytes([payload[off], payload[off+1], payload[off+2], payload[off+3]]);
        off += 4;
        let prefix = payload[off];
        off += 1;
        let code = u32::from_le_bytes([payload[off], payload[off+1], payload[off+2], payload[off+3]]);
        off += 4;
        let sev = payload[off];
        off += 1;
        let mlen = u32::from_le_bytes([payload[off], payload[off+1], payload[off+2], payload[off+3]]) as usize;
        off += 4;
        if off + mlen > payload.len() {
            return out;
        }
        let msg = String::from_utf8_lossy(&payload[off..off+mlen]).into_owned();
        off += mlen;
        out.push(Diagnostic {
            code:     format_code(prefix, code),
            severity: Severity::from_u8(sev),
            message:  msg,
            line,
            col,
        });
    }
    out
}

/// Renders a diagnostic Code from the wire-format prefix byte + numeric.
/// Prefix is the ASCII namespace tag ('S' = schema, 'W' = streaming-write,
/// 'D' = data validator); 0x00 means "namespace unspecified" — render
/// the numeric without a letter. See spec/abi.md §2.13 / spec/schema.md §10.2.
fn format_code(prefix: u8, numeric: u32) -> String {
    if prefix == 0 {
        format!("{:03}", numeric)
    } else {
        format!("{}{:03}", prefix as char, numeric)
    }
}
