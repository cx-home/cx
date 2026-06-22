# CX Command-Line Interface

**Status:** Current

The CX CLI (`cx`) is the user-facing wrapper over libcx. Every
subcommand delegates to a libcx ABI symbol (per
[`core/abi.md`](../core/abi.md)) and adds CLI-only concerns: file I/O,
argv parsing, exit-code mapping, and diagnostic rendering. This spec
is normative for the argv grammar, exit codes, environment variables,
and stdout / stderr framing.

The CLI is the single user-facing tool across all platforms; binding-
specific REPLs and scripts SHOULD shell out to `cx` rather than
re-implement subcommand behaviour, so that exit codes and diagnostic
formatting stay uniform.

---

## 1 — Global invocation

```
cx [GLOBAL OPTIONS] SUBCOMMAND [SUBCOMMAND OPTIONS] [POSITIONAL ARGS]
```

Global options are recognised before the subcommand token; per-
subcommand options are recognised after it. A bare `cx` (no
subcommand) prints help and exits 2 (usage error).

### 1.1 Global options

| Option | Meaning |
|---|---|
| `--help` / `-h` | Print help for the global / subcommand invocation; exit 0. |
| `--version` / `-V` | Print `cx M.N.P`, the libcx version, and `cx_abi_version`; exit 0. |
| `--no-color` | Disable ANSI color in diagnostics. |
| `--quiet` / `-q` | Suppress informational messages on stderr; errors still go to stderr. |
| `--strict` | Promote warnings (per-subcommand) to errors; non-zero exit on any. |
| `--verbose` / `-v` | (At most once.) Emit detail-level diagnostics to stderr. |

### 1.2 Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Generic error (parse failure, runtime error, I/O error). |
| `2` | Usage error (bad argv, missing required arg, unknown subcommand). |
| `3` | Diff detected (only for `cx diff` and `cx eq` — non-zero means inputs differ). |
| `4` | Lint findings (only for `cx lint --strict` — non-zero means diagnostics emitted). |
| `5` | Schema-validation failure (only for `cx validate` — non-zero means invalid). |
| `64` | Internal error (panic, assertion). Includes [`core/code.md §9.5`](../core/code.md) wire codes when applicable. |

Exit codes `0–9` are reserved for CX-defined semantics. Codes `≥ 64`
follow `sysexits.h` conventions for OS-level errors. Bindings that
embed `cx` programmatically SHOULD map exit codes to their host's
exception hierarchy and never silently collapse a non-zero exit into
zero.

### 1.3 Environment variables

| Variable | Effect |
|---|---|
| `CX_NO_COLOR` | Equivalent to `--no-color`. Also respects `NO_COLOR` per https://no-color.org/. |
| `CX_INCLUDE_ROOT` | Sets the include-resolution root (per [`core/code.md §13`](../core/code.md)). |
| `CX_CONFIG` | Path to a `cx.lock`-style config (per [`core/lockfile.md`](../core/lockfile.md)). Default: `./cx.lock`. |
| `CX_QUIET` | Equivalent to `--quiet`. |
| `CX_STRICT` | Equivalent to `--strict`. |

Command-line flags override the corresponding environment variables.

---

## 2 — Subcommand registry

### 2.1 Parse, format, canonical, lint, validate

