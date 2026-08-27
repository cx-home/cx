module main

import os
import code
import fixtures
import platform as _

// regen_code_diagram_golden — captures the PLAYGROUND renderer's Mermaid
// output (`code_diagram_with_level`: CFG / ERD / SEQ) for every
// graph-view fixture in `conformance/code_diagram.cxd` at all three
// detail levels, plus a synthetic pin corpus, into the committed golden
// set `vcx/tests/testdata/code_diagram_golden/<id>.<level>.golden`.
//
// This is the DR-8 bit-for-bit instrument for WAVE 3 of the diagram port
// (RULED 2026-08-20 — ledger/rulings_2026_08_20_diagram_wave3.md,
// DRW3-1). The conformance runner
// (`scripts/check_code_diagram_fixtures.py`) compares node-SETS and
// edge-SETS, so it cannot see line order, id minting order, or label
// bytes; this corpus does. It was captured ONCE from the UNMODIFIED V
// emitter at the wave-3 head — capturing shipped behavior is not golden
// movement, it is the instrument — and any regeneration after that IS
// golden movement, forbidden except under a DR-8 mini-ruling recorded in
// the ledger BEFORE the bytes move.
//
// The byte-equality gate is vcx/tests/code_diagram_golden_test.v.

const levels = ['min', 'compact', 'full']

