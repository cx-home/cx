# `cx-stdlib/journal` — append-only, hash-chained, tenant-partitioned event log + fold→state

```cx
[module-meta name=journal tier=D status=current]
```

**Status:** Current

> **Per-aggregate streams (R2) — IMPLEMENTED (complete).** §2.1.1 generalizes the single-chain handle to **per-aggregate streams** (the scalability model XAP requires, [`xap.md`](xap.md) §14.2). The default stream is the **invisible degenerate case** (no stream attr/coordinate, legacy alias), so the prior single-chain behavior is preserved **byte-identically** (all original conformance cases green, unchanged). **Implemented** in `vcx/code/stdlib_journal.v` across the whole surface: the `stream` key on `append` (per-stream `seq`/head/chain + per-stream `expect-prev-seq` conflict + parallel disjoint append); stream-scoped `read`/`slice`/`since`/`head`, `verify`, `fold`/`fold-slice`/`replay`, `snapshot`/`snapshot-verify`/`fold-from`, and `retain`/`compact` (per-stream seam-anchored copy-forward); the `streams` enumerator; and `file://` **reload** of named streams (via a persisted stream index). Tenant-wide state is the **caller's order-independent composition** of per-stream folds (the journal exposes per-stream `fold` + `streams`; it cannot merge opaque user states itself). Fixtures **journal-059…071** green (§10). The R2 graduation gate is **closed**; remaining graduation is the normal §11 checklist + user G3.

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
[journal tenant="acme" state="open" head-seq=147 head-hash="b3:9f…"   # a journal — over a store backend
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

### §2.2. `[entry]` — the attributed, hash-linked event record

A committed entry is the load-bearing value of this module. It **reuses the
attribution shape of [`xap.md`](xap.md) §22.6 exactly** — every event carries
`:actor` + `:authority` + `:tenant` — and adds the chain coordinates:

```cx
[entry seq=147 tenant="acme" stream="principal:dana"   # seq is per-stream (§2.1.1)
  actor="agent:ops-agent-1"            # the emitting party (opaque to journal — §2.6)
  authority="d-recon-77"               # the authority basis (a delegation/grant id — opaque)
  ts="2026-06-06T18:22:04.119Z"        # commit timestamp (assigned at append — §4.3)
  prev-hash="b3:8c1a…"                 # content hash of entry seq=146 (the chain link)
  hash="b3:9f04…"                      # content hash of THIS entry (over its canonical bytes)
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
  **genesis entry's `prev-hash` is the fixed sentinel `"b3:GENESIS"`** (§4.2).
- `hash` — the content hash of *this* entry computed over its **canonical bytes**
  (`seq` + `tenant` + `actor` + `authority` + `ts` + `prev-hash` + the event payload),
  via `hash` (default `sha256`, §4.2). Because `hash` covers `prev-hash`, the chain is
  **tamper-evident**: altering any past entry breaks every subsequent link (§2.5,
  §4.2).
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
not be served: a **stale-tail / concurrent-commit conflict** (`CXER4604`), a **closed
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
    anchor-hash="b3:9f04…"          # = entry seq=147's hash (the chain anchor — §2.2)
    hash-algo="sha256"              # the chain algo this snapshot is anchored against
    sig-algo="ed25519"              # crypto signing algo (§4.8) — non-repudiation of the artifact
    signature="b3:7c21…"            # crypto signature over (canonical state-bytes + at-seq + anchor-hash)
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
partition → `head-seq=0`, `head-hash="b3:GENESIS"`); they **do not** replay or verify
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
append *only if the tail has not moved* passes `$attribution.expect-prev-seq`; if the
target **stream's** `head-seq` ≠ that value at commit, `append` raises
**`cx-err:CXER4604 E_JOURNAL_STALE_TAIL`** (the caller re-reads and retries). This is
the per-stream conflict primitive XAP's §4.1 "first-commits-wins, second is a rejection"
rests on. Without `expect-prev-seq`, `append` always appends at the current head of that
stream (last-writer-extends, never overwrites).
The chain is **append-only**: there is no `update`/`delete`/`truncate` verb (§4.5).

### §3.3. Reading — range and CXPath slice

```
[?def read   scope=public impure [returns element]            ($journal::element $seq::int) ...]
[?def slice  scope=public impure [returns [sequence element]] ($journal::element $from::int $to::int) ...]
[?def since  scope=public impure [returns [sequence element]] ($journal::element $from::int) ...]
[?def query  scope=public impure [returns [sequence element]] ($journal::element $cxpath::path) ...]
[?def head   scope=public pure   [returns element]            ($journal::element) ...]
```

- `read $seq` — the single `[entry]` at `seq`, or the **absence channel (empty)** if
  `seq` is out of range (§2.5). `seq < 1` → `CXER4610`.
- `slice $from $to` — entries with `from ≤ seq ≤ to` (inclusive, 1-based) in `seq`
  order; an out-of-range or empty window → the **empty `[sequence element]`** (§2.5).
  `from > to` → `CXER4610`.
- `since $from` — `slice $from head-seq` (the tail from `$from` to the current head);
  the common incremental-read form (a reader catching up from its last-seen `seq`).
- `query $cxpath` — entries whose `[event …]` payload (or envelope attrs) match a
  **CXPath predicate** ([`store.md`](../std-lib/store.md) §6 query semantics), e.g.
  `[$journal:query $j '/event/do[@*='refund-duplicate']']`; returns matches in `seq`
  order, **empty** when none match. This is the auditable "why/when did X happen"
  query ([`xap.md`](xap.md) §22.10 answer 4) over a single tenant's log.
- `head` — the current `[entry]` at `head-seq` (**pure** — reads the cached head off
  the handle, no backend round-trip), or **absence** on an empty journal.

All reads are **tenant-confined by construction** — every one operates over the
handle's partition; **no read takes a tenant argument**, so a cross-tenant read
is not expressible (§4.1, [`xap.md`](xap.md) §22.6).

**Reads are stream-scoped (§2.1.1).** Because `seq` is per-stream, `read`/`slice`/`since`/
`head` operate on **one stream** — each gains a trailing defaulted `stream::string`
(default `:default`), e.g. `[$journal:read $j 147 "principal:dana"]`. `streams`
enumerates the journal's stream keys; `query $cxpath` matches **across all streams**
(it filters by payload, not `seq`) and returns matches grouped by stream then `seq`. A
read on an unknown stream → the **absence channel** (empty), never an error.

### §3.4. Folding — the state projection (pure reducer)

```
[?def fold scope=public impure [returns any] ($journal::element $fn      $init::any) ...]
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

`$fn` **MUST be pure** (§2.7); an impure `$fn` → `cx-err:CXER4611
E_JOURNAL_FOLD_IMPURE`. Determinism is guaranteed: same entries + same `$fn` + same
`$init` → same result, always (§2.7).

### §3.5. Replay and dry-run — deterministic re-execution / no-commit preview

```
[?def replay  scope=public impure [returns any] ($journal::element $fn $init::any $opts::map {}) ...]
[?def dry-run scope=public impure [returns element] ($journal::element $event::any $attribution::map $fn $init::any) ...]
```

- `replay` — a **deterministic re-execution** of the log into state via the pure `$fn`
  (§2.7); semantically `fold` with **replay options** (`opts.from`/`opts.to` to bound
  the window, `opts.at-seq` to reconstruct the state *as of* a past `seq` — the
  "rewind/branch is log navigation" of [`xap.md`](xap.md) §18.2, and the
  last-in-command anchor of §9.1). `replay` reads the committed log only and reaches
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
[verification valid=true  checked-from=1 checked-to=147 head-hash="b3:9f04…"]
[verification valid=false checked-from=1 first-bad-seq=88 reason=:hash-mismatch]   # a FINDING
```

`reason` ∈ `:hash-mismatch` (re-hash ≠ stored `hash`) | `:link-broken`
(`prev-hash` ≠ predecessor's `hash`) | `:seq-gap` (missing/duplicate `seq`) |
`:genesis-invalid` (`seq=1` `prev-hash` ≠ the `"b3:GENESIS"` sentinel). `verify-slice`
checks only `from..to` (anchoring `prev-hash` of `from` against `from-1`'s stored
`hash`). `opts.from`/`opts.to` bound `verify` likewise. A `[verification valid=false]`
is **not** an `[err]` — it is the successful tamper-evidence finding (§2.5,
[`xap.md`](xap.md) §22.6). `verify` raises `[err]` only when it cannot *perform* the
walk: closed handle (`CXER4612`), backend fault (store `CXER11xx`), denial (`CXER0271`).
`verify`/`verify-slice` also walk **across a snapshot/compaction boundary** (§4.10):
the first entry of a compacted segment anchors its `prev-hash` to the embedded
snapshot's `anchor-hash`, so a verify that begins at the seam checks that link instead
of the `"b3:GENESIS"` sentinel (a `:link-broken` finding if the seam does not match).

### §3.7. Snapshots, retention, compaction — derived checkpoints + archival copy-forward

```
[?def snapshot        scope=public impure [returns element] ($journal::element $fn $init::any $opts::map {}) ...]
[?def snapshot-verify scope=public impure [returns element] ($journal::element $snapshot::element) ...]
[?def fold-from       scope=public impure [returns any]     ($journal::element $snapshot::element $fn) ...]
[?def retain          scope=public impure [returns element] ($journal::element $policy::map) ...]
[?def compact         scope=public impure [returns element] ($journal::element $opts::map {}) ...]
```

All five are **non-mutating on the live chain** (§2.8, §4.5): `snapshot`/`fold-from`
read it, `retain` records a policy + checks coverage, `compact` copies forward into a
*new* segment. None advances `head-seq`/`head-hash` of the source journal.

- `snapshot` — folds the log up to `opts.at-seq` (default `head-seq`) with the **pure**
  `$fn`/`$init` (§2.7) and returns a **signed `[snapshot at-seq=N anchor-hash=… signature=… [state …]]`**
  value (§2.8). The `signature` is computed by `crypto` (§4.8) over the canonical bytes
  of `(state + at-seq + anchor-hash + hash-algo)`; the signing key is supplied via
  `opts.signing-key` (a `crypto` key handle) — **absent key + a tier that requires
  signing → `cx-err:CXER4614 E_JOURNAL_SNAPSHOT_UNSIGNED`** (a `mem://` test tier may
  opt out via `opts.sign=false`, yielding an *unsigned* snapshot usable for `fold-from`
  but **not** as a retention cover — §4.9). `anchor-hash` is set to entry `at-seq`'s
  live `hash`; `opts.at-seq` beyond head → `CXER4606`. The snapshot is a **derived
  artifact**: it is returned as a value and MAY be persisted by the caller (or
  `opts.persist=true` writes it to a snapshot-namespaced `store` key) — it is **never**
  appended to the chain. **Multi-stream (§2.1.1):** a tenant snapshot records the **set
  of stream heads** `{(stream, at-seq, anchor-hash)}` and folds the tenant-wide
  composition (§3.4); the `signature` covers that whole set, so **one signed snapshot is
  the tenant-wide integrity anchor** across all per-stream chains (§4.2). A
  single-stream snapshot is the `:default`-only case of this.
