# Consuming features — pins, the requires closure, `pkg:` references

How a XAP takes on features and libraries, reproducibly. Governing spec: the
feature distribution & market spec (`spec/03-approved/xap/xap_feature_distribution_market.md`)
— the two-dependency-planes and code-plane-loading sections in particular.

## Two dependency planes, never blurred

- **grammar plane** — a feature `uses` a feature (composition; W-gate
  territory; changes what a principal can *say*).
- **code plane** — any package `requires` a **library** (implementation;
  hash-pinned; changes what the code *calls*). A library never `uses` a
  feature, and — invariant N-DIST-2 — a library carries **no authority**: it
  executes under the requiring feature's grants and can neither hold nor
  request capabilities of its own.

## The deployment doc is the lockfile

`xap.cxd` with hash-pinned feature rows, plus each row's resolved `requires`
closure, is a **complete reproducible closure** spanning both planes. From the
live marine deployment:

```cx
[feature name=own-ship package=./features/own-ship status=ready version=0.1.1
    manifest=f77d02b1… hash=3c7867a3…
  [requires
    [pin library=marine-common version=0.2.0 manifest=ef3896cc… hash=5e1fdeee…]
    [pin library=nmea0183      version=0.1.0 manifest=dfc7a847… hash=9420de8a…]]]
```

The composed grammar is a deterministic function of the pinned set, so the
grammar hash is itself a supply-chain witness. **Update = new hash, explicit
re-pin; rollback = re-pin the previous hash** (the lifecycle section of the
distribution spec). In xap-marine, `make registry-pin` regenerates the pinned
doc from the registry via `registry/pin.cx`.

## Loading library code by pin — `pkg:` references

`[?lib]` resolves a fourth reference form alongside file paths, registered
names, and `https://`:

```cx
[?lib 'pkg:<name>@<version>' :as n]                    # registry-resolved
[?lib 'pkg:<name>@<version>#<manifest-hash>' :as n]    # pinned — alias table never consulted
```

The registry is bound by the `CX_REGISTRY` environment variable (a store URL);
the full fail-closed verification chain (content re-hash + publisher
signature) runs on **every** load — there is no trust-the-registry mode.
Verified against the live marine registry:

```cx
[?lib 'pkg:marine-common@0.2.0' :as mc]
[$mc:fmt-speed 6.4 "m/s"]
# → '3.3 m/s'
```

```sh
CX_REGISTRY=file:///…/xap-marine/registry/store cx --allow-read program.cx
```

Error lanes (fail-closed, from the distribution spec's function-surface
section): no registry bound → `CXER4889`; name/version absent → `CXER4886`;
a `#hash` pin that does not match the resolved manifest → `CXER4888`; a
tampered tree → `CXER4881`.

The deployment host derives each feature's `pkg:` reference from the
`xap.cxd` pins, so a running XAP's code plane **is** its lockfile.
`own-ship.cx` opens with exactly this:

```cx
[?lib 'pkg:marine-common@0.2.0' :as mc]
```

## Vendoring — materialized dependencies

Fetch → verify → write files → `[?lib './…']` remains valid (offline/at-sea
deployments vendor their whole feature set into a local store and install
with full trust checks and no network). `xap-marine/tools/vendor.cx` +
`make vendor` is the working example. `pkg:` is the canonical path; vendoring
is the explicitly-supported alternative, not required machinery.

## Version discipline

- A version is a store **alias** — a *name for a hash*; the hash is the
  truth. Released aliases are immutable (re-pointing raises `CXER4887`).
- Updates within a purchased/pinned range re-verify against the same
  machinery; a new artifact is a new version, always.
- Note the distinct, older mechanism: `cx.lock` (the lockfile spec,
  `spec/03-approved/core/lockfile.md`) pins `https://` module fetches with
  SRI integrity. `pkg:` + the `xap.cxd` pin view is the XAP-era system; both
  coexist, serving different reference forms.
