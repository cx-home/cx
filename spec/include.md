# CX Include Resolution

**Version:** 1.0 (design — implementation pending) — 2026-05-08
**Status:** v0.6.0 (design committed in ;
V core impl + per-binding rollout pending)

CX's single inclusion mechanism is the `[?cx include=path.cx]`
processing-instruction-like directive (per
[`spec/grammar.ebnf §416`](grammar.ebnf), ).
This document is the user-facing spec for the directive's
resolution semantics: what paths resolve, what gets inlined, when
errors fire, and how the merged document interacts with namespaces
and IDs.

---

## 1. Syntax

```cx
[users
 [?cx include=lib/admins.cx]
 [user name=carol]
]
```

The directive appears at any position where a CX node may appear.
It is parsed as a `CXDirectiveNode` (per [`spec/ast.md`](ast.md)
§25); when include resolution is enabled at parse time, the node
is replaced in-place by the included document's element-level
content (§4 below).

The directive accepts a single attribute, `include`, whose value
is a path string. The grammar reserves a single attribute slot;
additional attributes on the directive are a parse error.

```cx
[?cx include=defaults.cx] # legal
[?cx include='lib/util.cx'] # legal — single-quoted path
[?cx include="config/prod.cx"] # legal — double-quoted path
[?cx include=foo.cx other=bar] # parse error — extra attribute
```

---

## 2. When resolution runs

Include resolution is **opt-in**. By default, `[?cx include=...]`
directives are preserved as `CXDirectiveNode`s in the parsed AST
and the parser does not open the referenced files.

A caller enables resolution by supplying an *include root* — an
absolute directory path against which include paths are validated.
With a root supplied, every directive resolves during the parse
pipeline.

### 2.1 CLI

```sh
$ cx --include-root=/proj main.cx
$ cx --json --include-root=. main.cx > resolved.json
```

The `--include-root` flag accepts an absolute path or `.` (the
current working directory, expanded to absolute at flag-parse
time). Without the flag, the CLI parses the input but does not
resolve includes.

### 2.2 C ABI

```c
char* cx_to_data_bin_with_include_root(
 const char* input,
 const char* include_root, /* NULL or "" disables resolution */
 char** err_out
);
```

Plus per-format variants (`cx_xml_to_data_bin_with_include_root`,
…) and a depth-options variant
(`cx_to_data_bin_with_include_options`). Capability bit allocated
at implementation time; bindings query `cx_features`.

### 2.3 Per-binding API

Each binding adds an optional `include_root` parameter to its
parse entry points. Conventional spelling per binding:

| binding | spelling |
| ------- | -------- |
| Python | `parse(text, include_root="/proj")` |
| Go | `Parse(text, cx.WithIncludeRoot("/proj"))` |
| Rust | `parse(text).with_include_root("/proj")?` |
| TypeScript | `parse(text, { includeRoot: "/proj" })` |
| Java | `Cx.parse(text, ParseOptions.builder().includeRoot("/proj").build())` |
| Kotlin | `parse(text, includeRoot = "/proj")` |
| Swift | `parse(text, includeRoot: "/proj")` |
| C# | `Cx.Parse(text, includeRoot: "/proj")` |
| Ruby | `parse(text, include_root: "/proj")` |

---

## 3. Path resolution

### 3.1 Relative paths only

Include paths are interpreted as **relative**. Absolute paths are
a parse error (`E901`):

```cx
[?cx include=/etc/passwd] # E901: absolute path rejected
[?cx include=C:\Windows\system.ini] # E901
[?cx include=\\server\share\foo.cx] # E901: UNC path
```

A relative path is resolved against the **directory of the file
containing the directive**, not against the include root. This
matches the relative-import model from ECMAScript modules and
Python.

For the **entry document** (the buffer or file the caller passed
to the parser), the "directory containing the directive" is the
include root itself.

### 3.2 No URL schemes

Any path containing `://`, or starting with `file:`, `http:`,
`https:`, `ftp:`, `gopher:`, or `data:`, is a parse error
(`E903`). CX's parser does not perform network I/O and does not
resolve URL-shaped paths even if the include root happens to look
like a URL prefix.

### 3.3 Traversal check

After lexically resolving `..` segments and joining against the
including file's directory, the resulting path must lie under the
include root. A path that escapes the root is a parse error
(`E902`):

```
include_root: /proj
file: /proj/lib/util.cx
directive: [?cx include=../../etc/secrets.cx]
resolved: /etc/secrets.cx ← outside /proj, rejected
```

The check is lexical (collapse `..` segments before comparing).
Symlinks are followed when the file is opened; a symlink whose
target lies outside the include root is rejected by the same rule
applied to the resolved (post-symlink) path.

### 3.4 Path-separator portability

