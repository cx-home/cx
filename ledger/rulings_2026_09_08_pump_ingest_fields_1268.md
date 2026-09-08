# Ruling — a pump-ingested act is subject to the verb's declared parameter list, and the §3.1.2 binding states the mapping (#1268)

**Ruling ids:** 1268-c1, 1268-c2
**Date:** 2026-09-08
**Ruled by:** Fable session, 09:35 ET, on #1268, against the letter sets drafted
there at 09:01 ET.
**Status:** RULED before the work. Recorded here by campaign worker C, which
implements it and rules nothing in it.
**Follows:** `ledger/rulings_2026_09_05_xap_queue.md` — letter (b) of the
original #1268 scope (refuse EXTRAS, tolerate MISSING) stands and is not
revisited here. This ruling answers only what (b) could not reach: the
source-pump ingest path.

## The contradiction that made this a blocker

Five paths reach a committed act; four of them funnel through
`xap_emit_prepare` (`vcx/platform/stdlib_xap.v:2286`), which `:2346` already
declares to be "§4.9 THE pre-commit enforcement point". So the parameter check
belongs there once. But path 4 — the source pump — cannot survive it as the
code stands:

- `XapSourcePump` carries `verb` from the deployment-time §3.1.2 binding map
  (`vcx/platform/stdlib_xap_serve_notd_wasm32_emcc.v:436`, `:465-472`), not
  from the grammar.
- The act it builds (`:678-681`) is
  `cx.mk_element(name: 'do', items: [bus_atom(p.verb), payload])`, where
  `payload` is the entry's `[event …]` child (`:663-667`). **One child, and it
  is named after the source event.**
- `xap.md` §3.1.2 stated that shape normatively: "the intent is
  `[do :<verb> <published event>]`, committed through the SAME PEP → (bound
  journal, §3.1.1) → fold path as any emit".

A published event is a foreign document and satisfies no parameter list, so
§3.1.2 and N-COMPOSE-7-under-(b) contradicted each other the moment a refusal
landed at the funnel. `test_xap_host_arms_source_pumps_only_after_authority` is
the observed casualty. Path 4 is also the one path that ingests data cx did not
author, and today the grammar can explain **none** of what it commits — not
"extras admitted" but the whole payload undeclared.

## 1268-c1 — YES, and the binding states the mapping (letter 1(a))

A pump-ingested act **is** subject to the verb's declared parameter list. The
§3.1.2 binding map gains `fields:` — one entry per declared parameter, each a
CXPath into the published event:

```
fields: {id: "event/@vessel", note: "event/text"}
```

The pump builds a **conforming** act — declared field children, evaluated from
the event — and travels the funnel with **no exemption**. A binding whose
`fields:` does not cover the verb's declared list refuses at
`xap_start_source_pumps`, i.e. **at run, never at first delivery**, which is
already that function's stated contract for a bad binding. A verb whose
`[intent [do :v]]` is the bare fallback needs no `fields:` — the (b) ruling
exempts the fallback, and that is what sidesteps the `registered-at` scaffold
problem.

**Deletes:** `[do :<verb> <published event>]` as the ingested act shape; the
§3.1.2 sentence that states it; and the freedom to point any stream at any verb
without saying how the event becomes that verb's parameters. §3.1.2's "the SAME
PEP → journal → fold path as any emit" sentence now holds **without
qualification** — before this ruling it was true of the path and false of the
admission.

**Why, beyond the letter's own argument (Fable):** this is the inbound half of
`1334-SEAM-a` rule 5. When connectors land (v0.19) their CDC events arrive on
exactly this path, and a kit fulfilled by an external system must have every
ingested row explainable by the kit's grammar — otherwise the journal behind a
fulfilment carries foreign shapes the surface and the agents cannot read. The
binding is where a stream is already tied to a verb, group and actor; the field
mapping belongs beside them.

**The two rejected letters, and why they are dead:**

- **1(b), path 4 exempt.** Cheapest — no new surface, one guard at the funnel.
  Rejected: it establishes a **second admission regime** on the one path whose
  input cx does not control, which the orthogonality objective refuses. A
  journal that carries unexplainable acts only from foreign sources is worse
  than one that carries them everywhere, because the audit reader cannot tell
  which regime produced a row. It also costs a spec edit anyway, to qualify
  "the SAME … path as any emit".
- **1(c), the payload becomes ONE declared parameter** by convention
  (`[intent [do :evidence [event]]]`). Rejected: it forces every source-fed
  verb to declare a parameter whose name is a convention the grammar never
  states and whose type is "whatever the stream publishes" — a parameter that
  tells a client reading the grammar nothing. That over-fits the shared grammar
  to one deployment path and hides the mapping question rather than answering
  it.

## 1268-c2 — the parameter refusal lands FIRST in the §4.9 order (letter 2(a))

`xap_param_refusal` is inserted at `vcx/platform/stdlib_xap.v:2355`, **first**
in the §4.9 order — ahead of types, transitions and checks, because a field the
grammar cannot account for makes those refusals meaningless — and **ahead of**
the §4.11 `xap_intent_with_fields` write-back at `:2368`.

A caller is judged on what the caller sent. A runtime-stamped field can neither
satisfy nor violate that check, and `registered-at` is precisely such a field:
after the write-back it would be an undeclared extra on every act, so the
ordering is not a preference but a correctness condition.

**Deletes:** nothing. This is ordering.

