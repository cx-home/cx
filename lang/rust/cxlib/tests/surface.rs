// surface.rs — Phase 3.5 Rust Layer-1 retarget tests.
//
// Verifies the 16-method canonical Layer-1 surface per
// `spec/bindings.md §2.1` plus the code-projection
// helpers (`cx_code_diagram` / `cx_code_tree`). One test per Layer-1
// method (10 Doc + 6 Node = 16) plus surface-level smoke tests for
// the free functions, atom round-trip, and Layer-2 idioms.
//
// Mirrors `lang/python/test_surface.py` (Z66) and the analogous
// Go test file. Where V Layer-1 eval depends on directive-evaluation
// shapes that aren't yet wired at v0.8.0-dev (see Phase 2.x), the
// corresponding tests assert on the *error path* (CXER0100 surfaces,
// vs panicking). They will flip to positive-assertions once the
// remaining directive-eval bridges land.

use cxlib::{cx_code_diagram, cx_code_eval, cx_code_tree, Atom, atom_name, is_atom};
use cxlib::code::{self, Doc};
use cxlib::idioms::DocExt;
use serde_json::{json, Value};

const USERS_SRC: &str = "[users [user active=true [name Alice]] [user active=false [name Bob]] [user active=true [name Carol]]]";

// ── Doc Layer-1 methods 1..10 ─────────────────────────────────────────────────

#[test]
fn doc_method_01_parse_module_level() {
    // Module-level `parse(&[u8])` per spec/bindings.md §2.1 Method 1.
    let doc = code::parse(b"[doc [user [name Alice]]]").expect("parse");
    assert!(doc.root().is_some());
}

#[test]
fn doc_method_01b_parse_classmethod() {
    let doc = Doc::parse(b"[doc [user [name Alice]]]").expect("Doc::parse");
    assert!(doc.root().is_some());
}

#[test]
fn doc_method_02_bytes_roundtrip() {
    let src = "[doc [user [name Alice]]]";
    let doc = Doc::from_str(src).expect("parse");
    let bytes = doc.bytes();
    // Re-parsing the emitted bytes yields an equal document.
    let doc2 = Doc::parse(&bytes).expect("reparse bytes");
    assert!(doc.equals(&doc2).expect("equals"));
}

#[test]
fn doc_method_03_hash_stable_across_whitespace() {
    let a = Doc::from_str("[doc [x 1]]").expect("a");
    let b = Doc::from_str("[doc  [x  1]]").expect("b");
    // strict-canonical bytes should normalise whitespace.
    assert_eq!(a.hash().expect("a.hash"), b.hash().expect("b.hash"));
    // Hash is 64 hex chars.
    let h = a.hash().expect("hash");
    assert_eq!(h.len(), 64);
    assert!(h.chars().all(|c| c.is_ascii_hexdigit()));
}

#[test]
fn doc_method_04_equals_canonical_form() {
    let a = Doc::from_str("[doc [x 1]]").expect("a");
    let b = Doc::from_str("[doc  [x   1]]").expect("b");
    let c = Doc::from_str("[doc [x 2]]").expect("c");
    assert!(a.equals(&b).expect("equals a==b"));
    assert!(!a.equals(&c).expect("equals a!=c"));
}

#[test]
fn doc_method_05_eval_returns_text() {
    // Eval routes through cx_code_eval. A raw CXPath expression is a
    // valid program at v0.8.0 (the evaluator parses it as a value
    // expression). Default target is "text" — `Doc.eval` uses the
    // empty-string sentinel.
    let doc = Doc::from_str(USERS_SRC).expect("parse");
    let out = doc.eval_with_target("//user", "cx").expect("eval");
    // Three users in the fixture; the rendered output should mention
    // each name.
    assert!(out.contains("Alice"), "out missing Alice: {}", out);
    assert!(out.contains("Bob"),   "out missing Bob: {}", out);
    assert!(out.contains("Carol"), "out missing Carol: {}", out);
}

#[test]
fn doc_method_06_select_all_returns_nodes() {
    // select_all routes through cx_code_eval with the CXPath as the
    // program (matches Python `Document.select_all`).
    let doc = Doc::from_str(USERS_SRC).expect("parse");
    let users = doc.select_all("//user").expect("select_all");
    assert_eq!(users.len(), 3, "expected 3 users, got {}", users.len());
    for u in &users {
        assert_eq!(u.name(), "user");
    }
}

#[test]
fn doc_method_07_select_first_match() {
    let doc = Doc::from_str(USERS_SRC).expect("parse");
    let first = doc.select("//user").expect("select").expect("Some(node)");
    assert_eq!(first.name(), "user");
    // No match → Ok(None).
    let none = doc.select("//nonexistent").expect("select missing");
    assert!(none.is_none());
}

