# Rulings 2026-09-03 — #1260 the canonical act form (CA)

**Status: CA-1, CA-2, CA-3 RULED (a) 2026-09-03 under the owner's standing
letter-acceptance rule (2026-08-05: "accept all recommendations if they are
the best long term for cx"; the owner's 2026-09-03 instruction to proceed
autonomously); each re-verified against the world-class bar before recording
(one form, document-native, replayable from the record, general over
non-scalar fields). CA-2 amends WF-1's indicative `do=` + `[args …]` sketch
and was flagged to the owner for veto by letter — not vetoed. CA-4
(sequencing the host cutover) RULED (a) BY THE OWNER 2026-09-03 ("1a"):
#1260 gets its own landing ahead of #1265, cutover-first.** Proposed
and recorded BEFORE any spec text per the #832 process rule (commit
209f53fe6, then ruled and the draft flipped in the following commit). The
edit map at the end lands with the CA-4 implementation landing,
ruling-gated. The flow spec adopted the ruling before its G3 and graduated
the same day: `spec/03-approved/std-lib/flow.md` (its §13 item "#1260 ruled
and the `[args …]` form flipped"). Ruling ids `1260-CA-1 … 1260-CA-4`.

**Inputs read.** #1260 (the filing: one act, two spellings — `[do 'verb'
[field …]]` on the wire, `[intent verb= field=]` at the module boundary);
`xap.md` §3.4 (emit), §13.1 (Intent = `[do …]`); `xap_grammar_composition.md`
§5 (ρ), §6.1 (N-COMPOSE-7: the parameter list is `[intent [do :v [a] [b]]]`),
§8.2; `xap_feature_distribution_market.md` §1.2 (`apply ($verb $intent
$store)`), §6.3 (`POST /intent`); `journal.md` (the two saga signatures);
`modules/cx.md` (`cx:propose`'s `[args {param: value}]` record); `cxdm.md`
§2.3 (atom lexical rule), §2.4 (attributes are scalar-only, E211);
`ledger/rulings_2026_09_03_workflow_789.md` WF-1 (the step names its act by
qualified name; "the act's fields ride in the canonical act form #1260 rules
— this spec ADOPTS that form and mints no third spelling"); the shipped code
`vcx/platform/stdlib_xap.v` (`xap_emit_prepare`, `xap_emit_slots`),
`stdlib_xap_serve_notd_wasm32_emcc.v` (`xap_web_intent`),
`stdlib_xap_host_notd_wasm32_emcc.v` (`xap_host_intent`),
`coordination.v` (the saga runner's `[args {…}]` binding); fixtures
`xap-compose-034` (907), `xap-dist` (1010, 048), `journal-139/140/141`;
`vcx/cmd/xap_init_templates.v` (the scaffold's `compose.cx` seed).

---

## The scan — every shipped spelling of an act, tabulated

| # | Spelling | Head | Fields | Where (shipped) |
|---|---|---|---|---|
| A1 | `[do :verb [field value]…]` — emission | atom term | CHILD elements | `[$xap:emit]` in-process: the scaffold seed (`compose.cx`), demos d2/d3/d4, `reference/shop/cascade.cx`, `bench/xap` ×3, `design/787/w5`, ~60 V test sites |
| A2 | `[event actor=… [do 'ns/verb' [field value]…]]` — the committed record | qualified STRING (ρ rewrites item 0) | children | the durable envelope; fixtures `xap-compose-034` (`[do 'door/unlock']`), 756/845 |
| A3 | `[intent [do :verb [param]…]]` — the grammar's declaration | atom | children = the parameter list (N-COMPOSE-7) | every `feature.cxd` (124 sites in `xap-compose.cxd`; reference, market, oriel features) |
| A4 | `emits: ([do :verb [slot :type]…])` — component registration | atom | typed child slots | serve components (cascade.cx, scaffold, demos) — `xap_emit_slots` reads the slot NAMES from these children |
| A5 | `POST /intent/<verb>` + form-urlencoded fields — the serve bridge's web wire | URL | form fields → `xap_web_intent` builds A1 (one child per declared slot) | `x/ux-web.cx`, oriel, d3 |
| B1 | `[intent verb="v" feature= author= role= field="v"…]` — the deployment HOST's `POST /intent` body | attribute | ATTRIBUTES, mixed with envelope facts (author, role, ρ focus) | distribution §6.3; `docs/dev/client-and-views.md`; `features-authoring.md` (`[check kind=act intent="[intent verb=…]"]`); `xap_umbrella_test.v` ×14 |
| B2 | `apply ($verb $intent $store)` — the module boundary | `$verb` = qualified string | `$intent` = the B1 element; modules read `$intent//intent/@field` | distribution §1.2; docs-src 19; `xap-dist-048`; the host test module |
| C1 | `[step … [fn $cmd] [args {k: v}]]` — the saga step | closure | MAP keyed by parameter name | `journal.md`, `stdlib/journal.cx`, `journal-139/140/141`; the flow draft's §2.1 (marked "flips with #1260") |
| C2 | `[proposal … [args {param: value}]]` — the engine's binding record | — | MAP, name-keyed over the WHOLE parameter list, post-default | `cx.md` `cx:propose` (L113); stream 18 (`cmd-023`) |

