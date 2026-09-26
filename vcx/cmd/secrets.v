// `cx secrets` — the client's verb set of cx-platform/secrets (secrets.md §4;
// RULED: SEC-1 and its 2026-09-26 note, Letter 32 (6)).
//
// Three verbs, and A VALUE IS NEVER PRINTED by any of them, on any channel —
// the rule connector.md states as CXER6311 for a resolved value:
//
//   put     stores a value under a handle in its sealed provider
//   rotate  sets a handle's `next` value and opens its rotation window
//           inside the provider (secrets.md §2.2; sso.md §3.4)
//   list    lists the handles a sealed provider holds — handles only
//
// THE VERBS ADD NO SEMANTICS, the `cx flow` posture: each is the module's own
// public verb (`[$secrets:put]`, `[$secrets:rotate]`, `[$secrets:list]`)
// evaluated over the deployment document the command line names, under the
// invocation's own `--allow-*` grants (deny-by-default, security.md §3). The
// provider rows are validated exactly as the keystore's `open` validates them.
//
// A VALUE NEVER ARRIVES ON ARGV (Letter 32 (6)). argv is visible to every
// process on the host (`ps`) and to the shell's history, so `put` and `rotate`
// read the value from stdin — one trailing newline dropped, so `printf` and
// `echo` both work — or from the variable `--from-env VAR` names. A second
// positional argument after the handle is REFUSED as usage (exit 2) rather
// than taken as the value, so the habit of typing a secret on the command line
// fails before anything is read. The value reaches the evaluator as the DATA
// document of the driver program, never as program text.

module main

import os
import cx
import code { grant_scope_install, grant_scope_root, opt_root, refuse_unenforced_grant_scope }

const secrets_cli_usage = [
	'Usage: cx secrets put    HANDLE --deployment FILE [--from-env VAR] [--allow-*]',
	'       cx secrets rotate HANDLE --deployment FILE [--overlap DURATION] [--from-env VAR] [--allow-*]',
	'       cx secrets list   PROVIDER --deployment FILE [--allow-*]',
	'',
	'The client verbs of cx-platform/secrets (platform/secrets.md §4). A value is',
	'never printed, and never read from the command line.',
	'',
	'  HANDLE           handle:<provider>/<path>; the provider is a [secrets',
	'                   [provider name= kind=sealed …]] row of the deployment',
	'  PROVIDER         a sealed provider row\'s name=',
	'  --deployment F   the [deployment] document whose [runtime [secrets …]]',
	'                   rows name the providers (path=, key-from=)',
	'  --from-env VAR   put / rotate: take the value from the variable VAR',
	'                   instead of stdin (needs --allow-env)',
	'  --overlap D      rotate: the window before the successor becomes the',
	'                   active value (30s, 1h, 24h; default 0s)',
	'',
	'put and rotate read the value from STDIN unless --from-env names a',
	'variable; one trailing newline is dropped. A value given as an argument is',
	'refused (exit 2) — argv is visible to every process on the host.',
	'',
	'The verbs act on a sealed provider only (an env provider\'s value is the',
	'environment\'s). They need the grants their effects charge: --allow-read',
	'and --allow-write for the store, --allow-env (key-from=env:, --from-env)',
	'or --allow-read (key-from=file:) for the master key, --allow-random for',
	'the nonce AES-256-GCM draws, --allow-clock for rotate\'s deadline.',
	'',
	'Output: put answers [put handle= provider= slot=], rotate the window it',
	'opened ([rotation handle= overlap= not-after=]), list one handle per line.',
	'A refusal is the [err …] value on stderr.',
	'Exit: 0 done; 1 a refusal; 2 usage.',
]

struct SecretsCliOpts {
mut:
	deployment   string
	from_env     string
	overlap      string
	positional   []string
	allow_all    bool
	allow_common bool
	allow_caps   []string
	net_specs    []string
	read_roots   []string
	write_roots  []string
}

fn secrets_cli_die(msg string) {
	eprintln('cx secrets: ${msg}')
	for l in secrets_cli_usage {
		eprintln(l)
	}
	exit(2)
}

fn secrets_cli_parse(args []string) SecretsCliOpts {
	mut o := SecretsCliOpts{}
	mut i := 0
	for i < args.len {
		a := args[i]
		if !a.starts_with('--') {
			o.positional << a
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
				refuse_unenforced_grant_scope('cx secrets', a, cap_name, rest)
				if r := opt_root(grant_scope_root(cap_name, rest, 'read')) {
					o.read_roots << r
				}
				if w := opt_root(grant_scope_root(cap_name, rest, 'write')) {
					o.write_roots << w
				}
				o.allow_caps << cap_name
				if cap_name == 'net' && rest.contains('=') {
					o.net_specs << rest.all_after('=')
				}
			}
			i++
			continue
		}
		key := a['--'.len..].all_before('=')
		mut val := ''
		if a.contains('=') {
			val = a.all_after('=')
			i++
		} else {
			if i + 1 >= args.len {
				secrets_cli_die('${a} needs an argument')
			}
			val = args[i + 1]
			i += 2
		}
		match key {
			'deployment' { o.deployment = val }
			'from-env' { o.from_env = val }
			'overlap' { o.overlap = val }
			else { secrets_cli_die('unknown flag `--${key}`') }
		}
	}
	return o
}

