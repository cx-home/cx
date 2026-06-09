module main

import cx
import native

// ── Phase 3.2 — V native binding v0.8.0 Layer-1 surface tests ────────────────
//
// Coverage per `spec/bindings.md` §2.1:
//   - 10 Doc methods + 6 Node methods
//   - 3 free functions: cx_code_eval / cx_code_diagram / cx_code_tree
//   - 3 atom helpers: native.atom / is_atom / atom_name (covered in
//     native_atom_test.v; one round-trip check below for completeness).

const sample_users = '[users [user id=1 name=alice active=true] [user id=2 name=bob active=false]]'

// ── Layer-1 free functions ───────────────────────────────────────────────────

fn test_cx_code_eval_hello() {
	// Per conformance/binding_api.txt binding-api-010: a bare literal
	// program evaluates to its value rendered at the requested target.
	out := native.cx_code_eval('', '42', '') or {
		assert false, 'cx_code_eval failed: ${err.msg()}'
		return
	}
	assert out.contains('42'), 'expected 42 in output, got: ${out}'
}

fn test_cx_code_eval_rejects_empty_program() {
	_ := native.cx_code_eval('', '', '') or {
		assert err.msg().contains('CXER0100'), 'expected CXER0100, got: ${err.msg()}'
		return
	}
	assert false, 'empty program should fail'
}

fn test_cx_code_diagram_returns_mermaid() {
	out := native.cx_code_diagram('[foo bar]') or {
		assert false, 'cx_code_diagram failed: ${err.msg()}'
		return
	}
	// Either Mermaid `erDiagram` (data shape) or `flowchart TD` (code
	// shape) per `vcx/code/code_diagram.v:65`.
	assert out.contains('erDiagram') || out.contains('flowchart'),
		'expected Mermaid diagram, got: ${out}'
}

fn test_cx_code_diagram_rejects_empty_source() {
	_ := native.cx_code_diagram('') or {
		assert err.msg().contains('CXER0100')
		return
	}
	assert false, 'empty source should fail'
}

fn test_cx_code_tree_returns_json() {
	out := native.cx_code_tree('[hello]') or {
		assert false, 'cx_code_tree failed: ${err.msg()}'
		return
	}
	// Per `vcx/cx/code_tree.v` shape contract.
	assert out.contains('"kind"'), 'expected JSON tree, got: ${out}'
	assert out.contains('"loc"')
}

fn test_cx_code_tree_empty_source() {
	out := native.cx_code_tree('') or {
		assert false, 'cx_code_tree failed: ${err.msg()}'
		return
	}
	// Empty-source contract: synthetic root at [0,0).
	assert out.contains('"name":"root"'), 'expected synthetic root, got: ${out}'
	assert out.contains('"start":0')
}

// ── Doc method 1: parse_doc (Layer-1 parse(bytes) → Doc) ─────────────────────

fn test_parse_doc_basic() {
	d := native.parse_doc(sample_users) or {
		assert false, 'parse_doc failed: ${err.msg()}'
		return
	}
	assert d.source == sample_users
}

fn test_parse_doc_rejects_malformed() {
	_ := native.parse_doc('[unclosed') or {
		assert err.msg().contains('CXER0100'), 'expected CXER0100, got: ${err.msg()}'
		return
	}
	assert false, 'malformed source should fail'
}

// ── Doc method 2: bytes() ────────────────────────────────────────────────────

fn test_doc_bytes_returns_canonical() {
	d := native.parse_doc(sample_users) or { panic(err) }
	b := d.bytes()
	assert b.len > 0
	assert b.contains('user')
}

// ── Doc method 3: hash() ─────────────────────────────────────────────────────

fn test_doc_hash_is_sha256_hex() {
	d := native.parse_doc(sample_users) or { panic(err) }
	h := d.hash() or {
		assert false, 'hash failed: ${err.msg()}'
		return
	}
	// SHA-256 hex is 64 chars; ABI spec/abi.md §2.6.
	assert h.len == 64, 'expected 64-char hex, got ${h.len}: ${h}'
}

fn test_doc_hash_stable_across_parses() {
	d1 := native.parse_doc(sample_users) or { panic(err) }
	d2 := native.parse_doc(sample_users) or { panic(err) }
	h1 := d1.hash() or { panic(err) }
	h2 := d2.hash() or { panic(err) }
	assert h1 == h2
}

