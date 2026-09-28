// `cx deps sync` — the pin transport of the multi-repo shape as a verb of the
// binary (RULED: DEPSV-1, RS-7, K7c).
//
// RS-7 rules "a CX lock document plus a CX-written `cx deps sync`". The
// program is scripts/deps_sync.cx, with the format module it imports,
// scripts/deps_pins.cx, and it STAYS the one implementation: this verb adds no
// semantics, it carries the two files and runs them. Both are `$embed_file`-d
// at build, the idiom `cx primer` uses for docs/llm/primer.md — this file is
// linked into the pinned checkout's vcx/cmd/ by `sync-cmd-split`, so the path
// below is read from there, four levels under this repository's root — and the
// program is evaluated by the binary's own evaluator under the grants
// `make deps-sync` gave the file (`--allow-all`: it reads and writes deps/,
// reads the environment and runs git). Its lines, its refusals and its exit
// status are the program's: spec/03-approved/process/repository-dependency-
// pins.md §3 is the behaviour, conformance/deps_pins.cxd and test-deps-pins
// grade it over the file, and vcx/tests/cli_umbrella_test.v's test_deps_verb_*
// grade this verb over the binary.
//
// THE IMPORT. The program imports its format module by path,
// `[?lib './scripts/deps_pins.cx' as=pins]`, which the resolver reads from the
// working directory (#1604) — a directory that, for a component repository or
// any checkout but this one, has no such file. So the embedded module is
// registered in the evaluation's module table under that literal resolver
// string, the mechanism the conformance corpus uses for its sibling-module
// cases (a registered source precedes the disk and charges no read): the
// program this verb runs is the embedded pair, never half of it from the disk.
//
// THE BOOTSTRAP. `make deps-sync` calls this verb, and the verb's own binary
// is built from deps/, which the sync makes: a cx that predates the verb (a
// released one, a sibling worktree's) runs the checkout's scripts/deps_sync.cx
// instead — the Makefile probes `cx deps --help` and says which it ran — and a
// box with no cx at all seeds deps/ with scripts/deps_bootstrap.sh (#1673).

module main

import cx
import code

const deps_sync_src = $embed_file('../../../../scripts/deps_sync.cx').to_string()

const deps_pins_src = $embed_file('../../../../scripts/deps_pins.cx').to_string()

// deps_pins_resolver is the literal resolver string deps_sync.cx imports its
// format module by; the embedded module is registered under it.
const deps_pins_resolver = './scripts/deps_pins.cx'

const deps_cli_usage = [
	'Usage: cx deps sync [--check] [--verbose] [--vpath] [--deps FILE] [--dir DIR]',
	'',
	'The repository dependency pins (spec/03-approved/process/repository-dependency-',
	'pins.md). Reads deps.cxd and leaves deps/<repo>/ a checkout of exactly each',
	'row\'s sha: an absent checkout is fetched shallowly, a clean one elsewhere is',
	'moved to the pin, one with local changes is refused (checkout-drift), and a',
	'sha the remote does not have is refused (fetch-failed). It never warns.',
	'',
	'  --check      fetch and move nothing: a checkout that is not there',
	'               (missing-checkout) or not at its sha (checkout-drift) is refused',
	'  --verbose    one line per row before the census: in-sync, fetched, moved or',
	'               refusal, and the repository',
	'  --vpath      print the V -path value of the pin set and nothing else (§3.3)',
	'  --deps FILE  the pin document (default deps.cxd)',
	'  --dir DIR    the directory the checkouts live in (default deps)',
	'',
	'The program is scripts/deps_sync.cx with scripts/deps_pins.cx, embedded in',
	'this binary at build and run by its own evaluator with every grant: it reads',
	'and writes the checkouts, reads the environment and runs git. Run it from the',
	'checkout root; `make deps-sync` and `make deps-check` call this verb.',
	'',
	'Exit: 0 every row in sync; 1 a refusal; 2 usage, deps.cxd unreadable, or no',
	'origin to derive a row\'s fetch URL from.',
]

fn deps_cli_die(msg string) {
	eprintln('cx deps: ${msg}')
	for l in deps_cli_usage {
		eprintln(l)
	}
	exit(2)
}

// deps_cli_sync_args checks `sync`'s flags and answers them as the program's
// argv spells them (`--deps FILE`, `--dir DIR`). Nothing is ignored: an
// unknown flag or a positional argument is usage, exit 2 — the program itself
// reads only the flags it knows, so a mistyped one would otherwise be a sync
// that silently did something else.
fn deps_cli_sync_args(args []string) []string {
	mut out := []string{}
	mut i := 0
	for i < args.len {
		a := args[i]
		if a in ['--check', '--verbose', '--vpath'] {
			out << a
			i++
			continue
		}
		key := a.all_before('=')
		if key in ['--deps', '--dir'] {
			mut val := ''
			if a.contains('=') {
				val = a.all_after('=')
				i++
			} else {
				if i + 1 >= args.len {
					deps_cli_die('${a} needs a value')
				}
				val = args[i + 1]
				i += 2
			}
			if val == '' {
				deps_cli_die('${key} needs a value')
			}
			out << key
			out << val
			continue
		}
		if a.starts_with('-') {
			deps_cli_die('unknown flag `${a}`')
		}
		deps_cli_die('sync takes no argument `${a}` — it reads deps.cxd (or --deps FILE)')
	}
	return out
}

fn run_deps(args []string) {
	if args.len == 0 {
		deps_cli_die('needs a verb: sync')
	}
	verb := args[0]
	if verb == 'help' {
		for l in deps_cli_usage {
			println(l)
		}
		exit(0)
	}
	if verb != 'sync' {
		deps_cli_die('unknown verb `${verb}` (sync)')
	}
	deps_run_embedded(deps_cli_sync_args(args[1..]))
}

// deps_run_embedded evaluates the embedded program with `argv` after its own
// name, and exits with the program's status: the program ends every path in
// `[$env:exit N]`, so a return is either an evaluation error (exit 1, the
// run surface's status for one) or a program that no longer exits, which is
// reported rather than read as success.
fn deps_run_embedded(argv []string) {
	if !deps_sync_src.contains("[?lib '${deps_pins_resolver}'") {
		eprintln("cx deps: the embedded scripts/deps_sync.cx does not import [?lib '${deps_pins_resolver}'], the name this verb registers the embedded scripts/deps_pins.cx under — the program and the verb disagree (RULED: DEPSV-1)")
		exit(2)
	}
	prog := cx.parse_program(deps_sync_src) or {
		eprintln('cx deps: the embedded scripts/deps_sync.cx does not parse: ${err}')
		exit(2)
	}
	code.caps_set_all()
	mut pargv := ['scripts/deps_sync.cx']
	pargv << argv
	code.set_program_argv(pargv)
	mut env := code.new_env()
	env.state.module_table.register_source(deps_pins_resolver, deps_pins_src)
	result := code.eval(prog.body, mut env) or {
		flush_stdout()
		eprintln('cx deps sync: ${err}')
		exit(1)
	}
	flush_stdout()
	if result.is_element() && result.element().name == 'err' {
		eprintln('cx deps sync: the program answered an error value: ${result}')
		exit(1)
	}
	eprintln('cx deps sync: the embedded program returned without an exit status — it ends every path in [\$env:exit N], so this is a defect in the verb or the program (RULED: DEPSV-1)')
	exit(1)
}
