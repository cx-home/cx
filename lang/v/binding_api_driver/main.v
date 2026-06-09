module main

// Binding-API parity driver — V.
//
// Reads one JSON fixture object on stdin (see
// scripts/compile_binding_api_fixtures.py) and executes it through the
// Layer-1 surface in lang/v/native.
//
// Output protocol matches lang/python/cmd/binding_api_driver.py.

import os
import x.json2 as json
import cx
import native

// ── op-tree shape ────────────────────────────────────────────────────────────
//
// The JSON op-tree is decoded into json.Any nodes; we walk them
// directly rather than projecting into V structs (V's json2 decoder is
// dynamic-typed). Each op is a map with a "kind" key.

// ── result tagging ───────────────────────────────────────────────────────────

// Tagged-union return type for evaluator results. V lacks Python's
// flexible Any, so we encode kind via an enum + payload fields. raw_str
// is canonical-CX text we must NOT requote; str is a CX-string value
// that renders with quotes.

enum Kind {
	null_v
	raw_str
	cx_string
	cx_int
	cx_float
	cx_bool
	cx_doc
	cx_node
	cx_node_list
	cx_attrs
	cx_action
	cx_lambda_cx
}

struct Value {
	kind      Kind
	raw       string
	s         string
	i         i64
	f         f64
	b         bool
	d         native.Doc
	n         native.Node
	nodes     []native.Node
	attrs_map map[string]cx.ScalarValue
	act_name  string
	act_args  []Value
}

fn lambda_cx_value(src string) Value {
	return Value{kind: .cx_lambda_cx, s: src}
}

fn null_value() Value {
	return Value{kind: .null_v}
}

fn raw_value(s string) Value {
	return Value{kind: .raw_str, raw: s}
}

fn string_value(s string) Value {
	return Value{kind: .cx_string, s: s}
}

fn int_value(i i64) Value {
	return Value{kind: .cx_int, i: i}
}

fn float_value(f f64) Value {
	return Value{kind: .cx_float, f: f}
}

fn bool_value(b bool) Value {
	return Value{kind: .cx_bool, b: b}
}

fn doc_value(d native.Doc) Value {
	return Value{kind: .cx_doc, d: d}
}

fn node_value(n native.Node) Value {
	return Value{kind: .cx_node, n: n}
}

fn node_list_value(ns []native.Node) Value {
	return Value{kind: .cx_node_list, nodes: ns}
}

fn attrs_value(m map[string]cx.ScalarValue) Value {
	return Value{kind: .cx_attrs, attrs_map: m}
}

fn action_value(name string, args []Value) Value {
	return Value{kind: .cx_action, act_name: name, act_args: args}
}

// ── string rendering ────────────────────────────────────────────────────────

fn render_string(s string) string {
	mut out := s.replace('\\', '\\\\')
	out = out.replace('"', '\\"')
	return '"${out}${'"'}'
}

fn render_scalar(sv cx.ScalarValue) string {
	return match sv {
		bool { if sv { 'true' } else { 'false' } }
		i64 { sv.str() }
		f64 { sv.str() }
		string { render_string(sv) }
		cx.NullValue { '()' }
	}
}

fn extract_code(msg string) string {
	// Scan for CXERnnnn substring.
	for i := 0; i + 8 <= msg.len; i++ {
		if msg[i] == `C` && msg[i + 1] == `X` && msg[i + 2] == `E` && msg[i + 3] == `R` {
			mut all_digits := true
			for j in 4 .. 8 {
				c := msg[i + j]
				if c < `0` || c > `9` {
					all_digits = false
					break
				}
			}
			if all_digits {
				return msg[i..i + 8]
			}
		}
	}
	return 'UNKNOWN-ERROR'
}

// ── op-tree evaluator ────────────────────────────────────────────────────────

struct EvalState {
mut:
	doc      ?native.Doc
	err_code string
	env      map[string]Value
}

