# Rulings 2026-08-20 — XAP authoring toolchain remainder (#846)

## ATC-1 — client.cxs authored; the surface derivation check graduates to `cx xap check-surface`

**Status:** RULED (owner "846a", 2026-08-20 — #846 is pre-cut: a validation
gap, not a feature). Authorizes the three parts #846 split out of #726, at
the post-SPR-1 schema home `spec/03-approved/xap/xap_schemas/`.

**Ruling.**

1. **`client.cxs` exists.** The client kind — the fourth authored document
   kind (`client.cxd ⊢ client.cxs`, authoring process §3.1; distribution
   spec §1's client row) — gets its schema, in the sibling style
   (`mode=open`, `::type` ascriptions, `[req]`/`[opt]`/`[card]`). The
   schema states the CONTRACT derived from §3.1's documented field list and
   the two live instances (`reference/shop-web-client/client.cxd`, the
   `cx xap init --client` scaffold): a client names itself, ATTACHES to
   exactly one xap+surface, materializes at least one medium, and maps
   controls to intents the features declared. If an instance violates the
   contract, the instance is fixed — the schema is never loosened to it.

2. **The surface derivation check is toolchain, not app.** What
   `reference/shop/check-surface.cx` proved (a surface may not name an
   intent no feature declares, instance a feature the xap never enabled,
   or show a field that does not exist) is a property of ANY surface.
   It lands as **`cx xap check-surface [DIR]`**: the CLI discovers the
   project's authored layers, and the check itself stays a CX program
   (language policy — CX first) evaluated in-process against the composed
   grammar. Report = the compose gate's tooling face (`ok=` plus every
   problem, all of them, never just the first); process exit is the gate
   face (any problem ⇒ exit 1). The reference app becomes a CONSUMER:
   `reference/shop/check-surface.cx` retires, the umbrella tests pin the
   command instead.

3. **`cx xap init` truth + drift keeper.** `--client` emits a spec + shell,
   deliberately not a runnable server (views are the author's medium); the
   flag's help and the command's output now SAY so instead of implying a
   runnable project. The scaffolded `client.cxd` validates against
   `client.cxs` like every other layer. A structure-agreement test keeps
   scaffold and reference honest: the set of authored `.cxd` document kinds
   in `reference/shop{,-web-client}/` and in a fresh scaffold must be EQUAL,
   and every kind's schema must accept both. When the reference layout
   evolves, that test — not luck — says the scaffold drifted.

**Explicitly out of scope here** (stays open in authoring process §7):
graduating the schemas physically into the toolchain with a schema search
path, and upgrading the `kind=client` install gate from structural to
schema-backed — both ride the schema-search-path design, not this landing.

Closes #846.
