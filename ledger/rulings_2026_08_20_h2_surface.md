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
