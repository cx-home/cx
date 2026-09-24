# RULED: FW-1 — every named landing of `flow.md` lands in v0.18, and end-user automation authoring (#1498) with it (owner, 2026-09-24, in session on dev2)

**Status: RULED (owner, 2026-09-24, three letters in one session).** The owner asked whether
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

## What this page does not decide

- The XAP host's own rulings (which of the five binding kinds the deployment face serves in
  v0.18; whether the courier is a host thread or a `sched` cadence) are owed on
  cx-home/cx-platform-xap#1 before its code, per WF-28b.
- SD-1's condition stands: the schema-as-data code lands in v0.18 only if ready before the final
  cut, which follows the transports (INT-3 addendum 2). #1498 depends on it and sits behind it.
- The cut date. Today's letter D85 on #1591 governs the trigger of the v0.18.0 cut; this page adds
  scope to Lane 2 and says nothing about when the cut runs.
