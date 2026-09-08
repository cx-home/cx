# RULED: 1327-a — §3's verb list says which verbs answer, and a gate holds it

**Date:** 2026-09-08 · **Issue:** #1327 (`cx-home/cx-private`) · **Ruler:** the
v0.18.0 close-out campaign worker (#1354, rule 7), on the long-term-best
standard · **Related:** #1323 (the same class, one surface over), #1265, #789.

## The finding

`spec/03-approved/std-lib/flow.md` §3 declared **seventeen** public verbs;
`stdlib/flow.cx` registered **six** of them. Nothing was red: `make
flow-vocabulary-gate` (#1323) reads §2.3's WORD table against the module's
four refusal/pending tables and never looks at §3, and
`check-code-spec-consistency` compares signatures for defs that EXIST — a def
that does not exist has no signature to compare. A caller reading §3 could
not tell a verb that answers from one that names a wave, and a packet
planning against §3 discovered it mid-build (that is how #1327 was filed).

Measured while ruling this, and **the reverse drift nobody had looked for**:
`fold-record` is `scope=public` in the module (`stdlib/flow.cx:1116`) and
shipped in W1, and §3 did not declare it at all. The disagreement ran both
ways.

## The ruling

**(a) §3 carries a per-verb STATUS TABLE, and the marking is the one the
document already uses for exactly this: *named landing*.** §4.24 marks three
of its five binding kinds that way under **RULED: WF-36**, and says in the
same breath that "a kind marked *named landing* claims nothing built". That
is the settled vocabulary of this spec for "specified ahead of its code", so
§3 adopts it rather than inventing a second spelling. Two statuses, closed:
`shipped` and `named landing`. A named-landing row cites the section or
ruling that owns the verb and says "not yet implemented" — check C's rule for
§2.3's pending rows, one surface over. §3 additionally declares
`fold-record`, which it had been silently omitting.

`flow-vocabulary-gate` gains **check D**, which holds the table against the
module in BOTH directions:

- every verb §3 declares has a status row;
- every `scope=public` def the module registers is declared by §3 (the
  `fold-record` class);
- a row marked `shipped` IS a public def; a row marked `named landing` is
  NOT (a stale marking that understates the surface is a finding too);
- a named-landing row names its landing;
- a status word that is neither is a finding, so the table cannot be
  satisfied with prose the gate cannot read;
- and three vacuity guards: no §3 def lines, no status rows, or no public
  defs each report VACUOUS rather than passing over nothing.

## What this DELETES

The reading that §3 is a wish list. After this, §3 is a claim with a gate
behind it: the next verb spec'd ahead of its code is red the day it drifts,
not the day someone tries to call it.

## The alternative refused, and why

**(b) a `f--verb-pending` table in the module**, mirroring
`f--attr-pending` / `f--kid-pending`. Refused: those two tables exist because
they produce RUNTIME refusals — a document naming an admitted-but-unbuilt
word gets a refusal that names its landing. A verb that is not registered
cannot refuse anything; the module never sees the call, the loader does. So
a `f--verb-pending` table would be data with no live consumer, which this
repository calls a partial implementation, and it would put the answer in the
module while the question ("does this verb answer?") is asked by someone
reading the spec.

## Mutation test (the #1180 rule: a gate that cannot go red is not a gate)

Six mutations, each reverted, each producing exactly one D finding and exit
1, with a clean green before and after:

| mutation | finding |
|---|---|
| drop the `retry-now` status row | §3 declares it, the table has no row |
| mark `fleet` shipped | the table claims a verb that does not answer |
| mark `status` a named landing | the marking is stale; the module registers it |
| delete `fold-record` from §3's code block | the module registers a verb §3 does not declare |
| status word `soon` | the two statuses are closed |
| a named-landing row that cites nothing | the row does not name its landing |
| remove the whole table | VACUOUS, loudly, plus one row-missing finding per verb |

Green line at the end: `18 §3 verb(s) over 18 status row(s), 7 registered.`
