module main

import os
import cli

// The `data`-profile cx binary (I2, partition spec §4) — Ring 0 only.
//
// One binary name, profile-determined verb set: this main dispatches
// parse/emit/convert (the bare `--from/--to` surface), canonical, hash, eq,
// diff, validate (+ version/help) and NOTHING else. It imports only
// `cx` + the shared Ring-0 verb layer `cli`, so there is no evaluator, no
// capability machinery, no protocol stack IN THE ARTIFACT — cannot-execute
// is a property of the binary, not a runtime refusal (ruled, partition
// spec §4). fmt/lint are Ring-1 verbs (spec §2) and are likewise absent.
//
// Homoiconicity note (spec §2): this binary parses program forms —
// `[?for …]`, `[?def …]` — as inert element trees, the way an XML parser
// parses XSLT. `cx hash` of a `[?def]` is identical here and in the
// monolith; the I2 extraction gate pins that byte-for-byte.
//
// Verb words that exist in richer profiles are REFUSED BY NAME (never
// treated as a FILE argument — the #426 lesson), with an error naming the
// profile, so a data-profile install fails loud and self-diagnosing when a
// script expects `cx eval`/`cx lsp`/….

// Version stamp: the SAME build defines the monolith carries (vcx/Makefile's
// VERSION_DEFINES reaches every profile binary), and the SAME headline
// formatter — cli.version_headline, #979/RULED: CO-4. A provenance claim two
// artifacts spell differently is not a claim.
const version = $d('cx_version', '0.0.0-dev')
const cx_release = $d('cx_release', 'dev')
const cx_commit = $d('cx_commit', 'unknown')
const cx_build_date = $d('cx_build_date', 'unknown')
const cx_gc = $d('cx_gc', 'unknown')
const cx_vfork = $d('cx_vfork', 'unknown')

// Verbs that exist in the monolith / richer profiles but NOT here. A first
// argument matching one of these gets a profile refusal, never file-argument
// fall-through. Keep in sync with vcx/cmd/main.v's registry (checked by the
// extraction gate's CLI lane, which probes each name against both binaries).
const absent_profile_verbs = ['fmt', 'lint', 'eval', 'select', 'diagram', 'code-diagram',
	'code-tree', 'table', 'scaffold', 'demo', 'lock', 'lsp', 'store-serve', 'fabric-serve',
	'store-health', 'store-rotate-kek', 'store-mint-principal']

// retired_verbs — verb words that once shipped and were deliberately removed
// (RULED: CO-6). Kept in sync with vcx/cmd/main.v's map; a retired word must
// answer with its retirement in EVERY profile, never with a profile refusal
// that implies availability elsewhere.
const retired_verbs = {
	'store-token': 'the bearer/RBAC plane is gone; store credentials are XSP-AUTH principals granted in the daemon config ([xsp [grants ...]]). Mint one offline with `cx store-mint-principal` (#969).'
}

// Run-surface flags the monolith accepts that are meaningless without an
// evaluator. Refused with the profile message (not "unknown flag") so the
// failure names its cause.
const absent_run_flags = ['-e', '--expression', '--data', '--allow-all']

fn print_version() {
	gc_desc := match cx_gc {
		'e' { 'e — Perceus RC front line + precise STW vgc backstop' }
		'vgc' { 'vgc — precise STW tracing collector' }
		'boehm' { 'boehm — conservative tracing collector' }
		else { cx_gc }
	}
	println(cli.version_headline(version, cx_release, cx_commit))
	println('  profile  data (Ring 0 — no evaluator; this artifact cannot execute programs)')
	println('  commit   ${cx_commit}')
	println('  built    ${cx_build_date}')
	println('  gc       ${gc_desc}')
	println('  V fork   ${cx_vfork}')
}

