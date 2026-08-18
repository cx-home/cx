# #832 — spec-process audit and cure (ledger + ruling store)

Authorized: **R5.5** (owner, 2026-08-18, "5 approved") — "the spec-process
audit and cure is AUTHORIZED, including editing the process artifacts
themselves." Sequenced LAST before the v0.16.0 cut.

This file is itself named `partition_*` **deliberately and ironically**: until
the ruling store stops being a filename glob, this is the only spelling under
which the R6.x rulings recorded below are resolvable by the gate they cure.
The file should be the LAST one that ever has to make that choice.

Method note: every claim below was measured against the live tree and the
gate's own output (`make spec-freeze-gate`, GATE-RC captured un-piped), not
inferred from memory or prose.

---

## Part 1 — The violation audit (16 → 3 classes → 13 open)

`make spec-freeze-gate` at `d118db10` reported **16 violations** over
`f964c16a..HEAD`. Audited one by one:

### Class T — gate tokenizer false positives (3) — CURED in this wave

`8829c76a` (#828), `ee415f98` (#831), `a7e5da0c` (#777) all carry a `RULED:`
token whose ruling IS recorded in `partition_I5_exit_review_packet.md`
(§10 addenda: `828-1a`, `831-1a′`, `777-1a`). All three spell the token
parenthesized — `(RULED: 828-1a)` — and the gate's fragment parser kept the
closing `)` glued to the id, so `grep -F "828-1a)"` missed the recorded
`828-1a`. These commits followed the rule; the gate misread them.

**Cure (executed):** `strip_unbalanced_parens` in `spec_freeze_gate.sh` —
only UNBALANCED trailing parens are stripped, so the recorded
`R4.4(a-revised)` qualifier spelling survives intact. Selftest grown 5 → 8
scenarios, red-proofs included: a parenthesized BOGUS token still fails
(scenario H), so this is a false-positive fix, not a loosening. After the
fix: 16 → **13**, exactly this class.

### Class S — ruling recorded in a gate-VISIBLE store; token missing or misspelled (5)

| commit | issue(s) | ruling record | what went wrong |
|---|---|---|---|
| `a36244f4` | #854 #849 | **R5.1**, remediation register | ruled 2026-08-18, recorded LATE (post-commit; R5.0 row records the lateness) — no token to write at commit time |
| `ab6a62e5` | #853 | **R5.2**, register | same |
| `d3277277` | #840 | **R5.3**, register | same |
| `9a76fb18` | #808 #760 #833 | **808-1a / 760-1a / 833-1a**, exit packet §10 | rulings recorded BEFORE the work; message spells `RULED 808-1a` — **no colon**, so the gate's `RULED:` regex never sees a token |
| `f62deb82` | #823 | exit packet: "#823 — SCOPE IS THE WHOLE ISSUE" (owner) | scope ruling recorded; no token written |

The owner already ruled the route for the first three (register R5.0, "(a)"
2026-08-18): record the rulings in the register (done), do NOT rewrite pushed
history, do NOT self-add `ADJUDICATED_SHAS` rows — fold the set into this
audit. That route is applied to the whole class.

### Class U — express ruling recorded in a gate-INVISIBLE file (2 + 1 partial)

| commit | issue(s) | where the ruling actually lives |
|---|---|---|
| `397cbfff` | #817 (of #819 #817 #778 #740) | `batch_796_post_gate_defects.md` — owner batch ruling "RULED: 1a" 2026-08-13; **`batch_*` does not match the gate's `partition_*` glob.** #819/#778/#740: no store record found (test-honesty and error-code fixes; the did.md §8/§5 split is a real spec change riding impl) |
| `c5019ca6` | #844 | ruled "2a" by owner (cited in the message); the ruled OUTCOME is recorded in `xap_grammar_composition.md` §3.1/§8.1 — a working SPEC, not a ruling store. No discrete ruling row exists anywhere the gate can see |
| `aef85beb` | #705 (mime half) | the media-type ruling ("never `text/cx`") is recorded in `grammar_lexicon_review.md` — again a working spec outside the glob. The rest of the commit is stale-citation cleanup |

This class is the issue's own thesis, demonstrated with teeth: rulings were
followed and recorded, in files the gate cannot read. `RULED` rows exist today
in at least 44 files in `spec/02-working/`, of which the gate reads only the
34 `partition_*` ones — `delivery.md` alone holds 9 ruling records outside
the glob.

### Class M — no express recorded ruling found; catch-up/mechanical in kind (5)

| commit | issue(s) | the spec side of it |
|---|---|---|
| `05e4e5d3` | #837 | six link-path typos (`../` depth) across approved std-lib/xap specs + one stale example (`?await-all` arity) — semantics untouched; the release script was blocked by its own gate |
| `efd780b1` | #777 catch-up | §2.11.1's illustrative enumeration completed (7 → 10 key kinds); "nothing behavioral moves". 777-1a covers the map lane, arguably not this half |
| `5a6ae843` | #726 | authoring-process §7 status row ("open" → "wired") riding the `xap init` feature commit |
| `c6caa756` | #726 | spec pointers repointed from the tracker to the landed reference app (xap.md + two working specs) riding the app commit |
| `c21515cb` | #826 | the restructure PROPOSAL document + its rendered demo page. Acceptance 1 explicitly gated implementation on owner approval, later given (R5.4) — but at commit time the pairing (02-working proposal + docs-src artifact) was mixed with no ruling |

Honest reading: none of these is a semantic spec change smuggled past review
— but "mechanical" is exactly the judgment R4.1 exists to take away from the
committer. Each should have been split (spec-only + impl-only commits pass
the gate separately) or ruled first. Their disposition is the owner's
(letter Q2 below).

### The systemic finding

13 violations across 2026-08-16 → 2026-08-18, from at least 6 different work
streams, while `make test-vcx` ran green throughout — because
`spec-freeze-gate` sits in `TEST_TARGETS` (Makefile:429) but is not a
`test-vcx` dependency (Makefile:1025). The same lane hole as #860
(cured for the two agreement gates by R5.8). The discipline did not decay;
the feedback loop was disconnected. A committer who runs the operational
lane never sees the gate refuse, so the token habit never forms.

---

## Part 2 — The structural evaluation (the issue's four questions)

**1. Location vs prefix.** The store should be a LOCATION. A directory is
checkable by construction; a prefix is a convention six `grep` sites mistake
for a contract. Concretely: a top-level **`ledger/`** directory, outside
`spec/` entirely. The gate's three path classes then simplify to their
honest forms — normative spec = `spec/**` with NO exceptions; `ledger/**` is
neither spec nor impl; everything else is impl. The current carve-out
(`spec/** except partition_*`) exists only because two unrelated things share
a directory.

**2. Should campaign records live under `spec/` at all?** No. The lifecycle
directories (`01-new → 02-working → 03-approved`) describe SPEC maturity;
ledgers are immutable process history and never graduate. Keeping them inside
the lifecycle is why `02-working` is 65 files of which ~36 are not specs.
NOT-ADRs rider: `ledger/` holds *authorization records* (who ruled what,
when, naming which spec text) and campaign evidence — design rationale
itself stays IN the spec, per the standing no-ADRs rule. The cure must not
institutionalize ADRs under a new name.

**3. Archival.** With a recursive store glob (`ledger/**/*.md`), archival
becomes `git mv` into `ledger/_archived/` with zero effect on ruling
resolvability — the property the current design makes impossible (archiving
a `partition_*` file today silently orphans every token that names its
rulings).

**4. `batch_*` vs `partition_*`.** Dissolved by the move: location carries
the meaning, basenames become free naming. Existing basenames are kept
verbatim under `git mv` (36 files: 34 `partition_*` + 2 `batch_*`) so
history follows and in-tree citations are a mechanical path rewrite,
verified by `verify-doc-links` and a fresh gate run + selftest.

Also in scope at execution: `RULED` rows living in working SPECS
(`delivery.md` 9, `message_delivery_unification.md` 6, …) stay where they are
as historical prose — going forward, new rulings are recorded in `ledger/`
and tokens must resolve there. Additional non-ledger process records in
`02-working` (e.g. `evict_cx_from_v_PLAN.md`, `delivery_edit_packets.md`)
are CANDIDATES to move, each confirmed individually at execution — no bulk
reclassification.

---

## Part 3 — Rulings (R6.x ids reserved here; recorded BEFORE execution per R4.2)

**Owner ruled 2026-08-18: "1a 2a 3a 4a" — all four as recommended.**

- **R6.1 (1a) — ruling-store relocation, RULED.** Top-level `ledger/`,
  outside `spec/` entirely. All 36 glob-named files (34 `partition_*` +
  2 `batch_*`, this file among them) `git mv` with basenames kept. The gate's
  ruling store becomes `ledger/**/*.md` (recursive — archival into
  `ledger/_archived/` can never orphan a ruling); normative spec becomes
  `spec/**` with NO exceptions for NEW work; the legacy spellings
  (`spec/02-working/partition_*` / `batch_*`) keep their ledger classification
  so pre-move history classifies as it did when written, and the gate REFUSES
  the legacy namespace at the tree level — any file matching it at HEAD is a
  violation, so the historical carve-out cannot be re-entered.
- **R6.2 (2a) — disposition of the 13 open violations, RULED.** One
  adjudication batch: all 13 into `ADJUDICATED_SHAS`, each row naming its
  Part 1 evidence and this ruling. The skip stays loud, history stays intact,
  the gate goes green on facts rather than on a moved epoch.
- **R6.3 (3a) — wire `spec-freeze-gate` into `test-vcx`, RULED.** After R6.2
  makes it green (R5.8's order: green first, then wired).
- **R6.4 (4a) — §6.5.x anchor, RULED.** Declared DELIBERATE and permanent by
  one sentence in `code.md` §6.5.x (the x names the classification axis, not
  a pending number); NOT renumbered. Renumbering would shift three anchors
  across 61 citation sites in 17 files for zero behavioral gain — the owner's
  own framing at the 08-18 second round. **This is the NAMED spec
  authorization for that one sentence**, recorded here before the edit.

## Part 4 — Execution log

- 2026-08-18: Class T cure landed (`55ea91f9`) — `spec_freeze_gate.sh`
  unbalanced-paren stripping + selftest 5→8 (red-proof H for
  parenthesized-bogus). Gate output 16 → 13, the delta exactly Class T.
  SELFTEST-RC=0.
- 2026-08-18: owner ruled "1a 2a 3a 4a"; recorded at `1abd4ba7` BEFORE
  execution (R4.2).
- 2026-08-18 **R6.1 EXECUTED** (`d749950b`) — 37 files `git mv` to `ledger/`
  (34 `partition_*` + 2 `batch_*` + this file), basenames kept;
  `spec/02-working/` back to 29 actual working specs. Gate path classes
  rewritten (store = `ledger/**/*.md` recursive; spec = `spec/**`; legacy
  spelling classified ledger for history and REFUSED at the tree level);
  selftest 8→9 (scenario I: legacy-namespace red-proof). Verified: the gate
  reported the SAME 13 violations after the move as before — the historical
  classification held, and every pre-existing token still resolves. Eight
  reference sites repointed; zero relative links existed in the moving files
  (measured); the register's CLOSED R4.1 row kept verbatim as history.
- 2026-08-18 **R6.2 EXECUTED** (`21421fba`) — 13 `ADJUDICATED_SHAS` rows,
  each naming its Part 1 evidence class. **`make spec-freeze-gate` GREEN:
  GATE-RC=0, clean (f964c16a..HEAD), 14 ADJUDICATED lines, selftest 9/9.**
- 2026-08-18 **R6.3 EXECUTED** (`5ebd4ac4`) — `spec-freeze-gate` wired into
  `test-vcx`, green-first per R5.8's order.
- 2026-08-18 **R6.4 EXECUTED** (`63884f6b`) — the §6.5.x anchor note landed
  in `code.md` (spec-only commit, RULED: R6.4). First wording said "not a
  placeholder" and turned `check-code-spec-consistency` gate 1 red —
  "placeholder" is a forbidden completeness token in `code.md`. Reworded to
  "not an unassigned number"; gate green. The checker policing the sentence
  that legitimizes its own §6.5.x anchor is the process working.
