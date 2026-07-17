module main

import code
import cx
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
	for f in files {
		if !f.ends_with('.cxd') {
			continue
		}
		path := os.join_path(conformance_dir(), f)
		for c in cx.load_fixtures(path) {
			src := c.sections['in_cx'].trim_space()
			if src == '' || src == '[ignored]' || src == '[empty]' {
				continue
			}
			total++
			a := diff_cx_canon(src)
			b := diff_code_canon(src)
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
	//     are catalogued engine divergences for the cxparse unification
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
	// (1) hex under ::decimal/::bigint REJECTS (CXER0109) in both
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
	baseline := {
		'total':       679
		'agree':       542
		'diverge':     18
		'cx_only':     74
		'code_only':   1
		'multi':       26
		'both_reject': 18
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
