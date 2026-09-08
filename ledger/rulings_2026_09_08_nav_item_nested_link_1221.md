# RULED: 1221-a — a `[ux:nav-item]` that swallows a nested `[ux:link]` refuses
# it instead. 1221-b (the `[$xap:serve]` option guard) is NOT ruled here: the
# pre-flight found the question is larger than the issue states and it goes back
# for a decision.

Date: 2026-09-08. Issue: cx-home/cx-private#1221. Campaign: v0.18.0 close-out
(#1354), Lane 1. Ruled by the campaign worker under #1354 rule 7; the diagnosis
these letters rest on was posted on the issue at `2d4dd715b`.

## 1221-a — `[ux:nav-item]` REFUSES a descendant `[ux:link]`

### The mechanism, at the line

`x/ux-web.cx:441`, `lower-nav-item`:

```cx
[$box "li" "ux-nav-item" $el $ctx
  [?element "a" [?attr "href" [$string $el@href]]
    …
    [$ux:label-of $el]]]
```

The anchor is built from the ELEMENT's own `href`/`label` and handed to `$box`
as the entire body. The children are never lowered, so a child `[ux:link]` is
discarded whole — and the tell the issue reports, a missing `class="ux-link"`,
is that discard.

### Ruled: refuse, do not honour

`[ux:nav-item]` **is** the anchor — it emits the `<a>` itself. Honouring a child
`[ux:link]` leaves only two shapes, and both are worse than a refusal:

- emit the child's anchor inside the parent's — invalid HTML (`<a>` may not
  contain `<a>`) with per-browser behaviour;
- hoist the child's `href`/`label` onto its container — a nested element quietly
  rewriting its parent, which is the same class of surprise this issue is
  about, pointed the other way.

Refusing says the true thing: a nav item already is a link, so putting a link
inside one is a mistake about the vocabulary, not a formatting preference.

**DELETES:** the silent discard, and with it the `<a href="">` that renders fine
until it is clicked. It deletes none of the nesting's usefulness, because it had
none — the child never reached the output on either face.

### Construction

The precedent is already in the file: `x/ux.cx:784` refuses `ux-panel-nested`
for exactly this shape with `[?found $el/*//ux:panel]` — the CHILDREN's subtrees
(`/*//`), because the descendant axis includes the element itself and
`$el//ux:link` would refuse nothing useful while `$el//ux:panel` would refuse
every panel. The nav-item guard is that construction with a new code, in
`member-refusals`, and it joins a vocabulary that already carries
`ux-link-no-href` — so the surface already agrees that a dead anchor is a
refusable condition; it had simply never looked in this position.

Fixture: `conformance/stdlib/ux.cxd`, next free id `ux-121`.

**Authored BY HAND in the `.cxd`, and NOT through the generator — a registry
pre-flight finding that reverses the obvious move.** `design/787/tools/gen_ux_fixtures.cx`
is described as the suite's source ("emits the three cx-x/ux conformance suites,
RE-DERIVING every expected output by RUNNING the snippet"), and the instinct is
to add the case there and regenerate. Counted at `425806c5f`, the generator
holds **76** `ux-*` cases and `conformance/stdlib/ux.cxd` holds **83**: `ux-115`
… `ux-120` (the six views cases) and `ux-083` (`gate=enforced`, #1217/#1268)
exist ONLY in the `.cxd`. Regenerating would delete all seven, one of them
gate-enforced. So the generator is a historical seed, not the current source of
truth, and the case is hand-authored — with its `out-text` still DERIVED by
running the snippet through the built binary, which is the property that
mattered, rather than transcribed from belief.

That drift is a real defect and it is NOT #1221's: a tool documented as the
suite's generator that would silently destroy seven cases is its own issue, and
it is recorded here and on #1354 for the owner rather than fixed inside a
refusal-gate change.

## 1221-b — NOT RULED. The pre-flight moved the question.

The issue asks for a closed-set guard over the keys `xap_serve` reads:
`runtime`, `tenant`, `shell`, `auth`, `block` — five, where the demos show
three. The guard was written against that set, and then **reverted before it
landed**, because the corpus pre-flight (#1354 rule 3) found the premise wrong.

**`spec/03-approved/xap/xap.md:236` is normative and says the opposite.** The
§3.1 `run` option table is introduced with:

> `opts` (**every key is also accepted by `serve`**):

and the table is `tenant`, `journal`, `authz`, `sessions`, `components`,
`surfaces`, `handlers`, `resolver`, `sources`, `log-reduce`. `xap_serve` reads
**none of the last nine**. So the gap is not the two stale doc mentions the
issue names — it is **nine spec-promised `serve` options that are inert**, plus
three (`shell`, `auth`, `block`) that the verb honours and no table lists.

A guard over the five would refuse calls the **spec** says are legal. Flipping a
normative sentence is a ruling, and it is a ruling with a real fork in it (does
`serve` grow `run`'s whole option surface, or does the spec stop promising it),
so the letters go on the issue and nothing lands on this half until they are
answered.

**What DID land from this half:** nothing. The docstring at
`stdlib_xap_serve_notd_wasm32_emcc.v:786` and the D3 example at
`xap.md:3094` both stay as they are — under the spec sentence as written,
`components:`/`surfaces:` on `serve` are legal, and "correcting" them ahead of
the ruling would be truing the docs to the implementation's shortfall.

### The findings the letters rest on, recorded so they are not re-derived

- `xap_serve` reads exactly `runtime`, `tenant`, `shell`, `auth`, `block`.
- `shell`, `auth` and `block` appear in NO option table in the spec. `block` is
  load-bearing: omit it and the call parks forever; misspell it and it parks
  forever silently.
- `components`/`surfaces`/`handlers` are `[$xap:run]`'s in-process registration
  keys; `vcx/tests/xap_umbrella_test.v`'s hosted-spelling roster describes all
  three as "in-process registration; a hosted XAP composes features instead".
- Every call site in the tree already uses the run-then-serve shape and passes
  only keys inside the five: `bench/xap/render_cost.cx` (`runtime`, `block`),
  the `cx xap init` scaffold at `vcx/cmd/xap_init_templates.v:600` (`runtime`,
  `tenant`, `shell`), and all of `vcx/tests/xap_render_test.v` /
  `xap_umbrella_test.v` / `xap_serve_cap_test.v`. Nothing in the tree exercises
  the nine.
- The construction, when a set is finally settled, is `codec_build_opts`
  (`vcx/code/stdlib_codec.v:321`): refuse an unknown key naming what the verb
  accepts, on its stated ground that "a silently-ignored option is a promise the
  caller believes and the codec did not keep".
