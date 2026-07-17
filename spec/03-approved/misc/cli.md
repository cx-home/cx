# CX Command-Line Interface

**Status:** Current

The CX CLI (`cx`) is the one user-facing binary over the V core — the
same parser, canonicalizer, and evaluator that back `libcx` (per
[`core/abi.md`](../core/abi.md)) and every host-language binding. The
CLI adds only CLI concerns: argv parsing, file I/O, exit-code mapping,
and diagnostic rendering. This spec is normative for the argv grammar,
exit codes, and stdout / stderr framing.

The CLI is the single user-facing tool across all platforms;
binding-specific REPLs and scripts SHOULD shell out to `cx` rather
than re-implement subcommand behaviour, so that exit codes and
diagnostic formatting stay uniform.

Subcommand dispatch, the `cx --help` catalogue, and every
per-subcommand `--help` body are generated from ONE registry
(`vcx/cmd/main.v`, the `SubcommandSpec` table): a subcommand cannot
exist without being documented, and help can never drift from
dispatch.

---

## 1 — Global invocation

```
cx FILE.cx [RUN FLAGS]          # run a CX resource (the default action, §3.7)
cx - [RUN FLAGS]                # run a program from stdin (a pipe into bare
                                # `cx` with no FILE also evaluates stdin)
cx -e 'PROGRAM' [RUN FLAGS]     # run an inline program (also --expression)
cx --from=FMT [CONVERT FLAGS]   # convert a data document (the data reading)
cx SUBCOMMAND [ARGS]            # one of the subcommands in §2
```

The bare surface (no subcommand token) has two readings, selected by
the flags — the **run** surface (the program reading, §3.7) and the
**convert** surface (the data reading; an explicit `--from=…`, a
structural projection, `--compact`, or `--lossless` selects it). A
bare `cx` with no input and a TTY on stdin prints usage and exits
non-zero.

Unknown flags anywhere on the bare surface are a **hard usage error**
(exit 2) naming the flag — never a silent no-op (§3.7). Subcommands
likewise reject argv they do not understand with exit 2.

### 1.1 Global options

| Option | Meaning |
|---|---|
| `--help` / `-h` | Print help; exit 0. Uniform on every surface: `cx --help` prints the catalogue, `cx SUBCOMMAND --help` (or `-h`) prints that subcommand's usage. |
| `--version` / `-v` | Print expanded version / build info (version, commit, build date, GC model, V-fork gitlink); exit 0. Also available as the `cx version` verb — a registry subcommand, so the bare word can never fall through to the run surface and evaluate a `./VERSION` file on a case-insensitive filesystem. |

### 1.2 Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Error (parse failure, runtime error, I/O error) — or the subcommand's **meaningful negative**: `cx eq` / `cx diff` inputs differ, `cx lint` / `cx validate` findings at or above the `--fail-on` threshold, `cx select` empty match set, `cx lock --check` drift. |
| `2` | Usage error (bad argv, unknown flag, missing required argument, unknown subcommand). Some inspection subcommands also map unreadable input to 2. |

Exit codes `0–9` are reserved for CX-defined semantics. Bindings that
embed `cx` programmatically SHOULD map non-zero exits to their host's
exception hierarchy and never silently collapse a non-zero exit into
zero. Which of `1` / `2` a given subcommand emits for which condition
is normative per subcommand in §3 and summarised in §5.

### 1.3 Environment variables

The CLI itself is flag-driven; the few environment variables it
consults belong to specific subsystems:

| Variable | Effect |
|---|---|
| `CX_WORKER_THREADS` | Worker-pool sizing for the concurrency directives ([`core/code.md`](../core/code.md) §10.4). |
| `CX_STORE_KEK_<ID>` | Key-encryption keys for `cx store-rotate-kek` (§2.6). |
| `CX_ARROW_LIB` | Path to `libcx_arrow` for `cx table` Parquet / Arrow I/O. |

Command-line flags always override environment variables.

---

## 2 — Subcommand registry

The full dispatch surface — every verb below answers
`cx <verb> --help` with its usage. The tables group the registry by
concern; the registry itself (one table in `vcx/cmd/main.v`) is the
single source of truth.