| Subcommand | Wraps | Effect |
|---|---|---|
| `cx parse FILE [-f FORMAT]` | `cx_to_ast_bin` (or `cx_<fmt>_to_ast_bin`) | Parse to AST; emit `ast_bin` to stdout. |
| `cx fmt FILE` | `cx_fmt` | Lossless canonical (per [`core/canonical.md §2`](../core/canonical.md)). Emit to stdout; `-i` / `--in-place` rewrites the file atomically. |
| `cx canonical FILE` | `cx_canonical` | Strict canonical (per [`core/canonical.md §3`](../core/canonical.md)). Emit to stdout. |
| `cx hash FILE` | `cx_hash` | SHA-256 of strict-canonical bytes. Emit hex to stdout, single line + LF. |
| `cx eq A B` | `cx_eq` | Exit 0 if `A` and `B` are semantically equal, exit 3 if they differ. |
| `cx diff A B` | `cx_diff` ([`core/abi.md §2.17`](../core/abi.md)) | Structured semantic diff. Emit a CX-formatted diff document to stdout; exit 3 on non-empty diff. |
| `cx lint FILE [--ruleset RULES.cxs]` | `cx_lint` ([`core/abi.md §2.18`](../core/abi.md)) | Run lint rules. Emit diagnostics to stdout. `--strict` exits 4 on any finding. |
| `cx validate FILE --schema SCHEMA.cxs` | `cx_validate` | Schema validation. Emit diagnostics to stdout; exit 5 on violation. |

### 2.2 Conversion

| Subcommand | Wraps | Effect |
|---|---|---|
| `cx to-FORMAT FILE` | `cx_to_<format>` family | Emit converted output to stdout. Formats: `cx`, `xml`, `json`, `yaml`, `toml`, `md`, `csv`, `tsv`, `psv`. |
| `cx from-FORMAT FILE` | `cx_<format>_to_ast_bin` then `cx_ast_bin_to_cx` | Equivalent to `cx parse FILE -f FORMAT` followed by a re-emit to CX text. |

Format names are the same set used by [`core/conversions.md`](../core/conversions.md);
unknown formats exit 2 (usage error). The `cx to-cx` form is the
identity transform — it round-trips through the parser and re-emits.

### 2.3 Code evaluation

| Subcommand | Wraps | Effect |
|---|---|---|
| `cx eval EXPR` | `cx_code_eval` | Evaluate a CX-code expression string; emit the result to stdout. |
| `cx run FILE [-- ARG...]` | `cx_code_eval_streaming` | Run a CX-code program; trailing positional args after `--` become `$args` in scope. |
| `cx select FILE PATH` | `cx_code_eval` (with a CXPath path-value expression) | CXPath query; emit matches as a Sequence per [`core/cxdm.md`](../core/cxdm.md). |
| `cx dap` | — | Debug Adapter Protocol server on stdio for editors ([`debug.md`](debug.md)). |
| `cx debug attach ADDR --token=…` | — | Attach to a runtime started with `--debug-listen` ([`debug.md`](debug.md)). |
| `cx debug replay TAPE.cx` | — | Replay a recorded debug tape ([`debug.md`](debug.md) §6a). |

The retired narrow CXPath ABI (`cx_select` / `cx_select_all`, see
[`core/abi.md §2.7`](../core/abi.md)) is NOT re-exposed by the CLI;
`cx select` routes through `cx_code_eval` with a path-value
expression and inherits its semantics.

### 2.4 Schema and introspection

| Subcommand | Wraps | Effect |
|---|---|---|
| `cx features` | `cx_features` | Emit the capability bitmask (hex) and named features, one per line. |
| `cx version` | `cx_version`, `cx_abi_version` | Emit `cx M.N.P`, libcx version, `cx_abi_version`. Equivalent to `cx --version`. |

### 2.5 Tabular

| Subcommand | Wraps | Effect |
|---|---|---|
| `cx table-info FILE` | `cx_table_reader_open` + `cx_table_reader_schema` | Inspect a CXCol table — column names, types, row count, chunk count. Emit a CX-formatted summary. |
| `cx table-rows FILE [--from N] [--limit M]` | `cx_table_reader_*` family | Stream table rows to stdout in CSV form. `--from` / `--limit` slice the row stream without materialising the whole table. |

---

## 3 — Subcommand details

This section adds normative detail for subcommands whose flag set or
exit semantics need more than the registry tables in §2.

### 3.1 `cx fmt`

- `-i` / `--in-place` rewrites `FILE` atomically: writes the formatted
  bytes to a sibling tempfile, `fsync`s it, then renames over `FILE`.
- Without `-i`, formatted bytes go to stdout.
- `--profile=NAME` selects a formatting profile ([`../core/formatting.md`](../core/formatting.md));
  default `canonical`.
