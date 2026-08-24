# `cx-stdlib/journal` — append-only, hash-chained, tenant-partitioned event log + fold→state

```cx
[module-meta name=journal tier=D status=current]
```

**Status:** Current

> **Per-aggregate streams (R2) — IMPLEMENTED (complete).** §2.1.1 generalizes the single-chain handle to **per-aggregate streams** (the scalability model XAP requires, [`xap.md`](xap.md) §14.2). The default stream is the **invisible degenerate case** (no stream attr/coordinate, legacy alias), so the prior single-chain behavior is preserved **byte-identically** (all original conformance cases green, unchanged). **Implemented** in `vcx/code/stdlib_journal.v` across the whole surface: the `stream` key on `append` (per-stream `seq`/head/chain + per-stream `expect-pos` conflict + parallel disjoint append); stream-scoped `read`/`slice`/`since`/`head`, `verify`, `fold`/`fold-slice`/`replay`, `snapshot`/`snapshot-verify`/`fold-from`, and `retain`/`compact` (per-stream seam-anchored copy-forward); the `streams` enumerator; and `file://` **reload** of named streams (via a persisted stream index). Tenant-wide state is the **caller's order-independent composition** of per-stream folds (the journal exposes per-stream `fold` + `streams`; it cannot merge opaque user states itself). Fixtures **journal-059…071** green (§10). The R2 graduation gate is **closed**; remaining graduation is the normal §11 checklist + user G3.

Built **on top of** shipped modules — [`hash`](../std-lib/hash.md) (the hash-chain
links), [`store`](../std-lib/store.md) (the persistence backend, e.g. `file://`), and
[`crypto`](../std-lib/crypto.md) (signing the derived **snapshot** artifacts, §4.8) —
and adds no new persistence, digest, or signing mechanism of its own. Named `journal`
(not `log`) because `log` is reserved for diagnostic logging ([`xap.md`](xap.md) §25.1).

## §0. Consistency with the in-review amendments (normative dependency)

Authored to be consistent with the same amendments the XAP sibling modules align to
([`http.md`](http.md) §0, [`xap.md`](xap.md) §25.1); on their approval
the cited semantics are load-bearing here. If any is rejected or changed at G3, the
marked clauses are revisited.

| Amendment | What journal relies on |
|---|---|
| `code.md` §9.1.2 — **four-channel model** | a committed entry is a **present `[entry]` value that flows** on the value channel (§2.4); a **failed-precondition append** (stale-tail, closed, denied) rides the **failure channel** (`[err]`, auto-propagates §9.2); a **read of an empty or out-of-range slice** rides the **absence channel** (empty node-set), **never `null`** (no-conflation guard). |
| SAP §1 — **a non-fault result is a VALUE** | `verify` returning *invalid* is a **present `[verification valid=false …]` value**, not an `[err]`: a broken chain is a successful *finding*, not a fault (§2.5, §3.6). `dry-run` returning a projected state that a real append would reject is still a present value (§3.5). |
| SAP §2 — **`[?try]`/`[catch]`/`[on-error]` retirement** | journal faults are handled with `[?match]` / `[?else]` / `[?fallback]` only; this spec never uses `[?try]`. Canonical call form is `[$journal:append …]` (`[head …]`), never any retired infix. |
| SAP §5 — **cancellation = `CXER0260`** + capability-revocation backstop | a long `replay`/`fold`/`verify` cancelled by `[?timeout]`'s cooperative `[?cancel]` surfaces the core `CXER0260` (not a journal code); a raw store effect after cancel hits `CXER0271`. The journal handle satisfies the `[?with-open]` closeable contract (SAP §5.1). |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

journal does **not** re-specify content-addressing, backends, transport encoding, or
the `store` capability model — those are `store`'s ([`store.md`](../std-lib/store.md)
§2, §4, §9). journal composes `store.open` / `put-doc` / `get-doc` / `query` and
inherits store's `CXER11xx` faults unchanged (§8). It does **not** re-specify digest
algorithms — those are `hash`'s ([`hash.md`](../std-lib/hash.md)); journal composes
`hash.sha256` / `hash.format-hex` / `hash.equals` for the chain links. It does **not**
re-specify signature algorithms or key handling — those are `crypto`'s
([`crypto.md`](../std-lib/crypto.md)); journal composes `crypto.sign` / `crypto.verify`
to sign the derived **snapshot** artifacts (§4.8), adding no signing primitive.

---

## §1. Scope

`cx-stdlib/journal` provides the **event-sourced authority primitive**: an
**append-only, hash-chained, tenant-partitioned, attributed log** and the
**deterministic projection** of that log into state. Concretely: open/attach a
journal over a `store` backend; `append` an attributed event (returning the committed
`[entry]` with its `seq` + content hash + predecessor link); `read` a range or
CXPath-filtered slice; `fold` the log into a state projection; `replay` a
deterministic re-execution and `dry-run` a no-commit preview; `verify` the
hash-chain integrity; `snapshot` a **signed, derived state checkpoint** so fold
need not re-run from genesis; `retain` a prune-only-behind-a-snapshot retention
policy; and `compact` a copy-forward of *snapshot + retained tail* into a **new**
segment. The journal is **deterministic → replayable, dry-runnable, hashable**
([`xap.md`](xap.md) §14) — that is the entire reason it exists and the property every
operation preserves. Snapshot/retention/compaction are **derived artifacts and
archival operations, never edits of the live chain** (§2.8, §4.5): they accelerate
and bound replay without ever introducing a mutate-in-place verb, so append-only +
hash-chain integrity hold permanently (§2.8).

**Layering (decision per [`xap.md`](xap.md) §25.1).** journal is a **thin module
built on `hash` + `store`** — a *separate* module, not folded into either (folding
would put event-sourcing semantics into the content-addressed blob store, or chain
semantics into the digest library). The architecture is:
**`hash` (digests) + `store` (persistence) → `cx-stdlib/journal` (ordered append +
chain + fold) → `xap` (the §2 serialized cascade) / `authz` (the policy fold)**.

**Module vs. the XAP cascade — they coexist, with journal as the substrate.**

| Surface | Home | Role |
|---|---|---|
| **`cx-stdlib/journal` module** (this spec) | `[?lib 'cx-stdlib/journal']` | the **ordered-append + fold + verify** primitive — first-class functions returning `[entry]` / `[verification]` / projected-state values |
| **the §2 synchronous serialized cascade** | [`xap.md`](xap.md) §2, §14 | the **composition rule** (emit ⇒ `journal:append` ⇒ `bus` dispatch in commit order ⇒ sub-emissions append before the next external message). `journal` is appended *by* the cascade; it does not drive it |

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| Content-addressing, blob backends (`file://`/`mem://`/remote), transport encoding, compression | `cx-stdlib/store` ([`store.md`](../std-lib/store.md)) |
| Digest algorithms, SRI, hex/base64 formatting of digests | `cx-stdlib/hash` ([`hash.md`](../std-lib/hash.md)) |
| **Pub/sub: subscribe, publish, ordered dispatch** | `cx-stdlib/bus` ([`bus.md`](bus.md)) — the cascade couples the two; journal is sub-agnostic |
| **The synchronous serialized cascade** (emit⇒append⇒dispatch in commit order) | `cx-xap` ([`xap.md`](xap.md) §14) — a composition rule, not a primitive |
| Authority/PEP: who may append/read which slice, delegations, guardian grants | `cx-stdlib/authz` ([`authz.md`](authz.md)) — journal **records** `:actor`/`:authority` as opaque attribution; it does **not** decide or verify authority |
| `(principal, tenant)` session resolution, token verification | `cx-stdlib/session` ([`session.md`](session.md)) — journal takes the resolved `:actor`/`:authority`/`:tenant` as inputs |
| Signing / non-repudiation tiers (T0/T1/T2) of **individual entries** | `cx-stdlib/authz` + `crypto` ([`xap.md`](xap.md) §22.9) — journal guarantees **integrity of history** (the chain); per-entry authorship non-repudiation is a separate, orthogonal property layered above. (Distinct from **snapshot** signing, §4.8 — journal *does* sign the derived snapshot **artifact**, which is the snapshot's own self-integrity, not per-entry authorship.) |

`cx-stdlib/journal` is **Tier-B runtime — necessarily impure** for the persisted
verbs (`open`/`append`/`read`/`replay`/`verify`/`snapshot`/`fold-from`/`compact` reach
`store`, and `snapshot` additionally reaches `crypto` to sign — §4.8). It introduces
**no new capability**: persistence is gated by **`store`'s existing capability model**
(§5) — a `file://` journal needs `read`/`write`; a remote-backed one needs `net`; a
`mem://` journal is capability-free ([`store.md`](../std-lib/store.md) §9). `fold` and
`dry-run` over an already-materialized in-memory slice are **pure** and capability-free.

## §2. Conceptual model

### §2.1. The journal handle, ownership, and the tenant partition

```cx
[journal tenant="acme" state="open" head-seq=147 head-hash="sha2-256:9f…"   # a journal — over a store backend
  on-close="journal/close"]
```

A `[journal]` handle wraps **one `store` backend partition for exactly one tenant**,
plus the cached chain head(s) (`head-seq`, `head-hash` — **per stream** in the §2.1.1
model; one default chain in the implemented single-stream case). Ownership model:

- A **journal** is **single-tenant by construction** — it is opened *for* one tenant
  (§2.2) and **carries no cross-tenant addressability**. There is no operation that
  takes a tenant argument *after* open; the tenant is fixed at the handle. This is
  the structural form of [`xap.md`](xap.md) §22.6 "tenant is a hard partition;
  cross-tenant access is structurally impossible" — not a runtime check but the
  **absence of any cross-tenant surface** (§4.1).
- **Append is serialized per stream** (§2.1.1; per *journal* in the single-stream
  case) — `append` is the single mutating verb and is **linearized within a stream**:
  concurrent appends to one stream from multiple workers are ordered by that stream's
  commit lock, each observing the prior commit's hash as its predecessor (§2.3); two
  appends **to the same stream** never share a `seq`, and appends to **disjoint
  streams commit in parallel**.
- **Reads are concurrency-safe** — `read`/`fold`/`replay`/`verify`/`dry-run` operate
  over committed, immutable entries and MAY run concurrently with each other and with
  an in-flight `append` (a reader sees a consistent prefix up to some committed
  `seq`; §4.4).
- `state`: journal ∈ `"open" | "closed"`.
- The handle carries the **closeable contract** (`on-close="journal/close"`,
  [`code.md`](../core/code.md) §8.10.7): `[?with-open]`-able, never raises
  `CXER0108`; `close` flushes any buffered commit, releases the underlying `store`
  handle, and is **idempotent**. An op on a closed journal →
  `cx-err:CXER4612 E_JOURNAL_CLOSED`.

### §2.1.1. Streams — per-aggregate partitioning within a tenant (the R2 scale model)

A tenant journal is not one chain — it is a set of independent **streams**, each its
own hash chain. A **stream** is an *aggregate*: a `string` routing key naming a unit of
contention and ordering (typically one principal, entity, or workspace). This is the
journal-level realization of [`xap.md`](xap.md) §14.2: the cascade is
serialized **per stream**, so a tenant with thousands of active principals does not
funnel every intent through one global chain.

- **Per-stream chain.** Each stream has its **own dense, gap-free, 1-based `seq`** (its
  own genesis at `seq=1`) and its **own `prev-hash`/`hash` chain** → per-stream
  tamper-evidence (§4.2). `seq` orders events **within a stream**; there is **no global
  cross-stream `seq`**.
- **Append serialized per stream → disjoint streams commit in parallel.** The commit
  lock (§2.1) is **per stream**; two appends to *different* streams never contend, so
  the throughput ceiling of a single global lock is gone. Two appends to the **same**
  stream linearize exactly as today.
- **The single-chain journal is the degenerate single-stream case.** Omitting the
  stream key targets a default stream **`:default`**; a journal that only ever uses
  `:default` behaves **identically to the pre-amendment module** (this is why the
  generalization is backward-compatible).
- **Tenant-wide state is the order-independent composition of per-stream folds.**
  Because streams are *disjoint* aggregates, a tenant-wide fold is
  `compose(fold(s₁), fold(s₂), …)` and is **independent of any cross-stream interleaving**
  (replaying each stream in isolation reproduces byte-identical state). There is **no
  total order across streams** to reconstruct — only a partial order, total within each
  stream (N-CORE-1, per stream).
- **No cross-stream transaction.** The journal gives per-stream atomicity only; an
  effect that must touch two streams is the **caller's explicit choreography** (xap's
  cascade emits a follow-on intent into the second stream, §14.2) — journal never spans
  a commit across streams.
- **Tenant-wide integrity rides the snapshot.** Per-stream chains give per-stream
  tamper-evidence; a **signed snapshot** (§3.7/§4.8) records **all stream heads** + its
  own hash, anchoring the *whole tenant's* history at a checkpoint — so tenant-level
  tamper-evidence needs no new mechanism (§4.2 generalized over the stream set).

A bad/empty stream key → `cx-err:CXER4610 E_JOURNAL_ARG_INVALID` (§3.2). The tenant
hard partition (§4.1) is unchanged and sits *above* streams: **tenant ⊃ stream ⊃
entries** — streams partition *within* one tenant's journal, never across tenants.

A journal stream is the truth point of the platform's delivery concept —
stream(store URL, retention `full`|`window`, independent read cursors, `pull` +
local `subscribe` tail-follow (§3.3), attributed) per the delivery concept spec
([`delivery.md`](../core/delivery.md) §3; RULED: U1.1a–U1.15a). The delivery
layer above it (groups, credit, serving) is fabric's; the wire carriage is the
store profile's (§6.1). Nothing in this module changes because of that naming.

**Stream ingestion (stream 9, `distributed_store.md` §2 — ruling L173).** A
named stream authored in ANOTHER journal of the same tenant (a replica-local
stream) joins this journal as a **disjoint aggregate** via
`ingest-stream` (§3.3): its entries re-land **byte-identical** — the entry
hash survives, the chain verifies unchanged here — and no sequencer is
consulted, because tenant state is already the order-independent composition
of per-stream folds (above). `append` re-hashes by design (new
`seq`/`ts`/`prev-hash` — an entry hash MUST NOT survive re-append), so the
identity-preserving path is ONLY ingestion, and only into a stream key that
is new here or a clean prefix extension of what this journal already holds;
a key held with a **different** chain refuses
`cx-err:CXER5050 E_SYNC_STREAM_DIVERGENT` (a replica stream is a new
aggregate, never a merge into an origin stream), an unverifiable or gapped
source refuses `CXER5051 E_SYNC_CHAIN_INVALID` with nothing landed, and the
default stream / reserved `cx:*` streams refuse
`CXER5052 E_SYNC_STREAM_RESERVED` (evidence streams propagate on the store
feed, never by hand-ingestion). **Stream keys name aggregates, never
topology:** the replica id does NOT enter the hashed `stream` field —
replica provenance rides the envelope's `actor`/`authority` and Lane-2
claims, so re-homing a replica never changes entry identity (the sync-band
codes are registered under `distributed_store.md` §8, governance §9.6).

### §2.2. `[entry]` — the attributed, hash-linked event record

A committed entry is the load-bearing value of this module. It **reuses the
attribution shape of [`xap.md`](xap.md) §22.6 exactly** — every event carries
`:actor` + `:authority` + `:tenant` — and adds the chain coordinates:

```cx
[entry seq=147 tenant="acme" stream="principal:dana"   # seq is per-stream (§2.1.1)
  actor="agent:ops-agent-1"            # the emitting party (opaque to journal — §2.6)
  authority="d-recon-77"               # the authority basis (a delegation/grant id — opaque)
  ts="2026-06-06T18:22:04.119Z"        # commit timestamp (assigned at append — §4.3)
  prev-hash="sha2-256:8c1a…"                 # content hash of entry seq=146 (the chain link)
  hash="sha2-256:9f04…"                      # content hash of THIS entry (over its canonical bytes)
  [event [do :refund-duplicate [order "o-5521"]]]]   # the payload — any CX value (§2.3)
```

Fields:

- `seq` — a **dense, gap-free, 1-based** integer ordinal **within its `stream`**
  (§2.1.1). `seq=1` is that stream's genesis; `seq=N` always has predecessor `seq=N-1`
  *in the same stream*. The journal authority *is* this **per-stream** order (N-CORE-1);
  there is no global cross-stream `seq`.
- `stream` — the aggregate this entry belongs to (§2.1.1). **Present only for
  non-default streams**; its **absence means `:default`** (so a default-stream entry
  renders and hashes byte-identically to the pre-amendment module — the backward-compat
  invariant). `seq`, `prev-hash`, and `hash` are all scoped to it.
- `tenant` — the journal's tenant; stamped on every entry (never a free argument).
- `actor`, `authority` — the attribution (§2.6); **opaque strings to journal** — it
  records them verbatim and never interprets, validates, or authorizes them (that is
  `authz`'s job).
- `ts` — the commit timestamp, assigned by `append` (§4.3), monotonic non-decreasing
  with `seq`.
- `prev-hash` — the `hash` of `seq-1`'s entry **in the same stream**; each stream's
  **genesis entry's `prev-hash` is the fixed sentinel `"genesis:"`** (§4.2).
- `hash` — the content hash of *this* entry computed over its **canonical bytes**,
  via `hash` (default `sha256`, §4.2). **The preimage is normative and frozen
  (corrected 2026-08-05, audit C1 — the previous text omitted the wrapper and
  the conditional `stream` binding, so spec and implementation disagreed on the
  bytes the chain covers):** the canonical text of a synthetic element

  ```cx
  [entry-canonical seq=<int> tenant=<string> stream=<string>?
                   actor=<string> authority=<string> ts=<string>
                   prev-hash=<string> payload=<tagged-address>]
  ```

  with attributes in **exactly that order**, `stream` bound **only for
  non-default streams** (§2.1.1): a default-stream entry omits the attribute
  entirely, while a named-stream entry makes cross-stream relabeling a
  detectable tamper. **The payload is DETACHED (I1 row 11, erasure L184 /
  audit C1 — ONE entry form, no dual-accept):** `payload=` carries the event
  payload's own Tier-1 tagged address (an envelope field — a chain
  coordinate, not domain data); the payload is stored as its OWN doc in the
  backing store, inside the same group-commit scope as the entry. The chain
  covers the ADDRESS, which is intact after a lawful shred, so `verify`'s
  three checks pass with payloads destroyed — exactly the erasure mandate.
  The read surface re-hydrates the `[event …]` child by address; a shredded
  entry whose address is **tombstoned** attaches the typed attributed
  `[erased … shred-request=]` tombstone as a DIRECT child — never an
  `[event]`: the tombstone records the payload's destruction, it is not the
  entry's event, so has-event stays false and the L119 pass-through/`erased=`
  accounting is unchanged (stream 20 W5) — while a payload missing with no
  tombstone reads event-less. Rotation carries payload docs with their entries; an
  already-shredded payload copies nothing — the shred survives rotation. The
  wrapper element name `entry-canonical` is part of the preimage. **The hashed
  bytes are the synthetic element's Tier-1 document-identity bytes** — the same
  bytes `cx hash` / `$cx:hash` cover (strict canonical text,
  [`canonical.md`](../core/canonical.md); the E2/L82 basis, stated 2026-08-10,
  #724 live-probe): a clean-room implementation recomputes any shipped entry
  hash from this section alone (conformance pin `journal-079`). Note this is
  NOT the §4.8 snapshot-signature basis (value emission) — the two bases are
  each frozen. The
  stored/announced digest is the self-describing tagged address
  `<multiformats-name>:<lowercase hex>` (`sha2-256:` default — I1 stream 19,
  ONE registry; the private `sha256`/`b3` spellings and the `b3:GENESIS`
  sentinel are retired, the genesis prev-hash is the algo-neutral
  `genesis:`); the tag is NOT part of the hashed bytes. Because `hash`
  covers `prev-hash`, the chain is **tamper-evident**: altering any past
  entry breaks every subsequent link (§2.5, §4.2).
- `[event …]` — the **payload**, an **arbitrary CX value** the caller supplies;
  journal moves it verbatim and never parses or content-negotiates it (cf.
  [`http.md`](http.md) §2.3 — journal moves *values*, the caller owns
  their meaning).

### §2.3. journal moves event values; meaning is the caller's; the chain is the journal's

The `append` `$event` argument is **any CX value** — journal stores it verbatim
inside `[event …]` and stamps the attribution + chain coordinates around it. journal
owns **only** the envelope (`seq`/`tenant`/`actor`/`authority`/`ts`/`prev-hash`/`hash`
+ ordering + the chain); the payload's *semantics* (a `[do …]` intent, a domain fact,
a resolver decision-with-`:reason`, [`xap.md`](xap.md) §19) are the caller's. This is
the same octets/value-boundary discipline as `http` (§2.3 there) and `store` — a thin
module owns its envelope, not its cargo.

