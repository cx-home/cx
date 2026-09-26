# XAP-1a, XAP-1b — the xap host embeds the flow runner (owner: Letter 14 = 1a 2b, 2026-09-26)

**Status: RULED (owner, 2026-09-26 01:08Z, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591), Letter 14; the wave's scope widened by
Letter 19 = (a), 01:12Z).** It answers the two decisions cx-home/cx-platform-xap#1 owed before code
(flow.md §4.23, RULED: WF-28b: "the XAP host embedding this runner is a NAMED LANDING with its own
ruling"); FW-1 put that issue in the release and FW-2 holds the tag until it closes. The design draft
the letter carried was measured on `origin/release/0.18` `c7424ddf6` with the pins
`cx-platform-flow` `b81935b7`, `cx-platform-xap` `3c5d8232`, `cx-core-code` `896dffd3`.

## The owner's word, verbatim

- 2026-09-26 01:08Z: **"L14 1a 2b L15 a L16 a if these are the best long term for cx. not that we're
  burning credits pretty fast. don't cut anything short but we shouldn't be burning so many credits
  in the future"** — Letter 14 = Question 1 (a) + Question 2 (b). (L15 and L16 are decided on their own
  pages, not here.)
- 2026-09-26 01:12Z: **"a"** — Letter 19 = (a), the letter last put: the XAP-1 wave also builds the
  command-def projection a feature package owes the program face (the ruling of 2026-09-06,
  `rulings_2026_09_06_connector_is_a_feature_728.md`), so `cx flow serve` and the host load a
  feature package the same way and the WF-28b gate grades feature verbs on both runners — the
  draft's flag 2, decided before the brief rather than by the wave. `cx flow serve`'s `[store]`
  refusal naming #1334 goes with it.

## The letter's options, verbatim (#1591, Letter 14, 2026-09-25 22:08Z)

**Question 1 — which kinds the deployment face serves in v0.18 (proposed XAP-1a)**

- **(a) `schedule`, `intent`, `webhook` — every kind serve serves except `file` (refused, WF-29); `fold` stays a named landing on both runners (WF-36).** *Portability:* every serve row except `file` moves to a deployment unchanged, so WF-29's purpose is whole in v0.18. *Gate:* the host arm is graded over `webhook` (body = the `[args …]` record, nonce = its content address, as `case-one-law` does over `file`) and over `intent`. *Cost:* `schedule` needs fact 4's safepoint; `webhook` needs a path on the host's listener, refused at boot on collision with the standard surface, an OPTS route, an S-29 gateway route or the reserved `/.cx/flow/act`. *Authority:* a delivery is admitted as the binder's own act, so an unauthenticated path on a public host is a real exposure (*inference*); the spec already routes signed, replay-checked pushes through §3.4's connector `kind=webhook` → journal → an `intent` row. *Secrets:* unchanged (fact 9). *#1498's "when X":* served by `intent`.
- **(b) `intent` only, plus the reserved correlated-act path.** The smallest surface: an outside push reaches a hosted flow through §3.4's connector webhook (verified) → journal → `intent`, and `schedule` and `webhook` stay named landings on the deployment face. *Consequence:* a `[runner]` with `schedule` or `webhook` rows cannot move to a deployment without an edit, so WF-29's portability is half-true for the release. *Scope:* it narrows FW-1 ("every named landing … lands in v0.18"), which makes it a scope decision in its own right (the 2026-09-17 rule). `deadline=` still needs timers, so fact 4's fix is owed anyway.
- **(c) (a) plus `fold` on the host only,** with `fold=` naming a derived noun a `[deriver]` already declares. WF-36's blockers (no store handle; a comprehension in the runner document) are already deployment data on the host (*inference*). *Consequence:* the host serves a kind serve refuses, so a `fold` row can never move to serve — the "one row shape" symmetry breaks in the other direction. *Cost:* the largest scope, plus a new ruling on what WF-31's "fold position" nonce means for a deriver.
- **Recommend (a).** It completes the portability WF-29 was written for, gives the gate a kind both runners serve, and keeps FW-1 whole; `fold` keeps its own landing and its own ruling on both runners.

**Question 2 — the host-side courier: a host thread or a `sched` cadence (proposed XAP-1b)**

