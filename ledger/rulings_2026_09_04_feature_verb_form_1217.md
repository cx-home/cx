# Rulings 2026-09-04 — #1217 the UX projection reaches feature verbs (VF)

**IMPLEMENTED 2026-09-08 (#1217).** `ux:form` now dispatches on the source
kind; `ux:feature-form` is retired with no alias; the five refusal codes are
values; spec claim **P0-129** carries the rule; pinned by
`ux-122-one-entry-projects-both-declaration-systems` and
`ux-123-form-tells-its-refusals-apart` (both `gate=enforced`). Twelve call
sites cut over (oriel `serve.cx` ×2, the W5 shop `serve.cx` ×3,
`gen_ux_fixtures.cx` ×7) and nine fixture call sites re-spelled. One thing the
2026-09-04 record did NOT anticipate and the implementation measured: an
`observe` verb projected a form **with a submit button and no inputs** — a
write offered on a verb that declares it reads — so `ux-verb-observe` is a
behaviour fix, not only a diagnostic. The owner veto on retiring the #787 W5
public verb was flagged on 2026-09-04 and never exercised; it is retired.

**Status: VF-1 RULED (a) 2026-09-04 under the owner's standing letter-acceptance rule and the 2026-09-04 directive (run the campaign through; best long-term decision) — re-verified: one projection, one entry, dispatch on the value's kind, eight in-tree call sites to cut over, no external users. Proposed first (239fcd2de), ruled in the following commit; OWNER VETO by letter stands open because (a) retires the #787 W5 public verb `ux:feature-form`.**
Recorded BEFORE any spec text. Ruling id `1217-VF-1`. Needed by #1265 W3:
the `by=:principal` human-task step renders "the act's projected form"
(`flow.md` §4.6), and at the XAP face a step's act IS a composed-grammar
verb. VF-1(a) retires a public verb the #787 W5 work introduced — flagged
to the owner for veto by letter.

**Inputs read.** #1217 (the filing, measured on v0.17.0: `[$ux:form <feature
source> 'register']` refuses `ux-no-such-command`); `xap/ux.md` P0-2 (subject
kinds), P0-17 (the third projection derives from `[?def]` commands; clause
presence is the discriminator; labels degrade name-derived);
`xap_grammar_composition.md` §6.1 N-COMPOSE-7 (the verb's `[intent [do :v
[field]…]]` IS its parameter list); `x/ux.cx`: `form ($source::string
$verb $opts)` — P0-17's entry, `[?def]`-only, refusing `ux-no-such-command`
for anything else — AND `feature-form ($feature::any $verb $opts)`, PUBLIC
since #787 W5 (§9 "the XAP feature grammar as a projection subject"),
projecting a verb from the `[intent]` list with the written noun's types,
refusing `ux-no-such-verb`; its callers: `spec/03-approved/xap/demos/oriel/
serve.cx` (2), `design/787/w5/shop/serve.cx` (3), `conformance/stdlib/ux.cxd`
cases ux-080 and six more; `flow.md` §2.1/§4.6 (the step's `[do 'ns/verb'
[field value]…]` children ARE the verb's parameter list — CA-1/CA-2 — and an
EMPTY field is the one the performer supplies).

## The finding the ruling rests on

The filing's item 1 is SHIPPED — as a second public entry. Since #787 W5 the
projection exists twice: `$ux:form` for a `[?def]` command named by (module
source, verb) and `$ux:feature-form` for a grammar verb named by (feature
document, verb). The filing's failure is real on its own terms: `$ux:form`
handed a feature source answers `ux-no-such-command`, which reads as a typo,
and nothing tells the adopter the other entry exists. Two public entries for
ONE projection is the second-vocabulary pattern the orthogonality objective
refuses, and the W3 human-task form would have to know which declaration
system produced its verb to pick an entry.

## VF-1 — one projection, how many entries — RECOMMENDED: (a)

- **(a) RECOMMENDED — ONE entry, `$ux:form SOURCE VERB OPTS`, dispatching on
  the SOURCE KIND; `$ux:feature-form` is RETIRED cutover-first.** A source
  that is a string is module source text → P0-17's `[?def]` path, unchanged
  byte-for-byte; a source that is a `[feature …]` or `[grammar …]` element →
  the grammar path (today's `feature-form-of`: N-COMPOSE-7's declared list,
  the written noun's field types and `doc=` where names match, name-derived
  labels otherwise — P0-17's degradation rule; a composed `[grammar]` source
  resolves the qualified verb through it, the filing's item 2). Same
  semantic tree out (`ux:form verb=<qualified>` → `POST /intent/<verb>`),
  same renderer, same `opts`. Refusals told apart, as VALUES:
  `ux-no-such-command` (module source, no such def), `ux-not-a-command` (the
  def exists, no `[effects]`), `ux-no-such-verb` (grammar source, no such
  verb), `ux-verb-observe` (an `observe` verb — nothing to submit),
  `ux-source-unreadable` (neither kind). The flow's human-task form (W3) is
  this projection over the step's resolved verb with the document's filled
  fields pre-populated via `opts.values` and the EMPTY fields as the inputs
  (CA-2). **What it DELETES:** the public verb `ux:feature-form` and its
  `[fn-doc]`; its callers move to `ux:form` (oriel `serve.cx` ×2, the
  design-estate shop `serve.cx` ×3, ux.cxd's seven cases re-pinned under the
  one entry); the misleading `ux-no-such-command` for a grammar source.
  **What it KEEPS:** P0-17's `[?def]` path unchanged; `feature-form-of`'s
  derivation; every existing fixture's expected TREE (only the call spelling
  changes). **Strongest counter:** #787 W5 introduced `feature-form` under
  the owner's rulings, and retiring a public verb costs a cutover. **Answer:**
  the W5 ruling (DP1 4b) decided WHAT the projection derives from — the
  `[intent]` list — not that it needs its own entry; dispatch on the value's
  kind is how cx values already work (P0-2 admits subject kinds by what the
  subject IS), and cx has no external users yet, so the cutover is eight call
  sites in-tree.
- **(b) keep both entries; make `$ux:form` on a non-module source refuse
  with a code that NAMES `ux:feature-form`, and add `ux-not-a-command`.** The
  honest floor: fixes the misleading refusal, costs nothing. Rejected as the
  answer because it ratifies two entries for one projection and makes every
  caller — the flow's human-task form first — choose an entry by knowing the
  verb's provenance.
- **(c) fold the `[?def]` path INTO `feature-form` instead (retire `form`).**
  Rejected: `form` is P0-17's named entry throughout `ux.md`; the spec would
  have to be re-spelled everywhere for no gain.

## Edit map (ruling-gated; lands with #1265 W3 or as its own change before it)

| Where | Edit |
|---|---|
| `xap/ux.md` P0-17 | a paragraph: the third projection reaches BOTH declaration systems through the one entry, dispatching on the source kind; the grammar path derives from N-COMPOSE-7's list; the five refusal codes; `ux:feature-form` retired (cutover-first, no alias) |
| `x/ux.cx` | `form` dispatches on source kind and calls `feature-form-of`; `feature-form` and its `[fn-doc]` removed; refusal codes |
| `conformance/stdlib/ux.cxd` | ux-080 and the six `feature-form` cases re-spelled under `ux:form` (trees unchanged); the filing's `cx xap init` owner/register verb projects (positive); the five refusals as negatives; a composed `[grammar]` source resolving a qualified verb |
| `spec/03-approved/xap/demos/oriel/serve.cx`, `design/787/w5/shop/serve.cx` | callers re-spelled |
| `docs/dev/features-authoring.md`, `xap-quickstart.md` | one sentence: project the scaffolded verbs with `[$ux:form $feature 'register' {}]` |
