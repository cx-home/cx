# Rulings 2026-09-06 — #728 component 2: the four open items (CK-7 … CK-10)

**Status: RULED — CK-7 … CK-10 (a), owner 2026-09-06 ("rule the four open
items, all a if long-term best").** Each (a) was re-checked against the
long-term bar before being written as the recommendation; each states what
it DELETES. Ruling ids: `728-CK-7` `728-CK-8` `728-CK-9` `728-CK-10`. Branch
`design/789-workflow`. The four items are the ones
`rulings_2026_09_06_connector_is_a_feature_728.md` left open.

## Verified first — by grep and by reading the shipped code, not the prose

| Fact | Where | Result |
|---|---|---|
| `oidc` is "the relying-party half"; its §6 refusals are implicit/hybrid flows, ROPC, PKCE `plain`, dynamic registration, `alg:none`/`HS*` | `oidc.md` §1, §6 | `client_credentials` is NOT refused. `refresh` already takes `$client-auth::element` — the client-authentication machinery (§3.4, incl. `private_key_jwt`) a machine grant needs is there |
| `[?retry]` is specified with `max= backoff= delay= jitter= [on …]` and "sleep for the backoff-computed delay" | `code.md` §10.2.1 | spec text |
| The shipped `[?retry]` reads `:max`, `:on` and the body, and retries **with no delay at all** | `vcx/code/eval.v` `eval_retry` + the block comment above `eval_fallback`: "Backoff-delay computation is recognised but skipped … the actual sleep … happens in Phase 3.10" | **SHIPPED DEFECT** — `delay=`/`backoff=`/`jitter=` are accepted and ignored; a `[?retry max=5]` around a failing call hammers it five times back-to-back. Filed (see below). The connector inventory's row 7 (**T**: "retry with exponential backoff") is therefore WRONG on the backoff half — corrected |
| `[?retry]` retries ONLY when the body yields an `[err …]` value | `eval_retry`: `if !is_err_value(result) { return result }` | code |
| An HTTP non-2xx is a `[response status=429 …]` VALUE, never an `[err]` | `http.md` §2.4 | so a bare `[?retry]` around `http:get` never sees a 429 — the caller converts |
| `[?rate-limit]` already answers `[err code=cx-err:CXER0151 retry-after=DURATION]` | `code.md` §10.2.5 | **`retry-after=` on an err is an EXISTING convention** in the resilience band |
| `[?with-caps]` is deny-only: `[deny CAP (resource)?]`, grammar `[167]` | `security.md` §3 | spec text admits a RESOURCE on a deny |
| The shipped `[?with-caps]` collects bare capability NAMES only — no resource | `vcx/code/eval.v` `eval_with_caps`: `if lit.kind == .string_lit { denied << lit.str_val }` | **spec'd, unimplemented** — `[deny net "api.x.com:443"]` cannot be expressed today. Filed as #1332 |
| Process-level `--allow-net=host:port` IS resource-scoped and enforced | `security.md` §3 | code-backed (the CLI refuses unscoped read/write/env suffixes, enforces net) |
| A feature's manifest `needs` block already declares `[gateways kind=]` — the transports it opens; the concrete host is deployment data | `package.cxs` `[needs]`; CK-2 | schema text |
| The host invokes `<feature>:apply` with NO capability narrowing around it; "runs under the feature's granted slice" is a comment | `stdlib_xap_host_notd_wasm32_emcc.v` ~975–990 | code — the slice is authz (which VERBS), not caps (which HOSTS) |
| Pagination: no surface anywhere | whole tree | absent (inventory rows 18–22) |

## CK-7 — where `client_credentials` lands — RULED: (a)

- **(a) RULED — in `oidc`, as a fourth verb of §3.2:
  `client-credentials ($config $client-auth $now $opts)` → `[tokens access=
  token-type= expires-at= [scope …]]`, no ID token, no refresh token.** It
  POSTs `grant_type=client_credentials` (+ `scope` from `$opts`) to the
  discovered token endpoint under §3.4's client authentication — the same
  `[client-auth]` element, the same `private_key_jwt` assertion path, the
  same `CXER5306` on a non-2xx, the same `net` capability. The module's §1
  sentence is TRUED from "the relying-party half of OpenID Connect" to "the
  CLIENT half of OAuth 2.0 / OpenID Connect — the relying party's login dance
  and the machine client's token grant"; §6's refusals stand unchanged. A
  machine token has no refresh token: the caller (the `cx-connector`
  library, CK-5) re-mints before `expires-at`, exactly as it already must
  call `refresh` on a cadence (inventory row 16). **What it DELETES:** a
  sibling `oauth2` module, which would duplicate `discover`, `config`,
  `[client-auth]`, the error band and the capability text to add one POST.
  **Strongest counter:** the module is NAMED `oidc` and this grant is plain
  OAuth 2.0 with no identity in it. **Answer:** a name is not a reason for a
  second module (the orthogonality objective); the token endpoint, discovery
  and client authentication are one mechanism, and OIDC is itself a profile
  over the same endpoint. The scope sentence is the fix, not a new module.
- **(b) a sibling `oauth2` module.** REFUSED: two modules, one token
  endpoint; every connector would import both.
- **(c) inside the `cx-connector` library.** REFUSED: the token dance is not
  connector-specific — a plain program calling a machine API needs it too —
  and the library would grow its own `[client-auth]` handling.

## CK-8 — `Retry-After` — RULED: (a)

- **(a) RULED — `[?retry]` honors a `retry-after=` attribute on the err it is
  about to retry: the delay before the next attempt is the LARGER of the
  backoff-computed delay and `retry-after=` (a duration, or an absolute
  instant relative to `now`). No new attribute, no header name in the
  language.** This generalizes what `[?rate-limit]` already emits
  (`CXER0151 retry-after=DURATION`) — a rate-limited body and a rate-limiting
  server now tell the retry loop the same thing in the same word. The
  HTTP-specific half is the caller's, as `http.md` §2.4 already requires: the
  `cx-connector` library's gateway call turns a `429`/`503` `[response]`
  carrying `Retry-After` into an `[err … retry-after=…]` on the failure
  channel (seconds → duration; HTTP-date → instant), and a plain program does
  the same with three lines. **What it DELETES:** an engine-side retry loop
  (two loops, one call — `[?retry max=]` around an engine that also retries
  double-counts attempts); a `[?retry header="Retry-After"]` attribute (a
  wire protocol's header name inside a language directive); inventory row 8's
  "ruling needed".
  **Strongest counter:** the shipped `[?retry]` computes NO delay at all, so
  "the larger of" has nothing to be larger than. **Answer:** that is the
  defect filed below, not a reason to design around it; the ruling is written
  against the spec'd directive, and the fix lands `delay=`/`backoff=`/
  `jitter=` and `retry-after=` in one pass.
- **(b) the connector engine computes and sleeps.** REFUSED: a second retry
  mechanism under the first.
- **(c) `[?retry]` gains a `header=` opt.** REFUSED: HTTP in the language.

## CK-9 — pagination's vocabulary — RULED: (a)

- **(a) RULED — pagination is a `[paginate …]` CHILD element of `[gateway]`
  (the gateway's default), overridable as a `[paginate …]` child of a
  `[verb]`; `style=` is a CLOSED enum of the four styles the field has, each
  with its own named attributes; ONE stop rule for all four; `max-pages=` is
  REQUIRED.**

  | `style=` | Attributes | Continuation |
  |---|---|---|
  | `cursor` | `path=` (a CXPath over the response body yielding the next cursor), `param=` (the query parameter that carries it) | the cursor the last page yielded |
  | `page` | `param=`, `start=` (`0`\|`1`, default `1`), `size-param=`, `size=` | `param` + 1 |
  | `offset` | `param=`, `size-param=`, `size=` | `param` + `size` |
  | `link` | none | the `Link: rel="next"` header (RFC 5988) |

  **The stop rule, identical for every style:** stop when the continuation
  is ABSENT (a null/empty cursor, no `rel="next"`) OR the page is EMPTY, OR
  `max-pages=` is reached — in which case the walk yields what it has and an
  `[err code=… pages=]` on the failure channel naming the bound, never a
  silent truncation. `max-pages=` is required for the reason WF-18 made
  `attempts=` mandatory on `until`: an unbounded walk over a vendor's API is
  a runaway with someone else's rate limit as its only brake. **What it
  DELETES:** the `pagination::string` attribute CK-2 put on `[gateway]`
  earlier today (a style NAME cannot carry the path and parameter facts the
  inventory's rows 18–22 need — CK-2 under-specified it); four separate
  attributes; inventory row 22's separate "stop condition" item (one rule).
  **Strongest counter:** a single generic "next request = expression over the
  last response" covers styles nobody has named yet. **Answer:** that is
  computation in a declaration (the register's refusal), the page and offset
  styles need arithmetic no path expression has, and the four styles ARE the
  field — the inventory found no fifth. A closed enum that can grow by
  ruling is the honest shape.
- **(b) a bare `pagination=<style>` attribute.** REFUSED: under-specified, as
  above.
- **(c) one generic continuation expression.** REFUSED: computation in a
  declaration.

## CK-10 — per-feature network reach in one process (#747's prerequisite) — RULED: (a)

- **(a) RULED — the deny-only narrowing the language already specifies does
  it, once the spec'd resource form is implemented: the host wraps every
  invocation of a feature's `apply` and ingest — and the runner every call of
  a feature's projected defs (CK-3) — in `[?with-caps [deny net <host>]…]`
  where the denied set is (the union of every host the deployment binds to
  any feature's gateways) MINUS (the hosts bound to THIS feature's gateways).**
  A feature reaching another feature's host refuses `CXER0271` naming the
  host; a feature reaching a host bound to no feature is refused by the
  process grant, which stays the union. Nothing new is granted: the feature's
  manifest `needs [gateways kind=]` says what it OPENS (install-time
  consent), the deployment binds the concrete hosts (CK-2), and the
  narrowing is computed from those two facts at boot and re-computed on
  re-pin. **The prerequisite is the shipped gap, not a design:** `[deny CAP
  resource]` is grammar `[167]` and `eval_with_caps` drops the resource —
  filed below; until it lands, co-hosted features share the union and the
  deployment MUST say so (a `[runtime]` `co-hosted=true` opt-in that refuses
  to boot when absent and more than one feature binds a `net` gateway — the
  fail-closed default #747 asked for, so the regression it describes cannot
  arrive silently). **What it DELETES:** #747's open question as a design
  question (it becomes an implementation of a spec'd clause); a new
  allow-subset directive (`[only net …]`); one-process-per-adapter as the
  only isolation. **Strongest counter:** a deny list is O(features × hosts)
  and grows with the estate. **Answer:** it is data computed at boot, not
  authored; a hundred connectors over a few hundred hosts is a few hundred
  strings per feature, checked at an effect point that already string-matches
  the process grant.
- **(b) an `[only CAP resource…]` allow-subset clause.** REFUSED: a second
  narrowing vocabulary when the deny form with a resource is already
  specified and unbuilt — build the one that exists.
- **(c) one process per feature (#747's status quo).** REFUSED: thirty
  processes for thirty connectors is the operational split #747 exists to
  end.
- **Gate (normative for the landing):** two features, two mock hosts; each
  reaches its own, each refuses the other's with `CXER0271` naming the host;
  the same pair under `cx flow serve` through their projected defs; the
  `co-hosted=` refusal without the opt-in before the resource deny lands.

## Two shipped defects found, filed

1. **(#1331)** **`[?retry]` accepts `delay=`, `backoff=`, `jitter=` and ignores them — it
   retries with no delay.** `code.md` §10.2.1 says "sleep for the
   backoff-computed delay"; `eval_retry` has no sleep, and the block comment
   above it says the sleep "happens in Phase 3.10", which never landed the
   sleep. Every adopter reading the spec believes they have exponential
   backoff. Also: §10.2.1 cites "§10.2.5" for the backoff computation and
   §10.2.5 is `[?rate-limit]` — a dangling reference; the computation is not
   written anywhere. **prio:high** — a retry storm is the failure mode retry
   exists to prevent.
2. **(#1332)** **`[?with-caps]` drops the resource on `[deny CAP resource]`.** Grammar
   `[167]` and `security.md` §3 admit `[deny net "host:port"]`;
   `eval_with_caps` reads only the capability name, so a scoped deny
   silently denies the whole capability or nothing. The CK-10 prerequisite.

## Edit map — executed with this ruling

| Where | Change |
|---|---|
| `oidc.md` §1 | scope sentence trued (CK-7) |
| `oidc.md` §3.2 | `client-credentials` verb + paragraph; §7 reuses `CXER5306`/`CXER5303`; §9 adds it to the `net` row |
| `code.md` §10.2.1 | the `retry-after=` rule (CK-8); the dangling "§10.2.5" reference noted |
| `feature.cxs` | `[gateway pagination=]` attribute DELETED; `[paginate]` element on `[gateway]` and `[verb]` (CK-9) |
| `xap_feature_distribution_market.md` §6.3 step 5 | the per-feature deny narrowing and the `co-hosted=` fail-closed opt-in (CK-10) |
| `security.md` §3 | the resource form marked NAMED LANDING (spec'd, unimplemented) |
| `flow.md` §4.23 | one sentence: the runner narrows a feature's projected defs the same way (CK-10) |
| `design/728/connector_target_inventory_2026_09_06.md` | items 1, 2, 4, 6 → RULED; row 7 corrected (backoff absent); tally 12 T / 7 S |
| tracker | #1331 (retry backoff), #1332 (with-caps resource) filed; #747 commented |
