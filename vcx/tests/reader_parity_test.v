module main

import code
import platform as _
import cx
import fixtures
import crypto.sha1
import os

// reader_parity_test — ONE READER (RULED: CXF-5, #1521, epic #1522).
//
// CX has three doors into the same bytes:
//   (1) the DATA parser  — `cx.parse` / `cx.parse_cx` (vcx/cx/parser.v), which
//       the V fixture grader reaches through `vcx/fixtures/fixture_loader.v`
//       and which libcx's C ABI (`vcx/cx/cabi.v` `cx_to_ast_bin`) exports;
//   (2) the PYTHON binding — `cxlib.load_fixtures` (lang/python/cxlib/
//       fixtures.py) → `cxlib.parse` → `cx_to_ast_bin`, i.e. door (1) THROUGH
//       the shipped library rather than through this build's V modules;
//   (3) the PROGRAM reader — `cx.parse_program` (vcx/cx/program_parser.v +
//       program_lexer.v), which `cx FILE` and the grader's `in_code` lane use.
//
// #1521 measured them disagreeing on one shape: `[title a pattern's captures
// join the group binder list in pattern source order, left to right, depth
// first]` — an apostrophe INSIDE a word, a comma later on the line. Door (1)
// opened quoted text at the apostrophe and swallowed the three `[case]`
// siblings that followed; door (3) refused the same bytes with a DIFFERENT
// diagnostic at a different position; and the only step that noticed anything
// was the Python fixture-loader smoke's case count. A silent wrong answer is
// the one outcome the refuse-to-lie posture forbids.
//
// This step is the standing form of "or a parity step in TEST_TARGETS fails
// the build naming the file and the first divergence":
//
//   test_case_id_parity_every_corpus_file
//       Every `[case id=…]` marker the FILE carries is a case the data reader
//       answers. A swallow drops ids; a run-away quote duplicates none — so
//       the marker census is the ground truth, and the first missing id names
//       the divergence.
//   test_python_reader_agrees_case_for_case
//       Door (2) against door (1), file by file: the same id list AND the same
//       reconstructed sections (a per-case digest over the section keys in
//       document order and their bodies). Skipped, loudly, when no python3 or
//       no built libcx is present — the same preconditions `make test-python`
//       sets.
//   test_program_reader_agrees_on_bare_prose_titles
//       Door (3) against door (1) on the `[title …]` elements of the whole
//       corpus — bare-prose titles only (no nested bracket, hole or entity,
//       which are the deliberate data/program forks the cxparse differential
//       already catalogues). Both doors must accept, and their canonical
//       renders must be byte-identical.
//
// Deliberately NOT a second copy of `cxparse_full_corpus_diff_test.v`: that
// census diffs doors (1) and (3) over the `in_cx` SECTIONS of the corpus and
// locks bucket counts. This one reads the corpus FILES themselves — the
// position #1521's defect lived in, which no step read.

fn repo_root() string {
	return os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
}

fn conformance_dir() string {
	return os.join_path(repo_root(), 'conformance')
}

// corpus_files — every `.cxd` under conformance/ (recursive) plus the
// playground corpus, sorted, repo-relative.
fn corpus_files() []string {
	root := repo_root()
	mut out := []string{}
	mut stack := [conformance_dir()]
	for stack.len > 0 {
		dir := stack.pop()
		entries := os.ls(dir) or { continue }
		for e in entries {
			p := os.join_path(dir, e)
			if os.is_dir(p) {
				stack << p
				continue
			}
			if e.ends_with('.cxd') {
				out << p.replace(root + '/', '')
			}
		}
	}
	for p in ['scripts/gen_guide/playground/examples.cxd',
		'scripts/gen_guide/playground/examples.out.cxd'] {
		if os.exists(os.join_path(root, p)) {
			out << p
		}
	}
	out.sort()
	return out
}

