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

Implementation record appended below on landing.
