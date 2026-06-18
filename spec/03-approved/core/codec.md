# CX Codec API — format ⇄ tree, one model everywhere

**Status:** Current for v0.8.0. Graduated 2026-06-06 (G3).

This document specifies *how* a conversion between a serialization format and CX
is invoked, and the contract every format implementation satisfies. It is the
API/layering companion to `conversions.md`, which fixes the *semantics* of each
format pairing (what survives a round-trip, what is lossy). Design rationale and
the phased rollout live in `spec/02-inprogress/codec_architecture.md`.

> **Markdown distinction (ruling D-B, refined).** CX has **no markdown syntax** —
> the `[** ]`/`[# ]`/`` [`] ``/`[> ]` sigils remain removed, and a `[#…#]` block is
> opaque raw text. What exists is a markdown **codec**: a `bytes ⇄ CX tree`
> converter, exactly like the json/csv/xml codecs. A codec is not a surface; no
> markdown is admitted into the CX program/data grammar.

---

## §1 — Principle: the CX tree is the universal pivot

CX is homoiconic — every document, in any surface, is one CX node tree. A
conversion is therefore **always** `format → tree → format`, never
`format → format`. The tree is the only interchange:

```
   bytes ──parse──▶ CX tree ──(transform*)──▶ CX tree ──emit──▶ bytes
```

A new format is added as **one codec**; it then converts to and from every other
format for free. There is no per-pair conversion code anywhere in CX.

## §2 — Three orthogonal axes

A conversion composes three independent concerns. Implementations MUST keep them
separate:

| Axis | Job | Where | Effect class |
|---|---|---|---|
| **Transport** | read/write bytes | `cx-stdlib/io`, `cx-stdlib/http` | **effectful** — capability-gated |
| **Codec** | bytes ⇄ CX tree | the per-format codec modules (§3) | **pure** — never gated (§5) |
| **Transform** | tree → tree | the CX program (CXPath, `[?match]`, `[?modify]`) | per the program |

A full conversion is the pipeline
`transport-in → codec.parse → transform* → codec.emit → transport-out`.

## §3 — The codec contract

Every codec exposes the **same interface** under its module prefix
(`cx-stdlib/<codec>`). Reading bytes as text uses the text entry points; binary
formats and binary-safe paths use the `-bytes` entry points.

**Mandatory:**
```
[$<codec>:parse        STRING]   → tree
[$<codec>:parse-bytes  BYTES]    → tree
[$<codec>:emit         TREE]     → string
[$<codec>:emit-bytes   TREE]     → bytes
```

**Optional — provided only where the format warrants it, and named uniformly:**
```
[$<codec>:emit-pretty    TREE]          # a distinct human-readable variant
[$<codec>:parse-with-opts SRC OPTS]     # dialect / policy (csv dialect, url whatwg, html sanitize)
[$<codec>:emit-with-opts  TREE OPTS]
[$<codec>:parse-stream    SRC …]        # only where the format is streamable
[$<codec>:emit-stream     EVENTS …]     #   (json, csv, cxcol; not md/toml/yaml)
```

`emit` is the **canonical writer name** for every codec. Where a codec
historically used another name, that name is retained as an **alias** of `emit`
(e.g. `html:serialize`, `url:build` alias `html:emit`, `url:emit`).

### §3.1 — Invariants

1. **Bounded loss.** `parse` then `emit` loses no more than the codec's row in
   `conversions.md`. A codec MUST NOT introduce loss that table does not admit.
2. **Idempotent pivot.** `parse` of a codec's own `emit` output reproduces the
   tree (`parse(emit(t)) ≡ t` up to documented normalization).
3. **Purity.** `parse`/`emit` are total `bytes ⇄ tree` transforms with no
   transport, clock, or randomness (§5).

With the contract, conversion `X→Y` is **universally**:
```
[$<Y>:emit [$<X>:parse $src]]
```

## §4 — Codec coverage

| Codec | Mandatory | Notable optional |
|---|---|---|
| `cx` | ✅ | the pivot; `emit` = canonical form |
| `json` | ✅ | `emit-pretty`, `parse-stream`/`emit-stream`, `parse-with-opts` |
| `csv` | ✅ | `parse-with-opts`/`emit-with-opts` — **also subsumes TSV/PSV as dialects**, not separate codecs |
| `xml` | ✅ | `emit-with-opts` (lossless `<cx:T>` typing) |
| `yaml` | ✅ | — |
| `toml` | ✅ | — |
| `markdown` | ✅ | — (codec only; no markdown syntax — see header) |
| `html` | ✅ | `sanitize`/`extract-text`; `serialize` aliases `emit` |
| `url` | ✅ | `query-parse`/`query-encode`; `build` aliases `emit` |
| `ast` / `cxcol` / `data-bin` | `parse-bytes`/`emit-bytes` only | binary codecs — **no text `emit`**; registered for uniform discovery |

## §5 — Purity and capabilities

Codecs are classified **pure** (`purity_checker.v`): `[$json:parse $literal]` is
usable inside `[?modify]`, comprehensions, and any pure context, and charges no
capability. Only **transport** is effectful — `[$io:read-file]` (cap `io`),
`[$http:get]` (cap `net`), `[$io:write-file]` (cap `io`). Reading the bytes costs
a capability; parsing them does not.

## §6 — One source of truth: the codec registry

Each codec has exactly one underlying implementation. A single registry keys
format name → `{parse, parse_bytes, emit, emit_bytes, …}`, and **all three layers
route through it**:

- a CX module `[$<codec>:parse]` is a thin wrapper over the registry entry;
- the CLI `--from=X --to=Y` is a registry lookup + compose (`parse` then `emit`),
  not a hand-maintained per-pair branch;
- the ABI / language bindings expose the registry, not bespoke `cx_X_to_Y`
  functions.

No format may have a second, parallel conversion implementation.

## §7 — `[$convert]` — sugar over the registry

A single one-shot convenience, defined as composition over the registry (never a
parallel implementation):

```
[$convert SRC :from <codec> :to <codec>]   ≡   [$<to>:emit [$<from>:parse SRC]]
```

`:from`/`:to` take **atom** codec names (the v0.8.0 idiom for closed
enumerations). The compositional `[$<Y>:emit [$<X>:parse …]]` form remains the
primitive; `[$convert]` is for the common case and is where a `transform*` step is
omitted.

> **Parse-result shape.** `[$<codec>:parse]` returns the source document's
> top-level node(s). When a document has more than one top-level node (e.g. a
> leading comment plus a root element), the result is a **sequence**, not a single
> element — navigate it with the **descendant axis** (`$doc//elem`,
> `$doc//elem/@attr`). A direct child or attribute step on the sequence
> (`$doc/@attr`) raises `CXER0001` ("attribute path step on non-element value").
> The namespaced `[$<codec>:parse]` is canonical; the flat-dispatch alias
> `[$<codec>-parse]` is also accepted.

## §8 — Worked examples

```cx
# file → tree → json, on disk
[?lib 'cx-stdlib/io'] [?lib 'cx-stdlib/csv'] [?lib 'cx-stdlib/json']
[?let [= $tree [$csv:parse [$io:read-file 'in.csv']]]
  [$io:write-file 'out.json' [$json:emit $tree]]]

# one source → many formats (parse once, emit N)
[?let [= $tree [$json:parse [$http:body-bytes [$http:get $url]]]]
  [out [$json:emit-pretty $tree] [$csv:emit $tree]]]

# glob: convert every CSV in a directory
[?for [in $f [$io:glob 'data/*.csv']]
  [$io:write-file [$path:with-extension $f 'json']
    [$json:emit [$csv:parse [$io:read-file $f]]]]]

# the sugar
[$convert [$io:read-file 'doc.md'] :from markdown :to xml]

# parse a CX document, then navigate it — note the descendant axis `//` (§7):
# the parse result is a sequence, so a direct `$doc/@name` would raise CXER0001.
[?let [= $doc [$cx:parse [$io:read-file 'feature.cxd']]]
  [$doc//feature/@name]]
```
