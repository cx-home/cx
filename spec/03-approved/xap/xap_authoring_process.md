# XAP Authoring Process — three spec layers, one flow, scale-invariant

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: 02-working (2026-06-16; updated 2026-07-04). Companion to `xap_feature_composition_model.md` (the vocabulary + composition model + architecture/change doctrine), [`xap_grammar_composition.md`](xap_grammar_composition.md) (the normative composition algebra — the compose gate this process's outputs must pass), the distribution spec ([`../xap/xap_feature_distribution_market.md`](../xap/xap_feature_distribution_market.md) — how an authored feature is packaged/published/installed), and the normative `spec/03-approved/xap/xap.md`. Validated end-to-end against the in-family reference application `reference/shop/` (§6) with the real `cx` toolchain. (It succeeds an external reference XAP that validated this process first and has since evolved into its own independent project.)

**Purpose.** Define the **process for creating a XAP and the client surfaces that go with it**: how requirements become a validated, runnable XAP, at any scale, with AI assisting but never required.

---

## §1. The three spec layers

A XAP is authored as three kinds of spec document, each a `.cxd` validated by a `.cxs` schema (the schemas ship with the toolchain; drafts in `xap_schemas/`):

| Layer | Document | Captures | Depends on |
|---|---|---|---|
| **Feature** | `*.feature.cxd ⊢ feature.cxs` | requirements (functional/quality/domain — RFC-2119 level · status · acceptance) → grammar (verbs · nouns · rules) + frames/keys + per-verb effect-signature + governance defaults + the swappable **source** stack | — |
| **XAP** | `*.xap.cxd ⊢ xap.cxs` | which features it enables; composite features; principals/roles + agent; deployment/packaging; surfacing policy; governance defaults | feature specs |
| **Surface** | `*.surface.cxd ⊢ surface.cxs` | media; panels (placed feature instances) + layout; per-medium **materialization**; controls binding already-declared intents to per-medium triggers | XAP + feature specs |

Two load-bearing properties, both verified on the reference instance:

- **The surface layer is *derived*, not redeclared.** It references the features' verbs/views/nouns (a `shows` binding on a feature noun, a `control` binding on an acknowledge intent) and only adds medium-binding + layout. It never restates an intent.
- **A composite feature is just a feature** that `uses` others and declares **derived nouns** (`derived=true` + a `[from …]` join). Composition is closed under feature.

Two further document kinds exist at *other* boundaries (not authoring layers): the **composed grammar** `*.grammar.cxd ⊢ grammar.cxs` — a *derived projection* of the enabled feature set, recomputed never hand-edited ([`xap_grammar_composition.md`](xap_grammar_composition.md) §8) — and the **package manifest** `package.cxd ⊢ package.cxs` at the distribution boundary ([distribution spec](../xap/xap_feature_distribution_market.md) §2). The client spec (§3.1) remains the per-client fourth authored kind.

---

## §2. The flow

```
requirements  →  grammar (.cxd)  →  validate (.cxs)  →  TDD  →  run
 (human,      (agent compiles;   (cx validate        (acceptance →   (in-process
  fuzzy)       human reviews)     FILE --schema=…)     fixtures →      package;
                                                       impl)           adapters)
```

- **Requirements are the tests.** A requirement's acceptance criteria *are* the conformance fixtures — TDD falls out; it is not a separate invention.
- **Requirement ⟺ verb traceability** (every verb traces to a requirement, every requirement to a verb/rule) is enforced as a schema/validation concern, not a guideline.
- **Composition is gated.** The XAP layer's enabled set must pass the compose-time well-formedness gate (W1–W6, [`xap_grammar_composition.md`](xap_grammar_composition.md) §4) — the same gate runs at authoring/load, at runtime summoning, and at feature install; conflicts are values (`[!compose-conflict]`), reported in full, before anything wires.
- **Validation is real today:** `cx validate FILE --schema=SCHEMA.cxs` (exit 0 valid / 1 violation / 2 I/O-or-schema-fault). Schemas use `schema-mode open` so new vocabulary plugs in additively.
- **AI is assistive, never required.** The agent runs the interview (capture requirements — functional ones as user stories — elicit nouns/frames/governance/source, propose the grammar, generate a POC), but every artifact is a plain hand-editable file; manual authoring and any editor/tmux/git work unchanged. The authoring tool is itself a XAP ("XAP for XAP").
- **Loading a spec at runtime.** The loader reads `.cxd` grammar/feature files to a navigable value with `[$cx:parse]` (canonical; the flat alias `[$cx-parse]` is also accepted). A single-root file navigates directly (`$f@name`); a multi-root file uses the descendant axis `//` — see the parse-result shape in [`codec.md` §7](../core/codec.md) and [`modules/cx.md` §4](../modules/cx.md).

---

## §3. Project layout

```
my-xap/
  xap.cxd                                  # the XAP spec
  features/
    <feature>/<feature>.feature.cxd        # requirements + grammar + frames + governance + source
                                           # (+ <feature>.cx impl, <feature>.test.cxd fixtures — later)
  surfaces/<surface>.surface.cxd           # media bindings + layout (derived)
  schemas/*.cxs                            # transitional local copies; reference the toolchain's once published
  README.md  BACKLOG.md
```

Plain files — the CX LSP / tree-sitter (`.cx/.cxd/.cxs`), git, and any editor work as-is. The XAP tooling *adds* validation, the agent interview, and live preview (design-time = run-time); it replaces nothing.

### §3.1. The client app is a SEPARATE project (N-CLIENT-2)

The three spec layers describe the **XAP** — the experience runtime. They do **not** describe a client. Per **N-CLIENT-2** ([`xap.md`](../xap/xap.md) §16.1) a XAP **never embeds its renderer**: it exposes the medium-agnostic surface as **data** (the surface layer), and each client that materializes that surface into a medium is a **separate application with its own spec**, attaching over the shell (XSP / the `bus`).

```
my-xap/                         # the XAP — runtime, cascade, surface-as-data. NO renderer.
  xap.cxd  features/  surfaces/  schemas/

my-xap-<medium>-client/         # a SEPARATE client app, one per medium/renderer
  client.cxd ⊢ client.cxs       # the client spec: shell it attaches to, layout/windowing,
                                # per-pane refresh, settings, controls→intents mapping
  ...                           # the renderer implementation (e.g. an HTMX web server)
```

- **Web client default = HTMX, minimal-JS-by-exception.** The web client app server-renders HTML from the surface data it pulls; the browser is a generic hypermedia client. JavaScript is added **only by explicit design request**, named and contained, for the few interactions hypermedia cannot express (drag-to-resize splitters, etc.). Per-feature live cadence is hypermedia-native (`hx-trigger="every Ns"` per pane). The XAP↔client link MAY carry XSP **binary** frames that the *client app* (not the browser) decodes — keeping the XAP's payload native (`data-bin`) while the browser stays pure HTML.
- **Why separate:** the same surface-as-data drives a CLI, a TUI, an agent, and the web client with no change to the XAP (the client ladder, §16); embedding a renderer would bake in one medium and break agent-parity (N-MEDIUM-1).
- **The client spec is part of the standard template** — a fourth `.cxd ⊢ .cxs` document kind alongside feature/xap/surface, living in the client's own project.

---

## §4. Scale invariance (the CX-Store pattern)

> **One process, one schema set; the simple is the minimal valid instance of the complex.**

There is exactly one `feature.cxs`, one `xap.cxs`, one `surface.cxs`. **Hello-world** is the minimal `.cxd` validating against each (1 feature, 1 requirement, 1 principal, 1 medium = CLI). An **enterprise ecosystem** is a rich `.cxd` validating against the *same* schemas (N composed features, roles, federation, multi-cloud, many media). The process never branches by scale — only the *content* grows. (Just as CX Store keeps one API across a folder backend or a global-enterprise backend.)

It is a checkable claim: if hello-world and enterprise don't validate against the same three schemas, the process is wrong.

---

## §5. Is a list of requirements enough? (the POC question)

Requirements are the **seed and spine** but not quite enough alone. To realize a runnable XAP the agent elicits or infers four more things: the **noun schema**, **frame/key registration**, **verb effect-signatures**, and **minimal governance**. With those plus defaults (thinnest medium = CLI, single principal), **requirements → a POC surface = yes**; **requirements → production = requirements + the elicited gaps, reviewed.** Same artifacts; the POC leans on defaults (again, the CX-Store minimal-instance pattern).

---

## §6. Worked reference — the reference-instance XAP

The worked reference is **`reference/shop/`** in this repo (#726) — a small
shop: orders, shipments, and the delay alerts that live between them. It
succeeds the original external reference XAP, which validated this process
first and has since evolved into an independent project.

All three layers, each validating against its schema in `xap_schemas/` and
composing through the one W1–W6 gate:

- **features:** two BASE features that know nothing about each other —
  `orders` (registers the `order-id` key and the `time` frame; layered
  gateway/sensor **source** stack) and `shipments` (registers onto the *same*
  key with the same type — W2's agreement — with redundant vendor gateways
  and failover) — plus the **COMPOSITE** `delayed-shipment`, which joins the
  two over that key and frame into a derived `delay-alert` noun present in
  neither base, and a derived `escalate` verb whose signature is taken from
  its constituents.
- **xap:** enables the three, names the human roles (`fulfilment` holds final
  authority) and one agent (`expediter`, `dial=floor` — so it may propose and
  not commit), declares in-process packaging with a named remote.
- **surface:** screen + audio; the delay queue materializes as
  screen-highlight *and* audio-tone at once, and `escalate` is a screen
  button *or* a spoken phrase (same intent, different trigger, one authority
  decision). The agent attaches to the same surface a human does.

Two things the reference makes concrete that prose alone did not:

- **A base feature may not reach across.** "A shipment can only be dispatched
  for an order that was placed" is true and belongs on the *composite*, not
  on `shipments` — writing it in the base is refused with a W4 conflict,
  because it would mean `shipments` could never be enabled alone. Both files
  carry the explanation and a test pins that it is true.
- **Ambiguity is demonstrated, not described.** The two bases deliberately
  share a bare `highlight` term, so the reference carries a live
  `[!ambiguous-verb]` value listing both candidates — which is also the
  N-COMPOSE-1 witness (enabling `shipments` turns the old resolution into a
  prompt that still lists it, never into a different verb).

Pinned by the `test_reference_app_*` family in
`vcx/tests/xap_umbrella_test.v`; `reference/shop/compose.cx` runs the whole
demonstration on the command line.

---

## §7. Open / next

- **`cx xap init` is WIRED** (#726): `cx xap init NAME [--dir D] [--client]` scaffolds this layout — two independent base features, one composite joining them over a shared key, the xap wiring layer and a surface, plus optionally a SEPARATE client project. What it emits COMPOSES as generated (W1–W6 green, every layer schema-valid, unedited), and it demonstrates the two things a blank page cannot: that a bare term owned by two features resolves to an ambiguity VALUE rather than a guess, and that enabling a feature never rebinds an utterance that already resolved. **Landed since (#846, RULED ATC-1):** `client.cxs` is authored (the client kind validates like every other layer — the schema-less gap that let `version=1`-class type bugs through is closed), and the surface derivation check graduated out of the reference app as **`cx xap check-surface`** — any project's surfaces are checked against the composed grammar and enabled feature set, with `reference/shop/` now a consumer. **Landed since (RULED: ATC-2):** the `--client` scaffold is **RUNNABLE as generated** — it emits a `serve.cx` whose panes are **generic table views derived from the surface's `shows` declarations** (every shown field a column, no view authored by hand), intents wired through the standard `POST /intent/<verb>` path and each pane's refresh answered by `GET /<bind>`. The generic table is a FLOOR — the starting point the author replaces with views in their own medium, never a lesson in final UX — and the derivation is single-sourced in the generator, so the surface's `shows` and the client's tables cannot drift apart. Still open here: **graduate the schemas physically into the toolchain** + a schema search path, so a project references them instead of carrying local copies (`xap_schemas/` remains a canonical-here draft) — that move is also what upgrades the `kind=client` install gate from structural to schema-backed.
- **TDD layer:** define how a requirement's acceptance becomes a `*.test.cxd` conformance fixture run by the toolchain.
- **Run:** the in-process-package runtime + source adapters (the orchestrator impl, `vcx/code/stdlib_xap.v`, is the constraint).
- Reconcile vocabulary with the approved `xap.md` ("feature" ↔ "capability"; fold in frames/keys/consequence/source-stack) — **now scheduled**: the reconciliation list is the graduation section of [`xap_grammar_composition.md`](xap_grammar_composition.md) (user G3).

---

**References:** `xap_feature_composition_model.md` (vocabulary, composition axes, governance, architecture/change §11) · [`xap_grammar_composition.md`](xap_grammar_composition.md) (the normative composition algebra + compose gate) · [`../xap/xap_feature_distribution_market.md`](../xap/xap_feature_distribution_market.md) (packaging/publish/install) · `xap_schemas/{feature,xap,surface,client,grammar,package,instance}.cxs` (the schemas) · `spec/03-approved/xap/xap.md` (normative).