// marker_case_ids — the `[case id=…]` ids the FILE carries, read as text and
// outside every `[# … #]` raw span (a raw payload may quote a fixture's own
// `[case id=` line; that one is content, not a case). Mirrors the census the
// Python smoke derives (`lang/python/test_fixture_loader.py`: a line whose
// leading non-blank bytes are `[case id=`) and adds the id itself, so a
// divergence can be NAMED instead of counted.
fn marker_case_ids(src string) []string {
	mut ids := []string{}
	mut i := 0
	mut line_start := true
	for i < src.len {
		// A raw span is consumed whole — `[#` … `#]`.
		if src[i] == `[` && i + 1 < src.len && src[i + 1] == `#` {
			mut j := i + 2
			for j + 1 < src.len && !(src[j] == `#` && src[j + 1] == `]`) {
				j++
			}
			i = if j + 1 < src.len { j + 2 } else { src.len }
			line_start = false
			continue
		}
		if src[i] == `\n` {
			line_start = true
			i++
			continue
		}
		if line_start && (src[i] == ` ` || src[i] == `\t`) {
			i++
			continue
		}
		if line_start && src.len - i >= 9 && src[i..i + 9] == '[case id=' {
			mut j := i + 9
			for j < src.len && src[j] != ` ` && src[j] != `\t` && src[j] != `]`
				&& src[j] != `\n` {
				j++
			}
			ids << src[i + 9..j]
			i = j
			line_start = false
			continue
		}
		line_start = false
		i++
	}
	return ids
}

// reader_case_ids — the ids door (1) answers for the same file.
fn reader_case_ids(path string) []string {
	mut ids := []string{}
	for c in fixtures.load_fixtures(path) {
		ids << c.name.all_before(' ')
	}
	return ids
}

// first_divergence names the first index at which two id lists differ, in the
// terms a reader of the failure needs: what the file says and what the reader
// answered.
fn first_divergence(want []string, got []string) string {
	mut n := want.len
	if got.len < n {
		n = got.len
	}
	for i in 0 .. n {
		if want[i] != got[i] {
			return 'at case ${i + 1}: file says `${want[i]}`, reader answered `${got[i]}`'
		}
	}
	if want.len > got.len {
		return 'reader stopped after ${got.len} cases; the file\'s next case id is `${want[n]}`'
	}
	if got.len > want.len {
		return 'reader answered ${got.len} cases; the file carries ${want.len} — first extra `${got[n]}`'
	}
	return 'no divergence'
}

fn test_case_id_parity_every_corpus_file() {
	root := repo_root()
	files := corpus_files()
	assert files.len > 0, 'reader-parity: no corpus files found under ${conformance_dir()} — refusing to vouch'
	mut checked := 0
	for rel in files {
		path := os.join_path(root, rel)
		src := os.read_file(path) or {
			assert false, 'reader-parity: cannot read ${rel}: ${err}'
			continue
		}
		want := marker_case_ids(src)
		if want.len == 0 {
			continue
		}
		// Ask the data reader for the WHOLE file first. `load_fixtures` panics
		// on a parse error, and a panic names the loader, not the document — a
		// swallow that runs to EOF (the #1521 shape when no later quote closes
		// the region) surfaces as `stray ']' with no matching '['` at the last
		// line of the file, which says nothing about where it began. Reading
		// here turns that into the file's own name plus the reader's message.
		cx.parse_cx(src) or {
			assert false, 'reader-parity: ${rel} — the data reader (cx.parse_cx) REFUSES the corpus file: ${err.msg()} (RULED: CXF-5, #1521)'
			continue
		}
		got := reader_case_ids(path)
		assert want == got, 'reader-parity: ${rel} — the data reader (cx.parse_cx) and the file disagree:\n' +
			'  ${first_divergence(want, got)}\n' +
			'  file markers=${want.len} reader cases=${got.len}\n' +
			'  every `[case id=…]` the file carries must be a case the reader answers (RULED: CXF-5, #1521).'
		checked++
	}
	assert checked > 0, 'reader-parity: no corpus file carried a `[case id=` marker — refusing to vouch'
}

// case_digest — the reconstructed case as a loader-independent string: the
// section keys in document order, then every key and its body. Both loaders
// document themselves as the same reconstruction, so this is the element tree
// each one answers for the case, in the shape both can spell.
fn case_digest(order []string, sections map[string]string) string {
	mut parts := []string{}
	parts << order.join(',')
	mut keys := sections.keys()
	keys.sort()
	for k in keys {
		parts << '${k}=${sections[k]}'
	}
	return sha1.hexhash(parts.join('\x00'))
}

