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

---

# RULED: 1316-b3 — `cx flow watch` is READ-ONLY; a watcher has no liveness

Ruled by the owner + Fable at 2026-09-08 19:45 ET on worker B's 22:50Z
question 3 = **(b)**.

`watch` subscribes to the run's stream (`[$journal:subscribe]` +
`[?receive]`), paints each transition onto the picture as a `1316-b1`
overlay row, **arms NO timers and performs NO effect**. A parked run stays
parked while watched; a watcher that sees a due deadline SAYS so on the
picture and never fires it.

**Spec text (freeze edit carries the token):** `flow.md` §4.15 gains, beside
the runner table, the sentence that a watcher is an OBSERVER — it holds no
liveness, arms no timer and performs no effect; whether a deadline fires
never depends on who is looking. The runner table stays at three rows.

**Refused:** (a) a watcher that services timers — an observer becomes a
runner and a fleet console watching 200 runs would be 200 accidental
runners; (c) polling `status` — loses transitions between ticks.

## Measured, on a genuinely parked run

A finished run would prove nothing, so the probe parks one: a step whose act
fails with `attempts=2` unspent is `:retrying` with an `every=1h` wait — its
next move is a durable timer an hour out.

```
before  run :running   step :retrying      stream entries 2
watch   [flow-watch [flow-overlay … [node … status=:retrying]]]
after   run :running   step :retrying      stream entries 2
```

The watcher appended nothing and did not fire the wait. Pinned as
`diagram-031`.

## One delivery decision that is NOT the ruling's, and why

`watch` ANSWERS a value that the harness prints, exactly as `serve` does; it
does not stream a line per paint. This is a capability fact, not a
preference: the only output path a PROGRAM has is
`[$io:write-line [$env:stdout] …]`, which refuses `CXER0271` without
`--allow-write` — a grant that, in its own message, covers the whole
filesystem (per-path scoping is #1061). Making a read-only observer demand a
filesystem write grant in order to print would contradict the posture this
very ruling establishes. The live-paint face is therefore the XAP host's
`GET /stream` (`1316-b4`), and the CLI answers when it stops. The gap —
that a CLI program has no ungranted line-out — is drafted as **`1316-c2`**
on the issue.

---

# RULED: 1316-b4 — the run overlay rides the EXISTING host `GET /stream`

Ruled by the owner + Fable at 2026-09-08 19:55 ET, RECASTING worker B's
question 4, which was mis-premised in both directions:

1. §4.17 does not say "rides the host's `/stream` face" — it says "live via
   an SSE feed from `status`". The `/stream`-face wording is
   `design/789/scaling_ladder_2026_09_05.md`, a design doc.
2. `GET /stream` **exists** on the XAP host
   (`vcx/platform/stdlib_xap_host_notd_wasm32_emcc.v:48` header, `:872`
   handler) — a held-open SSE feed fanning one named `event: <feature>`
   frame per admitted act to every subscriber. The grep that concluded
   "does not exist" ran over `stdlib_xap.v`, the wrong file.

**Ruled (a):** on each run transition the host fans out ONE named frame on
the existing `/stream`, carrying the run id and that transition's `1316-b1`
overlay rows. The event name is pinned by the implementer's fixture and MUST
NOT collide with a feature name. The #647 discipline applies unchanged: the
broadcast is a CHANGE SIGNAL (run id, node id, status); anything
principal-bearing is read from `status` under the subscriber's own proof.

**Spec text (landed here):** §4.17's overlay sentence gains the XAP-face
carriage, the change-signal discipline, and the pointer to `1316-b3` for the
non-host case.

## Implementation is SEQUENCED BEHIND #1313's `1313-c`, and this is measured

The ruling's parenthetical is "the host (which embeds the runner — RULED:
1313-c)". **`1313-c` is ruled and NOT landed**, and its own text says so: it
"lands in RULED pieces: (i) re-arm + safepoint + boot fixture; (ii)
`schedule` + `intent`; (iii) `webhook` + `fold`", and it records that "today
`xap_host` parks in a bare sleep and no timer can fire".

Measured at this commit: `vcx/platform/stdlib_xap_host_notd_wasm32_emcc.v`
contains **no occurrence of `flow`** at all, and across `vcx/platform/` the
only file naming `cx-stdlib/flow` is `ring2_register.v` (the act seam). So
there is no run inside the host, and therefore no transition to fan out.

**Nothing frame-shaped is landed here on purpose.** A pusher wired to no
caller is a seam with no live consumer — a partial implementation by this
repo's own rule — and it would be worse than nothing, because the fixture
pinning the event name would pass while the mechanism it names never fires.
`1316-b4`'s code lands with, or immediately after, `1313-c` piece (ii),
which is what first puts a run inside the host. Recorded on #1354 rather
than filed as a new issue: the dependency is an open, ruled item.
