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
//!
//! I1 L48 (identity epoch): `decimal` and `bigint` are first-class
//! semantic kinds with their own wire tags (0x28 / 0x18). serde_json's
//! `Value` has no carrier for them, so the native codec decodes into
//! [`CxValue`] (full fidelity — see `decode_payload_value` /
//! `encode_value`); the JSON-facing `decode_payload` / `encode` pair is
//! a projection of it and fails loudly instead of erasing either kind.

use bigdecimal::BigDecimal;
use num_bigint::BigInt;
use serde_json::{Map, Number, Value};
use std::os::raw::c_char;
use std::ffi::CString;
use std::ptr;
use std::str::FromStr;

// Tag bytes — see spec/core/data-bin.md §3.2.
const TAG_NULL: u8         = 0x00;
const TAG_FALSE: u8        = 0x01;
const TAG_TRUE: u8         = 0x02;
const TAG_INT8: u8         = 0x10;
const TAG_INT16: u8        = 0x11;
const TAG_INT32: u8        = 0x12;
const TAG_INT64: u8        = 0x13;
// I1 L48: in-i64 bigint still encodes 0x18 (narrowing-within-kind — a
// kind is never erased). Matches V's `tag_bigint` in vcx/cx/data_bin.v.
const TAG_BIGINT: u8       = 0x18;
const TAG_FLOAT64: u8      = 0x20;
const TAG_DECIMAL: u8      = 0x28;
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

// ── Native value tree (I1 L48) ───────────────────────────────────────────────

/// Full-fidelity CXCol value tree.
///
/// The I1 identity epoch promoted `decimal` and `bigint` to first-class
/// semantic kinds (spec/03-approved/misc/type-mapping.md §2):
/// `decimal` maps to `bigdecimal::BigDecimal`, `bigint` to
/// `num_bigint::BigInt`. `serde_json::Value` cannot carry either, so
/// the native codec works on `CxValue` and the JSON-facing
/// `decode_payload` / `encode` pair is a lossless-or-error projection.
#[derive(Debug, Clone, PartialEq)]
pub enum CxValue {
    Null,
    Bool(bool),
    /// `int` kind. Encodes with canonical narrowing across the int-tag
    /// family (0x10/0x11/0x12/0x13) — never 0x18.
    Int(i64),
    Float(f64),
    /// `bigint` kind — base-10 integer image under tag 0x18. A bigint
    /// that fits i64 STILL rides 0x18 (narrowing-within-kind: the kind
    /// is never erased).
    BigInt(BigInt),
    /// `decimal` kind — FIXED-POINT base-10 image under tag 0x28.
    /// Scale (trailing zeros) is preserved: "1.10" stays "1.10".
    /// Exponent form is NOT a legal wire image.
    Decimal(BigDecimal),
    String(String),
    Array(Vec<CxValue>),
    /// Insertion-ordered map (mirrors V's `DataPairs`).
    Map(Vec<(String, CxValue)>),
}

impl CxValue {
    /// Project into a `serde_json::Value`. Fails loudly on `BigInt` /
    /// `Decimal` — JSON has no carrier for those kinds and the kind is
    /// never erased (I1 L48); use [`decode_payload_value`] to receive
    /// them natively.
    pub fn into_json(self) -> Result<Value, String> {
        match self {
            CxValue::Null => Ok(Value::Null),
            CxValue::Bool(b) => Ok(Value::Bool(b)),
            CxValue::Int(i) => Ok(Value::Number(Number::from(i))),
            CxValue::Float(f) => Number::from_f64(f)
                .map(Value::Number)
                .ok_or_else(|| "cxcol: NaN/Inf rejected".to_owned()),
            CxValue::BigInt(_) => Err(
                "cxcol: bigint value has no serde_json::Value carrier; \
                 use decode_payload_value (CxValue::BigInt) — the kind is \
                 never erased (I1 L48)".to_owned()),
            CxValue::Decimal(_) => Err(
                "cxcol: decimal value has no serde_json::Value carrier; \
                 use decode_payload_value (CxValue::Decimal) — the kind is \
                 never erased (I1 L48)".to_owned()),
            CxValue::String(s) => Ok(Value::String(s)),
            CxValue::Array(items) => {
                let mut out = Vec::with_capacity(items.len());
                for item in items {
                    out.push(item.into_json()?);
                }
                Ok(Value::Array(out))
            }
            CxValue::Map(pairs) => {
                let mut out = Map::with_capacity(pairs.len());
                for (k, v) in pairs {
                    out.insert(k, v.into_json()?);
                }
                Ok(Value::Object(out))
            }
        }
    }
}

