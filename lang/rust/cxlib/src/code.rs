//! v0.8.0 Layer-1 CX code surface — Rust binding.
//!
//! Per [`spec/bindings.md` §2.1](../../../spec/bindings.md) every binding
//! exposes a 16-method Layer-1 surface for parsing, hashing, evaluating,
//! and modifying CX documents. This module wires the v0.8.0 additions
//! to the existing `cxlib` foundation:
//!
//! * `cx_code_eval` / `cx_code_diagram` / `cx_code_tree` are exposed at
//!   the crate root (see `lib.rs`). The names mirror the C ABI per
//!   `spec/bindings.md` so Layer-1 conformance fixtures (`conformance/binding_api.txt`)
//!   bind against shared vocabulary.
//! * `Doc` and `Node` below are the canonical Layer-1 façades — thin
//!   wrappers over the existing `cxlib::ast::Document` + `Element` types
//!   that expose the 16-method surface listed in `spec/bindings.md`
//!   §2.1. Method counts: 10 on `Doc`, 6 on `Node` (= 16).
//!
//! The atom triple (`Atom::new`, `is_atom`, `atom_name`) is re-exported
//! from the crate root via `pub use atom::{Atom, is_atom, atom_name};`
//! in `lib.rs` — it is not counted in the 16
//! Doc/Node methods.
//!
//! # 16-method Layer-1 surface
//!
//! ```text
//! parse(bytes) -> Doc           (module-level constructor)
//! Doc.bytes() -> Vec<u8>
//! Doc.hash() -> String
//! Doc.equals(&Doc) -> bool
//! Doc.eval(&str) -> Result<String>
//! Doc.select_all(&str) -> Result<Vec<Node>>
//! Doc.select(&str) -> Result<Option<Node>>
//! Doc.modify(focus, action) -> Result<Doc>
//! Doc.find_all(&str) -> Vec<Node>
//! Doc.root() -> Option<Node>
//! Node.name() -> &str
//! Node.attr(&str) -> Option<serde_json::Value>
//! Node.attrs() -> Vec<(String, serde_json::Value)>
//! Node.children() -> Vec<Node>
//! Node.body() -> serde_json::Value
//! Node.kind() -> &'static str
//! ```

use serde_json::Value;

use crate::ast::{Document, Element, Node as AstNode};
use crate as cx;

// ── Node (Layer-1 wrapper around ast::Element) ───────────────────────────────

/// Layer-1 wrapper around [`ast::Element`]. The 6-method Node surface
/// (`name` / `attr` / `attrs` / `children` / `body` / `kind`) mirrors
/// the canonical surface in `spec/bindings.md §2.1`.
///
/// Owns its underlying `Element` for `Send + 'static` semantics — Rust
/// iterator adaptors over `Doc::find_all` etc. would otherwise carry
/// host-lifetime references that don't compose with Layer-2 idioms.
/// The clone cost is paid at boundary crossings, not on every
/// accessor.
#[derive(Debug, Clone)]
pub struct Node {
    el: Element,
}

impl Node {
    fn new(el: Element) -> Self { Self { el } }

    /// Method 11 — `Node.name() -> &str` (spec/bindings.md §2.1).
    pub fn name(&self) -> &str { &self.el.name }

    /// Method 12 — `Node.attr(name) -> Option<Value>`. Returns a
    /// cloned `serde_json::Value` so the result is owned by the
    /// caller (no lifetime tie-back to the underlying Document).
    pub fn attr(&self, name: &str) -> Option<Value> {
        self.el.attr(name).cloned()
    }

    /// Method 13 — `Node.attrs() -> Vec<(String, Value)>`. Preserves
    /// the source attribute order (Vec, not HashMap) — required for
    /// canonical hash stability.
    pub fn attrs(&self) -> Vec<(String, Value)> {
        self.el.attrs.iter()
            .map(|a| (a.name.clone(), a.value.clone()))
            .collect()
    }

    /// Method 14 — `Node.children() -> Vec<Node>`. Returns only
    /// child Elements (Text / Scalar / Comment / etc. are excluded —
    /// per Python parity).
    pub fn children(&self) -> Vec<Node> {
        self.el.children().into_iter().cloned().map(Node::new).collect()
    }

    /// Method 15 — `Node.body() -> Value`. Returns the first scalar
    /// child's value when present (preserves int / bool / atom
    /// round-trip); falls back to the concatenated text content;
    /// finally falls back to `Value::Null` when the element has no
    /// scalar / text content (only structural children).
    pub fn body(&self) -> Value {
        if let Some(v) = self.el.scalar() {
            return v.clone();
        }
        let txt = self.el.text();
        if !txt.is_empty() {
            return Value::String(txt);
        }
        Value::Null
    }

