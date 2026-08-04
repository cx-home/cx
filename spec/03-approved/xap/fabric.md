# fabric — platform-level eventing: durable + transient planes over XSP

**Status:** **03-approved** (graduated by owner ruling 2026-07-22 — the
implementation ships against this text: v1 P0–P3 complete incl. the served
tier, coord migration, and adapters; DLQ #543, request-reply #544, and the
NATS bridge #547 merged; 36 conformance cases in `fabric.cxd`; the #518
umbrella is closed; the last §18 residue — xsp §5 adoption — landed as #560
(2026-07-22). History: issue #518, owner decisions 2026-07-18; enterprise-scope +
full-story recharter 2026-07-20; promoted from 01-new with the §19 design
decisions by owner ruling 2026-07-20).
**Coordinates:** own bundled package **`cx-fabric`** (the `cx-xap` shape —
[`xap.md`](xap.md) §18), composing
[`journal.md`](../std-lib/journal.md) (durable plane),
[`bus.md`](../std-lib/bus.md) §2.2 (subscription vocabulary, by
reference), [`xsp.md`](xsp.md) +
[`xap_identity_model.md`](xap_identity_model.md)
(transport + mutual DID auth), and the store-serve precedent
(`cxstore_service_tier_phase2.md`) for the served tier. Multi-writer
consensus is **deferred by owner decision** — #521. Downstream demand:
the first downstream adopter (#518).

**Design goal (owner, 2026-07-20):** fabric is not internal plumbing — it is
the **enterprise-reusable platform messaging component**: the thing a system
standardizing on cx runs *instead of* NATS/JetStream, with a stated path to
the capabilities enterprises expect (adapters, clustering) so cx is never
pigeonholed below the standard enterprise integration patterns.

---

## 1 — Problem

cx has excellent *intra-process* eventing — `cx-stdlib/bus` is synchronous,
deterministic, ordered (N-BUS-1) — and a durable, hash-chained, replayable
log — `cx-stdlib/journal`, already openable over remote store backends. What
it lacks is a platform component that delivers events **between** processes,
hosts, and organizations. Today the only options are polling `journal-since`
over a remote store, or HTTP/SSE hand-wiring per application.

Downstream systems that standardize on cx need
enterprise integration patterns — pub/sub across services, durable consumers
with offsets, ephemeral coordination — and without a cx-native answer they
would put a foreign broker (NATS, Kafka) on their truth path, losing
canonical form, capability gating, and hash-chain verifiability at exactly
the boundary that matters most.

## 2 — The full cx story (the shape with NATS/JetStream removed)

The stack is layered so each enterprise expectation has exactly one home.
fabric is the delivery layer; it invents nothing below itself.

| Enterprise expectation | cx layer | Where specified |
|---|---|---|
| Object/blob + KV persistence, content-addressed, multi-backend (file/sqlite/s3), served multi-tenant | **store** (+ `store-serve`) | store specs; `cxstore_service_tier_phase2.md` |
| Durable ordered event log — the *truth*: append-only, hash-chained, attributed, replayable, tenant-partitioned (the Kafka-topic / JetStream-stream slot) | **journal** (rides store) | [`journal.md`](../std-lib/journal.md) |
| In-process eventing: synchronous, deterministic, ordered | **bus** | [`bus.md`](../std-lib/bus.md) |
| **Delivery between processes/hosts/orgs**: pub/sub, push, consumer groups + offsets, ephemeral coordination (the core-NATS + JetStream-consumer slot) | **fabric** (this spec) | here |
| Wire framing + streaming transport | **xsp** | [`xsp.md`](xsp.md) |
| Identity, mutual auth, capability & delegation | **did/vc/authz/session** + XSP-AUTH | [`xap_identity_model.md`](xap_identity_model.md) |
| Scheduling / delayed & recurring work | **sched** | `sched.md` |
| The experience/orchestration layer riding all of it | **cx-xap** | [`xap.md`](xap.md) |

The one-sentence pitch: **the log is the broker's spine, and cx already has
a better log** — fabric adds the delivery, grouping, and serving that turn
journal into platform messaging, with canonical CX as the payload everywhere
(EIP's "Canonical Data Model" — the hardest integration pattern — is the
platform's *foundation*, not an aspiration).

## 3 — Broker-world mapping (NATS / JetStream / Kafka → cx)

For any adopter explaining the migration:

| Broker concept | cx realization |
|---|---|
| core NATS pub/sub (fire-and-forget, fan-out-now) | fabric **transient plane** (§6) |
| JetStream stream / Kafka topic | **journal stream** — plus hash-chain verifiability and attribution the broker versions lack |
| JetStream durable consumer / Kafka consumer group | fabric **consumer group** with store-hosted offsets (§9) |
| JetStream ephemeral/push consumer | fabric subscription (push over XSP) (§11) |
| NATS request-reply | XSP `request`/`reply` frames over a fabric channel (§12.1 call conventions) |
| JetStream KV / ObjectStore | **store** — content-addressed, which the broker bolt-ons are not |
| NATS nkeys/JWT auth, Kafka ACLs | **DID proof-of-control** (mutual, channel-bound) + `observe`/`publish`/`consume` capability grants (§11) |
| Kafka partitions / NATS clustering | per-stream sequencing today (§10); clustering **staged** — #521 (§18) |
| Schema registry | CX canonical form + `.cxs` shapes — in the substrate, not a sidecar |
| Broker as message owner | **rejected** (§16): journal is the truth; fabric nodes are stateless-above-the-log delivery |

What cx is *better* at, day one: verifiable history (hash chain +
provenance), real mutual identity at the transport, capability-scoped
authorization, one canonical data model end to end, and truth that survives
the loss of every delivery node. What the broker world has that cx stages
deliberately: clustering (#521), ecosystem client breadth (§14 adapters +
the C-ABI SDK path), and operational maturity that only field time buys.

## 4 — Enterprise integration patterns: the coverage guarantee

The no-pigeonhole check. Every standard EIP capability an enterprise will
ask about, with its cx home and status — **nothing on this list is "not
possible"; everything is shipped, v1, a documented convention, or a named
staged item**:

| Pattern (EIP) | cx realization | Status |
|---|---|---|
| Canonical Data Model | CX canonical form — the substrate itself | shipped (core) |
| Message Channel | durable stream (journal) / transient channel | fabric v1 |
| Publish–Subscribe Channel | `subscribe` on either plane, fan-out | fabric v1 |
| Point-to-Point / Competing Consumers | consumer group — one consumer per event per group | fabric v1 |
| Durable Subscriber | group offset persisted in store (§9) | fabric v1 |
| Event-Driven Consumer | push delivery over the attached XSP channel | fabric v1 |
| Polling Consumer | `journal-since` (shipped today); pull iteration on a subscription | shipped / v1 |
| Content-Based Router | predicate-fn subscription (bus §2.2 vocabulary) | fabric v1 |
| Message Filter | pattern vocabulary: atom / terminal-`.*` glob / head / predicate | fabric v1 |
| Wire Tap | `observe` grant — read-only subscription, no offset writes | fabric v1 |
| Guaranteed Delivery | journal commit precedes delivery; at-least-once redelivery from offsets | fabric v1 |
| Idempotent Receiver | deterministic folds (N-CORE-1) — the platform posture for duplicates | shipped |
| Transactional Client | commit *is* the journal append; offset-commit-after-process | fabric v1 |
| Request–Reply | XSP `request`/`reply` frames over a fabric channel — call conventions §12.1 | **v1** (#544) |
| Correlation Id / Return Address | XSP `stream-id` + frame/event attrs | v1 |
| Message Expiration | transient = latest-wins by construction; durable = journal retention policy | v1 / journal |
| Claim Check | payload in store, content address in the event — content addressing makes this trivial | shipped (convention) |
| Dead Letter Channel | a DLQ is an ordinary stream + a redelivery-limit policy on the group (§9.1) | **v1** (#543) |
| Splitter / Aggregator / Process Manager | application folds over streams — language-level | shipped |
| Scheduled / Delayed Message | `sched` + fabric publish | convention v1 |
| Messaging Bridge | protocol **adapters** as edge clients (§14) | **soon** (§18) |
| Message History / Audit Trail | hash-chained journal + provenance attestation | shipped — *exceeds* the pattern |

## 5 — Positioning, packaging & the name (owner decision #518-1; naming ruling 2026-07-20)

fabric is **its own bundled package** — `[?lib 'cx-fabric']` — registered
beside `cx-xap`, **not** a `cx-stdlib` module. It *composes* journal + bus +
xsp, and the platform's settled rule is that composition layers ship as
their own capability-gated bundled subsystem above stdlib
([`xap.md`](xap.md) §18 positioning; std-lib README §3.1
anti-duplication). The primitives stay where they are; fabric adds no
storage, digest, ordering, or crypto mechanism of its own.

**Why not `cx-broker`:** a broker *owns* messages in flight — lose the
broker, lose undelivered truth. fabric's load-bearing property (§16) is the
opposite: the journal is the truth and fabric is delivery above it; losing
every fabric node loses no committed event. Naming it "broker" would promise
the semantics the design rejects. "fabric" names the connective layer.
(Considered and recorded 2026-07-20.)

Effectful and opt-in, never ambient: every fabric verb that reaches net or
store is capability-gated (§11). A thin catalog entry in
`spec/03-approved/std-lib/` arrives with graduation, per the
`xap.md`/`xsp-auth.md` pattern.

## 6 — One surface, two planes

fabric exposes **one subscribe/emit surface** with an explicit **durability
axis**; a subscription or emission names its plane, and nothing is silently
promoted or demoted between them.

| Plane | Semantics | Rides on |
|---|---|---|
| **durable** | committed events: ordered (per stream), attributed, hash-chained, replayable; consumer groups + offsets; **at-least-once** | `journal` (which rides `store`) |
| **transient** | ephemeral events: latest-wins per channel, fan-out-now to live subscribers; no history, no replay, no ack; **best-effort** | in-memory channels (the generalization of xap's Tier-2 coord pattern — §12) |

The durable plane is **not a second log**: a durable fabric stream *is* a
journal stream. fabric adds delivery (push over XSP instead of poll), group
consumption, and the serve tier — the truth stays in journal, with journal's
hash chain, attribution, and replay untouched.

## 7 — Subscription vocabulary (shared with bus, by reference)

The pattern language is **normatively `bus.md` §2.2** — one vocabulary
in-process and across the platform:

- **topic atom** — `:order.placed`, equality match;
- **prefix glob** — a terminal `.*` segment (`:order.*` matches `:order` and
  every `:order.…`), per the #397 dotted-atom ruling — the earlier
  trailing-`-` workaround is retired;
- **head name** — a string like `'metric'`, matching the element head;
- **predicate fn** — an arity-1 boolean `[?fn ($m) …]`, full structural
  power.

Glob + predicate are the only wildcard/structural mechanisms; no regex.
fabric adds **no** pattern forms of its own; any future extension lands in
`bus.md` §2.2 first and fabric inherits it.

## 8 — Bus is untouched (hard constraint)

N-BUS-1 stays the whole contract of `cx-stdlib/bus`: synchronous,
deterministic, ordered, single-owner — *"asynchronous, fire-and-forget, or
nondeterministically-ordered delivery is not part of this module and MUST
NOT be added."* fabric is a **sibling with honestly different promises**
(async, networked, at-least-once / best-effort), never a mode flag on bus. A
silent delivery-guarantee change is a silent-wrong-answer class; the two
components stay separate precisely so each contract stays readable.

## 9 — Consumer groups & offsets (owner decision #518-2: self-hosting)

A consumer-group offset is a **derived-position artifact** — the same class
as journal's signed snapshot `(state, at-seq, anchor-hash, signature)`,
which already persists to a snapshot-namespaced store key (journal.md
§2.8/§3.7). Offsets therefore live as **ordinary store data under a
fabric-namespaced key convention** — `journal-since` remains the underlying
catch-up primitive; **no new persistence surface exists or is needed**.

- Offset key shape (working sketch): `fabric/<stream>/<group>/offset` →
  `[offset seq=N at=…]`, written through the same store handle the journal
  rides. Tenancy inherits journal's hard structural partition (§4.1).
- **At-least-once** falls out: deliver → process → commit offset; a crash
  between process and commit redelivers. Exactly-once is **out of scope**
  (§16) — cx folds are deterministic and idempotent by construction
  (N-CORE-1), which is the platform's answer to duplicates.
- Within a group, a stream's events go to one consumer at a time (the
  single-sequencer node assigns; §10). Independent groups consume
  independently — that is the whole point of group-scoped offsets.

### 9.1 — Dead-letter + redelivery policy (#543; closes the §4 "convention — soon" row)

A poison event — one that crashes its consumer on every delivery — blocks a
group's tail forever under cumulative ack. The answer stays inside the
platform's shapes: **a DLQ is an ordinary stream, and the policy is group
state**, the same derived-artifact class as the offset (§9). No per-message
queue semantics, no visibility timeouts, no new persistence surface.

- **Declaration** rides the subscribe opts of a *group* subscription:
  `{group: "g", max-deliveries: N, dlq: "orders.dlq"}` — the two policy keys
  come **together or not at all** (a redelivery limit without a destination
  would discard truth; a destination without a limit never fires), `N ≥ 1`,
  and the DLQ stream must differ from the source stream (no self-loop).
  Violations refuse with `CXER4931 E_FABRIC_POLICY`.
- **The policy is group state**, persisted beside the offset
  (`fabric/<tenant>/<stream>/<group>/policy`, the §9 doc-backed-alias
  pattern): a later subscription in the group **inherits** it (opts omitted),
  an *identical* redeclaration is idempotent, a *conflicting* one refuses
  loudly (`CXER4931`) — group siblings never run divergent policies silently.
- **Attempt accounting keys on the head of the uncommitted tail** — under
  cumulative ack the head (the first pattern-matching event above the
  committed offset) is the only event that can block the group. A delivery
  record (`…/<group>/delivery`: `seq` + `attempts`) persists at delivery
  time, **before** the consumer sees the event: a resume that redelivers the
  same head increments it; a head that moved (the ack came) resets it. One
  count per subscription lifetime — a delivery attempt is a
  subscription-resume that redelivers, exactly the §19.3 redelivery unit.
- **On exhaustion** (`attempts` would exceed `max-deliveries`): the head is
  **not delivered**. fabric publishes a
  `[dead-letter stream=… seq=… group=… attempts=…]` envelope carrying the
  original event as its child to the DLQ stream (attribution: actor = the
  group, authority = `fabric:dlq` — the policy fired, not a session), commits
  the group offset through the dead-lettered seq, clears the delivery
  record, and delivery continues with the next event. The original entry
  stays in the source journal untouched — **nothing is lost**; the
  dead-letter event is delivery metadata plus a pointer (`stream`/`seq`),
  and the DLQ is consumable/replayable/policy-guardable like any stream.
- **Served tier**: the same accounting runs in the delivery pump and the
  §19.3 failover path via the same helpers (never a second implementation).
  Declaring a policy with `dlq=D` additionally requires the declaring
  principal to hold **`publish` on `D`** (§11) — a consume-only principal
  cannot write into a stream through a policy side door. The dead-letter
  publish itself is the server's own act at fire time.
- **The manual form stays first-class**: a consumer that *catches* a failure
  can always publish its own dead-letter and ack past it with shipped verbs
  — the policy automates exactly that composition, nothing more.

## 10 — Ordering (owner decision #518-3: single-sequencer first)

Ordering authority is **per stream and single-sequencer**, consistent with
every mechanism already in the platform: journal's per-stream commit lock
(no global cross-stream `seq`, by contract), bus's single-owner synchronous
total order, and the **single-node** store-serve tier ("stops there unless
multi-node demand is proven").

- The **fabric-serve node is the sequencer** for the streams it mounts:
  publishes to a durable stream serialize through its journal append (the
  per-stream commit lock *is* the sequencing).
- There is **no global cross-stream order** and fabric MUST NOT fabricate
  one; cross-stream coordination is the caller's explicit choreography,
  exactly as journal §4.3 states.
- Consensus / replicated sequencers / partitioned brokers are **deferred to
  #521**, triggered by proven multi-node demand from a fabric consumer —
  and they are a **roadmap item, not a rejection** (§18). Nothing in this
  design precludes that path: the sequencer is behind the serve seam, not
  in the client surface.

## 11 — Transport, identity, capability

**Transport is XSP** ([`xsp.md`](xsp.md)): fabric events
ride `event` frames; subscriptions and group management ride
`request`/`reply`; `error` carries the failure channel. Payloads are CX
`data-bin` — canonical form end to end. fabric is XSP's first consumer
larger than xap coordination, and its duty cycle is the demand signal for
the xsp.md §5 session-layer items (reconnect-resume, backpressure, heartbeat
— adopted via #560, with per-stream-priority multiplexing still deferred) —
fabric adopts rather than inventing parallel mechanisms.

**Identity is the graduated identity model**
([`xap_identity_model.md`](xap_identity_model.md)):
XSP-AUTH mutual proof of control at attach (N-IDENT-1/2), per-request proofs
on the live channel, anonymous floor for observe-only postures where the
deployment allows it.

**Capability model** — three independently grantable actions per
stream/channel scope, deny-by-default:

| Action | Grants |
|---|---|
| `observe` | read-only inspection: subscribe without consumption side effects (no offset writes) — the monitoring/dashboard/wire-tap grant |
| `publish` | emit onto a stream/channel |
| `consume` | group membership + offset commit on a durable stream |

`observe` exists precisely so inspection surfaces never need `consume`; a
grant of one action never implies another. Tenant partition is structural
(journal §4.1), not a filter.

## 12 — Transient plane & the xap coord migration (owner decision #518-4)

The transient plane **generalizes** xap's Tier-2 coordination channel:
named channels (`coord/<feature>/<tenant>`-style keys generalize to
`<scope>/<name>`), **latest-wins** per channel, fan-out-now to live XSP
subscribers, non-journaled, out-of-audit, off the PEP-gated cascade —
authorized once at wiring time (observe/publish grants), not per message.

**xap migrates onto it.** `[$xap:coord-publish]` / `[$xap:coord-read]` were
a single-slot in-memory map on the xap runtime (`rt.coord`) — an
implementation shortcut of what `xap.md` §19.1 already specifies ("carried
over `cx-stdlib/bus` as a topic distinct from the enforcement bus").
**Landed (P2, issue #531):** the coord verbs ride the fabric transient plane
— a lazily-opened per-runtime embedded fabric over a `mem://` journal,
channel keys tenant-first per §19.4 — with **observable behavior unchanged**
(latest-wins read, empty-if-unpublished, never in `[$xap:state]`, the same
wiring-time authority posture), and `rt.coord` is retired. One
transient-channel mechanism on the platform, not two.

### 12.1 — Request–reply call conventions (#544; the §3 NATS request-reply slot)

Request–reply is a **call**, not truth: it rides the transient plane —
never journaled, never replayed, no offsets, no ack — on ordinary
`<tenant>/<scope>/<name>` channel keys, over the native XSP
`request`/`reply` frame types (§11), which is exactly what those frame
types exist for.

- `[$fabric:respond $f CHANNEL FN]` → `[fabric-responder …]` registers an
  **arity-1 callable** answering the channel. Registration is
  **sticky-exclusive per channel** (the §19.3 posture, not a queue-group —
  competing responders arrive with demand): a second respond while the
  holder lives refuses with `CXER4933 E_FABRIC_RESPONDER`; the served tier
  frees the channel on the holder's connection death. The callable **never
  travels** — it stays in the registering process; only the channel
  registration crosses the wire.
- `[$fabric:request $f CHANNEL VALUE {deadline: MS}]` → the reply value — a
  **blocking, deadline-bounded call** (default 10 000 ms). A channel with no
  live responder refuses immediately with
  `CXER4932 E_FABRIC_NO_RESPONDER`; an expired deadline is
  `CXER4934 E_FABRIC_REQUEST_TIMEOUT`; a responder whose callable returns an
  err value propagates that err to the requester **verbatim** (the failure
  channel, composition honesty).
- `[$fabric:serve $responder {deadline: MS, max: N}]` → int (requests
  served) — the remote responder's pump: **pull stays the primitive**
  (§19.1). Pushed `request` frames buffer client-side exactly as pushed
  events do; `serve` drains the buffer, applies the callable, sends the
  `reply`/`error` frames, and reports how many calls it answered. A
  responder process's main loop is a `serve` loop.
- **Embedded tier**: `request` applies the registered callable
  **synchronously** — the degenerate but fully working form (§13),
  deterministic and trivially testable; `serve` returns 0 by construction
  (embedded calls are answered at the call site).
- **Served tier**: the requester's `request` verb routes to the responder's
  connection as a pushed `request` frame under a **server-assigned
  correlation stream-id**; the responder's `reply`/`error` frame routes back
  to the blocked requester by that id (Correlation Id = the XSP stream-id,
  §4). The server holds a pending-call table with an expiry sweep
  (`[limits request-timeout-ms=…]`, default 30 000) and **never blocks the
  sequencer on a responder**; a responder's death fails its pending calls
  loudly (`CXER4932`), never silently. Grants (§11): `request` needs
  `publish` on the channel, `respond` needs `consume`.
- **Deliberately not in v1** (recorded, not rejected): the envelope +
  explicit-reply primitive (`receive` request envelopes, reply by handle —
  caller-controlled concurrency) can layer *under* the callable convention
  if a deployment's duty cycle demands it; queue-grouped competing responders
  arrive the same way. The callable form is the call *convention* — the
  contract a caller programs against either way.

## 13 — Serve tier (the store-serve gradient)

fabric follows the **embedded → served** gradient exactly as store does
(`store` → `store-serve`):

- **Embedded**: a process opens fabric in-proc; durable streams via its own
  journal/store handles; transient channels process-local. No daemon, no
  network — the degenerate but fully working form.
- **Served**: a `fabric-serve` daemon (single-node, §10) mounts named
  fabrics, accepts XSP attaches, sequences durable publishes, fans out
  transient traffic, and hosts group assignment. It reuses the store-serve
  operational posture wholesale: authN providers (static token / JWT / DID
  first-class / OIDC), roles bundling permission classes over §11's actions,
  config as an attr-exact-validated CX doc, deny-by-default with only
  health/capabilities unauthenticated.

Deployment sits **alongside store-serve**, and a deployment MAY point
fabric-serve at the same store its journal rides — self-hosting all the way
down (§9).

### 13.1 — Served tier as implemented (P1, issue #531)

The subcommand landed as **`cx fabric-serve --config <path>`** (symmetric
with store-serve, per §19.6), configured by an attr-exact-validated
`fabric.service.cx` document (sample: `tooling/cxfabric/`): `[bind]`,
optional `[health]` (unauthenticated health/ready listener, probe-compatible
with `cx store-health`), optional `[tls]`, `[identity did= seed-env=]` (the
seed must re-derive the declared DID or boot refuses), `[policy]`
(mutual | floor), `[limits pending-window= liveness-ms= request-timeout-ms=]`,
`[fabrics]`
(mounts keyed by tenant — the attach's tenant routes structurally, §19.4),
and `[principals]`/`[anonymous]` carrying the §11 grants
(action = observe|publish|consume, scope = name or `*`, deny-by-default).

**Wire.** Raw XSP frames over tcp/tls — never HTTP (HTTP/SSE reach is the
§19.7 adapter). The attach handshake rides binary stream-0 frames exactly as
the shipped `$xsp:auth-*` calculus emits them (M1→M2 challenge, M3→M4 via the
session layer's attach verification — no second implementation). Everything
after establishment rides **text frames carrying canonical CX**: the data-bin
binary payload canonicalizes general element trees (single-scalar children
collapse to attributes, atoms stringify — the element-as-map duality its
handshake readers are built for), which would silently rewrite a published
event; the text canonical form is the lossless canonical form, so events,
entries, receipts, and refusals ride it verbatim. A binary verb payload
refuses loudly.

**Verbs** (request payload → reply, stream-id echoed): `publish` →
`[receipt seq stream]`; `publish-batch` (negotiated, xsp §5 `publish-batch`
feature, #607) → `[receipt-batch stream first last count]` — N `[event …]`
children append in ONE verb turn under one delivery pass; **validation is
atomic** (grant, every event shape, and the attribution vocabulary check
before the first append — a refusal appends nothing, and the client
isolates a poison event by retrying as pipelined singles); an append-time
FAULT mid-batch replies the fault err extended with `landed=`/`first=` so
the client folds exactly what the stream holds; `expect-prev-seq` does not
compose with a batch (single-append optimistic concurrency — use
`publish`); `subscribe`/`observe` → `[fabric-sub id …]`
(subscribe additionally carries the §9.1 policy attrs
`max-deliveries=`/`dlq=` on group subscriptions; both carry `head=` —
the stream's current head seq, `0` for an empty stream — so a replay
consumer can stop exactly at the head instead of probing for an empty
batch; the embedded tier's `[fabric-sub]` carries the same attr, #605); `ack` → null (cumulative,
§19.5); `emit` → null; `read` → latest value or `()` absence; `respond` →
`[fabric-responder id …]` (§12.1 registration); `request` → the responder's
reply value. Matching `[entry …]` elements push as `event` frames whose
stream-id is the subscription id; transient fan-out pushes
`[channel-value …]`; §12.1 calls push as `request` frames to the responder
connection (correlation stream-id server-assigned) and its `reply`/`error`
frames route back to the blocked requester; `ping` answers `pong` and
refreshes the liveness window.

**Attribution is server-constructed**: actor = the channel's session
principal, authority = `fabric:publish`. The client attribution vocabulary is
closed — `expect-prev-seq` forwards (optimistic concurrency is legitimately
the caller's); a claimed actor equal to the session principal is tolerated,
a different one refuses with the principal-mismatch error (the identity
model's demotion rule); any other key refuses loudly rather than being
silently dropped by journal.

**Mount rotation** (`rotate` → `[rotated streams sealed segments target]`,
#640): seals every stream of the connection's tenant mount at its own
boundary (`head_s − keep-n`) and swaps the mount onto a fresh
next-generation hot store — the served-tier surface for journal §4.11
rotation, and the mechanism a retention policy drives. Discipline:

- an explicit **`rotate` grant** is required (deny-by-default — no other
  action implies it), and `keep-n=` must be a positive per-stream window;
- the **committed floor** is enforced before anything is copied: if any
  consumer group — persisted offset **or** live subscription — is committed
  below a stream's boundary, the rotation refuses with
  `E_FABRIC_ROTATE_BLOCKED` naming the group, because sealing there would
  strand that group's uncommitted tail in the cold segment. Consumers ack,
  then the rotation succeeds;
- **publishes refuse with `E_FABRIC_ROTATING`** while a rotation runs (an
  append landing mid-copy would vanish on the swap) — acks and reads are
  unaffected. One rotation per mount at a time;
- the heavy tail copy runs **off the sequencer lock**; the reply is deferred
  until the swap commits, and the old journal handle closes after it (the
  sealed segment at rest);
- consumer state (group offsets, policies, delivery records) **carries** into
  the new store, so groups keep their offsets across a rotation;
- the hot window becomes the **replay horizon**: a group subscribing after a
  rotation resumes at the seam, not genesis. Sealed history stays discoverable
  through the segment index the rotation writes (journal §4.11), not through
  the live mount;
- the hot store must be a substrate the daemon owns (`file://`, `mem://`); a
  **served** (`cx-store://`) journal store refuses — rotating it means
  creating a mount on the store daemon, which is that daemon's lifecycle.

**Retention policy** (`[retention sweep-ms=… [stream name=… hot=N
archive=… hold=…] …]`, #636) is the *policy* layer over rotation: it names,
per stream, the hot window the daemon keeps live and what becomes of what
falls out of it, and it drives the SAME rotation path an operator's
`[rotate]` drives — every rotation invariant (committed floor, publish
refusal, off-lock copy, carried offsets) holds identically.

- `hot=N` is the live entry window (the primary cost dial —
  `bench/xap/SIZING.md` §1: RSS, boot, and per-op cost all scale with it).
  A stream past its window is rotated by the **retention sweeper**, with no
  operator action; `sweep-ms=0` keeps the policy declarative and leaves
  rotation to `[rotate]`.
- `name="*"` is the default policy; an exact stream name overrides it.
- `archive=<store url>` preserves the sealed predecessor under
  `<archive>/<tenant>/<segment>`; `archive="none"` drops it. **The chain
  anchor is retained in the segment index either way** — an archived segment
  is rehydratable, a dropped one is still provably accounted for. Nothing is
  ever silently lost.
- `hold=true` is the **legal hold**: it suspends archival *and* truncation.
  Because a rotation moves every stream of a mount, a hold anywhere on the
  mount suspends the whole sweep (loudly, naming the held stream) rather than
  sealing around it — a held stream that needs an independently-rotating
  neighbour belongs on its own mount.
- A sweep that a lagging consumer group blocks is **not an error**: it logs
  and retries next tick, because the consumer is expected to catch up.
- The hot window is therefore also the **replay horizon** — a consumer
  subscribing after a rotation resumes at the seam.

**Delivery discipline**: the pending window (§19.2) bounds grouped
subscriptions only — ungrouped/observe subscriptions have no offsets to
catch up from, so replay is unbounded (the socket, not the log, is their
buffer). Group failover (§19.3) triggers on connection death or a missed
liveness window when a live sibling waits (no competitor, no churn); a
deposed-for-staleness holder keeps its subscription but is never handed the
stream straight back; the successor reloads the committed offset and
redelivers exactly the uncommitted tail. Publishes sequence under one server
lock (§10); socket writes never happen under it — each connection has an
outbound queue drained by its own writer thread, so a wedged consumer wedges
only itself.

## 14 — Adapters & foreign clients (the enterprise reach story)

An **adapter is an ordinary fabric client at the edge** — a process holding
`publish`/`consume` grants that translates a foreign protocol onto fabric
streams and channels. **No core seam exists or is needed**: adapters use the
same surface as any consumer, which is why they can arrive incrementally
without destabilizing the core. Written in cx (dogfood rule), deployed like
any edge service.

- **Ingress value**: foreign events become **canonical CX at the boundary**
  — everything inward is canonical-form, capability-gated, hash-chain
  verifiable. The adapter is where the enterprise's mess stops.
- **Planned adapters** (order set by demand, §18): **NATS bridge** (the
  legacy-migration path — subjects ↔ streams/channels), **HTTP/SSE webhook**
  (the universal adapter: webhook-in → publish; subscription → SSE/webhook
  push), **Kafka bridge** (topic/partition ↔ stream; offset mapping),
  **MQTT** (IoT ingress), **AMQP 1.0** (legacy enterprise ESB seams).
- **Native client SDKs**: the **libcx C ABI** is the SDK path — the same
  route store already ships for Python/Go/Rust reaches fabric's embedded
  and remote client surface. A non-cx enterprise service consumes fabric
  through a binding or through an adapter; both are supported postures.

## 15 — Surface (verbs firmed during 02-working; shipped as specified)

```
[$fabric:open URL|CFG]              -> [fabric …] handle (embedded or remote)
[$fabric:publish  $f STREAM EVENT]  -> [receipt seq=N]          ; durable
[$fabric:subscribe $f STREAM PAT opts{group=…, from=…,
                   max-deliveries=…, dlq=…}]    -> subscription  ; §9.1 policy
[$fabric:receive  $sub opts{max=…, deadline=…}] -> [events …]   ; batched pull
[$fabric:ack      $sub SEQ]         -> null   ; cumulative commit through SEQ
[$fabric:emit     $f CHANNEL VALUE] -> null                     ; transient
[$fabric:read     $f CHANNEL]       -> latest value | [empty]   ; transient
[$fabric:observe  $f STREAM|CHANNEL PAT] -> subscription        ; no offsets
[$fabric:respond  $f CHANNEL FN]    -> [fabric-responder …]     ; §12.1
[$fabric:request  $f CHANNEL VALUE opts{deadline=…}] -> reply value
[$fabric:serve    $resp opts{deadline=…, max=…}] -> int         ; responder pump
[$fabric:close    $f]               -> null
```

Pull (`receive`) is the primitive on both tiers; the served tier
additionally pushes `event` frames on the attached XSP channel under the
bounded pending window (§19.1–.2). Exact signatures firm up in P0.

## 16 — What fabric is NOT

- **Not a broker on the truth path.** Journal is the truth; the durable
  plane is journal *plus delivery*. Losing every fabric node loses no
  committed event.
- **No global cross-stream order** (§10). Ever, at any tier.
- **No exactly-once.** At-least-once + deterministic/idempotent folds is the
  platform posture (§9).
- **No per-message deletion / queue semantics.** Retention is journal's
  (append-only, hash-chained); a "queue" is a stream + a group offset; a
  DLQ is a stream + a redelivery-limit policy (§9.1).
- **No new pattern language, persistence surface, or crypto** (§7, §9, §11).
- **Not a change to bus** (§8).

## 17 — Evidence & conformance plan (sketch)

- the first downstream adopter retired NATS for bus + journal behind a transport port;
  fabric is the port's target. Committed evidence (#518/#519 offers):
  worker-pool fan-out findings, durable-consumer cursor conventions,
  conformance-fixture contributions (100s–1000s of simulated entity
  lifecycles before real traffic). Per the owner's 2026-07-20 pace ruling,
  the §19 decisions were made by design — field evidence **refines** them
  (batch sizing, window defaults) but never gates progress.
- The two-plane split matches what the broker world converged on
  independently (core NATS + JetStream) and what xap needed internally
  (committed cascade vs Tier-2 coord) — evidence it is the stable point in
  this design space.
- Conformance venue at graduation: `conformance/stdlib/fabric.cxd` for the
  offline-deterministic surface (pattern matching, offset arithmetic,
  plane-separation refusals, capability denials), V engine tests for
  live-channel lanes (XSP delivery, group redelivery-after-crash), following
  the xsp-auth.cxd + xap_host_auth_test.v split.

## 18 — Roadmap: now / soon / later (owner scoping 2026-07-20)

**NOW — fabric v1 (DELIVERED — implemented against this spec; retained as
the scoping record):**
- embedded + single-node served tiers (§13); both planes (§6);
- consumer groups + store-hosted offsets, at-least-once (§9);
- `observe`/`publish`/`consume` grants over XSP-AUTH identity (§11);
- the xap coord migration (§12);
- conformance per §17.

**SOON — the enterprise-gap fills (named, scheduled, not vague):**
- **first adapters** (§14): HTTP/SSE webhook **landed** (P3, §19.7); the
  NATS bridge (the legacy-migration seam) **landed** (#547, §19.7);
  Kafka/MQTT/AMQP follow demand;
- **DLQ + redelivery-policy conventions** — **landed** (#543, §9.1);
- **request–reply call conventions** over `request`/`reply` frames —
  **landed** (#544, §12.1);
- **reconnect-resume / heartbeat / backpressure** adoption as xsp.md §5
  items land — fabric is their demand signal;
- **client SDK reachability** via the libcx C-ABI bindings (§14).

**LATER — demand-gated:**
- **clustering / replicated sequencer / partitioned streams** — #521,
  behind the serve seam (§10);
- cross-org federation semantics beyond XSP mutual auth (arrives with xap
  federation work);
- exactly-once: permanently out — idempotent folds are the answer (§16).

## 19 — Design decisions (made by design at the 02-working promotion, owner 2026-07-20; field evidence refines, never blocks)

1. **Receive loop: pull is the primitive; push callbacks are the served
   tier's delivery.** v1 ships `[$fabric:receive $sub opts{max=…,
   deadline=…}]` — a blocking, batched pull (deterministic, trivially
   testable, wraps into any worker-pool shape). The served tier's XSP push
   *is* the event-driven form (frames arrive on the attached channel); a
   local callback-registration convenience can layer over either later
   without a contract change. downstream worker-pool findings refine batch
   sizing and defaults, not the shape.
2. **Backpressure (xsp.md §5.2 — adopted, #560):** transient channels
   are latest-wins by construction — a slow subscriber simply observes
   fewer intermediate values (drop-oldest is inherent, not a policy);
   durable subscriptions get a **bounded pending window** (default:
   64 undelivered frames) — at the bound the server stops pushing and the
   consumer catches up from the journal by offset (the log is the buffer;
   **a slow consumer never blocks a publisher**). Since the §5 adoption
   this IS the xsp credit window: `[subscribe … window=W]` narrows it
   (clamped to the server ceiling), cumulative ack is the replenishment,
   and windowed observe subscriptions replenish via `credit` frames
   (auto-granted by the client as the app consumes). Features + limits are
   negotiated post-attach via the `session` verb (`[fabric-session
   features=… liveness-ms=…]`, xsp.md §5.0).
3. **Group assignment: sticky exclusive per stream per group, failover on
   death.** Within a group, one consumer owns a stream at a time (this is
   what per-stream ordering + §9 already imply); parallelism is across
   streams, never within one. A consumer that misses its liveness window
   (heartbeat-or-deadline, served tier) loses the assignment; the successor
   resumes from the last committed offset — the redelivery window is
   exactly the uncommitted tail, no separate visibility-timeout machinery.
4. **Transient-channel scoping: `<tenant>/<scope>/<name>`.** Tenant is the
   leading, structural segment (mirroring journal §4.1 — a partition, not a
   filter); `<scope>/<name>` generalizes xap's `coord/<feature>` shape.
5. **Offset commit is cumulative.** `[$fabric:ack $sub SEQ]` commits
   *through* SEQ (everything at-or-below is consumed) — Kafka-style; batch
   commit is therefore the same call, and per-event ack is the degenerate
   batch. No per-message ack bookkeeping.
6. **`fabric-serve` is a `cx` subcommand** riding the store-serve daemon
   plumbing (config loading, authN providers, health/ready, observability)
   — not a separate binary. Landed as `cx fabric-serve` (P1, §13.1),
   symmetric with store-serve.
7. **First adapter: HTTP/SSE webhook** (universal, zero foreign-protocol
   dependency, pure cx over stdlib http; webhook-in → publish, subscription
   → SSE stream / webhook push; auth posture = the store-serve provider set,
   §13). The NATS bridge follows for the legacy-migration seam (§18).
   **Landed (P3, issue #531):** `tooling/cxfabric/webhook-adapter.cx` — an
   ordinary edge client on the REMOTE tier of the one client surface
   (`[$fabric:open "xsp://…"]` dial + XSP-AUTH attach + verbs over the
   served wire, realizing §15's "embedded or remote"; net-capability-gated
   at the dial). Webhook-in publishes the body VERBATIM as the event
   (canonical CX at the boundary — JSON converts to its wrapped map
   element; subscribers' topic-atom patterns match the event's own atom);
   SSE out fans matching entries to route topics on the serve pub/sub
   path; webhook push POSTs `[batch …]` bodies to a callback and commits
   the cumulative ack only after a 2xx — a failing callback stops the ack,
   the §19.2 window stops the push, and the uncommitted tail redelivers.
   The door is bearer-token first (the static-token posture).
   **Landed (SOON item, issue #547): the NATS bridge** —
   `tooling/cxfabric/nats-bridge.cx`, the legacy-migration seam (§14/§18),
   again an ordinary edge client on the remote tier. It speaks the client
   subset of the NATS text protocol itself over `cx-stdlib/net`
   (INFO/CONNECT/PING/PONG/SUB/PUB/MSG — no NATS library, so the suite
   stays hermetic: the engine test drives it against an in-test mock
   server). Ingress: a SUB per `[in subject=… stream=…]` route; each MSG
   becomes canonical CX at the boundary (JSON → wrapped map element,
   CX-parseable → verbatim element, else a lossless `[nats-raw]` wrapper)
   and publishes onto the stream — a failed publish ends the session
   loudly, never a silent drop. Egress: a durable group subscription per
   `[out …]` route; events render per `fmt` (`body="event"` default ships
   just the event — legacy consumers don't know `[entry …]` envelopes;
   `body="entry"` opts into the attributed envelope) and PUB to the
   subject; after each batch the bridge PINGs and commits the cumulative
   ack only on the server's PONG (the at-least-once barrier, cognate to
   webhook push's ack-after-2xx). Reconnect re-dials and re-SUBs; offsets
   live outside the NATS connection, so egress resumes at the committed
   offset. Reply-to is ignored (request-reply is fabric-native, §12.1);
   TLS-required NATS servers are out of v1.

## 19.1 — Implementation staging (v1; each phase lands complete — no stubs)

| Phase | Ships | Depends on |
|---|---|---|
| **P0 — embedded core** | `cx-fabric` bundled package (registration beside cx-xap); both planes in-proc: durable publish/subscribe/receive/ack over journal+store (offsets per §9, cumulative ack per §19.5), transient emit/read over `<tenant>/<scope>/<name>` channels (§19.4); `observe`/`publish`/`consume` capability guards; `conformance/stdlib/fabric.cxd` (offline lanes: pattern vocabulary, plane separation, offset arithmetic, denial lanes) | nothing new — journal/store/bus/authz as shipped |
| **P1 — served tier** | `fabric-serve` subcommand (§19.6): XSP attach via XSP-AUTH, single-sequencer publish, push delivery + bounded pending window (§19.2), group assignment/failover (§19.3); live-channel V engine tests (delivery, redelivery-after-crash, denial) | P0; store-serve plumbing; xsp/xsp-auth as shipped |
| **P2 — xap coord migration** | `[$xap:coord-publish/read]` re-wired onto the transient plane, `rt.coord` retired, observable behavior unchanged (existing coord tests stay green as the regression gate) | P0 |
| **P3 — first adapter** | HTTP/SSE webhook adapter (§19.7) as an edge cx program + its conformance/engine lanes | P1 |

The SOON items of §18 followed v1 against real use: DLQ/redelivery-policy
conventions landed as §9.1 (#543), request-reply call conventions as §12.1
(#544), the NATS bridge as §19.7 (#547), and the xsp.md §5 session layer
(reconnect-resume / heartbeat / credit backpressure) was specified and
adopted as #560 (2026-07-22) — the served tier is its reference
implementation. Kafka/MQTT/AMQP adapters follow demand.

## 20 — Deferred (scoped, not vague)

- **Multi-writer ordering beyond the single sequencer** — #521 (consensus /
  replicated sequencer / partitioned brokers), on proven multi-node demand;
  a LATER roadmap item (§18), not a rejection.
- **Exactly-once delivery** — rejected as a goal; idempotent folds are the
  answer (§16).
- **Cross-org federation semantics beyond XSP mutual auth** — arrives with
  xap federation work, not here.
- **Reconnect-resume / heartbeat / multiplexing** — owned by xsp.md §5;
  fabric adopts, never forks.

---

**References:** [`bus.md`](../std-lib/bus.md) (§2.2 vocabulary,
§2.4 N-BUS-1) · [`journal.md`](../std-lib/journal.md) (§2.1.1
per-stream order, §2.8/§3.7 snapshot precedent, §4.1 tenancy, §4.3
cross-stream) · [`xsp.md`](xsp.md) (frames, §5 deferred)
· [`xap_identity_model.md`](xap_identity_model.md)
(XSP-AUTH, N-IDENT-1…4) · [`xap.md`](xap.md) (§18
packaging precedent, §19.1 coord channel) ·
[`cxstore_service_tier_phase2.md`](../misc/cxstore_service_tier_phase2.md)
(serve-tier posture) · issues #518 (charter + owner decisions), #521
(deferred consensus → LATER roadmap).
