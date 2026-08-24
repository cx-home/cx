# Ruling 2026-08-22 — Python eradication and its three blocking defects (#922, #924, #925, #926)

**Status:** RULED by the owner ("1 b obviously… 3 a / 5a / 6 a", then "2c",
"4c", 2026-08-22) against the six items posed in session. Recorded BEFORE
the work per R6.1. Prompted by the owner's finding that the CX-first
tooling directive had been ignored across ~8,045 lines of Python with no
why-not-CX issue and no override ever offered.

This ruling carries NAMED SPEC AUTHORIZATION for:
`spec/03-approved/misc/cli.md` (§3 argv grammar — the positional rule of
PYE-2), `spec/03-approved/std-lib/env.md` (the `argv()[0]` semantics of
PYE-2 and the capability annotation of PYE-3),
`spec/03-approved/std-lib/re.md` (§5 class-context semantics per PYE-4),
and the creation of a NEW normative spec for the `map:` / `array:`
namespaces per PYE-1. Each edit cites this ruling.

## PYE-1 (item 1b) — implement `map:` and `array:` IN FULL

All 26 registered functions ship: `map:` (get, put, keys, size, contains,
entry, merge, remove, for-each) and `array:` (size, get, append, head,
tail, reverse, subarray, put, remove, insert-before, flatten, join,
filter, for-each, fold-left, fold-right, sort). Computed-key access on
maps is included; `$m.$k` is presently a parse error.

The owner's reasoning is the binding constraint and is recorded verbatim
in intent: a partial implementation here "blew a hole in claude's scheme
to hide partial implementation." Shipping only the read surface would
have left 22 names advertised by the parser and 4 by LSP hover with no
implementation behind them — the exact advertised-but-dead pattern the
standing no-stubs rule forbids, and the defect #925 was filed about. The
recommendation to ship a read-only subset was withdrawn as a shortcut.

**Spec gap noted:** `map:` / `array:` have ZERO references in
`spec/03-approved/` AND no stdlib source — `stdlib/` carries 48 modules,
none of them `map.cx` or `array.cx`. The registration is phantom at THREE
layers: the module name resolves as registered-but-sourceless (`[?lib
'cx-stdlib/map']` → CXER0210 MODULE_UNKNOWN_REGISTERED / CXER0213), 26
function names sit in the parser table, and 8 carry LSP hover text. This
ruling authorizes both the normative spec and the stdlib source.

**CORRECTION (same day, before any work):** an earlier revision of this
entry claimed `math:` had the same gap. It does NOT. `math:` is a real,
fully-specified, fully-implemented module — `stdlib/math.cx` plus
`spec/03-approved/std-lib/math.md` with typed signatures — and resolves
normally once `[?lib 'cx-stdlib/math']` is imported (`math:sqrt 16` → 4.0,
`math:pow 2 10` → 1024.0). The claim was a false positive from grepping
for `math:sqrt` when the spec writes `sqrt`. Nothing to file for `math:`.
This is the distinction that matters for PYE-1: a registered `math:*` name
resolves because a module backs it; a registered `map:*` name never
resolves because nothing does.

Complements, does not disturb, the same-day map rulings
`rulings_2026_08_22_map_syntax_settlement.md` (MSS-1…4) and
`rulings_2026_08_22_typed_map_entry.md` (TME-1), which settled map
SYNTAX. This settles map OPERATIONS.

## PYE-2 (item 2c) — program arguments are positional; cx's flags bind before the FILE

The run surface becomes: `cx [cx-flags] FILE [program-args...]`.
Everything after the resource is the program's argv. No `--` separator,
no passthrough flag, no dependence on file content.

