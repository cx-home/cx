//! CXCol v1 codec — strict canonical binary data format.
//!
//! Spec: spec/core/data-bin.md.
//!
//! Decoder consumes the framed [u32 LE size][payload] buffer returned by
//! libcx.cx_to_data_bin (or just the payload, see `decode_payload`).
//! Encoder produces the same shape for input to libcx.cx_from_data_bin.
//!
//! Replaces the JSON-string detour previously used by ast::loads / dumps
//! (audit finding CB-3). Type fidelity preserved: int stays i64,
//! float stays f64, bool stays bool, etc.

use serde_json::{Map, Number, Value};
use std::os::raw::c_char;
use std::ffi::CString;
use std::ptr;

// Tag bytes — see spec/core/data-bin.md §3.2.
const TAG_NULL: u8         = 0x00;
const TAG_FALSE: u8        = 0x01;
const TAG_TRUE: u8         = 0x02;
const TAG_INT8: u8         = 0x10;
const TAG_INT16: u8        = 0x11;
const TAG_INT32: u8        = 0x12;
const TAG_INT64: u8        = 0x13;
const TAG_FLOAT64: u8      = 0x20;
const TAG_STRING: u8       = 0x30;
const TAG_DATE: u8         = 0x31;
const TAG_DATETIME: u8     = 0x32;
const TAG_BYTES: u8        = 0x33;
const TAG_ARRAY: u8        = 0x40;
const TAG_ARRAY_EMPTY: u8  = 0x41;
const TAG_MAP: u8          = 0x50;
const TAG_MAP_EMPTY: u8    = 0x51;
const TAG_TABLE: u8        = 0x60;
const TAG_TABLE_EMPTY: u8  = 0x61;

// Wire magic — 5-byte "CXCol" (0x43 0x58 0x43 0x6F 0x6C). Header is
// 12 bytes total. Matches V's `cxcol_magic` in vcx/cx/data_bin.v.
const CXCOL_MAGIC: &[u8; 5] = b"CXCol";
const CXCOL_MAGIC_LEN: usize = 5;
const CXCOL_VERSION: u8 = 0x01;
const CXCOL_FLAGS_LE: u8 = 0x01;
const CXCOL_DEFAULT_DEPTH: u32 = 64;

