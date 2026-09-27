# Owner decisions 2026-09-26 — Letter 40, end-user automation authoring (#1498): AA-1…AA-6

**Status: RULED (owner, 2026-09-26 ~23:3xZ, in session, on Letter 40 posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 23:2xZ; SD-2 required the design
letter first).** The full argument for each option is the board's letter; this page records what was
ruled. Every recommendation was (a).

## The owner's word, verbatim

"all a" — after asking "what are the best options for cx long term?" and hearing the six (a)s argued.

## AA-1 — a skeleton is a CX document shipped as data (L40.1 = (a))

An automation skeleton is a flow document plus one `[on …]` row, each TODO a typed named slot
(`[slot name= kind=act|field|role|principal|duration|value]`), shipped as data in cx-platform-flow;
composition.md lists the skeletons as a closed sub-set (§3.10 "automation skeletons"), each with a
reference example; the scaffold, the generated primer chapter and the studio read the same documents;
the seven §3 pattern bodies move from V literals into this data form in the same branch. Rejected:
archetype packages (flow#1 is off v0.18); a feature grammar row (R-3); a studio-side form.

## AA-2 — four skeletons and one selection attribute (L40.2 = (a))

`on-change-act`, `on-change-approve`, `on-change-check`, `on-schedule-act`, named `<trigger>-<shape>`,
using only kinds the host serves and vocabulary already built. The `intent` row gains ONE selection
attribute, `act='ns/verb'` (the entry's qualified intent name, the do-form's string, KIT-2), so only
the acts that matter start a run; the value test stays a `when=` guard; §4.25 unchanged. Not in the
set: `webhook`, `fold`, `map`/`until` bodies. Rejected: no `act=` (one run per act on the stream); one
skeleton only.

## AA-3 — one pure `fill`, two callers (L40.3 = (a))

`cx xap scaffold <skeleton>` keeps §3.9's contract and refuses with the seven patterns and the four
skeletons listed; one new pure def `fill` takes a skeleton and `[answers [<slot> <value>]…]` and
returns the flow document and its `[on …]` row with no slot open, or refuses naming every unanswered
or wrongly-typed slot in one refusal; `cx xap scaffold <skeleton> --answers FILE` calls it and the
studio calls the same def on the host. Rejected: the studio filling in its own code; the scaffold
writing into the deployment document.

## AA-4 — a fourth studio plane filled from closed pick-lists (L40.4 = (a))

An "automations" plane beside P0-114's three (the plane §4.17 already names), commands `ux:automate
[skeleton=<addr>] [answers …]` and `ux:retire-automation`, gated by a `ux:automate` claim distinct
from `ux:edit`; each slot a CLOSED pick-list (acts ρ resolves that the author's grants permit, the
noun's and the tenant's fields, the roster's roles and principals); the browser never sends a flow
document — the server runs `fill` then `validate` and the PEP rechecks; no skeleton carries
`pivot=true`, `by=:agent`, `by=:peer`, `flow=` or `[compute …]`; `as=` is the session principal.
P0-114's "three planes" becomes four. Rejected: the full flow canvas this release; scaffold-only.

## AA-5 — a published automation lives on the tenant's own automation stream (L40.5 = (a))

Publishing appends `[automation-published skeleton= flow= [answers …] [on …]]`, actor-stamped, to
the tenant's automation stream (P0-119's third channel); the host's binding set is the deployment
document's `[on …]` rows plus the fold of that stream; the flow's bytes are served from `[docs]` by
address; a republish is a new address starting new runs only, in-flight runs keep their pin; retiring
is an appended entry; a new skeleton version is adopted by replaying the answers (P0-120). §6.3.1 of
the distribution spec gains one sentence. Rejected: rewriting the deployment document; a feature
package per automation.

## AA-6 — two grades, one fixture shape (L40.6 = (a))

In-tree: each skeleton's reference `[answers]` document, `fill`'s output expected byte for byte, a
clean `validate`, `simulate` over a declared result table reaching `:done` and each skipped or
refused path, then a host-lane case whose expected result is the folded run record. At publish: the
server runs `simulate` over the skeleton's path table and refuses a publish that does not reach
`:done`; the studio shows the simulated overlay before the commit. Rejected: validate-only at
publish; the live run as the first evidence.

## Order (as the letter tabled it)

1. One spec branch, read by the owner before code: composition.md §3.10, flow.md §4.24 `act=`,
   ux.md P0-114 and the plane's section, §3.9 and the CLI flag, the §6.3.1 sentence — every sentence
   fixture-backed where a fixture can exist, the rest cited to this page.
2. The skeleton data, `fill` and the scaffold. 3. `act=` and the host's binding union. 4. The plane.
Deferred to the next release: the flow canvas plane, agent authoring and the archetype library,
`map`/`until`/`[compute]`/`by=:agent` in skeletons, a `migrate` UI, the `webhook` and `fold` kinds.
