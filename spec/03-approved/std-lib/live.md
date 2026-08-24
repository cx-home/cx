# `cx-stdlib/live` — the live-modes pack

```cx
[module-meta name=live tier=D status=current]
```

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14;
campaign #651/#516 stream 3, issue #675). This is the PACK spec the
ruled design `live_modes.md` (L129–L137, ruled (a) 2026-08-05) named in
its §9 spec-edit map ("new live.md — the pack"), bound by delivery.md
§4/§5/§6 per the §10 U1 binding (RULED: U1.1a–U1.15a). Nothing here
amends a ruled contract; this document gives the ruled contracts their
concrete pack surface: signatures, element shapes, error codes, and the
consumption seam. Implementation ledger:
`ledger/partition_I5_stream3_live.md`. (The former thin
catalog entry retired with this graduation — this file carries both the
module-meta row the stdlib-catalog-gate reads and the normative pack
text.)

## §1. The pack

`cx-stdlib/live` is a bundled sub-package (stdlib.md §3 gains its row —
authorized surgery, L129) whose three verbs are the live MODES over the
ONE planar comprehension: `[$live:changes-since]`, `[$live:observe]`,
`[$live:materialize]` — plus the maintenance/read companions
`[$live:advance]` and `[$live:read]` that the poll-shaped substrate
requires (live_modes §1: no push/tail-follow exists at v1; a maintained
fold needs an explicit tick). Ring-1 surface, Ring-2 resolution
(L97/L99). Module qualification dissolves the four name collisions
(`$live:observe` ≠ `$fabric:observe`; L129 grounds).

Every verb takes the comprehension QUOTED (the L99 lowering —
`[cx:expr '<source>']`), and the pipeline is the store-query pipeline
verbatim (store.md §6.2): parse → §7.8 six-point membership (typed
`CXER0120`) → static slice extraction → binding resolution →
authorize-before-execute (per-slice `[$authz:check]` when `$opts`
carries an authz handle; any `[deny]` refuses `CXER4700` and nothing
executes) → admissible L96 rewrites → the sandboxed executor. ONE
deliberate widening vs quoted STORE queries: live sources may be store
sources AND journal sources (`[$store:source]` / `[$journal:source]`)
— the modes are defined over the planar source set, not one store.

**Handle names in the quoted comprehension are FORMAL parameters**
(portable text, no captured environment). Each verb takes an explicit
`$bind` map — formal name (sigil-less) → open handle — and a formal
name left unbound, or bound to a handle of the wrong kind for its
source-ref form, refuses `CXER5071` before anything executes.

## §2. The surface

```cx
# verify-skip — signature sketch; live surface lands with the W1–W3 implementation
[?def changes-since scope=public impure [returns element]
  ($q::element $bind::map $cursor::element $opts={})]   ; → [changes …]
[?def observe       scope=public impure [returns element]
  ($q::element $bind::map $from::element $opts={})]     ; → [live-sub …]
[?def materialize   scope=public impure [returns element]
  ($store::element $q::element $bind::map $name::string $opts={})]
                                                        ; → [materialization …]
[?def advance       scope=public impure [returns element]
  ($ref::element $opts={})]                             ; → [advanced …]
[?def read          scope=public impure [returns element]
  ($ref::element)]                                      ; → [snapshot …]
```

- **`changes-since`** — stateless, one-shot: the ∂ set that carries a
  consumer from `$cursor` to head, plus the new cursor. The cursor is
  an argument and a return value; the server holds nothing.
- **`observe`** — a live ∂ subscription: returns a delivery.md §4
  subscription value (§5 below), client-anchored, closeable,
  `[?with-open]`-composable via `on-close=`.
- **`materialize`** — a named, store-aliased, checkpointed fold in
  `$store` under alias `$name`; maintained incrementally inside the
  incremental sub-fragment, honest-loud outside it (§7).
- **`advance`** — the maintenance tick for a materialization (pull the
  bound sources to head, apply ∂ or recompute loud, checkpoint, CAS
  the alias): the deployment driver is `sched` cadence. Returns
  `[advanced [head-set …] applied=N recomputed=BOOL]`.
- **`read`** — a point-in-time read: `[snapshot [head-set …] ROW…]` —
  the value carries its coordinate (L130's `{at-seq}`, which for a
  multi-source fold IS a head-set). Reads MAY coalesce (the sanctioned
  25ms leading+trailing shape); ∂ streams never do (§6).

## §3. ∂ frames (the L101 vocabulary, verbatim scope)

