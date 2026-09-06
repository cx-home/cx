# Rulings 2026-09-06 — #728 component 2: a connector is a feature (CK-1 … CK-6)

**Status: PROPOSED.** Recorded BEFORE any spec text, on the WF pattern: each
item is a letter with what it DELETES; (a) is the recommendation. Ruling ids,
in full so each greps literally: `728-CK-1` `728-CK-2` `728-CK-3` `728-CK-4`
`728-CK-5` `728-CK-6`. Branch `design/789-workflow`. Owner directive
2026-09-06 ("1a"): record the unification as a ruling packet rather than an
analysis note, because nothing of #728-2 is built and this is the cheapest
moment.

**The question the owner asked (verbatim intent).** cx flow delivers a
connector framework with a few connectors, and downstream adopters build
their own. CX can also model another system as a first-class XAP citizen,
from read-only data access up to full headless, message-based integration.
How do those two relate? Two approaches must be avoided; one approach must
scale from simple to complex, the way flow's own ladder does.

**The answer in one sentence.** They are not two approaches: a connector IS a
feature, and what scales is how much of that feature is data versus code.

## Inputs read — and what was VERIFIED by grep, not by reading prose

The WF-28a lesson applies: a spec sentence is not evidence. Each fact below
was checked against the tree.

| Fact | Where | Verified |
|---|---|---|
| A feature is grammar (nouns, verbs with `[intent [do :v [p]…]]`, rules) plus a runtime contract the host calls: `readout` always, `apply` iff a non-observe verb exists, `simulate` optional | `xap_feature_distribution_market.md` §1.2 | spec text; `docs-src/canonical/sections/19-xap-distribution.cxd` carries the minimal module |
| Package kinds are exactly three: **feature**, **library**, **client**; a library carries no grammar and no authority (N-DIST-2) | distribution spec §1.1 | spec text |
| The feature schema ALREADY carries a swappable transport stack: `[source [gateway name= kind= priority=] [reading field= failover= [sensor via=]] [adapter]]`; `kind` is deliberately open ("a new gateway plugs in with zero schema change") | `spec/03-approved/xap/xap_schemas/feature.cxs` lines 159–190 | schema text; USED by `reference/shop/orders.feature.cxd` (`[gateway name=shop-api kind=api priority=1]`) |
| The host loads each feature's code entry as a module and registers its public defs as closures spelled `<feature>:<def>` (`stripe:apply`, `stripe:readout`); it does NOT project one def per verb | `vcx/platform/stdlib_xap_host_notd_wasm32_emcc.v` lines 189–210, 975–990 | code |
| `[?lib 'pkg:<name>@<version>#<hash>']` is implemented on the platform profile | `vcx/code/module_loader.v:572`, `vcx/platform/stdlib_xap_dist.v:1194` | code |
| A command def is a `[?def]` with an `[effects]` clause; `[idempotent]` and `[compensates NAME]` are sibling clauses | `commands_effects.md` §2 | spec text; clauses exist in the parser |
| flow.md §4.1: a step's `[do 'ns/verb']` head resolves through the module tree to a command def in a program, and through ρ over the composed grammar to a verb in a XAP | `flow.md` §4.1, §3 (`$env` is the resolver) | spec text; the flow resolver is NOT implemented — `CXER4953` appears only in spec and ledger |
| `cx flow serve` "has no tenants, no surfaces, no cascade and no composed grammar"; it resolves acts through `[env …]`, a module tree | `flow.md` §4.23 (RULED: WF-28) | spec text |
| The flow's `attempts=` is refused on a step whose resolved command declares no `[idempotent]` | `flow.md` §8 `CXER4952` row (RULED: WF-23) | spec text |
| #747 already names two adapter kinds (declarative connector, coded bridge) and says the host must schedule ONE unit; #735 says "the contract is the interface either way; the declarative form is the default, not the only citizen" | issues #747, #735 | tracker |
| The live adapter contract: foreign events become canonical CX at the boundary, on a DECLARED guarantee rung (`:complete-ordered` / `:coalesced-rescan` / `:snapshot-diff`), into a single-writer adapter stream | `live.md` §8 | spec text |
| The connector inventory's five additions: connector document + engine, pagination, `client_credentials`, declarative signing, `Retry-After`; and its "must be ruled" items 3 (document shape) and 5 (ingestion time) | `design/728/connector_target_inventory_2026_09_06.md` | this branch |