extern "C" {
    fn cx_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_free(s: *mut c_char);

    // data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5)
    fn cx_xml_to_data_bin (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    fn cx_data_bin_to_xml (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_json(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_yaml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_toml(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Delimited (CSV/TSV/PSV/arbitrary) C ABI (Phase 7.68).
    // Text-text (8): cx_to_delimited / cx_from_delimited carry a single-byte
    // delimiter; cx_{to,from}_{csv,tsv,psv} aliases hard-code `,` / `\t` / `|`.
    fn cx_to_delimited  (input: *const c_char, delim: c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_delimited(input: *const c_char, delim: c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_csv  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_csv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_tsv  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_tsv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_to_psv  (input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_psv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;

    // Binary one-shots (6): csv/tsv/psv ↔ data_bin.
    fn cx_csv_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_tsv_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_psv_to_data_bin(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_csv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_tsv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_data_bin_to_psv(input: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
}

// Type alias for the (input, err_out) → buffer C ABI signature shared
// by all loaders / dumpers.
type CxBinFn = unsafe extern "C" fn(*const c_char, *mut *mut c_char) -> *mut c_char;

// ── Public entry points ──────────────────────────────────────────────────────

/// Encode CX text to a CXCol v1 framed buffer via the C ABI.
pub fn to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe { cx_to_data_bin(c_input.as_ptr(), &mut err_ptr) };
    if raw.is_null() {
        if err_ptr.is_null() {
            return Err("unknown error".to_owned());
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let payload = unsafe {
        let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let payload_ptr = (raw as *const u8).add(4);
        std::slice::from_raw_parts(payload_ptr, size).to_vec()
    };
    unsafe { cx_free(raw) };
    Ok(payload)
}

/// Decode a CXCol v1 framed buffer to canonical CX text via the C ABI.
/// `framed` must be the [u32 LE size][payload] layout that
/// cx_to_data_bin returns.
pub fn from_data_bin(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_from_data_bin, framed, "cx_from_data_bin")
}

// ── data_bin one-shot loaders/dumpers (Phase 7.28; spec/abi.md §2.4–§2.5) ────
//
// Loaders compose a per-format parser with emit_data_bin; return the
// payload bytes (frame-stripped, matching to_data_bin's convention).
// Dumpers compose parse_data_bin with a per-format emitter; expect
// framed input bytes (matching from_data_bin's convention).

// Shared loader helper: text input → payload bytes (frame stripped).
fn call_text_to_payload(fn_: CxBinFn, input: &str, fn_name: &str) -> Result<Vec<u8>, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe { fn_(c_input.as_ptr(), &mut err_ptr) };
    if raw.is_null() {
        if err_ptr.is_null() {
            return Err(format!("{}: unknown error", fn_name));
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let payload = unsafe {
        let hdr = std::slice::from_raw_parts(raw as *const u8, 4);
        let size = u32::from_le_bytes([hdr[0], hdr[1], hdr[2], hdr[3]]) as usize;
        let payload_ptr = (raw as *const u8).add(4);
        std::slice::from_raw_parts(payload_ptr, size).to_vec()
    };
    unsafe { cx_free(raw) };
    Ok(payload)
}

// Shared dumper helper: framed bytes → text.
fn call_bin_to_text(fn_: CxBinFn, framed: &[u8], fn_name: &str) -> Result<String, String> {
    if framed.is_empty() {
        return Err(format!("{}: empty input", fn_name));
    }
    crate::ensure_thread();
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { fn_(framed.as_ptr() as *const c_char, &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err(format!("{}: unknown error", fn_name));
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

/// Encode XML text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn xml_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_xml_to_data_bin, input, "cx_xml_to_data_bin")
}

/// Encode JSON text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn json_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_json_to_data_bin, input, "cx_json_to_data_bin")
}

/// Encode YAML text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn yaml_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_yaml_to_data_bin, input, "cx_yaml_to_data_bin")
}

/// Encode TOML text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn toml_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_toml_to_data_bin, input, "cx_toml_to_data_bin")
}

/// Decode a CXCol v1 framed buffer to XML text via the C ABI.
pub fn data_bin_to_xml(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_xml, framed, "cx_data_bin_to_xml")
}

/// Decode a CXCol v1 framed buffer to JSON text via the C ABI.
pub fn data_bin_to_json(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_json, framed, "cx_data_bin_to_json")
}

/// Decode a CXCol v1 framed buffer to YAML text via the C ABI.
pub fn data_bin_to_yaml(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_yaml, framed, "cx_data_bin_to_yaml")
}

/// Decode a CXCol v1 framed buffer to TOML text via the C ABI.
pub fn data_bin_to_toml(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_toml, framed, "cx_data_bin_to_toml")
}

// ── Delimited (CSV/TSV/PSV/arbitrary) C ABI (Phase 7.68) ──────────
//
// Per spec/conversions.md §8.
// `cx_to_delimited` / `cx_from_delimited` take a single-byte delimiter; the
// `cx_to_csv` / `cx_to_tsv` / `cx_to_psv` aliases hard-code `,` / `\t` / `|`.
// Binary one-shots cover the three named-delimiter variants.

// Shared text-text helper for the 6 named-delimiter aliases.
fn call_text(fn_: CxBinFn, input: &str, fn_name: &str) -> Result<String, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { fn_(c_input.as_ptr(), &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err(format!("{}: unknown error", fn_name));
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

// Shared text-text helper for the two delim-bearing entry points.
type CxDelimFn = unsafe extern "C" fn(*const c_char, c_char, *mut *mut c_char) -> *mut c_char;
fn call_delim(fn_: CxDelimFn, input: &str, delim: u8, fn_name: &str) -> Result<String, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let out = unsafe { fn_(c_input.as_ptr(), delim as c_char, &mut err_ptr) };
    if out.is_null() {
        if err_ptr.is_null() {
            return Err(format!("{}: unknown error", fn_name));
        }
        let msg = unsafe { std::ffi::CStr::from_ptr(err_ptr).to_string_lossy().into_owned() };
        unsafe { cx_free(err_ptr) };
        return Err(msg);
    }
    let s = unsafe { std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned() };
    unsafe { cx_free(out) };
    Ok(s)
}

/// Encode CX text to delimited text with an arbitrary single-byte delimiter.
/// `delim` must be any byte except `\r \n " ' \\`.
pub fn to_delimited(input: &str, delim: u8) -> Result<String, String> {
    call_delim(cx_to_delimited, input, delim, "cx_to_delimited")
}

/// Decode delimited text with an arbitrary single-byte delimiter to CX text.
pub fn from_delimited(input: &str, delim: u8) -> Result<String, String> {
    call_delim(cx_from_delimited, input, delim, "cx_from_delimited")
}

/// Encode CX text to CSV (comma-delimited) text.
pub fn to_csv(input: &str) -> Result<String, String> {
    call_text(cx_to_csv, input, "cx_to_csv")
}

/// Decode CSV text to CX text.
pub fn from_csv(input: &str) -> Result<String, String> {
    call_text(cx_from_csv, input, "cx_from_csv")
}

/// Encode CX text to TSV (tab-delimited) text.
pub fn to_tsv(input: &str) -> Result<String, String> {
    call_text(cx_to_tsv, input, "cx_to_tsv")
}

/// Decode TSV text to CX text.
pub fn from_tsv(input: &str) -> Result<String, String> {
    call_text(cx_from_tsv, input, "cx_from_tsv")
}

/// Encode CX text to PSV (pipe-delimited) text.
pub fn to_psv(input: &str) -> Result<String, String> {
    call_text(cx_to_psv, input, "cx_to_psv")
}

/// Decode PSV text to CX text.
pub fn from_psv(input: &str) -> Result<String, String> {
    call_text(cx_from_psv, input, "cx_from_psv")
}

/// Encode CSV text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn csv_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_csv_to_data_bin, input, "cx_csv_to_data_bin")
}

/// Encode TSV text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn tsv_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_tsv_to_data_bin, input, "cx_tsv_to_data_bin")
}

/// Encode PSV text to a CXCol v1 payload (frame-stripped) via the C ABI.
pub fn psv_to_data_bin(input: &str) -> Result<Vec<u8>, String> {
    call_text_to_payload(cx_psv_to_data_bin, input, "cx_psv_to_data_bin")
}

/// Decode a CXCol v1 framed buffer to CSV text via the C ABI.
pub fn data_bin_to_csv(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_csv, framed, "cx_data_bin_to_csv")
}

/// Decode a CXCol v1 framed buffer to TSV text via the C ABI.
pub fn data_bin_to_tsv(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_tsv, framed, "cx_data_bin_to_tsv")
}

/// Decode a CXCol v1 framed buffer to PSV text via the C ABI.
pub fn data_bin_to_psv(framed: &[u8]) -> Result<String, String> {
    call_bin_to_text(cx_data_bin_to_psv, framed, "cx_data_bin_to_psv")
}

/// Decode a CXCol v1 PAYLOAD (12-byte header + value section) into a
/// serde_json::Value with full type fidelity (int stays Number(i64),
/// not coerced to f64 like the JSON detour did).
pub fn decode_payload(payload: &[u8]) -> Result<Value, String> {
    if payload.len() < 12 {
        return Err("cxcol: payload too short for 12-byte header".to_owned());
    }
    if &payload[0..CXCOL_MAGIC_LEN] != CXCOL_MAGIC {
        return Err("cxcol: bad magic (expected 'CXCol')".to_owned());
    }
    if payload[CXCOL_MAGIC_LEN] != CXCOL_VERSION {
        return Err(format!("cxcol: unsupported version {}", payload[CXCOL_MAGIC_LEN]));
    }
    let flags = payload[6];
    if flags & 0xFE != 0 {
        return Err("cxcol: reserved flag bits set".to_owned());
    }
    if flags & 0x01 == 0 {
        return Err("cxcol: only little-endian payloads supported in v1".to_owned());
    }
    // bytes 7..11 max_depth (u32 LE); byte 11 reserved (must be zero).
    if payload[11] != 0 {
        return Err("cxcol: reserved header byte must be zero".to_owned());
    }
    let mut r = Reader::new(&payload[12..]);
    r.value()
}

/// Encode a serde_json::Value as a framed CXCol v1 buffer.
pub fn encode(value: &Value) -> Result<Vec<u8>, String> {
    let mut w = Writer::new();
    // Header — 5 magic + 1 ver + 1 flags + 4 max_depth + 1 reserved = 12.
    w.buf.extend_from_slice(CXCOL_MAGIC);
    w.buf.push(CXCOL_VERSION);
    w.buf.push(CXCOL_FLAGS_LE);
    w.u32(CXCOL_DEFAULT_DEPTH);
    w.buf.push(0);
    w.value(value)?;
    // Frame
    let payload_len = w.buf.len() as u32;
    let mut framed = Vec::with_capacity(4 + w.buf.len());
    framed.extend_from_slice(&payload_len.to_le_bytes());
    framed.extend_from_slice(&w.buf);
    Ok(framed)
}

// ── Reader ───────────────────────────────────────────────────────────────────

struct Reader<'a> {
    buf: &'a [u8],
    pos: usize,
    depth: usize,
    max_depth: usize,
}

impl<'a> Reader<'a> {
    fn new(buf: &'a [u8]) -> Self {
        Self { buf, pos: 0, depth: 0, max_depth: CXCOL_DEFAULT_DEPTH as usize }
    }

    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        if self.pos + n > self.buf.len() {
            return Err(format!("cxcol: {} bytes requested, {} remaining", n, self.buf.len() - self.pos));
        }
        let out = &self.buf[self.pos..self.pos + n];
        self.pos += n;
        Ok(out)
    }

    fn u8(&mut self) -> Result<u8, String> {
        if self.pos >= self.buf.len() {
            return Err("cxcol: unexpected end of input".to_owned());
        }
        let v = self.buf[self.pos];
        self.pos += 1;
        Ok(v)
    }

    fn u16(&mut self) -> Result<u16, String> {
        let bs = self.take(2)?;
        Ok(u16::from_le_bytes([bs[0], bs[1]]))
    }

    fn uvarint(&mut self) -> Result<u64, String> {
        let mut x: u64 = 0;
        let mut shift: u32 = 0;
        for i in 0..5 {
            let b = self.u8()?;
            if b < 0x80 {
                if i == 4 && b > 0x0F {
                    return Err("cxcol: varint overflow".to_owned());
                }
                if i > 0 && b == 0 {
                    return Err("cxcol: non-canonical varint (extra zero byte)".to_owned());
                }
                return Ok(x | ((b as u64) << shift));
            }
            x |= ((b & 0x7F) as u64) << shift;
            shift += 7;
        }
        Err("cxcol: varint exceeds 5 bytes".to_owned())
    }

    fn string_payload(&mut self) -> Result<String, String> {
        let n = self.uvarint()? as usize;
        let bs = self.take(n)?;
        String::from_utf8(bs.to_vec()).map_err(|e| e.to_string())
    }

    fn value(&mut self) -> Result<Value, String> {
        self.depth += 1;
        if self.depth > self.max_depth {
            return Err(format!("cxcol: recursion depth exceeds limit ({})", self.max_depth));
        }
        let tag = self.u8()?;
        let result = match tag {
            TAG_NULL => Ok(Value::Null),
            TAG_FALSE => Ok(Value::Bool(false)),
            TAG_TRUE => Ok(Value::Bool(true)),
            TAG_INT8 => {
                let bs = self.take(1)?;
                Ok(Value::Number(Number::from(bs[0] as i8 as i64)))
            }
            TAG_INT16 => {
                let bs = self.take(2)?;
                Ok(Value::Number(Number::from(i16::from_le_bytes([bs[0], bs[1]]) as i64)))
            }
            TAG_INT32 => {
                let bs = self.take(4)?;
                Ok(Value::Number(Number::from(i32::from_le_bytes([bs[0], bs[1], bs[2], bs[3]]) as i64)))
            }
            TAG_INT64 => {
                let bs = self.take(8)?;
                Ok(Value::Number(Number::from(i64::from_le_bytes([
                    bs[0], bs[1], bs[2], bs[3], bs[4], bs[5], bs[6], bs[7],
                ]))))
            }
            TAG_FLOAT64 => {
                let bs = self.take(8)?;
                let bits = u64::from_le_bytes([bs[0], bs[1], bs[2], bs[3], bs[4], bs[5], bs[6], bs[7]]);
                let v = f64::from_bits(bits);
                Number::from_f64(v).map(Value::Number).ok_or_else(|| "cxcol: NaN/Inf rejected".to_owned())
            }
            TAG_STRING => Ok(Value::String(self.string_payload()?)),
            TAG_BYTES => {
                let n = self.uvarint()? as usize;
                let bs = self.take(n)?;
                // Map :bytes to a base64-ish array of ints? For simplicity
                // we surface the raw bytes as a string of one-byte chars.
                // Future: surface as a tagged variant or Vec<u8>.
                Ok(Value::String(bs.iter().map(|b| *b as char).collect()))
            }
            TAG_DATE => {
                let bs = self.take(4)?;
                let year = i16::from_le_bytes([bs[0], bs[1]]);
                Ok(Value::String(format!("{:04}-{:02}-{:02}", year, bs[2], bs[3])))
            }
            TAG_DATETIME => {
                self.take(10)?; // placeholder
                let src_len = self.u16()? as usize;
                let bs = self.take(src_len)?;
                Ok(Value::String(String::from_utf8(bs.to_vec()).map_err(|e| e.to_string())?))
            }
            TAG_ARRAY => {
                let count = self.uvarint()? as usize;
                if count == 0 {
                    return Err("cxcol: array tag 0x40 with count=0; use 0x41 for empty".to_owned());
                }
                let mut out = Vec::with_capacity(count);
                for _ in 0..count {
                    out.push(self.value()?);
                }
                Ok(Value::Array(out))
            }
            TAG_ARRAY_EMPTY => Ok(Value::Array(vec![])),
            TAG_MAP => {
                let count = self.uvarint()? as usize;
                if count == 0 {
                    return Err("cxcol: map tag 0x50 with count=0; use 0x51 for empty".to_owned());
                }
                let mut out = Map::with_capacity(count);
                for _ in 0..count {
                    let key_tag = self.u8()?;
                    if key_tag != TAG_STRING {
                        return Err(format!("cxcol: map key must be string; got 0x{:02x}", key_tag));
                    }
                    let key = self.string_payload()?;
                    let val = self.value()?;
                    out.insert(key, val);
                }
                Ok(Value::Object(out))
            }
            TAG_MAP_EMPTY => Ok(Value::Object(Map::new())),
            TAG_TABLE | TAG_TABLE_EMPTY => self.table_payload(tag),
            other => Err(format!("cxcol: unknown tag 0x{:02x} at offset {}", other, self.pos - 1)),
        };
        self.depth -= 1;
        result
    }

    fn table_payload(&mut self, tag: u8) -> Result<Value, String> {
        if tag == TAG_TABLE_EMPTY {
            return Ok(Value::Array(vec![]));
        }
        let col_count = self.uvarint()? as usize;
        let mut cols = Vec::with_capacity(col_count);
        for _ in 0..col_count {
            let key_tag = self.u8()?;
            if key_tag != TAG_STRING {
                return Err(format!("cxcol: table column name must be string; got 0x{:02x}", key_tag));
            }
            let name = self.string_payload()?;
            self.u8()?; // column type code
            cols.push(name);
        }
        let row_count = self.uvarint()? as usize;
        let mut rows: Vec<Value> = (0..row_count)
            .map(|_| Value::Object(Map::with_capacity(col_count)))
            .collect();
        for col_idx in 0..col_count {
            for row in rows.iter_mut().take(row_count) {
                let val = self.value()?;
                if let Value::Object(ref mut m) = row {
                    m.insert(cols[col_idx].clone(), val);
                }
            }
        }
        Ok(Value::Array(rows))
    }
}

