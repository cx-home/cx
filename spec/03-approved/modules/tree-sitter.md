# `tree-sitter:` module — polyglot AST parsing

**Status:** Current

Normative reference for the `tree-sitter:` external-system module. Wraps `libtree-sitter` plus a bundled grammar set, exposing parse trees as CX values for downstream CXPath / `[?match]` / `[?modify]` composition.

---

## §1. Module metadata

| Field | Value |
|---|---|
| `ns_prefix` | `tree-sitter` |
| External C library | `libtree-sitter` (vendored) plus per-language grammars |
| `activation` | `[?lib 'tree-sitter']` |
| Default purity | `pure` |
| Error block | `CXER4300..CXER4309` (§8) |

Tree-sitter is a deterministic parser: same source plus same grammar yields the same parse tree. No filesystem, network, clock, or RNG. All functions in §2 except `tree-sitter:load-grammar` are `pure`.

## §2. Function surface

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `tree-sitter:parse` | `($language::string $source::string)` | `ts-tree` | pure |
| `tree-sitter:parse-to-cx` | `($language::string $source::string)` | `any` (AST as CX nodes) | pure |
| `tree-sitter:root` | `($tree::ts-tree)` | `ts-node` | pure |
| `tree-sitter:children` | `($node::ts-node)` | `[sequence ts-node]` | pure |
| `tree-sitter:kind` | `($node::ts-node)` | `string` | pure |
| `tree-sitter:text` | `($node::ts-node)` | `string` | pure |
| `tree-sitter:range` | `($node::ts-node)` | `map` (start/end line, column, byte) | pure |
| `tree-sitter:field` | `($node::ts-node $field-name::string)` | `ts-node` or nil | pure |
| `tree-sitter:query` | `($language::string $query::string $tree::ts-tree)` | `[sequence map]` (matches) | pure |
| `tree-sitter:languages` | `()` | `[sequence string]` | pure |
| `tree-sitter:load-grammar` | `($name::string $library-path::string)` | nil | impure |

`parse` returns an opaque handle for cursor-style walking (`root`/`children`/`kind`/...). `parse-to-cx` materialises the entire tree as CX elements:

```
[program
  [function-definition name="greet"
    [parameters [identifier "name"]]
    [body [string-literal "hello"]]]]
```

Once the source is CX, CXPath / `[?match]` / `[?modify]` / schema validation / `cx:hash` apply uniformly.

`tree-sitter:query` uses tree-sitter's S-expression query language. Each match in the return sequence has shape:

```
{"captures": {"name": [{"node": $n, "text": "...", "range": {...}}, ...]}}
```

`tree-sitter:load-grammar` is `impure` (opens a `.so` from a runtime path). The purity classifier per [`spec/core/code.md`](../core/code.md) §6.5.x refuses it from any `pure` `[?def]` body (raises `CXER0233`).

---

## §3. Grammar registry

The current release ships a fixed set of compiled grammars:

| Language | Grammar source |
|---|---|
| `sql` | `tree-sitter-sql` |
| `python` | `tree-sitter-python` |

Loading additional grammars at runtime:

```
[?lib 'tree-sitter']
[tree-sitter:load-grammar "rust" "/path/to/libtree-sitter-rust.so"]
[?def $tree [tree-sitter:parse-to-cx "rust" $source]]
```

Loaded grammars persist for the process lifetime. The loader refuses to load a grammar from a path outside the resolution set established by [`spec/core/code.md`](../core/code.md) §12.1.

---

## §4. AST mapping (tree-sitter → CX)

`parse-to-cx` follows these rules:

1. **Node kind → element name.** A tree-sitter node with kind `function_definition` becomes a CX element named `function-definition` (snake_case → kebab-case per CX naming convention).
2. **Named fields → attributes.** Tree-sitter named fields become CX attributes carrying child node text for scalar fields or CX subtrees for compound fields.
3. **Anonymous children → element children.** Children without a field name appear as positional child elements.
4. **Leaf nodes → text content.** Leaf nodes carry their source text as the element's primary content.
5. **Source ranges → `loc` attribute.** Every emitted element carries `loc=...` recording start/end line / column / byte. Strippable via `[?cx tree-sitter-strip-loc]`.

