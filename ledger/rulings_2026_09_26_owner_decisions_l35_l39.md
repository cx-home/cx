# Owner decisions 2026-09-26 (evening) — Letters 35, 38 and 39: the site token (SITE-1), shared-slot steps beside a selected run (RUN-5), #1498 stays in v0.18 (SD-2)

**Status: RULED (owner, 2026-09-26 ~23:00Z, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 18:5xZ (L35) and 22:4xZ (L38, L39)).**
Letter 37 (the pace past the weekly meter) is NOT ruled by this page: the owner asked for the plan
that keeps the post-split epic's finish at 2026-09-27 instead; that plan is the board's.

## The owner's word, verbatim

"l35a", "l38a", "l39 1498 stays in v0.18."

## SITE-1 — the public site builds on GitHub's runner with a read-only token (Letter 35 = (a))

The owner creates a fine-grained token (resource owner `cx-home`, the pinned component
repositories, *Contents: read* only, an expiry) and stores it as the Actions secret `CX_DEPS_TOKEN`
on `cx-home/cx`. `deps_bootstrap.sh` honours it when set, through a
`git -c url."https://x-access-token:…@github.com/".insteadOf=https://github.com/` configuration —
never on a command line, never in a log, the URL rule of the deps spec unchanged — and `site.yml`
passes it as `env`. One cx-private branch carries the change; it reaches `cx` on the next refresh,
after which the Site workflow is re-run and cxhome.org checked. The token retires by itself the day
the components are public (Letter 35 (b) stays the end state). Rejected: (b) publishing the
components now for a 404; (c) building the site on dev2.

## RUN-5 — a shared-slot step may run beside a SELECTED loop run under load 20 (Letter 38 = (a))

A load-sensitive step on `.build-slot-impl` (a real-socket lane, a memory gauge, the ratchet) no
longer waits for the loop's RUN-EXIT line when the loop's current run is a SELECTED run (the
`RUN-START … selected` line) and the box's 1-minute load average is under 20 at the moment the step
starts; the check is made immediately before EACH such step, as before. During a run that is not
selected (the full union, `RUN-START … union`/escalated) the RUN-EXIT rule stands. The 2026-09-14
rule this narrows was written on the load-218 day, before RUN-4's computed selection existed.
Rejected: (b) keeping the unconditional wait.

## SD-2 — #1498 stays in v0.18 (Letter 39 = (b))

End-user automation authoring (#1498) remains in the v0.18 post-split epic. It has no design yet
(the issue is filed "no decision yet"), so it lands as the other designs did: a design letter with
lettered options on the board first, the owner's ruling on the ledger, then the implementation wave.
Rejected: (a) moving it after the cut; (c) dropping it from v0.18.
