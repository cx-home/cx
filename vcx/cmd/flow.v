// `cx flow` — the LOCAL PROFILE of cx-stdlib/flow (flow.md §4.15; RULED:
// 1265-PD-1, ledger/rulings_2026_09_04_flow_w1_cli_1265.md).
//
// A flow document is DATA: it names its acts by qualified name and carries no
// `[?lib]` of its own (RULED: WF-1 — a `[?lib]` inside it would make its
// content address depend on the environment). So the command line must be TOLD
// where the acts live, and §4.1 already says where: the module tree of a
// program. `--env ENV.cx` names that program.
//
// ENV.cx is an ORDINARY CX program. Its `[?lib … :as alias]` imports and its
// own `[effects]`-bearing `[?def]`s ARE the module tree, and this subcommand
// splices those verbatim directive spans into the driver program it evaluates —
// so resolution, capability narrowing, `[idempotent]` dedup, `[compensates]`
// pairings and the `[requires-at]` admission all behave exactly as they would
// under `cx ENV.cx`, by construction rather than by a second implementation.
// Relative `[?lib './x.cx']` paths resolve against the WORKING DIRECTORY here
// for the same reason they do under `cx ENV.cx`: the loader's base directory is
// the process CWD, and splicing preserves that rule rather than inventing a
// file-relative one.
//
// The resolver element is built from every command def reachable in ENV.cx —
// `alias/def` for an imported member, `def` for its own — with `resolved=` the
// def's Tier-1 text address (the same address `command_meta_build` derives:
// the tagged hash of the RAW definition bytes), `compensates=` its pairing and
// `[fn $cmd]` the callable. Nothing else is special.
//
// The verbs add NO semantics: `validate` → `[$flow:validate]`, `simulate` →
// `[$flow:simulate]`, `status` → `[$flow:status]`, and `run` is `start` (which
// itself validates, then advances until the run parks or terminates). Dedup and
// resume are the module's own: a terminal run answers `[deduped …]` and an
// interrupted one resumes at the step it stopped.
//
// THE RUN ID IS DERIVED, NOT RANDOM. §4.15 requires that an interrupted
// `file://` run "resumes at the step it stopped" on the NEXT `cx flow run`, and
// the run-id preimage is (the document's Tier-1 address, the initiator, a nonce
// — RULED: 1265-PB-2). A CSPRNG nonce would make every invocation a new run and
// no resume could ever happen, so the local profile NAMES its nonce (the module
// supports exactly that: `opts.nonce`, PB-2) as the content address over the
// `[args …]` record. `cx flow run` is therefore idempotent on (document, actor,
// args): the same command resumes or dedups its own run, a different argument
// set is a different run.
//
// CAPABILITIES. The driver is evaluated under the program's own grants,
// `--allow-*` as for any `cx FILE` (deny-by-default, security.md §3). A
// `file://` journal therefore needs `--allow-read --allow-write` (or
// `--allow-all`); `--ephemeral` (`mem://`) needs none, and `validate` /
// `simulate` touch no journal at all.

module main

import os
import crypto.sha256
import cx
import code

// the journal tenant the local profile writes under: one token, stable, so
// `cx flow status` reads back what `cx flow run` wrote.
const flow_cli_tenant = 'cx-flow'

// the default journal (§4.15): a gitignored build-directory-shaped root in the
// working directory. `--ephemeral` is `mem://`.
const flow_cli_journal_default = 'file://.cx/flow/'