#[test]
fn doc_method_08_modify_returns_new_doc() {
    let doc = Doc::from_str(USERS_SRC).expect("parse");
    let new_doc = doc.modify("//user[@active=false]", "[delete]").expect("modify");
    // Pure-functional contract — receiver is unchanged.
    let orig_users = doc.select_all("//user").expect("orig select_all");
    assert_eq!(orig_users.len(), 3);
    // New Doc has Bob removed.
    let new_users = new_doc.select_all("//user").expect("new select_all");
    assert_eq!(new_users.len(), 2);
}

#[test]
fn doc_method_09_find_all_name_only() {
    // find_all is name-only and does NOT route through cx_code_eval,
    // so it works today.
    let doc = Doc::from_str("[doc [u [name Alice]] [u [name Bob]] [v [name Carol]]]")
        .expect("parse");
    let users = doc.find_all("u");
    assert_eq!(users.len(), 2);
    let names = doc.find_all("name");
    assert_eq!(names.len(), 3);
    let missing = doc.find_all("zzz");
    assert!(missing.is_empty());
}

#[test]
fn doc_method_10_root() {
    let doc = Doc::from_str("[doc [u [name Alice]]]").expect("parse");
    let root = doc.root().expect("root");
    assert_eq!(root.name(), "doc");
    let empty = Doc::from_str("").expect("empty parse");
    assert!(empty.root().is_none());
}

// ── Node Layer-1 methods 11..16 ───────────────────────────────────────────────

fn fixture_doc() -> Doc {
    // CX attribute surface form is `name=value` (no `@` prefix — the
    // `@` belongs in CXPath selectors, not attribute declarations).
    Doc::from_str("[doc [user id=1 active=true [name Alice] [age 42]]]")
        .expect("fixture parse")
}

#[test]
fn node_method_11_name() {
    let doc = fixture_doc();
    let root = doc.root().expect("root");
    assert_eq!(root.name(), "doc");
    let user = root.children().into_iter().next().expect("user");
    assert_eq!(user.name(), "user");
}

#[test]
fn node_method_12_attr() {
    let doc = fixture_doc();
    let user = doc.find_all("user").into_iter().next().expect("user");
    let id = user.attr("id").expect("@id");
    // Numeric attrs decode as a JSON number scalar.
    assert!(matches!(id, Value::Number(_)) || matches!(id, Value::String(_)));
    assert!(user.attr("definitely-not-an-attr").is_none());
}

#[test]
fn node_method_13_attrs_preserves_order() {
    let doc = fixture_doc();
    let user = doc.find_all("user").into_iter().next().expect("user");
    let attrs = user.attrs();
    assert_eq!(attrs.len(), 2);
    assert_eq!(attrs[0].0, "id");
    assert_eq!(attrs[1].0, "active");
}

#[test]
fn node_method_14_children_elements_only() {
    let doc = fixture_doc();
    let user = doc.find_all("user").into_iter().next().expect("user");
    let kids = user.children();
    assert_eq!(kids.len(), 2);
    assert_eq!(kids[0].name(), "name");
    assert_eq!(kids[1].name(), "age");
}

#[test]
fn node_method_15_body_scalar_round_trip() {
    let doc = Doc::from_str("[doc [n 42]]").expect("parse");
    let n = doc.find_all("n").into_iter().next().expect("n");
    let body = n.body();
    // Integer body — round-trips as a Number scalar.
    match body {
        Value::Number(num) => assert_eq!(num.as_i64(), Some(42)),
        Value::String(s) => assert_eq!(s, "42"),
        other => panic!("expected number or string body, got {:?}", other),
    }
}

#[test]
fn node_method_16_kind() {
    let doc = fixture_doc();
    let root = doc.root().expect("root");
    assert_eq!(root.kind(), "element");
}

// ── cx_code_eval / cx_code_diagram / cx_code_tree free fns ───────────────────

#[test]
fn free_fn_cx_code_eval_alias() {
    // cx_code_eval is the canonical name; routes
    // through cx_code_eval_with_len. Verify it's callable and
    // matches eval_code (the snake-case Rust idiom we keep).
    let res_canon = cx_code_eval("[doc]", "[?cx [marker]]", "cx");
    let res_idiom = cxlib::eval_code("[doc]", "[?cx [marker]]", "cx");
    assert_eq!(res_canon.is_ok(), res_idiom.is_ok());
    if let (Ok(a), Ok(b)) = (res_canon, res_idiom) {
        assert_eq!(a, b);
    }
}

#[test]
fn free_fn_cx_code_diagram_smoke() {
    let source = "[doc [user [name Alice]]]";
    let out = cx_code_diagram(source, "mermaid").expect("diagram");
    assert!(!out.is_empty(), "diagram should be non-empty");
    assert!(out.contains("flowchart"), "mermaid output: {}", out);
    assert!(out.contains("%%cx:"), "diagram should embed source per gate-9 contract: {}", out);
}