### §2.4. A committed entry is a VALUE, not a fault (SAP §1)

A successful `append` returns the **committed `[entry]` value** — present, flowing on
the value channel — carrying its assigned `seq`, `hash`, and `prev-hash` so the caller
has the durable commit coordinates without a re-read. A `read`/`slice` returns a
**present `[sequence element]` of `[entry]` values** (possibly empty — §2.7). `fold`
returns the **projected state value**. None of these are `[err]`.

`[err]` is reserved for genuine faults — the append never committed, or a read could
not be served: a **stale-tail / concurrent-commit conflict** (`CXER1114`), a **closed
handle** (`CXER4612`), a **capability denial** (store's `CXER0271`, §5), a **backend
fault** (store's `CXER11xx`, §8), or a **malformed argument** (`CXER4610`).

### §2.5. A broken chain is a FINDING, not a fault (SAP §1) — and absence vs present-empty

Two distinct "nothing"s and one distinct "negative result", following the
four-channel discipline ([`http.md`](http.md) §2.4–§2.5):

- **`verify` of a corrupt chain → a present `[verification valid=false …]` value**,
  **not** an `[err]`. A tamper-evidence *finding* (a re-hash mismatch, a broken
  `prev-hash` link, a `seq` gap) is a **successful detection** — the whole point of
  the operation is to *report* integrity, so reporting "invalid" is success. `verify`
  raises an `[err]` only when it cannot *perform* the check (closed handle, backend
  fault, denial). The finding carries the first offending `seq` + the failure kind
  (§3.6). This is the load-bearing SAP §1 decision for journal.
- **An empty or out-of-range read → the absence channel (empty node-set).** `read`
  over a range with no entries (e.g. a fresh journal, or `from`/`to` past the head)
  returns the **empty `[sequence element]`**, which flows inertly — *not* `null`, and
  *not* an `[err]`. A `read` of a *single* `seq` that does not exist likewise yields
  **absence** (empty), distinguished from a present entry by construction.
- **A present-but-empty fold → a present-empty value.** `fold` over an empty journal
  returns the `$init` value unchanged (the identity case), a **present** value that
  flows — never `null`. So an empty-journal projection and a never-run fold are
  distinguished: the former returns `$init` present; there is no "absent state".

### §2.6. Attribution is recorded, never adjudicated (the authz boundary)

journal **records** `:actor` + `:authority` + `:tenant` on every entry and guarantees
their **integrity** (they are inside the hashed canonical bytes, §2.2). journal does
**not** decide whether the actor *may* append, whether the authority basis is valid,
unrevoked, or attenuating — that is the **single PEP decision function** in
[`authz.md`](authz.md) ([`xap.md`](xap.md) §22.3), invoked *before*
`append` by the `xap` cascade. The bright line: **journal is the tamper-evident
recorder of who-did-what; `authz` is the gate that decided they could.** Keeping
authorization out of journal is what keeps journal thin (N-IMPL-1) and lets `authz`
own the one enforcement point ([`xap.md`](xap.md) §22.10 answer 3).

### §2.7. Determinism — the contract that makes replay/dry-run/audit possible

Every projection operation is **deterministic in the log**: `fold`/`replay`/`dry-run`
over the same entries with the same fold function produce the **same** state, every
time, on any conforming runtime. This is the substrate [`xap.md`](xap.md) §14, §20.1
(trust calibrated as a fold over outcomes), §9.1 (handoff-brief replay), and §10.10
answer 4 (scenarios validated by dry-run) all require. Two obligations follow and are
**normative**:

- **The fold function MUST be pure** (`[?def … pure …]`, §3.4). A non-pure fold
  argument → `cx-err:CXER4611 E_JOURNAL_FOLD_IMPURE` at the call site (the purity
  scanner of `code.md` §6.5 classifies it; an impure fold would break determinism and
  is rejected, paralleling the value-channel posture being the *norm*). `dry-run`'s
  reducer is held to the same bar.
- **Replay reads the committed log only** — it never re-reaches external effects;
  re-execution is the pure fold over the recorded events, not a re-run of the original
  side-effecting handlers. (The cascade's *handlers* are external; `journal:replay`
  replays the *recorded results*, deterministically.)

### §2.8. Snapshot, retention, compaction — derived artifacts, never a rewrite

Event sourcing without checkpoints re-folds from genesis on every reconstruction; a
long-lived chain makes that unbounded. journal answers this with three **non-mutating**
surfaces — each is a *derived artifact* or an *archival copy-forward*, and **none**
adds a mutate-in-place verb. The append-only invariant (§4.5) and the hash-chain
tamper-evidence (§4.2) are preserved *by construction*: every new surface either reads
the chain to produce a separate value, or copies entries forward into a new segment;
no surface edits, deletes, or reorders a committed entry in the live chain.

- **Snapshot — a signed, derived state checkpoint (NOT a log rewrite).** A
  `[snapshot]` is the result of folding the log up to a chosen `seq=N` and **signing
  the fold result together with the chain anchor**:

  ```cx
  [snapshot tenant="acme" at-seq=147
    anchor-hash="sha2-256:9f04…"          # = entry seq=147's hash (the chain anchor — §2.2)
    hash-algo="sha256"              # the chain algo this snapshot is anchored against
    sig-algo="ed25519"              # crypto signing algo (§4.8) — non-repudiation of the artifact
    signature="sha2-256:7c21…"            # crypto signature over (canonical state-bytes + at-seq + anchor-hash)
    ts="2026-06-06T18:40:00.000Z"
    [state …]]                       # the projected state value at seq=147 — the fold output
  ```

  A snapshot is **`(state-at-seq-N, N, hash-of-entry-N, signature)`** — a *projection
  plus a binding to the exact chain position it was taken at*. It is **never written
  back into the chain** and never advances `head-seq`/`head-hash`; it is a separate
  artifact (persisted via `store` under a snapshot-namespaced key, or held in memory).
  Its **validity is checkable against the chain**: `anchor-hash` MUST equal the live
  `hash` of entry `seq=N` (§3.7 `snapshot-verify`), so a snapshot **cannot silently
  diverge** from history — a snapshot taken against a tampered or wrong chain fails
  verification (`CXER4615`/`CXER4613`). The signature (§4.8) additionally makes the
  artifact **non-repudiable and integrity-checked on its own bytes**, so a forged or
  truncated snapshot is detectable independent of chain access.

- **`fold-from` — fast reconstruction over a snapshot.** `[$journal:fold-from $j
  $snapshot $fn]` folds **only the entries after `$snapshot.at-seq`** onto the
  snapshot's `[state …]`, yielding the same state a full `fold` would — but without
  re-folding the snapshotted prefix. This is the table-stakes acceleration: `fold-from`
  ≡ `fold` *in result* (an equivalence pinned by a fixture, §10), strictly faster in
  work. `fold-from` first checks the snapshot against the chain anchor (§3.7) so a
  divergent snapshot can never seed a wrong state.

- **Retention — a prune-only-behind-a-snapshot policy.** A `[retention]` policy
  (`keep-after-seq` / `keep-after-time` / `keep-N`) declares **which prefix of the
  chain may be archived/pruned**. The hard rule (§4.9): **a prefix may be pruned ONLY
  when a valid signed snapshot covers it** — i.e. the prune boundary `≤` some
  snapshot's `at-seq`, and that snapshot verifies against the chain. You can **never
  prune un-snapshotted history**, so audit + replay-from-snapshot still hold for every
  pruned entry's *effect* (it survives in the snapshot's signed state). Pruning is
  **archival** (move the pruned prefix to a cold/archive `store` namespace, or drop it
  from a `mem://` working set) — it is **not** a mutation of *live chain semantics*:
  the surviving tail's `prev-hash` links are unchanged, and the pruned prefix is
  reconstructable from its snapshot + (if archived) the cold copy. `retain` records the
  policy + the covering snapshot; the actual archival is performed by `compact` (the
  copy-forward), keeping a single integrity argument.
  **The cover rule extends to registered live materializations** (live modes
  L133; the pack spec `live.md` §7): a `cx-stdlib/live` materialization over a
  journal source registers itself in the journal's own store (alias namespace
  `cx-live/materialization/<tenant>[/s/<stream>]/<name>`), and `retain` refuses
  a pruning boundary (`CXER4616`) while a registration exists on the stream —
  a journal-source relation is the stream's entire history, i.e. the fold's
  recompute basis (`maintained ≡ recompute`; the derived-state posture makes a
  lost checkpoint a full replay), so history under a registered materialization
  may not be compacted away. Client-anchored observers get the honest
  resume-below-retention refusal instead; they pin nothing.

- **Compaction — a copy-forward into a NEW segment, never in-place.** `[$journal:compact
  $j $opts]` produces a **new journal/segment** whose genesis-equivalent is a covering
  `[snapshot]` followed by the **retained tail** (the entries the §4.9 retention policy
  keeps), leaving the **original journal byte-for-byte intact**. Compaction is a
  **copy-forward** (read original → write new), never an edit of the source. The
  compacted segment is itself a valid append-only hash-chain: its first entry carries
  `prev-hash` bound to the embedded snapshot's `anchor-hash` (a documented seam, §4.10),
  so `verify` and `replay` work *across the snapshot boundary* (§3.6/§3.5). Because the
  original is untouched, compaction is reversible by discarding the new segment; nothing
  about the live chain's history is lost or rewritten.

The integrity argument in one line: **snapshots and compacted segments are signed
projections/copies bound to chain positions; retention may only discard a prefix a
valid snapshot already preserves; the live chain is never edited.** Therefore
append-only (§4.5) and hash-chain tamper-evidence (§4.2) survive all three operations.

### §2.9. Valid time and corrections — the reserved payload vocabulary (stream 8)

The journal's own time is **transaction time**: per-stream `seq` is the order
authority (§4.3) and `ts` is metadata. **Valid time** — *when a recorded fact is
true in the domain* — is **payload domain data** under a normative **reserved
attribute vocabulary** ([`bitemporal.md`](../core/bitemporal.md), rulings
L115/L117). The two axes never fuse: valid time lives in the **hashed payload**
(Tier-1, caller-owned), transaction time in the **hashed envelope** (`seq`, `ts` —
journal-owned); one entry `hash` covers both; there is no third channel.

- **`valid-from=` / `valid-to=`** on an **element-shaped event payload** bound the
  fact's validity as the **half-open interval `[from, to)`** (no boundary
  double-count). An **open end is the ABSENT attribute — never `null`** (the
  no-conflation rule: `null` in either position is vocabulary misuse). Carriers
  are ISO `date` or `datetime`/instant scalars (day-grain business validity is
  real); `valid-from` must be **strictly before** `valid-to` when both are
  present. This is **two reserved attributes, not an interval kind**
  ([`cxdm.md`](../core/cxdm.md) §2.4). A payload that is not element-shaped
  carries no valid-time vocabulary (such facts are read as valid always).
- **`[supersedes hash=<entry-address> relation=…]`** — a payload child linking a
  correcting entry to the entry it corrects **by content address** (never by
  `seq`: stream-local and compaction-fragile; the hash composes with Lane-2
  claims). `relation` is **type-strict**: the **atom** `:correction` (the prior
  fact was WRONG — superseded across its whole valid extent) or `:amendment`
  (the prior fact was right then, wrong now — its valid interval closes at the
  amender's `valid-from`). The third taxonomy member, **`:assertion`**
  (a retroactive new fact — nothing superseded), is the **classification of a
  VT-bearing entry with NO `[supersedes]` child**, never a spelling on a
  linkage. The three fold differently; conflating them is what makes
  restatement unauditable.
- **Append never parses the payload** (§2.3 holds byte-identically): the
  vocabulary is recognized on the **read side** — the bitemporal projection and
  the `coherence` verb (§3.6). **`verify` stays syntactic**: a dangling
  `supersedes` is a **FINDING from `coherence`**, never a chain break.
- **Erasure (stream-20 binding input, L119):** valid-time metadata lives in the
  payload and is therefore **shreddable with it** — hoisting a temporal skeleton
  would need a fourth channel (forbidden) or envelope ownership of domain data
  (violates the journal boundary). A valid-time read over shredded entries
  **reports its redaction count visibly** (finding-not-fault) and never
  silently under-reports.

### §2.10. Declared payload schema — the reserved version vocabulary (stream 21)

Payload **schema identity** rides the same channel valid time does: **payload
domain data under a reserved attribute name**
([`schema_event_evolution.md`](../core/schema_event_evolution.md),
ruling L146 — "version tags are PAYLOAD vocabulary, never envelope"; the exact
coin stream 8 spent for valid time, spent the same way).

- **`schema=`** on an **element-shaped event payload** declares the payload's
  schema identity **by content address** (the E2 type identity of its
  declaration form, e.g. `sha2-256:…`) — never a version *string*: two schema
  revisions are two content addresses; nothing links them intrinsically (the
  Lane-2 `[schema-lineage]` claim carries the relation). The reservation is
  **naming, not a kind** ([`cxdm.md`](../core/cxdm.md) §2.4): the carrier is
  an ordinary string-scalar attribute.
- **Undeclared is legal.** One journal, mixed payload vocabularies is the
  ruled posture (the crypto one-algo-per-instance rule does not generalize:
  the algo is envelope, uniform by construction; vocabulary is payload,
  heterogeneous by construction). An upcaster chain may discriminate on
  `schema=`, on shape, or on both — coverage is the chain's contract (§3.9),
  and a refusal names the declared schema *or its visible absence*.
- **Append never parses the payload** (§2.3 holds byte-identically): the
  vocabulary is recognized on the **read side** — the upcaster seam (§3.9)
  and the `coherence` coverage pre-flight. `verify` stays syntactic.

### §2.11. Data subjects — the reserved erasure vocabulary (stream 20)

Erasure identity rides the same channel valid time (§2.9) and schema identity
(§2.10) do: **payload domain data under reserved attribute names**
([`erasure_compliance.md`](../std-lib/erasure_compliance.md), rulings
L182/L183 — the stream-8 template spent a third time). The reservation is
naming, not a kind ([`cxdm.md`](../core/cxdm.md) §2.4).

- **`subject=`** on an element-shaped payload root declares the payload's
  **data subject** (a DID or tenant-scoped subject id). A subject-bearing
  payload's detached doc (§2.2) is stored **whole** (one sealed object —
  structural sharing never crosses the shred boundary) and sealed under the
  subject's own destroyable key (SEK — [`store.md`](../std-lib/store.md) §9.2),
  so destroying that one key crypto-shreds exactly this subject's payloads.
- **`nonce=`** is reserved alongside it and **MANDATORY whenever `subject=` is
  present**: at least 128 bits of CSPRNG entropy, inside the sealed payload
  and nowhere else (the nonce IS content — covered by the payload address,
  destroyed by the same shred). It defeats the surviving-digest oracle: after
  a shred the payload's address remains in the chain, and without the nonce a
  low-entropy plaintext could be confirmed against it. A subject-bearing
  payload with a missing, short, or derived nonce refuses
  **`cx-err:CXER4619 E_ERASURE_NONCE_REQUIRED`** — never a warning. The nonce
  MUST NOT be derived from journal coordinates (`seq`, `ts`, `stream`,
  `prev-hash`, tenant, actor, authority) or the subject id — **append checks
  byte-equality against its coordinates** (the one place they all exist);
  presence and length are checked where the payload doc lands (the store's
  subject arm).
- Unlike §2.9/§2.10 this vocabulary IS enforced at **write time** — an
  unshreddable subject declaration (or an oracle-restoring nonce) must never
  be recorded, so the read side has nothing to repair (fail-closed, the
  erasure posture).
- **The reserved hold-stream `cx:legal-hold`** (ruling L188): a legal hold is
  a SIGNED Lane-2 `[legal-hold [subject …]|[hash …] [signer …] [at …]
  [sig alg=:ed25519 value= key=]]` claim VALUE journaled to this per-tenant
  named stream — it **binds from its journaled position onward** (a hold not
  yet journaled does not bind; the honest rule). The signature covers the
  claim's strict canonical text with the `[sig]` child removed; verification
  proves possession of `key=` — binding that key to the named signer identity
  is authz/vc's domain (the §2.6 attribution posture). Appends to this stream
  are write-time validated (`CXER4620` — same rationale as above: immutable
  entries, so an unbindable hold must never be recorded); `legal-holds`
  (§3.3) is the fail-closed load; enforcement (hold-beats-shred, the head pin
  + commit-lock re-check, blocking shred AND re-snapshot) is the
  `erase-subject` command's precondition
  ([`erasure_compliance.md`](../std-lib/erasure_compliance.md) §8).
- **The reserved erasure stream `cx:erasure`** (ruling L187, stream 20 W4):
  the `erase-subject` command (§3.3) journals its attributed shred-request
  record here — the record the read side reconciles against (a payload gone
  WITH a covering record is a lawful-erasure finding; one WITHOUT is
  fail-closed unavailable — audit M29), and the command's own durable dedup
  record (audit M31: keyed by the opaque `request=` token, exempt from its
  own shred reach — the records that prove an erasure happened are not
  erasable by it). **Direct appends refuse `CXER4622`** — write-time
  enforced like the hold stream, because a hand-authored erasure record
  would forge the evidence basis. The command also maintains the per-tenant
  **shred-generation** (`shred-generation`, §3.3): advanced atomically with
  each committed record, never by a refused one — the ENV-quadrant input
  that stales pre-shred snapshot fold-ids (§2.8, `CXER4640`).

## §3. Public function surface

Signature notation matches [`cx-stdlib/store`](../std-lib/store.md) and
[`http.md`](http.md). `::element` is a handle, `[entry]`, or
`[verification]`; `::map` is an options record; `::path` is a CXPath; `$fn` is a
**pure** function value (§2.7). An optional read that may be absent is typed
`[returns element]` (or `[returns [sequence element]]`) and yields the **absence
channel** (empty) when nothing is present (§2.5).

### §3.1. Opening / attaching a journal

```
[?def open   scope=public impure [returns element] ($store-url::string $tenant::string $opts::map {}) ...]
[?def attach scope=public impure [returns element] ($store::element   $tenant::string $opts::map {}) ...]
[?def close  scope=public impure [returns null]    ($journal::element) ...]
```

