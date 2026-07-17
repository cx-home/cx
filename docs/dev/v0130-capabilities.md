# v0.13.0 — what a developer should know

The one-page tour of the v0.13.0 platform surface, with pointers into this
doc set and the owning specs. (VERSION stays 0.12.0 until the release is cut;
this describes the `release/0.13.0` integration branch.)

## Headline: the XAP distribution staircase

The full feature-distribution pipeline landed — composition engine
(`[$xap:compose]`/`compose-report`/`resolve`/`grammar-hash`), packaging
(`pkg-tree`/`pkg-seal`/`pkg-sign`/`pkg-publish`/`pkg-fetch`/`pkg-verify`/
`pkg-install`/`pkg-requires-closure`/`pkg-catalog`), entitlement VCs
(`license-issue`/`license-verify`), `pkg:` module references, and the
deployment host `[$xap:host]` (a XAP server is data plus adapters — zero
bespoke server code). Spec: the feature distribution & market spec + the
grammar composition spec. Docs: [registry setup](registry-setup.md),
[consuming](registry-consuming.md), [marketplace](marketplace.md),
[xap quickstart](xap-quickstart.md). The market-as-a-product, commerce
feature, and payment rails remain **specified, not implemented**.

## Store: single-node production service tier (complete)

`cx store-serve` — multi-threaded CSRP daemon with static/JWT/DID/OIDC auth,
RBAC + store-per-tenant isolation, Prometheus/OTel/structured logs, opt-in
gRPC with normative parity, binary wire (cxbin bodies + length-prefixed
frames), HTTP keep-alive + client connection pool, graceful drain with probe
grace, runtime config reload (SIGHUP / admin op, validate-then-swap), admin
plane (status/gc/mounts/config-reload), systemd/Docker artifacts, and thin
Python/Go/Rust clients driven through the one V protocol core. Docs:
[store: service](store-service.md), [management](store-management.md).

**Encryption-at-rest** shipped on pack, object-per-key, sqlite, and s3
(AEAD envelopes, KMS seam, fail-closed both mode directions); KEK rotation
shipped (#287 closed): `cx store-rotate-kek` / `[$store:rotate-kek]`. Doc: [store: security](store-security.md).

**The store management console** — a separate repo (`xap-store-console`),
free tier complete: a XAP of feature packages managing daemons over CSRP.
Spec: the store management console spec. Bootstrap: `cx store-token`.

## Database access — external engines (build-gated)

Native SQL/K-V access to external databases, distinct from the store: an
engine-neutral surface (`[$sql-open URL]`, `[$sql-exec H STMT PARAMS]`,
`[$sql-query H STMT PARAMS]` → `[rows [row [col 'v'] …] …]`, `[$sql-close]`;
`[$redis-open]`/`[$redis-cmd]`/`[$redis-close]`) with per-engine
implementations gated at build time: `-d cx_db_sqlite` (libsqlite3),
`-d cx_db_pg` (libpq), `-d cx_db_mysql` (libmysqlclient), `-d cx_db_redis`
(pure-V RESP). Parquet/Arrow-IPC file I/O is `-d cx_arrow_files`
(user-supplied Arrow, thin shim; also behind `cx table dump/load
--to=parquet|arrow`). The default build links none of them and says so
honestly (verified on this build):

```
[$sql-open "sqlite:///tmp/demo.db"]
; → CXER1100 …no SQL engine for scheme "sqlite"
;   (rebuild with -d cx_db_sqlite / -d cx_db_pg / -d cx_db_mysql)
```

Opens are capability-guarded (`write` for sqlite files, `net` for
server engines). Note the distinct flag family: `-d cx_db_*` is DB access;
sqlite as a *store substrate* (`sqlite://` in `store:open`) is part of the
store proper. A dedicated spec for the `$sql-*`/`$redis-*` surface has not
been written yet — the modules spec directory carries the older
Arrow-returning `sqlite:` module design; treat the engine surface as
implementation-defined until its spec lands.

## The agentic tier (x/) — protocol shims on a stable substrate

`cx-x/*` is in-tree but exempt from the frozen-stability promise (the x-tier
README): `cx-x/run` (the Runnable convention — verified:
`[$run:invoke [?fn ($x) …] "dev"]`), `cx-x/llm` (Ollama-protocol provider,
scoped net grant), `cx-x/mcp` + `cx-x/mcp-server` (MCP over jsonrpc/http —
tool handlers are ordinary CX, so **capabilities enforce the tool sandbox**),
`cx-x/a2a` + `cx-x/a2a-xap` (A2A with tasks→journal, messages→bus,
DID/VC auth).

## Identity & trust primitives

`did` (did:key offline, did:web cached), `vc` (verifiable credentials,
attenuating delegations), `session` (attach by token/cookie/DID), `authz`
(the PEP), `crypto` (JWT verify, ed25519). Verified taste:

```cx
[?lib 'cx-stdlib/crypto' :as crypto]
[?lib 'cx-stdlib/did' :as did]
[?let [= $kp [$crypto:ed25519-keypair]]           # --allow-random
 [= $d [$did:key-create $kp@public]]
 [$did:verify-control $d $challenge
   [$crypto:ed25519-sign $kp@private $challenge]]]   # → true
```

XSP — the XAP stream protocol frame codec (`cx-stdlib/xsp`) is shipped and
conformance-tested; v1 web binding is SSE + POST. Doc:
[clients and views](client-and-views.md).

## Reliability work a dev will feel

- **Serving model**: reactors do I/O, a bounded executor pool runs handlers;
  overflow answers 503 — slow handlers can no longer freeze the HTTP plane
  (the serving execution model section of the XAP architecture working
  notes). Plus SIGPIPE immunity on the serve path and the whole-request
  client timeout (`CXER4534`, the http module spec).
- **Deployment process model**: port-as-mutex, fail-fast collisions, no
  bespoke supervision (same notes; realized in xap-marine's Makefile/tools).
- **Memory**: the per-`[?let]`/`[?for]` env-clone storm fixed (loaded p99
  692→61 ms in the field case); vgc adaptive pacing; terminal heap
  exhaustion dies loudly instead of SIGSEGV; store file:// open/persist
  fully streamed (no more monolithic-encode heap staircases).
- **Workers**: `[?worker]` bodies run concurrently by default (own thread),
  matching spec semantics; the GC soundness lineage underneath is closed.
- **Datagram deadlines**: `recv`/`recv-from` honor read deadlines
  (`CXER4507`) instead of blocking forever (the net module spec).
- **SSE**: subscribe ack is atomic with topic registration — no missed-push
  window.
- `[$store:modify-doc]` accepts `[using FN]` — computed per-node replacement,
  applied client-side, identical content address on any backend.

## Where to look things up

Approved specs: `spec/03-approved/` (core language: code/cxdm/canonical;
std-lib per module; xap/xsp; CSRP + gRPC + console under misc; process).
Working specs (design-accepted, cited here where relevant):
`spec/02-working/` — XAP architecture notes, authoring process, composition
model, grammar composition, distribution & market, store service tier.
Conformance fixtures under `conformance/stdlib/*.cxd` are executable,
spec-first examples for every module — when in doubt, read the fixture.
