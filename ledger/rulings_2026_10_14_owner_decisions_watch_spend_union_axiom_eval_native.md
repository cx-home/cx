# Owner decisions 2026-10-14 (morning to evening): WATCH-1, STORE-133, SCALE-1910, REFPIN-1, SPEND-1, UNION-1, AXIOM-1, the evaluator's path to native (EVAL-1 … EVAL-4), BAR-139, BAR-15, GOLEDG-1

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-14 09:36Z – 17:16Z; WATCH-1 is the integrator's ruling within no bar; recorded by core 10-14 from those RULING lines, verbatim below each heading).** This page carries every decision of the day that the 10-14 morning page (rulings_2026_10_14_owner_decisions_pgo_loopbin_scale_bridges.md, which already declares CLOSE-1927 and LABELS-1) does not, except the #784 placement tier and the #801 visibility decisions (PLACE-2, SCALE-784, HA-1, KUBE-1, CONS-1, DEPLOY-784, ERASE-784, REFS-784, the design document's D1-D6, VISIB-1, VISMK-1), which plat's page declares. Several decisions were relayed under names the id grammar does not parse (two to six capitals, a dash, digits: CFG-1); each heading below gives the declared id and the relayed name, and a subject cites the declared id. Issues: cx-home/cx-private#1836, #1934, #1935, #1910, #1917, #1923, #1837, cx-home/cx-core-code#133, #139, #140, cx-home/v#15, cx-home/cx-platform-reference#1.

## WATCH-1 — V's harness heartbeat is off in the loop (VTEST_REPORT_RUNNING_PERIOD_MS ?= 0), so the 30-minute liveness watch ends a quiet hang as STALLED

