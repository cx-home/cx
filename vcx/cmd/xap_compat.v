module main

import os
import cx

// `cx xap compat` — the publisher-facing half of AD-2 (#1182).
//
// Byte-for-byte the `cx schema compat` contract, deliberately: SEA-1 already
// taught adopters what a compat verb does and what its exit codes mean, and
// the whole point of AD-2 is that the CONTRACT half was missing the treatment
// the SCHEMA half already had. A second, differently-shaped command would
// have re-taught the same lesson in a new dialect.
//
//   exit 0  identical / additive / narrowing — the publish would proceed
//   exit 1  reinterpreting — the publish would refuse (CXER4892)
//   exit 2  usage / load failure
//
// This is the surfaced-ahead-of-publish face. The enforcing face is the
// publish stage itself; both call `cx.feature_compat`, so they cannot drift.
fn run_xap_compat(args []string) {
	mut files := []string{}
	mut renames := map[string]string{}
	for arg in args {
		if arg.starts_with('--rename=') {
			decl := arg.all_after('--rename=')
			if !decl.contains('=') || !decl.all_before('=').contains('/') {
				eprintln('cx xap compat: --rename takes KIND/OLD=NEW (kind: verb, noun, rule, key, field)')
				exit(2)
			}
			renames[decl.all_before('=')] = decl.all_after('=')
		} else if arg.starts_with('-') {
			eprintln("cx xap compat: unknown flag '${arg}'")
			exit(2)
		} else {
			files << arg
		}
	}
	if files.len != 2 {
		eprintln('Usage: cx xap compat [--rename=KIND/OLD=NEW]... OLD.feature.cxd NEW.feature.cxd')
		exit(2)
	}
	old_text := os.read_file(files[0]) or {
		eprintln('cx xap compat: ${err}')
		exit(2)
	}
	new_text := os.read_file(files[1]) or {
		eprintln('cx xap compat: ${err}')
		exit(2)
	}
	rep := cx.feature_compat(old_text, new_text, cx.FeatureCompatOpts{
		renames: renames
	}) or {
		eprintln('cx xap compat: ${err}')
		exit(2)
	}
	print(cx.feature_compat_report_text(rep))
	flush_stdout()
	if rep.verdict == 'refused' {
		exit(1)
	}
}