`open` opens (or re-opens) a journal for one `$tenant` over a `store` backend URL
(`file://…`, `mem://`, a remote URL — all of [`store.md`](../std-lib/store.md) §2.2),
internally opening the `store` and binding the tenant partition (§4.1). `attach`
binds a journal to an **already-open `[store]` handle** (so a process can share one
backend across tenants, each a separate `[journal]` over a tenant-rooted partition).
Both **read the current chain head** to populate `head-seq`/`head-hash` (an empty
partition → `head-seq=0`, `head-hash="genesis:"`); they **do not** replay or verify
the whole chain at open (that is explicit `verify`, §3.6). `close` flushes, releases
the underlying `store` (only the one `open` itself opened — an `attach`ed store is the
caller's to close), and is **idempotent**.

The trailing `$opts::map {}` is a **defaulted positional parameter**
(`grammar.ebnf [153b]` — a bare space-separated VALUE after the type, as in
[`http.md`](http.md) §3.1), so `[$journal:open $url $tenant]` ≡
`[$journal:open $url $tenant {}]`. `opts`:

| Key | Default | Meaning |
|---|---|---|
| `hash-algo` | `"sha256"` | the `hash` algorithm for chain links + entry hashes (`"sha256"`/`"sha384"`/`"sha512"`/`"blake3"`, [`hash.md`](../std-lib/hash.md) §3.1); fixed for the life of the chain (§4.2) |
| `create` | `true` | create the partition if absent; `false` + absent → `CXER4601` |
| `read-only` | `false` | when `true`, `append` → `CXER4603` (a read/verify/replay-only attach) |
| `clock` | impl monotonic-UTC | the `ts` source for `append` (§4.3); a supplied controllable clock (the demo's, [`xap.md`](xap.md) §25.1 timer enhancement) makes commit timestamps deterministic in fixtures |
| `encrypt-key-id` | (none) | the backing store's encryption-at-rest tenant key-id ([`store.md`](../std-lib/store.md) §9) — forwarded to the store open, so a chain sealed at rest is opened by naming its key here rather than through a `store`-open-then-`attach` detour |
| `encoding` / `compression` | (substrate default) | the backing store's at-rest framing ([`store.md`](../std-lib/store.md) §3), forwarded the same way |

### §3.2. Appending — the single mutating verb

```
[?def append scope=public impure [returns element] ($journal::element $event::any $attribution::map) ...]
```

`append` commits one event and returns the committed `[entry]` (§2.2, §2.4).
`$attribution` is a `::map` carrying `{actor: …, authority: …}` (both `string`, §2.6)
plus an optional **`stream`** routing key (`string`, §2.1.1; default `:default`); the
`tenant` is **not** an argument — it is the journal's, stamped automatically (the
structural tenant partition, §2.1/§4.1). A missing/empty `actor` or `authority`, or a
malformed `stream` → `cx-err:CXER4610 E_JOURNAL_ARG_INVALID` (every committed entry is
attributed, no anonymous appends). `append`:

1. resolves the target **stream** (`$attribution.stream`, default `:default`) and
   acquires **that stream's** commit lock (§2.1.1 — appends to *disjoint* streams never
   contend and commit in parallel);
2. assigns `seq = stream-head-seq + 1`, `ts` from the `clock` (§4.3),
   `prev-hash = stream-head-hash` (the head of *that* stream);
3. computes `hash` over the canonical bytes (§4.2, which now include `stream`) via `hash`;
4. persists the entry through `store` (§4.1) and advances **that stream's** head;
5. releases the lock and returns the `[entry]`.

**Optimistic-concurrency form (optional).** A caller that read the head and wants to
append *only if the tail has not moved* passes `$attribution.expect-pos`; if the
target **stream's** `head-seq` ≠ that value at commit, `append` raises
**`cx-err:CXER1114 E_STORE_REF_CONFLICT`** (the caller re-reads and retries). This is
the per-stream conflict primitive XAP's §4.1 "first-commits-wins, second is a rejection"
rests on. Without `expect-pos`, `append` always appends at the current head of that
stream (last-writer-extends, never overwrites).
(`expect-pos` is THE position encoding of the ONE CAS vocabulary —
E3/L84, I5 stream 1; the former `expect-pos` spelling is retired,
cutover-first. Semantics unchanged: "the stream is currently at
position N".)
The chain is **append-only**: there is no `update`/`delete`/`truncate` verb (§4.5).

### §3.3. Reading — range and CXPath slice

```
[?def read   scope=public impure [returns element]            ($journal::element $seq::int) ...]
[?def slice  scope=public impure [returns [sequence element]] ($journal::element $from::int $to::int $stream::string "" $opts::map {}) ...]
[?def since  scope=public impure [returns [sequence element]] ($journal::element $from::int $stream::string "" $opts::map {}) ...]
[?def query  scope=public impure [returns [sequence element]] ($journal::element $cxpath::path) ...]
[?def source scope=public impure [returns [sequence element]] ($journal::element $stream::string "") ...]
[?def head   scope=public pure   [returns element]            ($journal::element) ...]
[?def head-fresh scope=public impure [returns element]        ($journal::element) ...]
[?def legal-holds scope=public impure [returns element]       ($journal::element $opts::map {}) ...]
[?def erase-subject scope=public impure [effects [read] [write]] [returns element] ($journal::element $subject::string $attribution::map $opts::map {}) ...]
[?def shred-generation scope=public impure [returns int]      ($journal::element) ...]
[?def ingest-stream scope=public impure [effects [read] [write]] [returns element] ($journal::element $source::element $stream::string) ...]
[?def register-replica scope=public impure [effects [write]] [returns element] ($journal::element $id::string $opts::map {}) ...]
[?def deregister-replica scope=public impure [effects [write]] [returns element] ($journal::element $id::string $opts::map {}) ...]
[?def apply-erasures scope=public impure [effects [read] [write]] [returns element] ($journal::element $origin::element) ...]
[?def saga-run scope=public impure [effects [read] [write]] [returns element] ($journal::element $saga-def::element $opts::map {}) ...]
[?def saga-status scope=public impure [returns element] ($journal::element $id::string $opts::map {}) ...]
```

- `read $seq` — the single `[entry]` at `seq`, or the **absence channel (empty)** if
  `seq` is out of range (§2.5). `seq < 1` → `CXER4610`.
- `legal-holds $opts` — the §2.11 hold-stream load (stream 20): every retained
  `cx:legal-hold` entry re-validates **fail-closed** (`CXER4620` naming `seq`
  — never a skip); returns `[holds stream= head= count=]` with one
  `[hold seq= subject=|hash= signer= at=]` per binding hold. `opts`
  `{subject: …}` / `{hash: …}` filter. `head` is the hold-stream position the
  `erase-subject` precondition pins (a hold binds from its journaled position
  onward). Conformance pin `journal-128`.
- `erase-subject $subject $attribution $opts` — **the recorded RTBF command**
  (stream 20, [`erasure_compliance.md`](../std-lib/erasure_compliance.md)
  §7/§8): journal an attributed `[erase-subject [subject] [request] [sek]…
  [holds-head] [generation] [head-set] [docs] [report]]` record to the
  reserved per-tenant stream **`cx:erasure`**, then execute the crypto-shred
  walk — destroy the subject's SEK(s) and remove the subject mapping,
  tombstone every subject-sealed doc (T+E through the §7b.1 store funnel —
  attribution survives), purge the derived surfaces (computation-cache
  entries referencing the scope, materialization checkpoints, in-process
  dedup records and plaintext caches, the durable envelope residue), across
  the backing store AND every store the segment index names (predecessors +
  their recorded archive copies). **Hold-beats-shred:** the hold-stream head
  pins before commit and re-checks under the writing commit lock; a signed
  hold binding the subject (or a scoped hash) refuses **`CXER4621`
  atomically** — the shred-generation never advances, so no re-snapshot is
  forced (the hold suspends both). **The KMS destroy is strictly
  POST-COMMIT** (the forward-only pivot: once the record commits with the
  pin satisfied, no later hold binds that shred — by position, visibly).
  **Idempotent:** the journaled record IS the durable dedup record — its
  `request=` id is an opaque ≥128-bit CSPRNG token (`opts.request` may name
  it explicitly; the audit-M31 carve-out: never the subject id, and the
  record is exempt from its own shred reach); a resubmission (same subject +
  same token) answers `[deduped <the recorded shred-report>]` and re-runs
  only the idempotent walk (self-heal after a crashed walk), while a NEW
  token is a NEW command — re-landed subject data stays erasable. Direct
  appends to `cx:erasure` refuse **`CXER4622`** (a hand-authored record
  would forge the M29 read-time evidence). Returns the balanced
  `[shred-report subject= request= docs= erased= already-erased=
  subject-keys= derived= checkpoints= dedup-records= stores= disposed=
  generation= holds-head=]` — `docs = erased + already-erased`, always.
  Requires non-empty `actor` + `authority` (`CXER4609`); local custody only
  (`CXER1144` on remote/wire handles). The chain itself stays append-only:
  the command's only chain mutation is its own record — payload destruction
  is off-chain key destruction, which is the whole §2.2/§5 design.
  Conformance pin `journal-129`.
- `ingest-stream $source $stream` — **replica-local stream ingestion**
  (stream 9, [`distributed_store.md`](../std-lib/distributed_store.md)
  §2 — the §2.1.1 ingestion rule as a verb): register `$source`'s named
  stream into this journal's tenant as a disjoint aggregate. Entries re-land
  **byte-identical** (the entry hash survives; `verify` passes unchanged
  here); the source chain is verified in full BEFORE anything lands
  (`CXER5051` refusal, nothing partial); idempotent re-ingest answers
  `ingested=0`, and a grown source lands only the tail (clean prefix
  extension). Divergent stream key → `CXER5050`; default / reserved `cx:*`
  target → `CXER5052`. Payload docs ride along when the source holds them
  (content-addressed dedup makes the copy a no-op after a `fetch`); a
  payload lawfully shredded at the source still lands its entry — the chain
  covers the ADDRESS (§2.2), the evidence records replicate on their own
  stream, and the count is visible (`payloads-absent=`, present only when
  non-zero). Returns the balanced `[ingest-report stream= entries= ingested=
  already-present= head= hash=]` — `entries = ingested + already-present`,
  always. Same tenant only (`CXER4610`). Conformance pin `journal-133`.
- `shred-generation` — the tenant's current shred-generation (0 before any
  committed erase). The §2.8 snapshot-reach input: bind it into the fold
  identity passed as `fold-id` to `snapshot`/`fold-from`/`retain`, and every
  committed shred moves the current fold-id — pre-shred snapshots then
  refuse `fold-from` with `CXER4640`, forcing a re-snapshot under the
  post-shred fold (stream 21's staleness machinery, no new invalidation). A
  refused (held) erase never advances it.
- `slice $from $to` — entries with `from ≤ seq ≤ to` (inclusive, 1-based) in `seq`
  order; an out-of-range or empty window → the **empty `[sequence element]`** (§2.5).
  `from > to` → `CXER4610`.
- `since $from` — `slice $from head-seq` (the tail from `$from` to the current head);
  the common incremental-read form (a reader catching up from its last-seen `seq`).
  `slice`/`since` take a trailing `opts` whose `valid-at` engages the §3.8
  bitemporal projection over the collected range; `at-seq` does **not** ride them
  (the explicit range IS the TX axis — a teaching refusal, `CXER4610`).
- `query $cxpath` — entries whose `[event …]` payload (or envelope attrs) match a
  **CXPath predicate** ([`store.md`](../std-lib/store.md) §6 query semantics), e.g.
  `[$journal:query $j "/event/promo[= $_@valid-from '2026-02-01']"]`; returns
  matches in `seq` order, **empty** when none match. Predicates are homoiconic CX
  code, so an attribute comparison is written in the **prefix operator form** —
  the infix spelling `[@name='value']` is retired and the engine refuses it with a
  migration diagnostic ([`code.md §5.5.2`](../core/code.md)). This is the auditable
  "why/when did X happen" query ([`xap.md`](xap.md) §22.10 answer 4) over a single
  tenant's log.
- `source $stream` — the stream's retained committed `[entry]` sequence in `seq`
  order (`:default` when the stream key is omitted). This is THE journal-stream
  **source-reference form** for planar comprehensions
  ([`code.md §7.8`](../core/code.md), stream-2 ruling L97):
  `[?for [in $e [$journal:source $j "orders"]] …]` binds `$e` to each entry, and
  the reference's E3 position is the stream's `head-seq` — a planar plan over a
  journal stream is invalidated by per-stream advance, exactly the
  `(source-ref, position)` cache key of `planar_algebra.md` §3. A stream's
  appends are the natural **∂ input** (`[insert ENTRY]` — journal streams
  are append-only, so their deltas are monotone by construction) for the
  incremental sub-fragment's delta rules (`planar_algebra.md` §2, stream-2
  ruling L101): live maintenance over a journal source consumes the same
  ∂ vocabulary streams 3 and 4 carry.
- `head` — the `[entry]` at the handle's cached `head-seq`, or **absence** on an
  empty journal. Declared **pure**: it answers the handle's CACHED view and makes
  **no freshness claim** (stream 7 F1, #714 item 1) — under a second writer
  (another process on a local root; another client behind a read-only view) it
  MAY report a stale position **with no signal**. It satisfies neither
  `:read-your-writes` freshness nor a declared-fresh need; the coherence reach of
  the cached view is exactly the backing store handle's own reach (§4.6).
- `head-fresh` — the **declared-fresh head**: the distinct, **impure** verb that
  re-resolves the durable head **through the substrate** before answering
  (stream 7 F1). A read-only local handle re-takes its private snapshot view
  from disk through the normal capability-gated open path (a capability denial
  or integrity refusal propagates loudly — never a silently-unrefreshed
  answer); a remote-backed handle reads the daemon's table; `mem://` answers
  the live instance. Absence on an empty stream, like `head`.

All reads are **tenant-confined by construction** — every one operates over the
handle's partition; **no read takes a tenant argument**, so a cross-tenant read
is not expressible (§4.1, [`xap.md`](xap.md) §22.6).

**Reads are stream-scoped (§2.1.1).** Because `seq` is per-stream, `read`/`slice`/`since`/`source`/
`head` operate on **one stream** — each gains a trailing defaulted `stream::string`
(default `:default`), e.g. `[$journal:read $j 147 "principal:dana"]`. `streams`
enumerates the journal's stream keys; `query $cxpath` matches **across all streams**
(it filters by payload, not `seq`) and returns matches grouped by stream then `seq`. A
read on an unknown stream → the **absence channel** (empty), never an error.

**Local tail-follow — `subscribe` (RULED: U1.13a).**

```
[?def subscribe scope=public impure [returns element] ($journal::element $opts::map {}) ...]
```

`subscribe` returns a subscription (the delivery contract —
[`delivery.md`](../core/delivery.md) §4) over one stream (`opts.stream`,
default `:default`), delivering committed `[entry …]` elements in `seq` order:
entries strictly above `opts.from` (default: the current head — a live tail)
replay first, then the subscription goes live. This is the LOCAL form of the
profile's feed (§6.1) — one delivery concept, embedded and served (rung
`:complete-ordered` in both positions); it consumes with the general
`[?receive]`/`[?select]` (code.md §10.4). `opts.from` below the retained floor
(§2.8 compaction / §4.9 cover rule) refuses loudly with
`cx-err:CXER4617 E_JOURNAL_RESUME_GAP` (the `resume-below-retention` refusal
class — delivery.md §4), never a silent partial replay. The subscription is
closeable; closing the journal terminates it.

**Time-addressed positions — `seq-at` (RULED: U1.14a).**

```
[?def seq-at scope=public impure [returns element] ($journal::element $ts::datetime $opts::map {}) ...]
```

`seq-at` resolves a timestamp to a position: the largest `seq` in the stream
(`opts.stream`, default `:default`) whose commit `ts` ≤ `$ts` (well-defined:
`ts` is monotonic non-decreasing with `seq` per stream, §4.3), or the **absence
channel** if the stream has no entry at-or-before `$ts`. **Time is an index into
positions, never a cursor form** (delivery.md §5): the returned `seq` feeds
`since`/`slice`/`subscribe from=`; no cross-stream time ordering is implied or
expressible.

### §3.4. Folding — the state projection (pure reducer)

```
[?def fold scope=public impure [returns any] ($journal::element $fn      $init::any $stream::string "" $opts::map {}) ...]
[?def fold-slice scope=public impure [returns any] ($journal::element $fn $init::any $from::int $to::int) ...]
[?def fold-value scope=public pure [returns any] ($entries::[sequence element] $fn $init::any) ...]
```

`fold` reduces a **stream's** committed log into a state projection: starting from
`$init`, it applies the **pure** reducer `$fn` (`(state, entry) → state`) over every
entry of the stream in `seq` order, returning the final state. This is **THE authority**
— a stream's state is *defined* as `fold(stream)` ([`xap.md`](xap.md) §14). It
gains a trailing defaulted `stream::string` (default `:default`, §2.1.1).
**Tenant-wide state is the order-independent composition** `fold-tenant` =
`compose(fold(s₁), …, fold(sₙ))` over the journal's streams (§2.1.1): because streams are
disjoint aggregates, the composition has **no cross-stream ordering dependence** — the
result is identical for any stream interleaving (the §14.2 determinism guarantee). `fold-slice` folds only
`from..to` (a windowed projection / incremental fold over a known prefix-state).
`fold-value` is the **pure** core: it folds an **already-materialized** `[sequence
element]` of entries (e.g. the result of `slice`/`since`) with no backend access — so
a caller can `since` once and fold many times purely, and `fold`/`fold-slice` are
exactly `read-then-fold-value`.

`fold`'s trailing `opts` carries the §3.8 bitemporal axes: `at-seq` (the TX pin —
the stream-7 L125 always-on guard rides it exactly as on `replay`: a pinned fold
below a pruned floor refuses `CXER4991`, resolve through the covering snapshot)
and `valid-at` (engages the pre-fold projection) — and the §3.9 upcaster seam:
`upcast` (a pure chain, composed BEFORE the projection). Without any of the
three, the shipped fold path runs byte-identically.

`$fn` **MUST be pure** (§2.7); an impure `$fn` → `cx-err:CXER4611
E_JOURNAL_FOLD_IMPURE`. Determinism is guaranteed: same entries + same `$fn` + same
`$init` → same result, always (§2.7).

