# XAP — Grammar Composition (normative algebra)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: 02-working (2026-07-04). Normative elevation of the composition model in [`xap_feature_composition_model.md`](../../_archived/xap_feature_composition_model.md) (which remains the vocabulary + rationale companion). Destined to graduate as a sibling of the approved [`xap.md`](../xap/xap.md) under `spec/03-approved/xap/` (see the graduation section at the end). Companion schemas: [`xap_schemas/`](xap_schemas/) — `feature.cxs`, `xap.cxs`, `surface.cxs`, and the new `grammar.cxs` defined here.

**Purpose.** Define, at reimplementation grade, how the grammars of *n* features compose
into **one grammar** — the single interaction language a principal or agent speaks across
every feature enabled in a XAP. Pluggability ("a feature plugs in without refactoring")
and composability ("features join over shared frames/keys") are already design doctrine
in the composition model; this spec makes them **checkable**: composition either yields a
well-formed single grammar or a conflict **value** (never a crash, never silence), and a
set of invariants guarantees that plugging a feature in cannot silently change the
meaning of anything a principal could already say.

---

## §1. The object of composition

A **grammar** is the formalization of one feature (composition model §2):

```
G = (V, N, R, Φ, K)
```

| Component | Contains | Source in `feature.cxs` |
|---|---|---|
| **V** — verbs | intents with effect signature `(effect, scope, consequence)` + **parameter list** (§6.1) + `reads`/`writes` sets | `[verbs]` |
| **N** — nouns | the read-model: named nouns with typed fields; `derived` nouns carry a `[from …]` **source list** (§4.1) | `[nouns]` |
| **R** — rules | constraints, each tagged `kind ∈ {validity, mandate, exclusion, ordering, cardinality, dependency}` | `[rules]` |
| **Φ** — frame registrations | `(family ∈ {geo, time, value}, noun-field via)` pairs | `[frames]` |
| **K** — key registrations | `(key-name, noun-field via)` pairs | `[keys]` |

Requirements are the *source* of a grammar and governance grants are *attached to* a
grammar; neither is a component of it. Both are carried through composition unchanged
(§6, §7).

**Everything here is data.** A grammar is the projection of a validated
`*.feature.cxd`; a composed grammar is a CX document (§8) — readable, diffable,
agent-manipulable like any other CX value.

---

## §2. Qualified names — the namespace rule

> **N-COMPOSE-0 (namespace).** Every verb and noun in a composed grammar is
> **fully qualified by its owning feature's name**: `<feature>/<verb>`,
> `<feature>/<noun>`. Feature names are unique within a XAP (precondition W1, §4).
> Therefore **verb/noun collisions cannot occur in a composed grammar** — they are
> excluded by construction, not detected and repaired.

This is the normative reading of the approved lexicon's vocabulary-as-namespace
principle (you reference *a feature's vocabulary* and its verbs belong to it —
`xap.md`, the Vocabulary lexicon entry). The bare (unqualified) form of a verb
remains speakable; its resolution is defined in §5.

Frames and keys are deliberately **not** namespaced: they are the shared rulers owned
by no feature. Two features registering onto the key `product-id` or the frame `geo` is not
a collision — it is the *join seam*, the entire point of the machinery. What must
agree at a shared frame/key is checked by W2/W3 (§4).

---

## §3. The composition operator

```
compose : Grammar × Grammar → Grammar | [!compose-conflict …]
```

For features F₁ … Fₙ enabled in one XAP (the `[features]` list of the `*.xap.cxd`):

- **V(G) = ⋃ᵢ qualify(V(Fᵢ))** — disjoint union (N-COMPOSE-0).
- **N(G) = ⋃ᵢ qualify(N(Fᵢ))** — disjoint union.
- **R(G) = ⋃ᵢ scope(R(Fᵢ))** — each rule keeps its owning-feature scope. A rule may
  reference (a) its own feature's verbs/nouns, (b) frame/key predicates over the shared
  rulers, and (c) — for composite features only — the qualified verbs/nouns of the
  features in its `uses` set. A rule may **not** reach into an unrelated feature's
  grammar; cross-feature constraints are expressed over frames/keys or by authoring a
  composite. This is what keeps `independent` coupling genuinely independent.
- **Φ(G), K(G)** — merged by family / key-name. Multiple registrations onto one
  frame/key accumulate; they are how nouns become mutually comparable.

**Failure is a value.** If any well-formedness check (§4) fails, `compose` yields
`[!compose-conflict code=… at=… detail=…]` on the failure channel (SAP §1 — same
discipline as the approved cascade: a rejected intent is a value, not a crash). A XAP
with a conflicting feature set does not start degraded; it does not start, and says
exactly why.

### §3.1. Algebraic laws (normative, fixture-checked)

| Law | Statement |
|---|---|
| **commutativity** | `compose(A, B) ≡ compose(B, A)` — enable order never matters |
| **associativity** | `compose(A, compose(B, C)) ≡ compose(compose(A, B), C)` |
| **identity** | `compose(A, ∅) ≡ A` — the empty feature set is the unit of the operator. **∅ has no surface spelling, deliberately** (see below); this row states an algebraic property, and it is the one law in this table that is *not* fixture-checked, because it cannot be written down. |
| **idempotence** | `compose(A, A) ≡ A` at the grammar level (enabling the same feature twice in a `*.xap.cxd` is a W1 violation; the law governs the operator, not the wiring) |
| **closure** | the exported grammar of a **composite feature** is itself a `(V, N, R, Φ, K)`; composites compose like any base feature |

Equality `≡` is structural equality of the composed-grammar document under canonical
form (`core/canonical.md`) — set-semantics for the unions, so ordering is irrelevant.

