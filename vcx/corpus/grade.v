// corpus — the ONE copy of the module-corpus grading loop, in a module the
// SHIPPED binary links (#1591 D13a).
//
// ── Why this module exists ──────────────────────────────────────────────────
//
// #1448 (RULED: 1448-a) gave the grading loop one owner by lifting it out of
// `vcx/tests/code_eval_fixtures_test.v` into `vcx/tests/fixtures_grader/`.
// That owner was still under `vcx/tests/`, so it was reachable only from a V
// test process: the extract-sso report's flag F-2 states the consequence —
// `conformance/platform/sso.cxd` is 72 cases that no released `cx` can grade,
// and #1589's promise of "its corpus against a downloaded `cx`, minutes, no
// toolchain" had nothing behind it. D13a rules that the `cx` binary grades a
// corpus file itself, so the loop moves one directory further: out of the test
// tree into `vcx/corpus`, which `vcx/cmd` links for `cx corpus FILE…`.
//
// NOTHING about grading changed in the move. The per-case / per-module /
// per-suite gate resolution order, the capability-set injection, the
// `strict-mode` tag, the argv install, the deterministic clock, the advisory /
// enforced partition, the `CX_BLESS` paths and the #1432 build-identity note
// are carried verbatim from `vcx/tests/fixtures_grader/grader.v`, and the
// shards still grade through THIS loop — `vcx/tests/fixtures_grader` keeps the
// shard manifest, the census files and `run_shard`, and delegates the grading.
// The unchanged `stdlib corpus:` census is the evidence that the move is a
// move and not a rewrite.
//
// The two repo-shaped inputs the loop used to derive from its own @FILE — the
// corpus root and `conformance/gates.cxd` — are Options fields now, because a
// pure-CX package repository has neither at the paths this tree has them.
//
// `vcx/tests/runners/profile_gate/profile_gate.v` still MIRRORS these
// semantics for the profile binaries. That mirror was not 1448-a's business
// and is not this move's either.
module corpus

import cx
import code
import fixtures
import os
import math
import time

// ── Instrumentation (#1448) ─────────────────────────────────────────────────
//
// The partition is derived from MEASURED per-module-file cost, not from the
// alphabet — the cost is in the cases, not in the names — so the readings stay
// in the tree after the split: a shard that grows past its budget says so in
// its own log instead of in a post-merge correlation across two steps.
pub fn ms_line(kind string, what string, extra string, sw time.StopWatch) {
	println('[fixtures] ${kind} ${what} ms=${sw.elapsed().milliseconds()}${extra}')
}

// case_ms_line is the PER-CASE reading, printed only under
// `CX_FIXTURE_TIMING=1` (#1515). The file-level `ms_line` above says a corpus
// file costs 1,414 s; it cannot say which of its 589 cases spend it, and the
// answer to that question is the difference between rewriting a band and
// guessing at one. Off by default: 5,600 lines a run is diagnostic output,
// not evidence, and a diagnostic that turns itself on is one more thing a log
// reader has to explain away.
pub const timing_cases = os.getenv('CX_FIXTURE_TIMING') == '1'

// The line's TEXT, separated from printing it so the shape is pinned by a
// test rather than by a run's log. '' is the not-yet-started case, so a caller
// can flush unconditionally at the top of its loop.
pub fn case_ms_text(fname string, id string, ms i64) string {
	return if id == '' { '' } else { '[fixtures] case ${fname}/${id} ms=${ms}' }
}

fn case_ms_line(fname string, id string, sw time.StopWatch) {
	line := case_ms_text(fname, id, sw.elapsed().milliseconds())
	if timing_cases && line != '' {
		println(line)
	}
}

// graded_id emits the id of every case this process GRADES, under
// `-d cx_grader_ids` and nowhere else. It is the oracle for 1448-a's
// load-bearing property: the set of graded ids before the shard split and
// after it must be IDENTICAL — a case in no shard (silently ungraded) or in
// two (graded twice) shows up as a diff line. The compile-time branch is
// INSIDE the call, so the define cannot change the call graph.
@[inline]
pub fn graded_id(suite string, id string) {
	$if cx_grader_ids ? {
		println('GRADED-ID ${suite} ${id}')
	}
}

// ── The cx build identity a step runs against (#1432, RULED: 1432-a) ────────
//
// The post-merge run on 5193e3752 failed in the grader with `FAIL [11/66]
// C: 405943.8 ms, R: 13832.684 ms` and NO assertion text. The grader walks
// thousands of fixtures over many minutes, so a 13.8 s exit is a process that
// DIED, not a case that answered wrong — and the run log showed a parallel
// step relinking libcx.dylib / cx in the same minute. Diagnosing that took a
// correlation across two steps' logs; an early exit must name its own cause.
//
// So every driver and shard states the build identity it started against —
// the artifact's `.buildid` stamp plus the `.writer` sidecar #1056 added,
// which names the make TARGET, the UTC time and the pid that wrote it — in its
// first line, and re-reads it at its first RECORDED failure, advisory ones
// included, since an advisory row is the earliest signal available and the
// note is diagnostic, not a verdict. A stamp that MOVED between those two
// reads says, in that step's own log, that a build ran under it.
//
// Never fails a step and never blocks one: an absent artifact or stamp is
// reported as the absence it is. The path is the CALLER's (Options.identity_bin)
// — `vcx/target/cx` is a fact about this repository, not about grading.
pub fn build_identity(bin string) string {
	if bin == '' {
		return 'no build artifact named for this run'
	}
	if !os.exists(bin) {
		return 'no ${bin} in this tree'
	}
	id := os.read_file(bin + '.buildid') or { '(no .buildid stamp beside the artifact)' }
	writer := os.read_file(bin + '.writer') or { '(no .writer sidecar)' }
	return '${id} [written by ${writer}]'
}

