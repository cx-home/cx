# XSP — the XAP Stream Protocol (frame format, v1)

**Status:** Current (graduated to `03-approved` from `02-working`; the `cx-stdlib/xsp`
frame codec is shipped + conformance-tested). Resolves the **frame layer** of issue
**#31** (RFC: XAP Stream Protocol). Defines the self-describing XSP frame and its v1
transport bindings; multiplexing/backpressure/heartbeat/reconnect-resume and the
WebSocket/WebTransport bindings are scoped here but deferred to follow-ups.

> XSP is **not** XAP. XAP is the experience paradigm (the cascade, surfaces,
> trust — [`xap.md`](xap.md)). **XSP is the streaming wire
> protocol that carries XAP**: a self-describing frame + transport bindings.
> Layering: net → http → directives → xap; XSP is the framed transport beneath
> XAP's semantics.

---

## §1. Design verdict (resolving #31's open decision)

#31 asks where the framing/multiplexing plumbing lives: **(a)** a reusable
CX-level framed-stream primitive with XAP semantics on top, or **(b)** bake the
whole protocol into XAP. **Verdict: (a), realized as a dedicated `cx-stdlib/xsp`
module.** The frame is self-delimiting and transport-agnostic (a reusable
length-delimited framing primitive); the *meaning* of the `type` enum and the
`principal` DID is XAP's. For v1 both live in the one `xsp` module — the frame
codec is generic enough to reuse, and a premature split would add a layer with
no second consumer yet. The payload is opaque bytes; the canonical encoding is
**CX `data-bin`** (we dogfood our own binary codec, [`codec.md`](../core/codec.md)).

## §2. The frame — self-describing, self-delimiting

One frame, **network byte order (big-endian)**:

```
 offset  size   field          notes
 0       1      version        0x01 (XSP/1) — self-describing; future versions add fields
 1       1      type           1 request · 2 event · 3 reply · 4 cancel · 5 ping · 6 pong · 7 error
 2       8      stream-id      u64 — logical multiplexing of many exchanges over one connection
 10      1      flags          bit0 payload-binary (1=CX data-bin, 0=UTF-8 text)
                               bit1 end-of-stream (last frame for this stream-id)
                               bits2-7 reserved (MUST be 0 in v1)
 11      2      principal-len  u16 — length of the principal DID bytes (0 = anonymous)
 13      P      principal      UTF-8 DID string, e.g. "did:key:z6Mk…" (the §22.1 principal)
 13+P    4      payload-len    u32 — payload length (ceiling 2^32-1)
 17+P    L      payload        L bytes — CX data-bin (binary) or UTF-8 text per flags bit0
```

- **Header = `17 + P` bytes.** The two length prefixes (`principal-len`,
  `payload-len`) make the frame **self-delimiting**, so the *same* frame rides
  byte-stream transports (TCP/TLS/Unix — no message boundaries) and
  message-oriented ones (WebSocket/WebTransport) unchanged.
- **`version`** makes the frame self-describing and forward-compatible: a v2 may
  append fields; a v1 decoder rejects an unknown version (`CXER-XSP-VERSION`)
  rather than misparsing — future-proofing by construction.
- **`type`** is the XAP frame semantics (request/event/reply/cancel +
  ping/pong/error for liveness). `event` carries a committed cascade event;
  `request` carries an intent (`[do …]`); `reply` carries its outcome; `cancel`
  aborts a stream; `error` carries a failure-channel value.
