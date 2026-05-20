module main

import os
import cffi as cxlib

const repo_root = os.join_path(os.dir(@FILE), '..', '..')

// ── Suite parser ──────────────────────────────────────────────────────────────

struct Test {
mut:
	name     string
	sections map[string]string
}

fn flush_section(cur_section string, cur_lines []string, mut cur_sections map[string]string) {
	if cur_section == '' {
		return
	}
	mut lines := cur_lines.clone()
	for lines.len > 0 && lines[0].trim_space() == '' {
		lines.delete(0)
	}
	for lines.len > 0 && lines[lines.len - 1].trim_space() == '' {
		lines.delete(lines.len - 1)
	}
	cur_sections[cur_section] = lines.join('\n')
}

fn parse_suite(path string) []Test {
	src := os.read_file(path) or {
		eprintln('cannot read ${path}: ${err}')
		return []
	}
	mut tests := []Test{}
	mut cur_name := ''
	mut cur_sections := map[string]string{}
	mut cur_section := ''
	mut cur_lines := []string{}
	mut in_test := false

	for raw in src.split_into_lines() {
		if raw.starts_with('=== test:') {
			flush_section(cur_section, cur_lines, mut cur_sections)
			if in_test {
				tests << Test{ name: cur_name, sections: cur_sections.clone() }
			}
			cur_name = raw[9..].trim_space()
			cur_sections = map[string]string{}
			cur_section = ''
			cur_lines = []
			in_test = true
		} else if raw.starts_with('level:') || raw.starts_with('tags:') {
			// skip metadata
		} else if raw.starts_with('--- ') && in_test {
			flush_section(cur_section, cur_lines, mut cur_sections)
			cur_section = raw[4..].trim_space()
			cur_lines = []
		} else if in_test && cur_section != '' {
			cur_lines << raw
		}
	}
	flush_section(cur_section, cur_lines, mut cur_sections)
	if in_test {
		tests << Test{ name: cur_name, sections: cur_sections.clone() }
	}
	return tests
}

// ── Test runner ───────────────────────────────────────────────────────────────