**Why ∅ has no spelling (normative, and a deliberate trade).** Every candidate
spelling of the unit is indistinguishable from the accident that `CXER4874`
exists to catch. The zero-argument call is the obvious one, and it is exactly
what a XAP produces when its feature files were renamed, moved, or not yet
written — the shape an adopter meets first. A named `[feature]` contributing
nothing is not a unit either: it still joins the composed grammar's `[features]`
list and so moves the Tier-1 hash, and `feature.cxs` requires `[nouns]` to carry
at least one `[noun]`, so it cannot be written at all. That leaves no way to
name ∅ that is not also a way to compose nothing by mistake.

So the identity row states a property of the operator that the surface cannot
express, and we accept that cost knowingly: composing nothing has no use, while
*reporting* a composition of nothing as a pass has a large cost — the green is
load-bearing in the reader's mind and carries no information. The law's
practical content — that composition is a function of the feature SET, so
supplying no additional features changes nothing — remains fixture-checked by
the commutativity, n-ary order-independence and idempotence cases.
Because composition is a pure function of the feature set, the composed grammar is
**deterministic and content-addressable**: the same feature set always yields the same
composed-grammar document, hence the same Tier-1 hash. Distribution builds on this
(see the feature-distribution spec).

---

## §4. Compose-time well-formedness (the gate)

`compose` runs these checks; all violations are reported (not first-failure), each as a
`[!compose-conflict]` entry:

| # | Check | Rejects |
|---|---|---|
| **W1** | **feature-name uniqueness** — all enabled feature names distinct | two features named `orders` |
| **W2** | **key compatibility** — every registration onto one key name carries the same value type/shape | `product-id` registered as `::int` by one feature and `::string` by another |
| **W3** | **frame-registration validity** — each `via` names an existing field of the registering noun, typed to the family's coordinate type (`geo`: position; `time`: instant/interval; `value`: ordered scalar) | registering a `::string` name field onto the `geo` frame |
| **W4** | **rule consistency** — the statically decidable rule classes are checked pairwise over the merged rule set: a `mandate` and an `exclusion` may not cover the same (qualified verb, condition) pair; `ordering` rules may not form a cycle; `dependency` targets must exist in the composed grammar | feature A mandates what feature B excludes under the same condition; `A/x before B/y before A/x` |
| | *Structured targets.* A rule participates in W4's static checks by declaring machine-readable targets alongside its prose `statement`: `verb=` (the covered qualified verb), `when=` (the condition tag) for `mandate`/`exclusion`, `after=` for `ordering`, `requires=` for `dependency`, and — for `validity` rules — `nouns=` (space-separated noun names, §4.4: the floor/ceiling edge declaration; existence-checked as W5-class when declared). A prose-only rule is runtime-class (the envelope validator) and is not statically checked — declaring targets is what opts a rule into the compose-time gate. | |
| **W5** | **derived-reference existence** — every composite's `uses` entry, **every qualified noun reference in a derived noun's `[from …]`**, and every derived verb's constituent resolve to members of the composed grammar | a composite joining over a feature that is not enabled; `[from 'orders/order' 'nosuchfeature/nothing']` |
| **W6** | **utterance resolvability** — the resolution function ρ (§5) is total and deterministic over the composed grammar: every bare verb term yields exactly one qualified verb *or* a well-formed ambiguity value; never zero-or-crash | (structural — checked by construction of the bare-term index) |
| **W7** | **derived-noun write exclusivity** — no verb of the composed grammar declares `[writes]` onto a `derived=true` noun; a derived noun is **deriver-reserved** (§4.2). The sibling of the W5 `[from …]` existence check: W5 rules what a derived noun names, W7 rules who may fill it | `[verb name=raise-alert … [writes 'delayed-shipment/delay-alert']]` in any enabled feature or composite |

#### §4.1 `[from …]` — the derived-noun source list (normative)

A `derived` noun declares what it is derived FROM as a list of **qualified noun
references**, one per string item:

```
[noun name=delay-alert derived=true
  [field name=order-id type=string]
  [from 'orders/order' 'shipments/shipment']]
```

- **One or more** entries; each is a single `<feature>/<noun>` reference
 (the §3 N-COMPOSE-0 qualified form). A `derived` noun with no `[from …]`,
 or with an empty one, is a W5 violation — a derived noun that says nothing
 about its source is exactly the unchecked free text this rule replaces.
- Each reference **MUST resolve to a noun of the composed grammar** (W5, §4).
 The check is fail-closed: an entry that is not a qualified noun of the
 composed grammar is a conflict, whatever it looks like. A whitespace-bearing
 string is therefore ONE (unresolvable) reference, not a separator-joined
 list — the shape is deliberately unambiguous rather than lenient.
- **Join semantics are UNSPECIFIED — production is not.** `[from …]` names
 the sources; it does not say how they are combined, and no join algebra is
 committed by this rule — describing HOW the sources combine stays ordinary
 CX inside the noun's **declared deriver** (§4.2), never a grammar
 construct. A derived noun's state route holds what its deriver emitted to
 it, not the result of an engine-evaluated join.