// ── Doc method 4: equals() ───────────────────────────────────────────────────

fn test_doc_equals_self() {
	d := native.parse_doc(sample_users) or { panic(err) }
	eq := d.equals(d) or { panic(err) }
	assert eq
}

fn test_doc_equals_differs_when_content_differs() {
	d1 := native.parse_doc('[a 1]') or { panic(err) }
	d2 := native.parse_doc('[a 2]') or { panic(err) }
	eq := d1.equals(d2) or { panic(err) }
	assert !eq
}

// ── Doc method 5: eval() ─────────────────────────────────────────────────────

fn test_doc_eval_simple_yield() {
	d := native.parse_doc('[hello]') or { panic(err) }
	out := d.eval('42') or {
		assert false, 'eval failed: ${err.msg()}'
		return
	}
	assert out.contains('42')
}

// ── Doc method 6 + 7: select_all / select ────────────────────────────────────

fn test_doc_select_all_basic() {
	d := native.parse_doc(sample_users) or { panic(err) }
	matches := d.select_all('//user') or {
		assert false, 'select_all failed: ${err.msg()}'
		return
	}
	assert matches.len >= 1, 'expected at least one user, got ${matches.len}'
}

fn test_doc_select_all_returns_empty_for_no_match() {
	d := native.parse_doc(sample_users) or { panic(err) }
	matches := d.select_all('//nonexistent') or { panic(err) }
	assert matches.len == 0
}

fn test_doc_select_returns_first_match() {
	d := native.parse_doc(sample_users) or { panic(err) }
	first := d.select('//user') or {
		assert false, 'select failed: ${err.msg()}'
		return
	}
	assert first.name() == 'user'
}

fn test_doc_select_errors_on_no_match() {
	d := native.parse_doc(sample_users) or { panic(err) }
	_ := d.select('//nonexistent') or {
		assert err.msg().contains('CXER0103')
		return
	}
	assert false, 'select on no-match should raise CXER0103'
}

// ── Doc method 8: modify ─────────────────────────────────────────────────────

fn test_doc_modify_returns_new_doc() {
	d := native.parse_doc('[counter 1]') or { panic(err) }
	d2 := d.modify('//counter', '[set 2]') or {
		assert false, 'modify failed: ${err.msg()}'
		return
	}
	// Pure-functional: original unchanged.
	assert d.source.contains('1')
	// New Doc reflects the update.
	assert d2.source.contains('2') || d2.bytes().contains('2'),
		'expected counter=2 in modified Doc, got: ${d2.source}'
}

// ── Doc method 9: find_all ───────────────────────────────────────────────────

fn test_doc_find_all_depth_first() {
	d := native.parse_doc(sample_users) or { panic(err) }
	users := d.find_all('user')
	assert users.len == 2, 'expected 2 users, got ${users.len}'
}

fn test_doc_find_all_missing_returns_empty() {
	d := native.parse_doc(sample_users) or { panic(err) }
	missing := d.find_all('nonexistent')
	assert missing.len == 0
}

// ── Doc method 10: root ──────────────────────────────────────────────────────

fn test_doc_root_returns_first_element() {
	d := native.parse_doc(sample_users) or { panic(err) }
	r := d.root() or {
		assert false, 'expected root'
		return
	}
	assert r.name() == 'users'
}

fn test_doc_root_none_on_empty() {
	d := native.parse_doc('') or { panic(err) }
	if _ := d.root() {
		assert false, 'expected none on empty doc'
	}
}

// ── Node method 11: name ─────────────────────────────────────────────────────

fn test_node_name() {
	d := native.parse_doc(sample_users) or { panic(err) }
	r := d.root() or { panic('no root') }
	assert r.name() == 'users'
}

// ── Node method 12 + 13: attr / attrs ────────────────────────────────────────

fn test_node_attr_returns_scalar_value() {
	d := native.parse_doc(sample_users) or { panic(err) }
	first_user := d.select('//user') or { panic('no user') }
	id := first_user.attr('id') or {
		assert false, 'no id attr'
		return
	}
	if id is i64 {
		assert id == 1
	} else {
		assert (id as string) == '1' || (id as i64) == 1
	}
}

