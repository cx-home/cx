# Rulings 2026-08-19 — the composition track (DP-C1: #865 · #866 · #867)

Owner replied **"1a 2a 3a 4a 5a 6a 7a 8a 9a 10a 11a"** to the eleven-question
slate in `design/composition/DP-C1.md` (packet @ 940cda01, adversarial
re-verification amendment @ f2f7a67a). Recorded here BEFORE any work is
scheduled. Trade-offs and rejected options live in the packet; this file is
the citable outcome.

**Spec authorization: NOT granted by this file.** These rulings settle design
direction. Each implementation wave gets its named spec scope when scheduled,
per the standing rule (no spec edits during impl without prior authorization).

## R8.1 — #865 Q1(a): a derived noun is computed by a DECLARED DERIVER-AS-ACTOR

A derived noun's producer is a declared component role: it reads the
constituent streams, applies the derivation in ordinary CX, and emits the
derived noun's events as an accountable journal actor. The deriver's read set
must resolve **⊆ the noun's `[from …]` set** (checked at run assembly —
provenance becomes the read-authority envelope). **No join algebra is
committed.** Engine evaluation, if it ever lands, is an OPTIMIZATION of this
same contract: the engine becomes the bound deriver, events still land in the
noun's stream, nothing else changes. Rejected: engine-computed joins (commits
an algebra prematurely, overlaps #800, creates the system's only
unattributable state); staying uncomputed.

## R8.2 — #865 Q2(a): derived nouns are deriver-reserved — no grammar write verb

A `derived=true` noun admits no `[writes]` from any grammar verb; a composite
declaring one REFUSES at compose (sibling of the #840 dangling-`[from]`
check). The bound deriver commits through the runtime's component binding as
`actor: deriver:<name>` — the ordinary append path, not a bypass.
Consequences in the W5 reference composite: **`raise-alert` retires as a
grammar verb; `detect.cx` is promoted to the declared deriver**; `escalate`
and its N-COMPOSE-2 demonstration untouched; reads unrestricted. Manual
override is a SOURCE noun the deriver folds (listed in `[from …]`), never a
write verb on the derived noun.

## R8.3 — #865 Q3(a): missing producer — refuse the static, surface the dynamic

Run assembly refuses when a derived noun has no bound deriver: a named
refusal listing the unproduced nouns. A bound-but-dead deriver is observable
(it is a journal actor); the projection renders staleness honestly, P0-99
posture (`available=false` + reason). A derived noun's view is never
silently empty-as-if-clear.

## R8.4 — #865 Q4(a): the #800 boundary is affirmed, never merged

#800 owns queries you ASK (read-side: aggregates, pushdown, windows). #865
owns nouns the composition PROMISES (write-side: events in the noun's
stream, from a named actor). A deriver MAY use #800 machinery internally;
the contracts never merge.

## R8.5 — #866 Q5(a): instantiation is a checked relationship, cascade-shaped

An archetype is an **immutable, content-addressed feature document**
distributed at the vendor cascade level (P0-13, reserved from day one). An
instance = archetype address + a binding/refinement document **owned by the
deriver**, resolved cascade-style (P0-14 nearest-wins — no new resolver).
Archetype fixes propagate by **re-bless only**: one recorded act per
instance, gate re-checks every refinement against the new base;
un-re-blessed instances keep their pinned address. At fleet scale,
auto-re-bless is a POLICY ACTOR on the record (the 5b auto-approve
precedent) — categorically different from silent propagation. Rejected:
copy-with-provenance (a fork with a birth certificate); mutable `extends=`
(silent supply-chain propagation).

## R8.6 — #866 Q6(a): the refinement contract — four admitted, two refused