## Scope that lands in the same batch, and why it cannot be split

The ruling says paths 1–3 land with the pump mapping, and the source agrees: a
funnel check alone reds **every** pump act. Splitting it would land a knowingly
red tree.

- **Paths 1, 2, 4** — the funnel check at `stdlib_xap.v:2355`.
- **Path 3, the serve bridge** — `xap_web_intent` reads `xap_gc_verb_params`
  in preference to `xap_emit_slots` (`stdlib_xap.v:3142`). `emits` is the
  **component's** opt, not the grammar's `[params]`: it is a second,
  unadjudicated arity declaration, verbatim the failure N-COMPOSE-7 exists to
  abolish. Today an undeclared form field is **dropped before the funnel ever
  sees it**, and an empty `slots` drops the whole body. After this, an
  undeclared form field is a 403 — a refusal, not a silent drop.
- **Path 5, journal replay** (`xap_fold_committed`, `stdlib_xap.v:1844`)
  bypasses the funnel **by design** and is not touched: replay must reproduce
  what was committed, including acts committed before this ruling.

Reinforcing defect fixed in the same block: `xap_field_type_refusal`
(`stdlib_xap.v:6086`) does `ftype := declared[fe.name] or { continue }` — a
field the noun does not declare is skipped, not flagged. Second silent
acceptance, same cause.

## The iteration rule (re-confirmed in the source; it has already cost one build cycle)

Iterating the act's children: **every ELEMENT item is a field, every SCALAR
item is the designator.** Do **not** skip index 0 positionally —
`[do [field …]]` puts a field at index 0, and a positional skip refuses the
verb name as a field.

## Fixtures, before the fix

Named by the ruling, plus the two the drafted letters argued for:

1. a binding with complete `fields:` ingests and folds;
2. a binding short one parameter refuses **at run**, naming the parameter;
3. an act with an undeclared extra refuses **before** the write-back —
   `registered-at` cannot rescue it;
4. a **missing** declared field is ADMITTED — without this pin a later
   tightening to letter (a) passes unnoticed;
5. present-and-empty vs absent both admitted (the CA-1 rider: **presence**, not
   value, is the discriminator);
6. `POST /intent/<verb>` with an undeclared form field → **403**, not a 200
   with the field dropped;
7. the bare-`[intent [do :v]]` fallback does NOT refuse an extra — the
   exemption pinned as deliberate rather than as an oversight.

The toy door at `vcx/tests/xap_umbrella_test.v:105`/`:526` already declares
`[id] [note] [stuck] [jam]`, so the positive controls are cheap — and it stops
relying on undeclared fields, which #1268's scope requires under every letter.

## What was NOT ruled here

Whether the parameter list should also refuse **missing** fields (the original
letter (a)). It does not: `ledger/rulings_2026_09_05_xap_queue.md` ruled (b),
and fixture 4 above exists to make any future change to that visible.

## RULED: 1268-d — the error code (Fable + owner, 2026-09-08 16:25 ET)

The refusal class `1268-c2` orders first had no code, and the only unspent
code between the §4.9 sub-band and the compose surface was deliberately
reserved: `ledger/rulings_2026_09_05_constraint_grammar_1308.md:249-252`
allocated `CXER4865–4868` as "the band's last free codes" and ended
"`CXER4869` stays reserved"; `xap.md` §8 repeats the reservation. Letters were
drafted on #1268 rather than self-ruled, because "nothing else needs the
reserve" is an argument from absence over a reserve this record did not author.

**1(a) — spend `CXER4869` as `E_XAP_PARAM_UNDECLARED`**: the §4.9 pre-commit
refusal for an act carrying a field the verb's grammar does not declare,
ordered FIRST in the §4.9 item-3 order per `1268-c2`. **The §4.9 sub-band
(`CXER4865–4869`) is now FULL.** The next refusal class discovered at this
enforcement point needs a *band* decision, made with knowledge — not a reserve
spent blind. Checked by the ruling: `4880–4889` are all allocated, so "grow the
band past `4879`" would leave the registered allocation, and reusing
`CXER4867 E_XAP_FIELD_TYPE` would make one code mean two failures §4.6
explicitly separates ("a field the intent does not carry is not a type
failure"). Both refused.

Why the reserve is spent correctly rather than merely conveniently: it was
written in the same sentence that allocated codes for "the grammar-declared
runtime refusals raised at the one pre-commit enforcement point". This refusal
is exactly that class, raised at exactly that point, and ordered first among
its members. A reserve spent on the next member of the class it sits beside is
a reserve working as intended.

**2(a) — the deployment-time binding refusal takes no new code.** A binding
whose `fields` does not cover the verb's declared parameters rides the existing
`[$xap:run]` refusal path (`xap_err_arg_invalid`, the same channel that already
answers for a binding missing `verb:`), naming the verb and the uncovered
parameter. A configuration refusal and a per-act refusal have different
audiences — one is read once by whoever deploys, the other per act by a client,
and only the second is caught programmatically. Spending a second code to
distinguish a refusal that never reaches a client would have cost the band
growth `1(a)` refuses.

Registry rows land in **both** documents this band is registered across:
`xap_grammar_composition.md` §8.1 (the sub-band's own table) and `xap.md` §8's
reserve sentence, which stops saying `CXER4869` is reserved and starts saying
the sub-band is full. One band, two documents, no code defined twice — the
invariant §8 states is preserved by editing both in this landing.
