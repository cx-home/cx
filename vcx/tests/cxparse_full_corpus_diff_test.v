module main

import code
import platform as _
import cx
import fixtures
import hash.fnv1a
import os

// cxparse_full_corpus_diff_test — Phase 0 of the cxparse unification
// (spec/02-inprogress/cxparse_unification_PLAN.md).
//
// The comprehensive DIFFERENTIAL ORACLE: it diffs the two CURRENT parsers
// (cx.parse data path vs code.parse program path) over EVERY `in-cx` data
// input in the whole conformance corpus — not the ~50 hand-picked items in
// parser_parity_test.v. This is the safety net Phase 1+ diffs the unified
// parser against: once the agreement set is locked here, any structural
// drift introduced while merging the parsers fails this gate immediately.
//
// SUBSTRATE (identical to parser_parity_test.v): both sides reduce to a
// `cx.Node` rendered through the SAME canonical renderer, so a mismatch is a
// genuine structural divergence, not an emitter artifact.
//   cx side:   cx.parse(src).elements[0]               (data parser)
//   code side: code.program_parse_to_typed_node(src)   (program parser → eval;
//              for pure DATA, eval is identity, so this reflects code.parse's
//              structure)
//
// BUCKETS (every `in-cx` input lands in exactly one):
//   agree       both accept a single element and render identically  → the locked baseline
//   diverge     both accept a single element but render differently   → must match KNOWN list or FAIL
//   cx_only     cx parses 1 element; code rejects                     → data-only surface (XML/DTD/md/table/…)
//   code_only   code accepts; cx rejects                              → (expected ~0)
//   multi       cx yields ≠1 top-level element (multi-doc/prolog)      → not a single-element comparison
//   both_reject neither yields a comparable single element            → header/sentinel rows
//
// Phase 0 = MEASURE then LOCK. The first run reports the catalog; the
// `known_diverge` list below is then frozen to it, so the gate fails on any
// NEW divergence (a real Phase-1 regression) while tolerating the
// already-understood ones (SEQ-NEST + operator-head eval-confound).

fn conformance_dir() string {
	return os.real_path(os.join_path(os.dir(@FILE), '..', '..', 'conformance'))
}

// diff_cx_canon renders src via the cx DATA parser, or a sentinel.
fn diff_cx_canon(src string) string {
	doc := cx.parse(src) or { return 'REJECT' }
	if doc.elements.len != 1 {
		return 'MULTI'
	}
	return code.render_canonical(doc.elements[0])
}

// diff_code_canon renders src via the PROGRAM parser (+eval), or REJECT.
fn diff_code_canon(src string) string {
	n := code.program_parse_to_typed_node(src) or { return 'REJECT' }
	return code.render_canonical(n)
}

struct DiffRow {
	suite string
	name  string
	src   string
	cx    string
	code  string
}

