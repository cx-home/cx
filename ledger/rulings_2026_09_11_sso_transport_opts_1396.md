# RULED: 1396-a — one `transport` map for every SSO dial: threaded, honoured, and grown by proxy + client certificate; env-derived settings only under the `env` grant; a token-endpoint POST never follows a redirect

**Fable, 2026-09-11 02:4xZ, under the owner's delegation of 2026-09-09 05:50 ET**; the owner
may override on #1354. Lane S item S4. Premises re-verified at `19af3b349`:
`oidc_http_get`/`oidc_http_post_form` pass a bare `HttpReqOpts{}` (`stdlib_oidc.v:284-313`);
`oidc_discover` never reads its opts (`:336`); `crypto_jwks_fetch` calls `http_request_verb`
with no opts (`stdlib_crypto.v:2861-2896`); the http client reads only top-level `verify`/`ca`
(`http_opts_tls`, `stdlib_http_notd_cx_no_pack_http_client.v:1400-1406`) so the `tls::map`
`http.md` §3.1 promises "verbatim to net" is silently dropped; the TLS dial builds
`mbedtls.SSLConnectConfig{validate, verify}` with no client cert (`:1259-1273`); the CA probe is
five hardcoded paths, `SSL_CERT_FILE`/`SSL_CERT_DIR` unread (`:1386-1394`); `CONNECT` is refused
"out of scope v1" (`:1592-1594`); redirects are followed method-preserving for POST
(`:767-776`) so a 3xx from a token endpoint re-POSTs the code and the client secret.

## 1. Where the transport configuration lives — RULED (a)

- **(a) ONE `transport` map, recorded on `[oidc-config]` at `config` time as a `[transport …]`
  child and overridable per call by `opts.transport`; `discover` and `crypto:jwks-fetch`, which
  run before a config exists, take it directly as `opts.transport`.** Its keys are the http
  client's own (`http.md` §3.1): `tls` (the net `tls::map` — `ca`, `cert`, `key`, `verify`,
  `pin`, `min-version`, `server-name`), `timeout`, `proxy`, plus `follow-redirects`/
  `max-redirects` where they make sense. `session`'s `jwks` fetch inherits it through
  `jwks-fetch`. DELETES nothing; it makes `oidc.md` §3.1's `$opts` and `crypto.cx:67`'s
  `$opts::map {}` mean something.
- **(b) per-verb transport arguments** — refused: five verbs, five places to forget the proxy.
- **(c) process-wide env only (`HTTPS_PROXY`, `SSL_CERT_FILE`)** — refused as the ONLY path:
  a deployment with two IdPs behind different CAs, or a test lane that must not inherit the
  host's proxy, cannot express it; env stays as a convenience layer under (a).

## 2. The http client honours the map it is promised — no fork, an implementation debt

`http.md` §3.1 already says `tls::map` is passed verbatim to net and `net.md` §3.6 already
defines `ca`/`cert`/`key`/`pin`/`min-version`/`server-name`. The client implements the sentence:
`http_parse_req_opts` reads `opts.tls` (a map) and the TLS dial applies `cert`+`key` (client
certificate — `SSLConnectConfig` carries the fields), `pin`, `min-version`, `server-name`; the
legacy top-level `verify`/`ca` keep working as the documented shorthand. **Spec text: none** —
the spec was right. Conformance: a real-socket V test in the h2/tls band with a `net` TLS
listener under `require-client-cert`: the client with `tls.cert`/`tls.key` handshakes, the
client without them is `CXER4512`, a wrong `pin` is `CXER4513`.

## 3. Trust-store discovery — RULED (a)

- **(a) `SSL_CERT_FILE` then `SSL_CERT_DIR` are consulted BEFORE the five hardcoded paths,
  and only under the `env` capability** (`cap_guard('env', …)` — reading the environment is an
  effect, `security.md` §2; the fixed-path probe reads no environment and stays ungated as
  today). When the probe finds nothing, the `CXER4512` diagnostic names every path tried and
  says `SSL_CERT_FILE` is honoured under `--allow-env`, so the failure is legible.
