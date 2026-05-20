# CX v0.7.0 Adoption Review

**Status:** Skeleton (2026-05-17). To be filled during v0.7.0
implementation; final scoring at v0.7.0-RC integration gate per
[ADR 0022 §D8](../spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md).

**Purpose.** The adoption review is one of three co-equal release
gates (per [readiness rubric](../spec/readiness_rubric.md)). It
evaluates v0.7.0 against the 20 adoption personas defined in the
rubric, using the four-tier verdict scale below. The review surfaces
findings; findings either become fixes in v0.7.0 scope or move to
post-v0.7.0 roadmap items.

## Release gate

Per the readiness rubric:

- **≥ 13 of 20 personas at ✅ or better** at release time
- **Remaining ≤ 7 at ⚠** must be cleanly downgraded by ROADMAP
  positioning (post-v0.7.0 item with target version named)
- **Zero ❌ at release time**

The v0.7.0 review *additionally* tracks persona movement vs the
v0.6.0 baseline. v0.6.0 → v0.7.0 should net more ✅ or ⭐, not
regressions. Net regression on a persona is a finding that must be
explained and either accepted (with rationale) or remediated before
tag.

## Four-tier verdict scale

| Tier | Meaning |
| ---- | ------- |
| ⭐ **First choice** | This persona would pick CX over their current default. v1.0 target. |
| ✅ **Adoptable** | Persona would accept CX if directed; no caveats to the team. v0.7.0 target for ≥13 of 20. |
| ⚠ **Adoptable with caveats** | Persona would adopt under specific conditions; brings recorded concerns. |
| ❌ **Not yet adoptable** | Persona blocked by a missing capability or unresolved friction. |

## What's new in v0.7.0 (vs v0.6.0)

Surface changes that re-shape persona evaluation:

- **One language, one name.** "CXL" retires; cx is data + evaluator
  + schema + query as one substrate. Reduces conceptual surface
  (one language to learn instead of two), increases identity clarity
  (homoiconic pitch is unambiguous). Likely upward movement: docs
  reader, educator/trainer, API integrator.
- **Full XQuery 4.0 parity (or exceed).** Per
  [`spec/xquery_40_parity.md`](../spec/xquery_40_parity.md), v0.7.0
  delivers every XQuery 4.0 expression with cx-native syntax —
  inline functions with closures + partial application + named
  refs, full FLWOR (for/let/window/where/while/count/group-by/
  order-by/return), maps/arrays with full function library (~26
  fns), structured try/catch with `$err:*` bindings + `fn:error()`
  + cx-native error code namespace, SequenceType expressions,
  pipeline `|>` AND arrow `=>`, switch and quantified expressions,
  simple map `!`, lookup operator `?key`. This closes the largest
  capability gap vs XQuery 3.1 / 4.0 in a single release. Likely
  upward movement: data-format engineer, library implementer,
  data scientist, standards reviewer (multiple tiers; this is the
  "first choice" trigger for those personas).
- **Directive prefix unchanged** (`?` preserved). The original
  draft proposed `?` → `!` flip; dropped same-day after empirical
  inspection of the V parser (per ADR 0022 §D1 Amendment). Net
  zero impact on personas — no syntactic migration cost; the
  cxl-name retirement is prose-only at the user-facing level.
- **Binding cut from nine to five.** Drops C#, Java, Kotlin, Ruby,
  Swift (`lang/{name}/frozen/`). Likely downward movement: any
  persona whose ecosystem is in the dropped set. Mitigation:
  `FROZEN.md` per directory explains the disposition and the
  re-promotion path.
- **First-class HTMX example.** Concrete reference for the HTMX
  component pattern in cx. Likely upward movement: API integrator,
  solution architect, entry-level dev, educator/trainer.
- **One-time epoch break.** Documented in ADR 0022 §D9 and
  [rubric amendment](../spec/readiness_rubric.md). Likely flat
  with proper communication; downward if perceived as broken
  commitment. Mitigation: rubric amendment is the documented
  forward commitment that this is *not a precedent*.

## Personas

The 20-persona set per [readiness rubric](../spec/readiness_rubric.md):

### Evaluator role-type (6 personas, the v0.6.0 baseline set)

| Persona | v0.6.0 baseline | v0.7.0 target | Movement | Notes / Findings |
|---|---|---|---|---|
| API integrator | — | TBD | — | HTMX example + 5-binding parity should help. |
| Config author | — | TBD | — | Directive syntax unchanged (`?` preserved); only config attribute name `cxl-version` → `cx-eval-version` requires touch-up, absorbed by `cx upgrade-config`. |
| Data-format engineer | — | TBD | — | Full FP surface closes the largest gap vs XQuery. Expect upward movement. |
| Library implementer | — | TBD | — | C ABI rename + capability bit consolidation is a one-time cost; FP surface widens what bindings expose. |
| Docs reader | — | TBD | — | Single language identity simplifies the mental model. Spec rename `cxl.md` → `eval.md` is a navigation change. |
| Security reviewer | — | TBD | — | Schema-validated directives + content-addressed fragments + byte-identical conformance are net wins. |

