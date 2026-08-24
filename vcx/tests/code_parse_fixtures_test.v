module main

import code
import platform as _
import cx
import fixtures
import os

// ── End-to-end fixture-parsing test ──────────────────────────────────────────
//
// Reads conformance/code.txt, extracts every fixture's `in_code` block,
// and runs the program parser over it. This is gate-4 evidence at
// parser granularity (the V evaluator-level gate-4 requires the full
// interpreter).
//
// The conformance file uses a `=== test: ID` header per fixture; the
// in_code block is delimited by `--- in_code\n...\n--- <next>` or
// end-of-fixture. Block-content rules match scripts/check_code_fixtures.py.
//
// Fixtures that exercise grammar genuinely outside the CX program
// surface (currently: the labeled-element form `[name :slot value]`
// documented in spec/code.md §7 examples but not in spec/grammar.ebnf
// — see the parser commit message) are listed in
// `expected_parse_failures`. Any fixture not in that list that fails
// to parse is a test failure.

// Genuine spec / grammar gaps surfaced by the fixture corpus and to be
// resolved by spec amendment or follow-up parser work — see
// spec/v0_8_0_status.md for the open list. Listing them here keeps the
// regression gate honest while the items are open.
const expected_parse_failures = [
	// RULED: MSS-3 + MSS-4 (#917): four deliberate PARSE rejections — the
	// map-syntax settlement's refuse-never-invent pins (unknown declaration
	// kind, spaced glue after a key, checked key ascription, and the
	// program error surfacing instead of the silent data-fallback mangle).
	// Each carries an out-err pin in the eval runner.
	'program-map-103-mss4-unknown-kind-refuses',
	// #923 (RULED: BC-1): a /-bearing bare attr-value run whose prefix is
	// not a path head refuses LOUD with the quote-the-value hint at PARSE
	// (the eval runner pins the out-err).
	'program-attr-bare-003-slash-run-refuses-loud',
	// #920: literal dup keys refuse at PARSE in the program reading too
	// (W014 parity; the eval runner pins the out-err).
	'program-map-109-dupkey-parity-refuses',
	// MSS-7: a kind-only tag with a value refuses at parse.
	'program-map-113-mss7-kind-with-value-refuses',
	'program-map-104-mss3-spaced-glue-refuses',
	'program-map-106-mss3-key-ascription-checked',
	'program-map-107-mss3-fallback-hatch-closed',
	// CXP-1 (2026-08-20): the [?cx] pragma key set is a CLOSED registry;
	// this fixture deliberately pins the unknown-key refusal, so its
	// in-code payload MUST fail to parse.
	'program-cx-pi-003-unknown-cx-key-refused',
	// #820 (RULED: 820-1a): the `cx:` namespace is reserved for the
	// serializer's canonical image, so a `cx:`-prefixed element head is a
	// PARSE rejection (E210, wrapped CXER0100) in both readings — a
	// grounded negative, enforced via the eval runner's out_err path.
	'program-reserved-ns-001-cx-head-refused',
	// The four CXPath grounded negatives, registered when the stale
	// `program-cxpath-` entry left pending_phase2_impl_prefixes below:
	// that prefix blanket-SKIPPED every CXPath fixture in this gate as
	// "pending Phase 2 V impl" long after CXPath shipped, so the whole
	// family was unchecked here. Each of these four is a deliberate parse
	// rejection with an out-err pin, not a gap.
	//   [?find] is RETIRED from the §4.1 registry:
	'program-cxpath-010-retired-find-raises-error',
	//   #472: a GLUED attribute tail on a ROOTED path is rejected —
	//   `…/name/@attr` is the rooted spelling; the glued form is
	//   $-binding-path surface only ([135a]):
	'program-cxpath-attr-tail-003-glued-rooted-tail-rejected',
	'program-cxpath-attr-tail-004-glued-rooted-tail-no-predicate-rejected',
	//   #809: only the four [131b] names take the `()` NodeTest form:
	'program-cxpath-kindtest-011-unknown-kind-test-refused',
	// #466 attribute ascription: attributes are scalar-only (D2), so an
	// array annotation `name::T[]=…` in attribute position is a PARSE
	// rejection (CXER0100) in both readings — a grounded negative,
	// enforced via the eval runner's out_err path.
	'program-attr-ascription-007-array-type-err',
	// SAP errors/effects/fp migration: infix `|` is RETIRED (code.md §6.4/§8.9);
	// `5 | [$add1]` is now a parse error (CXER0100) — a grounded negative, so it
	// legitimately fails to parse and is enforced via the eval runner's out_err
	// path.
	'program-sap-pipe-03-infix-removed',
	// SAP C3c: [?try]/[catch]/[on-error] are RETIRED (code.md §8.8 tombstone /
	// §9.3); both negatives pin the CXER0100 rejection and are enforced via
	// the eval runner's out_err path.
	'program-sap-try-01-removed-negative',
	'program-sap-try-02-on-error-removed-negative',
	// Generator-family reshape (C-gen-1): infix range `to`/`by` is RETIRED;
	// ranges are the prefix builtin [$range lo hi step?]. These negatives pin
	// the CXER0100 parse rejection (enforced via the eval runner's out_err path).
	'program-gen-no-infix-001-to',
	'program-gen-no-infix-002-by',
	'program-gen-no-infix-003-to-star',
	// Open-end `*` is legal ONLY as range's hi argument ([125d/e]); in any other
	// position it is a parse error (enforced via the eval runner's out_err path).
	'program-gen-range-illegal-001-star-lo',
	'program-gen-range-illegal-002-star-stride',
	'program-gen-range-illegal-003-star-general-arg',
	// v0.8.0 atom semantic features pending Phase 2 V impl:
	// - 006: reserved-name (`:true`/`:false`/`:null`) lex-time rejection
	// not yet implemented; lexer accepts the token
	//   instead of raising CXER0100.
	// (003/004/005 atom-equality fixtures now parse cleanly after the
	// `[= :a :b]` homoiconic-comparison reshape — removed from this list.)
	'program-atom-006-reserved-true-parse-error',
	// #397 dotted atoms: a DETACHED dot (whitespace either side) is not a
	// segment continuation — `:order . placed` rejects at parse time with
	// CXER0100 (enforced via the eval runner's out_err path).
	'program-atom-018-detached-dot-not-a-continuation',
	// program-map-005 verifies that removed [?par-map] raises
	// CXER0100 at parse time (unknown directive). program-map-004 and
	// program-reduce-003 also raise CXER0100 but at eval time (the slot
	// parses cleanly; eval_map_directive / eval_reduce_directive reject
	// the flag combination), so they're handled by the eval fixture
	// runner's out_err path and don't appear here.
	'program-map-005-par-map-removed',
	// Wave 0 — block-scoping directives reject an empty body at parse
	// time with CXER0100.
	'program-with-open-005-empty-body-parse-error',
	'program-with-scope-005-empty-body-parse-error',
	// (#66: [?str] holes now accept full expressions — the former call-hole /
	// non-path-hole parse-rejection fixtures are retired; a computed hole parses
	// and evaluates, a non-scalar hole errors at EVAL, not parse.)
	// D21 step-of-zero: a slice axis with a LITERAL `0` step now rejects at
	// PARSE time (CXER0100), converging the impl to the formal contract
	// (grammar.ebnf GR-SLICE-STEP-ZERO) and D21's stated parse-time intent.
	// The fixture's out-err CXER0100 is still satisfied (the eval runner
	// accepts a parse-time CXER0100); a COMPUTED zero step keeps the eval-time
	// D21 check. See vcx/tests/slice_step_zero_test.v.
	'program-slice-013-step-zero',
	// #776 (stream 11 §3/§10): a hex token under an exact-kind postfix
	// ascription rejects at PARSE time (the #466 item-3 rule carried to
	// the program reading; message carries CXER0290, code CXER0100 —
	// the eval runner's out_err path accepts the parse-time raise).
	'program-ascription-002-hex-under-exact-refused',
	// #421: an unknown `[?name]` head stays fail-closed (CXER0100,
	// unknown_directive program intent — code.md §1.3 class 1). The `[?cx …]`
	// PI/config namespace is the carve-out (grammar [34]/[59a]: NOT a §4.1
	// directive) and parses via the node_lit DATA↔PROGRAM seam; this negative
	// pins that the carve-out did not loosen the registry for other heads.
	'program-cx-pi-004-unknown-directive-fails-closed',
	// Stream 13 L55 (I1): the registry's only alias [?chain] is RETIRED
	// (unknown directive, CXER0100) and the takewhile/dropwhile clause
	// spellings are RENAMED take-while/drop-while (old spellings
	// tombstone-error at parse). Grounded negatives, enforced via the
	// eval runner's out_err path.
	'program-iterator-chain-001',
	'program-for-takewhile-003-retired-spelling-negative',
	'program-for-dropwhile-003-retired-spelling-negative',
	// U1.1a / #763 (stream-2 W2): the [?for] lazy hint is RENAMED
	// [stream] → [lazy] ('stream' is the delivery concept's name). The
	// old spelling tombstone-errors at parse; [lazy] + a materialising
	// barrier ([order-by]/[group-by]) refuses at parse per §7.4.
	// Grounded negatives, enforced via the eval runner's out_err path.
	'program-for-lazy-002-stream-retired-spelling-negative',
	'program-for-lazy-003-materialiser-combine-negative',
	// #478: a DYNAMIC attribute value on a `[table[…]]` element literal
	// rejects at PARSE time (CXER0100 — the tabular form is data-only and
	// rides the data-reader seam, which cannot carry `$x`). Grounded
	// negative, enforced via the eval runner's out_err path.
	'program-table-478-002-attrs-dynamic-err',
	// #484: a headless glued `[table[` opener (anonymous table — grammar
	// [50]'s tabular alternative requires a Name) rejects at PARSE time
	// (CXER0100) in BOTH readings: the program lane delegates the span to
	// the data reader, which raises the outside-ElementMeta-position
	// error. Grounded negative, enforced via the eval runner's out_err
	// path.
	'program-table-484-002-misplaced-opener-err',
	// RULED CRS-1 + PS-1 (#862/#886): explicit `axis::` steps on a call /
	// directive RESULT reject at PARSE time with the BP-1 diagnostic
	// (grammar [135a] MUST-reject). Grounded negatives, enforced via the
	// eval runner's out_err path. (The CRS-1 case shipped without this
	// registration — the lane was red at the PS-1 baseline; trued here.)
	'program-callstep-004-axis-on-call-result-refused',
	'program-callstep-012-axis-on-directive-result-refused',
]