- **(b) honour the env vars ungated** — refused: it would be the one place the process reads
  its environment without a grant.

## 4. Proxy — RULED (a)

- **(a) an explicit `transport.proxy` URL (`http://[user:pass@]host:port`) plus, under the `env`
  grant only, `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY` (lowercase spellings too, `NO_PROXY` as
  RFC-less host/suffix/CIDR list); `https` targets tunnel with `CONNECT`, `http` targets are
  forwarded with an absolute-form request line; `Proxy-Authorization: Basic` from the URL
  userinfo.** The `CONNECT`-out-of-scope sentence at `:1592` stays for the VERB surface
  (`[$http:request "CONNECT" …]` remains refused) — the tunnel is the client's own. **Capability:
  BOTH the proxy host and the logical target must be within the `net` grant** — the grant is a
  policy about which hosts a program may reach, and a proxy that could launder it would make
  `--allow-net=idp.example` mean nothing. DELETES nothing.
- **(b) env only** — refused (§1(c)). **(c) no proxy, document it** — refused: two of the four
  named IdPs are reached from corporate networks through an egress proxy as the norm.

Graded per commit by a **CX forward proxy in the interop lane** (`scripts/sso_interop/proxy.cx`,
its own port beside 8793): `rp_drive.cx` gains rows `discover-via-proxy` and `login-via-proxy`
(`transport.proxy` set, the IdP host STILL granted), and `proxy-not-granted` (the proxy host
missing from `--allow-net` → `CXER0271` naming the proxy) — a third process, same lane shape.

## 5. Redirects on a token-endpoint POST — no fork

`complete`, `refresh` and `client-credentials` set `follow-redirects: false` on their token POST
regardless of the transport map; a 3xx from a token endpoint is `CXER5306` naming the status and
the `Location`, never a second POST of the code and the secret. `discover`'s GETs keep following
(a `/.well-known` redirect to a canonical host is ordinary), bounded as today. `oidc.md` §3.2
step 3 gains one sentence. **Spec text, delegated G3.**

## 6. `Retry-After` — RULED (a), the 1409-b placement made concrete

- **(a) surfaced, never slept on.** A 429/503 with `Retry-After` from any SSO dial is the same
  refusal it is today (`CXER5300`/`CXER5306`/`CXER3716`) with a `retry-after=<seconds>` attribute
  on the err (delta-seconds and HTTP-date both read, normalised to seconds). The caller —
  `sched`, the deployment, the interop driver — decides. DELETES nothing.
- **(b) the verb sleeps and retries** — refused: `complete` re-POSTing a code after a sleep is
  the exact double-redeem #1396 already names, and a pure-ish verb that blocks for a server's
  chosen interval is not a verb a fixture can grade.

## Spec text (delegated G3, flagged)

`oidc.md` §3.1 (the `transport` key on `config` and on `discover`), §3.2 step 3 (no redirect on
the token POST; `retry-after`), §9 (proxy: both hosts granted; env under `env`); `crypto.md` §3.10
(`jwks-fetch` opts = `transport`); `http.md` §3.1 (`proxy` row; the `tls` row unchanged and now
true), §3.6 (`SSL_CERT_FILE`/`SSL_CERT_DIR` under `env`); `net.md` unchanged. Commits carry
`RULED: 1396-a`.

## Conformance

Offline: `config` records `[transport …]` and `complete`/`refresh` read it (pinned by the
capability-denial path naming the PROXY host when the transport names one and the grant lacks
it — `CXER0271` is reachable with no socket); `follow-redirects` cannot be forced `true` on the
token POST; `Retry-After: 120` and an HTTP-date both normalise to seconds (pure parser, its own
case). Wire: the three proxy rows in the interop lane; the mTLS/pin trio in the real-socket band;
`SSL_CERT_FILE` pointing at a scratch bundle under `--allow-env` in the h2/tls test.

Nothing deferred. DPoP / mTLS-BOUND tokens (RFC 8705's binding of the token to the cert) stay
deferred per 1409-b — this record delivers the client certificate on the dial, not the binding.