// ── The parsed fixture ──────────────────────────────────────────────────────
pub struct ParsedFixture {
pub:
	id              string
	in_cx           string
	in_code         string
	out_text        string
	out_multiset    string // comma-separated multiset matcher for :par-unordered fixtures
	out_effects     string // ordered effect-point trace (stream 22 W1 — capability:resource per line)
	has_out_effects bool   // section DECLARED (an empty declared trace asserts zero admissions)
	out_err         string
	gate            string   // per-case gate toggle: enforced|advisory|pending|skip ('' = unset)
	issue           string   // the open issue an advisory case's red is tracked by, '<owner>/<repo>#<n>' — the case's own, else its element's (ADVIS-1, RULED: QUAL-1 (b))
	grant           string   // Effort B least-privilege grant: space-separated capability list ('none' = EMPTY set, PYE-3; '' = host default)
	argv            string   // program argv to install before eval (#926 PYE-2): space-separated, argv[0] included ('' = none)
	tol             f64      // relative float tolerance for out_text match (0 = exact)
	level           string   // family label: core|resilience|async|visualization|…
	tags            []string // case tags (e.g. 'strict-mode' enables --strict typing)
	ring            string   // per-case ring override ('' = inherit the suite header's ring=)
	packs           []string // declared local-effect pack dependencies (fixtures.cxs `packs=`)
	files           []fixtures.FixtureFile // the [file name='N' [#TEXT#]] inputs the case reads, laid down in a scratch directory the program runs from (gap-129, cx-private#1809, RULED: GAPS-1)
	// #1636 (RULED: D70 (a)): a case carrying [cli-argv] or [exit-code] is an
	// INVOCATION of the cx binary, graded by running it — these are its
	// sections as the loader read them (edge newlines trimmed, never clamped:
	// a `#` line in a program body is the program's own).
	cli_argv  string
	exit_code string
	cli_in_cx string
	cli_code  string
	cli_out   string
	cli_err   string
}

pub fn parsed_from(c fixtures.FixtureCase) ParsedFixture {
	return ParsedFixture{
		id:              c.name
		in_cx:           clamp_section(c.sections['in_cx'])
		in_code:         clamp_section(c.sections['in_code'])
		out_text:        clamp_section(c.sections['out_text'])
		out_multiset:    clamp_section(c.sections['out_multiset'])
		out_effects:     clamp_section(c.sections['out_effects'])
		has_out_effects: 'out_effects' in c.sections
		out_err:         clamp_section(c.sections['out_err'])
		gate:            c.gate
		issue:           c.issue
		grant:           c.grant
		argv:            c.argv
		tol:             c.tol
		level:           c.level
		tags:            c.tags
		ring:            c.ring
		packs:           c.packs
		files:           c.files
		cli_argv:        c.sections['cli_argv']
		exit_code:       c.sections['exit_code'].trim_space()
		cli_in_cx:       c.sections['in_cx']
		cli_code:        c.sections['in_code']
		cli_out:         c.sections['out_text']
		cli_err:         c.sections['out_err']
	}
}

// is_cli_case: the case is an invocation of the cx binary (#1636).
pub fn (f ParsedFixture) is_cli_case() bool {
	return f.cli_argv != '' || f.exit_code != ''
}

// clamp_section reproduces the former extract_section end-detection, applied
// to the loader's (already section-bounded) byte-exact body. A section's text
// ends at the first of: a bare `---` line or `--- \n` (legacy section-end /
// horizontal-rule marker the converter does NOT split on), or a
// blank-line-then-comment boundary (`\n\n#` inter-test heading mis-captured
// into the last section). This clamp is consumer-specific (eval) and lives
// here, not in the shared loader (conformance_run never clamped).
pub fn clamp_section(s string) string {
	mut end := s.len
	mut probe := 0
	for probe < s.len {
		next := s.index_after('\n---', probe) or { break }
		if next + 4 < s.len {
			c := s[next + 4]
			if c == ` ` || c == `\n` {
				end = next
				break
			}
		} else {
			// trailing `\n---` (optionally `\n--- `) at end of body
			end = next
			break
		}
		probe = next + 1
	}
	if ci := s.index('\n\n#') {
		if ci < end {
			end = ci
		}
	}
	return s[..end].trim_right(' \t\n')
}

// parse_fixtures_in parses a fixtures file at an arbitrary path (same format
// as conformance/code.cxd). Used by the per-module stdlib shards, by the
// package lane and by `cx corpus`. A case's `gate` is its own `gate=`, else
// its suite element's (D49a — the loader resolves it).
pub fn parse_fixtures_in(path string) []ParsedFixture {
	return parse_suite_in(path).cases
}

// ParsedSuite is one corpus file as the grading core reads it: the cases, the
// suite element's gate status (D49a, #1633; RULED: RS-27) and, when that
// element carries a gate= this core cannot grade, the refusal naming it.
pub struct ParsedSuite {
pub:
	gate    string // the [test-suite] element's gate= ('' = unset, enforced)
	reason  string // its reason=
	refusal string // '' = gradeable; else why the element's gate= is refused
	cases   []ParsedFixture
}

// parse_suite_in reads a corpus file's suite element and cases. A suite's gate
// status lives ON its element — `[test-suite … gate=advisory reason='…']` — so
// it travels with the file into whatever repository carries it; the loader has
// already folded it into every case that carries no `gate=` of its own.
// conformance/gates.cxd is the DERIVED cx-wide register (`make
// gates-manifest-gate` holds it equal to the elements), and this core does not
// read its module rows: a file graded in a component repository and the same
// file graded here must get the same verdict from the same bytes.
pub fn parse_suite_in(path string) ParsedSuite {
	if !os.exists(path) {
		return ParsedSuite{}
	}
	s := fixtures.load_suite(path)
	mut out := []ParsedFixture{}
	for c in s.cases {
		out << parsed_from(c)
	}
	return ParsedSuite{
		gate:    s.gate
		reason:  s.reason
		refusal: s.gate_refusal()
		cases:   out
	}
}

// ── The comparators ─────────────────────────────────────────────────────────

// thrown_matches_out_err / out_err_matches — this module does not carry its
// own reading of the `[out-err …]` channel. Both live in `code`
// (`code/out_err_matches.v`, RULED: 1408-a): the value path pins the
// TOP-LEVEL code by equality and reads a `cause=` token against a `[cause]`
// descendant; the thrown path is R3.12 / audit F-19, unchanged.
pub fn thrown_matches_out_err(msg string, out_err string) bool {
	return code.out_err_matches_thrown(msg, out_err)
}