- **(a) A host thread** — a V `spawn`ed loop, in the pump pattern, ticking the WF-32 set every D. *Consequence:* a third concurrent evaluator entry beside the reactors and pumps — the shape 1358-a rejected and the class #1411 measured on serve. *Timers:* those armed during the thread's `advance` land on the main lineage (fact 5), so they still need fact 4's safepoint and fire on a different fiber from the courier. *Byte-identity:* each run's transitions are still decided by the pure law under CAS (§4.2, §4.5), but the host's process model diverges from serve's serial one (*inference*).
- **(b) A `sched` cadence.** At boot the host arms `[$sched:every D courier-tick {mode: :fixed-delay}]` on the fiber that runs `rearm`, and the park at `:723` becomes a safepoint as `$xap:serve`'s is (1358-a). Reactor threads post webhook and act deliveries to that fiber over a `[?channel]` and answer `202`; the courier's turn performs the `start` or `advance` (sched §2.1's channel-tick form). *Consequence:* the courier, the re-armed `deadline=` timers and the `schedule` occurrences share one lineage; evaluation is serial as on serve (1411-a), and D is literally WF-28a's cadence. *Bonus:* the fact-4 fix also makes timers armed by feature code fire (`[$xap:after]`, sched §6). *Cost:* liveness depends on that fiber reaching its safepoint — a non-blocking host (`block: false`) relies on the embedding program's own `[?sleep]`, which the spec must state; and an HTTP delivery is answered at enqueue, not after advancing (a reply that differs from serve's; transitions do not).
- **(c) No courier in the host** — a `cx flow serve` runs beside the deployment on the same journal. *Consequence:* the host never embeds the runner, contradicting WF-28b's landing and FW-1 — a scope cut. *Constraint:* two processes on one journal need the served tier (§6.3.1: a local root takes one writer). *#1498:* the "when" rows would live outside the deployment document.
- **Recommend (b).** It reuses the cadence WF-28a chose and the safepoint mechanism 1358-a ruled, and adds no thread and no second evaluator entry. Its one prerequisite, the fact-4 fix, is owed by every hosted `deadline=` whichever option is chosen.

## XAP-1a — the deployment face serves schedule, intent and webhook

**RULED: Question 1 (a).** The XAP deployment host serves `kind=schedule`, `kind=intent` and
`kind=webhook`; `kind=fold` stays a named landing on both runners (RULED: WF-36) and `kind=file`
stays refused on the deployment face (RULED: WF-29). A deployment document carries the rows a
`[runner]` document carries — `[on …]`, `[courier …]`, `[docs …]` — spelled exactly as there, so
a binding moves between `cx flow serve` and a deployment with no edit. On the deployment face
`intent=` names a stream of the deployment's journal and a committed act's fields are the event's
payload (`[do 'ns/verb' [f v]…]` starts with `[args [f v]…]`). The host arm of the one-law gate is
graded over `webhook` and over `intent`.

## XAP-1b — the host-side courier is a sched cadence on the boot fiber