### 2.1 Parse, format, canonical, lint, validate

| Subcommand | Effect |
|---|---|
| `cx fmt [FILE]` | Lossless canonical formatter (per [`core/canonical.md`](../core/canonical.md), lossless canonical): preserves comments / anchors, normalizes whitespace and quoting. Also hosts the parser-based migration sweeps (`--migrate-predicates`, `--collapse-lets`). |
| `cx canonical [FILE]` | Strict canonical text (per [`core/canonical.md`](../core/canonical.md), strict canonical): strips presentation; output is data-equivalent. |
| `cx hash [FILE]` | SHA-256 hex of the strict-canonical bytes — the content address of the document. |
| `cx eq A B` | Exit 0 iff `strict-canonical(A) == strict-canonical(B)`; exit 1 if they differ. |
| `cx diff [FLAGS] A B` | Semantic diff over the strict-canonical forms; exit 1 on a non-empty diff (§3.4). |
| `cx lint [FLAGS] [FILE]` | Style + correctness warnings; exit 1 at/above `--fail-on` (§3.5). |
| `cx validate FILE --schema=SCHEMA.cxs [FLAGS]` | Schema validation per [`core/schema.md`](../core/schema.md); exit 1 at/above `--fail-on` (§3.6). |

`FILE` is optional where bracketed — those subcommands read stdin when
it is absent (§4).

### 2.2 Conversion (the bare convert surface)

Conversion is a bare-surface flag set, not a subcommand family:

```
cx --from=FMT [--to=FMT] [--compact] [--lossless] [--include-root=DIR] [FILE]
cx --ast|--cx|--xml|--json|--yaml|--toml|--md|--csv|--tsv|--psv|--cxcol [FILE]
```

- `--from` / `--to` name any codec in the registry
  ([`core/codec.md`](../core/codec.md)); the accepted text-format set
  is `cx xml json yaml toml md csv tsv psv`, and an unknown name exits
  non-zero with the registry error (never silently folds to `cx`).
- Non-CX input files auto-detect their format from the extension
  (`.xml` / `.json` / `.yaml` / `.yml` / `.toml` / `.md`) and stay on
  the convert surface.
- The projection shorthands (`--json` etc.) pick the output form of a
  single input; `--ast` emits the AST JSON, `--cxcol` the binary
  columnar form (§4).
- `--lossless` requests type-preserving output per
  [`core/conversions.md`](../core/conversions.md) §0.2 and is accepted
  only by lanes whose emitter implements a lossless image (`cx`,
  `xml`, `json`, `yaml` — read from the codec registry's capability
  flag); every other lane rejects the flag loudly (exit 2).
- `--include-root=DIR` resolves `[?cx include=…]` directives against
  `DIR` before conversion (include resolution is opt-in per
  [`core/code.md`](../core/code.md) §13).

### 2.3 Code evaluation

| Surface | Effect |
|---|---|
| `cx FILE.cx [--data=INPUT] [FLAGS]` | The **default action** (the run surface, §3.7): parse and evaluate the resource per [`core/code.md`](../core/code.md) §1.3. A pure-data document evaluates to itself. |
| `cx eval PROGRAM.cx [--data=INPUT] [FLAGS]` | Documented alias of the default action (prefer the plain `cx FILE.cx` spelling). Adds the inline forms `-e 'PROGRAM'` / `-d 'INPUT'` and `--target=FMT`. |
| `cx select 'PATH' [FILE]` | CXPath query over a document; matches print in canonical CX (§3.8). |

The debug surface (`cx dap`, `cx debug attach`, `cx debug replay`) is
specified in [`debug.md`](debug.md) but is **not yet shipped** — the
verbs are not in the registry and dispatch as usage errors until that
spec's implementation lands.

The retired narrow CXPath ABI (`cx_select` / `cx_select_all`, see
[`core/abi.md §2.7`](../core/abi.md)) is NOT re-exposed by the CLI;
`cx select` evaluates a CXPath value expression through the one
program evaluator and inherits its semantics (§3.8).

### 2.4 Inspection and visualisation

