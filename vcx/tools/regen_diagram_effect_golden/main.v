module main

import os
import code
import platform as _

// regen_diagram_effect_golden — captures the EFFECT/CAPABILITY graph
// (`effect_graph_with_level`) for the authored corpus at all three
// rungs into the committed golden set
// `vcx/tests/testdata/diagram_effect_golden/<id>.<level>.golden`, with
// each source beside it as `<id>.source`.
//
// RULED: DGX-1d (ledger/rulings_2026_08_21_diagram_capabilities.md).
// Waves 1-3 of the diagram port captured their goldens from a shipped V
// implementation before cutting over; that instrument does not exist for
// a kind that never shipped. This corpus is therefore AUTHORED — every
// byte read and reviewed at landing rather than taken from an oracle —
// and then frozen under exactly the DR-8 rule governing the other three
// corpora: regenerating it after landing is GOLDEN MOVEMENT, forbidden
// except under a mini-ruling recorded in the ledger BEFORE the bytes
// move.
//
// The corpus is chosen so the completeness gate's coverage clauses can
// bite: clause (v) requires every one of `security.md` §2's nine
// capabilities to be reached by some source here, and clause (iv)
// requires every DGX-1c opacity class to be produced by one. The rest
// exercise the graph's own claims — the reachability closure (a def
// called only from a branch arm; a def nothing calls), the
// `[?with-caps]` narrowing, alias resolution, and the case that has to
// work for the diagram to be worth anything: a program that reaches
// NOTHING says so.
//
// The byte-equality gate is vcx/tests/diagram_effect_golden_test.v.

const levels = ['min', 'compact', 'full']

const effect_sources = {
	// ── one source per capability (gate clause v) ──────────────────
	'eff-cap-read':          '[\$io:read-file "/etc/hosts"]'
	'eff-cap-write':         '[\$io:write-file "/tmp/out" "x"]'
	'eff-cap-net':           '[\$http:get "https://example.com/v1"]'
	'eff-cap-env':           '[\$env:var "HOME"]'
	'eff-cap-clock':         '[\$time:now]'
	'eff-cap-random':        '[\$random:crypto-bytes 16]'
	'eff-cap-subprocess':    '[\$process:run ("ls", "-l")]'
	'eff-cap-eval':          '[?eval \$tree]'
	'eff-cap-secret-reveal': '[?reveal \$token]'
	// ── one source per opacity class (gate clause iv) ──────────────
	'eff-opaque-eval':    '[?eval \$tree]'
	'eff-opaque-call':    '[\$mymod:go 1]'
	'eff-opaque-dynamic': '[+ x=1 [\$io:read-file "/y"] 2]'
	'eff-opaque-lib':     "[?lib './helper.cx' as=h]\n[\$h:go 1]"
	'eff-opaque-ring2':   '[\$journal:read \$j]'
	// ── the graph's own claims ─────────────────────────────────────
	// A program that reaches nothing must SAY SO — the case the whole
	// diagram exists to be able to make.
	'eff-pure':          '[?def double (\$x) [* \$x 2]]\n[\$double 21]'
	// The reachability closure: `fetch` is written outside any branch,
	// but the only call to it sits in a [?then] arm, so the capability
	// is conditional along every path.
	'eff-conditional':   "[?def fetch (\$u) [\$http:get \$u]]\n[?if [\$env:var \"GO\"] [then [\$fetch \"https://x\"]] [else [none]]]"
	// A def nothing calls: its effect site is drawn, its capability is
	// not claimed as reached.
	'eff-dead-def':      '[?def unused () [\$process:run ("rm", "-rf", "/")]]\n[ok]'
	// Two hops, both unconditional.
	'eff-chain':         "[?def inner (\$p) [\$io:read-file \$p]]\n[?def outer () [\$inner \"/etc/hosts\"]]\n[\$outer]"
	// The alias case DGX-1e exists for: without the lib-image the read
	// resolves to nothing and is silently missed.
	'eff-alias':         "[?lib 'cx-stdlib/io' as=fs]\n[\$fs:read-file \"/etc/hosts\"]"
	// A [?with-caps] narrowing that denies the very capability the body
	// reaches: the effect refuses rather than performs.
	'eff-denied':        '[?with-caps [deny net] [\$http:get "https://x"]]'
	// Impure, but charges nothing — the §6.5.1 exception table.
	'eff-uncharged':     '[\$print "hello"]'
	// Directive heads that charge (the `dir` rows).
	'eff-dir-sleep':     '[?sleep 1s]'
	'eff-dir-service':   '[?http-service name="svc"]'
	'eff-lib-https':     "[?lib 'https://example.com/m.cx' as=r]\n[ok]"
	// Match arms are branch arms; the for-comprehension's yield is not.
	'eff-match-arms':    "[?match [\$env:var \"M\"] [case \"a\" [\$io:read-file \"/a\"]] [else [\$io:write-file \"/b\" \"x\"]]]"
	'eff-for-yield':     '[?for [in \$p ("/a", "/b")] [yield [\$io:read-file \$p]]]'
	// A def inside a def: the walk re-roots `via` at each def-image.
	'eff-nested-def':    "[?def outer () [?def inner () [\$io:read-file \"/x\"]]]\n[\$outer]"
	// Several capabilities at once, some conditional — the shape a
	// reader actually brings to the tool.
	'eff-mixed':         "[?def load (\$p) [\$io:read-file \$p]]\n[?def publish (\$b) [\$http:post \"https://api/x\" \$b]]\n[?def audit (\$e) [\$io:append-file \"/var/log/a\" \$e]]\n[?if [\$env:var \"PUBLISH\"] [then [\$publish [\$load \"/etc/app.cx\"]]] [else [\$audit \"skipped\"]]]"
	'eff-empty':         ''
}

fn main() {
	out_dir := if os.args.len > 1 {
		os.args[1]
	} else {
		os.join_path('vcx', 'tests', 'testdata', 'diagram_effect_golden')
	}
	os.mkdir_all(out_dir) or {
		eprintln('regen_diagram_effect_golden: mkdir ${out_dir}: ${err}')
		exit(1)
	}
	mut ids := effect_sources.keys()
	ids.sort()
	mut written := 0
	for id in ids {
		src := effect_sources[id]
		src_path := os.join_path(out_dir, '${id}.source')
		os.write_file(src_path, src) or {
			eprintln('regen_diagram_effect_golden: write ${src_path}: ${err}')
			exit(1)
		}
		for lvl in levels {
			rendered := code.effect_graph_with_level(src, code.parse_code_diagram_level(lvl)) or {
				eprintln('regen_diagram_effect_golden: ${id} (${lvl}): ${err}')
				exit(1)
			}
			path := os.join_path(out_dir, '${id}.${lvl}.golden')
			os.write_file(path, rendered) or {
				eprintln('regen_diagram_effect_golden: write ${path}: ${err}')
				exit(1)
			}
			written++
		}
	}
	println('regen_diagram_effect_golden: wrote ${written} goldens to ${out_dir}')
}
