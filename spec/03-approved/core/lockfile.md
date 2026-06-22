# `cx.lock` — normative lockfile specification

**Status:** Current.
**Normative reference for:** `[?lib]` module resolution per [`code.md` §12.1](code.md).
**Authoritative formal grammar:** [`grammar.ebnf`](grammar.ebnf) productions [149]–[151] (`[?lib]` surface) plus the CX-data grammar (the lockfile itself is a CX-data document).

---

## §1. Purpose

`cx.lock` is the **single source of truth** for module resolution at
load time. It maps every module name a program imports (directly or
transitively) to a resolved bytes-identifier and, for bytes fetched
over HTTPS, a cryptographic integrity hash. Source files name
modules by **namespace path only**; the lockfile names **which
version** of those bytes is in scope.

The separation is load-bearing:

- **Source answers "what library."** Stable across version bumps;
  survives refactors.
- **Lockfile answers "which version."** Per-project, per-environment,
  single source of truth.

Concrete invariants enforced by the loader:

1. Every HTTPS-resolved module MUST have an `:sri` field in
   `cx.lock`; bytes that don't hash to that field's value are
   rejected (`cx-err:CXER0209`).
2. Every transitive HTTPS module reachable from the program's
   direct imports MUST have a matching `cx.lock` entry; missing
   entries are rejected (`cx-err:CXER0211 E_LIB_UNPINNED`).
3. `cx.lock` is checked into source control. Two developers who
   pull the same commit MUST resolve `[?lib]` to byte-identical
   bytes.

## §2. File location

The lockfile sits at the **project root** — the same directory as
the program's top-level `.cx` source file. Subdirectories and
imported packages do not have their own `cx.lock`; the project
root's lockfile is the authority for every module reachable from
the program.

The CLI surface for generating and updating `cx.lock` (`cx lock`,
`cx lock --update`, etc.) is **out of scope for this spec** and is
documented separately. This spec normates the file format and the
loader's read-side semantics only.

## §3. Format

`cx.lock` is a CX-data document. It parses through the existing
data grammar; no new lexer or parser support is required. The root
element is `cx.lock` and its single attribute is the schema
version. The body is a `modules` element containing one or more
`module` entries, optionally followed by a `transitive-graph`
element encoding the cross-module dependency edges.

```
[cx.lock version=1
  [modules
    [module ...]+]
  [transitive-graph
    [edge ...]*]]
```

### §3.1 Schema versioning

The `version` attribute on the root element identifies the
lockfile schema. **The current schema is `version=1`.** Loaders MUST
reject any `version` value they do not recognise; future schema
versions will be additive (new attributes, new sub-elements) but
the schema version is bumped whenever the loader's read-side
behaviour changes.

A loader at lockfile schema v1 reading a future v2 lockfile
raises a parse-time error and refuses to load the program. There
is no graceful-degrade path.

## §4. `[module]` entries

Each `[module]` entry maps one imported namespace to its resolved
bytes:

```
[module
  name=STRING       [; the resolver string from [?lib] ]
  resolved=STRING   [; absolute resolution; see §4.1 ]
  version=STRING?   [; semver-style version, optional ]
  sri=STRING?       [; SRI integrity hash; required for HTTPS ]
  ]
```

### §4.1 `name`

The exact resolver string as it appears in `[?lib]` source. The
loader matches lockfile entries by literal-string equality on
`:name`. Examples:

- `'cx-stdlib/strings'`
- `'github.com/example/regex-helpers'`
- `'./local-helpers.cx'`
- `'https://cdn.example.com/regex-1.2.3.zip'`

`name` is the lookup key; the loader does no normalization,
canonicalization, or rewriting before matching. `'./helpers.cx'`
and `'helpers.cx'` are distinct keys; only the form that matches
the source `[?lib]` directive is found.

### §4.2 `resolved`

The fully-resolved bytes identifier. Three shapes:

| `resolved` value shape | Meaning |
|---|---|
| `"./relative/path.cx"`, `"../parent/path.cx"`, or `"/abs/path/to/file.cx"` | File-path module per `code.md §12.1.1`; bytes are read from disk |
| `"https://cdn.example.com/foo-1.2.3.zip"` | HTTPS-fetched module; bytes pulled per [`code.md` §12.1.3](code.md) |
| `"bundled:<version>"` | Module shipped inside the CX binary; `<version>` matches the binary's version (e.g. `"bundled:0.8.0"`) |

The `resolved` shape determines whether `sri` is required (§4.4)
and how the loader retrieves the bytes (§5).

