# RULED: 1310-a, 1310-b, 1310-c — the xap slice folds the journal's correction taxonomy

Date: 2026-09-09. Issue: #1310. Ruled by the owner and Fable on the issue,
2026-09-08 19:30 ET (`1(a)`, `2(a)`, `3(a)` on the three letters worker C
drafted at 22:23Z). Recorded here before implementation.

## Why there was a question at all

#1310 reports a projection disagreeing with its source: the journal's
bitemporal read at `{at-seq, valid-at}` applies the §2.9 correction taxonomy
(`core/bitemporal.md` L117 — `[supersedes hash= relation=:correction|:amendment]`)
and `[$xap:state]` did not, so a corrected fact kept being shown after the
correction was on the record. The DIRECTION needed no ruling: it is settled
text (`xap_grammar_composition.md` §4.7 point 4 and §8.2a point 5 both said
"the xap fold consumes it then";
`ledger/rulings_2026_09_05_constraint_grammar_1308.md:192-194`). Three things
underneath it were open, and two of them decided whether the two reads could
agree at all.

Two premises in the record were measured FALSE on the way in and are corrected
here rather than carried:

1. §8.2a point 5 said the taxonomy "is unshipped in its runtime". It shipped
   at `3b7ae5b01`, pre-v0.17.0: `jrn_temporal_project`
   (`vcx/platform/stdlib_journal.v`) is the two-pass collapse.
2. #1310's scope statement said the fold should record the linkage "as
   `state_seq` already records the commit seq beside it". `state_seq` works
   because `seq` survives the publish path; the CONTENT ADDRESS did not —
   `fabric_publish` built `[receipt seq= stream=]` and discarded the `hash=`
   the journal's own `append` returns on the hydrated entry. So the address
   had to be threaded before anything could be recorded beside anything.

## 1310-a = Q1(a) — `hash=` on a slice record names the JOURNAL's entry address

Threaded, not derived: `fabric_publish`'s `[receipt]` gains `hash=` from the
entry the append already returns; `xap_emit_receipt_fold`, the §4.2 derive
commit and the §3.1.1 boot replay each pass it into `xap_fold_committed`; the
fold keeps it in `rt.state_hash` **beside** the record, in lockstep with
`state_seq` and `state_link`. **One hash, owned by the module that chains it —
xap computes none of its own.**

**What this DELETES:** the receipt's previously closed wire shape.
`spec/03-approved/xap/fabric.md` §7 (`[receipt seq stream]`) and §15
(`[receipt seq=N]`) are re-cast under this ruling — the form gains one
attribute and nothing existing is removed. It also deletes any possibility of
the taxonomy working on an unbound runtime, which is what letter 3 then had to
answer.

**Why long-term-best:** the issue's central pin is that the two reads agree
over the same entries. Under an xap-local address that pin is unverifiable by
construction — one fact would carry two addresses depending on which surface
read it, which is the "second store with the same name" the issue is about.

## 1310-b = Q2(a) — the carriers decode to nanoseconds

`xap_valid_at` compared instant carriers with `>` on their STRINGS. The
journal's `jrn_vt_instant` says in its own comment that this is not sound
(mixed date/datetime grains, fractional seconds, offsets), and the amendment
clamp is a comparison against the very axis the filter uses — so carrying the
clamp in ns while filtering as text would make the clamp and the filter
disagree inside one function. The carriers, the clamp and the caller's
`valid-at` now all decode through `jrn_vt_instant`.

**Measured red-proof** (`vcx/target/cx-dev` @ `b2c4d4f14`, before the fix): a
record declaring `effective 2026-01-01T00:00:00+01:00` — that is
`2025-12-31T23:00:00Z` — read at `{valid-at: "2025-12-31T23:30:00Z"}` answered
**0 records**, half an hour after the fact became valid. The same read answers
1 after the fix, and `{valid-at: "2025-12-31T22:30:00Z"}` stays 0. Pinned as
`xap-compose-155`.