- `snapshot-verify` — checks a `[snapshot]` against the chain and against its own
  signature, returning a **present `[snapshot-verification valid=… …]` finding** (a
  value, not an `[err]` — same SAP §1 posture as `verify`, §2.5/§3.6). It validates
  (1) `anchor-hash` equals the live `hash` of entry `at-seq` (else `valid=false
  reason=:anchor-mismatch`, the divergence guard of §2.8), (2) the signature verifies
  against the key (else `:signature-invalid`), and (3) `hash-algo` matches the chain's.
  An *unsigned* snapshot verifies its anchor only (`reason=:unsigned` is a `valid=true`
  caveat, never a fault).
- `fold-from` — reconstructs state **fast**: it `snapshot-verify`s `$snapshot` against
  the chain (a `valid=false` anchor → `cx-err:CXER4615 E_JOURNAL_SNAPSHOT_SEQ_MISMATCH`
  / a bad signature → `cx-err:CXER4613 E_JOURNAL_SNAPSHOT_SIG_INVALID`), then folds
  **only entries `at-seq+1 .. head`** onto `$snapshot.[state …]` with the pure `$fn`,
  returning the same state a full `fold $fn $snapshot-init` would (an equivalence pinned
  by a fixture, §10). `$fn` held to the **pure** bar (`CXER4611`).