- Multiple positional `FILE` arguments are allowed with `-i`; each is
  rewritten independently. A failure on one file does not roll back
  earlier successful rewrites — the exit code reflects whether ANY
  file failed.

### 3.2 `cx canonical`

- Strict canonical (per [`core/canonical.md §3`](../core/canonical.md))
  applies: no comments, single representation per value, sorted
  attribute order.
- No `-i` flag; canonical-form rewrite is a destructive operation that
  drops comments, so explicit redirection (`cx canonical f.cx > f.cx`)
  is required.

### 3.3 `cx hash`

- Output format: lowercase hex, 64 chars, single line terminated by LF.
- Hash is computed over the strict-canonical bytes per §3.2 — the same
  bytes `cx canonical FILE` would emit.
- Identical to the `Doc.hash()` method in [`misc/api.md`](api.md).

### 3.4 `cx eq` / `cx diff`

- Both compare strict-canonical forms — semantic equality, not
  byte-for-byte source equality.
- `cx eq` is silent on equal inputs (exit 0) and silent on differing
  inputs (exit 3); use `cx diff` when you need to see WHAT changed.
- `cx diff` emits a CX-formatted structured diff document; the shape
  is normative per `cx_diff` ([`core/abi.md §2.17`](../core/abi.md)).
- `--format=text` (default) emits the structured CX document;
  `--format=summary` emits a one-line per change human-readable list
  to stdout; the structured-document shape is the contract, summary
  output is informational and not stable across patch versions.

### 3.5 `cx lint`

- Default ruleset covers `L001–L007` (built-in rules registered in
  [`core/code.md §9.5`](../core/code.md)). Reserved codes `L008–L020`
  are not yet allocated.
- `--ruleset RULES.cxs` loads a custom rule document; codes outside
  `L001–L020` are accepted in custom rulesets and surfaced verbatim.
- `--strict` promotes any lint finding (default severity `warning`) to
  an error; exit 4 if any finding emitted, exit 0 otherwise.
- Without `--strict`, `cx lint` always exits 0 even with findings;
  consumers detect findings by parsing the diagnostic stream.

### 3.6 `cx validate`

- `--schema SCHEMA.cxs` is required. Multiple `--schema` flags are
  allowed; the document must validate against every schema (logical
  AND).
- Exit 5 on any S001–S020 violation; the violating CXER-equivalent
  schema codes (`S001`–`S020`, see [`core/schema.md`](../core/schema.md))
  are emitted as structured diagnostics on stdout.
- Schema codes use the `S` prefix and live in their own namespace
  separate from the `CXER` numeric range.

### 3.7 `cx run`

- The CX-code program FILE is loaded via `cx_code_eval_streaming`;
  module imports follow [`core/code.md §12`](../core/code.md) and
  `CX_CONFIG` / `cx.lock` per §1.3.
- Positional args after `--` are exposed inside the program as `$args`
  (a Sequence of strings) per [`core/code.md §13`](../core/code.md).
- The program's final value (or explicit return from `[?return …]`)
  is rendered to stdout in strict-canonical form. If the program
  emits to stdout directly via `[?print]` / stdlib `io/write-line`,
  those writes are interleaved.
- Runtime errors map to exit 1; the wire code (`CXERnnnn`) is
  reported on stderr.
- **Capabilities** (deny-by-default, [`../core/security.md`](../core/security.md)):
  `--allow-read=PATH`, `--allow-write=PATH`, `--allow-net=HOST:PORT`,
  `--allow-env=NAME`, `--allow-run=EXE`, and `--allow-all` (explicit opt-out).
  With no `--allow-*` the capability set is empty (pure-only); a denied effect
  raises `cx-err:CXER0271`, naming the grant to add.
- **Debugging** ([`debug.md`](debug.md)): `--debug` runs a local stepper;
  `--debug-listen=ADDR --debug-token=TOKEN` accepts a remote attach (token
  required; binds `127.0.0.1` unless `ADDR` is external).

