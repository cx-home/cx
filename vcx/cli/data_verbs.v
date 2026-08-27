module cli

import os
import cx

// cli — the Ring-0 CLI verb layer (I2, partition spec §4/§10 phase 2).
//
// Every function here implements a `data`-profile verb or a shared piece of
// the bare convert surface, and imports ONLY `os` + `cx` (Ring 0). Two
// binaries consume it: the monolith `cx` (vcx/cmd/ — which adds the run/eval
// surface, Ring-1/2 verbs, and delegates its data verbs here) and the
// `data`-profile `cx` (vcx/cmd_data/ — which dispatches ONLY these verbs and
// carries no evaluator, by construction). The implementations moved verbatim
// from vcx/cmd/main.v; behavior is pinned by the I2 byte-for-byte extraction
// gate (monolith vs data-profile CLI differential over the Ring-0 corpus).

// read_one_input reads the single [FILE] argument of a one-input verb, or
// stdin when absent.
pub fn read_one_input(args []string, cmd string) string {
	if args.len > 1 {
		eprintln('Usage: cx ${cmd} [FILE]')
		eprintln('Reads from FILE if given, otherwise stdin.')
		exit(2)
	}
	if args.len == 1 {
		return os.read_file(args[0]) or { eprintln('cx ${cmd}: ${err}'); exit(2) }
	}
	return os.get_raw_lines_joined()
}

// resolve_includes_text parses the given CX source with include
// resolution enabled against `root`, then emits the resolved AST
// back to canonical CX text. Used by the bare convert surface (and the
// monolith's eval lane) to bolt `--include-root` onto entry points whose
// downstream library calls only accept raw text. Round-trip cost
// is one extra parse + emit; acceptable for the doc-gen + ad-hoc
// CLI use cases that need this flag.
pub fn resolve_includes_text(src string, root string) !string {
	if root == '' {
		return src
	}
	doc := cx.parse_with_include_root(src, root)!
	return cx.emit_cx(doc)
}

pub fn run_canonical(args []string) {
	src := read_one_input(args, 'canonical')
	out := cx.cx_text_canonical(src) or { eprintln('cx canonical: ${err}'); exit(1) }
	println(out)
}

pub fn run_hash(args []string) {
	src := read_one_input(args, 'hash')
	out := cx.cx_text_hash(src) or { eprintln('cx hash: ${err}'); exit(1) }
	println(out)
}

pub fn run_eq(args []string) {
	if args.len != 2 {
		eprintln('Usage: cx eq FILE_A FILE_B')
		eprintln('Exits 0 if strict-canonical(A) == strict-canonical(B), 1 if not, 2 on error.')
		exit(2)
	}
	a := os.read_file(args[0]) or { eprintln('cx eq: ${err}'); exit(2) }
	b := os.read_file(args[1]) or { eprintln('cx eq: ${err}'); exit(2) }
	eq := cx.cx_text_eq(a, b) or { eprintln('cx eq: ${err}'); exit(2) }
	exit(if eq { 0 } else { 1 })
}

// run_diff implements `cx diff [--format=unified|json|summary] [--no-color] A B`
// per internal design record Exit codes 0/1/2.
pub fn run_diff(args []string) {
	mut format := 'unified'
	mut color_pref := 'auto'
	mut files := []string{}
	for arg in args {
		if arg.starts_with('--format=') {
			format = arg[9..]
		} else if arg == '--no-color' {
			color_pref = 'never'
		} else if arg == '--color' || arg.starts_with('--color=') {
			val := if arg == '--color' { 'always' } else { arg[8..] }
			color_pref = val
		} else if arg.starts_with('--') {
			eprintln('cx diff: unknown flag ${arg}')
			eprintln('Usage: cx diff [--format=unified|json|summary] [--no-color] A.cx B.cx')
			exit(2)
		} else {
			files << arg
		}
	}
	if files.len != 2 {
		eprintln('Usage: cx diff [--format=unified|json|summary] [--no-color] A.cx B.cx')
		eprintln('Exit 0 if data-equivalent, 1 if differs, 2 on error.')
		exit(2)
	}
	a := os.read_file(files[0]) or { eprintln('cx diff: ${err}'); exit(2) }
	b := os.read_file(files[1]) or { eprintln('cx diff: ${err}'); exit(2) }
	changes := cx.cx_text_diff(a, b) or { eprintln('cx diff: ${err}'); exit(2) }

	color := match color_pref {
		'always' { true }
		'never' { false }
		else { os.is_atty(1) > 0 } // auto: TTY check
	}

	out := match format {
		'unified' { cx.diff_render_unified(changes, color) }
		'json' { cx.diff_render_json(changes) }
		'summary' { cx.diff_render_summary(changes) }
		else {
			eprintln('cx diff: unknown --format=${format} (use unified|json|summary)')
			exit(2)
		}
	}
	if out.len > 0 {
		println(out)
	}
	exit(if changes.len == 0 { 0 } else { 1 })
}

