# Pre-Phase-1 cxstore networked backends — working spec

**Status:** **03-approved** (graduated by owner ruling 2026-07-22 — the
graduation precondition is met: s3:// / http(s):// / ftp:// / sftp://
backends are implemented, merged, and live-verified)
**Tracks:** #90 (http chunked response write), #91 (remote byte-source backends),
#106 (sftp/libssh2), #107 (ftps verification), #78 (CSRP minimum).

This draft proposes amendments to three approved specs. It is written *after*
the fact to correct a process miss (the changes were implemented before the
spec was drafted and were briefly squatting in `03-approved`); the
implementation now exists but should be re-validated against this spec + the
conformance fixtures it mandates, then graduated by the owner.

Each section gives **was → is**, alternatives considered, and the **conformance
gate** (the fixtures / behavioral tests that must exist before the change is
graduated).

---

## A. `std-lib/http.md` — server-side chunked-transfer-encoding response write (#90)

**Target:** `http.md` §3.5 (low-level `respond`) + §4.2 (out-of-scope table).

**Was:** "Request and response bodies are fully materialized (Content-Length set
on send); streaming/chunked request bodies and streaming response reads are out
of scope v1." `respond` wrote whole-body Content-Length only.

**Is:** `respond` additionally supports **chunked transfer-encoding** when the
`[response]` carries a `Transfer-Encoding: chunked` header: the body is written
as `<hex-len>\r\n<octets>\r\n` frames terminated by `0\r\n\r\n`, with
`Content-Length` suppressed (RFC 9112 §6.3 forbids both). Client streaming
request bodies + streaming client response reads remain out of scope. This is
the transport CSRP streams binary responses over; the chunked coding already
backed SSE server push (§3.6).

**Alternatives:** (a) Content-Length only + buffer the whole stream — rejected:
defeats streaming a large query result. (b) New low-level streaming verb —
deferred; the header-driven path reuses the existing `respond` contract.

**Conformance gate:** `conformance/stdlib/http.cxd` — a server chunked-write
case (response with `Transfer-Encoding: chunked` → wire shows chunk framing +
`0\r\n\r\n`, no Content-Length). Live multi-chunk binary round trip:
`vcx/tests/http_chunked_stream_test.v` (exists).

---

## B. `std-lib/store.md` §2.2.1 — remote byte-source backends (#91/#106/#107)

Each doc is one object named by its SHA-256 hash under the URL base; ops hit the
transport lazily per key (`net`-gated). **Was:** the table listed these as
flatly "read+write+list supported." **Is** (per-scheme, reflecting what is
actually implemented + verified):

| Scheme | Was | Is |
|---|---|---|
| `s3://` | "Standard SDK credential chain" | Real: AWS SigV4 signing; creds + endpoint from `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION`/`AWS_S3_ENDPOINT`; path-style for custom endpoints. **Live-verified** (MinIO). |
| `http(s)://` | "read + list" | Read byte source: `get-doc` + `exists` (GET/HEAD). Write → `CXER1110`; list needs WebDAV (future `http+dav`). **Live-verified.** |
| `ftp://` | "RFC 959 + RFC 4217" | RFC 959 plaintext (control + PASV data). **Live-verified.** |
| `ftps://` | "enforces TLS" | RFC 4217 AUTH TLS, **capped to TLS 1.2**. **Experimental/unverified end-to-end** — opt-in only via `opts.ftps-experimental=true`; default `open` raises `CXER1100` → #107. (mbedTLS handshake has crashed some vsftpd builds; not a verified round trip.) |
| `sftp://` | "SSH agent default; key-path/password" | libssh2-backed, **gated `-d cx_sftp`** (default build links no SSH lib → `CXER1100`). Auth: key-path (`opts.auth.key-path`) → password (URL userinfo / `opts.auth.password`); host key strict-verified vs `opts.auth.known-hosts` (`opts.host-key-check=off` skips, dev only). SSH-agent auth deferred. `net` + `read` (key file) capabilities. **Live-verified** (atmoz/sftp, incl. strict known-hosts). |

**New opts:** `ftps-experimental` (bool, default false), `host-key-check`
(`"off"` to skip sftp host-key verification, dev only).