// same_shape compares two render outputs ignoring whitespace differences
// (lines, multi-space, leading/trailing). Both must have the same nonblank
// tokens in the same order.
pub fn same_shape(a string, b string) bool {
	at := a.fields()
	bt := b.fields()
	if at.len != bt.len {
		return false
	}
	for i, t in at {
		if t != bt[i] {
			return false
		}
	}
	return true
}

// same_multiset compares two render outputs as multisets D11 — used for
// fixtures where emission order is genuinely non-deterministic but membership
// IS contracted (the [?test-concurrent] scaffold class; [par] output is SOURCE
// order always since L105 and no longer needs this comparator).
pub fn same_multiset(a string, b string) bool {
	mut ai := multiset_items(a)
	mut bi := multiset_items(b)
	if ai.len != bi.len {
		return false
	}
	ai.sort()
	bi.sort()
	for i, t in ai {
		if t != bi[i] {
			return false
		}
	}
	return true
}

fn multiset_items(s string) []string {
	mut inner := s.trim_space()
	if inner.starts_with('(') && inner.ends_with(')') {
		inner = inner[1..inner.len - 1]
	}
	mut items := []string{}
	for part in inner.split(',') {
		t := part.trim_space()
		if t != '' {
			items << t
		}
	}
	return items
}

// quote_only_diff reports whether `got` and `exp` differ ONLY by string-
// quoting (the render_value→render_canonical convention shift): strip every
// `'`/`"` and whitespace-normalise both; equal-but-not-identical means the
// sole difference is quote marks. Used to gate the CX_BLESS re-derivation so a
// genuine structural/value change is never silently adopted.
pub fn quote_only_diff(got string, exp string) bool {
	if got == exp {
		return false
	}
	g := got.replace("'", '').replace('"', '').fields().join(' ')
	e := exp.replace("'", '').replace('"', '').fields().join(' ')
	return g == e
}

// bless_emit appends a re-derived expected-output record for the offline
// rewriter. Marker-delimited to survive multi-line values without JSON
// escaping.
//
// #1448: with the stdlib walk sharded, up to k+1 processes may append here in
// one CX_BLESS run. Each record is ONE write(2) on an O_APPEND descriptor,
// which the kernel positions atomically for a regular file, so records
// interleave whole rather than tearing. The applier reads whole records.
pub fn bless_emit(file string, id string, new_text string) {
	mut fh := os.open_append('/tmp/cx_blesses.txt') or { return }
	fh.write_string('<<<BLESS file=${file} id=${id}>>>\n${new_text}\n<<<ENDBLESS>>>\n') or {}
	fh.close()
}

// bless_mode reads the two CX_BLESS lanes exactly as the single-file grader
// did. The I1 epoch re-bless is DISARMED in normal builds (register R3.9) —
// the epoch is closed; adopting every enforced out-text mismatch now takes an
// explicit `-d cx_epoch_bless` compile AND `CX_BLESS=epoch`. The refusal is an
// assertion in the caller's own test function, so it fails the step that asked.
pub fn bless_mode() (bool, bool, string) {
	bless := os.getenv('CX_BLESS') == '1'
	mut epoch := false
	mut refusal := ''
	$if cx_epoch_bless ? {
		epoch = os.getenv('CX_BLESS') == 'epoch'
	} $else {
		if os.getenv('CX_BLESS') == 'epoch' {
			refusal = 'CX_BLESS=epoch REFUSED: the I1 epoch is closed; a re-bless build requires explicit -d cx_epoch_bless (register R3.9)'
		}
	}
	return bless, epoch, refusal
}

// bless_refusal is the empty string unless this build was asked for the CLOSED
// I1 epoch re-bless without `-d cx_epoch_bless`. Every driver and shard
// asserts on it at its own `test_` line.
pub fn bless_refusal() string {
	_, _, refusal := bless_mode()
	return refusal
}