**`xap-compose-114` was MEASURED, not assumed.** Every instant in 113–116 is
same-grain `2026-MM-01T00:00:00Z` with no fraction and no offset, so the
lexicographic and nanosecond orders coincide and the recorded answer
`(r1, r2, r2, 0)` does not move. The ruling's re-cast clause is therefore not
exercised: nothing in the enforced corpus was pinning an unsound comparison.

## 1310-c = Q3(a) — an engaged read that cannot resolve a linkage REFUSES

`valid-at` present + a `[supersedes]` in the cut + no journal binding ⇒
`cx-err:CXER4618`, naming the binding as the missing thing. Fixtures bind
`mem://`.

**Why:** the alternative is a correction that is silently ignored, which is
precisely the failure this issue reports, reproduced in a new place. A refusal
that says "this runtime has no journal, so nothing can be corrected" is a
sentence an author can act on.

### The same refusal covers one more unresolvable case, and it is not the same as widening the rule

The implementation refuses on the general condition — a linkage in the cut
whose address space is not available — which is one case wider than the
literal words "on an UNBOUND runtime". The extra case is the **remote batch
publish** path: `fs_publish_batch_locked` replies
`[receipt-batch stream first last count]` (`vcx/platform/fabric_service.v`),
which carries no per-entry hashes, so `fab_batch_publish`'s synthesized
receipts hand the fold no address. Widening `receipt-batch` is a second wire
change the ruling did not authorize, so it was not taken; instead the read
fails closed and says which record has no address.

This is 1310-c's stated reason applied to 1310-c's stated condition (no
address to resolve against), not a new decision: fail-closed cannot produce a
wrong answer, and the alternative on that path is exactly the silent skip the
letter rejected. It is reported on the issue so a letter can reverse it.
`mem://`-bound fixtures do not reach the batch path, so it is documented and
not fixture-covered.

## Question 4 — the stale spec text, rewritten under 1310-c

Both "deliberately NOT here" blocks are replaced with the normative collapse:
§4.7 point 4 (the grammar declares no taxonomy vocabulary; what the fold adds
is the address) and §8.2a point 5 (engagement, the two relations, the address,
the ns decode, the verbatim refusals, the unresolvable-linkage refusal, and
compaction). `fabric.md` §7/§15 carry the receipt's new attribute.

## What is implemented, and the one thing that is not

`xap_at_seq` and `xap_valid_at` are replaced by ONE `xap_temporal_project`
mirroring `jrn_temporal_project` stage for stage. They could not simply be
extended in place: the seq cut returned a filtered node list, which destroys
the index alignment the collapse needs to read a record's own address, so the
two filters had to become one pass over indices.

**Byte-identity for a slice with no linkage is preserved by construction:**
`at-seq` alone still parses no payload, a noun declaring no `axis=` is still
filtered by nothing, and a compaction summary and a RECOMPUTED derived slice
(§4.12 — which carries no committed bookkeeping at all) are judged exactly as
before, since only the COLLAPSE consults the bookkeeping.

**Not implemented, drafted as `1310-d` on the issue:** the issue's pin also
asks that the xap read and the journal read "agree with the journal read over
the same entries" for the VALID-TIME half. That half cannot be written as
stated, and the reason is structural rather than a defect in this landing —
measured, not inferred:

- The journal reads validity from the reserved `valid-from=` / `valid-to=`
  **attributes on the event payload root**; an xap noun declares its axis as
  grammar `axis=` **FIELDS**, and the fold only reads intent CHILDREN. The two
  vocabularies never meet, so a journal `{valid-at}` read over an xap stream
  sees every event as unbounded-valid.
- An xap-published entry is `[entry … [event [event actor=… [do …]]]]` —
  double-wrapped, because the journal wraps the payload in `[event]` and the
  xap envelope is itself named `event`. `jrn_entry_event` therefore hands pass
  1 the xap envelope, whose only child is the intent, so the journal's own
  collapse does not see a `[supersedes]` written inside the intent either.

The CORRECTION half of the agreement pin IS writable and is pinned
(`xap-compose-157`): over one `mem://` stream the corrected record is absent
from the xap read, and the journal read at the same cut sees the same two
entries the xap fold saw. `1310-d` asks whether the envelope should carry the
reserved vocabulary so the journal's own projection works over an xap stream.

