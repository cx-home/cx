# RULED: 1351-a1, 1351-a2 — one public verb classifies an err result over TEXT

Date: 2026-09-08. Issue: #1351 ("err-result classification is reimplemented in
five places, three of them prefix scanners over rendered text — #1058 T1.1 had
to find each by hand"). Ruled by the owner + Fable on the issue, 2026-09-08
19:00 ET, on the letter sets worker A drafted there. Recorded BEFORE the
implementation, per the spec-freeze rule (rulings-before-edits, register R4.2).

## The ruling, verbatim in substance

**1351-a1 = 1(a).** ONE public verb over TEXT — `[$cx:carries-err TEXT] -> bool`
— backed by the existing `code.output_carries_err` (`vcx/code/eval.v:505-515`),
registered as a platform builtin with a `[fn-doc]`;
`scripts/gen_guide/playground/gen_examples.cx`'s `ERR-OPEN` / `SEQ-ERR-OPEN` /
`SEQ-ERR-MID` constants and the `:455-462` scan are DELETED in the same change.

The reason the verb takes TEXT and not a value: the byte contract belongs to
whatever renders the bytes, so the runtime publishes it once. The VALUE
question is already expressible in CX (`[?match]` plus a walk) and gets no
second face.

**1351-a2 = 2(a).** `stdlib/supervise.cx:121`'s `sup--is-err` STAYS — it is the
narrow value predicate, correct at each of its five uses (`:181`, `:196`,
`:280`, `:328`, `:519`), and folding a text face into a module that holds
values would be the layering error.

**Fixtures required by the ruling.** The verb over each of the three positions
the graders needed four rounds to find (a line beginning `[err `, `([err `,
`, [err `) and one negative: a document that merely CONTAINS the text `[err `
inside quoted content. The playground auditor's verdict over the corpus must be
byte-identical before and after — the red-proof is the deleted constants.
Registry pre-flight for the builtin name. `docs-check` in the lane.

## What the ruling REFUSED

- **1(b), two faces (a text one and a value one).** Refused: the value
  predicate is already writable in CX, so a value face would be a second
  spelling of something the language can already say — the surface duplication
  this campaign has refused three times (`1358-f1`, `1221-b-1a`, `1259-a`).
- **1(c), leave the transliteration with a cross-reference comment.** Refused:
  it leaves the last copy to drift on the next rendered shape, which is the
  entire history of this issue — seven sites found one at a time, plus a
  wave-3 commit message that claimed to have fixed a grader it never touched.
- **2(c), widen `sup--is-err` to recurse into sequences while we are here.**
  Refused unless a use is shown that needs it: a behavior change to a shipped
  module with no failing case behind it is a fix looking for a defect.

## What the implementation DERIVED (not re-decided)

Three things the ruled sentences do not spell out, each forced by a measured
mechanism rather than chosen:

**1. Where the `[fn-doc]` can live.** The `cx:` module has NO `stdlib/cx.cx`.
Its `[?def]` surface is SYNTHESIZED in V at `vcx/code/stdlib_bundle.v`
`codec_module_source()` (the `fmt == 'cx'` block), and its verbs dispatch from
`vcx/code/stdlib_cx.v` `cx_module_stdlib_builtin_env()`. Both the fn-doc GATE
(`scripts/gen_guide/stdlib_docs_check.cx:78`) and the guide's doc RENDERER
(`scripts/gen_guide/guide_build.cx:945`) glob `stdlib/*.cx` + `x/*.cx` only, so
neither can see a synthesized module. The `[fn-doc]` therefore rides at the
registration site — beside the `[?def]` in the synthesized source, where the
module loader classifies it as a top-level PLAIN span and `[$cx:ast]` serves it
in its `docs` array (`spec/03-approved/modules/cx.md` §2.2, the documented doc
lane).

Creating a real `stdlib/cx.cx` to get the doc graded was MEASURED and rejected
as out of scope: `cx` would enter the catalog gate's BUNDLE_SET
(`scripts/stdlib_catalog_gate.cx:64`) while SPEC_SET reads
`spec/03-approved/std-lib/*.md` (`:55`), where no `cx` module spec lives — the
module's spec is `spec/03-approved/modules/cx.md`. That is an orphan-bundle RED
whose fix is re-homing the `cx:` module's spec and moving nine synthesized
`[?def]`s out of V, i.e. a ruling-sized change of its own, not #1351's.

So the doc is carried by the surfaces that ARE live and gated: the normative
`spec/03-approved/modules/cx.md` §2.2 row (spec-freeze-gated) and the
`docs-src/llm/reference-stdlib.md.tmpl` narrative (regenerated and graded by
`make docs-check` — the gate the ruling names). The `[fn-doc]`'s example is
nevertheless backed VERBATIM by `conformance/stdlib/cx.cxd`'s
`cx-164-carries-err-sequence-mid`, which `make test-vcx-suite` runs green, so
the example is a real run and not a claim.

**2. Which spec section the row belongs in.** §2.2 "Eval and analysis", not
§2.1 "Core": the verb answers a question ABOUT a program's rendered output, the
same family as `cx:ast` / `cx:validate` / `cx:anchors`.

**3. `[?const NL '\n']` goes too.** `gen_examples.cx:331`'s `NL` had exactly
one consumer — the per-line split inside the deleted scan (`:454`). It is dead
the moment the scan is, and dead code left behind is not a smaller change.

`vcx/cx/parser.v:1552-1566`'s reserved-EvalName list is deliberately NOT
touched. It has not tracked the dispatch table since #437 (`cx:ast`,
`cx:schema-of`, `cx:version`, `cx:builtins`, `cx:env`, `cx:propose`,
`cx:eval-tree`, `cx:computation-id`, `cx:plan-address`, `cx:type-binding` are
all absent), it is consulted only for `[?Name …]` PI heads
(`vcx/cx/parser.v:1386`), and adding one name to an already-divergent closed
list would be a parity claim nothing checks.

## The count correction, recorded

The issue says "five places"; later comments raise it to seven. Worker A's
letters add an eighth — `stdlib/supervise.cx:121`'s `sup--is-err`, in CX and
narrow. It is NOT a defect (at all five of its uses the value handed to it is a
single result, and `:328` iterates the sequence itself before testing each
item, so the narrowness is correct by construction) and 1351-a2 leaves it
alone. Recorded so the tally is not re-litigated.

## The asymmetry that must survive the change

A grader can only widen what it TOLERATES. "Carries an err ⇒ the run must have
exited 1" is FALSE: a literal err in a data document is DATA echoing itself and
legitimately exits 0 (`program-cast-null-error`). #1058 T1.1 measured that
inversion as two false failures. `cx:carries-err` is documented as a tolerance
test with that reason attached, in the verb's own comment
(`vcx/code/stdlib_cx.v`) and at the deleted scan's site
(`gen_examples.cx`).