// Synthetic pin corpus — shapes the 46 graph-view fixtures never reach,
// chosen by reading the V emitter's arms at capture time: every SEQ
// inner directive (await family, cancel, every resilience policy, inner
// async, try-send/try-receive with a timeout, top-level send/receive,
// select timeout/default arms, a service with no routes), the CFG
// shapes the fixtures skip (nested let, modify inside a def, an
// over-cap basic block, a >30-char match arm, an unnamed for), the ERD
// edges (name collisions across depths, non-identifier names, every
// scalar type row, FK inference, >10-value enumeration, the DOCUMENT
// suppression step-back), and the parse-failure fallbacks (DRW3-2's surviving
// patches, and a source that defeats both).
const pin_sources = {
	'pin-seq-await-family':      '[?worker name="w" body=[?await-all \$fs]]'
	'pin-seq-await-plain':       '[?worker name="w" body=[?await \$f]]'
	'pin-seq-cancel':            '[?worker name="w" body=[?cancel \$job]]'
	'pin-seq-retry':             '[?worker name="w" body=[?retry max=3 body=[?send "m" to=\$ch]]]'
	'pin-seq-timeout':           '[?worker name="w" body=[?timeout after=5s body=[?send "m" to=\$ch]]]'
	'pin-seq-breaker':           '[?worker name="w" body=[?circuit-breaker threshold=5 body=[?send "m" to=\$ch]]]'
	'pin-seq-rate-limit':        '[?worker name="w" body=[?rate-limit rate=10 body=[?send "m" to=\$ch]]]'
	'pin-seq-bulkhead':          '[?worker name="w" body=[?bulkhead max=2 body=[?send "m" to=\$ch]]]'
	'pin-seq-fallback':          '[?worker name="w" body=[?fallback recover-with=[alt] body=[?send "m" to=\$ch]]]'
	'pin-seq-async-inner':       '[?worker name="w" body=[?async [job]]]'
	'pin-seq-async-top':         '[?async [job]]'
	'pin-seq-try-send':          '[?worker name="w" body=[?try-send "m" to=\$ch]]'
	'pin-seq-try-receive':       '[?worker name="w" body=[?try-receive from=\$ch timeout=50ms]]'
	'pin-seq-top-send':          '[?channel name="ch"]\n[?send "m" to=\$ch]'
	'pin-seq-top-receive':       '[?channel name="ch"]\n[?receive from=\$ch]'
	'pin-seq-select-timeout':    '[?worker name="w" body=[?select [case [timeout 50ms] [handled]] [case [default] [other]]]]'
	'pin-seq-service-no-routes': '[?http-service name="svc"]'
	'pin-seq-unknown-inner':     '[?worker name="w" body=[?modify \$d [set x 1]]]'
	'pin-seq-note-expression':   '[?worker name="w" body=[a-plain-element]]'
	'pin-seq-for-body':          '[?worker name="w" body=[?for \$x [in (1, 2)] [yield [?send \$x to=\$ch]]]]'
	'pin-seq-let-inner':         '[?worker name="w" body=[?let [= \$m "x"] [?send \$m to=\$ch]]]'
	'pin-seq-if-inner':          '[?worker name="w" body=[?if \$p [then [?send "a" to=\$ch]] [else [?send "b" to=\$ch]]]]'
	'pin-cfg-nested-let':        '[?let [= \$a 1] [?let [= \$b 2] [?if [> \$a \$b] [then [x]] [else [y]]]]]'
	'pin-cfg-modify':            '[?modify \$doc [set count 1] [append item]]'
	'pin-cfg-block-overflow':    '[a 1]\n[b 2]\n[c 3]\n[d 4]\n[e 5]\n[f 6]\n[g 7]\n[h 8]\n[i 9]\n[j 10]\n[k 11]\n[l 12]'
	'pin-cfg-long-match-arm':    '[?match \$v [case "a-really-long-pattern-string-way-past-thirty" [x]] [else [y]]]'
	'pin-cfg-for-unnamed':       '[?for \$x [in (1, 2, 3)] [yield [step \$x]]]'
	'pin-cfg-def-with-match':    "[?def classify (\$n) [?match \$n [case 0 'zero'] [else 'other']]]"
	'pin-cfg-def-and-call':      '[?def helper (\$n) [+ \$n 1]]\n[?def main () [helper 1]]'
	'pin-cfg-if-no-else':        '[?if [> \$x 0] [then [pos]]]'
	// #1037 — the cd-esc asymmetry between the if-arm and match-arm
	// emitters. An arm body whose LABEL carries a `"` is the only shape
	// that can tell the two apart, and the corpus had none: every arm
	// value in it is quote-free, so `cd-if-arm-emit`'s missing escape
	// was invisible for the whole life of the port. These two are the
	// SAME body under the two emitters, so a reader sees that only the
	// directive differs. With the fix reverted the if pin goes RED
	// (measured `t["'he said "hi"'"]` against a `\"`-escaped golden),
	// which is the whole point of pinning them.
	'pin-cfg-if-arm-quote':      '[?if [= 1 1] [then "he said \\"hi\\""] [else "she said \\"bye\\""]]'
	'pin-cfg-match-arm-quote':   '[?match 1 [case 1 "he said \\"hi\\""] [else "she said \\"bye\\""]]'
	'pin-erd-scalar-kinds':      '[rec [i 1] [f 1.5e0] [b true] [s "x"] [a :atom]]'
	'pin-erd-non-identifier':    '[+ [x 1] [y 2]]'
	'pin-erd-fk-inference':      '[order [order-id 1] [total 2]]\n[order [order-id 2] [total 3]]'
	'pin-erd-attr-values':       '[item id=1 kind="a"]\n[item id=2 kind="b"]\n[item id=3 kind="c"]'
	'pin-erd-deep-collision':    '[a [b [c "x"]]]\n[b [c "y"]]'
	'pin-erd-scalar-only':       '[point [x 1] [y 2]]'
	'pin-patch-abs-path':        '[?let [= \$x /root/item] \$x]'
	'pin-patch-match-bracket':   '[?match 12 [case [< 13] "small"] [else "big"]]'
	'pin-fallback-unparseable':  '[?if [ unbalanced'
	'pin-fallback-seq-text':     '[?worker name="w" [ unbalanced'
	// RULED: D910-1 (#910) — a pure-data document the PROGRAM reading
	// refuses but the DATA reading accepts takes the ingress's guarded
	// data fallback instead of the empty placeholder. The source carries
	// the three data-only idioms that made the shipped examples/config.cx
	// undiagrammable: the spaced `::T` annotation, a bare URL, a bare
	// filesystem path.
	'pin-data-prose-fallback':   '[server host=0.0.0.0\n  [port ::u16 8080]\n  [origins https://example.com]\n  [file /var/log/app.log]]'
	'pin-pi-stripped':           '[?cx data="x.cxd"]\n[user [name "ada"]]'
	'pin-empty-source':          '   '
	// #898 / DRW3-9 (RULED: ISW-1) — a source element literally named
	// `err`. Each is paired in intent with an identical non-err shape
	// already in this corpus (pin-seq-note-expression,
	// pin-seq-select-timeout), so a reviewer reads the two side by side
	// and sees that only the NAME differs. Measured against the pre-fix
	// engine:
	//   seq-note   — RED, the whole render refused ('code-diagram
	//                refused'); the V emitter wrote `Note over w : [err]`
	//   cfg-branch — RED, 'cx-err:CXER0001: no member "exit"' — the err
	//                propagated out through a dynamic-child position
	//   seq-select — GREEN pre-fix. Kept deliberately as a NEGATIVE pin:
	//                DRW3-9 named this shape as exposed, and it measures
	//                SAFE (the SEQ port's sequence-membership readers
	//                already covered it). It pins that it stays safe.
	'pin-err-literal-seq-note':   '[?worker name="w" [err code="x"]]'
	'pin-err-literal-seq-select': '[?worker name="w" body=[?select [case [timeout 50ms] [err code="timeout"]] [case [default] [other]]]]'
	'pin-err-literal-cfg-branch': '[?if [= 1 1] [then [err code="x"]] [else [ping]]]'
	// #1032 / RULED: SEQ-4 (ledger/rulings_2026_08_26_seq_classification.md)
	// — the shape class this corpus never pinned: a `[?let]` spine whose
	// sequence triggers are ALL let-BOUND (`[= $ch [?channel …]]`) and
	// whose terminal is a NON-trigger. Every SEQ pin above reaches its
	// trigger either bare at top level or bare at the end of the spine,
	// so the classifier's failure to descend through the binding clause
	// was invisible here — and playground examples 171/172, whose exact
	// sources these are, emitted `flowchart TD` for three months and two
	// release cuts while their labels and notes both promised a
	// sequenceDiagram. These two pins are the shape's only guard: with
	// SEQ-2 reverted they go RED (measured `flowchart TD` against a
	// `sequenceDiagram` golden), which is the whole point of pinning them.
	//
	// Sourced verbatim from scripts/gen_guide/playground/playground.examples.js
	// — the page's own bytes, so a corpus edit that re-breaks the shape
	// (as 1ffef3024's v0.8.0 syntax migration did; version-literal-ok) moves these goldens
	// instead of passing unobserved.
	'pin-seq-let-bound-spine-pair': '[?let [= \$ch [?channel name="jobs" buffer=4]]\n  [?let [= \$prod [?worker name="producer"\n                   [body [?let [= \$_ [?for [in \$i [\$range 1 3]]\n                                       [yield [?send \$i to=\$ch]]]]\n                           [?close \$ch]]]]]\n    [?let [= \$cons [?worker name="consumer"\n                     [body [?for [in \$i [\$range 1 3]]\n                             [yield [?receive from=\$ch]]]]]]\n      [?let [= \$_ [?wait-for worker=\$prod]]\n        [?wait-for worker=\$cons]]]]]'
	'pin-seq-let-bound-spine-fanout': '[?let [= \$jobs [?channel name="jobs" buffer=8]]\n  [?let [= \$results [?channel name="results" buffer=16]]\n    [?let [= \$d [?worker name="dispatcher"\n                  [body [?let [= \$_ [?for [in \$j [\$range 1 4]]\n                                      [yield [?send \$j to=\$jobs]]]]\n                          [?close \$jobs]]]]]\n      [?let [= \$w [?worker name="worker"\n                    [body [?for [in \$j [\$range 1 4]]\n                            [yield [?send [processed value=[?receive from=\$jobs]]\n                                     to=\$results]]]]]]\n        [?let [= \$_ [?wait-for worker=\$d]]\n          [?for [in \$k [\$range 1 4]]\n            [yield [?receive from=\$results]]]]]]]]'
}

