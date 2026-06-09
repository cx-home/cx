# `cx-stdlib/net` — sockets, transports, and TLS

```cx
[module-meta name=net tier=B status=current
  [standard ref='POSIX' title='Sockets']
  [standard ref='RFC 8305' title='Happy Eyeballs']
  [standard ref='RFC 5952' title='IPv6 text']
  [standard ref='RFC 6347' title='DTLS 1.2']
  [standard ref='RFC 9147' title='DTLS 1.3']]
```

**Status:** Current for v0.8.0

Normative reference (on graduation) for the `cx-stdlib/net` sub-package: the L4
transport layer — TCP, UDP, Unix-domain sockets, TLS — beneath the L7
`[?http-service]`/`[?http-client]` directives ([`code.md`](../core/code.md) §10.3)
and the future connectors / DB drivers (§1).

## §0. Foundations — admitted vs in-review

**§0.1 — net stands on ADMITTED semantics only; graduation depends on nothing
unadmitted.**

| Admitted mechanism | Used for |
|---|---|
| `[err]` + auto-propagation (`code.md` §9.2) | net faults |
| `cx-err:CXER0260` CANCELLED (admitted registry) | a cancelled net op (§2.4) — **at the cancellation point only**; net adds **no** unadmitted cap-revocation behavior |
| `cx-err:CXER0271` + the `net` capability, `[?with-caps]` (`security.md`) | capability gating (§5) |
| `[?match]` / `[?fallback]` (`code.md` §8.2/§10.2) | handling (§6) |
| `[?with-open]` closeable contract (`code.md` §8.10.7) | RAII close (§2.1) |
| `[?for [in $x SRC]]`, `[?retry]`, `[?timeout]` | composition (§6) |

**§0.2 — net-local API convention (declared, not inherited).** net adopts the
convention **"an optional read with no result yields the empty node-set"** for
`remote-addr`/`peer-cert` (§2.5). This is **net's own declared API convention**,
*modeled on* CXPath optional reads but **not** claimed to be mandated by CXPath for
stdlib functions (rev-4 Medium). It is consistent with the in-review four-channel
"absence" model but does not depend on it.

**§0.3 — consistent with, not blocked by, the in-review amendments** (four-channel
model, `[?try]` retirement, orthogonality guard, generator reshape). net uses none
of their new surface; if they land, §2/§6 framing gains their vocabulary. The §11
checklist does not gate on them.

---

## §1. Scope

Transport-level networking: opening/accepting stream connections (TCP, Unix-stream,
TLS), exchanging datagrams (UDP, Unix-datagram), name resolution, TLS
upgrade/termination. The layer a DB wire-protocol driver, a custom binary protocol,
a WebSocket stack, or an HTTP implementation is built **on top of**.

**HTTP is NOT in this module** (decision 2026-06-02): HTTP is L7; the architecture
is `cx-stdlib/net` (L4) → `cx-stdlib/http` (L7) → connectors. The `cx-stdlib/http`
module is a **separate, not-yet-authored task** and is **not** a dependency of net's
graduation (rev-4 Low — the not-yet-existing `spec/std-lib/http.md` is referenced
informationally only).

Out of scope: HTTP semantics; resilience wrappers (`code.md` §10.2); worker/channel
concurrency (§10.4); general URL parsing (`cx-stdlib/url`); hex/base64
(`cx-stdlib/bytes`). **In scope:** the restricted transport-URL grammar net itself
parses (§2.2) and the UTF-8 stream text contract (§3.4).

`cx-stdlib/net` is **Tier-B runtime — necessarily impure**. Socket/resolver ops need
the `net` capability (§5) and may raise `CXER45xx` (§8). Pure, capability-free:
`parse-addr`, `addr-to-string`.

## §2. Conceptual model

### §2.1. Handles — opaque, single-owner, impure resources

Opaque elements wrapping an OS descriptor (as `cx-stdlib/io` models a file handle):
not pure values, excluded from structural sharing, single-owner move semantics
(transfer via `[?channel]`; concurrent use → `cx-err:CXER4516`). Each carries the
closeable contract (`on-close="net/close"`, `code.md` §8.10.7): `[?with-open]`-able;
`cx-err:CXER0108` never raised; closing an in-flight handle cancels and joins it.

```cx
[socket fd=7 transport="tcp" state="open"
  local=[addr host="10.0.0.4" port=51200 family="ipv4"]
  remote=[addr host="93.184.216.34" port=443 family="ipv4"]
  secure=true alpn="h2" on-close="net/close"]
[listener fd=6 transport="tcp" state="listening" backlog=128
  local=([addr host="127.0.0.1" port=8080 family="ipv4"]    ; multi-address bind →
         [addr host="::1" port=8080 family="ipv6"])           ; local is a sequence (§3.7/H6)
  surface-accept-errors=false on-close="net/close"]
[socket fd=9 transport="udp" state="bound"
  local=[addr host="0.0.0.0" port=9000 family="ipv4"] on-close="net/close"]
[listener fd=11 transport="dtls" state="listening"          ; DTLS server listener (§3.6a, H1)
  local=[addr host="0.0.0.0" port=8443 family="ipv4"] on-close="net/close"]
[socket fd=12 transport="dtls" state="open" secure=true     ; per-peer DTLS socket from accept
  local=[addr host="10.0.0.4" port=8443 family="ipv4"]
  remote=[addr host="203.0.113.7" port=51000 family="ipv4"] on-close="net/close"]
```

Stream `state` ∈ `"open"|"half-closed-read"|"half-closed-write"|"cancelled"|"consumed"|"closed"`;
stream **and DTLS** listener ∈ `"listening"|"closed"`; datagram ∈ `"bound"|"connected"|"cancelled"|"closed"`;
a **DTLS** socket (connected client *or* per-peer accepted) ∈ `"open"|"cancelled"|"consumed"|"closed"`
— a secured datagram socket, so **no half-close states** (H1).

### §2.2. Addresses + the restricted transport-URL grammar (rev-4 H7)

```cx
[addr host="::1" port=443 family="ipv6"]
[addr host="fe80::1" port=443 family="ipv6" zone="en0"]
[addr path="/run/db.sock" family="unix"]
```