const flow_cli_usage = [
	'Usage: cx flow run      FLOW.cx --env ENV.cx [--journal URL | --ephemeral] [--<arg>=VALUE]...',
	'                                [--actor=ID] [--authority=ID] [--stream=NAME] [--allow-*]',
	'       cx flow validate FLOW.cx --env ENV.cx',
	'       cx flow simulate FLOW.cx RESULTS.cx [--env ENV.cx] [--<arg>=VALUE]...',
	'       cx flow status   --journal URL RUN-ID [--stream=NAME] [--allow-*]',
	'',
	'The local profile of cx-stdlib/flow (std-lib/flow.md §4.15): a journal, never',
	'a service. There is no engine to start — a run is a journaled record and the',
	'runner is a pure function this process evaluates.',
	'',
	'  FLOW.cx        the flow DOCUMENT (data — nine words, no [?lib] of its own)',
	'  RESULTS.cx     a [results [step name= status= [result …]]…] table (simulate)',
	'  RUN-ID         a run id as `run` printed it (status)',
	'',
	'  --env ENV.cx   the PROGRAM whose module tree the acts resolve through',
	'                 (§4.1). Its [?lib … :as alias] imports and its own',
	'                 [effects]-bearing [?def]s are that tree: an imported member',
	'                 is named `alias/def`, its own def is named `def`. Relative',
	'                 [?lib] paths resolve against the working directory, exactly',
	'                 as under `cx ENV.cx`.',
	'  --journal URL  the run\'s journal (default file://.cx/flow/ — gitignored)',
	'  --ephemeral    mem:// instead: process-lifetime, nothing persists',
	'  --<arg>=VALUE  one field of the run\'s [args …] record, typed by the flow\'s',
	'                 own declaration; a value that fails it refuses CXER4965',
	'  --actor=ID     the initiator (default principal:<the OS user>)',
	'  --authority=ID the authority basis (default cli)',
	'  --stream=NAME  place the run in its subject\'s aggregate stream (default:',
	'                 the run id itself)',
	'  --allow-*      capability grants, as for any `cx FILE` (deny-by-default).',
	'                 A file:// journal needs --allow-read --allow-write;',
	'                 --ephemeral, validate and simulate need no grant.',
	'',
	'The run id is DERIVED, never random: the content address over (the document,',
	'--actor, the [args …] record). So re-running the same command RESUMES an',
	'interrupted run at the step it stopped and answers [deduped …] for a terminal',
	'one, while a different argument set is a different run.',
	'',
	'Output: the record (or [valid …] / [simulation …]) in canonical CX on stdout;',
	'a refusal is the [err …] value on stderr.',
	'Exit: 0 a terminal :done run (or valid / simulated / found); 1 a run that',
	'parked or ended in a failure state, and every refusal; 2 usage.',
]

fn flow_cli_die(msg string) {
	eprintln('cx flow: ${msg}')
	for l in flow_cli_usage {
		eprintln(l)
	}
	exit(2)
}

fn flow_cli_read(path string, what string) string {
	return os.read_file(path) or {
		eprintln('cx flow: error reading ${what} "${path}": ${err}')
		exit(1)
	}
}

// ── the resolver, built from ENV.cx's module tree ────────────────────────────

// FlowCliAct is one resolver row: the act NAME a `[do …]` head may carry, the
// def's Tier-1 text address, its `[compensates]` pairing ('' = none) and the
// callable expression the driver program binds.
struct FlowCliAct {
	name        string
	resolved    string
	compensates string
	callable    string
}

// flow_cli_tier1 is the def's Tier-1 text address — the tagged hash of the RAW
// definition bytes, the same address command_meta_build derives for the
// propose/commit boundary (code.md §12.2.7). Answered from the def's verbatim
// source span, so the resolver row and the engine name the same thing.
fn flow_cli_tier1(raw string) string {
	return cx.cx_tag_address(cx.cx_default_hash_algo, sha256.sum256(raw.bytes()).hex())
}

// flow_cli_local_act answers the resolver row for one of ENV.cx's OWN defs, or
// none when the def is not a command (no `[effects]` clause — the §12.2.7
// discriminator).
fn flow_cli_local_act(span string) ?FlowCliAct {
	d := cx.parse_def(span) or { return none }
	if !d.has_effects {
		return none
	}
	return FlowCliAct{
		name:        d.name
		resolved:    flow_cli_tier1(span)
		compensates: d.compensates
		callable:    '\$${d.name}'
	}
}

