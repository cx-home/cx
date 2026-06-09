//! Round-trip tests for the Rust data_bin one-shot wrappers
//! (Phase 7.28 V core; Phase 7.32 Rust binding).
//!
//! Loaders return UNFRAMED payload bytes (matching `to_data_bin`'s
//! convention; the wrapper strips the [u32 LE size] frame). Dumpers
//! expect FRAMED input (matching `from_data_bin`'s convention). Tests
//! use a `reframe` helper to bridge.

use cxlib::data_bin::*;

fn reframe(payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(4 + payload.len());
    let size = payload.len() as u32;
    out.extend_from_slice(&size.to_le_bytes());
    out.extend_from_slice(payload);
    out
}

// ── XML one-shot ─────────────────────────────────────────────────────────────

#[test]
fn xml_to_data_bin_returns_cxcol_payload() {
    let payload = xml_to_data_bin("<server><host>localhost</host><port>8080</port></server>")
        .expect("xml_to_data_bin");
    assert!(payload.len() > 5, "expected non-empty payload, got {} bytes", payload.len());
    // Magic check — 5-byte "CXCol" per spec/core/data-bin.md §3.1 (v0.8.0).
    assert_eq!(&payload[..5], b"CXCol", "expected CXCol magic, got {:?}", &payload[..5]);
}

#[test]
fn xml_round_trip_through_data_bin() {
    let payload = xml_to_data_bin("<server><host>localhost</host><port>8080</port></server>")
        .expect("xml_to_data_bin");
    let out = data_bin_to_xml(&reframe(&payload)).expect("data_bin_to_xml");
    assert!(out.contains("server"), "expected server in xml output, got: {}", out);
    assert!(out.contains("localhost"), "expected localhost, got: {}", out);
    assert!(out.contains("8080"), "expected 8080, got: {}", out);
}

// ── JSON one-shot ────────────────────────────────────────────────────────────

#[test]
fn json_round_trip_through_data_bin() {
    let payload = json_to_data_bin(r#"{"name": "alice", "id": 1}"#).expect("json_to_data_bin");
    let out = data_bin_to_json(&reframe(&payload)).expect("data_bin_to_json");
    assert!(out.contains("alice"));
    assert!(out.contains("1"));
}

// ── YAML one-shot ────────────────────────────────────────────────────────────

#[test]
fn yaml_round_trip_through_data_bin() {
    let payload = yaml_to_data_bin("name: alice\nid: 1\n").expect("yaml_to_data_bin");
    let out = data_bin_to_yaml(&reframe(&payload)).expect("data_bin_to_yaml");
    assert!(out.contains("alice"));
}

// ── TOML one-shot ────────────────────────────────────────────────────────────

#[test]
fn toml_round_trip_through_data_bin() {
    let payload = toml_to_data_bin("name = \"alice\"\nid = 1\n").expect("toml_to_data_bin");
    let out = data_bin_to_toml(&reframe(&payload)).expect("data_bin_to_toml");
    assert!(out.contains("alice"));
}

// ── Cross-format compositions ────────────────────────────────────────────────

#[test]
fn xml_to_data_bin_to_json() {
    let payload = xml_to_data_bin(r#"<user id="1" name="alice"/>"#).expect("xml_to_data_bin");
    let out = data_bin_to_json(&reframe(&payload)).expect("data_bin_to_json");
    assert!(out.contains("alice"));
    assert!(out.contains("1"));
}

#[test]
fn json_to_data_bin_to_yaml() {
    let payload = json_to_data_bin(r#"{"name": "alice", "active": true}"#)
        .expect("json_to_data_bin");
    let out = data_bin_to_yaml(&reframe(&payload)).expect("data_bin_to_yaml");
    assert!(out.contains("alice"));
}

#[test]
fn toml_to_data_bin_to_xml() {
    let payload = toml_to_data_bin("host = \"localhost\"\nport = 8080\n")
        .expect("toml_to_data_bin");
    let out = data_bin_to_xml(&reframe(&payload)).expect("data_bin_to_xml");
    assert!(out.contains("localhost"));
    assert!(out.contains("8080"));
}