fn run_test(t Test) []string {
	mut failures := []string{}

	has_cx  := 'in_cx'  in t.sections
	has_xml := 'in_xml' in t.sections
	has_md  := 'in_md'  in t.sections
	has_cxl := 'in_cxl' in t.sections

	if !has_cx && !has_xml && !has_md && !has_cxl {
		return failures
	}

	in_cx  := t.sections['in_cx']  or { '' }
	in_xml := t.sections['in_xml'] or { '' }
	in_md  := t.sections['in_md']  or { '' }
	in_cxl := t.sections['in_cxl'] or { '' }

	// ── ?include resolution support (GG5) ──────────────────────────
	// `include_root` section signals the parse-time include resolver
	// should run against a per-fixture temp directory. Optional
	// `file_<path>` sections materialise files at `<temp>/<path>`
	// before the resolver runs. Used for cross-binding byte-identity
	// of the spec/include.md §1-§8 engine.
	use_include_resolver := 'include_root' in t.sections
	mut include_root_dir := ''
	mut cleanup_paths := []string{}
	if use_include_resolver {
		mut h := u32(2166136261)
		for c in t.name { h = (h ^ u32(c)) * u32(16777619) }
		include_root_dir = os.join_path(os.temp_dir(), 'cx_inc_${os.getpid()}_${h:08x}')
		os.rmdir_all(include_root_dir) or {}
		os.mkdir_all(include_root_dir) or { failures << 'cannot create temp dir ${include_root_dir}: ${err}'; return failures }
		cleanup_paths << include_root_dir
		for k, v in t.sections {
			if k.starts_with('file_') {
				rel_path := k[5..]
				full := os.join_path(include_root_dir, rel_path)
				os.mkdir_all(os.dir(full)) or {}
				os.write_file(full, v) or { failures << 'cannot write ${full}: ${err}'; return failures }
			}
		}
		defer { for p in cleanup_paths { os.rmdir_all(p) or {} } }
	}

	// ── out_text (CXL evaluation) ────────────────────────────────────────────
	// Driven by an `in_cxl` + `in_cx` pair: the CXL program is evaluated
	// against the CX input and the byte-exact output is compared against
	// `out_text`. The program's own `[?cx output-target=…]` directive
	// selects the target; the runner does not override it.
	if exp := t.sections['out_text'] {
		if has_cxl && has_cx {
			got := cxlib.eval_cxl(in_cx, in_cxl, '') or {
				failures << 'eval_cxl error: ${err}'
				return failures
			}
			if exp != got {
				failures << 'out_text mismatch\n  expected:\n${exp}\n  got:\n${got}'
			}
		} else {
			failures << 'out_text requires in_cxl + in_cx sections'
		}
	}

	// ── out_log (CXL log: emit capture) ──────────────────────────────────────
	// The runner injects a per-fixture `[?cx log-output=file:<tmp>]` +
	// `[?cx test-mode=true]` prelude so log:* emissions land at a known
	// path with stubbed timestamps. After `eval_cxl` returns, the runner
	// reads the temp file and compares it byte-identically against the
	// `out_log` section. Used for FF10 `log:` byte-identity fixtures.
	if exp := t.sections['out_log'] {
		if has_cxl && has_cx {
			tmp := os.join_path(os.temp_dir(), 'cx_conform_log_${os.getpid()}_${t.name.replace('/', '_')}.log')
			os.rm(tmp) or {}
			full := '[?cx log-output=file:${tmp}]\n[?cx test-mode=true]\n${in_cxl}'
			_ := cxlib.eval_cxl(in_cx, full, '') or {
				failures << 'eval_cxl error (out_log): ${err}'
				os.rm(tmp) or {}
				return failures
			}
			got := os.read_file(tmp) or { '' }
			os.rm(tmp) or {}
			// Strip leading/trailing blank lines to mirror parse_suite
			// section-body normalization (sections drop their own blanks
			// when read; the on-disk log file has a trailing newline that
			// we mirror by trimming \n on both sides).
			got_norm := got.trim('\n')
			if exp != got_norm {
				failures << 'out_log mismatch\n  expected:\n${exp}\n  got:\n${got_norm}'
			}
		} else {
			failures << 'out_log requires in_cxl + in_cx sections'
		}
	}

	// ── out_err (CXL evaluation error path OR CX parse error path) ───────
	// Either `eval_cxl` (when in_cxl + in_cx) must fail, or `to_cx`
	// (when only in_cx is present) must fail; the substring in `out_err`
	// must appear in the returned error message.
	if exp := t.sections['out_err'] {
		if has_cxl && has_cx {
			_ := cxlib.eval_cxl(in_cx, in_cxl, '') or {
				if !err.msg().contains(exp.trim_space()) {
					failures << 'out_err mismatch\n  expected substring: ${exp.trim_space()}\n  got: ${err.msg()}'
				}
				return failures
			}
			failures << 'out_err: expected failure containing ${exp.trim_space()}, got success'
		} else if has_cx {
			// Pure-parse error path: to_cx (or to_cx_with_include_root
			// when include_root section present) must fail. v0.7.0 GG12
			// + GG5 surface error codes this way.
			if use_include_resolver {
				_ := cxlib.to_cx_with_include_root(in_cx, include_root_dir) or {
					if !err.msg().contains(exp.trim_space()) {
						failures << 'out_err mismatch\n  expected substring: ${exp.trim_space()}\n  got: ${err.msg()}'
					}
					return failures
				}
				failures << 'out_err: expected to_cx_with_include_root failure containing ${exp.trim_space()}, got success'
			} else {
				_ := cxlib.to_cx(in_cx) or {
					if !err.msg().contains(exp.trim_space()) {
						failures << 'out_err mismatch\n  expected substring: ${exp.trim_space()}\n  got: ${err.msg()}'
					}
					return failures
				}
				failures << 'out_err: expected to_cx failure containing ${exp.trim_space()}, got success'
			}
		} else {
			failures << 'out_err requires in_cxl + in_cx sections OR an in_cx section'
		}
	}

	// ── out_ast ───────────────────────────────────────────────────────────────
	if exp := t.sections['out_ast'] {
		mut got := ''
		if has_xml {
			got = cxlib.xml_to_ast(in_xml) or { failures << 'xml_to_ast error: ${err}'; return failures }
		} else {
			got = cxlib.to_ast(in_cx) or { failures << 'to_ast error: ${err}'; return failures }
		}
		if !json_equal(exp, got) {
			failures << 'out_ast mismatch\n  expected: ${exp}\n  got:      ${got}'
		}
	}

	// ── out_cx ────────────────────────────────────────────────────────────────
	if exp := t.sections['out_cx'] {
		mut got := ''
		if has_xml {
			got = cxlib.xml_to_cx(in_xml) or { failures << 'xml_to_cx error: ${err}'; return failures }
		} else if has_md {
			got = cxlib.md_to_cx(in_md) or { failures << 'md_to_cx error: ${err}'; return failures }
		} else if use_include_resolver {
			got = cxlib.to_cx_with_include_root(in_cx, include_root_dir) or {
				failures << 'to_cx_with_include_root error: ${err}'; return failures
			}
		} else {
			got = cxlib.to_cx(in_cx) or { failures << 'to_cx error: ${err}'; return failures }
		}
		if exp.trim_space() != got.trim_space() {
			failures << 'out_cx mismatch\n  expected:\n${exp}\n  got:\n${got}'
		}
	}

	// ── out_xml ───────────────────────────────────────────────────────────────
	if exp := t.sections['out_xml'] {
		mut got := ''
		if has_xml {
			got = cxlib.xml_to_xml(in_xml) or { failures << 'xml_to_xml error: ${err}'; return failures }
		} else {
			got = cxlib.to_xml(in_cx) or { failures << 'to_xml error: ${err}'; return failures }
		}
		if exp.trim_space() != got.trim_space() {
			failures << 'out_xml mismatch\n  expected:\n${exp}\n  got:\n${got}'
		}
	}

	// ── out_json ──────────────────────────────────────────────────────────────
	if exp := t.sections['out_json'] {
		mut got := ''
		if has_xml {
			got = cxlib.xml_to_json(in_xml) or { failures << 'xml_to_json error: ${err}'; return failures }
		} else {
			got = cxlib.to_json(in_cx) or { failures << 'to_json error: ${err}'; return failures }
		}
		if !json_equal(exp, got) {
			failures << 'out_json mismatch\n  expected: ${exp}\n  got:      ${got}'
		}
	}

	// ── out_md ────────────────────────────────────────────────────────────────
	if exp := t.sections['out_md'] {
		mut got := ''
		if has_md {
			got = cxlib.md_to_md(in_md) or { failures << 'md_to_md error: ${err}'; return failures }
		} else {
			got = cxlib.to_md(in_cx) or { failures << 'to_md error: ${err}'; return failures }
		}
		if exp.trim_space() != got.trim_space() {
			failures << 'out_md mismatch\n  expected:\n${exp}\n  got:\n${got}'
		}
	}

	return failures
}

