# #1259 — `[$xap:emits-of]` reads its subject leniently, and the undeclared effect is `act`

**RULED: 1259-g1, 1259-g2, 1259-g3** (owner + Fable, 2026-09-09 02:55–03:05 ET,
on #1259), answering worker A's 00:19Z letters 1(a) / 2(a) / 3(a). This record
is the implementation's account of them.

## What the rulings decided

- **1259-g1** — `emits-of` reads `[verbs]`/`[nouns]` **directly** and never
  through `xap_gc_parse_feature`; a verb with no `effect=` reads as
  `effect=act`. Strictness stays at `compose`, the gate whose job it is; the
  READERS are total, which both instrument docstrings already claim. The `act`
  default is written into `spec/03-approved/xap/xap_grammar_composition.md` §6
  as one normative sentence, because until now it lived **only** in
  `x/ux.cx:2034` (`[?else $v@effect "act"]`) — a default no spec stated is a
  default three readers can drift apart on.
  Refused: (b) strict + correcting five `level=core` ux inputs (truing
  fixtures to a shortfall); (c) strict + a fallback walk (the dual-accept
  `1259-e3` exists to end); (d) withdrawing `e3` (abandons a ruled item).
- **1259-g2** — the **kind check is this verb's one refusal**: a subject that
  is neither a `[feature …]` nor a `[grammar …]` element. Every other subject
  answers a value, possibly the empty sequence. `CXER4852` leaves this verb's
  malformed-document path.
  Refused: (b) a second structural refusal when `[verbs]`/`[nouns]` are both
  absent — indistinguishable from an honest empty feature.
- **1259-g3** — the leniency gets its **own** fixture, plus a `ux:form` parity
  row. Refused: (b) no fixture — the five ux cases red for a dozen reasons and
  would never name this property.

## Cost, named by the ruling and accepted

A document `compose` would refuse still yields a derived vocabulary, so an
author can hand `[$xap:component]` an `emits:` block for a feature that will
not compose. The defect surfaces at `compose`. That is the cost
`xap_cohesion_builtin` already accepted knowingly for the other member of this
instrument family (`stdlib_xap.v`, "richer grammars … are compose's strictness
problem, not the ruler's").

## What was measured, not assumed

**The red, at this branch's own parent `5496dd6c0`** — the binary carrying the
STRICT `emits-of` — over the minimal document that is the shape `ux-036`,
`ux-037`, `ux-038`, `ux-039` and `ux-043` all carry (no `effect=`, no
`[requirements]`):

```
[probe [v [err code=cx-err:CXER4852 message='E_XAP: emits-of could not read the
 feature: feature "shop": verb "place-order" effect="" outside
 {observe, act, arrange}']]]
```

**The same document, read by the OTHER reader, under the same binary** — it
projects a full form and always has, which is the disagreement in one line:

```
[probe [all '' 'customer' 'lines' ''] [named 'customer' 'lines']]
```

**The expected vocabulary bytes were recorded from a run**, not predicted: the
same document made strict-admissible (`effect=act scope=shared
consequence=reversible` + a `[requirements]` clause added, nothing else) yields

```
[probe [v [do :place-order [customer :text] [lines :line]]]]
```

under that same pre-fix binary. So `xap-compose-158`'s first row pins the
leniency and nothing else, and the lane re-checks that twin (`TWIN-EXIT`) to
prove the well-formed path did not move.

## An implementation note that is not incidental

The lenient reader fills its `ftypes`/`forder` maps from plain
`xap_gc_children` loops, **not** from `if x := xap_gc_child(…)` capture blocks,
even though `xap_cohesion_builtin` uses the capture form. A `mut` assigned
inside such a block can read back as its zero value later in the optimized
build — measured on `vcx/cx/program_fmt.v` while landing #1320, where adding a
print to observe the value *hid* the bug. A vocabulary that silently derives as
empty is exactly the failure that would survive a green suite.

## Fixture

`xap-compose-158-emits-of-reads-a-minimal-feature-document` (level=core), in
`conformance/stdlib/xap-compose.cxd`. Registry pre-flight for `1259-g3` was run
across **all** refs, not just `release/0.18`: the global max was
`xap-compose-157` on `impl/cx-C-1310`, so this starts at 158. The sweep was
python-driven — the shell form hits the zsh `:c` history-expansion trap that
makes such a check vacuous.
