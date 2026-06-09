package cxlib

import (
	"strings"
	"testing"
)

// atom_test.go Tier-1 binding catchup for Go.
//
// Covers all six atom-scalar-kind gates:
//
//   33.1 — `:NAME` parses through libcx and decodes into the typed
//          AtomValue wrapper at the Go binding layer.
//   33.2 — Atom equality is type-strict (AtomValue != string with the
//          same content).
//   33.3 — Atom round-trips through ast_bin via cx_to_ast_bin →
//          decodeAST → encodeAST → cx_ast_bin_to_cx with byte-identical
//          canonical output.
//   33.4 — Canonical render emits `:NAME` (no quoting) in both attribute
//          and scalar positions.
//   33.5 — Reserved names `:true` / `:false` / `:null` are rejected at
//          construction time by the Go Layer-1 surface.
//   33.6 — Identity-hash domain is disjoint from same-named strings.
//
// These exercise the Go-side surface only; deeper semantic coverage
// (parser disambiguation, evaluator dispatch) lives in V's
// `vcx/cx/atom_test.v` and the cross-binding `conformance_code.go` runner.

// ── Layer-1 surface (gate 33.5) ──────────────────────────────────────────────

func TestAtomConstructorReturnsTypedValue(t *testing.T) {
	a, err := Atom("ok")
	if err != nil {
		t.Fatalf("Atom: %v", err)
	}
	if a.Name != "ok" {
		t.Errorf("Atom.Name = %q, want %q", a.Name, "ok")
	}
}

func TestAtomConstructorAcceptsKebabAndUnderscores(t *testing.T) {
	for _, n := range []string{"not-found", "http_2", "A", "_private"} {
		if _, err := Atom(n); err != nil {
			t.Errorf("Atom(%q) unexpected error: %v", n, err)
		}
	}
}

func TestAtomConstructorRejectsReservedNames(t *testing.T) {
	for _, n := range []string{"true", "false", "null"} {
		_, err := Atom(n)
		if err == nil {
			t.Errorf("Atom(%q) should fail (reserved name)", n)
			continue
		}
		if !strings.Contains(err.Error(), "reserved") {
			t.Errorf("Atom(%q) error = %v, want substring 'reserved'", n, err)
		}
	}
}

func TestAtomConstructorRejectsInvalidIdentifier(t *testing.T) {
	for _, n := range []string{"", "1abc", "has space", "has.dot", "has/slash"} {
		if _, err := Atom(n); err == nil {
			t.Errorf("Atom(%q) should fail (invalid identifier)", n)
		}
	}
}

func TestMustAtomPanicsOnReserved(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("MustAtom(\"true\") should panic")
		}
	}()
	_ = MustAtom("true")
}

// ── Predicate + accessor (gate 33.2) ─────────────────────────────────────────

func TestIsAtomPredicate(t *testing.T) {
	a := MustAtom("ok")
	if !IsAtom(a) {
		t.Errorf("IsAtom(AtomValue) = false, want true")
	}
	// Type-strict — strings are not atoms.
	if IsAtom("ok") {
		t.Errorf("IsAtom(\"ok\") = true, want false")
	}
	if IsAtom(42) || IsAtom(nil) || IsAtom(true) {
		t.Errorf("IsAtom should reject non-AtomValue types")
	}
}

func TestAtomNameAccessor(t *testing.T) {
	a := MustAtom("not-found")
	if a.AtomName() != "not-found" {
		t.Errorf("AtomValue.AtomName() = %q, want %q", a.AtomName(), "not-found")
	}
	// Function form.
	name, ok := AtomName(a)
	if !ok || name != "not-found" {
		t.Errorf("AtomName(AtomValue) = (%q, %v), want (\"not-found\", true)", name, ok)
	}
}

func TestAtomNameRejectsNonAtom(t *testing.T) {
	// Type-strict — no string coercion.
	if name, ok := AtomName("ok"); ok || name != "" {
		t.Errorf("AtomName(\"ok\") = (%q, %v), want (\"\", false)", name, ok)
	}
	if _, ok := AtomName(nil); ok {
		t.Errorf("AtomName(nil) should return ok=false")
	}
}

// ── Equality (gate 33.2) ─────────────────────────────────────────────────────