**Alternatives:** ftps as a normal supported backend (rejected — fails the
round trip + endangers servers, #107); sftp via pure-V SSH or shell-out
(rejected on #106 — libssh2 binding chosen).

**Conformance gate:** `conformance/stdlib/store.cxd` (currently EMPTY — 0 tests):
add language-neutral surface fixtures — URL→scheme dispatch, the read-only-http
`CXER1110`, ftps-default `CXER1100`, sftp-unbuilt `CXER1100`, error-code
mapping. Live round trips (need services, kept as env-gated V tests):
`store_s3_minio_test.v`, `store_http_test.v`, `store_ftp_test.v`,
`store_sftp_test.v`, + the always-on `store_sigv4_test.v`.

---

## C. `misc/cxstore-remote-protocol.md` — CSRP minimum profile (#78)

**Target:** the approved CSRP spec, which defaults to `ast_bin` (cxbin) bodies
and binary `[u32][u8 kind][payload]` streaming frames for `/query` and `/iter`.

**Proposed minimum profile (Phase 0.7 "single-node minimum"):**
- **Wire encoding `cxd` (text)** for the minimum, sanctioned by spec §2.2
  ("cxbin and cxd encodings produce identical doc IDs"). Rationale: the
  reference server is a CX `[?http-service]` and CX programs cannot emit/parse
  `ast_bin` or render structured nodes to text — there is no such CX verb.
- **Ops in the minimum:** `GET /cx-store/v1/capabilities` (handshake) +
  `POST /cx-store/v1/{get,put,delete,list}` + `exists` (via `get` 404). Hash
  passed as a `?hash=` query param on get/delete. Bearer auth (URL userinfo or
  `[opts bearer=…]`).
- **Enabling verbs (new, store surface):** `store-put-doc-text`
  (canonical text → hash + store) and `store-get-doc-text` (hash → canonical
  text) — the text doc-I/O the request/response bodies are built from. Public
  on `cx-stdlib/store`.
- **Server split — as built (the design landed here, not as first sketched):**
  the §3.5 http accept loop stays a CX program (`[?for accept-iter]`), but ONE
  request/response cycle is a V verb `[$store:csrp-handle $exchange
  $local-store]` (`vcx/code/store_csrp.v`). A pure-CX server was tried and
  rejected mid-impl: a CX program cannot build the cxd-text responses cleanly
  (no `join` verb; query/attr navigation yields wrapped nodes like `[value
  'abc']`, not bare strings). The V handler reads the request via
  `http_exchange_request_real`, dispatches to the local store, and writes the
  response via `http_respond_impl`. net-gated (`cap_guard('net')` first →
  CXER0271 by default).
- **Wire shapes (as built):** `[capabilities …]`, `[put-result hash=…
  stored=…]`, `[delete-result hash=… deleted=…]`, and the doc canonical text
  for `get`. **List is `[list-result [hashes [hash "h1"] [hash "h2"] …]]`** —
  NOT `[sequence …]`: `sequence` is a reserved collection constructor that the
  client's parser folds into a sequence value rather than a walkable element.
  Query params model as `[query-params [<name> "<value>"]]` (param name = elem
  name). Quoted strings parse to `TextNode`, not `ScalarNode` (client extractor
  must handle both).
- **Deferred beyond the minimum — the approved-wire completion (#182; not
  "Phase 2", which names the production-daemon tier):** binary `ast_bin`
  default + `[u32][ast_bin]` streaming frames, `/query` + aggregate pushdown
  (count/sum/avg/min/max), `/iter` streaming, `/modify` — i.e. the full
  approved `cxstore-remote-protocol.md` §2.1/§3 wire. These need `ast_bin`
  exposed as a CX surface (shared with #79/#80); the chunked transport already
  exists (§A / #90).

**Alternatives:** pure-CX server (tried, rejected mid-impl — see the server
split above); expose ast_bin CX verbs now (deferred — larger surface, couples
to #79/#80).

**Conformance gate:** `conformance/stdlib/store.cxd` — store-029 exercises the
deny-by-default `net` gate on `csrp-handle` (CXER0271). The live cx↔cx round
trip (a server cannot be fixtured with a live exchange) is
`vcx/tests/store_csrp_test.v`: a CX server program + a CX client program,
black-box over loopback, full CRUD lifecycle.

---

## D. Graduation checklist (owner)

1. Review A/B/C; fold the was→is deltas into the target `03-approved` files.
2. Confirm the conformance fixtures in §A/§B/§C exist and pass before graduation.
3. ftps stays experimental until #107 verifies it on a Linux FTPS server.
