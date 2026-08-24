# Delivery — the stream concept and its axes (U1 concept spec, DRAFT)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: RULED at the letter level 2026-08-10 (U1.1a–U1.7a, U1.9a — [`message_delivery_unification.md`](../../_archived/message_delivery_unification.md) §8): the concept is `stream`; this file is the concept spec. U1.8 re-posed (letter §8). Graduation to 03-approved and the P1–P6 edit packets ([`delivery_edit_packets.md`](../../_archived/delivery_edit_packets.md)) apply as one spec-only change carrying `RULED: U1.1a–U1.7a, U1.9a`.

**What this spec is:** the single definition of CX message delivery —
the concept, its declared axes, the constraint table, the subscription
contract, the mapping of record for every shipped surface, and the
dispatch boundary. It owns no implementation and no new runtime of its
own; it is the store-§2 discipline ("faceted axes — the model is
orthogonal to the substrate") applied to messaging.

**What this spec is NOT:** a broker, a new wire, or a replacement for
any shipped module. journal stays the truth; fabric stays the delivery
layer; bus stays dispatch (§7); the store profile stays the carriage.

---

## §1. The concept

A **stream** is an ordered, append-only sequence of messages.

- **Producers append.** Appending is the only mutation.
- **Consumers hold cursors.** A cursor is a position in a stream;
  consuming is advancing a cursor. The stream never changes because it
  was read.
- **Order is total within a stream and only per-stream across a set of
  streams.** There is no cross-stream total order, ever, at any tier
  (journal §2.1.1, fabric §10, profile §5.1 — one rule, already stated
  three times; this spec is where it is stated once).
- A message is any CX element value; the stream moves it verbatim
  (journal §2.3's posture, generalized).

Everything else — where the bytes live, how long they are retained,
whether consumers compete or fan out, how flow is controlled, whether
appends are attributed — is a **declared axis** (§2), never an
emergent property of which module was used.

## §2. The axes

Five values-carrying axes; two derived properties. Axes are declared
at stream creation or subscription (whichever the axis governs) and
reported on every subscription (§4). Nothing is inferred, promoted, or
silently downgraded — the refuse-to-lie posture of the adapter ladder
(live_modes §6) applies to every axis.

| Axis | Values | Governs | Where it ships today |
|---|---|---|---|
| **substrate** | `mem` · store URL (`mem://`, `file://`, `sqlite://`, `s3://`, `cx-store://`…) · served mount | creation | `[?channel]`; journal §3.1; fabric §13 |
| **retention** | `none` · `latest` · `window` · `full` | creation | channel; fabric transient §6; fabric §13.1 rotation / feed §5.1; journal §4.5 |
| **cursor sharing** | `independent` · `group` (named; sticky-exclusive per stream) | subscription | fabric plain/`observe` vs `group=` (§9, §11) |
| **flow** | `block(N)` (N=0 rendezvous) · `credit(W)` · `pull` | subscription | channel `buffer=`; xsp §5.2; journal `since` |
| **attribution** | `anonymous` · `attributed` (actor/authority/tenant + hash chain) | creation | channel/transient vs journal §2.2 |

**Derived, not declared:** *durability* is the substrate's (a `mem`
stream dies with the process; a `file://`-journal stream survives it;
a served mount's is the daemon's) and *locality* is the substrate's
(`mem` is in-process; a served mount is cross-process; a store URL is
wherever the store is). Declaring either separately from the substrate
would let a stream lie about itself.

**Constraint table** (invalid combinations refuse at creation, typed —
the store-§4 compatibility-class discipline):

- `flow=block` requires `substrate=mem` — blocking a producer across a
  wire IS `credit`; the two are one mechanism at two localities, not
  two mechanisms.
- `attribution=attributed` requires a chain-bearing substrate (a store
  URL); the entry envelope and preimage are journal's, by reference —
  this spec never restates them.
- `retention=none` requires `cursor sharing=group` — with nothing
  retained, an independent late subscriber could only ever see nothing;
  deliver-once is a competing-consumer semantics. (Fan-out over
  ephemeral data is `retention=latest` or `window`.) Equivalently,
  `sharing=independent` requires `retention=latest|window` (RULED:
  U1.11a — `[?channel]` enforces this at declaration, `CXER0217`).
- `retention=latest` defines `read`-style head-peek and makes the
  replay floor one message deep; **coalescing is exactly this point**
  (§6) and is not an operation anywhere else.
- On a fan-out (`independent`) stream the producer NEVER blocks on
  consumers — the window is retention, not flow. A consumer whose
  cursor falls below the window gets the loud typed gap refusal and
  re-seeds (RULED: U1.11a; one refusal class with the wire's
  resume-below-retention, §4).

## §3. The mapping of record

Every shipped surface is one of four things: a **point** (a named
combination of axis values), a **carriage** (a wire that transports
subscriptions), a **layer** (machinery over streams), or **outside**
(a different concept, boundary named).

| Surface | Is | As |
|---|---|---|
| `[?channel]` + `[?send]`/`[?receive]`/`[?subscribe]`/`[?select]`/`[?close]` (code.md §10.4) | point family | **the whole mem column** (RULED: U1.11a): default = the CSP point stream(`mem`, `none`, `group`, `block(N)`, `anonymous`); `sharing=independent retention=window keep=K` = in-process fan-out with a K-deep replay window; `retention=latest` = in-process latest-value fan-out (the coalescing point). One core spelling per mem point; fabric is NOT the answer for in-process fan-out |
| journal stream (journal.md §2.1.1) | point | stream(store URL, `full`\|`window`, `independent` at the read surface, `pull` + local `subscribe` tail-follow (RULED: U1.13a), `attributed`) — the truth point |
| fabric durable group subscription (fabric §9) | point | the journal point + `sharing=group` + `flow=credit` — the same truth, served (already normative: "the durable plane is not a second log") |
| fabric transient channel (fabric §6, §12) | point | stream(`mem`\|served, `latest`, `independent`, `credit`, `anonymous`); `[$fabric:read]` is the head-peek `retention=latest` defines |
| store change feed (profile §5) | carriage | the profile's transport of stream subscriptions (∂ frames, credit, head-set resume); "the journal's push surface" (journal §6.1) — never a fifth mechanism |
| fabric (the package) | layer | subscription serving, groups+offsets, DLQ, request-reply, adapters — delivery machinery OVER streams; it "invents nothing below itself" (fabric §2) and this spec is the named floor it stands on |
| live modes (`cx-stdlib/live`, ruled L129–L137) | modes | producers/consumers of derived (∂) streams; `observe` returns a §4 subscription; `changes-since` is its pull form; `materialize`'s checkpoint is a durable group-of-one cursor (§5) |
| io watch (io.md §3.10) | point (adapter-class source) | stream(`mem`, `none`, one consumer, `pull`) at rung `:coalesced-rescan`; `watch-next` is a module spelling of receive — harmonization stub, U1.8 |
| http SSE topics (http.md §3.6.1) | carriage | HTTP egress of a subscription; the XAP coalescer is a `retention=latest` read at this edge (§6) |
| bus (`cx-stdlib/bus`) | **outside** | dispatch, not delivery — §7 |
| an actor mailbox (dissolved) | point | stream(store URL, `window`\|`full`, `group`[of one], `pull`, `attributed`) — no new primitive. The lifecycle side is U2 (worker_lifecycle.md, RULED — executed and archived; the shipped module is [`std-lib/supervise.md`](../std-lib/supervise.md)): `[?monitor]` = a lifecycle subscription; supervision = a stdlib module over worker+monitor+sched. **Scale posture (RULED: U2.3a): workers are pool-scale, entities are stream-scale** — state lives in streams (fold = state), compute rides bounded pools consuming groups; the named trigger for a green-process runtime is a real workload needing >100k concurrent stateful in-process actors that cannot partition onto streams+pool |

## §4. The subscription contract

One contract; every subscribing surface returns an instance. A
subscription is an element value carrying, at minimum:

```cx
# verify-skip — schematic contract shape (ellipsis placeholders), not standalone CX
[subscription id="…"                       ; stable within its scope
  rung=":complete-ordered"                 ; the declared guarantee rung —
                                           ;   stream 7's ONE declaration
                                           ;   mechanism (live_modes §6),
                                           ;   reported ALWAYS, never assumed
  sharing="independent"|"group" group="…"? ; the cursor-sharing axis value
  flow="block"|"credit"|"pull" window=W?   ; the flow axis value
  head=…                                   ; source head at subscribe time
                                           ;   (fabric already ships head= — #605)
  cursor=…                                 ; the §5 cursor form
  on-close="…"]                            ; closeable (SAP §5.1) — [?with-open]-able
```

Instances: fabric's `[fabric-sub]`, the profile's `[feed-sub]`, stream
3's observe handle, the io watch handle, `[?subscribe]` on a fan-out
channel (U1.11a), `[$journal:subscribe]` (U1.13a), `[?monitor]`'s
worker-lifecycle subscription (U2.1a), and the anonymous subscription
a `[?channel]` implies for its receivers. Existing shapes conform by
gaining attributes additively (T2 at most); none is replaced.

**Consumption verbs.** `[?receive from=X]` / `[?try-receive]` accept
any subscription; `[?receive from=X max=N deadline=D]` is the batched
form (RULED: U1.12a — the ONE batch spelling; `[$fabric:receive]`
cuts over to it); `[?select]`'s `[case [from X $msg H]]` accepts any
mix of subscriptions plus `[timeout]` plus the send case
`[case [to CH EXPR H]]` (RULED: U1.15a); `[?close]` closes any.
Readiness is part of the contract (a subscription can answer "is a
message available without blocking" — how, is each substrate's
business). Group/durable consumers additionally `ack` cumulatively
(fabric §19.5, unchanged, module-level — `none`/`latest` points have
nothing to ack and refuse it typed).

**One option vocabulary (normative).** Every subscribing surface
spells the same option the same way: `from=` (resume anchor),
`window=` (credit window), `group=` (cursor sharing), `rung=`
(guarantee declaration), `keep=` (retention window depth). A surface
inventing a synonym for one of these is a spec defect.

**One refusal-class map (normative).** Three refusal classes, named
once; each surface reports its own band's code, mapped here:

| Class | Meaning | Surface codes |
|---|---|---|
| `resume-below-retention` | the cursor names history the substrate no longer holds; re-seed | profile `CXER5020`; channel `CXER0218` (STREAM_GAP); journal `CXER4617` |
| `closed-and-drained` | the stream ended and everything retained was delivered | channel `CXER0200`; each module's own terminal per its spec |
| `policy-invalid` | the declared axis combination is not a point | channel `CXER0217`; fabric `CXER4931`; profile `CXER5019` |

**Producer speech-acts stay distinct** — they are the producer verbs
of this one concept, not three mechanisms:

| Verb | Semantics | Point it belongs to |
|---|---|---|
| `send` | handoff into a flow-controlled `mem` stream; may block; no receipt | the channel point |
| `publish`/`append` | attributed commit; returns the entry/receipt; CAS via `expect-pos` | attributed points |
| `emit` | latest-write; no receipt, no history | `retention=latest` points |

## §5. The cursor doctrine

**THE cursor is a per-stream position.** Across a *set* of streams the
cursor is a **head-set** — the map stream → position (profile §5.1;
live modes L131) — because no cross-stream total order exists (§1).
In a context where exactly one stream is in scope (a fabric per-stream
subscription, a channel), the bare position is the **degenerate
single-stream form**, selected by context — default-elision, the
store-§3 discipline, not dual-accept. Boot/retention tokens ride the
cursor where the substrate's retention demands them (profile §5.1);
resume below a retention boundary refuses loudly (the `:gapless`-class
honest refusal — one rule, already shipped in three places, stated
once here).

Cursor anchoring is the shipped three-way split (live_modes §5,
generalized): client-anchored (the consumer keeps it), server-anchored
(a named group offset — store data, fabric §9), or value-anchored (a
checkpoint that IS the cursor — materialize). Nothing else exists.

## §6. Retention, and why coalescing is not flow control

`retention` declares the replay floor: `none` (deliver-once; nothing
to replay), `latest` (one message deep), `window` (a hot window — a
rotation boundary, a boot lifetime), `full`. Flow control (`block`/
`credit`/`pull`) never drops or merges messages — it only paces them.

**Coalescing — keeping only the newest value under load — is the
`retention=latest` point, not a flow model.** That is why it is "sound
only for last-write-wins snapshots" (live_modes §1): it is a retention
semantics, honest only where the stream declared it. Consequences,
now structural instead of footnotes:

- ∂ streams declare `retention=window|full`; coalescing is not an
  operation on those points — the ruled "∂ streams MUST NOT coalesce"
  (L130) falls out of the axes instead of standing beside them.
- The XAP render coalescer (25ms leading+trailing) is a
  `retention=latest` read at the SSE edge — sanctioned, declared,
  unchanged in behavior.
- fabric's transient plane "drop-oldest is inherent, not a policy"
  (fabric §19.2) is this same fact, in this vocabulary.

## §7. The dispatch boundary (bus)

**Dispatch is not delivery.** `cx-stdlib/bus` delivers each published
message to its matching subscribers *synchronously, deterministically,
in a defined order, on the caller's own stack* (N-BUS-1). There is no
queue, no cursor, no retention, no flow control — nothing for this
spec's axes to govern. That is not a gap; it is bus's identity: the
deterministic ordered drain is the primitive XAP's commit cascade
composes with the journal append (bus §2.4, xap §14), and replay
determinism is why async delivery is a MUST-NOT there (bus §4.1,
fabric §8 "bus is untouched").

The boundary, normatively: **a component needs dispatch when the
caller must observe every handler's completion before proceeding
(a transaction shape); it needs a stream when production and
consumption are decoupled in time, pace, or place.** The topic-pattern
vocabulary (bus §2.2 — atom, terminal-`.*` glob, head name, predicate
fn) is shared across both by reference, exactly as fabric §7 already
does; it is a *selection* vocabulary, not a delivery semantics.

## §8. Conformance sketch (on graduation)

- **Axis declaration + refusal lanes:** each constraint-table row has
  a typed-refusal fixture (block-over-wire, attributed-over-mem,
  retention-none-with-independent, ack-on-latest).
- **Contract conformance per instance:** fabric-sub, feed-sub, observe
  handle, watch handle each satisfy §4 (attrs present, closeable,
  receive/select-consumable) — one shared fixture family, run per
  surface (the G13 parity-family shape).
- **Cross-mechanism select:** one `[?select]` over {channel, fabric
  subscription, timeout} — the fixture that is impossible today.
- **Cursor doctrine:** degenerate-form round-trip (scalar ↔
  single-entry head-set agree); resume-below-boundary refusal parity
  across journal/feed/fabric (same class, three substrates).
- **Coalescing structural pair:** burst of N on `retention=window` →
  N frames (the shipped ∂ discriminator, cited); burst of N on
  `retention=latest` → head-peek sees only the last.
- **Dispatch boundary negative:** the bus surface refuses subscription
  -contract consumption (`[?receive]` on a bus handle is a typed
  error, pinned — the boundary is checkable, not prose).

## §9. Before / after (worked syntax pairs; the "before" shapes are schematic)

**One wait over mixed sources** (U1.2a/U1.5a):

```cx
[; BEFORE — no cross-mechanism wait: one forwarder worker per source + a mux channel ]
[?channel name=mux buffer=64]
[?worker name=fw-chan [; loop: [?receive from=work]  -> [?send … to=mux] ]]
[?worker name=fw-fab  [; loop: [$fabric:receive $cmds {max: 10, deadline: 1000}] -> mux ]]
[?worker name=fw-live [; loop: stream-3 handle read -> mux ]]
[; then consume mux; three shutdown paths, an extra hop ]

[; AFTER — one select ]
[?select
  [case [from work    $item [handle-work $item]]]
  [case [from $cmds   $e    [?do [handle-cmd $e] [$fabric:ack $cmds $e@seq]]]]
  [case [from $deltas $d    [apply-delta $d]]]
  [case [timeout 30s        [heartbeat]]]]
```

**In-process fan-out** (U1.11a):

```cx
# verify-skip — [?subscribe] is spec'd ruled surface; ships at #762 (un-skip there)
[; BEFORE — an embedded fabric just for local fan-out ]
[?let [= $f  [$fabric:open "mem://"]]
      [= $s1 [$fabric:subscribe $f "ticks" :tick.*]]
      [= $s2 [$fabric:subscribe $f "ticks" :tick.*]]
  [$fabric:publish $f "ticks" [do :tick [t v=1]]]]

[; AFTER — a channel that declares the point ]
[?channel name=ticks sharing=independent retention=window keep=64]
[?let [= $s1 [?subscribe from=ticks]]
      [= $s2 [?subscribe from=ticks]]
  [?send [tick v=1] to=ticks]      [; never blocks on consumers ]
  [?receive from=$s1]              [; -> [tick v=1] ]
  [?receive from=$s2]]             [; -> [tick v=1] — independent cursors ]

[; a laggard >64 behind is told, never silently starved: ]
[; [?receive from=$slow] -> [err code=cx-err:CXER0218 …floor…] — re-subscribe to re-seed ]
```

**Latest-value fan-out — the declared coalescing point** (U1.7a/U1.11a):

```cx
[; BEFORE — fabric transient: [$fabric:emit $f "gauge" $v] / [$fabric:read $f "gauge"] ]
[; AFTER ]
[?channel name=gauge sharing=independent retention=latest]
[; producer at 1kHz; a slow consumer's [?receive] sees the newest value —
   intermediates dropped BY DECLARATION, not by accident ]
```

**Batched receive** (U1.12a):

```cx
[$fabric:receive $sub {max: 100, deadline: 500}]   [; BEFORE (retired) ]
[?receive from=$sub max=100 deadline=500ms]        [; AFTER — one verb everywhere ]
```

**Local journal tail-follow** (U1.13a):

```cx
[; BEFORE — poll: [$journal:since $j [+ $last 1] "orders"], sleep 250ms, repeat ]
[; AFTER ]
[?let [= $sub [$journal:subscribe $j {stream: "orders"}]]
  [; replay-then-live; then: ]
  [apply [?receive from=$sub]]]
```

**Time-addressed resume** (U1.14a):

```cx
[; BEFORE — hunt for "where was midnight?" by slicing and scanning ]
[; AFTER ]
[?let [= $pos [$journal:seq-at $j 2026-08-01T00:00:00Z {stream: "orders"}]]
  [$journal:since $j [+ $pos 1] "orders"]]
```

**Send-readiness** (U1.15a):

```cx
[; BEFORE — a [?try-send]/CXER0201 busy-loop around a full pool ]
[; AFTER ]
[?select
  [case [to pool $job  [ok]]]
  [case [from ctrl $c  [handle $c]]]
  [case [timeout 5s    [shed-load]]]]
```

**Worker death observable** (U2.1a):

```cx
# verify-skip — [?monitor] is spec'd ruled surface; ships at #762 (un-skip there)
[; BEFORE — [?wait-for worker=$h] is a blocking join: one joiner worker per watched worker ]
[; AFTER — one supervisor, one wait ]
[?let [= $m1 [?monitor [?worker-handle name=ingest]]]
      [= $m2 [?monitor [?worker-handle name=render]]]
  [?select
    [case [from $m1  $ev [?match $ev [case [panicked $e] [restart-ingest]] [else [ok]]]]]
    [case [from $m2  $ev [?match $ev [case [panicked $e] [restart-render]] [else [ok]]]]]
    [case [from ctrl $c  [shutdown]]]]]
[; monitoring an already-dead worker delivers its terminal event immediately — no race ]
```

**The lazy hint** (U1.1a; #763, stream 2 executes):

```cx
# verify-skip — the BEFORE line deliberately shows the retired [stream] spelling (tombstoned by #763; the AFTER line is the live surface)
[?for [in $x $src] [stream] [yield [f $x]]]   [; BEFORE ]
[?for [in $x $src] [lazy]   [yield [f $x]]]   [; AFTER ]
```

**Filesystem watch joins the wait** (U1.8a):

```cx
[; BEFORE — a thread parked in [$io:watch-next $w 500] ]
[; AFTER ]
[?select
  [case [from $w   $chg [ingest $chg]]]
  [case [from ctrl $c   [stop]]]]
```

## Identity-epoch membership (audit C9)

**ADDITIVE + RESPEC — no I1 manifest row, no epoch.** This spec names
shipped semantics and generalizes consumer-surface operands; it moves
no wire byte, no Tier-1/Tier-2 address, no frozen preimage. The two
wire-moving doors U1 poses (full-surface cutover U1.2b; head-set-
everywhere U1.6b) are NOT part of this draft and carry their own epoch
sketch in the letter (U1.10) should the owner select them.
