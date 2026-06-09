//! ID/IDREF tests for the Rust binding.
//!
//! Mirrors lang/python/test_identity.py and V conformance/identity.txt.

use cxlib::ast::{parse, Element, Node};

fn root(d: &cxlib::ast::Document) -> &Element {
    for n in &d.elements {
        if let Node::Element(e) = n {
            return e;
        }
    }
    panic!("no root element")
}

#[test]
fn id_declaration_only_round_trips() {
    let cx_in = "[user #u-1 name=alice]";
    let doc = parse(cx_in).unwrap();
    assert_eq!(root(&doc).id.as_deref(), Some("u-1"));
    assert_eq!(doc.to_cx(), cx_in);
}

#[test]
fn id_with_anchor_coexists() {
    let doc = parse("[item &a #u-1 v=42]").unwrap();
    let item = root(&doc);
    assert_eq!(item.anchor.as_deref(), Some("a"));
    assert_eq!(item.id.as_deref(), Some("u-1"));
}

#[test]
fn attribute_value_reference_marked_is_ref() {
    let doc = parse("[users [user #u-1 name=alice] [reviewer assigned-to=@u-1]]").unwrap();
    let reviewer = doc.find_first("reviewer").unwrap();
    let a = reviewer.attrs.iter().find(|a| a.name == "assigned-to").unwrap();
    assert!(a.is_ref);
    assert_eq!(a.value.as_str().unwrap(), "u-1");
}

#[test]
fn resolve_id_finds_declared_element() {
    let doc = parse("[users [user #u-1 name=alice] [user #u-2 name=bob]]").unwrap();
    assert_eq!(
        doc.resolve_id("u-1").unwrap().attr("name").unwrap().as_str().unwrap(),
        "alice"
    );
    assert_eq!(
        doc.resolve_id("u-2").unwrap().attr("name").unwrap().as_str().unwrap(),
        "bob"
    );
    assert!(doc.resolve_id("u-3").is_none());
}

#[test]
fn elements_by_id_builds_full_map() {
    let doc = parse("[a #x v=1] [b #y v=2] [c #z v=3]").unwrap();
    let m = doc.elements_by_id();
    assert_eq!(m.len(), 3);
    assert_eq!(m["x"].name, "a");
    assert_eq!(m["y"].name, "b");
    assert_eq!(m["z"].name, "c");
}

#[test]
fn quoted_at_literal_is_not_a_reference() {
    let cx_in = "[item label='@literal']";
    let doc = parse(cx_in).unwrap();
    let label = root(&doc).attrs.iter().find(|a| a.name == "label").unwrap();
    assert!(!label.is_ref);
    assert_eq!(label.value.as_str().unwrap(), "@literal");
    assert_eq!(doc.to_cx(), cx_in);
}

#[test]
fn forward_reference_resolves() {
    let doc = parse("[users [reviewer assigned-to=@u-1] [user #u-1 name=alice]]").unwrap();
    let user = doc.resolve_id("u-1").unwrap();
    assert_eq!(user.attr("name").unwrap().as_str().unwrap(), "alice");
}

#[test]
fn nested_id_and_ref_round_trip() {
    let cx_in = "[doc\n  [users\n    [user #u-1 name=alice]\n  ]\n  [reviews\n    [review target=@u-1 score=5]\n  ]\n]";
    let doc = parse(cx_in).unwrap();
    assert!(doc.resolve_id("u-1").is_some());
    let review = doc.find_first("review").unwrap();
    let target = review.attrs.iter().find(|a| a.name == "target").unwrap();
    assert!(target.is_ref);
    assert_eq!(target.value.as_str().unwrap(), "u-1");
}

#[test]
fn body_ref_survives_ast_bin_round_trip() {
    // Phase 7.70: ast_bin v3 carries body_ref through the V↔binding
    // boundary. The field is populated post-parse from the v3 wire
    // bytes, not re-detected from text.
    let cx_in = "[doc [section #section-3 [para See [ref @section-3].]]]";
    let doc = parse(cx_in).unwrap();
    let section = doc.find_first("section").expect("section not found");
    let para = section.find_first("para").expect("para not found");
    let ref_node = para.items.iter().find_map(|n| match n {
        Node::Element(e) if e.name == "ref" => Some(e),
        _ => None,
    }).expect("ref node not found in para body");
    assert_eq!(ref_node.body_ref.as_deref(), Some("section-3"));
    assert!(ref_node.attrs.is_empty(), "ref node should have no attrs");
    assert!(ref_node.items.is_empty(), "ref node should have no items");
    let out = doc.to_cx();
    assert!(out.contains("[ref @section-3]"), "CX emit lost body_ref: {}", out);
}

#[test]
fn multiple_refs_to_same_id() {
    let doc = parse(
        "[users [user #u-1 name=alice] \
            [reviewer assigned-to=@u-1] \
            [approver checked-by=@u-1]]",
    )
    .unwrap();
    let mut count = 0;
    for el in doc.find_all("reviewer").into_iter().chain(doc.find_all("approver")) {
        for a in &el.attrs {
            if a.is_ref && a.value.as_str() == Some("u-1") {
                count += 1;
            }
        }
    }
    assert_eq!(count, 2);
}
