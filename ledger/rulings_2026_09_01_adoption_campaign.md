# Rulings 2026-09-01 — adoption campaign (AD): the vendor↔adopter seam

**Status: PROPOSED — AD-1..AD-8 await owner acceptance. No execution before
the letters are ruled.** Rulings recorded before work per the #832 process
rule. Campaign label `adoption campaign`; umbrella/scoreboard **#1188**;
members **#1181–#1186** (admission of #1161/#1162 is AD-8). Target release
**v0.18**; work lands on `release/0.18`.

**Origin.** Six reports filed 2026-09-01 from a downstream deployment
adopting archetype instantiation and feature distribution, all probed
against the shipped `cx v0.17.0` (@ 9dcd2297c). They are one family, not six
strays: every one of them sits on the seam between a vendor's published
feature and a deployment that adopts it — how a deployment narrows what it
publishes (#1181, #1186), how a publisher evolves and retires it (#1182,
#1183, #1184), and the one line-of-business concern the tree names but does
not carry (#1185). The tree's authoring, composition, and install stories are
strong; the *after* story is where the gaps are.

**Standing constraints this packet respects.** Orthogonality is the surface
objective (no second vocabulary for anything that already has one — AD-5);
fail-closed over fail-silent (AD-1, AD-2); no stubs and no partial
implementations; every newly-admitted position carries positive AND negative
fixtures; spec edits are ruling-gated (G3 graduation stays owner-only).

---

## Measured evidence recorded before the letters

Two probes, run on `cx v0.17.0` @ 9dcd2297c, that change what AD-1 has to
answer.

**E-1 — `[selection …]` has no consumer anywhere in the shipped engine.**
`grep` over `vcx/`, `stdlib/`, `x/` finds `selection` at exactly ONE site:
`vcx/platform/stdlib_xap.v:4968`, where `[$xap:instantiate]` *constructs* it.
Nothing reads it. The agent-tools face is not a special case of the omission
— it is the general case.

**E-2 — the surface gate that §4.3 names as selection's consumer does not
consult it, and the omission is worse than inert: it is inverted.** The
W16-b gate (`x/ux.cx` `surface-verb-refusals`) reads `[not-offered]` from the
**surface** document (`$surface//not-offered`), never from the effective
feature document's `[selection …]` child. Probe: an archetype with
`press`/`purge`(irreversible)/`see`, an instance binding carrying
`[select [not-offered verb=purge why='This deployment does not permit purging.']]`,
and a surface offering `press`:

```
[err code=ux-refused [ux-refusal code=ux-verb-unaccounted verb=purge]]
```

Repeating the declaration on the surface document passes the gate — and
`purge` is still in the effective document's verb list:

```
[probe [verbs 'press' 'purge' 'see'] [selection 1] [gate true]]
```

So the sentence in `xap_grammar_composition.md` §4.3 — selection is "carried
onto the effective document as a `[selection …]` child **for the surface gate
to hold**" — is not true of the implementation. A binding's SELECT today
withdraws the verb from nothing and *adds* an obligation to the surface
author. SELECT is the only one of the refinement contract's four verbs with
no normative effect.

**E-3 — the distribution surface is built, so #1182/#1184 are implementable,
not spec-only.** `vcx/platform/stdlib_xap_dist.v` (1904 lines) ships
`pkg-tree`/`seal`/`sign`/`publish` (including the SEA-1 lineage stage)
/`fetch`/`verify`/`install`/`catalog`/`requires-closure` and the license
verbs. `cx schema compat` ships with a closed class set, declared renames,
and exit codes 0/1/2 — the exact shape AD-2 asks to mirror. `cx xap` already
exists as a subcommand family (`init`, `check-surface`).

**E-4 — CXER band scan (governance.md §9.6, run 2026-09-01).** The `cx-xap`
registered allocation is `CXER4850–4889` (host/runtime 4850–4863;
composition 4870–4879; xap-dist 4880–4889), with `4890–4899` reserved for
the **package schema-evolution seam** (4890/4891 in use, 4892–4899 free for
that seam). A tree scan finds `4864–4869` unallocated. AD-1's PEP-time
refusal therefore takes **`CXER4864`** — the sibling of `CXER4850`, the
other PEP denial — and AD-2's publish-time refusal takes **`CXER4892`**,
which lands inside the seam its reservation names. Codes are registered with
the ruling, ahead of implementation, per the registry invariant.

---

## AD-1 — `[selection …]` binds every consumption point, through the one PEP (#1181)

**Recommended: (a).**

- **(a) Selection is normative on the effective document and is consulted at
  the ONE place that already gates every face: the PEP.** §8.2 already
  resolves every emitted verb term against the attached grammar before the
  PEP runs; a verb carried by the effective document under
  `[selection [not-offered …]]` refuses there with a NEW code
  `cx-err:CXER4864 E_XAP_VERB_NOT_OFFERED`, carrying the binding's authored
  `why=` text. Because the agent orchestrator is an ordinary client emitting
  `[do …]` through the same PEP (xap.md R8/R7), the tools face, the wire, and
  the emitter inherit the answer with **no second evaluator** — which is
  exactly what [P0-45]'s "one ruling, all surfaces" asks for and what
  [P0-35] means by one evaluator. Second half, from E-2: the surface gate
  reads `[selection]` off the effective document, so a verb the binding
  withdrew is **accounted for** and the surface author is not made to repeat
  the declaration. Fixtures: a not-offered verb refused at the PEP; the same
  verb absent from the tools projection; the same verb accounted at the
  surface gate with no surface-side declaration; and the negative — an
  `[offer]`ed verb unaffected on all three.
- **(b) Selection is presentation-only; say so plainly.** Cheaper, and
  honest, but it makes SELECT the one refinement verb with no effect,
  leaves E-2's inverted obligation in place, and tells a tenant that
  `why='This deployment does not permit purging.'` is decoration. A tenant
  who actually wants the verb gone is then pushed to fork the archetype,
  which is the outcome the catalog exists to prevent.
- **(c) Selection binds the faces but not the PEP.** REFUSED: two answers to
  one question — the face says no, the wire says yes — is precisely the
  split [P0-35] was written to forbid, and it is the shape that makes a
  withdrawn irreversible verb reachable by anyone who reads the grammar.

**Why (a) is long-term best.** Selection is a *narrowing*, and narrowing is
the discipline the whole refinement contract is built on (ADD narrows,
TIGHTEN narrows, LOOSEN refuses). A narrowing that only paints is not a
narrowing. Binding it at the PEP costs one code and no new evaluator, keeps
provenance recomputable (the verb stays in the document — there is still no
remove), and makes the substitutability promise real: an instance's contract
means the same thing to every consumer of it.

**Recorded distinction.** `CXER4864` is deliberately NOT `CXER4872`
("no such verb in the grammar"): "this deployment does not offer it" and "no
such verb" are different facts, the first is authored to be shown, and an
integration that cannot tell them apart cannot be debugged (the oidc/saml
fine-grained-refusal precedent).

## AD-2 — contract evolution gets the SEA-1 treatment (#1182)

**Recommended: (a).**

- **(a) A contract classifier in the shape `cx schema compat` already
  establishes, wired into publish exactly where SEA-1 wired the schema one.**
  Three-valued over a CLOSED class set on `.feature.cxd` members:
  *additive* (a new noun/field/verb/rule) publishes silently; *narrowing*
  (`consequence` raised, `scope` narrowed, a rule tightened, `[req]` added)
  publishes classified; *reinterpreting* (a rename, a removal, a type change
  on an existing field, a `[key]` whose `via=` moves, a verb's `[intent]`
  parameter list changed) **refuses the publish** with a new
  `cx-err:CXER4892 E_XAP_PKG_CONTRACT_REINTERPRETS` naming the missing rule
  per change, unless an authored in-tree claim covers the exact old→new pair
  — the `…lineage.cx` mechanism SEA-1d already defines, extended with
  `[contract-lineage]` claims. Surfaced ahead of publish as
  `cx xap compat [--rename=verb/OLD=NEW]… OLD.feature.cxd NEW.feature.cxd`,
  exit codes 0/1/2, byte-for-byte the `cx schema compat` contract.
- **(b) Consumer-side by design; state it and stop.** REFUSED as the whole
  answer: the composer's re-pin diff (§6 step 7) is real but it fires after
  publication, only for utterance rebinding, and only for consumers who
  re-pin. The publisher — the one party who can still fix it — learns
  nothing.
- **(c) Classify and warn, never refuse.** REFUSED: every other gate on this
  path is fail-closed. A warning that the schema half refuses and the
  contract half merely mentions teaches adopters that the contract is the
  soft half, which is the opposite of true — the contract is what consumers
  compose against.

**Why (a) is long-term best.** The asymmetry the report names is real and
one-directional: `*.cxs` cannot ship a reinterpretation, `.feature.cxd` can,
and the contract is the load-bearing artifact. The classifier is decidable
because the contract vocabulary is closed — the same property that made
SEA-1 possible. Cost is bounded by precedent: one class table, one command,
one code, one claim kind, reusing the publish stage that already walks both
trees.

**Sequencing note.** AD-2's classifier is what AD-4's optional
"is the successor contract-compatible?" hint would consume. AD-4 does not
depend on it.

## AD-3 — content addresses: a stated promise, declared migrations, and a re-derivation command (#1183)

**Recommended: (a).**

- **(a) governance.md gains §9.5b beside the error-code promise, in the same
  shape:** content addresses (Tier-1 document addresses, and everything
  pinned by them — `hash=`, `of=`, `code:`) are **stable across PATCH
  versions**; through 1.0 a MINOR may move them ONLY via a declared
  canonicalization repair; after 1.0 a move requires a MAJOR bump. A
  declared repair ships two obligations, both mechanical:
  (i) a machine-readable `[address-migration release=X.Y.Z [class …]]`
  document in the release artifact naming every moved document class, so an
  adopter tests their corpus instead of reading prose about it; and
  (ii) `cx address recheck` — given a set of stored pins and the tree they
  point into, report per pin `resolved` / `moved to=<new>` / `unresolved`,
  exit 0/1/2 on the `cx schema compat` pattern. Conformance pairs a document
  in a moved class with one outside it, so the class boundary is testable.
- **(b) State "no promise".** Better than today's silence, and it is the
  honest floor if (a) is judged too binding — but it makes every adopter
  build the drill privately, and it discards a promise CX can actually keep
  at patch granularity today.
- **(c) Absolute stability within a major, effective now.** REFUSED: it
  either forbids canonicalization soundness repairs before 1.0 or forces
  each one to a major bump. Deterring a soundness fix is the worst outcome
  available here; the v0.17.0 repair was correct and must stay cheap to
  ship.

**Why (a) is long-term best.** The failure shape is the one the report
names: not one artifact broken but every pinned reference refusing at once,
during an upgrade, indistinguishable from a legitimately stale pin
(`CXER4879` is the mechanism working). A promise plus a tool is what makes a
soundness repair safe to ship, and both halves are small.

## AD-4 — planned supersession is an ATTESTATION, not a manifest element (#1184)

**Recommended: (a).**

- **(a) A `deprecate` attestation at the market, in the yank shape:**
  `[deprecated since=<version> successor=pkg:<name> effective=<date>
  reason='…']`, published as a signed VC by the publisher DID. It inherits
  N-DIST-1 (no remote reach-in) for free, is **distinct from yank in the
  catalog** — a deprecated release stays discoverable and ranks below its
  successor, a yanked one does not — and is surfaced at the two moments a
  consumer can act: informational at compose/enable (**never** a refusal),
  and named at re-pin where the composer already diffs grammars.
- **(b) A manifest element.** REFUSED on mechanics, not taste: the manifest
  is sealed and its hash is the `of=`/`hash=` pin. Deprecation is by
  definition a fact learned AFTER the release was sealed — v1 is deprecated
  when v2 ships — so a manifest element could only ever deprecate a package
  in advance of its own successor existing. A forward-looking
  `supersedes=<version>` on the SUCCESSOR's manifest is additive and
  harmless, and it is not a substitute: nothing attaches it to v1's catalog
  entry.
- **(c) Prose only.** REFUSED: it forces the publisher with a healthy
  successor to choose between asserting a defect (yank) and saying nothing
  mechanical. Every other lifecycle stage is machine-legible; deprecation
  should not be the one that is not.

**Why (a) is long-term best.** It closes the misinformation fork the report
identifies, costs one attestation kind plus a catalog ranking rule, and
introduces no new trust primitive (§9 absence 3 holds: it is a VC).

## AD-5 — declarative process is #789's vocabulary, projected at the XAP layer — never a second one (#1185)

**Recommended: (a).**

- **(a) #1185 is the XAP-facing half of #789** ("general workflow on the saga
  substrate — flows-as-documents"), not a new capability. ONE vocabulary and
  ONE substrate: #789's flow-as-document over the stateless saga runner. The
  XAP layer contributes the four properties #1185 names and #789 does not
  yet pin: **actions may only name verbs in the composed grammar**;
  **authority is the constituents'** — an action is admitted only if the
  actor could have emitted that verb directly, at the same PEP, exactly as
  N-COMPOSE-2 does for derived verbs (this is the property most likely to be
  got wrong privately, and it is the one that keeps a definition from
  becoming a privilege-escalation path); **the `dial=` vocabulary governs
  execution**, with irreversible actions floored at approval; and
  **refusals are values** — a definition naming a verb the grammar no longer
  carries refuses at validation in the `[!compose-conflict]` shape, not at
  3am. `xap.md` gains one sentence beside the ~95 % line pointing at the
  vocabulary, so the line stops reading as an uncovered claim.
- **(b) Two vocabularies — sagas for cross-company flows, a lighter
  trigger/condition/action rule engine inside a XAP.** REFUSED: two ways to
  say one thing is the orthogonality defect the project exists to avoid, and
  #789 item 2 already names the failure mode (BPMN — a vocabulary that
  bloats into an unauditable programming language). The discipline boundary
  is the make-or-break item in that design; opening a second front loses it
  before it is drawn.
- **(c) Application territory; say so in `xap.md`.** REFUSED: every part is
  already in the tree (`sched`, journal, folds, cascade, `authz`, the dial),
  so "application territory" means every adopter assembles the same thing
  from the same parts, privately, in code — which is where variance goes to
  die, and it renders to no face.

**Scope consequence, ruled explicitly rather than assumed:** #789 is
~1.5 streams. Under (a) the v0.18 deliverable is the **reconciled design**
(the four XAP-layer properties folded into #789's design items, #1185
retained as the XAP-surface member) plus the one-sentence `xap.md` truing —
**not** the runner generalization. See AD-7.

## AD-6 — per-tenant fields are tenant DATA, and never enter the composed grammar (#1186)

**Recommended: (a).**

- **(a) A declared extension surface at the SCHEMA layer, defined once, with
  the tenant's field definitions carried as tenant data** — subject, name,
  label, and a type from a closed vocabulary, refs typed against existing
  schemas so a field may point at an existing noun but cannot invent a
  shape. Keyed the way field-capability claims already key,
  `(schema-address, CXPath)` per [P0-46], so it cascades by machinery that
  exists. Four properties are load-bearing and all four are enforceable
  rather than promised: validated on write (a write naming an undeclared
  field refuses); **read-open, write-closed over history** — folds tolerate
  a retired field on historical entries, since the journal never migrates,
  and declared-but-unset uses the value model's existing absent-vs-null
  distinction; **structurally unable to participate in an invariant** — a
  declared field is capturable, displayable, filterable, groupable, and
  referenceable in conditions, and is never an input to a fold's
  conservation rule; and projected on the three faces with no per-adopter
  view code.
- **(b) "Use the binding and accept N grammars"; state it.** REFUSED as the
  intended answer: it puts tenant material in the vendor-document layer,
  which contradicts [P0-119]'s own taxonomy, and it takes the most common
  customization of all outside [P0-120]'s replay-and-classify mechanism —
  the mechanism that exists to make fleet upgrades safe. N tenants with one
  added field each yields N bases to reason about on every release.
- **(c) A per-feature private extension point (untyped map / blob).**
  REFUSED: no interop, no validation, no projection, and every feature
  invents its own — the outcome a platform mechanism exists to prevent.

**Why (a) is long-term best.** The firewall in item 4 is the whole argument:
it is what keeps an upgrade a pin move no matter how many tenant fields
exist. That property can be *enforced* by the platform and can only be
*promised* by an adopter, and the difference compounds across a fleet.

**Open sub-question folded into execution, not deferred:** whether the
declaration lives in `core/schema.md` (one mechanism for every record type,
XAP or not) or in the XAP layer. Recommendation at execution: the schema
layer, because "one more field on this thing" is not XAP-specific and a
second mechanism later would be the (c) outcome by another route.

## AD-7 — v0.18 campaign scope: four land whole, one lands as a capability, one lands as design

**Recommended: (a).**

- **(a) Wave plan.** W1 — AD-1 (#1181): the truing + `CXER4864` + the
  surface-gate half + fixtures; AD-3 (#1183): the governance §9.5b statement
  + `[address-migration]` shape. W2 — AD-2 (#1182): `cx xap compat` + the
  publish stage + `CXER4892` + `[contract-lineage]`; AD-3 remainder:
  `cx address recheck` + the class-boundary fixture. W3 — AD-4 (#1184): the
  deprecate attestation + catalog ranking + surfacing at enable and re-pin.
  W4 — AD-6 (#1186): the tenant-extension capability, whole. W5 — AD-5
  (#1185): the reconciled design + the `xap.md` truing, with implementation
  sequenced behind #789 in a later release. Exit: full `make test` green
  (NOT `make test-vcx` — the #1078 lesson), every position positive- AND
  negative-fixtured.
- **(b) All six implemented in v0.18**, #1185's runner generalization
  included. NOT recommended: #789 is ~1.5 streams on its own and its
  vocabulary must settle at stream 10's exit review; forcing it into this
  campaign is how the BPMN failure mode gets in.
- **(c) Spec-and-rulings only in v0.18; implementation in v0.19.** NOT
  recommended: AD-1's defect is live for an adopter today, and AD-2/AD-3/AD-4
  are each bounded by an existing precedent.

## AD-8 — admit #1161 and #1162 to the campaign

**Recommended: (a).**

- **(a) Admit both.** They are the same adopter's audit, the same seam, and
  the same section: #1161 (the two approved specs disagree on whether `of=`
  pins the archetype DOCUMENT or the PACKAGE) and #1162 (an instance cannot
  name an implementation, so an `[add]`ed verb composes and admits with no
  possible `apply`). #1162 states it is a companion to #1161 and that #1161's
  ambiguity is the likely cause; #1181 is literally the third report about
  §4.3. Ruling AD-1 without ruling what `of=` pins leaves §4.3 half-trued,
  and the three fixes touch the same paragraphs.
- **(b) Leave them out; run them separately.** Cheaper to file, and wrong:
  the same paragraphs get edited twice, and the §4.3 reader is left with two
  partial answers.

**Note if admitted:** #1161's disposition is a pure spec ruling (which of
two readings is intended, then correct the two "sealed feature package whose
Tier-1 hash is exactly the `of=` pin" sentences OR correct `CXER4879`);
#1162 is a capability question (does the refinement contract get an
implementation slot, or is instantiation contract-level by design and said
so?) and would carry its own letter.

---

## Refusals register — do not re-propose without the named trigger

- **A second authorization evaluator for selection** (AD-1(c)). Trigger:
  none. The PEP is the one evaluator; a face-level filter that the wire does
  not honor is the split [P0-35] forbids.
- **A contract-compat WARNING instead of a refusal** (AD-2(c)). Trigger: a
  measured false-positive rate on the classifier over a real corpus that
  makes fail-closed unusable — measured, not anticipated.
- **Absolute address stability within a major, pre-1.0** (AD-3(c)).
  Trigger: 1.0.
- **Deprecation as a manifest element** (AD-4(b)). Trigger: none — the
  manifest is sealed before the fact exists. A `supersedes=` on the
  successor's manifest is separately additive and not blocked by this.
- **A second workflow/rule vocabulary inside XAP** (AD-5(b)). Trigger:
  #789's design demonstrating that its flow-as-document vocabulary cannot
  express in-XAP automation without bloating — i.e. the refusal is reopened
  by evidence from the ONE vocabulary, never by convenience.
- **An untyped per-feature extension blob** (AD-6(c)). Trigger: none.
- **Per-tenant fields via the archetype binding as the intended path**
  (AD-6(b)). Trigger: AD-6(a) proving unimplementable at the schema layer,
  with the finding recorded.
