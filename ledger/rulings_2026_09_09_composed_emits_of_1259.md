# #1259 — the composed arm of `[$xap:emits-of]`

**RULED: 1259-e1, 1259-e2, 1259-e3, 1259-f1, 1259-f2, 1259-f3** (owner + Fable,
2026-09-08 20:10–20:45 ET, on #1259). This record is the implementation's
account of them: what landed, what was measured, and the one fork the rulings
did not reach.

## What the rulings decided

- **1259-e1** — the composed arm's `items[0]` is the **qualified name as a
  STRING**: `[do "owner/register" [id :text] [name :text]]`. It is the
  canonical act form's own head spelling (RULED #1260 CA row A2), so a client's
  derived `emits:` atom and the act it emits agree with no re-qualification.
  Refused: a bare atom head (drops the qualifier and totality) and refusing
  ambiguous compositions (trades documented totality for tidiness).
- **1259-e2** — the FEATURE arm keeps `[do :verb …]` with a bare ATOM head,
  byte-identical. `xap-compose-138`/`-139`/`-142` are untouched.
- **1259-d1 / 1259-d3** — `emits-of` accepts a composed `[grammar …]`, and
  `xap_gc_verb_params` gains its first consumer.

## What was measured, not assumed

**A qualified ATOM is not spellable.** `is_atom_name_bytes`
(`vcx/cx/parser.v:3858`) and `is_valid_atom_name` (`vcx/code/eval.v:8772`) both
refuse `/`, and `cx_scalar` (`vcx/cx/emitter_cx.v:1869-1876`) writes
`':${name}'` **unchecked** — so `:owner/register` would emit bytes the parser
will not read back as that atom. A silent round-trip break, not a refusal.
That is why 1259-e1 (b) is not merely worse but unavailable.

**Everything the composed arm needs already rides the composed document.**
Measured at `aa160b22c` by composing two features that both declare a verb
named `register`:

```
[verbs [verb name='device/register' … [writes 'device/device'] [params 'id serial']]
       [verb name='owner/register'  … [writes 'owner/owner']  [params 'id name']]]
[nouns [noun name='device/device' [field name=id type=text] …]]
[bare-terms [term name=register candidates='device/register owner/register']]
```

Nothing is re-read from the feature sources — which is the point of §4.8's
self-contained grammar, and it is what makes `xap-compose-150` a fair test of
the qualifier: the bare word is ambiguous there by construction.

**A withdrawn verb is omitted.** §4.3a (RULED: AD-1) keeps a withdrawn verb in
`[verbs]` with `offered=false` so provenance stays recomputable, and omits it
from `[bare-terms]`, "whose stated job is what can be said here". A derived
client vocabulary is the same kind of statement: an `emits:` entry for a
withdrawn verb names an act ρ refuses with CXER4864 *before* the PEP
(`xap-compose-065`), so it would put a control on the panel whose first click
is a refusal the scaffold itself set up. Pinned by `xap-compose-152`, whose
second row proves the verb is still present in the grammar it was derived from
— an omission by the deriver, not a hole in the composition.

## The fork the rulings did not reach — `1259-g`, drafted on #1259

**1259-e3 as written reds five `level=core` ux fixtures, and the cause is not
the one its acceptance gate names.** The gate said: if a byte moves in
`ux-083`/`ux-122`, that measures that `noun-fields` and per-name `param-field`
differ, and 3(b) is then the ruled shape.

Measured, by running `x/ux.cx`'s own source as a program against both the
baseline and the edited module (no build, no slot):

1. On a **well-formed** feature whose verb declares no parameter list — the
   exact noun-fallback comparison the gate asked about — the projected form is
   **byte-identical**. The premise behind 3(b) is measured **false**.
2. `ux-083` and `ux-122`'s feature half is byte-identical too:
   `[probe [from-feature 'id' 'name']]`.
3. The reds come from somewhere else entirely: `emits-of` reads its subject
   with `xap_gc_parse_feature`, the **composition gate's** parser, while
   `ux:form` accepts documents composition refuses. `ux-036`, `-037`, `-038`,
   `-039` and `-043` all carry
   `[verb name=place-order [summary …] [intent …] [writes order]]` — no
   `effect=`, no `[requirements]` — and `ux:form` projects them today because
   `grammar-form` defaults the effect (`[?else $v@effect "act"]`,
   `x/ux.cx:2035`). Through `emits-of` they become
   `CXER4852 … effect="" outside {observe, act, arrange}`, and with `effect=`
   supplied, `… missing [requirements]`.

So routing `intent-params` through `emits-of` imports composition's **admission
rules** into the projection. That is a design fork — `xap_cohesion_builtin`
already refuses that import for the instrument family in its own words
("LENIENT extraction, deliberately not `xap_gc_parse_feature` … richer grammars
are compose's strictness problem, not the ruler's") — and it is not mine to
settle. Letters are on #1259; nothing of `1259-e3` is landed, and the work is
parked unmerged on `impl/cx-A-1259e3` rather than filed away as a new issue.