`parse-addr` (pure) and `dial`/`listen` accept a **restricted transport URL**, NOT a
general URL (that is `cx-stdlib/url`'s job). Normative rules:

- Forms: `tcp://host:port`, `tls://host:port`, `udp://host:port`, `dtls://host:port`
  (DTLS-over-UDP, §3.6a), `unix:/abs/path`,
  `unix-abstract:NAME` (§5); a bare `host:port` (parse-addr only).
- **A port is MANDATORY** for `tcp`/`tls`/`udp`/`dtls`; absent → `cx-err:CXER4500`
  (net infers no scheme-default ports — that is L7's job).
- IPv6 literals **MUST** be bracketed (`tcp://[::1]:443`); zone IDs `[fe80::1%en0]`.
- **Userinfo (`user:pass@`), query (`?…`), and fragment (`#…`) are REJECTED** →
  `cx-err:CXER4500`.
- **Path component** is allowed **only** for `unix`/`unix-abstract`; a path on
  `tcp`/`tls`/`udp`/`dtls` → `cx-err:CXER4500`.
- Percent-encoding is decoded **only** in `unix:` paths; hostnames are not
  percent-decoded.
- Hostnames are preserved verbatim by `parse-addr`; **IDNA2008 A-label**
  normalisation happens at `resolve`.
- Empty host (`:port` / `tcp://:port`) is legal **only as a wildcard bind**
  (`listen`); `dial` to an empty host → `cx-err:CXER4500`.
- Numeric ports only in `parse-addr` (purity — no service-name lookup).

`addr-to-string` round-trips (`parse-addr(addr-to-string(a)) == a`): IPv6 per RFC 5952,
bracketed iff port present, `%zone` inside brackets, Unix paths `unix:PATH`
percent-encoded, **abstract-namespace sockets `unix-abstract:NAME`** (M3).

### §2.3. `dial`/`listen` scheme dispatch; transport-pinned aliases

`dial`/`listen` dispatch on scheme (table in §2.2). **Per-transport aliases are
transport-PINNED**: `dial-tcp`/`dial-tls`/`dial-udp`/`dial-dtls` (and the
`listen-*` mirrors) accept only their own scheme (or a bare `host:port` implying it)
and reject a mismatched scheme → `cx-err:CXER4501`; `dial-unix`/`listen-unix` take a
`unix:`/`unix-abstract:` path. Only `dial`/`listen` dispatch across schemes.

### §2.4. Two timeout mechanisms + cancellation (rev-4 B2 — admitted only)

1. **Socket deadline** (`set-deadline`/`connect-timeout`, §3.7) → returnable
   `cx-err:CXER4507 E_NET_TIMEOUT`; handle stays usable.
2. **Directive `[?timeout DURATION BODY [on-timeout EXPR]]`** issues cooperative
   `[?cancel]` and returns `cx-err:CXER0141`. When the cancel reaches an in-flight
   net op, the op **aborts at that cancellation point and surfaces the admitted
   `cx-err:CXER0260` (CANCELLED)**; the handle → `state="cancelled"` and MUST be
   `close`d (further ops → `cx-err:CXER4515`). **net specifies NO capability-
   revocation backstop** — that behavior is an in-review SAP §5.2 proposal, not
   admitted, so net does not assert it (rev-4 B2). `[?timeout]` does not mutate the
   socket deadline.

### §2.5. EOF, partial I/O, writes, "nothing found"

- **Stream EOF** = present empty value (empty `string`/`bytes`) + `is-eof`. `is-eof`
  returns `true` iff the **most recent read observed orderly end-of-stream**; it
  reads cached state, performs **no I/O, never blocks, consumes nothing**; `false`
  before the first read. `read-exact` short of `n` → `cx-err:CXER4509`.
- **Writes are all-or-raise with partial-send observability:** `write-bytes`/
  `write-string` return `null` after the whole payload flushes, or raise; a
  `CXER4507`/`CXER4508` raised mid-flush **MUST carry `bytes-written=N`**.
- **Optional "nothing found" reads return the empty node-set** (`remote-addr`
  unconnected; `peer-cert` no peer cert) — **net's declared API convention** (§0.2).
  These read **cached, already-known local handle state** (set at connect/handshake)
  — **no network I/O** — so a miss is an in-memory optional read, not `null` and not
  `[err]`. By contrast `resolve` no-record and `dial` failure are external/effectful
  faults → `[err]` (`CXER4502`/`CXER4505`).

## §3. Public function surface (one exact signature per function — rev-4 H4)

`::duration` is `cx-stdlib/time`; `::element` a handle/addr; `::map` options.

### §3.1. Resolution & addresses
```
[?def parse-addr   scope=public pure   [returns element]            ($s::string) ...]
[?def addr-to-string scope=public pure   [returns string]             ($a::element) ...]
[?def resolve      scope=public impure [returns [sequence element]] ($host::string $opts::map) ...]
```
`resolve` → RFC-6724-ordered `[addr]`s; `opts.family`/`opts.timeout`; `net` resource
`host`; no record → `cx-err:CXER4502`, timeout → `cx-err:CXER4503`.

### §3.2. Dial (client)
```
[?def dial      scope=public impure [returns element] ($url::string $opts::map) ...]
[?def dial-tcp  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def dial-tls  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def dial-udp  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def dial-dtls scope=public impure [returns element] ($url::string $opts::map) ...]
[?def dial-unix scope=public impure [returns element] ($path::string $opts::map) ...]
```
`opts`: `connect-timeout`/`read-deadline`/`write-deadline::duration`, `bind::element`
(local source addr — §5 gating), `nodelay::bool` (TCP, default `true`),
`keepalive::duration`, `tls::map` (§3.6). Missing port → `CXER4500`; unsupported/
mismatched scheme → `CXER4501`.

### §3.3. Listen / accept (server)
```
[?def listen      scope=public impure [returns element] ($url::string $opts::map) ...]
[?def listen-tcp  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def listen-tls  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def listen-udp  scope=public impure [returns element] ($url::string $opts::map) ...]
[?def listen-dtls scope=public impure [returns element] ($url::string $opts::map) ...]
[?def listen-unix scope=public impure [returns element] ($path::string $opts::map) ...]
[?def accept      scope=public impure [returns element]            ($listener::element) ...]
[?def accept-iter scope=public impure [returns [iterator element]] ($listener::element) ...]
```
`listen` `opts`: `backlog::int` (default 128, stream only), `reuse-addr::bool`
(default `true`), `reuse-port::bool` (default `false`), `tls::map`,
**`surface-accept-errors::bool` (default `false`) — a `listen` opt stored on the
listener (rev-4 H5)**, not an `accept-iter` arg.

**Multi-address bind (rev-4 H6).** A literal IP binds one address; a wildcard
(`0.0.0.0`/`[::]`) binds that family's wildcard; a **hostname** (e.g. `localhost`)
resolves locally and binds **all** resolved addresses. Binding is **atomic** (any
constituent failure → close all + raise `CXER4517`/`CXER4506`). The listener's
`local` attribute and `local-addr` (§3.7) are a **`[sequence element]` of `[addr]`**
(length ≥ 1). A bind hostname uses the local resolver and is **not** subject to the
§4.5 outbound SSRF guard (binding is local).

**`accept` handshake + failure (rev-4 H8/M6).** `accept` on `tcp://`/`unix:` returns
a raw `[socket]`; on `tls://` it performs the server handshake (listener's stored
config) before returning `secure=true`. A single failed `accept` returns that
connection's `[err]`. **`accept-iter`:**
- **per-connection** failures (handshake failure, `ECONNABORTED`, per-client reset)
  are **transient → recorded as an audit event (§5) and SKIPPED** (one hostile
  client must not kill the loop). With `surface-accept-errors=true` they are instead
  yielded as `[or socket err]`.
- **listener-level fatal** errors (`EBADF`/closed fd → `CXER4515`; resource
  exhaustion `EMFILE`/`ENFILE` → `CXER4518`; post-creation permission loss →
  `CXER4519`) **terminate the iterator by raising** that `[err]` — they are not
  skipped.
- the iterator otherwise terminates only when the listener is `close`d.

### §3.4. Stream I/O — mirrors `cx-stdlib/io`, extended; UTF-8 text contract
```
[?def read-bytes     scope=public impure [returns bytes]             ($sock::element $n::int) ...]
[?def read-exact     scope=public impure [returns bytes]             ($sock::element $n::int) ...]
[?def read-line      scope=public impure [returns string]            ($sock::element) ...]
[?def read-all       scope=public impure [returns string]            ($sock::element $opts::map) ...]
[?def read-all-bytes scope=public impure [returns bytes]             ($sock::element $opts::map) ...]
[?def write-bytes    scope=public impure [returns null]              ($sock::element $b::bytes) ...]
[?def write-string   scope=public impure [returns null]              ($sock::element $s::string) ...]
[?def write-line     scope=public impure [returns null]              ($sock::element $s::string) ...]
[?def flush          scope=public impure [returns null]              ($sock::element) ...]
[?def is-eof         scope=public impure [returns bool]              ($sock::element) ...]
[?def line-iter      scope=public impure [returns [iterator string]] ($sock::element) ...]
[?def chunk-iter     scope=public impure [returns [iterator bytes]]  ($sock::element $chunk::int) ...]
```
Mirrors io's stream verbs; extends with `read-exact` (fixed frame) + `chunk-iter`
(binary, cognate to io's `line-iter`). **Text contract:** `read-line`/`read-all`/
`write-string`/`write-line` are UTF-8; invalid UTF-8 on a read → `cx-err:CXER4523
E_NET_ENCODING_INVALID` (use the `*-bytes` verbs for binary). `read-line` strips a
trailing `\n`/`\r\n` and `write-line` appends a terminator per the socket's
**`line-terminator`** option (a stream-only `set-opt`, §3.7; default `"auto"`→LF;
rev-4 H4 — the option has a real surface, not a phantom param). `read-bytes` `n` ≥ 1 else `CXER4522`. `read-all*`
`opts.max-bytes` defaults **64 MiB**, never unbounded; over → `CXER4510`.

### §3.5. Datagram I/O (UDP / Unix-datagram)
```
[?def send-to   scope=public impure [returns int]     ($sock::element $data $to::element) ...]
[?def recv-from scope=public impure [returns element] ($sock::element $n::int) ...]
[?def send      scope=public impure [returns int]     ($sock::element $data) ...]
[?def recv      scope=public impure [returns bytes]   ($sock::element $n::int) ...]
```
`$data` is `bytes`/`string` (UTF-8). `recv-from` → `[datagram bytes=… from=[addr …]]`.
`send`/`recv` need a *connected* socket; `send` unconnected → `CXER4522`.
`recv-from`/`recv` `n` ≥ 1 else `CXER4522` (rev-4 M5). **Atomic + oversize:** a
datagram send is atomic; the `int` return is the datagram length; oversize →
`cx-err:CXER4524 E_NET_MSG_TOO_LARGE`. Received datagram > `n` → `cx-err:CXER4511`
(impl MUST use `recvmsg`/`MSG_TRUNC`; silent truncation non-conformant).
**`send-to` capability (rev-4 B1; Unix targets rev-4 B3):** because `$to` is
arbitrary, `send-to` is a **gated effect point** — it checks `net` against `$to`
**and** does **not** ride only the bind grant. The check depends on `$to`'s family:
- **UDP** (`$to` = `host:port`): `net` match on `$to` (program-supplied host **or**
  resolved IP, §4.5 step 1) **+** the §4.5 address guard/pin, exactly like `dial`.
- **Unix-datagram** (`$to` = a `unix:`/`unix-abstract:` target): `net` match on the
  canonicalized `unix:` path-glob (§5), **no SSRF guard** (local — there is no IP).

A bound-but-undialed UDP *or* unixgram socket therefore cannot reach a target the
program was not granted.

### §3.6. TLS — client + server upgrade
```
[?def tls-wrap   scope=public impure [returns element] ($sock::element $opts::map) ...]
[?def tls-accept scope=public impure [returns element] ($sock::element $opts::map) ...]
[?def peer-cert  scope=public impure [returns element] ($sock::element) ...]
[?def tls-info   scope=public impure [returns element] ($sock::element) ...]
```
`peer-cert` → `[cert …]` or the empty node-set (§2.5/§0.2). `tls-info` →
`[tls version=… cipher=… alpn=…]`. `tls-wrap`/`tls-accept` **consume** the underlying
socket (→ `state="consumed"`); the secure socket inherits `fd`/deadlines/options;
upgrade at a clean protocol boundary; handshake failure closes the underlying socket
+ raises `cx-err:CXER4512`.

**`tls::map`:** `verify` (default `true`; `false` = §5 audited per-call opt-out under
the `net` grant, no new cap); **`server-name` default (rev-4 M4):** for `dial-tls`
defaults to the **dialed hostname** (if dialed by IP, SNI is omitted and `verify`
matches against the IP SANs); for **`tls-wrap` it is REQUIRED when `verify=true`**
(no dialed host to infer) else `cx-err:CXER4514`. `ca` (PEM `bytes`/`[cert …]`/
sequence — never a path); `cert`/`key` (PEM `bytes`; server TLS REQUIRES both else
`CXER4514`); `require-client-cert` (mTLS; failure → `CXER4512`); `alpn`
(`[sequence string]`); `alpn-required` (default `false`; no common → `CXER4512`);
`min-version` (`"1.2"`|`"1.3"`); `pin` (SHA-256 of peer DER SPKI as 32 raw `bytes` or
lowercase 64-hex; sequence = any-match; mismatch → `cx-err:CXER4513`; additive to
verification, or instead when `verify=false`). **ALPN selection = SERVER preference**
(server picks the first of *its* list the client offered).

**TLS `shutdown` (rev-4 M5 — true half-close).** `shutdown "write"` sends a TLS
`close_notify` (this side sends no more application data) **but does NOT send the
underlying FIN**; **reads remain valid** until the peer's `close_notify`/EOF, so a
proper request/response half-close works and a peer MAY still send after our
`close_notify`. `shutdown "read"` stops further inbound application data;
`shutdown "both"` exchanges `close_notify` and tears down. The underlying FIN is sent
by `close`, not by `shutdown "write"`. (Plaintext streams use ordinary TCP/Unix
half-close.)

### §3.6a. DTLS — TLS over datagram (OQ3 = (b): included in v1)

DTLS (Datagram TLS — RFC 6347 for 1.2, RFC 9147 for 1.3) secures **datagram**
transport. Scheme `dtls://host:port`; aliases `dial-dtls`/`listen-dtls`. A DTLS
socket is a datagram socket with `transport="dtls" secure=true`.

**Delivery semantics (the defining property).** DTLS gives TLS *security*
(confidentiality, integrity, peer authentication, anti-replay) over *datagram*
*delivery*: **application records stay lossy, reorderable, and unordered** — DTLS
does **not** add stream reliability. Only the **handshake** is made reliable
(retransmission timers + handshake sequence numbers). A DTLS socket therefore uses
the **§3.5 datagram verbs** (`send`/`recv` on a connected DTLS socket; one `send` =
one DTLS record in one datagram) — the §3.4 stream verbs (`read-line`/`read-all`/
`line-iter`) are **N/A** (no stream).

**Client.** `dial 'dtls://host:port'` (or `dial-dtls`) = connected UDP + DTLS
handshake → `secure=true` datagram socket. Equivalently, **`tls-wrap` on a
*connected* datagram socket** performs the **client** DTLS handshake (the datagram
cognate of STARTTLS). The §3.6 `tls::map` is reused unchanged
(`verify`/`server-name`/`ca`/`cert`/`key`/`pin`/`alpn`); `min-version` selects DTLS
`"1.2"`/`"1.3"`.

**Server — `tls-accept` + a MANDATORY stateless cookie (anti-DoS; H3).** The
server-side DTLS handshake is performed by **`tls-accept` on a per-peer datagram
socket** (rev-4 H3 — this is the datagram counterpart of stream `tls-accept`, so the
§7 ✅ cell has a definition). It runs automatically inside `accept`/`accept-iter` on
a `dtls://` listener, or may be called explicitly on a peer socket obtained from a
plain `udp://` listener. Before allocating per-peer handshake state the server
**MUST** perform the **version-appropriate stateless cookie exchange (H2):** for
**DTLS 1.2** the RFC 6347 **HelloVerifyRequest**; for **DTLS 1.3** the RFC 9147
**cookie extension carried in a HelloRetryRequest**. This is required, not optional —
a connectionless server is otherwise trivially spoofing/amplification-DoS-able.
`accept` yields a per-peer `secure=true` datagram socket scoped to that source
address; `accept-iter` is resilient per §3.3 (a failed/cookie-less peer handshake is
skipped + audited).

**Fragmentation.** DTLS handshake messages may exceed the path MTU and are fragmented
across datagrams transparently. An *application* `send` exceeding the negotiated max
record / path MTU → `cx-err:CXER4524 E_NET_MSG_TOO_LARGE` (§3.5), unchanged.

**Errors reuse the TLS codes:** handshake/cookie failure → `cx-err:CXER4512`; pin
mismatch → `cx-err:CXER4513`; config (server cert/key; `tls-wrap` verify without
`server-name`) → `cx-err:CXER4514`. `tls-info` reports the DTLS version. No new band
entries. **DTLS-over-`unixgram` is justified-❌** (a Unix datagram socket is local and
filesystem-permission-gated — transport encryption is meaningless; §7 ¹⁰).

### §3.7. Lifecycle, deadlines, options, introspection
```
[?def close        scope=public impure [returns null]              ($handle::element) ...]
[?def shutdown     scope=public impure [returns null]              ($sock::element $dir::string) ...]
[?def set-deadline scope=public impure [returns null]              ($sock::element $opts::map) ...]
[?def set-opt      scope=public impure [returns null]              ($sock::element $opts::map) ...]
[?def local-addr   scope=public impure [returns [sequence element]] ($handle::element) ...]
[?def remote-addr  scope=public impure [returns element]           ($sock::element) ...]
[?def is-open      scope=public impure [returns bool]              ($handle::element) ...]
```
`close` idempotent. `shutdown` `$dir` ∈ `"read"|"write"|"both"` (§3.6 for TLS).
**`local-addr` returns a `[sequence element]`** of one-or-more `[addr]` (a connected
socket yields a singleton; a multi-address listener yields all bound addresses — H6).
**`remote-addr`** returns a single `[addr]` or the empty node-set if never connected.
**Both `local-addr` and `remote-addr` are allowed after `close`** — they return the
cached snapshot taken at connect/bind time (no I/O) and never raise `CXER4515`.
`set-deadline`: `read`/`write`/`both` (relative) or `read-at`/`write-at` (absolute);
zero/past ⇒ immediate `CXER4507`; `:none` clears; relative+absolute same direction →
`CXER4522`. **`set-opt` per-transport** (unsupported → `cx-err:CXER4521`):

| Option | tcp | tls | unix-stream | udp | unixgram | dtls |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| `nodelay` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `keepalive` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `linger` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `recv-buf`/`send-buf` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `broadcast`/`multicast-*` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `line-terminator` (rev-4 H4: `"auto"`/`"lf"`/`"crlf"`, stream-only; honored by `read-line`/`write-line`, §3.4) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |

## §4. Semantics & guarantees

§4.1 deny-by-default. §4.2 deadlines bounded by default (host finite default, rec.
30 s). §4.3 no silent truncation/short transfer. §4.4 Happy-Eyeballs (RFC 8305:
RFC-6724 order, 250 ms stagger, ≤2 concurrent, first wins + cancels others;
deterministic from resolver output; each attempt an audit event). §4.6 single-owner
(→ `CXER4516`). §4.7 handle quota = host resource limits (same class of bound as
`code.md` §13.7 depth limit); over → `CXER4518`.

### §4.5. SSRF / DNS-rebinding guard — mandatory, canonicalized, admitted-grant override
Two checks for every **outbound** connect (`dial*`) and **every `send-to`** (rev-4
B1): **(1) capability match** — the `net` grant must match **either** the
program-supplied `host:port` **or** a resolved candidate `IP:port` (**rev-4 B2: this
is what makes a literal-IP grant usable for a *hostname* dial** —
`--allow-net=10.0.0.5:5432` authorizes `dial 'tcp://db.internal:5432'` when
`db.internal` resolves to `10.0.0.5`); absent both → `CXER0271`. **(2) address
guard** after resolution (below). Step 1's resolved-IP match does **not** by itself
bypass the deny set — step 2's override still requires a *literal-IP* (or `localhost`)
grant, so a hostname grant cannot reach a denied range.

**Canonicalization first (rev-4 M8):** each resolved candidate is normalized before
classification — IPv4-mapped/compatible IPv6 (`::ffff:a.b.c.d`) is unwrapped to the
embedded IPv4, zone IDs stripped, textual variants normalized — so
`::ffff:169.254.169.254` classifies as `169.254.169.254`.

**Mandatory default deny set (rev-4 H1 — empty list is non-conformant):** loopback
`127.0.0.0/8`,`::1`; link-local `169.254.0.0/16` (incl. metadata `169.254.169.254`),
`fe80::/10`; **private `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`**; **CGNAT
`100.64.0.0/10`**; ULA `fc00::/7`; this-host `0.0.0.0`/`::` as a destination. A
denied candidate → `cx-err:CXER4504 E_NET_FORBIDDEN_ADDRESS`.

**Override uses ONLY admitted host:port / host-glob grants — no "range grant"
grammar is introduced (rev-4 H2/H3):** the deny is bypassed for a candidate **iff**
the program-supplied `net` grant's host is (i) a **literal IP equal to the
candidate** (e.g. `--allow-net=10.0.0.5:5432` or `--allow-net=127.0.0.1:5432`), or
(ii) **`localhost`**, which explicitly authorizes the loopback addresses it resolves
to (rev-4 H3 — `--allow-net=localhost:5432` reaches loopback by design; fixtured). A
**hostname** grant whose name resolves into a denied range is **still denied** (so a
`--allow-net=api.example.com:443` grant cannot be rebound to `10.0.0.5` or the
metadata endpoint — the rebinding defense). Reaching an internal service *by
hostname* therefore requires granting its **literal IP**; this is the secure default
and uses only admitted grant grammar. The chosen candidate is **pinned** for the
connection lifetime. Hosts MAY extend (never empty) the deny set.

## §5. Capability integration

Gated by the admitted **`net`** capability (`security.md` §2–§4: host:port /
host-glob).

| Operation | Capability | Resource matched |
|---|---|---|
| `resolve` | `net` | `host` |
| `dial*` | `net` | program-supplied `host:port` **or** resolved `IP:port` (§4.5 step 1) + §4.5 guard/pin |
| **`send-to`** (UDP) | **`net`** | **`$to` `host:port` (program host or resolved IP) + §4.5 guard (rev-4 B1)** |
| **`send-to`** (unixgram) | **`net`** | **`$to` canonical `unix:`/`unix-abstract:` path-glob; no SSRF (rev-4 B3)** |
| `dial*` with `bind` local addr/port | `net` | **also** the bind `host:port` if it pins a specific local address or a port < 1024 (rev-4 M1); an ephemeral default-interface bind needs no extra grant |
| `listen*` | `net` | bind `host:port` (wildcard rules below) |
| `accept*`, connected `send`/`recv`, stream I/O, `set-*`, `tls-*`, `shutdown` | — | inherit the handle grant (the target was checked at `dial`/`send-to`/`listen`) |
| `close`, `is-open`, `local-addr`, `remote-addr`, `parse-addr`, `addr-to-string` | — | none |

Denial → `cx-err:CXER0271` naming grant + resource, e.g.
`[err code=cx-err:CXER0271 capability=net resource='10.0.0.5:9000']`.

**Listen wildcard grants:** `0.0.0.0:8080`/`[::]:8080` ⇒ `0.0.0.0:8080`/`*:8080`/
`:8080`; `127.0.0.1:8080` ⇒ `127.0.0.1:8080`/`localhost:8080`; `0.0.0.0:0` ⇒
`0.0.0.0:0`/`*:0` (selected port in `local-addr`).

**Unix grants + stale-socket confirmation (rev-4 H4/M7).** Filesystem Unix sockets
are gated by `net` `unix:` path-glob; the matched path is **fully resolved, canonical,
absolute** (relative→CWD; `..`/symlinks resolved **before** matching, so
`unix:/run/../etc/x` cannot bypass `unix:/run/*`). Abstract-namespace sockets use
`unix-abstract:NAME` (no filesystem node; matched literally). **Stale-socket unlink
under `reuse-addr=true` — exact test:** (1) `lstat` the path **without following
symlinks**; it MUST be a socket node (`S_ISSOCK`) — a regular file/dir/symlink →
`cx-err:CXER4517` (never unlinked); (2) attempt `connect()` — success ⇒ **live** →
`CXER4517`; failure with `ECONNREFUSED` ⇒ **stale** → unlink (still no-follow) and
rebind; any other `connect` error → `CXER4517`. The lstat→connect→unlink sequence
holds no TOCTOU guarantee beyond the no-follow + `S_ISSOCK` checks; a concurrent
racer that wins the rebind surfaces `CXER4517`.

**Unix/`unix-abstract` resource-grammar extension** (`host:port | host-glob |
unix:path-glob | unix-abstract:name-glob`) **needs a one-line `security.md` §2
confirmation at graduation** (checklist).

**`verify=false` audit event — self-contained shape (rev-4 M2).** A `verify=false`
TLS dial MUST emit:
```cx
[audit kind="tls-insecure" capability="net" resource="HOST:PORT"
       server-name="…" reason="verify-disabled"]
```
Required fields: `kind`, `capability`, `resource`, `server-name`. It is emitted to
the evaluation's audit/trace stream — the same stream `security.md` §4/§5 references
for capability grant/deny events — and is correlated with that stream, not a separate
sink. Because `security.md` does not yet fix an audit-event *schema*, the §11
checklist carries an item to **formalize the audit-event mechanism in `security.md`
at graduation**; until then this self-contained shape is normative for net.

**Cancellation:** a cancelled net op at a cancellation point reports the admitted
`cx-err:CXER0260` (§2.4); net asserts no unadmitted cap-revocation behavior.

## §6. Composition (admitted directives only)

```cx
[?retry max=3 backoff=exponential
  [?timeout 5s
    [$net:dial-tls 'tls://db.internal:5432' [tls [alpn ('pg')]]]]]
```
```cx
[?match [$net:dial-tcp 'tcp://db:5432' {}]
  [case [err @code='cx-err:CXER4505'] [$log:warn 'refused']]
  [case [err @code=$c] [err code=$c]]
  [case $sock $sock]]
```
Resilience (`§10.2`) wraps net calls (`[?timeout]` cancels → `cx-err:CXER0260`,
surfacing `cx-err:CXER0141`; `[?retry]` re-invokes). Recovery is `[?match]`/
`[?fallback]` (never `[?try]`). Servers: `[?http-service]` refactors onto
`[$net:listen 'tcp://0.0.0.0:8080']` + `accept-iter`; directive codes
`cx-err:CXER0160–0182` map onto net's `45xx` as a façade (§8). Concurrency:
`[?for [in $conn [$net:accept-iter $l]]]` → `[?worker]` over a `[?channel]`.
`[?with-open]` auto-closes via `on-close="net/close"`.

## §7. Applicability matrix

(Carries the per-feature applicability matrix the in-review orthogonality guard
— `spec-authoring-guide.md` §3 / SAP §0.2, **both candidate/awaiting-G3** — will
require; net provides it now as good practice, not because that gate is yet binding,
per rev-4's independence stance.)

| Operation | tcp | tls | unix-stream | udp | unixgram | **dtls** |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| `dial` | ✅ | ✅ | ✅ ᵖ | ✅ | ✅ ᵠ | ✅ |
| `listen` | ✅ | ✅ | ✅ ᵖ | ✅ | ✅ ᵠ | ✅ |
| `accept`/`accept-iter` | ✅ | ✅ | ✅ ᵖ | — ¹ | — ¹ | ✅ ¹¹ |
| stream read/write/`is-eof`/`line-iter`/`chunk-iter` | ✅ | ✅ | ✅ ᵖ | — ² | — ² | — ² |
| `send-to`/`recv-from`/`send`/`recv` | — ³ | — ³ | — ³ | ✅ | ✅ ᵠ | ✅ ¹² |
| `shutdown` | ✅ | ✅ ⁹ | ✅ ᵖ | — ⁴ | — ⁴ | — ⁴ |
| `tls-wrap`/`tls-accept`/`peer-cert`/`tls-info` | ✅ ⁵ | — ⁶ | ✅ ⁵ ᵖ | ✅ ⁷ | ❌ ¹⁰ | — ⁶ |
| `set-deadline`/`set-opt`/`local-addr`/`close`/`is-open` | ✅ | ✅ | ✅ ᵖ | ✅ | ✅ ᵠ | ✅ |
| `remote-addr` | ✅ | ✅ | ✅ ᵖ | ✅ ⁸ | ✅ ⁸ ᵠ | ✅ |

Platform: **ᵖ** Unix-stream ✅ POSIX + Windows 10 (1803)+, ❌ older Windows. **ᵠ**
Unix-datagram ✅ POSIX, ❌ Windows. 1 connectionless. 2 stream verbs N/A on datagrams.
3 datagram verbs N/A on streams. 4 half-close N/A connectionless. 5 upgradable via
`tls-wrap`. 6 already secured. 7 UDP TLS = **DTLS 1.2/1.3** (§3.6a). 8 connected→peer
addr; unconnected→empty node-set. 9 TLS `shutdown`=`close_notify` half-close (§3.6).
10 Unix-datagram is local + filesystem-gated → transport encryption meaningless, so
DTLS-over-`unixgram` is justified-❌. 11 DTLS `accept` runs the server cookie +
handshake (§3.6a). 12 a DTLS socket is per-peer **connected** → uses `send`/`recv`;
`send-to`/`recv-from` (arbitrary-peer) are N/A. The **dtls** column is the
`transport="dtls"` socket (already-secured datagram); its `tls-wrap`/`tls-accept`
cell is — ⁶ (already secured), while the **udp** column's ✅⁷ is the *upgrade* path
(`tls-wrap` a connected UDP socket → DTLS), mirroring tcp ✅⁵ vs tls — ⁶.
Asymmetries (DTLS-over-unixgram ❌¹⁰, Windows
unixgram ❌ᵠ) justified + fixture-pinned.

## §8. Error codes — `CXER4500–CXER4524` band

`4500–4599` is the next free block above the highest current allocation
(`cx-stdlib/fp` owns `4400–4409`; `module-tree-sitter` `4300–4309`). The rev-7
draft's `4400`-band rested on a stale registry read ("registry stops `4300–4309`")
made before `fp` landed at `4400`; net is reallocated `4500–4524` to avoid the
collision (governance §9.6, [SPEC-FINDINGS]). 1:1 symbolic↔wire.
**Notation:** `cx-err:CXERnnnn` is authoritative — required in this table, every
`[err code=…]`, and every fixture assertion; bare `CXERnnnn` is allowed shorthand in
prose (admitted-corpus practice). **Cancellation is core `cx-err:CXER0260`.**

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4500` | `E_NET_ADDR_INVALID` | malformed/restricted-URL violation; missing required port; userinfo/query/fragment/path-misuse |
| `cx-err:CXER4501` | `E_NET_SCHEME_UNSUPPORTED` | unsupported/mismatched scheme (incl. pinned-alias mismatch) |
| `cx-err:CXER4502` | `E_NET_RESOLVE_NXDOMAIN` | name does not resolve |
| `cx-err:CXER4503` | `E_NET_RESOLVE_TIMEOUT` | resolver timed out |
| `cx-err:CXER4504` | `E_NET_FORBIDDEN_ADDRESS` | resolved IP in the mandatory deny set (§4.5) — `dial*` or `send-to` |
| `cx-err:CXER4505` | `E_NET_CONNECT_REFUSED` | peer refused |
| `cx-err:CXER4506` | `E_NET_UNREACHABLE` | network/host unreachable |
| `cx-err:CXER4507` | `E_NET_TIMEOUT` | socket deadline lapsed (carries `bytes-written` on a write) |
| `cx-err:CXER4508` | `E_NET_RESET` | reset mid-stream (carries `bytes-written` on a write) |
| `cx-err:CXER4509` | `E_NET_UNEXPECTED_EOF` | `read-exact` EOF before `n` |
| `cx-err:CXER4510` | `E_NET_LIMIT_EXCEEDED` | `read-all*` over `max-bytes` |
| `cx-err:CXER4511` | `E_NET_DATAGRAM_TRUNCATED` | datagram larger than buffer |
| `cx-err:CXER4512` | `E_NET_TLS_HANDSHAKE_FAILED` | handshake (chain/hostname/version/cipher/ALPN/client-cert/missing server-name) |
| `cx-err:CXER4513` | `E_NET_TLS_PIN_MISMATCH` | SPKI pin mismatch |
| `cx-err:CXER4514` | `E_NET_TLS_CONFIG` | server TLS missing/invalid cert/key; `tls-wrap` verify w/o server-name; malformed `tls::map` |
| `cx-err:CXER4515` | `E_NET_HANDLE_CLOSED` | op on closed/consumed handle (NOT idempotent `close`; NOT `local-addr`/`remote-addr`) |
| `cx-err:CXER4516` | `E_NET_HANDLE_RACE` | concurrent/non-owner handle use |
| `cx-err:CXER4517` | `E_NET_ADDR_IN_USE` | `listen` on a bound address / live or non-socket path |
| `cx-err:CXER4518` | `E_NET_TOO_MANY_HANDLES` | handle quota / resource exhaustion |
| `cx-err:CXER4519` | `E_NET_PERMISSION` | OS permission (bind port < 1024; post-creation loss) |
| `cx-err:CXER4520` | `E_NET_AF_UNSUPPORTED` | address family unsupported on platform |
| `cx-err:CXER4521` | `E_NET_OPT_INVALID` | `set-opt` unsupported for the transport (§3.7) |
| `cx-err:CXER4522` | `E_NET_ARG_INVALID` | `n ≤ 0`; ambiguous deadline; `accept`/`send` on wrong socket kind |
| `cx-err:CXER4523` | `E_NET_ENCODING_INVALID` | invalid UTF-8 on a text read |
| `cx-err:CXER4524` | `E_NET_MSG_TOO_LARGE` | datagram exceeds path/socket maximum |

Shared/core: `cx-err:CXER0271` (cap denial incl. `send-to`/`bind`), `cx-err:CXER0260`
(cancellation), `cx-err:CXER0105` (single-use iterator re-walk), `cx-err:CXER0108`
(never raised). Directive façade: `CXER0180`→`4505`, `CXER0181`→`4512`; directive
`[?timeout]` `CXER0141` ≠ socket `CXER4507`.

## §9. Implementation notes (non-normative) — leveraging & enhancing V

V `net`: `dial_tcp`/`listen_tcp`/`accept`/`TcpConn` (deadlines; surface bytes-written
+ EOF-as-present-empty); `net.unix` (Windows AF_UNIX for §7 ᵖ; path canonicalization
+ `S_ISSOCK`/no-follow stale-socket test + abstract namespace); `dial_udp`/
`listen_udp`/`write_to` (**`recvmsg`/`MSG_TRUNC`** for §3.5; per-`send-to` cap+SSRF
check; oversize→`CXER4524`); TLS `net.ssl`/`net.mbedtls` (**highest-risk:** hostname
verify, SNI/`server-name` defaulting, ALPN **server-preference**, mTLS, SPKI pin,
min-version, consume-and-inherit-fd, half-close `close_notify` — harden or vendor
rustls/BoringSSL); **DTLS (§3.6a) needs the OpenSSL or mbedTLS DTLS APIs +
HelloVerifyRequest cookie machinery — `rustls` does NOT implement DTLS, so the rustls
fallback covers stream TLS only**; `resolve_addrs`/getaddrinfo (RFC 8305 staggering).
Net-new
CX-layer: SSRF canonicalize+deny+pin, `send-to` gating, audit emission, cancellation
observation (→ `CXER0260`). `vcx/code/services_listener_*` SHOULD refactor onto
`listen`/`accept-iter`.

## §10. Conformance fixtures (to author on graduation)

Hermetic, loopback-only. **Positives:** stream round-trip; `read-line` empty-at-EOF +
`is-eof`; TLS half-close (`shutdown "write"` then peer still sends, reads still
valid); UDP + (POSIX) unixgram round-trip; TLS handshake + mTLS + ALPN
(server-preference) + SPKI pin; **DTLS round-trip (`dial-dtls` → send/recv records);
DTLS handshake; DTLS server mandatory HelloVerifyRequest cookie; DTLS app-data loss
tolerated (a dropped record does not fault the socket);** `dial-tls` server-name
defaulting + `tls-wrap` requires server-name; `--allow-net` happy path; ephemeral `0.0.0.0:0` →`local-addr`
port; `localhost` dual-stack bind (v4+v6) → `local-addr` is a 2-element sequence;
**`--allow-net=localhost:5432` dials loopback (deny-override, rev-4 H3)**;
`remote-addr`/`peer-cert` empty-node-set when none; `local-addr` after `close` returns
cached. **Negatives:** no `net` grant → `CXER0271`; Unix w/o `unix:` grant →
`CXER0271`; `unix:/run/../x` vs `unix:/run/*` → `CXER0271`; **UDP `send-to` without a
target grant → `CXER0271` (rev-4 B1/L3)**; **`send-to` to a mandatory-deny address →
`CXER4504`; explicit literal-IP override `send-to` succeeds (rev-4 L3)**; SSRF rebind
to `10.0.0.5`/`::ffff:169.254.169.254` (mock resolver) → `CXER4504` (incl. the
canonicalization case); hostname grant resolving into a private range → `CXER4504`;
missing port → `CXER4500`; userinfo/query/fragment URL → `CXER4500`;
`dial-tcp 'tls://…'` → `CXER4501`; `read-exact` short → `CXER4509`; `n=0` reads →
`CXER4522`; invalid UTF-8 `read-line` → `CXER4523`; unconnected UDP `send` →
`CXER4522`; oversize datagram → `CXER4524`; oversize recv → `CXER4511`; server TLS
missing cert/key → `CXER4514`; `tls-wrap` verify w/o server-name → `CXER4514`; pin
mismatch → `CXER4513`; `set-opt nodelay` on UDP → `CXER4521`; deadline → `CXER4507`
(asserts `bytes-written`); `[?timeout]` cancellation → inner `CXER0260`, outer
`CXER0141`, `state="cancelled"`; handle race → `CXER4516`; non-socket / live stale
path `listen` → `CXER4517`; `accept-iter` continues past a per-client handshake fail
but **terminates on a listener-level fatal** (`EMFILE`→`CXER4518`); Windows unixgram ❌
+ DTLS-over-`unixgram` ❌ skip-with-rationale; **DTLS server without the
version-appropriate cookie (HelloVerifyRequest / RFC 9147) → non-conformant**
(a cookie-bypass negative).

## §11. Graduation checklist (independent of the in-review SAPs)

- [ ] Governance registry: add `CXER4500–CXER4524 | cx-stdlib/net | spec/std-lib/net.md`; re-run band scan.
- [ ] Module index + count: `net` is **+1** at graduation. Baseline is in flux —
      README §3 = 29 (no `http`), skeleton test = 30 (incl. spec-less `http`),
      in-review `fp.md` also +1. Add `'cx-stdlib/net'` to the skeleton `expected` +
      bump the assert; add the README §3 Tier-B row. **ADDED, nothing replaced.**
- [ ] `cx-stdlib/http` is a **separate task** (spec on net or de-bundle); NOT a net
      graduation dependency. The README(29)/skeleton(30) `http` discrepancy is owned
      there.
- [ ] Confirm the `net` resource-grammar `unix:`/`unix-abstract:` extension in
      `security.md` §2 (user/G3).
- [ ] **Formalize the audit-event mechanism in `security.md`** (shape/required
      fields/stream) so §5's `[audit kind="tls-insecure" …]` rests on an admitted
      schema (rev-4 M2). Until then net's self-contained shape is normative.
- [ ] Implement `stdlib/net.cx` + V primitives (§9).
- [ ] Author §10 fixtures; wire into the gate.
- [ ] Refactor `services_listener_*` onto `net.listen`/`accept-iter` (or tracked follow-up).
- [ ] Validate repo-relative cross-references render.
- [ ] (non-blocking) If the in-review SAPs land, enrich §2/§6 framing; net does not wait.
- [ ] Move to `spec/std-lib/net.md` (user-only).

---

### Open questions — RESOLVED (labeled, decided 2026-06-02)
1. **TLS-insecure gating — DECIDED (a):** under the `net` grant, audited (§5), no new capability.
2. **Module naming — DECIDED (a), 2026-06-02:** single `cx-stdlib/net` umbrella for
   tcp/udp/unix/tls/**dtls** — one capability, one cognate surface.
3. **DTLS — DECIDED (b) include in v1, 2026-06-02:** DTLS-over-UDP is specified in
   §3.6a (client `dial-dtls` / `tls-wrap`-on-connected-datagram; server with the
   mandatory HelloVerifyRequest cookie), reusing the §3.6 `tls::map` config + the TLS
   error codes. DTLS-over-`unixgram` remains justified-❌ (local + filesystem-gated).
4. **HTTP placement — answered:** its own `cx-stdlib/http` on net, not folded in (§1).
5. **SSRF internal-hostname ergonomics — DECIDED (a), 2026-06-02.** Secure default:
   a hostname resolving into a denied/private range is denied; reaching an internal
   service requires granting its **literal IP** (`--allow-net=10.0.0.5:5432`). This
   is the normative §4.5 behavior — uses only admitted host:port grammar, fully
   closes DNS-rebinding, no host-policy allowlist. *(Rejected: (b) trusted-hostname
   allowlist — reintroduces host policy; (c) exempt RFC1918 — the rev-4 H1
   regression.)*