Two facts the filing did not have:

1. **The host path drops the fields from the record.** `xap_host_intent`
   journals `do_el := [do 'ns/verb']` — the qualified head ALONE — and hands
   `apply` the B1 element with the fields
   (`stdlib_xap_host_notd_wasm32_emcc.v`: `do_el := xap_elem('do', [],
   [xap_str(qualified)])`, then `invoke_closure(apply, [qualified,
   cx.mk_element(intent), h.store])`). A host-committed act is therefore
   **unreplayable from the journal**: the record says who and which verb,
   never what. The filing's "translation is where a field is dropped without
   a refusal" is not a risk on this path; it is the shipped behaviour, for
   every field. (Correction 2026-09-03: an earlier revision cited fixture
   `xap-dist-040` line 1010 as evidence; that fixture emits `[do
   :place-order]` in-process with no fields in its INPUT, so it shows
   nothing about the host. No host test or fixture pins the journaled act's
   fields today — the CA-4 landing adds that pin.)
2. **Attributes cannot carry an act in general.** `cxdm.md` §2.4: attributes
   are scalar-only (E211 refuses a node-valued attribute). An act whose
   field is a list (order lines), a record (an address), a `[bounds …]`
   block or a geo-point has no attribute spelling. And `cxdm.md` §2.3's
   atom rule `[A-Za-z_][A-Za-z0-9_-]*` admits no `/`, so a QUALIFIED head
   can never be an atom — which is why ρ already rewrites `:sign` to
   `'guestbook/sign'` at commit (A1 → A2).

---

## CA-1 — the canonical act form — RECOMMENDED: (a)