func TestAtomEqualityTypeStrict(t *testing.T) {
	a := MustAtom("ok")
	b := MustAtom("ok")
	if a != b {
		t.Errorf("two AtomValue('ok') should compare equal by value")
	}
	c := MustAtom("err")
	if a == c {
		t.Errorf("AtomValue('ok') and AtomValue('err') must be unequal")
	}
	// Type-strict — atom vs string interface-eq must be false.
	var anyA any = a
	var anyS any = "ok"
	if anyA == anyS {
		t.Errorf("AtomValue('ok') == \"ok\" violates type-strict equality")
	}
}

// ── String render (gate 33.4) ────────────────────────────────────────────────

func TestAtomStringRender(t *testing.T) {
	a := MustAtom("ok")
	if a.String() != ":ok" {
		t.Errorf("AtomValue.String() = %q, want %q", a.String(), ":ok")
	}
	if MustAtom("not-found").String() != ":not-found" {
		t.Errorf("kebab-name render mismatch")
	}
}

// ── ast_bin round-trip (gate 33.3 + 33.4) ────────────────────────────────────

func TestAtomDecodesToAtomValue(t *testing.T) {
	doc, err := Parse("[event kind=:click]")
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	el, ok := doc.Elements[0].(*Element)
	if !ok {
		t.Fatalf("first element type %T, want *Element", doc.Elements[0])
	}
	if len(el.Attrs) != 1 {
		t.Fatalf("attr count = %d, want 1", len(el.Attrs))
	}
	attr := el.Attrs[0]
	if attr.DataType != "atom" {
		t.Errorf("attr.DataType = %q, want \"atom\"", attr.DataType)
	}
	if !IsAtom(attr.Value) {
		t.Errorf("attr.Value type %T, want AtomValue", attr.Value)
	}
	name, ok := AtomName(attr.Value)
	if !ok || name != "click" {
		t.Errorf("AtomName(attr.Value) = (%q, %v), want (\"click\", true)", name, ok)
	}
}

func TestAtomAstBinRoundTrip(t *testing.T) {
	src := "[event kind=:click]"
	doc, err := Parse(src)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	// Document.ToCx hands the document back through the C ABI via
	// encodeAST → cx_ast_bin_to_cx, so this exercises the full round-trip
	// (gate 33.3 + canonical render gate 33.4).
	out := strings.TrimSpace(doc.ToCx())
	if out != src {
		t.Errorf("round-trip mismatch:\n  got:  %q\n  want: %q", out, src)
	}
}

func TestAtomInElementBodyRoundTrip(t *testing.T) {
	// Atom inside an element body (not just attribute).
	src := "[state :idle]"
	doc, err := Parse(src)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	out := strings.TrimSpace(doc.ToCx())
	if out != src {
		t.Errorf("body-position round-trip mismatch:\n  got:  %q\n  want: %q", out, src)
	}
}

// ── Identity-hash disjoint domain (gate 33.6) ───────────────────────────────

func TestAtomHashDisjointFromString(t *testing.T) {
	// libcx's cx_hash over the canonical form is the load-bearing hash;
	// V's atom_test.v covers it directly. Here we mirror the test by
	// confirming canonical forms differ — that propagates through to the
	// SHA-256 over the canonical bytes.
	atomCanon, err := Canonical("[v kind=:ok]")
	if err != nil {
		t.Fatalf("Canonical(atom): %v", err)
	}
	stringCanon, err := Canonical("[v kind='ok']")
	if err != nil {
		t.Fatalf("Canonical(string): %v", err)
	}
	if atomCanon == stringCanon {
		t.Errorf("canonical form collision: atom %q == string %q", atomCanon, stringCanon)
	}

	atomHash, err := Hash("[v kind=:ok]")
	if err != nil {
		t.Fatalf("Hash(atom): %v", err)
	}
	stringHash, err := Hash("[v kind='ok']")
	if err != nil {
		t.Fatalf("Hash(string): %v", err)
	}
	if atomHash == stringHash {
		t.Errorf("identity hash collision: atom %q == string %q (gate 33.6)", atomHash, stringHash)
	}
}

// ── Capability bit advertisement ─────────────────────────────

func TestFeaturesAdvertisesAtomCapBit(t *testing.T) {
	bits := Features()
	if bits&(1<<33) == 0 {
		t.Errorf("cx_features = 0x%x, missing bit 33 (0x200000000) — atom support unadvertised", bits)
	}
}
