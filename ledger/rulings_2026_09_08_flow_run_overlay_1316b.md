# RULED: 1316-b1, 1316-b2, 1316-b5 — the run overlay is a VALUE keyed by the
# node id; three marks emit and five are registered; §4.17 gains a step
# re-attempt row

Date: 2026-09-08. Issue: cx-home/cx-private#1316 (Part 2, the run overlay).
Campaign: v0.18.0 close-out (#1354), Lane 2 (the #1265 flow ladder).
Letters drafted by worker B on the issue at 22:50Z; **ruled by the owner +
Fable at 2026-09-08 19:30 / 19:35 / 20:00 ET** and posted on the issue.
`1316-b3` (`cx flow watch` is READ-ONLY) and `1316-b4` (the overlay rides
the existing host `GET /stream`) are ruled in the same pass and are
recorded with their own implementations; this file covers the three the
`diagram` module lands.

## Ruled — 1316-b1: the run overlay is an OVERLAY VALUE keyed by the node id

`[flow-overlay [node id=<the 1316-a id> status=… elapsed=… holder=…
children=…]…]` is a pure projection of the `[flow-run …]` record. The
drawer — the web client, the studio, or one small compose verb for a
pasteable file — applies it to the base picture. The picture stays ONE
(§4.17), a transition paints ONE row over the feed, and Part 3's fleet
overlay is the same shape over N runs: one mechanism for both overlays,
addressed by the id `1316-a` minted for exactly this.

**Refused:** (a) a second renderer — deletes "a flow has ONE diagram" and
re-sends a picture per transition; (c) an opt on `flow-diagram` — makes the
canonical picture depend on an opt and forces the golden corpus to pin two
artifacts under one id.

## Ruled — 1316-b2: emit what the record bears; register the rest

The overlay's rule table carries one row per §4.17 run-overlay mark
(eight), so the completeness gate diffs it against the spec sentence for
SET EQUALITY. A mark that cannot be projected carries `pending=` with the
reason naming its landing — the same discipline as Part 1's construct
table.

**Refused:** (b) empty values for unreachable marks — makes "this run has
no quorum step" and "this build cannot draw quorum" indistinguishable, the
vacuous-green class in the picture itself; (c) status+elapsed only — a
silent scope cut.

### Implementation note: the ruling's COUNT was 5/3; the measurement is 3/5

The ruling states "Five rows emit now — status per step, elapsed since
activation, `map` child-run counts, the `[conflict]` on an uncompensatable
step, paused/cancelled across the whole picture." That count came from
worker B's own letter, and the letter was wrong on two of the five. The
DISCIPLINE the ruling settled is what governs, and applying it honestly
gives three emitting and five pending. Both corrections are measured:

- **`elapsed`** — the record's construct row carries no activation instant
  at all. `f--row-with` (`stdlib/flow.cx`) is a CLOSED attribute
  allow-list: `name`, `status`, `pivot`, `ord`, `reason`, `attempt`,
  `wait`, `fired-at`, plus a `map`'s five counters. There is nothing to
  subtract an activation instant from, so elapsed-since-activation is not a
  projection of the record. Making it one changes the PINNED fold identity
  (§2.2/§4.11: replay is byte-identical), which is a ruling and not the
  worker's: drafted as **`1316-c1`** on the issue.
- **`run-state`** — `:paused` and `:cancelled` are not in the record's
  closed status set (`f--atom`), and `pause`, `resume` and `cancel` are
  named landings with **no wave assigned** (`flow.md` §4.21 and the verb
  table). A run cannot BE paused today, so a mark saying it is could never
  fire.

Three marks therefore emit — a construct's `status=`, a `map`'s five
child-run counts (§4.12), and the `[conflict …]` carried on an
uncompensatable construct's row (§4.8) — and five are registered with the
reason naming what each waits on. This is not a scope cut: it is the
register the ruling installed, applied to what the record actually holds.

## Ruled — 1316-b5: §4.17's construct table gains a step re-attempt row

| `attempts=` / `every=` (on a step) | a re-attempt chip on the node — `attempts=N every=D` — so the step's worst case is readable without leaving the picture, by the rationale the `until` row already states (RULED: 1316-b5) |

The flow subject's rule table gains the matching row and chip; the
set-equality completeness gate then requires it. Drawn at every rung like
every other row — in practice beside `by=` and `deadline=`, its peers,
which is what "not rung-dependent" means here.

**Refused:** (b) undrawn — a bounded-retry step indistinguishable from a
plain one hides the one number an operator asks about a slow step;
(c) `full`-only — the first rung-dependent row in the table, with no
justification the other rows lack.

## Where this is pinned

- `stdlib/diagram.cx` §12.1 (the b5 row), §12.4 (the chip), §12.9 (the
  overlay: its sealed table, the record join, the walk, the entry point).
- `conformance/stdlib/diagram.cxd` — `diagram-022` (13 rows, 6 pending),
  `diagram-026` (the chip, recorded bytes), `diagram-027` (8 marks, 5
  pending), `diagram-028` (the projection over a nested document, recorded
  bytes), `diagram-029` (the property: every overlay row names a node the
  base picture drew, and a `[seq]` lane takes none), `diagram-030` (the
  three refusals, including a record that pinned another document).
- `spec/03-approved/std-lib/flow.md` §4.17 — the construct table's new row.