fn main() {
	out_dir := if os.args.len > 1 {
		os.args[1]
	} else {
		os.join_path('vcx', 'tests', 'testdata', 'code_diagram_golden')
	}
	os.mkdir_all(out_dir) or {
		eprintln('regen_code_diagram_golden: mkdir ${out_dir}: ${err}')
		exit(1)
	}
	mut written := 0
	fixture_file := os.join_path('conformance', 'code_diagram.cxd')
	for c in fixtures.load_fixtures(fixture_file) {
		view := c.meta['view'] or { '' }
		if view != 'graph' {
			continue
		}
		id := c.name.all_before(' ')
		src := c.sections['source'] or { '' }
		written += capture(out_dir, id, src)
	}
	mut pin_ids := pin_sources.keys()
	pin_ids.sort()
	for id in pin_ids {
		written += capture(out_dir, id, pin_sources[id])
	}
	println('regen_code_diagram_golden: wrote ${written} goldens to ${out_dir}')
}

fn capture(out_dir string, id string, src string) int {
	mut n := 0
	// The rendered output does NOT embed its source (unlike the wave-1
	// reference renderer's `%%cx:%%` marker), so the source rides beside
	// the goldens as `<id>.source` — that pair IS the gate's input.
	src_path := os.join_path(out_dir, '${id}.source')
	os.write_file(src_path, src) or {
		eprintln('regen_code_diagram_golden: write ${src_path}: ${err}')
		exit(1)
	}
	for lvl in levels {
		rendered := code.code_diagram_with_level(src, code.parse_code_diagram_level(lvl)) or {
			eprintln('regen_code_diagram_golden: ${id} (${lvl}): ${err}')
			exit(1)
		}
		path := os.join_path(out_dir, '${id}.${lvl}.golden')
		os.write_file(path, rendered) or {
			eprintln('regen_code_diagram_golden: write ${path}: ${err}')
			exit(1)
		}
		n++
	}
	return n
}