- `retain` — records a **`[retention]` policy** (`$policy` = one of
  `{keep-after-seq: N}` / `{keep-after-time: TS}` / `{keep-N: K}`) plus the covering
  snapshot it is validated against (`$policy.snapshot`, a `[snapshot]` value). It
  computes the prune boundary `B` (the highest `seq` eligible to be pruned) and
  **enforces the §4.9 cover rule**: `B ≤ $policy.snapshot.at-seq` **and** that snapshot
  must `snapshot-verify` valid-and-signed, else **`cx-err:CXER4616
  E_JOURNAL_RETENTION_UNCOVERED`** (you may not declare a prune of un-snapshotted
  history). `retain` does **not** itself delete anything — it returns a
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
`prev-hash = "b3:GENESIS"` (a fixed sentinel, never a real digest). Every entry's
`hash` is `hash.format-hex(hash.<algo>(canonical-bytes))` (prefixed with the algo tag,
e.g. `"b3:…"`/`"sha256:…"`) over its **canonical CX bytes** — the deterministic
serialization of `seq`+`tenant`+**`stream` (omitted when `:default`)**+`actor`+`authority`+`ts`+`prev-hash`+`[event …]`
(the doc's canonical render, the same bytes `store` would content-address). Because
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
`append` assigns `ts` from `opts.clock` (default monotonic UTC); `ts` is **monotonic
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
A stream-scoped reader (`read`/`slice`/`since`/`query`/`fold`/`replay`/`verify`)
observes a **consistent committed prefix of its stream**: every entry up to some
`seq ≤ that stream's head-seq` at the read's start, none partial. An `append`
committing concurrently — to this stream or any other — MAY or MAY NOT be visible to an
in-flight read (visible iff it committed to *this* stream before the read snapshotted
its head), but a read **never** observes a torn or uncommitted entry. `fold`/`replay`
over a stream's `since 1` thus reproduce a deterministic prefix; pairing with `head`
(per stream) lets a caller pin the exact `seq` they folded to. A tenant-wide
composition (§3.4) snapshots each stream's head independently; it is consistent per
stream, with no cross-stream linearization claimed (none exists — §4.3).

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
`head` and `fold-value` are **pure** (operate on the handle's cached head / an
already-materialized sequence — no backend access, referentially transparent). All
other verbs are **impure** (they reach `store`). The reducer `$fn` passed to
`fold`/`fold-slice`/`replay`/`dry-run`/`fold-value` **must be pure** regardless of the
enclosing verb's purity — determinism (§2.7) requires it; `CXER4611` enforces it.

### §4.7. Handle quotas and lifecycle
The underlying `store` handle counts against store/host quotas; an op on a closed
journal → `cx-err:CXER4612 E_JOURNAL_CLOSED`. `[?with-open]` close (§2.1) flushes +
releases, idempotent with explicit `close`.

### §4.8. Snapshot signing — non-repudiation of the derived artifact (composes `crypto`)
A `snapshot` is **signed** (§2.8/§3.7) by composing `crypto`'s signing primitives over
the canonical bytes of `(state + at-seq + anchor-hash + hash-algo)`; `sig-algo` is a
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

### §4.10. Compaction seam — copy-forward, never in-place
`compact` (§3.7) writes a **new** segment: a covering `[snapshot]` seam record, then the
**retained tail** copied **verbatim** (each entry's `seq`/`prev-hash`/`hash` bytes
unchanged). The seam: the first retained entry (`seq=B+1`) already carries
`prev-hash =` entry `B`'s `hash`, and the embedded snapshot's `anchor-hash` equals that
same `hash` (the snapshot covers through `≥ B`), so `verify`/`replay` crossing the seam
check the retained entry's `prev-hash` against the **snapshot anchor** instead of the
`"b3:GENESIS"` sentinel — a documented, verifiable join (§3.6). The **source journal is
left byte-for-byte intact**; `compact` is a read-original/write-new copy, so:

- it is **reversible** (discard the new segment; the source is untouched);
- it **never edits a committed entry** in place — the append-only invariant (§4.5)
  holds for both source and segment;
- the new segment is itself a valid append-only hash-chain anchored at its snapshot
  seam, so `append`/`verify`/`replay`/`fold`/`snapshot` all work on it unchanged.

Compaction therefore *bounds* replay cost (start from the seam, not genesis) **without**
any in-place mutation — the copy-forward discipline is what makes that sound.

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
| `read` / `slice` / `since` / `query` / `fold` / `fold-slice` / `replay` / `verify` / `verify-slice` | `read` (file/local) / `net` (remote) | the backend resource; `mem://` → none |
| `snapshot` / `fold-from` / `snapshot-verify` | `read` (to fold the chain) + `crypto` signing key for `snapshot` (§4.8) | the backend resource; `mem://` → none. Signing uses `crypto`'s key/cap posture — **no new journal cap** |
| `retain` | `read` (verify the covering snapshot) | the backend resource; records a policy, deletes nothing |
| `compact` | `read` (source) + `write`/`net` (the `opts.target`/`opts.archive` namespaces) | source + target/archive backend resources; `mem://` → none |
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
  [case [err @code='cx-err:CXER4604'] [$retry-after-rebase $j $ev]]   # stale tail → re-read + retry
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
  natural response to a `CXER4604` stale-tail; `[?timeout]` over a long `verify`/`replay`
  → `CXER0260`.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | `file://` backend | `mem://` backend | remote backend |
|---|:--:|:--:|:--:|
| `open` / `attach` / `close` | ✅ | ✅ ¹ | ✅ ² |
| `append` (single mutating verb) | ✅ | ✅ ¹ | ✅ ² |
| `read` / `slice` / `since` / `head` | ✅ | ✅ ¹ | ✅ ² |
| `query` (CXPath slice) | ✅ | ✅ ¹ | ✅ ² |
| `fold` / `fold-slice` / `fold-value` | ✅ | ✅ ¹ | ✅ ² |
| `replay` (incl. `at-seq` time-travel) | ✅ | ✅ ¹ | ✅ ² |
| `dry-run` (no-commit preview) | ✅ | ✅ ¹ | ✅ ² |
| `verify` / `verify-slice` (incl. across a seam) | ✅ | ✅ ¹ | ✅ ² |
| `snapshot` / `snapshot-verify` (signed checkpoint) | ✅ | ✅ ¹ ⁹ | ✅ ² |
| `fold-from` (fast reconstruction) | ✅ | ✅ ¹ | ✅ ² |
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
but **not** as a retention cover (§4.9).

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
§3.7, §4.8–§4.10). All values use `cx-err:` notation;
symbolic↔wire is 1:1 (governance invariant). **Cancellation is the core `CXER0260`,
not a journal code** (§0, §5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4600` | `E_JOURNAL_OPEN_FAILED` | `open`/`attach` could not bind the tenant partition (backend reachable but partition unusable; a backend *fault* surfaces as store's `CXER11xx`) |
| `cx-err:CXER4601` | `E_JOURNAL_NOT_FOUND` | `open` with `create=false` against an absent partition |
| `cx-err:CXER4602` | `E_JOURNAL_ALGO_MISMATCH` | re-opening an existing chain with a different `hash-algo` than it was created with (§4.2) |
| `cx-err:CXER4603` | `E_JOURNAL_READ_ONLY` | `append` on a `read-only=true` journal (§3.1) |
| `cx-err:CXER4604` | `E_JOURNAL_STALE_TAIL` | `append` with `expect-prev-seq` ≠ the current `head-seq` (optimistic-concurrency conflict, §3.2) |
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

`CXER4617–4649` remain **reserved** within the band for further checkpoint/archival
surface (e.g. snapshot-of-snapshot chaining, multi-segment compaction descriptors) so
they land without a re-allocation.

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
| `append` | `hash.<algo>` + `hash.format-hex` over canonical bytes; `store.put-doc`; advance the `head` alias | per-journal commit lock for linearization (§2.1); `prev-hash = head-hash`; `expect-prev-seq` check under the lock (§3.2); CAS the head alias for the optimistic path |
| `read` / `slice` / `since` | `store.get-doc` by per-seq alias/key, or `store.iter-docs` over the partition in `seq` order | a `seq → hash` index (a store alias per `seq`, or a packed segment) keeps `read` O(1); absence = empty node-set, not `null` (§2.5) |
| `query` | `store.query $cxpath` scoped to the tenant partition | reuses store's CXPath query engine ([`store.md`](../std-lib/store.md) §6); confined to one tenant by the partition (§4.1) |
| `fold` / `replay` | `since 1` (or windowed) → `fold-value` with the pure `$fn` | `fold-value` is the pure core; `replay at-seq=N` folds the prefix `1..N`; reaches no external effect (§2.7) |
| `dry-run` | `fold-value` to head + one provisional `$fn` step (no `put-doc`) | builds an uncommitted `[entry seq=head+1 …]`, never persists; head unmoved (§3.5) |
| `verify` | re-hash each entry via `hash`; compare stored `hash`/`prev-hash`; check `seq` density | returns a `[verification …]` finding, never raises on a *finding* (§2.5/§3.6); `hash.equals` for constant-time digest compare; at a seam, anchor `prev-hash` against the snapshot `anchor-hash` (§4.10) |
| `snapshot` | `fold` to `at-seq` (pure `$fn`) → `crypto.sign` over `(state+at-seq+anchor-hash+algo)` | returns a **derived** `[snapshot …]` value; `anchor-hash` = entry-`at-seq` `hash`; optional `store.put-doc` under a snapshot namespace (`opts.persist`); never appended (§2.8/§3.7) |
| `snapshot-verify` / `fold-from` | `hash.equals(anchor, live-hash-at-seq)` + `crypto.verify(sig)`; then `fold-value (since at-seq+1)` onto `state` | `snapshot-verify` returns a finding (value); `fold-from` raises `CXER4615`/`CXER4613` on a divergent/forged cover before folding the tail (§3.7) |
| `retain` | compute boundary `B` from the policy; `snapshot-verify` the cover; assert `B ≤ cover.at-seq` | returns a `[retention …]` value; deletes nothing; uncovered → `CXER4616` (§4.9) |
| `compact` | `store.put-doc` the seam `[snapshot]` + copy retained tail **verbatim** to `opts.target`; optionally `store` move `1..B` to `opts.archive` | copy-forward; source untouched (§4.10); new segment is a valid chain anchored at the seam; collision → `CXER4600` |

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
> the `streams` enumerator, per-stream `expect-prev-seq` stale-tail + its stream
> isolation, and the default-invisible backward-compat guard; **journal-066…068** —
> per-stream `verify`, per-stream `fold`, and per-stream `snapshot` + `fold-from`;
> **journal-069…071** — per-stream `retain` + `compact` (segment read, seam-anchored
> verify, source-intact). (`file://` reload of a named stream is validated out-of-band
> — it needs a write grant the hermetic `mem://` tier withholds.) These double as the
> [`xap.md`](xap.md) §14.3 battery's journal-layer half.

Positives: `open`/`append`/`read` round-trip — **`append` returns the committed
`[entry]` with `seq`, `prev-hash`, `hash`** (§2.4); genesis entry has
`prev-hash="b3:GENESIS"`, `seq=1` (§4.2); **dense gap-free `seq`** across N appends;
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
`verify-slice` bounded check; optimistic `append` with correct `expect-prev-seq`
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

Negatives / no-surface: **append-only — no `update`/`delete`/`truncate` verb exists**
(no-surface fixture); **cross-tenant read is inexpressible — no read takes a tenant
arg** (no-surface fixture, §4.1); concurrent-append conflict with `expect-prev-seq`
stale → `CXER4604`; `open create=false` on an absent partition → `CXER4601`; re-open
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
      prune-requires-snapshot fixtures, §10) before graduation. `CXER4617–4649` stay
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
   `append` takes a `{actor: … authority: …}` map (extensible for `expect-prev-seq`
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