impl From<&Value> for CxValue {
    fn from(v: &Value) -> CxValue {
        match v {
            Value::Null => CxValue::Null,
            Value::Bool(b) => CxValue::Bool(*b),
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    CxValue::Int(i)
                } else if let Some(u) = n.as_u64() {
                    // u64 above i64::MAX: a native integer outside the
                    // i64 range dumps with the bigint encoding per
                    // spec/03-approved/misc/type-mapping.md §5 (matches
                    // V's cx_to_data_bin auto-promotion, L20).
                    CxValue::BigInt(BigInt::from(u))
                } else {
                    // serde_json Numbers are i64 / u64 / f64; this arm
                    // is the finite-f64 remainder.
                    CxValue::Float(n.as_f64().unwrap_or(0.0))
                }
            }
            Value::String(s) => CxValue::String(s.clone()),
            Value::Array(arr) => CxValue::Array(arr.iter().map(CxValue::from).collect()),
            Value::Object(map) => CxValue::Map(
                map.iter().map(|(k, v)| (k.clone(), CxValue::from(v))).collect()),
        }
    }
}

// Wire-image validation (I1 L48). Both kinds carry a base-10 image in
// the same length-prefixed payload the string tag uses. `decimal` is
// FIXED-POINT only — optional '-', digits, optional '.' + digits;
// exponent form is not a legal wire image. `bigint` is the integer
// subset (no fraction).
fn check_base10_image(s: &str, kind: &str, allow_fraction: bool) -> Result<(), String> {
    let body = s.strip_prefix('-').unwrap_or(s);
    let (int_part, frac_part) = match body.split_once('.') {
        Some((i, f)) if allow_fraction => (i, Some(f)),
        Some(_) => {
            return Err(format!(
                "cxcol: {} wire image {:?} must be a base-10 integer", kind, s));
        }
        None => (body, None),
    };
    let all_digits = |p: &str| !p.is_empty() && p.bytes().all(|b| b.is_ascii_digit());
    let ok = all_digits(int_part) && frac_part.map_or(true, all_digits);
    if !ok {
        return Err(format!(
            "cxcol: {} wire image {:?} is not a fixed-point base-10 image \
             (exponent form is not a legal wire image)", kind, s));
    }
    Ok(())
}

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
///
/// I1 L48: payloads carrying `decimal` (0x28) or `bigint` (0x18)
/// values fail loudly here — JSON has no carrier for those kinds and
/// the kind is never erased. Use [`decode_payload_value`] to receive
/// them as `CxValue::Decimal` / `CxValue::BigInt`.
pub fn decode_payload(payload: &[u8]) -> Result<Value, String> {
    decode_payload_value(payload)?.into_json()
}

