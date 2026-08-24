# XAP quickstart — from a deployment doc to a running experience

A **XAP** is the unit you architect software in: **features** (each a grammar
of verbs/nouns/rules born from requirements) compose into **surfaces**
materialized across media, with governance built in. The implementation stays
thin — pure data plus the stdlib primitives (journal, bus, authz, session) and
the HTTP serve plane; there is no framework to adopt. Normative model: the XAP
spec (`spec/03-approved/xap/xap.md`); positioning and process model: the XAP
architecture working notes (`spec/02-working/xap_architecture.md`).

## The three authored layers

Per the XAP authoring process spec, a XAP is authored as three `.cxd`
documents, each validated by a `.cxs` schema:

| Layer | File | Captures |
|---|---|---|
| feature | `features/<f>/<f>.feature.cxd` | requirements → grammar (verbs · nouns · rules), frames/keys, governance, source stack |
| xap | `xap.cxd` | enabled features (hash-pinned), principals/roles, agents, sources, deployment, transport |
| surface | `surfaces/<s>.surface.cxd` | media + panels + per-medium materialization — *derived*, never redeclares intents |

A client is a **fourth, separate project** (invariant N-CLIENT-2 in the XAP
spec: a XAP never embeds its renderer) — see [clients and views](client-and-views.md).

Validation is real tooling, not convention (verified):

```sh
cx validate features/own-ship/own-ship.feature.cxd --schema=schemas/feature.cxs
cx validate xap.cxd --schema=schemas/xap.cxs
```

Schemas today live as local copies in the consuming project (its `schemas/` dir,
drafts canonical in `spec/03-approved/xap/xap_schemas/`); shipping them
physically in the toolchain is **still open** (the authoring process spec,
open/next section). The scaffolder is wired: `cx xap init NAME [--client]`
emits a composing project, and `--client` adds a sibling client that RUNS as
generated — generic table views derived from the surface's `shows`
declarations, a floor to replace with your own views (RULED: ATC-2).

## Composition — one grammar, gated

Enabled features compose into **one grammar**; conflicts are values, caught at
compose time (the W-gate of the grammar composition spec), never at runtime by
surprise. Bare terms resolve through ρ; ambiguity is an error carrying
candidates, never a guess. Verified:

```cx
[?lib 'cx-xap' :as xap]
[?let [= $chart
  [feature name=chart
   [nouns [noun name=viewport singular=true [field name=center type=geo-point]]]
   [verbs [verb name=highlight effect=arrange [intent [do :highlight]] [reads viewport]]]
   [requirements [requirement kind=functional as=user traces=highlight
     [want 'to mark a spot'] [so 'I can find it']]]]]
 [= $strikes
 [feature name=strikes
  [nouns [noun name=strike [field name=pos type=geo-point] [field name=at type=instant]]]
  [verbs [verb name=list-strikes effect=observe [intent [do :list-strikes]] [reads strike]]]
  [requirements [requirement kind=functional as=user traces=list-strikes
    [want 'to see strikes'] [so 'I avoid them']]]]]
 [= $g [$xap:compose $chart $strikes]]
 ([$count $g//verb], [$xap:resolve $g "highlight" {}])]
# → (2, 'chart/highlight')
```

`[$xap:compose-report]` is the never-raising tooling face;
`[$xap:grammar-hash]` gives the Tier-1 hash of the composed grammar — two
deployments with the same pins have bit-identical grammars (the
reproducibility section of the feature distribution & market spec).

## The deployment host — a XAP server is data plus adapters

`[$xap:host XAP-DOC OPTS]` boots a complete XAP from its deployment document:
acquire pinned packages → verify → compose (W-gate at load) → translate
governance into runtime dials → load each feature's contract module → serve
the standard surface (`GET /grammar`, `/features`, `/surface/<f>`,
`POST /intent`, `GET /stream`). A XAP with no custom transport is **zero
server code**. Deployment-specific pieces (extra routes, ingest workers, sim
cadence) register as adapters via OPTS — they never fork the host. See the
deployment-host section of the feature distribution & market spec; the live
consumer is `reference/shop-web-client/serve.cx`.

```sh
cd <your-xap-project>
make run     # the XAP on :9001, foreground (its ingest adapter by default)
make dev     # XAP + web client + browser; Ctrl-C stops both
make check   # the drift gate — specs ⇄ impl, fails on drift
```

## Process model — the port is the only mutex

Per the deployment process model section of the XAP architecture working
notes:

- **Bind failure is fatal to the whole process** — the deployment entry uses
  `[$xap:host …]!` so a XAP that cannot serve never half-runs its ingest
  workers. At most one instance per port, arbitrated by the kernel.
- **Collisions fail fast; replacement is explicit.** A launcher finding the
  port taken fails loudly naming the stop/restart verb; `stop` kills only
  processes it can verify as its own (port + command line), never a foreign
  owner.
- **No bespoke supervision.** Dev and crewed operation run unsupervised — a
  crash is a bug to root-cause, not respawn over. Unattended operation uses
  the OS supervisor (launchd/systemd). Processes exit cleanly on SIGTERM.
- **Serving model:** reactors own sockets, a bounded executor pool runs
  handlers; overflow answers 503 — a blocking handler can never freeze the
  HTTP plane (the serving execution model section of the same notes; shipped
  in v0.13.0).

## Capabilities and grants

Two distinct layers, both deny-by-default:

- **Host capabilities** (the security spec): `cx` grants `read`/`write`/`net`/
  `env`/… per invocation; an ungranted effect raises `CXER0271` naming the
  exact flag to add. The reference-app Makefile shows least-privilege grants per
  target.
- **XAP authority** (the trust-model part of the XAP spec): authority
  originates only from principals; every intent passes the one PEP; grants
  are per-verb, scoped, conditioned; the dial moves *who drives*, never *what
  is permitted*. Identity is DID-first (`did:key` offline — right for
  disconnected deployments), delegation is a Verifiable Credential.

## Sessions

A session is a `(principal, tenant)` **attachment**, tmux-style: the server
owns session state, clients attach/detach/mirror-attach, the session survives
client death. Authoritative state is the journal fold, never the session.
See the session & load-balancing section of the XAP architecture working
notes and the session module spec. The multi-tenant gateway/worker topology
is design-frozen, **implementation incremental** — what runs today is the
single in-process runtime a long-lived deployment uses.

## Next

- [Authoring features](features-authoring.md) — write the feature layer.
- [Consuming features](features-consuming.md) — pins and the code plane.
- [Clients and views](client-and-views.md) — materialize the surface.