// ── The gate policy (conformance/gates.cxd) ─────────────────────────────────
//
// load_gate_policy_at reads a gates document and returns the module->gate map
// for the given suite PLUS the suite's default= tier (falling back to the
// [gate-policy] default=). Toggle: 'enforced' failures block the gate;
// 'advisory' failures are reported but do NOT block (spec-first frontier /
// unimplemented). Resolution order (D49a, #1633 — was #721's per-module tier):
//   per-case gate= > the [test-suite] element's gate= > per-suite default > enforced
// A fixture that resolves to '' at every tier is enforced (deny-by-default,
// mirroring the capability grant model). The module->gate map is the DERIVED
// register's rows: the grading loop below does not consult it (the element is
// the source, and `make gates-manifest-gate` holds the rows equal to it). The
// package lane (vcx/tests/code_eval_fixtures_test.v) still takes it, behind
// the element it reads first through the same loader.
//
// An ABSENT policy file is the empty policy — every case enforced. That is the
// deny-by-default answer, and it is what a repository with no `gates.cxd` gets.
pub fn load_gate_policy_at(path string, suite string) (map[string]string, string) {
	mut m := map[string]string{}
	mut suite_default := ''
	mut policy_default := ''
	if path == '' {
		return m, suite_default
	}
	src := os.read_file(path) or { return m, suite_default }
	doc := cx.parse(src) or { return m, suite_default }
	for node in doc.elements {
		if node.is_element() {
			if node.element().name == 'gate-policy' {
				for a in node.element().attrs {
					if a.name == 'default' {
						policy_default = cx.scalar_value_str_public(a.value)
					}
				}
				for s in node.element().items {
					if s.is_element() {
						if s.element().name == 'suite' {
							mut sname := ''
							mut sdefault := ''
							for a in s.element().attrs {
								if a.name == 'name' {
									sname = cx.scalar_value_str_public(a.value)
								}
								if a.name == 'default' {
									sdefault = cx.scalar_value_str_public(a.value)
								}
							}
							if sname != suite {
								continue
							}
							suite_default = sdefault
							for md in s.element().items {
								if md.is_element() {
									if md.element().name == 'module' {
										mut mn := ''
										mut mg := ''
										for a in md.element().attrs {
											if a.name == 'name' {
												mn = cx.scalar_value_str_public(a.value)
											}
											if a.name == 'gate' {
												mg = cx.scalar_value_str_public(a.value)
											}
										}
										if mn != '' {
											m[mn] = mg
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	if suite_default == '' {
		suite_default = policy_default
	}
	return m, suite_default
}

// ── The local-effect pack composition (fixtures.cxs `packs=`) ───────────────
//
// excluded_packs probes the SAME `-d cx_no_pack_*` gates the build uses —
// composition is read off the artifact, never passed as free text. A case
// declaring a pack this binary packs out is SKIPPED by name, never graded:
// grading it would answer E_NO_CALLABLE, which is the pack working, not the
// case failing.
pub fn excluded_packs() []string {
	mut off := []string{}
	$if cx_no_pack_io ? {
		off << 'io'
	}
	$if cx_no_pack_env ? {
		off << 'env'
	}
	$if cx_no_pack_process ? {
		off << 'process'
	}
	$if cx_no_pack_time ? {
		off << 'time'
	}
	$if cx_no_pack_random ? {
		off << 'random'
	}
	$if cx_no_pack_log ? {
		off << 'log'
	}
	$if cx_no_pack_term ? {
		off << 'term'
	}
	$if cx_no_pack_http_client ? {
		off << 'http-client'
	}
	$if cx_no_pack_sched ? {
		off << 'sched'
	}
	// `platform` (RULED: PNAT-1, fixtures.cxs `packs=`): the natives only the
	// platform build composes — the store, audit, session and backend
	// registrations a platform module's pure-CX surface calls into. A binary
	// built without `-d cx_platform` (the embed and cli profiles) has none of
	// them, so a case that declares `packs=platform` is skipped there BY NAME;
	// grading it would answer E_NO_CALLABLE, which is the profile working,
	// not the case failing. Read off the artifact like every pack above.
	$if !cx_platform ? {
		off << 'platform'
	}
	return off
}

// needs_excluded_pack reports whether the case declares a dependency on a pack
// this composition excludes.
pub fn needs_excluded_pack(f ParsedFixture, off []string) bool {
	for p in f.packs {
		if p in off {
			return true
		}
	}
	return false
}

// ── The grading pass ────────────────────────────────────────────────────────

// Options carries everything the loop used to derive from its own @FILE, plus
// the two knobs the CLI verb needs and the shards do not.
pub struct Options {
pub:
	corpus_root       string // directory the file names resolve against ('' = names are paths already)
	gates_path        string // conformance/gates.cxd, or '' for the empty (all-enforced) policy
	suite             string // the gates.cxd [suite name=…] this run resolves under
	where             string // the label the #1432 build-identity note carries
	identity_bin      string // the build artifact whose stamp the note reads ('' = none)
	identity_at_start string // that stamp as read at process init
	manual_clock      bool = true // sched.md §3.3: the conformance harness runs the DETERMINISTIC clock (RULED: 1358-b)
	file_ms           bool = true // print the per-file `[fixtures] file …` reading (#1448's partition evidence)
	skip_packs        bool   // skip a case declaring a pack THIS binary packs out
	record            bool   // record a per-case row (the CLI verb's PASS/FAIL lines)
	cli_bin           string // the cx binary a [cli-argv]/[exit-code] case runs ('' = $CX_BIN, else this process when it is cx) — #1636
}

// CaseRecord is one row of the per-case ledger, recorded only under
// `Options.record` so the shard path stays allocation-identical to the loop
// this module was moved from.
pub struct CaseRecord {
pub:
	file   string
	id     string
	status string // 'graded' | 'skip' | 'other-lane' | 'skip-pack'
	gate   string // the effective gate for a graded row
	note   string // the reason a skipped row carries
pub mut:
	// us is a graded row's wall time in microseconds — the #1515 per-case
	// stopwatch, read when the case's grading ends (start-up excluded) — which
	// `cx corpus --times` prints (GAPS-1, cx-private#1813 §24); -1 otherwise.
	us i64 = -1
}

pub struct Outcome {
pub mut:
	ran               int
	out_err_ran       int
	files             int
	out_err_by_module map[string]int
	enforced          []string
	advisory          []string
	records           []CaseRecord
}

// grade_files runs every fixture of every named module file end-to-end — the
// loop `test_stdlib_module_fixtures` used to run over all 83 files in one
// thread, unchanged, over whatever subset the caller names.
//
// A name is resolved against Options.corpus_root and may carry its ring
// directory (`stdlib/ux.cxd`, `platform/flow.cxd`), with `extended.cxd` and
// `xml_codec.cxd` named directly: #1379 joined extended.cxd to this walk
// because it carries [in-code] cases the DOCUMENT lane (conformance_run.v)
// skips as OTHER-LANE while pointing here, and #1427-c lifted xml_codec.cxd
// out of stdlib/ as Ring 0. A case without [in-code] (extended's data cases,
// graded by the document lane) is skipped below.
pub fn grade_files(opts Options, names []string) Outcome {
	// The epoch refusal is asserted by the CALLER, at its own `test_` line
	// (`assert corpus.bless_refusal() == ''`), so the diagnostic names the
	// step that was asked to re-bless.
	bless, epoch, _ := bless_mode()
	mut o := Outcome{
		files: names.len
	}
	// #1026 coverage accounting. The authz suite's 25 [out-err …] cases were
	// long ASSUMED green here because they showed red under the standalone
	// document runner (conformance_run.v), which has no evaluator and was
	// scoring them against a parse of their `[in-cx [empty]]` scaffolding.
	// "Presumably green" is what that issue objects to, so the lane STATES
	// its coverage instead: which modules exercised the err channel, and how
	// many cases each contributed.
	// D49a (#1633): a suite's status is its [test-suite] element's gate=, which
	// the loader has already folded into each case that carries none of its
	// own. The policy document contributes its suite default= only — its
	// module rows are the DERIVED register, never a second source.
	_, suite_default := load_gate_policy_at(opts.gates_path, opts.suite)
	packs_off := if opts.skip_packs { excluded_packs() } else { []string{} }
	mut adv_ids := map[string]bool{}
	mut untracked_ids := map[string]bool{}
	mut failures := []string{}
	// #1432: the build-identity read at the first recorded failure, once per step.
	mut identity_reported := false
	for fpath in names {
		// the label a failure / coverage row carries: `flow.cxd`, not
		// `platform/flow.cxd` — the register in conformance/gates.cxd is
		// keyed on the module basename, which #1427-c's move did not change.
		fname := os.base(fpath)
		// #1448: the per-module-file reading the partition is derived from.
		fsw := time.new_stopwatch()
		file_ran_at_entry := o.ran
		full := if opts.corpus_root == '' { fpath } else { os.join_path(opts.corpus_root, fpath) }
		ps := parse_suite_in(full)
		// D49a: an element gate= this core cannot grade (pending, skip, a typo,
		// advisory with no reason= or no issue=, an advisory case naming no open
		// issue — ADVIS-1) fails the FILE as an enforced failure —
		// guessing what a pending suite means would grade something nobody
		// asked for. `cx corpus` refuses the same file with exit 2 before here.
		if ps.refusal != '' {
			failures << '${fname}: REFUSED — ${ps.refusal}'
			continue
		}
		cases := ps.cases
		// #1515: the previous case's reading is flushed HERE rather than at
		// each of the body's exits — the body `continue`s from a dozen places
		// and V has no block-scoped defer.
		mut pend_id := ''
		// GAPS-1, cx-private#1813 §24: the record the pending reading belongs
		// to, so `cx corpus --times` reads the same stopwatch #1515 prints.
		mut pend_rec := -1
		mut csw := time.new_stopwatch()
		// #1597 (RULED: RS-17): one env per case, and the finished one is TORN
		// DOWN before the next is built — `env.close()` empties its shell and
		// breaks the cycles in its module graph, so what a stale
		// conservatively-scanned word can reach is a few empty maps, not the
		// ~13 MB a connector load parses. Without it this walk paid 0.8 s for
		// its first case and 12–25 s for its last (RSS 0.83 → 6.34 GB over 591
		// cases). Declared here for the same reason `pend_id` is: the body
		// `continue`s from a dozen places.
		mut env := code.MatchEnv{}
		// gap-129 (cx-private#1809, RULED: GAPS-1): the scratch directory the
		// previous case's [file …] inputs were laid down in, torn down (and the
		// working directory restored) at the same point `env` is — the body
		// `continue`s from a dozen places.
		mut case_dir := ''
		orig_cwd := os.getwd()
		for f in cases {
			if failures.len > 0 && !identity_reported {
				identity_reported = true
				// A caller with no build artifact to watch (the CLI verb, a
				// package repository) has nothing to say here — an absence
				// stated as a note would be noise, not diagnosis.
				if opts.identity_bin != '' {
					println(build_identity_note(opts, opts.where))
				}
			}
			// #1636 (RULED: D70 (a)): an invocation case — [cli-argv] or
			// [exit-code], with or without [in-code] — is this lane's, graded
			// by running the binary (cli_case_failure below), not evaluated
			// in-process (which reads neither section: three antipatterns
			// cases failed for a reason not theirs and every [exit-code]
			// passed unchecked).
			if f.is_cli_case() {
				cli_gate := if f.gate != '' { f.gate } else { suite_default }
				if cli_gate == 'skip' || cli_gate == 'pending' {
					if opts.record {
						o.records << CaseRecord{
							file:   fname
							id:     f.id
							status: 'skip'
							gate:   cli_gate
							note:   'gate=${cli_gate}'
						}
					}
					continue
				}
				o.ran++
				graded_id(fname, f.id)
				if opts.record {
					o.records << CaseRecord{
						file:   fname
						id:     f.id
						status: 'graded'
						gate:   cli_gate
						note:   'invocation: graded by running the cx binary'
					}
				}
				adv_ids['${fname}/${f.id}'] = cli_gate == 'advisory'
				if why := cli_case_failure(opts, f, fname) {
					failures << why
				}
				continue
			}
			// #1379: a data-only case (no [in-code]) belongs to the document
			// lane; only the program cases are this lane's.
			if f.in_code == '' {
				if opts.record {
					o.records << CaseRecord{
						file:   fname
						id:     f.id
						status: 'other-lane'
						note:   '[in-cx …] only — the DOCUMENT lane grades it'
					}
				}
				continue
			}
			// effective gate: per-case > the suite element (both in f.gate, the
			// loader resolves them — D49a) > the policy's suite default (>
			// enforced when every tier is '').
			mut eff_gate := if f.gate != '' { f.gate } else { suite_default }
			// ADVIS-1 (RULED: QUAL-1 (b)): an advisory status is granted only to
			// a case that names the open issue tracking its red. The loader
			// refused an untracked case whose advisory came from the case or its
			// element (ps.refusal above); the POLICY's suite default is the one
			// tier it cannot see, so a case made advisory by the policy alone and
			// naming no issue is graded ENFORCED here, and its failure says why.
			policy_untracked := f.gate == '' && eff_gate == 'advisory'
				&& !fixtures.is_issue_ref(f.issue)
			if policy_untracked {
				eff_gate = 'enforced'
				untracked_ids['${fname}/${f.id}'] = true
			}
			if eff_gate == 'skip' || eff_gate == 'pending' {
				if opts.record {
					o.records << CaseRecord{
						file:   fname
						id:     f.id
						status: 'skip'
						gate:   eff_gate
						note:   'gate=${eff_gate}'
					}
				}
				continue // excluded from the gate (not run)
			}
			// cx-core-code#67: a `level=visualization` case is RENDER-spec, not
			// eval — its out-text is the structure recovered by rendering the
			// program to a diagram and reverse-parsing it (code.md §11.4.2
			// gate 9), graded by the diagram round-trip lane. The V grader skips
			// it; so does this lane, by name, never evaluating it as a program.
			if f.level == 'visualization' {
				if opts.record {
					o.records << CaseRecord{
						file:   fname
						id:     f.id
						status: 'skip'
						gate:   eff_gate
						note:   'level=visualization: graded by the diagram round-trip lane (gate 9)'
					}
				}
				continue
			}
			if opts.skip_packs && needs_excluded_pack(f, packs_off) {
				if opts.record {
					o.records << CaseRecord{
						file:   fname
						id:     f.id
						status: 'skip-pack'
						gate:   eff_gate
						note:   'declares packs=${f.packs.join(",")}; this binary excludes ${packs_off.join(",")}'
					}
				}
				continue
			}
			case_ms_line(fname, pend_id, csw)
			if pend_rec >= 0 {
				o.records[pend_rec].us = csw.elapsed().microseconds()
				pend_rec = -1
			}
			pend_id = f.id
			csw = time.new_stopwatch()
			o.ran++
			graded_id(fname, f.id)
			if opts.record {
				o.records << CaseRecord{
					file:   fname
					id:     f.id
					status: 'graded'
					gate:   eff_gate
				}
				pend_rec = o.records.len - 1
			}
			if f.out_err != '' {
				o.out_err_ran++
				o.out_err_by_module[fname.all_before('.cxd')]++
			}
			adv_ids['${fname}/${f.id}'] = eff_gate == 'advisory'
			env.close()
			case_dir = case_files_teardown(case_dir, orig_cwd)
			// gap-129: the case's own input files, laid down in a fresh scratch
			// directory the program runs from, so a relative read finds them.
			if f.files.len > 0 {
				case_dir = case_files_lay_down(f.files) or {
					failures << '${fname}/${f.id}: ${err.msg()}'
					env = code.new_env()
					continue
				}
			}
			env = code.new_env()
			// sched.md §3.3 loop-construction selector: the conformance harness runs the
			// DETERMINISTIC clock (RULED: 1358-b). Production defaults to :wall, so
			// without this every test-clock-advance case would answer CXER4970.
			//
			// The call is compiled out on a composition that packs `sched` OUT
			// (`-d cx_no_pack_sched`, the embed profile): the selector lives in
			// code/stdlib_sched_notd_cx_no_pack_sched.v, so there is no clock to
			// select and no case that needs one — every `packs=sched` case is
			// skipped by name on that binary.
			$if !cx_no_pack_sched ? {
				code.sched_set_manual_clock(opts.manual_clock)
			}
			// strict-tag parity (stream 14, the audit note): the stdlib and
			// package lanes honor 'strict-mode' exactly as the code.cxd lane
			// does — a tagged fixture must never silently run un-strict.
			if 'strict-mode' in f.tags {
				env.state.strict = true
			}
			code.register_conformance_test_modules(mut env.state.module_table) // #701
			if f.in_cx != '' && f.in_cx != '[empty]' {
				// cx-private#1718 item 2: the one [in-cx] binding every grader
				// shares — the input's SEMANTIC reading, anchors and merges
				// resolved, as the CLI's --data binding is (ANC-1).
				if n := code.fixture_doc_node(f.in_cx) {
					env.bind_set('doc', n)
					env.bind_set('input', n)
				}
			}
			// Capability-set injection (security.md §3, Effort A/B). The
			// conformance runner is the host here: deny-lane cases (those
			// expecting CXER0271) run under the EMPTY set so the effect
			// point denies; every other (behavior) case runs under a full
			// grant so real effects proceed. No fixture edits — the host
			// chooses the set, exactly as a CLI `--allow-*` / embedding would.
			if f.grant == 'none' {
				// PYE-3 (#926): behavior case pinned to the EMPTY set —
				// proves the exercised surface is ungated (argv/parse-args).
				code.caps_set_empty()
			} else if f.grant != '' {
				// Effort B: explicit per-fixture least-privilege grant, read
				// through the ABI grant-spec parser so a SCOPED token
				// (`read=/tmp`, `net=host:443`) means on a fixture exactly
				// what it means on the CLI and at the ABI — one spelling, one
				// admission rule (RULED: 1061-a).
				code.caps_apply_spec(f.grant) or {
					panic('fixture [grant …] refused (#713 loud unknown-cap): ${err.msg()}')
				}
			} else if f.out_err.contains('CXER0271') {
				code.caps_set_empty()
			} else {
				code.caps_set_all()
			}
			// Program argv (#926, PYE-2): fixture-declared vector, argv[0]
			// included; cleared otherwise so no cross-case leak.
			code.set_program_argv(f.argv.split_any(' \t').filter(it != ''))
			prog := cx.parse_program(f.in_code) or {
				if f.out_err != '' {
					if !thrown_matches_out_err(err.msg(), f.out_err) {
						failures << '${fname}/${f.id}: parse threw "${err.msg()}" but expected ${f.out_err} (R3.12)'
					}
					continue
				}
				failures << '${fname}/${f.id}: parse: ${err}'
				continue
			}
			mut result := code.eval(prog.body, mut env) or {
				if f.out_err != '' {
					if !thrown_matches_out_err(err.msg(), f.out_err) {
						failures << '${fname}/${f.id}: eval threw "${err.msg()}" but expected ${f.out_err} (R3.12)'
					}
					// out-effects grades on the thrown path too: effects
					// admitted BEFORE the throw are part of the witness.
					if why := effects_trace_failure(f, fname, ' (thrown path)') {
						failures << why
					}
					continue
				}
				failures << '${fname}/${f.id}: eval: ${err}'
				continue
			}
			// EV-PULL: force at the runner's result boundary.
			result = code.force_lazy_result(result, mut env)
			// cx-core-code#67: the serialization boundary — a function value
			// reaching the result has no data image and refuses CXER0291
			// (code.md §9.2), as the CLI's render() and the V grader do; this
			// lane renders with render_canonical (never fallible), so it
			// reproduces the deep predicate.
			if cx.contains_fn_value(result) {
				if f.out_err != '' {
					if !f.out_err.contains('CXER0291') {
						failures << '${fname}/${f.id}: expected ${f.out_err}, got function value (CXER0291)'
					}
				} else {
					failures << '${fname}/${f.id}: function value not serialisable (CXER0291), expected ${f.out_text.trim_space()}'
				}
				continue
			}
			if f.out_err != '' {
				// Expected an err: accept a V-error (handled above) or an
				// err-value whose TOP-LEVEL code is the expected one
				// (RULED: 1408-a).
				if !code.out_err_matches(code.render_canonical(result), f.out_err) {
					failures << '${fname}/${f.id}: expected ${f.out_err}, got ${code.render_canonical(result)}'
				}
				if why := effects_trace_failure(f, fname, '') {
					failures << why
				}
				continue
			}
			if why := effects_trace_failure(f, fname, '') {
				failures << why
			}
			rendered := code.render_canonical(result).trim_space()
			if f.out_multiset != '' {
				expected := f.out_multiset.trim_space()
				if !same_multiset(rendered, expected) {
					failures << '${fname}/${f.id}: multiset mismatch\n  got:      ${rendered}\n  expected: ${expected}'
				}
			} else {
				expected := f.out_text.trim_space()
				if f.tol > 0 {
					// Tolerant float match: PASS when |actual-expected| <= tol*|expected|.
					actual_f := rendered.f64()
					expected_f := expected.f64()
					if math.abs(actual_f - expected_f) > f.tol * math.abs(expected_f) {
						failures << '${fname}/${f.id}: tol mismatch (tol=${f.tol})\n  got:      ${rendered}\n  expected: ${expected}'
					}
				} else if !same_shape(rendered, expected) {
					if (bless && quote_only_diff(rendered, expected))
						|| (epoch && eff_gate != 'advisory') {
						bless_emit(fname, f.id, rendered)
					} else {
						failures << '${fname}/${f.id}: mismatch\n  got:      ${rendered}\n  expected: ${expected}'
					}
				}
			}
		}
		if pend_rec >= 0 {
			o.records[pend_rec].us = csw.elapsed().microseconds()
		}
		env.close()
		case_dir = case_files_teardown(case_dir, orig_cwd)
		case_ms_line(fname, pend_id, csw)
		if opts.file_ms {
			ms_line('file', fname, ' cases=${o.ran - file_ran_at_entry}', fsw)
		}
	}
	// Partition failures by the effective gate (the suite element, D49a):
	// 'advisory' suites are the spec-first frontier (unimplemented) — reported
	// but NOT blocking; everything else is enforced (deny-by-default).
	for fl in failures {
		key := fl.all_before(': ')
		if adv_ids[key] {
			o.advisory << fl
		} else if untracked_ids[key] {
			o.enforced << '${fl}\n  graded ENFORCED: advisory by the gate policy\'s suite default, but the case names no issue= -- an advisory red no open issue tracks is not granted (ADVIS-1)'
		} else {
			o.enforced << fl
		}
	}
	return o
}

// effects_trace_failure compares a case's DECLARED [out-effects …] trace — the
// ordered admitted effect points, one `capability:resource` per line, exact in
// order and count; a declared-but-empty trace asserts zero admissions —
// against the evaluator's trace for this case (stream 22 W1). The program lane
// read [out-effects …] and never compared it, so a wrong trace passed (#1636,
// REFUTE-1 r01); the in-module eval test compared it for code.cxd alone.
fn effects_trace_failure(f ParsedFixture, fname string, path_note string) ?string {
	if !f.has_out_effects {
		return none
	}
	got := code.effects_trace_snapshot().join('\n')
	exp := f.out_effects.trim_space()
	if got == exp {
		return none
	}
	return '${fname}/${f.id}: effect-trace mismatch${path_note}\n  got:      ${got}\n  expected: ${exp}'
}

// build_identity_note is the line printed at a step's first recorded failure:
// unchanged says the artifacts held still, MOVED names the mid-run relink
// (#1432).
pub fn build_identity_note(opts Options, where string) string {
	now := build_identity(opts.identity_bin)
	if now == opts.identity_at_start {
		return '[code_eval_fixtures] ${where}: first recorded failure (advisory ones included) — cx build identity UNCHANGED since this step started (${now})'
	}
	return '[code_eval_fixtures] ${where}: first recorded failure (advisory ones included) — cx build identity MOVED under this step: a parallel build relinked the binary mid-run (#1432)\n  at start: ${opts.identity_at_start}\n  now:      ${now}'
}

// failures_for answers the recorded failure lines of ONE case — the ledger the
// CLI verb turns into its `FAIL <id>` block. The stored line is
// `<file>/<id>: <detail>`, which is the shape every existing consumer greps.
pub fn failures_for(o Outcome, file string, id string) []string {
	key := '${file}/${id}: '
	mut out := []string{}
	for fl in o.enforced {
		if fl.starts_with(key) {
			out << fl[key.len..]
		}
	}
	for fl in o.advisory {
		if fl.starts_with(key) {
			out << fl[key.len..]
		}
	}
	return out
}

// case_files_lay_down writes a case's `[file name='N' [#TEXT#]]` inputs into a
// fresh scratch directory and makes it the working directory, so the program
// reads them by their relative names (gap-129, cx-private#1809, RULED:
// GAPS-1). The loader's files_refusal (cx corpus refuses the file before any
// grading) is asked again here, so a shard grading the same case refuses it
// too rather than writing outside the directory.
fn case_files_lay_down(files []fixtures.FixtureFile) !string {
	why := fixtures.files_refusal(files)
	if why != '' {
		return error('REFUSED — the case ${why}')
	}
	dir := os.join_path(os.temp_dir(), 'cx-corpus-files-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(dir) or { return error('cannot create the case\'s scratch directory ${dir}: ${err.msg()}') }
	for f in files {
		target := os.join_path(dir, f.name)
		parent := os.dir(target)
		if parent != dir {
			os.mkdir_all(parent) or {
				os.rmdir_all(dir) or {}
				return error('cannot create ${parent} for [file name=\'${f.name}\']: ${err.msg()}')
			}
		}
		os.write_file(target, f.text) or {
			os.rmdir_all(dir) or {}
			return error('cannot write [file name=\'${f.name}\']: ${err.msg()}')
		}
	}
	os.chdir(dir) or {
		os.rmdir_all(dir) or {}
		return error('cannot enter the case\'s scratch directory ${dir}: ${err.msg()}')
	}
	return dir
}

// ── the invocation cases (#1636, RULED: D70 (a)) ────────────────────────────
//
// The vocabulary conformance/llm/antipatterns.cxd and llm/cli.cxd declare, and
// scripts/gen_docs/primer_build.cx's replay has always graded: `[cli-argv]` is
// one argv token per line — `%DATA%` the [in-cx] file, `%FILE%` the [in-code]
// file, `%CODE%` the [in-code] body as one token — and absent it is
// `--allow-<g>…` for the case's grant= then `--data=%DATA% %FILE%`, or
// `%FILE%` alone when [in-cx] is `[empty]`. The output is stdout when it is
// not blank, else stderr, trailing newlines dropped; [out-text] matches it
// byte-exact, a one-line `cx-err:` [out-err] by containment (the corpus pins
// the code, not the wording), any other [out-err] byte-exact; [exit-code],
// when declared, is the process's own.

// cli_bin_for: the binary an invocation case runs — the caller's, else
// $CX_BIN, else this process when it is cx itself (`cx corpus`). '' = none,
// which the case is refused for by name: an invocation graded by nothing is
// the unchecked pass this lane exists to end.
fn cli_bin_for(opts Options) string {
	if opts.cli_bin != '' {
		return opts.cli_bin
	}
	env_bin := os.getenv('CX_BIN')
	if env_bin != '' && os.is_executable(env_bin) {
		return env_bin
	}
	me := os.executable()
	if os.base(me) == 'cx' || os.base(me).starts_with('cx-') {
		return me
	}
	return ''
}

pub fn cli_argv_tokens(f ParsedFixture) []string {
	if f.cli_argv.trim_space() != '' {
		return f.cli_argv.split_into_lines().map(it.trim_space()).filter(it != '')
	}
	mut toks := []string{}
	for g in f.grant.split_any(' \t') {
		if g != '' && g != 'none' {
			toks << '--allow-${g}'
		}
	}
	data := if f.cli_in_cx == '' { '[empty]' } else { f.cli_in_cx }
	if data.trim_space() == '[empty]' {
		toks << '%FILE%'
	} else {
		toks << '--data=%DATA%'
		toks << '%FILE%'
	}
	return toks
}

fn cli_case_failure(opts Options, f ParsedFixture, fname string) ?string {
	bin := cli_bin_for(opts)
	if bin == '' {
		return '${fname}/${f.id}: REFUSED — an invocation case ([cli-argv]/[exit-code]) is graded by running the cx binary, and this grader names none (Options.cli_bin, \$CX_BIN) (#1636)'
	}
	dir := os.join_path(os.temp_dir(), 'cx-corpus-cli-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(dir) or { return '${fname}/${f.id}: cannot create a scratch directory: ${err.msg()}' }
	defer {
		os.rmdir_all(dir) or {}
	}
	data := if f.cli_in_cx == '' { '[empty]' } else { f.cli_in_cx }
	data_path := os.join_path(dir, '${f.id}.data.cx')
	prog_path := os.join_path(dir, '${f.id}.prog.cx')
	os.write_file(data_path, data + '\n') or { return '${fname}/${f.id}: cannot write the document: ${err.msg()}' }
	os.write_file(prog_path, f.cli_code + '\n') or { return '${fname}/${f.id}: cannot write the program: ${err.msg()}' }
	argv := cli_argv_tokens(f).map(it.replace('%DATA%', data_path).replace('%FILE%', prog_path).replace('%CODE%', f.cli_code))
	// Each stream to a file of its own (no pipe to fill), the exit read
	// directly — the shape every child of the corpus tooling has.
	out_path := os.join_path(dir, 'stdout')
	err_path := os.join_path(dir, 'stderr')
	mut words := [os.quoted_path(bin)]
	words << argv.map(os.quoted_path(it))
	cmd := words.join(' ') + ' < /dev/null > ' + os.quoted_path(out_path) + ' 2> ' + os.quoted_path(err_path)
	rc := os.system(cmd)
	mut so := os.read_file(out_path) or { '' }
	mut se := os.read_file(err_path) or { '' }
	so = so.trim_right('\n')
	se = se.trim_right('\n')
	got := if so.trim_space() == '' { se } else { so }
	shown := 'cx ' + cli_argv_tokens(f).map(it.replace('%DATA%', 'input.cx').replace('%FILE%', 'prog.cx').replace('%CODE%', "'" + f.cli_code + "'")).join(' ')
	if f.cli_out != '' {
		if got != f.cli_out {
			return '${fname}/${f.id}: invocation output mismatch (`${shown}`)\n  got:      ${got}\n  expected: ${f.cli_out}'
		}
	} else if f.cli_err != '' {
		contains := !f.cli_err.contains('\n') && f.cli_err.starts_with('cx-err:')
		if (contains && !got.contains(f.cli_err)) || (!contains && got != f.cli_err) {
			return '${fname}/${f.id}: invocation refusal mismatch (`${shown}`)\n  got:      ${got}\n  expected: ${f.cli_err}'
		}
	} else {
		return '${fname}/${f.id}: an invocation case records no [out-text] or [out-err] — nothing to grade its output against (#1636)'
	}
	if f.exit_code != '' && f.exit_code != rc.str() {
		return '${fname}/${f.id}: invocation exit code ${rc}, expected ${f.exit_code} (`${shown}`)'
	}
	return none
}

// case_files_teardown restores the working directory and removes the scratch
// directory a case's files were laid down in; a no-op when the case had none.
fn case_files_teardown(case_dir string, orig_cwd string) string {
	if case_dir == '' {
		return ''
	}
	os.chdir(orig_cwd) or {}
	os.rmdir_all(case_dir) or {}
	return ''
}