/// Decode a CXCol v1 PAYLOAD (12-byte header + value section) into the
/// full-fidelity [`CxValue`] tree. This is the native decoder;
/// `decode_payload` is its JSON projection. `decimal` (0x28) decodes
/// to `CxValue::Decimal` with scale preserved ("1.10" stays "1.10");
/// `bigint` (0x18) decodes to `CxValue::BigInt` even when the value
/// fits i64 — the kind is never erased (I1 L48).
pub fn decode_payload_value(payload: &[u8]) -> Result<CxValue, String> {
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
///
/// A Number above i64::MAX encodes with the bigint tag (0x18) per
/// spec/03-approved/misc/type-mapping.md §5 (native integer outside
/// the i64 range dumps as the bigint encoding, matching V core).
pub fn encode(value: &Value) -> Result<Vec<u8>, String> {
    encode_value(&CxValue::from(value))
}

/// Encode a [`CxValue`] as a framed CXCol v1 buffer. This is the
/// native encoder; `encode` is its JSON entry point. `CxValue::BigInt`
/// always rides tag 0x18 — even when the value fits i64 — and
/// `CxValue::Decimal` rides 0x28 with a fixed-point base-10 image
/// (never exponent notation). Plain `CxValue::Int` stays on the
/// int-tag family (0x10..0x13, canonical narrowing).
pub fn encode_value(value: &CxValue) -> Result<Vec<u8>, String> {
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

    fn value(&mut self) -> Result<CxValue, String> {
        self.depth += 1;
        if self.depth > self.max_depth {
            return Err(format!("cxcol: recursion depth exceeds limit ({})", self.max_depth));
        }
        let tag = self.u8()?;
        let result = match tag {
            TAG_NULL => Ok(CxValue::Null),
            TAG_FALSE => Ok(CxValue::Bool(false)),
            TAG_TRUE => Ok(CxValue::Bool(true)),
            TAG_INT8 => {
                let bs = self.take(1)?;
                Ok(CxValue::Int(bs[0] as i8 as i64))
            }
            TAG_INT16 => {
                let bs = self.take(2)?;
                Ok(CxValue::Int(i16::from_le_bytes([bs[0], bs[1]]) as i64))
            }
            TAG_INT32 => {
                let bs = self.take(4)?;
                Ok(CxValue::Int(i32::from_le_bytes([bs[0], bs[1], bs[2], bs[3]]) as i64))
            }
            TAG_INT64 => {
                let bs = self.take(8)?;
                Ok(CxValue::Int(i64::from_le_bytes([
                    bs[0], bs[1], bs[2], bs[3], bs[4], bs[5], bs[6], bs[7],
                ])))
            }
            TAG_BIGINT => {
                // I1 L48: base-10 integer image; an in-i64 value still
                // arrives on 0x18 and stays a BigInt — kind preserved.
                let image = self.string_payload()?;
                check_base10_image(&image, "bigint", false)?;
                BigInt::from_str(&image)
                    .map(CxValue::BigInt)
                    .map_err(|e| format!("cxcol: bad bigint image {:?}: {}", image, e))
            }
            TAG_FLOAT64 => {
                let bs = self.take(8)?;
                let bits = u64::from_le_bytes([bs[0], bs[1], bs[2], bs[3], bs[4], bs[5], bs[6], bs[7]]);
                let v = f64::from_bits(bits);
                if !v.is_finite() {
                    return Err("cxcol: NaN/Inf rejected".to_owned());
                }
                Ok(CxValue::Float(v))
            }
            TAG_DECIMAL => {
                // I1 L48: fixed-point base-10 image; BigDecimal
                // preserves the scale ("1.10" stays "1.10").
                let image = self.string_payload()?;
                check_base10_image(&image, "decimal", true)?;
                BigDecimal::from_str(&image)
                    .map(CxValue::Decimal)
                    .map_err(|e| format!("cxcol: bad decimal image {:?}: {}", image, e))
            }
            TAG_STRING => Ok(CxValue::String(self.string_payload()?)),
            TAG_BYTES => {
                let n = self.uvarint()? as usize;
                let bs = self.take(n)?;
                // Map :bytes to a base64-ish array of ints? For simplicity
                // we surface the raw bytes as a string of one-byte chars.
                // Future: surface as a tagged variant or Vec<u8>.
                Ok(CxValue::String(bs.iter().map(|b| *b as char).collect()))
            }
            TAG_DATE => {
                let bs = self.take(4)?;
                let year = i16::from_le_bytes([bs[0], bs[1]]);
                Ok(CxValue::String(format!("{:04}-{:02}-{:02}", year, bs[2], bs[3])))
            }
            TAG_DATETIME => {
                self.take(10)?; // placeholder
                let src_len = self.u16()? as usize;
                let bs = self.take(src_len)?;
                Ok(CxValue::String(String::from_utf8(bs.to_vec()).map_err(|e| e.to_string())?))
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
                Ok(CxValue::Array(out))
            }
            TAG_ARRAY_EMPTY => Ok(CxValue::Array(vec![])),
            TAG_MAP => {
                let count = self.uvarint()? as usize;
                if count == 0 {
                    return Err("cxcol: map tag 0x50 with count=0; use 0x51 for empty".to_owned());
                }
                let mut out = Vec::with_capacity(count);
                for _ in 0..count {
                    let key_tag = self.u8()?;
                    if key_tag != TAG_STRING {
                        return Err(format!("cxcol: map key must be string; got 0x{:02x}", key_tag));
                    }
                    let key = self.string_payload()?;
                    let val = self.value()?;
                    out.push((key, val));
                }
                Ok(CxValue::Map(out))
            }
            TAG_MAP_EMPTY => Ok(CxValue::Map(Vec::new())),
            TAG_TABLE | TAG_TABLE_EMPTY => self.table_payload(tag),
            other => Err(format!("cxcol: unknown tag 0x{:02x} at offset {}", other, self.pos - 1)),
        };
        self.depth -= 1;
        result
    }

    fn table_payload(&mut self, tag: u8) -> Result<CxValue, String> {
        if tag == TAG_TABLE_EMPTY {
            return Ok(CxValue::Array(vec![]));
        }
        let col_count = self.uvarint()? as usize;
        let mut cols = Vec::with_capacity(col_count);
        let mut codes = Vec::with_capacity(col_count);
        for _ in 0..col_count {
            let key_tag = self.u8()?;
            if key_tag != TAG_STRING {
                return Err(format!("cxcol: table column name must be string; got 0x{:02x}", key_tag));
            }
            let name = self.string_payload()?;
            let mut code = self.u8()?; // §3.10.3 column type code (payload contract)
            if code == 0x82 {
                // §3.10.1 declared-name annotation (#807(c)) — the
                // declared spelling is a CX-render concern; codes drive
                // payloads here, so consume it and read the real code.
                let ann_tag = self.u8()?;
                if ann_tag != TAG_STRING {
                    return Err(format!("cxcol: declared-name annotation must carry a string; got 0x{:02x}", ann_tag));
                }
                let _ = self.string_payload()?;
                code = self.u8()?;
                if code == 0x82 {
                    return Err("cxcol: duplicate declared-name annotation in col-spec".to_string());
                }
            }
            codes.push(code);
            cols.push(name);
        }
        let row_count = self.uvarint()? as usize;
        let mut rows: Vec<Vec<(String, CxValue)>> = (0..row_count)
            .map(|_| Vec::with_capacity(col_count))
            .collect();
        for col_idx in 0..col_count {
            let cells = self.column_payload(codes[col_idx], row_count)?;
            for (row, cell) in rows.iter_mut().zip(cells.into_iter()) {
                row.push((cols[col_idx].clone(), cell));
            }
        }
        Ok(CxValue::Array(rows.into_iter().map(CxValue::Map).collect()))
    }

    // §3.10.3 typed column payloads (stream 17 W3 — the lattice rise:
    // per-column TYPED payloads, no per-cell tags; 0x80 nullable bitmap
    // wrapper; 0x81 mixed per-row tagged; 0x01 bit-packed bool).
    fn column_payload(&mut self, code: u8, row_count: usize) -> Result<Vec<CxValue>, String> {
        match code {
            0x00 => Ok(vec![CxValue::Null; row_count]),
            0x81 => (0..row_count).map(|_| self.value()).collect(),
            0x80 => {
                let inner = self.u8()?;
                let bitmap = self.take(row_count.div_ceil(8))?.to_vec();
                let nulls: Vec<bool> = (0..row_count)
                    .map(|i| (bitmap[i / 8] >> (i % 8)) & 1 == 1)
                    .collect();
                let n_nonnull = nulls.iter().filter(|n| !**n).count();
                let mut nonnull = self.typed_cells(inner, n_nonnull)?.into_iter();
                Ok(nulls
                    .into_iter()
                    .map(|is_null| {
                        if is_null {
                            CxValue::Null
                        } else {
                            nonnull.next().unwrap_or(CxValue::Null)
                        }
                    })
                    .collect())
            }
            _ => self.typed_cells(code, row_count),
        }
    }

    fn typed_cells(&mut self, code: u8, n: usize) -> Result<Vec<CxValue>, String> {
        let mut out = Vec::with_capacity(n);
        match code {
            0x01 => {
                // bool, bit-packed LSB-first (§3.10.4)
                let bits = self.take(n.div_ceil(8))?.to_vec();
                for i in 0..n {
                    out.push(CxValue::Bool((bits[i / 8] >> (i % 8)) & 1 == 1));
                }
            }
            0x10 => {
                let raw = self.take(n)?.to_vec();
                for b in raw {
                    out.push(CxValue::Int(b as i8 as i64));
                }
            }
            0x14 => {
                let raw = self.take(n)?.to_vec();
                for b in raw {
                    out.push(CxValue::Int(b as i64));
                }
            }
            0x11 | 0x15 => {
                let raw = self.take(2 * n)?.to_vec();
                for i in 0..n {
                    let v = u16::from_le_bytes([raw[2 * i], raw[2 * i + 1]]);
                    out.push(CxValue::Int(if code == 0x11 { v as i16 as i64 } else { v as i64 }));
                }
            }
            0x12 | 0x16 => {
                let raw = self.take(4 * n)?.to_vec();
                for i in 0..n {
                    let v = u32::from_le_bytes([raw[4 * i], raw[4 * i + 1], raw[4 * i + 2], raw[4 * i + 3]]);
                    out.push(CxValue::Int(if code == 0x12 { v as i32 as i64 } else { v as i64 }));
                }
            }
            0x13 | 0x17 => {
                let raw = self.take(8 * n)?.to_vec();
                for i in 0..n {
                    let mut b = [0u8; 8];
                    b.copy_from_slice(&raw[8 * i..8 * i + 8]);
                    out.push(CxValue::Int(i64::from_le_bytes(b)));
                }
            }
            0x20 => {
                let raw = self.take(8 * n)?.to_vec();
                for i in 0..n {
                    let mut b = [0u8; 8];
                    b.copy_from_slice(&raw[8 * i..8 * i + 8]);
                    out.push(CxValue::Float(f64::from_le_bytes(b)));
                }
            }
            0x21 => {
                let raw = self.take(4 * n)?.to_vec();
                for i in 0..n {
                    let mut b = [0u8; 4];
                    b.copy_from_slice(&raw[4 * i..4 * i + 4]);
                    out.push(CxValue::Float(f32::from_le_bytes(b) as f64));
                }
            }
            0x22 => {
                let raw = self.take(2 * n)?.to_vec();
                for i in 0..n {
                    let bits = u16::from_le_bytes([raw[2 * i], raw[2 * i + 1]]);
                    out.push(CxValue::Float(f16_bits_to_f64(bits)));
                }
            }
            0x18 => {
                for _ in 0..n {
                    let s = self.string_payload()?;
                    out.push(CxValue::BigInt(s.parse().map_err(|e| format!("cxcol: bigint image: {e}"))?));
                }
            }
            0x28 => {
                for _ in 0..n {
                    let s = self.string_payload()?;
                    out.push(CxValue::Decimal(s.parse().map_err(|e| format!("cxcol: decimal image: {e}"))?));
                }
            }
            0x30 | 0x33 | 0x70 => {
                for _ in 0..n {
                    out.push(CxValue::String(self.string_payload()?));
                }
            }
            0x31 => {
                for _ in 0..n {
                    let bs = self.take(4)?.to_vec();
                    let year = i16::from_le_bytes([bs[0], bs[1]]);
                    out.push(CxValue::String(format!("{:04}-{:02}-{:02}", year, bs[2], bs[3])));
                }
            }
            0x32 => {
                for _ in 0..n {
                    let bs = self.take(12)?.to_vec();
                    let mut nb = [0u8; 8];
                    nb.copy_from_slice(&bs[0..8]);
                    let ns = i64::from_le_bytes(nb);
                    // #807(d): offset_minutes rides the transport —
                    // render the local form (Z at offset 0).
                    let off = i16::from_le_bytes([bs[8], bs[9]]);
                    out.push(CxValue::String(format_datetime_ns_offset(ns, off)));
                }
            }
            _ => return Err(format!("cxcol: unknown column type code 0x{:02x}", code)),
        }
        Ok(out)
    }
}

// IEEE-754 binary16 → f64 (the decoder twin of the V-side converter).
fn f16_bits_to_f64(h: u16) -> f64 {
    let sign = ((h & 0x8000) as u32) << 16;
    let exp = ((h >> 10) & 0x1F) as i32;
    let mant = (h & 0x3FF) as u32;
    let bits: u32 = if exp == 0 {
        if mant == 0 {
            sign
        } else {
            let mut e = -1i32;
            let mut m = mant;
            while (m & 0x400) == 0 {
                m <<= 1;
                e -= 1;
            }
            m &= 0x3FF;
            sign | (((127 - 15 + e + 1) as u32) << 23) | (m << 13)
        }
    } else if exp == 31 {
        sign | 0x7F80_0000 | (mant << 13)
    } else {
        sign | (((exp - 15 + 127) as u32) << 23) | (mant << 13)
    };
    f32::from_bits(bits) as f64
}

// Render unix-nanos as the strict-canonical UTC ISO-8601 image.
fn format_datetime_ns_utc(ns: i64) -> String {
    format_datetime_ns_offset(ns, 0)
}

// #807(d): the local render for an offset-bearing wire datetime —
// unix_nanos is UTC; the suffix is 'Z' at offset 0, ±hh:mm otherwise.
fn format_datetime_ns_offset(ns: i64, off_min: i16) -> String {
    let local_ns = ns + i64::from(off_min) * 60 * 1_000_000_000;
    let secs = local_ns.div_euclid(1_000_000_000);
    let rem = local_ns.rem_euclid(1_000_000_000);
    let days = secs.div_euclid(86_400);
    let tod = secs.rem_euclid(86_400);
    let (y, m, d) = civil_from_days(days);
    let (hh, mm, ss) = (tod / 3600, (tod % 3600) / 60, tod % 60);
    let suffix = if off_min == 0 {
        "Z".to_string()
    } else {
        let sign = if off_min < 0 { '-' } else { '+' };
        let ab = off_min.unsigned_abs();
        format!("{sign}{:02}:{:02}", ab / 60, ab % 60)
    };
    if rem == 0 {
        format!("{y:04}-{m:02}-{d:02}T{hh:02}:{mm:02}:{ss:02}{suffix}")
    } else {
        format!("{y:04}-{m:02}-{d:02}T{hh:02}:{mm:02}:{ss:02}.{rem:09}{suffix}")
    }
}

// Howard Hinnant's days→civil algorithm.
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
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
        self.string_payload(s);
    }

    // Length-prefixed byte payload WITHOUT a leading tag — shared by
    // the string value form and the decimal / bigint image forms
    // (mirrors V's encode_string_payload).
    fn string_payload(&mut self, s: &str) {
        self.uvarint(s.len() as u64);
        self.buf.extend_from_slice(s.as_bytes());
    }

    fn value(&mut self, v: &CxValue) -> Result<(), String> {
        match v {
            CxValue::Null => self.u8(TAG_NULL),
            CxValue::Bool(true) => self.u8(TAG_TRUE),
            CxValue::Bool(false) => self.u8(TAG_FALSE),
            CxValue::Int(i) => self.int_canonical(*i),
            CxValue::Float(f) => {
                // NaN / Inf rejection per spec/policies.md §1.1, §1.2.
                if !f.is_finite() {
                    return Err("cxcol: NaN/Inf rejected".to_owned());
                }
                self.u8(TAG_FLOAT64);
                self.f64(*f);
            }
            CxValue::BigInt(b) => {
                // I1 L48: always 0x18 — an in-i64 bigint keeps its
                // kind (narrowing-within-kind never crosses kinds).
                self.u8(TAG_BIGINT);
                self.string_payload(&b.to_string());
            }
            CxValue::Decimal(d) => {
                // I1 L48: fixed-point base-10 image only — never
                // exponent notation (to_plain_string, not Display,
                // which may emit scientific form at extreme scales).
                self.u8(TAG_DECIMAL);
                self.string_payload(&d.to_plain_string());
            }
            CxValue::String(s) => self.string_value(s),
            CxValue::Array(arr) => {
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
            CxValue::Map(pairs) => {
                if pairs.is_empty() {
                    self.u8(TAG_MAP_EMPTY);
                } else {
                    self.u8(TAG_MAP);
                    self.uvarint(pairs.len() as u64);
                    for (k, vv) in pairs {
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