fn secrets_cli_install_caps(o SecretsCliOpts) {
	if o.allow_all {
		code.caps_set_all()
		return
	}
	if o.allow_common {
		code.caps_set_common()
		return
	}
	code.caps_set_list(o.allow_caps) or {
		eprintln('cx secrets: ${err.msg()}')
		exit(2)
	}
	if o.net_specs.len > 0 {
		code.caps_set_net_hosts(o.net_specs)
	}
	grant_scope_install(o.read_roots, o.write_roots)
}

// secrets_cli_stdin_value — the value `put` / `rotate` store when no
// `--from-env` names a variable: stdin, with ONE trailing newline dropped (a
// process's own stdin is its own input and gated by nothing, as its argv is
// not). An empty value is refused: storing nothing under a handle is a
// mistake, not a value. `--from-env` is read by the driver program itself,
// under the invocation's `env` grant.
fn secrets_cli_stdin_value() string {
	mut v := os.get_raw_stdin().bytestr()
	if v.ends_with("\r\n") {
		v = v[..v.len - 2]
	} else if v.ends_with("\n") {
		v = v[..v.len - 1]
	}
	if v == '' {
		secrets_cli_die('the value on stdin is empty — pipe it on stdin or name --from-env VAR')
	}
	for c in v {
		if c < 0x20 && c != `\n` && c != `\r` && c != `\t` {
			secrets_cli_die('the value on stdin carries a control character — a credential is text')
		}
	}
	return v
}

// secrets_cli_string renders a string as a CX double-quoted literal the data
// reader reads back byte for byte.
fn secrets_cli_string(s string) string {
	return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace("\n", '\\n').replace("\r", '\\r').replace("\t", '\\t') + '"'
}

fn run_secrets(args []string) {
	if args.len == 0 {
		secrets_cli_die('needs a verb: put | rotate | list')
	}
	verb := args[0]
	if verb in ['-h', '--help', 'help'] {
		for l in secrets_cli_usage {
			println(l)
		}
		exit(0)
	}
	o := secrets_cli_parse(args[1..])
	if verb !in ['put', 'rotate', 'list'] {
		secrets_cli_die('unknown verb `${verb}` (put | rotate | list)')
	}
	if o.deployment == '' {
		secrets_cli_die('${verb} needs --deployment FILE — the document whose [secrets [provider]] rows name the store')
	}
	if o.positional.len == 0 {
		what := if verb == 'list' { 'PROVIDER' } else { 'HANDLE' }
		secrets_cli_die('${verb} needs ${what}')
	}
	if o.positional.len > 1 {
		if verb == 'list' {
			secrets_cli_die('list takes one PROVIDER')
		}
		secrets_cli_die('${verb} takes one HANDLE and never a value as an argument — argv is visible to every process on the host; pipe the value on stdin or name --from-env VAR')
	}
	if o.overlap != '' && verb != 'rotate' {
		secrets_cli_die('--overlap is rotate\'s window; `${verb}` opens none')
	}
	if o.from_env != '' && verb == 'list' {
		secrets_cli_die('--from-env names the value put and rotate store; list stores none')
	}
	secrets_cli_install_caps(o)
	doc_src := os.read_file(o.deployment) or {
		eprintln('cx secrets: error reading --deployment "${o.deployment}": ${err}')
		exit(1)
	}
	target := o.positional[0]
	// The deployment document and, for put / rotate from stdin, the value ride
	// as the driver's DATA document — never as program text, so nothing in
	// either is evaluated. A `--from-env` value is read by the program itself.
	mut value_expr := ''
	mut input := '[secrets-cli-input ${doc_src}]'
	if verb != 'list' {
		if o.from_env != '' {
			value_expr = '[\$cxenv:var-required ${secrets_cli_string(o.from_env)}]'
		} else {
			input = '[secrets-cli-input ${doc_src} [secrets-cli-value ${secrets_cli_string(secrets_cli_stdin_value())}]]'
			value_expr = '[\$string [\$first \$doc//secrets-cli-value]]'
		}
	}
	dep := '[\$first [?for [in \$x \$doc//deployment] [yield \$x]]]'
	call := match verb {
		'put' {
			'[\$cxsecrets:put ${dep} ${secrets_cli_string(target)} ${value_expr}]'
		}
		'rotate' {
			ov := if o.overlap != '' { o.overlap } else { '0s' }
			'[\$cxsecrets:rotate ${dep} ${secrets_cli_string(target)} ${value_expr} {overlap: ${secrets_cli_string(ov)}}]'
		}
		else {
			'[\$cxsecrets:list ${dep} ${secrets_cli_string(target)}]'
		}
	}
	program := "[?lib 'cx-platform/secrets' as=cxsecrets]\n[?lib 'cx-stdlib/env' as=cxenv]\n${call}\n"
	out := code.eval_code(input, program, 'cx') or {
		eprintln('cx secrets: ${err}')
		exit(1)
	}
	answer := out.trim_space()
	if code.last_result_was_failure() || answer.starts_with('[err ') {
		eprintln(answer)
		exit(1)
	}
	if verb == 'list' {
		parsed := cx.parse(answer) or {
			println(answer)
			exit(0)
		}
		for n in parsed.elements {
			if n.is_sequence_node() {
				for it in n.sequence_node().items {
					println(secrets_cli_scalar(it))
				}
			} else {
				println(secrets_cli_scalar(n))
			}
		}
		exit(0)
	}
	println(answer)
	exit(0)
}

// secrets_cli_scalar is one listed handle as its bare text — `list` prints
// handles only, one per line, never a rendering of them.
fn secrets_cli_scalar(n cx.Node) string {
	if n.is_string() {
		return n.string_value()
	}
	if n.is_text_node() {
		return n.text_node().value
	}
	return n.str()
}
