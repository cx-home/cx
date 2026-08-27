# Reference: the CX standard library — v0.17.0

> **GENERATED.** Source: `docs-src/llm/reference-stdlib.md.tmpl` + the module
> sources and the conformance corpus. The catalogs below are projected from
> each module's own `[module-doc]`, so a bundled module cannot be missing
> from this page. Read `primer.md` first.

## Importing

`[?lib 'cx-stdlib/strings']` binds the module under its own name.
`[?lib 'cx-stdlib/strings' as=str]` renames it. `[?lib 'cx-x/tools' as=tools]`
imports from the experimental tier, and says so in the import line.

Three import prefixes:

* **`cx-stdlib/…`** — the frozen standard set. Stable surface.
* **`cx-x/…`** — experimental. Bundled and conformance-gated, but exempt from
  the stability promise. If you are writing code meant to last, prefer the
  standard tier.
* **`cx-xap`** — the XAP orchestrator, imported as a whole package
  (`[?lib 'cx-xap' :as xap]`), **not** as `cx-stdlib/xap`. It layers *above*
  the standard library and adds no authority, transport, or markup logic of
  its own. It appears in the standard-tier table below because it is bundled
  from the same directory; its import line is the exception.

A call is `[$module:fn args…]`. The `$` is not optional stylistically — it is
the assertion that this is a call rather than an element you are building
(see the anti-patterns in `primer.md`).

`prog.cx`
```cx
[?lib 'cx-stdlib/math' as=m]
[$m:abs -7]
```

```console
$ cx prog.cx
7
```

## Standard tier — `cx-stdlib/<name>`

