# RULED: 1255-a, 1255-b — the grammar plane's preflight, and rollout order

Date: 2026-09-08. Issue: #1255. Ruled by Fable on the issue, 2026-09-08
09:25 ET, on two letter sets drafted by worker A at 12:37Z. Recorded here
before implementation.

## Why there was a question at all

#1255 was filed as a documentation gap and is not one: the adopter's
customization model landed as a document (`ee81d2f0f`, merged `3678b2ec5`),
and writing it surfaced two **capability** gaps that the document could only
state as gaps with citations. A gap paragraph becomes a mechanism paragraph
only by a ruling, so the document did not block on either.

## 1255-a = Q1(a) — a per-refinement preflight on the grammar plane

`[$xap:instantiate-preflight ARCHETYPE BINDING]`, **report-first**: it
classifies each refinement as

- `clean`,
- `refused`, carrying that refinement's own reason code
  (`CXER4877` / `CXER4878` / `CXER4879`), or
- `redundant`,

and **never raises**.

It is a second FACE over the checks `[$xap:instantiate]` already runs, bound by
the **compose-report / compose agreement law** — one gate function, two faces —
so the report face cannot drift from the enforcing face. As part of this,
`instantiate`'s checks become **total** (every violation reported, not the
first), exactly as `compose` already did for W1–W15.

The fleet-level `cx xap preflight --to <addr>` — Q1(b) — is this verb's
CONSUMER and lands in a later wave. It is not an alternative to it.

**Refused: (c)**, leaving the two planes to teach different models for one
word. That is the shape the ruling names as the thing not to buy: one word,
two models.

### Fixtures the ruling names

- `xap-compose-131`'s v2 reports `redundant` for the tighten the vendor made
  the floor;
- a refused refinement names its code;
- the report face and `instantiate` **agree on every existing compose case**.

## 1255-b = Q2(a) — rollout order is deliberately unprescribed, and says so

One sentence in `spec/03-approved/xap/ux.md` §19.3 and one in the customization
document (`docs-src/llm/model-customization.md.tmpl` §6.2): **CX supplies the
facts** — per-tenant classification, independent pins — **not the policy.** No
normative order, no planner.

## What lands where

| change | file |
|---|---|
| the verb | `vcx/platform/stdlib_xap.v` (registration + the report face over the shared gate) |
| fixtures | `conformance/stdlib/xap-compose.cxd` |
| the intent sentence | `spec/03-approved/xap/ux.md` §19.3 |
| §6.2: two gap paragraphs → one mechanism paragraph + one intent sentence | `docs-src/llm/model-customization.md.tmpl`, then `make docs` |

Commits carry `RULED: 1255-a, 1255-b`. A commit touching `spec/` runs
`make spec-freeze-gate`; the regenerated `docs/llm/` lands in the SAME change
as the template edit.