Rationale: this is the interpreter convention (`python -O script.py
--verbose`, node, ruby, perl), and it is the only option under which the
two invocation modes are identical. A shebang script — already supported;
`#!/path/to/cx` executes and the parser tolerates the line — currently
cannot accept ANY argument (`./tool.cx alpha` → "unexpected extra
argument"), making CX scripts executable but unusable as CLI tools. Under
PYE-2, `cx foo.cx --verbose in.txt` and `./foo.cx --verbose in.txt` behave
identically.

**Invariant established:** a program's view of its arguments is
independent of how it was launched. This must hold for `cx FILE`,
shebang, `-e`, stdin, and any future standalone or compiled form.

`$env:argv` returns `[resource-path, ...program-args]`, matching
`sys.argv`. `env.md:80` currently says `argv()[0]` is "the executable
path" and is amended to name the resource being run.

**This is a breaking change, accepted.** ~45 invocation sites found by a
narrow grep put cx flags AFTER the file (5 in the Makefile, 8 in shipped
`.cx` script headers, 32 in docs); the true count is higher. Cutover-first
per the standing no-dual-accept rule — there is no transition period and
no acceptance of both forms. CX has no external users, so the cost is
internal only.

## PYE-3 (item 3a) — reading program arguments requires NO capability grant

Deny-by-default gates AMBIENT authority. Program arguments are supplied by
the caller at the invocation site — the caller already exercised the
authority by typing them, exactly as the FILE path is supplied today
without a grant. `$env:argv` and `$env:parse-args` over program args are
therefore ungated.

This does NOT relax `$env:var` / environment reads, which remain behind
`--allow-env`: those are ambient process state, which is the distinction
the capability model exists to draw.

## PYE-4 (item 4c) — the regex class rewrite becomes correct, not narrowed

`re2_apply_unicode_classes` (`vcx/cx/regex_re2.v:234-260`) becomes
character-class aware and resolves shorthands inside `[...]` through
interval arithmetic over codepoint ranges, not textual substitution. All
of `[\s]`, `[\S]`, `[\w]`, `[\W]`, `[\d]`, `[\D]` become correct, as does
the common `[^\S\n]` idiom.

The two cheaper options were rejected on a rule, not a preference:
`re.md` §2 already lists character classes and `\s` / `\w` as ✓ supported,
so leaving shorthands untranslated inside classes (ASCII-inside /
Unicode-outside) or refusing negated shorthands would each require editing
the spec down to the implementation — "never true a spec to a shortfall."

Tractability recorded so the scope is not overestimated: the rewrite
touches five fixed sets only — `\p{Nd}`, `\p{L}`, `\p{Z}`, `\s`, and `_`.
Precompute their intervals once; union / complement / subtract over sorted
interval lists is the standard technique and is what RE2 does internally.

**Orthogonality restored:** `\w` and `[\w]` mean the same thing. The
violation of that property is what produced the defect.

## PYE-5 (item 5a) — the exemption is all of `lang/python/**`

The Python binding target surface is exempt in full: `cxlib/**` plus its
tests, conformance runners, parity driver, benches, and usage examples.
Testing a Python API from Python is not CX-capable work, and the parity
driver is by definition the Python side of a four-language harness.

One evidence-gated exception: `lang/python/conformance.py` and
`conformance_code.py` (844 lines) are inspected during the work. If they
prove to be generic fixture running rather than binding exercise, they are
tooling that drifted into an exempt directory and they migrate. That
determination is reported, not assumed.

Everything outside `lang/python/**` is in scope for eradication —
8,045 lines / 34 files: `scripts/` (6,612), `examples/htmx/serve.py`
(497), `conformance/_audit_fixture.py` + `_convert_fixture.py` (340),
`bench_report.py` (301), `tooling/lsp/tests/` (295).

## PYE-6 (item 6a) — an all-SKIP gate run is a failure

`scripts/check_code_diagram_fixtures.py` currently exits 0 when all 62
fixtures SKIP (documented scaffold intent, its header line 25: "0 all
fixtures PASS (or all SKIP — skips never fail)"). The subcommands it
exercises now ship, so the allowance ends: zero passes means the gate
proved nothing and it exits nonzero. Individual skips remain legitimate.

Resolved in place and independently of the migration, so the correctness
fix is not entangled with a language change. This is NOT the b63c214e
failure mode (an accidental grep inversion); it is a deliberate allowance
that outlived its reason.

## Sequencing

#924, #925, #926 land BEFORE #922 — the migration is written against the
fixed language, not around the defects, and each defect gains its first
live consumer from the migration. The three are independent of each other
(`area:v-runtime`, `area:cx-lang`, `area:cli`, no shared files) and may
run in parallel. PYE-6 is independent of all four.

Model policy: all four are bulk implementation and sit in the Opus lane.
Map identity semantics were verified already settled — `{beta: 2, alpha:
1}` and `{alpha: 1, beta: 2}` share canonical form, hash, and equality —
so PYE-1 introduces no canonicalization question and no Fable-lane work.
