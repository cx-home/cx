# Reference: the `cx` command line — v0.16.0

> **GENERATED.** Source: `docs-src/llm/reference-cli.md.tmpl`. The help text
> below is the v0.16.0 binary's own `--help`, captured at generation
> time — not a transcription. Read `primer.md` first.

## The one rule

```
cx [cx-flags] FILE [program-args...]
```

Flags bind **before** the resource. Everything after the resource is the
program's `argv`. This is the interpreter convention (and shebang-identical),
and getting it backwards does not produce a usage error — it produces a
program that silently never got its capability:

#### cx flags placed after the file

The run surface is `cx [cx-flags] FILE [program-args...]` — the interpreter
convention. Everything AFTER the file is the PROGRAM's argv (#926), so
`--allow-env` there is a string handed to the program, not a grant handed to
`cx`. The capability is never granted and the program dies at its first
effect. Nothing warns you: the flag was consumed, just not by cx.

**Do not write this:**

`prog.cx`
```cx
[?lib 'cx-stdlib/env' as=env]
[probe args=[$count [$env:argv]] home=[$env:var-or-default 'CX_PRIMER_ABSENT' 'unset']]
```

```console
$ cx prog.cx --allow-env
[err code=cx-err:CXER0271 message='E_CAP_DENIED: env capability required for env-var-or-default; none granted (grant via --allow-env)']
```

**Write this:** cx flags placed before the file

`prog.cx`
```cx
[?lib 'cx-stdlib/env' as=env]
[probe args=[$count [$env:argv]] home=[$env:var-or-default 'CX_PRIMER_ABSENT' 'unset']]
```

```console
$ cx --allow-env prog.cx
[probe args=1 home=unset]
```

<sub>Fixtures: `ap-flags-after-file-wrong` / `ap-flags-after-file-right` in `conformance/llm/antipatterns.cxd`</sub>

An inline one-liner uses `-e`, and `cx eval` — a legacy alias of the default
action — still takes a **file**:

#### `cx eval 'PROGRAM'` — the subcommand takes a FILE

`cx eval` is a legacy ALIAS of the default run action and, like it, takes a
FILE. An inline program needs `-e`. The habit of writing
`cx eval '<source>'` (from other interpreters) makes cx try to OPEN the
program text as a path. Two rules avoid the whole class: run files with
`cx FILE`, and reach for `cx -e 'PROGRAM'` only for a one-liner.

**Do not write this:**

`prog.cx`
```cx
[+ 1 2]
```

```console
$ cx eval '[+ 1 2]'
cx eval: error reading program "[+ 1 2]": failed to open file "[+ 1 2]"; code: 2
```

**Write this:** `cx -e 'PROGRAM'` for a one-liner

`prog.cx`
```cx
[+ 1 2]
```

```console
$ cx -e '[+ 1 2]'
3
```

<sub>Fixtures: `ap-cx-eval-inline-wrong` / `ap-cx-eval-inline-right` in `conformance/llm/antipatterns.cxd`</sub>

## Reading program arguments

`env:argv` is ungated (reading your own arguments is not an effect) and
`argv[0]` is the file. `env:parse-args` takes a declarative flag spec.

`prog.cx`
```cx
[?lib 'cx-stdlib/env' as=env]
[probe args=[$count [$env:argv]] home=[$env:var-or-default 'CX_PRIMER_ABSENT' 'unset']]
```

```console
$ cx --allow-env prog.cx
[probe args=1 home=unset]
```

## `cx --help`