### §4.3 `version`

Optional semver-style version string. Informational —
the loader does **not** parse or compare versions. The field is
present so that humans reading the lockfile (and downstream
tooling) can identify which release of a module's resolved bytes
are in scope.

Future loader work may add `cx lock --upgrade` semantics that
consult `version` against publisher metadata; that surface is
out of scope here.

### §4.3.1 Version hotfix override interaction with `[?lib]`

`code.md §12.1` reserves a `[version 'X']` clause-child on `[?lib]`
for hotfix overrides — e.g.
`[?lib 'github.com/example/regex-helpers' [version '1.2.4-hotfix']]`.

When a `[?lib]` carries a `[version 'X']` clause-child, the loader
keys lockfile lookup by **`(name, version)`** as a tuple rather than
by `name` alone. The lockfile MAY carry multiple `[module]` entries
with the same `name` differentiated by `version`:

```cx
[module
  name="github.com/example/regex-helpers"
  version="1.2.3"
  resolved="https://cdn.example.com/regex-helpers-1.2.3.zip"
  sri="sha384-..."]
[module
  name="github.com/example/regex-helpers"
  version="1.2.4-hotfix"
  resolved="https://cdn.example.com/regex-helpers-1.2.4-hotfix.zip"
  sri="sha384-..."]
```

When `[?lib]` omits the override, the loader matches on `name` alone
and selects the entry whose `version` field is absent (or, if every
matching entry has a `version`, raises `cx-err:CXER0211 E_LIB_UNPINNED`).

When `[?lib]` includes `[version 'X']`, the loader requires an
entry whose `version` matches `X` exactly; no fallback to the
unversioned entry.

### §4.4 `sri` — Subresource Integrity hash

For HTTPS-resolved modules, `sri` is **required**. Loaders MUST
reject any HTTPS `[module]` entry that lacks an `sri` field.

The format follows the W3C Subresource Integrity spec:

```
sri="<algo>-<base64-of-binary-digest>"
```

Required algorithms: `sha384`, `sha512`. Loaders MUST accept both
and MAY accept additional algorithms; producers SHOULD prefer
`sha384` for new entries (matches the npm / Deno convention and is
the cheapest secure default).

Worked examples:

```
sri="sha384-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
sri="sha512-aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789aBcDeFgHiJkLmNoPqRsTuVwXyZ"
```

The loader fetches the URL, computes the digest of the returned
bytes under the named algorithm, base64-encodes the result, and
compares byte-identically against the recorded SRI. Mismatch
raises `cx-err:CXER0209 E_LIB_INTEGRITY_MISMATCH` and the bytes
are **not** cached (so a poisoned cache cannot shadow a valid
fetch on retry).

File-path and bundled modules do **not** require `:sri`:

- **File-path** modules — the bytes live in the project's source
  tree and are protected by source-control hashes already.
- **Bundled** modules — the bytes are part of the CX binary,
  which carries its own integrity discipline (signing,
  reproducible builds).

A lockfile MAY carry an advisory `:sri` field on a non-HTTPS
entry; the loader treats it as informational and does not verify.

## §5. Loader behaviour by `:resolved` shape

| `:resolved` shape | Retrieval path | SRI verified | Cache key |
|---|---|---|---|
| `"./..."` / `"../..."` / `"/abs/..."` | filesystem read | no | n/a |
| `"https://..."` | HTTPS GET (TLS verify always on) | yes (`:sri`) | `(URL, SRI)` pair |
| `"bundled:<v>"` | extracted from CX binary | no | n/a |

The HTTPS cache key is `(URL, SRI)` rather than `URL` alone so a
stale-by-mismatch entry can't shadow a good one: if the SRI in
`cx.lock` is bumped, the new pair is a fresh cache miss and
triggers a new fetch.

TLS certificate verification is **always on** for HTTPS modules.
There is no flag to disable it, no plaintext-HTTP fallback, and
no `--insecure` override. A platform-specific mechanism for
declaring trusted root CAs may exist at the host-OS level but is
out of scope for this spec.

## §6. `[transitive-graph]`

The `[transitive-graph]` element is an optional, normative-record
encoding of the dependency edges between modules. It is **not**
consulted by the loader at resolution time (the loader recomputes
the graph from the parsed `[?lib]` directives during the recursive
fetch in [`code.md` §12.1.3](code.md)); it exists so that tooling — `cx lock`,
diff viewers, audit reports — can render the dependency graph
without re-running the loader.