| Subcommand | Effect |
|---|---|
| `cx diagram PROGRAM.cx [--format=mermaid\|svg\|png] [-o OUT]` | Render a CX program as a diagram; every format embeds the source bytes, so the diagram reverse-parses to the same AST. |
| `cx code-diagram [FILE\|-] [--level=min\|compact\|full]` | Mermaid emitter: flowchart for code sources, erDiagram for data sources. |
| `cx code-tree [FILE\|-]` | Tree View JSON rendering of a CX source. |
| `cx demo` | Self-contained showcase (no file I/O, no network, < 1 s). |
| `cx scaffold KIND` | Typed, commented skeleton on stdout (`config` / `data` / `doc` / `log` / `table`). |
| `cx version` | Version / build info — identical output to `-v` / `--version` (§1.1). |

### 2.5 Tabular

| Subcommand | Effect |
|---|---|
| `cx table info FILE` | Column / row counts, types, byte size of a `[table[…]]` block. |
| `cx table dump FILE [--to=cx\|parquet\|arrow] [--output=FILE]` | Export a table block. |
| `cx table load FILE [--from=cx\|parquet\|arrow] [--to=cx] [--output=FILE]` | Import to a table block. |

`FILE` may be omitted to read stdin. Parquet / Arrow I/O requires
`libcx_arrow` (built with `-d cx_arrow_files`; located via
`CX_ARROW_LIB`).

### 2.6 Project and service

| Subcommand | Effect |
|---|---|
| `cx lock [FLAGS] [FILE...]` | Generate / verify `cx.lock` from `[?lib]` directives (per [`core/lockfile.md`](../core/lockfile.md)); `--check` exits 1 on drift. |
| `cx lsp [--verbose]` | The CX language server on stdio. |
| `cx store-serve --config PATH [--allow-*]` | Run the CX store service daemon. |
| `cx store-health --url READY_URL` | Store readiness probe; exit 0 iff accepting. |
| `cx store-token --id NAME [FLAGS]` | Mint a store bearer token + config stanza. |
| `cx store-rotate-kek --url URL --encrypt-key-id OLD --new-key-id NEW` | Rotate a store key-encryption key. |

---

## 3 — Subcommand details

This section adds normative detail for surfaces whose flag set or
exit semantics need more than the registry tables in §2.

### 3.1 `cx fmt`

- Formatted bytes go to stdout; rewriting a file is explicit
  redirection (`cx fmt f.cx > f.fmt.cx && mv f.fmt.cx f.cx`).
- Lossless canonical applies: comments, anchors, and authorial
  structure are preserved; whitespace and quoting are normalised.
- The migration sweeps (`--migrate-predicates`, `--collapse-lets`) are
  parser-based (never regex) and fail-closed per file; `-w` writes
  changed files in place and is required for multiple `FILE`s.

### 3.2 `cx canonical`

- Strict canonical applies: no comments, single representation per
  value, sorted attribute order.
- No in-place mode; canonical-form rewrite is a destructive operation
  that drops comments, so explicit redirection is required.

### 3.3 `cx hash`

- Output format: lowercase hex, 64 chars, single line terminated by LF.
- Hash is computed over the strict-canonical bytes per §3.2 — the same
  bytes `cx canonical FILE` would emit.
- Identical to the `Doc.hash()` method in [`misc/api.md`](api.md).

### 3.4 `cx eq` / `cx diff`

- Both compare strict-canonical forms — semantic equality, not
  byte-for-byte source equality.
- `cx eq` is silent: exit 0 on equal inputs, exit 1 on differing
  inputs, exit 2 on error; use `cx diff` when you need to see WHAT
  changed.
- `cx diff` flags: `--format=unified|json|summary` (default
  `unified`), `--no-color`, `--color[=always|never|auto]` (default
  `auto`: color on a TTY only). Exit 0 on an empty diff, 1 on a
  non-empty diff, 2 on error.
- The unified rendering is human-oriented; the `json` rendering is the
  stable machine shape.

### 3.5 `cx lint`

- Flags: `--format=text|json|summary` (default `text`),
  `--fail-on=info|warn|error|none` (default `error`),
  `--disable=ID1,ID2`, `--only=ID`, `--config=PATH` / `--no-config`.
