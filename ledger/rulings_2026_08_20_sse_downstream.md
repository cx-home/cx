# Ruling SSE-1 (2026-08-20) — the v1 web binding's SSE downstream: negotiated XSP-envelope carriage (owner "1b")

Owner ruling at the stale-issue review (2026-08-20, option "1b"; prime
directive: last window for wire-surface changes before production
clients): **xsp.md §4.1 stands as written — the v1 web binding's SSE
downstream carries base64-encoded XSP `event` frames — and the
implementation catches up to it.** Before this ruling only the upstream
POST had the `[envelope codec="xsp"]` opt-in decode; the downstream
(`xap_host_push_frame` and the `[$xap:serve]` `/events` feed) pushed
plain-CX SSE events with no XSP carriage at all.

## The reconciled reading (normative)

xsp.md §4.1 as written says every cascade event becomes an XSP `event`
frame, base64-encoded into the SSE `data:` field — it names no
negotiation. xap.md §24's plain feed shapes (`[surface …]` /
`[surface-delta …]` as the SSE data) are ALSO normative, and the shipped
bridge client consumes them. Framed-ALWAYS would falsify §24 and break
that client. The honest reading — stated as a short amendment in §4.1
under this ruling — is:

**The XSP framing of the downstream is negotiated per subscription; the
envelope changes CARRIAGE only, never content.**

- A subscriber that requests the XSP envelope — mirroring the upstream's
  opt-in vocabulary — receives each SSE event's `data:` field as
  base64(XSP `event` frame, `binary=false`) whose payload carries
  **byte-for-byte** the CX event text the plain lane delivers for the
  same event. SSE metadata fields (`event:` names, `id:`, `retry:`)
  stay plain SSE lines — they are transport metadata, not the event.
- A subscriber that does not opt in receives today's plain-CX events
  **byte-identically** (zero movement on the plain lane; the shipped
  bridge client sees no change).
- Both lanes coexist on one topic/feed: each committed event fans out in
  both carriages, each subscriber receiving exactly its negotiated one.

## The opt-in vocabulary (mirrors the upstream)

- **Generic `[$http:serve]` SSE promotion** (the only SSE surface
  reachable over the TLS/h2 lane): the promoting handler returns
  `[sse-subscribe topic="…" [envelope codec="xsp"] [event …]?]`.
  An unknown `codec` refuses the promotion loudly (500), never a silent
  plain fallback. The initial `[event …]`, when present, is framed in
  the subscription's negotiated carriage.
- **XAP feeds** (`[$xap:serve]` `GET /events`, `[$xap:host]`
  `GET /stream`): the subscribe request carries `?envelope=xsp` — the
  same per-subscription query opt-in shape as §24's `?delta=1`. An
  unknown `envelope` value refuses (400). (The upstream twin stays the
  deployment doc's `[transport [envelope codec="xsp"]]` for POST
  /intent, unchanged.)

## Why binary=false

The frame payload is the exact text the plain lane delivers, so
`base64-decode → [$xsp:decode] → payload` byte-compares against the
plain subscriber's (rejoined) `data:` payload. Carriage negotiation that
re-encoded the value (`binary=true` data-bin) could not make that
equality literal; the envelope must never be a second event vocabulary.

## Scope

- One frame encoder: the existing `xsp_encode_one` (vcx/platform/
  stdlib_xsp.v) is the only XSP framer — the downstream reuses it; no
  second encoder is minted.
- Plain-lane bytes are pinned by the existing fixtures (xap_render_test
  test_xap_sse_push, http_umbrella test_concurrent_sse_push,
  http_h2_serve_test) — all must stay green untouched.
- Spec deltas under this ruling: xsp.md §4.1 gains the short
  negotiated-carriage amendment (recording this ruling id). No other
  normative text moves.

## Implementation record (2026-08-20 — landed)

What landed (one encoder, three subscription surfaces, per-subscription
carriage at every fan-out):

- `vcx/platform/stdlib_xsp.v` — `xsp_sse_data_b64(payload)`: ONE helper
  wrapping the existing `xsp_encode_one` (never a second framer): builds
  the `event`/`binary=false` frame over the exact payload text and
  base64s the wire bytes.
- **Generic topic layer** (`[$http:serve]` / `[?http-service]`):
  `[sse-subscribe topic="…" [envelope codec="xsp"] …]` sets
  `WireResp.sse_xsp`; unknown codec refuses 500. The XSP lane registers
  under a NUL-prefixed sibling registry key (`sse_topic_key` —
  authored topics never carry NUL, so no collision), which makes the
  fd, h2-stream, AND TLS-h1 registries carriage-aware with ZERO change
  to their publish/prune/close logic. `[$http:sse-publish]` renders the
  event once per carriage (`sse_frame_event_xsp`: id/event/retry lines
  stay plain; data = base64 frame) and publishes to both keys; the
  delivered count spans both lanes. Initial `[event …]` frames ride the
  subscription's negotiated carriage.
- **`[$xap:serve]` `/events`** — `?envelope=xsp` (unknown value refuses
  400 via `xap_sse_envelope_of`); per-fd flag `xap_sse_xsp` beside the
  #609 delta flag; `xap_push_now` splits full-frame subscribers by
  carriage and wraps each delta subscriber's payload
  (`xap_delta_payload`, formerly xap_delta_frame, now returns the
  payload text) in its own carriage; the initial full frame is
  carriage-correct.
- **`[$xap:host]` `/stream`** — same `?envelope=xsp` opt-in (the
  downstream twin of the deployment doc's `[transport [envelope
  codec="xsp"]]` upstream opt-in); `xap_host_push_frame` fans the SAME
  readout out as the plain named event and the XSP twin
  (`xap_sse_named_frame_xsp`: `event: <feature>` stays a plain line);
  `xap_sse_push` now writes per-fd negotiated carriage.
- Spec: xsp.md §4.1 gains the negotiated-carriage amendment (this
  ruling). No other normative text moved.

Gates (all green, full logs, RC echoed):

- `vcx/tests/sse_xsp_downstream_test.v` (NEW lane) — topic layer: plain
  + xsp subscribers COEXIST ON ONE TOPIC, publish reports both
  (pushed=2), plain bytes verbatim (`data: tick-42\n\n`), xsp data
  decodes via an INDEPENDENT §2 wire parse to the byte-equal payload,
  and round-trips through the shipped codec
  (`[$xsp:decode [$bytes:from-base64 …]]` → `event|false|tick-42`);
  unknown codec refuses 500. XAP `/events`: initial + post-intent
  frames byte-compare across carriages; `?envelope=cbor` refuses 400.
  RC=0.
- `vcx/tests/http_h2_serve_test.v` (extended: check_sse_xsp_envelope_over_h2
  + `/feedx` resource) — both carriages of one topic multiplex on ONE
  TLS/h2 connection; plain stream byte-identical; xsp stream decodes to
  the same event text; existing battery untouched and green. RC=0.
- `vcx/tests/xap_umbrella_test.v` (host test extended) — `/stream` +
  `/stream?envelope=xsp` held across the admitted act: named `door`
  event in both carriages, byte-compare after decode; `?envelope=cbor`
  refuses 400. RC=0.
- Plain-lane pins untouched: `http_umbrella_test.v` RC=0 (pushed=2
  stands), `xap_render_test.v` RC=0 (test_xap_sse_push stands),
  `store_remote_umbrella_test.v` RC=0 (xsp frame-layer consumers),
  `stdlib_umbrella_test.v` RC=0 (xsp codec TDD).
