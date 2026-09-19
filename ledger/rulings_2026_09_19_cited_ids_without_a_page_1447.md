# Cited `RULED:` ids with no page — the recovery, 2026-09-19 (#1447)

`ledger/` is the decision store every `(RULED: <id>)` in a commit subject points
into. A token with no decision behind it is the exact failure mode the store
exists to prevent: it dresses a choice nobody took in the project's authority
structure. #1438's part 5 found seven such ids on 2026-09-14; measured again on
`cfc61676a`, across **every** subject on `release/0.18`, there were **eleven**.

This page is the recovery. It records no new decision except `1295-a`, whose
text is quoted from the owner's own letter on the issue; everything else is
either a POINTER to the page that already carried the decision, or a statement
that the token was never ruled.

## What the eleven actually were

Nine of the eleven were **indexing artifacts, not missing decisions** — the
decision was written, the page exists, and the id simply never appears in a
form `scripts/ledger_index.cx` can see. Three shapes, all of them fixed in the
pages themselves rather than papered over here:

| shape | ids | fixed by |
|---|---|---|
| an id run written with an **ellipsis**, so the interior ids are invisible | `1294-b` (`1294-a` … `1294-f`) | spelling the run out in `rulings_2026_09_09_xap_on_intent_handlers_1294.md` |
| the page never spells its **own** id at all | `1074-a`, `1177-a`, `1268-b` | naming the id in that page's own heading |
| the id is written in a **short form** or in **prose** where a heading was needed | `728-CK-4b` (as `CK-4b`), `831-1a′` (a bold paragraph in `partition_I5_exit_review_packet.md` §10) | the full id, in a heading |
| the page is on the head, this branch's base predates it | `THRU-2` | nothing — it resolves on `release/0.18` |

`1268-b`'s home is not the page most readers would guess: the #1268 page of
2026-09-08 says in its own header that "letter (b) of the original #1268 scope
… stands and is not revisited here" and names
`rulings_2026_09_05_xap_queue.md`, whose §#1268 section IS the decision. That
section now carries the id.

The remaining two entries are below: one real decision that had no page, and
four tokens that were never ruled at all.

## RULED: 1295-a — a coalesced pooled span inherits the OLDEST `pool_gen` of its parts

Owner, letter (a), on issue #1295; recorded here on 2026-09-19 because the
landing was V-only and went in "ledger-free" (`4e30125dd`, merged `55ce4c7c3`).
The decision's text is the owner's, quoted from the issue, not a reconstruction:

> **(a) oldest gen — RULED** (the fork issue's own fix shape). The merged
> span's `pool_gen` is the minimum over its parts, the freshly freed span
> counting as `now`; the sized-list tail walk already tolerates an old-gen span
> re-entering at the head (the split-remainder comment at :1725-1729 — found
> once the young blocker ages). DELETES: the restamp on merge. Cost bounded by
> the existing decommit/examine budgets (128 pages, 2048 spans per cycle).

Rejected with it, in the owner's words: **(b) youngest gen** — "the status quo;
never trims a growing region. Rejected: it is the defect." **(c) size-weighted
/ larger-part's gen** — "hedges between (a) and (b) with a rule nobody can
predict from the trace; rejected."

**What it DELETES:** the unconditional `pool_gen = gc_cycle` restamp that
`vgc_put_free_span` applied when it absorbed a pooled neighbour
(`third_party/v/vlib/builtin/vgc_d_vgc.c.v`), so a cold region that gained a
neighbour at least every two cycles never reached `vgc_pool_trim_age`.

V-only and cx-agnostic. Fixed on the fork at `cx-home/v@115487c7a4`
(`fix/vgc-pool-gen-1295`); pin bump `4e30125dd`, merged `55ce4c7c3`. A second
defect behind it — `vgc_pool_trim` walking each hot list from the tail and
stopping at the first young span, which made the gen fix inert for a
head-pushed span — was fixed in the same pin by `vgc_pool_push_aged`.

Recorded honestly: the issue's own reduction traces **identically** before and
after (pool 7 → 117 MB, `trimmed=0KB` on all ten cycles). That pool is hot by
pacing, not by the restamp; the pacing finding is #1386. This decision removes
the restamp defect and was never claimed to shrink that pool.

## 1310-f — NEVER RULED

Cited once, in the merge subject `3ef4d597e`
(`RULED: 1310-a, 1310-b, 1310-c, 1310-d, 1310-e, 1310-f`). The page
`rulings_2026_09_09_xap_correction_taxonomy_1310.md` carries `1310-a` through
`1310-e` and nothing more; no letter `(f)` was put to anyone on #1310 and no
text anywhere answers one. The subject over-counted the run.

Recorded as never-ruled rather than back-filled: the nearest candidate content
is the page's "**NOT implemented:** point 2, the removal of the
`entry/event/event` wrap", and that is explicitly the thing that was drafted
back as a fork rather than decided. Assigning it an id here would be an
inference wearing the store's authority.

## 1352-c, 1352-d, 1352-e — NEVER RULED

Cited together in `b7d9bb55c` and its merge `5c3a1ea2a`
(`RULED: 1352-a, 1352-b, 1352-c, 1352-d, 1352-e, 1352-f`). The page
`rulings_2026_09_09_agent_tool_projection_feature_verbs_1352.md` carries
`1352-a`, `1352-b`, `1352-f` and `1352-g`. Its title read
"`1352-a … 1352-f`", which is what made the gap look like an elision; it now
names the three ids the page actually carries.

The page does hold **two** decisions taken in that session (":act is a FAMILY,
and arrange verbs ARE projected", and "an observe verb's slots are typed from
the noun it READS"), under the heading "Two decisions taken here" — and neither
was given an id. Two unnumbered decisions and three unexplained ids is not a
mapping anyone can make from the outside, so they stay unnumbered and the three
tokens are recorded as never ruled. **For the owner:** if those two decisions
should carry ids, they are `1352-c` and `1352-d`'s obvious home, and `1352-e`
has no candidate at all.

## The 333 cited-only ids behind these, by age

`ledger-index` separates DECLARED ids (a heading carries the decision) from
CITED-ONLY ids (named in prose somewhere). The cited-only set is not a backlog
of missing decisions — most of it is cross-reference — and the distinction that
matters is whether an id is cited in a **commit subject**, because that is the
claim that a decision governs a change. Measured on `cfc61676a`, over every
subject on `release/0.18`:

| | count |
|---|---|
| distinct ids cited in commit subjects | 396 |
| of those, resolving to a page before this branch | 385 |
| of those, resolving to NO page | **11** (this page) |
| ids in the store, declared or cited | 1,015 |

So the "333 cited only" figure of #1438 is dominated by ids that resolve
perfectly well — the eleven above were the whole gap, and
`ledger-index-check`'s new subject rule (below) is what keeps it at zero.

## The rule that stops the twelfth

`scripts/ledger_index.cx --check` now also reads every `(RULED: …)` clause in
the commit subjects of `release/0.18` and refuses when an id-shaped token in
one resolves to no page. It scans only tokens that PARSE as decision ids: the
clause is free prose in much of the history (`CR-1..CR-6 — #1126 #1127 #1128`,
`EN-4(i`, `1573 class D`), and refusing prose would red the union on three
years of subjects rather than on the thing #1447 is about. That looser half —
a `RULED:` clause that carries no parsable id at all, so the check has nothing
to resolve — is named as a flag in this branch's RESULTS.md, not fixed here.
