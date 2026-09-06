# Rulings — the view grammar: sorting, filtering, faceting, paging, show/hide, autotype

2026-09-04, release/0.18. Recorded BEFORE the work, per the ledger
discipline. Raised by the owner as a design question ("cross-cutting grammar
that should be available to all nouns … not sure if they are standard XAP
verbs or another part of speech"); #1282 (ux-web side nav has no narrow
tier) is the presentation-side instance that surfaced it from downstream.

## VG-0 — the reading (recorded, not a letter)

A grammar is `G = (V, N, R, Φ, K)` (xap_grammar_composition.md §1). Verbs
carry an effect signature and a journal entry. Sorting, filtering, faceting
and paging have NO effect and commit nothing; ux.md P0-62 already says so —
ordering, like filtering and faceting, is a QUERY, cannot ride `[ux:form]`,
and its state is the URL (P0-78). The planar comprehension is exactly that
algebra: `[in $x noun]` + `[where]` + `[order-by]` + `[group-by]` +
`[yield]` (projection = which fields show), and the same quoted
comprehension is a live feed. Autotype is typed-on-read plus the `format`
hint. Show/hide is two things that must not share a word: capability-driven
visibility is authorization (P0-47 default-omit, `show=disabled`);
presentational choice is a hint (`view`, `order`) or, for a viewer's own
choice, URL state.

**So the parts of speech are three, and the third already exists:**

1. **verb** — effect, journaled, on the intent wire;
2. **noun** — the read model, derived nouns with `[from …]`;
3. **clause** — the query modifier; applies to every noun by construction,
   safe and idempotent, state in the URL, never journaled.

Minting these as XAP verbs is rejected on every axis: it would give effect
signatures, governance and journal entries to operations that change
nothing, and it contradicts P0-62.

## VG-1 — where the noun declares what the clauses may do (RULED: VG-1 = a)

- (a) **In the grammar, on the noun's fields**, beside `[frames]`/`[keys]`
  — a `[views]` component per noun: which fields are sortable, which are
  facetable, the default order, which fields are hidden by default. It
  constrains every query over the noun, the W-gates check it at compose
  time, and P0-60 ("a pager over an undeclared order is a refusal") becomes
  a compose-time fact instead of a render-time one. **Taken.** Deletes
  nothing: a noun with no `[views]` keeps today's behavior.
- (b) In the hint cascade only. Rejected: hints are presentational and per
  surface; two surfaces could disagree about whether a field is filterable,
  and the cost model (an index) has nowhere to attach.
- (c) New standard XAP verbs (`sort`, `filter`, …). Rejected per VG-0.

## VG-2 — durable per-viewer view preferences (RULED: VG-2 = a)

- (a) **P0-100 as written**: state lives in the journal stream of its
  owning aggregate — `prefs:<principal>` for a viewer's own preferences,
  `view:<entity>` for a shared saved view. `save-view` is an ordinary verb
  with an effect; a saved view is a derived noun; ephemeral choices stay in
  the URL. **Taken.** Mints no mechanism.
- (b) A session-document field. Rejected: loses the audit loop, dies with
  the session, contradicts §11 ("state follows authority, in a stream").
- (c) Client-side storage. Rejected already by P0-82 (state the server
  cannot see).

## Consequences for #1282

The side nav's missing narrow tier is geometry that decides what can be
viewed and how — neither a verb nor a noun — and the issue's own rule is the
right one: layout lives in the render context and the renderer, never in the
page and never in a feature verb. Its ask (2), a `narrow=` value on the
`place-var` like DS-7's span, is a hint axis on the author plane
(arrangement + hints, journaled per P0-115), not the viewer plane. Recorded
as the recommendation for that issue's own ruling: take both asks (renderer
collapses side→top at the 880px tier by default; the render context may
override it), and the rail width reads the theme's `aside-width` token.

## Execution order and the downstream note

Ruling (this file) → issues filed (#1285 grammar `[views]` component; #1286 saved views
over P0-100 streams) → spec edits under these ids (xap_grammar_composition.md
§1/§4, ux.md §10.6 cross-reference, xap.md feature schema) → fixtures →
implementation → CHANGELOG entry carrying the adopter note. The change is
ADDITIVE for adopters: a feature that pages or sorts a noun declares
`[views]` on it; a feature that implemented sort/filter as intents migrates
them to queries (cutover-first, no dual-accept). Downstream is told through
the issue and the CHANGELOG entry, never through their own repositories.