## The finding the packet rests on

The tree already contains the unification and has never said it. A feature
already IS "a grammar over an external system plus the code that reaches
it": its `[source]` stack names transports by open kind with priority and
failover, its `apply` is where a verb becomes an effect, its `readout` is a
fold over what it ingested, and it is published, signed, pinned, installed
and narrowed (`instance of=`) through one gate. The ladder's third invariant
("connectors are not a second kind of STEP") stopped one level short. The
missing invariant is: **connectors are not a second kind of FEATURE.**

The place the "two approaches" instinct actually bites is one level down, and
it is already ruled twice locally: a grammar verb and a command def are two
declaration systems for one act. VF-1 dispatches `ux:form` on that split;
flow.md §4.1 resolves it once per face. It has never been ruled once,
generally — and until it is, a connector reached from `cx flow serve` and the
same connector reached from the XAP host are two different resolved things,
which makes the one-law gate unbuildable across faces. CK-3 is that ruling.

## CK-1 — what a connector IS — RECOMMENDED: (a)

- **(a) RECOMMENDED — a connector is a FEATURE PACKAGE (`kind=feature`, §1.1),
  never a fourth package kind and never a standalone connector-definition
  document.** Its grammar is the external system's nouns and verbs
  (`stripe/charge`, `stripe/create-charge`); its `[source]` stack names how
  each noun is fed (CK-2); its `apply` is the connector engine (CK-5) driving
  the declared gateways; its `readout` is the fold over its adapter streams.
  A connector meets the compose gate W1–W6 like any feature, so a composite
  can derive nouns over it (`[from 'stripe/charge' 'orders/order']`), which
  no standalone connector document could offer. What scales is the code
  share inside the one package:

  | Rung | The adopter wants | The feature is | Data or code |
  |---|---|---|---|
  | 1 | read the other system's data | nouns from the ingested schema; `readout` over an adapter stream fed by a `[gateway]`; no non-observe verb, so no `apply` | all data |
  | 2 | call into it | verbs from the ingested schema; `apply` delegates to the engine executing the gateway declaration under `[?retry]`, `[?rate-limit]`, `[?circuit-breaker]`, `[?timeout]` | all data |
  | 3 | bend a few calls | the same package; its own `.cx` wraps or overrides named verbs before delegating | data plus a little code |
  | 4 | speak a protocol the engine cannot | `apply` and ingest are a coded bridge (#747's second kind) or a foreign-runtime engine (#732), behind the same contract | code, one contract |
  | 5 | full first-class, headless, message-based | a native feature: own nouns, verbs, rules, derived nouns, composed with everything else, on the PEP and the journal | code, indistinguishable from any feature |

  Moving up a rung adds code inside one package. It never switches
  frameworks. **What it DELETES:** the "connector document" as a document
  kind; the rung-5 "connector catalog" (the feature registry IS one — a git
  repository, signed, pinned, tenant-narrowed, distribution spec §4); #747's
  "adapter instance" as a distinct scheduled unit (it is a pinned `[feature]`
  row in a deployment or runner document); inventory "must be ruled" item 3.
  **Strongest counter:** a read-only rung-1 connector has no `apply`, so it
  is "not really a feature". **Answer:** §1.2 already makes `apply`
  conditional on a non-observe verb; a feature of pure nouns and observe
  verbs is a feature the contract anticipated.
- **(b) a standalone connector-definition document kind plus its engine — the
  #728-2 text as filed.** REFUSED: a second package kind means a second
  install gate, a second catalog, a second deployment row and a second
  authority story; and a connector's data could never be composed over,
  because nothing outside a feature reaches the W-gates.
- **(c) a connector is a LIBRARY package.** REFUSED: N-DIST-2 — a library
  carries no grammar and can hold no authority, and a connector's verbs must
  sit on the PEP with an effect signature like every act.

## CK-2 — where the transport declaration lives — RECOMMENDED: (a)

- **(a) RECOMMENDED — the EXISTING `[source]` stack, extended; never a new
  block.** A `[gateway kind=…]` row already names a transport by open kind
  with `priority=`; it gains the engine's per-transport NEEDS as attributes
  — the auth scheme (naming a secret-handle capability, #728-6, never a
  value), the pagination style and its stop condition, the signing scheme,
  the declared guarantee rung for what it ingests (`live.md` §8's closed
  atoms). A `[verb]` gains `via=<gateway>` (the exact analog of
  `[sensor via=]`); a noun's `[reading]` sensors already name theirs. The
  SHAPE lives in the feature; the BINDING — this deployment's base URL,
  sandbox versus production, this tenant's credential handle — lives in the
  deployment document's `[runtime]`/`[config]` per §6.3.1 ("the durable
  plane is deployment DATA"). One system offering an API, an SFTP drop, a
  message bus and direct database access is ONE feature with FOUR gateways:

  | Channel the system offers | The gateway row | Rung it declares |
  |---|---|---|
  | REST API | `[gateway kind=http …]` — write verbs `via=` it; polled nouns read through it | poll → `:snapshot-diff` |
  | FTP / SFTP drop | `[gateway kind=sftp …]` — poll, or a `file` binding on a runner | `:snapshot-diff`; `:coalesced-rescan` under watch |
  | messaging (AMQP, Kafka, NATS) | `[gateway kind=amqp …]` over a fabric bridge into the adapter stream | `:complete-ordered` where the broker orders |
  | direct database | `[gateway kind=cdc …]` — the live ladder's top rung (#728-3) | `:complete-ordered` |

  Two rules fall out and are ruled here. **Never split a system into
  features by transport** — `sap-api` and `sap-db` as two features is the
  two-approaches failure at the package level. **Split a large system by
  vocabulary if at all**, exactly as native features split: `sap-finance`
  and `sap-hr` are two features because they are two authority boundaries,
  not because they use two ports. **What it DELETES:** a `[connector …]`
  block; the inventory's "connector document" addition (rows 25, 26, 28 land
  on `[gateway]` plus `[config]`).
  **Strongest counter:** the `[source]` stack was drawn for sensors with
  failover, not for SaaS APIs. **Answer:** its own comment says `kind` is
  open so that a new gateway plugs in with zero schema change; an HTTP API is
  a gateway with a priority like any other, and redundant gateways with
  failover is exactly what a primary API plus a nightly file drop is.
