module main

import cx
import fixtures
import code
import platform as _
import os
import math

// thrown_matches_out_err reports whether a THROWN (V-error) eval/parse
// failure legitimately satisfies an `out-err` fixture. Register R3.12 / audit
// F-19: the historical #404–#407 false-green class let a thrown error pass ANY
// out-err case unchecked — so a case expecting cx-err:CXER0100 passed even if
// the thrown error was something else entirely. This pins the SPECIFIC code:
// when the fixture names a CXER token, the thrown message MUST carry it; with
// no CXER token, the whole expected string must appear. Empty out-err never
// matches a throw (a non-error case must not throw).
fn thrown_matches_out_err(msg string, out_err string) bool {
	oe := out_err.trim_space()
	if oe == '' {
		return false
	}
	idx := oe.index('CXER') or { return msg.contains(oe) }
	mut code_tok := 'CXER'
	mut i := idx + 4
	for i < oe.len && oe[i] >= `0` && oe[i] <= `9` {
		code_tok += oe[i].ascii_str()
		i++
	}
	return msg.contains(code_tok)
}

// R3.12: the discriminator that closes the false-green — a thrown error only
// satisfies an out-err case when its message carries the expected CXER code.
fn test_r312_thrown_error_must_match_out_err() {
	// match: the thrown message carries the expected code
	assert thrown_matches_out_err('eval: no arm matched cx-err:CXER0100 at …', 'cx-err:CXER0100')
	// MISMATCH: a different thrown code must NOT pass a CXER0100 case
	assert !thrown_matches_out_err('boom cx-err:CXER0271 caps', 'cx-err:CXER0100')
	// a throw with no code text must not pass a coded case
	assert !thrown_matches_out_err('generic panic, no code', 'cx-err:CXER0100')
	// no-CXER fixture: fall back to whole-string containment
	assert thrown_matches_out_err('some boundary text here', 'boundary text')
	assert !thrown_matches_out_err('unrelated', 'boundary text')
	// empty expectation never matches a throw
	assert !thrown_matches_out_err('anything', '')
}

// ── End-to-end fixture-evaluation test ───────────────────────────────────────
//
// Runs EVERY fixture in conformance/code.txt through parse → eval, and
// compares the result against the fixture's declared output. There is no
// whitelist: a fixture that is spec-inconsistent or depends on an
// unimplemented feature / absent module FAILS the gate until fixed.
//
// Comparison is shape-based: the actual result is rendered via
// code.render_canonical — the ONE §11.1a EV-RESULT-IMAGE owner
// (stream 22 W1) — then compared to the fixture's out_text /
// out_multiset / out_err (whitespace-normalised).

fn fixture_path_eval() string {
	return os.real_path(os.join_path(os.dir(@FILE), '..', '..', 'conformance', 'code.cxd'))
}

// Fixture code reads repo files by repo-root-relative path (xap-dist's
// registry/store, packages/gtin/…, market/*.feature.cxd), so the repo
// root is pinned as the process CWD once for the whole file — the same
// [?lib]-resolution contract test_package_fixtures states. Without this the
// eight path-consuming xap-dist cases fail from any other invoking CWD (#377).
fn testsuite_begin() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	os.chdir(root) or { panic('cannot chdir to repo root ${root}: ${err}') }
}

struct ParsedFixture {
	id           string
	in_cx        string
	in_code      string
	out_text     string
	out_multiset string // comma-separated multiset matcher for :par-unordered fixtures
	out_effects  string // ordered effect-point trace (stream 22 W1 — capability:resource per line)
	has_out_effects bool // section DECLARED (an empty declared trace asserts zero admissions)
	out_err      string
	gate         string   // per-case gate toggle: enforced|advisory|pending|skip ('' = unset)
	grant        string   // Effort B least-privilege grant: space-separated capability list ('none' = EMPTY set, PYE-3; '' = host default)
	argv         string   // program argv to install before eval (#926 PYE-2): space-separated, argv[0] included ('' = none)
	tol          f64      // relative float tolerance for out_text match (0 = exact)
	level        string   // family label: core|resilience|async|visualization|…
	tags         []string // case tags (e.g. 'strict-mode' enables --strict typing)
}

