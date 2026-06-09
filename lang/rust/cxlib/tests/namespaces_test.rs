//! Namespace resolution tests for the Rust binding.
//!
//! Mirrors lang/python/test_namespaces.py.

use cxlib::ast::{
    parse, resolve_namespaces, Element, Node, XML_NAMESPACE_URI,
};

fn root(d: &cxlib::ast::Document) -> &Element {
    for n in &d.elements {
        if let Node::Element(e) = n {
            return e;
        }
    }
    panic!("no root element")
}

#[test]
fn default_namespace_inherits_to_descendants() {
    let doc = parse("[html xmlns=http://www.w3.org/1999/xhtml [body [p Hi]]]").unwrap();
    let html = root(&doc);
    assert_eq!(html.local_name(), "html");
    assert_eq!(html.namespace_uri(), Some("http://www.w3.org/1999/xhtml"));
    let body = html.get("body").expect("body");
    assert_eq!(body.namespace_uri(), Some("http://www.w3.org/1999/xhtml"));
}

#[test]
fn default_namespace_does_not_apply_to_attrs() {
    let doc = parse("[html xmlns=urn:x id=top body]").unwrap();
    let html = root(&doc);
    let id = html.attrs.iter().find(|a| a.name == "id").expect("id");
    assert_eq!(id.namespace_uri(), None);
    assert_eq!(id.local_name(), "id");
}

#[test]
fn prefixed_element_resolves() {
    let doc = parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]").unwrap();
    let title = root(&doc).get("dc:title").expect("dc:title");
    assert_eq!(title.local_name(), "title");
    assert_eq!(title.namespace_uri(), Some("http://purl.org/dc/elements/1.1/"));
}

#[test]
fn prefixed_attribute_resolves() {
    let doc = parse(
        "[doc xmlns:xl=http://www.w3.org/1999/xlink [link xl:href=https://example.com Click]]"
    ).unwrap();
    let link = root(&doc).get("link").expect("link");
    let href = link.attrs.iter().find(|a| a.name == "xl:href").expect("xl:href");
    assert_eq!(href.local_name(), "href");
    assert_eq!(href.namespace_uri(), Some("http://www.w3.org/1999/xlink"));
}

#[test]
fn reserved_xml_prefix_resolves_without_declaration() {
    let doc = parse("[doc xml:base=https://example.com content]").unwrap();
    let base = root(&doc).attrs.iter().find(|a| a.name == "xml:base").expect("xml:base");
    assert_eq!(base.namespace_uri(), Some(XML_NAMESPACE_URI));
}

#[test]
fn reserved_cx_prefix_rejected_when_authored() {
    // The `cx:` prefix is reserved for the serializer's canonical image and
    // may not be authored in source (E210). Parsing must reject it.
    assert!(parse("[doc [cx:meta key=value]]").is_err());
}

#[test]
fn undeclared_prefix_passes_through_unbound() {
    let doc = parse("[doc [foo:bar baz]]").unwrap();
    let bar = root(&doc).get("foo:bar").expect("foo:bar");
    assert_eq!(bar.local_name(), "bar");
    assert_eq!(bar.namespace_uri(), None);
}

#[test]
fn redeclaration_in_subtree_overrides_default() {
    let doc = parse(
        "[html xmlns=http://www.w3.org/1999/xhtml\n  [body\n    [svg xmlns=http://www.w3.org/2000/svg\n      [circle r=10]\n    ]\n  ]\n]"
    ).unwrap();
    let html = root(&doc);
    let body = html.get("body").unwrap();
    let svg = body.get("svg").unwrap();
    let circle = svg.get("circle").unwrap();
    assert_eq!(html.namespace_uri(), Some("http://www.w3.org/1999/xhtml"));
    assert_eq!(body.namespace_uri(), Some("http://www.w3.org/1999/xhtml"));
    assert_eq!(svg.namespace_uri(), Some("http://www.w3.org/2000/svg"));
    assert_eq!(circle.namespace_uri(), Some("http://www.w3.org/2000/svg"));
}

#[test]
fn xmlns_undeclaration_with_empty_uri() {
    let doc = parse("[outer xmlns=urn:x [inner xmlns='' [child x=1]]]").unwrap();
    let outer = root(&doc);
    let inner = outer.get("inner").unwrap();
    let child = inner.get("child").unwrap();
    assert_eq!(outer.namespace_uri(), Some("urn:x"));
    assert_eq!(inner.namespace_uri(), None);
    assert_eq!(child.namespace_uri(), None);
}

#[test]
fn resolve_namespaces_is_idempotent() {
    let mut doc = parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ [dc:title Hi]]").unwrap();
    let first = root(&doc).get("dc:title").unwrap().namespace_uri().map(|s| s.to_string());
    resolve_namespaces(&mut doc);
    resolve_namespaces(&mut doc);
    let second = root(&doc).get("dc:title").unwrap().namespace_uri().map(|s| s.to_string());
    assert_eq!(first, second);
    assert_eq!(first.as_deref(), Some("http://purl.org/dc/elements/1.1/"));
}

#[test]
fn xmlns_declaration_attrs_have_no_resolved_uri() {
    let doc = parse("[doc xmlns:dc=http://purl.org/dc/elements/1.1/ body]").unwrap();
    let decl = root(&doc).attrs.iter().find(|a| a.name == "xmlns:dc").expect("xmlns:dc");
    assert_eq!(decl.namespace_uri(), None);
    assert_eq!(decl.local_name(), "dc");
}