- **(a) RECOMMENDED — ONE act: `[do 'ns/verb' [field value]…]`, the child
  form the journal already records, at every boundary.** Head = the
  qualified name as a string; a bare `:term` at emission is a TERM that ρ
  resolves (composition §5, "qualified always wins") and is never recorded.
  Fields = one child element per parameter, named as the grammar's
  `[intent [do :v [field]…]]` names them — the declaration IS the act with
  its fields empty, so validation against N-COMPOSE-7 is a structural
  comparison, and an EMPTY field element means "supplied by the performer"
  (the human-task and agent cases) while an ABSENT one means absent. The
  module boundary receives THE COMMITTED ELEMENT: `apply ($verb $intent
  $store)` keeps its arity, `$verb` stays the qualified string (it equals
  the head text), and `$intent` becomes the very `[do …]` the journal
  appended — same Tier-1 address, no translation, a module reads
  `$intent/id`. Envelope facts (actor, claimed author/role under auth-off,
  ρ focus) live OUTSIDE the act: the host wire carries the act inside the
  envelope shape the journal already uses (`[event actor=… [do …]]` in raw
  mode; the XSP `request` frame's `[payload [do …]]` under the envelope
  codec), and the proven principal overrides a claim exactly as §4.12 says
  today. **What it DELETES:** B1 — `[intent verb= field=…]` as an act
  carrier (the host's `POST /intent` body, the fourteen test bodies, the
  `client-and-views` and `features-authoring` examples, the acceptance
  check's `intent="[intent verb=…]"` text); B2's attribute reads
  (`$intent//intent/@jam`); the host's field-stripping `do_el`; C1's map in
  a flow step (CA-2). **What it KEEPS:** A1–A5 byte-for-byte (the scaffold
  seed, every demo, every `[$xap:on [do :sign [name $n]]]` pattern, the bus's
  `[do …]`-shaped matching, `emits` slots, the web bridge), `apply`'s
  three-argument shape, the `[refused reason=]` answer, and C2 — the
  engine's post-default `[args {param: value}]` binding record is a
  DIFFERENT LAYER (what `cx:propose` computed, not what an author wrote)
  and stays where `cx.md` put it; the runner builds it from the children
  exactly as `coordination.v` builds it from map entries today (two lists,
  labels and values). **Strongest counter:** the host's attribute form is
  compact and the reference client docs teach it. **Answer:** compactness
  bought unreplayable records; a form that cannot spell a list-valued field
  cannot be the canonical form of a general engine; and the docs teach one
  form to the browser (A5 → A1) and another to the API client (B1) for the
  same act — the filing's "same afternoon".
- **(b) attribute form canonical (`[do 'v' field=v…]` / `[intent verb=
  …]`).** REFUSED: deletes A1–A5 (the whole in-process and web wire, the
  grammar's declaration shape, `emits` slots, every `[$xap:on]` pattern) and
  cannot express a non-scalar field (fact 2) or a performer-supplied hole
  (an absent attribute reads as absence — the filing's own point).
- **(c) both forms plus a converter (`[$xap:intent-of DO]` /
  `[$xap:do-of INTENT]`).** REFUSED: dual-accept; deletes nothing; the
  converter runs AFTER the host has already appended the field-less record
  (fact 1), so it cannot restore the act of record; and it makes the
  carrier-document attribute walk a permanent adopter chore instead of
  removing it.
- **(d) map form canonical (`[do 'v' {field: value}]`, the saga's
  `[args {…}]`).** Rejected: an act is a DOCUMENT — journaled, content-
  addressed, matched by `[$xap:on]` patterns and bus `[do …]` matching, read
  by CXPath (`when=` in a flow) — and a map inside an element is a value,
  not structure: patterns stop binding, `$run//do/amount` becomes `.amount`
  dialect, and A3's parameter list would have to be re-spelled as a map of
  types. The one thing (d) has — name-keyed binding into a def's parameter
  list — (a) keeps at the engine layer (C2).

## CA-2 — how a flow step carries its act — RECOMMENDED: (a)

WF-1 ruled that a step names its act by QUALIFIED NAME, never by closure,
and sketched `do=<qualified act> [args …]?` while saying "the spec fixes
syntax; the ruling fixes what is in it" and "the act's fields ride in the
canonical act form #1260 rules — mints no third spelling". CA-1 decides
the form; this letter decides the carrier, and it AMENDS WF-1's sketch —
the owner may veto it by letter.

- **(a) RECOMMENDED — the step carries the act itself as a child:
  `[step name="reserve-inventory" [do 'inventory/reserve' [sku $args/sku]
  [qty $args/qty]]]`.** The flow document contains the act in the exact
  shape the journal will record it, with `$args/…` and result paths as the
  template holes; `validate` compares the `[do …]` children against the
  grammar's `[intent [do …]]` list structurally; `simulate`, fixtures and
  the WF-17 picture read the same element; a `by=:principal` step writes
  `[do 'orders/approve' [order $args/order] [decision]]` and the empty
  `[decision]` is the field the approver supplies — N-COMPOSE-7's own
  spelling. No new vocabulary: `do` is xap's word (§13.1) and no tenth flow
  word enters. **DELETES:** `do=` on `step`, the step-level `[args …]`
  container, C1's `[args {…}]`. **KEEPS:** the flow-level `[args …]`
  declaration (CA-3), `name=`, `pivot=`, `by=`, `to=`, `when=`, `deadline=`,
  `[escalate]`, `[bounds]`, the WF-1 resolution law (the head resolves at
  `validate` and `start` through the ONE resolver; `CXER4953` unchanged).
  **Strongest counter:** WF-1 was ruled with `do=` in its sketch. **Answer:**
  `do=` + `[args …]` splits ONE act across an attribute and a sibling
  container — the only shape in which the flow does not carry the record's
  shape, i.e. exactly the third spelling WF-1 forbade; WF-1's substance
  (qualified name, never a closure, resolved at validation) is untouched.
- **(b) `do=` + `[args [sku $args/sku] [qty $args/qty]]`.** Rejected: child
  form for the fields but a third carrier for the head; the runner
  reassembles an act the author could have written; every consumer
  (validate, simulate, diagram, studio) learns a step-only shape.
- **(c) `do=` + `[args {…}]` (the shipped saga form).** Rejected by CA-1(d).

## CA-3 — the run's input record — RECOMMENDED: (a)

- **(a) RECOMMENDED — child form throughout: the flow declares
  `[args [sku ::string] [qty ::int]…]` (the `.cxs` declaration forms, as
  drafted), `start` takes the record as `[args [sku "88"] [qty 1]…]`
  (`$args::element`), the record pins it verbatim, and `cx flow run FILE
  --sku=88 --qty=1` builds that element.** Then `$args/sku` in a `when=`
  guard and in a step's `[do …]` is literal CXPath over the recorded
  document — one access dialect for the whole record. **DELETES:**
  `$args::map` on `start` / `simulate`. **KEEPS:** the `CXER4965` check of
  the record against the declaration; the `.cxs` declaration forms.
- **(b) `start` takes a map and lays it out as children.** Rejected: a
  map→children translation at the one boundary the filing is about; the
  fixture that starts a run and the record it produces would differ in
  spelling.

## CA-4 — sequencing the host cutover — RULED (a) BY OWNER 2026-09-03

Fact 1 is a shipped soundness defect in `cx-xap`'s deployment host, not a
workflow-track item: today no host-committed act can be replayed from the
journal. The owner's standing policy is that `prio:high` bugs are fixed
in-line, ASAP; the #789 plan had the #1260 edit map landing with #1265 W1.

- **(a) RECOMMENDED — #1260 gets its OWN landing ahead of #1265, on a
  release branch, cutover-first:** `xap_host_intent` accepts the act
  (`[event actor= [do …]]` raw / XSP `[payload [do …]]`), journals it
  whole, hands `apply` the committed element; the fourteen test bodies, the
  `xap-dist` 1010 expectation (gains its fields), docs-src 19, the two
  `docs/dev` pages, the acceptance-check text and the distribution spec's
  §1.2/§6.3 sentences flip in the same change; `cx xap init` shows the seed
  replayed through emit AND the host. Label `bug` + `area:xap` +
  `prio:high`. **Why:** it unblocks any "replayed through both" fixture the
  flow's W1 needs and fixes an audit-trail hole independent of #789.
- **(b) fold into #1265 W1.** The plan of record; leaves the host journaling
  field-less acts until the workflow campaign opens.

---

## Edit map (ruling-gated; lands with the CA-4 landing, NOT this branch)

| File | Edit |
|---|---|
| `xap/xap_feature_distribution_market.md` §1.2 | `apply ($verb $intent $store)`: "`$intent` is the committed `[do …]` element — the value the journal appended, fields as children"; §6.3 `POST /intent`: the body carries the act in the journal envelope shape (raw) or the XSP request payload; envelope facts never ride the act |
| `xap/xap.md` §3.4 | one sentence: the committed event's `[do …]` is THE act form at every boundary (wire, record, module) — cite this ruling |
| `vcx/platform/stdlib_xap_host_notd_wasm32_emcc.v` `xap_host_intent` | decode `[event actor=? [do …]]` / `[payload [do …]]`; qualify item 0 via ρ; append the whole act; `invoke_closure(apply, [qualified, <committed do>, store])`; refuse an `[intent …]` body as a value naming the canonical form |
| `vcx/tests/xap_umbrella_test.v` (14 bodies), host test module (`@jam`/`@stuck` reads → child reads) | cutover |
| `conformance/stdlib/xap-dist.cxd` 1010 | the three events carry their fields; add: host-posted act journaled byte-identical (Tier-1 equal) and handed to `apply`; negative: attribute body refused; a list-valued field round-trips |
| `docs/dev/client-and-views.md`, `docs/dev/features-authoring.md`, `docs-src/canonical/sections/19-xap-distribution.cxd` | the examples and the acceptance `check … intent="…"` text |
| `vcx/cmd/xap_init_templates.v` | the seed story replays through emit and the host (already A1 — add the host leg) |
| `std-lib/journal.md`, `conformance/stdlib/journal.cxd` | per `flow.md` §12 (saga retirement) — the flow's fixtures use CA-2's shape |

## Fixtures the flow draft carries (authored with #1265 W1)

positive: a step's `[do …]` with holes filled equals the journaled act
(Tier-1 address equal); an empty field on a `by=:principal` step is
completed by the approver's act; a list-valued field (order lines) rides a
step and the record. negative: `do=` on a step refused by `validate`
(`CXER4952`, "the act is the `[do …]` child"); a step whose `[do …]`
children do not match the grammar's `[intent]` list (`CXER4953` class);
a map-valued `[args {…}]` in a step refused.