// flow_cli_module_acts answers the resolver rows for one `[?lib]` import's
// public command defs, named `alias/def`. A lib that does not resolve yields no
// rows: the driver program carries the SAME `[?lib]` span and refuses there with
// the loader's own CXER, which is the message the reader needs.
fn flow_cli_module_acts(span string, mut table code.ModuleTable) []FlowCliAct {
	ln := cx.parse_lib(span) or { return [] }
	m := code.resolve_lib(ln, mut table) or { return [] }
	prefix := code.module_call_prefix(ln)
	only := ln.only_imports
	mut out := []FlowCliAct{}
	for name in m.public_def_names() {
		if o := only {
			if name !in o {
				continue
			}
		}
		d := m.lookup_def(name, '') or { continue }
		if !d.has_effects {
			continue
		}
		mut comp := ''
		if d.compensates != '' {
			// the pairing lives on the def, in the DEFINING module's namespace —
			// so the resolver row names it the way a `[do …]` head would.
			comp = '${prefix}/${d.compensates}'
		}
		out << FlowCliAct{
			name:        '${prefix}/${name}'
			resolved:    flow_cli_tier1(d.source or { span })
			compensates: comp
			callable:    '\$${prefix}:${name}'
		}
	}
	return out
}

// flow_cli_env_scan reads ENV.cx and answers (its verbatim directive spans, in
// source order, and the acts they make reachable). The spans are spliced into
// the driver program unchanged: the module tree is ENV.cx's, not a copy of it.
fn flow_cli_env_scan(path string) ([]string, []FlowCliAct) {
	src := flow_cli_read(path, 'the --env program')
	spans := code.module_loader_scan_spans(src) or {
		eprintln('cx flow: --env "${path}" is not scannable CX: ${err.msg()}')
		exit(1)
	}
	mut table := code.new_module_table()
	code.register_bundled_stdlib(mut table)
	code.register_bundled_x(mut table)
	mut directives := []string{}
	mut acts := []FlowCliAct{}
	for sp in spans {
		match sp.kind {
			.lib {
				directives << sp.text
				acts << flow_cli_module_acts(sp.text, mut table)
			}
			.const_ {
				directives << sp.text
			}
			.def {
				directives << sp.text
				if a := flow_cli_local_act(sp.text) {
					acts << a
				}
			}
			else {}
		}
	}
	return directives, acts
}

// flow_cli_resolver renders the `[resolver [act …]…]` element (flow.md §4.1 —
// the executing environment's ONE resolver; the rows are the same
// `[act name= resolved=]` shape `validate` answers with).
fn flow_cli_resolver(acts []FlowCliAct) string {
	mut b := []string{}
	b << '[resolver'
	for a in acts {
		mut row := "  [act name='${a.name}' resolved='${a.resolved}'"
		if a.compensates != '' {
			row += " compensates='${a.compensates}'"
		}
		row += ' [fn ${a.callable}]]'
		b << row
	}
	b << ']'
	return b.join('\n')
}

// ── the [args …] record, typed by the flow's declaration ─────────────────────

// flow_cli_arg_types reads the flow document's `[args [sku::string] …]`
// declaration: field name → declared type ('' when the field carries none).
fn flow_cli_arg_types(flow_src string) map[string]string {
	mut out := map[string]string{}
	doc := cx.parse(flow_src) or { return out }
	for n in doc.elements {
		if !n.is_element() {
			continue
		}
		fl := n.element()
		if fl.name != 'flow' {
			continue
		}
		for it in fl.items {
			if !it.is_element() {
				continue
			}
			ae := it.element()
			if ae.name != 'args' {
				continue
			}
			for f in ae.items {
				if !f.is_element() {
					continue
				}
				fe := f.element()
				out[fe.name] = fe.data_type() or { '' }
			}
		}
	}
	return out
}

fn flow_cli_quote(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"')
}

