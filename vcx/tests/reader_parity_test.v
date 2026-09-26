module main

import code
import xap as _
import cx
import fixtures
import crypto.sha1
import os

// reader_parity_test — ONE READER (RULED: CXF-5, #1521, epic #1522;
// RULED: RUN-2, RS-12, RS-8 for the python door's retirement below).
//
// CX has three doors into the same bytes, of which THIS FILE grades two:
//   (1) the DATA parser  — `cx.parse` / `cx.parse_cx` (vcx/cx/parser.v), which
//       the V fixture grader reaches through `vcx/fixtures/fixture_loader.v`
//       and which libcx's C ABI (`vcx/cx/cabi.v` `cx_to_ast_bin`) exports;
//   (2) the PYTHON binding — `cxlib.load_fixtures`. RETIRED FROM THIS FILE
//       (RULED: RS-12, RS-8; #1591 item K3): the python binding left
//       cx-private whole as cx-home/cx-binding-python, so `lang/python/`
//       is gone from this tree and there is no in-tree door (2) to open any
//       more. A prior fix here tried to detect that and skip loudly, but an
//       installed `cxlib` elsewhere on the runner's Python path (not this
//       tree's, which left) still satisfied `import cxlib` and the test read
//       its `AttributeError` as a real disagreement rather than a missing
//       door — so `test_python_reader_agrees_case_for_case` and its
//       `python_bin`/`libcx_dir`/`python_door_present` helpers are gone, not
//       skipped. Door (1) vs. door (2) parity is now
//       cx-home/cx-binding-python's own concern to prove against its pinned
//       cx-private checkout, until D75 (open) rules on a cross-repo successor;
//   (3) the PROGRAM reader — `cx.parse_program` (vcx/cx/program_parser.v +
//       program_lexer.v), which `cx FILE` and the grader's `in_code` lane use.
//
// #1521 measured doors (1) and (3) disagreeing on one shape: `[title a
// pattern's captures join the group binder list in pattern source order,
// left to right, depth first]` — an apostrophe INSIDE a word, a comma later
// on the line. Door (1) opened quoted text at the apostrophe and swallowed
// the three `[case]` siblings that followed; door (3) refused the same bytes
// with a DIFFERENT diagnostic at a different position; and the only step
// that noticed anything at the time was the Python fixture-loader smoke's
// case count (also gone with the binding, above). A silent wrong answer is
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

// pinned_conformance_dir — the data-language suites left this tree for
// cx-core-data (RULED: RS-7, RS-12) and are read from its pinned checkout, so
// the readers are held to parity over them exactly as before. A tree without the
// pin is a failure here, never a smaller population.
fn pinned_conformance_dir() string {
	return os.join_path(repo_root(), 'deps', 'cx-core-data', 'conformance')
}