// run_validate implements `cx validate FILE --schema=SCHEMA.cxs` per
// spec/schema.md §10 (). Exit codes:
// 0 — no diagnostics at or above --fail-on threshold
// 1 — diagnostics at or above threshold
// 2 — usage / I/O / schema-load failure
// Default --fail-on=error matches `cx lint`.
pub fn run_validate(args []string) {
	mut schema_path := ''
	mut fail_on := 'error'
	mut mode_override := ''
	mut apply_defaults := false
	mut doc_files := []string{}
	for arg in args {
		if arg.starts_with('--schema=') {
			schema_path = arg[9..]
		} else if arg == '--schema' {
			eprintln('cx validate: --schema requires a value (use --schema=FILE)')
			exit(2)
		} else if arg.starts_with('--fail-on=') {
			fail_on = arg[10..]
		} else if arg.starts_with('--mode=') {
			mode_override = arg[7..]
		} else if arg == '--apply-defaults' {
			apply_defaults = true
		} else if arg.starts_with('--') {
			eprintln('cx validate: unknown flag ${arg}')
			eprintln('Usage: cx validate FILE --schema=SCHEMA.cxs')
			eprintln(' [--fail-on=info|warn|error|none] [--mode=open|strict|closed]')
			eprintln(' [--apply-defaults]')
			exit(2)
		} else {
			doc_files << arg
		}
	}
	if doc_files.len != 1 {
		eprintln('Usage: cx validate FILE --schema=SCHEMA.cxs [opts]')
		eprintln('Exit 0 if no diagnostics at/above --fail-on threshold (default error),')
		eprintln(' 1 if any diagnostic at/above threshold, 2 on I/O / schema-load failure.')
		exit(2)
	}
	if schema_path == '' {
		eprintln('cx validate: --schema=SCHEMA.cxs is required')
		exit(2)
	}
	doc_path := doc_files[0]
	doc_src := os.read_file(doc_path) or { eprintln('cx validate: ${err}'); exit(2) }
	schema_src := os.read_file(schema_path) or { eprintln('cx validate: ${err}'); exit(2) }
	// #792: the positioned door — `cx validate` is the surface that
	// prints FILE:LINE:COL to a human, so it is the one that pays for
	// element positions. Every other parse in the system stays on
	// parse_cx and allocates no ElementMeta it did not already need.
	doc := cx.parse_cx_positioned(doc_src) or { eprintln('cx validate: parse error: ${err}'); exit(2) }
	doc_single := doc.single or {
		eprintln('cx validate: multi-document inputs not yet supported')
		exit(2)
	}
	mut opts := cx.ValidateOptions{}
	if mode_override != '' {
		opts = cx.ValidateOptions{
			mode_override: match mode_override {
				'open' { ?cx.SchemaMode(cx.SchemaMode.open) }
				'strict' { ?cx.SchemaMode(cx.SchemaMode.strict) }
				'closed' { ?cx.SchemaMode(cx.SchemaMode.closed) }
				else {
					eprintln('cx validate: unknown --mode=${mode_override} (use open|strict|closed)')
					exit(2)
				}
			}
		}
	}
	report := if apply_defaults {
		cx.validate_with_defaults(doc_single, schema_src, opts) or {
			eprintln('cx validate: ${err}')
			exit(2)
		}
	} else {
		cx.validate(doc_single, schema_src, opts) or {
			eprintln('cx validate: ${err}')
			exit(2)
		}
	}
	if report.diagnostics.len > 0 {
		println(report.render(doc_path))
	}
	threshold := match fail_on {
		'info' { cx.Severity.info }
		'warn' { cx.Severity.warn }
		'error' { cx.Severity.error_severity }
		'none' { exit(0) }
		else {
			eprintln('cx validate: unknown --fail-on=${fail_on} (use info|warn|error|none)')
			exit(2)
		}
	}
	exit(if report.has_at_or_above_severity(threshold) { 1 } else { 0 })
}