fn test_node_attr_returns_none_for_missing() {
	d := native.parse_doc(sample_users) or { panic(err) }
	r := d.root() or { panic('no root') }
	if _ := r.attr('nonexistent') {
		assert false, 'expected none'
	}
}

fn test_node_attrs_map() {
	d := native.parse_doc(sample_users) or { panic(err) }
	first_user := d.select('//user') or { panic('no user') }
	attrs := first_user.attrs()
	assert 'id' in attrs
	assert 'name' in attrs
}

// ── Node method 14: children ─────────────────────────────────────────────────

fn test_node_children_returns_direct_elements() {
	d := native.parse_doc(sample_users) or { panic(err) }
	r := d.root() or { panic('no root') }
	kids := r.children()
	assert kids.len == 2, 'expected 2 user children, got ${kids.len}'
	assert kids[0].name() == 'user'
}

// ── Node method 15: body ─────────────────────────────────────────────────────

fn test_node_body_scalar() {
	d := native.parse_doc('[name alice]') or { panic(err) }
	r := d.root() or { panic('no root') }
	assert r.body().contains('alice')
}

fn test_node_body_empty_when_only_children() {
	d := native.parse_doc('[outer [inner]]') or { panic(err) }
	r := d.root() or { panic('no root') }
	assert r.body() == ''
}

// ── Node method 16: kind ─────────────────────────────────────────────────────

fn test_node_kind_is_element() {
	d := native.parse_doc(sample_users) or { panic(err) }
	r := d.root() or { panic('no root') }
	assert r.kind() == 'element'
}

// ── Layer-2 idiom shortcuts: Doc.diagram / Doc.tree / Doc.eval ───────────────

fn test_doc_diagram_shortcut() {
	d := native.parse_doc('[foo bar]') or { panic(err) }
	out := d.diagram() or {
		assert false, 'Doc.diagram failed: ${err.msg()}'
		return
	}
	assert out.contains('erDiagram') || out.contains('flowchart')
}

fn test_doc_tree_shortcut() {
	d := native.parse_doc('[hello]') or { panic(err) }
	out := d.tree() or {
		assert false, 'Doc.tree failed: ${err.msg()}'
		return
	}
	assert out.contains('"kind"')
}

fn test_doc_eval_to_target() {
	d := native.parse_doc('[a 1]') or { panic(err) }
	out := d.eval_to('9', 'text') or {
		assert false, 'eval_to failed: ${err.msg()}'
		return
	}
	assert out.contains('9')
}

// ── Atom round-trip (cross-check with native_atom_test.v) ────────────────────

fn test_atom_constructor_roundtrip() {
	a := native.atom('ok') or {
		assert false, 'atom failed: ${err.msg()}'
		return
	}
	assert native.is_atom(a)
	name := native.atom_name(a) or { panic(err) }
	assert name == 'ok'
}

// ── Layer-1 contract sanity: 16 distinct methods exist + 3 free fns + 3 atoms ─

fn test_layer1_method_count_sanity() {
	// Tickles every Layer-1 entry in one shot — proves the surface
	// compiles together. Per spec/bindings.md §2.1 (16 methods) +
	// (3 cx_code_* free fns) (3 atom fns).
	d := native.parse_doc('[a 1]') or { panic(err) }
	_ := d.bytes()
	_ := d.hash() or { panic(err) }
	_ := d.equals(d) or { panic(err) }
	_ := d.eval('1') or { panic(err) }
	_ := d.select_all('//a') or { panic(err) }
	_ := d.find_all('a')
	_ := d.root() or { panic('no root') }

	r := d.root() or { panic('no root') }
	_ := r.name()
	_ := r.attrs()
	_ := r.children()
	_ := r.body()
	_ := r.kind()

	_ := native.cx_code_eval('', '1', '') or { panic(err) }
	_ := native.cx_code_diagram('[a]') or { panic(err) }
	_ := native.cx_code_tree('[a]') or { panic(err) }

	a := native.atom('hello') or { panic(err) }
	_ := native.is_atom(a)
	_ := native.atom_name(a) or { panic(err) }

	// Reference cx to avoid unused-import warning if every accessor
	// returns into `_`.
	_ := cx.ScalarType.string_type
}