A binding document MAY: **RENAME presentation** (labels/help/prose; names of
record never), **ADD** (fields, verbs, tightening rules), **TIGHTEN**
(narrow only — defined by the existing effect-signature precedent: a
derivation MUST NOT weaken what it derives from), **SELECT** (the W16-b
offers/shows/not-offered-with-why vocabulary, reused). It MUST NOT
**repurpose** an inherited name or **loosen** an inherited rule/type/effect
signature — both refuse at compose with named codes **`archetype-repurpose`**
and **`archetype-loosen`** (W-numbers assigned in the composition-gate family
when the spec section lands). The load-bearing reason loosen refuses:
substitutability — one loosened instance means no consumer can trust any
instance, and the catalog stops being composable. No escape hatch; the
honest release valve is authoring your own feature. CX ships this MECHANISM;
third parties ship catalogs (standing, owner-ruled at #866's filing).

## R8.7 — #867 Q7(a): the floor — a spanning rule means one feature, with the composite carve-out

A rule or ordered choreography binding two nouns (or ordering two verbs)
refuses a base-feature split that would strand it. The legitimate escape is
promotion into a composite declaring `uses` over both bases (the
delayed-shipment shape W4 already enforces from the other side).
Split-with-promotion is legal and earns its documents only when each base is
independently meaningful (R8.10's bar).

## R8.8 — #867 Q8(a): the ceiling — the mechanical cohesion gate

Build the feature's internal graph from the document alone; **two connected
components = two features wearing one name**. Ships in the check-surface
family, report-first → refuse-when-ruled (the W16-b graduation path). Run
against an existing feature it is the split advisor: the components it
reports are the split it would accept. **Included in this ruling: validity
rules gain a checked noun-reference list** (the #840 pattern a second time —
checked, not computed) — today they carry their spanned nouns only in prose,
which blinds both floor and ceiling. Expected acceptance against the estate:
ORIEL one component, W5 trio one each (after the R8.9 correction), a glued
two-domain fixture reported as two, break-tested by gluing an unrelated
noun+verb pair into a healthy feature.

## R8.9 — #867 Q9(a): the edge set — declared semantic edges only; keys and frames are NOT edges

Edges: verb↔noun (`reads`/`writes`); verb↔verb (ordering rules,
`[constituents]`); noun↔noun (validity-rule checked refs per R8.8, sub-noun
typing `type=<noun>`/`repeats=`, `[from …]`). **Keys and frames are NOT
edges** — a key is where features MEET; counting shared keys as cohesion
makes every document one component and kills the gate. Inside a composite,
`[from …]` references to other features' nouns are legitimate cross-feature
edges excluded from the composite's own component count. **Disclosed
consequence, ruled with eyes open:** the W5 `orders` feature fails the
ceiling as written — its `line` noun is edge-less (no verb touches it, no
rule names it; `order-id` is name-convention only). The fix is one declared
relationship (ORIEL's `order.lines type=order-line repeats=true` is the
model) and rides the #867 implementation. Softening the edge set to pass the
undeclared relationship was rejected as vacuous-pass-by-installments.

## R8.10 — #867+#866 Q10(a): graduation — two genuinely different compositions

A feature is private until it survives TWO genuinely different compositions;
the second is the marketplace entry gate (#143's rails) and the archetype
bar (#866): entry requires both compositions named and recorded as evidence —
different composing surface/tenant, non-overlapping `uses` neighborhoods,
not two skins of one deployment. Same bar for archetype status: cohesion
gate green + two genuinely different instantiations.

## R8.11 — the W25 gate, Q11(a): ORIEL after-the-sale is ONE FEATURE

Subscriptions, returns, and reviews land inside `oriel.feature.cxd` as
scoped. The ruled tests themselves answer it: the floor finds spanning rules
binding the blocks into the core (subscription↔product, return↔order,
review↔product via the ruled approval fold), the ceiling finds one connected
component under R8.9 edges, and graduation finds no second composition — so
a split now would be authoring-context bias, the exact disease #867 checks.
A later split at the cohesion boundary is PACKAGING, not migration (client
journals never move). The flagship commits its own gate evidence: the
cohesion instrument's one-component run over ORIEL lands with #867's
instrument (whose acceptance already names ORIEL) — W25 does NOT wait on it.
Forward note, recorded not scheduled: `product.rating` (mean of approved
reviews) is the natural second deriver exemplar once R8.1's mechanism lands.

## Landings

- **W25 (#787)**: UNBLOCKED by R8.11 — after-the-sale as one feature, all 14
  act verbs (subscribe/change/cancel + request-return + write-review with
  the 5b auto-approve policy actor). Runs after W24 per the ruled campaign
  order.
- **#865 impl**: R8.1–R8.4. Named landing for the spec section, the W5
  composite cutover (raise-alert retired, detect.cx promoted), and the
  fixtures both ways (producer folds; absent producer = named refusal).
- **#866 impl**: R8.5–R8.6, R8.10. Named landing for the spec section, one
  archetype instantiated twice, re-bless propagation, and the ERP-trap
  refusal fixtures.
- **#867 impl**: R8.7–R8.10. Named landing for the spec section, the
  cohesion instrument over the estate (including the `orders/line`
  correction), and the break-tests.
- The three issues remain OPEN as those landings; dispositions recorded on
  each.
