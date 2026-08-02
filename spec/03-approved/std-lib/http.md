# `cx-stdlib/http` — HTTP/1.1 client and server

```cx
[module-meta name=http tier=D status=current
  [standard ref='RFC 9110' title='HTTP semantics']
  [standard ref='RFC 3986' title='URI']
  [standard ref='SSE' title='Server-Sent Events']]
```

**Status:** Current

Normative reference (on graduation) for the `cx-stdlib/http` sub-package: the L7
HTTP/1.1 layer — methods, headers, status, redirects, content decoding, and a
programmatic client + server — built **on top of** the L4 `cx-stdlib/net`
transport ([`net.md`](net.md), in review). It is the programmatic
companion to the declarative `[?http-service]` / `[?http-client]` directives
([`code.md`](../core/code.md) §10.3).

## §0. Consistency with the in-review amendments (normative dependency)

Authored to be consistent with the same amendments `net` aligns to
([`net.md`](net.md) §0); on their approval the cited semantics are
load-bearing here. If any is rejected or changed at G3, the marked clauses are
revisited.

| Amendment | What http relies on |
|---|---|
| `code.md` §9.1.2 — **four-channel model** | transport/protocol faults ride the **failure channel** (`[err]`, auto-propagates §9.2); a **non-2xx HTTP status is a present `[response]` value that flows** (§9.1.2), NOT a fault and NOT absence; an **absent header** rides the **absence channel** (empty node-set), an **absent/empty body** is a **present-empty value + `has-body` predicate** (the net/io EOF model, §9.1.2) — **never `null`** (no-conflation guard). |
| SAP §2 — **`[?try]`/`[catch]`/`[on-error]` retirement** | http faults are handled with `[?match]` / `[?else]` / `[?fallback]` only; this spec never uses `[?try]`. Canonical call form is `[$http:get …]` (`[head …]`), never the retired infix `\|` of `code.md` §10.3.4's client-op table. |
| SAP §5.2 — **cancellation = `CXER0260`** + capability-revocation backstop | a request cancelled by `[?timeout]`'s cooperative `[?cancel]` surfaces the core `CXER0260` (not an http code); post-cancel raw effects hit `CXER0271`. Client/server/exchange handles satisfy the `[?with-open]` closeable contract (SAP §5.1). |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

http does **not** re-specify sockets, TLS, deadlines, DNS, or the SSRF/rebind
guard — those are `net`'s ([`net.md`](net.md) §2–§5). http composes
`net.dial` / `net.listen` / `net.accept-iter` and inherits net's `CXER45xx`
transport faults unchanged (§8).

---

## §1. Scope