**RULED: Question 2 (b).** At boot the host arms `[$sched:every D courier-tick {mode: :fixed-delay}]`
on the fiber that ran `rearm` (D is `[courier every=D]`, WF-28a's cadence), ticking exactly the
WF-32 set; the host's blocking serving loop becomes that fiber's sched safepoint, as
`[$xap:serve … block]`'s is (RULED: 1358-a) — which also makes every timer armed in a blocking
hosted XAP fire (cx-home/cx-platform-xap#2). Reactor threads post webhook and act deliveries to that
fiber over a `[?channel]` and answer `202`; the courier's turn performs the `start` or `advance`,
so the host is serial with its courier as `cx flow serve` is (RULED: 1411-a). A non-blocking host
(`block: false`) relies on the embedding program's own blocking points.

## The spec sentences 1(a) + 2(b) add (verbatim, from the letter)

**`xap_feature_distribution_market.md` §6.3.1 — new paragraph after "Source tiers":**
> "**Flow bindings — `[on …]`, `[courier …]` and `[docs …]` rows (normative; RULED: XAP-1a, XAP-1b, WF-29).** A deployment document may carry the rows a `[runner]` document carries (`flow.md` §4.23) as direct children of its root, spelled exactly as there, so a binding moves between `cx flow serve` and a deployment with no edit. The host serves `kind=schedule`, `kind=intent` and `kind=webhook`; a `kind=fold` row refuses at boot naming its landing (RULED: WF-36) and a `kind=file` row refuses at boot naming the reason — a deployment has no filesystem to watch. Rows are validated beside step 2's run assembly, before any pump consumes; an `[on …]` row with no `[runtime [journal …]]`, no `[courier every=]` or no `[docs url=]` refuses, as does a `start=` whose fetched bytes do not hash to it (RULED: WF-30), and a `path=` that collides with the standard surface, an OPTS route, a mounted gateway route or the reserved act path `/.cx/flow/act`. A pending timer whose run pinned a document the host does not hold is an `[orphan …]` row in the boot `[restore-report …]`, never dropped (`flow.md` §4.15)."

**`flow.md` §4.9** — replace the text from "**At the XAP face this is a NAMED LANDING, not a shipped fact**" through "beside the `[deriver]` rows:" with:
> "At the XAP face the deployment document carries this row as a direct child of its root (`xap_feature_distribution_market.md` §6.3.1; RULED: XAP-1a), and the host serves `schedule`, `intent` and `webhook`:"

and in the example change `intent="orders/submitted"` to `intent="acts"` (`intent=` names a journal stream on both runners).

**`flow.md` §4.23** — replace "the standalone runner serves all five today; the deployment face serves NONE — it has no `[on …]` row, and giving it one is a named landing (§4.24)." with:
> "the standalone runner serves four (RULED: WF-36) and the deployment host three — `schedule`, `intent`, `webhook` (RULED: XAP-1a)."

Replace the paragraph beginning "**The XAP host embedding this runner is a NAMED LANDING**" with:
> "**The XAP host embeds this runner** (RULED: WF-28b, XAP-1a, XAP-1b). Its bindings are the deployment document's rows (`xap_feature_distribution_market.md` §6.3.1); its courier is a `sched` `every=` cadence armed with `mode: :fixed-delay` on the fiber that ran `rearm`, ticking exactly the WF-32 set, and the host's serving loop is that fiber's safepoint (`sched.md` §2.6, RULED: 1358-a); a delivery that arrives on a reactor thread is posted to that fiber and performed there, so the host is serial with its courier as this runner is (RULED: 1411-a). Its gate is this section's, extended: the host and `cx flow serve` produce byte-identical transitions for the same flow and the same admitted acts, over a kind both serve."

In the secrets paragraph, change "Until it lands, `cx flow serve` runs" to "Until it lands (cx-home/cx-private#1517), `cx flow serve` and the deployment host run", and "like any other `cx` command" to "like any other `cx` process".

**`flow.md` §4.24** — in the table's XAP host column, `schedule`, `intent` and `webhook` become "yes (RULED: XAP-1a)". After the WF-36 paragraph, add:
> "**The XAP host serves THREE of the five (RULED: XAP-1a)** — `schedule`, `intent`, `webhook`; `fold` refuses at boot naming its landing, as under `cx flow serve`, and `file` refuses naming the reason. On the deployment face `intent=` names a stream of the deployment's journal, and a committed act's fields are the event's payload: `[do 'ns/verb' [f v]…]` starts with `[args [f v]…]` — a fixed reading, not a mapping language (§4.25)."

**`flow.md` §11** — replace "(The host arm of this comparison rides the host-embed named landing, §4.23, and is not fixtured until it exists.)" with:
> "The host arm is normative with it: the same flow delivered to `cx flow serve` and to the deployment host over `webhook` and over `intent` yields byte-identical transitions; a `fold` and a `file` row refuse at host boot by name."

**`composition.md` §2.1 — new row S-41** (in cx-platform-xap):
> "| S-41 | `xap` host → `flow` | the deployment document's `[on …]` rows as the binding set; `start`, `advance` and `rearm` over the deployment's journal; the courier as a `sched` cadence on the boot fiber | contribute authority — the host is a courier, and every step is admitted against the run's recorded basis (1265-WF-40b); serve a kind it does not declare; tick through `fleet` (WF-32) | [`../xap/xap_feature_distribution_market.md`](…) §6.3.1; [`flow.md`](…) §4.9, §4.23, §4.24 | in-process — the host runs the runner's law in its own runtime |"

Add XAP-1a and XAP-1b to §6's decisions table, pointing at S-41.
## Scope carried by this page, and what it does not decide

- Issue item 5 (the runner's signing key and connector credentials through a capability handle)
  waits on cx-home/cx-private#1517; the only sentence this page adds for it is the §4.23 secrets
  paragraph's extension to the deployment host above. Closing cx-home/cx-platform-xap#1 with item 5
  open is the owner's call, not this page's.
- The two `composition.md` seam rows cx-home/cx-platform-xap#3 names (flow → xsp/xap for the
  delegated intent and the `flow` token; flow → did/vc for the step-ack signature) are written with
  S-41 by the same wave; they record edges W6 already shipped and decide nothing new.
- Byte-identity between the host and `cx flow serve` holds over ADMITTED acts (the draft's flag 3):
  the host decides at its own PEP, `cx flow serve` passes no authority store, so the gate's fixtures
  use acts that declare no `[requires]`.
