//! Round-trip tests for the Rust delimited (CSV/TSV/PSV) wrappers
//! (Phase 7.67 V core; Phase 7.68 Rust binding).
//!
//! Mirrors the 12-case shape of `vcx/tests/v34_delimited_test.v`,
//! `lang/python/test_delimited.py`, and `lang/go/cxlib/delimited_test.go`.
//!
//! Loaders return UNFRAMED CXCol payload bytes (matching the existing
//! `xml_to_data_bin` / `json_to_data_bin` convention; the wrapper strips
//! the [u32 LE size] frame). Dumpers expect FRAMED input. Tests use a
//! `reframe` helper to bridge.

use cxlib::data_bin::*;

fn reframe(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    let size = payload.len() as u32;
    out.extend_from_slice(&size.to_le_bytes());
    out.extend_from_slice(payload);
    out
}

// ── Emit (5) ─────────────────────────────────────────────────────────────────

#[test]
fn to_csv_table_direct() {
    let src = "[users [table[name::string age::int active::bool]]\n  alice 30 true\n  bob 25 false\n]";
    let out = to_csv(src).expect("to_csv");
    assert_eq!(out, "name,age,active\r\nalice,30,true\r\nbob,25,false\r\n");
}

#[test]
fn to_csv_repeated_row() {
    let src = "[users\n  [user id=1 name=alice admin=true]\n  [user id=2 name=bob]\n  [user id=3 name=carol admin=true]\n]";
    let out = to_csv(src).expect("to_csv");
    assert_eq!(out, "id,name,admin\r\n1,alice,true\r\n2,bob,\r\n3,carol,true\r\n");
}

#[test]
fn to_csv_dotted_path() {
    let src = "[config\n  [server host=localhost port=8080 tls=true]\n  [logging level=info format=json]\n]";
    let out = to_csv(src).expect("to_csv");
    let want = "server.host,server.port,server.tls,logging.level,logging.format\r\nlocalhost,8080,true,info,json\r\n";
    assert_eq!(out, want);
}

#[test]
fn to_tsv_basic() {
    let src = "[t [table[a b c]]\n  x y z\n]";
    let out = to_tsv(src).expect("to_tsv");
    assert_eq!(out, "a\tb\tc\r\nx\ty\tz\r\n");
}

#[test]
fn to_psv_basic() {
    let src = "[t [table[a b]]\n  x y\n]";
    let out = to_psv(src).expect("to_psv");
    assert_eq!(out, "a|b\r\nx|y\r\n");
}

// ── Parse (3) ────────────────────────────────────────────────────────────────

#[test]
fn from_csv_auto_types() {
    let csv_in = "name,age,active\nalice,30,true\nbob,25,false\n";
    let out = from_csv(csv_in).expect("from_csv");
    let want = "[table [table[name age::int active::bool]]\n  alice 30 true\n  bob 25 false\n]";
    assert_eq!(out, want);
}

#[test]
fn from_csv_quoted_stays_string() {
    let csv_in = "name,age\nalice,\"30\"\nbob,\"25\"\n";
    let out = from_csv(csv_in).expect("from_csv");
    let want = "[table [table[name age]]\n  alice 30\n  bob 25\n]";
    assert_eq!(out, want);
}

#[test]
fn from_csv_empty_cell_is_null() {
    let csv_in = "name,age\nalice,30\nbob,\n";
    let out = from_csv(csv_in).expect("from_csv");
    let want = "[table [table[name age::int]]\n  alice 30\n  bob null\n]";
    assert_eq!(out, want);
}

// ── Arbitrary delimiter + binary one-shots (4) ───────────────────────────────

#[test]
fn to_delimited_semicolon() {
    let src = "[t [table[a b]]\n  x y\n]";
    let out = to_delimited(src, b';').expect("to_delimited");
    assert_eq!(out, "a;b\r\nx;y\r\n");
}

#[test]
fn csv_to_data_bin_round_trip() {
    let payload = csv_to_data_bin("name,age\nalice,30\nbob,25\n").expect("csv_to_data_bin");
    assert!(payload.len() >= 5, "expected non-empty payload, got {} bytes", payload.len());
    assert_eq!(&payload[..5], b"CXCol", "expected CXCol magic, got {:?}", &payload[..5]);
    let out = data_bin_to_csv(&reframe(&payload)).expect("data_bin_to_csv");
    assert_eq!(out, "name,age\r\nalice,30\r\nbob,25\r\n");
}

#[test]
fn tsv_to_data_bin_round_trip() {
    let payload = tsv_to_data_bin("a\tb\nx\ty\n").expect("tsv_to_data_bin");
    let out = data_bin_to_tsv(&reframe(&payload)).expect("data_bin_to_tsv");
    assert_eq!(out, "a\tb\r\nx\ty\r\n");
}

#[test]
fn psv_to_data_bin_round_trip() {
    let payload = psv_to_data_bin("a|b\nx|y\n").expect("psv_to_data_bin");
    let out = data_bin_to_psv(&reframe(&payload)).expect("data_bin_to_psv");
    assert_eq!(out, "a|b\r\nx|y\r\n");
}