// flow_cli_args renders the run's `[args …]` record in CHILD form (RULED:
// #1260 CA-3), each field spelled per the flow's own declaration: a declared
// `::string` is quoted, everything else is the raw token so the declared type
// reads it (an int as an int, a decimal as a decimal). A value that does not
// check against the declaration refuses CXER4965 in `start`, as §3 says — the
// CLI never coerces a wrong value into a right-looking one.
fn flow_cli_args(pairs [][]string, types map[string]string) string {
	mut b := []string{}
	b << '[args'
	for p in pairs {
		name := p[0]
		raw := p[1]
		t := types[name] or { 'string' }
		lit := if t == 'string' { '"${flow_cli_quote(raw)}"' } else { raw }
		b << '  [${name} ${lit}]'
	}
	b << ']'
	return b.join('\n')
}

// flow_cli_nonce is the local profile's NAMED nonce (see the header): the
// content address over the run's `[args …]` record, so `cx flow run` is
// idempotent on (document, actor, args) and §4.15's resume happens.
fn flow_cli_nonce(args_src string) string {
	return sha256.sum256(args_src.bytes()).hex()
}

// ── driving the module's verbs ───────────────────────────────────────────────

// flow_cli_eval evaluates the driver program with FLOW.cx (and, for `simulate`,
// RESULTS.cx after it) as the DATA document, so no document text is ever
// embedded in program source and nothing needs escaping.
fn flow_cli_eval(input string, program string) string {
	return code.eval_code(input, program, 'cx') or {
		eprintln('cx flow: ${err}')
		exit(1)
	}
}

// flow_cli_answer classifies the rendered answer and exits: the record (or
// `[valid …]` / `[simulation …]`) goes to stdout, an `[err …]` refusal to
// stderr. Exit codes per §4.15 — 0 a terminal `:done` run, 1 a run that parked
// or ended in a failure state and every refusal.
fn flow_cli_answer(rendered string, want_done bool) {
	out := rendered.trim_space()
	doc := cx.parse(out) or {
		// an unparseable answer is not an answer: report it rather than
		// pretending a shape.
		eprintln('cx flow: the module answered text this surface cannot read: ${out}')
		exit(1)
	}
	mut head := ''
	mut status := ''
	for n in doc.elements {
		if !n.is_element() {
			continue
		}
		e := n.element()
		head = e.name
		status = e.attr('status')
		if e.name == 'deduped' {
			for it in e.items {
				if it.is_element() {
					status = (it.element()).attr('status')
					break
				}
			}
		}
		break
	}
	if head == 'err' {
		eprintln(out)
		exit(1)
	}
	println(out)
	// the status is an ATOM, so its image may or may not carry the leading `:`
	// depending on the emitter that spelled it; the terminal state is the same
	// state either way.
	if want_done && status.trim_left(':') != 'done' {
		exit(1)
	}
	exit(0)
}

// ── argv ─────────────────────────────────────────────────────────────────────

const flow_cli_known_flags = ['--env', '--journal', '--actor', '--authority', '--stream']

struct FlowCliOpts {
mut:
	env       string
	journal   string
	ephemeral bool
	actor     string
	authority string
	stream    string
	args      [][]string
	positional []string
	allow_all    bool
	allow_common bool
	allow_caps   []string
	net_specs    []string
}

fn flow_cli_parse(args []string) FlowCliOpts {
	mut o := FlowCliOpts{}
	mut i := 0
	for i < args.len {
		a := args[i]
		if !a.starts_with('--') {
			o.positional << a
			i++
			continue
		}
		if a == '--ephemeral' {
			o.ephemeral = true
			i++
			continue
		}
		if a == '--allow-all' {
			o.allow_all = true
			i++
			continue
		}
		if a == '--allow-common' {
			o.allow_common = true
			i++
			continue
		}
		if a.starts_with('--allow-') {
			rest := a['--allow-'.len..]
			cap_name := rest.all_before('=')
			if cap_name != '' {
				refuse_unenforced_grant_scope('cx flow', a, cap_name, rest)
				o.allow_caps << cap_name
				if cap_name == 'net' && rest.contains('=') {
					o.net_specs << rest.all_after('=')
				}
			}
			i++
			continue
		}
		// `--name VALUE` for the five named flags; `--name=VALUE` for those and
		// for every `[args …]` field.
		if a in flow_cli_known_flags {
			if i + 1 >= args.len {
				flow_cli_die('${a} needs an argument')
			}
			flow_cli_set(mut o, a['--'.len..], args[i + 1])
			i += 2
			continue
		}
		if !a.contains('=') {
			flow_cli_die('unknown flag `${a}` (an [args …] field is spelled `--name=value`)')
		}
		key := a['--'.len..].all_before('=')
		val := a.all_after('=')
		if '--${key}' in flow_cli_known_flags {
			flow_cli_set(mut o, key, val)
			i++
			continue
		}
		if key == '' {
			flow_cli_die('`${a}` names no field')
		}
		o.args << [key, val]
		i++
	}
	return o
}