### 3.8 `cx select`

- `PATH` is a CXPath expression per [`core/code.md §5.5`](../core/code.md).
- Matches are emitted as a Sequence in document order; an empty match
  set emits an empty Sequence and exits 0.
- `--require-match` (optional) causes exit 3 if the match set is
  empty; useful in scripts that treat "no match" as a failure case.

---

## 4 — Streams and framing

- All subcommands read input from `FILE` (positional) or from stdin if
  `FILE` is `-`.
- All subcommands emit primary output to stdout; diagnostics go to
  stderr.
- Binary outputs (`cx_to_ast_bin`, `cx_to_data_bin`, `cx_to_events_bin`,
  etc.) write the raw `[u32 LE size][payload]` framing per
  [`core/abi.md §1.3`](../core/abi.md). They are NOT base64-encoded.
- Text outputs write LF-terminated lines per
  [`core/canonical.md §2.2`](../core/canonical.md). The final line
  ends in LF.
- `--quiet` suppresses stderr informational messages; stderr is empty
  on success when `--quiet` is set, so scripts MAY tee stderr without
  filtering for success-cases.

---

## 5 — Exit-code matrix (reference)

The table below summarises which exit codes each subcommand may emit.
Blank cells indicate "subcommand never emits this code". Codes `1`
and `2` are emitted by every subcommand and are not repeated.

| Subcommand          | 0           | 3                  | 4              | 5       |
|---|---|---|---|---|
| `cx parse`          | parsed      | —                  | —              | —       |
| `cx fmt`            | formatted   | —                  | —              | —       |
| `cx canonical`      | canonical   | —                  | —              | —       |
| `cx hash`           | hashed      | —                  | —              | —       |
| `cx eq`             | equal       | differ             | —              | —       |
| `cx diff`           | empty diff  | non-empty diff     | —              | —       |
| `cx lint`           | no findings (or non-strict) | — | findings (`--strict`) | — |
| `cx validate`       | valid       | —                  | —              | invalid |
| `cx to-FORMAT`      | converted   | —                  | —              | —       |
| `cx eval`           | ok          | —                  | —              | —       |
| `cx run`            | program ok  | —                  | —              | —       |
| `cx select`         | found       | empty + `--require-match` | —        | —       |
| `cx features`       | always      | —                  | —              | —       |
| `cx table-info`     | inspected   | —                  | —              | —       |
| `cx table-rows`     | streamed    | —                  | —              | —       |

---

## 6 — Stability and version compatibility

- Subcommands and flags in the current release are stable through 1.0 —
  renaming or removing requires a major version bump.
- New subcommands and new flags are additive at minor versions.
- Exit-code semantics are stable through 1.0; new codes are only
  allocated above the `0–9` reserved CX range or in the `sysexits.h`
  `≥ 64` range.
- Error-message text is NOT stable across patch versions; consumers
  should parse exit codes and structured stderr (when `--quiet` is
  set, stderr is empty on success). The error-code stability policy
  is normative in [`process/governance.md §9.5a`](../process/governance.md).

---

## 7 — Cross-references

- [`core/abi.md`](../core/abi.md) — every subcommand's underlying C ABI symbol.
- [`core/canonical.md`](../core/canonical.md) — `cx fmt` and `cx canonical` semantics.
- [`core/code.md`](../core/code.md) — `cx eval`, `cx run`, `cx select` semantics; CXER wire codes.
- [`core/conversions.md`](../core/conversions.md) — formats accepted by `cx to-FORMAT` / `cx from-FORMAT`.
- [`core/schema.md`](../core/schema.md) — `cx validate` schema semantics; `S001–S020` codes.
- [`misc/api.md`](api.md) — library-level equivalents (`Doc.hash`, `Doc.diff`, `Doc.lint`, `Doc.modify`).
- [`misc/bindings.md`](bindings.md) — wire-format negotiation for HTTP / IPC contexts.
- [`process/governance.md §9`](../process/governance.md) — versioning policy; error-code stability.