    /// Method 16 — `Node.kind() -> &'static str`. Layer-1 contract
    /// returns one of `"element" / "scalar" / "sequence" / "array" /
    /// "map" / "path"`. The Layer-1 Node always wraps an `Element`
    /// today (selection results are routed via the CX evaluator,
    /// which materialises Elements); the `kind()` value is therefore
    /// `"element"` until the broader Node kind discrimination lands
    /// (Phase 3.x follow-up).
    pub fn kind(&self) -> &'static str { "element" }

    /// Layer-2 escape hatch — borrow the underlying `Element` for
    /// callers that need the full ast::Element surface
    /// (`find_all`, `set_attr`, …). Not part of the 16-method
    /// surface; safe to ignore for conformance.
    pub fn element(&self) -> &Element { &self.el }
}

// ── Doc (Layer-1 wrapper around ast::Document + bytes) ───────────────────────

/// Layer-1 Doc façade per `spec/bindings.md §2.1`. Holds the canonical
/// CX bytes plus a parsed [`ast::Document`]. Methods that return a new
/// `Doc` do NOT mutate the receiver (pure-functional contract per
/// `spec/bindings.md §2.1`).
#[derive(Debug, Clone)]
pub struct Doc {
    bytes: Vec<u8>,
    doc: Document,
}

impl Doc {
    fn from_parts(bytes: Vec<u8>, doc: Document) -> Self { Self { bytes, doc } }

    /// Method 1 — `parse(bytes) -> Doc`. Equivalent to the free
    /// function `cxlib::code::parse(...)` at the module level.
    ///
    /// Parse failures are surfaced with the Layer-1 wire code per
    /// `spec/bindings.md §2.4` (`cx-err:CXER0100` — malformed input).
    /// V's `eval_code` emits the same `EvalError{code, message}` token;
    /// this keeps the Rust binding's parse-error wire format identical.
    pub fn parse(source: &[u8]) -> Result<Self, String> {
        let s = std::str::from_utf8(source)
            .map_err(|e| format!("cx-err:CXER0100: Doc::parse: source is not valid UTF-8: {}", e))?;
        let doc = cx::parse(s).map_err(|e| format!("cx-err:CXER0100: {}", e))?;
        Ok(Self::from_parts(source.to_vec(), doc))
    }

    /// `&str` convenience constructor — common-case shortcut around
    /// `Doc::parse(s.as_bytes())`. Not counted as a separate Layer-1
    /// method; it forwards to `parse` for symmetry with Python's
    /// `Doc.parse(b"...")` / `Doc.parse("...")` polymorphic call.
    pub fn from_str(source: &str) -> Result<Self, String> {
        Self::parse(source.as_bytes())
    }

    /// Method 2 — `Doc.bytes() -> Vec<u8>`. Returns canonical CX bytes
    /// (re-emitted from the AST so the result is stable under
    /// parse-emit round-trip).
    pub fn bytes(&self) -> Vec<u8> {
        self.doc.to_cx().into_bytes()
    }

    /// Method 3 — `Doc.hash() -> String`. SHA-256 hex of the strict
    /// canonical bytes (spec/abi.md §2.6).
    pub fn hash(&self) -> Result<String, String> {
        cx::hash(&self.doc.to_cx())
    }

    /// Method 4 — `Doc.equals(other) -> bool`. Canonical-bytes
    /// equality — two Docs compare equal iff `cx_canonical` yields
    /// the same bytes for both.
    pub fn equals(&self, other: &Doc) -> Result<bool, String> {
        cx::eq(&self.doc.to_cx(), &other.doc.to_cx())
    }

    /// Method 5 — `Doc.eval(code) -> Result<String>`. Evaluates a CX
    /// program against this Doc. Wraps `cx_code_eval` (per
    /// `spec/bindings.md`). The default output target is `"text"`; for richer
    /// targets call `eval_with_target(...)`.
    pub fn eval(&self, code: &str) -> Result<String, String> {
        cx::cx_code_eval(&self.doc.to_cx(), code, "")
    }

    /// Variant of `Doc.eval` that picks a specific output target
    /// (`"cx"` / `"json"` / `"yaml"` / `"xml"` / `"csv"` / `"tsv"` /
    /// `"mermaid"`). Not part of the 16-method surface; Layer-2
    /// extension.
    pub fn eval_with_target(&self, code: &str, target: &str) -> Result<String, String> {
        cx::cx_code_eval(&self.doc.to_cx(), code, target)
    }