- When neither `--config` nor `--no-config` is given, the nearest
  `.cxlint.cx` (walking up from the input file's directory, or the
  cwd for stdin) is auto-discovered and merged into the active
  options.
- Exit 0 when no finding is at/above the `--fail-on` threshold, 1
  when any is, 2 on error. `--fail-on=none` always exits 0.

### 3.6 `cx validate`

- `--schema=SCHEMA.cxs` is required.
- Flags: `--fail-on=info|warn|error|none` (default `error`),
  `--mode=open|strict|closed` (overrides the schema-mode directive),
  `--apply-defaults` (insert schema-default attribute values).
- Exit 0 when no diagnostic is at/above `--fail-on`, 1 when any is,
  2 on I/O / schema-load failure. Schema semantics and codes are
  normative in [`core/schema.md`](../core/schema.md).

### 3.7 The run surface (bare `cx`)

The **default action**: `cx FILE.cx` (or `cx -`, `cx -e 'PROGRAM'`, or
a pipe into bare `cx`) selects the **program reading** of
[`core/code.md`](../core/code.md) §1.3 — parse and evaluate. A
pure-data resource evaluates to itself, and the §1.3 data-reading
fallback (with its program-intent guards) applies. `cx eval` is the
documented alias of this action.

- **Separate data input — `--data=FILE|-`.** The caller MAY supply a
  data document alongside the program. The input is loaded via the
  **data reading** (respecting `--include-root` when given) and bound
  as `$doc` (and `$input`) before evaluation. Per `core/code.md` §1.3,
  the caller-supplied input **wins**: the program's own data roots
  never rebind `$doc`. Without `--data`, the implicit-`$doc` selection
  of §1.3 applies (first data root, else `$doc` unbound). `--data=-`
  reads the input document from stdin; combining that with a
  program also arriving on stdin is a usage error (exit 2). A missing
  or unreadable `--data` file is a loud error (exit 1) — never a
  silent no-op.
- `--data` belongs to the run surface only: combining it with the
  convert surface (an explicit `--from=…`, an auto-detected non-CX
  input, a structural projection such as `--ast` / `--toml` / `--md` /
  `--psv` / `--cxcol`, `--compact`, or `--lossless`) is a usage error
  (exit 2).
- **Result rendering:** the program's final value is rendered to
  stdout in canonical CX by default; `--xml` / `--json` / `--yaml` /
  `--csv` / `--tsv` render the RESULT in that format (they do not
  reroute to the convert surface).
- **Unknown flags are hard errors.** Any flag the run surface does not
  recognise — including a misspelled `--allow-*` grant — exits 2 with
  a diagnostic naming the flag and pointing at `cx --help`. A flag
  that requires a value (`--data`, `--from`, `--to`,
  `--include-root`) given without one is the same usage error. The
  pre-#415 behaviour (silently ignoring unknown flags, exit 0) was a
  defect; nothing on the surface may swallow argv.
- Extra positional arguments (a second FILE, or a FILE alongside
  `-e` / `-`) are usage errors (exit 2).
- **Capabilities** (deny-by-default,
  [`core/security.md`](../core/security.md)): `--allow-read`,
  `--allow-write`, `--allow-net[=HOST[:PORT]]`, `--allow-env`,
  `--allow-clock`, `--allow-random`, `--allow-subprocess`,
  `--allow-eval`, `--allow-secret-reveal`, and `--allow-all` (the
  explicit opt-out). Only the `net` grant takes a scope argument
  today; a bare `--allow-net` additionally denies private ranges
  (override with a literal-IP scope or `--allow-all`). With no
  `--allow-*` the capability set is empty (pure-only); a denied effect
  raises `cx-err:CXER0271`, naming the grant to add.
- `--include-root=DIR` resolves `[?cx include=…]` in the program (and
  in the `--data` input) before evaluation.
- Runtime errors map to exit 1; the wire code (`CXERnnnn`) is reported
  on stderr.

### 3.8 `cx select`

```
cx select 'PATH' [FILE]
```

