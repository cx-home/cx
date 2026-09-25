# RULED: FW-1, FW-2 — every named landing of `flow.md` lands in v0.18, end-user automation authoring (#1498) with it, and the v0.18.0 tag waits for them while the repo split lands (owner, 2026-09-24, in session on dev2)

**Status: RULED (owner, 2026-09-24, four letters in one session; FW-2 added the same evening).** The owner asked whether
`cx flow` is architected to orchestrate heterogeneous internal and external systems as one
control plane, from web UX flows to workflows across hybrid clouds. The answer from the spec
(`deps/cx-platform-flow/spec/03-approved/platform/flow.md` §1.2, §4.6, §4.15, §4.23, §4.24,
§4.12b) is yes by design; the answer from the tracker was that the design's heterogeneous half —
the performer axis, `fleet`, `migrate`, the cross-company profile, the operator acts, vocabulary
round 2, the XAP host serving bindings — was still marked "named landing — not yet implemented"
in `flow.md` §3's status table and carried by no v0.18 issue, while the connector kit had already
been pulled into v0.18 (1430-c, 1430-e, INT-17). The owner ruled, verbatim:

1. On the waves: **"(a) file the issues, all in v0.18"**, and then: **"note that the cx ecosystem
   ci/cd depends on flow, with the v0.18 release"** — the three dogfood flows of `flow.md` §4.16
   (the release/publish lane, the XAP authoring process, the repo build/gate flow) are the
   ecosystem's pipelines; the release lane's cut approval is a `:principal` step and the authoring
   flow's drafts are `:agent` steps, so W3 is first in the ladder.
2. On layering custom automations into a XAP — "a field may be composed of entries to several
   other fields, or other data, but needs to be validated against an api or human approval
   chain": the engine covers it today (a `[deriver]` for the composed field, a `:runner` step on a
   connector-kit verb for the API check, a `:principal` step with a ladder and `quorum=` for the
   approval chain, an `[on …]` binding for the "when"); the authoring half, #1498, had been parked
   for the next release under SD-1. The owner ruled **"(a) reopen #1498 into v0.18"**.
3. The ruling id: **"ruling id FW-1, write the ledger row and commit it."**

Every issue below is `prio:high` (release-blocking) and extends, never relaxes, the
`cx flow run` / `cx flow serve` byte-identical pair (WF-28b). Nothing on this page is a new
design: each issue's body carries the spec sections, the rulings and the `flow.md` §10 gate row
that already state it.

| Id | Decision |
|---|---|
| **FW-1** | **(owner, letters (a), (a))** Every named landing of `flow.md` lands in **v0.18**, under INT-17's default-in rule, because the cx ecosystem's CI/CD runs on flow with this release. Filed post-split in the repositories that own them (RS-12; a component repository's `LABELS.md` carries no release label, so the title carries `v0.18`): **W3** the performer axis — `by=:principal` / `:agent` / `:peer`, offers, ladders, `quorum=`, `[notify]`, `claim` / `release` / `reassign` (cx-home/cx-platform-flow#3; RULED: WF-4, WF-12, WF-21, WF-23, 1265-PW-1..3; first in the ladder); **W4** `fleet` and the pure stall predicate (cx-home/cx-platform-flow#4; WF-7); **W5** `migrate`, the `[flow-lineage]` claim and the dry-run classification (cx-home/cx-platform-flow#5; WF-6); **W6** the cross-company profile, the signed `step-ack` and the XSP `flow` token (cx-home/cx-platform-flow#6; WF-8); the **operator acts** `cancel` / `pause` / `resume` / `skip` / `retry-now` and `resolve` (cx-home/cx-platform-flow#7; WF-19, WF-25, 1265-PB-8); **vocabulary round 2**'s three words still refused by landing, `until`, `flow=`, `calendar=` (cx-home/cx-platform-flow#8; WF-18, WF-22, WF-24); the **XAP host embedding the runner** — the `[on …]` row admitted into the deployment document, the host-side courier and `rearm` loop, byte-identical with `cx flow serve` (cx-home/cx-platform-xap#1; the one landing that still needs its own ruling before code, WF-28b, WF-29 — spec first, the owner reads); and **#1498** end-user automation authoring — "when X then Y" from the surface through the studio and `cx xap scaffold`, published as a versioned feature — **reopened into v0.18**, last in Lane 2 behind cx-home/cx-platform-xap#1, W3, vocabulary round 2 and SD-1. Recommended order (integrator, under INT-17 — an order, never membership): W3 → vocabulary round 2 → the operator acts → W4 → W5 → W6, the host issue on its ruling, #1498 last. Board: cx-home/cx-private#1354, Lane 2 addenda of 2026-09-24. |
| **FW-2** | **(owner, letter (a), the same session, on the collision between FW-1 and D85)** The repo split and the v0.18.0 cut are DECOUPLED. The split's critical path on #1591 (K9r → K7a → K7b → the forced push of `cx-home/cx` → K10) lands as planned, tomorrow if it can; **the `v0.18.0` tag waits for FW-1's issues** — cx-home/cx-platform-flow#3–#8, cx-home/cx-platform-xap#1 and #1498 — because the owner ruled them into v0.18 and a tag that shipped without them would make FW-1's "in v0.18" a point release's promise. D85 (#1591) is amended accordingly: its letter (a) still governs the split's own gate — `cx-home/cx` pushed, `make test` green, reported on the board, no wait for a word — and the TAG is struck from that trigger; the tag is the cut's last act, run when FW-1's issues are closed and the board reports it. K10p's `RELEASE_NOTES_v0.18.0.md` is written against FW-1's scope, not the 20:30Z board's. Rejected: (b) tag tomorrow with flow at W1 + serve and FW-1's items as v0.18.x — contradicts FW-1; (c) tag tomorrow as `v0.18.0-pre.2` — a second pre-release the notes and installer would have to carry for no reader's benefit. |

## What this page does not decide

- The XAP host's own rulings (which of the five binding kinds the deployment face serves in
  v0.18; whether the courier is a host thread or a `sched` cadence) are owed on
  cx-home/cx-platform-xap#1 before its code, per WF-28b.
- SD-1's condition stands: the schema-as-data code lands in v0.18 only if ready before the final
  cut, which follows the transports (INT-3 addendum 2). #1498 depends on it and sits behind it.
- The split's own timing. FW-2 decouples the tag from the split and says nothing about the K-steps'
  order or the forced push's hour; #1591's board owns both.

## Note 2026-09-25 — W3's spec edits

W3 (cx-home/cx-platform-flow#3, merged on `47e65ed92`, flow `main` at `d4d6ac87f`) carried three
edits to `flow.md` beyond §3's status rows, raised as its RESULTS.md flag 4 and put to the owner as
Letter 5 on cx-home/cx-private#1591:

1. the effects row — `claim`, `release` and `reassign` declare `[effects [read] [write]]` (with
   `[write]` alone each was refused CXER0271 at its own effect point over a file:// journal;
   flow-106 is the fixture);
2. §4.5's "Scope in this release" paragraph, rewritten for the arms W3 made reachable;
3. §4.6's sentence carrying 1265-PW-3's own text.

The owner answered, verbatim, "l5 whats the best long term for cx?", and the integrator's answer on
#1591 was **(a)**: the three are accepted as inside W3's decision — the effects row is what the
fixture proves, the §4.6 sentence is the ruling's own text, and the `[scope]` count is what the
issue asked for. Nothing is reverted; this note is the record the letter named. Rejected: (b) keep
the effects row and revert the two prose edits; (c) revert all three and file the defect.