// ── Writer ───────────────────────────────────────────────────────────────────

struct Writer {
    buf: Vec<u8>,
}

impl Writer {
    fn new() -> Self {
        Self { buf: Vec::with_capacity(256) }
    }

    fn u8(&mut self, v: u8) { self.buf.push(v); }
    fn u16(&mut self, v: u16) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn u32(&mut self, v: u32) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn i64(&mut self, v: i64) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn f64(&mut self, v: f64) { self.buf.extend_from_slice(&v.to_le_bytes()); }
    fn uvarint(&mut self, mut v: u64) {
        while v >= 0x80 {
            self.buf.push(((v & 0x7F) as u8) | 0x80);
            v >>= 7;
        }
        self.buf.push((v & 0x7F) as u8);
    }
    fn string_value(&mut self, s: &str) {
        self.u8(TAG_STRING);
        self.uvarint(s.len() as u64);
        self.buf.extend_from_slice(s.as_bytes());
    }

    fn value(&mut self, v: &Value) -> Result<(), String> {
        match v {
            Value::Null => self.u8(TAG_NULL),
            Value::Bool(true) => self.u8(TAG_TRUE),
            Value::Bool(false) => self.u8(TAG_FALSE),
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    self.int_canonical(i);
                } else if let Some(u) = n.as_u64() {
                    if u <= i64::MAX as u64 {
                        self.int_canonical(u as i64);
                    } else {
                        return Err(format!("cxcol: u64 {} exceeds i64 range", u));
                    }
                } else if let Some(f) = n.as_f64() {
                    self.u8(TAG_FLOAT64);
                    self.f64(f);
                } else {
                    return Err("cxcol: unsupported Number variant".to_owned());
                }
            }
            Value::String(s) => self.string_value(s),
            Value::Array(arr) => {
                if arr.is_empty() {
                    self.u8(TAG_ARRAY_EMPTY);
                } else {
                    self.u8(TAG_ARRAY);
                    self.uvarint(arr.len() as u64);
                    for item in arr {
                        self.value(item)?;
                    }
                }
            }
            Value::Object(map) => {
                if map.is_empty() {
                    self.u8(TAG_MAP_EMPTY);
                } else {
                    self.u8(TAG_MAP);
                    self.uvarint(map.len() as u64);
                    for (k, vv) in map {
                        self.string_value(k);
                        self.value(vv)?;
                    }
                }
            }
        }
        Ok(())
    }

    fn int_canonical(&mut self, v: i64) {
        if (-128..=127).contains(&v) {
            self.u8(TAG_INT8);
            self.buf.push(v as i8 as u8);
        } else if (-32_768..=32_767).contains(&v) {
            self.u8(TAG_INT16);
            self.u16(v as i16 as u16);
        } else if (-2_147_483_648..=2_147_483_647).contains(&v) {
            self.u8(TAG_INT32);
            self.u32(v as i32 as u32);
        } else {
            self.u8(TAG_INT64);
            self.i64(v);
        }
    }
}
