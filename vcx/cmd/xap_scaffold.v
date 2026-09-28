module main

import os
import cx
import code

// `cx xap scaffold NAME [--dir D] [--answers FILE --as PRINCIPAL]` — emit one
// COMPOSITION PATTERN's declaration skeleton (#1487, RULED: COMP-1) or one
// AUTOMATION SKELETON (#1498, RULED: AA-1, AA-2, AA-3, AA-8), and, for a
// skeleton with `--answers`, the flow document and its `[on …]` row that
// `fill` makes of it.
//
// composition.md §3 states a closed set of seven patterns, each with the
// enterprise need it answers, the modules it uses, a declaration skeleton
// drawn from the specifications' own examples, and the §2 seam rows it
// crosses; §3.10 states a closed sub-set of four automation skeletons, each a
// flow document plus one `[on …]` row whose every TODO is a typed, named
// `[slot name= kind=]`. The bodies of both are DATA shipped in
// cx-platform-flow (xap_scaffold_templates.v embeds them): this command
// carries no copy of a body of its own (RULED: AA-1).
//
// WHAT THE PATTERN STATES BECOMES A DECLARATION; WHAT IT DOES NOT BECOMES AN
// AUTHORING TODO, NEVER A GUESS. That is the discipline connector.md §6.3
// fixes for every skeleton the toolchain emits (RULED: 1430-g). A scaffold
// that guessed would be worse than a blank page, because a plausible wrong
// default is the kind an author does not re-read.
//
// It is PURE: a name — and, for a skeleton, the answers file its command line
// names — in; a skeleton or a filled document out. No network, no clock, no
// registry, nothing else read from the tree, and it never writes into a
// deployment document (RULED: AA-3). Every emitted document parses.
//
// `--answers FILE` calls `fill` (cx-platform/flow, RULED: AA-7) — the same
// pure def the studio's automations plane calls on the host, so the two
// cannot produce different documents from the same answers — and REQUIRES
// `--as PRINCIPAL`: the emitted row's `as=` is that principal, as `cx flow
// run` names its actor (RULED: AA-8). `fill`'s one refusal, naming every
// unanswered or wrongly-kinded slot, is printed as it answers and nothing is
// written.
//
// UNLIKE `cx xap init`, A PATTERN DOES NOT RUN AS GENERATED, and says so in
// its README: a composition pattern is a shape, and the feature names, the
// verbs, the thresholds, the routes and every deployment fact are the
// author's. `cx xap init` scaffolds a project that composes unedited because
// a project HAS a working shape; a pattern does not.

