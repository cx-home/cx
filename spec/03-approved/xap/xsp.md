# XSP — frame + session layer (v1) and the profile model

**Status:** Current (graduated to `03-approved` from `02-working`; the `cx-stdlib/xsp`
frame codec is shipped + conformance-tested). Resolves the **frame layer** of issue
**#31** (RFC: XAP Stream Protocol). Defines the self-describing XSP frame, its v1
transport bindings, the **§5 session layer** (heartbeat/liveness, credit flow
control, reconnect-resume — the #560 adoption, 2026-07-22), and — since the
stream-4 split (#676, the #651/#516 partition campaign) — the **§6 profile
model**: this document is the GENERIC layer (frame v1 unchanged, session
mechanics), and everything protocol-specific (payload verb vocabularies,
semantic feature tokens, error rows) lives in a **profile**. Multiplexing
beyond per-stream credit and the WebSocket/WebTransport bindings remain
deferred (§5.4).

> XSP is **not** XAP. XAP is the experience paradigm (the cascade, surfaces,
> trust — [`xap.md`](xap.md)). **XSP is the streaming wire protocol**: a
> self-describing frame + transport bindings + session mechanics. What the
> payloads MEAN belongs to the negotiated **profile** (§6) — the XAP profile
> carries XAP's semantics; the store profile is the store wire. Layering:
> net → http → directives → profile semantics; XSP is the framed transport
> beneath them.

---

## §1. Design verdict (resolving #31's open decision)

#31 asks where the framing/multiplexing plumbing lives: **(a)** a reusable
CX-level framed-stream primitive with XAP semantics on top, or **(b)** bake the
whole protocol into XAP. **Verdict: (a), realized as a dedicated `cx-stdlib/xsp`
module.** The frame is self-delimiting and transport-agnostic (a reusable
length-delimited framing primitive); the *meaning* of a `request`/`reply`/
`event` payload belongs to the negotiated profile (§6). The original caveat —
"a premature split would add a layer with no second consumer yet" — resolved
itself at stream 4 (#676): the store profile IS the second consumer, and the
generic/profile split this section anticipated is now normative. The payload
is opaque bytes; the canonical binary encoding is **CX `data-bin`**
(we dogfood our own binary codec, [`codec.md`](../core/codec.md)); profiles
rule which lane each payload role rides (the store profile's lanes-by-role
ruling is the template).

## §2. The frame — self-describing, self-delimiting

One frame, **network byte order (big-endian)**:

```
 offset  size   field          notes
 0       1      version        0x01 (XSP/1) — self-describing; future versions add fields
 1       1      type           1 request · 2 event · 3 reply · 4 cancel · 5 ping · 6 pong · 7 error · 8 credit (§5.2, negotiated-only)
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
  append fields; a v1 decoder rejects an unknown version (`CXER5000
  E_XSP_VERSION`) rather than misparsing — future-proofing by construction.
  The same posture governs the reserved flag bits: a v1 decoder REJECTS a
  frame with any of bits 2–7 set (`CXER5005 E_XSP_FLAGS`) — a future flag
  must be negotiated (§5.0), and silently tolerating unknown bits would make
  that negotiation unenforceable.
- **`type`** is the generic exchange grammar (request/event/reply/cancel +
  ping/pong/error for liveness, credit when negotiated). What a payload MEANS
  is the profile's (§6): under the **XAP profile** `event` carries a committed
  cascade event and `request` carries an intent (`[do …]`); under the **store
  profile** `request`/`reply` carry store verbs and `event` carries
  credit-governed result/∂ streams. Generic invariants hold everywhere:
  `reply` answers the `request` on its stream-id; `cancel` aborts a stream;
  `error` carries a failure-channel value.
- **`principal`** references the DID (#26 / xap.md §22.1). Identity is
  **orthogonal to transport**: the frame names *who*, verification (proof of key
  control, `did/verify-control`) and authorization (VCs ↔ §22.2 capabilities)
  are separate handshake/PEP concerns, not in the frame. Those concerns are
  normative in the graduated
  [identity model](xap_identity_model.md) — the XSP-AUTH handshake (its §4)
  proves the principal; the field itself stays an attribution/routing label
  (N-IDENT-1), and an unproven principal is anonymous (N-IDENT-2).
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

**Error codes** — numeric and registered since I5 stream 4 (L166, #717;
generic-layer sub-block `CXER5000–5009` of the `CXER5000–5049` band,
per-code rows in the store-profile spec's §4 error table):
`CXER5000 E_XSP_VERSION` (unknown version), `CXER5001 E_XSP_TRUNCATED`
(buffer shorter than the frame declares), `CXER5002 E_XSP_TYPE` (unknown
type), `CXER5003 E_XSP_LENGTH` (payload exceeds the 2^32-1 ceiling, or
principal exceeds 2^16-1), `CXER5004 E_XSP_PAYLOAD` (data-bin payload fails
to parse/emit), `CXER5005 E_XSP_FLAGS` (reserved flag bits 2–7 set). The
pre-I5 symbolic spellings (`CXER-XSP-VERSION` …) are RETIRED — a cutover,
never dual-accepted; the XSP-AUTH handshake's `CXER-XSP-AUTH-*` codes are
the identity model's and are unchanged by this allocation.

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
the shape SSE+POST fits, and the reference instance's actual traffic profile (a
high-rate event stream down, occasional intents up). #31 rejected SSE+POST as
the *general* XSP transport (it is one-way + text + a round-trip per upstream
message); it remains the correct **v1 web binding** until the WebSocket binding
lands, at which point the *same frames* switch carriers with no client logic
change above the transport adapter.

**Envelope negotiation (amendment — RULED: SSE-1, owner "1b" 2026-08-20,
`ledger/rulings_2026_08_20_sse_downstream.md`).** The XSP framing of the SSE
downstream is **negotiated per subscription**, mirroring the upstream's
`[envelope codec="xsp"]` opt-in; the envelope changes **carriage only, never
content**. The plain feed shapes of xap.md's SSE prerequisite section
(`[surface …]` / `[surface-delta …]` / the deployment host's named per-feature
readouts) are ALSO normative, so this section reads as negotiated carriage of
the same events — never a second event vocabulary:

- A subscriber that requests the XSP envelope — `[envelope codec="xsp"]` on
  the generic `[sse-subscribe …]` promotion, or `?envelope=xsp` on the XAP
  `GET /events` / `GET /stream` feeds (the same per-subscription query shape
  as the delta opt-in) — receives each event's `data:` field as
  base64(XSP `event` frame, `binary=false`) whose payload carries
  **byte-for-byte** the CX event text the plain lane delivers for the same
  event. SSE metadata fields (`event:` names, `id:`, `retry:`) stay plain SSE
  lines — transport metadata, not the event.
- A subscriber that does not opt in receives the plain-CX events unchanged,
  byte-identically. Both carriages coexist on one topic/feed; each committed
  event fans out in both, each subscriber receiving exactly its negotiated
  one.
- An unknown envelope/codec value refuses the subscription loudly (never a
  silent plain fallback an XSP-decoding client could not parse).

## §5. Session layer — heartbeat, flow control, reconnect-resume

**Status:** normative as of the #560 adoption (owner directive 2026-07-22 —
spec + implementation in one campaign; fabric's served tier is the driving
consumer and the reference implementation). The v1 frame (§2) is UNCHANGED:
every §5 mechanism rides existing fields, application-level negotiation, and
one new negotiated-only frame type. A §5-unaware v1 peer interoperates
untouched — it simply never negotiates the features.

### §5.0. Feature negotiation — transcript-covered offers + post-attach limits

Negotiation has TWO surfaces with a bright line between them (the stream-4
L164 ruling, closing the #718 downgrade-strip hole):

**1. Semantic tokens are transcript-covered.** Profile and feature OFFERS
that change what the peers may SAY to each other ride the XSP-AUTH
handshake itself: M1 and M2 carry the offered profile + semantic-feature
token sets, and M4 confirms the selection — **inside the signed
transcript** (identity model §4.4; the downgrade-protection property is
thereby extended from versions/suites to vocabulary). A MITM that strips a
token (`store-feed`, `store-delta`, `credit`, `publish-batch`, `resume`,
`peer`, …) breaks the transcript signature and the handshake aborts —
never a silent downgrade. Because this changes what the HKDF-labeled
transcript covers, the negotiation carriage lands with the
`xsp-auth/2/…` → `/3/` label bump (the label IS the version handle; a
`/2/` transcript MUST NOT be replayable against a `/3/` verifier).

**2. Operational limits stay post-attach.** The attached-channel `session`
query remains for values that tune an already-agreed vocabulary — windows,
timeouts, liveness cadence:

```cx
[fabric-session features="heartbeat credit resume publish-batch rotate" liveness-ms=30000
                pending-window=64 request-timeout-ms=30000]
```

- `features` — space-separated tokens the server speaks. The shipped set
  includes `rotate` (session-credential rotation, #640) — carried here
  since its introduction, now listed. Any token that changes SEMANTICS is
  transcript-bound per surface 1; the advert restates the confirmed set
  plus operational-only tokens. A client MUST NOT send a `credit` frame
  (§5.2) to a peer that did not confirm `credit`, nor a `publish-batch`
  verb (fabric.md §13, #607) to one that did not confirm it (the client's
  batch lane falls back to pipelined single publishes); a client that
  never asks gets the pre-§5 posture unchanged. Unknown tokens are ignored
  on this discovery surface (forward-compatible).
- A server that does not know the query refuses it as an unknown verb; the
  client tolerates the refusal and behaves as a pre-§5 peer.
- This negotiation is why the frame `type` space can grow without a version
  bump: a type is only ever sent to a peer that confirmed the feature
  carrying it. An un-negotiated `credit` byte at a pre-§5 peer is rejected
  loudly (`CXER5002 E_XSP_TYPE`), never misparsed.

### §5.1. Heartbeat / liveness

- Either side MAY send `ping` (type 5) at any time; the receiver MUST answer
  `pong` (type 6) echoing the `stream-id` and payload verbatim (opaque
  echo — usable for RTT or sequence probes).
- **Any inbound frame refreshes the peer's liveness window** — ping is the
  *idle* keepalive, not a required cadence when traffic flows.
- The server advertises its window as `liveness-ms` (§5.0; default 30000).
  A client SHOULD send `ping` once it has been write-idle for **half** the
  window (the reference client heartbeats from its receive drain loop — the
  parked standby consumer keeps its assignment). A peer silent past the
  window is DEAD: the server tears down its session state (fabric: the
  §19.3 group assignment fails over; the successor resumes per §5.3).
- Liveness is per-connection, judged on inbound frames only — no clock
  exchange, no skew sensitivity.

### §5.2. Flow control — credit windows

Per-stream, credit-based, receiver-driven:

- At subscription time the receiver MAY declare a **window** W
  (fabric: `[subscribe … window=W]`, clamped to the server's configured
  `pending-window` ceiling for group subscriptions). Undeclared keeps the
  server default (group subs: the pending-window; observe subs: unbounded —
  the pre-§5 replay contract).
- The sender decrements one credit per pushed `event` frame; **at zero it
  MUST stop pushing** on that stream. Control frames (`ping`/`pong`/
  `error`/`credit`) never consume credit.
- Replenishment, two equivalent forms:
  1. **Application acknowledgment** — a cumulative ack through sequence S
     (fabric `[ack …]`, §19.5) frees every credit at-or-below S. This is
     the durable-plane norm: the window IS the pushed-unacked tail.
  2. **`credit` frame (type 8, negotiated)** — `[frame type=credit
     stream=SUB [payload N]]` grants N additional credits (payload = a
     data-bin integer ≥ 1; the stream-id is the subscription id events
     ride). This serves flows with no application ack: a windowed
     observe-mode subscription's receiver auto-credits as it consumes (the
     reference client grants one credit per entry handed to the
     application, so the balance tracks real consumption, never the socket
     buffer).
- A slow consumer therefore never blocks a publisher and never causes
  unbounded buffering: on the durable plane the LOG is the buffer — at
  window exhaustion the sender stops pushing and the consumer catches up by
  offset (§5.3 replay is the same mechanism); on the transient plane
  latest-wins makes drop-oldest inherent (a starved subscriber observes
  fewer intermediates — by construction, not policy).

### §5.3. Reconnect-resume

Resume is **application-anchored, transport-stateless**: the transport
buffers nothing across connections; the durable log is the resume source
(the xap.md §16/§22.6 tie — the journal fold IS the state).

- Durable `event` frames carry the stream's **journal sequence** in the
  payload envelope (fabric: `[entry seq=N …]`); the seq is the resume
  token. Sequences are per-stream, strictly increasing, assigned by the
  single sequencer at publish (fabric §10).
- On reconnect the client re-runs the attach handshake (identity is
  re-proven — resume NEVER bypasses XSP-AUTH), then re-subscribes with a
  cursor: `[subscribe … from=N]` replays from sequence N (inclusive).
- **Resume guards (stream 7 F2, #714 item 2).** The observe-mode "a client
  that kept nothing starts wherever it chooses" freedom is exactly two
  silent failures waiting — a gap (skipped events) and a rewind — and both
  are **checkable server-side** against the requested cursor and the
  retained tail. A subscription declaring `:monotonic-reads`/`:gapless`
  (the fabric §7 consistency floor) gets those checks enforced at
  re-subscribe: under `:gapless`, a `from=` below the stream's retained
  floor refuses `cx-err:CXER4991` (naming the requested position and the
  floor) instead of silently replaying from the seam; `from=` beyond the
  head stays the standing out-of-range refusal. Undeclared observe
  subscriptions keep the pre-§5 replay contract byte-identically — the
  vocabulary is declare-and-verify, never a silent default change. (The
  stream-3 live surfaces run the same cursor checks unconditionally —
  live.md CXER5072/5073; declaring the tokens there is validated and adds
  nothing the default does not already check.)
- **Group subscriptions resume implicitly**: the committed offset (§19.5
  cumulative ack) is durable server-side state, so a bare re-subscribe
  resumes at committed+1 and the redelivery window is exactly the
  uncommitted tail — at-least-once by construction, no visibility-timeout
  machinery. `from=` on a group subscription is REFUSED: a client-supplied
  cursor could skip uncommitted events for the whole group (data loss) or
  silently rewind it; both are operator actions, not client whims.
- **Observe-mode (non-group) subscriptions resume explicitly**: the client
  tracks the last seq it processed and re-subscribes `from=last+1`. A
  client that kept nothing starts wherever it chooses — the server holds no
  per-observer state.
- Transient channels do not resume: latest-wins re-read after re-attach is
  the defined semantics.
- **Head-set cursors (multi-stream feeds):** a subscription whose source
  set is a SET of streams (the store profile's change feed) resumes with a
  **map** cursor — `[from [s plane= name=? pos=]…]`, one entry per source
  stream — never a scalar: no cross-stream total order exists, so a scalar
  seq would assert an ordering the source cannot honor. The scalar `from=N`
  remains the single-stream form (fabric). Positions are per-stream, dense,
  strictly increasing; resume replays strictly above the given positions.
  Normative shapes and the retention-boundary refusal live in the store
  profile spec (its §5).

### §5.4. Still deferred (scoped)

- **Multiplexing** beyond `stream-id` + per-stream credit (priority /
  weighted scheduling across streams).
- **WebSocket & WebTransport bindings** (§4 — the same frames switch
  carriers unchanged).

(Cross-runtime VC revocation propagation, formerly deferred here, is now
owned by the store profile's `peer` channel — a subscription to the peer's
revocations journal stream; see the store profile spec.)

## §6. Profiles — the semantic layer

A **profile** is a feature-token set + a payload verb vocabulary + its
error rows, negotiated per §5.0 surface 1 (transcript-covered). The
generic layer never grows semantics; growth is only ever a token. Rules:

- Frame v1 (§2) and the session mechanics (§5.1–§5.3) are shared by every
  profile unchanged. A profile MUST NOT redefine frame fields or session
  invariants; it defines what payloads mean and which encodings each
  payload role rides.
- Unknown profile tokens are ignored on the discovery surface;
  un-negotiated frame types and verbs are loud errors — never misparsed,
  never silently tolerated (§5.0).
- Error rows are numeric and registered (governance's error-code registry);
  a profile allocates its band there in the same change that implements
  the codes (#717 discipline).

Registry (v1):

| Profile | Vocabulary | Normative home |
|---|---|---|
| **XAP** | cascade events, intents (`[do …]`), fabric verbs — today's semantics, re-labeled | [`xap.md`](xap.md), [`fabric.md`](fabric.md), [`xap_identity_model.md`](xap_identity_model.md) |
| **STORE** | the store wire: store/journal verbs, credit-governed query/iter/list streams, change feed + ∂ frames, object wire, `peer` revocation channel | the stream-4 store profile spec (#676; `spec/03-approved/xap/xsp_store_profile.md` until promotion) |

## §7. Cross-references

- Issue #31 (this RFC); #26 (did/vc — the `principal` field's identity).
- [`xap_identity_model.md`](xap_identity_model.md) — the identity model
  (graduated #116/#519): XSP-AUTH mutual handshake over stream 0, channel
  binding, per-request proofs, N-IDENT-1…4.
- [`xap.md`](xap.md) §16 (clients), §22.1 (identity/DID),
  §23 (web client), §24 (SSE/streaming prerequisite), §26 (N-IDENT-1…4).
- [`core/codec.md`](../core/codec.md) — the `data-bin` payload codec.
- [`std-lib/did.md`](../std-lib/did.md), [`std-lib/http.md`](../std-lib/http.md).