fn run_suite(path string) bool {
	tests := parse_suite(path)
	mut pass := 0
	mut fail := 0
	for t in tests {
		failures := run_test(t)
		if failures.len == 0 {
			pass++
		} else {
			fail++
			println('FAIL  ${t.name}')
			for f in failures {
				println('      ${f}')
			}
		}
	}
	println('${path}: ${pass} passed, ${fail} failed')
	return fail == 0
}

fn main() {
	args := os.args[1..]
	suites := if args.len > 0 {
		args
	} else {
		[
			os.join_path(repo_root, 'conformance', 'core.txt'),
			os.join_path(repo_root, 'conformance', 'extended.txt'),
			os.join_path(repo_root, 'conformance', 'xml.txt'),
			os.join_path(repo_root, 'conformance', 'md.txt'),
			os.join_path(repo_root, 'conformance', 'eval.txt'),
			os.join_path(repo_root, 'conformance', 'cx_module.txt'),
			os.join_path(repo_root, 'conformance', 'log_module.txt'),
			os.join_path(repo_root, 'conformance', 'cx_lang.txt'),
			os.join_path(repo_root, 'conformance', 'include.txt'),
		]
	}
	mut all_pass := true
	for suite in suites {
		if !run_suite(suite) {
			all_pass = false
		}
	}
	if !all_pass {
		exit(1)
	}
}

// ── JSON equality (whitespace-insensitive structural compare) ─────────────────

fn json_equal(a string, b string) bool {
	va := parse_json_val(a.trim_space())
	vb := parse_json_val(b.trim_space())
	return json_vals_equal(va, vb)
}

type JVal = JNull | bool | f64 | string | []JVal | map[string]JVal

struct JNull {}