fn xap_scaffold_usage_lines() []string {
	mut u := [
		'Usage: cx xap scaffold NAME [--dir DIR] [--answers FILE --as PRINCIPAL]',
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
	u << 'Or one automation skeleton — a flow document and its [on …] row, every'
	u << 'TODO a typed, named [slot name= kind=] — from the closed sub-set of four'
	u << '(composition.md §3.10):'
	u << ''
	for s in xap_scaffold_skeletons() {
		u << '  ${s.name:-24} §3.10 ${s.trigger}: ${s.shape}'
	}
	u << ''
	u << '  --dir DIR            where to create it (default: ./NAME)'
	u << '  --answers FILE       a skeleton only: fill it from FILE\'s [answers …]'
	u << '                       document and emit the flow document and its'
	u << '                       [on …] row with no slot open'
	u << '  --as PRINCIPAL       required with --answers: the binder, the emitted'
	u << '                       row\'s as= (as `cx flow run` names its actor)'
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

// xap_scaffold_skeleton_readme — what the skeleton is, its slots, and how to
// fill it. Generated from the skeleton document itself, so it cannot drift
// from the data beside it.
fn xap_scaffold_skeleton_readme(s XapScaffoldSkeleton, names []string) string {
	mut b := []string{}
	b << '# ${s.name} — an automation skeleton'
	b << ''
	b << 'Emitted by `cx xap scaffold ${s.name}` from composition.md §3.10.'
	b << ''
	b << '**The shape.** ${s.shape}. **The trigger.** an `[on kind=${s.trigger} …]` row (flow.md §4.24).'
	b << ''
	b << '## What was emitted'
	b << ''
	for n in names {
		b << '- `${n}`'
	}
	b << ''
	b << 'The skeleton is a flow document plus one `[on …]` row in which every'
	b << 'TODO is a typed, named `[slot name= kind=]`; the answers file is its'
	b << 'reference `[answers …]` document, one child per slot. Edit the answers.'
	b << ''
	b << '## The slots'
	b << ''
	for sl in s.slots {
		b << '- ${sl}'
	}
	b << ''
	b << 'An `act` is `\'ns/verb\'`, a `field` a lower-case name, a `role`'
	b << '`role:<name>`, a `principal` `principal:<id>`, a `duration` a literal'
	b << 'such as `1d`, a `value` a scalar.'
	b << ''
	b << '## Fill it'
	b << ''
	b << '    cx xap scaffold ${s.name} --answers ${s.name}.answers.cxd --as principal:<id> --dir <new dir>'
	b << ''
	b << 'emits the flow document and its `[on …]` row with no slot open — the row'
	b << 'carrying `start=`, the flow\'s address, and `as=`, the principal `--as`'
	b << 'names — or one refusal naming every unanswered or wrongly-kinded slot.'
	b << 'It never writes into a deployment document: add the row to yours.'
	b << ''
	b << 'The set of skeletons is CLOSED — on-change-act, on-change-approve,'
	b << 'on-change-check, on-schedule-act (composition.md §3.10).'
	b << ''
	return b.join('\n')
}

fn xap_scaffold_filled_readme(s XapScaffoldSkeleton, names []string, principal string) string {
	mut b := []string{}
	b << '# ${s.name} — a filled automation'
	b << ''
	b << 'Emitted by `cx xap scaffold ${s.name} --answers FILE --as ${principal}`'
	b << 'from composition.md §3.10: `fill` (cx-platform/flow) over the skeleton'
	b << 'and the answers, with no slot left open.'
	b << ''
	b << '## What was emitted'
	b << ''
	for n in names {
		b << '- `${n}`'
	}
	b << ''
	b << 'The `[on …]` row\'s `start=` is the flow document\'s Tier-1 address and'
	b << 'its `as=` is `${principal}`, whose own act each start is (flow.md §4.9).'
	b << 'Nothing was written into a deployment document: add the row to your'
	b << 'deployment\'s bindings and serve the flow document from its `[docs]`.'
	b << ''
	return b.join('\n')
}

// xap_scaffold_fill evaluates `fill` over the embedded skeleton and the
// answers file, the documents as the DATA input so no document text is ever
// embedded in program source. It answers the two documents' texts, or the
// refusal as it was rendered.
fn xap_scaffold_fill(s XapScaffoldSkeleton, answers_src string, principal string) !(string, string) {
	input := [s.source, '[scaffold-answers', answers_src, ']', "[scaffold-as '${principal}']"].join('\n')
	program := [
		"[?lib 'cx-platform/flow' :as cxflow]",
		'[?let [= \$r [\$cxflow:fill [\$first [\$cx:select \$doc "/skeleton"]] [\$first [\$cx:select \$doc "/scaffold-answers/*"]] {as: [\$string [\$first [\$cx:select \$doc "/scaffold-as"]]]}]]',
		'  [?match \$r [case [err] \$r] [else [scaffold-filled [flow [\$cx:serialize [\$first \$r]]] [on [\$cx:serialize [\$first [\$tail \$r]]]]]]]]',
	].join('\n')
	out := code.eval_code(input, program, 'cx') or { return error(err.msg()) }
	doc := cx.parse(out.trim_space()) or { return error(out.trim_space()) }
	for n in doc.elements {
		if !n.is_element() {
			continue
		}
		e := n.element()
		if e.name == 'scaffold-filled' {
			mut flow_txt, mut on_txt := '', ''
			for it in e.items {
				if it.is_element() && it.element().name == 'flow' {
					flow_txt = xap_scaffold_payload(it.element())
				} else if it.is_element() && it.element().name == 'on' {
					on_txt = xap_scaffold_payload(it.element())
				}
			}
			return flow_txt, on_txt
		}
		break
	}
	return error(out.trim_space())
}

fn xap_scaffold_write(dir string, files map[string]string, readme string) []string {
	os.mkdir_all(dir) or {
		eprintln('cx xap scaffold: cannot create ${dir}: ${err}')
		exit(1)
	}
	mut names := files.keys()
	names.sort()
	mut written := []string{}
	for f in names {
		p := os.join_path(dir, f)
		os.write_file(p, files[f]) or {
			eprintln('cx xap scaffold: cannot write ${p}: ${err}')
			exit(1)
		}
		written << p
	}
	rp := os.join_path(dir, 'README.md')
	os.write_file(rp, readme) or {
		eprintln('cx xap scaffold: cannot write ${rp}: ${err}')
		exit(1)
	}
	written << rp
	return written
}

fn run_xap_scaffold(args []string) {
	patterns := xap_scaffold_patterns()
	skeletons := xap_scaffold_skeletons()
	if args.len == 0 || args[0] in ['-h', '--help'] {
		for l in xap_scaffold_usage_lines() {
			println(l)
		}
		exit(if args.len == 0 { 2 } else { 0 })
	}
	name := args[0]
	mut chosen := XapScaffoldPattern{}
	mut skeleton := XapScaffoldSkeleton{}
	mut found := false
	mut is_skeleton := false
	for p in patterns {
		if p.slug == name {
			chosen = p
			found = true
		}
	}
	for s in skeletons {
		if s.name == name {
			skeleton = s
			found = true
			is_skeleton = true
		}
	}
	if !found {
		// The refusal NAMES THE CLOSED SETS. A composition that is not one of
		// them is the owner's decision, so the useful answer is the sets, not
		// a near-miss suggestion (composition.md §3.9; comp-002).
		eprintln('cx xap scaffold: `${name}` is not a composition pattern or an automation skeleton.')
		eprintln('The set is CLOSED (composition.md §3) — the seven are:')
		for p in patterns {
			eprintln('  ${p.slug:-24} ${p.section} ${p.title}')
		}
		eprintln('and the four automation skeletons (composition.md §3.10):')
		for s in skeletons {
			eprintln('  ${s.name:-24} §3.10 ${s.trigger}: ${s.shape}')
		}
		eprintln('A composition that is not one of them is a decision for the owner,')
		eprintln('not a variation to improvise.')
		exit(2)
	}
	mut dir := './${name}'
	mut answers := ''
	mut principal := ''
	mut i := 1
	for i < args.len {
		match args[i] {
			'--dir', '--answers', '--as' {
				if i + 1 >= args.len {
					xap_scaffold_die('${args[i]} needs a value')
				}
				match args[i] {
					'--dir' { dir = args[i + 1] }
					'--answers' { answers = args[i + 1] }
					else { principal = args[i + 1] }
				}
				i += 2
			}
			else {
				xap_scaffold_die('unknown flag `${args[i]}`')
			}
		}
	}
	if !is_skeleton && (answers != '' || principal != '') {
		xap_scaffold_die('--answers and --as fill an automation skeleton (composition.md §3.10); `${name}` is a composition pattern')
	}
	if principal != '' && answers == '' {
		xap_scaffold_die('--as names the binder of a FILLED skeleton; it needs --answers FILE')
	}
	if answers != '' && principal == '' {
		// RULED: AA-8 — the CLI names the binder; a filled row with no binder
		// is refused rather than completed at publish (comp-003).
		xap_scaffold_die('--answers requires --as PRINCIPAL: the emitted [on …] row\'s as= is that principal, whose own act each start is, as `cx flow run` names its actor (composition.md §3.9, RULED: AA-8)')
	}
	if principal.contains("'") || principal.contains('\\') || principal.contains('\n') {
		xap_scaffold_die('--as `${principal}` is not a principal — write principal:<id>')
	}
	if os.exists(dir) && os.ls(dir) or { [] }.len > 0 {
		// Refuse rather than merge, the same rule `cx xap init` holds:
		// scaffolding into a populated directory is how a half-overwritten
		// project happens.
		eprintln('cx xap scaffold: ${dir} already exists and is not empty')
		exit(1)
	}
	if is_skeleton && answers != '' {
		src := os.read_file(answers) or {
			eprintln('cx xap scaffold: cannot read the answers file ${answers}: ${err}')
			exit(1)
		}
		flow_txt, on_txt := xap_scaffold_fill(skeleton, src, principal) or {
			// fill's one refusal, as it answered; nothing is written.
			eprintln(err.msg())
			exit(1)
		}
		files := {
			'${name}.flow.cx': flow_txt
			'${name}.on.cxd':  on_txt
		}
		mut names := files.keys()
		names.sort()
		written := xap_scaffold_write(dir, files, xap_scaffold_filled_readme(skeleton, names,
			principal))
		for p in written {
			println(p)
		}
		println('')
		println('${name} filled — composition.md §3.10. The [on …] row names the flow by its')
		println('address; add it to your deployment document yourself.')
		println('')
		println('Next: cx lint ${os.join_path(dir, names[0])}')
		return
	}
	if is_skeleton {
		files := {
			'${name}.skeleton.cxd': skeleton.source
			'${name}.answers.cxd':  skeleton.answers
		}
		mut names := files.keys()
		names.sort()
		written := xap_scaffold_write(dir, files, xap_scaffold_skeleton_readme(skeleton,
			names))
		for p in written {
			println(p)
		}
		println('')
		println('${name} — composition.md §3.10. README.md lists its slots; fill them with')
		println('--answers FILE --as PRINCIPAL. Every slot is a TODO, never a guess.')
		println('')
		println('Next: cx lint ${os.join_path(dir, names[0])}')
		return
	}
	mut names := chosen.files.keys()
	names.sort()
	written := xap_scaffold_write(dir, chosen.files, xap_scaffold_readme(chosen, names))
	for p in written {
		println(p)
	}
	println('')
	println('${chosen.title} — composition.md ${chosen.section}. README.md lists what the')
	println('pattern does NOT fix; each of those is an authoring TODO, never a guess.')
	println('')
	println('Next: cx lint ${os.join_path(dir, names[0])}')
}