fn profile_refusal(what string) {
	eprintln('cx: ${what} is not available in the data profile — this artifact has no evaluator and cannot execute programs (by construction).')
	eprintln('data-profile verbs: canonical hash eq diff schema validate version; convert via --from=/--to= (see cx --help)')
	exit(2)
}

struct SubcommandSpec {
	name    string
	summary string
	help    []string
	run     fn ([]string) @[required]
}

const subcommands = build_subcommands()

fn build_subcommands() []SubcommandSpec {
	return [
		SubcommandSpec{
			name:    'canonical'
			summary: 'Strict canonical text (strips presentation; data-equivalent).'
			help:    [
				'Usage: cx canonical [FILE]',
				'',
				'Strict canonical text: strips comments and other presentation; the output',
				'is data-equivalent to the input. Reads FILE, or stdin if absent.',
			]
			run:     cli.run_canonical
		},
		SubcommandSpec{
			name:    'schema'
			summary: 'Schema verb family — infer a .cxs from a corpus; export to JSON Schema; classify compatibility.'
			help:    [
				'Usage: cx schema infer [--sample=N] [--output=FILE] FILE...',
				'       cx schema export --to=json-schema [--output=FILE] SCHEMA.cxs',
				'       cx schema compat [--rename=TYPE/OLD=NEW]... [--allow-remove=TYPE/FIELD]... [--output=FILE] OLD.cxs NEW.cxs',
				'',
				'infer — synthesize a deterministic open-mode .cxs schema from a corpus',
				'of documents (shape_inference.md: identical types stay identical,',
				'int and float join to float, decimal joins only decimal, anything else',
				'becomes [or ...] — never widened to string; attr optionality and child',
				'[card "M..N"] come from observed counts). Full-corpus by default;',
				'--sample=N bounds it and records provenance in the schema header.',
				'',
				'export — project a .cxs schema to JSON Schema 2020-12 describing the',
				'document\'s lossless JSON projection (the \$tag envelope): element types',
				'become \$defs objects; [card] becomes contains/minContains/maxContains;',
				'scalar kinds map to native JSON types with string carriers for exact',
				'numerics, temporals, and bytes. Deterministic byte-stable output.',
				'',
				'compat — classify every field-level change OLD -> NEW into the closed',
				'class set (schema.md §16.5, RULED: SEA-1): additive/widen/rename/',
				'default classes derive their translator (a [schema-lineage] claim +',
				'a generated pure upcaster def, written via --output=FILE); narrowing,',
				'removal, and reinterpreting classes REFUSE with the missing rule named',
				'per change. Renames are declared, never guessed. Exit 0 derivable/',
				'identical; 1 refused; 2 usage/load failure.',
			]
			run:     cli.run_schema
		},
		SubcommandSpec{
			name:    'hash'
			summary: 'SHA-256 hex of the strict-canonical bytes.'
			help:    [
				'Usage: cx hash [FILE]',
				'',
				'SHA-256 hex digest of the strict-canonical bytes — the content address of',
				'the document. Reads FILE, or stdin if absent.',
			]
			run:     cli.run_hash
		},
		SubcommandSpec{
			name:    'eq'
			summary: 'Exit 0 iff strict-canonical(A) == strict-canonical(B).'
			help:    [
				'Usage: cx eq A.cx B.cx',
				'',
				'Compares the strict-canonical forms of two documents.',
				'Exit 0 if equal, 1 if they differ, 2 on error.',
			]
			run:     cli.run_eq
		},
		SubcommandSpec{
			name:    'diff'
			summary: 'Semantic diff (walks the strict-canonical forms).'
			help:    [
				'Usage: cx diff [--format=unified|json|summary] [--no-color] A.cx B.cx',
				'',
				'Semantic diff over the strict-canonical forms.',
				'  --format=unified|json|summary   (default unified)',
				'  --no-color                      disable ANSI color in unified output',
				'  --color[=always|never|auto]     color policy (default auto: TTY only)',
				'Exit 0 if data-equivalent, 1 if the documents differ, 2 on error.',
			]
			run:     cli.run_diff
		},
		SubcommandSpec{
			name:    'validate'
			summary: 'Validate a document against a CX schema (.cxs).'
			help:    [
				'Usage: cx validate FILE --schema=SCHEMA.cxs [opts]',
				'',
				'Validates FILE against the schema.',
				'  --fail-on=info|warn|error|none  exit-1 threshold (default error)',
				'  --mode=open|strict|closed       override the schema-mode directive',
				'  --apply-defaults                insert schema-default attribute values',
				'Exit 0 if no diagnostics at/above --fail-on, 1 if any,',
				'2 on I/O / schema-load failure.',
			]
			run:     cli.run_validate
		},
		SubcommandSpec{
			name:    'version'
			summary: 'Version / build info (same output as -v / --version).'
			help:    [
				'Usage: cx version',
				'',
				'Prints expanded version / build info — version, profile, commit,',
				'build date, GC model, V-fork gitlink — exactly as `cx -v` does.',
			]
			run:     fn (args []string) {
				print_version()
			}
		},
	]
}

