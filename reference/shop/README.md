# `shop` — the in-family XAP reference application

The successor to the external reference XAP that validated the authoring
process before it became an independent project (#726). It is deliberately
small: a shop with orders, shipments, and the delay alerts that live between
them. Small enough to read in one sitting, complete enough that every claim
the XAP specs make about composition is demonstrated on it rather than
described.

## Try it

Everything below runs from the repo root against a built `cx`.

```bash
# 1. the compose gate + rho, including the deliberate ambiguity
cx --allow-read reference/shop/compose.cx

# 2. the committed cascade: PEP -> journal -> bus, state as a fold,
#    the dial admitting and a revoke refusing again
cx --allow-read --allow-write reference/shop/cascade.cx

# 3. the surface derivation check (a toolchain command since #846;
#    point it at a broken copy to watch it refuse)
cx xap check-surface reference/shop

# 4. seal / sign / publish / install through the distribution engine
CX_SHOP_REG=/tmp/shop-reg cx --allow-read --allow-write --allow-env \
  --allow-random reference/shop/package.cx

# 5. the web client (separate project)
CX_SHOP_PORT=8770 cx --allow-read --allow-write --allow-env \
  --allow-net=127.0.0.1:8770 reference/shop-web-client/serve.cx

# 6. scaffold a NEW project from this layout — it composes unedited
cx xap init myshop --client && cx --allow-read myshop/compose.cx
```

**On (5), the browser.** htmx 1.9.10 is **vendored** at
`shell/static/htmx.min.js` (source and sha256 in `static/PROVENANCE.md`), so
the page swaps with no network at all. Verified in a real browser against
this build: clicking *Place order* leaves a planted `window` marker intact
and `performance.getEntriesByType('navigation').length` at 1 — no page
reload — while the order list gains the new record and the shipment pane is
untouched. Clicking *Dispatch* swaps that pane alone, on the same page load.

Everything the server renders is also testable head-lessly:

```bash
curl localhost:8770/                     # the shell, mounts spliced with folded state
curl localhost:8770/surface              # the same surface as CX — agent parity
curl -X POST -d "customer=lin" localhost:8770/intent/place-order
curl -o /dev/null -w '%{http_code}\n' -X POST localhost:8770/intent/teleport   # 403
```

htmx is the documented default for a CX web client ("minimal-JS-by-exception",
`xap_authoring_process.md` §3.1) and the engine emits `hx-post` / `hx-target`
/ `hx-swap` **natively** — so a served XAP produces htmx markup whether the
client asks for it or not. The shipped demo and `cx xap init --client` use
the CDN tag instead, since a generated project has no vendored copy to point
at; this reference vendors it so the version under test is pinned by hash.

## The three authored layers

| File | Layer | What it does |
|---|---|---|
| `orders.feature.cxd` | base feature | orders and their lines; registers the `order-id` key and the `time` frame |
| `shipments.feature.cxd` | base feature | dispatches against orders; registers onto the **same** key, same type |
| `delayed-shipment.feature.cxd` | **composite** | joins the two bases; derives an alert noun that exists in neither |
| `shop.xap.cxd` | xap | enables the three, names the principals and the agent, sets the dial |
| `shop.surface.cxd` | surface | binds the already-declared verbs to screen + audio |

Each validates against its schema in `spec/03-approved/xap/xap_schemas/`:

```bash
cx validate --schema=spec/03-approved/xap/xap_schemas/feature.cxs reference/shop/orders.feature.cxd
```

## What it demonstrates, and where to look

**A composite is a feature nobody authored the data for.** `delay-alert`
is not in `orders` and not in `shipments` — a delay is a *relationship*
between them, so it can only live above both. The console's delay queue
shows it: three orders go in, and exactly one comes out —

```
ORDER BOOK          SHIPMENT BOARD        DELAY QUEUE
o-1 — ada           s-1 → o-1 (acme)      o-1 — ada promised 2026-08-01
o-2 — grace         s-3 → o-3 (acme)
o-3 — linus
```

`o-2` is promised in 2099; `o-3` delivered. Only `o-1` is past its promise
with a shipment that never arrived.

**`[from …]` is checked, but it is still not computed — know who computes it.**
As of #840 the gate reads `[from 'orders/order' 'shipments/shipment']` and W5
requires each qualified noun reference to resolve in the composed grammar, so
those names are load-bearing like `uses` and `constituents`. What #840
deliberately did NOT settle is the join: no engine evaluates it, and a
component's view is handed only its OWN state slice, so a composite's derived
noun still has no producer. `detect.cx` is that producer — the same join, in
ordinary CX, over the two bases' folded state, recorded through
`delayed-shipment/raise-alert`. That file and that verb stay until a join
surface is designed and ruled. So the gate now checks the composite's wiring
AND its declared sources; it still does not check or compute the join
itself.

**Features stay independent, and the gate enforces it.** "A shipment can
only be dispatched for an order that was placed" is true, and it may **not**
be written in `shipments.feature.cxd` — that would reach outside its own
grammar and mean `shipments` could never be enabled alone. W4 refuses it.
The rule lives on the composite, which declares `uses`. Both files carry the
explanation, and `test_reference_app_base_feature_may_not_reach_across`
pins that the explanation is true rather than folklore.

**Ambiguity is a value, not a guess.** `orders` and `shipments` both define
a bare `highlight`. That is legal — qualified names keep them apart — and it
is the point: with both enabled, `[do highlight]` yields

```
[err code=cx-err:CXER4871 term=highlight
     candidates='orders/highlight shipments/highlight']
```

which the composer must turn into a prompt. A client may not auto-pick.

**Enabling a feature never changes what an old sentence means.** The same
pair is the N-COMPOSE-1 witness: with `orders` alone, `highlight` resolves
to `orders/highlight`; adding `shipments` may only ever turn that into an
ambiguity that *still lists* `orders/highlight`. It may never quietly become
`shipments/highlight`.

**A composite cannot launder authority.** `delayed-shipment/escalate` is
derived over `shipments/ship` and `orders/cancel-order`, so it inherits
`act` / `shared` / `irreversible` from them — the floor is derived, not
declared, and a gentler declaration is refused. Granting the wrapper's own
name conveys nothing; the PEP wants the constituent grants.

**The agent shares the human's surface, and the dial is the only thing
holding it back.** `shop.surface.cxd` attaches the `expediter` to the same
surface a person uses (agent-parity), and `shop.xap.cxd` sets its dial to
`floor` — so it may observe and propose but not commit an irreversible verb.
That is a construction, not a convention.

**One intent, several media, one authority decision — as DECLARED.**
`shop.surface.cxd` distributes `escalate` across a screen button and a
spoken phrase: same verb, same journal entry, same check. Read that as the
design surface, because it is: a surface *distributes*, it does not render,
and materializing a medium takes a client for it. Only the screen client
exists here, and the serve path handles no audio at all — so nothing is
speaking. The `[simulation]` blocks in the features are declarative in the
same way: the schema defines them, and nothing in the toolchain reads them
yet.

## The committed cascade

`cascade.cx` drives the whole thing: PEP → journal append → ordered bus,
with state as the **fold** of the committed stream.

```bash
cx --allow-read reference/shop/compose.cx    # the gate and rho
cx --allow-read --allow-write reference/shop/cascade.cx
```

What the cascade output shows, in order:

- **The human principal is the root of the chain.** `fulfilment` acts with no
  delegation, and because a grammar is attached the journal receives
  `orders/place-order` — the *qualified* intent, never the bare term.
- **The composite is refused for an agent that holds nothing**, and the
  denial names `orders/cancel-order` — a **constituent**. The wrapper's own
  name is not a thing you can hold, which is what stops a composite from
  laundering authority.
- **The dial admits it**, once *both* constituents are delegated.
  `why-allowed` then answers `allowed='true'` with both delegations in the
  chain and `accountable principal=principal:fulfilment` — authority always
  traces to a human.
- **Revoking one constituent refuses the same emit again**, naming the one
  that went.
- **The fold counts one escalate, not three.** The two refusals appended
  nothing — which is how "the PEP decides *before* the append" becomes
  observable rather than asserted.

Two things worth knowing if you write your own:

- **A dial scope must be a STRING to name a qualified capability.**
  `[scope 'orders/cancel-order']` — not `[scope :orders/cancel-order]`, since
  an atom name cannot contain `/`. An *atom* scope names a registered
  component and grants the verbs that component `emits`, which are bare; with
  a grammar attached the PEP checks *qualified* leaf grants, so the bare form
  will not admit anything.
- **`why-allowed` is a live query, not a record.** Bind it before you revoke,
  or you will ask it after the revoke has landed and get `false` for an emit
  that was admitted.

## Testing the surface

The surface is **derived** — `surface.cxs` says so: it "BINDS
already-declared verbs/views to MEDIA … it does NOT redeclare intents."
Nothing was checking that claim, and the schema cannot: it validates one
document's *shape* and knows nothing about the features.

So all three of these validate with `RC=0`:

- a control naming an intent no feature declares (`delayed-shipment/escalatte`)
- a panel instancing a feature the xap never enabled (`invoices`)
- a `shows` field that does not exist on the noun (`delay-alert.no-such-field`)

A web client would not catch them either — a client tests **rendering**;
these are errors of **meaning**, and all three are decidable statically
against the composed grammar and the enabled feature set.

```bash
cx xap check-surface reference/shop
```

The check began life here as `check-surface.cx` (#726) and GRADUATED into
the toolchain as `cx xap check-surface` (#846) — a surface being a faithful
derivation is a property of any XAP, not of this app, and this app is now a
consumer of the tool rather than its only implementation. It reports like
the compose gate's tooling face — `ok=` plus every problem — and exits 1 on
any problem. Point it at a broken copy of this directory to watch it refuse;
the tests do exactly that, because a check that only ever says `ok=true` is
worth nothing.

## Packaging and distribution

`package.cx` puts the three features and one shared library through the real
distribution engine: sealed into content-addressed trees, signed from day
one, published to a store, then **installed** into the shop's deployment
document.

```bash
CX_SHOP_REG=/tmp/shop-reg cx --allow-read --allow-write --allow-env \
  --allow-random reference/shop/package.cx
```

The install is not a copy. It is a fail-closed pipeline with a **per-kind
gate**:

- `kind=feature` → **W1–W6 over the installing XAP's enabled set ∪ the
  candidate.** The same compose gate `compose.cx` runs, now standing between
  a published package and the runtime. A feature that cannot compose with
  what is already enabled is refused with `CXER4884`, `stage=compose-gate`,
  carrying the `[conflict …]` set.
- `kind=library` → the **exports surface**: every def the manifest exports
  must be present in the packaged code. A library holds no authority — it
  **must not** declare `[needs]`, and installing one issues no grants
  (N-DIST-2). Enabling *is* granting, and there is nothing here to enable.

`orders` requires `shop-money`, so the install resolves the pin
**transitively** and records it under the feature in the returned document —
the §7 lockfile view:

```
[feature name=orders version='1.0.0' manifest=sha2-256:… hash=sha2-256:…
  [requires [pin library=shop-money version='1.0.0'
                 manifest=sha2-256:… hash=sha2-256:…]]]
```

Installs **chain**: each returns the updated deployment document, which the
next installs against — so `delayed-shipment`'s gate runs against a XAP that
already has `orders` and `shipments` enabled, exactly as it would in the
field.

## The web client — a separate project

`reference/shop-web-client/` is its own application, and the separation is
the point (N-CLIENT-2): a XAP never embeds its renderer. It exposes the
surface as **data**, and each client materializes it into one medium. The
same surface drives a CLI, a TUI, an agent and this browser with no change
to the shop.

```bash
CX_SHOP_PORT=8770 cx --allow-read --allow-write --allow-env \
  --allow-net=127.0.0.1:8770 reference/shop-web-client/serve.cx
```

Server-rendered CX → HTML, **no JavaScript and no build step**. htmx is one
script tag; live cadence is per pane (`hx-trigger="every 2s"` on the alert
pane, because the surface marks it foreground). `GET /surface` serves the
same surface as `application/cx` — **agent parity**: the expediter reads what
the browser reads, and the dial decides what it may do, not a different door.

It carries `client.cxd`, the fourth document kind, validated against
`client.cxs` like every other layer (#846 authored the schema —
`spec/03-approved/xap/xap_schemas/client.cxs`; the `kind=client` install
gate remains structural until the schema search path lands).

**Two engine limits it is written around rather than hiding** (#839): a
control renders only its *last* `[input …]`, so multi-slot verbs cannot be
driven from the web — the controls take one slot each and the views default
the rest with `[?else]`. And the intent route emits *anonymously*, which a
journal-bound runtime refuses, so this runtime is deliberately unbound. Both
are asserted in the tests, so when #839 lands those assertions fail and this
client gets simpler.

## Components — the runtime half of a feature

`cascade.cx` declares one `[$xap:component …]` per feature: `bind` is the
state route, `emits` is the intent shape. The **feature** says what may be
said; the **component** says what saying it does. They are separate on
purpose — the spec layers are authored and reviewable, the components are
wiring.

## Pinned by

`vcx/tests/xap_umbrella_test.v` — the `test_reference_app_*` and
`test_reference_cascade_*` families, which re-pin item 8 ("worked
reference-instance case") of the fixture family in
`spec/03-approved/xap/xap_grammar_composition.md` §9. Together they cover the
gate and both of its faces agreeing, the cross-reach refusal, all of ρ,
N-COMPOSE-1, signature derivation, commutativity of the grammar hash, and
then the cascade: qualified commits, N-COMPOSE-2 refusal naming the
constituent, dial-admits-then-revoke-refuses with `why-allowed` agreeing,
and state re-folding from the journal in a fresh runtime.

## Still to land (#726)

Every piece the issue asked for is landed: the three authored layers, the
compose gate, ρ, the committed cascade with its scoped delegation and
revocation, the surface derivation check, packaging through the distribution
engine, and the served-web HTMX client.

`cx xap init NAME [--dir D] [--client]` scaffolds this layout for a new
project — and what it emits composes through W1–W6 unedited, so a new author
meets a working XAP rather than a pile of blanks:

```bash
cx xap init myshop --client
cx --allow-read myshop/compose.cx
```

The toolchain remainder landed as #846: `client.cxs` is authored (the client
layer validates like every other), and the surface derivation check
graduated to `cx xap check-surface` with this app as a consumer. Still open,
and toolchain rather than app: graduating the schemas physically into the
toolchain with a search path (which is also what upgrades the `kind=client`
install gate from structural to schema-backed). `xap_authoring_process.md`
§7 tracks it.