`cx-stdlib/http` provides **HTTP/1.1 request/response semantics**: a programmatic
client (methods, headers, materialized request/response bodies, redirects, content
decoding, connection pooling), message introspection, and a minimal programmatic
server (event-loop dispatch over net's listener fd, §9 backend note). HTTP/2 and HTTP/3 are out of
scope v1 (§7, pinned by a negative fixture).

**Layering (decision 2026-06-02).** HTTP is an **L7** protocol layered on the
**L4** `cx-stdlib/net` transport — a *separate module*, not folded into net
(folding would break net's L4/L7 boundary and transport×operation matrix). The
architecture is: **`cx-stdlib/net` (L4 sockets/TLS) → `cx-stdlib/http` (L7
HTTP) → connectors / declarative directives**.

**Module vs. directives — they coexist, with the module as the engine.**

| Surface | Home | Role |
|---|---|---|
| **`cx-stdlib/http` module** (this spec) | `[?lib 'cx-stdlib/http']` | the **programmatic** client/server library — first-class functions returning `[response]` / `[request]` values |
| **`[?http-service]` / `[?http-client]` directives** | [`code.md`](../core/code.md) §10.3 | the **declarative** surface — a queryable service *definition* with `[resource]` routing + lifecycle |

The directives are the declarative façade; on graduation they **SHOULD** compile
onto this module (paralleling net's note that `[?http-service]`'s listener should
refactor onto `net.listen`/`accept-iter`, [`net.md`](net.md) §6).
The directive-layer codes `CXER0160–0182` (`code.md` §10.3.6) remain the directive
taxonomy and map onto this module's `CXER45xx` band + net's `CXER45xx` as a façade
(§8) — every directive code has a documented target.

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| TCP/TLS sockets, DNS, deadlines, SSRF/rebind guard | `cx-stdlib/net` ([`net.md`](net.md)) |
| HTTP/2, HTTP/3 (QUIC), WebSocket upgrade, `CONNECT` tunnelling | out of scope v1 (§7) |
| **Streaming request bodies** (chunked send) and **streaming response reads** | out of scope v1 (§4.2) — bodies are materialized; a streaming surface is a future revision |
| Cookie jar / automatic cookie state | out of scope v1 (§4.3) — http carries no cookie store |
| `deflate` / `br` content-encoding | **unsupported this revision** (§4.4 — raw-passthrough; `cx-stdlib/bytes` ships `gzip`+`zstd` only). Enabling them is an explicit future HTTP amendment when the in-testing bytes codecs land (§11), not an automatic flip |
| Declarative service definition + `[resource]` routing + `[auth]` | `[?http-service]` ([`code.md`](../core/code.md) §10.3) |
| Retry / circuit-breaker / rate-limit | resilience directives ([`code.md`](../core/code.md) §10.2) — they *wrap* http calls (§6) |
| URL parse / build / join / query-encode | `cx-stdlib/url` |
| MIME / full content-type parsing, multipart | `cx-stdlib/mime` (http parses only the `charset` token, §3.4) |
| JSON / form body (de)serialization | caller via `cx-stdlib/json` / `cx-stdlib/url`; http moves octets (§2.3) |
| gzip/zstd codec | `cx-stdlib/bytes` (http orchestrates, §4.4) |

`cx-stdlib/http` is **Tier-B runtime — necessarily impure** for the network verbs.
Every request/serve operation reaches the network through `net` and therefore
requires the **`net`** capability (§5) — http introduces **no new capability**.
Message construction and introspection are **pure** and capability-free.

## §2. Conceptual model

### §2.1. Handles, ownership, and concurrency

Three impure handle kinds wrap net resources plus HTTP config:

```cx
[http-client base-url="https://api.example.com" state="open"      # client — connection POOL
  follow-redirects=true max-redirects=10 on-close="http/close"]

[http-server url="tcp://0.0.0.0:8080" state="listening"           # server — over a net listener
  on-close="http/close"]

[exchange state="open" on-close="http/close"                      # one server-side request/response turn
  [request method="GET" path="/users/42" ...]]                    #   pins ONE keep-alive connection
```

Ownership model (this is the load-bearing concurrency contract):

- A **client** is **concurrency-safe**: multiple workers MAY call `send` on one
  `[http-client]` simultaneously. The handle wraps a **pool**; `send` checks a
  connection out, uses it, and returns it under internal synchronization. The
  single-owner rule applies to each *pooled net socket*, **not** to the client.
- An **exchange** is **single-owner** (net §2.1/§4.6 verbatim): it pins one
  net socket; transfer to a worker via `[?channel]`; concurrent/non-owner use →
  `cx-err:CXER4516 E_NET_HANDLE_RACE` (net's code, inherited).
- A **server**'s `accept-iter` is a single-use stream (`cx-err:CXER0105` on a
  second walk).
- `state`: client ∈ `"open" | "closed"`; server ∈ `"listening" | "draining" |
  "closed"`; exchange ∈ `"open" | "responded" | "closed"`.
- All three carry the **closeable contract** (`on-close="http/close"`,
  [`code.md`](../core/code.md) §8.10.7): `[?with-open]`-able, never raise
  `CXER0108`; close cancels+joins in-flight ops + releases pooled/underlying net
  sockets (SAP §5.1).
- **Concurrent `close` vs an in-flight `send` (pinned).** When one worker `close`s
  a client while another's `send` is mid-flight, `close` issues a cooperative
  `[?cancel]` and joins: the in-flight `send` that has **already produced its
  `[response]`** returns it normally; one still awaiting the network **observes the
  core `cx-err:CXER0260` (CANCELLED)** at its next cancellation point (SAP §5.2),
  and its pooled socket is released. A `send` **begun after** `close` →
  `cx-err:CXER4535 E_HTTP_HANDLE_CLOSED`. (Same model for `stop` vs an in-flight
  `respond`.)

### §2.2. `[request]` / `[response]` — a documented extension of the locked schema

`[response]` **reuses the locked `code.md` §10.3.3 shape exactly**:

```cx
[response status=200
  [headers [header name="Content-Type" value="application/json"]]
  [body $bytes]]                                   # [body] optional (§2.5)
```

`[request]` is a **documented superset** of the locked `code.md` §10.3.3 shape, not
an exact reuse. The locked shape carries `method=` + `path=` (+ `[path-params]` /
`[query-params]`); the module adds a **client-issue attribute `url=`**:

| View | Addressing | Shape |
|---|---|---|
| **client-issued** (input to `send` / one-shot verbs) | `url=` (absolute, or relative to the client `base-url`) | `[request method="GET" url="https://h/p?q" [headers …] [body …]]` |
| **server-received** (yielded by `accept-iter`) | `path=` + Host header (the locked shape) | `[request method="GET" path="/p" [query-params …] [headers …] [body …]]` |

Both are the same `[request]` tag; `url=` and `path=` are the two addressing views.
When sending, the module derives the wire request-target `path` + query and the
`Host` header from `url=` (via `cx-stdlib/url`). A client-issued `[request]` MUST
carry `url=` and MUST NOT carry `path=`; a server-received one carries `path=` and
not `url=`; violating this → `cx-err:CXER4539 E_HTTP_ARG_INVALID`. This extension is
declared here as the module's addition to the §10.3.3 schema (the directive layer
adopts it on the graduation refactor, §6).

**Query strings (receive side).** On every server-received `[request]` — the
exchange lane, the module `[$http:serve]` handler lane, the `[?http-service]`
directive lane, and any host built on them — the request-target's query string is
parsed into the `[query-params]` child: one `[<name> "<value>"]` element per
`k=v` pair, in wire order, with names and values percent-decoded (`+` decodes to
space) — the receive-side twin of `[$url:query-encode]`. A valueless pair
(`?flag`) carries the empty string; no query → an empty `[query-params]`. The
`path=` attribute never carries the query — routing matches on the bare path. A
handler reads `$request/query-params/<name>` (terminal labeled-field unwrap).

**Method shape — one representation.** A method is an **uppercase string**
(`"GET"`, `"POST"`, custom `"PURGE"`) everywhere: the `method=` attribute value and
the `request` generic's first argument. Atoms (`:get`) are **not** used for methods.
The one-shot verb *names* (`get`, `post`, …) are functions, distinct from the
method *value*.

### §2.3. http moves octets; (de)serialization is the caller's choice; body-kind rule

The request `$body` argument is **`bytes` | `string` | absent**; http sends it
verbatim, materialized, and sets `Content-Length` (streaming/chunked **request**
bodies are out of scope v1, §4.2). Higher-level encodings are explicit and
caller-owned (no hidden codec):

- JSON: `[$json:emit $value]` → string, `content-type` `"application/json"`;
- form: `[$url:query-encode $map]` → string, `"application/x-www-form-urlencoded"`;
- CX value: the doc's canonical bytes, `"application/cx"`.

**Body-kind rule (resolves the shared-shape ambiguity vs `code.md` §10.3.3).** At
the **module / transport boundary the `[body]` child holds raw octets — `bytes`,
or a `string` (UTF-8 text)** — and http never parses or content-negotiates it.
`code.md` §10.3.3's "the `body` child holds the *parsed* request body when
`consumes=` permits" is a **directive-layer** transformation applied *above* this
module: the directive takes the module's raw `[body]` and parses it per `consumes=`
into a CX value. The module's accessors (`body-bytes` / `body-text`, §3.4) operate
on the raw octets only.

### §2.4. A non-2xx status is a VALUE, not a fault (SAP §1)

A completed exchange returning 4xx/5xx is a **successful transport outcome** — the
request reached the server and got an answer. So a non-2xx response is a **present
`[response status=…]` value that flows** (SAP §1 value-channel), **not** an `[err]`
and **not** absence. `[$http:get …]` returning 404 yields `[response status=404 …]`,
inspected with `status` / `ok` (§3.4). This is the load-bearing four-channel
decision for http.

Opt-in escalation: a client/request `raise-for-status=true` opt turns a non-2xx
into `cx-err:CXER4533 E_HTTP_STATUS` at the call site. **The error preserves
diagnostics**: it carries `status=N` and the **full `[response]` (headers + body)
as a child** —
`[err code=cx-err:CXER4533 status=404 [response status=404 [headers …] [body …]]]`.
Off by default so the value-channel posture is the norm.

`[err]` is reserved for genuine faults — the request never produced a valid
response: connect failure (net `CXER45xx`), unparseable status/headers
(`CXER4526`), redirect loop (`CXER4527`), body limit (`CXER4530`), framing
(`CXER4536`), decode (`CXER4532`).

### §2.5. Absence vs present-empty — two distinct nothings (SAP §1, net §2.5)

http follows net's exact split:

- **Absent header → the absence channel (empty node-set).** `header` on a name the
  message does not carry returns the **empty node-set**, which flows inertly — *not*
  `null`. There is **no `header-value` accessor** (it would conflate an absent
  header with a present empty-valued header); the value is reached by a path step,
  `[$http:header $r 'ETag']/@value`, which yields the present value `""` for a
  present empty header and **absence** for an absent header. Distinct by
  construction.
- **Absent/empty body → a present-empty value + a predicate** (the io/net EOF
  model, net §2.5: `''`/empty `bytes` are *present* EBV-false values that flow).
  `body-bytes` is **total** and always returns present `bytes` — empty `bytes` for
  both a missing `[body]` and an explicitly empty body. `has-body` (§3.4) is the
  **structural** distinction: `true` iff a `[body]` child is framed. So
  no-body → `has-body=false`, `body-bytes=∅`; empty-body → `has-body=true`,
  `body-bytes=∅`; non-empty → `has-body=true`, `body-bytes=content`. The
  distinction the empty-bytes value alone cannot carry is recovered by `has-body`.

**Bodyless-status rule.** Responses with status **204 or 304**, and **any response
to a `HEAD` request**, carry no message body (RFC 9110 §6.4.1): the parser frames no
`[body]` and `has-body` is `false` regardless of any `Content-Length` header.
`CONNECT` tunnelling is out of scope v1 (§1) — a `CONNECT` request →
`cx-err:CXER4539 E_HTTP_ARG_INVALID`.

**Interim 1xx responses are consumed, never returned (pinned).** A **1xx**
(`100 Continue`, `103 Early Hints`, …) is an *interim* response: the client
**consumes and discards** it (honoring `Expect: 100-continue` by then sending the
request body) and continues reading until the **final** response (status ≥ 200),
which is the value `get`/`send`/etc. return. A 1xx is therefore **never** the call
result. **Server-side:** high-level `serve` emits **no** interim 1xx (its handler
returns one final `[response]`, status 200–599, §3.5); the **low-level `respond` MAY
send interim 1xx** (`100 Continue`, `103 Early Hints`) as non-final writes followed
by exactly one final response — "1xx then final" is the only interim sequence, and
`respond` after the final → `cx-err:CXER4541` (§3.5).

**Header field representation (pinned).** Every header is
`[header name="…" value="…"]` (the `code.md` §10.3.3 shape). **`value` is always a
`string`**, decoded as **ISO-8859-1 (latin-1)** so every wire byte round-trips
losslessly (RFC 9110's historical field-value octet model) — there is no `bytes`
child and no alternate shape. Senders MUST keep values to visible-ASCII + the
latin-1 range; a value containing CR/LF → `cx-err:CXER4531` (§4.6). `name` is an
RFC 9110 `token`.

### §2.6. Client scheme dispatch (over net)

The client verbs dispatch on the request URL's scheme to a net transport; **only
`http`/`https` are accepted** (any other → `cx-err:CXER4525 E_HTTP_URL_INVALID`):

| URL scheme | net transport ([`net.md`](net.md)) | Default port | TLS |
|---|---|---|---|
| `http://host[:port]/…` | `net.dial 'tcp://host:port'` | 80 | none |
| `https://host[:port]/…` | `net.dial 'tls://host:port'` + `opts.tls` | 443 | client handshake (§4.7) |

(Server **bind** URLs are net transport URLs — `tcp://` / `tls://` — not
`http://`; see §3.5.)

## §3. Public function surface

Signature notation matches [`cx-stdlib/io`](../std-lib/io.md) and
[`net.md`](net.md). `::duration` is a `cx-stdlib/time` duration;
`::element` is a handle, `[request]`, or `[response]`; `::map` is an options record.
An optional read that may be absent is typed `[returns element]` and yields the
**absence channel** (empty) when nothing is present (§2.5).

### §3.1. Client construction

```
[?def client scope=public impure [returns element] ($opts::map {}) ...]
[?def close  scope=public impure [returns null]    ($handle::element) ...]
```

A trailing `$opts::map {}` is a **defaulted positional parameter** —
`grammar.ebnf [153b] PositionalParam ::= '$' Name TypeAnnot? (S Default)?`, i.e. the
default is a **bare, space-separated VALUE after the type** (`$opts::map {}`),
**not** `$opts::map = {}` (the `=` form is a *named* param `$opts={}::map`, [153c]).
So the caller MAY omit it; `[$http:client]` ≡ `[$http:client {}]`. The same trailing
`{}` default is used on every `opts`-taking verb below and on `serve`/`listen`
(§3.5).

`client` returns an `[http-client]` pooling net connections under shared config;
**no network access at construction** — it validates `base-url` eagerly as an
**absolute `http`/`https` URL with an authority (host)** (via `[$url:parse]` +
the authority/scheme check; a relative, schemeless, or non-`http(s)` `base-url`
→ `cx-err:CXER4525 E_HTTP_URL_INVALID`, since a relative request `url=` has no
host/capability target without one) and defers all capability / SSRF / reachability
checks to the first `send` (§5). `close` is **idempotent** and
releases pooled sockets. `opts` (every key is also a per-request override in §3.2):

| Key | Default | Meaning |
|---|---|---|
| `base-url` | — | prefix for relative request `url=` (resolved via `[$url:join]`) |
| `headers` | `{}` | default headers merged into every request (managed names excepted, §4.6) |
| `follow-redirects` | `true` | follow 3xx per §4.3 |
| `max-redirects` | `10` | exceeding → `CXER4528` |
| `timeout` | `30s` | **whole-request** deadline incl. all redirect hops + body read (§4.5); ≠ net's per-socket deadline |
| `tls` | net defaults + ALPN `("http/1.1")` | `tls::map` passed verbatim to `net` ([`net.md`](net.md) §3.6); see §4.7 ALPN rule |
| `max-body-bytes` | `67108864` (64 MiB) | response-body cap, **both decoded and compressed/wire bytes** (§4.4); exceeding → `CXER4530`; **never unbounded** |
| `max-header-bytes` | `65536` (64 KiB) | total response header-block cap; exceeding → `CXER4531` |
| `max-headers` | `100` | response header-count cap; exceeding → `CXER4531` |
| `auto-decompress` | `true` | transparently decode `Content-Encoding` `gzip`/`zstd` (§4.4); other codings left raw |
| `user-agent` | impl default | `User-Agent` default |
| `legacy-post-redirect` | `false` | when `true`, 301/302 after POST rewrites to GET (legacy browser behavior); default `false` = RFC-9110 preserve (§4.3) |
| `raise-for-status` | `false` | non-2xx → `CXER4533` carrying the response (§2.4) |

### §3.2. One-shot verbs (module-level, URL-first)

```
[?def get     scope=public impure [returns element] ($url::string $opts::map {}) ...]
[?def post    scope=public impure [returns element] ($url::string $body $opts::map {}) ...]
[?def put     scope=public impure [returns element] ($url::string $body $opts::map {}) ...]
[?def del     scope=public impure [returns element] ($url::string $opts::map {}) ...]
[?def patch   scope=public impure [returns element] ($url::string $body $opts::map {}) ...]
[?def head    scope=public impure [returns element] ($url::string $opts::map {}) ...]
[?def options scope=public impure [returns element] ($url::string $opts::map {}) ...]
[?def request scope=public impure [returns element] ($method::string $url::string $opts::map {}) ...]
```

Each returns a `[response …]` value (§2.4) or raises a fault (§8). The trailing
**`$opts::map {}` is a defaulted positional parameter** (`grammar.ebnf [153b]` —
bare space-separated VALUE after the type, §3.1), so omitting it is the shorter call and the bundled stub arities are
preserved exactly (`[$http:get $url]` ≡ `[$http:get $url {}]`, `[$http:post $url
$body]` ≡ `[$http:post $url $body {}]`) — see §12 / the stub-compat note. These supersede the
`null`-bodied `get`/`post`/`put`/`del` stub in `stdlib/http.cx` — **same names,
real semantics** (`del`, not `delete`, the latter being a reserved directive name,
`code.md` §4.1). Each opens an **ephemeral** client, issues one request, drops it.
`opts` accepts the §3.1 keys plus `headers`, `content-type`, `query` (`::map` →
query string via `[$url:query-encode]`), and — for `request` — **`body`** (the
generic verb carries a body for any method, so custom methods with bodies work):

```
request : opts.body  ::  bytes | string | absent     ; the generic body path
```

`$body` for `post`/`put`/`patch` is `bytes`/`string` (§2.3); `head`/`options`/`del`
carry no body argument (a body via `opts.body` on `head`/`options`/`del` →
`CXER4539`).

### §3.3. Connection reuse — issue a request through a client

```
[?def send scope=public impure [returns element] ($client::element $req::element) ...]
```

`send` issues a client-form `[request …]` (§2.2, `url=`) through a pooled
`[http-client]` and returns its `[response]`. A request `url=` may be **absolute**
or **relative to the client's `base-url`** (resolved via `[$url:join]`); a
**relative `url=` when the client has no `base-url`** → `cx-err:CXER4525
E_HTTP_URL_INVALID` (no host/capability target to resolve against). `[request]` is a homoiconic value, so
callers build it as a literal — no separate builder:

```cx
[?with-open [$http:client {base-url: 'https://api.example.com'}] $c
  [$http:send $c [request method="GET" url="/users/42"
                   [headers [header name="Accept" value="application/json"]]]]]
```

`send` is concurrency-safe across workers sharing `$c` (§2.1). The §3.2 one-shot
verbs are exactly `client` + build-`[request]` + `send` + `close`.

### §3.4. Message introspection (pure)

```
[?def status        scope=public pure [returns int]                ($resp::element) ...]
[?def ok            scope=public pure [returns bool]               ($resp::element) ...]
[?def header        scope=public pure [returns element]            ($msg::element $name::string) ...]
[?def headers       scope=public pure [returns [sequence element]] ($msg::element) ...]
[?def headers-named scope=public pure [returns [sequence element]] ($msg::element $name::string) ...]
[?def has-body       scope=public pure [returns bool]              ($msg::element) ...]
[?def body-bytes     scope=public pure [returns bytes]             ($msg::element) ...]
[?def body-bytes-wire scope=public pure [returns bytes]            ($msg::element) ...]
[?def body-text      scope=public pure [returns string]            ($msg::element) ...]
```

`$msg` is a `[request]` or `[response]`. All are **pure** (operate on the
materialized message value — no capability, referentially transparent).

- `status` / `ok` — response-only; `ok` is `true` iff `status` ∈ 200–299; on a
  `[request]` → `cx-err:CXER4539 E_HTTP_ARG_INVALID`.
- `header` — **case-insensitive** (RFC 9110 field names); returns the **first**
  matching `[header …]` element (receive order), or the **absence channel (empty)**
  when absent (§2.5). For a multi-valued field use `headers-named` (all occurrences,
  receive order); the RFC-combined value is the `,`-join of those values, computed
  by the caller when needed.
- `headers` — all `[header …]` in receive order, duplicates preserved.
- `has-body` — structural body presence (§2.5).
- `body-bytes` — the **current** body octets: decoded if `auto-decompress` applied
  (§4.4), raw otherwise; empty `bytes` if no/empty body (total, §2.5).
- `body-bytes-wire` — the **original on-the-wire** body octets **before**
  decompression (the compressed entity), so callers can validate `Content-Length`,
  `Digest`, or a body signature against what was actually received. Equals
  `body-bytes` when no decompression occurred (§4.4). **On a `[request]`** (which
  this module never wire-compresses on send) it **always equals `body-bytes`** — the
  accessor is total on both message kinds.
- `body-text` — decodes `body-bytes` as text using the `Content-Type` `charset`
  token (a minimal inline token parse — *not* a dependency on `cx-stdlib/mime`;
  default UTF-8; only UTF-8 / ASCII / latin-1 are guaranteed v1, other charsets →
  use `body-bytes` + caller decode). Invalid-for-charset bytes — including a body
  still under an **undecoded** content-encoding — raise
  `cx-err:CXER4532 E_HTTP_CONTENT_DECODE` (defined behavior, never silent mojibake).

### §3.5. Server — programmatic, built on a real-socket listener (optional surface)

```
[?def serve            scope=public impure [returns element]            ($url::string $handler $opts::map {}) ...]
[?def listen           scope=public impure [returns element]            ($url::string $opts::map {}) ...]
[?def accept-iter      scope=public impure [returns [iterator element]] ($server::element) ...]
[?def exchange-request scope=public impure [returns element]            ($exchange::element) ...]
[?def respond          scope=public impure [returns null]               ($exchange::element $resp::element) ...]
[?def stop             scope=public impure [returns null]               ($server::element) ...]
```

`serve` and `listen` take the same defaulted `$opts::map {}` as the client verbs
(§3.1); `[$http:serve $url $handler]` ≡ `[$http:serve $url $handler {}]`.

**Server bind URLs are net transport URLs, not `http://`** (the §2.6 `http://`/
`https://` table is *client* dispatch). A server binds with `tcp://host:port`
(plaintext) or `tls://host:port` (TLS); a `tls://` bind **requires** `opts.tls` with
`cert`/`key` — net raises `cx-err:CXER4514 E_NET_TLS_CONFIG` if absent
([`net.md`](net.md) §3.6).

`opts` (defaults chosen to **match the `[?http-service]` lock**, `code.md` §10.3.1,
so the directive refactor changes no behavior):

| Key | Default | Lock source |
|---|---|---|
| `max-body-bytes` | `10485760` (10 MiB) | `code.md` §10.3.1 |
| `read-timeout` / `write-timeout` | `30s` | `code.md` §10.3.1 |
| `grace-period` | `30s` | `code.md` §10.3.1 (drain window for `stop`) |
| `max-connections` | `1000` | `code.md` §10.3.1 |
| `backlog` | net default 128 | net §3.3 |
| `block` | `false` | when `true`, `serve` does not return — it runs the listener on the calling fiber until process termination (the `[?http-service] [block true]` clause compiles to this). Default `false` returns the `[http-server]` handle and proceeds. |
| `tls` | — | required for `tls://` binds |

- **High-level `serve`** — binds a real-socket listener and drives an accept/read
  loop (the picoev event-loop backend, §9), parses each
  connection into a server-form `[request]`, calls `$handler` (`[request] →
  [response]`), and writes the response. **Handler-output validation → HTTP 500.**
  `serve` accepts only a **final** `[response]` (status ∈ **200–599**) from
  `$handler` (a handler does **not** emit interim 1xx — `serve` is non-interim in
  v1, §2.5; 1xx is only a low-level `respond` capability); **any other outcome is a
  500** — a returned `[err …]`, a `!` panic, a non-`[response]` value, or a
  `[response]` with status ∉ 200–599 (incl. a 1xx — a **malformed** handler result)
  all produce a `[response status=500]` whose **body is the handler's `[err]`
  serialized to its canonical `application/cx` bytes** (`content-type
  "application/cx"`; the octets-only body rule of §2.3 holds — the err is
  *serialized*, not embedded as a live child) and stamped `CXER4542
  E_HTTP_HANDLER_FAILED`. The server never crashes on a handler fault, and
  `CXER4541` (the low-level `respond` validation code) is **not** surfaced through
  `serve` — `serve` synthesizes a 500 instead.
  This *is* the directive `CXER0165` mapping (§8). Returns an `[http-server]`.
- **Low-level** `listen` → `[http-server]`; `accept-iter` → a single-use
  `[iterator element]` of **`[exchange]`** handles (§2.1). **v1 is non-pipelined**:
  at most one in-flight request per connection; on a keep-alive connection the next
  request is yielded as a **new** exchange only after the prior exchange's
  `respond`. `exchange-request $ex` → the parsed server-form `[request]` (impure
  accessor on the single-owner handle). `respond $ex $resp` writes the response on
  the exchange's pinned connection and validates `status` ∈ 100–599 (else
  `cx-err:CXER4541 E_HTTP_RESPOND_INVALID`). An **interim 1xx** (status 100–199) is a
  **non-final write that does NOT mark the exchange `"responded"`** — the caller MAY
  send several (e.g. `100 Continue`, `103 Early Hints`) and then exactly one final
  response. A **final** response (status ≥ 200) marks the exchange `"responded"`.
  `respond` **after** a final response — or a 1xx after the final — → `CXER4541`
  (so "1xx then final" works, but "final then anything" does not).
- **Read-timeout on the low-level path (pinned).** If a connection produces no
  complete request within `read-timeout`, **no exchange is yielded for it** — the
  connection is closed and `accept-iter` proceeds to the next (a per-connection
  timeout is **not** a listener fault, so `accept-iter` does **not** raise and does
  **not** yield an `[err]`). High-level `serve` additionally writes a `[response status=408]` whose body is a
  `CXER4540 E_HTTP_SERVER_TIMEOUT` `[err]` **serialized to canonical `application/cx`
  bytes** (§2.3 octets-only body rule, `content-type "application/cx"`) before
  closing when a partial request line was read (directive `CXER0163`, §8).
- `stop $server` — graceful drain: the server enters `state="draining"` and, for up
  to `grace-period`, answers new exchanges with a **503** whose body is a `CXER4543
  E_HTTP_UNAVAILABLE` `[err]` **serialized to canonical `application/cx` bytes** (the
  directive `CXER0166` outcome, §8 — a response, not a raised error) — then
  force-closes. Idempotent; `[?with-open]` close calls it.

`serve` is the engine `[?http-service]` compiles onto on graduation; the directive
adds declarative `[resource]` routing, `:name` path-param binding, and `[auth]` on
top (§6).

### §3.6. SSE / streaming — held-open server push + client read

> **Concurrent server push (cx-private #28, RESOLVED).** Two SSE shapes coexist:
> a **single held-open stream** on the `accept-iter` path (`sse`/`send-event`,
> below) — correct for one producer, but the `accept-iter` consumer is **serial
> by design**, so a *long-lived* feed there blocks the loop; and the **pub/sub**
> path on the concurrent `serve` engine (`sse-subscribe` + `sse-publish`, §3.6.1)
> — the right shape for live multi-client push. A `serve` handler promotes its
> connection by **returning `[sse-subscribe topic="…" [event …]?]`**; the reactor
> holds the fd and joins it to the named topic; **any** handler (on any worker)
> fans out with `[$http:sse-publish "…" [event …]]`. No reactor thread is ever
> blocked — pushes are event-driven from whichever request causes them, never a
> producer loop on a single exchange. Use `accept-iter`+`sse` for a one-shot
> stream; use `serve`+`sse-subscribe`/`sse-publish` for concurrent live feeds.
> (A timeout/non-blocking std-stream read — the sibling gap for an interactive
> client — is `cx-stdlib/io` #29.)

> **Implementation tier (this revision).** The **live held-open socket transport
> is implemented** on the L4 `net` layer (built on the real `accept-iter` /
> exchange the low-level server loop uses): `sse` writes the event-stream prelude
> and **holds the connection open**; `send-event`/`heartbeat` **flush real frames**;
> `sse-connect` opens a **real streaming GET** and holds the response connection;
> `sse-events` is a **live single-use iterator** that reads frames off the wire as
> they arrive, with **auto-reconnect** (`Last-Event-ID` resume, bounded by
> `max-reconnect`). All declared codes are raised by the live path: `CXER4544`
> (send/heartbeat on a closed/disconnected stream), `CXER4545` (server
> max-streams), `CXER4547` (2xx that is not `text/event-stream`), `CXER4549`
> (auto-reconnect exhausted), `CXER4550` (frame over `max-event-bytes`), `CXER4551`
> (malformed wire frame), and the **single-use** `CXER0105` on a second
> `sse-events` walk; the pure-codec faults `CXER4539` (empty event) / `CXER4531`
> (CR/LF-in-field, incl. CR in `data` — round-trip is identity) hold both on the
> frame and parse sides. The shared pure framing/parsing codec keeps the symmetry
> invariant (what the server frames parses back equal on the client). Behavioral
> coverage: `vcx/tests/http_sse_real_test.v` (server push + client read over
> real loopback sockets); codec symmetry: `vcx/tests/http_sse_test.v`.
>
> **Two refinement bounds are best-effort in this revision** and surfaced, never
> silently absorbed: `CXER4546` (write backpressure — a stalled slow consumer past
> `stream-write-timeout`) and `CXER4548` (client idle-timeout) require per-write /
> per-read socket deadlines whose timeout↔fault mapping over the buffered reader is
> a follow-up; the v1 transport instead relies on the OS socket buffer + the bounded
> `max-event-bytes`/`max-reconnect` caps so no path is unbounded.

A streaming response keeps the connection fd **registered and held open** and writes the body incrementally, rather than materializing one `[response]`. Both halves share **one pure `[event]` value** (so what the server writes parses back equal on the client — the symmetry invariant, fixtures §10):

```cx
[event id="42" event="order-updated" data="…" retry=3000]   # all attrs optional; multi-line data splits on \n
```

**Server push.** `[$http:sse $exchange {…}]` promotes an open `[exchange]` to a streaming response — it writes the SSE status line + managed headers (200, `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, chunked), marks the exchange `"responded"` (a `respond`/second `sse` after → `CXER4541`), and returns a **single-owner** `[sse-stream]` write handle (closeable, `on-close="http/close"`; non-owner use → `CXER4516`).

```
[?def sse         scope=public impure [returns element] ($exchange::element $opts::map {}) ...]
[?def send-event  scope=public impure [returns null]    ($stream::element $event::element) ...]
[?def heartbeat   scope=public impure [returns null]    ($stream::element) ...]
[?def stream-open scope=public pure   [returns bool]    ($stream::element) ...]
```

- `sse` `opts`: `retry` (initial reconnect-hint ms), `keep-alive` (`15s` auto-heartbeat; `0s` off), `headers`, `last-event-id` (inbound resume convenience).
- `send-event` frames + flushes one `[event]` as a chunk (empty `[event]` → `CXER4539`; CR/LF in `event`/`id` → `CXER4531`); on a disconnected peer or any send/heartbeat after the stream is closed → `CXER4544` (`CXER4535` is reserved for client/server/exchange handles). `heartbeat` writes one `:`-comment liveness frame. `stream-open` is the pure producer-loop guard.
- **Reconnect is client-driven and the server is stateless** — no replay buffer; the handler reads `Last-Event-ID` and decides what to replay (for XAP that is the `journal`-fold-from-cursor). **Bounded resources** (`serve`/`listen` opts): `max-streams` (`1024`; beyond → `CXER4545`), `stream-write-timeout` (`30s`; a stalled slow consumer → `CXER4546` and the stream closes — backpressure is **surfaced, not absorbed**, never an unbounded pending-event buffer). Open streams count against net's handle quota (`CXER4518`).

#### §3.6.1. Concurrent SSE on `serve` — topic pub/sub (#28)

The `sse`/`send-event` surface above promotes **one** `[exchange]` on the serial `accept-iter` path. For **live multi-client push that coexists with serving other requests**, a `[$http:serve]` handler uses the pub/sub surface, which runs on the concurrent `serve` engine without blocking a worker:

```
[?def sse-publish scope=public impure [returns int] ($topic::string $event::element) ...]
```

- **Subscribe.** A handler **promotes its connection to a live feed by RETURNING** `[sse-subscribe topic="<name>" [event …]?]` (instead of a `[response]`). The server writes the SSE prelude, holds the connection open (exempt from the idle timeout), and joins the fd to the string-keyed **topic**. The optional single `[event …]` child is written as the **initial frame** (a malformed initial event → `500`; an empty/missing `topic` → `500`). The handler returns immediately — the connection stays open as a subscriber. **The prelude/initial frame is a readiness acknowledgment**: writing it and joining the topic are atomic with respect to `sse-publish`, so once a client has received bytes of its feed, every subsequent publish to that topic reaches (and counts) this subscriber — a client never observes its own ack yet misses a later event.
- **Publish.** `[$http:sse-publish "<topic>" [event …]]` frames the `[event]` once (same pure codec, so `CXER4539`/`CXER4531` apply) and writes it to **every** connection currently subscribed to `<topic>`, returning the **count delivered**. It is callable from **any** handler on **any** worker thread; a subscriber whose write fails (peer gone) is dropped from the topic. Writing to the subscriber sockets is a net effect (capability `net`, `CXER0271` when ungranted).
- **Cleanup is synchronous.** When a subscriber connection closes, its fd is removed from every topic before the socket is reused, so a concurrent `sse-publish` can never write to a stale fd.
- **No producer loop.** Pushes are **event-driven** — emitted by whichever request mutates state (e.g. a `POST /commit` handler calls `sse-publish`), not by a loop holding one exchange. This is what makes it concurrent where a `send-event` loop on a single `accept-iter` exchange is not.

```cx
[?def handler impure ($req)
  [?let [= $p [$text $req@path]]
    [?if [= $p "/events"]
      [then [sse-subscribe topic="prices" [event data="ready"]]]   # this connection joins "prices"
      [else [?let [= $n [$http:sse-publish "prices" [event data="42"]]]   # fan out to all subscribers
              [response status=200 [body "pushed"]]]]]]]
[$http:serve "tcp://0.0.0.0:8080" $handler {}]
```

**Client read** (the `EventSource` equivalent). `sse-connect` opens a streaming GET; on a 2xx `text/event-stream` it returns an `[sse-source]` read handle, on a non-2xx a materialized `[response]` **value** (a 2xx that is *not* an event stream → `CXER4547`). URL-first and `net`-gated like `get`.

```
[?def sse-connect   scope=public impure [returns element]            ($url::string $opts::map {}) ...]
[?def sse-events    scope=public impure [returns [iterator element]] ($source::element) ...]
[?def source-open   scope=public pure   [returns bool]               ($source::element) ...]
[?def last-event-id scope=public pure   [returns element]            ($source::element) ...]
```

- `sse-events` yields parsed `[event]`s in arrival order (single-use — second walk `CXER0105`); heartbeat/comment frames are consumed silently; **clean end-of-stream is absence** (SAP §1 — not `null`, not `[err]`); a malformed wire frame → `CXER4551`. `source-open`/`last-event-id` are pure accessors (last-event-id absent → the absence channel).
- `sse-connect` `opts` (plus the parent client keys): `last-event-id` (resume header), `reconnect` (`true`; auto-reconnect per the server `retry:` + last id), `max-reconnect` (`10`; beyond → `CXER4549`, never unbounded), `retry` (`3s` fallback backoff), `idle-timeout` (`0s` off; no event/heartbeat within it → `CXER4548`), `max-event-bytes` (`1 MiB`; over → `CXER4550`). `close` (the shared closeable verb) ends a stream/source — there is no separate `sse-close`/`sse-disconnect`.

## §4. Semantics & guarantees (soundness)

### §4.1. Deny-by-default, no ambient network
No request/serve op proceeds without an active `net` grant for the host:port (§5);
http adds nothing to net's capability model.

### §4.2. Bodies are materialized and bounded by default
Request and response bodies are **fully materialized** (Content-Length set on
send); **streaming/chunked request bodies and streaming response reads are out of
scope v1** (§1, §7). Response bodies cap at `max-body-bytes` — applied to **both**
the wire/compressed bytes read **and** the decoded output (§4.4, anti-zip-bomb) —
exceeding → `cx-err:CXER4530`. Server inbound bodies cap at the server
`max-body-bytes` → `cx-err:CXER4538`. **Chunked transfer-encoding** is decoded for
framing and counted against the cap; a malformed chunk / transfer-encoding →
`cx-err:CXER4536 E_HTTP_PROTOCOL` (framing faults route to 4511, distinct from the
status/header parse fault `CXER4526` and the content/charset decode fault
`CXER4532`). A whole-request `timeout` bounds wall-clock by default (§4.5).

**Body-framing conflicts are rejected, not guessed (request-smuggling guard,
normative).** The transfer codings v1 supports are **`chunked` and `identity`**
only. A message is **rejected** — inbound server request → `cx-err:CXER4537
E_HTTP_REQUEST_INVALID`; client response → `cx-err:CXER4526 E_HTTP_INVALID_RESPONSE`
— when it presents any of: (1) **both** `Transfer-Encoding` and `Content-Length`;
(2) **multiple `Content-Length`** headers, or one with comma-separated/conflicting
values (a single repeated identical value is still rejected for simplicity);
(3) a non-numeric or negative `Content-Length`; (4) a `Transfer-Encoding` whose
**final** coding is not `chunked`, or any **unsupported** transfer coding. http
never falls back to read-until-close to resolve an ambiguous frame.

### §4.3. Redirect policy (RFC 9110) — exact matrix
With `follow-redirects=false`, a 3xx is **returned as a value** (`[response
status=302 …]`, §2.4) — not followed, not a fault. With `follow-redirects=true`:

| Status | Method on redirect | Body | Notes |
|---|---|---|---|
| 301, 302 | **preserved** (default); → `GET` iff `legacy-post-redirect=true` and the method was `POST` | preserved (dropped on the legacy POST→GET rewrite) | RFC-9110 §15.4 SHOULD-preserve; legacy opt for old behavior |
| 303 | → `GET` (→ `HEAD` if the request was `HEAD`) | dropped | "see other" |
| 307, 308 | preserved | preserved | method + body invariant |

- **Body replay (pinned).** Because v1 bodies are **materialized** (§4.2), a
  method-and-body-preserving redirect (307/308, and any preserved-method 301/302
  including custom methods) **replays the original request body verbatim** on the
  next hop — the materialized octets are re-sent, with `Content-Length` recomputed
  (identical). 303 and the legacy POST→GET rewrite drop the body.
- `Location` is resolved against the current URL via `[$url:join]` (RFC 3986 §5) —
  **relative Locations are valid**.
- A **missing or unparseable `Location`** on a followed 3xx → `cx-err:CXER4529
  E_HTTP_REDIRECT_INVALID`. (When `follow-redirects=false` there is no Location
  requirement — the 3xx is returned as a value.)
- A **cycle** in visited URLs → `cx-err:CXER4527 E_HTTP_REDIRECT_LOOP`; exceeding
  `max-redirects` → `cx-err:CXER4528 E_HTTP_TOO_MANY_REDIRECTS`.
- Each hop re-runs net's capability match + SSRF/rebind guard against the new host
  (§5, [`net.md`](net.md) §4.5).
- **No cookie jar v1** (§1): the only cross-origin scrubbing is that
  caller-/client-supplied **`Authorization` and `Cookie` request headers are
  dropped** when a redirect targets a different origin (scheme+host+port). http
  carries no cookie state and sets no `Cookie` automatically.

### §4.4. Content decoding
**The decoded set is fixed for this revision: `gzip` and `zstd`** (the codecs
`cx-stdlib/bytes` ships) — plus the no-op `identity`. **`deflate` and `br` are NOT
decoded this revision (§7 ❌); enabling them is an explicit future HTTP spec
amendment, not an automatic consequence of `cx-stdlib/bytes` growing a codec.** This
is deliberate: `auto-decompress` mutates `body-bytes`/`body-text`/fixtures/
conformance, so the decoded set is a **normative HTTP surface decision** that must
not change silently when another module changes (the amendment edits this section,
§7, §8, and the fixtures together). `cx-stdlib/bytes` is in testing adding
`deflate`/`br`; when it ships them, the amendment is queued (§11) — until it lands,
the behavior here is exactly as written.

With `auto-decompress=true`:

- **`identity`** (or an absent `Content-Encoding`) is a no-op — the body is the
  decoded body; `body-text` does **not** fail on it.
- **`gzip` / `zstd`** are decoded via `cx-stdlib/bytes`. **Stacked codings** are
  honored: a `Content-Encoding: gzip, zstd` list is decoded **in reverse order of
  application** (rightmost coding was applied last, so it is undone first), each
  layer counted against the cap. If **any** coding in the chain is unsupported this
  revision (`deflate`/`br`/unknown), the **whole body is left raw** — no partial
  decode (an `[err]`-free, deterministic outcome).
- Decoding is **transparent and non-destructive to the headers**: the wire headers
  (including `Content-Encoding` and the original `Content-Length`, which describes
  the compressed entity) are **left verbatim and fully inspectable** (and the
  compressed octets remain reachable via `body-bytes-wire`, §3.4); the response
  gains a `content-decoded=true` marker attribute, and `body-bytes` returns the
  **decoded** octets (decoded size = `[$bytes:length [$http:body-bytes $r]]`, the
  authority).
- Both the compressed bytes read and the decoded output are bounded by
  `max-body-bytes` (§4.2) — a declared-but-corrupt stream, or one whose decoded
  length exceeds the cap, → `cx-err:CXER4532 E_HTTP_CONTENT_DECODE` (decode failure)
  or `CXER4530` (cap).

An encoding outside the decoded set (`deflate`, `br`, or any genuinely unknown
coding) is **left raw** with the header retained and no `content-decoded` marker —
the **raw-passthrough fallback**; `body-bytes` returns the raw (still-encoded)
octets and `body-text` on them raises `CXER4532` (§3.4). Decoding never happens when
`auto-decompress=false`.

### §4.5. Two timeout mechanisms (net-aligned)
The client `timeout` opt is a **whole-request** deadline (connect + every redirect
hop + body read), surfaced as `cx-err:CXER4534 E_HTTP_REQUEST_TIMEOUT`; distinct
from net's per-socket deadline (`CXER4507`) and the directive `[?timeout]`
(`CXER0141`). A `[?timeout]` wrapping an http call cancels cooperatively → core
`CXER0260` (§0, SAP §5.2), independent of the http `timeout` opt. Server-side, a
`read-timeout`/`write-timeout` lapse → `cx-err:CXER4540 E_HTTP_SERVER_TIMEOUT`
(directive `CXER0163`).

### §4.6. Header hygiene and managed fields
- **Field-name grammar:** RFC 9110 `token` (no CR/LF/space/control); a CR/LF in any
  name or value (request-splitting / response-header injection) →
  `cx-err:CXER4531 E_HTTP_HEADER_INVALID`. **Obs-fold** (RFC 9110-deprecated
  line-folded values) in a *response* is rejected → `CXER4526`; in an inbound
  *request* → `CXER4537`. Field **values** are **latin-1 strings** (§2.5's pinned
  representation — every wire byte round-trips; no `bytes` child). Header-block
  size/count are bounded by `max-header-bytes` / `max-headers` (§3.1) → `CXER4531`.
- **Managed fields (overwritten, not forwarded):** `Host` (from the request URL),
  `Content-Length` (from the materialized body), `Connection` and
  `Transfer-Encoding` (from the keep-alive policy) are **set by the implementation**;
  a caller-supplied value for any of these is **ignored and overwritten** (not an
  error). Hop-by-hop headers are not forwarded across redirects.

### §4.7. TLS and ALPN — http/1.1 only at v1
The client offers ALPN **`http/1.1` only** by default. **ALPN merge precedence
(pinned):** when the caller supplies `tls.alpn`, that list **replaces** the default
verbatim (it is not merged or appended). If the caller's list causes the server to
negotiate `h2`/`h3`, http/1.1 v1 cannot speak it → `cx-err:CXER4536 E_HTTP_PROTOCOL`
(the connection is closed). All other `tls::map` behavior (verification, SNI,
pinning, mTLS, `verify=false` under the `net` grant) is net's, passed through
unchanged ([`net.md`](net.md) §3.6); http overrides only the `alpn`
default.

### §4.8. Handle quotas
Pooled client sockets and server exchanges count against net's open-handle quota
(net §4.7) → `cx-err:CXER4518` on exhaustion. An op on a closed client/server/
exchange → `cx-err:CXER4535 E_HTTP_HANDLE_CLOSED`.

## §5. Capability integration

Gated by the existing **`net`** capability ([`security.md`](../core/security.md)
§2–§4) — **no new capability**, consistent with `store`'s remote backends
([`store.md`](../std-lib/store.md) §9) and net's `verify=false` decision
([`net.md`](net.md) §5).

| Operation | Capability | Resource matched |
|---|---|---|
| `get`/`post`/`put`/`del`/`patch`/`head`/`options`/`request`/`send` | `net` | the request URL's **parsed host + effective port** (§below); then net's SSRF guard + pin per hop (§4.3) |
| `serve` / `listen` | `net` | bind `host:port` (net's listen-wildcard grant rules) |
| `accept-iter` / `exchange-request` / `respond` / `stop` | — | inherit the server's grant; **no per-peer re-check** (net §5) |
| `client` / `close` | — | pool/release only (no net access — §3.1) |
| `status`/`ok`/`header`/`headers`/`headers-named`/`has-body`/`body-bytes`/`body-bytes-wire`/`body-text` | — | **pure** (§3.4) |

**Capability resource form (pinned, resolves the canonicalization ambiguity).** The
matched resource is the **canonicalized `host:port`**: the URL is parsed and then
canonicalized via `[$url:normalize]` / `[$url:build]` — which is the step that
**lowercases the host and emits the IDN A-label** (`[$url:parse]` alone stores
U-labels; A-label emission happens on build, [`url.md`](../std-lib/url.md) §4.2/§4.3).
The **effective port** is the explicit port or the scheme default (`http`→80,
`https`→443; net's `parse-addr` does *not* infer defaults, so http supplies them).
net then matches *that* canonical `host:port` against the grant globs and runs the
SSRF guard on the resolved IPs. So
`--allow-net=api.example.com:443` authorizes `https://api.example.com/…` (no
explicit `:443` needed in the URL).

A denial raises `cx-err:CXER0271 E_CAP_DENIED` naming the missing grant + resource
(net's effect point):
`[err code=cx-err:CXER0271 capability=net resource='api.example.com:443']`. CLI:
`cx FILE --allow-net=api.example.com:443`. **Cancellation + revocation** follow
net §5 / SAP §5.2: a cancelled request at a cancellation point reports `CXER0260`;
a raw effect after cancel hits `CXER0271`; `[?with-open]` close runs under restored
caps.

## §6. Composition with the integration layer

Canonical call form is `[$http:VERB …]` (`[head …]`). The infix `\|` in `code.md`
§10.3.4's client-op table (still current in-repo text) is the form the in-review
SAP §2.1 retires; this module never uses it. If the SAP graduates, the §10.3.4
table is rewritten to `[head …]` calls in the same change (listed in §11); if it
does not, the module surface here stands regardless (it introduces no infix).

```cx
[?retry max=3 backoff=exponential
  [?timeout 10s
    [$http:get 'https://api.example.com/users/42' {}]]]
```

Handle outcomes by **shape**, not `[?try]` — a non-2xx is a value (§2.4), a fault is
`[err]`:

```cx
[?match [$http:get 'https://api.example.com/users/42' {}]
  [case [err @code='cx-err:CXER4527'] [$log:warn 'redirect loop']]   # fault
  [case [err @code=$c] [err code=$c]]                                # re-raise
  [case [response @status=404] [$log:info 'not found']]              # a VALUE (404)
  [case $resp $resp]]                                                # 2xx / other status
```

- **Resilience (§10.2)** wraps http calls: `[?timeout]` → `CXER0260`/`CXER0141`;
  `[?retry]` re-invokes; `[?circuit-breaker]`/`[?rate-limit]` gate the call site.
- **Recovery is `[?else]` / `[?fallback]` / `[?match]`** (SAP §2) — never `[?try]`.
  `[?else [$http:get $url {}] [response status=503]]` defaults on **fault or
  absence**, *not* on a non-2xx value (§2.4 — a 4xx flows through `[?else]`).
- **Servers (§10.3):** `[?http-service]` SHOULD compile onto `[$http:serve …]` — the
  directive's `on=http port=8080` → bind URL `tcp://0.0.0.0:8080` (and `[tls …]` →
  `tls://…` + `opts.tls`); its `[resource]`/`:name`/`[auth]` routing layers above
  the module's `$handler`; its `CXER0160–0182` map per §8.
  - **Real-socket lifecycle.** The directive opens a real picoev listener (§9
    backend note) iff `port > 0` **and** an observable opt-in is present —
    `[block true]`, a `[bind-host ADDR]` clause, or use of `[$serve-file]`;
    otherwise it keeps today's in-process (`cx-test://`) path so the conformance
    battery (`port=0`) never port-allocates. `[block true]` makes evaluation
    block on the listener until `[?stop $handle]` or SIGINT/SIGTERM (graceful
    drain per `serve`'s `grace-period`); default returns the handle and proceeds.
  - **Static files.** `[$serve-file]` (zero-arg, env-driven) resolves
    `$request/path` under the service `root` (threaded via `dyn_context` at
    handler entry); a positional arg overrides the path
    (`[GET "/"] [$serve-file "index.html"]`). Body is raw octets
    (`os.read_bytes`, §2.3), Content-Type by extension. A `..` path segment →
    **400 `bad path`** (symlink containment is a later hardening item).
  - **`[cache true]`** — opt-in static-file body cache for `[$serve-file]`.
    **Default `false`**: every request reads the file fresh (always reflects
    on-disk edits, holds no body memory). `true`: bodies are memoized keyed by
    resolved fs-path and revalidated by mtime (one `stat` per hit) — higher
    throughput under load (≈1.8× on a serve-file `wrk` run) at the cost of
    holding file bodies in memory. Honored identically by the `[$serve-file]`
    eval path and the listener's static-file fast path.
  - **Greedy route.** A trailing literal `*` route segment captures the path
    remainder under synthetic param `_` (`[GET "/assets/*"]` →
    `$request/path-params/_`). Wildcard MUST be trailing; a mid-path `*` →
    `CXER0100` at parse.
  - **`[default-headers H=v …]`** — an attrs-only clause whose headers are
    emitted on every response (the COOP/COEP/CORP knob the playground needs);
    a header set explicitly on a returned `[response]` wins per-key.
- **Concurrency (§10.4):** `[?for [in $ex [$http:accept-iter $s]]]` → hand each
  single-owner `[exchange]` to a `[?worker]` over a `[?channel]` (net §4.6).
- **`[?with-open]` (§8.10.7):** auto-closes client/server/exchange via
  `on-close="http/close"` (cancels+joins, SAP §5.1), idempotent with explicit
  `close`/`stop`.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | `http://` | `https://` | other scheme |
|---|:--:|:--:|:--:|
| `get` / `head` / `options` / `del` | ✅ | ✅ | ❌ ¹ |
| `post` / `put` / `patch` (with body) | ✅ | ✅ | ❌ ¹ |
| `request` (generic / custom method, `opts.body`) | ✅ | ✅ | ❌ ¹ |
| `send` (via client) | ✅ | ✅ | ❌ ¹ |
| `client` / `close` | ✅ | ✅ ² | — ³ |
| `status`/`ok`/`header`/`headers`/`headers-named`/`has-body`/`body-*` | ✅ | ✅ | — ⁴ |
| redirect following (§4.3) | ✅ | ✅ | — ⁵ |
| `gzip`/`zstd`/`identity` auto-decompress (§4.4) | ✅ | ✅ | — ⁵ |
| `deflate`/`br` auto-decompress | ❌ ⁶ | ❌ ⁶ | — ⁵ |

| Operation | `tcp://` bind | `tls://` bind |
|---|:--:|:--:|
| `serve` / `listen` / `accept-iter` / `exchange-request` / `respond` / `stop` | ✅ | ✅ ⁷ |

| Protocol version | client | server |
|---|:--:|:--:|
| HTTP/1.0 (request/respond) | ✅ ⁸ | ✅ ⁸ |
| HTTP/1.1 (keep-alive, chunked) | ✅ | ✅ |
| HTTP request **streaming** body / response **streaming** read | ❌ ⁹ | ❌ ⁹ |
| HTTP pipelining (multiple in-flight per connection) | — ¹⁰ | ❌ ¹⁰ |
| HTTP/2 · HTTP/3 (QUIC) · WebSocket · CONNECT | ❌ ¹¹ | ❌ ¹¹ |

Footnotes: **1** non-http(s) scheme → `CXER4525` (negative fixture); use
`cx-stdlib/net` for raw transports. **2** `https` TLS config flows to net unchanged
(§4.7). **3** `client` carries defaults, not one scheme; the per-request scheme is
validated at `send`. **4** pure introspection over a materialized message —
scheme-independent. **5** redirect/decoding are response processing, not scheme
verbs. **6** `deflate`/`br` are **deliberately unsupported this revision**
(raw-passthrough fallback, §4.4), pinned by a negative fixture. Enabling them is a
**future HTTP spec amendment** (§11) that edits §4.4/§7/§8 + fixtures together —
*not* an automatic flip when `cx-stdlib/bytes` (in testing) ships the codecs. **7**
`tls://` bind requires `opts.tls` `cert`/`key` (net
`CXER4514`). **8** HTTP/1.0 accepted/emitted; keep-alive defaults off per the RFC.
**9** materialized bodies only v1 (§4.2); a streaming surface is a future revision.
**10** non-pipelined v1 (§3.5): one in-flight request per connection; the client
never issues pipelined requests (—), the server never reads a second before
`respond` (❌). **11** out of scope v1 — large multiplexing/framing surface;
ALPN-negotiated `h2`/`h3` → `CXER4536` (§4.7); pinned by negative/skip fixtures.

Cognate-coverage: every method verb ships for both schemes and both
one-shot/`send` paths; every introspection accessor works on `[request]` and
`[response]`. The intentional asymmetries (HTTP/2/3, streaming, pipelining,
`deflate`/`br`) are justified above and pinned by negative/skip fixtures; each is a
**documented limit of this revision**, not an open cell.

## §8. Error codes — `CXER4525–CXER4589` band (proposed allocation)

`CXER4525–CXER4543` is allocated to http in the governance registry
([`governance.md`](../process/governance.md) §9.6), the next free block above
`cx-stdlib/net`'s `CXER4500–4524` (net was renumbered off its rev-7 4400-band after
a collision with `cx-stdlib/fp`'s `CXER4400–4409`; http takes the block above net).
This revision uses `CXER4525–4543` (core) + `CXER4544–4551` (SSE/streaming, §3.6; `4552–4589` reserved). All values use `cx-err:` notation; symbolic↔wire is 1:1
(governance invariant). **Cancellation is the core `CXER0260`, not an http code**
(§4.5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4525` | `E_HTTP_URL_INVALID` | malformed URL or non-http(s) scheme (§2.6); bad/relative `base-url` at `client`, or a relative request `url=` with no `base-url` (§3.1/§3.3) |
| `cx-err:CXER4526` | `E_HTTP_INVALID_RESPONSE` | status line / headers unparseable, or response obs-fold (maps directive `CXER0182`) |
| `cx-err:CXER4527` | `E_HTTP_REDIRECT_LOOP` | redirect cycle (§4.3) |
| `cx-err:CXER4528` | `E_HTTP_TOO_MANY_REDIRECTS` | `max-redirects` exceeded |
| `cx-err:CXER4529` | `E_HTTP_REDIRECT_INVALID` | followed 3xx with missing/unparseable `Location` |
| `cx-err:CXER4530` | `E_HTTP_BODY_TOO_LARGE` | response body exceeded `max-body-bytes` (decoded or wire, §4.4) |
| `cx-err:CXER4531` | `E_HTTP_HEADER_INVALID` | CR/LF-injected / invalid header name/value, or `max-header-bytes`/`max-headers` exceeded (§4.6) |
| `cx-err:CXER4532` | `E_HTTP_CONTENT_DECODE` | `Content-Encoding` (gzip/zstd) decompress failure, or `body-text` charset decode failure (§3.4/§4.4) |
| `cx-err:CXER4533` | `E_HTTP_STATUS` | non-2xx under `raise-for-status=true`; carries `status=` + the `[response]` (§2.4) |
| `cx-err:CXER4534` | `E_HTTP_REQUEST_TIMEOUT` | client whole-request `timeout` lapsed (§4.5) |
| `cx-err:CXER4535` | `E_HTTP_HANDLE_CLOSED` | op on a closed client/server/exchange handle |
| `cx-err:CXER4536` | `E_HTTP_PROTOCOL` | framing fault (bad chunk / transfer-encoding) or ALPN-negotiated `h2`/`h3` (§4.2/§4.7) |
| `cx-err:CXER4537` | `E_HTTP_REQUEST_INVALID` | server: malformed inbound request / obs-fold (maps directive `CXER0160`) |
| `cx-err:CXER4538` | `E_HTTP_REQUEST_TOO_LARGE` | server: inbound body > `max-body-bytes` (maps directive `CXER0164`) |
| `cx-err:CXER4539` | `E_HTTP_ARG_INVALID` | `status`/`ok` on a `[request]`; `url=`/`path=` misuse (§2.2); body on a bodyless verb; invalid method |
| `cx-err:CXER4540` | `E_HTTP_SERVER_TIMEOUT` | server `read-timeout`/`write-timeout` lapsed (maps directive `CXER0163`) |
| `cx-err:CXER4541` | `E_HTTP_RESPOND_INVALID` | `respond` with status ∉ 100–599, or a second `respond` on one exchange |
| `cx-err:CXER4542` | `E_HTTP_HANDLER_FAILED` | `serve` `$handler` faulted/panicked or returned a malformed result; stamped on the synthetic 500 (maps directive `CXER0165`) |
| `cx-err:CXER4543` | `E_HTTP_UNAVAILABLE` | `serve` drain: 503 body during graceful shutdown (maps directive `CXER0166`) |
| `cx-err:CXER4544` | `E_HTTP_STREAM_CLOSED` | (server) `send-event`/`heartbeat` on a disconnected peer, or any stream op after `close` (§3.6) |
| `cx-err:CXER4545` | `E_HTTP_STREAM_LIMIT` | (server) opening an `sse` stream beyond `max-streams` (§3.6) |
| `cx-err:CXER4546` | `E_HTTP_STREAM_BACKPRESSURE` | (server) a `send-event` write stalled past `stream-write-timeout`; the stream is closed (§3.6) |
| `cx-err:CXER4547` | `E_HTTP_SSE_NOT_STREAM` | (client) `sse-connect` got a 2xx whose `Content-Type` is not `text/event-stream` (a non-2xx is a returned `[response]`, not this fault) |
| `cx-err:CXER4548` | `E_HTTP_SSE_IDLE_TIMEOUT` | (client) no event or heartbeat within `opts.idle-timeout` on an open source (§3.6) |
| `cx-err:CXER4549` | `E_HTTP_SSE_RECONNECT_EXHAUSTED` | (client) consecutive reconnects exceeded `opts.max-reconnect` (a fault, not end-of-stream) |
| `cx-err:CXER4550` | `E_HTTP_SSE_FRAME_TOO_LARGE` | (client) one event frame exceeded `opts.max-event-bytes` (unbounded-frame guard) |
| `cx-err:CXER4551` | `E_HTTP_SSE_PARSE` | (client) a malformed SSE wire frame at that `[next]` (§3.6) |
| `CXER4552–CXER4589` | — | reserved for future http streaming extensions (WebSocket upgrade, request-body streaming) |

`CXER4532`'s decoded set is **this revision's** `gzip`/`zstd` (§4.4); the
deflate/br amendment (§11) would extend that description in lock-step — it does not
drift on its own.

**Shared/core codes http surfaces (not in its band):** `cx-err:CXER0271` (capability
denial, §5); `cx-err:CXER0260` (cancellation, §4.5); `cx-err:CXER0105` (second walk
of `accept-iter`, §3.5); `cx-err:CXER0108` never raised (handles are closeable,
§2.1). **Inherited net transport faults** (propagate as-is, not remapped):
`CXER4504` (SSRF deny), `CXER4505` (connect refused), `CXER4506` (unreachable),
`CXER4507` (socket deadline), `CXER4508` (reset), `CXER4512` (TLS handshake),
`CXER4513` (pin mismatch), `CXER4514` (server TLS config), `CXER4516` (handle race),
`CXER4518` (handle quota).

**Directive-layer mapping (façade — every `code.md` §10.3.6 code maps to an http
code, or stays intentionally directive-owned where the concern is routing/auth).**

| Directive code | Target | Notes |
|---|---|---|
| `CXER0160` BAD_REQUEST | `CXER4537` | server inbound parse |
| `CXER0161` UNAUTHORIZED | — *(directive-owned)* | `[auth]` is a directive routing concern; the module's `$handler` returns a 401 `[response]` itself |
| `CXER0162` NOT_FOUND | — *(directive-owned)* | routing is the directive's; `serve` delegates dispatch to `$handler` |
| `CXER0163` REQUEST_TIMEOUT | `CXER4540` | server read timeout |
| `CXER0164` PAYLOAD_TOO_LARGE | `CXER4538` | server body cap |
| `CXER0165` INTERNAL_ERROR | `CXER4542` (or the handler's verbatim `[err]`) | serve wraps a handler fault into a 500 |
| `CXER0166` SHUTTING_DOWN | `CXER4543` | `serve` drain answers a 503 whose body is a `CXER4543` `[err]` serialized to `application/cx` octets (§2.3/§3.5) |
| `CXER0180` CONNECTION_REFUSED | net `CXER4505` | transport, via net |
| `CXER0181` TLS_HANDSHAKE_FAILED | net `CXER4512` | transport, via net |
| `CXER0182` INVALID_RESPONSE | `CXER4526` | client response parse |

Routing (`0162`) and `[auth]` (`0161`) stay directive-owned: the module provides
transport + handler dispatch, not routing/auth, so those have no module *error*
(they are handler-returned `[response]`s). Every other directive code maps to a
concrete module/net code above.

## §9. Implementation notes (non-normative) — composing net + cx-stdlib/bytes + V host primitives

| http surface | Building block | Enhancement needed |
|---|---|---|
| `get`/…/`send` | `net.dial 'tcp\|tls://…'` + stream I/O ([`net.md`](net.md) §3.4) | HTTP/1.1 request serializer + response parser (status line, headers, chunked decode → `CXER4536`) atop net's `read-line`/`read-exact`/`write-string` |
| connection pool | per-(host,port,scheme) keep-alive map of net `[socket]`s | internal sync for concurrent `send` (§2.1); idle eviction; single-owner socket checkout |
| redirects (§4.3) | re-issue via net; `[$url:join]` for relative `Location` | per-hop capability + SSRF re-check; `Authorization`/`Cookie` strip on cross-origin |
| decompression (§4.4) | `cx-stdlib/bytes` `gzip-decompress` / `zstd-decompress` | stacked-coding reverse-order decode; dual wire+decoded cap; `content-decoded` marker + `body-bytes-wire`; headers verbatim; deflate/br left raw |
| `body-text` charset (§3.4) | minimal `Content-Type` `charset` token scan | UTF-8/ASCII/latin-1 only v1; no `cx-stdlib/mime` dependency |
| `serve`/`listen`/`accept-iter` | `picoev` event loop + `picohttpparser` (both vendored in the patched V fork, `third_party/v/vlib/{picoev,picohttpparser}`) bound on net's `listen` fd | event-loop accept/read → `picohttpparser` request parse → `[exchange]` → `$handler` → write; non-pipelined keep-alive; handler-fault→500; `grace-period` drain. **NOT** V's `net.http`/blocking-accept stack (§9 backend note) |
| TLS / ALPN (§4.7) | net `tls://` / `tls-wrap` | offer `http/1.1` ALPN; reject negotiated `h2`/`h3` → `CXER4536` |
| cancellation | net cancellation observation (SAP §5.2) | whole-request `timeout` layered over net deadlines |

Spec is implementation-agnostic; only surface + guarantees are normative. The
existing `vcx/code/services_listener_*` and the `[?http-client]`/`[?http-service]`
evaluator paths SHOULD refactor onto this module + net once both graduate (no
silent dual HTTP stack).

**Server-leg backend — picoev + picohttpparser (resolves the deferred backend
question).** The isolation bench (`make bench-code-http-isolation`,
`vcx/tests/runners/code_http_isolation_bench.v`) measured the no-op request path
on two legs against the same workload: the interpreter leg (`code.eval` + env
clone, no socket) ran at ~10 µs/req (~99k req/s) while the warm-keep-alive
transport leg over V's blocking `net.http`-style serve ran at ~145 µs/req
(~6.9k req/s) — transport is ~14× the interpreter cost and ~93.5 % of request
wall-clock. The ~10k req/s ceiling is therefore **transport-bound, not
interpreter-bound**, so the server leg is built on a **picoev event loop driving
`picohttpparser`** (both vendored in the patched V fork) rather than a
thread-per-request blocking accept-loop. This is non-normative (surface +
guarantees in §3.5/§4 are unchanged); it records *how* the listener meets them.
The event-loop model is also what makes held-open connections (SSE / long-poll,
a directive-layer feature) first-class — picoev keeps the fd registered without
burning a thread per stream, which the blocking accept-loop cannot do cheaply.

**Multicore substrate + the two GC facts that gate throughput on macOS.** The
listener binds ONE socket and spawns N picoev loops (one per core) that all watch
that shared fd; the kernel distributes `accept()`s across them (portable — macOS
`SO_REUSEPORT` does not load-balance, but shared-fd accept does). Per-request env
clones keep concurrent handler eval safe.

(1) **Parallel-mark must be capped to a single marker.** libgc defaults to one
mark helper per core; on macOS every stop-the-world collection then wakes N-1
helpers that contend (mach `thread_suspend`/`resume` + mark-queue spin), starving
the reactor threads. The patched V fork emits `GC_set_markers_count(1)` in the
macOS `main()` boehm preamble before `GC_INIT()` (the `GC_MARKERS` env var still
overrides). Measured on a 12-core M-series, serve-file under `wrk -t8 -c100`:
~48.5K req/s with parallel mark vs ~125–131K req/s with a single marker (**2.6×**
at every thread count).

(2) **This does NOT yet yield multicore scaling.** With marking fixed, throughput
plateaus at ~130K req/s (~1–2 effective cores) and degrades past ~2 client
threads — the reactors burn 5–7 cores spinning on the Boehm global allocator
lock, driven by ~10KB of per-request allocation (the per-request
`bindings`/`closures`/`dyn` map clones → ~36 stop-the-world collections/s under
load). Big-heap tuning does not lift it (the alloc lock, not collection
frequency, is the limiter; thread-local-alloc is compiled into the macOS libgc
but does not absorb it). True scaling requires cutting per-request allocation —
share/COW the handler env instead of cloning it per request.

## §10. Conformance fixtures (to author on graduation)

Hermetic, loopback-only (a test server via `serve`, or net loopback). **Every
matrix ✅ has ≥1 positive fixture; every justified ❌ a negative/skip fixture.**

Positives: GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS round-trip (status + headers +
body byte-exact); `request` generic with a custom method + `opts.body`;
`[$http:get $url]` (omitted `$opts={}`) ≡ `[$http:get $url {}]` (stub-arity compat);
`https://` against a test CA (TLS via net); **non-2xx returns a `[response
status=404]` VALUE, not `[err]`** (§2.4); `raise-for-status=true` → `CXER4533`
**carrying status + the `[response]` body/headers**; header case-insensitivity;
**duplicate headers** preserved by `headers`/`headers-named`, `header` returns the
first; header `value` is a **latin-1 string** round-tripping high bytes (§2.5);
**absent header → absence (empty), present empty-valued header → `""`** (distinct
via `/@value`); **`has-body` distinguishes no-body (204/304/HEAD) from empty-body**;
**1xx (`100 Continue`/`103 Early Hints`) consumed — the call returns the final ≥200
response**; connection reuse via `client`+`send` (pool hit) + concurrent `send` from
multiple workers + **concurrent `close` mid-`send` → in-flight observes `CXER0260`,
post-close `send` → `CXER4535`**; redirect follow (301/302 preserve, **307/308
materialized-body replay incl. custom method**, `legacy-post-redirect` POST→GET, 303
method rewrite + body drop, **relative `Location` via `[$url:join]`**); cross-origin
`Authorization`/`Cookie` strip; `gzip`/`zstd`/`identity` auto-decompress with **wire
headers left verbatim** + `content-decoded` marker + decoded-size authority +
**`body-bytes-wire` returns the compressed entity**; **stacked `gzip, zstd`
reverse-order decode**; chunked transfer decode; `--allow-net` happy path
(**canonical host via `[$url:normalize]` + default port**); `serve` accept-loop
dispatch + low-level `accept-iter`/`exchange-request`/`respond`; **graceful `stop`
drain → 503 carrying `[err code=cx-err:CXER4543]`**.

Negatives: no `net` grant → `CXER0271`; `ftp://`/`ws://` → `CXER4525`; bad
`base-url` at `client` → `CXER4525`; unparseable response / obs-fold → `CXER4526`;
redirect loop → `CXER4527`; over `max-redirects` → `CXER4528`; missing `Location`
(while following) → `CXER4529`; response over `max-body-bytes` (decoded **and**
compressed-wire) → `CXER4530`; CRLF header injection / over `max-header-bytes` /
over `max-headers` → `CXER4531`; corrupt gzip/zstd → `CXER4532`; **invalid status
construction** (`respond` status 999) → `CXER4541`; **double `respond`** →
`CXER4541`; whole-request timeout → `CXER4534`; `[?timeout]` cancellation → inner
`CXER0260`, outer `CXER0141`; server inbound malformed → `CXER4537`; server body
over cap → `CXER4538`; `status` on a `[request]` / `url=`+`path=` misuse → `CXER4539`;
`CONNECT` request → `CXER4539`; **server read timeout → low-level: no exchange
yielded + connection closed; `serve`: 408 with `CXER4540`**; **ALPN-forced `h2`
negotiated → `CXER4536`**; malformed chunk → `CXER4536`; **request-smuggling guards
— `Transfer-Encoding`+`Content-Length` together, duplicate/`conflicting
Content-Length`, unsupported transfer coding → `CXER4537` (server) / `CXER4526`
(client)**; handler panic / non-`[response]` / out-of-range status from `$handler`
→ 500 with `CXER4542`; **`deflate`/`br` left raw — raw-passthrough fixture
(`Content-Encoding: br` retained, no `content-decoded` marker, `body-text` →
`CXER4532`)**; HTTP/2 + HTTP/3 + pipelining + streaming-body skip-with-rationale.
Inherited transport negatives (connect refused `CXER4505`, TLS handshake
`CXER4512`) exercised through net.

SSE / streaming (§3.6): **`[event]` framing round-trip** — `send-event` on the server and `sse-events` `[next]` on a loopback client yield the **equal** `[event]` value (the symmetry invariant), incl. multi-line `data` split/rejoin and an `id`/`event`/`retry`-bearing frame; a heartbeat/comment frame is consumed silently (not yielded); **clean end-of-stream is absence** (the iterator exhausts, not `null`/`[err]`); `last-event-id` checkpoints the last seen `id`. Negatives: empty `[event]` → `CXER4539`; CR/LF in `event`/`id` → `CXER4531`; `respond`/second `sse` after a stream opened → `CXER4541`; `send-event` after peer disconnect → `CXER4544`; opening beyond `max-streams` → `CXER4545`; stalled write past `stream-write-timeout` → `CXER4546`; `sse-connect` to a 2xx non-`text/event-stream` → `CXER4547`; idle past `idle-timeout` → `CXER4548`; reconnects past `max-reconnect` → `CXER4549`; frame over `max-event-bytes` → `CXER4550`; malformed wire frame → `CXER4551`; a non-2xx `sse-connect` returns a `[response]` value (not a fault); second walk of `sse-events` → `CXER0105`.

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      add `CXER4525–CXER4543 | cx-stdlib/http | spec/std-lib/http.md`; re-run the
      band scan (confirm no overlap with net's `CXER4500–4524`).
- [ ] **Module index + count (see §12).** Add a `http` row to
      [`spec/std-lib/README.md`](../std-lib/README.md) §3 (Tier-B) and bump §3's
      "**29**"→"**30**" and §3.2's "**29-module**"→"**30-module**". **No
      skeleton-test change for http** — it already asserts 30 and lists
      `'cx-stdlib/http'`; refresh the stale count-history comment (lines ~25–27).
- [~] **Real bodies for the §3 surface** (no stub). **DONE:** the **client** —
      one-shot `get`/`post`/`put`/`del`/`patch`/`head`/`options`/`request` + pooled
      `send` issue a real HTTP/1.1 request over the `cx-stdlib/net` TCP core and
      parse the real response (status line / headers / Content-Length / chunked /
      `Connection: close`); introspection `status`/`ok`/`header`/`headers`/
      `headers-named`/`has-body`/`body-bytes`/`body-bytes-wire`/`body-text` real;
      `client`/`close` real; **`https://` real** over the net TLS layer (mbedTLS;
      verify defaults true against the OS trust store, `verify:false`/`ca` opts per
      §3.6). **REMAINING** (own sub-layers): redirects + gzip/zstd decode; the
      server-side accept-loop API `listen`/`accept-iter`/`exchange-request`/
      `respond`/`stop` (`serve` already binds a real picoev socket). The verbs that
      remain unimplemented now error honestly — no synthetic response.
- [ ] Implement on net: HTTP/1.1 serializer/parser + pool + redirects +
      gzip/zstd decompression + server; refactor `services_listener_*` and the
      `[?http-client]`/`[?http-service]` evaluator paths onto it (or a tracked
      follow-up — no silent dual HTTP stack).
- [ ] Confirm http's reliance on the §0 in-review amendments survived their G3
      (four-channel model incl. **non-2xx-is-a-value**, `[?try]` retirement,
      `CXER0260` cancellation, orthogonality-guard home).
- [ ] **`cx-stdlib/net` must graduate first** (hard dependency — http is built on
      it, uses its `CXER45xx` band and capability layer).
- [ ] Coordinate with `code.md` §10.3: re-point the directive surface to compile
      onto this module and record the `CXER0160–0182 ↔ CXER45xx` façade
      (§8) in §10.3.6 (incl. `on=`/`port=` → bind-URL, `[tls]` → `tls://`+`opts.tls`).
      **If the SAP graduates, rewrite the `code.md` §10.3.4 client-op table off the
      infix `\|` onto `[head …]` calls in the same change** (§6).
- [ ] **Future amendment (tracked, NOT part of this graduation): `deflate`/`br`
      decode.** When `cx-stdlib/bytes` (in testing) ships deflate/br, a *separate*
      HTTP spec amendment flips §7's deflate/br ❌→✅ and edits §4.4 (decoded set),
      §8 (`CXER4532` description), and the §10 fixtures **together** — an explicit
      surface change, never an automatic flip when the codec lands. This revision
      graduates with deflate/br as the documented raw-passthrough limit.
- [ ] Author §10 fixtures; wire into the gate.
- [ ] Validate repo-relative cross-references render.
- [ ] Move `spec/02-inprogress/http.md` → `spec/std-lib/http.md` (user-only).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states the **single correct count** and the **exact lines** that change
at graduation; per Rule G3 it makes **no edits**.

**"Bundled name" ≠ "module behavior."** The skeleton test
`vcx/tests/stdlib_skeleton_test.v` (`test_stdlib_surface_enumerates_bundled_subpackages`)
asserts that 30 sub-package **names** exist with non-empty, parseable,
public-`[?def]` source — its header comment explicitly admits **signature-only
`null` placeholders**. So the skeleton proves `'cx-stdlib/http'` is a **bundled
name** with a signature stub; it does **not** prove HTTP behavior. This spec + the
§11 impl supply the behavior. The *count* tracks bundled **names**, so http counts.

**Ground truth — the bundled-name count today is 30, not 29.** That test's
`expected` list includes `'cx-stdlib/http'` and its assert is 30. The discrepancy is
in [`spec/std-lib/README.md`](../std-lib/README.md) §3, which says "**29**" and
**omits the `http` row** (its 19 Tier-A + 8 Tier-B + 2 Tier-C = 29 rows are the 30
skeleton names minus `http`). `process` *is* present in both the README §3 Tier-B
table and the skeleton list — it is not part of the discrepancy. http was bundled
as a name in the std-lib impl phase but never given a README row or a spec — an
authoring omission, not a design choice to exclude it.

**Resolution (decision 2026-06-02 — author the spec).** http is a real L7 module
and part of the bundled-name surface. The fix is to the README, to match the binary
(referenced by section / test-symbol, since line numbers shift when the stale
count-history comment is refreshed):

| Target (by section/symbol) | Current | Becomes (at graduation) |
|---|---|---|
| `README.md` §3 intro sentence | "enumerates **29** sub-packages" | "**30**" |
| `README.md` §3.2 frozen-surface sentence | "The **29-module** … frozen surface" | "**30-module**" |
| `README.md` §3 Tier-B table | (no `http` row) | add `\| http \| HTTP/1.1 client + server (built on net) \| [http.md](http.md) \|` |
| `stdlib_skeleton_test.v` — `test_stdlib_surface_enumerates_bundled_subpackages` | asserts **30**, lists `'cx-stdlib/http'` | **unchanged** — already correct; refresh the count-history comment above it |

**Interaction with the other in-review drafts (local facts only).** http is a
**reconciliation, not an addition** — it corrects README 29→30 to match the binary's
existing 30 bundled names; the skeleton does not move. `net` and `fp` are **not yet
bundled** (absent from the skeleton), so each is a genuine **+1** at its own
graduation. The SAP §3.1 phrases fp's bump as "29→30" against the **stale** README
baseline that omits http; once http reconciles the README to 30, fp re-bases to
**+1 on the then-current count** (30→31), and `net` likewise (+1). Order-independent;
each graduation applies +1 to whatever the current count is. **No edits are made by
this draft** (G3) — the table above is for the graduation PR.

---

### Review questions — RESOLVED (user G3, 2026-06-02)

1. **One-shot vs. client surface — DECIDED (a).** Keep both the URL-first one-shot
   verbs *and* `client`+`send`, with `$opts={}` defaulted so the bundled stub
   arities (`get(url)`, `post(url, body)`) stay valid. (Spec: §3.1–§3.3.)
2. **Server surface inclusion — DECIDED (a).** Include `serve`/`listen`/
   `accept-iter`/`exchange-request`/`respond`/`stop` with the `[exchange]`
   single-owner ownership model. (Spec: §3.5.)
3. **Non-2xx-as-value — DECIDED (a).** A non-2xx is a flowing `[response]` value;
   `raise-for-status` is opt-in and its `[err]` carries `status` + the full
   `[response]`. The load-bearing four-channel decision. (Spec: §2.4.)
4. **`deflate`/`br` content-encoding — DECIDED: unsupported this revision (❌),
   enabled by an explicit future amendment.** The "⏳ on deck" framing of rev-3 was
   corrected: a normative matrix admits only ✅/❌/— (no third deferred state), and a
   decode set that mutates `body-bytes`/`body-text`/fixtures must not flip silently
   when `cx-stdlib/bytes` grows a codec. So this revision is **gzip/zstd/identity
   only**; deflate/br are ❌ raw-passthrough (§4.4). `cx-stdlib/bytes` is in testing
   adding them; when it ships, a **separate HTTP spec amendment** flips §7 + edits
   §4.4/§8/fixtures together (tracked in §11). The on-deck intent is honored as a
   queued amendment, not an automatic behavior change. (Spec: §4.4, §7 ❌⁶, §11.)
5. **Directive refactor timing — DECIDED (a).** Re-point `[?http-service]`/
   `[?http-client]` onto this module *in the graduation PR* (no dual HTTP stack);
   the largest cross-cutting change, tracked in §11. (Spec: §6, §8 façade, §11.)
