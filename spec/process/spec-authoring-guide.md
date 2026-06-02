# CX Spec Authoring Guide

**Status:** Current for v0.8.0

Authoring conventions for normative CX specification documents. Reviewers use this guide when checking whether a spec is admission-ready. The corpus governance rules themselves (G1 mutual compatibility, G2 terseness, G3 user-only approval) live in [`governance.md`](governance.md) §13; this file is the practical author-facing companion.

## 1 — The destruction test

A complete CX specification passes this test: if all code and implementation history were destroyed and only the specs remained, a competent engineer could recreate CX — parser, AST, format conversions, document API, CXPath, streaming, ABI, and language bindings — with no divergence from the original design.

Ambiguity is a first-class defect. Wherever a reasonable implementor could make two correct-seeming choices and produce different observable behaviour, the spec has failed.

## 2 — Quality criteria

A spec section passes if a competent engineer who has never seen the CX codebase could read it and produce an implementation that passes the conformance suite.

A spec section fails if:

- It describes what a method does without specifying what it returns for every possible input, including missing, empty, and error cases.
- It uses "appropriate", "reasonable", "typical", or "usually" without a normative default.
- It specifies the happy path but leaves error paths implicit.
- Two reasonable engineers reading it could make different implementation choices that produce different observable behaviour.
- It references a concept defined elsewhere without citing where.

Every method signature in API-bearing specs ([`../misc/api.md`](../misc/api.md), [`../core/code.md`](../core/code.md), [`../misc/bindings.md`](../misc/bindings.md)) must specify:

1. What it returns on success.
2. What it returns when the target is absent (not an error).
3. What constitutes a programming error (panic/throw) vs a soft return.

Every binary-format spec ([`../core/data-bin.md`](../core/data-bin.md), [`../core/ast-bin.md`](../core/ast-bin.md), [`../core/streaming.md`](../core/streaming.md)) must include a hex-annotated test vector.

> **Candidate refinement (awaiting G3, tied to the errors/effects/fp SAP §1).** When the four-channel value model is admitted, the API-bearing checklist above (items 1–3) refines for **CX language/stdlib** specs to the four channels: what it returns as a **value**, on **absence** (empty node-set/sequence), as a **failure** (`[err]`, auto-propagating), and as a **reported problem** (`[invalid …]`, flows as data). Until SAP §1 graduates, the three-item form above remains current. *(Not yet admitted — does not bind authors until G3.)*

## 3 — Orthogonality (uniform application)

> **Status: CANDIDATE — awaiting G3.** This section was authored alongside the errors/effects/fp SAP and is **not yet admitted**; it does not bind authors until the user approves it (`governance.md` §13 G3). The rest of this guide is Current for v0.8.0. On approval, drop this banner and add §3 to the readiness rubric's reviewer checklist.

A language feature MUST apply uniformly across its **natural domain** — every value kind it could sensibly act on, every position, every type. A user must never have to discover *by trial* that a feature works on X but not the cognate Y. The canonical smell: a `sort` that silently works on ints but not floats is **broken**, not "limited." Asymmetry forces every user to carry a standing question — *how limited is this feature?* — which is a tax on every use and a first-class defect, the same way ambiguity is (§1).

Any cell a feature does **not** cover MUST be a **documented, justified exception**, never an accident. Three obligations make this enforceable:

1. **Applicability Matrix (required per feature).** Every feature's spec section carries a matrix of its domain dimensions × ✅ / ❌ / — (not-applicable), with a one-line rationale on every ❌ **and** every —. Limits become visible at spec-read time, not at use time. A — must be genuinely meaningless (e.g. "spread a scalar" — a scalar has no members), not a hole wearing a dash.
2. **The `UNIFORM` review gate (G3 blocker).** A feature cannot graduate until its matrix is complete and every ❌ is justified *in writing*. An ❌ with no rationale is a defect, not a documented limit. For features with observable surface, every ✅ cell has ≥1 conformance fixture and every justified ❌ has a negative fixture pinning the documented limit.
3. **Cognate-coverage rule.** When a capability is admitted for one value kind (e.g. `*`/`**` spread over element children), the same capability for cognate kinds (sequence/array members) is admitted **in the same pass**, or its absence is justified in the matrix. This is the no-dual-accept discipline (`governance.md`, no-migration-runway posture) applied to feature *domains*: you do not ship the asymmetry now and "generalize later."

**Rollout scope (so this is not retroactively destabilizing).** These obligations bind **features newly admitted or materially changed from this section's G3-approval forward**. Already-admitted specs are **conformant by grandfather** — they are not made non-compliant the moment this lands. Retrofitting matrices onto the existing corpus is a **backlog audit** (tracked in `readiness-rubric.md`), done opportunistically when a spec is next revised, **never a release blocker** on its own. "Materially changed" = adding/altering observable surface (a new operation, value kind, position, or type domain), not a typo or clarification.

**Worked example (the audit that motivated this section — and a lesson in auditing *correctly*).** `[?match]`/`[case]` pattern matching ranges over the value kinds {scalar, element + attrs, sequence, array, map, …} × {literal, `$bind`, `_`, spread, type-test}. The first audit pass *misreported* the matrix: it tested attributes with bare `code=x` and concluded attributes "didn't match" — but CX *admits* attribute matching via **`@code=x`** (rule 6, which the build runs today) **and** plain **`code=x`** (rule 9, spec-valid but with a current build conformance gap); the bug was the **audit method**, not the feature. A corrected pass found the genuine gaps were narrower: attribute/map value-*capture*, sequence/array *spread*, array *literals*, and *type-kind* tests. Three lessons the guardrail enforces: **(1)** build the matrix by **running the real parser with the real surface** (a wrong-syntax probe produces a false ❌ — audit-before-trust); **(2)** reconcile against the **spec text**, not just the impl — a form the spec admits but the build rejects is a *conformance gap* (a ✅-with-an-impl-bug), not a ❌; **(3)** the fix is to specify the **complete** grammar to an all-✅-or-justified matrix, not to patch the one cell someone hit. The matrix is the artifact that turns "we think it's general" into "here is the proof, cell by cell" — *provided the proof was run correctly*.

## 4 — Companion documents

- [`governance.md`](governance.md) — release process, audit framework, and the load-bearing G1/G2/G3 rules.
- [`readiness-rubric.md`](readiness-rubric.md) — release-readiness gates; quality criteria here are a precondition for any spec row to pass.
- [`threat-model.md`](threat-model.md) — security threat model that hardening-bearing specs cross-reference.
