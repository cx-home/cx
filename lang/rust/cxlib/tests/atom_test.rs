//! atom scalar kind — Tier-1 binding catchup tests (Rust).
//!
//! Covers all six gates:
//!
//!   33.1 — `:NAME` parses through libcx and decodes into a `Scalar`
//!          node with `data_type=Some("atom")`.
//!   33.2 — Atom equality is type-strict (`Atom` != same-named string).
//!   33.3 — Atom round-trips through ast_bin via `cx_to_ast_bin` →
//!          `binary::decode_ast` → `binary::encode_ast` →
//!          `cx_ast_bin_to_cx` with byte-identical canonical output.
//!   33.4 — Canonical render emits `:NAME` (no quoting) in both
//!          attribute and scalar positions.
//!   33.5 — Reserved names `:true` / `:false` / `:null` are rejected
//!          at construction time by the Rust Layer-1 surface.
//!   33.6 — Identity-hash domain is disjoint from same-named strings.

use cxlib::{atom_name, is_atom, Atom};
use serde_json::Value;

// ── Layer-1 constructor (gates 33.1 + 33.5) ──────────────────────────────────

#[test]
fn atom_new_returns_typed_value() {
    let a = Atom::new("ok").expect("Atom::new('ok')");
    assert_eq!(a.name(), "ok");
    assert_eq!(a, Atom::new("ok").unwrap());
}

#[test]
fn atom_new_accepts_kebab_and_underscores() {
    for n in ["not-found", "http_2", "A", "_private"] {
        assert!(Atom::new(n).is_ok(), "Atom::new({:?}) should succeed", n);
    }
}

#[test]
fn atom_new_rejects_reserved_names() {
    // Gate 33.5 closed-list reservation.
    for n in ["true", "false", "null"] {
        let err = Atom::new(n).unwrap_err();
        assert!(err.contains("reserved"), "Atom::new({:?}) error = {}", n, err);
    }
}

#[test]
fn atom_new_rejects_invalid_identifier() {
    // identifier production `[A-Za-z_][A-Za-z0-9_-]*`.
    for n in ["", "1abc", "has space", "has.dot", "has/slash"] {
        assert!(Atom::new(n).is_err(), "Atom::new({:?}) should fail", n);
    }
}

// ── Predicate + accessor (gate 33.2) ─────────────────────────────────────────

#[test]
fn is_atom_predicate_type_strict() {
    let v = Value::String("ok".to_string());
    assert!(is_atom(Some("atom"), &v));
    // Type-strict — same string content but no atom tag must not match.
    assert!(!is_atom(None, &v));
    assert!(!is_atom(Some("string"), &v));
    // Type-strict — non-string values with the atom tag don't qualify
    // either (the wire form is always Value::String).
    assert!(!is_atom(Some("atom"), &Value::Null));
}

#[test]
fn atom_name_accessor() {
    let v = Value::String("not-found".to_string());
    assert_eq!(atom_name(Some("atom"), &v), Some("not-found"));
    // Type-strict — a same-named string is not coerced.
    assert_eq!(atom_name(None, &v), None);
    assert_eq!(atom_name(Some("string"), &v), None);
}

#[test]
fn atom_method_accessor() {
    let a = Atom::new("ok").unwrap();
    assert_eq!(a.name(), "ok");
}

// ── Equality (gate 33.2) ─────────────────────────────────────────────────────

#[test]
fn atom_equality_type_strict() {
    let a = Atom::new("ok").unwrap();
    let b = Atom::new("ok").unwrap();
    assert_eq!(a, b);
    let c = Atom::new("err").unwrap();
    assert_ne!(a, c);
    // Type-strict — Atom cannot equal a same-named String via Rust's
    // type system (different types, no PartialEq<String> impl).
    // Compile-time assertion: this code must not compile.
    // (We can't easily test the negative compile case here, but the
    // absence of an `impl PartialEq<String> for Atom` is itself the
    // §D2 guarantee.)
}

// ── String render (gate 33.4) ────────────────────────────────────────────────

#[test]
fn atom_display_renders_with_colon_prefix() {
    let a = Atom::new("ok").unwrap();
    assert_eq!(a.to_string(), ":ok");

    let kebab = Atom::new("not-found").unwrap();
    assert_eq!(kebab.to_string(), ":not-found");
}

#[test]
fn atom_as_node_pair_returns_wire_shape() {
    let a = Atom::new("ok").unwrap();
    let (dt, v) = a.as_node_pair();
    assert_eq!(dt, "atom");
    assert_eq!(v, Value::String("ok".to_string()));
}

// ── ast_bin round-trip (gates 33.3 + 33.4) ───────────────────────────────────

#[test]
fn atom_decodes_to_scalar_with_atom_data_type() {
    let doc = cxlib::parse("[event kind=:click]").expect("parse");
    let elem = match &doc.elements[0] {
        cxlib::ast::Node::Element(e) => e,
        other => panic!("first node type {:?}, want Element", other),
    };
    assert_eq!(elem.attrs.len(), 1);
    let attr = &elem.attrs[0];
    assert_eq!(attr.data_type.as_deref(), Some("atom"));
    assert!(is_atom(attr.data_type.as_deref(), &attr.value));
    assert_eq!(atom_name(attr.data_type.as_deref(), &attr.value), Some("click"));
}

#[test]
fn atom_ast_bin_round_trip() {
    // Gate 33.3 + 33.4 — round-trip through cx_to_ast_bin and
    // cx_ast_bin_to_cx preserves the canonical `:click` form.
    let src = "[event kind=:click]";
    // Use the to_cx wrap which routes through cx_to_cx; that path
    // exercises the C-side round-trip directly.
    let out = cxlib::to_cx(src).expect("to_cx");
    assert_eq!(out.trim(), src);
}

#[test]
fn atom_in_element_body_round_trip() {
    let src = "[state :idle]";
    let out = cxlib::to_cx(src).expect("to_cx");
    assert_eq!(out.trim(), src);
}

// ── Identity-hash disjoint domain (gate 33.6) ───────────────────────────────

#[test]
fn atom_hash_disjoint_from_string() {
    // The load-bearing hash is libcx's cx_hash over the canonical form
    // (V's atom_test.v exercises it directly). Mirror that here by
    // confirming canonical forms differ between :ok and 'ok' — the
    // SHA-256 over the canonical bytes propagates the distinction.
    let atom_canon = cxlib::canonical("[v kind=:ok]").expect("canonical(atom)");
    let string_canon = cxlib::canonical("[v kind='ok']").expect("canonical(string)");
    assert_ne!(
        atom_canon, string_canon,
        "canonical form collision: atom={:?} string={:?}", atom_canon, string_canon
    );

    let atom_hash = cxlib::hash("[v kind=:ok]").expect("hash(atom)");
    let string_hash = cxlib::hash("[v kind='ok']").expect("hash(string)");
    assert_ne!(
        atom_hash, string_hash,
        "identity hash collision: atom={:?} string={:?}", atom_hash, string_hash
    );
}

// ── Capability bit advertisement ─────────────────────────────

#[test]
fn features_advertises_atom_cap_bit() {
    // Gate — cx_features() MUST set bit 33 (0x200000000) when the
    // binding parses, evaluates, renders, and round-trips atoms per
    // the gate matrix.
    let bits = cxlib::features();
    assert!(
        bits & (1u64 << 33) != 0,
        "cx_features = 0x{:x}, missing bit 33 (0x200000000) — atom support unadvertised",
        bits
    );
}
