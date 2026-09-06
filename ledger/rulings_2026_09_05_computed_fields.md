# Rulings 2026-09-05 — computed field values, and how a slug is declared (DF-1, DF-2)

**Status: DF-1 and DF-2 RULED by the owner, 2026-09-05** (owner answers `1c`,
`2a`). The owner asked whether a derived/computed field ability is needed at
all, given that it adds CODE to a grammar, and asked for the drawbacks each
way. Recorded BEFORE any spec text (ledger discipline; register R4.2).

**Kept separate on the owner's instruction.** The `[check]` sandbox question
that surfaced during this analysis is NOT ruled here — it has its own record,
`rulings_2026_09_05_grammar_expression_env.md` (GE-0..GE-3).

## What was measured, on the landed tree (2026-09-05)

Both probes ran against `release/0.18` + the `known-by` rename. Neither is
reasoning from source.

1. **A slug is already declarable and enforced.**
   `[type url-slug::text [pattern '^[a-z0-9]+(-[a-z0-9]+)*$']]` with
   `identity=slug` accepts `my-first-post` and refuses `"My First Post"` with
   `cx-err:CXER4867` naming the field. Nothing computes the slug from a title.
2. **A `[check]` can compare two fields and refuse disagreement**
   (`[= $intent/slug $intent/title]`), but **cannot call a stdlib module** —
   that is GE's subject, and it is what decides DF-1.

## DF-1 — may the grammar compute a field's value? — RULED (c): NO

The question is not whether it would be convenient. It is what a feature
document IS: a DECLARATION — diffable, content-addressable, servable,
analyzable as data. #1308 already placed two executable slots in it (`[check]`,
a predicate; `[fold]`, a comprehension), each justified on its own. A third
makes "the feature file is a program" the honest description, and the
properties that made the grammar worth having degrade one slot at a time.

- (a) `[compute EXPR]` on a field, with the expression environment opened so
  textual derivations work. **Rejected on ORDER, not merit**: what a declared
  law may reach is its own decision (GE), and it should not be settled as a
  side effect of adding a convenience.
- (b) `[compute EXPR]` limited to built-in operators. **Rejected on
  measurement**: every TEXTUAL derivation — the slug that raised the question,
  a name, a key, a code — is inexpressible, leaving arithmetic. The feature
  would miss its own motivating case while costing a third executable slot,
  the LAST free code in the runtime band (`4850–4869`), a new W row, dependency
  ordering and cycle detection between computed fields, and an evaluation slot
  ahead of type-checking. A surface that misses its motivating case is not a
  small surface; it is a permanent one that must be explained forever.
- (c) **No computed fields. The caller supplies the value; the grammar checks
  it. TAKEN.** *Deletes:* nothing — nothing was built. An adopter gives up
  having the value produced for them, and keeps the ability to declare what it
  must satisfy (§4.6) and, where expressible, that it agrees with the record's
  other fields (§4.9a). The project keeps a grammar that is still data.

**The examples were re-examined before ruling**, because "the examples are
obvious" was the original case for building it, and most of them argued the
other way:

- *slug from title* — inexpressible; and a slug that silently recomputes when a
  title is edited breaks every URL that pointed at the old one. The real
  requirement is compute-once-then-freeze, which is a creation-time default,
  not a standing derivation. See DF-2.
- *full name from first + last* — inexpressible; and `first + " " + last` is
  wrong for a large share of the world's names. In a contract that is a
  permanent wrong answer rather than one client's bug.
- *line total from quantity × price* — expressible, and real, but small: the
  price charged must be stored regardless, so the derivation is a write-time
  convenience over data already kept — and money that silently recomputes is a
  defect.
- *normalized search key* — an index concern; it belongs to the store.

**What would reopen this:** GE-1 admitting stdlib calls removes (b)'s
objection, leaving only the third-executable-slot argument. That is a judgement
to make with the GE decision in hand, not before it. This record marks the
door rather than leaving it unmarked.

## DF-2 — how a slug is declared — RULED (a): a pattern, not a surface

A URL-safe handle is a real requirement and needs no new grammar. Every piece
of the ruled pattern ships today:

```
[types [type url-slug::text [pattern '^[a-z0-9]+(-[a-z0-9]+)*$']]]

[keys [key name=post-id via=slug]]

[noun name=post identity=slug known-by=title
  [field name=slug  type=url-slug]
  [field name=title type=text]]
```

- **The shape is enforced** — a non-slug value refuses `CXER4867` at the one
  pre-commit point (§4.9), on the component path as well as under a host.
- **`identity=slug`** is what a link addresses and what the fold merges on; it
  defaults from the key registration.
- **`known-by=title`** is what a person reads — the §4.8 division: the system
  addresses by `identity`, a person recognizes by `known-by`.
- **Who computes it: the CALLER, or the feature's own module under
  `[$xap:host]`** — never the grammar. Beyond DF-1, there is a second reason: a
  slug used as an identity must be STABLE, so it is computed once at creation
  and then left alone. A standing derivation would recompute it on every later
  edit, which is precisely the behavior not wanted.
- **Agreement, where expressible, is a `[check]`** (§4.9a).

Rejected:

- (b) **A `slug=` attribute on the noun.** Rejected twice over: it
  special-cases one instance of a general shape (a pattern-typed identity
  field), which is the surface bloat orthogonality refuses; and it SPENDS the
  word, so an adopter who later wants a field genuinely named `slug` finds the
  name taken by an unrelated meaning. That is the `label` mistake this campaign
  has already paid for once (#1307, and the `known-by` rename).
- (c) **A built-in `slugify` in the grammar.** Rejected: behavior travelling as
  grammar. If slugification should be shared it is a stdlib function a module
  calls — which is GE's subject, not this one.

## Consequence for the docs

The slug pattern above is the answer adopters will look for. It is written into
the composition spec §4.8 as a worked example so that nobody reinvents `slug=`.