fn test_full_corpus_data_differential() {
	files := os.ls(conformance_dir()) or {
		assert false, 'cannot list conformance dir'
		return
	}
	mut total := 0
	mut agree := 0
	mut cx_only := 0
	mut code_only := 0
	mut both_reject := 0
	mut multi := 0
	mut diverge := []DiffRow{}
	// PROTO_CANON_OUT=<path>: dump a per-input canonical-hash row for every
	// corpus input (suite, name, fnv1a64 of each reader's canonical render).
	// The bucket counts below pin only CATEGORY membership, so a change that
	// moves a render WITHIN a bucket is invisible to this gate; diffing two
	// dumps (baseline at the base commit vs the change) is the measurement
	// protocol that turned "predicted zero" into "measured zero" for ASP-2
	// (#903) and D910-1 (#910). Written to a FILE because V's test runner
	// swallows println on OK. Dormant unless the env var is set.
	canon_out := os.getenv('PROTO_CANON_OUT')
	mut canon_rows := []string{}
	for f in files {
		if !f.ends_with('.cxd') {
			continue
		}
		path := os.join_path(conformance_dir(), f)
		for c in fixtures.load_fixtures(path) {
			src := c.sections['in_cx'].trim_space()
			if src == '' || src == '[ignored]' || src == '[empty]' {
				continue
			}
			total++
			a := diff_cx_canon(src)
			b := diff_code_canon(src)
			if canon_out != '' {
				canon_rows << '${f}\t${c.name}\t${fnv1a.sum64_string(a):016x}\t${fnv1a.sum64_string(b):016x}'
			}
			if a == 'MULTI' {
				multi++
				continue
			}
			if a == 'REJECT' && b == 'REJECT' {
				both_reject++
				continue
			}
			if a == 'REJECT' {
				code_only++
				continue
			}
			if b == 'REJECT' {
				cx_only++
				continue
			}
			if a == b {
				agree++
			} else {
				diverge << DiffRow{
					suite: f
					name:  c.name
					src:   src
					cx:    a
					code:  b
				}
			}
		}
	}
	if canon_out != '' {
		os.write_file(canon_out, canon_rows.join('\n') + '\n') or {
			assert false, 'cannot write PROTO_CANON_OUT dump: ${err}'
		}
	}
	mut r := []string{}
	r << '[cxparse-diff] corpus data differential over ${total} in-cx inputs:'
	r << '  total=${total} agree=${agree} diverge=${diverge.len} cx_only=${cx_only} code_only=${code_only} multi=${multi} both_reject=${both_reject}'
	for d in diverge {
		r << '  [${d.suite}] ${d.name}'
		r << '    src : ${d.src}'
		r << '    cx  : ${d.cx}'
		r << '    code: ${d.code}'
	}
	report := r.join('\n')

	// BASELINE LOCK (Phase 0, 2026-06-04). Frozen to the first full-corpus run.
	// This is the merge oracle: a Phase-1+ change that makes a previously-
	// agreeing input diverge drops `agree` / raises `diverge` and fails here.
	// A change that CONVERGES a known divergence also fails ("deliberately
	// update the baseline") — same philosophy as the parser_parity gate.
	// The divergences are CATALOGUED + classified in
	// _gate_evidence/cxparse_phase0_differential.md (data-only surface,
	// eval-confound, render-convention, and the genuine Class-D latents).
	// Class-D RESOLUTION (2026-06-04): D1/D2/D4 (code bugs) + D3 (cx bug) were
	// fixed pre-merge, moving the baseline 37→32 diverge (383→388 agree). D5
	// (`[root 42 [x]]` mixed-content §9-scope) is DEFERRED to Phase 3's "§9 to
	// one layer" step — it converges there by construction; ext-011 + pred-006
	// remain the two known D5 rows. See the catalog's Class-D RESOLUTION table.
	// Phase 4.2 NUMBER-FORK CONVERGENCE (2026-06-04): the program lexer now
	// implements lexicon [L20] (hex `0x…`, `_` separators) like the data parser,
	// so two previously program-rejected hex inputs — `[flags 0xFF]`
	// (extended.cxd) and `[mask 0xCAFE]` (lint.cxd) — now parse and AGREE. That
	// moves cx_only 108→106 and agree 388→390 (a deliberate convergence bump;
	// diverge unchanged at 32).
	// @CHOICE-1 §9-ONE-LAYER, SLICE A (2026-06-05): the data parser's whitespace
	// auto-array (try_auto_array → a single `T[]` element) is RETIRED — a typed
	// whitespace scalar run is now N discrete typed CHILDREN (body_is_typed_list),
	// AND the typed-list classifier now handles mixed content (child elements
	// interleaved). That CONVERGES the two known D5 mixed-content rows (ext-011 +
	// pred-006, the `[root 42 [x]]` §9-scope cases the comment above predicted
	// "converges by construction" here): cx no longer merges `42 4.2`-style runs
	// into one quoted Text, matching the program parser. diverge 32→30, agree
	// 390→392 (deliberate convergence; no new rejects — cx_only/code_only/both
	// unchanged).
	// D-B MARKDOWN REMOVAL (2026-06-05): markdown is no longer CX syntax (the
	// parser sigil arms `~ ^ \` > [#heading [--- [* italic`, the CX↔MD layer,
	// and conformance/md.cxd were all removed). Deleting md.cxd drops its 27
	// in_cx rows from the corpus: total 556→529, agree 392→379 (−13),
	// diverge 30→27 (−3), cx_only 106→95 (−11). code_only/multi/both_reject
	// unchanged — a pure corpus-shrink, no new divergence among surviving rows.
	// DATA↔PROGRAM SEAM CLOSURE (2026-06-05): the program reader now admits the
	// pure-data constructs it previously forked on / rejected — raw text `[#…#]`,
	// entity / char refs `&…;`, and declarations `[!…]` / `[!DOCTYPE …]` — via a
	// `node_lit` literal that delegates to the data reader (cx.parse_data_node).
	// 4 corpus rows that were cx_only (data accepted, program rejected) now
	// AGREE: agree 379→383 (+4), cx_only 95→91 (−4). diverge/code_only/multi/
	// both_reject unchanged — a strict convergence improvement, no regressions.
	// D-B MARKDOWN CONVERSION RESTORED (2026-06-06): the CX↔MD conversion layer
	// (parser_md.v / emitter_md.v / Format.md / CLI --md) and conformance/md.cxd
	// were restored — WITHOUT re-adding the markdown sigil arms to the CX parser
	// (no `~ ^ \` > [#heading` surface). md.cxd was pruned to its CONVERSION cases
	// (HTML-style element names + md→cx); its 10 sigil-input cases were dropped
	// since that surface stays removed. The surviving 17 in_cx rows rejoin the
	// corpus: total 529→546 (+17); agree 383→396 (+13), diverge 27→28 (+1),
	// cx_only 91→94 (+3), code_only/multi/both_reject unchanged. Deterministic.
	// TRIPLE-QUOTE BIJECTION FIXTURES (2026-06-08): extended.cxd cases 048/049
	// (triple-quote `\"` round-trip + canonical fixed point) add 2 in_cx rows;
	// both parsers AGREE on each. total 546→548 (+2), agree 396→398 (+2); all
	// other categories unchanged.
	// PROGRAM-MODE `:table` BLOCK PARSE (2026-06-09): the program parser gained
	// `[table[…]]` recognition (program_parser.v at_table_block_body /
	// reparse_table_element_as_node) — it now delegates a table-bearing element
	// to the data reader via the DATA↔PROGRAM `node_lit` seam, so a `:table`
	// input that the program parser previously REJECTED (and the data parser
	// accepted → counted cx_only/diverge) now parses identically in both engines.
	// Pure convergence, no regressions: agree 398→441 (+43), diverge 28→10 (−18),
	// cx_only 94→69 (−25); code_only/multi/both_reject/total unchanged. The
	// remaining 10 divergences are the known mixed-content / comment / single-
	// colon-attr forks (no tables).
	// LOSSLESS-COMMENT PRESERVATION (2026-06-09): `cx fmt` is now lossless for
	// comments — the data parser retains a top-level line comment as a
	// CommentNode sibling (prolog for a leading comment, the elements list for a
	// between/trailing one) instead of discarding it, so `cx_text_fmt` round-
	// trips it (canonical.md §2.1). One corpus row — lint.cxd
	// 040-l001-mixed-comment-styles, whose `# …`-bearing input previously parsed
	// to a single element — now yields a trailing top-level CommentNode, so
	// `doc.elements.len != 1` and it lands in `multi` rather than `agree`.
	// agree 441→440 (−1), multi 25→26 (+1); diverge/cx_only/code_only/
	// both_reject/total unchanged. (Strict `cx canonical` still STRIPS comments,
	// so the canonical-hash corpus is unaffected.)
	// +1 total/agree (#12): code.cxd gained program-meta-001-annotate-and-read
	// (the [?meta]/meta-of fixture backing the directive reference); both parsers
	// agree on it. total 548→549, agree 440→441; others unchanged.
	// #82 TIER-1 IDENTITY (2026-06-25): identity.cxd gained 8 order-semantics
	// cases (id-024..031: map-key normalize, sequence/array/attr order preserve,
	// comment strip). 7 parse identically in both engines (+7 agree); 1 is
	// data-only (+1 cx_only — the program parser rejects that bracket form).
	// total 549→557, agree 441→448, cx_only 69→70; diverge/multi/both_reject/
	// code_only unchanged (no parsing regression — purely new fixtures).
	// #82 §2.8 ANCHOR EXPANSION (2026-06-29): identity.cxd gained 5 strict-canonical
	// cases (id-032..036: anchor strip, alias expand, alias/merge-equivalent-to-
	// inline, merge override). 2 parse identically in both engines (+2 agree); 3
	// carry anchor/alias/merge surface the program parser rejects (+3 cx_only).
	// total 557→562, agree 448→450, cx_only 70→73; others unchanged (purely new
	// fixtures, no parsing regression).
	// #312 COMMENT-BRACKET RULE SPEC'D (2026-07-10): core.cxd gained case 036
	// (comment prose quoting bracketed CX forms — the balanced rule the EBNF
	// now specifies). Parses identically in both engines: +1 total, +1 agree.
	// #341 DEF NO-OUTER-CAPTURE FIXTURE (2026-07-11): code.cxd gained case
	// program-def-no-outer-capture (§12.2.2 — def bodies resolve live, no
	// def-time snapshot; its in-cx input `[doc [x 42]]` parses identically in
	// both engines): +1 total, +1 agree.
	// +6 total (step-terminating-colon / typed-attr-read fixtures, 2026-07-13):
	// code.cxd gained program-atom-008..015 pinning the QName-fold
	// byte-adjacency rule (grammar [131b] / lexicon [L11]) and typed attribute
	// reads (cxdm §2.4). Five new in-cx inputs land in agree; `[x ns:attr=7]`
	// lands in cx_only (DATA mode admits QName attribute names; the
	// PROGRAM-mode element literal does not — pre-existing gap, unchanged by
	// the fold fix). No existing row moved category. total 564→570,
	// agree 452→457, cx_only 73→74; diverge/code_only/multi/both_reject
	// unchanged.
	// +3 total (float-EBV fixtures #382/#384, 2026-07-13): code.cxd gained 13
	// program-if/match/logic/cxpath-float cases pinning cxdm §6 rule 2
	// (int/float share the numeric truthiness rule) and the absence-marker
	// EBV rule. Ten carry `[empty]` in-cx (skipped above); the three
	// score-pairs docs (if-float-003 + the two cxpath-float cases) parse
	// identically in both engines and land in agree. No existing row moved
	// category. total 570→573, agree 457→460; every other bucket unchanged.
	// +2 total (EBV-unification fixtures #383, 2026-07-13): code.cxd gained
	// 17 program-if/logic/match elem/seq/container cases pinning the owner
	// ruling (present named element truthy by presence; singleton sequence
	// wrapper recurses; containers stay empty-is-falsy). Fifteen carry
	// `[empty]` in-cx (skipped above); the two `[app [flag]]` existence-idiom
	// docs (if-elem-002/003) parse identically in both engines and land in
	// agree. No existing row moved category. total 573→575, agree 460→462;
	// every other bucket unchanged.
	// +8 total (#391 fixtures, 2026-07-13): code.cxd gained 4 absolute-path
	// cases (cxpath-013..016; three plain data in-cx docs land in agree, one
	// in cx_only) and core.cxd gained 4 D2 scalar-only attr-value rejection
	// cases (037-040). The D2 in-cx docs are the REJECTED forms themselves:
	// the DATA parser now refuses them (cx-err:E211) while the program
	// reading either also rejects (`x=($a $b)` / `x={k: 1}` → both_reject
	// +2) or still accepts them as element construction with collection-
	// valued attrs (`local=([addr …] …)` / `x=[q]` → code_only +2) — the
	// program-side attr-value question is #396/#268, tracked, not this
	// baseline's to settle. No existing row moved category. total 575→583,
	// agree 462→465, cx_only 74→75, code_only 1→3, both_reject 2→4.
	// +1 total (#392 fixtures, 2026-07-13): xml.cxd case 024 (cx:arr emit/
	// import round-trip) carries a plain-data in-cx doc that parses
	// identically in both engines. total 583→584, agree 465→466; every
	// other bucket unchanged.
	// +3 total (#397 dotted-atom fixtures, 2026-07-13): atoms.cxd 025-027.
	// The dotted-attribute and dotted-sequence docs parse identically in both
	// engines (agree +2, the point of the [L11] lockstep extension); the
	// trailing-dot boundary doc (`[m x=:order.]`) is a STRING attr in the
	// data reading but a program-side parse rejection → cx_only +1.
	// #396 ruling 1b (2026-07-13, scalar-only attrs): +1 total (core.cxd 041,
	// the directive-attr `[?cx custom=[q]]` rejection doc → both_reject).
	// The two extended.cxd attr-body rows CONVERGE: the pipe-block doc was a
	// known DIVERGE row (data read a node-valued body, program read the raw
	// span) and both readers now REJECT it (diverge −1, both_reject +1); the
	// hash-raw doc read as a body-attr on the data side only (cx_only) and
	// both readers now read the same STRING scalar (cx_only −1, agree +1).
	// +10 total (#404 D22 table-query fixtures, 2026-07-14): code.cxd
	// program-table-d22-001..011 carry 10 distinct table-bearing in-cx docs
	// (one case reuses the shared `[empty]` doc). A `[table[…]]` block is a
	// DATA-surface construct (grammar [29]); the program reading rejects it
	// in expression position, so all 10 land in cx_only. No existing row
	// moved category. total 588→598, cx_only 75→85.
	// +3 total (#405/#406 eval-strictness fixtures, 2026-07-14): code.cxd
	// program-cmp-ordered-{atomize-text-node,string-attr-err} and
	// program-cmp-ordered-guard-err-propagates carry 3 plain-data in-cx
	// docs ([doc [n 7]] / [doc [box w="5"]] / [doc [r a='30'] [r a='28']])
	// that parse identically in both engines — agree +3, every other
	// bucket unchanged. The other 14 new cases reuse the shared [empty]
	// doc. total 598→601, agree 469→472.
	// #421 [?cx] PI-namespace fix (2026-07-14): the program reading now
	// classifies `[?cx …]` as the CXDirective/config namespace (grammar
	// [34]; NOT a §4.1 directive) and parses it via the node_lit
	// DATA↔PROGRAM seam, so the program reading of a CXDirective IS the
	// data reading. Four corpus rows that were cx_only (data accepted,
	// program rejected on the bogus "unknown directive '[?cx]'") CONVERGE
	// to agree: schema_validate.cxd sv-052/sv-053/sv-054 (`[?cx
	// schema=…]` directives riding in a target doc) and core.cxd
	// 017-cxdirective. include.cxd also gained 2 new in-cx docs
	// (inc-002/inc-003 bare-config-PI pass-through; inc-001 stays multi —
	// its lone top-level `[?cx]` parses into doc.prolog, elements.len==0)
	// which land in agree. No row moved into any reject bucket. total
	// 601→603, agree 472→478, cx_only 85→81; diverge/code_only/multi/
	// both_reject unchanged.
	// +5 total (#413 table-XML-lane fixtures, 2026-07-14): xml.cxd cases
	// 025/027/028/029/030 carry 5 table-bearing in-cx docs pinning the
	// [table] block XML image (cx:cols + cx:row/cx:cell, conversions.md
	// §2.1). A top-level `[name [table[…]] …]` doc parses identically in
	// both engines (unlike #404's expression-position tables, which the
	// program reading rejects) — agree +5, every other bucket unchanged.
	// total 603→608, agree 478→483 (rebased over the #421 move).
	// +3 total (#443 AST-JSON table-projection fixtures, 2026-07-14):
	// table.cxd tab-016/017/018 carry 3 table-bearing in-cx docs pinning
	// the AST-JSON "table" projection (ast.md Element). Top-level
	// `[name [table[…]] …]` docs parse identically in both engines (same
	// shape as #413's xml.cxd additions) — agree +3, every other bucket
	// unchanged. total +3 (rebased over the #463 move: 616/491 → 619/491, diverge 9→12), agree 483→486.
	// +5 total (#443 MD pipe-table fixtures, 2026-07-14): md.cxd 033–037
	// carry 5 table-bearing in-cx docs pinning the [table] → GFM
	// pipe-table image (conversions.md §7). Same top-level table-doc
	// shape — agree +5, every other bucket unchanged. total 611→616,
	// agree 486→491.
	// +3 total (#457 bytes-ascription fixtures, 2026-07-14): extended.cxd
	// 016b/016c carry the short-hex and 8-byte-hex `[x::bytes 0x…]` docs.
	// Post-fix the program reading coerces the ORIGINAL token under the
	// ascription (ProgramLiteral.src), so both docs parse identically in
	// both engines — agree +2 (pre-fix they DIVERGED: the program side
	// int-coerced/clamped the hex before `::bytes` applied). 016d is the
	// attr-position doc `[e h::bytes=0x3a7bd3e2]`: the DATA reading types
	// it, but the PROGRAM element literal has no `name::T=value` attr-
	// ascription production ("unexpected token '::' in expression
	// position") → cx_only +1 (pre-existing program-reading gap, tracked
	// separately; NOT settled by this baseline). No existing row moved
	// category. total +3, agree +2, cx_only +1 (rebased over the #463 move: 616/491 → 619/493/82).
	// +3 total (#455 fixtures, 2026-07-14): core.cxd cases 042-044 pin the
	// attribute-run/comment-trivia rule — a `[; … ]` child no longer
	// terminates the DATA reader's ElementMeta loop, so `env=dev` after a
	// comment child is an ATTRIBUTE in every lane (the fix converged the
	// canonical/hash lane with fmt/--json/eval). The three in-cx docs land
	// in diverge for the SAME pre-existing reason as the known row
	// 011-comment-in-element: the data parser RETAINS the CommentNode as an
	// item (lossless-fmt round-trip, 2026-06-09 entry above) while the
	// program lexer drops comments as trivia — a presentation-retention
	// render difference, not a meaning split (both sides agree on attrs +
	// children; strict canonical strips the comment on both). No existing
	// row moved category. total +3 (rebased over the #463 move: 616/491 → 619/491, diverge 9→12), diverge 9→12; every other bucket
	// unchanged.
	// +7 total (#434 step-scoped `(bind $NAME)` fixtures, 2026-07-14):
	// code.cxd program-cxpath-bind-001…007 carry 7 plain-data teams docs
	// ([teams [team name=… [member …]…]…]) that parse identically in both
	// engines — agree +7, every other bucket unchanged. The 2 #454
	// unbound-$doc cases reuse the shared [empty] doc (not counted).
	// total 608→615, agree 483→490.
	// +4 total (#464 ast_bin table-record fixtures, 2026-07-15):
	// table.cxd tab-019..022 carry 4 table-bearing in-cx docs pinning
	// the emit_ast_bin → bin_to_doc identity (ast-bin.md §4.8 table
	// record, tag 0x17, v9). Same top-level table-doc shape — agree +4,
	// every other bucket unchanged. total 616→620, agree 491→495.
	// +11 total (#440/#441/#444/#458 conversion-contract fixtures, 2026-07-15):
	// conversions.cxd (new suite, 9 in-cx docs) + yaml.cxd emit-quoting cases
	// (2). No engine changed — the wave touches only the YAML/JSON codec
	// lanes — so every movement is pre-existing parser behavior newly
	// EXPOSED by fixture inputs the corpus never carried:
	//   agree +3 — conv-003 (decimal element), conv-004 (sized element),
	//     conv-009 (top-level table doc; both engines agree per the #413 row).
	//   cx_only +4 — conv-005/conv-012 (type-ANNOTATED attributes,
	//     `when::date=…` / `sum::bytes=…`: the program parser rejects the
	//     attr-annotation form), yaml-023/yaml-024 (map docs with multi-word
	//     bare / quoted number-shaped string values the program reading
	//     rejects). Data-only surface, same class as the Phase-0 catalog.
	//   diverge +4 — conv-001/conv-002 (map-value date/datetime: the data
	//     parser auto-types them, the program reading renders them as quoted
	//     strings), conv-008 (quoted duration-/bigint-shaped map strings:
	//     render_canonical drops the quotes on the cx side — the map-value
	//     string-quoting gap), conv-010 ([hash::bytes 0x…]: the program
	//     reading coerces the hex payload to its decimal int text). All four
	//     are cataloged engine divergences for the cxparse unification
	//     backlog, not regressions of this wave.
	// Rebased over #467/#443 (base 608→616): total 616→627, agree 491→494,
	// diverge 9→13, cx_only 81→85.
	// +4 total (#478 table-element head-meta fixtures, 2026-07-15):
	// table.cxd tab-023..026 pin ElementMeta on `[table[…]]`-block
	// elements (grammar [29]/[50]: the TableBlock occupies only the
	// TypeAnnotation slot; anchor/merge/id/attrs coexist and MUST be
	// attached — the data parser previously dropped the attrs silently).
	// BOTH engines were fixed in the same wave: the data parser attaches
	// the collected attrs (parser.v table branch), and the program
	// reading's element-literal body loop re-checks for the `[table[`
	// clause-child opener after an attribute run and delegates the span
	// to the data reader (program_parser.v at_table_clause_opener), so
	// the two readings stay convergent. No existing row moved category:
	//   agree +2 — tab-023 (attrs+table), tab-024 (nested attrs+table
	//     with trailing sibling) parse and render identically in both
	//     engines.
	//   cx_only +1 — tab-025 (`&u #cat` anchor/id meta + table): the
	//     program reading rejects the anchor/id meta run, same class as
	//     the Phase-0 data-only-surface catalog.
	//   both_reject +1 — tab-026 (`[users::int [table[a]] …]`): the data
	//     parser now rejects the explicit `::T` + TableBlock conflict
	//     loudly (#478 fail-closed rule), and the program reading (which
	//     delegates the tabular form to the data reader) rejects it the
	//     same way.
	// total 644→648, agree 508→510, cx_only 86→87, both_reject 6→7.
	// integration/482-483-486 (2026-07-15): the three post-campaign engine
	// waves stacked into one branch. Per-branch movement docs live in the
	// superseded PRs #482 (#466: +12 total/+10 agree/-3 cx_only/+5
	// both_reject — 3 corpus rows converged: extended 016d, conversions
	// conv-005/conv-012), #483 (#469/#473: +4 total/+2 agree, diverge +3
	// comment-retention class -1 conv-008 converged), #486 (#478: +4
	// total/+2 agree/+1 cx_only/+1 both_reject), plus #481 (#471/#472:
	// +4 total/+4 agree) folded in after its post-cut merge. Numbers are the
	// integrated ACTUALS from a full run on the merged tree.
	// #484 GLUED TABLE_OPEN CUTOVER (2026-07-15): the data reader's
	// TableBlock opener check is now byte-adjacent `[table[` ONLY —
	// matching grammar.ebnf's TABLE_OPEN single-token lexer note and the
	// program reading, which was ALWAYS glued-only (the ws-tolerant data
	// claim silently promoted `[users [table [cols]] rows]` to a table and
	// hijacked ordinary composition like `[furniture [table [legs 4]]]`).
	// A misplaced glued opener (top level / mid-body) now rejects loudly
	// in BOTH engines instead of falling into Array/Sequence garbage.
	// Movement, fully accounted (total 668→677, +9 = the new table.cxd
	// tab-027..035 in-cx rows):
	//   agree +16 — 6 of the new rows (tab-027/028/029 nested composition,
	//     tab-030 element-named-table composition, tab-034/035 cell
	//     quoting) parse+render identically in both engines, plus the 10
	//     code.cxd program-table-d22-* in-cx docs whose SPACED `[table [`
	//     spelling was migrated to the glued token (cutover-first): the
	//     program reading had rejected those docs (cx_only) — with the
	//     canonical spelling both engines read the same table.
	//   cx_only −10 — the migrated d22 rows above.
	//   both_reject +2 — tab-032/033 (misplaced `[table[` opener): both
	//     engines reject loudly per the new fail-closed rule.
	//   diverge +1 — tab-031 (`[users [table [name age]] Ada 36]`): BOTH
	//     engines now read composition (the #484 convergence — no silent
	//     table promotion); the residual is the pre-existing multi-word
	//     text-run class (data: one Text ' Ada 36'; program: discrete
	//     'Ada' 36 typed items), same family as the Phase-0 catalog.
	// #475 movement (total 677→679, +2 = the new conversions.cxd
	// conv-014/conv-017 in-cx rows):
	//   agree +1 — conv-014 (mixed-content `[p 'seen ' [em twice] ' today']`)
	//     parses+renders identically in both engines.
	//   diverge +1 — conv-017 (`[m {'$tag': weird}]`): the data renderer
	//     quotes the `$`-leading STRING map key (cx_emit_map_key — a bare
	//     `$tag` would re-read as a binding reference in the program
	//     reading); the program renderer emits it bare. Same pre-existing
	//     program-vs-data collection-quoting family as the Phase-0 catalog
	//     (#473 fixed the data side; the program renderer's key rule is
	//     the residual).
	// #466 ATTR-VALUE SEMANTICS (2026-07-15): two owner rulings landed.
	// (1) hex under ::decimal/::bigint REJECTS (CXER0290) in both
	// engines — extended.cxd 016g/016h (`[e n::decimal=0x2a]` /
	// `[e n::bigint=0x2a]`) move agree → both_reject (agree −2,
	// both_reject +2). (2) code.md §6.4.1 wins over the retired
	// validate.md attr-collection surface: element-construction attr
	// values are STRICTLY scalar — the program reading's canonical-
	// stringify seam for non-scalar attr values is gone, so core.cxd
	// 038 (`[m x={k: 1}]`) and 040 (`[m x=[q]]`) — which the data
	// reading already rejected (D2 E211) while the program reading
	// stringified — move code_only → both_reject (code_only −2,
	// both_reject +2). Movement fully accounted: agree 542→540,
	// code_only 3→1, both_reject 14→18; total unchanged.
	// #495 (2026-07-16): the program renderer's `__cx_map__` key
	// emission converges on the shared envelope-lane quoting rule
	// (cx.cx_emit_envelope_map_key) — a `$`-leading / colon-bearing
	// string key now quotes in the program rendering exactly as the
	// data renderer's cx_emit_map_key does, so conv-017
	// (`[m {'$tag': weird}]`) renders identically in both engines:
	// diverge 19→18, agree 541→542; total unchanged. The #475
	// paragraph above records the divergence this closes.
	// #587 movement (total 679→680): the new code.cxd
	// program-descendant-seq-roundtrip-004 in-cx row
	// (`[w ([item n=1], [item n=2], [item n=3])]` — a paren-sequence
	// element body) parses+renders identically in both engines: agree +1.
	// #646 movement (total 680→684): the four module-scope-through-frames
	// regression fixtures each carry a trivial `[doc]` in-cx row, all
	// parsing+rendering identically in both engines: agree +4.
	// #516/#651 pre-I1 pin batch movement (total 684→706): the pin batch
	// (parts 1–3: operator-head family + quote-hole/E210 pins, Tier-2 pair
	// family, data-bin wire goldens) added 22 in-cx rows — agree +12
	// (plain data pins), cx_only +7 (data-only surfaces the program reading
	// rejects), both_reject +3 (deliberate error-pin rows). diverge stays
	// 18 — no new engine divergence, corpus growth only.
	// I1 row-3 binary slots movement (total 706→707): the sd-010 multihash
	// schema-ref case carries one in-cx row parsing identically in both
	// engines: agree +1. diverge stays 18 — corpus growth only.
	// I1 row-4 part 2 movement (total 707→713): the L58 r'''-in-data-mode
	// family (ext 050-054) parses identically in both engines (agree +5 —
	// the raw-triple reader is the ONE shared scanner) and the [2a]
	// mid-line `---` bare-text witness (ext 055) is a data-only document
	// the program reading rejects (cx_only +1). diverge stays 18 — corpus
	// growth only.
	// I1 row-5 movement (total 713→720): the stream-15 reserved-namespace
	// family (ns-017..023). The five E213 negatives reject in BOTH engines
	// (both_reject +5 — cx_check_reserved_ns_attrs is the one shared rule;
	// the program literal lane enforces it via eval_construction_attrs).
	// The two positives carry prefixed child names (`p:x`/`z:item`), which
	// the program reading has always rejected: cx_only +2. diverge holds
	// 18 — corpus growth only.
	// I1 row-8 movement (total 720→723): the operator-head lexer fix.
	// oph-006/007 (`[* $x 2]` / `[> $x 2]`) now PARSE in the data lane —
	// both_reject −2 → cx_only +2 (the program reading still rejects the
	// unbound $x). New guard rows: oph-008 `[-1, 2]` agrees (+1);
	// oph-009 (alias doc) is data-only (+1 cx_only); oph-010 `[+]` is the
	// FIRST corpus row where BOTH readings accept an operator-headed
	// input — the data reading yields the element `[+]`, the program
	// reading EVALUATES the operator to an arity-err VALUE: diverge +1,
	// the ruled data/program mode fork for operator elements
	// (homoiconicity working as specified), joining the 18 documented
	// forks.
	// Post-I1 movement (723→725): binding_api.cxd gained the L48
	// promoted-kinds parity rows 111/112 — one shared in-cx doc
	// (`[order price=19.99 qty=…]`, decimal + bigint attrs) both
	// readings accept identically: agree +2, corpus growth only.
	// I2 movement (725→729): lockfile.cxd landed (corpus audit G10 —
	// the Ring-0 lockfile document surface, 4 in-cx cases). A
	// `[cx.lock …]` document is data-only — the program reading does
	// not claim it — so all four land in cx_only: corpus growth only,
	// no divergence change.
	// I3 movement (729→741): fmt.cxd landed (corpus audit G6 — the
	// formatting.md fixture family, 12 in-cx cases). +8 agree (plain
	// single-element data docs both readings accept identically);
	// +1 diverge (fmt-010-program-let-faithful — a `[?let …]` form:
	// the ruled data/program mode fork, same class as the operator-
	// head fork above); +2 multi (comment-sibling / multi-form docs);
	// +1 both_reject (fmt-012's deliberately unclosed input — the
	// fail-closed lane). Corpus growth only, no parsing regression.
	// #772 movement (741→742): program-cxpath-pred-attr-type-test landed
	// (the type-test predicate ground truth) — +1 agree (its in-cx doc is
	// a plain data document, identical under both readings; the typed
	// attr `age::int=5` is the D3 ascription both readers share). Corpus
	// growth only, no divergence change.
	// #703 movement (742→744): sv-062/sv-063 landed (exact [range] bounds
	// on decimal/bigint — item E's discriminator pair) — +2 agree (both
	// in-cx docs are plain data documents, identical under both readings).
	// Corpus growth only, no divergence change.
	// #673 movement (744→748): sv-064…sv-067 landed (I5 stream 1 W2 —
	// the retired-schema-pragma + header-edge negatives) — +4 agree
	// (each case's in-cx target is the plain data document
	// `[server host=x]`, identical under both readings). Corpus growth
	// only, no divergence change.
	// Stream-6 W2+W5+W6 (#678): +11 (cmd-001..012 command clauses), +6
	// (cmd-013..018 idempotency), +4 (cmd-019..022 propose) in-cx
	// inputs, all in the agree class — corpus growth only, no divergence
	// change (748/583 → 759/594 → 765/600 → 769/604).
	// Stream-21 W5 (#693/#716 item 4): +3 (sv-059a..c semver dialect
	// acceptance — each in-cx target is the plain `[book id=x]`), all in
	// the agree class — corpus growth only, no divergence change
	// (769/604 → 772/607).
	// Stream-16 W2 movement (772/607 → 779/612, diverge 20→22): +7 in-cx
	// rows from the sv-068..074 validator-completion fixtures. The +2
	// diverge = the PRE-EXISTING quoted-string-in-collection rendering
	// class (cxparse renders ('a', 2) bare / ((a, 2)) while the code
	// parser keeps quotes) exercised by sv-071/sv-073's body collections —
	// corpus growth exposing a known class, no new divergence mechanism,
	// no existing row moved category. Reviewed deliberately per this
	// test's contract.
	// Stream-17 W7 movement (779/612 → 795/628): +16 in-cx rows from the
	// §9 pair family (table_transparency.cxd) — ALL SIXTEEN in the agree
	// class; every divergence bucket unchanged. Corpus growth only,
	// reviewed deliberately per this test's contract.
	// Stream-18 W6 movement (795/628 → 797/630): +2 in-cx [doc] rows from
	// the cmd-023/024 args-record family (code.cxd) — BOTH in the agree
	// class; every divergence bucket unchanged. Corpus growth only,
	// reviewed deliberately per this test's contract.
	// Stream-14 W6 movement (797/630 → 801/634): +4 in-cx data rows from
	// the s22-witness/tape families (code.cxd — the [ignored]/[doc]
	// inputs of ev-async-006 / ev-park-001 and companions) — ALL FOUR in
	// the agree class; every divergence bucket unchanged. Corpus growth
	// only, reviewed deliberately per this test's contract.
	// #704 movement (801/1 → 802/2): +1 in-cx row from ns-024, the E210
	// authored-`cx:`-name negative that pinned the previously unfixtured
	// half of the reserved-URI pair. It lands in code_only — the bucket
	// this census expects to stay ~0 — and that is NOT noise: `[doc [cx:x
	// 1]]` is refused by the DATA reader and ACCEPTED by the program
	// reader, so the census is reporting a real asymmetry, not a fixture
	// artifact. Probed live: a program can construct and emit `[cx:x 1]`,
	// and the emitted document then fails its own re-parse (E210) — the
	// same "output fails its own re-parse" class #704 was filed for,
	// reached through the program lane instead of an xmlns binding.
	// FILED as #820 (the program-side refusal needs its own error-code
	// ruling: E210 is documented as a DATA-layer code). The row stays and
	// the bucket moves DELIBERATELY: it is this census earning its keep.
	// Every other bucket unchanged.
	// #809 movement (802/634/91 → 813/644/92): +11 in-cx rows from the
	// [131b] kind-test families — 10 in code.cxd
	// (program-cxpath-kindtest-001..010; kindtest-011's `[ignored]` input
	// is skipped by the filter above) and 1 in fmt.cxd (fmt-013). Fully
	// accounted, and each bucket for a reason:
	//   agree +10 — the three distinct code.cxd docs
	//     (`[doc [a first] …]` ×7, `[users [user id=1 role=admin] …]` ×2,
	//     `[doc [port 8080] …]` ×1) are plain data documents that both
	//     readings accept and render identically.
	//   cx_only +1 — fmt-013's in-cx is a PROGRAM
	//     (`[?for [in $c //c] [yield (…)]]`), because fmt fixtures format
	//     programs. The data reading takes it as prose; the program
	//     reading parses it and then REJECTS at eval (CXER0001: a rooted
	//     `//c` needs $doc, which a bare corpus row does not bind). That
	//     is the ruled data/program mode fork this census already
	//     catalogues — same class as fmt-010-program-let-faithful, the
	//     precedent from the I3 fmt.cxd landing above. Probed live in
	//     both readings before re-baselining.
	// No existing row changed category: diverge / code_only / multi /
	// both_reject are all untouched, which is the thing that would have
	// signalled a real parsing regression from the kind-test work.
	// #736 movement (813/92/28 → 815/93/29): +2 in-cx rows from the
	// body-position alias fmt pins (fmt-014, fmt-015). Each row's bucket
	// was classified DIRECTLY (the same diff_cx_canon / diff_code_canon
	// pair this test uses, run on the two inputs), not inferred:
	//   multi +1 — fmt-014's input is `[a &n 1]` + `[b [*n]]`, TWO
	//     top-level elements, and the anchor has to be a sibling because
	//     the fmt runner's §1 purity check runs STRICT canonical, which
	//     refuses a dangling alias (§2.8). Two documents → MULTI by this
	//     census's own rule, before either reading is compared.
	//   cx_only +1 — fmt-015 (`[x [a &n 1] [b [*n] [*n]]]`): the data
	//     reading takes `[*n]` as an alias reference; the program reading
	//     takes it as the operator `*` with one operand and refuses on
	//     arity. That is the homoiconic data/program fork for
	//     operator-shaped heads this census already catalogues (the
	//     oph-006/007 rows above are the same mechanism), not a
	//     regression from the alias emit fix.
	// agree / diverge / code_only / both_reject all unchanged.
	// #824 movement (815/644 → 818/647): +3 in-cx rows from the
	// head-position attribute-axis fixtures (program-cxpath-attr-head-001,
	// -002, -003 in code.cxd). All three carry the SAME `[users [user id=1
	// role=admin] [user id=2]]` document — this census counts per CASE, not
	// per distinct input — and it is a plain data document both readings
	// accept and render identically. Classified DIRECTLY with the census's
	// own reader pair, not inferred: agree. Every other bucket unchanged.
	// #820 movement (code_only 2 → 1, both_reject 25 → 26; TOTAL
	// UNCHANGED): this is a CONVERGENCE, and it closes the loop this
	// census opened. ns-024 (`[doc [cx:x 1]]`) landed in code_only when
	// #704's fixture arrived — "code accepts; cx rejects", the bucket this
	// census expects to stay ~0 — and that anomaly is what surfaced #820:
	// the `cx:` reservation was enforced in the DATA reader only, so a
	// program could construct and emit a document the data reader then
	// refused to read back. With the program reader enforcing the SAME
	// reservation through the SAME authority (RULED: 820-1a), both
	// readings now refuse the row and it moves to both_reject. Verified
	// directly on the input with the census's own reader pair, not
	// inferred. Total is unchanged because the three new
	// program-reserved-ns fixtures carry `[ignored]`, which this census
	// skips. code_only is down to its last row.
	// #825 movement (818/22 → 820/24): +2 in-cx rows from the comment
	// round-trip pins (fmt-016 block comment in an inline body, fmt-017 line
	// comment forcing the multiline lane), and BOTH land in diverge.
	//
	// That is corpus growth exposing a KNOWN class, not a new divergence
	// mechanism: comments are DATA-reading nodes that the program reading
	// discards as trivia (the program AST carries no comment node at all),
	// so a comment-bearing input renders differently under the two readings
	// by construction. core.cxd 011 / 042 / 043 / 044 / 045 / 046 / 047 and
	// lint.cxd 040 are already in this bucket for exactly the same reason,
	// with the identical `<unknown sum type value>` signature — that string
	// is the PROGRAM renderer meeting a CommentNode inside this harness's
	// comparison substrate; it is not reachable from any CLI surface
	// (verified: --to=cx/json/xml, `cx FILE`, and `cx canonical` all render
	// the comment or strip it correctly).
	//
	// The reason these two rows are NEW is that the emitter used to DROP the
	// comment, so the data side rendered `[a 'text']` and matched the
	// program side by accident. Fixing the loss made an existing fork
	// visible. No pre-existing row changed category; agree / cx_only /
	// code_only / multi / both_reject are all unchanged.
	// #829 movement (820/24 → 821/25): +1 in-cx row, fmt-018, joining the
	// same comment-retention diverge class the #825 note above describes —
	// comments are DATA nodes the program reading discards as trivia, so any
	// comment-bearing input renders differently under the two readings by
	// construction. No pre-existing row changed category.
	// #831 movement (821/647 → 823/649): +2 in-cx rows, the 831-* core.cxd
	// cases, and BOTH land in `agree`. That is the point of 831-1a′ rather
	// than a side effect of it: the collection-item bare rule now admits only
	// images both readings read the same way, so a case built out of exactly
	// the shapes that used to fork (`'a b'`, `'a.b'`, `https://…`) converges.
	// `diverge` is unchanged at 25 — no pre-existing row changed category.
	// #829 movement (823/25 → 824/26): +1 in-cx row, fmt-019, joining the
	// SAME comment-retention diverge class the #825/#829 notes above
	// describe — a comment is a DATA node the program reading discards as
	// trivia, so any comment-bearing input renders differently under the two
	// readings BY CONSTRUCTION. `agree` is unchanged; no pre-existing row
	// changed category.
	// #829-remainder movement (824/26 -> 826/28): +2 in-cx rows, fmt-020 and
	// fmt-021 (the ELEMENT-META zone shapes), joining the SAME
	// comment-retention diverge class as fmt-018/fmt-019 above and for the
	// same structural reason — a comment is a DATA node the program reading
	// discards as trivia. `agree` is unchanged; no pre-existing row changed
	// category. The two core.cxd goldens this landing re-blessed (042/044)
	// are `out-cx` changes on rows that were ALREADY in their buckets, so
	// they move no counts.
	// 2026-08-20 (CXP-1 + #878): +1 total = the new xml.cxd 026 separator
	// fixture, which lands in the KNOWN ws-attachment diverge class (the
	// data reading keeps 'Cheese ' with its boundary space, the code
	// reading trims — same class as core 007-mixed-content); and the
	// flipped program-cx-pi bogus fixture moves agree -> both_reject
	// (both parsers refuse the unknown pragma key now).
	// 2026-08-21 (RULED: ASP-2, #903): +1 total, +1 cx_only = the new
	// code.cxd program-array-042-discrete-token-array fixture — its in-cx
	// doc carries comma-less discrete-value arrays, which the DATA reader
	// now accepts (two items, types intact) and the PROGRAM reader
	// deliberately declines (there a bracket is an array only with a
	// top-level comma — the reader difference grammar.ebnf [56b] records).
	// The movement is the NEW FIXTURE, not parser drift: the ASP-2 parser
	// change itself moved ZERO of the 827 pre-existing rows (bucket counts
	// AND per-input canonical hashes of both readers, measured against a
	// baseline run at a8152a52 before this fixture was added).
	// 2026-08-21 (RULED: ASP-3, #909): +1 total, +1 cx_only = the new
	// code.cxd program-array-043-element-body-discrete-children fixture —
	// element bodies of ws-delimited discrete values (now including `(…)`/
	// map-shaped `{…}` structure tokens) read as discrete children in the
	// DATA reader. The row is cx_only, like its ASP-2 sibling 042: the doc
	// also carries the GUARD shapes (bare `(kg, lbs)` prose parens, the
	// glued `(1, 2)[0]` span), which the bare PROGRAM reader declines —
	// the D910-1 data-only-idiom class; the CLI reaches such docs through
	// eval_code's guarded data fallback, not through this reader. The
	// ASP-3 parser change itself moved ZERO of the 828 pre-existing rows
	// (bucket counts AND the per-input canonical-hash dump this test now
	// emits under PROTO_CANON_OUT, diffed against a baseline run at
	// a61b73d7 before this fixture was added).
	// 2026-08-23 (#933/#934 wave): +2 total, +2 agree = the new extended.cxd
	// fixtures 016e (bytes MAP KEY `{0x2a::bytes: on}`) and 016f (bytes
	// collection ITEM `(0x2a::bytes, ok)`), pinning the ::bytes ascription
	// carriage in canonical form. Both rows AGREE: the program reader's
	// expression-position ascription moved to the shared CHECKED core
	// (coerce_scalar_strict — it had refused hex-under-::bytes, the #457
	// shipped carrier, and fell to UNCHECKED coercion for bool/date/etc.),
	// and the program item renderer carries the bytes ascription like
	// decimal/bigint. The parser/emitter changes themselves moved ZERO of
	// the 829 pre-existing rows (bucket counts AND the PROTO_CANON_OUT
	// per-input hash dump, diffed against a baseline run at 6ce6adac
	// before these fixtures were added).
	// 2026-08-23 (#923, RULED: BC-1): agree 650→652, cx_only 95→93 — the
	// program lexer's attr-value micro-mode reads a glued `name=RUN` as ONE
	// bare run auto-typed by the data core, so the two rows the program
	// reader used to REFUSE on run-internal bytes now parse and AGREE
	// (program-modify-009 `email=a@x.com`, md 012 `src=photo.png`); the
	// MULTI row 024-attlist-decl's code-lane hash moved for the same reason
	// (`src=logo.png`, within-bucket). Every other pre-existing row's hash
	// is unchanged (PROTO_CANON_OUT diff vs the #933-wave dump: exactly
	// those three rows).
	// 2026-08-23 (#934): +2 total = the new extended.cxd refusal fixtures
	// 016j/016k (a quoted value + glued `::` in array/sequence slots refuses
	// per MSS-3 item 5 — the DATA reader used to silently split it into a
	// nested two-item sequence). 016k both-reject; 016j is code_only because
	// the PROGRAM reading of `['x'::int]` is its own deliberate surface (a
	// slice literal), not a slot ascription. The parser change itself moved
	// ZERO pre-existing rows (PROTO_CANON_OUT dumps byte-identical).
	baseline := {
		'total':       833
		'agree':       652
		'diverge':     29
		'cx_only':     93
		'code_only':   2
		'multi':       29
		'both_reject': 28
	}
	got := {
		'total':       total
		'agree':       agree
		'diverge':     diverge.len
		'cx_only':     cx_only
		'code_only':   code_only
		'multi':       multi
		'both_reject': both_reject
	}
	assert got == baseline, 'cxparse differential baseline moved (review + update deliberately):\n' +
		'  baseline=${baseline}\n  got     =${got}\n' + report
}
