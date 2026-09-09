# RULED: 1316-c1 — the construct row gains a sticky `activated=<entry seq>`;
# the EMITTER resolves seq → the entry's `ts` and paints `elapsed`

Date: 2026-09-08 22:00 ET (posted on the issue 2026-09-09T00:05:37Z).
Issue: cx-home/cx-private#1316 (Part 2, the run overlay).
Campaign: v0.18.0 close-out (#1354), Lane 2 (the #1265 flow ladder).
Letter drafted by worker B on the issue at 23:39Z; **ruled by the owner +
Fable with a FOURTH option the letter did not carry** — (d).

## Ruled

`f--row-with` (`stdlib/flow.cx`) gains `activated=` — the SEQ of the journal
entry whose transition moved the construct into `:running`, or into the first
non-`:waiting` status — sticky like `attempt`/`fired-at`, taken from the
receipt's `seq` which the fold already reads. It is DETERMINISTIC, so the fold
identity stays byte-identical on replay (§2.2/§4.11) and the printed step rows
in `conformance/stdlib/flow.cxd` re-pin ONCE with a deterministic value.

The overlay VALUE (`1316-b1`) carries `activated=` VERBATIM. `elapsed` is
painted by the EMITTER — the host's `GET /stream` frame (`1316-b4`) or
`cx flow watch` (`1316-b3`) — which holds the journal, resolves seq → that
entry's `ts`, and subtracts from ITS OWN clock. The record therefore says WHEN
by seq and stays a clock-free pure fold; the clock-bearing half lives where a
clock exists. flow.md §4.17's "elapsed since activation" and §4.11's "the
record is the state" both stay true, so **this ruling authorizes no spec
edit** — unlike `1316-b3`/`b4`/`b5`, its text carries no "Spec text, ruled"
clause, and none was taken.

**`1316-b2`'s count is corrected by the same pass:** three marks emitted
before this (a construct's `status=`, a `map`'s child-run counts, the
`[conflict …]` on an uncompensatable construct); `run-state` stays `pending=`
naming `pause`/`resume`/`cancel`, which have no wave; `elapsed` is ruled in.
So the overlay's sealed rule table is **four emit, four pending** — `(8, 4)`
in diagram-027's own probe.

**Refused:** (a) an activation INSTANT on the row — only timer transitions
carry `at=` and flow keeps no clock of its own (RULED: 1358-e), so (a) cannot
name its clock for an ordinary activation and would re-open the 2026-vs-1970
trap; (b) the overlay reading the transitions — deletes `1316-b1`'s pure
projection and re-derives per paint what the fold derives once; (c)
`pending=` forever — deletes the mark an operator asks for first ((c) was the
correct HOLDING position and was thanked, not refused as conduct).

Blast radius **HIGH** (fold row shape; flow.cxd re-pins).

## As implemented — and two things the ruling's own text did not predict

**1. WRITE-ONCE, not sticky-with-overwrite.** `attempt`/`fired-at` are sticky
WITH overwrite: a timer fires many times and the row reports the most recent.
A construct activates ONCE, so a later transition must never replace the
value. Measured (flow-066): a step moved by entry 2 (`:running`) and again by
entry 3 (`:done`) reports **2**. The ruling says "sticky like
`attempt`/`fired-at`", which is the right family and the wrong overwrite rule;
write-once is what "the entry whose transition MOVED the construct into
`:running`" actually means, so the implementation follows the definition
rather than the analogy.

**2. The POSITIONAL read had to be fixed to hold §4.11's equality.**
`status`'s `opts.at` branch flattened the slice's transitions and folded them
through the public `fold-record`, which has thrown the entry boundaries away
and therefore cannot name an entry. Measured before the fix: `status at: 3`
answered a row with **no** `activated=` where the head read answered
`activated=2` for the very same construct — §4.11's own equality broken by a
field. The branch now reduces over the slice's ENTRIES with `f--fold-step`,
the same reducer the head read uses, so the two reads differ only in WHERE
they stop. flow-025's pinned bytes are unchanged by this (verified byte for
byte), and flow-066's `at-3-one` is the assertion that keeps it true.

**ABSENT, never 0, where there is no entry to name:** a construct still
`:waiting` at the position read, and the PURE fold — `fold-record` over a bare
transition sequence, which is also `simulate`'s path (§2.2). 0 is a seq no
entry ever carries (journal.md §3.2 numbers from 1), so writing it would be a
value that reads like an answer.

`f--fold-fn-id` moves `fold-record/2` → `fold-record/3`, which is what forces
every live snapshot anchor to be re-taken — the bump the identity comment
beside it already prescribes for any change to `f--apply-transition`.

## The re-pin was MEASURED at 5 fixtures, not the ~65 rows the ruling estimated

The ruling said "the 65 printed step rows in `conformance/stdlib/flow.cxd`
re-pin ONCE". Measured, by running the module SOURCE as a program against
every case in the corpus with a BASELINE control run beside it (no build, no
build slot — the embedded-stdlib probe), the moving set is **five cases**:
`flow-030`, `flow-040`, `flow-042`, `flow-058`, `flow-059` — twelve rows in
all. The estimate was high because most printed step rows in that corpus are
`simulate` or `fold-record` output, and those have NO journal entry to name,
so they are unchanged by construction. In every one of the five the ONLY
change is the inserted ` activated=N` (checked mechanically: the edited output
with `activated=` stripped is byte-identical to the baseline output).