fn flow_cli_set(mut o FlowCliOpts, key string, val string) {
	match key {
		'env' { o.env = val }
		'journal' { o.journal = val }
		'actor' { o.actor = val }
		'authority' { o.authority = val }
		'stream' { o.stream = val }
		else { flow_cli_die('unknown flag `--${key}`') }
	}
}

fn flow_cli_install_caps(o FlowCliOpts) {
	if o.allow_all {
		code.caps_set_all()
		return
	}
	if o.allow_common {
		code.caps_set_common()
		return
	}
	code.caps_set_list(o.allow_caps) or {
		eprintln('cx flow: ${err.msg()}')
		exit(2)
	}
	if o.net_specs.len > 0 {
		code.caps_set_net_hosts(o.net_specs)
	}
}

// flow_cli_actor_default — §4.15: a checkout's own flows run under the runner,
// so the initiator is the OS user and the authority basis is the CLI itself.
fn flow_cli_actor_default() string {
	u := os.getenv('USER')
	name := if u != '' { u } else { os.getenv('LOGNAME') }
	return 'principal:' + if name != '' { name } else { 'unknown' }
}

fn flow_cli_opts_map(o FlowCliOpts, nonce string, with_flow bool) string {
	mut b := '{env: \$e'
	if with_flow {
		b += ' flow: \$fl'
	}
	b += ' actor: "${flow_cli_quote(o.actor)}" authority: "${flow_cli_quote(o.authority)}"'
	if nonce != '' {
		b += ' nonce: "${nonce}"'
	}
	if o.stream != '' {
		b += ' stream: "${flow_cli_quote(o.stream)}"'
	}
	return b + '}'
}

// ── the four verbs ───────────────────────────────────────────────────────────

fn run_flow(args []string) {
	if args.len == 0 {
		flow_cli_die('needs a verb: run | validate | simulate | status')
	}
	verb := args[0]
	mut o := flow_cli_parse(args[1..])
	if o.actor == '' {
		o.actor = flow_cli_actor_default()
	}
	if o.authority == '' {
		o.authority = 'cli'
	}
	if o.ephemeral {
		if o.journal != '' {
			flow_cli_die('--ephemeral and --journal name two different journals; pick one')
		}
		o.journal = 'mem://cx-flow'
	}
	match verb {
		'run' { flow_cli_run(o) }
		'validate' { flow_cli_validate(o) }
		'simulate' { flow_cli_simulate(o) }
		'status' { flow_cli_status(o) }
		else { flow_cli_die('unknown verb `${verb}` (run | validate | simulate | status)') }
	}
}

// flow_cli_prelude is the driver's own module set, aliased so it can never
// clash with anything ENV.cx imports under a name of its own.
fn flow_cli_prelude(with_journal bool) string {
	mut b := ["[?lib 'cx-stdlib/flow' :as cxflow]"]
	if with_journal {
		b << "[?lib 'cx-stdlib/store' :as cxstore]"
		b << "[?lib 'cx-stdlib/journal' :as cxjournal]"
	}
	return b.join('\n')
}