```
[transitive-graph
  [edge from="cx-stdlib/json" to="cx-stdlib/strings"]
  [edge from="github.com/example/regex-helpers" to="cx-stdlib/strings"]]
```

Each `[edge]` is a directed reference `from=MODULE to=MODULE`
where both endpoints match the `:name` of some `[module]` entry
in the same lockfile.

A lockfile MAY omit `[transitive-graph]` entirely; the loader
behaviour is identical with or without it.

## §7. Worked example — full lockfile

```
[cx.lock version=1
  [modules
    [module
      name="cx-stdlib"
      resolved="bundled:0.8.0"]
    [module
      name="cx-stdlib/strings"
      resolved="bundled:0.8.0"]
    [module
      name="cx-stdlib/json"
      resolved="bundled:0.8.0"]
    [module
      name="github.com/example/regex-helpers"
      resolved="https://cdn.example.com/regex-helpers-1.2.3.zip"
      version="1.2.3"
      sri="sha384-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    [module
      name="./local-helpers.cx"
      resolved="./local-helpers.cx"]]
  [transitive-graph
    [edge from="github.com/example/regex-helpers" to="cx-stdlib/strings"]
    [edge from="./local-helpers.cx" to="cx-stdlib/strings"]]]
```

A program importing `cx-stdlib/strings`, `cx-stdlib/json`,
`github.com/example/regex-helpers`, and `./local-helpers.cx` would
resolve every direct and transitive dependency through the entries
above. The bundled stdlib modules are fetched from the CX binary;
the external library is fetched once (cache miss) over HTTPS and
hashed against the SRI; the local helper is read from disk.

## §8. Error codes

The lockfile interacts with module loading via the error codes
defined in [`code.md` §9.5](code.md). For convenience, the
codes most relevant to the lockfile read path:

| Wire code | Symbolic | When raised |
|---|---|---|
| `cx-err:CXER0208` | `E_LIB_INSECURE_TRANSPORT` | A `[?lib]` resolver uses `http://` (parse-time refusal; never reaches the lockfile) |
| `cx-err:CXER0209` | `E_LIB_INTEGRITY_MISMATCH` | HTTPS fetch bytes don't match the recorded `sri` |
| `cx-err:CXER0210` | `E_LIB_IMPORT_CYCLE` | Cyclic edge detected in the import graph at load time |
| `cx-err:CXER0211` | `E_LIB_UNPINNED` | A transitive dependency has no matching `cx.lock` entry |
| `cx-err:CXER0212` | `E_LIB_MALFORMED_LOCKFILE` | `cx.lock` itself fails to parse, carries an unknown `version`, or has structurally-invalid `[module]` / `[transitive-graph]` content (distinct from `code.md §9.5` `E_LIB_MALFORMED_DIRECTIVE` which governs `[?lib]` / `[?def]` / `[?const]` source-side parse errors) |
| `cx-err:CXER0213` | `E_LIB_UNRESOLVABLE` | `resolved` value does not match any known shape (`./`, `../`, `/`, `https://`, `bundled:`) |

## §9. Generation and updates

`cx.lock` is **generated** and **maintained** by tooling (the
`cx lock` CLI subcommand at minimum; future IDE / editor surfaces
may also write to it). The exact CLI surface is documented
separately.

Hand-editing `cx.lock` is not forbidden but is discouraged: the
loader treats the file as the source of truth for hashes, and a
malformed hand-edit that gets the `:sri` value wrong will fail
`cx-err:CXER0209` on the next load.

`cx.lock` MUST be committed to source control. CI MUST NOT
auto-regenerate it on every build — that would mask
supply-chain compromises (an attacker who replaces module bytes
upstream can also be the one who refreshes the lockfile). Lockfile
updates are deliberate, reviewed commits.

## §10. Future work

The following extensions are reserved for future revisions:

- **Bearer / Basic authentication** on `[?lib]` HTTPS fetches.
  Grammar reserves the attribute positions (see `grammar.ebnf`
  [151]); credential storage, rotation, and per-module scoping
  are currently out of scope.
- **`:vendor`** field on `[module]` entries — opt-in mirror-from-
  source-control behaviour where the lockfile records both a
  primary URL and a fallback location.
- **`cx lock --upgrade`** semantics consulting publisher metadata
  via `:version`.
- **Cross-language packages** — packages authored in one binding's
  source language consumed from another binding. Out of scope
  for the lockfile; the cross-binding contract is
  [`../misc/bindings.md`](../misc/bindings.md).