```console
$ cx --help
Usage:
  cx [flags] FILE.cx [args...]   Run a CX resource (the default action): parse
                            and evaluate. A pure-data document evaluates to
                            itself. Everything after FILE is the PROGRAM's
                            argv ($env:argv, argv[0]=FILE) — cx flags go
                            BEFORE the file, program args after (the
                            interpreter convention; shebang-identical).
  cx [flags] - [args...]    Run a program from stdin (a pipe into bare `cx`
                            with no FILE also evaluates stdin).
  cx [flags] -e 'PROGRAM' [args...]   Run an inline program (also --expression).
  cx <subcommand> [args]    One of the subcommands below.
  cx -v | --version         Version / build info.
  cx -h | --help            This help.

Run flags (the default action; flags bind BEFORE the resource):
  --cx (default) | --xml | --json | --yaml | --csv | --tsv   render the RESULT
  --data=FILE|-             separate data input: loaded via the data reading
                            and bound as $doc/$input before evaluation; the
                            caller input WINS over the program's data roots.
  --strict                  enforce declared ::T / [returns T] annotations at
                            call boundaries + [?pipe] stage flow (code.md §12.7;
                            default OFF erases annotations — documentation only).
  Unknown flags are hard usage errors (exit 2) — nothing is ignored.
  Capabilities are deny-by-default (spec/core/security.md); grant explicitly:
    --allow-read --allow-write --allow-net --allow-env --allow-clock
    --allow-random --allow-subprocess --allow-eval --allow-secret-reveal --allow-common --allow-all
    (--allow-net takes an optional scope: --allow-net=host[:port])
    --allow-common is the common working set WITHOUT secret-reveal;
    --allow-all additionally grants secret-reveal, which declassifies secrets.

Convert flags (the data reading; an explicit --from selects it):
  cx --from=FMT [--to=FMT] [--compact] [--lossless] [--include-root=DIR] [FILE]
    --from: cx|xml|json|yaml|toml|md|csv|tsv|psv
            (.xml/.json/.yaml/.toml/.md files auto-detect their format)
    --to:   cx|xml|json|yaml|toml|md|csv|tsv|psv
  Projection shorthands: --ast --cx --xml --json --yaml --toml --md --csv
                         --tsv --psv --cxcol
  --compact              minimised output
  --lossless             emit round-trip-preserving output (conversions.md
                         0.2/2.2.1): xml carries cx: markers; json/yaml
                         carry the $tag structure envelope plus a `cx:type`
                         sidecar / `!!cx:T` tags — element docs re-import
                         byte-identically (cx/xml/json/yaml targets; other
                         lanes reject the flag)
  --include-root=DIR     resolve [?cx include=...] against DIR first

Subcommands (`cx <subcommand> --help` for details):
  fmt               Lossless canonical formatter (preserves comments/anchors).
  canonical         Strict canonical text (strips presentation; data-equivalent).
  schema            Schema verb family — infer a .cxs from a corpus; export to JSON Schema; classify compatibility.
  tools             Agent-tool verb family — project command defs to MCP tool descriptors.
  hash              SHA-256 hex of the strict-canonical bytes.
  eq                Exit 0 iff strict-canonical(A) == strict-canonical(B).
  diff              Semantic diff (walks the strict-canonical forms).
  lint              Style + correctness warnings.
  validate          Validate a document against a CX schema (.cxs).
  eval              Evaluate a CX program (alias of the default run action; prefer `cx FILE`).
  primer            Print the LLM onboarding primer for THIS binary (#938).
  version           Version / build info (same output as -v / --version).
  select            CXPath query over a document (matches in canonical CX).
  diagram           Render a CX program as a diagram (mermaid/svg/png).
  code-diagram      Mermaid diagram of a CX source (flowchart / erDiagram).
  code-tree         Tree View JSON of a CX source.
  table             Table API over [table[...]] blocks (info / dump / load).
  scaffold          Typed, commented skeleton on stdout (config/data/doc/log/table).
  xap               XAP project tooling — scaffold (`init`) and check (`check-surface`).
  demo              Self-contained showcase (no file I/O, no network, < 1s).
  lock              Generate / verify cx.lock from [?lib] directives.
  lsp               Language server (LSP) on stdio.
  store-serve       Run the CX store service daemon from a config.
  fabric-serve      Run the CX fabric eventing daemon from a config.
  store-health      Store readiness probe (exit 0 iff accepting).
  store-rotate-kek  Rotate a store key-encryption key (re-wrap envelopes).
```

## The verbs you will actually reach for

| Command | Use it for |
|---|---|
| `cx FILE.cx` | run a program, or print a document's canonical form |
| `cx -e 'PROG'` | a one-liner |
| `cx fmt FILE` | lossless format (keeps comments and anchors) |
| `cx canonical FILE` | strict canonical text — what identity is defined over |
| `cx hash FILE` | SHA-256 of the strict-canonical bytes |
| `cx eq A B` / `cx diff A B` | semantic equality / semantic diff |
| `cx lint FILE` | style and correctness findings |
| `cx validate FILE --schema=S.cxs` | schema check |
| `cx select 'PATH' FILE` | one CXPath query, no program |
| `cx --from=json --to=cx f.json` | the convert surface |
| `cx code-diagram FILE` | Mermaid of a program (or `--view=effects` for its capability graph) |
| `cx primer` | this documentation set's primer, for the installed binary |
| `cx demo` | a self-contained showcase, no I/O, under a second |

## Capability grants

```
--allow-read --allow-write --allow-net[=host[:port]] --allow-env
--allow-clock --allow-random --allow-subprocess --allow-eval
--allow-secret-reveal
--allow-common     # all of the above EXCEPT secret-reveal
--allow-all        # including secret-reveal (declassifies secrets)
```

Deny-by-default, and a denial names the flag that would have allowed it:

`prog.cx`
```cx
[?lib 'cx-stdlib/io']
[$io:write-file "/tmp/out.txt" "hello"]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0271 message='E_CAP_DENIED: write capability required for io-write-file; none granted (grant via --allow-write)']
```

Grant the narrowest thing that works. `--allow-net` takes a scope; the others
are all-or-nothing, which is a reason to prefer `--allow-read` over
`--allow-common` in anything automated.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the program produced an error value, or a check found findings |
| 2 | usage error — an unknown flag, a missing file, a bad invocation |

Unknown flags are hard errors. Nothing is ignored, which is why a typo'd
grant fails loudly *before* the file but silently *after* it.

## Scripting `cx` from CX

Tooling in this repo is written in CX and run with `cx <file>` — never
`cx eval`, and never a shell wrapper where CX would do. The pattern:

```console
cx --allow-read --allow-write --allow-subprocess --allow-env script.cx --flag value
```

Flags for `cx` first, the script, then the script's own arguments.