// v0.8.0 fixtures whose parser support is gated on Phase 2 V impl.
// Each prefix below matches fixtures shipped in conformance/code.txt as
// NOT_YET_IMPLEMENTED (per the in-file preambles); they MUST be skipped
// by this static parse gate until the corresponding parser lands.
// As each parser comes online, remove its prefix from this list —
// the test then naturally tracks Phase 2 progress.
//
// Coverage of pending prefixes:
// program-cxpath-* (CXPath as value kind)
// program-match-multi-* (multi-arm match)
// program-modify-* + 0031 ([?modify])
// program-def-* ([?def] module functions)
// program-const-* ([?const])
// program-lib-* ([?lib])
// module-* module-system fixtures
// program-atom-* (atom; some predicates use
// CXPath axes which need)
//   program-builtin-*          — selected entries gated on CXPath
//   program-element-*          — selected entries gated on CXPath
//   program-render-*           — selected entries gated on CXPath
// pred-* ([expr] general predicate)
const pending_phase2_impl_prefixes = [
	'program-match-multi-',
	'program-modify-',
	'program-def-',
	'program-const-',
	'program-lib-',
	'module-',
	'pred-',
	// strided ranges / slices / comprehensions / views — the
	// `-wN-` deferred wave; parser surface
	// lands post-promotion. Covers slice-w1..w4, range-w5, for-w6/w7, view-w8.
	'program-slice-w',
	'program-range-w',
	'program-for-w',
	'program-view-w',
	// element-head type-annotation `[name::T[] …]` ([26], §3.7) in
	// program-expression position is not yet parsed (the program parser
	// treats `::` as an axis specifier); the CXER0107 unknown-TypeName
	// fixture exercising it is pending that parser+eval path. (Provisional
	// impl-verify fixture — surface to be confirmed when the path lands.)
	'program-element-typed-array-',
]