CXPath query over one document — a pure read; the subcommand is
capability-neutral (it accepts no `--allow-*` flags and needs none).

- `PATH` is a single CXPath value expression per
  [`core/code.md §5.5`](../core/code.md): `$doc`-anchored
  (`$doc/user@name`), document-rooted (`/users/user`), or descendant
  (`//user[= $_@role 'admin']`). The input document is bound as `$doc`
  (and `$input`); no other binding is in scope. An argument that is
  not a path expression is a usage error (exit 2).
- The document is read from `FILE`, or from stdin when `FILE` is `-`
  or absent, via the **data reading**.
- **Output:** matches print to stdout one per line, in document order,
  in canonical CX. Attribute-axis matches materialize as
  `[name value]` fields; a single-focus plain child-chain attribute
  read prints the attribute's typed scalar value (the `core/code.md`
  §6.2 terminal-attribute unwrap — in canonical CX, so strings print
  quoted). An empty match set prints nothing.
- **Exit codes:** 0 when at least one node matched; 1 when the match
  set is empty; 2 on error (usage, unreadable input, document or path
  parse error).

---

## 4 — Streams and framing

- Subcommands that take an optional `FILE` read stdin when it is
  absent or `-`.
- All subcommands emit primary output to stdout; diagnostics go to
  stderr.
- The binary projection (`--cxcol`) writes the raw
  `[u32 LE size][payload]` framing per
  [`core/abi.md §1.3`](../core/abi.md); it is NOT base64-encoded.
- Text outputs write LF-terminated lines per
  [`core/canonical.md §2.2`](../core/canonical.md). The final line
  ends in LF.

---

## 5 — Exit-code matrix (reference)

The table below summarises the meaningful exits per surface. Code `2`
(usage error) is available on every surface and is not repeated.

| Surface | 0 | 1 |
|---|---|---|
| run surface (bare `cx` / `cx eval`) | program ok | parse / runtime / I-O error |
| convert surface (`--from` / projections) | converted | parse / convert error |
| `cx fmt` | formatted | parse error |
| `cx canonical` | canonical | parse error |
| `cx hash` | hashed | parse error |
| `cx eq` | equal | differ |
| `cx diff` | empty diff | non-empty diff |
| `cx lint` | no findings ≥ `--fail-on` | findings ≥ `--fail-on` |
| `cx validate` | valid | diagnostics ≥ `--fail-on` |
| `cx select` | ≥ 1 match | empty match set |
| `cx table` | ok | error |
| `cx lock` | generated / clean | `--check` drift |
| `cx store-health` | accepting | not accepting |

---

## 6 — Stability and version compatibility

- Subcommands and flags in the current release are stable through 1.0 —
  renaming or removing requires a major version bump.
- New subcommands and new flags are additive at minor versions.
- Exit-code semantics are stable through 1.0; new codes are only
  allocated above the `0–9` reserved CX range or in the `sysexits.h`
  `≥ 64` range.
- Error-message text is NOT stable across patch versions; consumers
  should parse exit codes, not stderr text. The error-code stability
  policy is normative in
  [`process/governance.md §9.5a`](../process/governance.md).

---

## 7 — Cross-references

- [`core/abi.md`](../core/abi.md) — the C ABI the same engine exports to bindings.
- [`core/canonical.md`](../core/canonical.md) — `cx fmt` and `cx canonical` semantics.
- [`core/code.md`](../core/code.md) — the run surface's program reading, `$doc` binding, CXPath (`cx select`) semantics; CXER wire codes.
- [`core/conversions.md`](../core/conversions.md) / [`core/codec.md`](../core/codec.md) — formats accepted by the convert surface.
- [`core/schema.md`](../core/schema.md) — `cx validate` schema semantics.
- [`core/security.md`](../core/security.md) — the capability model behind `--allow-*`.
- [`debug.md`](debug.md) — the specified (not yet shipped) debug surface.
- [`misc/api.md`](api.md) — library-level equivalents (`Doc.hash`, `Doc.diff`, `Doc.lint`, `Doc.modify`).
- [`process/governance.md §9`](../process/governance.md) — versioning policy; error-code stability.
