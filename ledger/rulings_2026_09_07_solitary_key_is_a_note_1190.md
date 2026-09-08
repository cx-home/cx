# Ruling — the solitary-key report is a NOTE, not a second observation channel (#1190)

**Ruling id:** 1190-b
**Date:** 2026-09-07
**Ruled by:** campaign worker, long-term-best standard (owner rule 7 of #1354).
**Status:** RULED, recorded BEFORE the work.
**Follows:** `ledger/rulings_2026_09_01_key_vocabulary_1190.md` (1190-a) — which
ordered the report and is unchanged by this.

## The defect

1190-a shipped the single-registrant key report as a NEW top-level child of
`[compose-report …]`:

```
[compose-report ok=true [solitary-key name=order-id feature=alpha noun='alpha/a' via=oid detail='…'] …]
```

`xap_grammar_composition.md` §8.1 states the return shape of
`[$xap:compose-report]` exhaustively —

> returns `[compose-report ok=<bool> [conflict …]* [note …]*]`. A
> `[note code=:… at=… detail=…]` is a REPORT, not a violation: it never moves
> `ok=` … the notes are the gate telling the author something worth knowing
> about a grammar that composed. The note vocabulary is `:identity-ambiguous`
> (§4.8) and `:terminal-state` (§4.11).

`[solitary-key …]` appears in neither the shape nor the vocabulary. The spec is
the only truth, so a landed element the spec does not know about is a
divergence, not a feature — and the divergence is worse than a missing row,
because the sentence the spec DOES carry ("the notes are the gate telling the
author something worth knowing about a grammar that composed") becomes false
the moment an observation ships outside the notes.

## The ruling

**(a) The solitary-key report moves into the notes channel** as

```
[note code=':solitary-key' at='<feature>/<noun>#<via>' key='<key-name>' detail='…']
```

and §8.1's note vocabulary gains `:solitary-key`. `ok=` is untouched, exactly
as 1190-a constrains; `compose` still carries no notes.

**Refused: (b) spec `[solitary-key …]` as a third top-level element.** It is
the cheaper edit and it is wrong. `[conflict]` and `[note]` are not two
elements, they are the two ANSWERS a report can give — one moves `ok=`, one
does not. A solitary key gives the second answer, so it is a note by
definition; shipping it as its own element makes "does this move `ok=`?"
un-answerable from the element name and forces every future observation to
invent a lane with no principle to pick by. CX has no external users yet, so
this surface churn costs a fixture flip today and nothing later.

**Refused: (c) leave it undocumented.** A shipped surface outside the spec is
how the spec stops being the truth.

## Why `key=` is an attribute and not prose

1190-a constraint 2 requires the report to name the key AND its single
registrant, so a reader can tell a typo from a deliberate private ruler
without re-deriving the composition. `at=` carries the registrant — the same
`<feature>/<noun>#<field>` locator `:terminal-state` already uses — and `key=`
carries the ruler being reported on. Both stay machine-legible.

A note's `at=` shape is ALREADY determined by its `code=` (`:identity-ambiguous`
is `<feature>/<noun>`, `:terminal-state` is `<feature>/<noun>#<field>`), so a
code-scoped `key=` extends a rule the channel already has rather than making
`[note]` a bag: an attribute is admitted only where the code names what it
holds, and §8.1 says so.

## Execution constraints

1. `ok=` is never moved by a `:solitary-key` note (1190-a constraint 1 stands).
2. The note names the key (`key=`) and its one registrant (`at=`), structurally
   (1190-a constraint 2 stands).
3. Both fixtures move with it: `xap-compose-068` (the one-character-apart pair
   reports two notes) and `xap-compose-069` (a key that actually joins reports
   nothing). 069 needs no edit if it asserts silence — confirm, do not assume.
4. §8.1's return-shape row and note vocabulary are edited in the SAME commit as
   the emitter, carrying `RULED: 1190-b`; `make spec-freeze-gate` runs before
   the push.