// check_lossless enforces #416/#444: --lossless is honored only by lanes
// whose emitter implements a lossless image (conversions.md §0.2): cx, xml
// (`<cx:T>` carriers), json (`cx:type` sidecar) and yaml (`!!cx:T` tags) —
// read from the codec registry's capability flag, the single source of
// truth. TOML/MD lossless is spec'd as unsupported; every non-lossless lane
// REJECTS the flag loudly (the pre-#416 CLI accepted it as a silent no-op).
// Checked here (not only in convert_by_name) because csv/tsv/psv/ast/cxcol
// dispatch bypasses the codec-registry compose.
pub fn check_lossless(mode string) {
	mode_lossless := (cx.codec_lookup(mode) or { cx.Codec{} }).lossless
	if !mode_lossless {
		eprintln('error: --lossless is not supported for --to=${mode}; supported: ${cx.lossless_codec_names().join(', ')}')
		exit(2)
	}
}

// convert_and_print runs the data-reading convert pipeline (the bare
// surface's non-eval path) and prints the result: structural projections
// (ast/cxcol), compact CX, and the delimited direct lanes dispatch here;
// everything else goes through the ONE codec registry (codec.md §6) — any
// registered codec is reachable by name, and an unknown name errors
// ("unknown source/target format: …") rather than silently folding to cx.
pub fn convert_and_print(input string, from_fmt string, mode string, compact bool, lossless bool) {
	out := if mode == 'ast' {
		cx.to_ast(input) or {
			eprintln('error: ${err}')
			// #1019: the three-way E211 / evaluator split is WORKS AS
			// SPECIFIED — `[m x=[$call]]` is a legal PROGRAM form and an
			// illegal DATA attribute (code.md §6.4.1 VALUE-must-reduce-to-
			// scalar at eval; lexicon §10 D2 refuses node-valued attrs at
			// parse; code.md §1.3 DATA ⊆ PROGRAM). `--ast` is the data
			// reading, so it is RIGHT to refuse. What was missing is the
			// orientation: a program-shaped resource on the DATA projection
			// looks like the lane disagreeing with itself. One extra line
			// names the lane. Message-only — the verdict and exit code are
			// unchanged.
			if err.msg().contains('cx-err:E211')
				&& cx.source_carries_program_directive(input.bytes()) {
				eprintln('this resource is program-shaped; --ast is the DATA projection (cli.md §2.2)')
			}
			exit(1)
		}
	} else if mode == 'cx' && compact {
		cx.to_cx_compact(input) or { eprintln('error: ${err}'); exit(1) }
	} else if mode == 'csv' {
		cx.to_csv(input) or { eprintln('error: ${err}'); exit(1) }
	} else if mode == 'tsv' {
		cx.to_tsv(input) or { eprintln('error: ${err}'); exit(1) }
	} else if mode == 'psv' {
		cx.to_psv(input) or { eprintln('error: ${err}'); exit(1) }
	} else if mode == 'cxcol' {
		doc := cx.parse(input) or { eprintln('error: ${err}'); exit(1) }
		bytes := cx.emit_data_bin(doc) or { eprintln('error: ${err}'); exit(1) }
		C.write(1, bytes.data, bytes.len)
		return
	} else {
		cx.convert_by_name(input, from_fmt, mode, lossless) or {
			eprintln('error: ${err}')
			exit(1)
		}
	}
	println(out)
}