## RULED: 1310-d — points 1, 3 and 4 landed; point 2 drafted back as a fork

Owner + Fable, 2026-09-09 04:10 ET, on the issue: `(a)` with `(b)` folded into
the same landing. Recorded here as implemented, with the one point that is
NOT implemented named explicitly rather than left to be discovered.

**Landed.**

- **Point 1 — the envelope carries the journal's reserved validity
  vocabulary.** `[$xap:emit]` derives `valid-from=` / `valid-to=` from the
  written noun's `axis=` fields and stamps them on the durable envelope's
  root, and it hoists a `[supersedes hash= relation=]` child of the intent to
  a direct child of the envelope. Both are where `jrn_vt_bounds` and
  `jrn_temporal_project`'s pass 1 look, because the envelope is the payload
  `jrn_entry_event` hands them. `xap.md` §3.1.1 gains the normative row.
- The noun whose axes are read is resolved with the FOLD's own resolution,
  factored into `xap_commit_bind` and called from both sides, so the axis the
  emit stamps and the noun the fold writes cannot be two different nouns. When
  the bind names no grammar noun both reads get no axis and both filter
  nothing — they stay in agreement, which is the invariant, rather than one
  side silently narrowing.
- **Point 3 — the agreement pins.** `xap-compose-159` (no linkage: a fact not
  yet valid is absent from BOTH reads) and `xap-compose-160` (the journal's
  own collapse applies an xap-written `:correction`, asserted at two instants
  so a single column cannot agree by accident).
- **Point 4 — measured, and the answer is that nothing needs re-recording.**
  Every xap-committed entry's preimage and hash do move, but a sweep of all
  20 `sha2-256:` literals in `xap-compose.cxd` finds ZERO journal-entry
  content addresses: 18 are record/version/architecture pins computed in the
  fixture, 2 are synthetic unresolvable addresses used as refusal probes
  (`sha2-256:0000dead`, `sha2-256:aa`). Every real entry address is read live
  through `[$journal:read … ]/@hash`. `fabric.md` states no committed-envelope
  row at all — the shape lives in `xap.md` §3.1.1 — so the re-cast is there.
- **`1310-e`** — `journal-161` pins the `hash=`-is-not-a-content-address
  refusal (`CXER4618`) that `journal-112` left uncovered. Measured GREEN at
  HEAD: coverage, not a defect.

**NOT implemented: point 2, the removal of the `entry/event/event` wrap.**
Drafted back as a fork on #1310 with the measurement, because the `event` head
is load-bearing in a way the ruling did not have in front of it:

- The boot replay and every external observer select an xap entry with a
  fabric HEAD PATTERN spelled `"event"` — `stdlib_xap.v`'s own replay
  subscription, plus four `[$fabric:observe $f "acts" "event"]` lanes in
  `xap_umbrella_test.v`.
- A head pattern matches the PAYLOAD's head, not the journal's wrapper. That
  is pinned, gate-enforced, by `fab-cst-003`, which observes with the pattern
  `"do"` over `[do :order.a]` payloads and is delivered.
- The pattern vocabulary is a topic atom, a head-name string, or a predicate
  — there is no match-everything pattern.

So dropping the head makes the boot replay match ZERO entries. It would red
`xap-compose-157` (whose `replay-raw-n=2` IS the boot replay) and the four
observer lanes, and it changes the subscription every external consumer of an
xap stream writes. `xap.md` §3.1.1 states the head "stays `event`, so
`"event"` is the stream's total pattern" — normative text point 2 contradicts.
Point 1 alone closes the measured defect, so the two halves are separable and
this landing takes the one that is settled.

**The defect, measured with the shipped binary at `b2c4d4f14` before any fix**
(recorded, not predicted): `[agree jrn-mar=2 xap-mar=1 … raw=2]` — the journal
handed back a fact dated five months in the future that the feature's own read
correctly withheld; and `[collapse jrn-mar=2 xap-mar=1 jrn-jul=2 xap-jul=2
raw=2]` — the journal applied an xap-written correction in neither column.
`path-event-event=2` / `path-event-do=0` / `path-vf=0` on the same run
confirm the double wrap and the absent vocabulary directly.