Per-grammar mapping detail is mechanical from the grammar's `node-types.json`; advanced users inspect the mapping via `tree-sitter:kind` plus `tree-sitter:field` on the raw `ts-tree`.

---

## §5. Threat model

- **Source-size DoS.** Parsing a 1 GB input is 1 GB of work (O(n) typical, O(n²) pathological). Applications validate source length before passing to `parse`.
- **Pathological grammars.** Custom grammars loaded via `load-grammar` are trusted code; a malicious or buggy grammar can cause infinite loops inside the parser.
- **Grammar ABI version drift.** A grammar compiled against one libtree-sitter ABI may fail against another. Bundled grammars are versioned with their host library; external grammars are caller's responsibility.

See [`spec/process/threat-model.md`](../process/threat-model.md) for the document-level threat model.

---

## §6. Composition

`parse-to-cx` output composes with `cx:hash` for content-addressed source-tree caching, with `[?match]` for pattern-based rewriting, and with `sqlite:` for storing AST analyses in a queryable database.

```
[?lib 'tree-sitter']
[?lib 'cx:io']
[?const $py-tree [tree-sitter:parse-to-cx "python" [io:read-file "app.py"]]]
[?for [in $call [?= //call[= $_@function "execute"]]]
  [yield [?= ./arguments/string-literal/@text]]]
```

Tree-sitter consumes raw source-code text (a string), not a CX
document. `[?cx include=…]` is the **CX-document** inclusion directive
([`core/code.md §13`](../core/code.md)) and is not appropriate for
loading arbitrary file bytes; use `[io:read-file …]` from
[`std-lib/io.md`](../std-lib/io.md) when the source is a file path,
or pass the literal source string inline.

---

## §7. Conformance

Fixtures live at `conformance/module_tree_sitter.txt`. Categories:

1. SQL parse round-trip — sample SQL strings parse and produce the documented CX AST shape; `parse-to-cx` round-trips through `cx:canonical` byte-identically per [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md).
2. Python parse round-trip — same shape with Python grammars.
3. Query — `tree-sitter:query` with sample S-expression queries returns expected match sequences.
4. CXPath composition — `parse-to-cx` plus `[?= //function-definition/@name]` produces expected node lists (verifies AST mapping fidelity).
5. `load-grammar` refusal from a `pure` `[?def]` body — raises `CXER0233` per [`spec/core/code.md`](../core/code.md) §6.5.x.
6. Error paths — each code in §8 produced by at least one fixture.

---

## §8. Error codes

`tree-sitter:` claims `CXER4300..CXER4309`:

| Code | Description |
|---|---|
| `CXER4300` | Language not loaded (use `tree-sitter:languages` to list available) |
| `CXER4301` | Parse failure (tree contains ERROR nodes; raised only when `strict=true`) |
| `CXER4302` | Query syntax error (malformed S-expression) |
| `CXER4303` | Grammar load failure (filesystem error, ABI mismatch, version skew) |

`CXER4304..CXER4309` reserved.

`CXER4301` is opt-in: by default `parse` / `parse-to-cx` return a tree that may contain ERROR nodes (tree-sitter's error-recovery parsing); applications that want hard-failure pass `strict=true`.

---

## §9. Cross-references

- [`spec/core/code.md`](../core/code.md) §12.1 — `[?lib]` module loading.
- [`spec/core/code.md`](../core/code.md) §6.5.x — purity classification.
- [`spec/core/ast.md`](../core/ast.md) — CX AST shape that parsed trees map onto.
- [`spec/modules/sqlite.md`](sqlite.md) — sibling module commonly composed with tree-sitter for AST analytics.
- [`spec/process/threat-model.md`](../process/threat-model.md) — document threat model.
