// atom.go atom scalar kind for the Go binding.
//
// Atom is a name-equality, type-strict scalar kind ("symbol" in other
// ecosystems). Surface form `:NAME`. Type-strict equality, Layer-1
// surface, round-trip + hash domain, and a closed reserved-name list.
//
// The Go binding's Layer-1 surface matches V's atom(name) / is_atom(v) /
// atom_name(v) triple, adapted to Go's PascalCase convention per
// `spec/bindings.md`:
//
//   cx.Atom(name)    — constructor returning an AtomValue
//   cx.IsAtom(v)     — predicate; type-strict (strings return false)
//   cx.AtomName(v)   — accessor; non-atom returns "" + false
//   v.AtomName()     — method accessor on AtomValue
//
// Atom values flow through Attr.Value / ScalarNode.Value as the typed
// AtomValue wrapper (rather than a bare string) so equality is naturally
// type-strict: an AtomValue compares unequal to a same-named string by
// Go's standard interface-equality rules.

package cxlib

import (
	"fmt"
	"regexp"
)

// ── AtomValue ────────────────────────────────────────────────────────────────

// AtomValue is the typed wrapper carrying an atom's name through the
// AST. Equality via Go's `==` and `reflect.DeepEqual` is by Name only,
// and an AtomValue compares unequal to any plain string with the same
// content — that's the type-strict equality rule.
//
// The struct is value-typed (not a pointer) so it behaves as a scalar
// at every callsite. It's also comparable, so it can serve as a map key
// inside Go (note: forbids atoms as keys in CX Map nodes;
// that rule applies to the on-the-wire shape, not Go internals).
type AtomValue struct {
	Name string
}

// String implements fmt.Stringer with the canonical render `:name`
func (a AtomValue) String() string { return ":" + a.Name }

// AtomName returns the atom's name (without the leading colon). Method
// accessor per spec/bindings.md §Layer 1 — Go uses receiver methods
// where idiomatic.
func (a AtomValue) AtomName() string { return a.Name }

// ── Layer-1 surface ───────────────────────────────────────────

// atomReservedNames is the closed-list reservation. Three
// names that would shadow scalar literals (`:true` / `:false` / `:null`)
// are rejected at lex time in V (vcx/code/parser.v parse_atom_literal).
// The Go binding mirrors the rule at construction time.
var atomReservedNames = map[string]struct{}{
	"true":  {},
	"false": {},
	"null":  {},
}

// atomNameRe matches the identifier production from spec/grammar.ebnf §3.4
// `[A-Za-z_][A-Za-z0-9_-]*`.
var atomNameRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_-]*$`)

// Atom constructs a typed atom value, validating against the
// §D1 identifier production and §D8 reserved-name list. Returns an
// error rather than panicking so callers can decide between fail-fast
// (`MustAtom`) and graceful degradation.
func Atom(name string) (AtomValue, error) {
	if _, reserved := atomReservedNames[name]; reserved {
		return AtomValue{}, fmt.Errorf(
			"atom literal ':%s' is reserved; "+
				"use bare '%s' for the bool/null scalar", name, name)
	}
	if !atomNameRe.MatchString(name) {
		return AtomValue{}, fmt.Errorf(
			"atom name %q does not match identifier production "+
				"[A-Za-z_][A-Za-z0-9_-]*", name)
	}
	return AtomValue{Name: name}, nil
}

// MustAtom is the panic-on-invalid variant of Atom, suitable for
// compile-time-known constants (`var OK = cx.MustAtom("ok")`).
func MustAtom(name string) AtomValue {
	a, err := Atom(name)
	if err != nil {
		panic(err)
	}
	return a
}

// IsAtom returns true iff v is an AtomValue. Per §D2
// equality is type-strict — strings, ints, and other scalar kinds all
// return false even if their content matches an atom's name.
func IsAtom(v any) bool {
	_, ok := v.(AtomValue)
	return ok
}

// AtomName returns the name of an AtomValue and true; for non-atom
// values it returns "" and false. The dual-return shape matches Go's
// type-assertion idiom (cf. `v, ok := m[k]`) and avoids the panic
// surface of a single-return accessor.
//
// To get the atom name as a method instead, use `v.AtomName()` on a
// typed AtomValue receiver.
func AtomName(v any) (string, bool) {
	if a, ok := v.(AtomValue); ok {
		return a.Name, true
	}
	return "", false
}