fn python_bin() string {
	for cand in ['python3', 'python'] {
		r := os.execute('${cand} -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)"')
		if r.exit_code == 0 {
			return cand
		}
	}
	return ''
}

fn libcx_dir() string {
	d := os.join_path(repo_root(), 'vcx', 'target')
	for name in ['libcx.dylib', 'libcx.so', 'cx.dll'] {
		if os.exists(os.join_path(d, name)) {
			return d
		}
	}
	return ''
}

fn test_python_reader_agrees_case_for_case() {
	root := repo_root()
	py := python_bin()
	libdir := libcx_dir()
	if py == '' || libdir == '' {
		// Same preconditions `make test-python` sets (LIBCX_LIB_DIR pinned to
		// the freshly-built libcx, a >= 3.10 interpreter). Say so out loud:
		// a silently-skipped parity door is how #1521 stayed open.
		eprintln('reader-parity: SKIPPED the python door — python3=${py != ""} libcx=${libdir != ""}')
		return
	}
	files := corpus_files()
	list := files.join('\n')
	list_file := os.join_path(os.temp_dir(), 'cx_reader_parity_files_${os.getpid()}.txt')
	os.write_file(list_file, list) or {
		assert false, 'reader-parity: cannot write the file list: ${err}'
		return
	}
	defer {
		os.rm(list_file) or {}
	}
	// The snippet drives the SHIPPED reader under test (cxlib.load_fixtures)
	// and prints one row per case: file, id, and the same digest inputs the V
	// side hashes. Nothing is computed here that the loader does not already
	// answer.
	snippet := 'import sys, os, hashlib\n' +
		'sys.path.insert(0, os.path.join(sys.argv[1], "lang", "python"))\n' +
		'import cxlib\n' +
		'for rel in open(sys.argv[2]).read().split("\\n"):\n' +
		'    if not rel: continue\n' +
		'    for c in cxlib.load_fixtures(os.path.join(sys.argv[1], rel)):\n' +
		'        parts = [",".join(c.order)] + ["%s=%s" % (k, c.sections[k]) for k in sorted(c.sections)]\n' +
		'        d = hashlib.sha1("\\x00".join(parts).encode("utf-8")).hexdigest()\n' +
		'        print("%s\\t%s\\t%s" % (rel, c.name.split(" ")[0], d))\n'
	snippet_file := os.join_path(os.temp_dir(), 'cx_reader_parity_${os.getpid()}.py')
	os.write_file(snippet_file, snippet) or {
		assert false, 'reader-parity: cannot write the loader driver: ${err}'
		return
	}
	defer {
		os.rm(snippet_file) or {}
	}
	res := os.execute('LIBCX_LIB_DIR=${libdir} ${py} ${snippet_file} ${root} ${list_file} 2>&1')
	assert res.exit_code == 0, 'reader-parity: the python door (cxlib.load_fixtures) failed:\n${res.output}'
	mut py_rows := map[string]string{}
	mut py_ids := map[string][]string{}
	for line in res.output.split('\n') {
		if line.trim_space() == '' {
			continue
		}
		f := line.split('\t')
		if f.len != 3 {
			continue
		}
		py_rows['${f[0]}\t${f[1]}'] = f[2]
		py_ids[f[0]] << f[1]
	}
	assert py_rows.len > 0, 'reader-parity: the python door answered no cases — refusing to vouch'
	for rel in files {
		path := os.join_path(root, rel)
		v_cases := fixtures.load_fixtures(path)
		if v_cases.len == 0 && py_ids[rel].len == 0 {
			continue
		}
		mut v_ids := []string{}
		for c in v_cases {
			v_ids << c.name.all_before(' ')
		}
		assert v_ids == py_ids[rel], 'reader-parity: ${rel} — the V data reader and the python binding (libcx) disagree:\n' +
			'  ${first_divergence(v_ids, py_ids[rel])}\n' +
			'  V cases=${v_ids.len} python cases=${py_ids[rel].len} (RULED: CXF-5, #1521).'
		for c in v_cases {
			id := c.name.all_before(' ')
			v_digest := case_digest(c.order, c.sections)
			p_digest := py_rows['${rel}\t${id}'] or { '' }
			assert v_digest == p_digest, 'reader-parity: ${rel} — case `${id}` reconstructs differently:\n' +
				'  V digest=${v_digest} python digest=${p_digest}\n' +
				'  the two doors must answer the same element tree for the same bytes (RULED: CXF-5, #1521).'
		}
	}
}

