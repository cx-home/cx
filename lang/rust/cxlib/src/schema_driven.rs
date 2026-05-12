//! Schema-driven CXDB encoding (Phase 7.73 / 7.74b; spec/abi.md §2.12,
//! capability bit 24).
//!
//! Loaders take `(input, schema, ref_form, name_hint)` and return
//! unframed CXDB payload bytes. The dumper takes a framed CXDB buffer
//! plus an optional schema hint and returns canonical CX text.
//!
//! `ref_form`: 0 = content-hash only (default; spec/data_bin.md
//! §3.13.1 tag 0x10), 1 = inline schema bytes (tag 0x11), 2 =
//! content-hash + name hint (tag 0x12).

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;

extern "C" {
    fn cx_free(s: *mut c_char);

    fn cx_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_xml_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_json_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_yaml_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_toml_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_md_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_csv_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_tsv_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_psv_to_data_bin_schema_driven(input: *const c_char, schema: *const c_char,
        ref_form: c_int, name_hint: *const c_char, err_out: *mut *mut c_char) -> *mut c_char;
    fn cx_from_data_bin_schema_driven(data_bin: *const c_char, schema_hint: *const c_char,
        err_out: *mut *mut c_char) -> *mut c_char;
}

type SchemaDrivenFn = unsafe extern "C" fn(
    *const c_char, *const c_char, c_int, *const c_char, *mut *mut c_char) -> *mut c_char;

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

fn call_loader(f: SchemaDrivenFn, input: &str, schema: &str,
               ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    crate::ensure_thread();
    let c_input = CString::new(input).map_err(|e| e.to_string())?;
    let c_schema = CString::new(schema).map_err(|e| e.to_string())?;
    let c_hint = CString::new(name_hint).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe {
        f(c_input.as_ptr(), c_schema.as_ptr(), ref_form as c_int,
          c_hint.as_ptr(), &mut err_ptr)
    };
    if raw.is_null() {
        return Err(unsafe { take_err(err_ptr, "schema-driven loader: unknown error") });
    }
    Ok(unsafe { copy_framed_and_free(raw) })
}

pub fn to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn xml_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_xml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn json_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_json_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn yaml_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_yaml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn toml_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_toml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn md_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_md_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn csv_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_csv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn tsv_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_tsv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}
pub fn psv_to_data_bin_schema_driven(input: &str, schema: &str, ref_form: i32, name_hint: &str) -> Result<Vec<u8>, String> {
    call_loader(cx_psv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)
}

/// Decode a framed CXDB schema-driven buffer to canonical CX text.
/// `schema_hint` (CX text) is consulted only when the embedded schema
/// reference is content-hash-only and not resolvable from the
/// consumer's content-addressable store; pass "" to use embedded
/// resolution.
pub fn from_data_bin_schema_driven(framed: &[u8], schema_hint: &str) -> Result<String, String> {
    if framed.is_empty() {
        return Err("from_data_bin_schema_driven: empty input".to_owned());
    }
    crate::ensure_thread();
    let c_hint = CString::new(schema_hint).map_err(|e| e.to_string())?;
    let mut err_ptr: *mut c_char = ptr::null_mut();
    let raw = unsafe {
        cx_from_data_bin_schema_driven(
            framed.as_ptr() as *const c_char, c_hint.as_ptr(), &mut err_ptr)
    };
    if raw.is_null() {
        return Err(unsafe { take_err(err_ptr, "cx_from_data_bin_schema_driven: unknown error") });
    }
    let s = unsafe { CStr::from_ptr(raw).to_string_lossy().into_owned() };
    unsafe { cx_free(raw) };
    Ok(s)
}