- **`principal`** references the DID (#26 / xap.md §22.1). Identity is
  **orthogonal to transport**: the frame names *who*, verification (proof of key
  control, `did/verify-control`) and authorization (VCs ↔ §22.2 capabilities)
  are separate handshake/PEP concerns, not in the frame.
- **`payload`** is opaque bytes. Binary payloads are **CX `data-bin`** (a CX
  value round-trips losslessly); text payloads are UTF-8 (for text-only
  transports / human-readable streams).

## §3. CX surface (`cx-stdlib/xsp`)

The frame as CX data — symmetric encode/decode (decode produces exactly what
encode consumes, plus a `consumed` attr):

```cx
[frame type=event stream=7 principal="did:key:z6Mk…" eos=false binary=true
  [payload <any CX value>]]
```

| Function | Effect | Result |
|---|---|---|
| `[$xsp:encode FRAME]` | pure | `bytes` — the wire frame. `binary=true` (default) data-bin-encodes the `[payload]` child's value; `binary=false` encodes its text scalar as UTF-8. |
| `[$xsp:decode BYTES]` | pure | a `[frame …]` element with attrs (`version type stream principal eos binary consumed`) and a `[payload]` child holding the decoded CX value (binary) or text string. `consumed` = total frame length, so a reader can pull the next frame at `BYTES[consumed..]`. |
| `[$xsp:decode-all BYTES]` | pure | a `[frames …]` element whose children are the parsed `[frame …]` elements (the byte-stream-transport reader) — navigable as `$fs//frame`, `[$count $fs]`, `[?for [in $f $fs]]`. Trailing partial bytes appear as a `[remainder …]` child. |

Attrs default: `type` required; `stream` = 0; `principal` = "" (anonymous);
`eos` = false; `binary` = true. Errors are failure-channel values (`[err …]`),
per the SAP §1 / stdlib §5 model.

**Error codes** (`CXER-XSP-*`, symbolic — matching the trust-stack style):
`CXER-XSP-VERSION` (unknown version), `CXER-XSP-TRUNCATED` (buffer shorter than
the frame declares), `CXER-XSP-TYPE` (unknown type), `CXER-XSP-LENGTH` (payload
exceeds the 2^32-1 ceiling), `CXER-XSP-PAYLOAD` (data-bin payload fails to
parse).

## §4. Transport bindings (same frame, different carriers)

| Binding | Use | v1 status |
|---|---|---|
| **SSE (server→client) + POST (client→server)** | **web client v1** | **the v1 binding** (§4.1) — `http` has SSE today; no WebSocket needed |
| **Raw TCP/TLS (+ Unix)** | native/TUI/local, max performance | buildable now (net stack is real) — follow-up |
| **WebSocket (wss)** | universal bidi over 443 | deferred — `http` WS upgrade is out of scope today (#31) |
| **WebTransport (HTTP/3)** | future best (no head-of-line blocking) | deferred — drop-in third binding, no frame change |

### §4.1. The v1 web binding — SSE + POST

The web client (xap.md §23) speaks XSP over the transports `cx-stdlib/http`
already has:

- **server → client: SSE.** Each cascade event becomes an XSP `event` frame.
  SSE is a **text** medium, so the frame bytes are **base64**-encoded into the
  SSE `data:` field (one frame per SSE event). The client base64-decodes and
  `[$xsp:decode]`s.
- **client → server: POST.** Each user/agent intent is an XSP `request` frame in
  the POST body (raw bytes, or base64 for text-only intermediaries). The server
  `[$xsp:decode]`s, maps `principal` → session, and emits the intent into the
  cascade.

This is **asymmetric** (server-push stream + per-intent upstream POST) — exactly
the shape SSE+POST fits, and the marine surface's actual traffic profile (a
high-rate event stream down, occasional intents up). #31 rejected SSE+POST as
the *general* XSP transport (it is one-way + text + a round-trip per upstream
message); it remains the correct **v1 web binding** until the WebSocket binding
lands, at which point the *same frames* switch carriers with no client logic
change above the transport adapter.

## §5. Deferred (scoped, not yet specified)

- **Multiplexing** beyond the `stream-id` field (per-stream flow/ordering).
- **Backpressure / flow control** (credit-based windows).
- **Heartbeat / liveness** (`ping`/`pong` cadence + timeout).
- **Reconnect-resume** (per-stream sequence numbers + replay-from-offset; ties
  to the journal fold, xap.md §16/§22.6).
- **WebSocket & WebTransport bindings**.
- **Cross-runtime VC revocation propagation** (vc.md §5 3b) rides the same
  server↔server channel once defined.

## §6. Cross-references

- Issue #31 (this RFC); #26 (did/vc — the `principal` field's identity).
- [`xap.md`](xap.md) §16 (clients), §22.1 (identity/DID),
  §23 (web client), §24 (SSE/streaming prerequisite).
- [`core/codec.md`](../core/codec.md) — the `data-bin` payload codec.
- [`std-lib/did.md`](../std-lib/did.md), [`std-lib/http.md`](../std-lib/http.md).