> **Why the references are checked even though the join is not.** `[from …]`
> is the only place a derived noun says what it is derived from. Leaving it as
> free text while `uses` and `constituents` beside it were strict meant the one
> part of a composite that describes its actual content was unvalidated — and a
> reader could reasonably take a passing gate as having covered it (#840). The
> reference is checkable without committing to a join semantics; those are
> separable, and only the first is settled here.

Note the shape differs from the sibling `[constituents 'a/b c/d']`, which is a
single space-separated payload. `[from …]` takes one reference per string item.

Rule kinds outside W4's static classes (`validity` and condition-dependent constraints)
remain **runtime** checks — they are exactly the envelope/validator machinery the
approved trust model already runs per intent (`xap.md` §21.6); composition adds no
second enforcement path.

**When the gate runs.** At XAP load (reading the `*.xap.cxd`), and again at any runtime
surfacing/enabling of a feature (the surfacing axis — summoning a feature into a running
XAP re-runs the gate against the extended set *before* wiring). Installing a distributed
feature runs the same gate at install time (feature-distribution spec) — one gate, three
call sites.

#### §4.2 Derivation semantics — the deriver as actor (normative; R8.1–R8.4)

A derived noun is **computed by a declared deriver**: a component bound in
the wiring layer (`*.xap.cxd ⊢ xap.cxs`, a `[deriver]` entry inside
`[principals]`) that reads the constituent streams, applies the derivation
in ordinary CX, and **emits the derived noun's events as an accountable
journal actor** (`actor: deriver:<name>`), through the runtime's ordinary
component binding and append path — never a bypass.

```
[principals
  [deriver name=detect produces='delayed-shipment/delay-alert'
           package='./detect.cx'
           doc='Joins orders past their promise with undelivered shipments.']]
```

1. **The deriver is a principal.** It sits beside `[role]` and `[agent]`
   because it is the same kind of thing: an actor whose acts are
   attributable on the journal. Run assembly reads ONE block to know every
   actor. `produces=` names exactly one qualified `derived=true` noun of
   the composed grammar (an unresolvable or non-derived target is a
   load-time refusal); a grammar may bind at most one deriver per derived
   noun.
2. **Derived nouns are deriver-reserved (W7).** No grammar verb may
   declare `[writes]` onto a derived noun — the compose gate refuses
   (`:w7`). A manual override is modeled as a **source noun the deriver
   folds** (listed in `[from …]`), never as a write verb on the derived
   noun: the correction is then attributable input, and the derivation
   stays the only producer.
3. **`[from …]` is the read-authority envelope.** The deriver's read set
   MUST resolve within its noun's `[from …]` set — checked at run
   assembly. Provenance is not documentation; it is the bound on what the
   producer may consume. Reads by everyone else are unrestricted, as for
   any noun.
4. **A derived noun without a producer refuses at run assembly.** Assembly
   over a grammar whose `derived=true` nouns are not all bound to a
   deriver refuses with `cx-err:CXER4875`, naming **every** unproduced
   noun (not first-failure). A bound-but-dead deriver is the dynamic case
   and is *observable* rather than refusable — the deriver is a journal
   actor, so staleness is visible, and a projection renders it honestly
   (`available=false` + reason; the P0-99 posture). A derived noun's view
   is never silently empty-as-if-clear.
5. **No join algebra is committed.** The derivation body is ordinary CX
   inside the deriver. Engine-evaluated derivation, if it ever lands, is
   an OPTIMIZATION of this same contract: the engine becomes the bound
   deriver, events still land in the noun's stream under the same actor
   discipline, and nothing else changes.
6. **The #800 boundary.** The analytics campaign owns queries you **ask**
   (read-side: aggregates, pushdown, windows). This section owns nouns the
   composition **promises** (write-side: events in the noun's stream, from
   a named actor). A deriver MAY use the query machinery internally; the
   contracts never merge.

#### §4.3 Archetype instantiation and the refinement contract (normative; R8.5, R8.6, R8.10)

An **archetype** is an immutable, content-addressed `[feature …]` document —
someone else's product, distributed at the vendor cascade level (P0-13). An
**instance** is derived from it by a **binding document owned by the
deriving tenant**, resolved cascade-style (P0-14 nearest-wins; which binding
document is in force is deployment resolution, not new machinery). CX ships
the MECHANISM; third parties ship catalogs (standing owner ruling at #866's
filing).

```
[instance of='sha2-256:<hex of the archetype document>' name=product-review
  [rename field=attestation/subject label='Product']
  [add [field name=verified-buyer type=bool] on=attestation]
  [tighten verb=approve consequence=irreversible]
  [select [not-offered verb=revoke why='Reviews are withdrawn by support, not shoppers.']]]
```

`[$xap:instantiate ARCHETYPE BINDING]` is a **pure function** — archetype
document in, binding document in, the **effective `[feature …]` document**
out (or a refusal). Compose's contract is untouched: it receives ordinary
feature documents, however they were derived; instantiation is its own
content-addressable step (the `[$xap:compose]` purity precedent), so the
same (archetype, binding) pair yields the same effective document
everywhere, forever.

1. **The pin is load-bearing.** `of=` MUST equal the Tier-1 content address
   of the archetype document presented; a mismatch refuses
   (`cx-err:CXER4879`). An instance is derived from an EXACT base — never
   from "whatever the vendor ships today".
2. **The refinement contract — four verbs admitted, everything else
   structurally impossible:**
   - **RENAME presentation** — `label`/`doc`/`summary` of a named noun,
     field, or verb. Names of record are not renameable: the vocabulary has
     no slot for it.
   - **ADD** — new fields on existing nouns, new verbs, new rules. Adding
     is always a narrowing in this rule model (every rule kind constrains);
     an added name MUST NOT collide with an inherited one (that is
     repurposing, below).
   - **TIGHTEN** — a verb's effect signature may move only up the
     rank lattice (§6's derived-floor ranks reused): scope may narrow,
     consequence may rise, effect may strengthen. A `[tighten]` that
     widens any axis refuses.
   - **SELECT** — the W16-b subsetting vocabulary (`offer` /
     `not-offered`-with-why), carried onto the effective document as a
     `[selection …]` child for the surface gate to hold. Selected names
     MUST exist.
3. **The two refusals that keep a catalog composable:**
   - **`cx-err:CXER4877 E_XAP_ARCHETYPE_REPURPOSE`** — the binding gives an
     inherited name a different meaning: an `[add]` whose verb/field/rule
     name already exists in the archetype, or a `[rename]`/`[tighten]`/
     `[select]` naming a member that does not exist (a refinement of
     nothing is a new meaning wearing a familiar shape).
   - **`cx-err:CXER4878 E_XAP_ARCHETYPE_LOOSEN`** — the binding weakens an
     inherited rule, type, or effect signature. The load-bearing reason:
     substitutability — one loosened instance means no consumer can trust
     any instance, and the catalog stops being composable. There is no
     escape hatch; the honest release valve is authoring your own feature.
   Removal is not refused because it cannot be spelled: the binding
   vocabulary has no remove.
4. **Qualified self-references follow the rename.** An archetype's internal
   ordering rules, `[constituents]`, and `[from …]` lists cite its own
   members by its own feature name; the effective document is those same
   members under the instance's name, so every `<archetype>/<member>`
   self-reference rewrites to `<instance>/<member>`. (Without this, any
   archetype carrying an ordering rule would fail W4 in every instance —
   the reference pair's fixtures pin it.) References to OTHER features are
   untouched.
5. **Provenance rides the effective document** as an
   `[instantiated-from archetype='sha2-256:…' binding='sha2-256:…']` child —
   recomputable, informative, and what the re-bless discipline reads.
6. **Re-bless, never silent propagation (R8.5).** An archetype fix reaches
   an instance by ONE recorded act: the binding's `of=` moves to the new
   base address and the instance re-instantiates, with the whole contract
   re-checked against the new base (a v2 that turns yesterday's `[tighten]`
   into a widening refuses at re-bless — the gate holds at every
   generation). Un-re-blessed instances keep their pinned address and are
   exactly as valid as they were. Fleet-scale auto-re-bless is a POLICY
   ACTOR on the record (the 5b auto-approve precedent) — categorically
   different from silent supply-chain propagation. Rejected shapes,
   recorded: copy-with-provenance (a fork with a birth certificate);
   mutable `extends=` (silent propagation).
7. **Graduation (R8.10, shared with the granularity discipline).**
   Archetype status is EARNED: the cohesion gate green, plus TWO genuinely
   different instantiations named and recorded as evidence — different
   composing surface/tenant, non-overlapping `uses` neighborhoods, not two
   skins of one deployment. The checking instrument is the granularity
   work's; this section owes only the bar.

The distribution half — how archetype packages are pinned, signed, and
acquired — is the feature-distribution & market spec's, unchanged: an
archetype travels as an ordinary sealed feature package whose Tier-1 hash
is exactly the `of=` pin.

#### §4.4 Granularity — the floor, the ceiling, and graduation (normative; R8.7–R8.10)

Feature granularity stops being taste and becomes a CHECK. The
REST-vs-microservices granularity wars were unwinnable because boundaries
were informal (org charts) and expensive (every boundary bought latency and
ops burden); here a boundary costs a document reference and a feature is a
formal object, so boundary correctness is computable. Two rejected framings,
recorded: *as small as possible* (the aggregate floor below refuses it) and
*size by taste* (the ceiling below replaces it).

**The edge set (R8.9) — declared semantic edges only.** The feature's
internal graph has its nouns and verbs as nodes and exactly these edges:

- **verb ↔ noun** — the verb's `[reads …]` / `[writes …]` targets;
- **verb ↔ verb** — ordering/dependency rules over structured targets
  (`verb=` with `after=`/`requires=`) and a derived verb's
  `[constituents]`;
- **noun ↔ noun** — a validity rule's **checked noun list** (below),
  sub-noun typing (a field whose `type=` names a sibling noun,
  `repeats=` or not), and a derived noun's `[from …]`.

**Keys and frames are NOT edges** — a key is where features MEET; counting
shared keys as cohesion would make every document one component and kill
the gate. Inside a composite, `[from …]` and rule references to OTHER
features' members are legitimate cross-feature edges and are excluded from
the composite's own component count.

**Validity rules gain a checked noun list (the R8.8 rider, ruled 3a).**
A validity rule declares the nouns it spans as `nouns=` — space-separated
noun names, the exact `verb=`/`after=`/`requires=` structured-target
precedent: declaring opts the rule into compose-time existence checking
(an unresolvable name is a W5-class conflict); a prose-only rule stays
runtime-class and is invisible to the floor and ceiling, which is why the
declaration is worth writing.

```
[rule name=review-cites-purchase kind=validity nouns='review order'
  [statement 'A verified review MUST cite an order containing the product.']]
```

1. **The floor — too small (R8.7).** A rule or ordered choreography binding
   two nouns (or ordering two verbs) means ONE feature: a base-feature
   split that would strand such a rule is refused by the rule's own edge —
   the members it binds are one component, and a component is never split.
   The legitimate escape is PROMOTION into a composite declaring `uses`
   over both bases; split-with-promotion earns its documents only when
   each base is independently meaningful (the graduation bar).
2. **The ceiling — too big (R8.8).** Build the graph from the document
   alone; **two connected components are two features wearing one name.**
   The instrument is `[$xap:cohesion FEATURE]` — pure, env-free — returning
   a report value: the component count, each component's member set, and
   the edge list. It ships REPORT-FIRST (refusal arrives only by a later
   ruling, the W16-b graduation path), and run against an existing feature
   it is the **split advisor**: the components it reports are the split it
   would accept. Shipping "big feature A" as one product stays legitimate —
   author a1/a2/a3 at the cohesion boundary and sell the COMPOSITION as A;
   a later split is then packaging, not migration, and client journals
   never move.
3. **Graduation — context bias (R8.10).** Designed-for-one-XAP bias cannot
   be seen by inspection, only by a second composition failing to fit. A
   feature is PRIVATE until it survives TWO genuinely different
   compositions — different composing surface/tenant, non-overlapping
   `uses` neighborhoods, not two skins of one deployment — and the second
   composition is the marketplace entry gate. The same bar is archetype
   status (§4.3.7).

Conformance: §9 family 12. The disclosed estate consequence (R8.9, ruled
with eyes open): the reference `orders` feature failed the ceiling as
first written — its `line` noun was edge-less (`order-id` was a naming
convention, not a declared relationship); the fix is one declared
relationship (`[field name=lines type=line repeats=true]` on the order
noun), which rides the instrument's landing.

---

## §5. One language — bare-term resolution ρ

The composed grammar is not just a merged registry; it is the **single interaction
language**. A principal or agent utters terms without caring which feature owns them
("highlight the stock-outs", `[do highlight …]`). Resolution is normative and
deterministic:

```
ρ(term, args, context) → qualified-verb | [!ambiguous-verb candidates=…] | [!unknown-verb term=…]
```

1. **Qualified always wins.** `[do inventory/recount]` (or the spoken "inventory's
   recount") resolves by lookup; steps 2–4 never run.
2. **Unique owner.** If exactly one feature in the composed grammar defines the bare
   term, resolve to it.
3. **Context narrowing** (in order, first unique winner):
   a. the feature owning the **panel in focus** (foreground, then containing surface);
   b. the feature(s) owning the **nouns bound in `args`** — if the argument bindings
      touch nouns of exactly one candidate, resolve to it;
   c. the candidate whose `reads`/`writes` sets are satisfiable in the current surface
      (candidates whose nouns are not present at all are dropped).
4. **Ambiguity is a value, not a guess.** If more than one candidate survives, ρ yields
   `[!ambiguous-verb term=… candidates=[…qualified…]]`. The composer/Radar MUST turn
   this into a disambiguation prompt (the fuzzy-human → precise-intent loop,
   `xap.md` §18.2); a client MUST NOT auto-pick. If zero candidates exist,
   `[!unknown-verb]`.

Resolution happens **before** the cascade: what commits to the journal is always the
qualified intent (attribution and audit are exact); the bare term is surface
convenience only.

> **N-COMPOSE-1 (no silent rebinding).** Extending a composed grammar (enabling or
> installing a feature) never silently changes what an utterance means: for any
> `(term, args, context)` that resolved to qualified verb *v* before the extension,
> ρ afterwards yields either *v* or an `[!ambiguous-verb]` value that lists *v* among
> the candidates. It never resolves to a different verb without a prompt. Qualified
> utterances are absolutely stable (step 1 is untouchable by extension).

N-COMPOSE-1 is the formal content of "seamless integration": plugging features in can
only ever *add* things to say and, at worst, ask you which of two meanings you intended
— it can never make yesterday's sentence quietly do something else.

---

## §6. Effect signatures & governance under composition

**Derived verbs compose their signatures deterministically.** A composite feature's
verb declares the constituent verbs it invokes — `[constituents <qualified-verb> …]`
in its `[verb …]` block (this is also the N-COMPOSE-2 grant set, and it lands in the
composed grammar's `[constituents]`, `grammar.cxs`). Its signature floor derives from
them:

- `effect` — `act` if any constituent it invokes is `act`, else `arrange` if any is
  `arrange`, else `observe`. (Writes domain state anywhere ⇒ act; touches composition
  structure ⇒ arrange; pure read ⇒ observe.)
- `scope` — `shared` if any constituent is `shared`, else `local`.
- `consequence` — the maximum along `none < reversible < irreversible`.

Hand-declared signatures on derived verbs MAY *strengthen* (raise consequence, widen to
shared) but MUST NOT weaken the derived floor; a weaker declaration is a W5-class
conflict.

> **N-COMPOSE-2 (no authority amplification).** Emitting a composite/derived verb
> requires **every grant its constituent verbs require**. Composition never launders
> authority: wrapping `door/unlock` inside a friendly composite does not lower the
> grant, the consequence gate, or the guardian condition that `door/unlock` itself
> demands. The PEP evaluates the constituent set, not the wrapper's name.

Grants attach to qualified verbs/nouns and pass through composition **unchanged** —
governance is finer than the feature (composition model §6) and is orthogonal to the
merge. The dial, envelopes, and guardian conditions all key on qualified names, so
nothing about them is composition-sensitive.

### §6.1. The intent's parameter list — a verb's signature is in its own grammar

> **N-COMPOSE-7 (self-describing signature).** A verb's `[intent [do :<verb> …]]`
> clause carries the verb's **parameter list**: one `[<param>]` per value the
> emitted intent takes, in emission order.
>
> ```
> [verb name=place-order effect=act scope=shared consequence=reversible
>  [intent [do :place-order [id] [customer] [promised-at]]]
>  [writes order]]
> ```
>
> A grammar in which a verb's parameters are knowable **only** from a client's
> component registration is not well-formed under this clause: the feature
> document would be an incomplete description of the feature it defines, and two
> clients would be free to disagree about the verb's arity with nothing to
> adjudicate between them.

**Why this is a grammar rule and not a client convention.** A feature document is
the single statement of what a feature *is* (§1: everything here is data). The
effect signature already lives there because the PEP needs it; the reads/writes
sets already live there because the read model needs them. The parameter list is
the same kind of fact and had the same claim on the document — it was simply
missing, and every consumer that needed it was inferring it instead.

The inference in question is **the noun a verb `[writes]`**. It is the best
guess available from feature documents alone, and it is wrong in the ordinary
case: a noun carries the fields of the *record*, a verb takes the arguments of
the *act*, and the two differ wherever the record holds anything the actor does
not supply — an assigned id, a server clock, a computed total. A consumer
inferring from the noun therefore over-offers, and does so silently.

**Consumer obligation (normative).** A consumer that needs a verb's parameters:

1. MUST use the declared list when the `[intent]` clause states one;
2. MAY fall back to the written noun's fields when it does not — degrading to
   the previous, over-offering behaviour rather than to an empty signature, so
   that a document predating this clause still projects something usable;
3. MUST NOT treat the fallback as authoritative — in particular it MUST NOT
   report a verb's arity from the noun as though the grammar had declared it.

**Composition.** The parameter list passes through composition **unchanged**,
qualified with its verb (§2). A derived verb declares its own list; unlike the
effect signature (§6) there is no floor to derive, because a wrapper's arguments
are not the union of its constituents' arguments — a composite exists precisely
to take fewer, or different, arguments than the verbs it invokes.

*Provenance: #787 DP1 ruling 4b (owner, 2026-08-17). The projection under
`cx-x/ux` was the consumer that surfaced it: `feature-form` derived a form's
fields from the written noun and offered five controls for a verb that takes
three, with the runtime discarding the extra two.*

---

## §7. Requirements under composition

Requirement ⟺ verb traceability (authoring process §2) lifts to the composed grammar:
every qualified verb still traces to a requirement in its owning feature's spec, and a
**composite feature carries its own requirements** for its derived verbs/nouns (it is a
feature; the closure law is not just structural). The composed grammar therefore has
full requirement coverage by construction — there is no such thing as a composed verb
with no requirement behind it. Acceptance criteria remain the conformance fixtures of
their owning feature; composition adds only the fixtures of this spec (§9).

---

## §8. The composed grammar as data — `grammar.cxs`

The output of `compose` is a document `[grammar …]` validating against
[`xap_schemas/grammar.cxs`](xap_schemas/grammar.cxs) (draft alongside the other three):

- one `[verb]` / `[noun]` entry per qualified member, each carrying
  `feature=` **provenance**;
- the merged `[frames]` / `[keys]` tables with every registration listed
  (`feature=` + `via=` per registration) — the join seams made visible;
- the scoped `[rules]` set;
- a `[bare-terms]` index: every bare term → its candidate set (the precomputed input
  to ρ, and the artifact a client/agent reads to know "what can be said here").

Consumers: the **composer feature** (composition model §11.3) reads it to compose;
the **Radar/resolver** reads it for context→candidate ranking; **clients** read it as
the control-vocabulary source; the **feature-distribution gate** reads it to run W1–W6
against a candidate install; **`cx validate`** checks it like any `.cxd ⊢ .cxs` pair.
It is a *projection* (recomputable from the feature specs), never hand-edited, and
deterministic per §3.1 — hence cacheable and content-addressable by its Tier-1 hash.

### §8.1. Function surface (pure) & error codes

Four pure, deterministic, env-free functions on `cx-xap` (no journal, no PEP, no
clock — composition is a function of its inputs):

| Function | Signature → result |
|---|---|
| `[$xap:compose FEATURE …]` | variadic over parsed `[feature …]` documents (each `⊢ feature.cxs`). Returns the composed `[grammar …] ⊢ grammar.cxs`. **Zero features raises `cx-err:CXER4874`** — see §3.1's identity row: ∅ is an operand, not the absence of operands, and a composition of nothing is refused rather than reported green. A W1–W6 violation raises `cx-err:CXER4870` whose error value carries **every** violation as a `[conflict code=:w1…:w6 at=… detail=…]` entry (not first-failure). A non-`[feature]` argument raises `cx-err:CXER4873`. |
| `[$xap:compose-report FEATURE …]` | same inputs; **never raises on conflicts** — returns `[compose-report ok=<bool> [conflict …]*]`. The tooling face of the gate (the distribution installer and the composer show this *before* anything wires); `compose` is the enforcing face. The two MUST agree: `compose` raises iff `compose-report` has `ok=false`. **Zero features therefore reports `ok=false`** carrying a single `[conflict code=:empty at='(no features)' detail=…]` — the `code=` vocabulary is `:w1…:w6` **plus `:empty`**, which is a vacuity refusal rather than a W-gate violation. Both faces decide it through the SAME predicate, so the agreement law holds by construction and not by parallel edits. |
| `[$xap:resolve GRAMMAR TERM CONTEXT?]` | ρ (§5). `TERM` is the bare or qualified verb term (string). `CONTEXT` is a map making the §5 narrowing inputs explicit: `{focus: <feature>, nouns: [<qualified-noun>…], present: [<feature>…]}` — the focus panel's feature, the nouns bound in the utterance's args, the features present on the surface; all optional. Returns the qualified verb name (string, e.g. `'orders/highlight'`). Ambiguity raises `cx-err:CXER4871` with `candidates=(<qualified>…)` on the error value; an unknown term raises `cx-err:CXER4872`. |
| `[$xap:grammar-hash GRAMMAR]` | the Tier-1 content hash (hex string) of the composed grammar under canonical form — the §3.1 equality oracle and the distribution spec's §7 supply-chain witness. |
| `[$xap:instantiate ARCHETYPE BINDING]` | §4.3: pure — the archetype `[feature …]` document plus an `[instance …] ⊢ instance.cxs` binding yields the **effective `[feature …]`** (with its `[instantiated-from …]` provenance child), or raises `cx-err:CXER4877/4878/4879` per the refinement contract. Compose receives the result as an ordinary feature. |
| `[$xap:cohesion FEATURE]` | §4.4: pure — the feature's internal graph under the R8.9 edge set, as a report value: `[cohesion-report feature=… components=N [component [member kind=… name=…]…]… [edge kind=… a=… b=…]*]`. Report-first (never refuses); two components are two features wearing one name, and the components ARE the split it would accept. |

**Error codes** (from the `cx-xap` band — registered `CXER4850–4879`
after the 2026-08-05 xap.md §8 amendment (audit C5: the original
`…–4949` proposal yielded `4890–4949`); next free block after the
approved §8 registry's `…4862`; fold into that registry at graduation):

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4870` | `E_XAP_COMPOSE_CONFLICT` | the W-gate rejects — error value carries all `[conflict]` entries (§4) |
| `cx-err:CXER4871` | `E_XAP_VERB_AMBIGUOUS` | ρ: >1 candidate survives narrowing — `candidates=` lists them (§5); the composer MUST prompt, never pick |
| `cx-err:CXER4872` | `E_XAP_VERB_UNKNOWN` | ρ: zero candidates (§5) |
| `cx-err:CXER4873` | `E_XAP_FEATURE_INVALID` | a `compose`/`compose-report` argument is not a schema-valid `[feature …]` document |
| `cx-err:CXER4874` | `E_XAP_COMPOSE_EMPTY` | `compose` is given **no features at all** (§3.1 identity row) — a gate over the empty set has verified nothing, so it refuses instead of returning the unit. `compose-report` reports `ok=false` with `[conflict code=:empty …]`. This refuses the *call*, never a feature: any composition with at least one feature proceeds to the W-gate as before, however little that feature declares. |
| `cx-err:CXER4875` | `E_XAP_DERIVED_UNPRODUCED` | run assembly (§4.2): a `derived=true` noun of the attached grammar has no bound `[deriver]` — the error value names **every** unproduced noun. Also raised when a `[deriver]`'s `produces=` does not resolve to a `derived=true` noun of the grammar, or when two derivers bind one noun. |
| `cx-err:CXER4876` | `E_XAP_DERIVER_READ_OUTSIDE_FROM` | run assembly (§4.2): a bound deriver's declared read slice falls outside its noun's `[from …]` set — provenance is the read-authority envelope. |
| `cx-err:CXER4877` | `E_XAP_ARCHETYPE_REPURPOSE` | instantiate (§4.3): the binding gives an inherited name a different meaning — an `[add]` colliding with an inherited name, or a refinement naming a member the archetype does not declare. |
| `cx-err:CXER4878` | `E_XAP_ARCHETYPE_LOOSEN` | instantiate (§4.3): the binding weakens an inherited rule, type, or effect signature — a `[tighten]` that widens any axis. Substitutability is the reason; there is no escape hatch. |
| `cx-err:CXER4879` | `E_XAP_INSTANCE_INVALID` | instantiate (§4.3): the `of=` pin does not match the archetype document's content address, or the binding document is malformed. |

Conformance fixtures for this section live at `conformance/stdlib/xap-compose.cxd`
(authored spec-first; the M0 engine — pure env-free builtins in
`vcx/code/stdlib_xap.v` — runs them green and the gate manifest enforces them).

### §8.2. Runtime integration — the composed grammar at the PEP

The composed grammar becomes **operative** when it is attached to a runtime:
`[$xap:run {… grammar: G}]` accepts the composed `[grammar …]` document (the §8
projection) and pins it as that runtime's control vocabulary. Attachment changes
the emit cascade in exactly the two ways this spec already mandates:

1. **Resolution before the cascade (§5).** Every emitted intent's verb term is
   resolved through ρ against the attached grammar *before* the PEP runs: a
   qualified term must exist in the grammar (else `cx-err:CXER4872`); a bare
   term must resolve uniquely (surviving ambiguity raises `cx-err:CXER4871`
   with `candidates=` — the runtime never guesses, exactly like
   `[$xap:resolve]`); and the **committed journal event carries the qualified
   intent**, so attribution and audit are exact even when the surface utterance
   was bare.
2. **N-COMPOSE-2 at the PEP (§6).** For a derived verb, the PEP evaluates the
   **transitive constituent grant set** — the leaf (non-derived) verbs reached
   by following `[constituents]` through the grammar — and admits the emit only
   if the actor holds *every* leaf grant over that constituent's slice. The
   wrapper's own name is never consulted: a grant naming the composite conveys
   nothing, and a denial names the missing **constituent**, exactly as emitting
   that constituent directly would. A constituent naming a verb absent from the
   grammar is required literally (fail-closed; the W5 existence check makes
   this unreachable for gate-passed grammars). Constituent cycles are
   W5-rejected at compose time, so expansion terminates on gate-passed input
   (the expander still carries a visited set — defense, not semantics).

`[$xap:why-allowed]` answers over the same set: for a derived verb it reports
`allowed=true` iff every leaf-constituent decision permits — it never reports
the wrapper as allowed while a constituent grant is missing.

A runtime with **no** attached grammar keeps the pre-composition cascade
semantics (bare verbs route by component `emits`; back-compat for the bundled
demos). Attachment is what switches on §5/§6 enforcement — compose-gate time
(load, summon, install) is exactly when a grammar is (re)attached.

Conformance: §9 family 6 (same fixture corpus, `xap-compose.cxd`).

---

## §9. Conformance fixtures (to author with the implementation)

Fixture families, each an executable `.cxd` case (acceptance-criteria style, run by the
toolchain):

1. **Algebra** — commutativity/associativity/identity/idempotence over 3 toy features
   (structural equality of composed documents under canonical form).
2. **Namespace** — two features with same-named verbs/nouns compose cleanly; both
   qualified members present; bare-term index lists both.
3. **W-gate** — one fixture per W1…W5 violation, each asserting the exact
   `[!compose-conflict]` code + `at=`; a multi-violation fixture asserting *all*
   conflicts are reported.
4. **ρ-resolution** — unique-owner; focus-narrowing; args-narrowing; ambiguity value
   (asserting candidate list); unknown term; qualified bypass.
5. **N-COMPOSE-1** — a before/after pair: utterance resolves to `orders/highlight` with
   orders alone; after enabling `stock-outs`, the same utterance yields
   `[!ambiguous-verb]` containing `orders/highlight` — and asserts it does **not**
   silently resolve to `stock-outs/highlight`.
6. **N-COMPOSE-2 / runtime integration (§8.2)** — a composite wrapping a
   high-consequence verb: emitting it without the constituent grant is
   PEP-rejected exactly as the constituent would be (the denial names the
   constituent); granting the *wrapper's* name conveys nothing; granting every
   leaf constituent admits the emit; the grant set expands transitively through
   nested composites; with a grammar attached, a bare emit resolves through ρ
   (unique → the committed event is qualified; ambiguous → `CXER4871`; unknown
   → `CXER4872`); `why-allowed` on a composite reflects the constituent
   decisions, never the wrapper.
7. **Signature derivation** — derived verb over observe+act constituents derives
   `act`/`shared`/max-consequence; a weakening declaration is rejected.
8. **N-COMPOSE-7 (parameter list)** — a verb declaring `[intent [do :v [a] [b]]]`
   exposes exactly `(a, b)` to a consumer, in that order, regardless of the
   fields of the noun it writes; the same verb with a bare `[intent [do :v]]`
   falls back to the written noun's fields; a consumer reporting arity
   distinguishes the declared case from the fallback. Pinned against
   `reference/shop/` (below), whose act verbs declare their lists.
9. **Worked reference-instance case** — **LANDED** at `reference/shop/`
   (#726), pinned by the `test_reference_app_*` family in
   `vcx/tests/xap_umbrella_test.v`. Two base features (`orders`,
   `shipments`) that know nothing about each other + the composite
   (`delayed-shipment`) that joins them over the shared `order-id` key and
   `time` frame: composes clean through this gate, both faces agreeing; the
   derived `delay-alert` noun resolves; the derived verb's signature is
   taken from its constituents rather than declared; ρ is exercised over a
   bare term the two bases deliberately share, so ambiguity, the qualified
   bypass and N-COMPOSE-1 are all demonstrated on the same pair; and a base
   feature reaching across to another's verb is refused as a W4 conflict.
   (This succeeds the external reference XAP that validated the model
   before it became an independent project.)
10. **Derivation (§4.2)** — the deriver folds its sources and the derived
   noun's route fills under `actor: deriver:<name>` (the positive case); a
   grammar with a `derived=true` noun and no bound deriver refuses assembly
   with `CXER4875` naming the noun; a verb declaring `[writes]` on a
   derived noun is a W7 compose conflict; a deriver whose declared reads
   escape `[from …]` refuses with `CXER4876`. Pinned against
   `reference/shop/` (the `detect` deriver producing
   `delayed-shipment/delay-alert`).
11. **Instantiation (§4.3)** — one archetype, two genuinely different
   bindings, both effective documents compose clean (the positive pair —
   pinned against `reference/archetypes/`); a stale `of=` pin refuses
   `CXER4879`; an `[add]` colliding with an inherited verb refuses
   `CXER4877` (the repurpose trap); a widening `[tighten]` refuses
   `CXER4878` (the loosen trap); a re-bless (the pin moved to the v2 base)
   re-checks the whole contract — the fix propagates to the re-blessed
   instance while the un-re-blessed sibling keeps its pinned base
   byte-identically.
12. **Granularity (§4.4)** — the reference estate under the cohesion
   instrument: `orders`/`shipments`/`delayed-shipment` each ONE component
   (after the `orders/line` declared-relationship fix — and the pre-fix
   two-component shape is itself pinned as the split-advisor case); a
   deliberately glued two-domain fixture reports TWO components naming the
   split; the break-test — gluing an unrelated noun+verb pair into a
   healthy feature — flips the report; a `nouns=` list naming a
   nonexistent noun is a W5-class conflict.

---

## §10. Graduation (into `spec/03-approved/xap/`, user G3 only)

On graduation this document lands as a **sibling normative spec** (modular companion —
`xap.md` stays the orchestrator core), plus these reconciliations in `xap.md` itself:

1. **feature ↔ capability** — complete the terminology cutover flagged in the lexicon:
   **feature** = the composition unit; **capability** = the §22.2 granted right, only.
   One pass, no dual-accept residue.
2. **Lexicon additions** — `grammar` (a feature's verbs+nouns+rules), `frame`, `key`,
   `composite feature`, `composed grammar`, `bare-term resolution (ρ)`.
3. **Invariant registry** — add **N-COMPOSE-0/1/2** to the frozen invariant set.
4. **Cross-refs** — the surfaces-&-composition section points here for the algebra;
   the augmentation section's coupling values are unchanged (this spec is the algebra
   *underneath* the three-axis model, not a revision of it).
5. **Schemas** — `grammar.cxs` graduates with `feature/xap/surface.cxs` into the
   toolchain (authoring process §7).

Prerequisite working docs to retire into rationale-companions on the same pass:
`xap_feature_composition_model.md` (vocabulary — stays as design rationale),
`xap_architecture.md` (positioning — already marked resolved).

---

**References:** [`xap_feature_composition_model.md`](../../_archived/xap_feature_composition_model.md)
(vocabulary, three axes, governance, §11 doctrine) ·
[`xap_authoring_process.md`](xap_authoring_process.md) (three layers, traceability) ·
[`xap_schemas/`](xap_schemas/) (feature/xap/surface/grammar schemas) ·
[`../xap/xap.md`](../xap/xap.md) (lexicon, cascade, PEP, trust,
augmentation, federation) · [`../core/canonical.md`](../core/canonical.md)
(canonical form for grammar equality) · the feature-distribution & market spec
(`spec/03-approved/xap/xap_feature_distribution_market.md` — the install-time caller of the §4 gate).
