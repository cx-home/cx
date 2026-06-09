// CX V binding — atom scalar kind (v0.8.0).
//
// Layer-1 surface for the new `atom` scalar kind: constructor,
// predicate, and name accessor. Atoms are first-class scalars
// distinct from strings (per spec/cxdm.md §4.1 — no atom↔string
// coercion). Surface syntax `:NAME` parses to a ScalarNode with
// data_type=.atom_type and value=ScalarValue(name).
//
// Per: V native is the Tier-1 binding that lands atom
// support in v0.8.0. Python / Go / Rust catch up in Phase 3 of
// spec/v0_8_0_status.md.

module native

import cx

// atom constructs a typed atom scalar value from a name. Name must
// match the identifier production `[A-Za-z_][A-Za-z0-9_-]*` per
// spec/code.md §3.4 / §3.6. Reserved names `true`, `false`, `null`
// are rejected with an error — use the bare bool
// null scalar in those cases instead.
//
// Examples:
//   a := native.atom('ok')!         // → ScalarNode atom :ok
//   b := native.atom('not-found')!  // → ScalarNode atom :not-found
//   _ := native.atom('true')        // → error CXER0100
pub fn atom(name string) !cx.ScalarNode {
	if name.len == 0 {
		return error('cx-err:CXER0100: atom name must not be empty')
	}
	if !is_valid_atom_name(name) {
		return error('cx-err:CXER0100: invalid atom name "${name}" — must match [A-Za-z_][A-Za-z0-9_-]*')
	}
	if name == 'true' || name == 'false' || name == 'null' {
		return error('cx-err:CXER0100: atom literal ":${name}" is reserved; use the bare bool/null scalar')
	}
	return cx.ScalarNode{
		data_type: .atom_type
		value:     cx.ScalarValue(name)
	}
}

// is_atom reports whether `n` is a typed atom scalar. False for
// scalars of any other kind, for Elements, for collection nodes,
// and for any other Node variant.
pub fn is_atom(n cx.Node) bool {
	if n is cx.ScalarNode {
		return n.data_type == .atom_type
	}
	return false
}

// atom_name returns the atom's name (without the leading `:`).
// Returns an error if `n` is not an atom.
//
// Examples:
//   a := native.atom('ok')!
//   name := native.atom_name(a)!  // → 'ok'
pub fn atom_name(n cx.Node) !string {
	if n is cx.ScalarNode {
		if n.data_type == .atom_type {
			if n.value is string {
				return n.value as string
			}
			return error('cx-err:CXER0001: atom ScalarNode value is not a string (internal invariant violated)')
		}
	}
	return error('cx-err:CXER0100: not an atom — got ${n.type_name()}')
}

// is_valid_atom_name reports whether `s` is a syntactically-valid
// atom name per spec/code.md §3.6 (the ident production matching
// spec/code.md §3.4 and spec/grammar.ebnf [122b]). Does not check
// the reserved-name rule (that lives in `atom`).
fn is_valid_atom_name(s string) bool {
	if s.len == 0 { return false }
	c0 := s[0]
	if !((c0 >= `a` && c0 <= `z`) || (c0 >= `A` && c0 <= `Z`) || c0 == `_`) {
		return false
	}
	for i in 1 .. s.len {
		c := s[i]
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) ||
		   (c >= `0` && c <= `9`) || c == `_` || c == `-` {
			continue
		}
		return false
	}
	return true
}