// CX-native: read code.cxd via fixtures.load_fixtures (replaces the inline
// '=== test:' scanner + extract_section + strip_format_fences). The
// doc-example template and fence handling are done by the converter; the
// section-body clamp the old extract_section applied is baked into the .cxd.
fn parse_all_fixtures() []ParsedFixture {
	mut out := []ParsedFixture{}
	for c in fixtures.load_fixtures(fixture_path_eval()) {
		out << parsed_from(c)
	}
	return out
}

fn parsed_from(c fixtures.FixtureCase) ParsedFixture {
	return ParsedFixture{
		id:           c.name
		in_cx:        clamp_section(c.sections['in_cx'])
		in_code:      clamp_section(c.sections['in_code'])
		out_text:     clamp_section(c.sections['out_text'])
		out_multiset: clamp_section(c.sections['out_multiset'])
		out_effects:  clamp_section(c.sections['out_effects'])
		has_out_effects: 'out_effects' in c.sections
		out_err:      clamp_section(c.sections['out_err'])
		gate:         c.gate
		grant:        c.grant
		argv:         c.argv
		tol:          c.tol
		level:        c.level
		tags:         c.tags
	}
}

// clamp_section reproduces the former extract_section end-detection, applied
// to the loader's (already section-bounded) byte-exact body. A section's text
// ends at the first of: a bare `---` line or `--- \n` (legacy section-end /
// horizontal-rule marker the converter does NOT split on), or a
// blank-line-then-comment boundary (`\n\n#` inter-test heading mis-captured
// into the last section). This clamp is consumer-specific (eval) and lives
// here, not in the shared loader (conformance_run never clamped).
fn clamp_section(s string) string {
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

// (The former harness-local render_value/quote helper family is
// RETIRED — stream 22 W1: the §11.1a EV-RESULT-IMAGE has ONE owner,
// code.render_canonical (vcx/code/render.v), and both grading paths
// call it directly. A second mirror renderer here was the
// reference-impl-becomes-spec trap in miniature.)

// quote_only_diff reports whether `got` and `exp` differ ONLY by string-
// quoting (the render_value→render_canonical convention shift): strip every
// `'`/`"` and whitespace-normalise both; equal-but-not-identical means the
// sole difference is quote marks. Used to gate the CX_BLESS re-derivation so a
// genuine structural/value change is never silently adopted.
fn quote_only_diff(got string, exp string) bool {
	if got == exp {
		return false
	}
	g := got.replace("'", '').replace('"', '').fields().join(' ')
	e := exp.replace("'", '').replace('"', '').fields().join(' ')
	return g == e
}

// bless_emit appends a re-derived expected-output record for the offline
// rewriter (scripts/apply_blesses.cx). Marker-delimited to survive multi-line
// values without JSON escaping.
fn bless_emit(file string, id string, new_text string) {
	mut fh := os.open_append('/tmp/cx_blesses.txt') or { return }
	fh.write_string('<<<BLESS file=${file} id=${id}>>>\n${new_text}\n<<<ENDBLESS>>>\n') or {}
	fh.close()
}

fn test_all_code_fixtures_evaluate() {
	bless := os.getenv('CX_BLESS') == '1'
	// I1 epoch re-bless: DISARMED in normal builds (register R3.9) — the
	// epoch is closed; adopting every enforced out-text mismatch now takes
	// an explicit `-d cx_epoch_bless` compile AND CX_BLESS=epoch.
	mut epoch := false
	$if cx_epoch_bless ? {
		epoch = os.getenv('CX_BLESS') == 'epoch'
	} $else {
		assert os.getenv('CX_BLESS') != 'epoch', 'CX_BLESS=epoch REFUSED: the I1 epoch is closed; a re-bless build requires explicit -d cx_epoch_bless (register R3.9)'
	}
	// Runs EVERY fixture in conformance/code.txt end-to-end (parse -> eval
	// -> render) against the fixture's OWN declared output (out_err /
	// out_multiset / out_text). NO whitelist and NO test-side overrides:
	// a new fixture is covered the moment it lands, and any fixture that
	// is spec-inconsistent or depends on an unimplemented feature / absent
	// module FAILS this gate until it is made spec-consistent. The
	// fixture's declared output is the spec-expected output.
	all := parse_all_fixtures()
	mut ran := 0
	mut failures := []string{}
	mut adv_ids := map[string]bool{}
	mut pending := []string{}
	for f in all {
		if f.in_code.trim_space() == '' { continue
		 } // section/header rows carry no program
		// `level=visualization` fixtures are RENDER-spec, not eval: their
		// out-text is the structure recovered by rendering to a diagram and
		// reverse-parsing it (§11.6 gate 9), not an evaluation result. They are
		// validated by code_diagram_roundtrip_test.v (mermaid/svg/png round-trip).
		// Evaluating them here is the wrong harness — skip.
		if f.level == 'visualization' { continue
		 }
		// Per-case `gate=pending`: a fixture explicitly deferred with a
		// documented reason (e.g. an unbuilt tier-3 surface, or a test of
		// an internal-only invariant unreachable from conformant user
		// code). Tracked, not silently whitelisted — the case carries its
		// reason inline. Excluded from the enforced assertion until the
		// gate is flipped back to enforced.
		if f.gate == 'pending' {
			pending << f.id
			continue
		}
		ran++
		// Per-case `gate=advisory` (the TDD expected-red state, SAP migration):
		// the fixture RUNS and a failure is REPORTED but does NOT block the
		// gate — flipped to enforced when its impl lands. Partitioned at the
		// end of the loop by this id->advisory map (mirrors the stdlib runner).
		adv_ids[f.id] = f.gate == 'advisory'
		mut env := code.new_env()
		// #701: fixture module sources register EXPLICITLY per-env — the
		// production constructor no longer seeds them (they shadowed user
		// files; pin = module_loader_shadowing_test.v).
		code.register_conformance_test_modules(mut env.state.module_table)
		// A `strict-mode`-tagged fixture runs under --strict type
		// validation (§12.7: CXER0206/0207). Default fixtures erase
		// `::T` / `[returns T]` annotations.
		if 'strict-mode' in f.tags {
			env.state.strict = true
		}
		if f.in_cx != '' && f.in_cx != '[ignored]' && f.in_cx != '[empty]' {
			if doc := cx.parse(f.in_cx) {
				for i in 0 .. doc.elements.len {
					n := doc.elements[i]
					if n is cx.Element {
						env.bindings['doc'] = n
						env.bindings['input'] = n
						break
					}
				}
			}
		}
		// Capability-set injection (security.md §3, Effort A/B). An
		// explicit per-fixture `grant=` is the Effort B least-privilege
		// set (the stream-6 command fixtures need it: cmd-002 proves the
		// [effects] NARROWING denies a capability the host DID grant —
		// running it under the empty set would be a false green for the
		// wrong denial). Otherwise: CXER0271-expecting cases run empty,
		// behavior cases run under the full grant.
		if f.grant == 'none' {
			// PYE-3 (#926): a BEHAVIOR case pinned to the EMPTY set — proves
			// the exercised surface is ungated (argv/parse-args).
			code.caps_set_empty()
		} else if f.grant != '' {
			code.caps_set_list(f.grant.split_any(' \t,').filter(it != '')) or {
				assert false, 'fixture grant= refused (#713 loud unknown-cap): ${err.msg()}'
			}
		} else if f.out_err.contains('CXER0271') {
			code.caps_set_empty()
		} else {
			code.caps_set_all()
		}
		// Program argv (#926, PYE-2): install the fixture-declared vector
		// (argv[0] included) before eval; clear back to the host fallback
		// otherwise so a prior case's vector never leaks.
		code.set_program_argv(f.argv.split_any(' \t').filter(it != ''))
		prog := cx.parse_program(f.in_code) or {
			if f.out_err != '' {
				if !thrown_matches_out_err(err.msg(), f.out_err) {
					failures << '${f.id}: parse threw "${err.msg()}" but expected ${f.out_err} (R3.12)'
				}
				continue
			}
			failures << '${f.id}: parse: ${err}'
			continue
		}
		mut result := code.eval(prog.body, mut env) or {
			if f.out_err != '' {
				if !thrown_matches_out_err(err.msg(), f.out_err) {
					failures << '${f.id}: eval threw "${err.msg()}" but expected ${f.out_err} (R3.12)'
				}
							// out-effects grades on the THROWN path too (stream 14, the
			// audit note): effects admitted BEFORE the throw are part of
			// the witness — skipping the trace here read as covered when
			// it never graded.
			if f.has_out_effects {
				got_trace2 := code.effects_trace_snapshot().join('\n')
				exp_trace2 := f.out_effects.trim_space()
				if got_trace2 != exp_trace2 {
					failures << '${f.id}: effect-trace mismatch (thrown path)\n  got:      ${got_trace2}\n  expected: ${exp_trace2}'
				}
			}
			
			continue
			}
			failures << '${f.id}: eval: ${err}'
			continue
		}
		// EV-PULL: the runner IS a result boundary — force with env alive.
		result = code.force_lazy_result(result, mut env)
		// Serialization boundary: a function value reaching the program
		// result is not data-serialisable — CXER0291 (§8.6), mirroring
		// code.render()'s guard.
		if code.is_fn_value(result) {
			if f.out_err != '' {
				if !f.out_err.contains('CXER0291') {
					failures << '${f.id}: expected ${f.out_err}, got function value (CXER0291)'
				}
			} else {
				failures << '${f.id}: function value not serialisable (CXER0291), expected ${f.out_text.trim_space()}'
			}
			continue
		}
		rendered := code.render_canonical(result).trim_space()
		if f.out_err != '' {
			if !rendered.contains(f.out_err) {
				failures << '${f.id}: expected ${f.out_err}, got ${rendered}'
			}
		} else if f.out_multiset != '' {
			if !same_multiset(rendered, f.out_multiset.trim_space()) {
				failures << '${f.id}: multiset mismatch\n  got:      ${rendered}\n  expected: ${f.out_multiset.trim_space()} (as multiset)'
			}
		} else {
			exp := f.out_text.trim_space()
			if !same_shape(rendered, exp) {
				if (bless && quote_only_diff(rendered, exp)) || epoch {
					bless_emit('code.cxd', f.id, rendered)
				} else {
					failures << '${f.id}: shape mismatch\n  got:      ${rendered}\n  expected: ${exp}'
				}
			}
		}
		// out-effects: the ordered admitted-effect-point trace (stream
		// 22 W1) — graded IN ADDITION to the value channel; the trace
		// is exact (order AND count), one `capability:resource` line
		// per admitted effect point.
		if f.has_out_effects {
			// A DECLARED-but-empty section asserts ZERO admissions —
			// the undeclared-effect-never-exercised witness shape.
			got_trace := code.effects_trace_snapshot().join('\n')
			exp_trace := f.out_effects.trim_space()
			if got_trace != exp_trace {
				failures << '${f.id}: effect-trace mismatch\n  got:      ${got_trace}\n  expected: ${exp_trace}'
			}
		}
	}
	// Partition failures by per-case gate: `advisory` cases (the SAP migration's
	// TDD expected-red frontier) are reported but NOT blocking; everything else
	// is enforced. Mirrors the stdlib runner's adv_ids partition.
	mut enforced := []string{}
	mut advisory := []string{}
	for fl in failures {
		if adv_ids[fl.all_before(': ')] {
			advisory << fl
		} else {
			enforced << fl
		}
	}
	if advisory.len > 0 {
		eprintln('${advisory.len} advisory code.cxd fixture failure(s) of ${ran} — spec-first frontier (unimplemented), reported not blocking:')
		for fl in advisory {
			eprintln('  ${fl}')
		}
	}
	if enforced.len > 0 {
		eprintln('${enforced.len} ENFORCED code.cxd fixture failure(s) of ${ran} run:')
		for fl in enforced {
			eprintln('  ${fl}')
		}
	}
	if pending.len > 0 {
		eprintln('${pending.len} fixture(s) gate=pending (tracked, not enforced): ${pending.join(', ')}')
	}
	assert ran > 0, 'no fixtures ran'
	if !bless && !epoch {
		assert enforced.len == 0
	}
}

// parse_fixtures_in parses a fixtures file at an arbitrary path (same
// format as conformance/code.txt). Used by the per-module stdlib
// conformance auto-runner.
fn parse_fixtures_in(path string) []ParsedFixture {
	if !os.exists(path) {
		return []
	}
	mut out := []ParsedFixture{}
	for c in fixtures.load_fixtures(path) {
		out << parsed_from(c)
	}
	return out
}

// test_stdlib_module_fixtures auto-discovers every conformance/stdlib/*.txt
// file and runs ALL its fixtures end-to-end (no whitelist). Each
// cx-stdlib module owns one such file (its spec §6 conformance list),
// named for the module (e.g. conformance/stdlib/bytes.txt); the
// per-module isolation lets module implementations land in parallel
// without touching a shared whitelist. Runs clean (ran == 0) before the
// stdlib/ directory or any module file exists, so it is safe to land
// ahead of the modules.
// load_gate_policy reads conformance/gates.cxd and returns the module->gate
// map for the given suite PLUS the suite's default= tier (falling back to the
// [gate-policy] default=). Toggle: 'enforced' failures block the gate;
// 'advisory' failures are reported but do NOT block (spec-first frontier /
// unimplemented). Resolution order (the manifest's own header, #721):
//   per-case gate= > per-module entry > per-suite default > enforced
// A fixture that resolves to '' at every tier is enforced (deny-by-default,
// mirroring the capability grant model).
fn load_gate_policy(suite string) (map[string]string, string) {
	mut m := map[string]string{}
	mut suite_default := ''
	mut policy_default := ''
	path := os.real_path(os.join_path(os.dir(@FILE), '..', '..', 'conformance', 'gates.cxd'))
	src := os.read_file(path) or { return m, suite_default }
	doc := cx.parse(src) or { return m, suite_default }
	for node in doc.elements {
		if node is cx.Element {
			if node.name == 'gate-policy' {
				for a in node.attrs {
					if a.name == 'default' {
						policy_default = cx.scalar_value_str_public(a.value)
					}
				}
				for s in node.items {
					if s is cx.Element {
						if s.name == 'suite' {
							mut sname := ''
							mut sdefault := ''
							for a in s.attrs {
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
							for md in s.items {
								if md is cx.Element {
									if md.name == 'module' {
										mut mn := ''
										mut mg := ''
										for a in md.attrs {
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

fn test_stdlib_module_fixtures() {
	bless := os.getenv('CX_BLESS') == '1'
	// I1 epoch re-bless: DISARMED in normal builds (register R3.9) — the
	// epoch is closed; adopting every enforced out-text mismatch now takes
	// an explicit `-d cx_epoch_bless` compile AND CX_BLESS=epoch.
	mut epoch := false
	$if cx_epoch_bless ? {
		epoch = os.getenv('CX_BLESS') == 'epoch'
	} $else {
		assert os.getenv('CX_BLESS') != 'epoch', 'CX_BLESS=epoch REFUSED: the I1 epoch is closed; a re-bless build requires explicit -d cx_epoch_bless (register R3.9)'
	}
	dir := os.join_path(os.dir(fixture_path_eval()), 'stdlib')
	entries := os.ls(dir) or { return }
	mut files := []string{}
	for e in entries {
		if e.ends_with('.cxd') {
			files << e
		}
	}
	files.sort()
	mut ran := 0
	mut failures := []string{}
	// #1026 coverage accounting. The authz suite's 25 [out-err …] cases were
	// long ASSUMED green here because they showed red under the standalone
	// document runner (conformance_run.v), which has no evaluator and was
	// scoring them against a parse of their `[in-cx [empty]]` scaffolding.
	// "Presumably green" is what that issue objects to, so the lane now STATES
	// its coverage instead: which modules exercised the err channel, and how
	// many cases each contributed.
	mut out_err_ran := 0
	mut out_err_by_module := map[string]int{}
	module_gate, suite_default := load_gate_policy('stdlib')
	mut adv_ids := map[string]bool{}
	for fname in files {
		cases := parse_fixtures_in(os.join_path(dir, fname))
		for f in cases {
			// effective gate: per-case > per-module > per-suite default (>
			// enforced when every tier is '').
			mut eff_gate := if f.gate != '' { f.gate } else { module_gate[fname.all_before('.cxd')] }
			if eff_gate == '' {
				eff_gate = suite_default
			}
			if eff_gate == 'skip' || eff_gate == 'pending' {
				continue // excluded from the gate (not run)
			}
			ran++
			if f.out_err != '' {
				out_err_ran++
				out_err_by_module[fname.all_before('.cxd')]++
			}
			adv_ids['${fname}/${f.id}'] = eff_gate == 'advisory'
			mut env := code.new_env()
			// strict-tag parity (stream 14, the audit note): the stdlib and
			// package lanes honor 'strict-mode' exactly as the code.cxd lane
			// does — a tagged fixture must never silently run un-strict.
			if 'strict-mode' in f.tags {
				env.state.strict = true
			}
			code.register_conformance_test_modules(mut env.state.module_table) // #701
			if f.in_cx != '' && f.in_cx != '[empty]' {
				if doc := cx.parse(f.in_cx) {
					for i in 0 .. doc.elements.len {
						n := doc.elements[i]
						if n is cx.Element {
							env.bindings['doc'] = n
							env.bindings['input'] = n
							break
						}
					}
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
				// Effort B: explicit per-fixture least-privilege grant.
				code.caps_set_list(f.grant.split_any(' \t,').filter(it != '')) or {
					assert false, 'fixture [grant …] refused (#713 loud unknown-cap): ${err.msg()}'
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
					continue
				}
				failures << '${fname}/${f.id}: eval: ${err}'
				continue
			}
			// EV-PULL: force at the runner's result boundary.
			result = code.force_lazy_result(result, mut env)
			if f.out_err != '' {
				// Expected an err: accept a V-error (handled above) or an
				// err-value whose render carries the expected CXER code.
				if !code.render_canonical(result).contains(f.out_err) {
					failures << '${fname}/${f.id}: expected ${f.out_err}, got ${code.render_canonical(result)}'
				}
				continue
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
					if (bless && quote_only_diff(rendered, expected)) || (epoch && eff_gate != 'advisory') {
						bless_emit(fname, f.id, rendered)
					} else {
						failures << '${fname}/${f.id}: mismatch\n  got:      ${rendered}\n  expected: ${expected}'
					}
				}
			}
		}
	}
	// Partition failures by the per-module gate policy (conformance/gates.cxd):
	// 'advisory' modules are the spec-first frontier (unimplemented) — reported
	// but NOT blocking; everything else is enforced (deny-by-default).
	mut enforced := []string{}
	mut advisory := []string{}
	for fl in failures {
		if adv_ids[fl.all_before(': ')] {
			advisory << fl
		} else {
			enforced << fl
		}
	}
	if advisory.len > 0 {
		println('${advisory.len} advisory stdlib fixture failure(s) of ${ran} — frontier/unimplemented modules, reported not blocking.')
	}
	if enforced.len > 0 {
		println('${enforced.len} ENFORCED stdlib fixture failure(s) of ${ran}:')
		for fl in enforced {
			println('  ${fl}')
		}
	}
	// #1026: state the coverage rather than leaving it inferred. `ran` counting
	// up is the claim that these fixtures were EXECUTED here — the property the
	// document runner could not honestly make about them.
	mut err_mods := out_err_by_module.keys()
	err_mods.sort()
	mut err_parts := []string{}
	for m in err_mods {
		err_parts << '${m}=${out_err_by_module[m]}'
	}
	println('stdlib corpus: ${ran} fixtures ran across ${files.len} module file(s); ' +
		'${out_err_ran} exercised the [out-err …] channel — ${err_parts.join(' ')}')
	if files.len > 0 {
		// A corpus that discovers files but runs nothing is the vacuous-pass
		// shape this issue is about; refuse to call that green.
		assert ran > 0, 'stdlib corpus: ${files.len} module file(s) found but ZERO fixtures ran'
		assert out_err_ran > 0, 'stdlib corpus: no fixture exercised the [out-err …] channel — the negative lane is not running'
	}
	if !bless && !epoch {
		assert enforced.len == 0
	}
}

// test_package_fixtures runs every package's OWN acceptance corpus —
// packages/<name>/<name>.test.cxd (distribution spec §1: "acceptance fixtures
// (requirements are the tests)") — through the same engine as the stdlib
// corpus. Package fixtures import their code via a repo-root-relative
// [?lib './packages/<name>/…'] path, so this test pins the repo root as the
// process CWD (the [?lib] resolution contract for `cx <file>` run from the
// root). Gate policy comes from the 'packages' suite in conformance/gates.cxd,
// keyed by package directory name; absent = enforced (deny-by-default).
// Runs clean (ran == 0) before any package exists.
fn test_package_fixtures() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	dir := os.join_path(root, 'packages')
	entries := os.ls(dir) or { return }
	os.chdir(root) or { return }
	mut files := []string{}
	for e in entries {
		p := os.join_path(dir, e, '${e}.test.cxd')
		if os.exists(p) {
			files << p
		}
	}
	files.sort()
	mut ran := 0
	mut failures := []string{}
	module_gate, suite_default := load_gate_policy('packages')
	mut adv_ids := map[string]bool{}
	for path in files {
		pkg := os.base(os.dir(path))
		cases := parse_fixtures_in(path)
		for f in cases {
			mut eff_gate := if f.gate != '' { f.gate } else { module_gate[pkg] }
			if eff_gate == '' {
				eff_gate = suite_default
			}
			if eff_gate == 'skip' || eff_gate == 'pending' {
				continue
			}
			ran++
			adv_ids['${pkg}/${f.id}'] = eff_gate == 'advisory'
			mut env := code.new_env()
			// strict-tag parity (stream 14, the audit note): the stdlib and
			// package lanes honor 'strict-mode' exactly as the code.cxd lane
			// does — a tagged fixture must never silently run un-strict.
			if 'strict-mode' in f.tags {
				env.state.strict = true
			}
			code.register_conformance_test_modules(mut env.state.module_table) // #701
			if f.grant == 'none' {
				code.caps_set_empty() // PYE-3: ungated-surface behavior pin
			} else if f.grant != '' {
				code.caps_set_list(f.grant.split_any(' \t,').filter(it != '')) or {
					assert false, 'fixture [grant …] refused (#713 loud unknown-cap): ${err.msg()}'
				}
			} else if f.out_err.contains('CXER0271') {
				code.caps_set_empty()
			} else {
				code.caps_set_all()
			}
			code.set_program_argv(f.argv.split_any(' \t').filter(it != '')) // PYE-2
			prog := cx.parse_program(f.in_code) or {
				// a parse failure is NEVER an expected outcome for a package
				// fixture — even err cases must parse (the xap-compose M0
				// lesson: parse-as-pass masks authoring defects).
				failures << '${pkg}/${f.id}: parse: ${err}'
				continue
			}
			result := code.eval(prog.body, mut env) or {
				if f.out_err != '' {
					if !thrown_matches_out_err(err.msg(), f.out_err) {
						failures << '${pkg}/${f.id}: eval threw "${err.msg()}" but expected ${f.out_err} (R3.12)'
					}
					continue
				}
				failures << '${pkg}/${f.id}: eval: ${err}'
				continue
			}
			if f.out_err != '' {
				if !code.render_canonical(result).contains(f.out_err) {
					failures << '${pkg}/${f.id}: expected ${f.out_err}, got ${code.render_canonical(result)}'
				}
				continue
			}
			rendered := code.render_canonical(result).trim_space()
			expected := f.out_text.trim_space()
			if !same_shape(rendered, expected) {
				failures << '${pkg}/${f.id}: mismatch\n  got:      ${rendered}\n  expected: ${expected}'
			}
		}
	}
	mut enforced := []string{}
	mut advisory := []string{}
	for fl in failures {
		if adv_ids[fl.all_before(': ')] {
			advisory << fl
		} else {
			enforced << fl
		}
	}
	if advisory.len > 0 {
		println('${advisory.len} advisory package fixture failure(s) of ${ran} — frontier, reported not blocking.')
	}
	if enforced.len > 0 {
		println('${enforced.len} ENFORCED package fixture failure(s) of ${ran}:')
		for fl in enforced {
			println('  ${fl}')
		}
	}
	assert enforced.len == 0
}

// same_shape compares two render outputs ignoring whitespace
// differences (lines, multi-space, leading/trailing). Both must have
// the same nonblank tokens in the same order.
fn same_shape(a string, b string) bool {
	at := a.fields()
	bt := b.fields()
	if at.len != bt.len { return false }
	for i, t in at {
		if t != bt[i] { return false }
	}
	return true
}

// same_multiset compares two render outputs as multisets
// D11 — used for fixtures where emission order is genuinely
// non-deterministic but membership IS contracted (the [?test-concurrent]
// scaffold class; [par] output is SOURCE order always since L105 and no
// longer needs this comparator). Parses both sides
// by stripping outer `()` parens + splitting on `,` (handling the CX
// sequence-literal render shape `(a, b, c)`), trims items, sorts both
// sides, compares element-by-element. Asserts that the multiset of
// items is identical, irrespective of emission order.
fn same_multiset(a string, b string) bool {
	mut ai := multiset_items(a)
	mut bi := multiset_items(b)
	if ai.len != bi.len { return false }
	ai.sort()
	bi.sort()
	for i, t in ai {
		if t != bi[i] { return false }
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
		if t != '' { items << t }
	}
	return items
}