| Module | Scope |
|---|---|
| `authz` | The XAP authority model as data plus a single decision function. |
| `bus` | In-process publish/subscribe that delivers each published message to its matching subscribers synchronously and in a defined order. |
| `bytes` | Byte-level operations on the CX bytes scalar kind. |
| `crypto` | Operations involving a key, a secret, or authentication. |
| `csv` | Parse and emit CSV/TSV following RFC 4180 with Excel-pragmatic extensions. |
| `diagram` | The §10.1.2 reference diagram renderer as a pure CX program (RULED #758, DR-1…DR-11). |
| `did` | Decentralized identifiers (DIDs): the decentralized identity source that identifies a principal, counterpart to crypto's centralized JWT/JWKS. |
| `email` | Parse and build RFC 5322 + MIME multipart email messages. |
| `env` | Expose process-level metadata to CX code: environment variables, command-line arguments, and process identity. |
| `fabric` | Platform-level eventing over the shipped primitives: one subscribe/emit surface with an explicit durability axis. |
| `format` | Emit CX values back to CX text in four forms: canonical, pretty, compact, and diff-friendly. |
| `fp` | Functional composition over the four value channels. |
| `ft` | In-program fulltext search with structured ranking and snippet generation. |
| `geo` | Coordinate primitives without a new scalar kind — geometries are ordinary CXDM elements. |
| `hash` | Content-addressable hashing — fixed-length digests of arbitrary byte payloads. |
| `html` | HTML as a first-class document format: parse, sanitize, serialize, and extract text. |
| `http` | HTTP/1.1 request/response semantics: a programmatic client and server built on the `cx-stdlib/net` transport. |
| `i18n` | The message and translation layer of CX's internationalization surface. |
| `io` | File and stream I/O — whole-file reads and writes, streaming handles, line iteration, filesystem queries, directory operations, globbing, tempfiles, and advisory file locking. |
| `journal` | An append-only, hash-chained, tenant-partitioned event log and the deterministic projection of that log into state. |
| `json` | Parse JSON (RFC 8259) into CXDM values and emit CXDM values back to JSON. |
| `live` | The live modes over the one planar comprehension: the same quoted `[?for]` that runs once as a query is also a delta feed. |
| `locale` | The primitives layer of CX's internationalization surface. |
| `log` | Structured logging: leveled emit with arbitrary structured fields. |
| `math` | Numeric utilities over CX int and float scalar kinds. |
| `mime` | MIME data-shape handling: a built-in extension-to-type registry, Content-Type and Content-Disposition parsing, multipart boundary generation, type classification, and Accept-header content negotiation. |
| `net` | Transport-level (L4) networking: opening and accepting stream connections (TCP, Unix-stream, TLS), exchanging datagrams (UDP, Unix-datagram, DTLS), name resolution, and TLS upgrade or termination. |
| `path` | Filesystem path manipulation — splitting, joining, normalizing, and comparing OS paths. |
| `process` | Run child processes: spawn them, capture their output, stream their stdio, connect them into pipelines, deliver signals, manage process groups, and drive pseudo-terminals. |
| `prof` | In-program profiling, callable directly from CX code. |
| `random` | Two distinct randomness facilities, kept cleanly separated so PRNG output can never accidentally stand in for crypto. |
| `re` | Regular expressions backed by the RE2 engine, guaranteeing linear-time matching against any input with no catastrophic backtracking. |
| `sched` | Scheduled events and timers on the event loop. |
| `session` | The server-held (principal, tenant) session for a web app. |
| `similar` | Graded comparison as a generalization of exact equality: where = returns a boolean, the core ~ operator returns a score in [0,1] plus evidence, and a decision policy maps the score to :match / :review / :no-match bands. |
| `store` | A content-addressed object store with URL-dispatched backends. |
| `strings` | String inspection, search, and transformation for general text work. |
| `supervise` | Restart policies over monitored workers: run a set of named children (each an arity-0 callable spawned as a worker) under a declared policy — strategy (:one-for-one, :one-for-all, :rest-for-one), restart intensity (max-restarts within a window), and per-child exponential backoff — restarting them when they die according to each child's restart type (:permanent, :transient, :temporary). |
| `test` | Authoring primitives for unit-test-style programs written in CX: assertions, fixtures, lifecycle hooks, and structured reporting. |
| `time` | Dates, datetimes, durations, and instants, with wall-clock and monotonic time sources. |
| `url` | RFC 3986 and WHATWG-URL-aligned URL parsing, building, and component encoding. |
| `uuid` | Generate, parse, format, and validate Universally Unique Identifiers. |
| `validate` | Validate a CX data record against a record-schema at runtime, in the    JSON-Schema / pydantic style. |
| `vc` | Verifiable credentials: portable, signed, attenuating delegations that carry authority between DIDs and verify offline (the §22.2 delegation transport, counterpart to `did` for identity). |
| `xap` | The XAP orchestrator — the experience layer at the top of the CX web    stack. |
| `xsp` | The XAP Stream Protocol frame codec — a self-describing, self-delimiting frame [version · type · stream-id · principal-DID · flags · len · payload] that carries XAP over any transport. |

## Experimental tier — `cx-x/<name>`

| Module | Scope |
|---|---|
| `a2a-xap` | A2A tasks over the xap substrate (EXPERIMENTAL x/ tier, #6 Y2b). |
| `a2a` | A minimal A2A (Agent-to-Agent) protocol client (EXPERIMENTAL x/ tier, #6    Y2) — completing the agentic triad (S9 MCP client, Y1 MCP server, Y2 A2A) on the    shared substrate (jsonrpc + http + json), no new transport. |
| `adjudicate` | Out-of-band agent adjudicator for the similar review band (EXPERIMENTAL    x/ tier; cx-private #376, similar.md §5.3 ruling Q4). |
| `llm` | A minimal LLM provider (EXPERIMENTAL x/ tier, #6 D2/S10) — the first    Runnable. |
| `mcp-server` | Minimal MCP server helpers (EXPERIMENTAL x/ tier, #6 Y1; stream 18) — the    server counterpart to cx-x/mcp, at the 2025-06-18 protocol revision (one    target). |
| `mcp` | A minimal MCP (Model Context Protocol) client (EXPERIMENTAL x/ tier, #6    S9). |
| `run` | The Runnable convention + combinator library (EXPERIMENTAL x/ tier, #6    D2/M2). |
| `term` | Native raw-mode terminal input for interactive TUIs (EXPERIMENTAL x/    tier, #30). |
| `tools` | The agent-tool projection (EXPERIMENTAL x/ tier; stream 18): ONE    tool-descriptor model derived from command definitions ([effects]-bearing    [?def]s — clause presence is the discriminator) at list time, no    materialized manifest. |
| `ux-tui` | The TERMINAL RENDERER of the UX projection (EXPERIMENTAL x/ tier;    #787 W5): the second of two peers over `cx-x/ux`'s semantic vocabulary, and    the reason R5's renderer-agnostic claim is testable rather than asserted. |
| `ux-web` | The WEB RENDERER of the UX projection (EXPERIMENTAL x/ tier;    #787): one of two peers over `cx-x/ux`'s semantic vocabulary, not the    privileged one. |
| `ux` | The SEMANTIC CORE of the UX projection (EXPERIMENTAL x/ tier;    #787): the vocabulary, the fragment addressing, the validation, the three    projections (command→form, query→table, feature-grammar→form/columns), the    hint claims, the patch algebra a live feed lowers onto, and the surface    document's routing correspondence. |

## The packs that need a capability

Pure modules (`strings`, `math`, `map`, `array`, `fp`, `json`, `re`, `path`,
`format`, `bytes`, `url`, `mime`, …) need no grant. The effectful ones name
their capability at the point of the effect, so you discover the requirement
by running rather than by reading:

| Pack | Capability | Grant |
|---|---|---|
| `io` (files, dirs) | read / write | `--allow-read`, `--allow-write` |
| `net`, `http` | net | `--allow-net[=host[:port]]` |
| `env` (`var`, `vars`) | env | `--allow-env` |
| `time` (now, clocks) | clock | `--allow-clock` |
| `random`, `uuid` | random | `--allow-random` |
| `process` | subprocess | `--allow-subprocess` |
| `cx` (`[?eval]`) | eval | `--allow-eval` |
| secret declassification | secret-reveal | `--allow-all` |

`env:argv` and `env:parse-args` are **ungated** — reading your own arguments
is not an effect.

`prog.cx`
```cx
[?lib 'cx-stdlib/env']
[$env:var "CX_DEFINITELY_UNSET_VAR_XYZ_001"]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0271 message='E_CAP_DENIED: env capability required for env-var; none granted (grant via --allow-env)']
```

## The modules worth knowing first

### `strings` — UTF-8, codepoint-positioned

`prog.cx`
```cx
[?lib 'cx-stdlib/strings']
[$strings:length "héllo"]
```

```console
$ cx prog.cx
5
```

Indexing, length, and slicing count codepoints, and case folding follows the
Unicode tables — so this is not the answer a byte-oriented library gives:

`prog.cx`
```cx
[?lib 'cx-stdlib/strings']
[$strings:upper "straße"]
```

```console
$ cx prog.cx
'STRASSE'
```

For byte-level work use `bytes`; for patterns use `re`.

### `re` — RE2, and what that excludes

`re` is RE2-backed: linear time, no backtracking, and therefore **no
lookaround and no backreferences**. Those are refused at compile time, not
silently mis-executed — which matters when you are porting a PCRE pattern.

`prog.cx`
```cx
[?lib 'cx-stdlib/re']
[$re:compile "(.)\\1"]
```

```console
$ cx prog.cx
[err code=cx-err:CXER3200 message='E_RE_FEATURE_UNSUPPORTED: CXER3200:E_RE_FEATURE_UNSUPPORTED: (.)\1']
```

`prog.cx`
```cx
[?lib 'cx-stdlib/re']
[$re:matches [$re:compile "a+"] "aaa"]
```

```console
$ cx prog.cx
true
```

### `map` and `array` — absence is a value, not a crash

A missing key reads as empty rather than raising; a strict read is a separate
call. This is the same absence discipline as the rest of the language.

`prog.cx`
```cx
[?lib 'cx-stdlib/map']
[$map:get {a: 1} 'zz']
```

```console
$ cx prog.cx
()
```

`prog.cx`
```cx
[?lib 'cx-stdlib/array']
[$array:get [1, 2] 5]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0100 message='[$array:get] position 5 is out of range for an array of 2 item(s) — positions are 1-based (E_ARRAY_INDEX_OUT_OF_RANGE)']
```

### `fp` — the functional layer

`map`, `filter`, `fold`, `flat-map` over sequences, and the absence-aware
variants that make a pipeline total rather than partial.

`prog.cx`
```cx
[?lib 'cx-stdlib/fp']
[?def inc ($x) [+ $x 1]]
[$fp:map (1, 2, 3) $inc]
```

```console
$ cx prog.cx
(2, 3, 4)
```

### `json` — parse and emit

`prog.cx`
```cx
[?lib 'cx-stdlib/json']
[$json:parse "42"]
```

```console
$ cx prog.cx
42
```

### `format` — four renderings, all of them faithful

`canonical`, `compact`, `pretty` and `diff-friendly` are four *renderings* of
one value, and every one of them round-trips: parsing the output gives back a
structurally equal value.

`prog.cx`
```cx
[?lib 'cx-stdlib/format']
[?let [= $w [user active=true age=41 name=alice role="ops lead" score=1.5 tier=:gold [s "text"] [i 7] [d 2.50] [b false] [a :ok]]]
  [$eq [$format:canonical [$cx:parse [$format:pretty $w]]] [$format:canonical $w]]]
```

```console
$ cx prog.cx
true
```

That is a guarantee about **types**, not just text. `pretty` never quotes a
non-string scalar — a decimal stays a decimal, an atom keeps its `:` sigil, a
glued type annotation survives:

`prog.cx`
```cx
[?lib 'cx-stdlib/format']
[$format:pretty [u tier=:gold]]
```

```console
$ cx prog.cx
'[u tier=:gold]'
```

`prog.cx`
```cx
[?lib 'cx-stdlib/format']
[$format:pretty [u port::u16=8080 t=100ms]]
```

```console
$ cx prog.cx
'[u port::u16=8080 t::duration=100ms]'
```

There is exactly one deliberate divergence between the forms: `pretty` always
quotes a string, while `canonical` leaves it bare whenever the bare image
re-parses as that same string. Both round-trip.

Which one to reach for:

| Form | Use it for |
|---|---|
| `canonical` | identity — hashing, addressing, equality. Never for display |
| `compact` | the same bytes, minimised |
| `pretty` | reading and debugging. **Not version-stable — never snapshot-test it** |
| `diff-friendly` | review diffs; sorts attributes |

### `cx` — CX reflecting on CX

`[$cx:parse]`, `[$cx:serialize]`, `[$cx:ast]`, `[$cx:from-format]`. This is
how tooling written in CX reads CX — including the generator that produced
this file.

`prog.cx`
```cx
[?let [= $t [$cx:parse "[?if true [then 1] [else 2]]"]] [$count $t//then]]
```

```console
$ cx prog.cx
1
```

### `log` — structured context, not string prefixes

Log context is a **scope**, entered with `[?with-scope]` and read back as a
map. Nesting overrides key by key, and the scope is restored on exit — which
is what makes a request id ride an entire call tree without being threaded
through every signature:

`prog.cx`
```cx
[?lib 'cx-stdlib/log']
[?with-scope {request-id: "r1"}
  [$log:current-scope]]
```

```console
$ cx prog.cx
{request-id: r1}
```

`prog.cx`
```cx
[?lib 'cx-stdlib/log']
[?with-scope {request-id: "outer"}
  [?with-scope {request-id: "inner"}
    [$log:current-scope]]]
```

```console
$ cx prog.cx
{request-id: inner}
```

`prog.cx`
```cx
[?lib 'cx-stdlib/log']
[$log:current-scope]
```

```console
$ cx prog.cx
{}
```

### `time` — typed instants, refused nonsense

`prog.cx`
```cx
[?lib 'cx-stdlib/time']
[$time:date 2026 2 31]
```

```console
$ cx prog.cx
[err code=cx-err:CXER3300 message='E_TIME_INVALID_COMPONENT: 2026-2-31']
```

## Finding the rest

Per-function documentation is co-located with the implementation as
`[fn-doc]` blocks in `stdlib/<module>.cx`, gated for presence, purity, and
example-backing by `make guide-check`. The rendered form is the "Standard
library" section of the guide. Each module's full conformance matrix is
`conformance/stdlib/<module>.cxd` — the honest answer to "what does this
function do at the edges".
