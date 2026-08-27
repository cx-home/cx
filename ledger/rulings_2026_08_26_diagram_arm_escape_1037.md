# Rulings — the if-arm / match-arm `cd-esc` asymmetry (#1037), 2026-08-26

Authorizing issue: **#1037** ("cd-esc asymmetry between the if-arm and
match-arm emitters — one is wrong for any value carrying a
double-quote"). Branch `wave9/1036-1037-1001-diagram`, off
`release/0.17` @ `4a83b2361`.

Recorded in advance of the #1031 ledger's NT-9a, which named the
asymmetry as a known open question and carried it faithfully rather than
closing it inside another issue's authorization.

---

## AE-1 — the two sides, measured

`stdlib/diagram.cx` §9.5, same body under the two emitters, at
`compact`:

```
[?if [= 1 1] [then "he said \"hi\""] [else "she said \"bye\""]]
  →   t["'he said "hi"'"]                     ← if arm,    UNESCAPED
[?match 1 [case 1 "he said \"hi\""] [else …]]
  →   a1["'he said \"hi\"'"]                  ← match arm, ESCAPED
```

The if arm's label closes its own `["` on the value's first `"`. That is
not a cosmetic difference: it is a diagram the reader does not get,
because mermaid cannot parse the line. The two sides had drifted because
`cd-if-arm-emit` never ran its label through `cd-esc` and
`cd-match-emit` (and `cd-def-block`) always have, since the wave-3 port.

## AE-2 — which side the spec supports

`spec/03-approved/std-lib/diagram.md` §4, "The Mermaid form — normative
byte rules":

> **Escape set** (labels and edge labels): `\` → `\\`, `"` → `\"`,
> newline → `\n`, applied in that order.

Unconditional, scoped to LABELS AND EDGE LABELS, with no exemption for
an emitter or a node kind. §10's playground renderer adds shapes and a
rule table on top of that form; it does not restate or relax the escape
set, and `esc` in the module is written as the §4 set with §4 named in
its comment.

So the MATCH side is the spec's side and the IF side is the defect.
There is no reading on which an unescaped label is the intended
behaviour: `esc` exists precisely to make a value safe in a label
position, and a label the renderer refuses is the one outcome the byte
rules exist to prevent.

## AE-3 — the fix removes the switch rather than flipping it

`cd-nl-one`'s `$esc` parameter — added at #1031 to carry the asymmetry
faithfully rather than silently tidy it — is DELETED, and the plain
spelling is escaped unconditionally. Flipping the if-arm call site from
`false` to `true` would fix today's defect and leave the mechanism that
produced it in place; with the parameter gone the two arms cannot drift
apart again without someone reintroducing it on purpose.

The §9.4b TABLE branch is untouched. It escapes for HTML (`&quot;` and
the rest, `#` last), which is the correct escape for its own form, and
it never took the `$esc` path.

## AE-4 — golden movement: NONE, and that is the finding

Measured over the whole committed corpus (282 goldens) with the fix in
place and nothing regenerated: **UNCHANGED 282, MOVED 0.**

Not one source in the corpus put a `"` inside an arm value. That is why
the asymmetry survived the port, the wave-3 capture, and two release
cuts: the instrument that exists to catch exactly this could not see it,
because the shape was absent. A gate with no case for a shape does not
test that shape — it just doesn't fail.

## AE-5 — the pins that close it

Two sources are added to the synthetic pin corpus
(`vcx/tools/regen_code_diagram_golden`), the SAME body under the two
emitters so a reader sees that only the directive differs:

| pin | source |
|---|---|
| `pin-cfg-if-arm-quote` | `[?if [= 1 1] [then "he said \"hi\""] [else "she said \"bye\""]]` |
| `pin-cfg-match-arm-quote` | `[?match 1 [case 1 "he said \"hi\""] [else "she said \"bye\""]]` |

Six new goldens (2 sources × 3 rungs). Adding an instrument is not
golden movement — no committed byte changes — but the regeneration pass
that writes them touches the DR-8 corpus, so it is recorded here before
it runs, and its result is asserted: the six new files, and no others.

BOTH arms are pinned, not just the broken one. The match side is
currently right, and a pin that only covered the if arm would let a
future "unify by removing the escape" go green on half the evidence.

## AE-6 — red-proof

With `cd-nl-one` reverted to the `$esc` switch and `cd-if-arm-emit`
passing `false`, the DR-8 byte gate reports exactly two failures:
`pin-cfg-if-arm-quote.compact` and `pin-cfg-if-arm-quote.full`
(`t["'he said "hi"'"]` measured against the escaped golden).
`pin-cfg-match-arm-quote` stays green at every rung, and both `min`
goldens stay green because `cd-cfg-min` emits one box per top-level def
plus `main` and never reaches an arm label. That failure SET is the
asymmetry itself, reproduced by the pins that now forbid it.
