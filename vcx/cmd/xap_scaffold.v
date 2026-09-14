module main

import os

// `cx xap scaffold PATTERN [--dir D]` — emit one COMPOSITION PATTERN's
// declaration skeleton (#1487, RULED: COMP-1).
//
// composition.md §3 states a closed set of seven patterns, each with the
// enterprise need it answers, the modules it uses, a declaration skeleton
// drawn from the specifications' own examples, and the §2 seam rows it
// crosses. An adopter's agent that has read `cx primer`'s platform chapter
// knows the set exists; this command is how it starts from one of them
// without re-typing a skeleton out of a specification and without inventing
// the parts the specification deliberately leaves open.
//
// WHAT THE PATTERN STATES BECOMES A DECLARATION; WHAT IT DOES NOT BECOMES AN
// AUTHORING TODO, NEVER A GUESS. That is the discipline connector.md §6.3
// fixes for every skeleton the toolchain emits (RULED: 1430-g): an
// undetectable pagination shape becomes a TODO on the verb, anything about
// idempotency becomes a TODO per act verb, a security scheme outside the
// closed set becomes a TODO rather than the nearest member of it. A scaffold
// that guessed would be worse than a blank page, because a plausible wrong
// default is the kind an author does not re-read.
//
// It is PURE: fixture in — the pattern name — skeleton out. No network, no
// clock, no registry, nothing read from the tree. Every emitted document
// parses (`cx lint`), which is what the pattern's own test asserts for all
// seven.
//
// UNLIKE `cx xap init`, THE RESULT DOES NOT RUN AS GENERATED, and says so in
// its README: a composition pattern is a shape, and the feature names, the
// verbs, the thresholds, the routes and every deployment fact are the
// author's. `cx xap init` scaffolds a project that composes unedited because
// a project HAS a working shape; a pattern does not.

fn xap_scaffold_usage_lines() []string {
	mut u := [
		'Usage: cx xap scaffold PATTERN [--dir DIR]',
		'',
		"Emits one composition pattern's declaration skeleton — the flow",
		'document, the feature and gateway declarations and the deployment',
		'binding the pattern states — with an authoring TODO wherever the',
		'pattern fixes no value. The set is CLOSED (composition.md §3):',
		'',
	]
	for p in xap_scaffold_patterns() {
		u << '  ${p.slug:-24} ${p.section} ${p.title}'
	}
	u << ''
	u << '  --dir DIR   where to create it (default: ./PATTERN)'
	u << ''
	u << 'A composition an adopter needs that is not one of the seven is a'
	u << 'decision for the owner, not a variation to improvise: this command'
	u << 'refuses an eighth name rather than emitting something near it.'
	return u
}

fn xap_scaffold_die(msg string) {
	eprintln('cx xap scaffold: ${msg}')
	for l in xap_scaffold_usage_lines() {
		eprintln(l)
	}
	exit(2)
}

