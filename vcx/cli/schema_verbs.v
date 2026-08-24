module cli

import os
import cx

// cx schema — the Ring-0 schema verb family (shape_inference.md §2/§8,
// stream 16). Imports ONLY os + cx; both binaries dispatch here (the
// monolith and the data profile — corpus shape synthesis needs no
// evaluator). W3 lands `infer`; `export` follows (W6); embed/extract/
// bundle remain spec-only until their waves.

pub fn run_schema(args []string) {
	if args.len == 0 {
		eprintln('Usage: cx schema infer [--sample=N] [--output=FILE] FILE...')
		eprintln('       cx schema export --to=json-schema [--output=FILE] SCHEMA.cxs')
		eprintln('       cx schema compat [--rename=TYPE/OLD=NEW]... [--allow-remove=TYPE/FIELD]... [--output=FILE] OLD.cxs NEW.cxs')
		eprintln("Sub-verbs: infer (synthesize an open-mode .cxs schema from a corpus);")
		eprintln("           export (project a .cxs to JSON Schema 2020-12 — the \$tag-envelope shape);")
		eprintln('           compat (classify every field-level change old->new, derive the translator')
		eprintln('                   for the derivable classes, refuse reinterpreting changes with the')
		eprintln('                   missing rule named — schema.md §16.5, RULED: SEA-1)')
		exit(2)
	}
	match args[0] {
		'infer' { run_schema_infer(args[1..]) }
		'export' { run_schema_export(args[1..]) }
		'compat' { run_schema_compat(args[1..]) }
		else {
			eprintln("cx schema: unknown sub-verb '${args[0]}' (expected: infer, export, compat)")
			exit(2)
		}
	}
}

// run_schema_compat — the L149 predicate as a CLI verb (schema.md §16.5).
// Exit 0: derivable/identical; exit 1: refused (missing rules named on
// stdout in the report); exit 2: usage / parse / load failure.
fn run_schema_compat(args []string) {
	mut files := []string{}
	mut renames := map[string]string{}
	mut allow_remove := []string{}
	mut output := ''
	for arg in args {
		if arg.starts_with('--rename=') {
			decl := arg.all_after('--rename=')
			if !decl.contains('=') || !decl.all_before('=').contains('/') {
				eprintln('cx schema compat: --rename takes TYPE/OLD=NEW')
				exit(2)
			}
			renames[decl.all_before('=')] = decl.all_after('=')
		} else if arg.starts_with('--allow-remove=') {
			decl := arg.all_after('--allow-remove=')
			if !decl.contains('/') {
				eprintln('cx schema compat: --allow-remove takes TYPE/FIELD')
				exit(2)
			}
			allow_remove << decl
		} else if arg.starts_with('--output=') {
			output = arg.all_after('--output=')
		} else if arg.starts_with('-') {
			eprintln("cx schema compat: unknown flag '${arg}'")
			exit(2)
		} else {
			files << arg
		}
	}
	if files.len != 2 {
		eprintln('Usage: cx schema compat [--rename=TYPE/OLD=NEW]... [--allow-remove=TYPE/FIELD]... [--output=FILE] OLD.cxs NEW.cxs')
		exit(2)
	}
	old_text := os.read_file(files[0]) or {
		eprintln('cx schema compat: ${err}')
		exit(2)
	}
	new_text := os.read_file(files[1]) or {
		eprintln('cx schema compat: ${err}')
		exit(2)
	}
	rep := cx.schema_compat(old_text, new_text, cx.SchemaCompatOpts{
		renames:      renames
		allow_remove: allow_remove
	}) or {
		eprintln('cx schema compat: ${err}')
		exit(2)
	}
	print(cx.schema_compat_report_text(rep))
	flush_stdout()
	if rep.verdict == 'refused' {
		exit(1)
	}
	if output != '' {
		if rep.translator == '' {
			eprintln('cx schema compat: the schemas are identical — nothing to derive (no translator written)')
		} else {
			os.write_file(output, rep.translator) or {
				eprintln('cx schema compat: ${err}')
				exit(2)
			}
		}
	}
}

fn run_schema_export(args []string) {
	mut files := []string{}
	mut to := ''
	mut output := ''
	for arg in args {
		if arg.starts_with('--to=') {
			to = arg.all_after('--to=')
		} else if arg.starts_with('--output=') {
			output = arg.all_after('--output=')
		} else if arg.starts_with('-') {
			eprintln("cx schema export: unknown flag '${arg}'")
			exit(2)
		} else {
			files << arg
		}
	}
	if to != 'json-schema' {
		eprintln('cx schema export: --to=json-schema is the supported target (XSD follows the #288 mapping table)')
		exit(2)
	}
	if files.len != 1 {
		eprintln('Usage: cx schema export --to=json-schema [--output=FILE] SCHEMA.cxs')
		exit(2)
	}
	text := os.read_file(files[0]) or {
		eprintln('cx schema export: ${err}')
		exit(2)
	}
	out := cx.schema_export_json_schema(text) or {
		eprintln('cx schema export: ${files[0]}: ${err}')
		exit(2)
	}
	if output != '' {
		os.write_file(output, out) or {
			eprintln('cx schema export: ${err}')
			exit(2)
		}
	} else {
		print(out)
		flush_stdout()
	}
}

fn run_schema_infer(args []string) {
	mut files := []string{}
	mut sample := 0
	mut output := ''
	for arg in args {
		if arg.starts_with('--sample=') {
			sample = arg.all_after('--sample=').int()
			if sample <= 0 {
				eprintln('cx schema infer: --sample takes a positive document count')
				exit(2)
			}
		} else if arg.starts_with('--output=') {
			output = arg.all_after('--output=')
		} else if arg.starts_with('-') {
			eprintln("cx schema infer: unknown flag '${arg}'")
			exit(2)
		} else {
			files << arg
		}
	}
	if files.len == 0 {
		eprintln('Usage: cx schema infer [--sample=N] [--output=FILE] FILE...')
		exit(2)
	}
	// Deterministic corpus order regardless of shell glob order.
	files.sort()
	mut docs := []cx.Document{}
	for f in files {
		src := os.read_file(f) or {
			eprintln('cx schema infer: ${err}')
			exit(2)
		}
		ext := os.file_ext(f).trim_left('.').to_lower()
		if ext in ['', 'cx', 'cxd', 'cxs'] {
			docs << cx.parse(src) or {
				eprintln('cx schema infer: ${f}: ${err}')
				exit(2)
			}
		} else {
			// Non-CX corpora enter through the codec table (a parser may
			// be profile-dependent — e.g. json's strict parser lives in
			// the code layer and is absent from the data profile).
			n := cx.codec_parse_node(ext, src) or {
				eprintln('cx schema infer: ${f}: ${err}')
				exit(2)
			}
			if n is cx.Element {
				docs << cx.Document{
					elements: [cx.Node(n)]
				}
			} else {
				eprintln('cx schema infer: ${f}: the ${ext} corpus document is not element-rooted (inference synthesizes element schemas)')
				exit(2)
			}
		}
	}
	schema := cx.schema_infer(docs, cx.SchemaInferOpts{ sample: sample }) or {
		eprintln('cx schema infer: ${err}')
		exit(2)
	}
	if output != '' {
		os.write_file(output, schema) or {
			eprintln('cx schema infer: ${err}')
			exit(2)
		}
	} else {
		print(schema)
		flush_stdout()
	}
}
