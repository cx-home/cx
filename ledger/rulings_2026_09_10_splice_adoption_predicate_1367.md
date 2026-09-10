# RULED: 1367-a — `[?splice]`'s adoption predicate covers every kind R-A1's refusal predicate names

**Fable, 2026-09-10 07:05Z, under the owner's delegation** (letters drafted by
worker A on #1367; owner may override on #1354): 1(a) and 2(a). Refused 1(b) —
a post-construction refusal widens the blast radius to every result and makes
the diagnostic lie permanently; refused 1(c) — a second check that can only
fire on shapes (a) eliminated is the asymmetry that caused this. 2(a): both
kinds in one change, because the fix *is* "make the two predicates agree".

## What was wrong

Two predicates thirty lines apart in `vcx/code/dynamic_construction.v`
disagreed about what a sequence value is.

- `is_content_sequence_value` (`:89`) — the R-A1 refusal predicate — admits an
  anonymous element, a seq-marker element, a raw `cx.SequenceNode`, and a lazy
  `cx.IteratorNode`. When one of those reaches element content it refuses with
  `CXER0100 … adopt its members with [?splice EXPR]` (code.md §6.4.1, #847-1a).
- `seq_items` (`:118`) — what `[?splice]` adopted through — admits only an
  element named `''`, the seq marker, or the arr marker.

So for a raw `SequenceNode` and a lazy `IteratorNode` the refusal named a
remedy that did not work: `[?splice EXPR]` wrapped the value as a single child
instead of adopting its members. Measured at `1a77938f4` with the release
binary:

```
[?let [= $flt [$filter (1,2,3) [?fn ($x) [> $x 1]]]] [probe [v [?splice $flt]]]]
  →  [probe [v (2, 3)]]                     WRONG — one wrapped child

[?lib 'cx-stdlib/bytes' :as bytes]
[?let [= $p [$bytes:split 'a,b,c' ',']] [probe [v [?splice $p]]]]
  →  [probe [v (a::bytes, b::bytes, c::bytes)]]   WRONG — one wrapped child
```

and the same two values, placed in element content directly, are refused by
R-A1 with the `[?splice]` remedy — so neither spelling worked.

The eager path was already adopting, and it is already pinned:
`program-collection-kind-002` expects `[?splice [$tail $flt]]` to yield
`[tail [e x=2] [e x=3]]`. One program shows both behaviors side by side —
`[?splice [$tail $flt]]` adopts, `[?splice $flt]` wraps.

## What changed

- New `splice_members` (`dynamic_construction.v:136`) — `[?splice]`'s adoption
  predicate, admitting a raw `SequenceNode` (its items) and a lazy
  `IteratorNode` (forced through `iterate`, the same force `[$last]`/`[$tail]`
  already apply) before falling through to `seq_items`. The arr marker keeps
  coming from `seq_items`; `[?splice]` has adopted arrays since #1223.
- All five `[?splice]` adoption sites now go through it: the element body
  (`:243`), the quoted directive-slot loop (`:602`), `wrap_items_q` (`:675`),
  `lift_quoted_items` (`:707`), and `splice_into` (`eval.v:903`, which the
  sequence and array literals of #1223 share).
- `eval_unquote_value` (`:428`) deliberately keeps `seq_items`: that is
  `[?unquote]`'s arity check, not splice adoption, and no ruling touches it.
- Fixtures `program-dc-splice-adopts-iterator-1367` and
  `program-dc-splice-adopts-sequence-node-1367` in `conformance/code.cxd`, both
  red at `1a77938f4`.

## DELETES

The wrapped answer for `[?splice]` over a lazy iterator and over a raw
`SequenceNode` — no fixture pinned it. The load-bearing status of the
`[?splice [?to-sequence …]]` workaround: those 24 uses stay correct
(`[?to-sequence]` over a materialized sequence is identity), they are simply no
longer required.

## Spec

None. `code.md` §6.4.3's registry row says `[?splice]` "adopts a **sequence
value's** members into element content (R-A1: a sequence value cannot BE
element content; `[?splice]` is the syntactic adopter)", and R-A1's own
predicate is what defines "a sequence value" — it names the lazy iterator. The
implementation is brought to the text; no spec sentence moves, so no
`spec-freeze-gate` token is owed for the prose.