- **(b) a new `[connector]` block beside `[source]`.** REFUSED: two places
  to answer "where does this noun's data come from".
- **(c) transports declared in the deployment document only.** REFUSED as
  stated, KEPT in part: the deployment binds concrete endpoints and handles
  (§6.3.1); it cannot declare which gateways a feature HAS, because compose
  and the adopter's narrowing read the feature.

## CK-3 — one road to a verb from both faces — RECOMMENDED: (a)

**The fact.** The host registers `<feature>:apply`. A program loading the
same package through `[?lib 'pkg:…']` sees `apply` and `readout`, not one
def per verb. flow.md §4.1 says a program resolves `[do 'stripe/create-charge']`
to a COMMAND DEF. So today, under `cx flow serve` with `[env]`, that head
resolves to nothing, and the same flow that runs on the host cannot run on
the runner — which is the portability the ladder exists to deliver.

- **(a) RECOMMENDED — loading a feature package as a MODULE projects ONE
  command def per grammar verb; the projection is the loader's, defined
  once, and is what BOTH faces resolve to.** For each `[verb name=v …]`
  whose `[intent [do :v [p1] [p2]…]]` names its parameters (N-COMPOSE-7), the
  loader defines a public `[?def v … ($p1 $p2 …)]` whose body is
  `[<feature>:apply '<feature>/v' [do :v [p1 $p1] [p2 $p2]…] $store]`.
  Its clauses: the parameter list is the `[intent]` list verbatim; its
  `[effects]` is the `apply` def's declared `[effects]` (checked and
  enforced, L110 — the projection can neither widen nor hide what the code
  does); its `[idempotent]` and `[compensates …]` come from the verb, which
  means **`[verb]` gains `idempotent::bool` and `compensates::string`** in
  `feature.cxs`, mirroring the command clauses. This last is load-bearing,
  not cosmetic: WF-23 refuses `attempts=` on a step whose resolved command
  declares no `[idempotent]`, so without it EVERY connector verb is
  retry-unsafe and every connector step refuses `attempts=`. `$store` is the
  environment's store binding: the deployment store on the host, and on the
  runner a **`[store url=]` row in the `[runner]` document, required when
  `[env]` loads a feature package** (absent → `CXER4965` at boot, naming the
  package — the class WF-33 already uses). On the XAP face nothing changes:
  ρ resolves the qualified verb and the PEP admits it before `apply`; the
  projected def is the same call the host makes at line 979, so the two
  roads meet at ONE function. **What it DELETES:** hand-written command defs
  wrapping `$stripe:apply` per connector per program; the second half of the
  VF-1 split as a permanent seam (ux:form's dispatch stands, but both kinds
  now project the same def); WF-28's implicit assumption that `[env]` module
  trees carry only hand-authored defs.
  **Strongest counter:** the composed-grammar effect signature `(effect,
  scope, consequence)` and the `[effects]` clause are different vocabularies;
  projecting one from the other invents a mapping. **Answer:** (a) does NOT
  map them. The signature stays the PEP's business at the XAP face; the
  `[effects]` clause stays the code's, inherited from `apply`. The projection
  carries each to the face that reads it and invents nothing.
