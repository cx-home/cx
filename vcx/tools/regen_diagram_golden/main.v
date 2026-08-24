module main

import os
import cx
import code
import fixtures
import platform as _

// regen_diagram_golden — captures the reference renderer's Mermaid
// output for every supported `program-viz-*` fixture at all three
// detail rungs (min / compact / full) into the committed golden corpus
// `vcx/tests/testdata/diagram_mermaid_golden/<id>.<detail>.golden`.
//
// The corpus is the DR-8 bit-for-bit instrument for the CX port of the
// renderer (RULED 2026-08-20, ledger/rulings_2026_08_20_diagram_renderer.md):
// it was captured ONCE from the unmodified V renderer at the wave-1
// head — capturing shipped behavior, not moving goldens — and any
// regeneration after that is golden movement, forbidden except under a
// DR-8 mini-ruling recorded in the ledger BEFORE the bytes move.
//
// The byte-equality gate is vcx/tests/diagram_mermaid_golden_test.v.

const details = ['min', 'compact', 'full']

// Synthetic pin corpus — sources chosen (at capture time, against the
// UNMODIFIED V renderer) to reach the emitter surfaces the
// `program-viz-*` fixtures never exercise with their current parse
// shapes: labeled then/else arms, pipe fn-stage capsules, iteration
// using=/init=/par=/ordered=, resilience body= wiring, fallback err
// edges, channel/send/receive placeholder wiring + escapes, nested
// select case arms, nested service/worker capsules, async/await/cancel
// shapes, call + attr-chip + truncation labels. Each renders at all
// three detail rungs.
const pin_sources = {
	'pin-pipe-fn-stages':        '[?pipe (1, 2) through=[?fn (\$x) [* \$x 2]] through=[?fn (\$y) [+ \$y 1]]]'
	'pin-if-labeled-arms':       '[?if [> \$x 0] then=[pos] else=[neg]]'
	'pin-map-using-par-ordered': '[?map \$xs using=[?fn (\$x) [* \$x \$x]] par=true ordered=true]'
	'pin-reduce-using-init':     '[?reduce \$xs using=[?fn (\$a \$b) [+ \$a \$b]] init=0]'
	'pin-retry-body':            '[?retry max=3 backoff=exponential delay=100ms body=[?http-client get="https://api.example.com/x"]]'
	'pin-fallback-err-edge':     '[?fallback body=[?http-client get="https://a.example/x"] recover-with=[?http-client get="https://b.example/y"]]'
	'pin-select-top-sequence':   '[?select case=[arm from=\$cha do=[handled-a]] case=[arm from=\$chb do=[handled-b]]]'
	'pin-await-all-async':       '[?await-all ([?async body=[step-a]], [?async body=[step-b]])]'
	'pin-worker-top-sequence':   '[?worker name="w1" body=[?receive from=\$ch]]'
	'pin-fn-attr-chips':         '[?map \$xs using=[?fn (\$x) [user id=1 name=\'ada\' role=\'admin\' tenant=\'acme\']]]'
	'pin-if-nested-cancel':      '[?if [> \$extremely-long-binding-name-that-overflows-the-truncation-cap 1000000] then=[a-very-long-element-name-here-yes k=\'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\' [child]] else=[?cancel \$future-handle]]'
	'pin-send-placeholder':      '[?send "m" to=\$ch]'
	// RULED: D913-1 (#913) — a structure-free document renders its element
	// tree (captured by hand at the landing, not regenerated). The source
	// PROGRAM-parses — this lane's extract check requires it — and the
	// detector is semantic (no cx-node mark), so the same render covers the
	// D910-1 data-lift class, whose provenance pins live in
	// diagram_of_source_test.
	'pin-data-doc-tree':         '[server host=0.0.0.0 tls=true\n  [port 8080]\n  [workers 4]\n  [logging [level info] [rotate daily]]]'
	'pin-try-receive':           '[?try-receive from=\$ch]'
	'pin-channel-escape':        '[?channel name="jobs" buffer=4]'
	'pin-cancel-async':          '[?cancel [?async body=[long-job]]]'
	'pin-timeout-body':          '[?timeout 500ms body=[work-item]]'
	'pin-nested-select-send':    '[?if \$p then=[?select case=[arm from=\$ch do=[handled]] case=[arm from=\$other]] else=[?send "x" to=\$ch]]'
	'pin-nested-service-worker': '[?if \$p then=[?http-service name="svc-a"] else=[?worker name="w2" body=[?receive from=\$ch]]]'
	'pin-pipe-call-label':       '[?pipe \$in through=[?fn (\$x) [\$compute \$x 2]] through=[?reduce \$x using=[?fn (\$a \$b) [+ \$a \$b]] init=0]]'
	'pin-label-truncation':      '[?cancel \$a-binding-name-that-is-well-over-forty-eight-characters-long-for-truncation]'
}

fn main() {
	out_dir := if os.args.len > 1 {
		os.args[1]
	} else {
		os.join_path('vcx', 'tests', 'testdata', 'diagram_mermaid_golden')
	}
	os.mkdir_all(out_dir) or {
		eprintln('regen_diagram_golden: mkdir ${out_dir}: ${err}')
		exit(1)
	}
	fixture_file := os.join_path('conformance', 'code.cxd')
	mut written := 0
	for c in fixtures.load_fixtures(fixture_file) {
		if !c.name.starts_with('program-viz-') {
			continue
		}
		in_code := c.sections['in_code']
		out_err := c.sections['out_err'] or { '' }.trim_space()
		if out_err != '' {
			// Render-error fixtures have no output to capture.
			continue
		}
		cx.parse_program(in_code) or {
			eprintln('regen_diagram_golden: ${c.name}: parse: ${err}')
			exit(1)
		}
		for d in details {
			rendered := code.render_diagram(in_code, 'mermaid:${d}') or {
				eprintln('regen_diagram_golden: ${c.name} (${d}): ${err}')
				exit(1)
			}
			path := os.join_path(out_dir, '${c.name}.${d}.golden')
			os.write_file(path, rendered) or {
				eprintln('regen_diagram_golden: write ${path}: ${err}')
				exit(1)
			}
			written++
		}
	}
	mut pin_names := pin_sources.keys()
	pin_names.sort()
	for name in pin_names {
		src := pin_sources[name]
		cx.parse_program(src) or {
			eprintln('regen_diagram_golden: ${name}: parse: ${err}')
			exit(1)
		}
		for d in details {
			rendered := code.render_diagram(src, 'mermaid:${d}') or {
				eprintln('regen_diagram_golden: ${name} (${d}): ${err}')
				exit(1)
			}
			path := os.join_path(out_dir, '${name}.${d}.golden')
			os.write_file(path, rendered) or {
				eprintln('regen_diagram_golden: write ${path}: ${err}')
				exit(1)
			}
			written++
		}
	}
	println('regen_diagram_golden: wrote ${written} golden file(s) to ${out_dir}/')
}