fn (mut st EvalState) eval(op json.Any) Value {
	if st.err_code != '' {
		return null_value()
	}
	m := op as map[string]json.Any
	kind := (m['kind'] or { json.Any('') }).str()
	match kind {
		'doc_ref' {
			if doc := st.doc {
				return doc_value(doc)
			}
			st.err_code = 'CXER0100'
			return null_value()
		}
		'str' {
			return string_value((m['value'] or { json.Any('') }).str())
		}
		'num' {
			s := (m['value'] or { json.Any('') }).str()
			if s.contains('.') {
				return float_value(s.f64())
			}
			return int_value(s.i64())
		}
		'bool' {
			return bool_value((m['value'] or { json.Any(false) }).bool())
		}
		'action' {
			name := (m['name'] or { json.Any('') }).str()
			args_raw := (m['args'] or { json.Any([]json.Any{}) }) as []json.Any
			mut args := []Value{}
			for a in args_raw {
				args << st.eval(a)
				if st.err_code != '' {
					return null_value()
				}
			}
			return action_value(name, args)
		}
		'lambda_cx' {
			src := (m['source'] or { json.Any('') }).str()
			return lambda_cx_value(src)
		}
		'method' {
			tgt_op := m['target'] or { return null_value() }
			tgt := st.eval(tgt_op)
			if st.err_code != '' {
				return null_value()
			}
			method := (m['method'] or { json.Any('') }).str()
			args_raw := (m['args'] or { json.Any([]json.Any{}) }) as []json.Any
			mut args := []Value{}
			for a in args_raw {
				args << st.eval(a)
				if st.err_code != '' {
					return null_value()
				}
			}
			return st.dispatch(tgt, method, args)
		}
		'var' {
			name := (m['name'] or { json.Any('') }).str()
			if v := st.env[name] {
				return v
			}
			st.err_code = 'UNDEFINED-VAR-${name}'
			return null_value()
		}
		'eq' {
			lop := m['left'] or { return null_value() }
			rop := m['right'] or { return null_value() }
			lhs := st.eval(lop)
			if st.err_code != '' {
				return null_value()
			}
			rhs := st.eval(rop)
			if st.err_code != '' {
				return null_value()
			}
			return bool_value(eq_values(lhs, rhs))
		}
		'block' {
			bindings_raw := (m['bindings'] or { json.Any([]json.Any{}) }) as []json.Any
			result_name := (m['result'] or { json.Any('') }).str()
			saved_env := st.env.clone()
			for b_any in bindings_raw {
				b := b_any as map[string]json.Any
				name := (b['name'] or { json.Any('') }).str()
				bop := b['op'] or {
					st.err_code = 'BINDING-MISSING-OP'
					return null_value()
				}
				v := st.eval(bop)
				if st.err_code != '' {
					st.env = saved_env.clone()
					return null_value()
				}
				st.env[name] = v
			}
			final := st.env[result_name] or {
				st.err_code = 'UNKNOWN-RESULT-${result_name}'
				return null_value()
			}
			st.env = saved_env.clone()
			return final
		}
		'spawn' {
			body := m['body'] or { return null_value() }
			// V's `spawn` returns a thread-handle. We snapshot the
			// op + state, run it on the new thread, and wait for the
			// result. The point of the fixture is to exercise the
			// binding's GC thread-register path; a fresh thread does
			// that whether or not we'd actually fan out the work.
			handle := spawn run_spawn(st.doc, st.env.clone(), body)
			res := handle.wait()
			if res.err_code != '' {
				st.err_code = res.err_code
				return null_value()
			}
			return res.value
		}
		else {
			st.err_code = 'UNKNOWN-OP-${kind}'
			return null_value()
		}
	}
}

struct SpawnResult {
	value    Value
	err_code string
}

fn run_spawn(doc ?native.Doc, env map[string]Value, body json.Any) SpawnResult {
	mut st := EvalState{
		doc: doc
		env: env
	}
	v := st.eval(body)
	return SpawnResult{
		value: v
		err_code: st.err_code
	}
}

fn eq_values(a Value, b Value) bool {
	return value_to_eq_key(a) == value_to_eq_key(b)
}

