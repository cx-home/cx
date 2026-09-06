# Ruling 2026-09-06 — #1265 W1-E, the snapshot-anchor interval (PE-1)

**Status: RULED (a) under the standing letter-acceptance rule**, recorded
before the change per the #832 process rule. Ruling id `1265-PE-1`. Open to
an owner veto.

**What raised it.** W1-E's implementer measured the anchor interval for the
first time (`ledger/bench_flow_w1e_anchored_reader_2026_09_06.md`) and found
the shipped default of 64 about 2x off the best interval at a few hundred
entries. It left 64 in place on the stated ground that "§4.11 names it
(RULED: 1265-PC-2)".

**That ground is false, and checking it is what makes this rulable now.**
`flow.md` §4.11 says the record is read "from the last snapshot" and names
NO interval. `1265-PC-2` says "snapshots taken at an interval" and names no
number either. A grep for `snapshot-every` across `spec/03-approved/`
returns nothing. The number 64 exists in exactly one place: `f--snap-default`
in `stdlib/flow.cx`. It is an implementation default, not a shipped or ruled
surface, and no ruling is contradicted by moving it.

**The evidence.**

| Sweep | Result |
|---|---|
| READ half alone, run length 10 000 | 6.8 ms at interval 8, 7.5 at 16, 9.3 at 32, 11.6 at 64, 16.7 at 128, 26.6 at 256 — monotone in the interval, no bowl (read cost is O(interval); the write half is what makes a bowl) |
| BOTH halves, a 200-item `map` whose parent stream is 403 entries | 81.4 s anchoring off; 27.1 at 4, **18.0 at 8**, 18.7 at 16, 23.7 at 32, 35.3 at 64, 51.0 at 128, 82.7 at 256 |

The bowl bottoms at 8-16 and the square root of 403 is about 20. The
analytic model behind it is not in doubt: reading costs one anchor
verification plus the tail, O(interval); writing an anchor costs the
journal's `1..at-seq` prefix walk amortized over the interval,
O(length / interval); the sum is minimized at c times the square root of the
length. A FIXED interval is therefore not merely mistuned, it is
asymptotically wrong — at 10^6 entries an interval of 64 walks about 15 000
prefix entries per advance, and §9's flat-latency row measures exactly that
length.

## PE-1 — the default interval — RULED: (a)

- **(a) RULED — the default becomes `max(16, ceil(sqrt(head)))`, recomputed
  on each advance from the run's head position.** `opts.snapshot-every`
  still pins a constant when a caller supplies one, and `0` still turns
  anchoring off and restores the genesis fold exactly. The interval is a
  pure function of the head position, so replay stays byte-identical and the
  fold identity is untouched — anchor PLACEMENT is not semantically
  observable (that is what `flow-045`'s anchored = genesis = anchoring-off
  equivalence pins); only the COUNT of anchor entries in the journal
  changes, and it changes deterministically.
  **What it DELETES:** the fixed constant 64, and with it the property the
  old comment claimed outright — "an ordinary short run never takes an
  anchor at all". The floor of 16 keeps the weaker, sufficient version: a
  run of 16 transitions or fewer still anchors nothing, which covers the
  make-replacement rung's ten-step flows. A run of 20 transitions now takes
  one anchor, which is not a cost worth protecting.
  **Why the floor, and why no cap.** Without a floor, the square root of 10
  is 3 and every short run pays anchor writes for nothing. A cap would
  reintroduce the error being fixed: the square-root rule is self-limiting
  by construction (read and amortized-write cost stay equal), so a ceiling
  invented without data is the same mistake 64 was.
  **Strongest counter:** one both-halves sweep at ONE parent length is thin
  evidence for a rule across lengths. **Answer:** which is why the sweep at
  a second length is this ruling's GATE, not a follow-up — the change lands
  only if the adaptive default measures within 1.3x of the swept best at
  both lengths. If it does not, (b) is the fallback and the ledger records
  the refutation.
- **(b) lower the fixed default to 16.** REFUSED as the primary: it fixes
  the measured case and leaves the asymptotic case wrong, which is the case
  §9's 10^6 row exists to measure. Kept as the fallback if the gate fails.
- **(c) leave 64.** REFUSED: it is 2x off where it was measured, wrong by a
  growing factor where it was not, and the reason given for leaving it —
  that the spec names it — is not true.

**Gate (all three, or the change does not land).**
1. The both-halves sweep re-run at TWO parent lengths (the 403-entry row and
   one materially longer), with the adaptive default within 1.3x of the
   swept best at each; both tables recorded in the bench ledger.
2. `flow-045` (anchored = genesis = off) still green — the correctness
   invariant the interval must never touch.
3. `flow-047`'s exact anchor-append counts RE-DERIVED against the rule
   rather than against 64, and still asserted exactly. A fixture that
   asserts a count must state which interval the rule yields at that head.
