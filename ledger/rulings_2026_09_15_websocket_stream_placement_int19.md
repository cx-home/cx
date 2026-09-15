# Integrator decision 2026-09-15 — where the WebSocket frame codec, the upgrade and `kind=stream` live (RULED: INT-19)

`kind=stream` (#1461) is ruled into v0.18 by **1430-e** — "WebSocket and SSE over
`http`" — and #1086 (RFC 6455 over the existing net TCP/TLS surface) is ruled in
by **INT-17**, whose own text names it in cluster 5 as one of the additions that
"should have been done v0.18 and must be added now". #1086's issue asked for a
scope ruling and named the choice it could not make for itself: *"a pure codec
module or an http submodule; the xsp frame-codec precedent applies"*. INT-17
answers the membership question; this page answers the placement one, **before
the spec and before the code** (OL-15).

The two issues are one branch because the stream kind rides the WebSocket #1086
adds: SSE exists today (`http.md` §3.6) and WebSocket does not, so a `kind=stream`
adapter specified without #1086 would declare `protocol=ws|sse` over a surface
half of which is not there.

| Id | Decision |
|---|---|
| **INT-19** | **(integrator, under INT-17 and 1430-e)** Three artifacts, three rings, three documents, and no sentence of one restated in another. **(i)** The WebSocket **FRAME CODEC** is a pure **Ring 1** module `ws` — `cx-stdlib/ws`, spec `spec/03-approved/stdlib/ws.md`, corpus `conformance/stdlib/ws.cxd`, code `vcx/code/stdlib_ws.v`, band **`CXER6900–6999`** (`E_WS_*`) — carrying framing, masking, fragmentation, the control frames, the close codes, the UTF-8 rule a TEXT message is held to, the bounds, and the one pure value the handshake computes (the `Sec-WebSocket-Accept` derivation, over `crypto`'s SHA-1 and `bytes`' base64 and never a second digest). The precedent is this tree's own: `xap/xsp.md` §2 specifies a self-describing, self-delimiting frame apart from every carrier that moves it, and RFC 6455's frame has the same property. **(ii)** The **UPGRADE HANDSHAKE** is `http.md`'s — a new **§3.7**, "WebSocket upgrade — client dial and server accept", over the existing net TCP/TLS surface (§2.6's client scheme dispatch for `ws://`/`wss://`, §3.5's server surface, §3.6's SSE for the shape of a held-open connection), taking codes from the **`CXER4552–4589`** block §8 already reserved for exactly this, and capability-gated with the `net` grant `http` already uses. Three places in `http.md` are trued with the section and no others: line 73's out-of-scope row, §7's matrix cell, and §8's reservation sentence. **(iii)** `kind=stream` is **`connector.md` §3.15**, on the §3.9.7 template's nine subsections, inside `connector` — the placement 1430-e already decided for it. It adds **no code** to the connector band: every refusal is the core's, the codec's or `http`'s, and the last two are re-raised unchanged (the `graphql` and `soap` precedent). |

## Placement, decided here before spec or code (OL-15)

| module | ring | namespace today → cutover | spec | corpus | code |
|---|---|---|---|---|---|
| `ws` | 1 (pure codec: the frame, the mask, the fragments, the control frames, the accept derivation; the connection is `http`'s) | `cx-stdlib/ws` | `stdlib/ws.md` | `conformance/stdlib/ws.cxd` | `vcx/code/stdlib_ws.v` |
| the upgrade | 2 (it dials and it binds) | inside `cx-platform/http` | `platform/http.md` §3.7 | `conformance/platform/http.cxd` | `vcx/platform/stdlib_http.v` |
| `kind=stream` adapter | inside `connector` (Ring 2) | — | `connector.md` §3.15 | `connector.cxd` | `vcx/platform/stdlib_connector_stream.v` |

Paths are the post-#1427 tree. The `ws` row enters `registry/modules.cxd` as
`planned` with this record; the other two are dimensions of modules whose rows
already exist.

## The band, and why it is not the next free one

`CXER6900–6999`. `CXER6700–6799` and `CXER6800–6899` are `sftp`'s and `ftp`'s on
#1457's and #1458's branch, which is unmerged on the tree this branch was cut
from — so they are **stepped over rather than reused**, exactly as `connector`
stepped over `mailbox`'s `6100–6199` in #1430 rather than reusing a band a
deferred branch had claimed. A band scan across `spec/`, `registry/` and
`conformance/` on 2026-09-15 returned nothing at or above `6900` anywhere in the
tree.

The upgrade takes `CXER4552–4561` out of the block `http.md` §8 reserved for
"future http streaming extensions (WebSocket upgrade, request-body streaming)"
before any of this existed. `4562–4589` stays reserved for the second half of
that sentence.

## Why the frame codec is a module and not an http submodule

#1086 named both options and the xsp precedent. Four reasons decide it, and each
one is a property the alternative loses:

1. **The decisions are pure and `http` is not.** Every choice a frame codec
   makes — how many octets follow, whether an opcode is assigned, whether a
   length form is minimal, whether an assembled message is valid UTF-8 — is a
   function of its arguments. Inside `http` those cases would need the `net`
   capability they do not use, and the `embed` profile would carry a WebSocket
   parser it cannot reach.
2. **Two consumers differ by one comparison.** The client masks and the server
   does not (RFC 6455 §5.1). A shared codec with a `from=` argument is one
   implementation and one corpus; two halves inside `http` would be two.
3. **A third consumer exists that is not a connection at all** — a program
   reading a captured stream from a file, which is also how the corpus grades
   everything.
4. **The precedent is already ruled.** `xsp` is a frame codec specified apart
   from its carriers (#363 item 4(a)), and `soap` is a codec specified apart from
   the `http` that moves it (1430-c). This is the third instance of one decision,
   not a new one.

## What #1086's issue asked that this page does not answer

The issue names "server accept + client dial" and both are in §3.7. It names
"capability-gated with the same net dial/listen grants" and §3.7 cites §5 rather
than restating it. It does **not** ask for a subprotocol registry, an extension
transform (`permessage-deflate`), or an HTTP/2 `CONNECT`-style tunnel, and none
of the three is in scope here: the extension NEGOTIATION is in §3.7 and the
`rsv-negotiated` seam is in `ws.md` §4.3, so an extension that lands later
changes neither document's shape.

## Composition

Two seam rows, added with the spec and before the dependency:

| # | Direction | Why it is new |
|---|---|---|
| **S-36** | `connector` → `http`, the held-open surface | S-9 is the request/response half and S-29 the inbound one; neither covers a connection held open across many drains |
| **S-37** | `http` → `ws` | the first dependency `http` has on a Ring 1 frame codec |

`connector` → `journal` (S-11) and `connector` → `live` (S-13) already exist and
carry the landing `kind=stream` makes; no row is added for them.