> RULING integrator 2026-10-14T09:36:11Z (WATCH-1 = (a), priv's DECISION-ASK 09:36:00Z; a loop mechanism, no bar touched, FLAKE-1 kept): Makefile 'export VTEST_REPORT_RUNNING_PERIOD_MS ?= 0' so V's harness heartbeat stops masking a hung test from the 30-min liveness watch (the watch then ends a quiet hang as exit 124 STALLED with the process tree); the planted-heartbeat probe case F-stall-beat in flows/sim/premerge RED before / GREEN after; priv lands it with its next landing (not TEST_TARGETS, not flows/postmerge.flow.cx, not flows/load.cxd).

## STORE-133 — (relayed as STORE133 = (b)) cx-core-code#133 stays open under PARITY-1 until equal-or-better; it closes when #1923's per-hop lock fix lands

> RULING owner 2026-10-14T11:00:53Z (via integrator, STORE133 = (b)): cx-core-code#133 stays OPEN under PARITY-1 until equal-or-better; it closes when #1923's per-hop lock fix lands (the channel rendezvous cost) — fable's store slice lands on its own (memory parity), the time row is #1923's.

## SCALE-1910 — (relayed as SCALE1910 = (a)) #1910's k=8 bar stays 1.3x k=1 as written; plat cuts the k=8 hand-off

> RULING owner 2026-10-14T11:00:53Z (via integrator, SCALE1910 = (a)): #1910's k=8 bar stays 1.3x k=1 as written; plat profiles and cuts the k=8 hand-off (awake-executor width / re-arm), closes when a run reads <= 1.3x.

## REFPIN-1 — (relayed as REFPIN = (b)) cx-platform-reference stays dev1's; the items that need its re-pin wait for dev1

> RULING owner 2026-10-14T11:00:53Z (via integrator, REFPIN = (b)): cx-platform-reference stays dev1's — nothing from dev2's streams to that repo; xap#21, #1837's app half, store#17's acceptance row and the db-cdc move wait for dev1's re-pin (plat may post the ask on reference#1 once).

## SPEND-1 — no spend beyond the 5-hour windows: no bridging, a drain of low tens of dollars only to finish a landing within minutes of done

> RULING owner 2026-10-14T11:07:38Z (via integrator, SPEND-1; confirms BRIDGE-4 with a small drain): no spend beyond the 5-hour windows — no bridging; at most the low tens of dollars of extra usage IF NEEDED to finish a landing or close within minutes of done at a fill (OVER-4's drain shape: one 'DRAIN <item> <ETA>' line, then PAUSE). The integrator reports the extra-usage figure on every WRAP-UP and stops the drain at ~$20 past the fill.

## UNION-1 — perf-pair and premerge-record leave the union's wall and run in the loop's idle period

> RULING owner 2026-10-14T15:04:28Z (via integrator, UNION-1 = (a)): perf-pair and premerge-record LEAVE the union's wall and run in the loop's idle period (they are row steps; the union is the test gate) — a flows/load.cxd change, ruled: priv lands it (the branch it prepared), with the premerge sim cases proving the union no longer waits on them; #1917's union line then counts the rows that follow; the three quiet rows so far (942, 818, 2,272 s) stand as recorded.

## AXIOM-1 — the documentation opens the why page with the owner's axiom statement, verbatim

> RULING owner 2026-10-14T16:14:54Z (via integrator, AXIOM-1; docs — priv's area, first docs item at the 19:30Z relaunch): the cx documentation carries this statement verbatim, as the opening of the why page (and wherever the docs state what cx is): "CX starts from a single axiom: computing is data transformation, nothing more. Languages, frameworks and processes are ceremony around that fact. CX is the principle made a language: transform." Land it through the docs pipeline (cx main via the refresh), DOCS-51 as before: the owner reads the page before the tick counts; no paraphrase, no added adjectives.

## EVAL-1 — (relayed as EVAL1836 = (a)) #1836's evaluator half: compile every [?def] body once (refined by EVAL-2; its interpreter half superseded by EVAL-3)

> RULING owner 2026-10-14T16:42:04Z (via integrator, EVAL1836 = (a)): cx-private#1836's evaluator half, first lever = compile every [?def] body once (cx-core-code#64's compiled form extended from [?loop] to def bodies: names to slots, operators to direct calls, arguments in slots; the walker the fallback for uncovered forms); target <= 120 ns a call, the gate case prof-039-def-call-step-cost tightened to it; the 596-case corpus + the Benchmarks Game are the net; error positions and purity tracking stay exact (a DECISION-ASK if either needs a tree the compiled form lacks). core, 4-8 sessions, slices each with its measured row.

## BAR-139 — (relayed as BAR139 = (c)) cx-core-code#139 closes on the measured read cost with its floor restated; the first library call's 1 MB is #140

> RULING owner 2026-10-14T16:42:04Z (via integrator, BAR139 = (c)): cx-core-code#139 closes on the measured read cost (2.0 -> 1.0 MB per MB read, one copy) with its floor restated on the issue as a program that makes one library call; the first library call's 1 MB stays as the already-filed cx-core-code#140. fable-1910 posts the restated floor + rows and closes #139 when the s2 slice lands.

## BAR-15 — (relayed as BAR15 = (a)) cx-home/v#15's bar restated: under 100 us per collection at a 1 MB live set; RSS = empty program + live set + planned headroom

> RULING owner 2026-10-14T16:42:04Z (via integrator, BAR15 = (a)): cx-home/v#15's bar restated on the issue: time = under 100 us per collection at a 1 MB live set on pi-digits; memory = peak RSS no more than the empty program's RSS + the live set + the collector's planned headroom (~12.3 MB on pi-digits); gaps2 posts the restated bar with the current readings (103 us after the __DATA_CONST fix) and closes v#15 when both read met on a landed bump.

## EVAL-2 — (relayed as EVAL1836-2) the compiled form is tier 1 of a tiered evaluator and the intermediate form the later tiers consume

> RULING owner 2026-10-14T16:46:44Z (via integrator, EVAL1836-2; refines EVAL1836 = (a) — the long-term, highest-performance path): the compiled [?def] form is TIER 1 of a tiered evaluator and is built as the intermediate form the later tiers consume — slots, resolved operator bindings, purity and position data carried along, nothing thrown away. Tier 2 = the same resolved form translated to V and compiled to native code for hot/pure functions (#1836's lever (c)); tier 3 = unboxed numerics inside the native tier (#1836's lever (b)). The budget page states the per-tier targets: tier 1 <= 120 ns a call; tier 2 at compiled-language parity on the Benchmarks Game rows. core designs tier 1's form with tier 2 in view (a DECISION-ASK on the form before the first slice lands).

## EVAL-3 — (relayed as EVAL1836-3 = (b)) straight to native in v0.18: the resolution IR, then native code through V; the walker only as the fallback (cx-private#1934)

> RULING owner 2026-10-14T16:54:16Z (via integrator, EVAL1836-3 = (b); supersedes EVAL1836 (a)'s interpreter half): the highest-performance path, in v0.18 — STRAIGHT TO NATIVE. Step 1 (2-3 sessions): the resolution pass as the IR only (names -> slots, operators bound to their implementations, arguments in slots, purity and position data carried), no tuned slot interpreter; the existing tree walker stays as the fallback for forms the compiler does not cover and is never optimized. Step 2 (12-20 sessions): the IR translated to V and compiled to native code — 'cx build' for a native deployment binary, and at run time hot/pure functions compiled through V (tcc, tens of ms) and loaded; native frames visible to the collector's scan and barrier; errors and purity exact; unboxed numerics (register arithmetic without tag checks) as the native tier's second slice. Targets on the budget page: compiled-language parity on the Benchmarks Game rows the subset covers; each slice lands with its measured row (PERF-EVID) and the 596-case corpus green under the native tier. core owns it; a DECISION-ASK on the IR's shape before step 1 lands; fable-1910 may take step 2's hardest pieces (the collector linkage) on core's request.

## EVAL-4 — (relayed as EVAL1836-4 = (a)) ahead-of-time native first ('cx build' with the optimizing compiler + PGO), then the run-time tcc tier (cx-private#1934)

> RULING owner 2026-10-14T16:56:03Z (via integrator, EVAL1836-4 = (a); the order inside EVAL1836-3): AHEAD-OF-TIME NATIVE FIRST — 'cx build' translates the program's IR to V and compiles it with the optimizing C compiler + PGO into a deployment binary (the Benchmarks Game rows and the budget page's native targets are measured on it); THEN the run-time tier: hot/pure functions of a running script compiled through V/tcc in tens of ms and loaded (10x+ over the walker, instant start-up), with a later background re-compile by the optimizing compiler as the HotSpot-shaped refinement. One translator, one IR, one collector linkage; the trigger and the C compiler differ.

## GOLEDG-1 — (relayed as GOLEDGER-1 = (a)) a measured cx / Python / Go comparison ledger replaces every 'vs Go' expectation (cx-private#1935; not before window 25)

> RULING owner 2026-10-14T17:16:57Z (via integrator, GOLEDGER-1 = (a), NOT this window): a comparison LEDGER replaces every 'vs Go' expectation — the 21 cx-examples workload rows + the Benchmarks Game programs, each measured on dev2 with cx (today, then the native column slice by slice), Python 3.12.15 (PYBASE-1) and Go (the Benchmarks Game's Go entries as they are; Go twins written for the workload rows), time + peak memory + scaling at k per row, published on cx-examples' ledger; cells marked measured, never projected. Filed as a v0.18 issue at the 19:30Z relaunch (priv files; the Go twins ~1 window, priv or core after their current close-first items; the Go toolchain install on dev2 is approved as a reference install under REFS-784's shape, version recorded). Not started in window 23/24's pause.