**Not a cut (stream 7 F8, #714 item 6).** The tenant-wide composition is
annotated **at the verb** (`fold`/`streams` fn-docs): each stream's head
snapshots independently and **no cross-stream linearization is claimed**
(§4.3/§4.4) — the verifiable multi-stream READ coordinate is `:at-head-set`,
the signed snapshot head-set (§3.7), and committing across streams is
stream 10's entirely.

### §3.5. Replay and dry-run — deterministic re-execution / no-commit preview

```
[?def replay  scope=public impure [returns any] ($journal::element $fn $init::any $opts::map {}) ...]
[?def dry-run scope=public impure [returns element] ($journal::element $event::any $attribution::map $fn $init::any) ...]
```

- `replay` — a **deterministic re-execution** of the log into state via the pure `$fn`
  (§2.7); semantically `fold` with **replay options** (`opts.from`/`opts.to` to bound
  the window, `opts.at-seq` to reconstruct the state at a past `seq` — the
  "rewind/branch is log navigation" of [`xap.md`](xap.md) §18.2, and the
  last-in-command anchor of §9.1; `opts.valid-at` engages the §3.8 bitemporal
  projection over the replayed window — the fourth-quadrant query is
  `{at-seq: N, valid-at: T}`; `opts.upcast` engages the §3.9 upcaster seam
  ahead of it, and a pinned replay uses TODAY'S chain). `replay` reads the committed log only and reaches
  **no external effect** (§2.7) — it is the audit/time-travel projection, repeatable
  and regression-gateable.
- `dry-run` — **preview an append WITHOUT committing it**: it computes what the
  state-after-this-event *would be* — `fold-value (since 1) $fn $init` then one more
  `$fn` step with a **provisional** (uncommitted, `seq = head-seq+1`) `[entry]` built
  from `$event`/`$attribution` — and returns a `[dry-run state=… provisional-entry=[entry …]]`
  value. **Nothing is persisted; `head-seq`/`head-hash` do not move.** This is the
  speculative-composition / anticipation machinery ([`xap.md`](xap.md) §19) and the
  policy-scenario validator ([`xap.md`](xap.md) §22.10 answer 4 — "could a student
  ever go full-auto?" is a `dry-run` of the decision function against the scenario).
  Because it commits nothing, `dry-run` over a `read-only` journal is allowed and is
  **capability-free beyond the read** it already performed.

Both hold `$fn` to the **pure** bar (§2.7, `CXER4611`).

### §3.6. Verifying — hash-chain integrity (a finding, not a fault)

```
[?def verify       scope=public impure [returns element] ($journal::element $opts::map {}) ...]
[?def verify-slice scope=public impure [returns element] ($journal::element $from::int $to::int) ...]
```

`verify` walks the chain and **re-hashes every entry**, checking that (1) each entry's
`hash` equals the re-computed content hash over its canonical bytes (§4.2), (2) each
`prev-hash` equals the predecessor's `hash`, and (3) `seq` is dense and gap-free from
genesis. It returns a **present `[verification …]` value** (§2.5):

```cx
[verification valid=true  checked-from=1 checked-to=147 head-hash="sha2-256:9f04…"]
[verification valid=false checked-from=1 first-bad-seq=88 reason=:hash-mismatch]   # a FINDING
```

`reason` ∈ `:hash-mismatch` (re-hash ≠ stored `hash`) | `:link-broken`
(`prev-hash` ≠ predecessor's `hash`) | `:seq-gap` (missing/duplicate `seq`) |
`:genesis-invalid` (`seq=1` `prev-hash` ≠ the `"genesis:"` sentinel). `verify-slice`
checks only `from..to` (anchoring `prev-hash` of `from` against `from-1`'s stored
`hash`). `opts.from`/`opts.to` bound `verify` likewise. A `[verification valid=false]`
is **not** an `[err]` — it is the successful tamper-evidence finding (§2.5,
[`xap.md`](xap.md) §22.6). `verify` raises `[err]` only when it cannot *perform* the
walk: closed handle (`CXER4612`), backend fault (store `CXER11xx`), denial (`CXER0271`).
`verify`/`verify-slice` also walk **across a snapshot/compaction boundary** (§4.10):
the first entry of a compacted segment anchors its `prev-hash` to the embedded
snapshot's `anchor-hash`, so a verify that begins at the seam checks that link instead
of the `"genesis:"` sentinel (a `:link-broken` finding if the seam does not match).

**The payload reconciliation axis (stream 20, ruling L186 / audit M29 —
[`erasure_compliance.md`](../std-lib/erasure_compliance.md)).** The chain
verdict stays **syntactic**: the entry hash covers the payload **address**
(§2.2), so all three checks pass with payloads lawfully destroyed —
`:payload-missing` is **never** a chain-break reason (else every shredded
journal would report invalid forever, destroying the audit story). Payload
integrity is an **additive report axis** on a valid walk: every detached
payload in the range is fetched and re-hashed, and every payload-missing (or
rehash-failing) entry **MUST reconcile against an ATTRIBUTED erasure record**
— the journaled shred-request whose `[docs]` scope covers the address, or the
address's own `[erased …]` tombstone. The report becomes

```cx
[verification valid=true checked-from=1 checked-to=2 head-hash="sha2-256:…"
  redacted=1 payloads-verified=3 unattributed-missing=0]
```

with **any `unattributed-missing > 0` a LOUD finding** — a payload gone with
no lawful erasure record is evidence of tampering or key loss, never silently
counted among the redactions. The axis attrs appear only when the accounting
engaged (some payload missing — the §2.9 present-when-non-zero posture), all
three together (the balanced-account shape); a clean chain keeps the classic
report byte-identically. `verify-slice` reconciles its own range the same way.

**`coherence` — the semantic linter over the §2.9 reserved vocabulary (stream 8).**

```
[?def coherence scope=public impure [returns element] ($journal::element $opts::map {}) ...]
```

`verify` checks bytes; `coherence` checks the **valid-time vocabulary's meaning**.
It walks the retained entries (`opts.stream` scopes to one stream; default = the
default stream then named streams sorted), checks each element-shaped payload's
`valid-from`/`valid-to` carriers and `[supersedes]` linkage against §2.9, and
resolves each **well-formed** supersedes target against the **tenant's** retained
entry hashes (linkage may cross streams). It returns a present
`[coherence tenant=… checked=N findings=K …]` value whose `[finding …]` children
are **FINDINGS, never errors** (§2.5):

```cx
[coherence tenant="acme" checked=4 findings=2
  [finding kind=:dangling-supersedes seq=3 hash="sha2-256:00ff…"]
  [finding kind=:temporal-vocab-invalid seq=4 reason="supersedes missing hash="]]
```

`kind` ∈ `:temporal-vocab-invalid` (a non-temporal or `null` carrier; an empty
half-open interval; a string-spelled or unknown `relation`; a `[supersedes]`
missing `hash=` or carrying a non-address) | `:dangling-supersedes` (a
well-formed target that is **no retained entry's hash**, in a tenant with **no
pruned floor** — a definite dangle) | `:supersedes-unverifiable` (target not
retained, but some chain has a pruned floor — the target may lawfully live in
pruned history; the honest report, never a false dangle claim). One finding per
defect: a malformed `[supersedes]` is never also resolved for linkage. Shredded
payloads cannot be checked and are counted **visibly** (`erased=N`, present when
non-zero — the §2.9 honest-reporting posture). `coherence` raises `[err]` only
when it cannot perform the walk (closed handle `CXER4612`, backend fault,
denial), exactly like `verify`.

**The stream-21 coverage pre-flight rides the same verb** (§3.9): given
`opts.upcast` (a pure chain), `coherence` dry-applies the chain to every
event-bearing retained entry and reports each refusal as an
**`:uncovered-entry`** finding (an output violating the seam contract as
**`:upcast-invalid`**) carrying `seq`, `hash`, the declared `schema=` when
present, and the chain's own refusal as `reason=` — "would this fold cover
all N entries?" answered before any fold runs. Coverage is a coherence
question, never a `verify` one.

### §3.7. Snapshots, retention, compaction — derived checkpoints + archival copy-forward

```
[?def snapshot        scope=public impure [returns element] ($journal::element $fn $init::any $opts::map {}) ...]
[?def snapshot-verify scope=public impure [returns element] ($journal::element $snapshot::element $opts::map {}) ...]
[?def fold-from       scope=public impure [returns any]     ($journal::element $snapshot::element $fn $opts::map {}) ...]
[?def resnapshot      scope=public impure [returns element] ($journal::element $fn $init::any $snapshot::element $opts::map {}) ...]
[?def retain          scope=public impure [returns element] ($journal::element $policy::map) ...]
[?def compact         scope=public impure [returns element] ($journal::element $opts::map {}) ...]
```

All six are **non-mutating on the live chain** (§2.8, §4.5): `snapshot`/`fold-from`/
`resnapshot` read it, `retain` records a policy + checks coverage, `compact` copies
forward into a *new* segment. None advances `head-seq`/`head-hash` of the source
journal.

- `snapshot` — folds the log up to `opts.at-seq` (default `head-seq`) with the **pure**
  `$fn`/`$init` (§2.7) — **`opts.upcast` (RULED: SEA-1)** engages the §3.9 chain over the
  folded prefix exactly as on `fold` (upcast THEN the projection; a pure chain, `CXER4611`;
  uncovered entries refuse `CXER4641`), so a snapshot **under the current fold** is
  spellable when that fold includes a chain — and returns a **signed `[snapshot at-seq=N
  anchor-hash=… signature=… [state …]]`**
  value (§2.8). The `signature` is computed by `crypto` (§4.8) over the canonical bytes
  of `(state + at-seq + anchor-hash + hash-algo)` — shorthand; **the normative
  signed preimage incl. wrapper, field order, `stream?`, and the reserved
  `fold-id?` slot is §4.8's `snapshot-canonical` form**; the signing key is supplied via
  `opts.signing-key` (a `crypto` key handle) — **absent key + a tier that requires
  signing → `cx-err:CXER4614 E_JOURNAL_SNAPSHOT_UNSIGNED`** (a `mem://` test tier may
  opt out via `opts.sign=false`, yielding an *unsigned* snapshot usable for `fold-from`
  but **not** as a retention cover — §4.9). **`opts.signer` (S6.4, F5(b))** records a
  signer DID on the returned value as an **unsigned outer `signer="<did>"` attribute**
  alongside `sig-algo=`/`signature=` — a verify-time key hint **outside the frozen
  §4.8 preimage** (the preimage is untouched; no second signing epoch). An *unsigned*
  snapshot cannot carry the hint — no signature binds it — so `opts.sign=false` +
  `opts.signer` is the authoring-time misuse `CXER4610`, never a silently-ignored
  forgeable claim. Absent
  `opts.signer`, the handle's own identity is recorded **only when it is the signing
  key's own identity** (the handle DID equals the key's derived `did:key`) — otherwise
  no `signer` is recorded: the pre-S6.4 shape, so existing artifacts stay
  byte-identical. `anchor-hash` is set to entry `at-seq`'s
  live `hash`; `opts.at-seq` beyond head → `CXER4606`. The snapshot is a **derived
  artifact**: it is returned as a value and MAY be persisted by the caller (or
  `opts.persist=true` writes it to a snapshot-namespaced `store` key) — it is **never**
  appended to the chain. **`opts.fold-id` (stream 21, L147)** records the snapshot's
  **fold identity** — the determinism quadruple `(entries, chain, $fn, $init)` as a
  **computation address** (fn ⊕ chain ⊕ env, built with the stream-5 machinery:
  `[$cx:hash [computation …]]` over the fn's Tier-1 address, the chain's Tier-1
  address, and `[$cx:env]`) — **filling §4.8's reserved signed-preimage slot**:
  omitted while unset (pre-stream-21 artifacts byte-identical), covered by the
  signature when set, so the `fold-from` check below is on a signed field, never on
  forgeable envelope data. A non-address value is `CXER4610`. The tenant SET form
  refuses `opts.fold-id` (`CXER4610` — its preimage reserves no slot; record fold
  identity per stream with `stream=` + `fold-id=`). **Multi-stream (§2.1.1):** a tenant snapshot records the **set
  of stream heads** `{(stream, at-seq, anchor-hash)}` and folds the tenant-wide
  composition (§3.4); the `signature` covers that whole set, so **one signed snapshot is
  the tenant-wide integrity anchor** across all per-stream chains (§4.2). A
  single-stream snapshot is the `:default`-only case of this.
  **The SET form (stream 7 W6 — this is the `:at-head-set` cut substrate,
  [`consistency_vocabulary.md`](../core/consistency_vocabulary.md)):**
  a tenant snapshot (no `stream=`) over a journal WITH named streams answers
  `[snapshot tenant= hash-algo= sig-algo= …]` carrying one
  `[h (stream=S)? at-seq=N anchor-hash=H [state V]]` member per non-empty
  stream — the default chain first (no `stream` attr, the invisible-default
  rule), then named streams **sorted by name** — each member's `[state]`
  folded with the caller's reducer, the cut taken under the journal op
  funnel (one instant across all streams). `opts.at-seq` is refused on the
  set form (`CXER4610` — the set cuts at the heads; pin a single stream
  with `stream=` + `at-seq`); a retention-pruned member refuses
  `CXER4991` exactly like the single form. `snapshot-verify` answers
  `[snapshot-verification valid=… form=set …]`, checking every member's
  anchor against the live chain (`valid=false reason=:anchor-mismatch
  stream=S` names the failing stream) and the ONE signature over the set
  preimage. `fold-from` consumes a **single-stream** snapshot only — a set
  member carries its own `[state]` and position, so the refusal (`CXER4610`)
  teaches the consumption path: `fold-slice` from `at-seq+1` seeded by the
  member state, composed per §3.4 (the journal never merges opaque user
  states). A **retention cover** stays a single-stream snapshot (retention
  is per-stream, §4.9). Pre-W6 this surface silently snapshotted the
  (possibly empty) default chain — a FALSE artifact signed as the tenant
  state; fixtures journal-099…103 pin the repaired behavior.
- `snapshot-verify` — checks a `[snapshot]` against the chain and against its own
  signature, returning a **present `[snapshot-verification valid=… …]` finding** (a
  value, not an `[err]` — same SAP §1 posture as `verify`, §2.5/§3.6). It validates
  (1) `anchor-hash` equals the live `hash` of entry `at-seq` (else `valid=false
  reason=:anchor-mismatch`, the divergence guard of §2.8), (2) the signature verifies
  against the key (else `:signature-invalid`), and (3) `hash-algo` matches the chain's.
  **Key resolution (S6.4):** when the snapshot carries the `signer=` outer hint (§4.8),
  step (2)'s verify key is resolved **from the `signer` DID** (v1: the self-describing
  `did:key`/`did:peer:0` forms) and **never** from the unsigned `verify-key=` field —
  a mismatched `signer`/key fails step (2) (`:signature-invalid`), and a `signer` that
  does not resolve offline is `valid=false reason=:signer-unresolvable`. Absent
  `signer`, the key resolves as before (the snapshot-carried `verify-key=`) — fully
  back-compatible.
  An *unsigned* snapshot verifies its anchor only (`reason=:unsigned` is a `valid=true`
  caveat, never a fault). The unsigned tier is reserved for snapshots carrying **no
  signature**: a snapshot where `signature=` rides without a registry-verified
  `sig-algo=` (absent or `none`) is `valid=false reason=:unsupported-suite` — a
  stripped suite tag is the crypto-agility downgrade attack (stream 19 L36), never a
  silent downgrade to anchor-only validity. **Appointment (S6.4, opt-in):** `opts.require-appointed=true`
  additionally checks that the crypto-valid snapshot's `signer` DID holds the
  **`snapshot-sign`** capability — over `opts.scope` when given — in the
  caller-designated registry `opts.authz` (an open `[authz-store …]` handle; the same
  VC-compiled capability calculus as the profile's §6.1 rows). Crypto validity and
  appointment are DISTINCT checks (§4.8): not appointed — or no `signer` to check,
  including an unsigned snapshot — is the **finding** `valid=false
  reason=:not-appointed` (the registry's `[deny …]` explanation as a child; a value,
  never a fault), while `require-appointed` without an open `[authz-store]` handle is
  the misuse `CXER4610` (`E_JOURNAL_ARG_INVALID`). Omitted → the pure public-key check
  above, byte-identically the pre-S6.4 finding.
- `fold-from` — reconstructs state **fast**: it `snapshot-verify`s `$snapshot` against
  the chain (a `valid=false` anchor → `cx-err:CXER4615 E_JOURNAL_SNAPSHOT_SEQ_MISMATCH`
  / a bad signature → `cx-err:CXER4613 E_JOURNAL_SNAPSHOT_SIG_INVALID`), then folds
  **only entries `at-seq+1 .. head`** onto `$snapshot.[state …]` with the pure `$fn`,
  returning the same state a full `fold $fn $snapshot-init` would. `$fn` held to the
  **pure** bar (`CXER4611`). **The fold-identity check (stream 21, L147):** the
  trailing `opts` take **`fold-id`** — the caller's CURRENT fold identity (the
  quadruple's computation address, §4.8) — and **`upcast`** (the §3.9 chain, covering
  the TAIL entries). A **declared** `fold-id` against a snapshot carrying a different
  identity — **or carrying none** — refuses
  **`cx-err:CXER4640 E_JOURNAL_FOLD_ID_MISMATCH`** with the re-snapshot teaching:
  the snapshot is frozen output of some *other* fold, and folding forward from it
  yields silently-stale state (the exact shape this closes; #716). Undeclared keeps
  the shipped path byte-identically. The `fold-from ≡ fold` equivalence is thereby
  **conditional-and-checkable** (the former fixture compared both paths under the
  SAME `$fn` and was blind to a vocabulary change): with the matching declared
  identity and the chain over the tail, `fold-from` equals the full fold under the
  chain — pinned by fixture (§10, `journal-122/123`).
- `resnapshot` — **the L147 maintenance discipline as a verb (RULED: SEA-1):**
  re-derives `$snapshot` at its **own** `at-seq`/`stream` under the **current**
  fold quadruple. It verifies `$snapshot` against the chain (anchor →
  `CXER4615`; signature, when present → `CXER4613`; the SET form is refused
  `CXER4610` exactly as on `fold-from` — re-derive per stream), **requires**
  `opts.fold-id` (the current identity, a computation address — absent or
  non-address → `CXER4610`: a re-derivation without a declared identity has
  nothing to stamp), then folds `1 .. at-seq` with the pure `$fn`/`$init` under
  `opts.upcast` (uncovered → `CXER4641`; a retention-pruned prefix refuses
  exactly as `snapshot` — a re-derivation needs the genesis prefix) and signs
  per §4.8 (`opts.signing-key` / `opts.sign=false` / `opts.signer`, all the
  `snapshot` rules verbatim), returning the new snapshot carrying
  `fold-id=opts.fold-id`. **Idempotent (SEA-1f):** a `$snapshot` already
  carrying the declared identity returns unchanged — nothing landed, nothing
  re-derives. The `CXER4640`/`CXER4616` re-snapshot teachings name this verb.
  All refusals are existing codes; `resnapshot` mints none.
- `retain` — records a **`[retention]` policy** (`$policy` = one of
  `{keep-after-seq: N}` / `{keep-after-time: TS}` / `{keep-N: K}`) plus the covering
  snapshot it is validated against (`$policy.snapshot`, a `[snapshot]` value). It
  computes the prune boundary `B` (the highest `seq` eligible to be pruned) and
  **enforces the §4.9 cover rule**: `B ≤ $policy.snapshot.at-seq` **and** that snapshot
  must `snapshot-verify` valid-and-signed, else **`cx-err:CXER4616
  E_JOURNAL_RETENTION_UNCOVERED`** (you may not declare a prune of un-snapshotted
  history). **The current-fold reading (stream 21, L147/#716):** `$policy.fold-id`
  declares the caller's CURRENT fold identity — a cover carrying a **different**
  identity, or **none**, then refuses `CXER4616` with the re-snapshot teaching
  (§4.9: covered-under-the-current-fold); undeclared keeps the shipped check
  byte-identically. `retain` does **not** itself delete anything — it returns a
  `[retention boundary=B covered-by-seq=N policy=…]` value that `compact` consumes;
  separating *policy* from *archival* keeps one integrity argument (§2.8). A policy
  whose boundary exceeds head, or a malformed `$policy`, → `CXER4610`.
- `compact` — performs the **copy-forward**: given `opts.retention` (a `[retention]`
  from `retain`) and `opts.target` (a `store` URL/handle for the new segment), it writes
  a **new journal/segment** = the covering `[snapshot]` (as the segment's seam record)
  followed by the **retained tail** (`boundary+1 .. head`), each retained entry copied
  **verbatim** (same `seq`/`hash`/`prev-hash` — bytes unchanged, §4.10). It returns a
  `[journal …]` handle (or `[compaction …]` descriptor) for the new segment and
  **leaves the source journal byte-for-byte intact** (§2.8) — `compact` is a copy, never
  an in-place edit, so it can be discarded losslessly. If `opts.archive` names a cold
  `store` namespace, the pruned prefix `1..boundary` is **moved there** (archival, not
  deletion) before the source's working view drops it; without `archive`, the prefix is
  retained in place (compaction then only *produces* the new segment). A target that
  collides with a live chain → `CXER4600`; a missing/uncovered retention → `CXER4616`.
  The target open is **derived** — it inherits the source's at-rest posture and
  `hash-algo` (§4.12), it does not open bare.

### §3.8. The bitemporal read — `{at-seq: N, valid-at: T}` (stream 8)

```
[?def temporal-slice scope=public pure [returns [sequence element]] ($entries::[sequence element] $opts::map {}) ...]
```

The bitemporal read is a **substrate-provided PURE projection**
`[sequence entry] → [sequence entry]`, parameterized by
`(tx-position, valid-instant)` and composed **before** the fold — the §3.4 fold
contract is untouched (pure `$fn`, deterministic), and **stream 21's upcasters
take the same seam** (a pure entry-sequence → entry-sequence stage ahead of the
reducer). The naming is **disambiguated by assignment** (bitemporal.md L118):
**`at-seq`** is the transaction-time pin (stream 7's spelling — the L125
always-on pin guard rides it everywhere), **`valid-at`** is the valid-time
instant; **`as-of` is not used on any new surface** (`authz` keeps its shipped
`as-of` with a cross-reference). The two axes never fuse: `valid-at` rides
read/fold/replay **opts**, never `consistency=`.

**Surfacing.** `fold` and `replay` take both axes in their trailing `opts`
(`fold` gains the trailing `$opts::map {}`; its `at-seq` pin refuses
`CXER4991` below a pruned floor exactly as `replay`'s — resolve through the
covering snapshot). `slice`/`since` take `valid-at` in their trailing `opts`
(their explicit range **is** the TX axis, so `at-seq` there is a teaching
refusal, `CXER4610`). `temporal-slice` is the **pure core** over
already-materialized entries (the `fold-value` twin — `since` once, project
and fold many times purely). `fold-slice` deliberately takes no temporal
opts: its windowed prefix-state contract composes as
`temporal-slice ∘ fold-value`.

**The four-quadrant table (normative).**

| | TX = now (head) | TX = `at-seq: N` |
|---|---|---|
| **VT = now (no filter)** | the shipped raw fold/read | the shipped raw TX cut (replay-to-N) |
| **VT = `valid-at: T`** | the projection at the head | **THE bitemporal query** — "what did we know at N about T" |

Quadrants 1–2 are the shipped raw reads — **no payload parsing, byte-identical
behavior**. A given `valid-at` **engages the projection**:

1. **TX cut** — entries with `seq ≤ N` (the given range for `slice`/`since`).
2. **The as-of collapse (§2.9 taxonomy):** every in-cut **`:correction`**
   target (by content address) is **excluded across its whole valid extent** —
   a corrector's own later supersession never restores its target (restoring a
   corrected fact is a NEW assertion); every in-cut **`:amendment`** clamps its
   target's `valid-to` to the amender's **own `valid-from`** (the earliest
   clamp wins; an `:amendment` without its own `valid-from` has an undefined
   close point — `CXER4618`). **`:assertion`s coexist** — nothing superseded.
3. **The `valid-at` filter** — keep the surviving entries whose effective
   half-open `[from, to)` contains `T` (absent end = unbounded; a payload with
   no valid-time vocabulary is valid always).

**Honesty rules.** A shredded (event-less) entry cannot be judged and **passes
through visibly** — filtering it out would silently under-report a redaction
(§2.9 erasure posture). Malformed reserved vocabulary under an ENGAGED
projection refuses **`cx-err:CXER4618 E_JOURNAL_TEMPORAL_INVALID`** loudly,
naming the offending `seq` — the *chain's* vocabulary, distinct from
`CXER4610` (the *caller's* args, e.g. a non-temporal `opts.valid-at`). The
projection never silently skips an entry it cannot classify.

**The interval verbs — `overlaps` / `contains-instant` (L118: "interval
builtins land with the vocabulary").**

```
[?def overlaps         scope=public pure [returns bool] ($a::element $b::element) ...]
[?def contains-instant scope=public pure [returns bool] ($a::element $instant::any) ...]
```

Both are **pure journal module verbs**, not §6.5 core builtins — the §6.5
tables are CLOSED and identity-bearing (stream 5's builtin-set id hashes
them), and the vocabulary's normative home is §2.9. `overlaps` answers whether
two vocabulary-bearing elements' half-open windows intersect
(`max(from₁, from₂) < min(to₁, to₂)`; absent ends unbounded) — half-open
**adjacency does not overlap** (no boundary double-count).
`contains-instant` answers `from ≤ T < to`. Malformed vocabulary on an
argument refuses `CXER4618`; a non-element argument or non-temporal instant is
`CXER4610`. **CXPath predicate filtering over the vocabulary needs no grammar
change** (proven, conformance `journal-115`): attr-presence
(`…/promo[@valid-from]`), negated presence, and prefix-operator comparisons
filter materialized entries as-is. (The `query` verb's predicate handling is a
pre-existing name-step subset — tracked #782, not a vocabulary limitation.)

**The M5 pair in one line:** `fold … {at-seq: 1, valid-at: Aug 3}` vs
`fold … {valid-at: Aug 3}` is the **restatement delta** — the defensible
invoice basis and the corrected basis, from one immutable chain (conformance
`journal-108`).

### §3.9. The upcaster seam — `{upcast: $chain}` (stream 21)

```
[?def upcast scope=public pure [returns [sequence element]] ($entries::[sequence element] $chain) ...]
```

Upcasters are **pure entry → entry projections composed at the §3.8 seam** —
the same pure entry-sequence stage ahead of the reducer; the §3.4 fold
contract is untouched
([`schema_event_evolution.md`](../core/schema_event_evolution.md),
ruling L146). The **chain is caller-supplied** — one pure def (its **Tier-1
source address is its trust identity**; Tier-2 rides for cache sharing, the
stream-5 dual form): the journal recognizes the seam, never the domain.

- **Surfacing.** `fold` and `replay` take **`upcast: $chain`** in their
  trailing opts, composable with the §3.8 axes. `upcast` is the **pure core**
  over already-materialized entries (the `temporal-slice` twin); `slice`/
  `since` readers compose it manually. The chain must be **pure**
  (`CXER4611`, exactly as the reducer).
- **Order: upcast THEN the valid-time projection.** An upcaster may
  *synthesize* §2.9 vocabulary for entries that predate it — so the
  projection must see the chain's output (conformance `journal-119`: the
  order is observable, not stylistic).
- **The envelope is the journal's.** The chain receives the hydrated
  `[entry]` and returns an `[entry]` whose **`[event]` payload it may
  rewrite**; the seam carries the original envelope and non-event children
  forward and takes only the output's `[event]`. An output that is not an
  `[entry]`, drops the payload (an upcaster never shreds), or rewrites the
  identity pair `seq=`/`hash=` refuses **`CXER4642`** loudly.
- **An entry no upcaster covers is a failure-channel error at fold time**
  (ruling L151): a chain refusal (an `[err]` return) is
  **`CXER4641 E_JOURNAL_UPCAST_UNCOVERED`**, naming `seq`, `hash`, and the
  declared `schema=` or its visible absence — **never absence, never a
  skip**. Tolerance is never the compatibility mechanism.
- **The coverage pre-flight is a coherence question:** `coherence` given
  `{upcast: $chain}` dry-applies the chain to every event-bearing retained
  entry and reports each refusal as an **`:uncovered-entry` finding** (an
  envelope rewrite reports `:upcast-invalid`) with the declared schema
  visible — converting a mid-replay abort into a pre-execution diagnostic.
  Findings, never errors; `verify` stays syntactic.
- **Shredded entries pass through** without chain application, exactly as
  the §3.8 projection keeps them (L119) — visible in `erased=`, counted by
  the engaged fold. This is one instance of stream 20's **generalized
  visible-count rule** ([`erasure_compliance.md`](../std-lib/erasure_compliance.md)):
  every surface that omits data for erasure reasons reports the omission
  count and its attribution, in the value, at the point of omission — a
  lawful shred is a *finding*; a missing upcaster stays a *fault*.
- **`replay {at-seq: N}` uses TODAY'S chain** — which is precisely why the
  chain is identified: a past-state read is reproducible as a function of
  **(entries, chain, fn, init)**, never of a date (the stream-21 determinism
  quadruple; fold-identity-carrying snapshots consume this identity).
- **The lineage load — `lineage-path` (ruling L149).** How a caller BUILDS
  a chain: the evolution graph is a set of **Lane-2
  `[schema-lineage [from <address>] [to <address>]
  [relation :additive|:narrowing|:split|:merge] [upcaster …]]` claim
  values** (endpoints are schema **content addresses** — two schema
  revisions are two E2 identities; nothing links them intrinsically).
  `[$journal:lineage-path $claims $from $to]` is the **registry load**,
  fail-closed: a duplicate edge, a cycle, or ANY pair of endpoints
  admitting two paths refuses **`CXER4643 E_JOURNAL_LINEAGE_AMBIGUOUS`**
  (an ambiguous graph must never silently pick a chain); it returns the
  claims along the **unique** path in composition order. No covering path
  is **`CXER4644 E_JOURNAL_LINEAGE_NO_PATH`** — loud, the pre-execution
  twin of `CXER4641`; lineage is DIRECTED (a downgrade direction is not
  covered by an upgrade edge — the market spec's narrow downgrade
  exception is its own, visibly-counted surface). Malformed claims are the
  caller's args (`CXER4610`).
- **The derived chain — claims as the chain value (RULED: SEA-1g).**
  Everywhere `{upcast: …}` accepts a fn chain it ALSO accepts a
  **`[schema-lineage]` claim carrying `[derived root=… RULE*]` rules, or a
  sequence of such claims in composition order** (exactly `lineage-path`'s
  output shape) — the mechanical translators `cx schema compat` derives
  ([`schema.md`](../core/schema.md) §16.5.2). The seam applies the rules
  **natively**: pure and lossless by construction (field-level surgery on the
  authored payload; the closed rule vocabulary is `set-default` /
  `rename-attr` / `drop-attr` / `rename-elem` / `drop-elem`), with the
  chain-wise discriminator — an entry declaring `schema=` **unknown to the
  claim set** refuses `CXER4641` (stale vocabulary never silently passes); an
  entry with **no** declared schema passes through; each claim applies exactly
  where the entry's current address equals its `[from]`, restamping to its
  `[to]`. A claim **without** `[derived]` rules refuses `CXER4610` — a
  hand-written upcaster is a fn chain, never guessed from a claim. The
  fn-chain surface is unchanged; the two forms never mix in one `upcast`
  value.

## §4. Semantics & guarantees (soundness)

### §4.1. Tenant is a hard, structural partition (no runtime check — the absence of a surface)
A `[journal]` is bound to one tenant at `open`/`attach` and exposes **no operation
that names another tenant**. Entries are persisted under a **tenant-rooted `store`
namespace** (the partition; [`store.md`](../std-lib/store.md) aliases/layout), so a
second tenant's entries live under a disjoint namespace reached only through a
*different* `[journal]` handle. Cross-tenant read/append is therefore not a denied
operation — it is an **inexpressible** one ([`xap.md`](xap.md) §22.6, §22.7). This is
the journal-level realization of the process-per-tenant isolation
([`xap.md`](xap.md) §14.1): even co-located in one process (the shared-worker tier), two
tenants' journals share no addressability.

### §4.2. The hash chain — tamper-evident by construction (per stream)
The chain is **per stream** (§2.1.1): **each stream's** genesis entry (`seq=1`) has
`prev-hash = "genesis:"` (a fixed sentinel, never a real digest). Every entry's
`hash` is the self-describing tagged address `<multiformats-name>:<hex>`
(`sha2-256:` default — I1 stream 19, ONE registry; the private `b3`/`sha256`
tags are retired) over its **canonical CX bytes** — the deterministic
serialization of `seq`+`tenant`+**`stream` (omitted when `:default`)**+`actor`+`authority`+`ts`+`prev-hash`+`payload=<tagged-address>`
(§2.2's `entry-canonical` wrapper; the payload rides DETACHED as its own
content-addressed doc since I1 row 11). Because
`hash` covers `prev-hash`, and `prev-hash` covers the entire prior chain transitively,
**mutating any past entry changes its `hash`, which breaks every subsequent `prev-hash`
link in that stream** — `verify` (§3.6) detects it at the first offending `seq`.
**Tenant-wide** tamper-evidence (across all streams) is anchored by the signed snapshot
(§4.8), which commits the full set of stream heads. The `hash-algo` is **fixed at `open`** for the life of the chain
(mixing algos mid-chain would make `verify` ambiguous); re-opening with a different
`hash-algo` over an existing chain → `cx-err:CXER4602 E_JOURNAL_ALGO_MISMATCH`.
**Integrity of history is guaranteed at every tier; authorship non-repudiation
(signing) is a separate, orthogonal property** layered above by `authz`/`crypto`
([`xap.md`](xap.md) §22.9) and is out of scope here.

### §4.3. Commit timestamp and ordering (per stream)
`append` assigns `ts` from `opts.clock`; the DEFAULT (no clock supplied) is
the deterministic capability-free synthesis: **the Unix epoch plus `seq`
seconds, emitted as a real ISO-8601 UTC-Z instant**
(`1970-01-01T00:00:01Z` at `seq=1`; day boundaries roll the date — I1 row
10, #712: the pre-I1 `epoch:HH:MM:SS` spelling was not a datetime and
wrapped silently at 24h). `ts` is **monotonic
non-decreasing with `seq` within a stream** (a later `seq` never has an earlier `ts`;
if the clock would regress, `append` clamps `ts` to that stream's predecessor `ts`
rather than emit a non-monotonic stamp — the *order* authority is `seq`, not `ts`,
N-CORE-1). The controllable clock ([`xap.md`](xap.md) §25.1 timer enhancement)
makes `ts` deterministic for fixtures and the demo's incapacity windows. **Per-stream
`seq` order — never `ts` — is the system authority** (§2.1.1); `ts` is metadata. There
is **no total order across streams**: `ts` may be used to *merge* streams for display,
but it confers no ordering authority, and disjoint-stream state composition does not
depend on it (§3.4).

### §4.4. Read consistency under concurrent append (per stream)
A stream-scoped reader (`read`/`slice`/`since`/`source`/`query`/`fold`/`replay`/`verify`)
observes a **consistent committed prefix of its stream**: every entry up to some
`seq ≤ that stream's head-seq` at the read's start, none partial. An `append`
committing concurrently — to this stream or any other — MAY or MAY NOT be visible to an
in-flight read (visible iff it committed to *this* stream before the read snapshotted
its head), but a read **never** observes a torn or uncommitted entry. `fold`/`replay`
over a stream's `since 1` thus reproduce a deterministic prefix; pairing with `head`
(per stream) lets a caller pin the exact `seq` they folded to. A tenant-wide
composition (§3.4) snapshots each stream's head independently; it is consistent per
stream, with no cross-stream linearization claimed (none exists — §4.3).

**Consistency declarations (stream 7 — the declare-and-verify vocabulary,
[`consistency_vocabulary.md`](../core/consistency_vocabulary.md)).** The
closed guarantee vocabulary attaches to this surface at two points, and only two:

- **Handle floor.** `open`/`attach` accept a `consistency` opts key — one atom or a
  sequence of atoms from the closed vocabulary — checked **once, at declaration
  time**, against the guarantee set this journal surface advertises:
  `:prefix-consistent` (this section's committed-prefix contract),
  `:at-seq-pinned` (the `replay`/`snapshot`/`fold-from` position pins),
  `:at-head-set` (the §3.7 signed snapshot head-set), `:monotonic-reads` (head
  refresh is forward-only), `:gapless` (subject to the per-read retention guard
  below), and — over a local backing store only — `:read-your-writes` (a
  byte-source remote backing refuses it: the handle cannot prove its own writes
  are visible back through a caching layer). A token the surface does not
  advertise refuses the open loudly with `cx-err:CXER4990
  E_CONSISTENCY_UNSATISFIABLE`, carrying the failing **stage**, the failing
  **token**, the **surface**, and the **advertised set** (the D-C1 naming shape)
  as structured `[context …]` children on the err value. The handle element
  echoes the declared floor (a `consistency=` attribute); an undeclared handle
  carries no attribute and behaves exactly as before — the vocabulary is
  declare-and-verify, never a silent default change. A `compact` target segment
  is itself an open: compact's `opts` accept the same `consistency` key as the
  floor of the segment handle it returns.
- **Per-read pins.** `replay`/`snapshot` `opts.at-seq` (and the pin a
  `fold-from` snapshot carries). A pin beyond the stream head stays `CXER4606`.
  A position whose required prefix is retention-pruned (the stream's seam floor
  is above the chain genesis) refuses `cx-err:CXER4991
  E_CONSISTENCY_PIN_UNCOVERABLE`, naming the requested position, the retained
  floor, and the resolve-through path (`fold-from` over the covering snapshot)
  — **never a silent fold from the seam**: a fold or snapshot seeded mid-chain
  without its covering snapshot is a wrong state presented as a right one, the
  exact silent-degradation class this vocabulary exists to close (#714). This
  guard is always-on (a pin **is** a declaration); it does not require a
  declared floor.

Closed-set discipline: an unknown token is a typed `CXER4990` error (stage
`vocabulary`), never ignored, and tokens are **atoms** (a string spelling is
refused — the vocabulary is type-strict). `:exactly-once` is permanently
refused NAMING `[idempotent]` ([`code.md`](../core/code.md) command clauses) as
the answer — effect-boundary dedup answers retries, not a delivery-guarantee
claim. `:serializable` is refused naming the cross-stream coordination design
(stream 10). Under a declared `:gapless` floor, an explicit-`from` read
(`slice` / `since` / `replay from=`) that asks below the retained floor refuses
`CXER4991` instead of silently clamping to the seam; `source` reads the
retained suffix *by contract* (§3.3) and is not an explicit-`from` read.

### §4.5. Append-only — no mutation surface (snapshot/retention/compaction included)
There is **no `update`, `delete`, or `truncate` verb**, and **none of `snapshot` /
`retain` / `compact` is one** (§2.8, §3.7). Correction is by **appending a compensating
event** (event-sourcing's discipline — the log records that a correction happened,
preserving the audit trail [`xap.md`](xap.md) §22.6). The checkpoint/archival surfaces
preserve append-only **by construction**:

- `snapshot`/`fold-from` only **read** the chain to produce a separate, signed
  derived artifact (§2.8, §4.8) — they never write the chain and never advance the head.
- `retain` only **records a policy + checks coverage** (§4.9) — it deletes nothing.
- `compact` is a **copy-forward into a NEW segment** (§4.10), leaving the source
  byte-for-byte intact; the pruned prefix is **archived, not erased**, and only ever a
  prefix a valid signed snapshot already preserves. There is **no in-place compaction**:
  the source journal's live chain semantics (its `prev-hash` links, its `seq` density)
  are never altered.

Thus the append-only invariant is **permanent** and the hash-chain stays tamper-evident
(§4.2) under every checkpoint/archival operation — the only way a committed entry's
bytes change is *nowhere*.

### §4.6. Purity boundary
`head` and `fold-value` are **pure** (`fold-value` operates on an
already-materialized sequence — no backend access, referentially transparent;
`head` answers the handle's **cached view**, which stays coherent within one
process — a shared-root sibling's advances fold in forward-only — but carries
**no freshness contract**: stream 7 F1 states this rather than papering over it,
and `head-fresh` (§3.3) is the impure verb for a declared-fresh need). All
other verbs are **impure** (they reach `store`). The reducer `$fn` passed to
`fold`/`fold-slice`/`replay`/`dry-run`/`fold-value` **must be pure** regardless of the
enclosing verb's purity — determinism (§2.7) requires it; `CXER4611` enforces it.

### §4.7. Handle quotas and lifecycle
The underlying `store` handle counts against store/host quotas; an op on a closed
journal → `cx-err:CXER4612 E_JOURNAL_CLOSED`. `[?with-open]` close (§2.1) flushes +
releases, idempotent with explicit `close`.

### §4.8. Snapshot signing — non-repudiation of the derived artifact (composes `crypto`)
A `snapshot` is **signed** (§2.8/§3.7) by composing `crypto`'s signing primitives over
the snapshot's canonical bytes. **The signed preimage is normative and frozen
(stated 2026-08-05, audit C1 — previously only the informal
`(state + at-seq + anchor-hash + hash-algo)` tuple appeared, with no wrapper, no
field order, and no `stream` rule; the body-child and byte-basis statements below
were corrected 2026-08-10, #724 live-probe — the earlier text showed a `[state …]`
wrapper as the body child, which does not verify against any shipped signature):**
the canonical-form emission of the synthetic element

```cx
[snapshot-canonical at-seq=<int> stream=<string>? anchor-hash=<string>
                    hash-algo=<string> fold-id=<string>?
  <state-value>]
```

**The SET preimage (stream 7 W6 — ADDITIVE):** the §3.7 tenant SET snapshot
signs its own, distinct synthetic element —
`[snapshot-set-canonical hash-algo=<string> [h (stream=<string>)?
at-seq=<int> anchor-hash=<string> [state <value>]]…]`, members in the
artifact's own order (default first, named sorted) and **byte-shared** with
the artifact's `[h]` children, so verify re-renders the artifact's members
verbatim. Every existing single-stream preimage is **byte-unmoved** — the
set form is a new artifact shape, not a re-spelling (the frozen-preimage
rule holds).

with attributes in **exactly that order**, `stream` bound only for non-default
streams (same rule and rationale as the entry preimage), and the sole body child
being **the folded state VALUE itself** — the value carried *inside* the snapshot
artifact's `[state …]` element, **without the `[state]` wrapper** (a
sequence-shaped state contributes its sequence value as that one child). The
wrapper name `snapshot-canonical` is part of the preimage. **The signed bytes are
the value-emission bytes, not the §4.2 document-identity bytes:** the signature
covers exactly the canonical-form emission of the element *as constructed*
(the `$format:canonical` surface, [`canonical.md`](../core/canonical.md)) —
string-typed attribute values keep their emit-quoting, and there is **no trailing
newline**. This is deliberately distinct from the entry-hash basis in §4.2 (the
Tier-1 document identity `cx hash`/`$cx:hash` computes, which re-canonicalizes
parsed text): the two bases are each frozen, and conformance pins hold each one
(`journal-079` entry, `journal-080` snapshot). **`fold-id` is a signed-preimage attribute RESERVED from the I1 epoch
onward and FILLED by stream 21 (L147)** (audit C1 repair (a)): it is omitted
while unset — so pre-stream-21 snapshot signatures are unchanged — and when
`snapshot` is given `opts.fold-id` (§3.7) it carries the snapshot's fold
identity **inside the signature**, making the `fold-from` mismatch check
(`CXER4640`) trustworthy rather than a check on a forgeable unsigned field.
The I1 reservation is why stream 21 landed with NO second signing epoch. `sig-algo` is a
`crypto`-supported signature algorithm (e.g. `ed25519`) and the key is supplied via
`opts.signing-key` (a `crypto` key handle). journal **adds no signing primitive** — it
composes `crypto` exactly as it composes `hash` for the chain. The signature is the
artifact's **non-repudiation + self-integrity** guarantee: a snapshot's bytes can be
verified without chain access (`snapshot-verify` step 2), while `anchor-hash` binds it
to a chain position (step 1) so the two together make a snapshot **unforgeable and
non-divergent**. This is **orthogonal to integrity-of-history** (§4.2): the chain is
tamper-evident regardless of snapshots; signing protects the *checkpoint artifact*.
Signing is **the only new effect** the amendment introduces beyond `store`/`hash`, and
it reuses `crypto`'s existing capability posture (§5) — no new journal capability.

**The appointed-signer surface (S6.4, F5(b)) — the `signer=` outer hint.** A signed
snapshot MAY carry `signer="<did>"` as an **unsigned outer attribute** alongside
`sig-algo=`/`signature=`/`verify-key=`. It is **not** part of `snapshot-canonical` —
the frozen preimage above is byte-unchanged and NO second signing epoch exists — yet
it cannot be forged usefully: `snapshot-verify` resolves the verify key **from** the
`signer` DID and verifies the frozen-preimage signature under that key (§3.7 step 2),
so a `signer` naming anyone but the actual key holder fails. The crypto check stays a
pure public-key verification (pushdown-safe — the profile's `journal-snapshot-verify`
consults no authority state and is unchanged on the wire); **appointment** — "is this
signer the org's designated snapshot signer for this scope?" — is the SEPARATE,
caller-opt-in authority check (§3.7 `opts.require-appointed`): the `signer` DID must
hold the **`snapshot-sign`** capability row (profile §6.1) in the caller-designated
registry. Client-signs stays the default (self-attestation — no appointment needed);
appointment changes WHO may sign, never WHERE the key lives — the signing key never
travels (§6.1, F5b).

### §4.9. Retention cover rule — you may never prune un-snapshotted history
A `[retention]` policy (`keep-after-seq` / `keep-after-time` / `keep-N`) defines a
prune **boundary** `B` (highest `seq` eligible to drop). The **hard invariant** (enforced
by `retain`, §3.7): a prefix `1..B` may be pruned **only if** some snapshot `S` with
`S.at-seq ≥ B` exists, `S` `snapshot-verify`s **valid and signed**, and `S`'s
`anchor-hash` matches the live chain. Otherwise `retain` → `cx-err:CXER4616
E_JOURNAL_RETENTION_UNCOVERED`. The integrity argument:

- **Audit survives.** Every pruned entry's *effect* is folded into `S.[state …]`, which
  is signed — so the projected authority over the pruned range is preserved and
  attributable. If `opts.archive` is used (§4.10), the raw pruned entries also survive
  in a cold namespace, fully re-verifiable.
- **Replay survives.** Reconstruction after pruning is `fold-from S` over the retained
  tail — *identical* to the pre-prune `fold` (the §10 equivalence) — so no replay
  capability is lost.
- **Live semantics survive.** Pruning is **archival of a prefix**, not an edit of the
  retained tail: the tail's `prev-hash` links and `seq` values are unchanged; the seam
  is documented (§4.10). The chain is not "rewritten to start later" — it is *carried
  forward through a signed checkpoint*.

Because pruning is gated on a valid signed snapshot that already preserves the pruned
state, **no history is ever lost or made unauditable** — that is the whole point of
binding retention to snapshots.

**The current-fold reading (stream 21, L147 — closing #716's data-loss path).** The
cover rule reads **covered-under-the-CURRENT-fold**: a signed cover frozen under an
OLD fold satisfies the mechanical test above yet preserves state the current fold's
vocabulary can no longer produce — pruning behind it loses exactly the
interpretations the "no history is ever lost" argument promises to keep. When the
caller declares its current fold (`$policy.fold-id`, the §4.8 quadruple address),
`retain` enforces the reading: a cover carrying a different identity — or none —
refuses `CXER4616` (re-snapshot under the current fold, then prune). **Periodic
re-snapshotting under the current fold is the NAMED maintenance discipline** that
both bounds upcaster-chain length and keeps covers prunable-behind. An undeclared
`retain` keeps the shipped check byte-identically (the declaration is what makes
the reading binding — the journal cannot know the caller's fold).

**Dedup-record extension (commands and effects, stream 6 — L111).** The
cover rule EXTENDS to idempotency dedup records: an entry recording an
idempotent command's dedup fact (the commit-boundary transition event
paired with the `idem/<tenant>/<key>` must-not-exist CAS record) **may
not be compacted away before its declared `[window DUR]` expires** — the
prune boundary `B` must not cross an unexpired dedup record. Compaction
reopening the double-execution window would be a silent semantic change
dressed as housekeeping (the papering-over D-C1 warns against). Dedup
records are **fold-visible facts** (replay-stable): a fold over the
retained log reproduces exactly the dedup decisions the live path made.

### §4.10. Compaction seam — copy-forward, never in-place
`compact` (§3.7) writes a **new** segment: a covering `[snapshot]` seam record, then the
**retained tail** copied **verbatim** (each entry's `seq`/`prev-hash`/`hash` bytes
unchanged). The seam: the first retained entry (`seq=B+1`) already carries
`prev-hash =` entry `B`'s `hash`, and the embedded snapshot's `anchor-hash` equals that
same `hash` (the snapshot covers through `≥ B`), so `verify`/`replay` crossing the seam
check the retained entry's `prev-hash` against the **snapshot anchor** instead of the
`"genesis:"` sentinel — a documented, verifiable join (§3.6). The **source journal is
left byte-for-byte intact**; `compact` is a read-original/write-new copy, so:

- it is **reversible** (discard the new segment; the source is untouched);
- it **never edits a committed entry** in place — the append-only invariant (§4.5)
  holds for both source and segment;
- the new segment is itself a valid append-only hash-chain anchored at its snapshot
  seam, so `append`/`verify`/`replay`/`fold`/`snapshot` all work on it unchanged.

Compaction therefore *bounds* replay cost (start from the seam, not genesis) **without**
any in-place mutation — the copy-forward discipline is what makes that sound.

### §4.11. Rotation — sealing the hot window (the composed operation)

`rotate` (§3.7) is the **segmentation + eviction** operation deployments actually
run: it composes §4.9 and §4.10 — cover, validate, copy — and adds the two things a
long-lived deployment needs beyond a single compaction.

```
[$journal:rotate $j {streams: 'all', keep-n: 10000, target: 'file://…-g2',
                     signing-key: <seed hex>, carry: ('fabric/acme/',)}]
  ⇒ [rotated streams=N sealed=M segments=T target='…' [journal …]]
```

- **The cover** is caller-supplied (`snapshot:`) or a minimal **rotation cover** built
  and signed here from `signing-key` — a `[rotation-cover]` state at the boundary
  with the chain's anchor. §4.9 is unchanged: no valid signed cover, no sealing.
- **`streams: 'all'`** seals the whole tenant journal — the default chain plus every
  named stream, each at its **own** boundary (`head_s − keep-n`, floored at 0). A
  stream whose boundary floors at 0 is copied **whole** (nothing sealed, no cover
  needed): a rotation must never let a stream fall out of the hot window merely
  because it is quiet. The target opens **once** and every stream compacts into that
  one instance.
- **The segment index** (`cx-journal/segments/<tenant>`, written in the *target*)
  records each sealed predecessor — `to` (the boundary), `anchor` (the seam hash),
  `store` (the predecessor's URL, **userinfo-redacted**) — **appended to the
  predecessors the source already carried**. A chain of rotations therefore stays
  walkable from the newest hot store alone, which is what makes cold history
  discoverable without a registry.
- **`carry:`** names alias-name prefixes whose entries ride into the new store.
  Consumer state living beside the chain (a fabric mount's group offsets, policies,
  and delivery records) **must** travel: a rotation that left it behind would
  silently reset every consumer group.
- Rotation is **copy-then-swap**: the source journal and store are never mutated, so
  a crash mid-rotation leaves the live chain intact and the operation is simply
  retried against a fresh target. **Eviction is the swap** — the caller repoints at
  the returned journal and closes the old handle; per-operation cost then tracks the
  hot window rather than lifetime volume.

The *policy* question — when to rotate, what window each stream keeps, where sealed
segments are archived and for how long — is deliberately **not** here: rotation is
the mechanism a retention policy drives.

### §4.12. The derived open — a target inherits the source's posture

A `compact` / `rotate` **target** is not an independent store the caller happens to
name: it is the chain's own continuation (rotation is copy-then-**swap**, §4.11 — the
returned journal *becomes* the live chain). So the target open is **derived**, and
inherits from the source's backing store:

- **`encrypt-key-id`** ([`store.md`](../std-lib/store.md) §9). A bare target open
  would make the new hot window **plaintext at rest**, silently downgrading the
  posture at every segment boundary — which §9's fail-closed mandate forbids as
  flatly as it forbids a silent plaintext write anywhere else. It also made an
  encrypted chain **unrotatable** (a subject-bearing payload's carry then refuses
  `CXER1144` custody, correctly) and made an *existing* encrypted store unusable as
  a target (its self-describing reopen needs the key).
- **`encoding` / `compression`** — the at-rest **framing**, so the new hot window
  keeps the substrate shape the deployment chose.
- **`hash-algo`** (§4.2). `compact` copies retained entries **verbatim** (§4.10 —
  `seq`/`prev-hash`/`hash` bytes unchanged), so a target stamped with the default
  algo would carry entries hashed under a *different* one: a segment that fails its
  own `verify`. The stamp must be the source's.

Precedence, highest first: an **explicit key on the caller's `opts`** (the
key-per-segment policy — each sealed segment under its own KEK); then the target
**URL's own** `?encoding=` / `?compression=` when it states one (framing has a URI
spelling; `encrypt-key-id` has none); then the **source's** value.

Framing inherits only **within one scheme** — a `file://` → `sqlite://` rotation must
not carry `object-per-key` into a substrate that has no such framing. `encrypt-key-id`
inherits **across** schemes by design: a target that cannot seal then refuses
**loudly** (§9), which is the only honest answer; degrading to plaintext is not one.

Nothing here moves an address: at-rest sealing keys objects by the **plaintext** hash
(§9), so the copy-forward is byte-identical either way. `head-fresh`'s read-only
substrate reopen (§4.4) performs the same inheritance for the same reason.

## §5. Capability integration

Gated by **`store`'s existing capability model** ([`store.md`](../std-lib/store.md) §9,
[`security.md`](../core/security.md) §2–§4) — **no new capability**, consistent with
http reusing `net` ([`http.md`](http.md) §5). The capability required
is **the capability the underlying `store` backend requires** — journal adds nothing:

| Operation | Capability | Resource matched |
|---|---|---|
| `open` / `attach` (file/local backend) | `read` (+ `write` if `create` may write) | the backend path ([`store.md`](../std-lib/store.md) §9) |
| `open` / `attach` (remote backend) | `net` | the backend host:port (store §9) |
| `open` / `attach` (`mem://`) | — | **capability-free** (store §9 — pure in-process state) |
| `append` | `write` (file/local) / `net` (remote) | the backend resource; `mem://` → none |
| `read` / `slice` / `since` / `source` / `query` / `fold` / `fold-slice` / `replay` / `verify` / `verify-slice` | `read` (file/local) / `net` (remote) | the backend resource; `mem://` → none |
| `snapshot` / `fold-from` / `snapshot-verify` | `read` (to fold the chain) + `crypto` signing key for `snapshot` (§4.8) | the backend resource; `mem://` → none. Signing uses `crypto`'s key/cap posture — **no new journal cap** |
| `retain` | `read` (verify the covering snapshot) | the backend resource; records a policy, deletes nothing |
| `compact` | `read` (source) + `write`/`net` (the `opts.target`/`opts.archive` namespaces) | source + target/archive backend resources; `mem://` → none |
| `rotate` | `read` (source) + `write`/`net` (the `opts.target` namespace) — the composed §4.11 operation inherits `retain`'s + `compact`'s caps, adding none | source + target backend resources; `mem://` → none |
| `head` / `fold-value` / `dry-run` (the in-memory step) | — | **pure** (§4.6) — operate on materialized values / cached head |
| `close` | — | release only |

A denial raises `cx-err:CXER0271 E_CAP_DENIED` at the **store effect point**, naming
the missing grant + resource (store §9 verbatim):
`[err code=cx-err:CXER0271 capability=write resource='file:///var/xap/acme']`. CLI:
`cx FILE --allow-write=/var/xap`. **Cancellation + revocation** follow store / SAP
§5.2: a cancelled `replay`/`fold`/`verify`/`snapshot`/`compact` at a cancellation point
reports the core `CXER0260`; a raw store effect after cancel hits `CXER0271`;
`[?with-open]` close runs under restored caps. journal introduces **no journal-specific
capability** — *who may append/read which slice* is `authz`'s policy (§2.6), enforced
before `append`, not a host-capability concern. **Snapshot signing** (§4.8) reaches
`crypto` with the supplied key handle under `crypto`'s **existing** capability posture
([`crypto.md`](../std-lib/crypto.md)); journal adds **no** new capability for it (a
denied/absent signing key surfaces as `CXER4614`, not a host-cap fault). `compact`'s
write to the new segment/archive is the **same `store` `write`/`net` cap** as `append`
(no new cap), gated at the store effect point with `CXER0271`.

## §6. Composition with the integration layer

Canonical call form is `[$journal:VERB …]` (`[head …]`); journal uses no infix and no
`[?try]` (§0). The marquee composition is the **§2 serialized cascade**, owned by
`xap`, not journal:

```cx
# xap drives this — journal supplies only the append + fold steps:
[$xap:on :order-received [?def [$ev]
  [?let [= $committed [$journal:append $j [event $ev]
                        {actor: $actor authority: $auth}]]  # 1. append (journal)
    [$bus:emit $b :order-committed $committed]]]]           # 2. dispatch in commit order (bus)
# the synchronous, ordered, log-coupled wiring is the xap composition rule — NOT here.
```

Handle outcomes by **shape**, not `[?try]` — a committed entry / a finding is a value
(§2.4–§2.5), a fault is `[err]`:

```cx
[?match [$journal:append $j [event $ev] {actor: $a authority: $au}]
  [case [err @code='cx-err:CXER1114'] [$retry-after-rebase $j $ev]]   # stale tail → re-read + retry
  [case [err @code=$c] [err code=$c]]                                  # re-raise other faults
  [case [entry @seq=$s] $s]]                                           # a VALUE — the committed seq

[?match [$journal:verify $j {}]
  [case [verification @valid=false] [$alert :tamper-detected]]         # a FINDING (value)
  [case [verification @valid=true]  :ok]]
```

- **State-as-a-fold is the authority** ([`xap.md`](xap.md) §14): a surface/component
  reads `[$journal:fold $j $project-fn $init]` (or `replay … at-seq=$n` for a past
  view) — never a separate mutable store. The trust calibration ([`xap.md`](xap.md)
  §20.1) and the policy-stack resolution ([`xap.md`](xap.md) §21.5) are *folds* over
  this journal.
- **Handoff brief replay** ([`xap.md`](xap.md) §21.1) is a `replay`/`query` over the
  provenance cone — `query` the causal slice, `replay … at-seq=last-in-command` for the
  returning principal's known-good model.
- **Snapshots bound the fold cost** — a long-lived surface takes a periodic
  `[$journal:snapshot $j $project-fn $init {signing-key: $k}]` and reconstructs with
  `[$journal:fold-from $j $snap $project-fn]` instead of a from-genesis `fold`; the
  result is identical (§10 equivalence), the work bounded to the tail. `verify`/`replay`
  remain correct **across the snapshot/compaction seam** (§4.10) — a `verify` that
  spans a compacted boundary checks the seam link against the snapshot anchor.
- **Retention + compaction are archival, not edits** — `retain` declares a
  prune-behind-a-snapshot policy (§4.9) and `compact` copies *snapshot + retained tail*
  into a new segment (§4.10), leaving the source intact. State-as-a-fold over the
  compacted segment (`fold-from` the seam snapshot) equals the fold over the original.
- **Anticipation / policy scenarios** ([`xap.md`](xap.md) §19, §22.10): `dry-run` the
  candidate event/decision against the real fold function — deterministic, no commit.
- **`authz`** ([`authz.md`](authz.md)) decides; journal **records** the
  `:actor`/`:authority` it was told (§2.6). **`session`**
  ([`session.md`](session.md)) resolves the `(principal, tenant)` that
  becomes the attribution + the journal handle's tenant. **`bus`**
  ([`bus.md`](bus.md)) is orthogonal — pub/sub; the cascade couples them.
- **`[?with-open]`** ([`code.md`](../core/code.md) §8.10.7): auto-closes the journal
  via `on-close="journal/close"` (flush + release, SAP §5.1), idempotent with explicit
  `close`. **Resilience** ([`code.md`](../core/code.md) §10.2): `[?retry]` is the
  natural response to a `CXER1114` stale-tail; `[?timeout]` over a long `verify`/`replay`
  → `CXER0260`.

### §6.1. Journal over the wire — the XSP store profile

Remote journal access (the surface #644 shipped without a spec section)
is NORMATIVE here for the **XSP store profile only** (stream 4, #676;
store.md §6.4) — it was never spec'd for CSRP, and CSRP retires:

- **v1 (shipped, I5 stream-4 W6): the journal rides the profile's object
  wire.** A journal attached to a `cx-store(+xsp)://` handle runs every
  §3 verb through the store's remote object model: entry and snapshot
  docs travel as content-addressed objects (`objects-have/put/get` —
  the I1-frozen preimages transfer byte-exact, dedup'd), and the
  per-stream head/entry pointers ride the daemon's AUTHORITATIVE alias
  table (`aliases`/`aliases-set` with CAS). Error identity holds: a
  remote `append`'s stale-tail loses the daemon-side alias CAS and
  raises the SAME `CXER1114` a local one raises; committed entries,
  findings, and `[err]` faults cross the wire as the values they
  already are. Two writers against one daemon serialize on the
  daemon's tables — never last-writer-wins.
- **The change feed is the journal's push surface** (store profile §5):
  a feed subscription at `:complete-ordered` delivers entry appends in
  ref-advance order with HEAD-SET resume cursors; at-least-once,
  credit-governed, never coalesced. Replica seeding and revocation
  propagation (profile §7) are this same mechanism.
- **Attach and authority** are the profile's: XSP-AUTH principals, VC-
  compiled capabilities; the journal handle's tenant comes from the
  attach-bound session exactly as §5's capability table requires (`net`
  on the client; the daemon holds the local grants).
- **Verb pushdown (NORMATIVE — S6, RULED: F3+F4+F5+R1.1(b), register
  2026-08-08; the two design points that gated this cut are ruled).**
  For journals whose logs dwarf their queries, the §3 verbs run
  DAEMON-SIDE as profile payload verbs (the profile's §4.3 family,
  feature token `store-journal`): long reads
  (`read`/`slice`/`since`/`query`) as credit-governed `event` streams
  (`cancel`+`eos`), folds/replay/dry-run over the authoritative log
  with the pure-`$fn` enforcement of §3 unchanged — server-side
  `CXER4611` exactly as locally, `CXER4610` argument identity likewise.
  The ruled answers to the two design points:
  - **Fn carriage (F3a):** the reducer crosses as the **def DOCUMENT,
    by document address, over the object wire** — an OPAQUE document
    (raw-byte identity, verified on load) — plus a MANDATORY
    computation-identity claim (`claim="computes-as:<algo>:<hex>"`)
    the daemon recomputes over the parsed entry def and REFUSES on
    mismatch. A dependency closure is more documents (a module IS one
    document; `entry=` selects the reducer). No special function
    carriage exists, so no identity fork is possible.
  - **Key custody (F5b):** `snapshot` is NOT pushed down — the signing
    key NEVER travels; the daemon serves the reconstruction state and
    the client signs locally. An organization may appoint a designated
    SIGNER principal through the ordinary credential model (the
    profile's `snapshot-sign` capability row) — appointment governs
    WHO signs, never WHERE the key lives. `snapshot-verify` (a
    public-key check) IS pushdown-safe and pushes down — including
    the S6.4 `signer=` outer-hint resolution (§4.8: an unsigned
    attribute outside the frozen preimage, bound by the signature
    because the verify key resolves FROM it). The pushed-down verb
    takes no new fields and consults NO authority state; appointment
    enforcement (§3.7 `opts.require-appointed`) is the CALLER's
    separate check against the `snapshot-sign` row.
  - **Budget (F4a):** every daemon-side evaluation runs under the
    operator-configured step limit + memory ceiling; exceeding either
    is the profile's loud typed refusal (`CXER5024`), never a daemon
    takedown. The family is read-only against the journal, so a
    refused evaluation leaves nothing half-applied.
  - `fold-value` stays client-eval only — it is pure over
    already-materialized entries (§3.4); a wire form would move the
    data to the compute (ledger letter J1). `head` is the client
    handle's pure cached read; `append` and pointer moves stay on the
    v1 object-wire carriage above; `retain`/`compact`/`fold-from` are
    owner-side maintenance, not family verbs.
  Pushed-down and client-eval answers are op-for-op EQUIVALENT (same
  state bytes, same computation-identity hash, same error identity) —
  pinned by the G13 parity lanes with the local embedded engine as the
  oracle (R4.4a-revised).

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | `file://` backend | `mem://` backend | remote backend |
|---|:--:|:--:|:--:|
| `open` / `attach` / `close` | ✅ | ✅ ¹ | ✅ ² |
| `append` (single mutating verb) | ✅ | ✅ ¹ | ✅ ² |
| `read` / `slice` / `since` / `source` / `head` | ✅ | ✅ ¹ | ✅ ² |
| `query` (CXPath slice) | ✅ | ✅ ¹ | ✅ ² |
| `fold` / `fold-slice` / `fold-value` | ✅ | ✅ ¹ | ✅ ² |
| `replay` (incl. `at-seq` time-travel) | ✅ | ✅ ¹ | ✅ ² |
| `dry-run` (no-commit preview) | ✅ | ✅ ¹ | ✅ ² |
| `verify` / `verify-slice` (incl. across a seam) | ✅ | ✅ ¹ | ✅ ² |
| `snapshot` / `snapshot-verify` (signed checkpoint) | ✅ | ✅ ¹ ⁹ | ✅ ² ¹⁰ |
| `fold-from` (fast reconstruction) | ✅ | ✅ ¹ | ✅ ² |
| `resnapshot` (re-derive under the current fold — RULED: SEA-1) | ✅ | ✅ ¹ ⁹ | ✅ ² ¹⁰ |
| `retain` (prune-behind-snapshot policy) | ✅ | ✅ ¹ | ✅ ² |
| `compact` (copy-forward to new segment) | ✅ | ✅ ¹ | ✅ ² |

| Property | Supported? | |
|---|:--:|---|
| Hash-chain tamper-evidence (`verify`) | ✅ | every backend — the chain is in the entry bytes, backend-independent |
| Tenant hard partition (no cross-tenant surface) | ✅ ³ | structural — §4.1 |
| Deterministic `fold`/`replay`/`dry-run` (pure `$fn`) | ✅ | §2.7; impure `$fn` → `CXER4611` |
| Snapshot validity checkable against the chain (anchor) | ✅ | §2.8/§3.7 — `anchor-hash` = entry-N `hash`; divergent → `:anchor-mismatch` |
| Signed snapshot non-repudiation (composes `crypto`) | ✅ ⁹ | §4.8; unsigned allowed on `mem://` test tier (not a retention cover) |
| Prune only behind a valid signed snapshot | ✅ | §4.9 — uncovered prune → `CXER4616`; no un-snapshotted history pruned |
| Compaction = copy-forward (source intact, reversible) | ✅ | §4.10 — never in-place; new segment anchored at the seam |
| `fold-from` ≡ full `fold` in result | ✅ | §3.7/§10 — pinned by an equivalence fixture |
| `mem://` capability-free operation | ✅ ¹ | store §9 |
| Pushed-down ≡ client-eval per verb (state bytes, computation-identity hash, error identity) | ✅ ¹⁰ | §6.1 pushdown (RULED F3/F4/F5) — G13 parity lanes, embedded-engine oracle |
| Daemon-side evaluation budgeted (step limit + memory ceiling, typed refusal) | ✅ ¹⁰ | §6.1 / profile §4.3 (F4a) — `CXER5024`, never a takedown |

| Operation | | |
|---|:--:|---|
| In-place `update` / `delete` / `truncate` of a committed entry | ❌ ⁴ | append-only invariant (§4.5) — correct by compensating append; pinned by a negative fixture |
| In-place / destructive compaction (rewrite the live chain) | ❌ ⁵ | compaction is **copy-forward only** (§4.10) — `compact` writes a *new* segment, never edits the source; pinned by a source-intact fixture |
| Prune un-snapshotted history (retention without a cover) | ❌ ⁵ | §4.9 — `retain` rejects an uncovered prune (`CXER4616`); pinned by a negative fixture |
| Cross-tenant read/append | ❌ ⁶ | **inexpressible** by construction (§4.1) — not a denied op; pinned by a no-surface fixture |
| Multi-tenant journal handle (one handle, many tenants) | ❌ ⁶ | one tenant per handle (§2.1); share a `store` via per-tenant `attach` instead |
| Pub/sub / subscriber dispatch | — ⁷ | `bus`'s concern ([`bus.md`](bus.md)); journal is sub-agnostic |
| The synchronous serialized cascade | — ⁷ | `xap`'s composition rule ([`xap.md`](xap.md)); not a journal primitive |
| Authority/PEP decision (may-this-actor-append?) | — ⁸ | `authz`'s ([`authz.md`](authz.md)); journal *records* attribution, never adjudicates (§2.6) |
| Entry signing / non-repudiation tiers | — ⁸ | `authz`+`crypto` ([`xap.md`](xap.md) §22.9); orthogonal to integrity-of-history |

Footnotes: **1** `mem://` is in-process, **capability-free** (store §9) — durability
ends with the process; used for tests + the shared-worker tier. **2** remote backends
require `net` (store §9); the chain semantics are identical. **3** the partition is the
*absence* of a cross-tenant surface, enforced structurally, not by a runtime guard
(§4.1). **4** append-only is permanent — there is no mutate verb at any tier
(negative fixture). **5** snapshot/retention/compaction are now **in scope** as
non-mutating derived-artifact + copy-forward surfaces (§2.8, §3.7, §4.8–§4.10); what
remains ❌ is *in-place/destructive* compaction and *uncovered* pruning — both barred
by construction, each pinned by a fixture. **6** cross-tenant access / multi-tenant
handles are **inexpressible** — no surface takes a second tenant (no-surface fixture).
**7** pub/sub and the cascade are sibling concerns (`bus`/`xap`) — out of journal's
scope by the thin-module split (N-IMPL-1). **8** authorization + signing are `authz`'s
— journal guarantees integrity-of-history + attribution-recording only, orthogonal
properties ([`xap.md`](xap.md) §22.9). **9** snapshot signing composes `crypto`
(§4.8) under `crypto`'s existing capability posture — no new journal cap; a `mem://`
test tier may take an *unsigned* snapshot (`opts.sign=false`) usable for `fold-from`
but **not** as a retention cover (§4.9). **10** remote `snapshot` is CLIENT-EVAL over
daemon-served state — the signing key never travels (§6.1 pushdown, F5b); the
appointed-signer capability governs WHO signs, never WHERE the key lives;
`snapshot-verify` pushes down (public-key check). The pushed-down verbs run under the
profile's operator budget (F4a).

Cognate-coverage: every read/fold/replay/verify/snapshot/fold-from/retain/compact verb
works across all three backends; the chain + tenant-partition + determinism +
snapshot-anchor + prune-behind-snapshot + copy-forward guarantees hold
backend-independently. The intentional ❌s (in-place mutation, *destructive*
compaction, *uncovered* pruning, cross-tenant) are structural invariants, each pinned
by a negative/no-surface fixture; the —s (pub/sub, cascade, authz, per-entry
non-repudiation tiers) are sibling-module concerns, not open cells.

## §8. Error codes — `CXER4600–CXER4649` band (proposed allocation)

`CXER4600–CXER4649` is the **proposed allocation** to `cx-stdlib/journal` in the
governance registry ([`governance.md`](../process/governance.md) §9.6), the next free
block above `cx-stdlib/http`'s `CXER4525–4543` (the XAP modules take contiguous blocks
above http: journal `4600–4649`, with `bus`/`authz`/`session`/`xap` to follow in their
own drafts). This revision uses `CXER4600–4612` (core surface) **plus
`CXER4613–4616` from the reserved band** for snapshots/retention/compaction (§2.8,
§3.7, §4.8–§4.10) **and `CXER4617`** for the `subscribe` resume gap (§3.3;
RULED: U1.13a). All values use `cx-err:` notation;
symbolic↔wire is 1:1 (governance invariant). **Cancellation is the core `CXER0260`,
not a journal code** (§0, §5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4600` | `E_JOURNAL_OPEN_FAILED` | `open`/`attach` could not bind the tenant partition (backend reachable but partition unusable; a backend *fault* surfaces as store's `CXER11xx`) |
| `cx-err:CXER4601` | `E_JOURNAL_NOT_FOUND` | `open` with `create=false` against an absent partition |
| `cx-err:CXER4602` | `E_JOURNAL_ALGO_MISMATCH` | re-opening an existing chain with a different `hash-algo` than it was created with (§4.2) |
| `cx-err:CXER4603` | `E_JOURNAL_READ_ONLY` | `append` on a `read-only=true` journal (§3.1) |
| `cx-err:CXER1114` | `E_STORE_REF_CONFLICT` | `append` with `expect-pos` ≠ the current `head-seq` (optimistic-concurrency conflict, §3.2). **I1 row 15 (audit M21): `CXER4604` is RETIRED — every optimistic-concurrency conflict (journal stale-tail, store ref advance, CSRP alias CAS — the former `CXER1704` too) unifies on this ONE ref-conflict code. `4604` is a tombstone, never reassigned.** |
| `cx-err:CXER4605` | `E_JOURNAL_CHAIN_BROKEN` | an internal read found a **structurally** broken chain where one is required to proceed (e.g. `append` cannot read its predecessor's `hash`); a *reported* tamper finding from `verify` is **not** this — it is a `[verification valid=false]` value (§2.5, §3.6) |
| `cx-err:CXER4606` | `E_JOURNAL_SEQ_OUT_OF_RANGE` | `replay`/`verify` `opts.at-seq`/`from`/`to` references a `seq` beyond the head (a *read* of an out-of-range `seq` is **absence**, not this — §2.5; this is reserved for the bounded *projection* verbs given an impossible anchor) |
| `cx-err:CXER4607` | `E_JOURNAL_HASH_UNSUPPORTED` | `opts.hash-algo` not a `hash`-supported algorithm ([`hash.md`](../std-lib/hash.md) §3.1) |
| `cx-err:CXER4608` | `E_JOURNAL_EVENT_UNSERIALIZABLE` | `$event` cannot be canonically serialized for hashing/persistence (not a representable CX value) |
| `cx-err:CXER4609` | `E_JOURNAL_ATTRIBUTION_INVALID` | `$attribution` missing/empty `actor` or `authority` (§3.2 — no anonymous appends) |
| `cx-err:CXER4610` | `E_JOURNAL_ARG_INVALID` | `seq < 1`, `from > to`, or other malformed range/argument (§3.3) |
| `cx-err:CXER4611` | `E_JOURNAL_FOLD_IMPURE` | the `$fn` passed to `fold`/`fold-slice`/`replay`/`dry-run`/`fold-value` is not pure (§2.7/§4.6) |
| `cx-err:CXER4612` | `E_JOURNAL_CLOSED` | any op on a closed `[journal]` handle (§2.1/§4.7) |
| `cx-err:CXER4613` | `E_JOURNAL_SNAPSHOT_SIG_INVALID` | a `[snapshot]`'s signature fails to verify against the key (`fold-from`/`snapshot-verify`, §3.7/§4.8) — a forged/corrupt **signed** snapshot used where a valid one is required |
| `cx-err:CXER4614` | `E_JOURNAL_SNAPSHOT_UNSIGNED` | `snapshot` invoked without `opts.signing-key` (and `opts.sign` not explicitly `false`), or an **unsigned** snapshot offered as a retention cover where a signed one is required (§3.7/§4.9) |
| `cx-err:CXER4615` | `E_JOURNAL_SNAPSHOT_SEQ_MISMATCH` | a `[snapshot]`'s `anchor-hash` ≠ the live `hash` of entry `at-seq` — the snapshot **diverges** from the chain (`fold-from`/`snapshot-verify`, §2.8/§3.7); a `snapshot-verify` *finding* of this is a value, this code is for verbs that **require** a non-divergent snapshot to proceed |
| `cx-err:CXER4616` | `E_JOURNAL_RETENTION_UNCOVERED` | `retain`/`compact` with a prune boundary **not** covered by a valid signed snapshot (`B > snapshot.at-seq`, or the cover is unsigned/divergent) — the §4.9 prune-behind-snapshot rule (never prune un-snapshotted history) |
| `cx-err:CXER4617` | `E_JOURNAL_RESUME_GAP` | `subscribe` with `opts.from` below the retained floor (§3.3; the `resume-below-retention` refusal class, delivery.md §4; RULED: U1.13a) |
| `cx-err:CXER4618` | `E_JOURNAL_TEMPORAL_INVALID` | malformed §2.9 reserved vocabulary encountered by an **ENGAGED** bitemporal projection (§3.8) — a non-temporal or `null` `valid-from`/`valid-to` carrier, an empty half-open interval, a malformed `[supersedes]`, an `:amendment` without its own `valid-from` — naming the offending `seq`; the **chain's** vocabulary, distinct from `CXER4610` (the **caller's** args, e.g. a non-temporal `opts.valid-at`). Raw (unengaged) reads never raise it |
| `cx-err:CXER4619` | `E_ERASURE_NONCE_REQUIRED` | a subject-bearing payload (§2.11) whose `nonce=` is missing, shorter than 16 bytes, equal to the subject id, or byte-equal to a journal coordinate — the digest-oracle defense is inoperative, so the write refuses (ruling L182/audit C7; raised at append and at the store's subject arm) |
| `cx-err:CXER4620` | `E_ERASURE_HOLD_INVALID` | a `[legal-hold]` claim that cannot bind (§2.11 hold-stream / erasure_compliance §8, ruling L188): malformed scope (not exactly one of `[subject]`/`[hash]`), missing `[signer]`/`[at]`, missing/incomplete/unverifiable `[sig]`, or an unsupported signature algorithm — refused at APPEND to the reserved `cx:legal-hold` stream (entries are immutable; a malformed hold recorded once would poison the fail-closed load forever) and raised LOUD by `legal-holds` if one is encountered at load — never a skip |
| `cx-err:CXER4621` | `E_ERASURE_HELD` | `erase-subject` refused by a binding legal hold (§2.11 / erasure_compliance §8, ruling L188): a signed hold whose scope names the subject — or a hash inside the enumerated doc scope — bound at the unlocked pin or at the commit-lock re-check. The refusal names the hold's `seq`, signer, and scope; it is ATOMIC (no record, no generation advance, no re-snapshot forced — the hold suspends shred AND regeneration). Hold-beats-shred; a hold that lands after the record commits binds every FUTURE shred, never the committed one (the forward-only pivot) |
| `cx-err:CXER4622` | `E_ERASURE_RECORD_RESERVED` | a direct `append` to the reserved `cx:erasure` stream (§2.11): erasure records are journaled ONLY by the `erase-subject` command itself — a hand-authored record would forge the M29 read-time evidence basis and the M31 dedup record |
| `cx-err:CXER4640` | `E_JOURNAL_FOLD_ID_MISMATCH` | `fold-from` with a **declared** current fold (`opts.fold-id`) against a snapshot carrying a **different** fold identity — or carrying **none** (§3.7/§4.8, ruling L147): the snapshot is frozen output of some other fold and folding forward from it yields silently-stale state; the refusal teaches re-snapshot-under-the-current-fold. Undeclared calls never raise it |
| `cx-err:CXER4641` | `E_JOURNAL_UPCAST_UNCOVERED` | an entry no upcaster covers, hit by an **ENGAGED** upcaster seam at fold/replay time (§3.9, ruling L151) — the chain refused (returned `[err]`) — naming `seq`, `hash`, and the declared `schema=` or its visible absence; never absence, never a skip. The `coherence` pre-flight reports the same condition as an `:uncovered-entry` **finding** instead |
| `cx-err:CXER4642` | `E_JOURNAL_UPCAST_INVALID` | the chain's output violates the seam contract (§3.9): not an `[entry]`, the `[event]` payload dropped (an upcaster never shreds), or the identity pair `seq=`/`hash=` rewritten (the envelope is the journal's) |
| `cx-err:CXER4643` | `E_JOURNAL_LINEAGE_AMBIGUOUS` | the lineage graph fails the unique-path invariant at `lineage-path` load (§3.9, ruling L149): a duplicate edge, a cycle, or some pair of endpoints admitting two paths — rejected fail-closed, naming the offending pair; an ambiguous graph must never silently pick a chain |
| `cx-err:CXER4644` | `E_JOURNAL_LINEAGE_NO_PATH` | `lineage-path` asked for endpoints the graph does not connect (§3.9) — loud, never an empty answer: the pre-execution twin of `CXER4641` (lineage is directed; a downgrade direction is not covered by an upgrade edge) |

`CXER4645–4649` remain **reserved** within the stream-21 sub-band;
`CXER4623–4639` remain reserved to the erasure/compliance surface (stream 20,
governance §9.6; `4619`–`4622` are that slice's spent codes, above).

**Shared/core codes journal surfaces (not in its band):** `cx-err:CXER0271`
(capability denial at the store effect point, §5); `cx-err:CXER0260` (cancellation,
§5); `cx-err:CXER0108` never raised (the handle is closeable, §2.1). **Inherited
`store` backend faults** (propagate as-is, not remapped):
[`store.md`](../std-lib/store.md) §7 — `CXER1110` (read-only backend), `CXER1121`
(not-found), `CXER1130` (store closed), and the store transport/encoding faults.
**Inherited `hash` faults** ([`hash.md`](../std-lib/hash.md) §): `CXER2000`
(`hasher-new` unknown algo) surfaces via `CXER4607` at the journal boundary (journal
validates `hash-algo` at `open` and maps the unknown-algo case to its own code).
**Inherited `crypto` faults** (snapshot signing, §4.8): a `crypto` key/sign fault
propagates as-is; the journal-specific *absent-key* and *bad-signature* cases map to
`CXER4614` and `CXER4613` at the journal boundary.

## §9. Implementation notes (non-normative) — composing store + hash

| journal surface | Building block | Notes |
|---|---|---|
| `open` / `attach` | `store.open` / a passed `[store]` handle | tenant-rooted namespace via store aliases/layout ([`store.md`](../std-lib/store.md), alias surface §6.2 / identity §4); read the head alias to populate `head-seq`/`head-hash` |
| `append` | `hash.<algo>` + `hash.format-hex` over canonical bytes; `store.put-doc`; advance the `head` alias | per-journal commit lock for linearization (§2.1); `prev-hash = head-hash`; `expect-pos` check under the lock (§3.2); CAS the head alias for the optimistic path |
| `read` / `slice` / `since` | `store.get-doc` by per-seq alias/key, or `store.iter-docs` over the partition in `seq` order | a `seq → hash` index (a store alias per `seq`, or a packed segment) keeps `read` O(1); absence = empty node-set, not `null` (§2.5) |
| `query` | `store.query $cxpath` scoped to the tenant partition | reuses store's CXPath query engine ([`store.md`](../std-lib/store.md) §6); confined to one tenant by the partition (§4.1) |
| `fold` / `replay` | `since 1` (or windowed) → `fold-value` with the pure `$fn` | `fold-value` is the pure core; `replay at-seq=N` folds the prefix `1..N`; reaches no external effect (§2.7) |
| `dry-run` | `fold-value` to head + one provisional `$fn` step (no `put-doc`) | builds an uncommitted `[entry seq=head+1 …]`, never persists; head unmoved (§3.5) |
| `verify` | re-hash each entry via `hash`; compare stored `hash`/`prev-hash`; check `seq` density | returns a `[verification …]` finding, never raises on a *finding* (§2.5/§3.6); `hash.equals` for constant-time digest compare; at a seam, anchor `prev-hash` against the snapshot `anchor-hash` (§4.10) |
| `snapshot` | `fold` to `at-seq` (pure `$fn`) → `crypto.sign` over `(state+at-seq+anchor-hash+algo)` | returns a **derived** `[snapshot …]` value; `anchor-hash` = entry-`at-seq` `hash`; optional `store.put-doc` under a snapshot namespace (`opts.persist`); never appended (§2.8/§3.7) |
| `snapshot-verify` / `fold-from` | `hash.equals(anchor, live-hash-at-seq)` + `crypto.verify(sig)`; then `fold-value (since at-seq+1)` onto `state` | `snapshot-verify` returns a finding (value); `fold-from` raises `CXER4615`/`CXER4613` on a divergent/forged cover before folding the tail (§3.7) |
| `retain` | compute boundary `B` from the policy; `snapshot-verify` the cover; assert `B ≤ cover.at-seq` | returns a `[retention …]` value; deletes nothing; uncovered → `CXER4616` (§4.9) |
| `compact` | `store.put-doc` the seam `[snapshot]` + copy retained tail **verbatim** to `opts.target`; optionally `store` move `1..B` to `opts.archive` | copy-forward; source untouched (§4.10); new segment is a valid chain anchored at the seam; collision → `CXER4600` |
| `rotate` | `retain` (per stream, own boundary) → `compact` into ONE target → write the segment index (`cx-journal/segments/<tenant>`) + carry the named alias prefixes | copy-then-swap: source untouched; returns `[rotated … [journal …]]` (the new hot); unsigned cover → `CXER4614`; nothing-to-seal → `CXER4610` (§4.11) |

The chain link uses **`hash.sha256` by default** ([`hash.md`](../std-lib/hash.md) §3.1)
— `blake3` is available and is the faster choice for a hot append path; the algo is a
per-chain `open` option (§4.2). The `seq → entry-hash` index (so `read`/`replay` need
not scan) is an implementation choice over store aliases or a packed segment file; the
spec is index-agnostic. Spec is implementation-agnostic; only surface + guarantees are
normative.

**Why this stays thin (N-IMPL-1).** journal adds **no persistence engine** (store), **no
digest** (hash), **no signing** (crypto, §4.8), **no pub/sub** (bus), **no policy**
(authz), **no orchestration** (xap). It is exactly: a per-tenant commit lock, a
`seq`/`prev-hash`/`hash` envelope around a caller value, a pure fold, a re-hash walk,
and — for the checkpoint surfaces — a *signed projection* (compose `crypto`) plus a
*copy-forward* of a retained tail (compose `store`). Snapshots/retention/compaction add
**no new mechanism**: they are folds + signatures + copies over the existing chain.
Everything else composes.

## §10. Conformance fixtures (to author on graduation)

Hermetic; default to the **`mem://` backend** (capability-free, deterministic) plus a
`file://`-tmp variant for the persistence/quota cases. **Every matrix ✅ has ≥1
positive fixture; every justified ❌ a negative/no-surface fixture.** All use the
controllable `clock` (§4.3) so `ts`/`hash` are byte-stable.

> **Per-stream (§2.1.1) fixtures.** The original cases cover the **single-`:default`-
> stream** behavior and remain green byte-identically. **Authored (green):**
> journal-059…065 — named-stream genesis, default↔named independence, per-stream `seq`,
> the `streams` enumerator, per-stream `expect-pos` stale-tail + its stream
> isolation, and the default-invisible backward-compat guard; **journal-066…068** —
> per-stream `verify`, per-stream `fold`, and per-stream `snapshot` + `fold-from`;
> **journal-069…071** — per-stream `retain` + `compact` (segment read, seam-anchored
> verify, source-intact). (`file://` reload of a named stream is validated out-of-band
> — it needs a write grant the hermetic `mem://` tier withholds.) These double as the
> [`xap.md`](xap.md) §14.3 battery's journal-layer half.

Positives: `open`/`append`/`read` round-trip — **`append` returns the committed
`[entry]` with `seq`, `prev-hash`, `hash`** (§2.4); genesis entry has
`prev-hash="genesis:"`, `seq=1` (§4.2); **dense gap-free `seq`** across N appends;
**`prev-hash` chains** (entry N's `prev-hash` = entry N-1's `hash`); `slice`/`since`
return entries in `seq` order; **empty/out-of-range read → absence (empty node-set),
not `null` and not `[err]`** (§2.5); `query` CXPath slice over `[event …]` payloads;
`head` (pure) returns the current entry, **absence on an empty journal**; `fold` over
the log → a deterministic state projection; **`fold` over an empty journal returns
`$init` unchanged** (§2.5); `fold-value` purity (fold a `since` result with no backend
access); `replay … at-seq=N` reconstructs the **as-of-N** state (time-travel); **two
runs of the same `fold`/`replay` produce byte-identical state** (determinism, §2.7);
`dry-run` returns `[dry-run state=… provisional-entry=[entry seq=head+1 …]]` and
**leaves `head-seq`/`head-hash` unmoved** (no commit); `verify` of an intact chain →
**`[verification valid=true checked-to=N]`** (a VALUE); **`verify` of a tampered entry
→ `[verification valid=false first-bad-seq=K reason=:hash-mismatch]` (a FINDING, not
`[err]`)** + the `:link-broken`/`:seq-gap`/`:genesis-invalid` reason variants;
`verify-slice` bounded check; optimistic `append` with correct `expect-pos`
commits; concurrent appends from multiple workers are **linearized** (no shared `seq`,
each `prev-hash` chains, §2.1); `[?with-open]` auto-close idempotent; `mem://` runs
under the **empty capability set** (no `CXER0271`); `file://` `append` under
`--allow-write` happy path.

Snapshot / retention / compaction positives: **`snapshot` round-trip** — `snapshot` at
`seq=N` returns `[snapshot at-seq=N anchor-hash=<entry-N hash> signature=… [state …]]`
and `snapshot-verify` of it → **`[snapshot-verification valid=true]`** (a VALUE);
**`fold-from $snap $fn` equals a full `fold $fn`** in result (the §3.7 equivalence —
byte-identical projected state, the table-stakes acceleration check); **the snapshot
leaves `head-seq`/`head-hash` unmoved** (derived artifact, never appended, §2.8);
unsigned `mem://` snapshot (`sign=false`) verifies its anchor only
(`valid=true reason=:unsigned`) and seeds `fold-from`; **`verify` ACROSS a
snapshot/compaction seam** — a compacted segment's first retained entry anchors its
`prev-hash` to the seam snapshot and `verify` → `valid=true` (§4.10); `retain` with a
covering signed snapshot returns `[retention boundary=B covered-by-seq=N …]`;
**`compact` copy-forward leaves the SOURCE byte-for-byte intact** (re-`verify` source
after compaction → still `valid=true`, `head` unchanged) and produces a new segment
that itself `verify`s `valid=true`; `replay`/`fold-from` over the compacted segment
equals the original's fold (state preserved across pruning, §4.9).

Snapshot / retention / compaction negatives: **prune-requires-snapshot — `retain`
with a boundary past the cover (or no cover) → `CXER4616`** (never prune
un-snapshotted history, §4.9); a **forged/corrupt signed snapshot** to `fold-from` →
`CXER4613` (signature invalid); a **divergent snapshot** (`anchor-hash` ≠ live entry-N
`hash`, e.g. taken against a tampered chain) to `fold-from`/required-cover →
`CXER4615`, and to `snapshot-verify` → a **`[snapshot-verification valid=false
reason=:anchor-mismatch]` FINDING** (value, not `[err]`); `snapshot` without a
signing-key on a signing-required tier → `CXER4614`; an **unsigned snapshot offered as
a retention cover** → `CXER4614`; `snapshot opts.at-seq` beyond head → `CXER4606`;
`compact` to a target colliding with a live chain → `CXER4600`; **no in-place /
destructive compaction surface exists** (source-intact + no-rewrite no-surface
fixture, §4.10).

> **Appointed-signer (S6.4, F5(b)) fixtures.** Authored (green): journal-072…075 —
> **self-signed verify** (the `signer=` hint stamped and the verify key resolved from
> it → `valid=true`, the default self-attestation path); **appointed-signer verify**
> (the signer DID holds `snapshot-sign` in the caller-designated `[authz-store]`
> registry → `valid=true` under `require-appointed`); **forged signer** (`signer=`
> names a DID whose key did not produce the signature → `valid=false
> reason=:signature-invalid`); **appointment required but ungranted** (crypto-valid,
> no `snapshot-sign` grant → `valid=false reason=:not-appointed`, the registry's
> `[deny …]` as the finding's child).

Negatives / no-surface: **append-only — no `update`/`delete`/`truncate` verb exists**
(no-surface fixture); **cross-tenant read is inexpressible — no read takes a tenant
arg** (no-surface fixture, §4.1); concurrent-append conflict with `expect-pos`
stale → `CXER1114`; `open create=false` on an absent partition → `CXER4601`; re-open
with a different `hash-algo` → `CXER4602`; `append` on `read-only=true` → `CXER4603`;
unsupported `hash-algo` → `CXER4607`; missing `actor`/`authority` → `CXER4609`;
`seq<1` / `from>to` → `CXER4610`; **impure `$fn` to `fold`/`replay`/`dry-run` →
`CXER4611`** (the determinism guard); op on a closed journal → `CXER4612`;
`replay at-seq` beyond head → `CXER4606`; an unserializable `$event` → `CXER4608`; no
`write` grant on a `file://` append → `CXER0271`; a tampered chain detected mid-`append`
(predecessor unreadable) → `CXER4605` (distinct from the `verify` *finding*);
`[?timeout]` over a long `verify`/`replay` → inner `CXER0260`. Inherited store
negatives (read-only backend `CXER1110`, not-found `CXER1121`, store closed `CXER1130`)
exercised through the backend.

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6): add
      `CXER4600–CXER4649 | cx-stdlib/journal | spec/std-lib/journal.md`; re-run the band
      scan (confirm no overlap with http's `CXER4525–4543` or the sibling XAP blocks).
- [ ] **Module index + count (see §12).** Add a `journal` row to
      [`spec/std-lib/README.md`](../std-lib/README.md) §3 (Tier-B) and bump the count
      by **+1 on the then-current count** (journal is a genuine **new** bundled name,
      unlike http which was a reconciliation; it must also be added to the skeleton
      test's expected list + assert, [`http.md`](http.md) §12 — the
      five XAP modules are five genuine +1s, ordered with the other in-review drafts).
- [ ] **Add the bundled name + implement** `stdlib/journal.cx` for the **full** §3
      surface: `open`/`attach`/`close`; `append`; `read`/`slice`/`since`/`query`/`head`;
      `fold`/`fold-slice`/`fold-value`; `replay`/`dry-run`; `verify`/`verify-slice`;
      **`snapshot`/`snapshot-verify`/`fold-from`/`retain`/`compact`** (§3.7).
- [ ] Implement on `store` + `hash` (+ `crypto` for snapshot signing): per-tenant
      partition + commit lock + `seq→hash` index + the canonical-bytes hash + the
      re-hash `verify` walk **incl. the snapshot/compaction seam** (§4.10); pure
      `fold-value` core; the determinism (`CXER4611` purity) gate; the signed-snapshot
      projection (`crypto.sign`/`verify`, §4.8); the prune-behind-snapshot cover check
      (`CXER4616`, §4.9); the `compact` copy-forward (source-intact, §4.10).
- [ ] **`cx-stdlib/store`, `cx-stdlib/hash`, and `cx-stdlib/crypto` are shipped** (hard
      dependencies — journal is built on store+hash, and snapshot signing composes
      crypto); confirm the `store` capability model + CXPath query engine, the `hash`
      algo set, and `crypto`'s signing algos/key handles are the versions cited here.
- [ ] Confirm journal's reliance on the §0 in-review amendments survived their G3
      (four-channel model incl. **finding-is-a-value** + **absence-not-null**, `[?try]`
      retirement, `CXER0260` cancellation, orthogonality-guard home).
- [ ] Coordinate with the **sibling XAP drafts** — `bus`/`authz`/`session`/`xap` — so
      the contiguous `CXER46xx` blocks, the cascade ownership (§1/§6), the attribution
      boundary (§2.6), and the tenant-partition contract (§4.1) agree across all five
      before any of them graduates.
- [ ] **Snapshots / retention / compaction are IN this revision** (§2.8, §3.7,
      §4.8–§4.10) — signed snapshot **projection** + `fold-from` + prune-behind-snapshot
      retention + copy-forward compaction, all **non-mutating** (no mutate-in-place verb;
      §4.5). They consume codes `CXER4613–4616` of the reserved band (§8). Confirm the
      append-only + hash-chain invariants hold under all three (the source-intact and
      prune-requires-snapshot fixtures, §10) before graduation. `CXER4618–4649` stay
      reserved for any later checkpoint/archival surface.
- [ ] Author §10 fixtures; wire into the gate.
- [ ] Validate repo-relative cross-references render (siblings live alongside in
      `spec/02-inprogress/xap/`).
- [ ] Move `spec/02-inprogress/xap/journal.md` → `spec/std-lib/journal.md`
      (user-only).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states the count delta; per Rule G3 it makes **no edits**.

**journal is a genuine `+1`** (unlike http, which was a README-vs-binary
*reconciliation* of an already-bundled name — [`http.md`](http.md)
§12). journal is **not yet a bundled name**: it is absent from the skeleton test
`vcx/tests/stdlib_skeleton_test.v`. So at graduation it adds **+1 to the
then-current bundled-name count** — both a new `'cx-stdlib/journal'` entry in the
skeleton's `expected` list (with its assert bumped) **and** a new `journal` row +
count bump in [`spec/std-lib/README.md`](../std-lib/README.md) §3.

**Interaction with the other in-review drafts (local facts only).** journal is one of
**five** new XAP bundled names (`bus`, `journal`, `authz`, `session`, `xap` —
[`xap.md`](xap.md) §25.1), each a genuine **+1**, alongside the independently-in-review
`net` and `fp` (also +1 each) and the http *reconciliation* (29→30, no skeleton move).
The bumps are **order-independent**: each graduation applies +1 to whatever the count
is at that moment. journal does **not** depend on the others to graduate *as a module*
(its only hard deps are the shipped `store` + `hash`), but the **five XAP drafts SHOULD
be reviewed and graduated as a cohort** so the cascade-ownership, attribution-boundary,
and contiguous-error-band agreements (§11) are settled together rather than across
separate G3s. **No edits are made by this draft** (G3) — the deltas above are for the
graduation PR.

---

### Review questions — RESOLVED (user G3, 2026-06-07)

1. **`append` attribution shape — RESOLVED (a): `$attribution::map`.**
   `append` takes a `{actor: … authority: …}` map (extensible for `expect-pos`
   and a future signing-tier hint without an arity change), rather than two positional
   string args. The map future-proofs the optimistic-concurrency + signing-tier
   additions inside the reserved band without breaking `append`'s arity, matching how
   `store`/`http` carry an `$opts::map`. (Rejected: (b) positional `$actor $authority`
   forces an arity break the moment a third attribution field lands; (c) folding
   attribution into the event value would let a caller forge/omit it and breaks the
   §2.6 envelope/cargo split.)

2. **`dry-run` reducer signature — RESOLVED (a): self-contained `$fn`+`$init`.**
   `dry-run` is self-contained (`$event $attribution $fn $init`), folding from genesis
   each call — the v1 thin surface (correctness + determinism are obvious; it is the
   §10.10-answer-4 scenario validator verbatim). **Noted v1.x optimization (deferred,
   additive — a defaulted positional, costs nothing to defer):** accept an optional
   pre-folded `$state-at-head` to skip the re-fold on a hot anticipation path (the
   speculative-composition loop, [`xap.md`](xap.md) §19). (Rejected: (b) requiring the
   caller to pass the pre-folded state now is premature optimization that complicates
   the common case.) The reserved-band/amendment plan accounts for the optimization.
