//! Tree-mutation helpers used by `Document::transform` / `transform_all`.
//!
//! The CXPath parser, lexer, predicate types, and evaluator that lived
//! here were deleted in Phase 4 (CB-5): expression evaluation now runs
//! in libcx via `cx_select_all_paths`, and bindings navigate the
//! returned structural paths against their in-memory tree. What
//! remains here is host-language tree manipulation — not duplication.

use crate::ast::{Document, Element, Node};

/// Return a copy of `e` with independent attrs/items vectors so a
/// caller's `f` cannot mutate the source.
pub fn elem_detached(e: &Element) -> Element {
    Element {
        name: e.name.clone(),
        anchor: e.anchor.clone(),
        merge: e.merge.clone(),
        data_type: e.data_type.clone(),
        attrs: e.attrs.clone(),
        items: e.items.clone(),
        local: e.local.clone(),
        ns_uri: e.ns_uri.clone(),
        id: e.id.clone(),
        body_ref: e.body_ref.clone(),
    }
}

/// Functional replace of `d.elements[idx]`.
pub fn doc_replace_at(d: &Document, idx: usize, el: Element) -> Document {
    let mut new_elements = d.elements.clone();
    if idx < new_elements.len() {
        new_elements[idx] = Node::Element(el);
    }
    Document {
        elements: new_elements,
        prolog: d.prolog.clone(),
    }
}

/// Functional replace of `e.items[idx]`.
pub fn elem_replace_item_at(e: &Element, idx: usize, child: Node) -> Element {
    let mut new_items = e.items.clone();
    if idx < new_items.len() {
        new_items[idx] = child;
    }
    Element {
        name: e.name.clone(),
        anchor: e.anchor.clone(),
        merge: e.merge.clone(),
        data_type: e.data_type.clone(),
        attrs: e.attrs.clone(),
        items: new_items,
        local: e.local.clone(),
        ns_uri: e.ns_uri.clone(),
        id: e.id.clone(),
        body_ref: e.body_ref.clone(),
    }
}

/// Slash-path-style descent for `Document::transform`. Returns a new
/// `Element` with `f` applied at the path given by `parts`, or `None`
/// if the path doesn't resolve.
pub fn path_copy_element(
    e: &Element,
    parts: &[&str],
    f: &dyn Fn(Element) -> Element,
) -> Option<Element> {
    for (i, item) in e.items.iter().enumerate() {
        if let Node::Element(child) = item {
            if child.name == parts[0] {
                if parts.len() == 1 {
                    let updated = f(elem_detached(child));
                    return Some(elem_replace_item_at(e, i, Node::Element(updated)));
                }
                if let Some(new_child) = path_copy_element(child, &parts[1..], f) {
                    return Some(elem_replace_item_at(e, i, Node::Element(new_child)));
                }
                return None;
            }
        }
    }
    None
}

// ── Path-based navigation (CB-5 / Phase 4) ──────────────────────────────────

/// Walk `path` (indices into `Document.elements` then `Element.items`)
/// and return a *cloned* element at that position. Returns `None` if
/// any step is out-of-bounds or hits a non-Element item.
pub fn navigate_doc_path(d: &Document, path: &[usize]) -> Option<Element> {
    if path.is_empty() || path[0] >= d.elements.len() {
        return None;
    }
    let mut node: &Node = &d.elements[path[0]];
    for &k in &path[1..] {
        match node {
            Node::Element(e) if k < e.items.len() => {
                node = &e.items[k];
            }
            _ => return None,
        }
    }
    if let Node::Element(e) = node {
        Some(e.clone())
    } else {
        None
    }
}

/// Return a new `Document` with the element at `path` replaced by
/// `new_elem`. Only the spine along `path` is rebuilt; the original
/// `Document` is unchanged.
pub fn replace_at_doc_path(d: &Document, path: &[usize], new_elem: Element) -> Document {
    if path.is_empty() {
        return d.clone();
    }
    let mut new_elements = d.elements.clone();
    if path.len() == 1 {
        if path[0] < new_elements.len() {
            new_elements[path[0]] = Node::Element(new_elem);
        }
    } else if let Node::Element(top) = &new_elements[path[0]].clone() {
        let new_top = replace_in_element(top, &path[1..], new_elem);
        new_elements[path[0]] = Node::Element(new_top);
    }
    Document {
        elements: new_elements,
        prolog: d.prolog.clone(),
    }
}

fn replace_in_element(el: &Element, path: &[usize], new_elem: Element) -> Element {
    if path.is_empty() {
        return new_elem;
    }
    let mut new_items = el.items.clone();
    if path.len() == 1 {
        if path[0] < new_items.len() {
            new_items[path[0]] = Node::Element(new_elem);
        }
    } else if let Node::Element(child) = &new_items[path[0]].clone() {
        let new_child = replace_in_element(child, &path[1..], new_elem);
        new_items[path[0]] = Node::Element(new_child);
    }
    Element {
        name: el.name.clone(),
        anchor: el.anchor.clone(),
        merge: el.merge.clone(),
        data_type: el.data_type.clone(),
        attrs: el.attrs.clone(),
        items: new_items,
        local: el.local.clone(),
        ns_uri: el.ns_uri.clone(),
        id: el.id.clone(),
        body_ref: el.body_ref.clone(),
    }
}
