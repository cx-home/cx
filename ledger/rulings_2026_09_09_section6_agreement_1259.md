# #1259 — `1259-h`: two readers of §6, pinned by a gate

Ruling record for `1259-h`, the letter that closed `1259-e3`. It is the third
and last 1259 record; the other two are
[`rulings_2026_09_08_emits_of_1259.md`](rulings_2026_09_08_emits_of_1259.md),
[`rulings_2026_09_09_composed_emits_of_1259.md`](rulings_2026_09_09_composed_emits_of_1259.md)
and [`rulings_2026_09_09_lenient_emits_of_1259.md`](rulings_2026_09_09_lenient_emits_of_1259.md).

## Provenance

| letter | ruled by | on #1259 at |
|---|---|---|
| `1259-h` | Fable, under the owner's 2026-09-09 delegation | 2026-09-09 05:56 ET (comment 09:56:04Z) |

Nothing here was self-ruled. The worker's own draft on #1259 recommended
1(b) — a shared reader in a new frozen-std sub-package — and `1259-h` refused
it in favour of 1(c). This record implements 1(c).

## What `1259-h` decided, and what it deleted

`1259-e3` would have given §6 ONE reader by importing `cx-xap` into
`x/ux.cx`. That import fails at load time: `cx-xap` is registered as its own
package outside both the frozen-std and the x tier
(`vcx/platform/stdlib_bundle.v`), and
`test_x_tier_is_bundled_separately_from_frozen_std`
(`vcx/tests/stdlib_umbrella_test.v`) seeds std + x only and loads every x
module. Zero of the twelve bundled x modules import `cx-xap`.

`1259-h` therefore **DELETES `e3`'s "one walk" goal** and replaces it with
*two walks proven equal by the gate*. `impl/cx-A-1259e3g`'s `x/ux.cx` change
is not merged and the branch is abandoned; its `g` half landed separately at
`0c7a5e625`.

**The ceiling the letter sets:** two readers are pinnable by a fixture; three
are not. A THIRD reader of §6 reopens option (b) — one shared reader, at the
cost of a new frozen-std sub-package and the `spec/03-approved/std-lib/*.md`
the catalog gate then requires — as its own letter. Do not add one silently.

## What was there before

`[$xap:emits-of]` was already correct: after `1259-g1` it reads `[verbs]` and
`[nouns]` leniently, treats an absent `effect=` as `act`, walks every
`[intent]` and every `[do]`, dedupes slot names in first-seen order, and falls
back to the written noun's fields — resolving a qualified `[writes 'ns/noun']`
through `all_after_last('/')`.

`x/ux.cx` disagreed with it on three shapes. Measured on the shipped binary at
`12abdac33`, one act verb per document:

| document | `[$xap:emits-of]` | `ux:form` |
|---|---|---|
| minimal | `customer lines` | `customer lines` |
| no `effect=` | `customer lines` | `customer lines` |
| `[requirements]` | `customer` | `customer` |
| two `[intent]` blocks | `customer lines` | `customer` |
| a repeated parameter name | `customer lines` | `customer customer lines` |
| `[writes 'shop/order']` | `customer lines` | *(nothing)* |

Three causes, all in `x/ux.cx`:

1. `intent-params` read `[$first $intents]` and that intent's first `[do]`.
2. It yielded one name per occurrence, so a repeated name grew a second
   control for one slot — the #1268 over-offer class in its feature-document
   spelling.
3. `feature-form-of` compared the `[writes …]` name to `[noun name=…]`
   verbatim, so the qualified spelling matched no noun, the parameter fallback
   had nothing to fall back to, and the form projected with no fields at all.

## Implementation readings — decisions the letter left open

These are **not** new rulings.

1. **The dedup lives in `intent-params`; the bare-naming lives in
   `feature-form-of`.** The letter says "`intent-params` implements §6" and
   names the noun fallback as part of §6, but that fallback is the caller's —
   only `feature-form-of` holds the `[nouns]`. Splitting on where the data is
   keeps both defs' existing contracts (`intent-params` answers absence and
   the caller decides what absence means), which the `[params]` arm and its
   public `[fn-doc]` both depend on. The agreement gate pins the composed
   whole either way.

2. **The composed `[params 'a b']` arm is UNCHANGED, on a measurement.**
   `xap_gc_verb_params` splits on whitespace and does not dedup either, so the
   two readers already agree on a repeated name in the composed spelling.
   Adding a dedup there would have been an unmeasured behavior change on the
   arm `ux-083` pins.

3. **`uniq-names` walks the prefix by index rather than using `has-str`.**
   Order is the contract — `emits-of` emits slots in declaration order and a
   form's controls read top to bottom — so the dedup must keep the FIRST
   occurrence. `has-str` cannot express "seen before this position".

4. **The gate reads the ux side off the projected FORM, not off
   `[$ux:intent-params]`.** The parameter list §6 describes includes the noun
   fallback, and that lives in the caller; reading the def alone would pin
   half the rule and leave the half #1268 tripped over unpinned.

## What is pinned, and where

`conformance/stdlib/ux.cxd`, both `level=core gate=enforced`:

- **`ux-124`** — the three shapes `1259-h` names (minimal, no `effect=`,
  `[requirements]`). Green before this landing as well; it is the regression
  guard, because neither reader's own suite compares it to the other.
- **`ux-125`** — the three shapes that disagreed. RED at `12abdac33` on all
  three, green after.

Both emit, per document, `agree=` alongside BOTH ordered lists, so a
regression names the shape and shows what each reader answered rather than
only that a string moved.

## Out of scope, measured, and left open on #1259

A verb declaring `effect=arrange` is outside the derived act vocabulary —
`[$xap:emits-of]` skips it (`eff != '' && eff != 'act'`) — and `ux:form`
still projects a submit form for it, because `grammar-form` refuses only
`observe`. That is a MEMBERSHIP disagreement, not a parameter-name one.
`1259-h` rules on ordered parameter names; nothing rules on membership, and
changing either reader would change what a surface offers. Reported on #1259
rather than fixed or dropped.
