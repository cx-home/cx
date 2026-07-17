# CX v0.13.0 — developer onboarding

Task-oriented docs to get a developer productive on the v0.13.0 platform:
XAP (features, clients, registries, the market model) and CX Store (embedded
→ service, management, security). Every code snippet in this set was run
against the real `cx` toolchain before it landed here; every claim traces to
a spec — the spec is the only source of truth (see the governance spec).

Where a capability is designed but not yet shipped, the doc says so
explicitly, with the owning spec named.

## Reading order

**Day 1 — the platform in one sitting**

1. [v0.13.0 capabilities](v0130-capabilities.md) — what the platform does today, in one page.
2. [Store: embedded](store-embedded.md) — the content-addressed store, the substrate everything rides on.
3. [XAP quickstart](xap-quickstart.md) — what a XAP is, the three spec layers, the deployment host, the process model.

**Building a XAP**

4. [Authoring features](features-authoring.md) — feature spec + contract module.
5. [Consuming features](features-consuming.md) — pins, the `requires` closure, `pkg:` module references.
6. [Clients and views](client-and-views.md) — surfaces as data; the HTMX web-client pattern.

**Distributing features**

7. [Registry: setup](registry-setup.md) — a git repo is a registry; seal, sign, publish.
8. [Registry: consuming](registry-consuming.md) — verify, install, pin, vendor.
9. [Marketplace](marketplace.md) — the market model, entitlements, fees, payment rails: today vs specified.

**Operating a store**

10. [Store: service tier](store-service.md) — the daemon, auth, observability, CSRP/gRPC, deploy artifacts.
11. [Store: management](store-management.md) — status, gc, diff, branch; recovery and migration; the admin console.
12. [Store: security](store-security.md) — capabilities, encryption-at-rest, RBAC, tenancy.

## Conventions used throughout

- `cx <file>` runs a program (never `cx eval`); capability grants are
  explicit flags (`--allow-read`, `--allow-net=host:port`, …) — deny-by-default
  per the security spec.
- `$…@attr` reads an attribute; `[?lib '…' :as ns]` imports a module;
  `[$ns:fn …]` calls into it.
- The worked XAP example everywhere is the marine helm
  (`cx-home/xap-marine` + `cx-home/xap-marine-htmx-web-client`) — the
  validated reference instance named by the XAP authoring process spec.
