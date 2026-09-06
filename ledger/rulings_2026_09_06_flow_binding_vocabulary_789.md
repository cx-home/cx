# Rulings 2026-09-06 — #789, the binding vocabulary and the WF-28 amendment (WF-29, WF-28b)

**Status: RULED — WF-29 (a) and the WF-28 amendment approved by the owner
2026-09-06 ("1a").** Ruling ids, in full so each greps literally:
`789-WF-29a` `789-WF-28b`. Branch `design/789-workflow`.

## Why this exists — an error in WF-28a, found by the packet that tried to build it

WF-28a wrote, as a statement of fact:

> The `[on …]` row is the SAME row the deployment document carries (§4.9,
> RULED: WF-3) — one binding vocabulary across both faces.

and made normative a gate requiring byte-identical transitions under
`cx flow serve` and under the XAP deployment host. **Both rest on something
that does not exist.** Verified by grep, not by reading:

| Claim in WF-28a | Checked | Result |
|---|---|---|
| the deployment document carries an `[on …]` binding row | `spec/03-approved/xap/xap_feature_distribution_market.md` §6.3.1 | FALSE. The deployment document is `[features]`, `[principals]` (`[deriver]`/`[role]`/`[agent]`), `[runtime]`, `[host-auth]`. There is no `[on …]` row, spec'd or implemented |
| `[on … start= as=]` exists somewhere to be shared | the whole repository | It appears in ONE file: `std-lib/flow.md`. Every other `[on …]` in the tree is unrelated — `[?http-service … [on http]]`, `[?fallback … [on PREDICATE]]`, a XAP UI handler |
| the host runs flows, so the two loops can be compared | `vcx/platform/stdlib_xap*.v` | FALSE. No `start`, `advance`, `status`, `rearm`, courier tick or binding dispatch. `xap_host()` boots registry → pins → compose → contract modules → runtime → govern → surfaces |
| "the same row on both faces" is at least internally consistent | flow.md's own two examples | FALSE. §4.9 names **schedule / committed intent / fold transition**; §4.23 names **webhook / schedule / file**. Only `schedule` overlaps |

**The method failure, named so it is not repeated.** The standing rule is
that a spec sentence is not evidence the thing exists; WF-27's premises were
checked by running greps against `sched`, `time`, `authz` and
`commands_effects` before ruling. WF-28's central invariant was not — it was
taken from §4.9's own prose. §4.9 is itself the sentence that was never true.

## WF-29 — the binding vocabulary, and the truing of §4.9 — RULED: (a)

- **(a) RULED — ONE row shape and ONE closed set of five kinds; each FACE
  declares which kinds it serves, and no face is claimed to serve a kind it
  does not.** The shape is `[on <kind> <kind-attrs> start=<Tier-1 address>
  as=<principal|role>]`, `as=` the binder whose act the start is (X2,
  unchanged).

  | Kind | The event, and where it lives | `cx flow serve` | XAP host |
  |---|---|---|---|
  | `schedule` | a durable `sched` timer (`every=`, `at=`) | yes | named landing |
  | `intent` | a committed intent — a `fabric` subscription or a journal consumer (`intent=`) | yes | named landing |
  | `fold` | a `live` `observe` adapter on a fold transition (`fold=`) — needs the `live` pack | yes | named landing |
  | `webhook` | an HTTP delivery (`path=`) — to the runner's ingress, or a host surface | yes | named landing |
  | `file` | a path appearing or changing (`glob=`) | yes | **refused** — a deployment has no filesystem to watch, and a hosted flow that wants a file is fed by a runner or an adapter |

  **`queue` is NOT a sixth kind.** The scaling ladder's prose named one; it
  is `intent` over a `fabric` subscription, and a second spelling of one
  mechanism is what this project refuses. **DELETES** the ladder's `queue`
  wording.
  **The §4.9 sentence is TRUED (this amends WF-3's text, not its ruling).**
  "At the XAP face the binding is ONE row in the deployment document, beside
  the `[deriver]` rows" described something that has never existed. It
  becomes a NAMED LANDING, marked as such, so no reader takes it for shipped
  and no future ruling builds on it the way WF-28a did.
  **Strongest counter:** declaring kinds a face does not serve yet is
  writing the future into an approved spec again — the exact error above.
  **Answer:** the difference is the marking. A kind marked "named landing"
  claims nothing built; the failure was an unmarked sentence read as fact.
  The table's purpose is that the shape is fixed ONCE, so the host half, when
  it is ruled, adopts rows rather than inventing them.
- **(b) let each face keep its own kinds.** REFUSED: two vocabularies for
  one concept, and a flow could not move between faces without an edit —
  which is the portability the ladder exists to deliver.
- **(c) rule only the three kinds `cx flow serve` needs now.** REFUSED: the
  deployment face would then invent its own three later, arriving at (b) by
  a slower route.

## WF-28b — the amendment to WF-28a — RULED (owner, "1a")

Three changes to WF-28a; everything else in it stands.

1. **The "same row the deployment document carries" sentence is DELETED**
   and replaced by WF-29's table: one row shape, one kind vocabulary,
   per-face availability declared — the deployment face today serving NONE.
2. **The host-embed gate is REPLACED as this packet's gate.** WF-28a made
   normative a comparison against a face that does not exist. The invariant
   it protects — one law, N runners — is testable against the runners that
   DO exist: **the same flow, the same acts, run under `cx flow run` and
   under `cx flow serve`, produce byte-identical transitions.** That is this
   packet's gate and it is buildable today.
3. **"The XAP host embeds the runner" becomes a NAMED LANDING with its own
   ruling, which is the owner's** — it requires admitting `[on …]` into the
   deployment document schema in `xap_feature_distribution_market.md`, a
   change to a shipped XAP surface, plus a host-side binding/courier/`rearm`
   loop that does not exist. Its gate is WF-28a's original one, and it is
   written into that landing rather than lost: when the host runs flows, the
   host and `cx flow serve` must produce byte-identical transitions.

**What this DELETES from the campaign's plan:** the assumption that WF-28
was one packet. It is two, and the second is gated on an owner ruling about
XAP's deployment document. The scaling ladder's item 3 is correspondingly
half the size it looked, and its rung-3 gate ("the repo's gate under
`cx flow serve` with an approval gate") is unaffected — it needs the
standalone runner, never the host.

## Edit map — `spec/03-approved/std-lib/flow.md`

| Section | Edit |
|---|---|
| §4.9 | the deployment-document binding sentence marked a NAMED LANDING, not current fact; WF-29's kind table referenced |
| §4.23 | the "same row" sentence replaced by WF-29's shape + per-face table; the gate replaced by the `cx flow run` vs `cx flow serve` comparison; the host embed named as its own landing |
| new §4.24 | WF-29's five kinds, their attributes, and the per-face availability table |
| §11 | the embed fixture retargeted to `cx flow run` vs `cx flow serve`; a negative for `file` on the deployment face |