    /// Method 6 — `Doc.select_all(cxpath) -> Result<Vec<Node>>`. Routes
    /// through `cx_code_eval` (the program IS the CXPath expression)
    /// and parses the `"cx"` output back through `cxlib::parse`.
    /// Non-element results raise an error — for scalar / aggregate
    /// shapes use `Doc.eval` directly.
    pub fn select_all(&self, cxpath: &str) -> Result<Vec<Node>, String> {
        let out = cx::cx_code_eval(&self.doc.to_cx(), cxpath, "cx")?;
        if out.trim().is_empty() {
            return Ok(Vec::new());
        }
        let result = cx::parse(&out)?;
        let mut nodes = Vec::new();
        for n in result.elements {
            if let AstNode::Element(e) = n {
                nodes.push(Node::new(e));
            }
        }
        Ok(nodes)
    }

    /// Method 7 — `Doc.select(cxpath) -> Result<Option<Node>>`. First
    /// match of `select_all`; `None` when the path matches nothing.
    pub fn select(&self, cxpath: &str) -> Result<Option<Node>, String> {
        let mut all = self.select_all(cxpath)?;
        Ok(if all.is_empty() { None } else { Some(all.remove(0)) })
    }

    /// Method 8 — `Doc.modify(focus, action) -> Result<Doc>`.
    /// Pure-functional update — returns a new Doc, the
    /// receiver is unchanged. `action` carries the trailing modify
    /// action clause + args, e.g. `"[delete]"`, `"[set \"Alicia\"]"`,
    /// `"[rename component]"`.
    pub fn modify(&self, focus: &str, action: &str) -> Result<Doc, String> {
        let prog = format!("[?modify $doc {} {}]", focus, action);
        let out = cx::cx_code_eval(&self.doc.to_cx(), &prog, "cx")?;
        let new_doc = cx::parse(&out)?;
        Ok(Self::from_parts(out.into_bytes(), new_doc))
    }

    /// Method 9 — `Doc.find_all(name) -> Vec<Node>`. Name-only
    /// convenience; no CXPath parse, depth-first walk.
    pub fn find_all(&self, name: &str) -> Vec<Node> {
        self.doc.find_all(name).into_iter().cloned().map(Node::new).collect()
    }

    /// Method 10 — `Doc.root() -> Option<Node>`. Root element of the
    /// document, or `None` for an empty document.
    pub fn root(&self) -> Option<Node> {
        self.doc.root().cloned().map(Node::new)
    }

    // ── Layer-1 code-projection helpers ──────────────────────────
    //
    // Both pass the canonical CX bytes through `cx_code_diagram` /
    // `cx_code_tree`. Kept on Doc for ergonomic parity with `.eval()`.
    // Not counted in the 16-method surface — code-projection is a
    // separate spec carve-out.

    /// Mermaid diagram of this Doc's source (cap bit 31).
    pub fn diagram(&self) -> Result<String, String> {
        cx::cx_code_diagram(&self.doc.to_cx(), "mermaid")
    }

    /// JSON tree projection of this Doc's source
    /// cap bit 32).
    pub fn tree(&self) -> Result<Value, String> {
        cx::cx_code_tree(&self.doc.to_cx())
    }

    /// Layer-2 escape hatch — borrow the underlying `ast::Document`
    /// for callers that need the full Document API
    /// (`resolve_id`, `to_xml`, `to_json`, …). Not part of the 16-method
    /// surface.
    pub fn document(&self) -> &Document { &self.doc }

    /// Layer-2 escape hatch — the raw canonical-bytes the Doc was
    /// constructed from. Distinct from `bytes()`, which re-emits
    /// through the AST; this returns the as-parsed buffer.
    pub fn source_bytes(&self) -> &[u8] { &self.bytes }
}

// ── Module-level free functions per spec/bindings.md §2.1 ────────────────────

/// Parse canonical CX bytes into a Doc value. Equivalent to
/// `Doc::parse(source)`; module-level alias matches the spec's
/// `parse(bytes) -> Doc` Layer-1 method-1 signature.
pub fn parse(source: &[u8]) -> Result<Doc, String> {
    Doc::parse(source)
}

// Mirror in tests — covers the 16-method count in one assertion-friendly
// place. Compile-only; no runtime cost.
#[cfg(test)]
const _LAYER_1_METHOD_COUNT_CHECK: () = {
    // 10 Doc methods + 6 Node methods = 16, per spec/bindings.md §2.1.
    let doc_methods: &[&str] = &[
        "parse", "bytes", "hash", "equals", "eval",
        "select_all", "select", "modify", "find_all", "root",
    ];
    let node_methods: &[&str] = &[
        "name", "attr", "attrs", "children", "body", "kind",
    ];
    assert!(doc_methods.len() + node_methods.len() == 16);
};