// bare_prose_title_lines — every `[title …]` line of a corpus file whose body
// is PLAIN ASCII PROSE: letters, digits, spaces, `'` and `-`, and nothing else.
// That is the population with exactly one right answer today, and it is the
// class #1521's apostrophe lives in (`the pattern's own source order`).
//
// Everything outside the class is left to the census or to a filed issue:
//   • `[` `]` `$` `&` `#` `"` — nested nodes, holes, entity refs, raw spans and
//     quoted runs: the deliberate data/program forks
//     `cxparse_full_corpus_diff_test.v` catalogues;
//   • `,` — a §9 [L25c] comma element body is an ArrayNode to the data reader and
//     a parse REFUSAL to the program reader, for every comma body in the corpus
//     and not only for these: measured and filed as #1541. #1521's own title
//     shape carries commas and is graded by the case-id step above, which is the
//     step its defect shows up in;
//   • `.` and `:` — the program lexer's GLUED-RESIDUE run (#935 / #1384) makes
//     `world.` / `ab:c` one `.bare_value`, which reads as a string SCALAR and so
//     blocks the §9 [L25b] prose join the data reading performs: the same defect
//     class as #1521 in a different input, measured and filed as #1538;
//   • non-ASCII — an em dash is not a name character to the program lexer, which
//     refuses the byte while the data reading carries it as prose (the census's
//     `cx_only` bucket).
//
// Each exclusion goes when its issue does, and the class widens with it.
fn bare_prose_title_lines(src string) []string {
	mut out := []string{}
	for line in src.split('\n') {
		t := line.trim_space()
		if !t.starts_with('[title ') || !t.ends_with(']') {
			continue
		}
		body := t[7..t.len - 1]
		if body.trim_space() == '' {
			continue
		}
		mut plain := true
		for b in body.bytes() {
			ok := (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`)
				|| (b >= `0` && b <= `9`) || b == ` ` || b == `'` || b == `-`
			if !ok {
				plain = false
				break
			}
		}
		if !plain {
			continue
		}
		// A token-INITIAL `-` is the program reading's minus / operator head
		// (`[- $a $b]`, the `program-ophead-*` family the census catalogues), so
		// `outside --strict a parameter …` refuses there while the data reading
		// carries it as prose. A `-` INSIDE a word (`well-known`) is an ordinary
		// name character to both and stays in the class.
		if body.starts_with('-') || body.contains(' -') {
			continue
		}
		out << t
	}
	return out
}

fn data_render(src string) string {
	doc := cx.parse(src) or { return 'REJECT: ${err.msg()}' }
	if doc.elements.len != 1 {
		return 'MULTI'
	}
	return code.render_canonical(doc.elements[0])
}

fn program_render(src string) string {
	n := code.program_parse_to_typed_node(src) or { return 'REJECT: ${err.msg()}' }
	return code.render_canonical(n)
}

fn test_program_reader_agrees_on_bare_prose_titles() {
	root := repo_root()
	mut checked := 0
	// Every divergence is collected before the verdict, and the report names the
	// FIRST one in full plus the count. A step that aborted on the first row said
	// nothing about how wide the class was, and each widening cost a whole run.
	mut bad := []string{}
	for rel in corpus_files() {
		src := os.read_file(os.join_path(root, rel)) or { continue }
		for t in bare_prose_title_lines(src) {
			checked++
			a := data_render(t)
			b := program_render(t)
			if a == b {
				continue
			}
			bad << 'reader-parity: ${rel} — the data reader and the program reader answer DIFFERENT trees for one bare-prose title:\n' +
				'  src : ${t}\n' +
				'  data: ${a}\n' +
				'  prog: ${b}'
		}
	}
	assert checked > 0, 'reader-parity: no bare-prose `[title …]` line found in the corpus — refusing to vouch'
	assert bad.len == 0, '${bad[0]}\n  ${bad.len} of ${checked} bare-prose titles diverge; every entry point answers the same element tree for the same bytes (RULED: CXF-5, #1521).'
}