- **(b) leave two roads — grammar verbs on the host, hand-written command
  defs wrapping `apply` in programs.** REFUSED: every connector authored
  twice, and the one-law gate (WF-28b) compares two different resolved acts,
  so it can never be green for a connector step.
- **(c) give `cx flow serve` a composed grammar and a PEP.** REFUSED: WF-28
  ruled the runner has neither, deliberately — that is what keeps a make
  replacement from adopting the XAP model. (c) is a second host.

## CK-4 — OpenAPI ingestion: what it produces, and when — RECOMMENDED: (a)

- **(a) RECOMMENDED — a BUILD-TIME pure transform, OpenAPI document → feature
  package, published like any feature and treated as an ARCHETYPE the
  adopter narrows with `instance of=`.** Paths and operations become verbs
  with N-COMPOSE-7 parameter lists; schemas become nouns; the servers block
  becomes `[gateway kind=http]` rows; security schemes become the gateway's
  auth-scheme need; pagination hints (`Link`, cursor fields) become the
  pagination declaration where detectable and an authoring TODO where not.
  The code entry is the stub `apply`/`readout` delegating to the engine
  (CK-5). Testable with no network: fixture in, canonical package out.
  **What it DELETES:** runtime OpenAPI reads; inventory "must be ruled" item
  5; per-vendor hand authoring for the regular majority of SaaS.
  **Strongest counter:** vendors change their OpenAPI documents; a build-time
  package goes stale. **Answer:** so does every dependency; re-ingest,
  re-publish, re-pin is the same loop as any feature version, and W5
  `migrate` with the fleet preflight is how a running estate crosses it.
- **(b) a runtime read of the vendor's OpenAPI URL.** REFUSED: unpinnable and
  unsignable; a grammar that changes under a running deployment defeats the
  compose gate and every W-check that was green at boot.

## CK-5 — where the engine lives — RECOMMENDED: (a)

- **(a) RECOMMENDED — a LIBRARY package, `cx-connector`, that a connector
  feature `requires`.** N-DIST-2 applies verbatim: the library holds no
  authority and runs under the REQUIRING feature's granted slice. It
  executes a `[gateway]` declaration: builds and signs requests, walks
  pagination to its stop condition, obtains and refreshes tokens
  (`client_credentials` landing in `oidc` or a sibling — the inventory's
  item 1, still open), and appends ingested records to the feature's
  adapter stream under the declared rung. Retry, backoff, rate limiting,
  circuit breaking and timeouts are NOT its code — they are the shipped
  directives the stub declares around the call. Its additions are exactly
  the inventory's: pagination, declarative signing, `Retry-After`
  awareness (item 2, still open — a `[?retry]` opt or engine code). **What
  it DELETES:** "the connector engine" as a host component; per-connector
  plumbing; the inventory's "connector document + its engine" as one
  addition (it is now `[gateway]` attributes plus this library).
  **Strongest counter:** the engine needs `net` reach that a library
  cannot hold. **Answer:** correct, and it is the feature's grant, not the
  library's — which is exactly #747's prerequisite. A payments connector
  and an MQTT bridge co-hosted in one process today share one grant set. A
  feature's granted slice already bounds `apply` (N-DIST-2); whether that
  slice bounds NETWORK reach per feature is UNVERIFIED and is the
  prerequisite this packet inherits from #747, not one it dodges.
