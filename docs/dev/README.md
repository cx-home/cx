# CX developer onboarding

Task-oriented docs to get a developer productive on the CX platform. Every
code snippet in this set was run against the real `cx` toolchain before it
landed here; every claim traces to a spec — the spec is the only source of
truth (see the governance spec). Where a capability is designed but not yet
shipped, the doc says so explicitly, with the owning spec named.

The conceptual companion is the guide (`make guide` → `docs/guide/`), whose
navigation is the ring model: Ring 0 data, Ring 1 code, Ring 2 platform,
Ring 3 ecosystem. This set is the operator/developer depth behind the
guide's Ring 2 and Ring 3 pages, plus the ORIEL worked example.

## Reading order

**Day 1 — the platform in one sitting**

1. [Platform capabilities](v0130-capabilities.md) — what the platform does, in one page (written at the v0.13.0 line; the guide's ring pages carry what has landed since).
2. [Store: embedded](store-embedded.md) — the content-addressed store, the substrate everything rides on. *(Ring 2)*
3. [XAP quickstart](xap-quickstart.md) — what a XAP is, the three spec layers, the deployment host, the process model. *(Ring 2)*

**Building a XAP** *(Ring 2 — authoring and running)*

4. [The ORIEL guide](oriel-guide.md) — **build a surface the ORIEL way**: the reference storefront end to end — domain document, composition document, theme, zero view code, and the six instruments that police it. Start here if you learn from a worked example.
5. [The studio](studio-guide.md) — **edit a running surface, and ship the result**: the design tool over journaled commands. Try it in five minutes, what it can and cannot express, where it sits in the workflow, and the three deploy channels that make a client's customizations survive an upgrade.
6. [Authoring features](features-authoring.md) — feature spec + contract module.
7. [Consuming features](features-consuming.md) — pins, the `requires` closure, `pkg:` module references.
8. [Clients and views](client-and-views.md) — surfaces as data; the HTMX web-client pattern.

**Distributing features** *(Ring 3 — the ecosystem)*

9. [Registry: setup](registry-setup.md) — a git repo is a registry; seal, sign, publish.
10. [Registry: consuming](registry-consuming.md) — verify, install, pin, vendor.
11. [Marketplace](marketplace.md) — the market model, entitlements, fees, payment rails: today vs specified.

**Operating a store** *(Ring 2 — operations)*

12. [Store: service tier](store-service.md) — the daemon, auth, observability, CSRP/gRPC, deploy artifacts.
13. [Store: management](store-management.md) — status, gc, diff, branch; recovery and migration; the admin console.
14. [Store: security](store-security.md) — capabilities, encryption-at-rest, RBAC, tenancy.

## Conventions used throughout

- `cx <file>` runs a program (never `cx eval`); capability grants are
  explicit flags (`--allow-read`, `--allow-net=host:port`, …) — deny-by-default
  per the security spec.
- `$…@attr` reads an attribute; `[?lib '…' :as ns]` imports a module;
  `[$ns:fn …]` calls into it.
- The reference applications: `reference/shop/` is the minimal in-family
  reference; **ORIEL** (the [ORIEL guide](oriel-guide.md)) is the full
  reference surface — storefront, terminal shell, and voice-style renderer
  from one set of declarations.