// xap_scaffold_readme — what the pattern is, what was emitted, and what is
// still the author's. Generated from the pattern's own row so the README
// cannot drift from the bodies beside it.
fn xap_scaffold_readme(p XapScaffoldPattern, names []string) string {
	mut b := []string{}
	b << '# ${p.title} — a composition pattern skeleton'
	b << ''
	b << 'Emitted by `cx xap scaffold ${p.slug}` from composition.md ${p.section}.'
	b << ''
	b << '**The need.** ${p.need}'
	b << ''
	b << '**Modules.** ${p.modules}'
	b << ''
	b << '**Seams crossed.** ${p.seams}'
	b << ''
	b << '**Graded by.** ${p.graded}'
	b << ''
	b << '## What was emitted'
	b << ''
	for n in names {
		b << '- `${n}`'
	}
	b << ''
	b << '## What is a TODO, and why'
	b << ''
	b << 'What the pattern STATES became a declaration above; what it does not'
	b << 'state became a TODO. Nothing was guessed — that is the discipline'
	b << 'connector.md §6.3 fixes for every skeleton the toolchain emits'
	b << '(RULED: 1430-g), and a plausible wrong default is the kind an author'
	b << 'does not re-read.'
	b << ''
	for t in p.todos {
		b << '- ${t}'
	}
	b << ''
	b << '## This does not run as generated'
	b << ''
	b << '`cx xap init` scaffolds a project that composes unedited, because a'
	b << 'project has a working shape. A composition pattern does not: the'
	b << 'feature names, the verbs, the thresholds and every deployment fact'
	b << 'are yours. What the skeleton does guarantee is that it PARSES, and'
	b << 'that every declaration in it is one the pattern actually states.'
	b << ''
	b << '    cx lint ' + names.join(' ')
	b << ''
	b << 'The set of patterns is CLOSED. A composition you need that is not one'
	b << 'of the seven is a decision for the owner, not a variation to'
	b << 'improvise (composition.md §3).'
	b << ''
	return b.join('\n')
}

fn run_xap_scaffold(args []string) {
	patterns := xap_scaffold_patterns()
	if args.len == 0 || args[0] in ['-h', '--help'] {
		for l in xap_scaffold_usage_lines() {
			println(l)
		}
		exit(if args.len == 0 { 2 } else { 0 })
	}
	name := args[0]
	mut chosen := XapScaffoldPattern{}
	mut found := false
	for p in patterns {
		if p.slug == name {
			chosen = p
			found = true
		}
	}
	if !found {
		// The refusal NAMES THE CLOSED SET. A pattern that is not one of the
		// seven is the owner's decision, so the useful answer is the set, not
		// a near-miss suggestion.
		mut slugs := []string{}
		for p in patterns {
			slugs << p.slug
		}
		eprintln('cx xap scaffold: `${name}` is not a composition pattern.')
		eprintln('The set is CLOSED (composition.md §3) — the seven are:')
		for p in patterns {
			eprintln('  ${p.slug:-24} ${p.section} ${p.title}')
		}
		eprintln('A composition that is not one of them is a decision for the owner,')
		eprintln('not a variation to improvise.')
		exit(2)
	}
	mut dir := './${name}'
	mut i := 1
	for i < args.len {
		match args[i] {
			'--dir' {
				if i + 1 >= args.len {
					xap_scaffold_die('--dir needs a directory')
				}
				dir = args[i + 1]
				i += 2
			}
			else {
				xap_scaffold_die('unknown flag `${args[i]}`')
			}
		}
	}
	if os.exists(dir) && os.ls(dir) or { [] }.len > 0 {
		// Refuse rather than merge, the same rule `cx xap init` holds:
		// scaffolding into a populated directory is how a half-overwritten
		// project happens.
		eprintln('cx xap scaffold: ${dir} already exists and is not empty')
		exit(1)
	}
	os.mkdir_all(dir) or {
		eprintln('cx xap scaffold: cannot create ${dir}: ${err}')
		exit(1)
	}
	mut names := chosen.files.keys()
	names.sort()
	mut written := []string{}
	for f in names {
		p := os.join_path(dir, f)
		os.write_file(p, chosen.files[f]) or {
			eprintln('cx xap scaffold: cannot write ${p}: ${err}')
			exit(1)
		}
		written << p
	}
	readme := os.join_path(dir, 'README.md')
	os.write_file(readme, xap_scaffold_readme(chosen, names)) or {
		eprintln('cx xap scaffold: cannot write ${readme}: ${err}')
		exit(1)
	}
	written << readme
	for p in written {
		println(p)
	}
	println('')
	println('${chosen.title} — composition.md ${chosen.section}. README.md lists what the')
	println('pattern does NOT fix; each of those is an authoring TODO, never a guess.')
	println('')
	println('Next: cx lint ${os.join_path(dir, names[0])}')
}
