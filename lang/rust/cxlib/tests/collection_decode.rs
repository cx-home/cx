//! Regression: the Rust binary AST decoder must handle the v0.8.0 collection
//! node tags 0x0F SequenceNode / 0x10 ArrayNode / 0x11 MapNode. Before the fix
//! `read_node` returned `Err("unknown AST node type")` for them, so any CX
//! document containing a collection (e.g. `conformance/schema_validate.cxd`'s
//! `[expect-codes [:S…]]` atom arrays) failed to parse via the Rust binding.

use cxlib::ast::{self, Node};

#[test]
fn array_node_decodes() {
    // An atom array nested in an element, plus a sibling — the shape that
    // desynced the Python/Go decoders before their fix.
    let doc = ast::parse("[s [a [:S002]] [b [:S003]]]").expect("parse");
    let root = match &doc.elements[0] {
        Node::Element(e) => e,
        other => panic!("expected element, got {other:?}"),
    };
    assert_eq!(root.name, "s");
    assert_eq!(root.items.len(), 2);
    let a = match &root.items[0] {
        Node::Element(e) => e,
        other => panic!("expected element, got {other:?}"),
    };
    match &a.items[0] {
        Node::ArrayNode(items) => assert_eq!(items.len(), 1),
        other => panic!("expected ArrayNode, got {other:?}"),
    }
}

#[test]
fn sequence_and_map_decode() {
    assert!(ast::parse("[x (1, 2, 3)]").is_ok(), "sequence literal");
    assert!(ast::parse("[x [1, 2, 3]]").is_ok(), "array literal");
    assert!(ast::parse("[x {k: 1, j: 2}]").is_ok(), "map literal");
}

#[test]
fn schema_validate_loads() {
    // The suite that was previously un-loadable via the Rust binding.
    let mut p = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    for _ in 0..8 {
        if p.join("conformance/schema_validate.cxd").exists() {
            break;
        }
        if !p.pop() {
            break;
        }
    }
    let path = p.join("conformance/schema_validate.cxd");
    if !path.exists() {
        return; // safe no-op if the fixture isn't reachable
    }
    let cases =
        cxlib::fixtures::load_fixtures(path.to_str().unwrap()).expect("load schema_validate.cxd");
    assert!(!cases.is_empty());
    // sv-002 carries `[expect-codes [:S002]]` → reconstructs to "S002".
    let sv002 = cases
        .iter()
        .find(|c| c.name.starts_with("sv-002"))
        .expect("sv-002 present");
    assert_eq!(
        sv002.sections.get("sv_expected_codes").map(String::as_str),
        Some("S002"),
        "atom-array expect-codes reconstruction"
    );
}
