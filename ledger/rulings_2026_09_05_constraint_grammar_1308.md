# Rulings 2026-09-05 — #1308 the feature grammar as a CONSTRAINT grammar (CG-1..CG-7)

**Status: CG-1..CG-7 RULED as marked below, 2026-09-05, under the owner's
standing letter-acceptance rule (a recommendation is accepted when it is the
long-term-best; the owner opened the campaign on 2026-09-04 with "prep and
begin 1308"). Each letter was re-checked against the bar before it was
recorded; any letter the owner reverses is reverted BEFORE spec text lands
under it.** Recorded BEFORE any spec text (ledger discipline; register R4.2).
Ruling ids `1308-CG-N`.

**Inputs read.** #1308 (the umbrella: seven asks, the effort/impact/risk
audit) and #1301–#1307 (each with a reproduction on the `cx xap init`
scaffold shape, measured on v0.17.0); `xap_grammar_composition.md` §1, §4
(W1–W8), §4.1–§4.5, §6, §8; `xap.md` §2.2, §3.4, §4.3, §8 (the
`CXER4850–4889` band: 4865–4869 are the only unallocated codes);
`xap_schemas/feature.cxs` (`[field type::string [req]]` — free text;
`kind` enum carries `cardinality`; `[views]` per VG-1), `grammar.cxs` (a
composed noun = `name`, `feature`, `derived`, `[from]`, `[views]` — NO
fields); `core/schema.md` §4, §7 (`[enum]`, `[range]`/`[min]`/`[max]`,
`[pattern]` RE2, named `[type X::base …]`); `core/planar_algebra.md`
(APPROVED 2026-08-20; `[?for]` is THE comprehension, no second query
surface; static dependency extraction; delta rule); `core/bitemporal.md`
(APPROVED 2026-08-14; L115 `valid-from=`/`valid-to=` half-open, open end =
absent; L117 `[supersedes hash=]` + `:assertion|:correction|:amendment`;
L118 the read is a PURE projection named `{at-seq, valid-at}`, never
`as-of`); `ledger/rulings_2026_09_04_view_grammar.md` (VG-0: three parts of
speech — verb, noun, clause; VG-1: the noun declares what the clauses may do).
Implementation read: `stdlib_xap.v` — `xap_gc_rule_kinds` (line 3189:
`cardinality` present, read by nothing else), `xap_gc_gate` (W1–W8),
`xap_gc_w8_role`, `xap_gc_grammar_doc` (nouns emitted WITHOUT fields — the
#1307 finding reproduces on the 0.18 tree; `[views]` rides verbatim since
#1285), `xap_emit_prepare` → `xap_pep_admits` → cascade → fold (NO rule is
evaluated anywhere on the path); `stdlib_xap_host_notd_wasm32_emcc.v`
(`<f>:apply` runs over the COMMITTED act — the only place a law lives today);
`schema_validate.v` `validate_node_against_type(schema_text, type_name, node)`
(shipped — #1303's mechanism exists); `purity_checker.v` `check_predicate`
(shipped — #1302's purity theorem exists); `eval.v`
`eval_group_by_directive` + `planar_delta.v` (`[group-by]` with `$key` /
`$count` RUNS on this tree — measured 2026-09-05, so #1305's "spec'd and
unimplemented" caveat is stale); `stdlib_journal.v` (NO `at-seq` /
`valid-at` / `supersedes` — stream 8's runtime half is unshipped).

## The finding the rulings rest on

The grammar is a structure grammar and a weak constraint grammar. Every law
a downstream vocabulary claims is enforced by a module's `apply` under
`[$xap:host]` or by nobody; a `[$xap:component]` runtime holds no law at
all. Five of the seven asks are the VG-1 move in the VG-1 slot — the noun
(or the verb, or the rule) DECLARES, the W-gate CHECKS at compose, the
runtime ENFORCES at one point. The two that are designs (#1302, #1305) are
the ones sealed contracts attach to: SEA-1 and #1182 make a contract sealed
under a prose law a re-publish once a checkable law exists, so the RULING is
what cannot wait for the cut, even where the runtime half lands after it.

**One enforcement point (the position that binds CG-1, CG-2, CG-4):** every
runtime-class law evaluates in `xap_emit_prepare` AFTER the PEP admits and
BEFORE the cascade commits — the position `apply` occupies under the host,
so a module and a grammar rule refuse at the same point, and a refusal is a
VALUE on the failure channel naming the rule (§2.3), with nothing appended.
Bindings available there: `$intent` (the qualified intent), `$row` (the id's
merged record as the state fold produces it, absent for a new id), and,
when the law's scope is the fold, `$slice` (the noun's current slice).

## CG-1 — `kind=cardinality` (#1301) — RULED (a)

- (a) **Finish the kind that exists.** `[rule kind=cardinality nouns=N
  of='a b …' min=M max=X]`: every name in `of=` is a field of noun N typed
  as a sibling noun; `min ≤ max`; a field belongs to at most one cardinality
  group (**W9**, reported like W8, never first-failure). Fold: the records
  for one id never carry more than `max` of the group, and with `min ≥ 1` a
  verb that `[writes]` one alternative refuses when another is present —
  `cx-err:CXER4866 E_XAP_CARDINALITY` naming the rule and the alternatives
  present. Views: a `[facet]` over a cardinality group is admitted (W8's
  "never a sub-noun" arm gains the exception) and its values are the
  alternatives' names. Edge set: the rule contributes a `rule-nouns` edge
  like a validity rule (§4.4). **Taken.** *Deletes:* a `kind=cardinality`
  rule WITHOUT `of=`/`min=`/`max=` no longer composes green — it is a W9
  refusal (cutover-first; the only such rule in the tree is #1301's own
  probe). A noun without the rule is byte-identical.
- (b) Compose check only; fold enforcement waits for CG-2's mechanism.
  Rejected: leaves the runtime admitting what the gate refused, which is the
  defect measured.
- (c) `one-of=` on the field. Rejected: a multi-field constraint on one
  field; leaves `cardinality` an empty enum value.

## CG-2 — the evaluable `[check]` and rule scope (#1302) — RULED (a)

- (a) **A `[check …]` child beside `[statement]`, holding a PURE cx
  predicate; `scope=row|fold` (default `row`); evaluated pre-commit.** The
  predicate ranges over `$intent`, `$row` and, for `scope=fold`, `$slice`.
  Purity is checked at compose by the shipped checker (`check_predicate`) —
  an impure call is a **W10** refusal. A false check refuses
  `cx-err:CXER4865 E_XAP_RULE_REFUSED` naming the rule; nothing is appended.
  `scope=fold` evaluates over the noun's current slice and is priced as
  such (the ruling states the cost: one slice read per admitted intent
  touching the noun; the algebra's static dependency extraction is the
  seam a later plan cache attaches to — not minted here). A rule with a
  `[check]` stays runtime-class for the floor/ceiling (§4.4 unchanged);
  `nouns=` still declares the edge and is REQUIRED when `[check]` is
  present (a checked law that names no noun has no place to run). One
  language: the predicate is cx, as the planar algebra rules for queries
  ("no second query surface"). **Taken.** *Deletes:* nothing for existing
  contracts — a prose-only rule stays runtime-class documentation exactly
  as §4 says today; the component-path runtime gains its first law.
- (b) A bounded constraint language. Rejected: a second language to
  extend, contradicting the algebra's one-comprehension rule; the cost
  bound it buys is better had by `scope` and the dependency extraction.
- (c) Spec that validity rules are documentation. Rejected: truing the
  spec to the shortfall; makes the component path permanently lawless.

## CG-3 — `type=` resolves to the schema type language (#1303) — RULED (a)

- (a) **A `[types]` element in the feature, schema.md type-decl syntax
  verbatim (`[type state::atom [enum :open :closed]]`,
  `[type money::decimal [min 0] [unit currency]]`); `type=` accepts a
  scalar of the CLOSED grammar scalar set, a sibling noun, or a named type;
  anything else is a W11 refusal (closes #1193's silent half).** The scalar
  set is the one the tree already reads (`text`, `int`, `decimal`, `bool`,
  `instant`, `interval`, `geo-point`, `ref`, plus `prose` from CG-7) and is
  written down in feature.cxs as an enum-shaped table mapping each to its
  schema base (`text`→`string`, …); the composed grammar carries `[types]`.
  At the enforcement point every intent field whose noun field has a type
  is validated by `validate_node_against_type` over the feature's generated
  schema text; a failure refuses `cx-err:CXER4867 E_XAP_FIELD_TYPE` naming
  field, type and value. `[unit F]` is a GRAMMAR clause (not a validator
  clause): W11 checks F is a field of the same noun. An instance may
  `[tighten]` a named type — narrow an enum, raise a min, lower a max, add a
  pattern — never widen (CXER4878's axis list gains "type"). **Taken.**
  *Deletes:* an unknown or misspelled `type=` no longer composes green. A
  contract using only the scalar set is byte-identical.
- (b) Inline constraints on the field, no named types. Rejected: no reuse
  across nouns or features; the tighten contract has nothing to name.
- (c) Leave `type=` open. Rejected: a downstream gate cannot see an enum's
  values or a range; it is the measured defect.

## CG-4 — the verb declares its transition (#1304) — RULED (a)

- (a) **`[transition field=F from=':a' to=':b']` on an act verb** (0..*;
  several `from` values may be given space-separated). **W12:** F is an
  enum-typed field (CG-3) of a noun the verb `[writes]`; every `from`/`to`
  is a member of the enum; a state with no outgoing transition is reported
  TERMINAL in the compose report (report, not refusal); ordering between
  two transitioning verbs is DERIVED (`to` of one = `from` of another ⇒
  after-edge) and a hand-written `kind=ordering` rule that contradicts a
  derived edge is a W4 conflict. Fold (the CG-2 point, no new mechanism):
  an intent whose `$row@F` is not in `from` refuses
  `cx-err:CXER4868 E_XAP_TRANSITION` naming verb, field, actual and allowed
  states; a new id (no row) admits only a transition whose `from` includes
  the enum's declared initial value or is omitted; the committed record
  carries `F=to` WRITTEN BY THE RUNTIME, and an intent that carries a
  different value for F refuses the same code — seed and module cannot
  disagree about the write. Views: F is facetable by construction (W8
  admits it without a `[facet]` declaration). **Taken.** *Deletes:* nothing
  for a verb without `[transition]`.
- (b) A `[lifecycle]` block on the noun. Rejected: splits a verb's
  declaration across two places; the verb is the transition.
- (c) Hand-written ordering + checks per transition. Rejected: every
  vocabulary writes the same twenty lines; the derived ordering is lost.

## CG-5 — a derived noun carries its `[fold]` (#1305) — RULED (a)

- (a) **`[fold …]` on a `derived=true` noun holding a planar comprehension
  (`[?for [in $t 'thing/thing'] [group-by …] [yield …]]`).** **W13:** the
  comprehension's sources ⊆ `[from …]` (W5 extended: every `[in]` source
  is a qualified noun of the `[from]` list); pure (the shipped checker);
  every `[yield]` shape is the noun's own name carrying only its declared
  fields. Runtime: a derived noun with a `[fold]` is its OWN producer — run
  assembly no longer raises CXER4875 for it; it is served as a slice
  recomputed from its sources' current slices on read (pure, deterministic,
  the algebra's ONE-traversal contract) and maintained incrementally by
  `planar_delta` where the comprehension is in the delta rule's monotone
  class. A `[deriver]` bound in the wiring still overrides the `[fold]`
  (W7 unchanged: no grammar verb writes it). `[group-by]`/`$key`/`$count`
  RUN on this tree — measured; the ask's ordering caveat is withdrawn.
  **Taken.** *Deletes:* nothing — a derived noun without `[fold]` keeps
  CXER4875. **Ordered LAST in the campaign** (the umbrella's own risk row:
  freshness and cost on read); the ruling stands now because a sealed
  readout-as-module-verb is a re-publish after it.
- (b) A deriver shipped in the feature package as code. Rejected: behavior
  travels as code, the component path still cannot run it.
- (c) Status quo. Rejected: the readout family does not exist in a
  composed XAP.

## CG-6 — the valid-time axis (#1306) — RULED (a′)

- (a′) **`axis=valid-from|valid-to` on a field (`instant`-typed), at most
  one pair per noun (W14); the composed grammar carries it; the xap read
  gains the bitemporal projection in stream 8's names: `[$xap:state rt path
  {at-seq: N, valid-at: T}]` — at-seq folds the journal to N, valid-at
  keeps the records whose `[from, to)` (half-open, open end = absent field)
  contains T. The correction taxonomy (`[supersedes hash=]`,
  `:assertion|:correction|:amendment`) is the JOURNAL's contract (L117) and
  is unshipped in `stdlib_journal.v`; it lands as stream 8's own delivery
  and the xap fold consumes it then — filed as its own issue against the
  journal, NOT folded into this campaign.** `as-of` is not minted (L118).
  **Taken.** *Deletes:* nothing for a noun without `axis=`.
- (a) The same plus the supersedes fold inside this campaign. Rejected on
  ordering: it re-implements a journal contract inside xap; stream 8 owns
  it. (a′) is (a) minus that one piece, stated, not silent.
- (b) A `cx-stdlib/temporal` library each module calls. Rejected: behavior
  not grammar; every feature re-implements the verb.
- (c) Wait for stream 8 entirely. Rejected: every field sealed meanwhile
  carries a private spelling.

## CG-7 — what a surface needs beyond `[views]`, and fields on the composed grammar (#1307) — RULED (a)

- (a) **`identity=`, `label=` on the noun; `prose` in the scalar set;
  `answers=law` on an observe verb; the composed grammar carries the
  noun's `[field]`s, `[types]`, these attributes and `[views]`.** **W15:**
  `identity=`/`label=` name a field of the noun; `identity=` DEFAULTS to
  the field an identity-role key registers `via=` when exactly one does
  (report, not refusal, when it cannot default); `answers=law` at most one
  per feature; `prose` is a scalar (a role of text, not a constraint — so
  CG-3's named types are not the home for it) mapping to schema `string`.
  grammar.cxs `[noun]` gains `[elem field 0..*]`, `[elem types 0..1]` and
  the attributes; §8's "as data" contract is what makes a served grammar
  sufficient for a surface. **Taken.** *Deletes:* nothing; all optional,
  defaults preserve today's behavior; the composed grammar grows children
  (the byte-identity fixture of §9 item 14 re-pins with fields present —
  the "additive guarantee" is re-stated as "a noun with no new declarations
  composes to the same nouns plus its fields").
- (b) In the hint cascade. Rejected by VG-1's own argument.
- (c) Convention. Rejected: adopters' folds already disagree.

## Dependencies and execution order

```
CG-3 types ─┬─▶ CG-4 transition ◀─┬─ CG-2 check (the enforcement point)
CG-7 fields/identity ─────────────┘   CG-1 cardinality (uses the point)
CG-6 axis + read           CG-5 fold (LAST)
```

Waves (each: spec edits under its `1308-CG-N` id → feature.cxs / grammar.cxs
→ fixtures (compose refusal per W-row arm, runtime refusal per code, the
additive byte-identity re-pin) → implementation → `make test` → land →
CHANGELOG line carrying the adopter note):

1. **Wave A — declarations (S):** CG-7 (fields on the composed grammar
   first — everything later must survive composition), CG-3 `[types]` +
   the closed scalar set + W11 + CXER4867, CG-6 `axis=` + W14.
2. **Wave B — the enforcement point (L):** CG-2 `[check]`, W10, CXER4865,
   the pre-commit evaluation in `xap_emit_prepare`; then CG-1 W9 +
   CXER4866 and CG-4 W12 + CXER4868 + derived ordering + terminal report,
   both on the point.
3. **Wave C — reads (M):** CG-6's `{at-seq, valid-at}` projection on
   `[$xap:state]`; the journal-side supersedes issue filed.
4. **Wave D — the fold (L):** CG-5 W13 + the self-producing derived noun.

Error codes allocated by this record (the band's last free codes; §8 table
gains four rows): `CXER4865 E_XAP_RULE_REFUSED`, `CXER4866
E_XAP_CARDINALITY`, `CXER4867 E_XAP_FIELD_TYPE`, `CXER4868
E_XAP_TRANSITION`. `CXER4869` stays reserved. Compose-time refusals ride
`CXER4870` as `:w9…:w15` conflicts.

## The downstream note

Additive for every sealed contract: a feature that declares none of the new
attributes composes to the same grammar plus its fields. A contract whose
law is prose stays admitted and unenforced until it declares a `[check]`, a
`[transition]`, a `cardinality` group or a typed field — and each such
declaration is a re-publish under SEA-1. Downstream is told through the
issues and the CHANGELOG, never through their own repositories.
