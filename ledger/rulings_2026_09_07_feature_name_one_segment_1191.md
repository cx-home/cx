# Ruling — a feature name is ONE segment; `/` is the qualification separator (#1191)

**Ruling id:** 1191-a
**Date:** 2026-09-07
**Ruled by:** campaign worker, long-term-best standard (rule 7 of #1354).
**Status:** RULED, recorded BEFORE the work.

## The defect, verified at `ea32f2303`

`feature.cxs` accepts any string as a feature name, `/` included. A feature
named `pb/store` validates, composes, and qualifies its members correctly —
and then every ordering rule in it refuses at W4:

```
[compose-report ok=false
 [conflict code=':w4' at='pb/store/seal-after-make'
  detail='rule target "pb/store/seal" reaches outside pb/store's grammar and its uses set']
 …]
```

The cause is one line of `xap_gc_gate`:

```v
owner := tgt.all_before('/')      // 'pb' — not 'pb/store'
```

The same feature named `acme.store` composes `ok=true` today (measured).

## The ruling

**(a) A feature name is a SINGLE SEGMENT: `/` is refused.** It is refused in
`feature.cxs` by pattern (so `cx validate` names the problem at authoring
time) AND at compose time as a `:w1` conflict (so a document that never met
the schema cannot smuggle one in). §2 states the convention: `/` is the
member-qualification separator and is therefore TAKEN; publisher
qualification uses `.` — `acme.store` — which nothing in the composition
algebra splits on.

**Refused: (b) make the resolver split on the last `/`.** It fixes the filed
symptom and leaves the model undecidable. A qualified name is
`<feature>/<member>`; if a feature name may contain `/`, then `a/b/c` cannot
be parsed without knowing the feature set, because a member name is equally
unconstrained. The tree already splits BOTH ways — `all_before('/')` at the
W4 scope check and the dependency check, `all_after_last('/')` at slice paths,
selection matching and ρ narrowing — and under single-segment names those
agree, while under (b) every one of ~10 sites becomes a separate correctness
question with no invariant to check it against. (b) would also need a pattern
on member names to be sound, so it costs MORE constraint than (a), not less.

**Refused: (c) state the convention only.** Prose that nothing enforces is how
this got filed: the author's signal arrives at the first ordering rule,
months after the naming choice, pointing at the rule.

## Why (a) is long-term best

It turns "a qualified name has exactly two segments" from a thing that happens
to be true into a checked invariant, which is what makes qualification
reversible without a registry lookup — the property §5's bare-term index and
every `all_after_last('/')` site already assume. It fails at `cx validate`,
which is the issue's own stated preference, and its diagnostic names the
naming choice rather than the rule that tripped over it. And it does not
refuse the need behind the filing: publisher qualification is answered, with a
separator the algebra does not touch.

## Execution constraints

1. Both halves land together. A schema pattern alone leaves compose defenceless
   on a hand-built `[feature]` value; a compose check alone leaves `cx validate`
   silent. The filing's own lesson is that one gate late is the defect.
2. The `:w1` conflict's `detail` names the separator convention, so the reader
   learns the fix from the refusal.
3. Corpus pre-flight, done: NO fixture in `conformance/` or `vcx/tests/`
   declares a feature name containing `/`. Nothing is being flipped.
4. Fixtured: a slashed feature name is a `:w1` conflict at compose; the same
   feature with a dotted name composes `ok=true` WITH its ordering rule (the
   filed repro, resolved); and a `cx validate` of the slashed document refuses
   against `feature.cxs`.
5. §2 (the namespace rule) carries the statement; §4's W1 row carries the
   check. `RULED: 1191-a` in the commit; `make spec-freeze-gate` before push.
