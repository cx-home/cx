## 12. The platform — the seams, the patterns, the runtimes

> **GENERATED CHAPTER.** Every section below §12.1 is projected from
> `spec/03-approved/platform/composition.md` §1-§3 and
> `spec/03-approved/platform/deployment-topology.md` §1-§4 by
> `scripts/gen_docs/primer_platform.cx`. `make primer-platform-check` fails
> the run when this text and those pages disagree, so what you read here is
> what those pages say — edit the pages, never this chapter.

Read this chapter before composing anything on the platform. It answers four
questions an adopter's agent otherwise guesses at: what an element's head
means, which module may use which (and which direction is refused), which
compositions exist (the set is CLOSED), and what changes when the same
composition is deployed across four runtimes instead of one.

`cx xap scaffold <pattern>` emits any of §12.5's patterns as a declaration
skeleton with an authoring TODO wherever the pattern fixes no value.

### 12.1 The three head shapes, before any of the rest

Every skeleton in this chapter is a document of ELEMENTS, and the head of an
element decides what it is. There are three head shapes and no fourth
(`core/code.md` §6.3, §8).

**Bare `[name …]` is data-element construction.** The head names an element
you are building, never a function to run — even when `name` happens to match
a built-in. `[first "a"]` constructs an element named `first`; the built-in
is `[$first "a"]`.

```cx
[step name="pull-contacts" needs="start"]
```

**`[$name …]` is the call form.** The `$` sigil is what makes a word head a
call: `$`-bound name in head position, applied to the positional arguments.
The sigil is declared, never inferred — a bare word head can never be a call.

```cx
[$strings:upper "acme"]
```

**`[?name …]` is a special form.** A directive: control flow, binding,
definition — `[?for …]`, `[?let …]`, `[?def …]`, `[?if …]`. Directives are a
closed, registered set.

```cx
[?for [in $c $contacts] [yield $c@email]]
```

(One footnote to the first shape: a closed set of reserved operator tokens —
`+ - * / %`, `= != < <= > >=`, `~`, `and or not`, `cast`, `union intersect
except` — is admitted BARE as an expression head, because a symbolic token is
never a valid data-element name. `[> $x 100]` is the comparison, not an
element named `>`.)

**This is why a flow's `[do …]` and a feature's `[intent [do …]]` are DATA.**
Neither is a call and neither runs where it is written: they are data elements
the flow runner (for `[do …]` in a step) or the agent surface (for the
`[intent]` a verb declares) hands to the platform, which resolves the verb,
decides it, and records the result. An agent that reads a `[do …]` as an
invocation has misread every pattern below.

### 12.2 Orthogonality — composition.md §1

**§1. Scope, and the orthogonality rule**