// corpus_files — every `.cxd` under conformance/ (recursive) plus the
// playground corpus, sorted, repo-relative.
fn corpus_files() []string {
	root := repo_root()
	mut out := []string{}
	assert os.is_dir(pinned_conformance_dir()), '${pinned_conformance_dir()} is not there -- run `make deps-sync`'
	mut stack := [conformance_dir(), pinned_conformance_dir()]
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
				rel := p.replace(root + '/', '')
				// A pinned suite this tree still carries under the same path is read
				// from this tree's copy (the files the allocation assigns and this tree
				// has not released yet); the pinned copy is not a second population.
				pinned_prefix := 'deps/cx-core-data/'
				if rel.starts_with(pinned_prefix)
					&& os.exists(os.join_path(root, rel.all_after(pinned_prefix))) {
					continue
				}
				out << rel
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

// bare_prose_title_lines — every `[title …]` line of a corpus file whose body
// is PLAIN ASCII PROSE: letters, digits, spaces, `'`, `-`, and — since #1538
// closed the glued-residue half of the same rule and #1541 gave the program
// reader §9 [L25c]'s comma body — `.`, `:` and `,`, and nothing else. That is the population with exactly one right answer today, and it is
// the class #1521's apostrophe lives in (`the pattern's own source order`).
//
// The `.`/`:` widening IS #1538's evidence: `world.` and `ab:c` are one
// `.bare_value` run whose KIND used to be the quoted case, so the §9 [L25b]
// prose join declined and the body came back as N discrete items. Every title
// in the corpus carrying a sentence-final period, a dotted run or a glued
// QName is graded here now.
//
// Everything outside the class is left to the census or to a filed issue:
//   • `[` `]` `$` `&` `#` `"` — nested nodes, holes, entity refs, raw spans and
//     quoted runs: the deliberate data/program forks
//     `cxparse_full_corpus_diff_test.v` catalogues;
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
				|| b == `.` || b == `:` || b == `,`
			if !ok {
				plain = false
				break
			}
		}
		if !plain {
			continue
		}
		// RULED: 1563-a (#1563) — a glued `::` inside a comma-less body §9
		// [L25b] has classified as bare prose is PROSE, so the `::` exclusion
		// is GONE and those titles are graded here now. What remains excluded
		// is an ATOM-leading run (`:ok::atom`): a `:` at a token start opens an
		// atom, which is self-delimiting, so [L25b]'s join declines and the
		// program reading answers discrete items where the data reading
		// answers one run. That is the position-driven entry 1559-a rules and
		// its own branch carries; the exclusion cites it and goes with it.
		if body.contains(' :') || body.starts_with(':') {
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

// ── the THIRD column: accepted-by-one (RULED: 1548-c, #1548) ────────────────
//
// The two columns above grade bytes BOTH readers accept. They have nothing to
// say about the bytes only one reader accepts, which is exactly where the two
// readings drift apart unnoticed — the class that made `cx lint` answer 0 on a
// document `cx FILE` refuses (#1546), and the reason #1521 existed.
//
// The owner's letter (c) on #1548: the data ring's bare-prose reading and the
// code ring's strict tokenization are two grammars over one bracket syntax,
// and their divergence on such bytes is a STATED PROPERTY — named by this
// step and judged file by file. So every file one reader accepts and the other
// refuses is LISTED below with the refusing reader and why, and the step fails
// on an entry that is neither a filed issue nor a recorded, reasoned
// exception. An unexplained entry is a red; so is a STALE one, because a table
// nobody prunes stops being evidence.
//
// This is not the census in another spelling: `cxparse_full_corpus_diff_test`
// diffs the two readers over the `in_cx` SECTIONS of the corpus and locks
// bucket counts. This reads the FILES — the position a reader divergence
// actually reaches a writer from.

// AcceptedByOne is one file the readers disagree about ACCEPTING.
struct AcceptedByOne {
	path   string // repo-relative
	by     Reader // the reader that ACCEPTS it
	reason string // a filed issue (`#1541 …`) or a recorded exception's reason
}

enum Reader {
	data
	program
}

fn (r Reader) str() string {
	return match r {
		.data { 'data' }
		.program { 'program' }
	}
}

// parity_scan_files — the population this column judges: every corpus and
// playground file the two columns above already read, plus every `.cx` under
// `scripts/`, `stdlib/` and `examples/` (RULED: 1548-c), which is where a
// program document a writer actually runs lives.
fn parity_scan_files() []string {
	root := repo_root()
	mut out := corpus_files()
	for dir in ['scripts', 'stdlib', 'examples'] {
		mut stack := [os.join_path(root, dir)]
		for stack.len > 0 {
			d := stack.pop()
			for e in os.ls(d) or { []string{} } {
				p := os.join_path(d, e)
				if os.is_dir(p) {
					if e != 'node_modules' {
						stack << p
					}
					continue
				}
				if e.ends_with('.cx') {
					out << p.replace(root + '/', '')
				}
			}
		}
	}
	out.sort()
	return out
}

// accepted_by_one_scan classifies the population: for every file, does the
// data reader accept it, does the program reader, and when exactly one does,
// what did the other say. `.cxd` corpus files the program reader refuses are
// the bulk and are reasoned by CLASS below, not one sentence per file.
fn accepted_by_one_scan() ([]AcceptedByOne, map[string]string) {
	root := repo_root()
	mut rows := []AcceptedByOne{}
	mut refusals := map[string]string{}
	for rel in parity_scan_files() {
		src := os.read_file(os.join_path(root, rel)) or { continue }
		mut data_ok := true
		mut data_msg := ''
		cx.parse_cx(src) or {
			data_ok = false
			data_msg = err.msg()
		}
		mut prog_ok := true
		mut prog_msg := ''
		cx.parse_program(src) or {
			prog_ok = false
			prog_msg = err.msg()
		}
		if data_ok == prog_ok {
			continue
		}
		if data_ok {
			rows << AcceptedByOne{
				path: rel
				by:   .data
			}
			refusals[rel] = prog_msg
		} else {
			rows << AcceptedByOne{
				path: rel
				by:   .program
			}
			refusals[rel] = data_msg
		}
	}
	return rows, refusals
}

// ── the reasons, one per class ──────────────────────────────────────────────
//
// A FILED ISSUE is named by number: the divergence is a defect and the step
// carries it until the fix moves the file into the graded population above.
// A RECORDED EXCEPTION states why the two readings are each their ring's own
// correct answer — 1548-c's own words: "the data ring's bare-prose reading and
// the code ring's strict tokenization are two grammars over one bracket
// syntax", and a program form the data grammar has no production for is not a
// defect of either.

const reason_1576 = "#1576 — a parenthetical `(…)` or a COMMA inside a body §9 [L25b] has classified as bare prose. The data reader answers ONE prose run; the program reader applies ASP-3's structure-token rule (a ws-delimited `(…)` is discrete) and [L25c]'s comma-array rule, both of which are written for bodies that carry NO bareword. Which rule wins when a bareword IS present is what [L25b] does not say. Split from #1559 by 1559-a's measurement."

const reason_1577 = "#1577 — a `[| … ]` BLOCK SPAN's content. The data reader carries it verbatim (ast.md's BlockContent); the program reader tokenizes inside it, so a `|` or a digit-led run in that content is read as program text — and in one of these the LEXER refuses before any parser could re-scan, which is why 1559-a's parser-driven span cannot reach it. Split from #1559."

const reason_1578 = "#1578 — a bare URL in an ATTRIBUTE VALUE. 1559-a narrowed 1384-a's `/` sentence so a bare URL in a BODY is prose in both rings, but an attribute value is an EXPRESSION position (1559-d) and #923/BC-1's attr-value run sends a `/`-bearing value whose prefix reads as a path head to the CXPath lane. Whether that lane should prefer the data reading's string is the one question 1559-a's row does not settle; the refusal is at least loud and carries its own fix. Split from #1559."

const reason_1579 = "#1579 — 1559-a's re-scan triggers on a parse REFUSAL, because a bareword head may be a CALL and that dispatch is decided at EVAL (a pre-emptive collapse destroyed cmd-030's arguments). These two prose bodies DO begin to parse — a leading `-`, a trailing `.` — and so reach a different tree instead of refusing, which means \"does it parse?\" is not by itself the discriminator the rule needs. Split from #1559."

const reason_l25c_residue = '#1541 residue, REASONED not pending — a nested `[`/`(`/`{` in one comma slot. There the data reading leaves the array lane entirely and the comma becomes literal PROSE (`[xs a, [b 1], \'c\']` → `[xs \'a, \' [b 1] \',\' \'c\']`, measured), which is the data ring\'s prose classifier and not a tree a tokenizing reader can answer. The program reader refuses it BY NAME instead of inventing a third reading.'

const reason_entity = 'RECORDED EXCEPTION (1548-c) — an `&Name;` entity reference is a DATA body form (grammar [66]). A program document has no entity lane and `&` in program position is not a reference opener, so the program reader\'s refusal is the code ring\'s own correct answer, not a divergence to close.'

const reason_ophead = 'RECORDED EXCEPTION (1548-c) — a token-initial `=` is an OPERATOR HEAD in program mode (the `program-ophead-*` family the cxparse census catalogues) and ordinary data content in the data ring. [L70a] excludes `=` from BareChar outright, so this one is the grammar agreeing with the fork.'

const reason_datalane = 'RECORDED EXCEPTION (1548-c) — a DATA-only lane the program grammar has no production for: a hex integer the data reader coerces per its own rule, the retired paren-call surface kept as DATA text, an element body the program reader closes differently because `=` and bare prose mean other things to it. The census (`cxparse_full_corpus_diff_test`) catalogues these as the data-only surface, which is what its `cx_only` bucket is named for.'

const reason_1536 = 'RECORDED EXCEPTION (1548-c), RULED: 1536-a — a call-shaped head (`[$mod:verb …]`) or a `$name` hole beside a ws-delimited `(…)`/`{…}` literal. These thirty-two entries STAY, and that is the decision working rather than failing: 1536-a fixed the TOOL, not the readers. `cx --ast` now arbitrates the two readings as `cx lint` has since #1546, so the four entry points answer one tree for one byte string; the data reader still refuses a call-shaped document, which RULED: TRAP-1 (#1529) states outright and [L83]-0 makes grammar ("`[$` call (program mode)"). So the divergence is the stated PROPERTY 1548-c exists to record, no longer an open issue — which is why the reason is an exception and names no pending work.'

const reason_attr = 'RECORDED EXCEPTION (1548-c) — a COMPUTED attribute `name=[EXPR]` is a program form (code.md §6): the value is evaluated at the call site. The data grammar\'s attributes are scalar-only by decision D2 (a node-valued attribute was GRADUATED out, 2026-06-03), so the data reader\'s E211 is the data ring stating its own rule, not a reader disagreeing with itself.'

const reason_prog = 'RECORDED EXCEPTION (1548-c) — a program document whose BRACKET structure the data balancer cannot read: a `[?const]` spanning the file, a `[= …]` binding clause, a `]` inside program source. The TRAP-1 class again — one ring\'s syntax handed to the other ring\'s balancer, which is what a `.cx` PROGRAM is.'

// accepted_by_one_table — the judged population (RULED: 1548-c). Grouped by
// the REASON each entry carries, because the reasons cluster and a per-file
// sentence seventy-five times over would be a table nobody reads. Adding a
// corpus file or a `.cx` the two readers disagree about REDS this step until
// the entry is here with a reason; removing the divergence reds it too, so a
// fix cannot leave a stale excuse behind — which is how #1538, #1541, #1550,
// #1559's fixed half and #1564 each proved themselves: eighty-six entries on
// 2026-09-18 morning, seventy-five after, and every departure forced by this
// judgement rather than asserted by a commit message.
const accepted_by_one_table = [
	// ── #1559 — an ASCII BareChar in prose the run does not admit (4) ──
	// 6 -> 4: conformance/code.cxd and conformance/stdlib/array.cxd left with
	// cx-core-code's extraction (RULED: RS-12, D68a); the scan walks conformance/
	// of THIS tree and does not follow deps/.
	AcceptedByOne{'deps/cx-core-data/conformance/lockfile.cxd', .data, reason_1576},
	AcceptedByOne{'deps/cx-core-data/conformance/yaml.cxd', .data, reason_1576},
	AcceptedByOne{'examples/article.cx', .data, reason_1579},
	AcceptedByOne{'examples/vcore.cx', .data, reason_1577},
	// ── #1559 — a bare URL's `://` (RULED: 1384-a keeps `/` out of the run) (3) ──
	AcceptedByOne{'examples/chapter.cx', .data, reason_1578},
	AcceptedByOne{'examples/post.cx', .data, reason_1578},
	// ── #1541 residue — a nested node in a comma slot (2; conformance/platform/
	//    store.cxd's own entry left with cx-platform-store's extraction (RULED:
	//    RS-12, RS-8; #1591 item K3) — this test's population walks conformance/
	//    and deps/cx-core-data/conformance/ only (pinned_conformance_dir(), RS-7),
	//    so the entry cannot be repointed at the pin the way a corpus grader's
	//    would be; it is simply gone from the population this step scans) ──
	AcceptedByOne{'examples/doc.cx', .data, reason_l25c_residue},
	// ── recorded exception — an `&Name;` entity reference (2) ──
	AcceptedByOne{'examples/cx-tour.cx', .data, reason_entity},
	AcceptedByOne{'examples/env.cx', .data, reason_entity},
	// ── recorded exception — a token-initial operator head (1) ──
	AcceptedByOne{'examples/logs.cx', .data, reason_ophead},
	// ── recorded exception — a DATA-only lane the program grammar has no form for (6) ──
	// 4 -> 6: the front door's two corpora (#1589 item 23, RULED: RS-7, RS-9) -- a
	// [title] of bare prose carrying a word the program reader takes as a keyword
	// (`module`, `shape`). The three data-language suites are read at cx-core-data's
	// pin (RULED: RS-12).
	// 6 -> 7: conformance/gates_register.cxd, D49a's derived-register corpus (RULED:
	// RS-27) -- the same class: a bare-prose [title] (`the suite element says …`)
	// the program reader does not read as text.
	// 7 -> 6: conformance/xml_codec.cxd left with cx-core-code's extraction
	// (RULED: RS-12, D68a); the scan walks conformance/ of THIS tree and does
	// not follow deps/.
	AcceptedByOne{'conformance/bundle_sources.cxd', .data, reason_datalane},
	AcceptedByOne{'deps/cx-core-data/conformance/conversions.cxd', .data, reason_datalane},
	AcceptedByOne{'conformance/docs_fragment.cxd', .data, reason_datalane},
	AcceptedByOne{'conformance/gates_register.cxd', .data, reason_datalane},
	AcceptedByOne{'deps/cx-core-data/conformance/fmt.cxd', .data, reason_datalane},
	AcceptedByOne{'deps/cx-core-data/conformance/xml.cxd', .data, reason_datalane},
	// ── #1536 — a call-shaped head beside a ws-delimited literal (22) ──
	// 33 -> 22: eleven of these were cx-platform-sso's and left with the
	// extraction (RULED: RS-12, #1591 item 11) -- the module, the four interop
	// programs' three judged files and the seven example programs. The scan
	// walks scripts/, stdlib/ and examples/ of THIS tree and does not follow
	// deps/, so the pinned checkout is not judged here: the repository that
	// owns those files judges its own reader parity, or nothing does, and
	// RESULTS.md says which. `examples/platform/together/sso-flow-xap/actor.cx`
	// stays -- it is cx's composition, not sso's.
	AcceptedByOne{'examples/platform/together/sso-flow-xap/actor.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_code_diagram_fixtures.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_code_fixtures.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_code_spec_consistency.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_completions_drift.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_no_adr_citations.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_no_cxl_token.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_null_absence_conflation.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_portable_links.cx', .program, reason_1536},
	AcceptedByOne{'scripts/check_xpath_parity_fixtures.cx', .program, reason_1536},
	AcceptedByOne{'scripts/compare_bench.cx', .program, reason_1536},
	AcceptedByOne{'scripts/compile_binding_api_fixtures.cx', .program, reason_1536},
	// 22 -> 23: scripts/deps_cx_selftest.cx, #1643's bootstrap self-test -- the
	// class's own shape, `[$process:run ("sh", "-c", $script)]` (RULED: RS-7).
	AcceptedByOne{'scripts/deps_cx_selftest.cx', .program, reason_1536},
	AcceptedByOne{'scripts/fmt_corpus_sweep.cx', .program, reason_1536},
	AcceptedByOne{'scripts/gate_lock_selftest.cx', .program, reason_1536},
	AcceptedByOne{'scripts/gen_docs/primer_build.cx', .program, reason_1536},
	// 21 -> 22: scripts/gen_site/site_build.cx, the cxhome.org landing-page
	// generator (RULED: RS-28, RS-30) -- the class's own shape,
	// `[$pb:cat-seqs ($acc, ($item,))]`, the same fold primer_build.cx above
	// folds with, whose functions it imports.
	AcceptedByOne{'scripts/gen_site/site_build.cx', .program, reason_1536},
	AcceptedByOne{'scripts/gen_guide/snippet_check.cx', .program, reason_1536},
	AcceptedByOne{'scripts/lang_stats.cx', .program, reason_1536},
	// 23 -> 24: #1670's scripts/release_asset_links_gate.cx, the same shape as
	// check_portable_links.cx above (`[$array:flatten (…)]`) -- the release
	// staging directory scan reuses its glob-then-flatten idiom verbatim.
	AcceptedByOne{'scripts/release_asset_links_gate.cx', .program, reason_1536},
	AcceptedByOne{'scripts/run_bench_json.cx', .program, reason_1536},
	// 21 -> 23: RS-33's K12 branch, scripts/check_no_ai_attribution.cx and
	// scripts/strip_attribution.cx -- the class's own shape,
	// `[$process:run ("git", "clone", "--mirror", $source, $mirror)]` and
	// `[$process:run ("git", "-C", $dir, ...)]`, same as deps_cx_selftest.cx
	// above (RULED: RS-33; fix(ff8ebdc35), CXF-8).
	// 23 -> 21: examples/platform/scim/projection/project.cx and
	// stdlib/supervise.cx left with cx-core-code's extraction (RULED: RS-12,
	// D68a); the scan walks examples/ and stdlib/ of THIS tree and does not
	// follow deps/.
	AcceptedByOne{'scripts/check_no_ai_attribution.cx', .program, reason_1536},
	AcceptedByOne{'scripts/strip_attribution.cx', .program, reason_1536},
	// ── recorded exception — a computed attribute `name=[EXPR]` (23) ──
	// 22 -> 21: scripts/sso_interop/idp.cx left with the sso extraction (RS-12).
	// 21 -> 22: scripts/check_migrate_namespace_fixtures.cx, RS-4's sweep grader.
	// 22 -> 26: the front door's bundled-source table, its tree check, and the two
	// graders (#1589 item 23, RULED: RS-7, RS-9).
	// 26 -> 27: scripts/product_import_gate.cx, RS-24's product-import gate.
	// 27 -> 25: stdlib/flow.cx and examples/platform/flow/checkout/orders.cx left with the flow extraction (RS-12).
	// 25 -> 27: the derived gate register's check and its tree driver (D49a,
	// RULED: RS-27).
	// 27 -> 26: stdlib/diagram.cx left with cx-tooling's extraction (RULED: RS-12,
	// D59a); the scan walks stdlib/ of THIS tree and does not follow deps/.
	// 26 -> 24: examples/platform/scim/projection/no-leak.cx and
	// examples/platform/scim/provisioning/provision.cx left with cx-core-code's
	// extraction (RULED: RS-12, D68a).
	// 22 -> 23: scripts/secrets_scan.cx, K13's secrets-scan gate (RULED: D59a,
	// RS-28, CXF-1) -- its hit-record's computed `line=[…]`/`match=[…]` attributes.
	AcceptedByOne{'examples/code-tour.cx', .program, reason_attr},
	AcceptedByOne{'examples/cxpath-tour.cx', .program, reason_attr},
	AcceptedByOne{'examples/match-multi.cx', .program, reason_attr},
	AcceptedByOne{'examples/modify-crud.cx', .program, reason_attr},
	AcceptedByOne{'scripts/bundle_check.cx', .program, reason_attr},
	AcceptedByOne{'scripts/bundle_sources.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_bundle_sources_fixtures.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_deps_pins_fixtures.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_docs_fragment_fixtures.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_lint_rules.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_migrate_namespace_fixtures.cx', .program, reason_attr},
	AcceptedByOne{'scripts/check_no_stub_impl.cx', .program, reason_attr},
	AcceptedByOne{'scripts/consolidate_tests.cx', .program, reason_attr},
	AcceptedByOne{'scripts/deps_pins.cx', .program, reason_attr},
	AcceptedByOne{'scripts/deps_sync.cx', .program, reason_attr},
	AcceptedByOne{'scripts/gates_register.cx', .program, reason_attr},
	AcceptedByOne{'scripts/gates_register_check.cx', .program, reason_attr},
	AcceptedByOne{'scripts/gen_guide/guide_build.cx', .program, reason_attr},
	AcceptedByOne{'scripts/gen_guide/playground/gen_examples.cx', .program, reason_attr},
	AcceptedByOne{'scripts/product_import_gate.cx', .program, reason_attr},
	AcceptedByOne{'scripts/repo_paths.cx', .program, reason_attr},
	AcceptedByOne{'scripts/ring_query.cx', .program, reason_attr},
	AcceptedByOne{'scripts/secrets_scan.cx', .program, reason_attr},
	// ── recorded exception — a program document the data balancer cannot read (9) ──
	// 8 -> 9: scripts/docs_fragment.cx, the RS-9 fragment contract (a `"#]"` literal).
	// 9 -> 8: scripts/flow_vocabulary_gate.cx left with the flow extraction (RS-12).
	// 8 -> 10: scripts/gate_on_suite_migrate.cx, D49a's migration (a `"]"` literal;
	// the heading read 8 over nine rows before it).
	// 10 -> 9: stdlib/connector.cx left with cx-platform-connector's extraction
	// (RULED: RS-12, RS-8, RS-27; #1591 item K3).
	AcceptedByOne{'scripts/bisect_batch.cx', .program, reason_prog},
	AcceptedByOne{'scripts/check_editor_surface_parity.cx', .program, reason_prog},
	AcceptedByOne{'scripts/diagnostics_census.cx', .program, reason_prog},
	AcceptedByOne{'scripts/docs_fragment.cx', .program, reason_prog},
	AcceptedByOne{'scripts/fuzz_cx.cx', .program, reason_prog},
	AcceptedByOne{'scripts/gate_on_suite_migrate.cx', .program, reason_prog},
	AcceptedByOne{'scripts/gen_docs/primer_platform.cx', .program, reason_prog},
	AcceptedByOne{'scripts/repos_allocation_gate.cx', .program, reason_prog},
	AcceptedByOne{'scripts/store_session_dep_gate.cx', .program, reason_prog},
]

// judge_accepted_by_one is the verdict, as a PURE function of the scan and the
// table, so the red-proof below can plant an entry without touching the tree:
// `unexplained` is every observed divergence the table does not carry (or
// carries with the other reader accepting), `stale` every table entry the scan
// no longer observes.
fn judge_accepted_by_one(observed []AcceptedByOne, table []AcceptedByOne) ([]string, []string) {
	mut declared := map[string]AcceptedByOne{}
	for d in table {
		declared[d.path] = d
	}
	mut seen := map[string]bool{}
	mut unexplained := []string{}
	for o in observed {
		seen[o.path] = true
		d := declared[o.path] or {
			unexplained << 'reader-parity accepted-by-one: ${o.path} — the ${o.by.str()} reader accepts it and the other REFUSES it, and the step carries no reason for that. Add it to accepted_by_one_table with a filed issue number or a recorded exception (RULED: 1548-c, #1548).'
			continue
		}
		if d.by != o.by {
			unexplained << 'reader-parity accepted-by-one: ${o.path} — the table says the ${d.by.str()} reader accepts it; the scan says the ${o.by.str()} reader does. The divergence changed sides, so its reason no longer describes it (RULED: 1548-c, #1548).'
		}
	}
	mut stale := []string{}
	for d in table {
		if d.path !in seen {
			stale << 'reader-parity accepted-by-one: ${d.path} — the table carries a reason for a divergence the readers NO LONGER have. Remove the entry with the fix that closed it; an excuse nobody prunes stops being evidence (RULED: 1548-c, #1548).'
		}
	}
	return unexplained, stale
}

fn test_accepted_by_one_is_named() {
	observed, refusals := accepted_by_one_scan()
	assert observed.len > 0, 'reader-parity accepted-by-one: the scan found no divergence at all across the corpus and every .cx under scripts/, stdlib/ and examples/ — refusing to vouch (the readers are not identical; a zero here means the scan broke)'
	unexplained, stale := judge_accepted_by_one(observed, accepted_by_one_table)
	if unexplained.len > 0 {
		first := unexplained[0]
		path := first.all_after('accepted-by-one: ').all_before(' —')
		msg := refusals[path] or { '' }
		assert false, '${first}\n  the refusing reader said: ${msg.all_before('\n')}\n  ${unexplained.len} unexplained of ${observed.len} observed.'
	}
	assert stale.len == 0, '${stale[0]}\n  ${stale.len} stale of ${accepted_by_one_table.len} declared.'
}

// The column's RED-PROOF (1548-c's fixture-first clause): a planted entry the
// table does not carry fails the judgement, and a planted table row the scan
// does not observe fails it too. Without this the column could be satisfied by
// a judgement that never says no.
fn test_accepted_by_one_red_proof() {
	planted := [
		AcceptedByOne{'conformance/nowhere-planted.cxd', .data, ''},
	]
	unexplained, _ := judge_accepted_by_one(planted, accepted_by_one_table)
	assert unexplained.len == 1, 'the column must refuse an unexplained entry'
	assert unexplained[0].contains('conformance/nowhere-planted.cxd'), unexplained[0]
	assert unexplained[0].contains('carries no reason'), unexplained[0]

	_, stale := judge_accepted_by_one([]AcceptedByOne{}, [
		AcceptedByOne{'conformance/nowhere-planted.cxd', .data, reason_entity},
	])
	assert stale.len == 1, 'the column must refuse a reason for a divergence that is gone'
	assert stale[0].contains('NO LONGER'), stale[0]

	// and a divergence that changed sides is not silently re-labelled.
	// Anchor RETARGETED (K7a, RULED: RS-12) from conformance/code.cxd, which
	// left with cx-core-code's extraction and is no longer in the table at
	// all under any kind, to examples/article.cx, a `.data` entry the table
	// still carries (reason_1579) and that this tree keeps for good.
	side, _ := judge_accepted_by_one([
		AcceptedByOne{'examples/article.cx', .program, ''},
	], accepted_by_one_table)
	assert side.len == 1, 'the column must refuse an entry whose accepting reader changed'
	assert side[0].contains('changed sides'), side[0]
}

// ── #1548's own two reproductions, graded by BOTH readers in one step ───────
//
// 1548-c's fixture-first clause. The nested same-quote region is the FIRST
// recorded exception (row 2 of the decision): a program form is not prose, so
// the program reader's refusal is the ruled reading (1521-a, #1546) and the
// data reader's prose reading of the same bytes is the data ring's own correct
// answer. The em-dash body is the DEFECT half (row 3) and stays graded as one
// until #1550 lands, at which point the expectation below flips WITH the fix.
struct ShapeDisposition {
	src        string
	data_ok    bool
	program_ok bool
	reason     string
}

const accepted_by_one_shapes = [
	ShapeDisposition{"[?element \"entry\" [?attr \"path\" \"door.feature.cxd\"] '[feature [want 'to unlock']]']", true, false, 'RECORDED EXCEPTION (1548-c row 2), the first one: the data reading takes the body as one verbatim prose Text and accepts it; the program reader refuses it as an unterminated string, which is the ruled reading (1521-a, #1546) because a program form is not prose.'},
	ShapeDisposition{'[title an \u2014 dash]', true, true, '#1550 (1548-c row 3) — FIXED: prose is Unicode in both rings, so the bareword scan admits the character and this shape flipped to accepted-by-BOTH, exactly as the decision said it would. The row stays, asserting both readers accept it, so a regression in either reader reds this step.'},
]

fn test_accepted_by_one_shapes_are_graded_by_both_readers() {
	for sh in accepted_by_one_shapes {
		mut data_ok := true
		mut data_msg := ''
		cx.parse_cx(sh.src) or {
			data_ok = false
			data_msg = err.msg()
		}
		mut prog_ok := true
		mut prog_msg := ''
		cx.parse_program(sh.src) or {
			prog_ok = false
			prog_msg = err.msg()
		}
		assert data_ok == sh.data_ok, 'reader-parity accepted-by-one shape: the DATA reader ${if data_ok { 'accepts' } else { 'refuses' }} `${sh.src}`, the step says it must ${if sh.data_ok { 'accept' } else { 'refuse' }} it: ${data_msg}\n  ${sh.reason}'
		assert prog_ok == sh.program_ok, 'reader-parity accepted-by-one shape: the PROGRAM reader ${if prog_ok { 'accepts' } else { 'refuses' }} `${sh.src}`, the step says it must ${if sh.program_ok { 'accept' } else { 'refuse' }} it: ${prog_msg}\n  ${sh.reason}'
	}
}
