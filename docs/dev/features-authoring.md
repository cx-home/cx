# Authoring a feature — spec + contract module

A **feature** is the XAP composition unit: a grammar (verbs, nouns, rules)
compiled from requirements, plus an implementation module that travels with
it. Vocabulary and rationale: the feature composition model spec
(`spec/02-working/xap_feature_composition_model.md`); the authoring flow: the
XAP authoring process spec; the package shape: the feature distribution &
market spec.

## 1. The feature spec (`<name>.feature.cxd`)

Requirements are the source; the grammar is the compiled output. **A
requirement's acceptance criteria are the conformance fixtures** — TDD falls
out. The real reference is `reference/shop`'s base
feature spec; its anatomy:

```cx
[feature name=own-ship version=0.1.1
  [summary "The vessel's own state from its instruments …"]
  [frames                             # shared rulers for cross-feature joins
    [use frame=geo  via=position]
    [use frame=time via=observed-at]]
  [nouns                              # the read-model
    [noun name=own-ship singular=true
      [field name=position type=geo-point doc="…"] …]]
  [verbs                              # each with an effect signature
    [verb name=read-instruments effect=observe scope=local consequence=none
      [intent [do :read-instruments]] [reads own-ship] …]
    [verb name=set-safety-contour effect=act scope=shared consequence=reversible
      [intent [do :set-safety-contour meters=$meters]] [writes safety-contour] …]]
  [rules [rule name=depth-alarm-mandate kind=mandate guardian=true …]]
  [governance                         # per-verb grant defaults
    [grant verb=read-instruments   to=any]
    [grant verb=set-safety-contour to=skipper dial-min=auto]]
  [requirements
    [requirement kind=functional as=skipper traces=set-units
      [want "…"] [so "…"]
      [acceptance "…" [check kind=act as=skipper intent="[intent verb=\"set-units\" …]"
                        then-path="/surface/own-ship" then-has="m/s"]]] …]
  [source maps-to=own-ship            # the swappable layered adapter stack
    [gateway name=yd-wifi kind=yacht-devices priority=1] …]]
```

Load-bearing rules:

- **Effect signature** on every verb — `effect` (observe | act | arrange) ×
  `scope` (shared | local) × `consequence` (none → irreversible). observe is
  ungated; act meets the authz PEP; arrange meets the envelope; consequence
  scales the gate (the verb-effect-signature section of the composition model
  spec).
- **Requirement ⟺ verb traceability** — every verb traces to a requirement
  and vice versa; enforced as a validation concern.
- **Frames and keys** relate nouns *across* features: a frame is a shared
  continuous coordinate (compare by nearness — geo, time, value), a key a
  shared identifier (join by sameness — `mmsi`). Register onto them; never
  invent private ones for shared concepts.
- **The source stack is a seam**: gateways (`kind` deliberately not enum'd) +
  prioritized sensors with failover feed the nouns; the noun shapes are the
  stable contract — nothing above the stack changes when a vendor does.

Validate as you go (verified): `cx validate features/own-ship/own-ship.feature.cxd --schema=schemas/feature.cxs`.

## 2. The contract module (`<name>.cx`)

A feature's behavior ships **inside its package**, never in the serving
process. The module exports the conventional surface the deployment host
calls (the feature runtime contract section of the distribution spec):

| Export | Required | Called |
|---|---|---|
| `readout ($store $t)` | always | serves `GET /surface/<feature>`; feeds the push channel |
| `apply ($verb $intent $store)` | iff the grammar has a non-observe verb | after the PEP admits the emit; `$verb` arrives qualified |
| `simulate ($store $t $params)` | optional | the host's sim tick |

Minimal complete module (verified end-to-end):

```cx
[?lib 'cx-stdlib/store' :as store]

[?def readout scope=public impure ($store $t)
  [?let [= $n [$count [$store:list-docs $store]]]
   [$concat "[readout title=\"Notes\" [kv k=\"count\" v=\"" $n "\"]]"]]]

[?def apply scope=public impure ($verb $intent $store)
  [?if [= $verb "notes/add-note"]
   [then [?let [= $h [$store:put-doc $store [note [text "from intent"]]]] $verb]]
   [else [?element "refused" [?attr "reason" [$concat "no apply for " $verb]]]]]]
```

- `apply` may **refuse on domain policy** (value bounds, device state) by
  returning `[refused reason=…]` — the host acks `ok=false` with the reason.
  The PEP admitted the *verb*; the feature refused the *values* — two layers,
  both visible.
- The module's `[?lib]` imports resolve on the code plane (`pkg:` references
  — see [consuming features](features-consuming.md)) or inside the package's
  own tree, never by reaching into the deployment's filesystem.
- A module whose defs you export must declare them in the manifest's
  `exports` block; the install gate verifies the listing against the code
  both ways (see [registry setup](registry-setup.md)).

The full-size real example is `reference/shop`'s base
feature impl —
live telemetry readout with simulator fallback, unit-preference and control-slot
`apply`, shared helpers from a common library over the code plane.

## 3. Exports and scope

`scope=public` on a `[?def]` is what a module exports; everything else stays
private (module semantics: the code spec). For a packaged feature the
manifest's `exports` block lists exactly the public contract surface
(`own-ship/readout`, `own-ship/apply`) — projected from the code at publish,
re-verified at install.

## 4. Composition — composite features

A composite feature is **just a feature** that `uses` others and declares
derived nouns (a `[from …]` join over shared frames/keys). Composition is
closed under feature; the composite packages, publishes, and installs like a
base feature, with its `uses` set as grammar-plane dependencies. Reference:
`reference/shop`'s composite delayed-shipment feature (joins its two
base features over geo + time into derived alert nouns).

Authority note: a composite's cross-feature reads are exactly what the
`needs` block's `reads` consent is for — see [marketplace](marketplace.md)
for the consent model.