#[test]
fn free_fn_cx_code_diagram_unsupported_format_errs() {
    let res = cx_code_diagram("[doc]", "definitely-not-a-format");
    assert!(res.is_err());
}

#[test]
fn free_fn_cx_code_tree_returns_json_value() {
    let source = "[doc [user [name Alice]]]";
    let tree = cx_code_tree(source).expect("tree");
    // every node carries {kind, loc:{start,end}}.
    let kind = tree.get("kind").expect("kind field").as_str().expect("kind str");
    assert_eq!(kind, "element");
    let loc = tree.get("loc").expect("loc field");
    assert!(loc.get("start").is_some(), "loc.start required: {:?}", loc);
    assert!(loc.get("end").is_some(), "loc.end required: {:?}", loc);
}

#[test]
fn free_fn_cx_code_tree_handles_empty_source() {
    let tree = cx_code_tree("").expect("tree empty");
    // Empty source still emits a well-formed root.
    assert_eq!(tree.get("kind").and_then(|v| v.as_str()), Some("element"));
    let loc = tree.get("loc").expect("loc");
    assert_eq!(loc.get("start").and_then(|v| v.as_u64()), Some(0));
    assert_eq!(loc.get("end").and_then(|v| v.as_u64()), Some(0));
}

#[test]
fn free_fn_cx_code_tree_loc_offsets_in_source() {
    let source = "[doc [user]]";
    let tree = cx_code_tree(source).expect("tree");
    let loc = tree.get("loc").expect("loc");
    let start = loc.get("start").and_then(|v| v.as_u64()).expect("start");
    let end = loc.get("end").and_then(|v| v.as_u64()).expect("end");
    assert!(end >= start);
    assert!((end - start) as usize <= source.len());
}

// ── Doc.diagram() / Doc.tree() façades ───────────────────────────────────────

#[test]
fn doc_diagram_method_routes_to_cx_code_diagram() {
    let doc = Doc::from_str("[doc [user [name Alice]]]").expect("parse");
    let out = doc.diagram().expect("diagram");
    assert!(out.contains("flowchart"));
}

#[test]
fn doc_tree_method_routes_to_cx_code_tree() {
    let doc = Doc::from_str("[doc [user [name Alice]]]").expect("parse");
    let tree = doc.tree().expect("tree");
    assert_eq!(tree.get("kind").and_then(|v| v.as_str()), Some("element"));
}

// ── Atom round-trips ──────────────────────────────────────────

#[test]
fn atom_new_valid_name() {
    let a = Atom::new("ok").expect("atom");
    assert_eq!(a.name(), "ok");
    assert_eq!(a.to_string(), ":ok");
}

#[test]
fn atom_new_rejects_reserved() {
    assert!(Atom::new("true").is_err());
    assert!(Atom::new("false").is_err());
    assert!(Atom::new("null").is_err());
}

#[test]
fn atom_is_atom_predicate() {
    let v = json!("ok");
    assert!(is_atom(Some("atom"), &v));
    assert!(!is_atom(None, &v));
    assert!(!is_atom(Some("atom"), &Value::Number(serde_json::Number::from(42))));
}

#[test]
fn atom_name_accessor() {
    let v = json!("ok");
    assert_eq!(atom_name(Some("atom"), &v), Some("ok"));
    assert_eq!(atom_name(None, &v), None);
}

// ── Layer-2 idioms (`cxlib::idioms`) ─────────────────────────────────────────

#[test]
fn idioms_find_iter_routes_to_find_all() {
    let doc = Doc::from_str("[doc [u [n 1]] [u [n 2]] [v [n 3]]]").expect("parse");
    let users: Vec<_> = doc.find_iter("u").collect();
    assert_eq!(users.len(), 2);
    let ns: Vec<_> = doc.find_iter("n").collect();
    assert_eq!(ns.len(), 3);
}

#[test]
fn idioms_select_iter_iterates_select_all() {
    let doc = Doc::from_str(USERS_SRC).expect("parse");
    let users: Vec<_> = doc.select_iter("//user").expect("select_iter").collect();
    assert_eq!(users.len(), 3);
}

#[test]
fn idioms_diagram_with_explicit_format() {
    let doc = Doc::from_str("[doc [user]]").expect("parse");
    let out = doc.diagram_with("mermaid").expect("diagram");
    assert!(out.contains("flowchart"));
    let bad = doc.diagram_with("definitely-not-a-format");
    assert!(bad.is_err());
}

#[test]
fn idioms_explain_returns_layer_1_desugaring() {
    use cxlib::idioms::explain;
    let s = explain("select_iter", "//user");
    assert!(s.contains("select_all"));
    assert!(s.contains("//user"));
    let s = explain("find_iter", "user");
    assert!(s.contains("find_all"));
    let unknown = explain("nope", "x");
    assert!(unknown.contains("unknown"));
}
