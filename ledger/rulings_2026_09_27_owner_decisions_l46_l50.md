# Owner decisions 2026-09-27 — Letters 46–50 and the org profile: KIT-4's shape (KIT4-1…3), the #1498 spec gaps (AA-7…9), HOST-4's seed made real (SEED-1), the host act's basis (HOSTB-1), the call spread's readings (SPREAD-2), the org-profile push (ORG-1)

**Status: RULED (owner, 2026-09-27 ~03:2xZ, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 01:1xZ (L46), 01:3xZ (L47), 02:5xZ (L48, L49), 03:1xZ (L50)).**

## The owner's word, verbatim

"all a / note that a tenant may compose multiple xaps"

## KIT4-1 — the reference scenario's transcript is what the host observes (L46.1 = (a))

`expected.txt` is re-blessed to the acks, the readout, the audit and outbound lines read from the
host's journal after it exits, and `/__mints__`; discovery, token, validate and the wire probe move to
`crm-rest.test.cxd` cases. Rejected: the ack carrying the verb's answer; adapter routes wrapping the
stand-in driver's calls.

## KIT4-2 — one host per tenant (L46.2 = (a)), and a tenant may compose multiple xaps (the owner's note)

The scenario boots one host per tenant via `opts.tenant`; xap.md §2.1's one `[xap-runtime]` per tenant
stands. The owner's note, verbatim: "a tenant may compose multiple xaps" — a tenant is the unit of
hosting and may run several composed deployments; the connector's one-deployment-many-tenants row
(connector.md §4.1) is served by one host per tenant, each host booting the deployment for its tenant.
Rejected: one host serving every tenant from the session's (principal, tenant).

## KIT4-3 — the production document refuses at boot (L46.3 = (a))

The host boots on `production.cx` and the raised copy and refuses at boot, listing every refusal
(CXER6309, CXER6300), as §4.2's "at boot" says. Rejected: corpus cases only.

## AA-7 — `fill` lives in `cx-platform/flow` (L47.1 = (a))

The pure filler is a def of `cx-platform/flow`, beside the skeleton data; its refusal, naming every
open or wrongly-typed slot, is a code in flow's band. Rejected: xap beside the scaffold.

## AA-8 — the CLI names the binder (L47.2 = (a))

`cx xap scaffold <skeleton> --answers FILE` requires `--as <principal>` and refuses without it; the
emitted `as=` is that principal, as `cx flow run` names its actor. Rejected: a slot filled at publish.

## AA-9 — the boot check counts the automation stream (L47.3 = (a))

The deployment host's boot check counts the fold of the tenant's automation stream as bindings, so a
tenant whose only bindings are its published automations boots (AA-5); one sentence in the
distribution spec §6.3.1 beside AA-5's, xap-dist-080's expectation updated fixture-first. Rejected:
requiring at least one own `[on …]` row.

## SEED-1 — HOST-4's seed made real (L48 = (a))

A binding row may name a `cap:` basis (`authority=cap:…`), and the runner's `[authz principal=]` row
seeds the opened store with the root grant AND the runner's capabilities, so a `[requires]` step by
the root resolves against the seeded store under `cx flow serve` and under the host — the
discriminating fixture Letter 36 asked for then exists (granted runs, ungranted CXER4700, both
faces); the CK-3 projection carries `[requires]` to the host. Measured by flow#10b: today the seed is
consulted on neither face. Rejected: retiring the seed; keeping a clause no fixture can fail.

## HOSTB-1 — a session principal's act runs under a basis the host derives (L49 = (a))

On an auth-enabled host, the basis of a session principal's feature-verb act is derived from the
XSP-AUTH session's (principal, tenant) and the deployment's grant for that principal; a granted
principal's verb runs to `:done`, an ungranted one is refused CXER4700 — a fixture on the host lane
(cx-platform-xap#5; HOST-3's case then grades the run, not a decline). Rejected: the client naming
its basis on the wire; leaving the decline as the case's meaning.

## SPREAD-2 — the call spread's three readings (L50 = (a), (a), (a))

A non-sequence spread is the operand fault CXER0100 (one register for one fault); a spread accepts a
sequence or an array, the members `[?splice]` adopts (one collection law); `grammar.ebnf` in
cx-core-data states the marker ([125a] amended, [125h] added) so the grammar page and the reader
agree. #1686 merges as graded.

## ORG-1 — the org-profile README is pushed (`go .github` = (a))

The static repo-map README DOCS-3 prepared (`_gate_evidence/pipeline_docs3/org-profile/README.md`)
is pushed by the integrator to `cx-home/.github` as the organisation profile (D57a), announced on the
board first.

## AA-10 — the #1498 spec branch is approved (owner, 2026-09-27 ~04:0xZ: "specs approved")

SD-2's read gate is passed: the owner read and approved `impl/cx-F-1498-spec` (graded `c1aba750f`;
cx-platform-xap `6cebdc286`, cx-platform-flow `d29772ca6`, cx-platform-ux `bfd8fefa9`, cx-core-code
`35078275b`, each `impl/1498-spec`) with AA-7…9 folded in as ruled. The branch merges after XCO
lands (both move the flow and xap mains; one spec commit rebases and re-pins), and the two code waves
of AA-1…9 (wave 1: the skeleton data, `fill`, the scaffold; wave 2: `act=`, the host's binding
union, the automations plane) launch from the kit.

## PACE-3 — this session runs the kit overnight (owner, 2026-09-27 ~04:2xZ: "a")

The owner will be asleep and the account switch needs the owner, so PACE-2's "no new agents" is
lifted for THIS session only: it runs the kit in order — KIT-4, flow#12, #1472 now; SEED-1, HOSTB-1
and #1498 wave 1 after XCO and the spec branch merge; wave 2 after wave 1 — under the standing rules
(merges per gap, verdicts posted, letters numbered on the board before they are asked, nothing
re-litigated), stops launching when the weekly meter is spent or a letter blocks the next item, and
posts the HANDOFF for the morning. Rejected: holding after XCO and the spec branch until the owner
wakes (six idle hours).

## PIVOT-1 — a read-only step before the pivot needs no compensator (Letter 51 = (a), owner ~06:1xZ)

flow.md §4.7 gains the rule: a step whose act is an `effect=observe` verb (a read) may precede the
pivot without declaring a compensator — there is nothing to undo — while every pre-pivot act that
writes keeps §4.7's compensator requirement. order-pipeline (#1472) moves back to its designed order
(pull-contacts and enrich-orders before commit-order), fixture first (case 007 flips from the
refusal to the run; a new case refuses a pre-pivot WRITE without a compensator so the rule stays
sharp). One sentence in §4.7 with its case ids (RS-38). Rejected: keeping the built order; do-nothing
compensator verbs on crm-rest and orders-db.