fn value_to_eq_key(v Value) string {
	return match v.kind {
		.raw_str { v.raw }
		.cx_string { v.s }
		.cx_int { v.i.str() }
		.cx_float { v.f.str() }
		.cx_bool { if v.b { 'true' } else { 'false' } }
		else { render_top(v) }
	}
}

fn (mut st EvalState) dispatch(target Value, method string, args []Value) Value {
	match target.kind {
		.cx_doc {
			return st.dispatch_doc(target.d, method, args)
		}
		.cx_node {
			return st.dispatch_node(target.n, method, args)
		}
		.cx_node_list {
			if method == 'count' {
				return int_value(target.nodes.len)
			}
			st.err_code = 'UNKNOWN-LIST-METHOD-${method}'
			return null_value()
		}
		.null_v {
			st.err_code = 'CXER0100'
			return null_value()
		}
		else {
			st.err_code = 'UNKNOWN-TARGET-${method}'
			return null_value()
		}
	}
}

fn (mut st EvalState) dispatch_doc(d native.Doc, method string, args []Value) Value {
	match method {
		'bytes' {
			return raw_value(d.bytes().trim_right('\n'))
		}
		'hash' {
			h := d.hash() or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return raw_value(h)
		}
		'equals' {
			if args.len < 1 || args[0].kind != .cx_doc {
				st.err_code = 'CXER0100'
				return null_value()
			}
			b := d.equals(args[0].d) or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return bool_value(b)
		}
		'eval' {
			if args.len < 1 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			s := d.eval(args[0].s) or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return raw_value(s.trim_right('\n'))
		}
		'select_all' {
			if args.len < 1 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			ns := d.select_all(args[0].s) or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return node_list_value(ns)
		}
		'select' {
			if args.len < 1 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			n := d.select(args[0].s) or {
				// CXER0103 = no match. Spec says select returns Node? —
				// map "no match" to null_v rather than err.
				code := extract_code(err.msg())
				if code == 'CXER0103' {
					return null_value()
				}
				st.err_code = code
				return null_value()
			}
			return node_value(n)
		}
		'modify' {
			if args.len < 2 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			focus := args[0].s
			action_str := if args[1].kind == .cx_action {
				render_action(args[1])
			} else if args[1].kind == .cx_string {
				args[1].s
			} else {
				st.err_code = 'CXER0100'
				return null_value()
			}
			nd := d.modify(focus, action_str) or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return doc_value(nd)
		}
		'find_all' {
			if args.len < 1 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			return node_list_value(d.find_all(args[0].s))
		}
		'root' {
			n := d.root() or { return null_value() }
			return node_value(n)
		}
		'parse' {
			if args.len < 1 {
				st.err_code = 'CXER0100'
				return null_value()
			}
			src := match args[0].kind {
				.cx_string { args[0].s }
				.raw_str { args[0].raw }
				else { '' }
			}
			nd := native.parse_doc(src) or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return doc_value(nd)
		}
		'diagram' {
			s := d.diagram() or {
				st.err_code = extract_code(err.msg())
				return null_value()
			}
			return raw_value(s)
		}
		else {
			st.err_code = 'UNKNOWN-DOC-METHOD-${method}'
			return null_value()
		}
	}
}

fn (mut st EvalState) dispatch_node(n native.Node, method string, args []Value) Value {
	match method {
		'name' {
			return string_value(n.name())
		}
		'attr' {
			if args.len < 1 || args[0].kind != .cx_string {
				st.err_code = 'CXER0100'
				return null_value()
			}
			sv := n.attr(args[0].s) or { return null_value() }
			return scalar_to_value(sv)
		}
		'attrs' {
			return attrs_value(n.attrs())
		}
		'children' {
			return node_list_value(n.children())
		}
		'body' {
			return string_value(n.body())
		}
		'kind' {
			return string_value(n.kind())
		}
		else {
			st.err_code = 'UNKNOWN-NODE-METHOD-${method}'
			return null_value()
		}
	}
}

fn scalar_to_value(sv cx.ScalarValue) Value {
	return match sv {
		bool { bool_value(sv) }
		i64 { int_value(sv) }
		f64 { float_value(sv) }
		string { string_value(sv) }
		cx.NullValue { null_value() }
	}
}

