# Ruling H2-1 (2026-08-20) — the TLS+h2 serve-path surface is approved (#875, owner "a")

The owner authorized the spec draft (option a on the #875 letter): the
serve path's TLS + ALPN + HTTP/2 surface is now specified at
spec/03-approved/std-lib/http.md §13 — [tls cert= key=] child on the
serve config, ALPN ("h2","http/1.1"), no h2c, stream↔exchange mapping
with unchanged handler semantics, no PUSH_PROMISE, SSE lowering to DATA
frames with per-stream flow-control backpressure, error codes allocated
from the §8 band at implementation. Transport-only reuse of the #105
RFC-7540 codec; zero gRPC semantics (adapter-only doctrine). G3 on the
section text rides the cut review package; the IMPLEMENTATION is #875's
own campaign, cut-independent, and starts only on its own go.

## Implementation record (2026-08-20, #875 — owner go "this is a v0.16.0 deliverable")

The H2-1 surface landed, impl-only against the approved §13 text plus ONE
spec truing under this ruling (the §13 status paragraph recorded "nothing
below is shipped yet"; after this landing that claim is false, so it now
records the landing and the gate lane — no normative behavior changed).

What landed:

- `vcx/platform/http_h2_serve_notd_wasm32_emcc.v` (new) — the TLS+ALPN
  listener + both framings. TRANSPORT-ONLY reuse of the #105 codec
  (store_grpc_h2.v frame layer, store_grpc_hpack.v/huffman): the h2
  connection driver is a fresh generic state machine (the gRPC lane's
  H2Conn completes gRPC length-prefixed calls and stays untouched); zero
  gRPC semantics on this path.
- `[?http-service]` gains the `[tls cert=PATH key=PATH]` child
  (services.v collect_tls_child; ServiceRecord.tls_cert/tls_key); the
  listener trigger includes it. `[$http:serve "tls://…" $handler
  {tls: {cert: … key: …}}]` wires the same engine; a tls:// bind without
  certs refuses CXER4514 (never a silent cleartext fallback).
- Handlers run on the SHARED bounded executor pool (§14): the h2 owner
  thread enqueues DispatchJobs (h2c/h2_stream fields; fd lane untouched);
  ring-full sheds an inline 503 HEADERS with no evaluation.
- SSE over h2 (§13.3): `[sse-subscribe topic=…]` promotes the stream;
  event writes are DATA frames under per-stream WINDOW_UPDATE flow
  control with a bounded (1 MiB) per-stream queue — overflow RSTs exactly
  that stream (ENHANCE_YOUR_CALM). cx_sse_topic_publish fans out to fd,
  h2-stream, and TLS-h1 subscribers; publishers only enqueue, never block
  on any connection's I/O. The xap-RUNTIME feed (`[$xap:serve]`, sse_rt)
  stays on its cleartext lane — §13 names only the two http serve
  surfaces.
- Threading: mbedtls forbids concurrent ops on one ssl context, so each
  connection has ONE owner thread doing all socket I/O, paced by the
  listener-conf read timeout (5 ms tick — mbedtls applies the LISTENER
  conf to accepted conns; a per-conn set_read_timeout writes an unused
  conf, found live). Handshakes run over the nonblocking bio
  (accept_raw + complete_handshake, 10 s budget) so the tick can never
  bound a handshake round trip. Thread-per-connection bounded by
  CX_HTTP_TLS_CONNS (default 256; h2 makes connections ≈ clients).
- Protocol errors stay wire-level (GOAWAY/RST with RFC 7540 codes,
  mirroring the #222/#223-hardened gRPC lane: exact preface, oversized-
  frame refusal, header-block + CONTINUATION caps, HPACK failure =
  COMPRESSION_ERROR). No CX-visible error value surfaces from them, so
  NO §8 CXER was minted — the §9.6 registration happens if/when one
  becomes CX-visible.

Gate: `vcx/tests/http_h2_serve_test.v` — ALPN negotiates h2 + a request
round-trips over h2 frames; ALPN http/1.1 falls back h1-over-TLS with
responses BYTE-IDENTICAL to the cleartext listener; SSE over ONE h2
connection multiplexes two feeds + the publishing exchanges, a window-
starved stream pins at its 8-octet window while its sibling receives all
events, and crediting it later drains it to identical bytes; the h2c
preface is refused as h1 on both cleartext and ALPN-http/1.1 TLS.
Existing lanes green: http_umbrella, http_slow_handler_isolation,
platform_grpc_umbrella — zero golden movement on the h1/gRPC paths.
