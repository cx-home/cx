# RULED: 1259-a, 1259-b, 1259-c — the derived client vocabulary

Date: 2026-09-08. Issue: #1259 (with #1220 item 1). Ruled by Fable on the
issue, 2026-09-08 13:50 ET, on three letter sets drafted by worker A at
17:18Z. Recorded here with the implementation, and the one place the
implementation is NARROWER than the ruled sentence is stated below rather than
quietly absorbed.

## Why there was a question

`[$xap:component]`'s `emits:` restates a vocabulary the feature document
already declares. The reference estate carries **nine** hand-restatements of
one grammar (`reference/shop-web-client/serve.cx:71`, `:87`, `:100`,
`reference/shop/cascade.cx:37`, `:43`, `:48`, `design/787/w5/shop/serve.cx:184`,
`:190`, `:195`), and one of them is **wrong**: `orders.feature.cxd:22` declares
`[field name=promised-at type=instant]` and `serve.cx:71` writes
`[promised-at :string]`. Nothing notices, because the slot type is inert at
HEAD (`xap_emit_slots`, `stdlib_xap.v:3182`, collects only the element name).

Nothing in `conformance/` graded the `emits:` shape at all, so this was a
design choice and not a fixture fight.

## 1259-a = Q1(b) — one pure verb, not a `from:` option

`[$xap:emits-of FEATURE]` returns the materialized Sequence of
`[do :verb [field :type]…]` atoms an author would otherwise hand-write.
`emits:` stays the only option on `component`; there is **no `from:` key and no
sugar**.

A value composes — filter it, probe it, diff it against a hand-written block,
hand it to `cx xap init --client` — where an option cannot. And a second key
policed by a refusal rule is the two-spellings fork `1358-f1` refused and the
second option surface `1221-b-1a` deleted from `serve`.

The derivation runs over `xap_gc_parse_feature` (`stdlib_xap.v:3885`), which
already yields the three inputs: act verbs, the declared intent parameters
(§6.1 N-COMPOSE-7) and the written noun's typed fields. **No fourth walk.**

## 1259-b = Q2(a) — the derived atoms carry the field TYPES

Taken from the written noun's `[field … type=]` declarations, which is already
the surface plane's documented source for a field's type. It makes the derived
block byte-comparable to a careful author's, and it replaces the live wrongness
above rather than adding a hook.

The fallback is the one `xap_gc_verb_params`' own docstring documents and
nothing consumed until now: a bare `[intent [do :v]]` means "ask the noun", so
the slots become the written noun's fields **in declaration order**.

## 1259-c = Q3(a) — `component`'s option set is CLOSED

`{bind, view, working-panel, emits, affinity, reduce}` and nothing else; any
other key refuses `CXER4852` **naming the key** (the `serve` guard's shape from
1221-b-1a). Before this, `emit:` or `emits-of:` produced a component with no
vocabulary, in silence.

Three `xap.md` sentences that were false at HEAD are settled in the same
commits:

| sentence | settled as |
|---|---|
| `:733`, `:895` — `props` is an arm of `component` | **STRUCK.** No code has ever read it there; `[$xap:panel]`'s positional second argument has always been its only reader. |
| `:895` — CXER4852 for a component with a missing arm | **IMPLEMENTED**, in the corpus-compatible form (below). |
| `:1652` — a second, bracketed spelling `[emits [[do …]]]` | **STRUCK**, cutover-first. One read site existed and it was map-key only; nothing ever accepted the spelling, so nothing can break. |

### Where the implementation is NARROWER than the ruled sentence, and why

The ruled sentence is "a component with neither `view` nor `emits` refuses
CXER4852 by name". Implemented literally, that reddens **four gate-enforced
fixtures**: `xap-compose-rl43-orders`, `rl45-orders`, `rl48-x` and `rl49-x`
(`conformance/stdlib/xap-compose.cxd:1088`, `:1112`, `:1192`, `:1226`) each
register a `{bind:, affinity:}` component **on purpose** — an affinity-only
component exists to be resolved and summoned (§3.2's ramp), and the resolve
machinery never renders it.

A gate-enforced fixture is a prior ruling and outranks a sentence written
before it. So the refusal ships as the intent's largest corpus-compatible
form: **a component that declares no arm at all** — no `view`, no
`working-panel`, no `emits`, no `affinity`, no `reduce` — is refused by name.
`bind:` alone can neither render, speak, nor be resolved.

Nothing of the ruled intent is lost: the typo case the sentence was aimed at
(`emits-of:`, `emit:`) is caught **upstream and more precisely** by the closed
option set, which refuses the key by name instead of inferring a missing arm
from its absence. Reported on #1354 rather than absorbed.

## #1220 item 1 — landed first, in the same change

`xap_seq_items` (`stdlib_xap.v:1967`) had no `iterator_node` arm and no
empty-name-wrapper arm, so a `[?for]` comprehension — the natural way to build
`emits:`, and a shape `[$xap:emits-of]` makes more likely — flattened to
NOTHING and the component registered with no vocabulary, silently. Both arms
added, materializing through `iterate`, which is exactly what
`xap_list_item_nodes` (`stdlib_xap_serve_notd_wasm32_emcc.v:1377`) already does
one layer up. The ruling required this to land first or in the same batch: a
derived Sequence must not be the thing that registers zero verbs.

## Fixtures

In `conformance/stdlib/xap-compose.cxd`, ids 138+: the derived block for a
feature declaring `promised-at type=instant` (types included), the bare-intent
fallback to the noun's fields, an unknown `component` key refused by name, a
no-arm component refused **with an affinity-only component registering in the
same case**, and the #1220 comprehension case.

Lanes: `test-vcx-suite` (the corpus grader and the xap umbrella),
`test-vcx-code`, `spec-freeze-gate`, `guide-check` (a new public def needs its
`[fn-doc]`), and `docs-check` with `make docs` committed.