fn print_subcommand_help(sc SubcommandSpec) {
	for line in sc.help {
		println(line)
	}
}

fn print_usage_and_exit(exit_code int) {
	mut b := []string{}
	b << 'cx — CX data tool (data profile: parse, convert, canonicalize, hash, diff, validate)'
	b << ''
	b << 'This is the data-profile build: it reads and writes CX (and XML/JSON/YAML/'
	b << 'TOML/MD/CSV/TSV/PSV), and it CANNOT execute programs — there is no eval'
	b << 'verb and no evaluator in the artifact. Program forms parse as inert data.'
	b << ''
	b << 'Usage:'
	b << '  cx [--from=FMT] [--to=FMT | --xml|--json|--yaml|--toml|--md|--csv|--tsv|--psv|--ast|--cxcol]'
	b << '     [--compact] [--lossless] [--include-root=DIR] [FILE|-]'
	b << '      Convert / re-emit a document (default target: canonical CX).'
	b << '      Reads FILE, or stdin when `-` or piped.'
	b << ''
	b << 'Subcommands:'
	for sc in subcommands {
		b << '  ${sc.name:-17} ${sc.summary}'
	}
	b << ''
	b << '  -h, --help      this help'
	b << '  -v, --version   version / build info (incl. profile)'
	out := b.join('\n')
	if exit_code == 0 {
		println(out)
	} else {
		eprintln(out)
	}
	exit(exit_code)
}