Inside the directive, `/` is the path separator regardless of host
platform. The host's native separator is used only when opening
the resolved file. A directive with `\` as a separator on POSIX
hosts is interpreted literally (the `\` is part of the filename),
which is almost certainly an authoring mistake; the parser does
not auto-translate.

```cx
[?cx include=lib/util.cx] # works on Linux, macOS, Windows
[?cx include=lib\util.cx] # broken on POSIX (treats \u as escape)
```

---

## 4. What gets inlined

When `[?cx include=path]` resolves to a parsed CX document *D*,
the directive node is replaced in the parent AST by *D*'s
element-level children, in source order. Specifically:

- **Inlined:** `Element`, `Comment`, `PI`, `RawText`, `Scalar`,
 `Text`, `BlockContent`, `AliasElement`, `EntityRef` at *D*'s
 top level.
- **Not inlined:** `XMLDecl`, `DoctypeDecl`, and any other
 `CXDirectiveNode` at *D*'s top level. These are valid in *D*'s
 own standalone parse but are discarded at splice time.
- **Discarded:** the `[?cx include=...]` directive node itself.

Position in the parent is preserved: every inlined node takes the
position of the consumed directive. Document order is preserved
across the splice boundary.

### 4.1 Splicing multiple top-level children

A document with several top-level children inlines all of them at
the directive site:

```cx
# defaults.cx:
[server host=localhost]
[server host=backup]
[client timeout=30]

# main.cx:
[config
 [?cx include=defaults.cx]
 [client retries=3]
]

# After resolution, main.cx parses as:
[config
 [server host=localhost]
 [server host=backup]
 [client timeout=30]
 [client retries=3]
]
```

### 4.2 Empty / whitespace-only includes

A file with no element-level children inlines as nothing — the
directive site simply disappears from the parent AST. A file with
only comments is treated identically to a file with comments only,
which means the comments do inline (per §4 list), but if the file
has only whitespace, nothing inlines.

---

## 5. Resolution timing

Include resolution runs as a distinct pass between parsing and the
existing namespace / ID resolution passes:

1. **Parse** the entry document into an unresolved AST.
2. **Include-resolve** the AST (recursively, per §6 and §7).
3. **Namespace-resolve** per [`spec/namespaces.md`](namespaces.md).
4. **ID-resolve** per [`spec/identity.md`](identity.md).

This means an included file's namespace declarations and ID
declarations are applied *as if they had been authored inline at
the directive site*. The included file's `xmlns:foo=...` is in
scope only for its content (its declarations come along on the
inlined elements). Its `#u-1` joins the parent's ID space; a
duplicate across the include boundary is a parse error per
 D3.

---

## 6. Cycle detection

The parser maintains an *include stack* during resolution: an
ordered list of canonicalized absolute paths of files currently
being expanded. A directive whose resolved path is already on the
stack is a parse error (`E904`).

A self-include is the simplest cycle:

```cx
# loop.cx:
[?cx include=loop.cx] # E904: include cycle (loop.cx → loop.cx)
```

A diamond include is **legal** — both `B` and `C` inlining the
same `D` is fine, because `D` is not on the stack at either
inlining site (it was popped between):

```
A
├── B
│ └── D ← legal
└── C
 └── D ← also legal
```

The error message lists the cycle from the first stack occurrence
to the current top.

---

## 7. Depth limit

Include-stack depth is bounded by `max_include_depth`, defaulting
to **8**. A depth-9 include is a parse error (`E905`). The limit
is configurable via the same per-call options that expose
`max_depth` (element nesting) and the allocation cap.

The element-nesting limit (`max_depth`, default 64 per
[`spec/policies.md §5.4`](policies.md)) and the include-depth
limit are independent — the two multiply rather than add.

---

## 8. Errors

| code | meaning |
| ---- | ------- |
| `E901` | Absolute include path rejected |
| `E902` | Include path escapes the include root |
| `E903` | URL-shaped include path rejected |
| `E904` | Include cycle detected |
| `E905` | `max_include_depth` exceeded |
| `E906` | Included file does not exist |
| `E907` | Included file not readable (permissions) |
| `E908` | Include path resolves to a directory, not a regular file |
| `E909` | I/O error during include read |
| `E910` | Included file is not valid UTF-8 |
| `E911` | Included file fails its own parse |

Errors `E910` and `E911` carry both the included-file location
(line / column inside the included file) and the directive site
that opened it, joined by an `included from …` chain (per
 D7):

```
parse error: unexpected '}' at /proj/lib/util.cx line 12 col 8
 included from /proj/main.cx line 4 col 1: [?cx include=lib/util.cx]
```

---

## 9. Conversion across formats

| Format | Behavior |
| ------ | -------- |
| CX → CX (round-trip, resolution disabled) | Directives preserved as `[?cx include=...]` |
| CX → CX (round-trip, resolution enabled) | Directives consumed; included content inlined |
| CX → XML (resolution disabled) | Directives emit as `<?cx include="..."?>` PI |
| CX → XML (resolution enabled) | Directives consumed; included content emitted inline as XML |
| XML → CX | `<?cx include="..."?>` PI parses as `CXDirectiveNode`; resolution applies if enabled |
| CX → JSON / YAML / TOML / MD | Same posture as XML — directives preserved when disabled, consumed when enabled |