fn flow_cli_run(o FlowCliOpts) {
	if o.positional.len != 1 {
		flow_cli_die('run takes exactly one FLOW.cx')
	}
	if o.env == '' {
		flow_cli_die('run needs --env ENV.cx (the program whose module tree the acts resolve through)')
	}
	flow_src := flow_cli_read(o.positional[0], 'the flow document')
	directives, acts := flow_cli_env_scan(o.env)
	args_src := flow_cli_args(o.args, flow_cli_arg_types(flow_src))
	url := if o.journal != '' { o.journal } else { flow_cli_journal_default }
	flow_cli_install_caps(o)
	program := [
		flow_cli_prelude(true),
		directives.join('\n'),
		'[?let [= \$fl [\$first [\$cx:select \$doc "//flow"]]]',
		'[= \$e ${flow_cli_resolver(acts)}]',
		'[= \$j [\$cxjournal:open "${flow_cli_quote(url)}" "${flow_cli_tenant}"]]',
		'[= \$a ${args_src}]',
		'  [\$cxflow:start \$j \$fl \$a ${flow_cli_opts_map(o, flow_cli_nonce(args_src), true)}]]',
	].join('\n')
	flow_cli_answer(flow_cli_eval(flow_src, program), true)
}

fn flow_cli_validate(o FlowCliOpts) {
	if o.positional.len != 1 {
		flow_cli_die('validate takes exactly one FLOW.cx')
	}
	if o.env == '' {
		flow_cli_die('validate needs --env ENV.cx (the program whose module tree the acts resolve through)')
	}
	flow_src := flow_cli_read(o.positional[0], 'the flow document')
	directives, acts := flow_cli_env_scan(o.env)
	flow_cli_install_caps(o)
	program := [
		flow_cli_prelude(false),
		directives.join('\n'),
		'[?let [= \$fl [\$first [\$cx:select \$doc "//flow"]]]',
		'[= \$e ${flow_cli_resolver(acts)}]',
		'  [\$cxflow:validate \$fl \$e]]',
	].join('\n')
	flow_cli_answer(flow_cli_eval(flow_src, program), false)
}

fn flow_cli_simulate(o FlowCliOpts) {
	if o.positional.len != 2 {
		flow_cli_die('simulate takes FLOW.cx and RESULTS.cx')
	}
	flow_src := flow_cli_read(o.positional[0], 'the flow document')
	results_src := flow_cli_read(o.positional[1], 'the result table')
	mut directives := []string{}
	mut acts := []FlowCliAct{}
	if o.env != '' {
		directives, acts = flow_cli_env_scan(o.env)
	}
	args_src := flow_cli_args(o.args, flow_cli_arg_types(flow_src))
	flow_cli_install_caps(o)
	program := [
		flow_cli_prelude(false),
		directives.join('\n'),
		'[?let [= \$fl [\$first [\$cx:select \$doc "//flow"]]]',
		'[= \$rs [\$first [\$cx:select \$doc "//results"]]]',
		'[= \$e ${flow_cli_resolver(acts)}]',
		'[= \$a ${args_src}]',
		'  [\$cxflow:simulate \$fl \$a \$rs {env: \$e}]]',
	].join('\n')
	flow_cli_answer(flow_cli_eval(flow_src + '\n' + results_src, program), false)
}

fn flow_cli_status(o FlowCliOpts) {
	if o.positional.len != 1 {
		flow_cli_die('status takes exactly one RUN-ID')
	}
	if o.journal == '' {
		flow_cli_die('status needs --journal URL (or --ephemeral, which holds no run past its process)')
	}
	id := o.positional[0]
	flow_cli_install_caps(o)
	mut sopts := '{}'
	if o.stream != '' {
		sopts = '{stream: "${flow_cli_quote(o.stream)}"}'
	}
	program := [
		flow_cli_prelude(true),
		'[?let [= \$j [\$cxjournal:open "${flow_cli_quote(o.journal)}" "${flow_cli_tenant}"]]',
		'  [\$cxflow:status \$j "${flow_cli_quote(id)}" ${sopts}]]',
	].join('\n')
	flow_cli_answer(flow_cli_eval('', program), false)
}
