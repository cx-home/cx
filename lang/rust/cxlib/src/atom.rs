//! atom scalar kind for the Rust binding.
//!
//! Atom is a name-equality, type-strict scalar kind ("symbol" in other
//! ecosystems). Surface form `:NAME`. See
//! §D2 (type-strict
//! equality), §D5 (Layer-1 surface), §D7 (round-trip + hash domain),
//! §D8 (reserved-name closed list), §D10 (gate matrix).
//!
//! The Rust binding's atom layer maps the on-the-wire CX representation
//! (`Node::Scalar { data_type: "atom", value: Value::String(name) }`) to
//! a typed `Atom` newtype wrapper at the Layer-1 surface. The AST node
//! itself keeps `serde_json::Value` so existing accessors and the
//! ast_bin codec don't need a sum-type bump; the `is_atom` /
//! `atom_name` helpers project the `(data_type, value)` pair into a
//! type-strict view.
//!
//! Layer-1 surface (matches V's `atom(name)` / `is_atom(v)` /
//! `atom_name(v)` triple, adapted to Rust's snake_case convention per
//! `spec/bindings.md` and Rust idioms):
//!
//! ```ignore
//! use cxlib::Atom;
//! let a = Atom::new("ok")?;
//! assert_eq!(a.name(), "ok");
//! assert_eq!(a.to_string(), ":ok");      // canonical render (§D7)
//! assert!(a.as_node_pair().0 == "atom");
//! ```

use std::fmt;

use serde_json::Value;

// ── reserved-name list ────────────────────────────────────────

/// closed-list reservation. The three names that would
/// shadow scalar literals (`:true` / `:false` / `:null`) are rejected
/// at lex time in V (`vcx/code/parser.v` `parse_atom_literal`); the
/// Rust binding mirrors the rule at construction time.
const RESERVED_ATOM_NAMES: &[&str] = &["true", "false", "null"];

/// Identifier production from `spec/grammar.ebnf §3.4` — atoms accept
/// `[A-Za-z_][A-Za-z0-9_-]*`. Hand-rolled rather than depending on the
/// regex crate; the production is simple enough.
fn is_valid_atom_name(name: &str) -> bool {
    let mut chars = name.chars();
    let first = match chars.next() {
        Some(c) => c,
        None => return false,
    };
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    for c in chars {
        if !(c.is_ascii_alphanumeric() || c == '_' || c == '-') {
            return false;
        }
    }
    true
}

// ── Atom newtype ─────────────────────────────────────────────────────────────

/// Type-strict atom scalar value.
///
/// Equality is by `name` only, and an `Atom` compares unequal to any
/// plain `&str` / `String` with the same content — that's the
/// type-strict equality rule of §D2. The type is `Clone + PartialEq +
/// Eq + Hash` so it slots cleanly into Rust collections.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Atom {
    name: String,
}

impl Atom {
    /// Construct a typed atom, validating against 
    /// (identifier production) and §D8 (reserved-name list).
    ///
    /// Returns `Err` rather than panicking so callers can decide
    /// between fail-fast (`Atom::new(...).unwrap()`) and graceful
    /// degradation.
    pub fn new(name: impl Into<String>) -> Result<Self, String> {
        let name = name.into();
        if RESERVED_ATOM_NAMES.contains(&name.as_str()) {
            return Err(format!(
                "atom literal ':{}' is reserved; \
                 use bare '{}' for the bool/null scalar",
                name, name
            ));
        }
        if !is_valid_atom_name(&name) {
            return Err(format!(
                "atom name {:?} does not match identifier production \
                 [A-Za-z_][A-Za-z0-9_-]*",
                name
            ));
        }
        Ok(Atom { name })
    }

    /// Construct without validation. Use only when the name is already
    /// known to be well-formed (e.g., reconstructing from a verified
    /// `ast_bin` decode). The public-API `new` is the safe path.
    pub(crate) fn from_decoded(name: String) -> Self {
        Atom { name }
    }

    /// The atom's name (without the leading colon).
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Project to the `(data_type, value)` pair the AST uses on the wire.
    /// The wire form is `Scalar(data_type="atom",
    /// value=String(name))`. Useful when building `Node::Scalar`
    /// fragments by hand.
    pub fn as_node_pair(&self) -> (&'static str, Value) {
        ("atom", Value::String(self.name.clone()))
    }
}

impl fmt::Display for Atom {
    /// Canonical render — `:NAME`. No quoting, no
    /// bracketing, byte-identical to source text.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, ":{}", self.name)
    }
}

// ── Layer-1 free functions ───────────────────────────────────────────────────

/// Predicate over a `Node::Scalar`'s `(data_type, value)` pair —
/// returns `true` iff the pair represents an atom on the wire. Per
/// §D2 the predicate is type-strict; a `Value::String` with
/// `data_type=None` (i.e., a regular string) returns false, and a
/// well-tagged `data_type=Some("atom")` with a non-string `value`
/// (malformed payload) returns false too — both halves of the wire
/// shape must agree.
pub fn is_atom(data_type: Option<&str>, value: &Value) -> bool {
    data_type == Some("atom") && matches!(value, Value::String(_))
}

/// Accessor returning the atom name as a borrowed `&str`, or `None` if
/// the `(data_type, value)` pair is not an atom. Type-strict per §D2 —
/// no coercion from a same-named string.
pub fn atom_name<'a>(data_type: Option<&str>, value: &'a Value) -> Option<&'a str> {
    if data_type == Some("atom") {
        match value {
            Value::String(s) => Some(s.as_str()),
            _ => None,
        }
    } else {
        None
    }
}
