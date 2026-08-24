# Bitemporal semantics (stream 8)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 8, issue #680). Mandate: transaction
time stays the journal's `seq` (shipped); a standard valid-time attribute
vocabulary + as-of-both-axes reads ("what did we know when"). Temporal
semantics cannot be retrofitted into stored, hashed values
post-production. Normative once approved.

**Worked example (M5):** "On Aug 5 we learned the Aug 1 price was wrong."
Entry `seq=12` asserts `19.99::decimal` valid-from Aug 1; order `o-5521`
prices from it at `seq=13`; entry `seq=27` corrects — `[supersedes
hash=<entry-12-address>]`, `17.99::decimal` valid-from Aug 1. Four folded
views from one immutable chain: `{at-seq:13, valid-at:Aug 3}` → 19.99
(the defensible invoice); `{at-seq:27, valid-at:Aug 3}` → 17.99 (the
restatement basis); the pair is the restatement delta — the number the
auditor asks for that today's substrate cannot produce. Both entries
remain, chain verifiable, the correction itself attributed
(actor/authority) — "who corrected the price, under what authority, and
when" answers on both axes.

## §1. Findings

1. **Transaction time is solid at the ordinal, hollow at the instant:**
   dense gap-free per-stream `seq` with hash chaining and `at-seq` reads
   at three levels; but no cross-stream total order (a tenant-wide TX
   coordinate is a HEAD-SET, carried today only by the signed snapshot),
   `ts` is normatively non-authoritative — and in the shipped default is
   `epoch:HH:MM:SS`, a seq-derived string that is not a datetime at all
   (#712). `keep-after-time` retention is a spec'd no-op for the same
   missing ts→seq primitive (#712).
2. **Valid time is genuinely nothing** — zero occurrences of the concept
   in any approved spec. Three unnamed near-misses exist (authz
   `[until]`, VC issued-at/expires with `not-yet-valid`, session
   nbf/exp): validity windows in everything but name, per-module,
   non-composing.
3. **The substrate cannot distinguish** a late-arriving fact from a
   correction from a genuine change — three different things that all
   look like "another entry at a later seq." Correction discipline
   exists as prose ("append a compensating event") with zero vocabulary:
   no linkage field, no taxonomy, no fold contract for superseded facts.
4. The mock clocks (`[?sleep mock]`, time/sched virtual clocks) are
   determinism devices, not a time axis — but they are what makes
   bitemporal fixtures byte-stable.

## §2. Valid time: payload data under a normative vocabulary (L115)

Valid time is **payload domain data** under a normative reserved
attribute vocabulary: `valid-from=` / `valid-to=`, **half-open
`[from, to)`** (the SQL:2011/XTDB convention — no boundary
double-count), open end = ABSENT attribute (never `null`; the
no-conflation rule). Carriers: `date`, `datetime`, `::instant` all
admissible (day-grain business validity is real); stream 11's
strict-validation rule applies. **Two attributes, not an interval
kind** — eleven kinds were just settled and kind addition is a
major-version event. Tested against the closed lane list: Lane 1
rejected (identity-excluded metadata is semantically wrong for validity
— two records differing only in effective date must be different
values); Lane 3 rejected (the journal owns only the envelope; valid
time is domain semantics); **Lane 2 remains the retroactive-annotation
escape** for already-stored values, with the honest caveat that a
detached claim made later is weaker than an in-payload assertion.

## §3. Transaction time: position-only at v1 (L116)

The TX coordinate is **`seq` per stream; a tenant-wide coordinate is a
head-set** (the signed snapshot is its carrier). A wall-clock TX axis is
explicitly out at v1 — with the enabling decision made NOW rather than
deferred into a second epoch: **the default journal `ts` becomes a real
ISO-8601 UTC-Z instant IN FORM at I1** — the deterministic epoch-
anchored synthesis (`1970-01-01T00:00:0N Z` + seq) replaces the
`epoch:HH:MM:SS` string, so the form is spec-conformant and fixtures
stay byte-stable, while real wall-clock `ts` remains the existing
`opts.clock` opt-in (no `clock` capability pulled into every append).
The whole journal fixture family re-blesses at I1 (#712, joins the
manifest). ts→seq resolution (well-defined by per-stream monotonicity:
binary search) is then additive later, and `keep-after-time` implements
on it (#712).

## §4. Corrections (L117)

- **Linkage:** a correcting entry carries `[supersedes
  hash=<entry-address>]` — the corrected entry's content address (never
  `seq`: stream-local and compaction-fragile; the hash composes with
  Lane-2 claims).
- **Taxonomy (closed atom vocabulary):** `:assertion` (retroactive new
  fact — nothing superseded), `:correction` (the prior fact was WRONG —
  superseded across its whole valid extent), `:amendment` (the prior
  fact was right then, wrong now — its valid interval closes, a new one
  opens). They fold differently; conflating them is what makes
  restatement unauditable.
- **`verify` stays syntactic:** a dangling `supersedes` is a FINDING
  from a coherence verb, never a chain break.

## §5. The bitemporal read (L118)

A **substrate-provided PURE projection** `[sequence entry] → [sequence
entry]`, parameterized by `(tx-position, valid-instant)`, composed
BEFORE `fold-value` — the fold contract is untouched (pure `$fn`,
deterministic), and stream 21's upcasting gets the same seam.
Surfaced through journal read/fold/replay opts with **disambiguated
naming: `{at-seq: N, valid-at: T}`** — `as-of` is not used on any new
surface (authz keeps its shipped `as-of` with a cross-reference;
stream 7 coordinates on `at-seq` for TX snapshot claims — the
three-claimant collision resolved by assignment). The four-quadrant
query table (now/now, at-seq/now, now/valid-at, at-seq/valid-at) is
normative; the fourth quadrant is THE bitemporal query. CXPath
predicate filtering over the vocabulary needs no grammar change;
interval builtins (`[$overlaps]`, `[$contains-instant]`) land with the
vocabulary; the as-of COLLAPSE (selecting the current fact, not
filtering) is the projection's job, driven by the §4 taxonomy.

## §6. Identity seam and the erasure constraint (L119)

Confirmed and stated normatively: **VT lives in the hashed payload**
(Tier-1, caller-owned; UTC-Z strict canonicalization inherited from
ruling 20 at I1 — no new epoch need) and **TX lives in the hashed
envelope** (Lane 3, journal-owned); one entry hash covers both; no
fourth lane. **The stream-20 constraint is ruled here** (S2 precedes
S4): valid-time metadata is **shreddable with the payload** — hoisting
a temporal skeleton would require a fourth lane (forbidden) or
envelope ownership of domain data (violates the journal boundary);
therefore a VT query over shredded entries **reports its redaction
count visibly** (finding-not-fault; honest-reporting obligation) and
never silently under-reports. Stream 20 inherits this as a binding
input.

## §7. What stays out (L120 — ratified exclusions)

No store temporal tables (the journal is the only history; store
as-of, if ever, is a projection over E3's ref lineage); no in-place
temporal rewrites (append-only is permanent); no interval kind; no
wall-clock TX authority (`seq` — never `ts` — stays the order
authority); no cross-stream total order (head-sets; coordination is
stream 10); views are folds (materialization is stream 3's
`[?materialize]`); `verify` stays syntactic.

## §8. authz composition (L121)

`check {as-of: T, with-context: C}` gains the coherence rule: the
context snapshot records its TX position (the fold's at-seq/head-set);
the **bitemporal authorization query** — "what would we have decided at
position P, for instant T" — is thereby specifiable; an incoherent
pair (a gate's state predicate evaluated against a context folded
after facts the caller meant to exclude) is constructible only
explicitly, and the decision value records BOTH coordinates for audit.

## §9. Corpus handoff (stream 14; M5 substrate)

The price-correction four-quadrant fixture family (the restatement
delta pair as the headline); supersedes-linkage + taxonomy fold
fixtures (`:correction` vs `:amendment` vs `:assertion` fold
differently — discriminator triple); half-open boundary probes
(valid-to exactly at T); open-ended validity (absent attr, never
null); ts-form re-bless vectors (I1); redaction-visibility fixture
(shredded entry → reported count, not silence); coherence-rule authz
fixture (decision value carries both coordinates); offline-replica
seed fixture (VT precedes TX — stream 9's consumer made concrete).

## §10. Rulings ledger — RULED

Letters 115–121 **ruled (a) 2026-08-05 under the standing acceptance
ruling**: payload VT vocabulary, half-open, absent-open-end, two
attributes not a kind, Lane-2 escape (115); position-only TX at v1
with the ts FORM fixed at I1 (deterministic UTC-Z synthesis; wall
clock stays opt-in) and ts→seq additive later (116); hash-linked
supersedes + the three-relation taxonomy + syntactic verify (117); the
pure pre-fold projection, `{at-seq, valid-at}` naming (as-of retired
from new surfaces, stream-7 coordination), four-quadrant table (118);
VT-in-payload/TX-in-envelope confirmed + VT shreddable with visible
redaction reporting — stream 20's binding input (119); the exclusion
list ratified (120); the authz coherence rule + dual-coordinate
decision values (121). Recorded in the campaign decision log.
Spec-edit map: journal.md (vocabulary recognition, projection, opts,
ts form, retention), cxdm.md (reserved attribute vocabulary note),
authz.md §3.4 (coherence + recorded coordinates), vc.md/session.md
(cross-refs naming their windows as valid-time instances), stream-20
handoff, stream-9 handoff (VT/TX divergence preserved in sync),
stream-7 naming coordination, stream-21 fold-seam handoff.