// ── action rendering ────────────────────────────────────────────────────────

fn action_keyword(name string) string {
	return match name {
		'Set' { 'set' }
		'Delete' { 'delete' }
		'Rename' { 'rename' }
		'SetAttr' { 'set-attr' }
		'DeleteAttr' { 'delete-attr' }
		'Append' { 'append' }
		'Prepend' { 'prepend' }
		'InsertBefore' { 'insert-before' }
		'InsertAfter' { 'insert-after' }
		'Replace' { 'replace' }
		'Using' { 'using' }
		else { name.to_lower() }
	}
}

fn is_ident(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !((c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
			|| (c >= `0` && c <= `9`) || c == `_`) {
			return false
		}
	}
	return true
}

fn render_action(v Value) string {
	kw := action_keyword(v.act_name)
	mut parts := ['[${kw}']
	for arg in v.act_args {
		match arg.kind {
			.cx_lambda_cx {
				parts << arg.s
			}
			.cx_string {
				s := arg.s
				if kw == 'rename' && is_ident(s) {
					parts << s
				} else if (kw == 'append' || kw == 'prepend' || kw == 'insert-before'
					|| kw == 'insert-after' || kw == 'replace') && s.starts_with('[') {
					parts << s
				} else {
					parts << render_string(s)
				}
			}
			.cx_bool {
				parts << if arg.b { 'true' } else { 'false' }
			}
			.cx_int {
				parts << arg.i.str()
			}
			.cx_float {
				parts << arg.f.str()
			}
			else {
				parts << '?'
			}
		}
	}
	return parts.join(' ') + ']'
}

// ── top-level rendering ─────────────────────────────────────────────────────

fn render_top(v Value) string {
	return match v.kind {
		.null_v { '()' }
		.raw_str { v.raw }
		.cx_string { render_string(v.s) }
		.cx_int { v.i.str() }
		.cx_float { v.f.str() }
		.cx_bool { if v.b { 'true' } else { 'false' } }
		.cx_doc { v.d.bytes().trim_right('\n') }
		.cx_node {
			render_node(v.n)
		}
		.cx_node_list {
			mut parts := []string{}
			for n in v.nodes {
				parts << render_node(n)
			}
			parts.join('\n')
		}
		.cx_attrs {
			render_attrs(v.attrs_map)
		}
		.cx_action {
			render_action(v)
		}
		.cx_lambda_cx {
			v.s
		}
	}
}

fn render_node(n native.Node) string {
	mut doc := cx.Document{}
	doc.elements << n.element
	out := doc.to_cx()
	return out.trim_right('\n')
}

fn render_attrs(m map[string]cx.ScalarValue) string {
	mut keys := m.keys()
	keys.sort()
	mut parts := []string{}
	for k in keys {
		v := m[k] or { cx.ScalarValue(cx.NullValue{}) }
		parts << '${k}: ${render_scalar(v)}'
	}
	return '{' + parts.join(', ') + '}'
}

// ── main ─────────────────────────────────────────────────────────────────────

fn main() {
	raw_input := os.get_raw_lines_joined()
	if raw_input.trim_space() == '' {
		eprintln('ERR:NO-INPUT')
		exit(2)
	}
	any_val := json.decode[json.Any](raw_input) or {
		eprintln('DRIVER-CRASH:${err.msg()}')
		exit(2)
	}
	fx := any_val as map[string]json.Any
	in_cx := (fx['in_cx'] or { json.Any('') }).str()
	ops_any := fx['ops'] or { json.Any(json.Null{}) }
	if ops_any is json.Null {
		println('UNSUPPORTED')
		return
	}
	mut doc_opt := ?native.Doc(none)
	if in_cx != '' {
		d := native.parse_doc(in_cx) or {
			code := extract_code(err.msg())
			println('ERR:${code}')
			return
		}
		doc_opt = d
	}
	mut st := EvalState{
		doc: doc_opt
	}
	result := st.eval(ops_any)
	if st.err_code != '' {
		println('ERR:${st.err_code}')
		return
	}
	println(render_top(result))
}
