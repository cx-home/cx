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

## 1259-i — the readers agree on MEMBERSHIP, not only on names

**RULED: 1259-i — (a)** (Fable, 2026-09-09 09:17 ET, under the owner's
delegation). Membership is **"not `observe`"**: `[$xap:emits-of]` offers every
verb that is not `observe` — `act`, `arrange`, and the undeclared effect the
1259-g1 clause reads as `act` — in both arms, with the same parameter walk, the
same fallback and the same `offered=false` skip.

**Verified before the change, as the ruling instructs:** nothing pinned the
exclusion. `grep -rn 'emits-of' conformance/ x/ spec/ docs-src/ | grep -i arrange`
returns nothing — no fixture asserted an arrange verb's ABSENCE from an
`emits-of` answer.

**Red-proved at `f34b55b3d`** over a feature carrying one `act`, one `arrange`
and one `observe` verb, and its composed grammar:

```
[probe [feature-arm [do :place [title :text] [lane :text]]]
       [grammar-arm [do 'board/place' [title :text] [lane :text]]]]
```

The arrange slot is absent from BOTH arms. After: both answer `place` and
`highlight`, and `peek` stays out. Pinned as `xap-compose-161`.

**One thing the ruling did not name, found by reading both arms.** They did not
apply the same test. The feature arm read `eff != '' && eff != 'act'`, which
honors 1259-g1's undeclared-effect default; the **grammar arm demanded
`effect == 'act'` exactly**, so it dropped an undeclared effect as well as an
arrange one — it never honored 1259-g1 at all. The single `eff == 'observe'`
test fixes both, which is what "the same fallback" in the ruling requires.

## The `ux-124` row the ruling asks for CANNOT be authored yet, and why

`1259-i` asks for "one row in `ux-124`'s agreement set for the arrange document
(`agree=true`)". Three measurements say that row would be either vacuous or
red for an unrelated reason, so it is **not** in this landing and the concern is
on the issue rather than resolved by picking whichever document looks green.

1. **The canonical arrange verb has no parameters.** All 30 `effect=arrange`
   verbs in `xap-compose.cxd` are
   `[verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]`.
   A slot-comparison row over that document answers `[emits] [ux]` — both empty
   — and therefore `agree='true'` **before AND after** the fix. Measured both
   ways. That is an absence-based row: it passes for the wrong reason.
2. **A parameterised arrange verb with `[writes]` has no precedent**, and the
   §6 signature floor says writing domain state ⇒ `act`, so declaring `arrange`
   over a write is a weakening a W5-class conflict exists to catch. Not a
   document to put in a gate.
3. **`ux:form` cannot project ANY verb with no `[writes]` noun** — including
   every corpus arrange verb. `x/ux.cx:2132` is
   `[= $wname [$bare-name [$string [$first $v/writes]]]]`, and `$first` over an
   empty selection answers `nth: index 0 out of range (1..0)`, which lands as
   an `[err]` INSIDE the projected form. Measured on three documents: `act` +
   `[writes]` projects cleanly; `arrange` + `[writes]` projects cleanly;
   **`act` + `[reads]` and `arrange` + `[reads]` both error**. So the defect is
   "no written noun", NOT arrange — it is older than this ruling and independent
   of it.

Point 3 also contradicts `1259-i`'s stated premise that "`ux:form` keeps
projecting a submit form for them". It refuses only `observe`, which is what the
ruling checked — but on the canonical arrange verb it does not refuse, it
CRASHES. The two readers therefore still do not agree on that document, and no
change to `emits-of` can make them.

The `emits-of` half is correct, self-contained and lands here. The remainder is
drafted back on #1259 as letters rather than decided.