The lossless round-trip story is therefore: **with resolution
disabled, CX → any format → CX preserves directives byte-for-byte;
with resolution enabled, the round-trip is across the resolved
document, not the source.** Adopters who need the resolved form
opt in; adopters who need the unresolved form (e.g., a refactoring
tool that operates on the directive structure) leave the default.

---

## 10. Examples

### 10.1 Modular config

```cx
# defaults.cx:
[server
 host=localhost
 port:u16 8080
 +tls
]

[client
 timeout:u32 30
 retries:u8 3
]

# overrides.cx:
[server port:u16 8443]

# main.cx:
[config
 [?cx include=defaults.cx]
 [?cx include=overrides.cx]
]
```

After resolution against `--include-root=.`, `main.cx` parses
as:

```cx
[config
 [server host=localhost port:u16 8080 +tls]
 [client timeout:u32 30 retries:u8 3]
 [server port:u16 8443]
]
```

(Merging the two `[server ...]` sub-trees is the application's
responsibility; CX's include resolution is purely structural —
it splices nodes, it does not deep-merge.)

### 10.2 Modular document with cross-file ID refs

```cx
# glossary.cx:
[term #t-rest definition='Representational State Transfer']
[term #t-rpc definition='Remote Procedure Call']

# article.cx:
[doc
 [?cx include=glossary.cx]
 [para
 APIs broadly fall into two families: [ref @t-rest]-style and
 [ref @t-rpc]-style.
 ]
]
```

After resolution, the references `@t-rest` and `@t-rpc` resolve
against the merged document's ID table — exactly as if the
glossary terms had been authored inline. Per
 D3.

### 10.3 Cycle (parse error)

```cx
# a.cx: [?cx include=b.cx]
# b.cx: [?cx include=a.cx]
```

```
$ cx --include-root=. a.cx
parse error E904: include cycle detected
 at /proj/a.cx line 1 col 1: [?cx include=b.cx]
 at /proj/b.cx line 1 col 1: [?cx include=a.cx]
 (a.cx is already on the include stack)
```

### 10.4 Traversal (parse error)

```cx
# /proj/lib/util.cx:
[?cx include=../../etc/secrets.cx]
```

```
$ cx --include-root=/proj /proj/main.cx
parse error E902: include path escapes include root
 at /proj/lib/util.cx line 1 col 1: [?cx include=../../etc/secrets.cx]
 resolved to: /etc/secrets.cx
 include root: /proj
```

---

## 11. Implementation contract

The implementation phase delivers:

- A new V core pass `resolve_includes(doc, root, max_depth)` that
 walks the AST, replaces `CXDirectiveNode{include=...}` nodes
 with the inlined content per §4, and applies the cycle / depth /
 traversal / URL checks of §3, §6, §7.
- New C ABI entry points (`cx_to_data_bin_with_include_root`,
 `cx_xml_to_data_bin_with_include_root`, …) at a newly-allocated
 capability bit, plus a depth-options variant
 (`cx_to_data_bin_with_include_options`).
- A `--include-root` CLI flag on every parse-accepting subcommand.
- Per-binding wrappers that thread an optional `include_root`
 parameter through their parse entry points (§2.3).
- Conformance fixtures at `conformance/include.txt` covering each
 decision and error code, including XML round-trip.
- Test harnesses per binding mirroring the V conformance suite.

The merged AST after include resolution is indistinguishable from
the AST of an equivalent inline-authored document. Specifically,
`cx_text_canonical(resolve(A)) == cx_text_canonical(B)` whenever
*B* is the inline-equivalent of *A*'s resolved form. This is the
property that lets adopters refactor between single-file and
multi-file CX without changing downstream behavior.

---

## 12. References

- — design
 decisions and rationale.
- [`spec/grammar.ebnf §416`](grammar.ebnf) — directive grammar.
- [`spec/ast.md`](ast.md) — `CXDirectiveNode` AST shape.
- [`spec/identity.md §2.1`](identity.md) — ID-merging contract
 enabled by include resolution.
- [`spec/namespaces.md`](namespaces.md) — namespace scoping over
 the merged AST.
- [`spec/policies.md`](policies.md) — BOM / line-ending /
 recursion-depth / allocation policies that apply identically to
 included files.
- [`spec/threat_model.md §4 T3`](threat_model.md) — confused-
 deputy threat that this feature's API and checks mitigate.
- —
 external entities are deliberate non-features; this is the
 alternative path.
- W3C XInclude 1.0 — XML's analogous mechanism. CX rejects its
 URL-fetching surface.