**Each module owns exactly one thing, dependencies point downward, and a seam is
DECLARED rather than reached for.** A module lives in the ring of its highest
verb and a Ring-1 module never imports a Ring-2 one
(`README.md` §1; `../stdlib/README.md` §1;
`../core/cx_partition.md` §10), which is the downward
direction stated structurally; within Ring 2 the same rule is stated seam by
seam in §2 below, where each module names what it USES of a neighbor and what it
must NOT do to it — the shape
`connector.md` §12 fixed and `flow.md` §6.1 adopted.
A dependency that is neither a ring edge nor a §2 row does not exist: a module
never reaches into another module's state, never re-implements what a neighbor
owns, and never requires a neighbor that does not require it back — `flow`
depends on features and no feature depends on `flow`
(`flow.md` §6, RULED: #728 CK-6), the connector kit owns the walk
while the protocol module owns the bytes (`connector.md` §1.1,
§3.9.1, I-13), `sync` owns the watermark while `sched` owns the cadence
(`sync.md` §2.6, §12), `audit` owns the record while `journal` owns
its durability (`audit.md` §1.1, §11), and a surface reads a
feature's readout without reaching past it
(`../xap/xap_feature_distribution_market.md`
§1.2, §6.3). The whole of §2 is that paragraph made checkable.

### 12.3 The seam table — composition.md §2

**§2. The seam table**

**§2.1. The declared seams**

One row per ordered pair. **Direction** is read as *the left module uses the
right module*; what crosses is what the left module may take, and the refusing
sentence is what the same specification forbids it in the same breath. Every row
is a quotation of a specification section, named in the `Cited` column; a row's
authority is that section, never this table.

**Carrier** says what carries the row when its two sides sit in different
runtimes (`deployment-topology.md` §3): `in-process`
is a seam whose two sides always share a runtime, so it has no cross-runtime
form; `XSP <profile> (<binding field>)` is a seam whose callee is a runtime of
its own in the distributed shape, naming the profile the session runs under and
the deployment-binding field where it is declared. A carrier is never
discovered and never inferred from a row: it is deployment data, and the seam
itself is unchanged by it. **Every row carries one** — an empty cell is a seam
whose deployment story nobody wrote down, and `check-composition-seams` refuses
it (§4).

| # | Direction | What crosses | The refusing sentence | Cited | Carrier |
|---|---|---|---|---|---|
| S-1 | `flow` → `connector` | a connector feature's VERBS as `[do …]` heads, resolved through the one resolver, and each verb's recorded result as record data | reach past a verb into a gateway, a cursor, a token, a budget window or an ingestion rung — none is addressable from a document | `flow.md` §6.1 | in-process — the runner resolves an act through its `[env …]` module tree |
| S-2 | `flow` → `sync` | nothing directly — a sync's verbs are named by a step like any other verbs, and its recorded result is record data | own a cadence, or restate a diff, a dedup key, a horizon or a reseed plan in the document | `flow.md` §6.1 | in-process — same resolver |
| S-3 | `flow` → `fabric` | intent bindings as one of the five binding kinds that START a run; `:peer` steps reaching non-CX systems through its adapters; its dead-letter precedent | invent a second delivery or durability story, and never carry the trigger INSIDE the document | `flow.md` §6.1, §4.24 | XSP XAP (the deployment's fabric URL) |
| S-4 | `flow` → surface (`ux`) | the approval widget for a `:principal` proposal, the inbox and claim surface, the operator console, the studio and the picture | render, or let an operator act on, a value the run record does not hold | `flow.md` §6.1 | XSP XAP (the host's serve URL) |
| S-5 | `flow` → `audit` | nothing of its own — a step's act carries whatever audit obligation its own definition declares, at the act's own effect point | write to `cx:audit`, or copy an act's audit record into the run record as a second story of the same event | `flow.md` §6.1 | in-process — the obligation is the act's own |
| S-6 | `flow` → `journal` | the home stream per run; transitions as entries; the run record as fold plus snapshots; locator triples on effects | — (the substrate is the journal's; a second durability story is refused at S-3) | `flow.md` §6 | XSP STORE (`[runner [journal url=]]`) |
| S-7 | `flow` → `authz` | the authority basis at start; `[bounds]` attenuation for agent steps; `approve`/`commit` for `:principal` proposals; guardian grants | contribute authority itself — the process calling `advance` is a courier and contributes NO authority to any step | `flow.md` §6, §4.5 | in-process — the session's compiled basis |
| S-8 | `flow` → `sched` | every `deadline=`, `every=` and rung `within=` as a durable timer whose callback is `advance` | act on a fired timer naming a construct that is no longer `:running`/`:pending` — the record decides | `flow.md` §6, §4.2 | in-process — the runner's own timers |
| S-9 | `connector` → `http` | `client`, `send`, `request` and the `[request]`/`[response]` shapes; the rule that a non-2xx is a value | build a second HTTP client; re-parse a header `http` parsed; read a status any way but through `http`'s accessors | `connector.md` §12 | in-process |
| S-10 | `connector` → `audit` | `record`, `emit`, `require` — one record per outbound call | write to `cx:audit` directly; the stream is reserved and `emit` is its one writer | `connector.md` §12, §4.4 | in-process |
| S-11 | `connector` → `journal` | the adapter stream ingested records land on, under the gateway's declared rung | invent a second durability story | `connector.md` §12 | XSP STORE (the binding's `[journal url=]`) |
| S-12 | `connector` → `authz` | the PEP decision, asked like any verb: ρ resolves it, the runtime admits the emit, and only then does `apply` run | be the decision point for whether a verb may be emitted | `connector.md` §12.1 | in-process |
| S-13 | `connector` → `live` | the closed rung atoms a gateway declares | invent a fifth rung | `connector.md` §12 | in-process |
| S-14 | `connector` → `sched` | nothing directly — the deployment schedules ingestion and token warming | own a cadence | `connector.md` §12 | in-process — nothing crosses |
| S-15 | `sync` → `connector` | `open`, `run`, `walk`, and the `[gateway]`/`[paginate]` declaration its `[capture]` is a child of; `classify`'s error value for a failed read | build a second walk, a second retry loop or a second credential story; re-parse a `[response]` the kit parsed | `sync.md` §12 | in-process |
| S-16 | `sync` → `store` | `put-doc`/`get-doc` for the watermark and the index; the content address for every dedup key | invent a second address; hold a document the journal owns | `sync.md` §12 | XSP STORE (the binding's `[store url=]`) |
| S-17 | `sync` → `journal` | `append` for every delta, on the feature's adapter stream under the gateway's declared rung | fold, snapshot, verify, prune or rewrite anything; invent a second durability story | `sync.md` §12 | XSP STORE (the binding's `[journal url=]`) |
| S-18 | `sync` → `audit` | `record`, `emit`, `require` — one record per capture run | write to `cx:audit` directly; emit per delta rather than per run | `sync.md` §12, §4.4 | in-process |
| S-19 | `sync` → `fabric` | the dead-letter stream a refused record lands on | build a second dead-letter queue | `sync.md` §12, §4.5 | XSP XAP (the deployment's fabric URL) |
| S-20 | `audit` → `journal` | the reserved stream `cx:audit`; retention, tamper-evidence and export are all the journal's | keep a second store, or prove more than the chain proves | `audit.md` §2.5, §3.2, §3.3, §11 | XSP STORE (the binding's `[journal url=]`) |
| S-21 | `sso` → `session`, `store`, `authz`, `journal`, `http`, `crypto` | the store seam and the pending, replay and link tables; the grant names as a session's authority basis; one `journal:append` per recorded decision; the request/response message model; every signature | decide anything or hold policy — this module decides nothing and holds no policy, and there is no metrics subsystem | `sso.md` §11 | in-process, except `store` and `journal` — XSP STORE (`[store url=]`) |
| S-22 | `sso` → `flow` | a rotation and a provisioning sequence are flow documents whose steps are this module's operator verbs | make a login a flow | `sso.md` §11 | in-process — a document, not a call |
| S-23 | `fabric` → `journal`, `store` | the durable plane IS the journal point served; consumer groups and cumulative offsets are store-persisted | invent anything below itself — fabric is the delivery layer | `../xap/fabric.md` §2, §6, §9; `fabric.md` | XSP STORE (`fabric.service.cx`'s mount) |
| S-24 | feature → `connector` | the kit: `apply` delegates to it, so a connector is a declaration plus two definitions | be a second kind of anything — there is no connector document and no fourth package kind | `connector.md` §1, §1.2 I-1, §13.2 | in-process — the kit runs inside the feature |
| S-25 | feature → `sync` | `[capture]` as a child of the feature's `[gateway]` — one source's incrementality, declared once | declare a schedule, a budget or an endpoint in the capture | `sync.md` §2.1 | in-process — `[capture]` is a child of the `[gateway]` |
| S-26 | surface → feature | `GET /surface/<feature>` calls the feature's `readout` over `$host`; `GET /stream` pushes on the readout's change digest | reach past the readout — the projection reads the feature's grammar and the deployment's data, and no materialized descriptor exists to drift | `../xap/xap_feature_distribution_market.md` §1.2, §6.3; `connector.md` §5.2 | in-process — the readout is called with `$host` |
| S-27 | `xap` host → feature | the `readout` / `apply` / `simulate` contract surface, keyed by the composed grammar's qualified verbs, each call taking the deployment context `$host` | boot a feature whose code entry is not at `<feature-name>.cx` — the host REFUSES TO ENABLE it rather than answering reads with an empty readout | `../xap/xap_feature_distribution_market.md` §1.2, §6.3 | in-process — the host boots the feature's code |
| S-28 | agent surface → feature verbs | the tool-descriptor projection: `name` is the qualified verb, `description` is the verb's `[summary]`, `input-schema` comes from the `[intent]` slots, `read-only` is `effect = observe` | let a verb with no `[summary]` reach an agent — `validate` reports `CXER6325` where the author is looking | `connector.md` §5.1; `../x/tools.md` §2–§3 | in-process — the projection is computed in the host |
| S-29 | `connector` → `http`, the SERVICE surface | mounting a gateway's DECLARED route on the deployment's `[?http-service]`, and reading the request the vendor pushed. S-9 is the client half — this is the inbound one `kind=webhook` needs | mount a route no `[gateway]` declared, serve one at an origin the feature chose, or bind a listener of its own — the listener, the address and the TLS are the deployment's, and a delivery on an unmounted route refuses `CXER6327` | `connector.md` §3.10.1, §3.10.6, §3.10.7 | in-process — the kit mounts a route on a service the deployment bound |
| S-30 | `connector` → `db_access` | the `[sql-db]` / `[redis-db]` handle its `open` answers as a `kind=db` gateway's connection, and its four SQL verbs as the bytes; one cursor-column query per page, with the backend handle bound through §4.2's chain | write SQL text into a `[call]`, an audit record or any persisted artifact (I-5); build a second connection pool, a second retry loop or a second isolation story | `connector.md` §3.8.1, §3.8.2, §3.8.4, §3.8.6; `../core/db_access.md` §3 | in-process — the kit calls the module that holds the handle |
| S-31 | `connector` → `graphql` | the GraphQL codec: a document parsed and emitted in its canonical form, the request envelope its declared variables are carried in, the response envelope a failure arrives inside and its three outcomes, an error's `extensions.code`, the schema reader introspection and the ingest both use, and the connection page the `connection` pagination style walks | open a socket, hold a handle, read a clock, classify a retry, decide a wait, or yield a partial page — every one of those is the kit's, once; and the kit for its part never re-parses a document the codec parsed (I-13) | `connector.md` §3.11.1, §3.11.2, §3.11.3, §3.11.9; `../stdlib/graphql.md` §9 | in-process — the kit calls the codec |

**§2.2. The refused directions**

A refused direction is a row of its own, because a direction nobody wrote down
is a direction every agent infers differently. **Check** says whether the
refusal is mechanically detectable in a specification's own sentences — the
`yes` rows are exactly the pair table of §4's step; a `no` row is a rule a
person reads and a reviewer holds. **Carrier** is the §2.1 column, and a refused
direction's carrier is `none`: a refusal holds in the same-process shape and in
the distributed one alike, so no carrier can make it legal
(`deployment-topology.md` §3).

| # | Refused direction | The refusing sentence | Check | Cited | Carrier |
|---|---|---|---|---|---|
| R-1 | `connector` → `flow` | Flow depends on features; a feature never depends on flow. A read-only connector feeding a dashboard must not require a workflow engine it never calls | **yes** | `connector.md` §12.3, §1.2 I-10 (RULED: CK-6) | none — refused in both shapes |
| R-2 | `sync` → `flow` | A sync runs on the deployment's or the runner's cadence with no run in existence; a feature's ingest never depends on flow | **yes** | `sync.md` §12.3, §1.2 I-10 (RULED: CK-6) | none — refused in both shapes |
| R-3 | feature → `flow` | `flow` is a CONSUMER of feature verbs; no feature — connector features included — lists `flow` in its `needs`, and none is required to | no | `flow.md` §6 (RULED: #728 CK-6) | none — refused in both shapes |
| R-4 | `audit` → `store` | `store`: **nothing** — reached only through journal | **yes** | `audit.md` §11 | none — refused in both shapes |
| R-5 | `connector` → `sched` | `sched`: nothing directly — the deployment schedules ingestion and token warming; the kit must not own a cadence | **yes** | `connector.md` §12 | none — refused in both shapes |
| R-6 | `sync` → `sched` | A capture declares no schedule: there is no `every=`, no `cron=` and no `interval=` attribute and there will not be one; an attribute naming a cadence refuses `CXER6416` | **yes** | `sync.md` §2.6, §2.1, §12 | none — refused in both shapes |
| R-7 | `connector` engine → a transport's bytes | The engine never sees a transport's bytes: the kind's own protocol module builds, sends and parses them | no | `connector.md` §1.1, §3.9.1 (I-13) | none — refused in both shapes |
| R-8 | `flow` → a module's state, through a transform step | A transform step performs no act, opens no connection, reads no store and holds no capability — only the run record | no | `flow.md` §4.4a (RULED: WF-42) | none — refused in both shapes |
| R-9 | `flow` → a feature's internals, as a mapping | Putting the MAPPING between two connectors' nouns inside either connector is refused: that is a transform step's pure definition, so a step can sit between two features without either learning the other exists | no | `flow.md` §6.1, §4.4a | none — refused in both shapes |
| R-10 | any module → `cx:audit` | The stream is reserved and `emit` is its one writer; a specification sentence that says "audit" with no row in the audit integration map is a defect in that specification | no | `audit.md` §2.5, §11 | none — refused in both shapes |
| R-11 | `audit` → the act it records | Emitting never changes the act; the record is what was decided, not the deciding | no | `audit.md` §6.5, §2.2 | none — refused in both shapes |
| R-12 | surface → a value the record does not hold | A surface READS the record, and a value it needs is recorded by a step | no | `flow.md` §6.1 | none — refused in both shapes |
| R-13 | library → feature | A library never `uses` a feature: code does not depend on grammar, and authority cannot be smuggled through the code plane | no | `../xap/xap_feature_distribution_market.md` §1.1 (N-DIST-2) | none — refused in both shapes |
| R-14 | feature → a co-tenant feature's bound host | Every invocation runs inside a resource-scoped `[deny net …]`; a feature reaching another's host refuses `CXER0271` naming it, and that scoped deny IS the isolation between co-tenant features | no | `../xap/xap_feature_distribution_market.md` §6.3 step 4 (RULED: CK-10, 1437-a) | none — refused in both shapes |
| R-15 | Ring 1 → Ring 2 | A Ring-1 module never imports one of these; nothing in the Ring-1 directory imports the Ring-2 one | no | `README.md` §1; `../stdlib/README.md` §1 (RULED: 1427-a) | none — refused in both shapes |

**Why R-15 is not mechanical, stated rather than left to be rediscovered.** The
two `[?lib 'cx-platform/…']` lines that stand in the Ring-1 tree today —
`../stdlib/README.md` §1 and
`../stdlib/http-client.md` — are a PROGRAM's imports
shown in an example, not a module's, and the second one is the worked case of a
program importing both halves. The refusal is about a module's import graph,
which a specification's prose does not carry; `ring-import-gate` reads the
import graph itself. A check that read those two lines as violations would cry
wolf on the two pages that state the rule.

### 12.4 The composition patterns — composition.md §3

**§3. The composition patterns**

The set is **closed**: a composition an adopter needs that is not one of the
seven below is a decision for the owner, not a variation to improvise. Each
pattern names the enterprise need it answers in one sentence, the modules it
uses, a declaration skeleton drawn from the specifications' own examples, the
§2 rows it crosses, and the reference example that grades it. **A pattern with
no reference example is a defect of this page**, and §3.8 is where those defects
are listed with the issue that owes each one (RULED: COMP-1).

**§3.1. Poll–transform–sink**

**The need.** An outside system is read on a cadence, its records are mapped
into another system's nouns, and the result is written to a sink — without
either system's declaration learning that the other exists.

**Modules.** `connector` (the walk), `flow` (the ordering and the transform
step), `journal` or a second connector (the sink).

```cx
[flow name="poll-transform-sink" stall-after=1d
  [args [since::string] [region::string]]
  [step name="pull-contacts"
        [do 'crm-rest/list-contacts' [updated-since $args/since]]]
  [step name="to-order-lines" needs="pull-contacts"
        [compute 'mapping/contacts-to-lines'
          [contacts $steps/pull-contacts/result/contact]
          [region $args/region]]]
  [step name="sink-lines" needs="to-order-lines"
        [do 'orders-db/insert-lines' [lines $steps/to-order-lines/result/line]]]]
```

**Seams crossed.** S-1 (the verbs), S-6 (the transitions), R-8 and R-9 (the
transform reaches no module's state and is where the mapping lives), R-1 (neither
feature names `flow`).

**Graded by.** No reference example — §3.8.

**§3.2. Approval with pivot and compensation**

**The need.** A sequence in which one step must be admitted by a person, one
step cannot be undone, and every step before the irreversible one is reversed
automatically when a later step fails.

**Modules.** `flow` (the ordering, the offer, the pivot), `authz` (the PEP that
admits the approval act), `journal` (the transitions and the compensation
entries), the surface (the approval widget and the inbox).

```cx
[flow name="approval-with-pivot" stall-after=1d
  [args [order::string] [amount::decimal]]
  [step name="approve-large" by=:principal to=role:finance
        when="$args[> $_/amount 10000]" deadline=1d
        [do 'orders-db/approve-order' [order $args/order] [amount $args/amount] [decision]]
        [escalate [notify to=role:finance-lead within=2h]
                  [to role:finance-lead within=4h]]]
  [step name="commit-order" needs="approve-large" pivot=true
        [do 'crm-rest/create-contact' [email $args/order] [name $args/order]]]]
```

Compensation is **not** written in the document: `[compensates]` lives on the
command definition, and a failure before the pivot reverses each `:done` step in
reverse document order (`flow.md` §4.8); a failure after the pivot is
`:incomplete` and is never compensated (`flow.md` §4.7).

**Seams crossed.** S-1, S-4, S-5, S-6, S-7; R-12 (the surface reads the record).

**Graded by.** `order-pipeline` — **#1472**
(`../../../reference/connectors/README.md`
§2.3, cases `order-pipeline-003-approval`, `-004-escalate`, `-006-compensation`,
`-007-pivot`).

**§3.3. Async bulk export**

**The need.** An outside system answers a large read by accepting a job, making
the caller wait, and serving a file — three verbs and an ordering, with no verb
that requires the ordering.

**Modules.** `connector` (the three verbs), `flow` (the ordering and the bounded
wait).

```cx
[flow name="async-bulk-export" stall-after=1d
  [args [tenant::string]]
  [step name="submit" [do 'acme/submit-export' [tenant $args/tenant]]]
  [until name="await-export" needs="submit" when="$steps/poll-export/result/@ready"
         attempts=20 every=1m
    [step name="poll-export"
          [do 'acme/poll-export' [job $steps/submit/result/job]]]]
  [step name="download" needs="await-export"
        [do 'acme/download-export' [job $steps/submit/result/job]]]]
```

This is the case that looks like a dependency on `flow` and is not: the flow
supplies the ordering, the retry ladder, the approval and the compensation, and
an adopter without `flow` orders the same three verbs from a script or a surface
(`connector.md` §12.3).

**Seams crossed.** S-1, S-6, S-10; R-1 (the three verbs stand alone).

**Graded by.** No reference example — §3.8.

**§3.4. Inbound webhook**

**The need.** An outside system pushes; the deployment verifies the signature,
refuses a replay, answers back-pressure with a `429` and a `Retry-After`, and
records each accepted delivery exactly once.

**Modules.** `connector` (the `kind=webhook` adapter, the credential chain run
in the verify direction, the budget arithmetic run in reverse), `http` (the
mount), `journal` (the landing), `audit` (the record).

```cx
[source
 [gateway name=hook kind=webhook priority=1 signing=hmac-sha256-header rung=snapshot-diff
   doc='the inbound route; the deployment mounts it and binds the verification key'
   [route path='/hooks/orders' method=post]
   [verify header='X-Signature' over=raw-body replay-window=5m
           delivery-id='/delivery_id' dedup=content-address]]]
```

**Seams crossed.** S-9, S-10, S-11, S-12, S-24; R-7 (the bytes are `http`'s).

**Graded by.** `inbound-webhook` — **#1468**
(`../../../reference/connectors/README.md`
§2.7).

**§3.5. Fan-out over a bus**

**The need.** One committed act is delivered to consumers that the producer does
not name, durably, with each consumer group keeping its own position.

**Modules.** `fabric` (the delivery layer, both planes), `connector` (the
`kind=bus` adapter), `flow` (the publish and the confirmation), `journal` (the
durable plane).

```cx
[source
 [gateway name=order-events kind=bus priority=1 auth=none rung=snapshot-diff
   doc='the deployment binds an embedded fabric in one environment and the bridge in another']]
```

```cx
[step name="publish-order" needs="approve-large"
      [do 'order-events/publish' [order $args/order] [tenant $args/tenant]]]
```

The gateway declares only the core attributes — `name=`, `kind=`, `priority=`,
`auth=`, `rung=`; everything kind-specific is the adapter's and is declared by
it, never hard-coded in the engine (RULED: 1430-d,
`connector.md` §3.9.3).

**Seams crossed.** S-3, S-11, S-23, S-24; R-7.

**Graded by.** `order-pipeline` — **#1472**
(`../../../reference/connectors/README.md`
§2.3, case `order-pipeline-005-bus-round-trip`), which grades one publish and
one consume over `kind=bus`. Fan-out across more than one consumer group is
graded by `fabric`'s own conformance corpus and by no reference example
(`fabric.md`; `../xap/fabric.md` §9).

**§3.6. Incremental sync into a store**

**The need.** A source is read repeatedly without re-reading what has not
changed, resumably across a restart, with each record landing exactly once.

**Modules.** `sync` (the cursor, the watermark, the dedup index), `connector`
(the walk beneath it), `store` (the watermark and the index), `journal` (the
deltas), `live` (the view over them).

```cx
[source
 [gateway name=orders-db kind=db priority=1 auth=basic rung=snapshot-diff
   [paginate style=cursor max-pages=50 path='/id' param=cursor]
   [capture mode=polling-diff kind=instant key='/id' version='/updated_at'
            since-param=since overlap=5m deletes=unobservable]]]
```

**Seams crossed.** S-13, S-15, S-16, S-17, S-18, S-25; R-2 and R-6 (no run and
no cadence in the declaration).

**Graded by.** `orders-db` — **#1467**
(`../../../reference/connectors/README.md`
§2.2, §1.2's `sync` column).

**§3.7. Agent surface over verbs**

**The need.** An agent is given a system's verbs as described tools, decides
what to do, and never sees or argues with how it is done.

**Modules.** the feature's grammar (the verbs), `x/tools` (the projection),
`authz` (the PEP at the effect point), the `xap` host (the serving surface).

```cx
[verbs
 [verb name=list-contacts effect=observe via=acme-api
  [summary 'List the contacts the tenant can see.']
  [intent [do :list-contacts [updated-since]]]
  [reads contact]]]
```

The agent sees a tool with a schema and never a gateway, a cursor, a token or a
`Retry-After`; every annotation it sees is a hint, and enforcement is the PEP's
and the effect point's (`connector.md` §5.1, §5.3).

**Seams crossed.** S-12, S-26, S-27, S-28; R-14 (an agent cannot reach a host
the deployment did not bind).

**Graded by.** `crm-rest` — **#1466**
(`../../../reference/connectors/README.md`
§1.2's agent-surface column: six verbs project as six tool descriptors, and a
verb without a `[summary]` refuses `CXER6325` before an agent sees it).

**§3.8. Patterns with no reference example yet**

Each row is a defect of this page under COMP-1, recorded rather than hidden.

| Pattern | What is ungraded | The issue that owes it |
|---|---|---|
| §3.1 poll–transform–sink | The poll and the sink are graded by **#1467** and **#1472**; the TRANSFORM is graded by no reference example — the `order-pipeline` document carries no `[compute …]` step, and the transform step's own conformance cases are advisory until the runner code lands (`flow.md` §4.4a, RULED: WF-42) | **#1472** — the one example whose document already orders two features' verbs, and so the one that can carry the mapping between them |
| §3.3 async bulk export | The pattern named by `connector.md` §12.3 as the case that looks like a dependency on `flow` is demonstrated by none of the seven reference examples, and is not among the coverage gaps that document states (`../../../reference/connectors/README.md` §1.4) | **none** — no issue owes it today |

**§3.9. The scaffold**

`cx xap scaffold <pattern>` emits one pattern of §3 as a DECLARATION SKELETON
(RULED: COMP-1). The contract is four sentences.

**Input** is a pattern name and nothing else: one member of the closed set
named by §3.1-§3.7, taken as a slug. **Output** is the declaration documents
that pattern states — the flow document, the feature and gateway declarations,
and the deployment binding — plus a README carrying the pattern's need, its
modules, the §2 rows it crosses, the reference example that grades it, and the
list below. Every emitted document parses.

**The TODO rule.** What the pattern STATES becomes a declaration; what it does
not state becomes an authoring TODO, never a guess — the discipline
`connector.md` §6.3 fixes for every skeleton the toolchain
emits (RULED: 1430-g), applied here to a composition instead of to an OpenAPI
document. The feature names, the thresholds, the routes, the nouns, the verbs,
every idempotency claim and every deployment fact are TODOs, and each says why
it is one. The command is pure — a pattern name in, a skeleton out, with no
network, no clock and nothing read from the tree.

**The refusal.** A name outside the closed set is refused with the seven
named, never with the nearest one: a composition an adopter needs that is not
one of the seven is a decision for the owner, not a variation to improvise,
and a scaffold that answered with something near it would hide that decision
rather than raise it. The skeleton does not run as generated, and says so —
`cx xap init` scaffolds a project that composes unedited because a project has
a working shape, and a composition pattern is a shape.

### 12.5 The four runtimes — deployment-topology.md §1

**§1. The runtimes**

Four daemons serve the platform, each with its own configuration document, its
own XSP profile and its own journal. `cx --help` names three of them as
subcommands — `store-serve`, `fabric-serve` and `flow serve`; the fourth is the
XAP host a deployment boots through `[$xap:serve]`
(`../xap/xap.md` §9, §25.2).

| Runtime | Daemon | XSP profile | Binding fields | What it journals |
|---|---|---|---|---|
| **store** | `cx store-serve --config <path>` | the **STORE** profile — the store's network API IS the XSP store profile, and `cx-store://host:port/store-name/` dials the daemon's `[xsp]` listener over TLS (`cx-store+xsp://` is the cleartext sibling) | the daemon's `[xsp]` section: the listener, `[grants [grant did= caps= over=]…]`, `[limits …]`, `[revocations journal=]`, `[peers [peer url=]]`; the client side carries no userinfo — identity rides the open-opts `xsp-did` + `xsp-seed-env`, and the seed always names an env var | the fixed `store:log` lineage (#708): the docs plane plus one stream per named wire ref — the one log the local porcelain and the wire subscription read |
| **fabric** | `cx fabric-serve --config <path>` | the **XAP** profile — fabric's verbs are that profile's vocabulary, spoken as raw XSP frames over tcp/tls; a client dials `[$fabric:open "xsp://…"]` and attaches under XSP-AUTH | the attr-exact-validated `fabric.service.cx`: `[bind]`, optional `[health]`, optional `[tls]`, `[identity did= seed-env=]`, `[policy]` (mutual \| floor), `[limits pending-window= liveness-ms= request-timeout-ms=]`, `[fabrics]` (mounts keyed by tenant), `[principals]`/`[anonymous]` carrying the grants | nothing of its own below itself: the durable plane IS the journal point served, and consumer groups and cumulative offsets are store-persisted |
| **the flow runner** | `cx flow serve RUNNER.cx` | the **XAP** profile plus the `flow` semantic-feature token — a delegated intent crosses as the initiator's runner emitting the counterparty's act through its own authenticated XSP session, answered by a signed `step-ack` | the `[runner]` document: `[journal url=]`, `[docs url=]` (a Tier-1 `start=` address is fetched and verified here), `[env …]` (the resolver's module tree), `[store url=]`, `[ingress bind=]` (never a bare port), the `[on kind= …]` rows of §4.24's one vocabulary, and `[courier every=]` | one home stream per run: transitions as entries, the run record as fold plus snapshots, locator triples on effects |
| **the XAP host** | `[$xap:serve URL {runtime: …}]`, bootstrapped onto `[?http-service]` / `[$http:serve]` — xap opens no socket of its own | the **XAP** profile over the v1 **web binding**: SSE server→client, POST client→server; raw TCP/TLS is buildable and the WebSocket binding is deferred | the deployment document's `[on …]` rows for the kinds this face serves, the runtime's registered components and surfaces, and the session/attribution posture a bound runtime refuses to boot without | the deployment's fold — the journal fold IS the state, which is why resume is application-anchored and transport-stateless |

**Cited:** `store.md` §6.4 and its `wire` axis row;
`../xap/xsp_store_profile.md` §6.1 (the `[xsp
[grants …]]` section); `../xap/fabric.md` §13, §13.1, §19.6,
and §2/§6/§9 for the durable plane;
`flow.md` §4.23, §4.24 and §4.12b; `../xap/xsp.md`
§4, §4.1, §5.3 and §6's profile registry; `../xap/xap.md` §9,
§24 and §25.2.

**Inside the XAP host, and inside it only.** Features run in the host, and the
connector engine and the sync contract run inside a feature: the host calls a
feature's `readout` / `apply` / `simulate` with the deployment context `$host`,
`apply` delegates to the kit, and a `[capture]` is a child of the feature's
`[gateway]` (`composition.md` S-24, S-25, S-27). Neither the
engine nor the sync contract is a daemon, and neither is reachable across a
runtime boundary except as the feature's verbs.

**The fifth process that is not a runtime.** `cx flow run` from a checkout is a
runner with no liveness guarantee and no bindings — the invocation IS the
`start` (`flow.md` §4.24's runner table). It is named here so that
"the flow runner" in this page always means the daemon.

### 12.6 The two shapes, and a worked binding — deployment-topology.md §2

**§2. The two shapes, as equals**

A deployment runs the four runtimes in one process or in four, and the
declarations are IDENTICAL in both: the same feature documents, the same flow
document, the same seam rows. **Only the deployment binding changes.**

| | same-process shape | distributed shape |
|---|---|---|
| store | opened in-process at a `mem://` or `file://` URL — the `embedded` deployment axis, where the substrate is named in the URI | `cx store-serve`, dialed at `cx-store://host:port/store-name/` — the `service` deployment axis, where the substrate hides inside the daemon |
| fabric | opened in-process: durable streams over the process's own journal/store handles, transient streams process-local — no daemon, no network | `cx fabric-serve` alongside store-serve, dialed at `xsp://host:port`, MAY point at the same store its journal rides |
| the flow runner | `cx flow run` over the checkout's journal, or the runner embedded in the XAP host | `cx flow serve RUNNER.cx`, its own journal and ingress |
| the XAP host | the same `[$xap:serve]` process that holds everything above | its own process, reaching the other three as a client |

**Cited:** `store.md`'s `deployment` axis (`embedded` · `service`);
`../xap/fabric.md` §13's embedded and served tiers;
`flow.md` §4.24 — "a flow moves between them without an edit, and
what changes is where the runner runs, not what the flow says".

**§2.1. A worked binding — `order-pipeline` in both shapes**

`../../../reference/connectors/README.md`
§2.3 states the example's two bindings in words: the graded scenario boots
`crm-rest`'s mock and `orders-db`'s sqlite file plus a `kind=bus` gateway bound
to an **embedded fabric over a `mem://` journal**, and the production deployment
binds the NATS bridge instead. Written in the binding block that document
proposes (`[deployment [runtime [connectors [connector feature= [gateway …]
[tenant …]]]]]`, §2.1 there), the same-process shape is:

```cx
[deployment name=order-pipeline-scenario
 [runtime
  [journal url='mem://order-pipeline/acts' stream=acts]
  [store url='mem://order-pipeline/store']
  [connectors
   [connector feature=crm-rest
     [gateway name=crm-api base-url='http://127.0.0.1:8801'
       [retry max=4 delay=250ms backoff=exponential jitter=full]
       [timeout per-attempt=10s]]
     [tenant name=tenant-north
       [credential gateway=crm-api handle='secret:crm/sandbox/north-client']]]
   [connector feature=orders-db
     [gateway name=order-store backend='sql-db:orders-sandbox']
     [tenant name=tenant-north
       [credential gateway=order-store handle='secret:orders/sandbox/north']]]
   [connector feature=order-events
     [gateway name=order-bus fabric='mem://order-pipeline/bus']
     [tenant name=tenant-north
       [credential gateway=order-bus handle='secret:bus/sandbox/north']]]]]]
```

and the distributed shape differs in exactly the deployment facts
`connector.md` §4.6 names — a different WHERE per gateway, a
different handle per tenant — plus the three carriers this page adds:

```cx
[deployment name=order-pipeline-production
 [runtime
  [journal url='cx-store://store.example.test:8443/order-pipeline/' stream=acts]
  [store url='cx-store://store.example.test:8443/order-pipeline/'
         xsp-did='did:key:z6Mk…' xsp-seed-env=ORDER_PIPELINE_SEED]
  [connectors
   [connector feature=crm-rest
     [gateway name=crm-api base-url='https://crm.example.test'
       [retry max=6 delay=500ms backoff=exponential jitter=decorrelated]
       [timeout per-attempt=20s]]
     [tenant name=tenant-north
       [credential gateway=crm-api handle='secret:crm/production/north-client']]]
   [connector feature=orders-db
     [gateway name=order-store backend='sql-db:orders-production']
     [tenant name=tenant-north
       [credential gateway=order-store handle='secret:orders/production/north']]]
   [connector feature=order-events
     [gateway name=order-bus fabric='xsp://fabric.example.test:8450']
     [tenant name=tenant-north
       [credential gateway=order-bus handle='secret:bus/production/north']]]]]]
```

The flow document, the three feature documents and every `[gateway]`
DECLARATION are byte-identical between the two; what moved is a URL, a handle
and a carrier. `xsp-did=` and `xsp-seed-env=` are the store client's open-opts
under their own names (`store.md` §6.4), written where a deployment
writes its other facts: the seed names an env var rather than a value, as §6.4
requires and as `connector.md` §4.6's "a handle, never a value"
requires of every credential.

**The spelling is the reference document's proposal, not a specification's.**
`../../../reference/connectors/README.md`
§8 item 1 records that `connector.md` §4.6 says WHAT a binding carries and no
specification says how it is spelled; the blocks above inherit that proposal
unchanged. The per-kind WHERE is likewise the ADAPTER's field and not this
page's — §4.6 states `base-url=` for `kind=http` and `kind=soap`, a backend
handle for `kind=db` and, for an operator's own kind, whatever its adapter
declared — so `backend=` on the `kind=db` gateway and the fabric URL on the
`kind=bus` gateway are written above under that rule, at the names the adapter
owns. When §4.6 fixes the spelling, this section follows it.

### 12.7 The carrier rule — deployment-topology.md §3

**§3. The carrier rule**

**Every cross-runtime seam between CX components is an XSP session under the
callee component's profile, declared in the deployment binding, never
discovered.** One carrier, stated once:

1. **The profile is the callee's**, from
   `../xap/xsp.md` §6's registry — the STORE profile toward a
   store, the XAP profile toward fabric, the flow runner and the XAP host. The
   generic frame layer never grows semantics; growth is only a token.
2. **The session is authenticated at attach.** XSP-AUTH is mutual,
   channel-bound and transcript-signed
   (`../xap/xap_identity_model.md` §4), and
   reconnect re-proves identity — resume never bypasses it.
3. **The address is bound, never discovered.** A URL, a DID and a seed env var
   are deployment data written in the binding (§2.1); no runtime learns a
   peer's address from a registry, a broadcast or another runtime's journal.
4. **In-process is the other carrier, and it is the same seam.** When both
   sides share a process the seam is an ordinary call across a `[?lib]` surface
   and no frame is encoded. The seam row does not change; its `Carrier` column
   does (§4 of `composition.md`, the `Carrier` column of its
   §2.1 and §2.2).

**Integration edges, named as such.** Two wires cross a runtime boundary and are
NOT this rule's subject, because the party on the far side is not a CX
component:

| Edge | What it is | Cited |
|---|---|---|
| `grpc` (store) | the gRPC edge adapter — `cx-store+grpc(s)://`, re-based onto the profile pipeline with per-call XSP-AUTH — for gRPC-speaking environments. The CX-to-CX wire is `cx-store://` | `store.md` §6.4 and its `wire` axis row |
| the NATS bridge (fabric) | an ordinary edge client on fabric's remote tier (`tooling/cxfabric/nats-bridge.cx`), the legacy-migration seam — a bridge to a non-CX broker, not a seam between two CX runtimes | `../xap/fabric.md` §14, §18 (#547) |

A third wire is an edge of the same kind in the other direction: the webhook
adapter's HTTP/SSE reach (`../xap/fabric.md` §13's first
adapter). An edge carries no CX-to-CX seam and never appears in a seam row's
`Carrier` column.

### 12.8 What differs across a runtime boundary — deployment-topology.md §4

**§4. What differs from in-process — three rules a pattern may rely on**

A pattern composed in one process and deployed across four is the same pattern;
these three rules are everything that changes, and a pattern may rely on them.

**§4.1. Identity crosses as signed claims, never as an in-memory `$host`**

In one process a feature call carries the deployment context `$host`
(`composition.md` S-27). Across a runtime boundary there is no
`$host` to carry: the session principal proved key control in the XSP-AUTH
handshake, and authority reaches the session as verifiable credentials
presented on the control stream — a presented VC's subject MUST be the session
principal, and there are no bearer credentials in this model
(`../xap/xap_identity_model.md` §4, §5.1). The
daemon's own local grants are the `[xsp [grants [grant did= caps= over=]…]]`
section, and each matching grant compiles at attach into an ordinary
`[delegation …]` in the session's authority basis, decided by the one decision
function (`../xap/xsp_store_profile.md` §6.1;
`../xap/xap_identity_model.md` §5.3). A
configuration WITH a grants section is deny-by-default.

**What this means for a pattern.** A cross-runtime step's authority is the
callee's compiled basis — local grants plus that session's verified credentials,
intersected with the envelopes — and never the caller's memory. A pattern that
would pass an in-memory context across a seam has no distributed form; a pattern
that names a principal and a capability has the same form in both shapes.

**§4.2. A session can drop mid-act, so a cross-runtime step is at-least-once**

`../xap/xsp.md` §5 is normative and applies to every profile
unchanged: `ping`/`pong` liveness with the server's advertised window (§5.1);
receiver-driven credit windows, where the sender at zero credit MUST stop
pushing (§5.2); and reconnect-resume that is application-anchored and
transport-stateless — the transport buffers nothing across connections, the
durable log is the resume source, and the resume token is the durable event's
journal sequence (§5.3).

Two consequences a pattern may rely on:

- **A cross-runtime step is at-least-once and completes on an acknowledgment.**
  A delegated intent is answered by a signed `step-ack` naming the
  counterparty's effect locator and the initiator's locator it acted on
  (`flow.md` §4.12b); the run id in it is a correlation key and never
  an authority input.
- **Every act a cross-runtime step emits is idempotent, or is recorded as not.**
  `order-pipeline`'s bounded re-attempt (`attempts=`/`every=`) is admitted only
  because the consume verb declares `[idempotent]`, and the one step that cannot
  be retried carries `pivot=true`
  (`../../../reference/connectors/README.md`
  §2.3). A step that reaches no module's state has nothing to retry: a transform
  step performs no act, opens no connection, reads no store and holds no
  capability — only the run record (`flow.md` §4.4a, RULED: WF-42,
  CK-4b's recorded-intent shape).

**§4.3. Each runtime keeps its own journal, and no seam reads another's**

A runtime's journal is its own: the store's `store:log` lineage, fabric's served
durable plane, the runner's home stream per run, the host's fold (§1). Across a
boundary, each party's journal holds its half — "there is no shared record and
no shared engine", and disputes settle by comparing the two chains at the
locators the acknowledgments name (`flow.md` §4.12b). **A
cross-runtime seam exchanges records — acts, acknowledgments, effects — and
never shared state.** A pattern that reads a peer's journal to learn what
happened has no distributed form; a pattern that reads an acknowledgment does.