The result-side ∂ is a sequential edit script over the maintained
relation, positions in FINAL coordinates applied ascending — exactly
the `planar_delta` output vocabulary:

- `[insert pos=N ROW]` · `[retract pos=N]` · `[regroup pos=N ROW]`
  (a γ group's output row replaced in place);
- `[recompute reason="…"]` — the honest marker: what follows is the
  full relation at head re-stated as inserts (the consumer rebuilds);
  never a wrong ∂, never a silent full scan masquerading as
  maintenance.

ROW carries the SAME flat provenance attributes as the recompute
relation (L131 transparency: delta and recompute agree in shape).
Within the incremental sub-fragment (L101 membership: σ/π/⋈/γ under
established predicate totality; τ/λ excluded) the ∂ set is EXACT;
outside it, `changes-since`/`observe` answer the `[recompute]` marker
form — with two universal exactness points that hold for EVERY
comprehension: from the EMPTY cursor the exact ∂ is the full relation
as inserts (this is equivalence-quartet leg 1), and at QUIESCENCE
(cursor = head on every source) the exact ∂ is EMPTY by identity —
positions advance on every source event, so equal coordinates prove ∅,
and a `[recompute]` there would claim ignorance of a provable
empty delta. A query err is a fault, not a finding: it
terminates the ∂ stream loud, delivered as the final frame. Late
bitemporal corrections appear as retroactive retract+insert at their
TX position (contract, not surprise); per-frame redaction counts ride
along (the L119 posture — one instance of stream 20's generalized
visible-count rule, [`erasure_compliance.md`](../std-lib/erasure_compliance.md) §6:
every surface omitting data for erasure reasons reports the omission
count and attribution at the point of omission; a store source's erase
act rides the `store:log` docs plane as its own event, so a lawful shred
is a delivered, attributed change — never a silent disappearance).

## §4. The cursor (head-set; one vocabulary)

THE cursor is a head-set — the profile §5.1 spelling reused, entries
per FORMAL source name:

```cx
# verify-skip — cursor shape (schematic positions)
[head-set [s source="orders" pos=412] [s source="audit" pos=88]]
```

`pos` is the source's own position: the fixed `store:log` per-ref
advance seq (#708) for a store source; the journal seq for a journal
source. A store source is MULTI-STREAM under #708 — the docs plane is
the bare `[s source= pos=]` entry, and each named wire ref is its own
`[s source= ref=NAME pos=]` entry (the profile §5.1 per-stream form on
this cursor; a ref advance is answered as the exact retract+insert of
the ref's content rows). The empty cursor is `[head-set]`. Never a
scalar (L131: a planar source set is a set; no cross-stream total
order exists). A
`boot=` token rides the head-set where substrate retention demands it
(profile §5.1; feed lineage across boots is #764). A cursor entry
naming no source in the comprehension, or a malformed position,
refuses `CXER5072`; resume below a retention boundary refuses
`CXER5073` (the delivery.md `resume-below-retention` class — the
honest refusal, never a silent re-seed).

## §5. The observe handle IS a subscription (delivery §4)

`observe` returns, from day one, a conforming delivery.md §4
subscription value — no bespoke handle kind, no bespoke receive loop
(live_modes §10):

```cx
# verify-skip — handle shape (schematic)
[live-sub id="…" rung=":complete-ordered" sharing="independent"
  flow="pull" retention="window"
  [head-set …] on-close="live-close"]
```

- `rung=` is ALWAYS reported (stream 7's ONE declaration mechanism):
  native store/journal sources declare `:complete-ordered` (the store
  log is per-ref ordered, the journal prefix-consistent); a source
  wired through an adapter reports the ADAPTER's declared rung (§8),
  and a mixed source set reports the WEAKEST member rung.
- Client-anchored resume: `$from` = the last-delivered head-set
  (`from=last+1` doctrine); the server holds no per-observer state.
  Declaring `:monotonic-reads`/`:gapless` in `$opts` engages stream
  7's server-side cursor checks.
- ∂ subscriptions declare `retention=window|full`; `retention=latest`
  on a ∂ stream is the structural `CXER5075` policy refusal — that is
  delivery §6's rendering of "∂ MUST NOT coalesce" (L130).
- **Consumption:** `[?receive from=$sub]` / `[?receive from=$sub
  max=N deadline=D]` / `[?select]` cases / `[?close]` — the U1.12a/
  U1.15a verbs. Stream 3 implements the receive/select/close arms for
  `live-sub` (its verbs' first live consumer — a handle nobody can
  read is a seam with no consumer); #762 generalizes the same arms
  across every delivery.md §4 instance. Receive on a terminated,
  fully-drained subscription refuses `CXER5074`
  (`closed-and-drained`).

## §6. The equivalence quartet (normative; corpus-pinned)

1. A one-time `[?for]` ≡ `changes-since` from the empty cursor.
2. `observe` ≡ repeated `changes-since` driven by source advance.
3. `materialize` ≡ `observe` + a durable fold + an address.
4. Maintained state ≡ recompute — for fragments within the
   incremental sub-fragment, whose membership requires established
   predicate totality (M6/L101: a partial predicate is recompute-only,
   so this leg never faces state-then-err vs whole-comprehension-err
   divergence).

Corpus families: live_modes §8, unabridged.

## §7. Materialize: checkpoint, aggregates, honesty

- The fold value lives in `$store` as a doc; `$name` is its alias.
  **The checkpoint IS the durable cursor** (value-anchored, delivery
  §5): checkpoint doc = `[checkpoint q= [head-set …] ROW…]` (the fold
  value spliced as the rows; `q=` carries the canonical-text hash of
  the quoted comprehension), put-doc-then-alias ordering, alias
  advance by `expect-pos` CAS on the alias's per-name advance
  position, under `CXER1114`. Derived-state posture: a
  missing/unreadable/query-mismatched checkpoint means full replay;
  correctness untouched. `q=` makes re-attachment safe: `materialize`
  on an existing alias RE-ATTACHES (resumes the durable cursor, writes
  nothing) iff the checkpoint carries the same query hash; a name held
  by a different value refuses `CXER1114` — never a silent replace.
  The checkpoint store is a local object-graph store at v1 (a remote
  checkpoint store refuses `CXER1709`; the wire CAS rides the
  stream-4 store profile).
- Per-aggregate maintenance (L130): `sum/count/avg` are
  retract-incremental; `max/min/distinct` force the LOUD group
  recompute (the named boundary). Membership is decided by the L101
  test (`planar_incremental_membership`); outside it, `advance`
  recomputes loud (`recomputed=true`) — and `$opts`
  `maintenance="incremental"` turns that recompute into the typed
  refusal `CXER5076` for callers that must not pay recompute.
- **The retention cover rule extends to registered materializations**
  (L133): history below a registered materialization's cursor may not
  be compacted away (journal.md carries the extension — §9 surgery
  map); client-anchored observers get the honest `CXER5073` refusal
  instead. The registration is JOURNAL-side only, and lives in each
  journal source's OWN store as a doc behind the alias
  `cx-live/materialization/<tenant>[/s/<stream>]/<name>` (the
  fabric-offset pattern: derived-position artifacts as store data);
  `journal:retain` refuses a pruning boundary while a registration
  exists on the stream. Store sources need no registration: a store
  relation is CURRENT state — full replay reads live docs, never
  history.

## §8. The adapter contract (L134/L135 — the owner mandate)

An adapter is an ordinary edge client (fabric §14 posture): foreign
events become canonical CX at the boundary; the adapter is where the
mess stops.

- **The guarantee ladder is a closed atom vocabulary, DECLARED per
  adapter stream and reported on every subscription** (one declaration
  mechanism — stream 7's): `:complete-ordered` (CDC),
  `:coalesced-rescan` (watch — the io.md rung verbatim: overflow means
  rescan, consumers MUST), `:snapshot-diff` (poll). A consumer wiring
  a requirement for a stronger rung than the adapter declares refuses
  `CXER5077` at wiring time — refuse-to-lie, never a silent
  downgrade.
- **Cursor mapping, two directions:** ingest — the adapter's external
  resume token MUST be recoverable from the CX side after a crash
  (offsets live outside the foreign connection; the NATS-bridge
  shape); egress — cumulative ack only after a foreign-side barrier
  (PONG / 2xx). No time-keyed cursors at v1 (#712).
- **Ingest identity:** the three-way lowering ladder is normative
  (JSON → wrapped map element; CX-parseable text → first element
  verbatim; anything else → a lossless named wrapper — never a drop);
  the ingest dedup key is a stream-6 idempotency key over the external
  record's identity tuple (must-not-exist CAS; present-value dedup
  hits); adapters DECLARE which CX notion each nullable SQL column
  maps to (the NULL-duality obligation, collected here); attribution
  is the proven session principal, never claimed.
- **Adapter-is-only-client:** a stream created with a writer principal
  refuses appends from any other — `CXER5078`, enforced at append (a
  checked posture, not a convention; the ladder is void under
  interleaved writers).
- **v1 floor:** poll (`sched` cadence + monotone-key queries +
  content-address dedup + `store:diff` → declares `:snapshot-diff`)
  and watch (fs → `:coalesced-rescan`). CDC is the ladder's top rung,
  spec'd now, arriving additively as a hermetic logical-replication
  adapter (foreign protocol over `net`, no foreign library);
  `db_access` is NOT extended for it at v1.
- **The concrete W4 surface.** The DECLARATION rides stream 7's handle
  floor: `[$journal:open URL TENANT {declare: [adapter-stream stream=
  rung= writer=]}]` (and `[$journal:attach]` alike) — persisted in the
  journal's own store, idempotent re-declaration, a CONFLICTING
  re-declaration refuses `CXER5075`; the rung must be a ladder atom. A
  consumer states a ladder REQUIREMENT through the same `$opts rung=`
  slot the §5 guarantee tokens use — stronger-than-declared refuses
  `CXER5077`. Exclusivity: an append to a declared stream by any
  principal but the declared writer refuses `CXER5078`. The pack ships
  the floor as pack verbs (the same thin-surface architecture as every
  stdlib verb; fabric §14's "written in cx" posture is the
  foreign-protocol adapters', which are separate edge deployables):
  `[$live:adapt-poll URL TENANT STREAM SRC Q WRITER]` — Q is the
  caller's quoted SINGLE-store-source comprehension; every
  `[$live:ingest]` tick pulls the exact ∂ window via `changes-since`
  and appends it atomically as ONE `[ingested from= at= FRAME…]` entry,
  so the stream itself carries the resume token (the NATS-bridge shape)
  and crash re-ingest is impossible by construction;
  `[$live:adapt-watch URL TENANT STREAM DIR WRITER]` — fs events
  between ticks, overflow or the first tick RESCANS (the io.md rung),
  files lower through `[$live:lower]` into one
  `[ingested rescan= [file path= LOWERED]…]` entry per non-empty tick
  (re-delivery under rescan is the declared rung's semantic);
  `[$live:lower RAW]` — the three-way ladder, in the normative order.
  Egress floor: the cumulative-ack-after-barrier contract is pinned on
  fabric's group ack (corpus family; no bespoke egress surface at v1).

## §9. Error codes (band CXER5070–5089; registered §9.6 2026-08-05)

| Code | Name | Meaning |
|---|---|---|
| `CXER5070` | `E_LIVE_NOT_PLANAR` | the argument is not a quoted planar comprehension |
| `CXER5071` | `E_LIVE_SOURCE_UNBOUND` | a formal source name is unbound, or bound to the wrong handle kind |
| `CXER5072` | `E_LIVE_CURSOR_INVALID` | cursor not a head-set / entry names no source / malformed position |
| `CXER5073` | `E_LIVE_RESUME_BELOW_RETENTION` | the delivery.md `resume-below-retention` class |
| `CXER5074` | `E_LIVE_CLOSED_DRAINED` | the delivery.md `closed-and-drained` class |
| `CXER5075` | `E_LIVE_POLICY_INVALID` | the delivery.md `policy-invalid` class (e.g. `retention=latest` on a ∂ stream) |
| `CXER5076` | `E_LIVE_NOT_MAINTAINABLE` | `maintenance="incremental"` demanded outside the incremental sub-fragment |
| `CXER5077` | `E_LIVE_RUNG_INSUFFICIENT` | wiring-time guarantee-ladder refusal |
| `CXER5078` | `E_LIVE_EXCLUSIVE_WRITER` | adapter-stream append by a non-writer principal |

`5079–5089` reserved, unassigned. Reused (never duplicated here):
`CXER0120` planar membership refusal; `CXER4700` authz deny;
`CXER1114` checkpoint alias CAS conflict. THIS table is the band's
per-code registry (the stream-4 precedent: per-code rows live in the
owning spec — core code.md carries only the `CXER0100–0299` CX-code
range); the governance §9.6 band row is updated in the commit that
first implements a code (#717 same-change discipline — W1 shipped
5070–5073 with `changes-since`).

## Identity-epoch membership (audit C9)

ADDITIVE — the pack owns no I1 manifest row and joins no epoch (the
live_modes.md closing section governs; restated here so the pack spec
is self-contained).