fn main() {
	args := os.args[1..]
	if args.len == 0 && os.is_atty(0) != 0 {
		print_usage_and_exit(1)
	}

	if args.len > 0 {
		if args[0] == '-v' || args[0] == '--version' {
			print_version()
			exit(0)
		}
		if args[0] == '-h' || args[0] == '--help' {
			print_usage_and_exit(0)
		}
		for sc in subcommands {
			if args[0] == sc.name {
				rest := args[1..]
				if '--help' in rest || '-h' in rest {
					print_subcommand_help(sc)
					exit(0)
				}
				sc.run(rest)
				return
			}
		}
		// RULED: CO-6 — a RETIRED verb word names its own retirement in every
		// profile: listing it among absent_profile_verbs implied it was
		// available in a richer profile, which is false.
		if args[0] in retired_verbs {
			eprintln('cx: `${args[0]}` is retired — ${retired_verbs[args[0]]}')
			eprintln('run `cx --help` for the current subcommand catalog')
			exit(2)
		}
		if args[0] in absent_profile_verbs {
			profile_refusal('`cx ${args[0]}`')
		}
	}

	// ── Bare CONVERT surface: ONE strict argv pass (#415 discipline) ────────
	// The data profile has no run surface: every input takes the DATA reading
	// and the convert pipeline. For a pure data document the output is
	// byte-identical to the monolith's bare surface (a data document
	// evaluates to itself); program documents are emitted as inert trees.
	mut input := ''
	mut input_file := ''
	mut got_input := false
	mut stdin_input := false
	mut mode := ''
	mut compact := false
	mut lossless := false
	mut explicit_from := false
	mut from_fmt := 'cx'
	mut to_fmt := 'cx'
	mut include_root := ''
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in absent_run_flags || arg.starts_with('--data=') || arg.starts_with('--allow-') {
			profile_refusal('`${arg}` (a run-surface flag)')
		}
		if arg == '-' {
			if got_input {
				eprintln('cx: unexpected `-` — the convert surface takes one input FILE')
				exit(2)
			}
			stdin_input = true
			got_input = true
			i++
			continue
		}
		if arg == '-h' || arg == '--help' {
			print_usage_and_exit(0)
		}
		if arg == '-v' || arg == '--version' {
			print_version()
			exit(0)
		}
		if !arg.starts_with('-') {
			if got_input {
				eprintln('cx: unexpected extra argument ${arg} — the convert surface takes one input FILE')
				exit(2)
			}
			input_file = arg
			got_input = true
			i++
			continue
		}
		// Flag namespace — a closed set; unknown names are hard errors.
		if arg == '--ast' { mode = 'ast' }
		else if arg == '--cx' { mode = 'cx' }
		else if arg == '--xml' { mode = 'xml' }
		else if arg == '--json' { mode = 'json' }
		else if arg == '--yaml' { mode = 'yaml' }
		else if arg == '--toml' { mode = 'toml' }
		else if arg == '--md' { mode = 'md' }
		else if arg == '--csv' { mode = 'csv' }
		else if arg == '--tsv' { mode = 'tsv' }
		else if arg == '--psv' { mode = 'psv' }
		else if arg == '--cxcol' { mode = 'cxcol' }
		else if arg == '--compact' { compact = true }
		else if arg == '--lossless' { lossless = true }
		else if arg.starts_with('--from=') { from_fmt = arg[7..]; explicit_from = true }
		else if arg.starts_with('--to=') { to_fmt = arg[5..] }
		else if arg.starts_with('--include-root=') { include_root = arg[15..] }
		else if arg in ['--from', '--to', '--include-root'] {
			eprintln('cx: ${arg} requires a value (use ${arg}=…)')
			exit(2)
		}
		else {
			eprintln('cx: unknown flag ${arg}')
			eprintln('run `cx --help` for the accepted convert flag set')
			exit(2)
		}
		i++
	}

	if stdin_input {
		input = os.get_raw_lines_joined()
	} else if input_file != '' {
		input = os.read_file(input_file) or {
			eprintln('error reading file ${input_file}: ${err}')
			exit(1)
		}
	} else if !got_input {
		if os.is_atty(0) != 0 {
			print_usage_and_exit(1)
		}
		input = os.get_raw_lines_joined()
	}

	if include_root != '' && from_fmt == 'cx' {
		input = cli.resolve_includes_text(input, include_root) or {
			eprintln('error resolving includes: ${err}')
			exit(1)
		}
	}

	// Auto-detect input format from file extension if not explicit
	if !explicit_from && input_file.len > 0 {
		if input_file.ends_with('.xml') { from_fmt = 'xml' }
		else if input_file.ends_with('.json') { from_fmt = 'json' }
		else if input_file.ends_with('.yaml') || input_file.ends_with('.yml') { from_fmt = 'yaml' }
		else if input_file.ends_with('.toml') { from_fmt = 'toml' }
		else if input_file.ends_with('.md') { from_fmt = 'md' }
	}

	if mode.len == 0 { mode = to_fmt }

	// #416/#444 lossless-lane enforcement — shared rationale at
	// cli.check_lossless.
	if lossless {
		cli.check_lossless(mode)
	}

	cli.convert_and_print(input, from_fmt, mode, compact, lossless)
}
