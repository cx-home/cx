//! Integration tests for the Phase 7.65 ID/IDREF C ABI wrappers
//! (`cx_id_lookup`, `cx_resolve_ref`, `cx_node_id`) per ADR 0003.

use cxlib::{id_lookup, resolve_ref, node_id};
use serde_json::Value;

const DOC: &str = "[users\n  [user #u-1 name=alice]\n  [user #u-2 name=bob]\n  [reviewer assigned-to=@u-1]\n]\n";

#[test]
fn test_id_lookup_happy_path() {
    let out = id_lookup(DOC, "u-1").expect("id_lookup ok");
    let s = out.expect("id_lookup found u-1");
    let v: Value = serde_json::from_str(&s).expect("AST-JSON parses");
    assert_eq!(v["type"], "Element");
    assert_eq!(v["name"], "user");
    assert_eq!(v["id"], "u-1");
}

#[test]
fn test_id_lookup_missing_returns_none() {
    let out = id_lookup(DOC, "does-not-exist").expect("id_lookup ok");
    assert!(out.is_none(), "missing id should return Ok(None), got {:?}", out);
}

#[test]
fn test_resolve_ref_equals_id_lookup() {
    let a = id_lookup(DOC, "u-2").expect("id_lookup ok").expect("u-2 found");
    let b = resolve_ref(DOC, "u-2").expect("resolve_ref ok").expect("u-2 found");
    assert_eq!(a, b, "resolve_ref must equal id_lookup for shared namespace");
}

#[test]
fn test_node_id_at_cxpath() {
    let user = node_id(DOC, "//user").expect("node_id ok");
    assert_eq!(user.as_deref(), Some("u-1"));

    let reviewer = node_id(DOC, "//reviewer").expect("node_id ok");
    assert!(reviewer.is_none(), "reviewer has no id, expected None, got {:?}", reviewer);
}
