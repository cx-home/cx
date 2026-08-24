module main

import os
import cx
import code
import fixtures
import platform as _

// regen_diagram_vector_golden — the WAVE-2 DR-8 bit-for-bit instrument
// (#758, RULED 2026-08-20; ledger/rulings_2026_08_20_diagram_renderer.md).
//
// Captures the DETERMINISTIC halves of the SVG/PNG path from the
// pre-cutover V renderer, into
// `vcx/tests/testdata/diagram_vector_golden/`:
//
//   <id>.dot             — the DOT text fed to graphviz (ours, exact)
//   envelope.svg         — the dot-less SVG envelope for a fixed source
//   envelope.png         — the dot-less PNG envelope for a fixed source
//   splice.svg           — inject_svg_metadata over a FIXED svg input
//   splice.png           — inject_png_text_chunk over a FIXED png input
//
// graphviz's OWN output is version- and font-dependent, so it is not
// goldenable across machines; gate 9 covers the live end-to-end hop.
// Everything this tool captures is authored by us and byte-exact.
//
// Captured ONCE from the unmodified V code at the wave-2 head; this
// tool now REGENERATES the same corpus from the CX module, so a
// regeneration that moves bytes is exactly the DR-8 signal. Any
// regeneration after the cutover is golden movement — forbidden except
// under a DR-8 mini-ruling recorded in the ledger BEFORE the bytes
// move. The byte-equality gate is
// vcx/tests/diagram_vector_golden_test.v.

// The fixed splice inputs — chosen so the splice arithmetic (SVG's
// "after the first >" rule; PNG's "after the IHDR chunk" offset walk +
// CRC-32 over type+data) is pinned without depending on graphviz.
const fixed_svg_input = '<?xml version="1.0"?>\n<svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">\n  <g id="graph0"><title>CX</title></g>\n</svg>\n'

const fixed_source = '[?retry max=3 [?timeout 500ms [?async [?http-client target=\$url]]]]'

// fixed_png_input is a minimal but REAL png: signature + IHDR(1x1
// grayscale) + IDAT + IEND, built the same way the envelope builder
// does so the splice's IHDR-offset walk is exercised on a valid file.
fn fixed_png_input() string {
	return code.diagram_png_envelope_cx('') or { panic(err) }
}

fn main() {
	out_dir := if os.args.len > 1 {
		os.args[1]
	} else {
		os.join_path('vcx', 'tests', 'testdata', 'diagram_vector_golden')
	}
	os.mkdir_all(out_dir) or {
		eprintln('regen_diagram_vector_golden: mkdir ${out_dir}: ${err}')
		exit(1)
	}
	mut written := 0
	// ── per-fixture DOT text ────────────────────────────────────────
	for c in fixtures.load_fixtures(os.join_path('conformance', 'code.cxd')) {
		if !c.name.starts_with('program-viz-') {
			continue
		}
		if (c.sections['out_err'] or { '' }).trim_space() != '' {
			continue
		}
		in_code := c.sections['in_code']
		prog := cx.parse_program(in_code) or {
			eprintln('regen_diagram_vector_golden: ${c.name}: parse: ${err}')
			exit(1)
		}
		dot := code.render_dot_cx(prog) or {
			eprintln('regen_diagram_vector_golden: ${c.name}: render-dot: ${err}')
			exit(1)
		}
		os.write_file(os.join_path(out_dir, '${c.name}.dot'), dot) or {
			eprintln('regen_diagram_vector_golden: write: ${err}')
			exit(1)
		}
		written++
	}
	// ── the two dot-less envelopes ──────────────────────────────────
	os.write_file(os.join_path(out_dir, 'envelope.svg'), code.diagram_svg_envelope_cx(fixed_source) or { panic(err) }) or {
		panic(err)
	}
	written++
	os.write_file(os.join_path(out_dir, 'envelope.png'), code.diagram_png_envelope_cx(fixed_source) or { panic(err) }) or {
		panic(err)
	}
	written++
	// ── the two splices over fixed inputs ───────────────────────────
	os.write_file(os.join_path(out_dir, 'splice.svg'), code.diagram_svg_splice_cx(fixed_svg_input, fixed_source) or { panic(err) }) or { panic(err) }
	written++
	os.write_file(os.join_path(out_dir, 'splice.png'), code.diagram_png_splice_cx(fixed_png_input(), fixed_source) or { panic(err) }) or { panic(err) }
	written++
	println('regen_diagram_vector_golden: wrote ${written} golden file(s) to ${out_dir}/')
}