Fixtures: `flow-066` (the record half — write-once, the positional/head
equality, and both absence cases) and `diagram-032` (the overlay half — the
seq carried verbatim, and the negative that a row folded with no journal
carries none rather than an empty one). Both were red-proofed against the
baseline module before the fix: `flow-066` answered `''` for three of its five
probes, `diagram-032` dropped `activated=2` from its `journal-backed` half.

## Registry note — the fixture is `flow-066`, and the pre-flight that said
## `flow-063` was VACUOUS

The first pre-flight for this fixture swept every branch with
`git show "$b:conformance/stdlib/flow.cxd" | grep -c id=flow-063` and reported
"no collisions". It was **vacuous**: zsh consumes `:c` inside `"$b:conformance/…"`
as a parameter modifier, so `git show` was handed a name it could not resolve
and every branch answered nothing. `flow-063` is in fact claimed by
`impl/cx-B-1313b` (#1313's `rearm-uses-each-runs-recorded-basis`), and
`flow-064`/`flow-065` landed on `release/0.18` with #1365 while this work was
being written. The correct pre-flight uses `"${b}:…"`, or does not go through
the shell at all. Same trap as the one worker A recorded on #1354; the fix is
one brace and the failure mode is silence.

---

# AMENDED — RULED: 1316-d — `activated=` is the activating transition's FOLD
# ORDINAL, write-once; the entry-seq form above is SUPERSEDED

Date: 2026-09-09 04:05 ET (posted on the issue 2026-09-09T07:13:12Z).
Issue: cx-home/cx-private#1316. Letter drafted by worker B on the issue at
07:01Z; ruled (a) by the owner + Fable.
Related: `1265-PC-2` (`snapshot-every` is a COST knob), `flow-045`
(gate=enforced: the anchored read equals the genesis fold, as a byte
equality), `flow-066` (kept), §11a (`f--take-anchor`).

## Why the form above was wrong — and it was caught by a gate, not by review

`1316-c1`'s premise, that a journal entry's seq is a stable in-run address,
does not hold. `f--take-anchor` appends `[flow-snapshot …]` **into the run's
own home stream** (`stdlib/flow.cx` §11a), so every anchor CONSUMES a seq, and
a value read off an entry seq therefore became a function of `snapshot-every`
— which `1265-PC-2` rules is a pure cost knob that must not be observable.

MEASURED, in the c1 lane at `b25fb87bf`
(`vcx/target/lane_B_1316c1.log`, `SUITE-EXIT=2`): `flow-045` — the pin that
the anchored read equals the genesis fold — went RED, with
`anchored-eq-off false` and `anchored-eq-default false`, and the same step
recording `activated=4` under anchoring against `activated=3` without it. A
gate-enforced fixture outranks a ruling, so the ruling moved.

## Ruled

`f--row-with` writes `activated=<the FOLD ORDINAL of the activating
transition>` — the first move out of `:waiting` — once, read off the `$ord`
that def already receives, exactly as `ord=` is the completing transition's
ordinal. The fold reads only `[flow-transition …]` entries (`f--entry-ts`), so
no anchor, migration marker or future interleaved entry can move it.

REVERTED with it: the `$seq` threading through `f--commit` /
`f--after-commit` / `f--fold-step` / `f--fold-apply` / `f--fold-one` /
`f--apply-transition` / `f--apply-construct`, **and** `1316-c1`'s change to
`status`'s `opts.at` branch. The ordinal lives in the fold state, so the head
read and the positional read cannot disagree and the positional read goes back
to the flattened `fold-record` form it always had. `flow-066` (the head /
positional equality pin) is KEPT and is what proves it. `flow-045` is
untouched.

`1316-c1`'s other clauses stand: write-once and not sticky-with-overwrite (the
measured correction to the letter's own "sticky"), deterministic, and the
overlay (`1316-b1`) carrying the value verbatim while the EMITTERS — the
`/stream` frame (`1316-b4`) and `cx flow watch` (`1316-b3`) — map the ordinal
to the transition they are already walking and paint `elapsed` against their
own clock.

**Refused:** (b) projecting `activated=` out of `flow-045`'s comparison —
deletes `1265-PC-2` as a byte equality and makes an anchor observable; (c) the
entry's `ts` — unmeasured invariance; (d) dropping the attribute — refused
under `1316-c1` and still refused.

## One clause of `1316-c1` this ruling widens, and it is a MEASUREMENT

`1316-c1` said the attribute is ABSENT where the fold is not journal-backed —
`fold-record` over a bare transition sequence, and `simulate`. That was a
property of the SEQ (there is no entry, so there is no seq), not of the
attribute. **A transition sequence has ordinals whether or not anyone
journaled it**, so under `1316-d` the pure fold carries `activated=` exactly
as a live one does, and a simulated record now names the ordinal that
activated each construct. Nothing in the ruled mechanism could suppress it
without re-introducing the very threading the ruling reverts.

The consequence is that `1316-c1`'s re-pin count does not carry over, and it
is re-measured rather than re-estimated. Measured with the module-source probe
against an `origin/release/0.18` control (no build, no build slot — the slot
FIFO was 13 deep):

- `flow-023-doc-start`, the `[fn-doc]` example for `start` mirrored into the
  corpus, moves from the pinned bare rows to
  `ord=3 activated=2` / `ord=5 activated=4`. Under `1316-c1`'s seqs the same
  case measured `activated=2` / `activated=3` — so the second row's value
  differs between the two forms, which is the difference the ruling is about,
  observed on a fixture rather than argued.

The full re-pin table, both directions, is in the commit that lands it.