- **(b) the engine inside the host.** REFUSED: a connector then needs a
  host to run, so the runner face (CK-3) is dead, and "zero server code"
  becomes false the first time a vendor needs a signing scheme the host
  lacks.
- **(c) the engine inside each connector package.** REFUSED: N copies of one
  library, each re-verified, each drifting.

## CK-6 — a connector feature does NOT depend on flow — RECOMMENDED: (a)

Asked by the owner mid-packet: "are all system adapter features dependent on
cx flow or not?"

- **(a) RECOMMENDED — NO, and the direction is ruled so nothing later
  reverses it.** A connector feature's verbs are emitted by ANY emitter — a
  control on a surface, an agent, a binding, a flow step — through the one
  PEP; its `[source]` ingestion runs on the host's or runner's cadence with
  no run in existence; its `readout` serves `GET /surface/<f>` like any
  feature's. **Flow depends on features (it names their verbs); a feature
  never depends on flow.** flow.md §6's composition table lists `flow` as a
  consumer of `xap`, never as a member of any feature's `needs`, and that
  stays so. Flow is what an adopter ADDS for long-running choreography over
  those verbs — retry ladders, approvals, compensation, `until` polls.
  **What it DELETES:** nothing; it forbids a dependency before it forms.
  **Strongest counter:** inventory row 23 (submit an export, poll until
  ready, download) is written as a flow, so a connector "needs" flow for
  async bulk operations. **Answer:** that is a PATTERN over three verbs,
  each of which stands alone; the flow orders them, and an adopter without
  flow can order them from a script or a surface.
- **(b) connectors are a flow module component (as #728 sequenced
  them).** REFUSED: a read-only rung-1 connector feeding a dashboard would
  then require a workflow engine it never calls.

## What this packet changes elsewhere (edit map — executed WHEN RULED, not now)

| Where | Change |
|---|---|
| `design/789/scaling_ladder_2026_09_05.md` invariant 3 | add: "and not a second kind of FEATURE (RULED: CK-1)" |
| same, rung 4 row "connect to SaaS APIs without code" | "the connector kit" → "connector FEATURES (CK-1) over the `[source]` gateway stack (CK-2), the `cx-connector` library (CK-5), OpenAPI → feature-package ingestion (CK-4)" |
| same, rung 5 row "a connector catalog" | DELETED as a missing item; the feature registry is the catalog; what remains missing is the volume gate (a 100-connector registry built by ingestion) |
| same, sequencing item 6 | "connector kit (#728-2)" → "connector features: CK-3's verb projection + `[verb]` clauses, CK-2's gateway attributes, CK-5's library, CK-4's ingestion" |
| `design/728/connector_target_inventory_2026_09_06.md` "must be ruled" | items 3 and 5 → RULED here (CK-1/CK-2, CK-4); items 1, 2, 4 stay open; add: the #747 per-feature network-reach prerequisite |
| `spec/03-approved/xap/xap_schemas/feature.cxs` | `[gateway]` gains auth-scheme / pagination / signing / rung attributes (CK-2); `[verb]` gains `via::string`, `idempotent::bool`, `compensates::string` (CK-2, CK-3) — spec edits, ruling-gated |
| `flow.md` §4.1 | one sentence: in a program, a feature package loaded through `[env]` resolves its verbs as the projected command defs (CK-3) |
| `flow.md` §4.23 `[runner]` | the optional `[store url=]` row and its `CXER4965` case (CK-3) |
| `xap_feature_distribution_market.md` §1.2 | the projection rule (CK-3) beside the contract table; §6.2 notes that `pkg:` loading of a feature also yields the projected defs |
| #728 | component 2 retitled to match; #747 "adapter instance" → pinned feature row; #732 unchanged (rung 4 of CK-1's table) |

## What stays open after this packet (named, not dodged)

1. Per-feature capability scoping inside one process — whether a feature's
   granted slice bounds `net` reach (#747). The prerequisite for co-hosting
   connectors; unverified in the tree.
2. Where `client_credentials` lands (inventory item 1).
3. `Retry-After` as a `[?retry]` opt or engine behavior (inventory item 2).
4. Pagination's vocabulary — four named styles or one declarative stop
   condition (inventory item 4) — now an attribute question on `[gateway]`.
5. The runner's `[store]` row when `[env]` loads a feature (CK-3's named
   consequence) — ruled here in shape, implemented with the runner.
