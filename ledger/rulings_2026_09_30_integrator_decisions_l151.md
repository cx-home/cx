# Integrator decision 2026-09-30 — Letter 151, taken as delegated: the representation issue closes on the runtime round that meets the ruling bar, and Letter 129's framing is amended

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, DELEG-3; the letter came in REPRM-1's
RESULTS.md (`_gate_evidence/pipeline_reprm/`, graded `89abf94dc`) and was posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 21:4xZ with this taking; the owner may
reverse it on reading). SHIP-1, REPRM-1 (L129), RP-5, RP-6, 1226-a, #1119, #1207, #1295, cx-home/v#6.**

## The owner's words, verbatim

"no decisions for at least 8hrs. pause if limits are hit and resume when lifted. make best long term
decisions for cx. no deferring. no partial work. only complete, sound, performant implementation that
follows the expectations"

## What W8 measured (Letter 129's round, 2026-09-30, on `63299f88a`/`3e3eb534e`, three runs per read)

Peak RSS on the audit's 300k-record corpora under `--from=X --to=X`, each read on the shared slot
after a RUN-EXIT: JSON 38.29× input (Stage 0: 83.56×), XML 40.93× (Stage 0: 58.00×), identical to the
second decimal across passes at load 10–25. RP-5's attribution: the live tree alone 7.92× (JSON) and
7.94× (XML) of input after a forced collect; RSS over live 4.07× (JSON) and 3.74× (XML) on the
convert, 2.07× on the JSON parse alone. bench/repr json 7.568 against its 7.95 pin, xml 7.940 against
8.35; repr-guard green. The measuring program is kept beside the record
(`_gate_evidence/pipeline_reprm/measure_rss.cx`).

## RTMEM-1 — #1119 closes when RSS ÷ live ≤ 2.5× at parse peak holds on both reads, met in the V fork's collector; RP-6 stays trigger-bound (L151 = (a))

The bar Letter 129 cited — peak RSS ≤ 8× input — was DELETED by 1226-a on 2026-09-05 as unreachable
by construction (vgc's 2× pacing goal over a 7.9× tree floors near 16× input); the bar the ledger
holds is RSS ÷ live ≤ 2.5× at parse peak, and this measurement leaves it red on the runtime half
alone. cx-home/v#6's restamp fix (fork `03df817b29`, pinned 09-10) did not move `trimmed` off zero:
post-peak the hot pool is age 0–1 at every trim, popped and re-pushed each cycle under a goal of
marked plus the GOGC term, so the pool and pacer policy on a monotone build-up is the cause that
remains. RP-6's trigger — a consumer feeding a > 100 MB record document — has not fired; Letter 129's
"when the bar is not met, RP-6's round lands" read the deleted bar as RP-6's trigger, and is amended
by this page: what fires on this measurement is 1226-a's runtime red, and its round is RTMEM-1.

Taken: one opus round in the V fork (its own worktree, the pin-bump discipline of the standing rules,
a `v_fork_register.cxd` row): the collector's retention on a monotone build-up diagnosed under
`VGC_GCTRACE=1` on this round's corpora, the policy that returns pooled spans the build-up will not
reuse designed and stated in the fork's vgc notes, a vgc test red first (a monotone build-up whose
RSS ÷ marked at peak must be ≤ 2.5), then `measure_rss.cx` re-run on the same corpora and the
repr-guard and bench/repr pins re-graded; #1119 closes on the green run of the pin bump that carries
the two reads under the bar, and the finding closes cx-home/v#6. RP-6's seams (shape-shared record
maps, columnar record arrays) keep their trigger as RP-6 = (a) ruled. Rejected: (b) shape-shared
record maps now, paired with the runtime round — the D22 API moves at the cut for a density no
consumer has asked for, and the bar is met only by the runtime half anyway; (c) columnar record
arrays — the largest seam of the data ring rewritten at the cut against a trigger that has not fired;
(d) closing #1119 on 1226-a's bar as "representation done, runtime upstream" — a red ratchet
recorded as a pass, the thing 1226-a refused.
