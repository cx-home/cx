# Rulings 2026-08-20 — binding-path axis surface (#881)

## BP-1 — binding paths carry the value-meaningful compact steps only

**Status:** RULED (owner batch "still several bugs that should be able to be
fixed: 877, 881, 882" — fix authorization; surface decided under the standing
long-term-best directive, executed this session).

**Ruling.** A binding path (`$x/…`) is a query over a **detached value**: a
binding holds a VALUE, not a node with document context. Grammar [135a]
(`BindingStep`) is therefore the value-meaningful subset of path steps —
child (`/name`), wildcard, descendant (`//name`), kind tests, attribute
(`@attr`), parent (`..`), map-key, plus predicates. **Explicit `axis::`
spellings are not binding-path surface at all**: lateral and ancestor axes
(`following-sibling::`, `ancestor::`, …) have no referent on a detached
value, and the value-meaningful axes already have compact spellings. The
parser MUST reject an explicit axis step on a binding path with a precise
diagnostic that (a) names grammar [135a] and this ruling, (b) states the
compact-step surface, and (c) names the rooted-path alternative
(`//…/axis::name`), where all twelve axes apply.

**What changed.**
- `spec/03-approved/formal/grammar.ebnf` [135a] — BindingStep production
  annotated with the value-meaningful subset and the MUST-reject clause.
- `vcx/cx/program_parser.v` — both step arms of `parse_binding_with_path`
  (`/name`, `//name`) refuse `name::…` with the BP-1 diagnostic; the older
  predicate-site refusal (`[axis::name]` step-existence, previously "not
  yet supported") is re-worded to the same BY-DESIGN message. Three sites,
  one wording.

**Non-goals.** Document-rooted queries (`//…`) keep all twelve axes,
unchanged. No evaluator change — this closes a diagnostic hole (the old
failure was a generic `unexpected token '::'`).

**Evidence.** `[?let [= $u [user [b 1]]] [$string $u/ancestor::user]]` now
fails with the BP-1 message naming `//…/ancestor::name`; `$u//b` value
queries unaffected. Closes #881.
