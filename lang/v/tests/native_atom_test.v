module main

import cx
import native

// native_atom_test.v — V native binding tests for atom helpers.

fn test_atom_constructor_ok() {
	a := native.atom('ok') or {
		assert false, 'atom(ok) failed: $err'
		return
	}
	assert a.data_type == .atom_type
	assert (a.value as string) == 'ok'
}

fn test_atom_constructor_kebab_case() {
	a := native.atom('not-found') or {
		assert false, 'atom(not-found) failed: $err'
		return
	}
	assert a.data_type == .atom_type
	assert (a.value as string) == 'not-found'
}

fn test_atom_constructor_with_underscore_and_digit() {
	a := native.atom('http_2') or {
		assert false, 'atom(http_2) failed: $err'
		return
	}
	assert a.data_type == .atom_type
	assert (a.value as string) == 'http_2'
}

fn test_atom_constructor_rejects_empty_name() {
	_ := native.atom('') or {
		assert err.msg().contains('CXER0100')
		return
	}
	assert false, 'atom("") should fail'
}

fn test_atom_constructor_rejects_invalid_chars() {
	_ := native.atom('not ok') or {
		assert err.msg().contains('CXER0100')
		return
	}
	assert false, 'atom("not ok") should fail (space in name)'
}

fn test_atom_constructor_rejects_leading_digit() {
	_ := native.atom('1ok') or {
		assert err.msg().contains('CXER0100')
		return
	}
	assert false, 'atom("1ok") should fail (digit-leading name)'
}

fn test_atom_constructor_rejects_reserved_true() {
	_ := native.atom('true') or {
		assert err.msg().contains('CXER0100')
		assert err.msg().contains('reserved')
		return
	}
	assert false, 'atom("true") should fail'
}

fn test_atom_constructor_rejects_reserved_false() {
	_ := native.atom('false') or {
		assert err.msg().contains('reserved')
		return
	}
	assert false, 'atom("false") should fail'
}

fn test_atom_constructor_rejects_reserved_null() {
	_ := native.atom('null') or {
		assert err.msg().contains('reserved')
		return
	}
	assert false, 'atom("null") should fail'
}

fn test_is_atom_true_for_atom() {
	a := native.atom('ok') or {
		assert false, 'atom failed: $err'
		return
	}
	assert native.is_atom(a)
}

fn test_is_atom_false_for_string_scalar() {
	s := cx.ScalarNode{ data_type: .string_type, value: cx.ScalarValue('ok') }
	assert !native.is_atom(s)
}

fn test_is_atom_false_for_int_scalar() {
	s := cx.ScalarNode{ data_type: .int_type, value: cx.ScalarValue(i64(42)) }
	assert !native.is_atom(s)
}

fn test_is_atom_false_for_text_node() {
	t := cx.TextNode{ value: 'ok' }
	assert !native.is_atom(t)
}

fn test_atom_name_returns_payload() {
	a := native.atom('not-found') or {
		assert false, 'atom failed: $err'
		return
	}
	name := native.atom_name(a) or {
		assert false, 'atom_name failed: $err'
		return
	}
	assert name == 'not-found'
}

fn test_atom_name_errors_on_non_atom() {
	s := cx.ScalarNode{ data_type: .string_type, value: cx.ScalarValue('ok') }
	_ := native.atom_name(s) or {
		assert err.msg().contains('not an atom')
		return
	}
	assert false, 'atom_name on string should fail'
}

fn test_atom_emit_through_parse_roundtrip() {
	// Constructor produces a value identical (structurally) to what
	// the parser produces for surface text. Verify by parsing a CX
	// fragment containing an atom attribute and confirming the
	// resulting scalar matches the constructor's output.
	doc := native.parse('[event kind=:click]') or {
		assert false, 'parse failed: $err'
		return
	}
	e := doc.elements[0] as cx.Element
	attr := e.attrs[0]
	dt := attr.data_type() or {
		assert false, 'attribute missing data_type'
		return
	}
	// D3: the attribute data_type carrier is the type-NAME string (?string),
	// not the ScalarType enum.
	assert dt == 'atom'
	assert (attr.value as string) == 'click'
}
