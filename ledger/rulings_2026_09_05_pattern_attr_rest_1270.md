# Ruling record — #1270: the pattern attribute REST `[NAME @* $a]` is implemented, not deleted (2026-09-05)

Issue: #1270 (bug, area:cx-lang, prio:medium). Grammar: `core/grammar.ebnf` [126d].
Spec: `core/code.md` §5.1 (pattern grammar), §5.2 rule 5 (body-bind auto-unwrap).
Split out of #1172 (whole-element head-bind, RULED 1172-Q1a) so the rider was not lost.

## The state it is in

Grammar [126d] admits `'@*' '$' Name /* attr REST: bind unmatched attrs as a Map */`.
The program parser refuses it:

```
[?match [cat k=1 hello] [case [cat @* $a] $a] [else NOMATCH]]
→ CXER0100: parse: expected attribute name after @, got *
```

Same class as #1136 — the grammar admits, the engine refuses.

## 1270-Q1 — RULED (a): keep [126d] and implement it

- **(a) RULED.** `@* $a` binds the attributes the pattern's other `@` predicates
  do NOT name, as a **map**, in the candidate's own attribute order; `{}` when
  none remain. **DELETES:** nothing — the production is a parse error today, so no
  program can depend on either answer, and no shipped surface changes meaning.
  Why implement rather than trim: the pattern language covers CHILDREN
  exhaustively (`$x` body binds, `*`, `**`, the head-bind `[NAME$x]`) and a map
  pattern already has its own rest. Attributes were the one axis with no way to
  say "the ones I did not name", so trimming [126d] would leave the pattern
  language permanently weaker over attributes than over children — for no gain,
  since the grammar already states the intent.
- (b) delete the production from the grammar. Rejected: it spends nothing to keep
  and it is the only spelling of a capture the language otherwise cannot express.
- (c) admit it and bind a SEQUENCE of `[attr]` elements. Rejected: attributes are a
  map on the node (cxdm §2.4); handing back a sequence of two-field elements makes
  the caller re-key what the carrier already keys, and `[$map:get]` is then the
  natural next call anyway.

## 1270-Q2 — RULED: both riders, as the natural reading

- **(i) With NO other attribute predicates, `@* $a` binds ALL attributes.** There is
  nothing to subtract, so the rest IS the whole. `[cat @* $a]` against
  `[cat k=1 j=2 hello]` binds `$a = {k: 1, j: 2}`.
- **(ii) `@* $a` DOES count as an attribute predicate for §5.2 rule 5.** So
  `[cat @* $a $n]` binds `$n` to the matched ELEMENT, not to the unwrapped body.
  Rule 5's discriminator is "the pattern carries attribute predicates" — the
  reading being "the attributes are the filter, the binding is what I just
  selected". `@*` names every attribute, so it is the strongest form of that, and
  the alternative would make `[cat @* $a $n]` and `[cat @k $k $n]` disagree about
  `$n` for the same document, which is the surprise rule 5 exists to avoid. A
  caller who wants the unwrapped body writes `[cat @* $a]` and reads the body
  through the bound element, or omits the rest.

Attribute values keep their read typing (`k=1` binds the int `1`), so the rest map
is `{k: 1}`, not `{k: '1'}` — the same values the `@k $k` predicate binds.

## Exit

Fixtures in `conformance/code.cxd` (`program-pat-attr-rest-*`): no other predicates
(all attributes); some named predicates (only the remainder); no attributes left
(`{}`); no attributes at all (`{}`); rest-map key ORDER = the candidate's attribute
order; the rule-5 interaction (`[cat @* $a $n]` binds the element, `[cat $n]` still
unwraps); and a `[?for]` pattern-generator over the rest. Spec §5.1/§5.2 wording
under `RULED: 1270-Q1` / `RULED: 1270-Q2`; grammar [126d] left as written, now
implemented.