fn is_pending_phase2_impl(id string) bool {
	for prefix in pending_phase2_impl_prefixes {
		if id.starts_with(prefix) {
			return true
		}
	}
	return false
}

// Fixture-only test helpers (parsed as plain ident calls by the V
// parser — they appear in conformance fixtures but not in spec/code.md
// §4.1 registry). The parser correctly parses them as zero-arity or
// slot-bearing calls; the dispatcher at evaluation time recognises
// them per the fixture-format extension in conformance/code.txt §Format.
//
// We list them here for documentation only; they don't affect parsing.

fn fixture_path() string {
	return os.real_path(os.join_path(os.dir(@FILE), '..', '..',
		'conformance', 'code.cxd'))
}

struct Fixture {
	id     string
	in_code string
	gate    string // per-case gate toggle (enforced|advisory|pending|skip; '' = enforced)
}

// CX-native: read the .cxd suite via fixtures.load_fixtures. The doc-example
// `=== test: <test-id>` template (formerly stripped here via strip_fences) is
// already excluded by the converter, so no fence handling is needed; fixtures
// without an in_code section are skipped, as before.
fn read_fixtures() []Fixture {
	mut out := []Fixture{}
	for c in fixtures.load_fixtures(fixture_path()) {
		if 'in_code' !in c.sections {
			continue
		}
		out << Fixture{ id: c.name, in_code: c.sections['in_code'], gate: c.gate }
	}
	return out
}

