# Rulings 2026-09-05 — the grammar-expression environment (GE-0..GE-3)

**Status: GE-0..GE-3 RULED by the owner, 2026-09-05** (owner answers `1a` on
the defect, then `1a 2a 3a 4a`). Recorded BEFORE any spec text (ledger
discipline; register R4.2).

**Subject.** What an EVALUATED GRAMMAR EXPRESSION may read. There are two of
them today — a rule's `[check]` (§4.9a, RULED: 1308-CG-2) and a derived noun's
`[fold]` (§4.12, RULED: 1308-CG-5) — and they share one code path
(`eval_pure_predicate` → the §3.1 sandbox). Kept separate from the computed
-field question on the owner's instruction; that is
`rulings_2026_09_05_computed_fields.md` (DF-1, DF-2).

## The finding — measured, not inferred

Three probes on `release/0.18` + the `known-by` rename, same feature each time:

1. `[check '[= $intent/slug $intent/title]']` — **works.** Admits when the two
   fields match, refuses `CXER4865` when they do not.
2. `[check '[= $intent/slug [$strings:lower $intent/title]]']` — **`no callable
   "strings:lower"`.**
3. `[check "[?lib 'cx-stdlib/strings' :as s] [= …]"]` — **`CXER4113: an eval
   may not widen the module set`.**

And the decisive one, (3) run twice with different CALLERS:

| the program that called `[$xap:emit]` | what the law did |
|---|---|
| no `cx-stdlib/strings` import | every intent refused — the law cannot decide |
| `[?lib 'cx-stdlib/strings' :as s]` present | the law works and refuses correctly |

**A declared law's meaning depended on the caller's imports.** The predicate
inherits the caller's `[?lib]` set under the non-widening rule
(`code.md` §6.4.4 / `modules/cx.md` §3.2) — a rule that is right for `cx:eval`,
where the caller IS the author, and wrong here, where the author is the feature
and the caller is whoever emitted. §4.9's whole claim is that a module and a
grammar rule refuse the same intent for the same reason; a law that answers
differently per caller does not meet it. It also fails in the loud direction —
every intent refused — which an adopter reads as "checks are broken".

## GE-0 — the caller-dependence is a DEFECT — RULED (a)

- (a) **A grammar expression does not inherit the caller's module set. Its
  environment is fixed by this record, and a module call outside it is a
  COMPOSE refusal** — W10 for `[check]`, W13 for `[fold]` — so an author sees
  it when composing, not per-intent at runtime. §4.9a's description of the
  predicate as "ordinary cx" is corrected: it is the environment defined here.
  `CXER4113` becomes unreachable from a grammar expression. **TAKEN.**
- (b) Leave the mechanism and only correct the spec. Rejected: it documents
  caller-dependence instead of removing it.
- (c) Exempt grammar predicates from the non-widening rule and let them import
  freely. Rejected under GE-2.

## GE-1 — which modules a grammar expression may read — RULED (a)

- (a) **`cx-stdlib/strings`, `cx-stdlib/math`, `cx-stdlib/re`. TAKEN.**
  Text, numbers and patterns: the demonstrated gap exactly. `re` is RE2, so
  matching is linear-time and bounded — a law that runs per intent may not
  carry a backtracking blowup.
- (b) (a) plus `array`, `map`, `fp`. Rejected for now: plausible and cheap, but
  no case has appeared, and this project grows closed tables on evidence (the
  §4.6 scalar set, the rule kinds). Admission is a one-line ruling later.
- (c) All 24 modules that declare no impure def. Rejected: purity is necessary,
  not sufficient. It would put `zip`/`tar` decompression on a commit path,
  admit `diagram`'s 559 defs into a law, and tie the surface a law may reach to
  whatever the stdlib happens to contain rather than to a decision.

**Why the list is safe to trust.** "Declares no impure def" became a VERIFIED
property at #1298: the module loader now runs the purity checker over every
module's defs and its resolved imports, and refuses `CXER0233` on a
contradiction. Before that landing this ruling would have rested on an
unchecked annotation.

**Widening procedure.** A module joins by ruling, recorded here, with the case
that motivated it. Nothing is admitted because it happens to be pure.

## GE-2 — how those modules are reached — RULED (a)

- (a) **Pre-imported under their canonical prefixes** — `[$strings:lower …]`
  resolves with no import line. The environment installs exactly the GE-1 set
  and pins the non-widening allow-list TO that set, so a grammar expression can
  neither reach past it nor depend on who called. **TAKEN.**
- (b) The predicate declares `[?lib]`, restricted to the allow-list. Rejected:
  a self-documenting predicate reads better, but it requires exempting grammar
  expressions from the non-widening rule GE-0 exists to repair — a repaired
  hole reopening under another name — and it adds an import line for every
  reader and gate to audit.

## GE-3 — scope — RULED (a)

- (a) **One environment definition, covering `[check]` and `[fold]` alike, and
  every evaluated grammar expression added later. TAKEN.** They share the code
  path today; `[fold]` has the identical defect and the identical fix.
- (b) `[check]` only. Rejected: it leaves a known defect standing in a feature
  that shipped four commits earlier, and brings this ruling back within a month.

## What this does NOT do

It does not reopen DF-1. GE governs what a law may READ; it says nothing about
what the grammar may PRODUCE. DF-1 records that GE-1 admitting stdlib calls
removes one of its two objections — that is a door marked, not a door opened.

## Delivery

Spec: §4.9a (the corrected environment paragraph, replacing "ordinary cx"),
§4.12 (the same environment, by reference), the W10 and W13 rows. The module
list is a closed table in the spec, mirrored in the implementation — this repo
gates such mirrors in both directions, so it cannot silently drift.