fn json_vals_equal(a JVal, b JVal) bool {
	return match a {
		JNull  { b is JNull }
		bool   { b is bool && (a as bool) == (b as bool) }
		f64    { b is f64 && (a as f64) == (b as f64) }
		string { b is string && (a as string) == (b as string) }
		[]JVal {
			if b !is []JVal { return false }
			aa := a as []JVal
			ba := b as []JVal
			if aa.len != ba.len { return false }
			for i in 0 .. aa.len {
				if !json_vals_equal(aa[i], ba[i]) { return false }
			}
			true
		}
		map[string]JVal {
			if b !is map[string]JVal { return false }
			am := a as map[string]JVal
			bm := b as map[string]JVal
			if am.len != bm.len { return false }
			for k, v in am {
				bv := bm[k] or { return false }
				if !json_vals_equal(v, bv) { return false }
			}
			true
		}
	}
}

struct JsonReader {
mut:
	src []u8
	pos int
}

fn parse_json_val(src string) JVal {
	mut r := JsonReader{ src: src.bytes(), pos: 0 }
	return r.read_val()
}

fn json_is_ws(b u8) bool {
	return b == ` ` || b == `\t` || b == `\n` || b == `\r`
}

fn (mut r JsonReader) skip_ws() {
	for r.pos < r.src.len && json_is_ws(r.src[r.pos]) {
		r.pos++
	}
}

fn (mut r JsonReader) peek() u8 {
	if r.pos < r.src.len { return r.src[r.pos] }
	return 0
}

fn (mut r JsonReader) read_val() JVal {
	r.skip_ws()
	if r.pos >= r.src.len { return JVal(JNull{}) }
	b := r.peek()
	return match b {
		`"` { r.read_str() }
		`{` { r.read_obj() }
		`[` { r.read_arr() }
		`t` { r.pos += 4; JVal(true) }
		`f` { r.pos += 5; JVal(false) }
		`n` { r.pos += 4; JVal(JNull{}) }
		else { r.read_num() }
	}
}

fn (mut r JsonReader) read_str() JVal {
	r.pos++ // '"'
	mut s := []u8{}
	for r.pos < r.src.len {
		b := r.src[r.pos]
		if b == `"` { r.pos++; break }
		if b == `\\` {
			r.pos++
			if r.pos < r.src.len {
				esc := r.src[r.pos]
				r.pos++
				match esc {
					`n`  { s << `\n` }
					`r`  { s << `\r` }
					`t`  { s << `\t` }
					`"`  { s << `"` }
					`\\` { s << `\\` }
					else { s << `\\`; s << esc }
				}
			}
		} else {
			s << b
			r.pos++
		}
	}
	return JVal(s.bytestr())
}

fn (mut r JsonReader) read_obj() JVal {
	r.pos++ // '{'
	mut obj := map[string]JVal{}
	r.skip_ws()
	if r.pos < r.src.len && r.peek() == `}` { r.pos++; return JVal(obj) }
	for r.pos < r.src.len {
		r.skip_ws()
		key_val := r.read_val()
		key := if key_val is string { key_val as string } else { '' }
		r.skip_ws()
		if r.peek() == `:` { r.pos++ }
		val := r.read_val()
		obj[key] = val
		r.skip_ws()
		if r.peek() == `,` { r.pos++; continue }
		if r.peek() == `}` { r.pos++; break }
		break
	}
	return JVal(obj)
}

fn (mut r JsonReader) read_arr() JVal {
	r.pos++ // '['
	mut arr := []JVal{}
	r.skip_ws()
	if r.pos < r.src.len && r.peek() == `]` { r.pos++; return JVal(arr) }
	for r.pos < r.src.len {
		val := r.read_val()
		arr << val
		r.skip_ws()
		if r.peek() == `,` { r.pos++; continue }
		if r.peek() == `]` { r.pos++; break }
		break
	}
	return JVal(arr)
}

fn (mut r JsonReader) read_num() JVal {
	mut s := []u8{}
	for r.pos < r.src.len {
		b := r.src[r.pos]
		if b == `,` || b == `}` || b == `]` || json_is_ws(b) { break }
		s << b
		r.pos++
	}
	num_str := s.bytestr()
	if num_str == 'null'  { return JVal(JNull{}) }
	if num_str == 'true'  { return JVal(true) }
	if num_str == 'false' { return JVal(false) }
	fv := num_str.f64()
	if fv != 0.0 || num_str == '0' || num_str == '0.0' {
		return JVal(fv)
	}
	return JVal(f64(0))
}