// Wrap helper names so the parser accepts them as zero-arity calls.
// Helpers are not in §4.1 registry — they look like ordinary ident
// invocations to the parser, which is the intended behavior. No
// special handling needed.

fn is_expected_failure(id string) bool {
	for f in expected_parse_failures {
		if f == id {
			return true
		}
	}
	return false
}

fn test_every_fixture_in_code_parses() {
	cases := read_fixtures()
	assert cases.len > 100, 'expected many fixtures, got ${cases.len}'
	mut failures := []string{}
	mut expected_pass := 0
	mut expected_fail_actually_passed := []string{}
	mut pending_phase2_skipped := 0
	for f in cases {
		// Skip fixtures gated on Phase 2 V impl (per
		// pending_phase2_impl_prefixes). When their parser lands,
		// remove the prefix from the list — this test then naturally
		// tracks Phase 2 progress.
		if is_pending_phase2_impl(f.id) {
			pending_phase2_skipped++
			continue
		}
		// gate=advisory / gate=pending fixtures are the spec-first TDD frontier
		// (SAP migration): their PROPOSED surface (e.g. `::T` typed binds,
		// `@code=$c` attr capture, map/array-literal patterns, `[tap]`) is not yet
		// grammar-supported, so a parse failure is the EXPECTED red — not a test
		// failure. They flip to enforced (and must then parse) as the impl lands.
		if f.gate == 'advisory' || f.gate == 'pending' {
			pending_phase2_skipped++
			continue
		}
		// Some fixtures use the labeled-element form `[name :slot v]`
		// in handler bodies which is documented in spec examples but
		// not in current grammar. Tracked via expected_parse_failures.
		_ := cx.parse_program(f.in_code) or {
			if is_expected_failure(f.id) {
				continue
			}
			failures << '${f.id}: ${err.msg()}'
			continue
		}
		if is_expected_failure(f.id) {
			expected_fail_actually_passed << f.id
		}
		expected_pass++
	}
	if pending_phase2_skipped > 0 {
		println('  ${pending_phase2_skipped} fixtures skipped (pending Phase 2 V impl per pending_phase2_impl_prefixes)')
	}
	if failures.len > 0 {
		println('Unexpected parse failures (${failures.len}):')
		for fl in failures {
			println('  ${fl}')
		}
	}
	if expected_fail_actually_passed.len > 0 {
		println('Fixtures listed as expected-failure but actually parse cleanly:')
		for id in expected_fail_actually_passed {
			println('  ${id}')
		}
	}
	assert failures.len == 0
	assert expected_fail_actually_passed.len == 0
	println('Parser handles ${expected_pass} fixtures cleanly.')
}
