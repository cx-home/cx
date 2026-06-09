//! v0.8.0 Layer-2 Rust idioms — opt-in sugar over the Layer-1 surface.
//!
//! Per [`spec/bindings.md` §3.3](../../../spec/bindings.md) the Layer-2
//! surface for Rust is `Iterator<Item = Node>` combinators that
//! desugar to Layer-1 `select_all` / `find_all` calls. Importing from
//! `cxlib::idioms` is OPTIONAL — Layer-1 lives at `cxlib::code::Doc`
//! and is the byte-identical cross-binding contract.
//!
//! # Examples
//!
//! ```ignore
//! use cxlib::idioms::DocExt;
//! use cxlib::code::Doc;
//!
//! let doc = Doc::from_str("[doc [user [name Alice]] [user [name Bob]]]")?;
//!
//! // Iterator combinator — desugars to Layer-1 `select_all`.
//! let names: Vec<_> = doc.select_iter("//user/name")?
//!     .filter_map(|n| match n.body() {
//!         serde_json::Value::String(s) => Some(s),
//!         _ => None,
//!     })
//!     .collect();
//! // ≡ doc.select_all("//user/name")?.into_iter()...
//!
//! // find_iter is the name-only variant — no CXPath parse.
//! let users: Vec<_> = doc.find_iter("user").collect();
//! // ≡ doc.find_all("user").into_iter()...
//! ```
//!
//! # Desugaring
//!
//! Per `spec/bindings.md §3.3`, every Layer-2 expression has a
//! documented Layer-1 equivalent:
//!
//! | Layer 2                              | Layer 1                       |
//! |--------------------------------------|--------------------------------|
//! | `doc.select_iter("//x")?`            | `doc.select_all("//x")?.into_iter()` |
//! | `doc.find_iter("user")`              | `doc.find_all("user").into_iter()`  |
//! | `doc.eval("[?...]")?`                | `Doc::eval` (Layer-1)              |
//! | `doc.diagram()?`                     | `Doc::diagram` (Layer-1)           |
//! | `doc.tree()?`                        | `Doc::tree` (Layer-1)              |
//!
//! `explain()` returns the desugaring string for any Layer-2
//! operation; used by fixtures and LSP hovers.

use crate::code::{Doc, Node};

/// Extension trait that adds iterator-combinator sugar to `Doc`. Bring
/// this trait into scope (`use cxlib::idioms::DocExt;`) to enable
/// `select_iter` / `find_iter` on any `Doc`.
pub trait DocExt {
    /// CXPath selection as an `Iterator<Item = Node>`. Desugars to
    /// `self.select_all(cxpath)?.into_iter()`.
    fn select_iter(&self, cxpath: &str) -> Result<std::vec::IntoIter<Node>, String>;

    /// Name-only selection as an `Iterator<Item = Node>`. Desugars to
    /// `self.find_all(name).into_iter()`.
    fn find_iter(&self, name: &str) -> std::vec::IntoIter<Node>;

    /// Mermaid diagram builder API — drop-in for `Doc::diagram()`
    /// with explicit format selection. Currently only `"mermaid"`
    /// is supported; other formats route through
    /// the CLI tier.
    fn diagram_with(&self, format: &str) -> Result<String, String>;
}

impl DocExt for Doc {
    fn select_iter(&self, cxpath: &str) -> Result<std::vec::IntoIter<Node>, String> {
        Ok(self.select_all(cxpath)?.into_iter())
    }

    fn find_iter(&self, name: &str) -> std::vec::IntoIter<Node> {
        self.find_all(name).into_iter()
    }

    fn diagram_with(&self, format: &str) -> Result<String, String> {
        // Layer-1 Doc::diagram is hard-coded to "mermaid"; route
        // through the free function cx_code_diagram for explicit
        // format pass-through (so Layer-2 callers can request future
        // SVG/PNG once those tiers land).
        crate::cx_code_diagram(
            std::str::from_utf8(self.source_bytes())
                .map_err(|e| format!("DocExt::diagram_with: source not valid UTF-8: {}", e))?,
            format,
        )
    }
}

/// Return the Layer-1 desugaring for a Layer-2 operation. Mirrors the
/// `cxlib.idioms.explain(...)` helper in the Python binding. Used by
/// fixtures and LSP hovers; not a runtime requirement.
///
/// ```ignore
/// use cxlib::idioms::explain;
/// assert_eq!(
///     explain("select_iter", "//user"),
///     r#"doc.select_all("//user")?.into_iter()"#
/// );
/// ```
pub fn explain(op: &str, arg: &str) -> String {
    match op {
        "select_iter"  => format!(r#"doc.select_all({:?})?.into_iter()"#, arg),
        "find_iter"    => format!(r#"doc.find_all({:?}).into_iter()"#, arg),
        "diagram_with" => format!(r#"cxlib::cx_code_diagram(doc.source_bytes(), {:?})"#, arg),
        _ => format!("explain: unknown Layer-2 op {:?}", op),
    }
}