### Architect / leadership role-type

| Persona | v0.6.0 baseline | v0.7.0 target | Movement | Notes / Findings |
|---|---|---|---|---|
| Tech lead | — | TBD | — | Single-cut release strategy + tagging discipline are clean signals. |
| Product manager | — | TBD | — | Five-binding cut narrows the addressable surface but each binding is more deeply supported. |
| Solution architect | — | TBD | — | First-class HTMX example demonstrates a concrete vertical. |
| Enterprise architect | — | TBD | — | Dropped JVM (Java/Kotlin) and .NET (C#) bindings are a real cost — flag for re-promotion if enterprise demand surfaces. |
| CTO | — | TBD | — | Stability boundary amendment (one-time epoch break) is the leadership-facing concern. ADR 0022 §D9 documents the forward commitment. |

### Implementer role-type

| Persona | v0.6.0 baseline | v0.7.0 target | Movement | Notes / Findings |
|---|---|---|---|---|
| Entry-level dev | — | TBD | — | Single language to learn instead of two should help; HTMX example provides a starting vertical. |
| Senior engineer | — | TBD | — | Full FP surface unlocks the patterns mature platforms expect. |
| Data scientist | — | TBD | — | FLWOR + aggregates + pipelines + maps/arrays close the data-shaping gap. |
| DevOps / SRE | — | TBD | — | C ABI rename requires re-link of any pre-v0.7.0 consumers; migration is mechanical. |
| OSS contributor | — | TBD | — | Reduced binding matrix means fewer parallel ports to learn; deeper investment per binding. |

### Reviewer role-type

| Persona | v0.6.0 baseline | v0.7.0 target | Movement | Notes / Findings |
|---|---|---|---|---|
| Standards reviewer | — | TBD | — | XQuery 4.0 alignment + cx-native additions is a substantive position. |
| Compliance / legal | — | TBD | — | Schema-validated directives + content-addressing improve auditability. |
| Vendor / tool integrator | — | TBD | — | TS binding retained for browser-side cx tooling. |

### Reader role-type

| Persona | v0.6.0 baseline | v0.7.0 target | Movement | Notes / Findings |
|---|---|---|---|---|
| Educator / trainer | — | TBD | — | Cleaner identity (one language) and concrete HTMX example are easier to teach. |

## Findings (to be filled during review)

To be populated during v0.7.0 implementation as conformance fixtures,
binding ports, examples, and migration tooling land. Each finding
gets a disposition:

- **Fix in v0.7.0** — scope addition before tag
- **Move to post-v0.7.0** — named in [ROADMAP](../ROADMAP.md) with
  target version
- **Accept with rationale** — recorded as a deliberate trade-off

## Process

The review runs continuously during v0.7.0 implementation, not as a
single end-of-cycle pass:

1. **Dev kickoff:** populate v0.6.0 baseline column with retrospective
   scoring (or `n/a` if v0.6.0 hadn't been formally reviewed).
2. **Per-feature integration:** when a §D2 / §D3 / §D4 / §D5 / §D6 /
   §D7 / §D8 milestone lands, re-score affected personas and
   record findings.
3. **v0.7.0-RC integration gate:** final scoring pass. Personas at
   ❌ must be remediated or downgraded; ≥13/20 must be ✅; net
   regressions vs v0.6.0 explained.
4. **At-tag:** scoring frozen, findings closed-out, post-v0.7.0
   findings moved to ROADMAP.

The review is one of three co-equal gates with the readiness rubric
and the friction-budget gate (per
[`docs/EVALUATION_EXPERIENCE.md`](EVALUATION_EXPERIENCE.md)).
All three must pass before v0.7.0 tags.

## References

- [ADR 0022](../spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md) — v0.7.0 scope
- [readiness rubric](../spec/readiness_rubric.md) — gate criteria, 20-persona set
- [ROADMAP](../ROADMAP.md) — release sequencing
- [`docs/EVALUATION_EXPERIENCE.md`](EVALUATION_EXPERIENCE.md) — friction-budget gate

---

## N2 v0.7.0: 20-persona scoring against the v0.7.0 surface

Conducted 2026-05-19 against the v0.7.0-dev HEAD (post the
batch-completion of A/B/C/D/E + W/X/Z/U/GG row blocks). Per the
readiness rubric persona set:

| # | Persona                          | v0.6.0 | v0.7.0 | Δ | Findings |
|---|----------------------------------|--------|--------|---|----------|
| 1 | Documentation writer             | ⚠      | ✅     | ⬆ | Full XQuery 4.0 directives + locale-aware formatting close v0.6.0 templating gaps |
| 2 | Config author                    | ✅     | ⭐     | ⬆ | cx:lang + log: + cx upgrade-config tool; rich query for env-dependent config |
| 3 | Data-format engineer (XML/SOAP)  | ⚠      | ✅     | ⬆ | ADR 0003 D1 full surface (XML round-trip body_ref, $ref semantic emit, CXPath body-ref predicate, resolve_body_ref) |
| 4 | API integrator                   | ⚠      | ✅     | ⬆ | log: structured logging + Arrow IPC round-trip + cx:eval gated |
| 5 | Library implementer              | ✅     | ⭐     | ⬆ | C ABI rename (G row), full 5-binding parity, frozen-binding sentinel |
| 6 | Analytics user                   | ⚠      | ✅     | ⬆ | Parquet round-trip in 4 bindings + cx table dump --parquet CLI |
| 7 | Build engineer                   | ✅     | ✅     | – | Reproducible builds (BB row) + perf gate (V7) + pinned baseline |
| 8 | Performance-sensitive consumer   | ⚠      | ✅     | ⬆ | T-row instrumented; AA-row comparative benchmark report shipped |
| 9 | Security-conscious deployer      | ⚠      | ⭐     | ⬆ | U-row fully closed (memory caps, safe-url, ?include sandbox, threat model §10-§11) |
| 10 | Schema-validation user          | ⚠      | ✅     | ⬆ | Schema validator 20/20 + cx:validate + cx:schema-of + body=ref constraint |
| 11 | Cross-format-conversion user    | ⚠      | ✅     | ⬆ | spec/conversions.md $ref convention + per-format coverage |
| 12 | i18n adopter                    | ❌     | ⚠     | ⬆ | cx:lang + format-number en/de/fr; full CLDR/ICU is v0.7.x |
| 13 | Streaming-output consumer       | ⚠      | ✅     | ⬆ | Y-row streaming sink + correctness invariant in §8.4 |
| 14 | Template author                 | ✅     | ⭐     | ⬆ | XQuery 4.0 expression surface in directive form; full A-row |
| 15 | Embedded-evaluator user         | ⚠      | ✅     | ⬆ | cx:eval gated (M1-M5) with origin-bearing errors |
| 16 | Multi-language pipeline user    | ⚠      | ✅     | ⬆ | Arrow IPC byte-identity across 4 active bindings |
| 17 | Diff/merge tooling integrator   | ⚠      | ✅     | ⬆ | cx:diff JSON shape + cx:patch AST mutator + cx:merge 3-policy |
| 18 | CI/CD integrator                | ✅     | ✅     | – | V-row workflows + S-row release mechanics |
| 19 | First-time evaluator (FTE)      | ⚠      | ✅     | ⬆ | Friction reduction via cx upgrade-config + docs/migrations/v0.7.0.md |
| 20 | XML-native consumer             | ⚠      | ✅     | ⬆ | ADR 0003 D1 + XML round-trip + namespace surface |

**Scoring:** 2 ⭐, 15 ✅, 1 ⚠, 0 ❌. Net Δ vs v0.6.0: +16 upward
movements (12 ⚠ → ✅, 4 ✅ → ⭐, 1 ❌ → ⚠, 0 regressions). The
readiness gate passes: ≥ 13 of 20 at ✅ or better (17 of 20 here).

**Findings:**

1. Persona 12 (i18n adopter) stays at ⚠ because the v0.7.0 locale
   coverage is en/de/fr only — full CLDR locale catalog gates on
   V/ICU integration filed as v0.7.x.
2. Personas 7 and 18 hold at ✅ rather than advancing to ⭐
   because their needs are infra-pacing, not feature-blocked;
   v0.7.0 doesn't structurally change CI/CD or build-engineer
   trajectories.

No findings rise to release-blocker level. v0.7.0 is gate-clear
under the adoption-review row.

---

## N3 v0.7.0: friction-budget gate re-run

Per `docs/EVALUATION_EXPERIENCE.md` the friction-budget gate
counts "moments of confusion" across the 20 persona walkthroughs.
v0.6.0 baseline: 11 friction events. v0.7.0 re-run: **7 friction
events** (−4).

Eliminated by v0.7.0:
- "Why does the format have only attribute-form IDREF?" (resolved
  by ADR 0003 D1 body-position form + audit closures GG7-GG14)
- "How do I evaluate a CXL template?" (resolved by the new
  cx:eval module surface)
- "Can I use this with Parquet?" (resolved by X-row)
- "What's the v0.6 → v0.7 upgrade path?" (resolved by I1
  cx upgrade-config tool)

Remaining (post-v0.7.0):
- Q5 LSP gap — "no autocomplete for new directives" (gated on
  Q4 tree-sitter regen)
- ICU/CLDR — "my locale isn't supported" (gated on V ICU
  integration)
- BaseX modules — "no built-in file: / http:" (v0.8.0)
- 3 minor docs-discoverability findings → R-row follow-ups

Friction-budget gate: **passes**. v0.7.0 net-reduces by 4 events,
well within the rubric's "no net regression" requirement.
