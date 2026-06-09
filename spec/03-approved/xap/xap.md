# `cx-xap` — the XAP paradigm & orchestrator

```cx
[module-meta name=xap tier=D status=new]
```

**Status:** **Approved — design-frozen for v0.8.0** (graduated to `03-approved` 2026-06-09). The design is frozen here; the **empirical resolver-accuracy gate (§20/§26) remains OPEN**, along with the impl / §10 fixtures / governance + package registration items in §11 — graduating the text does **not** close the on-real-use gate. Runtime **incrementally implemented**. The XAP experience-layer paradigm (Part II) + the orchestrator module that composes the general-purpose modules (bus / journal / authz / session / sched + http / crypto / time). The `cx-xap` package is bundled (`[?lib 'cx-xap' :as xap]`) and the demo ladder (`spec/03-approved/xap/demos/` D1–D4) runs on it: the pure constructors, the cascade (`run`/`emit`/`state`), the dial (`dial`/`why-allowed`), the web `serve` leg (GET shell / POST cascade over the core picoev engine), **and the live `GET /events` SSE feed (§24): held-open, event-driven server push on each committed intent — implemented on the picoev engine, no longer bridge-deferred**. Deferred: the broader subsystem surface. Graduation to a fully frozen module is still gated on the empirical resolver-accuracy test (§20, §26).

Normative reference (on graduation) for the `cx-xap` sub-package: the
experience layer at the top of the CX web stack — component/surface/view-tree
constructors, intent registration + the committed cascade, journal-folded state,
the pluggable resolver hook, content-negotiated render, the dial/RACI delegation
wrappers, the `[$xap:serve]` bootstrap onto `[?http-service]`, and the
`[$xap:init]` project scaffolder. It is the composition companion to the
declarative `[?http-service]` / `[resource]` directives ([`code.md`](../core/code.md)
§10.3) and the programmatic `[$http:serve]` engine ([`http.md`](../std-lib/http.md) §3.5).

> **Positioning & addressing (normative).** `cx-xap` is its **own bundled
> subsystem — NOT a `cx-stdlib` module.** It is the experience layer that
> *composes* the general-purpose primitives, which **remain in `cx-stdlib`**
> (`bus` / `journal` / `authz` / `session` / `sched`, atop `http` / `net` /
> `crypto` / `time`). XAP is a *layer above* stdlib, not a peer utility (§1). It
> ships **in the CX binary** (bundled), addressed three ways:
> - the **`cx xap …` CLI subcommands** (`init`/`new`/…) are **core to the
>   binary** — always present, no import;
> - the **declarative control-plane reuses the core `[?http-service]` directive**
>   ([`code.md`](../core/code.md) §10.3) — XAP introduces **no new core directive**;
> - the **effectful programmatic runtime** (`[$xap:…]`) is a **capability-gated
>   bundled package** reached via `[?lib 'cx-xap']` — gated because
>   `serve`/`emit`/`run` touch net/journal/bus, so it must be opt-in, never
>   ambient core.
>
> This mirrors `http` exactly (a **core `[?http-service]` directive** + a **gated
> `[$http:…]` engine**) and satisfies "built into cx" — including the toolchain
> being XAP-shaped (R6) — without making an effectful surface ambient.

> **Platform scope.** This module is the **thin** experience-layer orchestrator.
> The broader platform it anchors — operations/topology at scale, CX-as-
> infrastructure-as-code, cross-XAP **federation**, and the fleet / meta-XAP — is
> mapped in **§28**, which also records the load-bearing rulings (R1–R6) reconciled
> into the sections below. Those platform concerns will partition into separate
> specs **later** (N-IMPL-1); for now they live here, in this one spec.

## §0. Consistency with the in-review siblings & amendments (normative dependency)

`xap` is the top of a layered, in-review stack; on the siblings' approval the
cited semantics are load-bearing here. If any is rejected or changed at G3, the
marked clauses are revisited. The decomposition — five `cx-stdlib` primitives +
the `cx-xap` orchestrator — and the three enhancements are §25.1; the capability
summary is its §0 table.

| Dependency | What xap relies on |
|---|---|
| `cx-stdlib/bus` ([`bus.md`](../std-lib/bus.md), forthcoming) | general **pub/sub** — `[$bus:on …]` subscribe, `[$bus:emit …]` publish, **synchronous ordered dispatch** (zero-or-many subscribers react in commit order). xap drives it in the *log-coupled* mode (§2); it does not add an async/mailbox mode. |
| `cx-stdlib/journal` ([`journal.md`](../std-lib/journal.md), forthcoming) | append-only **hash-chained** event log — `[$journal:append …]`, `[$journal:fold …]`, `[$journal:replay …]`, dry-run. The state authority + audit/replay substrate (N-CORE-1). |
| `cx-stdlib/authz` ([`authz.md`](../std-lib/authz.md), forthcoming) | the trust model — principals, capabilities, attenuating/time-bounded/revocable **delegations**, **guardian grants**, the signed incapacity-predicate library, and the single **PEP decision function** `[$authz:check …]`. xap calls the PEP at the one enforcement point (§2.2); it never re-implements authority. *(Distinct from `caps`, which is effect-permissions.)* |
| `cx-stdlib/session` ([`session.md`](../std-lib/session.md), forthcoming) | `(principal, tenant)` sessions — `[$session:attach …]`, `[$session:of …]`, the mirrored-attach contract. Turns an authenticated request into the actor an intent commits under. |
| `cx-stdlib/html` ([`html.md`](../std-lib/html.md)) | view-tree → HTML serialize + sanitize. xap's `text/html` render leg (§5) delegates here; xap holds no markup logic. |
| `cx-stdlib/http` ([`http.md`](../std-lib/http.md) §3.5) | the real-socket `[$http:serve]` engine + `[?http-service]` directive ([`code.md`](../core/code.md) §10.3) that `[$xap:serve]` bootstraps onto (§9). xap opens **no socket of its own**. |
| `http` **SSE / streaming** ([`http.md`](../std-lib/http.md) §3.6) | held-open `text/event-stream` writes for the authoritative event-feed + working-panel slice-feeds (§16, §18, §24). **Implemented**: the http client+low-level-server SSE (§3.6) and, on the `[$xap:serve]` picoev engine, the held-open event-driven `GET /events` push (§24). Working-panel slice-feeds remain the broader surface. |
| `http` **timer / scheduled-event** enhancement (§25.1) | `[$…:after dur ev]` cancelable timers for incapacity windows (`no-ack-within "10m"`) + lifecycle. xap surfaces it as `[$xap:after …]` (§4.4) over the picoev timer. |
| `crypto` **JWT/JWKS** enhancement (§25.1) | consumed *via* `session`, not directly — xap does not verify tokens itself. |
| SAP §1 — **four-channel model** | results are **values**; a surface/component/fold returns a present value, never `null`. A rejected intent rides the **failure channel** (`[err]`); a not-yet-resolved resolver candidate rides the **absence channel** (empty node-set). |
| SAP §2 — **`[?try]` retirement** | intent outcomes are handled with `[?match]` / `[?else]` / `[?fallback]`; this spec never uses `[?try]`. Canonical call form is `[$xap:fn …]` (`[head …]`), never an infix. |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

xap does **not** re-specify pub/sub, the log, authority, sessions, HTML, or the
socket — those are its siblings'. xap is **Tier-B runtime — necessarily impure**
for the run/commit/serve/init verbs (they touch the bus, the log, the network,
the filesystem) and requires their capabilities transitively; the **data
constructors are pure** and capability-free (§5).

---

## §1. Scope

`cx-xap` provides the **composition and orchestration** surface of a XAP:
pure constructors for **components** (the typed triple, §17),
**surfaces** (a composition of placed components, §13.1/§19), and **view trees**;
intent-handler **registration** and the **committed cascade** (the §2 emit ⇒
journal-append ⇒ ordered-dispatch rule, PEP-gated); **state** as a journal fold;
the **resolver/Radar** hook (pluggable — scripted default, LLM-pluggable, §20);
content-negotiated **render** (HTML or `application/cx` view-tree-data, §3);
thin **dial/RACI** wrappers issuing authz delegations (§21); the **`serve`**
bootstrap onto `[?http-service]`; and the **`init`** project scaffolder (§25.2).

**Layering (decision per §25).** xap is the **experience
layer** at the top: `net (L4) → http (L7) → [?http-service] directive → XAP
modules (bus · journal · authz · session · xap)`. xap is a *separate module*
above the others, never folded into them (folding would break N-IMPL-1's
thin-module decomposition and put composition logic into the wrong concern).

**Module vs. directive — they coexist, with the module as the engine.**

| Surface | Home | Role |
|---|---|---|
| **`cx-xap` module** (this spec) | `[?lib 'cx-xap']` | the **programmatic** orchestrator — constructors, cascade, resolver hook, `[$xap:serve]`, `[$xap:init]` |
| **`[?http-service]` / `[resource]` directives** | [`code.md`](../core/code.md) §10.3 | the **declarative** control-plane — routing + lifecycle that `[$xap:serve]` bootstraps onto (N-IMPL-1: the directive *is* the framework-shaped part; xap adds none) |

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| pub/sub mechanics (subscribe/publish/ordered dispatch) | `cx-stdlib/bus` ([`bus.md`](../std-lib/bus.md)) |
| append-only hash-chained log, fold, replay, dry-run | `cx-stdlib/journal` ([`journal.md`](../std-lib/journal.md)) |
| principals, capabilities, delegations, guardian grants, incapacity library, the PEP decision function | `cx-stdlib/authz` ([`authz.md`](../std-lib/authz.md)) |
| session attach/detach, token verify, mirrored-attach | `cx-stdlib/session` ([`session.md`](../std-lib/session.md)) |
| HTML serialization + sanitization | `cx-stdlib/html` ([`html.md`](../std-lib/html.md)) |
| TCP/TLS sockets, the HTTP/1.1 engine, SSE held-open writes, `[resource]` routing | `cx-stdlib/net` / `cx-stdlib/http` / `[?http-service]` |
| state-slice query / CXPath | core CXPath ([`code.md`](../core/code.md)) |
| the resolver's *judgment quality* (relevance/ranking/prediction) | the pluggable resolver impl (§20); xap defines only the **interface** + a scripted default |
| WebSocket bidirectional transport, CRDT collab | out of scope v1 (§27 — SSE-only) |
| identity issuance (IdP) | external OIDC/SAML, integrated via `session` (§22.1) |

`cx-xap` **introduces no new capability** — it inherits `net` (via
`http`, for `serve`), `io`/`http`/`process` (via the `init` fetchers, §10), and
the authority model (via `authz`). The data constructors are **pure** and
capability-free (§5).

## §2. Conceptual model

### §2.1. The runtime handle and the cascade

One impure handle wraps a running XAP — its bus, its journal, its authz context,
its session registry, and its registered handlers:

```cx
[xap-runtime tenant="acme" state="running"          ; one tenant's wired bus+journal+authz+sessions
  on-close="xap/close"]
```

A `[xap-runtime]` is created by `[$xap:run]` (§4.1) and is **single-tenant** —
tenant is a hard partition (§22.6); cross-tenant access is
structurally impossible because a runtime owns exactly one tenant's journal +
bus. It carries the **closeable contract** (`on-close="xap/close"`,
[`code.md`](../core/code.md) §8.10.7): `[?with-open]`-able, never raises
`CXER0108`; close drains the bus + flushes the journal + releases sibling
handles.

**The cascade is the composition rule this module owns.** An intent committed
through a runtime is processed as the §14 **synchronous
serialized cascade** — the load-bearing N-CORE-1 ordering, built by *wiring* the
siblings, not by a new primitive:

```
[$xap:emit] ⇒  (1) authz PEP check          [$authz:check …]   ; §2.2 — reject ⇒ [err], no append
           ⇒  (2) journal append            [$journal:append …]; commit point — assigns order in the intent's stream (§14.2)
           ⇒  (3) bus dispatch in order      [$bus:emit …]      ; subscribers react in defined order
           ⇒  (4) any sub-emissions append BEFORE the next external message commits on that stream (recurse 1–4)
```

> **N-CORE-1 (commit order is the system authority).** The journal append (step
> 2) is the commit point that assigns total order **within the intent's aggregate
> stream** (§14.2); subscriber emissions (step 4) are appended and processed before
> the next *external* message commits on that stream. Disjoint streams commit in
> parallel; cross-stream effects are explicit choreography (§14.2).
> A free-running async/mailbox bus is **rejected** (§14, §26) —
> it breaks replay/determinism. xap MUST drive `bus` in this synchronous,
> ordered, log-coupled mode; `bus` itself offers the general pub/sub, xap supplies
> the discipline.

### §2.2. The bus is the single enforcement point (PEP); xap calls it, does not implement it

Before any intent is appended, xap calls the **authz PEP decision function**
`[$authz:check …]` (§22.3) with the intent's actor +
authority-basis, the target slice, and the tenant. The PEP is **one checkpoint,
one authoritative bus**: a denied intent never reaches the journal — it returns a
**failure-channel** `[err code=cx-err:CXER4850 E_XAP_UNAUTHORIZED]` carrying the
missing grant + resource, and **nothing is appended** (the log records only
admitted intents + their authority basis, §22.6). xap **owns
the *call site*** (the cascade orders the check before the append); `authz`
**owns the *decision*** (the composition `effective = individual ∩ ⋂envelopes`,
§21). xap re-implements no authority logic — N-IMPL-1.

### §2.3. A rejected intent is a VALUE on the failure channel, not a crash (SAP §1)

A committed intent that the PEP admits but a subscriber *rejects* (e.g. a refund
on an already-held order, Appendix B step 6) appends a
**rejection event** and the cascade surfaces a flowing `[err]` the emitter may
re-plan on — the agent re-plans, the human sees the struck option. This is the
SAP four-channel posture: a rejection is a **present `[err]` value that flows**,
not a runtime fault; the runtime never crashes on a rejected intent. A genuine
fault (PEP unavailable, journal write failure, malformed handler) is the only
thing that raises out of `[$xap:emit]` (§8).

### §2.4. Components and surfaces are pure data (SAP §1)

A **component** (§17) is the typed triple `(slice-in,
view-tree-out, intent-vocabulary-out)` plus a view/working-panel declaration; a
**surface** is a composition of *placed* components (each placed instance **is a
panel**, §13.1). Both are **CX data values** — `[$xap:component]`
/ `[$xap:surface]` are **pure constructors** returning the bracketed value, not
opaque code and not directives. Because they are data, the **agent reads,
generates, and recomposes them** precisely (the §17/§18.1 payoff), and the
resolver (§20) operates over them as a fold. A view tree is medium-agnostic
(§13.2): it is *what* is composed, never *how* it materializes
(§5 render is the per-medium step).

### §2.5. Content negotiation is render-time, agent-parity is structural (SAP §1, §15)

The **same surface value** is content-negotiated at render (§5): `text/html` →
HTML fragment with the human's controls bound inline (via `html`);
`application/cx` → the **view-tree value**, controls as `[do …]` data (the agent).
Same source, same controls, two representations — purer HATEOAS than HTML-only.
Because the surface is data, **the agent reads the identical surface the human
perceives**, so agent-parity holds across every medium (§13.2),
not just screens. Modality (tap / voice / gesture / physical) is likewise a
render-time binding of the control, not part of it (§5).

---

## §3. Public function surface

Signature notation matches [`cx-stdlib/io`](../std-lib/io.md) /
[`http.md`](../std-lib/http.md). `::element` is a `[xap-runtime]` handle, a
`[component]`, a `[surface]`, an `[intent]` (`[do …]`), or a view-tree node;
`::map` is an options record; a trailing `$opts::map {}` is a **defaulted
positional parameter** (`grammar.ebnf [153b]` — bare space-separated VALUE after
the type, [`http.md`](../std-lib/http.md) §3.1), so it may be omitted. An
optional read that may be absent is typed `[returns element]` and yields the
**absence channel** (empty) when nothing is present (SAP §1).

### §3.1. Runtime lifecycle (impure)

```
[?def run    scope=public impure [returns element] ($opts::map {}) ...]
[?def serve  scope=public impure [returns element] ($url::string $opts::map {}) ...]
[?def close  scope=public impure [returns null]    ($runtime::element) ...]
```

`run` wires a `[xap-runtime]` (bus + journal + authz + sessions) for one tenant
and registers the components/surfaces/handlers in `opts`; **no network access at
construction**. `serve` runs that runtime over a real socket by bootstrapping the
`[?http-service]` directive / `[$http:serve]` engine (§9). `close` is
**idempotent**: it drains the bus, flushes the journal, releases sibling handles.
`opts` (every key is also accepted by `serve`):

| Key | Default | Meaning |
|---|---|---|
| `tenant` | — | the tenant this runtime partitions (§22.6); required |
| `journal` | new `store`-backed | the `[$journal:open …]` handle (or its opts) the runtime folds over ([`journal.md`](../std-lib/journal.md)) |
| `authz` | new context | the `[$authz:context …]` (principals + grant store) the PEP resolves against ([`authz.md`](../std-lib/authz.md)) |
| `sessions` | new registry | the `[$session:registry …]` handle ([`session.md`](../std-lib/session.md)) |
| `components` | `[]` | components registered at start (`[$xap:component …]` values, §4.2) |
| `surfaces` | `[]` | named surfaces (`[$xap:surface …]` values, §4.3) |
| `handlers` | `[]` | intent handlers (`[$xap:on …]` registrations, §4.5) |
| `resolver` | `:scripted` | the resolver impl (§20) — `:scripted` (default), a `[component]`-emitting closure, or an external LLM resolver handle |

### §3.2. Data constructors (pure)

```
[?def component scope=public pure [returns element] ($name::string $opts::map) ...]
[?def surface   scope=public pure [returns element] ($name::string $panels::element $opts::map {}) ...]
[?def panel     scope=public pure [returns element] ($component::string $opts::map {}) ...]
[?def fold      scope=public pure [returns element] ($component::element $slice::element) ...]
```

All four are **pure** — referentially transparent, capability-free, returning CX
data values (§2.4). `component` builds the §5 typed triple; `surface` composes
placed `panel`s (CXPath-scoped nesting); `panel` places a registered component
into a surface; `fold` evaluates a component's pure `[view …]` projection over a
state `slice` to a view tree (no journal, no network — the projection only).

### §3.3. State (impure read over the journal)

```
[?def state scope=public impure [returns element] ($runtime::element $cxpath::string) ...]
```

`state` returns the **fold over the journal** (§14) projected
by `$cxpath` — the server-authoritative slice *now* (the live truth a handoff
brief reads from, §21.1). It delegates to `[$journal:fold …]`;
xap holds no state of its own. Impure because it reads the live log; the result
is a **present value** (empty node-set for an empty slice, never `null`).

### §3.4. Intent registration + the committed cascade (impure)

```
[?def on    scope=public impure [returns null]    ($runtime::element $pattern::element $handler) ...]
[?def emit  scope=public impure [returns element] ($runtime::element $intent::element $opts::map {}) ...]
[?def after scope=public impure [returns element] ($runtime::element $dur::duration $intent::element) ...]
```

- **`on`** registers `$handler` for `[do …]` intents matching `$pattern` — it is
  a **thin wrap of `[$bus:on …]`** ([`bus.md`](../std-lib/bus.md)) plus the
  cascade discipline: the handler runs in step 3 of §2.1, and any intent it emits
  re-enters the cascade (step 4) and is journaled before the next external
  message. xap adds the ordering + PEP coupling; `bus` owns subscription.
- **`emit`** runs the §2.1 cascade for one intent: **PEP check (`[$authz:check]`)
  → journal append (`[$journal:append]`, the commit point) → ordered bus dispatch
  (`[$bus:emit]`) → sub-emission recursion**. It returns the committed **event**
  value (with its commit-order index + recorded authority basis); a PEP denial
  returns `[err code=cx-err:CXER4850]` and appends nothing (§2.2); a subscriber
  rejection appends a rejection event and surfaces a flowing `[err]` (§2.3).
  `opts.actor` / `opts.authority` name the emitter + grant basis (default: the
  `opts.session`'s principal); `opts.dry-run=true` runs the cascade against
  `[$journal:replay]` **without committing** (the §22.10/§20 dry-run — deterministic
  over log + policy stack), returning the would-be event(s) for preview.
- **`after`** schedules `$intent` to be emitted after `$dur` via the http timer
  enhancement (§0); returns a cancelable timer handle. Used for incapacity
  windows (`no-ack-within "10m"`) + lifecycle (§25.1). A
  scheduled emit re-enters the cascade like any other.

### §3.5. Content-negotiated render (pure)

```
[?def render scope=public pure [returns element] ($surface::element $opts::map {}) ...]
```

`render` materializes a `[surface]` for one medium/representation — the §2.5
content-negotiation step. **Pure** (a deterministic projection of the data
value): no journal, no network, no capability. `opts`:

| Key | Default | Meaning |
|---|---|---|
| `accept` | `"text/html"` | `"text/html"` → HTML fragment (controls bound inline, via `[$html:serialize]` + `[$html:sanitize]`); `"application/cx"` → the view-tree value, controls as `[do …]` data (the agent leg, §2.5) |
| `modality` | `:default` | the per-principal control-trigger binding (§15) — render-time only; the control + its `[do …]` intent are unchanged across modalities (agent-parity) |
| `context` | `{}` | the resolver's context projection (§20) the renderer reads for modality + foreground/periphery placement |

`render` to `application/cx` is the **identity-preserving** leg: the returned
view tree round-trips losslessly (the agent reads exactly what the HTML leg
renders from). HTML escaping/sanitization is delegated wholly to `html`
(§0); xap supplies no markup.

### §3.6. The resolver / Radar hook (impure)

```
[?def resolve         scope=public impure [returns element] ($runtime::element $context::element $opts::map {}) ...]
[?def resolver-default scope=public pure  [returns element] ($rules::element) ...]
```

`resolve` is the **context→composition** entry (§19): it asks
the runtime's configured resolver to compose a surface (relevance / ranking /
placement / layering) for the given `$context`, records its decision as a journal
event **with `:reason`** (so a nondeterministic judgment is auditable + replayable,
§19/§20.1), and returns the composed `[surface]` (or the
**absence channel** when nothing meets threshold). The resolver itself is
**pluggable** — `:scripted` (the default, built by `resolver-default` from
declared `$rules`), a CX closure, or an external LLM resolver handle (§20); xap
defines the **interface + trust-ramp/attention-tier hooks**, not the judgment.
`opts.tier` requests a foreground/peripheral/queued placement bounded by the
§20.2 stakes gate; `opts.dry-run=true` runs the resolver on *predicted* events for
anticipatory speculative composition (§19, §20) without
committing.

### §3.7. The dial / RACI surface — thin authz wrappers (impure)

```
[?def dial          scope=public impure [returns element] ($runtime::element $scope::element $setting::element) ...]
[?def grant-guardian scope=public impure [returns element] ($runtime::element $grant::element) ...]
[?def revoke         scope=public impure [returns null]    ($runtime::element $delegation::string) ...]
[?def why-allowed    scope=public impure [returns element] ($runtime::element $intent::element $opts::map {}) ...]
```

These are **thin wrappers issuing authz delegations** (§21) —
"sliding the dial *is* issuing / adjusting / revoking a delegation at the chosen
scope" (§21.3, one mechanism, no new primitive). xap adds **no authority logic**:

- **`dial`** sets the operational-control mode (manual / turn-by-turn / watch-the-map
  / semi-auto / full-auto, §21.1) at any node of the
  `action ⊂ capability ⊂ surface ⊂ group ⊂ principal-default` scope hierarchy
  (§21.3, most-specific-wins), by calling `[$authz:delegate …]` — the delegation is
  scoped, attenuating, time-bounded, revocable. RACI assignments more expressive
  than the 1-D presets (§21.4) pass through to authz directly. The setting is
  **clamped to the principal's envelope** (`effective = individual ∩ ⋂envelopes`,
  §21.5/§21.6 most-restrictive-wins) — xap forwards; authz computes.
- **`grant-guardian`** issues a guardian grant (§22.4) via
  `[$authz:grant-guardian …]`; well-formedness (≥ 1 will-independent
  falsifiable-by-presence incapacity predicate, refusal-triggers unexpressible,
  signing tier) is **enforced by authz** (§22.5/§22.8) — xap surfaces the
  authoring-time `[err]` (a malformed gate → `[err]` from authz, propagated;
  xap stamps no guardian semantics).
- **`revoke`** revokes a delegation/grant by id via `[$authz:revoke …]`
  (delegations are revocable, §22.2).
- **`why-allowed`** answers "why can/can't actor X emit intent Y" — a **query over
  the log + policy stack at that instant** (§22.10 answer 4),
  delegating to the authz dry-run decision function; returns the deciding
  delegation chain (or the denying envelope). Deterministic (log + policy are pure
  data), so it is a regression-gated conformance query.

### §3.8. Project scaffolder (impure, lib fn behind the CLI)

```
[?def init scope=public impure [returns element] ($dir::string $opts::map {}) ...]
```

`init` is the §25.2 **project scaffolder** — the lib function behind `cx xap init`
/ `cx new xap`. It **lands CX data + code files** into `$dir`, each carrying
**instructional comments** ("set your IdP issuer here", "declare capabilities
here", "this dial defaults to manual — raise it when ready"). The project's XAP
*is* those files; the modules just run them (N-IMPL-1 — behavior in modules,
**configuration in CX files**, not baked into the library). It is **purely a
fetch-and-write harness with no new module of its own**: the template is pulled
from a **pluggable source** and written out (§10). `opts`:

| Key | Default | Meaning |
|---|---|---|
| `template` | `:default` | the bundled default scaffold, or a named template |
| `source` | `:bundled` | `:bundled` (in-tree default), `[file PATH]` (local dir, via `io`), `[http URL]` (tarball, via `http`), `[git URL]` (clone, via `process` git) — additional fetchers behind the same interface (§25.2) |
| `tenant` | `"example"` | the tenant name stamped into the scaffolded config |
| `force` | `false` | overwrite an existing non-empty `$dir` (default: refuse → `CXER4858`) |

`init` returns a manifest of written files (paths + bytes). It requires the
capability of whichever fetcher the `source` selects (`io` for `[file …]`, `net`
for `[http …]`, `process` for `[git …]`) plus `io` to write the tree — no new
xap capability (§6).

---

## §4. Semantics & guarantees (soundness)

### §4.1. The cascade is synchronous, serialized, and log-coupled (N-CORE-1)

`[$xap:emit]` and the handler re-entry of `[$xap:on]` MUST follow the §2.1 order:
**PEP check → journal append (commit point) → ordered bus dispatch →
sub-emissions appended before the next external message**. The journal append is
the point that assigns total commit order **within the intent's stream** (§14.2);
dispatch order among subscribers is the `bus`'s defined order. An async/mailbox
bus is rejected (§14, §26): xap never offers a mode where a subscriber's emission
commits *after* a later external message **on the same stream**. Concurrent
external intents on the **same slice** (hence the same stream — human + agent,
Appendix B step 6) are **serialized by that stream** — first-committed wins, the
second commits as a rejection event with a flowing `[err]` (§2.3); intents on
**disjoint** streams commit in parallel (§14.2).

### §4.2. The PEP gates every intent; nothing un-granted commits (N-TRUST-1)

No intent is appended without an admitting `[$authz:check …]` (§2.2). Authority
originates only from principals (§22, N-TRUST-1); xap holds
none. A denied intent → `CXER4850`, no append, logged at the authz layer. The
**bright line is enforced by authz's typed gate** (§22.5,
N-CONTROL-1) — xap cannot express a refusal-triggered grant because
`grant-guardian` forwards verbatim to authz, which rejects it at authoring. xap
adds no path around the PEP.

### §4.3. State is a deterministic fold; reads are live and present (N-CORE-1)

`[$xap:state]` is a pure-relative-to-the-log fold (§14) — same
log ⇒ same state (replayable, dry-runnable, hashable). The result is a **present
value** (empty node-set for an empty slice, never `null` — SAP §1). A handoff
brief's "current state" (§21.1) subscribes to its slice via the
event-feed (§9), so it reflects truth, not stale memory.

### §4.4. Content negotiation preserves controls + agent-parity (N-CLIENT-1)

`[$xap:render]` MUST emit **the same controls** in both representations: HTML
binds them inline for the human; `application/cx` carries them as `[do …]` data
for the agent — both fire the **identical** intent (§2.5). No client vocabulary
leaks upward (N-CLIENT-1, §23): the view tree is the contract;
HTML is one materialization. Modality is a render-time binding (§3.5) — the same
control, a different trigger per principal, the same intent the agent emits.

### §4.5. The resolver is pluggable; its decisions are auditable, never authoritative (§19, §20)

`[$xap:resolve]` records every surfacing decision as a journal event with
`:reason`, `:capability`, `:level`, and `:context-class` — so "why did this
surface?" is answerable and replayable (§20.1). The resolver's
*judgment* is nondeterministic (scripted or LLM); its *governance* is not: the
**trust ramp** (levels 0–3 peripheral reach, §20.1) and the
**attention tiers** (T0–T5 interruption, §20.2) bound what a resolution may do —
**both gates required for a foreground interruption, except T0** (pre-authorized
guardian, bypasses the ramp). xap enforces the gate composition; the resolver
proposes within it. The resolver **never holds authority** — a proposed dial
setting or guardian action still passes the §4.2 PEP.

### §4.6. `init` writes a project, not configuration-in-the-library (N-IMPL-1)

`[$xap:init]` MUST land the project's behavior-bearing config as **ordinary CX
files** in `$dir` (§25.2), never bake it into the library: the
modules ship *behavior*, the template ships *the configured project*. The fetcher
is pluggable (§3.8); `init` is a harness with **no new module**. A `..` or absolute
escape in a template path → `CXER4858 E_XAP_INIT_INVALID` (containment); an
existing non-empty `$dir` without `force` → `CXER4858`.

### §4.7. Handle lifecycle
`[xap-runtime]` carries the closeable contract (§2.1): `[?with-open]`-able,
idempotent `close`, never raises `CXER0108`. Close drains the bus + flushes the
journal + releases the sibling handles it owns; an op on a closed runtime →
`cx-err:CXER4859 E_XAP_RUNTIME_CLOSED`.

## §5. The component triple — the §5 worked example (normative shape)

`[$xap:component]` returns the §17 typed triple as a **pure data
value** (§2.4) — not a directive, not opaque code:

```cx
[$xap:component order-card
  {props {order ::ref  compact ::bool}                  ; typed inputs (slice-in)
   bind /orders[?[= @/id $props/order]]                 ; CXPath state-slice it reads
   emits [[do :open $_] [do :cancel $_]]                ; the controls it offers (intent-vocabulary-out)
   view [?def [$o] …view-tree…]                         ; pure projection (view-tree-out)
   working-panel :none}]                                ; :none = a plain view; or a [kind …] for the 5%
```

- **`props`** — typed inputs (the §5 typed triple's input arm).
- **`bind`** — the CXPath state-slice the component reads (composes with the
  capability's read-slice, §17/§22.2).
- **`emits`** — the `[do …]` intent vocabulary the panel offers; **a control set
  *is* a capability set** (§17/§18.1/§22), so agent-operating a
  panel = holding delegated capabilities for its controls.
- **`view`** — the **pure** projection from slice to view tree (medium-agnostic,
  §2.5).
- **`working-panel`** — `:none` for a plain **view** (the thin 95 %), or a
  `[kind …]` for an interactive **working panel** (the 5 %, §18) declaring one of the v1 kinds (`data-grid`, `board`, `canvas/graph`,
  `chart-with-brushing`, `inline-editor`) with its `(read-model,
  control-vocabulary)` contract (§18.1), or the generic mount.

A placed instance is a **panel** (`[$xap:panel order-card {order: $id}]`); a
composition of panels is a **surface** (`[$xap:surface …]`). A panel **has
identity** → an addressable fragment endpoint bound to a slice; when the slice
changes, the cascade re-renders that panel and the feed out-of-band-swaps it
(§17, §18). The working-panel↔page shared-state seam is dissolved
**by the bus** (§18): one committed intent fans out as both an
OOB fragment swap (thin parts) and a slice-event (the working panel).

## §6. Capability integration

Gated by the **existing** capabilities of its siblings — **no new capability**
(§0):

| Operation | Capability | Resource matched |
|---|---|---|
| `run` | — *(wires handles)* | none at construction (defers to the journal/authz/session handles' own caps) |
| `serve` | `net` (via `http`/`[?http-service]`) | the bind `host:port` ([`http.md`](../std-lib/http.md) §5) |
| `emit` / `on` / `after` / `resolve` / `state` | inherited from `journal` (`store` backend) + `authz` (`crypto`) | the runtime's tenant-rooted slice namespace (§22.6) |
| `dial` / `grant-guardian` / `revoke` / `why-allowed` | inherited from `authz` | the delegation/grant store |
| `init` | `io` (write) + the `source` fetcher's cap (`io` / `net` / `process`) | `$dir` + the template source |
| `component` / `surface` / `panel` / `fold` / `render` / `resolver-default` | — | **pure** (§2.4, §3.2, §3.5) |

A PEP denial inside the cascade surfaces `cx-err:CXER4850 E_XAP_UNAUTHORIZED`
(§2.2); an *effect* denial (e.g. `serve` without `net`) surfaces the underlying
`cx-err:CXER0271 E_CAP_DENIED` from the effect point (http/io/process), **not**
remapped — xap introduces no capability of its own and never masks the sibling's
denial. **Cancellation + revocation** follow SAP §5.2: a cancelled `serve`/`emit`
at a cancellation point reports the core `CXER0260`; `[?with-open]` close runs
under restored caps.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | `text/html` render | `application/cx` render | non-screen medium |
|---|:--:|:--:|:--:|
| `render` a view surface | ✅ | ✅ | ✅ ¹ |
| `render` a working-panel surface | ✅ | ✅ ² | ✅ ¹ |
| control / `[do …]` intent carried | ✅ | ✅ | ✅ ¹ |

| Operation | scripted resolver | closure resolver | LLM resolver |
|---|:--:|:--:|:--:|
| `resolve` (compose surface) | ✅ | ✅ | ✅ ³ |
| anticipatory dry-run (`opts.dry-run`) | ✅ | ✅ | ✅ ³ |

| Operation | manual / turn-by-turn / watch-map | semi-auto / full-auto | guardian |
|---|:--:|:--:|:--:|
| `dial` (issue delegation) | ✅ | ✅ ⁴ | — ⁵ |
| `grant-guardian` | — ⁶ | — ⁶ | ✅ ⁵ |

| Operation | bus dispatch mode |
|---|:--:|
| synchronous serialized cascade (§2.1) | ✅ |
| async / mailbox dispatch | ❌ ⁷ |

| Operation | SSE feed (held-open) | one-shot HTTP |
|---|:--:|:--:|
| `serve` event-feed + slice-feeds | ✅ ⁸ | ✅ |

| Transport feature | client | server |
|---|:--:|:--:|
| WebSocket bidirectional / CRDT collab | ❌ ⁹ | ❌ ⁹ |

Footnotes: **1** a surface is medium-agnostic (§13.2) — HTML/CX
are two renderers; speech/haptic/physical media materialize the *same* view tree
(Appendix C). **2** the working panel's `(read-model, control-vocabulary)` is the
agent's view — the agent operates it via `[do …]` data, never pixels (§18.1). **3** the resolver interface is impl-pluggable (§20); the LLM leg is the
real-use, **empirically-unproven** prediction-accuracy gate (§20, §26) — supported by interface, gated by evidence. **4** semi-/full-auto is a
scoped attenuating delegation clamped to the envelope (§21, authz). **5** the dial
spans manual↔auto; **guardian is a separate regime** (a pre-authorized grant,
§21.2), so `dial` does not issue guardian and `grant-guardian`
does not set a dial mode — distinct surfaces, no overlap. **6** `dial` never
authors a guardian grant (the bright line, §22.5). **7** an
async bus breaks replay/determinism — **rejected** (N-CORE-1, §14, §26); pinned by a negative fixture. **8** held-open `text/event-stream`
requires the http **streaming amendment** (§0); until it lands, the bridge shell
supplies SSE (§24) — same CX core. **9** WebSocket/CRDT is
out of scope v1 (§27 — SSE-only); pinned by a skip fixture.

Cognate-coverage: every render leg emits the same controls (agent-parity); every
resolver impl satisfies the same interface + governance gates; every dial setting
is the same delegation mechanism. The intentional asymmetries (async bus,
WebSocket/CRDT, the dial/guardian split) are justified above and pinned by
negative/skip fixtures — each a **documented limit of this revision**, not an open
cell.

## §8. Error codes — `CXER4850–CXER4949` band (proposed allocation)

`CXER4850–CXER4949` is the **proposed allocation** for `cx-xap` in the
governance registry ([`governance.md`](../process/governance.md) §9.6) — the next
free block above `cx-stdlib/http`'s `CXER4525–4543` (the `4544–4849` gap is left
unallocated for net/http growth + the bus/journal/authz/session siblings, which
claim their own bands at their graduations). This revision uses
`CXER4850–CXER4862`. All values use `cx-err:` notation; symbolic↔wire is 1:1
(governance invariant). **Cancellation is the core `CXER0260`, not an xap code**
(§6).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4850` | `E_XAP_UNAUTHORIZED` | the PEP (`[$authz:check]`) denied an intent in the cascade; nothing appended (§2.2) |
| `cx-err:CXER4851` | `E_XAP_INTENT_REJECTED` | a subscriber rejected an admitted intent; the rejection event + flowing `[err]` (§2.3) |
| `cx-err:CXER4852` | `E_XAP_COMPONENT_INVALID` | `component` with a missing/ill-typed arm (`props`/`bind`/`emits`/`view`/`working-panel`) (§5) |
| `cx-err:CXER4853` | `E_XAP_SURFACE_INVALID` | `surface`/`panel` referencing an unregistered component or a malformed placement (§3.2/§5) |
| `cx-err:CXER4854` | `E_XAP_SLICE_INVALID` | `state`/`fold` with an unparseable CXPath or an out-of-tenant slice (§3.3, hard partition) |
| `cx-err:CXER4855` | `E_XAP_RENDER_UNSUPPORTED` | `render` `accept` outside `{text/html, application/cx}`, or a medium binding with no renderer (§3.5) |
| `cx-err:CXER4856` | `E_XAP_RESOLVER_FAILED` | the configured resolver impl faulted or returned a non-`[surface]` value (§3.6/§20) |
| `cx-err:CXER4857` | `E_XAP_DIAL_INVALID` | `dial`/RACI setting outside the principal's envelope, or a malformed scope node (§3.7/§21 — clamp violation) |
| `cx-err:CXER4858` | `E_XAP_INIT_INVALID` | `init` path containment violation (`..`/absolute escape), non-empty `$dir` without `force`, or unfetchable template source (§3.8/§4.6) |
| `cx-err:CXER4859` | `E_XAP_RUNTIME_CLOSED` | op on a closed `[xap-runtime]` handle (§4.7) |
| `cx-err:CXER4860` | `E_XAP_CASCADE_FAULT` | journal write failure or PEP unavailable mid-cascade — a genuine fault, not a rejection (§2.3) |
| `cx-err:CXER4861` | `E_XAP_TENANT_VIOLATION` | a cross-tenant slice/grant reference (the hard partition, §22.6) |
| `cx-err:CXER4862` | `E_XAP_FEDERATION_VIOLATION` | a cross-**XAP** data reference *other than* via a delegated intent — e.g. a `state`/`fold` reaching into another XAP's journal (the data partition, §22.6.1; cross-XAP effects MUST be delegated intents, not direct reads) |

**Shared/core/sibling codes xap surfaces (not in its band):** `cx-err:CXER0271`
(effect-capability denial from http/io/process — `serve`/`init`, §6, **not**
remapped); `cx-err:CXER0260` (cancellation, §6); `cx-err:CXER0108` never raised
(the runtime is closeable, §2.1/§4.7). **Sibling faults propagate as-is, not
remapped** — guardian-gate well-formedness `[err]`s from `authz` (§22.5/§22.8), journal integrity faults from `journal`, session-token faults from
`session`, HTTP faults from `http` (`CXER45xx`), HTML faults from `html`
(`CXER39xx`). xap re-implements none of those, so it surfaces but does not own
them (N-IMPL-1).

## §9. Implementation notes (non-normative) — composing the four siblings + `[?http-service]`

| xap surface | Building block | Wiring needed |
|---|---|---|
| `run` | open `journal` + `authz` + `session` handles; register handlers on `bus` | one `[xap-runtime]` per tenant; the cascade discipline (§2.1) bound around `bus` dispatch |
| `emit` / `on` cascade | `[$authz:check]` → `[$journal:append]` → `[$bus:emit]` | the synchronous, ordered, log-coupled drive (N-CORE-1); sub-emission recursion before the next external message |
| `state` / `fold` | `[$journal:fold]` + CXPath | tenant-rooted slice namespace; live read |
| `render` (html) | `[$html:serialize]` + `[$html:sanitize]` | controls bound inline; no markup logic in xap |
| `render` (application/cx) | the canonical view-tree value | identity-preserving round-trip (agent-parity) |
| `resolve` | the configured resolver (`:scripted` rules fold / closure / LLM handle) | record decision events with `:reason`; gate by trust ramp (§20.1) + attention tiers (§20.2) |
| `dial` / `grant-guardian` / `revoke` / `why-allowed` | `[$authz:delegate]` / `[$authz:grant-guardian]` / `[$authz:revoke]` / authz dry-run | clamp to envelope (authz computes `effective = individual ∩ ⋂envelopes`); xap forwards |
| `serve` | the `[?http-service]` directive / `[$http:serve]` engine ([`http.md`](../std-lib/http.md) §3.5) | bootstrap onto the existing directive; SSE feed via the streaming amendment (§0) or the bridge shell until it lands |
| `after` | the http picoev timer enhancement (§25.1) | cancelable scheduled emit re-entering the cascade |
| `init` | `io` write + a pluggable fetcher (`io` dir / `http` tarball / `process` git) | fetch-and-write harness; instructional-comment CX files; no new module |

**`[$xap:serve]` bootstraps on the EXISTING directive — no bespoke runtime.**
`serve` does **not** open a socket; it constructs the `[?http-service]` definition
([`code.md`](../core/code.md) §10.3) whose `$handler` runs the cascade and whose
`[resource]` routing maps request paths to surfaces, then runs it on the
`[$http:serve]` picoev engine ([`http.md`](../std-lib/http.md) §3.5, §9).
The authoritative event-feed + working-panel slice-feeds are **SSE** (§16, §18, §24): one-way server push over `text/event-stream`, which the http
**streaming amendment** (§0) supplies as held-open fds; **until it lands the
bridge shell supplies SSE** (Appendix D) — the swappable
transport, the CX core identical (the §23 bridge-then-native discipline). The
process topology (§14.1) — control-plane gateway + per-tenant
workers — is a deployment concern of the `--role app` binary, not this module's
surface.

Spec is implementation-agnostic; only surface + guarantees are normative. This
records *how* xap meets them by wiring the siblings — it adds no engine.

## §10. Conformance fixtures (to author on graduation)

Hermetic, in-process where possible (`port=0` / `cx-test://`, [`http.md`](../std-lib/http.md) §10);
loopback only where a socket is needed. **Every matrix ✅ has ≥1 positive fixture;
every justified ❌ a negative/skip fixture.**

Positives: `component` builds the §5 triple (round-trips as data); `surface`/`panel`
compose + a panel resolves to an addressable slice-bound fragment; `fold` projects
a slice to a view tree (pure); **`emit` runs the cascade in order — PEP check →
append → ordered dispatch → sub-emission appended before the next external
message** (commit-order asserted against the journal); **concurrent human+agent
intents on one slice serialize — first commits, second is a rejection event with a
flowing `[err]`** (Appendix B step 6); `state` reflects the live
fold (present empty node-set for an empty slice, never `null`); **`render` to
`text/html` and to `application/cx` emit the same controls** (agent-parity, §2.5)
+ a non-screen modality binding (the Appendix C readout); `resolve` composes a
surface + **records a decision event with `:reason`** (auditable/replayable) +
anticipatory `dry-run` over predicted events without committing; the trust ramp
(0–3) + attention tiers (T0–T5) gate a foreground interruption (both gates
required, T0 bypasses); **`dial` issues a delegation clamped to the envelope**
(most-restrictive-wins) + `revoke` revokes it + `why-allowed` returns the deciding
chain (deterministic query); `grant-guardian` issues a well-formed guardian grant;
`serve` bootstraps `[?http-service]` (in-process happy path) + an SSE feed leg
(via the bridge until the amendment lands); `init` lands the default scaffold (CX
files with instructional comments) from each fetcher (`io` dir / `http` tarball /
`process` git). **Stream model + clients (the rulings of §28.2):** the **§14.3
battery** validates per-aggregate streams (per-stream order, disjoint-stream
parallelism, conflict→rejection, recoverable cross-stream choreography, replay
determinism, hash-chain integrity); **federation** — a parent XAP composes a
child's surface through a delegated session and a cross-XAP effect commits as a
**delegated intent** (never a direct cross-journal read, §22.6.1); **multi-client
sync** — one committed intent re-materializes on two attached clients (web over
SSE/bridge + TUI over the in-process `bus`, §16); **CLI render** — a one-shot CLI
materializes a surface to text from `application/cx` (the §16 floor client).

Negatives: PEP denial → `CXER4850`, **nothing appended** (assert log unchanged);
subscriber rejection → `CXER4851` + appended rejection event; malformed component
arm → `CXER4852`; surface referencing an unregistered component → `CXER4853`;
out-of-tenant / unparseable slice → `CXER4854` / `CXER4861`; a cross-XAP **direct
journal read** (not a delegated intent) → `CXER4862` (§22.6.1); `render` `accept`
outside the two media → `CXER4855`; resolver returns a non-`[surface]` → `CXER4856`;
**`dial` outside the envelope → `CXER4857`** (clamp); guardian gate with **no
incapacity predicate / a refusal-trigger → propagated `[err]` from authz**
(§22.5, not an xap code — assert it is *unexpressible*); `init`
`..`/absolute-escape or non-empty dir without `force` → `CXER4858`; op on a closed
runtime → `CXER4859`; mid-cascade journal/PEP fault → `CXER4860`; **async/mailbox
bus dispatch requested → rejected (no such mode)** — negative fixture pinning
N-CORE-1; **WebSocket/CRDT serve leg → skip-with-rationale** (§27). Inherited effect denials (`serve` without `net`, `init` without the fetcher
cap) → `CXER0271` exercised through http/io/process.

## §11. Graduation checklist (executor → user G3)

- [ ] **Empirical resolver-accuracy gate** (§20, §26) — the
      one **on-real-use** gate before graduation: the resolver's *prediction
      accuracy* over time. On-paper completeness is not sufficient.
- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      register `CXER4850–CXER4949 | cx-xap | spec/03-approved/xap/xap.md` under a **`cx-xap`
      subsystem** entry (not under `cx-stdlib`); re-run the band scan (confirm no
      overlap with http's `CXER4525–4543`).
- [ ] **Package registration (see §12) — NOT a stdlib count bump.** `cx-xap` is its
      **own bundled package**, parallel to `cx-stdlib`: add the `bundled:<version>`
      lockfile shape + `[?lib 'cx-xap']` resolution, and add `'cx-xap'` to the
      bundled-**package** list in `vcx/tests/v08_stdlib_skeleton_test.v` (distinct
      from the `cx-stdlib/*` list). **Do not** add an `xap` row to the `cx-stdlib`
      README or bump its 37-module count — `cx-xap` is not a stdlib module.
- [x] **The primitives have graduated** (hard dependency — xap composes them):
      `cx-stdlib/bus`, `cx-stdlib/journal`, `cx-stdlib/authz`, `cx-stdlib/session`,
      `cx-stdlib/sched` are all in `03-approved/std-lib` (Tier D).
- [ ] **The http SSE / streaming amendment** ([`http.md`](../std-lib/http.md))
      must land for the native event-feed path; until then the bridge shell
      supplies SSE (graduation MAY proceed on the bridge per §9, the §23
      bridge-then-native discipline).
- [ ] Implement the subsystem on the `cx-stdlib` primitives (bus/journal/authz/session/sched) + `html` + `[?http-service]`: the
      cascade (§2.1), the pure constructors (§3.2), `state`/`render`/`resolve`,
      the dial/RACI wrappers, `serve` (bootstrap on `[?http-service]`), and `init`
      (the fetch-and-write harness). **No reimplementation of a sibling** (N-IMPL-1).
- [ ] Confirm xap's reliance on the SAP (four-channel, `[?try]` retirement,
      `CXER0260` cancellation, orthogonality guard) survived its G3.
- [ ] Author §10 fixtures; wire into the gate (incl. the commit-order +
      agent-parity + envelope-clamp + cascade-rejection assertions).
- [x] Validate repo-relative cross-references render (siblings + amendments) —
      all 42 internal links re-depthed `../../03-approved/` → `../` at the move.
- [x] Graduate via the normal spec pipeline (user-only G3): moved
      `spec/02-working/xap/` → `spec/03-approved/xap/` (2026-06-09) and set the Status
      header to **Approved — design-frozen for v0.8.0**. `cx-xap` follows the standard
      pipeline like every other module — `02-working` while in development,
      `03-approved` once frozen. *(The design is frozen; the empirical gate above and
      the impl/registration items below stay OPEN — see the Status note.)*
- [ ] Each demo in `spec/03-approved/xap/demos/*` runs green on the implemented runtime
      (the demo READMEs' expected-output blocks become conformance checks).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states how the count moves and the **exact lines** that change at
graduation; per Rule G3 it makes **no edits**.

**The primitives are `cx-stdlib`; `cx-xap` is a separate bundled package — they
count differently.** The XAP runtime decomposes into (a) the **general-purpose
primitives** — `bus`, `journal`, `authz`, `session`, `sched` — which are
**`cx-stdlib` modules** (each a distinct bundled sub-package, +1 to the stdlib
count; **already graduated** — `cx-stdlib` README §3 is at 37, Tier D), and (b) the
**`cx-xap` orchestrator subsystem** (this spec), which is **not** a `cx-stdlib`
module and therefore **does not bump the stdlib count**. `cx-xap` is registered as
its **own bundled package** — parallel to `cx-stdlib`, not inside it.

| Target | At `cx-xap`'s graduation |
|---|---|
| `cx-stdlib` README §3 count / frozen-surface sentence | **unchanged** — `cx-xap` is not a stdlib module |
| `cx-xap` package registration | add the `cx-xap` **bundled package** (lockfile `bundled:<version>` + `[?lib 'cx-xap']` resolution); its own pipelined spec tree (`spec/02-working/xap/` → `spec/03-approved/xap/` at graduation) |
| bundled-name skeleton test | add `'cx-xap'` to the **bundled-package** list + its assert (distinct from the `cx-stdlib/*` list) |
| governance error registry | the `cx-xap` band (`CXER4850–…`, §8) registered under a `cx-xap` subsystem entry, not under `cx-stdlib` |
| `cx xap …` CLI subcommands | core binary commands (no registration as a lib) |

**The primitives' stdlib graduations already happened** (bus/journal/authz/session/
sched are in `cx-stdlib`, Tier D). This section now governs only **`cx-xap`'s
separate registration** as a bundled package + core CLI — no change to the stdlib
count. **No edits are made by this draft** (G3); the table is for the graduation PR.
---

# Part II — The XAP paradigm (normative architecture)

*The orchestrator module above (§0–§12) realizes the paradigm specified here. The
sections below were consolidated from the former `xap.md` design document; the
decomposition they describe — five `cx-stdlib` primitives (bus · journal · authz ·
session · sched) + the `cx-xap` orchestrator (this spec) — is the in-review stack
this spec sits atop. The normative model is settled;
the one remaining gate before graduation is empirical — real-use validation of the
resolver's prediction accuracy (§20, §26).*

- **Layer & shape:** XAP is the **experience layer** at the top of the CX web
  stack. It is **not a framework** — it is a small set of **thin CX stdlib
  modules** plus the *existing* `[?http-service]` routing directive; there is no
  bespoke runtime to adopt, only functions/commands you call to **create,
  extend, manage, and run** one or more XAPs in a CX process (§25). The whole
  thing is authored *in CX* — the flagship dogfood.

  ```
  net (L4 sockets)
    → http (L7 engine — picoev + picohttpparser)                      stdlib_http.md
      → [?http-service] / [resource] directives (routing/lifecycle/auth)  code.md §10.3
        → XAP = thin stdlib modules:  bus · journal · authz · session · sched · xap
                (authored in CX — NOT a framework; see §25)
  ```

- **Normative dependencies (must exist for a conforming XAP runtime):** the full
  module decomposition + the new modules/enhancements XAP requires are in
  **§25.1**; the capability-level summary:
  | Capability | Provided by | Status |
  |---|---|---|
  | Real-socket HTTP/1.1 listener + routing + lifecycle | `[?http-service]` / `[resource]` ([`code.md`](../core/code.md) §10.3) compiled onto `[$http:serve]` ([`http.md`](../std-lib/http.md) §3.5, §9) | http engine shipped; directive cutover in progress |
  | **SSE / streaming responses (held-open fds)** | http engine streaming surface | **NOT in http v1** ([`http.md`](../std-lib/http.md) §4.2 marks streaming out of scope) — see §24; the bridge shell supplies SSE until it lands |
  | State-slice query + capability scoping | CXPath ([`code.md`](../core/code.md)) | available |
  | Hash-chained log + signing | CX crypto module (hash, sign/verify) | available |
  | View-tree rendering to HTML | CX html module (serialize/sanitize) | available |
  | Surface / intent / grant validation | the two-validator model (structural + semantic) | available |

- **Does NOT compose with:**
  - A client-side SPA state model (React/Redux/signals) as the *app* spine. XAP
    is server-authoritative; client-side reactivity is scoped **inside working panels**
    only (§18), never the whole surface.
  - A bounded "app" navigation model. XAP is post-app: capabilities compose and
    surface per context (§19). "Apps" survive only as saved/pinned compositions.
  - A web client whose conventions leak upward into XAP. XAP is CX's layer
    **above** any client; the client is a swappable renderer (§23).

---

## §13. The paradigm

The bounded application — a container of features you navigate *to* — is
replaced by a **field of composable capabilities that surface per context**: the
principal does not go to an app; the right capability and its interface come to
them at the right moment ("Radar" — anticipate need and put the right thing in
front of the principal before they ask).

Nothing in the CX runtime defines an "app": there is a log, a bus, components,
intents, and an agent. Delete the "app" convention and what remains is exactly a
capability field. The **agent** — the peer that reads state-as-data and
assembles components from intent — is the composition layer: it continuously
composes the interface from the field in response to context.

**The 95 / 5 split is *within* every surface, not across surfaces.**
Line-of-business software is ~95 % data/workflow/audit/collaboration/security
(forms, tables, detail views, approvals, history) and ~5 % highly interactive
surface (a canvas, a grid, a live timeline). A conforming XAP runtime MUST let a
hypermedia-thin 95 % and a thick interactive 5 % coexist in one surface, on one
authoritative core, without forcing two stacks (§18).

### §13.1. Lexicon (normative terms)

The XAP vocabulary is small and deliberately *not* the vocabulary of the dead app
paradigm. Every term below is defined on its own footing — never as "like an app
but…" — and every term is **medium-agnostic** (§13.2): it names a *role*, not a
screen-thing.

> **The world in one sentence.** The **Radar** composes a **surface** of
> **panels** — **views** to perceive, **working panels** to work in, **controls**
> to act — and you **pin** the ones you keep.

**Everyday terms — what you perceive and say:**

| Term | Definition | Leaves behind |
|---|---|---|
| **Surface** | what's composed for you right now; **semantic, not pixels** — *what* is present, not *how* it shows up. | app / screen / page / view-of-an-app |
| **Panel** | a distinct part of a surface (a placed component instance, §17). | window / pane / card / widget |
| **View** | a panel that **presents** — the thin 95 %. | read-only screen / report |
| **Working panel** | a panel you **work in**, with its own local interaction loop — the interactive 5 % (§18). "Working" = you engage *in* it; it is **not** about holding focus (focus is the **foreground**, §20). | the rich/JS-heavy widget |
| **Control** | a part you **act through**; triggering one fires an **intent**. | button / link |
| **Summon** (v.) | explicitly call a capability up. | open / launch / navigate-to |
| **Pin** (v.) | keep a surface or name fixed so you return to it; pinned surfaces are your anchors (there is **no home screen** — §13.2, §19). | bookmark / favourite / home screen |

**The cast:**

| Term | Definition |
|---|---|
| **Principal** | the authority party — a human **or** an org/role — to whom authority traces. The **P in XAP**: final say, buck-stops-here. Load-bearing in the dial (§21) and trust (§22) models. |
| **Agent** | an artificial-intent peer that emits the **same** `[do …]` intents a principal emits, and acts as the **Radar** / composition layer. |
| **Radar** | the agent in its composing role: turns context into a composed surface and decides what surfaces where (§19). |

**Backstage terms — the architecture; rarely said to a principal:**

| Term | Definition |
|---|---|
| **Intent** (`[do …]`) | the unit of action itself, emitted identically by a principal (via a control) or an agent (as data). |
| **Capability** | the composable unit a panel comes from — a component triple (§17) + context-affinity; in the trust model, the right to emit certain intents / read certain slices (§22). |
| **The dial** | how much initiative the agent takes — the **operational-control** axis (§21). *(Disambiguation: "the dial" is the governance axis "who drives"; "a **control**" — above — is an element you act through. The two never collide because the governance text says "the dial" / "operational control", never "a control".)* |
| **Log** | the append-only, hash-chained record everything folds from (§14). |
| **Medium / materialize** | see §13.2. |
| **XAP interface** | the contact-layer artifact, when it must be distinguished from the felt experience. (XAP : interface :: UX : GUI.) |

**eXperience leads** (the medium — the UX/DX/CX family); **Agent in the middle**
(subordinate but indispensable — the Radar); **Principal in charge** (the
accountability invariant, §21, §22).

**Aliases (non-normative).** Each concept has **one normative term** (the bold
heads above) — that is what protocol, code, and conformance fixtures use. For
prose, UI copy, and per-medium phrasing, the following aliases are **blessed and
interchangeable**; they introduce no new concept. Register: *plain* = casual,
*medium* = fits non-screen media, *formal* = architecture register.

| Normative | Plain | Medium | Formal |
|---|---|---|---|
| **Surface** | the composition | — | composed surface |
| **Panel** | part, block | region, station, zone | component instance |
| **View** | readout | gauge, indicator, feed | presentation |
| **Working panel** | console | workbench, cockpit | interactive panel |
| **Control** | action | command, lever, handle | control point |
| **Intent** | a "do" | — | `[do …]` message |
| **The dial** | the throttle | — | operational control |
| **Summon** (v.) | call up, pull up | ask for | — |
| **Pin** (v.) | keep | anchor | — |
| **Materialize** (v.) | show up as | take form as | render |
| **Foreground** | the spotlight | front-and-centre | — |
| **Periphery** | the edge | ambient zone | radar zone |

In particular, **`view` is the normative head for a presenting panel; `readout`
is its blessed alias for non-visual media** (a spoken or tonal "wind readout" is
a view materialized in audio). **`medium` is never aliased to "channel"** —
*channel* is reserved for an attachable client transport (email/chat, §16).

### §13.2. A surface is medium-agnostic

> **N-MEDIUM-1.** A surface is **semantic** — it is *what* is composed (its
> panels, what they present, what they let you do), **never** *how* it is
> rendered. *How* it reaches a principal is the **medium**, and the same surface
> **materializes** differently per medium and per principal.

- **Medium** — whatever materializes a surface and carries interaction: a screen,
  yes, but equally **speech, haptics, a physical button set, a gesture, stepping
  through a door, ambient light, a car dashboard, a boat's tiller.**
- **Materialize** (v.) — to render a surface *into* a medium. *The same surface
  materializes as a screen layout for you, as speech for someone else, as a lit
  doorway in a building.*

Consequences, all already load-bearing elsewhere in this spec:

- A **control** is a semantic action-point; how it is *triggered* — a tap, a
  spoken word, a gesture, a physical button, a step through a door — is a
  **render-time binding of the medium**, not part of the control (§15, modality
  binding). "Press the button," "say the word," "make the gesture" are the *same*
  control firing the *same* **intent**.
- Because the surface is data, the **agent reads the identical surface** the human
  perceives — so **agent-parity holds across every medium**, not just screens
  (§15).
- New modalities (voice, AR, ambient, BCI) arrive as new **media** that
  materialize existing surfaces — **never as new paradigms**. This is the
  operational meaning of the terminal-paradigm claim (Appendix A.2): the paradigm
  is defined *above* the rendering layer.
- A worked, fully non-screen example is in **Appendix C** (a blind sailor sailing
  a boat with XAP, told entirely in this lexicon).

---

## §14. Core — server-authoritative, event-sourced, synchronous serialized bus

**State lives server-side as a fold over append-only, hash-chained event
streams** (the authority). This is the substrate the agent-preview and audit
stories require: each stream is **deterministic → replayable, dry-runnable,
hashable**. A **stream** is the unit of ordering and contention — an *aggregate*
(typically a principal, an entity, or a workspace, §14.2); within a XAP the
streams partition the tenant's state.

The bus is **pub/sub** — everything is a message; zero or many subscribers
respond — but committed through a **synchronous serialized cascade**:

1. each external message is appended to the log;
2. subscribers react in a defined order;
3. any messages they emit are appended and processed **before the next external
   message commits**.

> **N-CORE-1 (commit order is the system authority).** "Something is always in
> charge" = a stream's commit order. This is *system authority* (who owns
> state/truth/ordering), distinct from *operational control* (who drives — §21).
> Total order holds **within a stream**; across streams the journal is a
> **partial order**, made total only where an explicit cross-stream choreography
> links two events (§14.2).

Async actor mailboxes are **rejected**: nondeterministic ordering *within a
stream* breaks replay and reintroduces the "no single truth" drift.

*(Mechanically: pub/sub is the `bus` module and the log is the `journal` module
(§25.1); the synchronous serialized cascade is the composition rule `xap` applies
when wiring them — emit ⇒ `journal` append ⇒ `bus` dispatch in commit order. It is
not a separate primitive.)*

### §14.1. Process topology

`cx serve` is **one binary** (one C ABI, one `[?http-service]` implementation —
§25) run in distinct **roles** that are **separate processes** with separate
security, lifecycle, and failure boundaries — never co-mingled in one address
space:

- **`--role tooling`** — the developer daemon: localhost, single-developer, LSP
  + editor HTTP. Localhost-trust posture.
- **`--role app`** — the XAP application runtime: remote, authenticated,
  multi-tenant.

Co-mingling is forbidden: it would put localhost-trust code in the same address
space as remote-auth code, and couple lifecycles that must move independently.

**App-role internal topology (process-per-tenant — §22.7):**

- a **control-plane / gateway** process — terminates TLS, authenticates via the
  IdP (§22.1), routes each session to its tenant, supervises tenant workers
  (spawn / recycle / crash-recovery). It holds **no tenant state** — only
  routing + auth + supervision;
- **per-tenant worker** processes — each owns exactly one tenant's journal (its
  per-aggregate streams, §14.2) + bus + state; a worker crash cannot touch another
  tenant;
- a lighter **shared-worker logical-partition tier** co-locates small /
  low-assurance tenants behind one gateway — an opt-in density trade-off.

**Dev-time cooperation (design-time = run-time, §18.2).** When building a XAP, the
tooling daemon orchestrates a **local single-tenant app-runtime worker** for
live preview — a distinct, process-isolated child, *not* merged into the tooling
daemon. The authoring loop previews the real runtime.

### §14.2. Stream partitioning — how the cascade scales (R2)

The cascade is serialized **per aggregate stream**, not per tenant. A naïve
single-log-per-tenant reading serializes *every* principal's intents through one
cascade — a throughput ceiling at the hundreds-to-thousands of concurrent
principals a real XAP carries.

**The stream model is the journal's, not xap's** —
[`journal.md`](../std-lib/journal.md) §2.1.1 is its **definitional home** (per-stream
`seq`/chain/head, append serialized per stream, the `:default`-stream degenerate
case, the order-independent tenant-wide fold, snapshot-anchored tenant integrity).
xap does not define a parallel model; it **composes** that one: the §2.1 cascade
runs **per stream**, so an intent's journal-append (step 2) commits into *its*
stream and disjoint streams commit in parallel. N-CORE-1 holds **per stream**.

A single intent that spans streams (the rare cross-aggregate case) is **explicit
choreography**: it commits in its home stream and emits follow-on intents into the
others, each re-entering *that* stream's cascade — there is **no implicit
cross-stream transaction** (the journal offers per-stream atomicity only,
§2.1.1). Conflict *on one stream* resolves by §4.1 over the journal's per-stream
`expect-prev-seq` (first-commits-wins; the second is a rejection event with a
flowing `[err]`). Cross-XAP coordination (§22.6.1 federation) is this same rule one
tier up.

> **Scope + experiment gate.** Total order is only as wide as a unit of contention
> needs it — the stream, not the whole tenant. Replay / determinism / audit are
> preserved *per stream* (by the journal); cross-stream consistency is the
> application's explicit choreography, never a hidden global lock. The stream model
> is **drafted but not yet implemented in the journal** (the journal ships the
> single-`:default`-stream case today, [`journal.md`](../std-lib/journal.md) Status);
> it is **validated by the §14.3 battery** before it is trusted, and its journal-layer
> half is the journal's own per-stream fixtures (§10 there).

### §14.3. The R2 validation battery (experiment gate — runs before trust)

Per-aggregate streams (§14.2) trade a single global order for parallel per-stream
orders; that trade is **only safe if the partition cannot corrupt state or lose
the guarantees** N-CORE-1 makes per stream. §14.2 is therefore **gated on an
adversarial battery**, not on paper review — the "experiment along the way." It
extends the §10 conformance posture (hermetic, in-process, `cx-test://`) with a
**concurrency/corruption** dimension. The battery is **green before the stream
model is trusted**, and pinned as a standing regression once it is.

**Two layers, no overlap (N-IMPL-1).** The *journal-layer* properties — per-stream
order/chain/genesis, disjoint-stream parallel append, `expect-prev-seq` conflict,
order-independent composition, per-stream `verify`, snapshot anchoring — are the
**journal's** fixtures ([`journal.md`](../std-lib/journal.md) §10); xap does not
re-test journal internals. The properties below are the **xap-cascade layer** built on
them: that the §2.1 cascade *uses* per-stream commit correctly (PEP→append-on-the-right-
stream→dispatch), that cross-stream effects are explicit choreography, and that a
rejected stream-conflict surfaces as a flowing `[err]` (§2.3).

**Properties under test (each a fixture family):**

1. **Per-stream total order.** Concurrent intents on **one** stream commit in a
   single, replayable order; the hash chain for that stream is unbroken and
   verifies. (Strengthens §4.1.)
2. **Disjoint-stream parallelism + independence.** Intents on **distinct** streams
   commit concurrently and the result is **independent of interleaving** —
   replaying each stream in isolation reproduces byte-identical state (no hidden
   global ordering dependence leaked in).
3. **Conflict → rejection, never corruption.** Two intents racing the **same**
   slice on one stream: first commits, the second is a **rejection event with a
   flowing `[err]`** (§2.3/§4.1) — never a torn write, never a lost update, never
   a silent overwrite.
4. **Cross-stream choreography is explicit and recoverable.** A cross-aggregate
   intent that fails partway (home stream committed, the follow-on into stream B
   rejected) leaves **each stream individually consistent** and surfaces the
   `[err]`; there is **no implicit two-phase commit** and **no half-applied global
   state**. The compensating intent is itself a journaled event.
5. **Per-stream replay / dry-run determinism.** `[$journal:replay]` and
   `opts.dry-run` (§3.4) over a single stream are deterministic and match the live
   fold; a tenant-wide fold is the deterministic merge of its streams' folds.
6. **Hash-chain integrity under tampering.** A mutated/reordered event in any
   stream is **detected** (the chain fails to verify) — tamper-evidence is
   per-stream, not weakened by the partition.

**Adversarial generators:** randomized interleavings at the stream boundary;
fault injection at each cascade step (PEP up, append fails; append commits,
dispatch faults — assert `CXER4860` and **no partial stream state**); worker
recycle mid-cascade (durable timers + the stream re-fold survive, §25.1); a
fuzzed stream-routing key (assert no intent silently lands in the wrong stream →
`CXER4854`/`CXER4861`).

**Pass criterion:** all six families green across N randomized seeds with **zero**
corruption/lost-update/cross-stream-leak observations; any single failure **blocks
the §14.2 partition** (fall back to the single-stream-per-tenant reading until
fixed). This battery is a **graduation prerequisite** for any operations work that
assumes the partition (§28.3 D1).

---

## §15. Representation — hypermedia default + content negotiation

The default representation is hypermedia: the server renders surfaces and ships
fragments carrying their controls inline (HATEOAS). The same surface is
**content-negotiated** on `Accept`:

- `text/html` → HTML fragment with the human's controls bound inline;
- `application/cx` → the **view-tree value**, controls as `[do …]` data (the
  agent).

Same source, same controls, two representations. This is what makes the agent
operate at the semantic layer uniformly — it reads the view tree as data and
emits the **same** `[do …]` intents a human's gesture emits. It is also purer
HATEOAS than HTML-only: the representation tells *both* parties what they can do
next.

**Modality is a per-principal binding, not a fixed UI.** Because a control is
semantic data, the *input* that triggers it (hotkey, button, drag, voice) is a
render-time binding, not part of the control. The renderer binds controls
to the modality the principal prefers; the preference is context (§19) the
renderer reads. Same control, different trigger per person — and it is the
*same* control the agent emits as data (agent-parity). Content negotiation
thus extends from *representation* to *interaction modality*.

---

## §16. Clients — thin, attachable; one consistency contract

Clients **attach** to the runtime (the tmux model: the server owns session
state; clients attach/detach; the session survives client death). Multiple
clients MAY attach to one session — default **mirrored** (human + agent see the
same surface; §21 over-the-shoulder collaboration). Client *thickness* is a
representation/caching choice, **never an authority change**:

```
one-shot CLI (text in/out, no feed) → thin (HTML fragment)
  → view-tree-as-data (TUI / native / mobile / agent)
  → thick native w/ optimistic local apply → collaborative-editor w/ CRDT
```

All tiers use **one contract**: `intents-out` + `authoritative-event-feed-in`.
Thin clients render the feed; thick clients add optimistic-apply + reconcile;
the collaborative few add CRDT. **Authority never moves.**

**Shell ≠ client ≠ renderer (all medium-specific; the surface is not).** Three
layers sit below the medium-agnostic surface (§13.2), and the lexicon keeps them
distinct: the **shell** is the server-side transport (HTTP+SSE, or the in-process
`bus`); the **client** is the attached peer; the **renderer** is *how* that client
materializes a surface (htmx for the web client, a cell grid for a TUI, lines for
a CLI). "Web shell" is casual shorthand for *HTTP shell + browser client + htmx
renderer* — fine until a second client shares the runtime, which is exactly when
the three must be named apart.

**The event-feed is a §16 client-consistency primitive, independent of working
panels.** Cross-client live sync — act through a control on one client and every
attached client re-materializes — needs the **authoritative-event-feed-in**, with
or without any working panel (§18). A one-shot CLI needs **no** feed (it emits one
intent, renders once, detaches — request/response). Two *simultaneously attached*
clients that must stay consistent **do** need it. The feed's transport is per
client: **SSE** for the web client (gated on §24 / supplied by the bridge until it
lands); the **in-process `bus`** directly for a co-located TUI — no SSE — which is
the §23 "swappable transport, identical core" thesis made concrete.

**The client ladder (the reference XAP's on-ramp).** Clients are added
thinnest-first, each adding exactly one layer:
**one-shot CLI** (text in → `[do …]`, surface → stdout; no shell, no document, no
feed — runs on today's stack with zero deferred dependencies) → **web client**
(htmx renderer over an HTTP shell; adds the document shell + HTML medium +
optional SSE feed) → **TUI client** (cell renderer over the in-process `bus`; adds
the live feed and a long-lived attach). All three afford the **same
capabilities** — the same `[do …]` intents over the same surface (N-CLIENT-1); the
CLI is the floor because it is the thinnest renderer, not a lesser one.

**Channels are clients too.** A channel — email, chat, SMS, voice, an embedded
panel — is just another attachable client: a transport for intents-in and a
renderer for surfaces-out over the same bus contract. **Email is the v1
channel**; the rest plug in as adapters without touching the core (each maps the
channel's gestures to `[do …]` intents and renders surfaces into the channel's
representation — §15 generalized to non-HTTP transports). A channel is a
renderer, not a new paradigm.

---

## §17. Components — the typed triple

A **component** is the reusable, authoring-level definition behind a **panel**
(the everyday term — §13.1): a pure transform from a state slice to a view tree,
with a declared interface (slice-in, view-tree-out, intent-vocabulary-out), and a
declaration of whether its rendered panel is a plain **view** or a **working
panel** (the interactive 5 %, §18):

A component is created by the `[$xap:component …]` function (§25) and is just CX
data — the bracketed form below is the *value* it returns, not a bespoke
directive:

```cx
[$xap:component order-card
  [props {order ::ref  compact ::bool}]              ; typed inputs
  [bind /orders[?[= @/id $props/order]]]             ; CXPath state-slice it reads
  [emits [[do :open $_] [do :cancel $_]]]            ; the controls it offers
  [view [?def [$o] …view-tree…]]                     ; pure projection
  [working-panel :none]]                             ; :none = a plain view; or a [kind …] for the 5%
```

A placed instance of a component **is a panel** on a surface. Composition is
CXPath-scoped nesting. A panel **has identity** → it is an **addressable fragment
endpoint bound to a slice**; when the slice changes, the bus re-renders that
panel and out-of-band-swaps it. Because the component is **data** (not opaque
code), the agent reads, generates, and recomposes panels precisely — this
supplies the component model that bare hypermedia lacks.

---

## §18. Working panels — the 95 / 5 within one surface

A surface is hypermedia-thin (95 %) with declared **working panels** (5 %) — interactive
regions with a *local* reactive loop (the only place client-side MVU/signals
live, scoped). A working panel is declared in the view tree and bound to a state slice
by CXPath:

```cx
[working-panel :kind retry-timeline [bind /charges[?[in @/order $live-orders]]]]
```

The working panel subscribes to a **scoped** event-feed for its slice, applies
optimistically, reconciles against the log. The working panel↔page shared-state seam is
dissolved **by the bus**: one committed intent fans out as both an out-of-band
fragment swap to the thin parts and a slice-event to the working panel. A working panel is
**not a sandbox** — it is a subscriber+publisher like everything else, plus a
local render loop.

### §18.1. First-party working panel library + standard control contract

**The contract first.** Every working panel *kind* is a **typed interaction protocol**
= a `(read-model, control-vocabulary)` pair, both data:

- **Read-model** — the semantic state the working panel exposes (what the agent
  *sees*), a projection of the bound slice — **never pixels**. The human sees a
  rendered widget; the agent reads the same read-model.
- **Control-vocabulary** — the standard `[do …]` intents the kind exposes. A
  human triggers them by gesture; the agent emits the *identical* intents as
  data. **A control set _is_ a capability set** (§17/§22) — so agent-operating
  a working panel = holding delegated capabilities for its controls, and the dial
  / envelopes (§21) apply per-control.

Because the control shape is **standard per kind**, an agent that understands
`data-grid` operates *any* data-grid working panel in *any* surface — controls are
not relearned per surface. This is the payoff: the interactive 5 %,
historically the part most hostile to automation, becomes uniformly
agent-operable.

**Common baseline (every working panel):** `[do :select …]`, a read-model subscription
to its scoped feed, and the §16 optimistic-apply → reconcile contract.

**v1 set:**

| Kind | Read-model (agent sees) | Control vocabulary (`[do …]`) |
|---|---|---|
| **data-grid** | visible rows, column schema, sort/filter/selection state | `:sort`, `:filter`, `:page`, `:select`, `:edit-cell`, `:bulk`, `:export` |
| **board (kanban)** | lanes, cards per lane, positions | `:move-card`, `:reorder`, `:add-card`, `:edit-card` |
| **canvas/graph** | nodes `{id,label,pos,type}`, edges `{from,to,type}` | `:move-node`, `:connect`, `:disconnect`, `:add-node`, `:delete-node` |
| **chart-with-brushing** | data domain, current brush/selection, aggregates | `:brush`, `:select-points`, `:drill`, `:set-dimension` |
| **inline editor** | document structure/AST, cursor/selection | `:insert`, `:replace`, `:format`, `:apply-suggestion` |

The marquee case is **canvas/graph**: the agent moves "node A next to node B" by
emitting `[do :move-node …]` against the semantic read-model — it never renders
or parses pixels. The surface usually *most* hostile to automation becomes
agent-native.

**Collaborative editing** (the hardest 5 %) is the inline-editor / canvas under
CRDT (§16's thickest tier): the control vocabulary is unchanged; conflict
resolution is the client-thickness escalation, not a different contract.

**Beyond v1 (generic mount, or later promotion):** calendar/scheduler, geo-map,
tree/hierarchy editor ship via a **generic mount contract** until promoted to
first-party; promotion = standardizing their read-model + control vocabulary
the same way.

### §18.2. Authoring loop — "know-it-when-I-see-it" → agent precision

The human reacts to *rendered output* (fuzzy, visual); the agent edits the
*component-as-data* (precise). The bridge:

1. **Live preview** keeps instant feedback.
2. **Addressable nodes** — "make *that* bigger" (click/voice) resolves to a
   CXPath node the agent edits.
3. **Edits are intents on a component-document** — event-sourced, so
   rewind/branch is log navigation (taste iteration = time travel).
4. **Variants over single-shot** — the agent offers N versions; the human picks
   or blends.

Assembly is **data wiring, not just layout**: "when this row is clicked, open
that detail working panel" is `[on [do :select $_] [show /detail [bind $id]]]`.
**Design-time = run-time:** the builder is itself a XAP; the assembled UI is the
same data the runtime executes (no design-to-code gap).

---

## §19. Surfaces & composition — capability field, context, resolver

The substrate is **radar-native from day one** (no hard app boundary); but
**surfacing is conservative** (stable anchors + summon-on-demand first;
anticipation layered in progressively — §20). New pieces:

- **Capability** = a component triple (§17) + **context-affinity** metadata
  (when/where it is relevant — the inverse of routing: context → candidate
  surfaces).
- **Context** = a queryable projection over the event stream + ambient signals
  (focus, recent intents, role, the entity in hand, upstream events) —
  CXPath-queryable.
- **The context→composition resolver** — agent-driven relevance / ranking /
  placement / layering. This is "Radar," the new core component. Its decisions
  are recorded as events (with `:reason`), so a nondeterministic judgment is
  **auditable** even though it is not a deterministic function. The impl behind
  the handle may be a single model **or an agent manager orchestrating a pool**
  (§22.2); `xap` is agnostic — it sees one handle, and authority traces through
  per-sub-agent sub-delegations regardless.
- **Anticipatory speculative composition** — the same machinery run on
  *predicted* events, pre-composing candidate surfaces held peripheral (reuses
  dry-run). Prediction *quality* is the unproven, highest-risk part (the
  "Clippy" failure mode) — bounded by §20.
- **Attention / interruption cost model** — restraint is make-or-break. Default
  **peripheral-ready, not modal-interrupting**; cheap dismiss; "why is this
  here?" transparency. Only a handoff that needs the principal *now* earns the
  foreground (§21).

---

## §20. Anticipation trust ramp + attention tiers

### §20.1. Anticipation trust ramp

Anticipation authority is **earned per capability × context-class**, and is
itself a delegation (§22): the resolver's right to proactively surface a
capability is granted by the principal and revocable. Capabilities start at the
bottom and ramp **only on evidence**:

| Level | Name | Behavior |
|---|---|---|
| 0 | Summon-only | never self-surfaces; principal must explicitly summon. Default for new capabilities. |
| 1 | Indexed | appears in search/summon + the capability palette; no unsolicited surfacing. |
| 2 | Peripheral-suggest | may appear in the glanceable radar zone; never steals focus. The default *ceiling* under conservative surfacing. |
| 3 | Foreground-propose | may compose inline into the *current* surface as a suggested action/panel; encountered on look — still not modal. |

Trust is calibrated **deterministically from the log**: every surfacing event
records capability, level, context-class, and the principal's response
(acted-on / glanced-dismissed / ignored / explicitly-suppressed). The trust
score per (capability, context-class) is a **fold over those outcomes** — so
"why did this surface?" is answerable and replayable. Promotion requires
sustained positive signal; a single "don't show me this" demotes/suppresses.
Trust is **asymmetric — slow to gain, fast to lose**. The principal may pin a
level manually (an override grant).

The ramp governs only levels 0–3. **Seizing the foreground is NOT on the ramp** —
it is governed separately by stakes (§20.2). Trust earns reliability and reach; it
does not buy the right to interrupt.

### §20.2. Attention & interruption tiers

The single serial foreground (§21) is the scarce resource; what may claim it is
governed by **stakes × time-criticality, not by the resolver's confidence**:

| Tier | Seize foreground? | What it is |
|---|---|---|
| T0 Guardian / safety handoff | **Always** | a guardian takeover (§21) or guardian-class hand-back; needs the human *now* on a harm-compounding situation. Bounded by the pre-authorized grant. |
| T1 Decision-blocked | **Only if inaction is costly** | agent in delegated-auto cannot proceed without a decision only this principal can make, and delay has real cost; interrupts with a rehydrated brief (§21.1). Cheap delay → demote to T2. |
| T2 Foreground-propose | No (enters workspace) | relevant to the current task; appears inline; encountered on look. (= ramp level 3.) |
| T3 Peripheral | No | ambient radar zone; glanceable. (= ramp level 2.) |
| T4 Queued / digest | No | batched for a natural break or a digest. |
| T5 Suppressed | No | below threshold / muted / would violate a focus boundary. |

Governing rules:

1. **Only T0 and (conditional) T1 may seize the foreground.** Everything else is
   peripheral or queued — the structural defense against "Clippy": most
   anticipation is *physically incapable* of interrupting.
2. **Stakes gate, not confidence gate.** High confidence + low stakes maxes at
   T2/T3. Confidence governs whether/where something surfaces peripherally; it
   never buys interruption.
3. **Focus boundaries are sacred.** "deep work" / "in a meeting" / "DND" is
   context (§19) that *raises* the threshold — under deep focus even T1 demotes to
   T2 unless it is T0.
4. **One-at-a-time foreground.** Attention is serial; a higher-tier event parks
   the current to peripheral and takes the foreground; never two competing
   modals. Agent parallelism lives in the periphery/queue.
5. **Every interruption is an audited, reversible event** with its tier + reason;
   the response feeds §20.1 calibration; cheap dismiss is always present.

**Composition:** the ramp (trust) sets peripheral reach (0–3); the tiers (stakes)
gate interruption (T0–T1). **Both gates are required for a foreground
interruption** — except **T0**, which bypasses the trust ramp because safety is
pre-authorized by grant.

> **Residual risk (honest).** Relevance ranking *within* a tier is still agent
> judgment and can be wrong — but the design caps the *loudness* of a wrong
> guess: a mistaken item can only be peripheral/inline (cheap to dismiss), never
> a mid-task interruption, unless genuinely T0/T1. What remains empirically
> unproven is the resolver's *prediction accuracy* over time — the one gate to
> graduation.

---

## §21. Interaction & control model

### §21.1. Agent-initiative spectrum; handoff brief

Humans pseudo-multitask but attend **serially** (one foreground); the agent
multitasks **in parallel** (on the bus). The interaction model is the contract
for how the agent's parallel background work surfaces into the human's single
foreground, and how control hands off. Modes (per surface, resolver-defaulted,
human-overridable):

| Mode | Decides | Acts | In XAP |
|---|---|---|---|
| Manual-navigate | human | human | agent silent; human emits all intents |
| Turn-by-turn | agent (next step) | human | agent proposes the next intent JIT; human commits |
| Watch-the-map | human (informed) | human | agent maintains the situational picture |
| Semi-auto | agent | agent; human vetoes | agent emits speculatively; human supervises + rollback |
| Full-auto | agent | agent | agent commits; human gets result + audit |

A "mode" is how much initiative the agent takes over emitting/committing
intents — and issuing a delegation (§22) *is* throttling up the dial.
**Map-mode (shared situational awareness) is what keeps takeover safe** — pure
turn-by-turn deskills, pure auto makes handoff dangerous.

**Handoff brief (required, not optional).** When auto hands back, the human's
foreground was elsewhere and their world-model is cold; a handoff therefore
carries a **context-rehydrated brief** — handing the foreground back *without*
one is exactly what causes the automation takeover-crash.

The brief is **decision-scoped, not history-scoped** — organized around the
decision now required, back-filling only the context that decision needs. It is
itself a **surface** (composed per §17/§19, content-negotiated per §15) with the
decision options inline as `[do …]` controls. Minimal contents
(decision-first):

1. **The ask** — the decision needed, options as controls.
2. **Recommendation + why I stopped** — proposed action, rationale, and crucially
   what the agent is *uncertain* about / why it handed back.
3. **What I did and why** — actions since the agent took initiative, each
   annotated with its **authority basis** (delegation/grant id). For a guardian
   hand-back: the grant + the **incapacity predicate that fired** (§22.8) + the
   minimal action + that the system is in a held state awaiting return.
4. **What happened** — the causal chain to here, compressed.
5. **Current state** — the relevant slice *now* (live), so the principal reasons
   from truth, not stale memory.

**How much log to replay** — a **causally-scoped, salience-filtered** slice,
never the whole log: the *provenance cone* of the pending decision (follow
causation links backward from the trigger), anchored at the returning
principal's **last-in-command point** (their last known-good model), keeping
pivotal events and eliding routine repetition (47 auto-refunds →
"refunded 47 duplicates", expandable). **Progressive disclosure:** minimal by
default, complete on demand. **Liveness:** "current state" subscribes to its
slice; decision options re-validate against the live log (an option that becomes
invalid is struck with a note).

### §21.2. Control model — two axes, three regimes

Two distinct "in control" axes:

- **System authority** — the log owns state/truth/ordering (§14). Party-agnostic.
- **Operational control** — who drives. Three regimes:

1. **Human-in-command (default)** — the human freely throttles control
   manual↔auto at any granularity (§21.3).
2. **Delegated auto** — human throttled up; reclaimable anytime; agent acts
   within delegated scope.
3. **Guardian takeover** — agent acts as fiduciary on **incapacity +
   harm-of-inaction**. Shape: **pre-authorized fail-operational** — affirmative
   *minimal* protective action, but only in capabilities a human
   **pre-authorized** for guardian mode (advance-directive model, narrow +
   enumerated per capability), only on positive incapacity, routing to humans,
   fully audited. **Fail-safe (halt/hold/alarm) is the per-capability floor**
   until guardian scope is explicitly granted.

> **N-CONTROL-1 (the bright line — the most trust-load-bearing invariant).**
> *The agent may act when the human **cannot**; it must **never** act when the
> human **will not**.* Incapacity (may act) vs disagreement/refusal/
> non-compliance (must never act) is an **architectural guarantee, not a
> policy** — enforced by §22's typed gate. At every instant control traces to a
> human: controlling **now**, or **in-advance** via a grant. The agent never
> holds un-granted authority.

### §21.3. Control granularity — fine-grained to grouped

The control dial binds at **any node of a scope hierarchy**, settings inheriting
(most-specific-wins):

```
action[+condition] ⊂ capability ⊂ surface ⊂ group/domain ⊂ principal-default
  (finest)                                                    (coarsest)
```

- **Fine (per-action, conditioned):** "auto-approve `refund-duplicate` when
  amount < $50 and not flagged; turn-by-turn otherwise." Conditional autonomy
  uses ordinary `state` predicates — **not** the guardian incapacity gate
  (§22.8); this is routine delegation conditioning, not emergency authority.
- **Per-capability / per-surface**, **grouped (per-domain)** named bundles, and
  the coarsest **principal-default** fallback.

**Resolution:** the **most-specific** dial setting matching an intent governs it,
always **bounded by the principal's authority ceiling** (granularity sets the
autonomy *mode*; it never exceeds *authority* — attenuation, §22).

**One mechanism, no new primitive:** every dial setting at every granularity is a
**scoped, revocable delegation** (§22). "Sliding the dial" *is* issuing /
adjusting / revoking a delegation at the chosen scope.

**Anti-overload:** the resolver **proposes** dial settings from observed behavior
("you've hand-approved 30 sub-$50 refunds — auto them?"), gated by the trust
ramp (§20.1); groups + the principal-default keep the common case a single
setting. The principal tunes; the agent curates.

### §21.4. The dial is a trust/RACI assignment

The dial position is a **per-context assignment of responsibility roles between
principal and agent**, set from **trust = _f(intent, competence)_**: *intent* =
stakes / reversibility / blast radius / sensitivity; *competence* = demonstrated
capability + **current state** of either party (a fold over the log). Whichever
party is more fit *in this context* is assigned the role; the principal accepts
or adjusts the resolver's proposal.

**RACI is the underlying model, and it is shared** — either party may hold any
role by context:

| Role | May be held by |
|---|---|
| **Responsible** (does the work) | human **or** agent |
| **Accountable** (owns the outcome) | *ultimate* = **principal only**; *operational* accountability may be the agent's within delegated scope |
| **Consulted** (input sought before acting) | human **or** agent |
| **Informed** (told during/after) | human **or** agent |

> **N-CONTROL-2 (ultimate accountability never leaves a principal).** The agent
> may be Responsible, Consulted, Informed, and operationally accountable within
> scope — but the buck stops at a human/org. A guardian action, though
> Agent-Responsible, keeps the *grantor* Accountable.

The §21.1 modes are **presets** — common RACI configurations (Accountable =
principal throughout). RACI is more expressive than the presets and admits
assignments the 1-D dial cannot name; the dial UI offers the presets, the
resolver or a power user may set RACI directly. Every assignment is a scoped
delegation (§22).

### §21.5. Control hierarchies and collective state — the policy stack

The *effective* dial position is the resolution of a **policy stack** over two
hierarchies plus contextual/collective state:

- **Actor identity / type / state.** Trust binds to the *specific* actor and its
  *current state*; a degraded / low-confidence / unverified-version agent
  **auto-tightens** its own envelope.
- **Principal hierarchy (supervisor / guardian).** A principal with a recorded
  **authority relationship** over another sets the subordinate's *envelope* (a
  manager bounds reps; a parent sets a child's car to auto-only; an adult child
  sets auto-drive for an aged parent). The authority to constrain is itself an
  established, recorded relationship — not assertable by any principal over any
  other, and scoped to the relevant domain.
- **Agent hierarchy (managing agent).** A managed agent's envelope = the managing
  agent's grant to it, never exceeding the managing agent's own; accountability
  chains *up* to a principal.
- **Collective / contextual state.** Aggregate team/org state gates members'
  options (team hits its high-risk quota → high-risk deals stop surfacing or
  require step-up).

**Composition — two rules:**

- **Envelopes intersect → most-restrictive-wins.** Constraints can only
  *restrict*, never expand, never beyond the grantor's own authority
  (attenuation).
- **Discretionary setting within the envelope.** The individual's own dial (§21.3
  most-specific-wins) operates *clamped to* the envelope.

```
effective-control = individual-setting ∩ ⋂(superior, managing-agent, collective gates)
```

Each envelope-setter must hold a legitimate, recorded authority relationship;
accountability is layered; at every level *ultimate Accountable is a human*
(N-CONTROL-2). A parent setting a child's envelope is **principal-over-principal
authority** (legitimate by relationship), *not* an agent overriding a human.

### §21.6. Envelopes are context-conditioned allowed-sets (forced safe transitions)

An envelope is an **allowed set** of dial positions / RACI assignments — a
ceiling (`≤ semi-auto`), a floor (`≥ turn-by-turn`), a single mode (`{manual}`),
a **band excluding both ends**, or any combination. Composition stays
intersection (most-restrictive = smallest intersection).

Worked case — a student-driver license envelope:

| Context | Allowed set | Why |
|---|---|---|
| **Off-freeway** | `{manual}` only | build core skill unaided in low-stakes settings |
| **On-freeway** | assisted band — **no full-manual, no full-auto** | full-manual excluded (competence floor: high stakes → assistance mandatory); full-auto excluded (engagement ceiling: the student must stay in-the-loop — anti-deskilling) |

Contrast the young-child case (*auto-only* — the machine drives because the child
cannot) with the student (*auto excluded* — the human must drive, with help,
because they are learning): **opposite allowed-sets, same mechanism.**

Two properties:

- **Context-conditioned.** The allowed-set is a function of context and shifts as
  context changes; envelopes are evaluated continuously, like all §19 context.
- **Forced safe transition.** When a context change makes the **current mode fall
  outside** the new allowed-set, the system performs a **controlled transition to
  the nearest allowed mode — with a handoff brief (§21.1) if a human must take or
  share control** — and **fail-safe** (halt/hold) if it cannot transition safely.
  **Never silent continuation in a now-disallowed mode.**

**Envelope sources include regulators** — graduated-licensing rules are a
regulatory principal bounding the driver; same mechanism. Effective control is
the intersection of all of them.

---

## §22. Trust model — authority originates only from principals

> **N-TRUST-1 (the originating axiom).** Authority originates **only** from
> principals. Everything else — agents, sessions, guardian grants — is
> delegation. The operational-control dial (§21) *is* delegation issuance and
> revocation.

### §22.1. Identity
A **principal** is an authenticated subject (human or org/role), tenant-scoped.
XAP integrates an **external identity source** — an **IdP** (OIDC/SAML) **or** a
**DID resolver** (§28.2 R9) — maps the subject → a tenant-scoped principal, and
owns *authorization + audit*, not identity issuance.
Attach = authenticate → a **session** bound to (principal, tenant) over TLS.

**There is no anonymous XAP.** Every intent commits under a `(principal, tenant)`
session, because the PEP gates every intent (§22.3). "No login" is **not** "no
session": it is a **fixed, pre-granted dev principal** under `--role tooling`
localhost-trust (§14.1) — the cascade still PEP-checks every intent, it simply
always admits. The whole auth surface is **one seam** — a single `identity.cx`
attach policy plus the role flag; moving floor→production flips that seam from the
fixed principal to **IdP-verify** and **nothing else in the project moves**
(N-IMPL-1 — configuration in CX files, not in the library).

**SSO is also the federation enabler** (§22.6.1): one IdP authentication mints
**N `(tenant, XAP)`-scoped sessions** across a composed mesh, so the principal
authenticates once and the experience federates.

### §22.2. Capabilities + delegation
A **capability** = the right to emit certain intents / read certain slices
(composes with the component triple's declared intent vocabulary, §17).
**Relationships** determine *who may delegate to whom* (ReBAC — §21.5
parent/child, manager/rep, guardian/ward); **conditions/context** gate *when* a
delegation applies (ABAC — §21.3/§21.6 predicates, allowed-sets). The model is
**capability/delegation at the core, with relationships and conditions as its
expressive layers; RBAC roles are one convenience sugar over capability bundles,
not the model.** Delegations are **scoped, attenuating** (cannot delegate more
than you hold → no privilege escalation), **time-bounded, revocable**:

```cx
[delegation d-recon-77
  [tenant acme]
  [from [principal dana]] [to [agent ops-agent-1]]
  [capabilities [refund-duplicate]]
  [over /orders[?[= @/charge-state "erroring"]]]
  [attenuates d-dana-ops] [until $t0+1h] [revocable true]
  [issued-as "throttle:reconcile→auto"]]              ; the control dial issued this
```

**Agent pools sub-delegate, attenuating.** An "agent" is often an **agent
manager orchestrating a pool** behind the resolver handle (§3.6/§19). Each pool
agent receives its **own attenuating sub-delegation** — a narrower session
derived from the manager's grant (cannot exceed it). The journal's `:actor` then
names the **specific** pool agent, and `revoke` / `why-allowed` (§3.7) operate at
sub-agent granularity (revoke one misbehaving sub-agent without killing the pool).
A pool **never multiplies authority**: however many sub-agents it spins up, every
intent commits through the one PEP under a delegation that traces to a principal
(N-TRUST-1). Orchestration is a runtime concern; authority is a delegation
concern — the two stay separate, and `xap` is agnostic to the pool (it sees one
handle and one session per sub-delegation).

### §22.3. The bus is the single enforcement point (PEP)
Before committing any intent the bus verifies the actor's authority-basis grants
this capability, over this slice, in this tenant, unrevoked — else
`[err [code :CXER-UNAUTHORIZED]]`. **One checkpoint, one authoritative bus.**

### §22.4. Guardian grant
A guardian grant = a conditional pre-issued delegation with an incapacity-typed
gate:

```cx
[delegation g-pay-001
  [tenant acme] [mode :guardian]
  [from [principal acme-admin]] [to [agent ops-agent-1]]
  [capabilities [pause-payment-gateway]]
  [gate [all [incapacity [no-ack-within "10m" [of :escalation]]]
             [state      [gt /metrics/charge-error-rate 0.15]]]]
  [action [do :pause-payment-gateway]]                ; minimal, pinned
  [route [page sam dana]] [audit :required]
  [dormant-until-gate true]]
```

Authority still traces to the principal who authored it — guardian = human
control exercised in advance, at the security layer.

### §22.5. The bright line, made unforgeable
The gate DSL has **two** predicate types: `incapacity` (`no-ack-within`,
`unreachable`, `quorum-lost`, …) and `state` (harm thresholds). A guardian
`[gate …]` may reference **only** those. Any gate branching on a principal's
*choice* (`[declined …]`, `[refused …]`) is **rejected at grant-authoring time**.
The invariant is a *type constraint on the grant language* — a refusal-triggered
grant cannot be expressed, so the agent cannot hold one. `incapacity` terms
resolve to a signed, vetted **library** (§22.8); a guardian gate is well-formed
only if it contains **≥ 1 incapacity predicate**.

### §22.6. Log: hash-chained, partitioned, attributed
Every event carries `:actor` + `:authority` (basis) + `:tenant` + its
XAP/stream identity; the chain is per **stream** (§14.2) → tamper-evident. Audit
+ non-repudiation are free; event sourcing *is* the compliance trail.

**Two partitions, not one.** *Authority* partitions by **tenant** (the org
boundary — cross-tenant access is structurally impossible). *Data* partitions by
**XAP** (a bounded context = one runtime = one journal) and, within it, by
**aggregate stream** (§14.2). The three-level nesting is
**tenant ⊃ XAP ⊃ stream ⊃ events**. The earlier text conflated "tenant" with
"runtime/journal"; separating them is what lets one tenant hold many XAPs and
thousands of streams while every isolation guarantee still holds.

### §22.6.1. Federation — composing many XAPs into one experience

A principal's experience is a **composition of many XAPs**, not one monolith —
the §19 capability field spanning runtimes. Composition is **federation at the
experience layer**, never shared state:

- a principal (via SSO, §22.1) holds **independent authenticated sessions in N
  XAPs**; the surface is the composed **union** of those XAPs' surfaces;
- **no XAP reads another's journal** — the data hard-partition holds *across
  XAPs* exactly as it holds across tenants;
- a cross-XAP effect flows as a **delegated intent** (explicit choreography: an
  intent in XAP-A emits, through a delegated session, an intent into XAP-B),
  never as implicit shared state — §14.2 cross-stream coordination raised one
  tier.

**Hierarchy and mesh are one primitive** — *a XAP-as-panel reached through a
delegated session*. **Hierarchy:** a parent XAP embeds a child's surface as a
nested panel (§13.1 CXPath-scoped nesting), holding the delegated session.
**Mesh:** the principal's client / Radar holds peer sessions and composes at the
experience layer (no parent). The topology is only *who holds the composing
sessions*; the mechanism — delegated session + surface composition — is
identical, and adds **no new trust primitive** (it is §22.2 delegation).
**Admin / support XAPs** are the same primitive specialized: an
over-the-shoulder mirrored attach (§16/§21) granted by a scoped, time-bounded,
revocable delegation.

### §22.7. Tenancy
Process-per-tenant by default (hard blast-radius / noisy-neighbor / data
isolation), with a lighter shared-process logical-partition tier for small /
low-assurance tenants (§14.1).

### §22.8. Incapacity-predicate library — the trusted surface
`incapacity` predicates are the **only** terms that can *enable* guardian action
(§22.5), so they are XAP's most safety-critical trusted surface. A guardian
`[gate …]` references predicates **by `name@version` from a signed, versioned
library**; inline ad-hoc incapacity logic is rejected at authoring.

**Defining criterion — will-independence.** A predicate qualifies as
`incapacity` iff its truth is **independent of the principal's will** — it
measures whether the principal is *able to receive and act on* a request, never
what they *decided*. Authoring-time test: *"Could this become true while the
principal is actively, knowingly declining?"* If yes, it is a refusal-predicate
in disguise and is **rejected**.

**Invariants every incapacity predicate must satisfy:**

1. **Will-independent** (the criterion above).
2. **Observable** — truth derives only from logged, attributable signals +
   attested sensor inputs; no opaque inference.
3. **Minimum-persistence** — requires a duration; no instantaneous trigger.
4. **Falsifiable-by-presence** — the principal acking / re-appearing makes it
   **immediately false**. *The moment the human can act, guardian authority
   evaporates*, and a returning human always reclaims control (§21.2).
5. **No self-assertion** for physiological/safety predicates — they require an
   independent **attested signal source**, never the agent's own judgment.

**Initial library:**

| Predicate | Meaning | Required params |
|---|---|---|
| `no-ack-within` | a request was issued; no ack in the window | `:duration`, `:of <prompt\|escalation>` |
| `unreachable` | all contact channels failed for a duration | `:principal`, `:via`, `:for` |
| `session-lost` | session dropped / no heartbeat | `:principal`, `:for` |
| `quorum-lost` | fewer than N of a role reachable | `:role`, `:need`, `:for` |
| `escalation-exhausted` | every tier tried, none acked | `:chain` |
| `operator-incapacitated` | attested sensor-derived incapacity | `:signal` (attested), `:for` |

**Not incapacity — by design.** Time pressure / deadlines / harm thresholds are
`state` predicates: a deadline alone does not mean the human *cannot* act. They
gate guardian action only when **ANDed with** an incapacity predicate.

**Gate well-formedness.** A guardian `[gate …]` is invalid unless it contains
**≥ 1 `incapacity` predicate** (a gate of only `state` predicates could fire
while the principal is present and declining → bright-line violation). Adding /
changing a library predicate is a **high-privilege, logged, attributed
governance action**, shipping with its will-independence rationale, attested
signal sources, and a conformance fixture proving it is true only under genuine
incapacity and **false the instant the principal re-engages** (invariant 4). The
library is **signed + versioned**; grants bind `name@version`, so a predicate
cannot be silently redefined under existing grants. Validation uses the
two-validator model (structural: params+type; semantic: will-independence +
falsifiable-by-presence).

### §22.9. Assurance / signing tiers
Two **orthogonal** integrity properties:

- **Integrity of history** — the hash-chained log (§22.6) makes the event
  *sequence* tamper-evident, at every tier.
- **Authorship non-repudiation** — how strongly an individual artifact is bound
  to its author. This is what the tiers govern:

| Tier | Binding | Default use |
|---|---|---|
| **T0 Session-attributed** | via the authenticated TLS session | ordinary intents — don't tax every click |
| **T1 Principal-signed** | cryptographically signed by the principal's key | **delegations** and **guardian grants** |
| **T2 Co-signed (M-of-N)** | multiple principals must sign — a two-person rule | guardian grants for **irreversible / high-blast-radius** capabilities |

**Guardian grants are T1 minimum** (they authorize action while a human
*cannot* intervene) and **T2 for irreversible capabilities**, and must verify on
*two* axes before arming: their own signature **and** the signed predicate
library they reference (§22.8). The **bus (PEP) verifies the required tier before
commit**; failure → `[err [code :CXER-UNAUTHORIZED]]`, logged. Tier is a policy
knob, not a paradigm change.

### §22.10. Configuration & validation tractability (the policy-nightmare answer)
The expressive model raises the **configuration-and-validation nightmare** — the
very enterprise-IAM-hell XAP exists to dissolve. Five structural answers:

1. **The agent authors and curates policy (XAP applied to itself).** You state
   intent in high-level terms ("students stay engaged on freeways") and the
   resolver compiles + maintains the low-level delegations/envelopes, surfacing
   them for approval (the §18.2 authoring loop + §21.3 "propose from observed
   behavior"). *Authz is just another XAP surface.*
2. **Default-deny, attenuating, expiring (object-capability).** Authority is
   nothing-until-granted; grants are narrow, cannot escalate, are time-bounded +
   revocable → **self-pruning**, killing RBAC role-explosion at the root.
3. **One enforcement point, one decision function.** All authority resolves at
   the bus PEP (§22.3) through a single composition
   (`effective = individual ∩ ⋂envelopes`, subject to capability + conditions +
   gates). One function to test; every intent passes through it.
4. **Scenarios are conformance fixtures, validated by dry-run.** "Could a student
   ever go full-auto on a freeway?" / "Could an agent ever act on refusal?" are
   answered by running the resolver in **dry-run** over the scenario against the
   real decision function — deterministic (log + policy stack are pure data),
   repeatable, regression-gated. "Why can/can't X do Y" is a query over the log +
   policy stack at that instant.
5. **Invariants shrink the validation space.** Safety comes from structural
   invariants that cannot be configured away — the bright line
   (refusal-triggers unexpressible, §22.5/§22.8), attenuation
   (escalation impossible), ultimate-Accountable-is-a-principal (N-CONTROL-2),
   guardian needs ≥ 1 incapacity predicate + signing. The worst cases are simply
   not in the language.

> **Honest residual risk.** Answer (1) leans on resolver quality — the same
> prediction-accuracy caveat as §20. A bad policy *proposal* is mitigated (it
> surfaces for approval and is invariant-bounded), but the *ergonomics* of
> agent-authored authz are unproven and need real use. Answers (2)–(5) hold
> regardless.

---

## §23. Web client — bridge-then-native; XAP above the client

The web client is the **most replaceable** layer:

- **Bridge now** on a proven thin-client hypermedia library to validate the stack
  without building client infrastructure prematurely.
- **CX-native thin client later**, once the bus/view-tree protocol stabilizes, so
  the web target becomes a peer of TUI/native/agent (content-negotiating
  view-tree-as-data for agents like every other target).

> **N-CLIENT-1 (XAP above the client).** XAP is CX's layer **above** the client;
> no client's vocabulary leaks upward. This preserves agent-parity and the
> multi-target story.

**The bridge→native swap is gated, not calendared**, and **incremental**, not a
flag day:

- **Stability gate (necessary).** The `/v1` *client-facing* protocol — the
  event-feed schema, the `application/cx` view-tree representation (§15), the
  intent/control encoding, the working panel slice-feed (§18.1), and the attach/auth
  handshake (§22.1) — must be **frozen** (no breaking change for ≥ one release
  cycle; breaking changes scheduled for `/v2`) and **conformance-covered and
  green** (a spec-first protocol conformance suite the bridge passes — "passes
  the suite" *defines* "is a correct client").
- **Pull gate (sufficient reason).** Swap only when the bridge's limits bite: web
  needs view-tree-as-data for full agent parity; or the "supplement burden"
  crosses over (native client < the supplements); or a needed protocol feature
  the bridge cannot express cleanly.
- **Incremental.** Introduce the native client **surface-by-surface alongside the
  bridge**, validated against the same conformance suite, bridge as fallback
  until parity.
- **Explicit non-trigger.** Do **not** swap on a date, on novelty, or before the
  conformance suite exists.

---

## §24. SSE / streaming-response prerequisite (open dependency)

XAP's authoritative event-feed (§16) and working panel slice-feeds (§18) require the http
layer to hold connections open and stream responses (SSE). **http v1 does not
provide this** ([`http.md`](../std-lib/http.md) §4.2 — bodies are
materialized; streaming is out of scope). Two consequences, both already
reflected in the layering:

1. **The picoev engine MUST be designed for held-open / streaming fds** — the
   event-feed is not a one-shot request/response, so streaming-response support
   in the http engine is a hard prerequisite for the native `[?http-service]`
   path, not an optional extra.
2. **Until streaming lands, the SSE feed is supplied by the bridge shell** (the
   veb HTTP+SSE shell of the reference demo — see Appendix D).
   This is the same bridge-then-native discipline as §23: the shell is the
   swappable transport; the CX core is identical.

**SSE, not WebSocket, is the v1 feed transport.** One-way server push covers the
event-feed, radar updates, working panel slice-events, and out-of-band swaps. True
bidirectional WebSocket is required only for collaborative-editing CRDT (the
thickest §16 tier), which is out of scope for v1.

---

## §25. Implementation — thin CX stdlib modules, not a framework

XAP is **not a bespoke runtime or framework**. The general-purpose primitives are
**thin `cx-stdlib` modules** (`bus`/`journal`/`authz`/`session`/`sched`) — each a
clean, independently reusable concern; the **`cx-xap` orchestrator** (this spec,
its own bundled subsystem — §0 Positioning) composes them plus the *existing*
`[?http-service]` / `[resource]` routing directives into the experience layer. You
build a XAP by **calling functions** (`[$xap:…]`, `[$bus:…]`, `[$journal:…]`, …)
and serving it;
the principle is the same hybrid `http` already proves — `[$http:serve]` is the
engine, `[?http-service]` is optional declarative sugar. The whole stack is
authored in CX (the flagship dogfood); one C ABI / one `[?http-service]` runtime
serves CLI, LSP, the tooling daemon, and XAP — no duplicate maintenance. A V/veb
shell bridges delivery until the http engine's streaming transport (§24) has
burn-in.

> **N-IMPL-1 (thin modules, no framework).** Each module stays thin; the
> control-plane (routing / lifecycle) is the *existing* `[?http-service]`
> directive, not a new framework. A XAP's *behavior* lives in the modules; a XAP
> *project*'s configuration lives in ordinary CX files (§25.2), not baked into
> the library.

**The CX toolchain is itself XAP-shaped (the deepest dogfood).** The runtime's
capabilities — `eval`, `parse`, `render`, `test`, `serve`, `init`, the LSP — are a
**capability field** (§19); today's `cx` CLI is one **client** over it; and the
`--role tooling` daemon (§14.1) is already a single-principal, localhost-trust,
multi-client runtime (CLI + LSP + editor-HTTP). Adding **web and TUI clients that
afford the same capabilities** (N-CLIENT-1) makes the toolchain a XAP in fact, not
just in shape. The honest scope line: the **pure capabilities**
(`eval`/`parse`/`render`) need no session or journal — a one-shot CLI invokes one
and renders, detaching (§16 floor); the **XAP emerges in the *stateful* dev
runtime** (workspace, live preview, the dev loop), where journaling the dev
session buys **replayable, auditable dev sessions**. Because `init` / `serve` are
themselves capabilities that *create and run XAPs*, the toolchain is a XAP that
builds XAPs — closing the loop with the fleet / operations layer (§28.3 D4).

### §25.1. Required stdlib additions & enhancements

A conforming XAP runtime needs: **five `cx-stdlib` primitive modules** (`bus`,
`journal`, `authz`, `session`, `sched` — **now graduated**, `03-approved/std-lib/`,
Tier D), the **`cx-xap` orchestrator** (this spec, a separate bundled subsystem),
and **three enhancements** to existing modules. Everything else XAP needs is
composed in CX from what already ships (`hash`+`store`, `html`, `validate`,
`crypto`, `email`, `url`, `mime`, CXPath). The primitives' specs are at
`spec/03-approved/std-lib/{bus,journal,authz,session,sched}.md`.

**New thin modules:**

| Module | Concern | Built on | Key surface (illustrative) |
|---|---|---|---|
| **`bus`** | general **pub/sub**: subscribe, publish, **synchronous ordered dispatch** (zero-or-many subscribers react in order; no async — N-BUS-1) | — | `[$bus:on …]`, `[$bus:emit …]` |
| **`journal`** | append-only, **hash-chained** event log + `fold → state` + replay/dry-run + **signed snapshots / retention / compaction** *(named `journal`, since `log` = logging)* | `hash`, `store`, `crypto` | `[$journal:append …]`, `[$journal:fold …]`, `[$journal:snapshot …]`, `[$journal:compact …]` |
| **`authz`** | the trust model: principals, capabilities, **delegations** (attenuating/time-bounded/revocable), **guardian grants**, the signed **incapacity-predicate library**, and the single **PEP decision function** *(distinct from `caps`, which is effect-permissions)* | `crypto` | `[$authz:delegate …]`, `[$authz:grant-guardian …]`, `[$authz:check …]` |
| **`session`** | `(principal, tenant)` sessions: attach/detach, mirrored-attach; **Bearer** (agents/channels) **+ cookie-session + CSRF** (browsers) | `crypto`(JWT), `http` | `[$session:attach …]`, `[$session:attach-cookie …]`, `[$session:csrf-verify …]`, `[$session:of …]` |
| **`sched`** | **scheduled events / timers**: `after`/`at`, `every` (fixed-delay **or** fixed-rate), **`recur`/`cron`** (calendar recurrence), **durable** (journal-backed, survives restart), catch-up policy, **test clock** | picoev loop, `time`, `journal` | `[$sched:after …]`, `[$sched:at …]`, `[$sched:recur …]`, `[$sched:cron …]`, `[$sched:restore …]` |
| **`xap`** | **orchestrator + composition**: component/surface/view-tree constructors, content-negotiation (HTML via `html` / view-tree-data), the resolver hook (scripted now, LLM-pluggable), `[$xap:serve]`, and project `[$xap:init]` (§25.2). *Wires the others into the §14 cascade; does not reimplement them* | all of the above | `[$xap:component …]`, `[$xap:surface …]`, `[$xap:on …]`, `[$xap:resolve …]`, `[$xap:serve …]` |

> **The §14 serialized cascade is a composition rule in `xap`, not a module.**
> `bus` offers general pub/sub; XAP drives it in the **synchronous, ordered,
> log-coupled** mode (emit ⇒ `journal` append ⇒ dispatch in commit order ⇒
> sub-emissions append before the next external message). A free-running async
> bus is **rejected** (N-CORE-1) — it breaks replay/determinism.

**Enhancements to existing modules:**

| Module | Enhancement | For |
|---|---|---|
| **`http`** | **SSE / streaming** — `text/event-stream`, held-open writes, **server push *and* client read** (Last-Event-ID reconnect) | the authoritative event-feed + slice-feeds (§16, §24) — the one *hard* prerequisite; the agent client + channels *consume* the feed |
| **`crypto`** | **JWT/JWKS verify + RSA-PKCS1v15 + ECDSA-P256 verify primitives** — full alg coverage **RS256/384/512 + ES256 + EdDSA** (what mainstream IdPs issue) | turning an authenticated request into a `(principal, tenant)` session; the IdP itself stays external (§22.1) |
| **`time`** | **recurrence models** — an RFC 5545 RRULE-grade rule value + cron parsing + DST/tz-aware occurrence math (`next-occurrence` / `occurrences-in`) | `sched`'s `recur`/`cron` calendar schedules; reusable for business recurrence (e.g. renewal dates) |

*(The timer/recurrence engine is the standalone **`sched`** module (firing) over
the **`time`** recurrence amendment (occurrence math) — not an http enhancement.
Incapacity windows (`no-ack-within "10m"`), lifecycle, calendar schedules, and the
demo's controllable clock all run on `sched`; durable timers persist via
`journal` so a guardian window survives a worker recycle.)*

**Not required for v1** (out of scope, §27): WebSocket (only for CRDT collab) and
any user-facing concurrency surface (the bus is synchronous-serialized; the http
engine is already multicore).

### §25.2. Project init — a harness, not configuration-in-the-library

`[$xap:init]` (lib function) and `cx xap init` / `cx new xap` (CLI command)
**scaffold a project**: they land CX **data + code files** into a directory, each
carrying **instructional comments** ("set your IdP issuer here", "declare
capabilities here", "this dial defaults to manual — raise it when ready"). The
project's XAP *is* those files; the modules just run them — which is what keeps
the library thin (it ships *behavior*; the template ships *your configured
project*).

The template contents are pulled from a **pluggable source** — a local file/dir
(`io`), an http tarball (`http`), or a git repo (via `process` git) — so `init`
is purely a fetch-and-write harness with no new module of its own. (`"etc."`
sources are additional fetchers behind the same interface.)

---

## §26. Invariants (the frozen, load-bearing set)

A conforming XAP runtime MUST uphold these. Everything else (clients, working panels,
predicates, capabilities, assurance tiers) extends *without* disturbing them.

- **N-CORE-1** — commit order is the system authority; state is a deterministic
  fold over append-only, hash-chained **per-aggregate streams** (total order
  within a stream; partial order across streams, coordinated explicitly —
  §14/§14.2).
- **N-CONTROL-1** — the bright line: the agent may act when the human *cannot*;
  never when the human *will not* (§21.2). Enforced by the typed gate (§22.5).
- **N-CONTROL-2** — ultimate Accountable is always a principal; authority traces
  to a human at every instant (§21.4).
- **N-TRUST-1** — authority originates only from principals; everything else is
  attenuating, revocable delegation (§22).
- **N-CLIENT-1** — XAP is above the client; no client vocabulary leaks upward;
  human and agent are peers on one `[do …]` intent surface (§15, §23).
- **Hard partition (two axes)** — *authority* partitions by tenant (cross-tenant
  access structurally impossible); *data* partitions by XAP→stream (no XAP reads
  another's journal). Cross-XAP composition is **federation** — delegated
  sessions + delegated intents, never shared state (§22.6/§22.6.1).
- **Guardian gate well-formedness** — ≥ 1 will-independent, falsifiable-by-
  presence incapacity predicate from the signed library; refusal-triggers
  unexpressible (§22.5, §22.8).
- **N-IMPL-1** — XAP is thin stdlib modules + the existing `[?http-service]`
  directive, not a framework; behavior lives in the modules, a project's
  configuration lives in ordinary CX files (§25).
- **N-PLATFORM-1** — the principal's experience stays simple; behind-the-scenes
  complexity is a gradient the same paradigm spans **without rewrite** (the
  reference XAP's one capability + a CLI client, and a federated multi-cloud mesh
  with ops agents, are one paradigm). Growth is composition along dimensions —
  capabilities, dial, media/clients, federation, scale, deployment (§28.4) —
  never a second stack.

---

## §27. Out of scope

- A game-engine / Figma-class real-time collaborative canvas as a *first-class*
  target. The interactive 5 % is served via thick-client working panels + (where
  needed) CRDT, not subsidized into the core.
- XAP as an identity provider — the IdP is integrated, not built (§22.1).
- Cross-tenant data sharing / federation.
- WebSocket bidirectional transport in v1 (SSE-only — §24).
- Real integrations in the reference demo (see Appendix D).
- Cross-tenant **data sharing** — distinct from experience-layer **federation**
  (§22.6.1), which shares no data (delegated sessions + delegated intents only).

---

## §28. Platform map — domains, rulings & growth (scoping; non-normative)

*Scoping section, not normative platform text. It records the architectural
rulings settled while designing the reference XAP (all reconciled into the
sections above) and maps the broader platform this thin module anchors. Per
N-IMPL-1 / N-PLATFORM-1 (§26) the platform concerns below **will partition into
separate specs later**; **for now they live here, in one spec.***

### §28.1. The demo is a XAP with a hello-world *capability*

There is **no "hello-world XAP."** There is **a XAP whose first surfaced
capability is hello-world** (the `greeting` triple, §13.1/§17), reached through a
**CLI**, then **web**, then **TUI** client (§16 ladder). The XAP is the persistent
thing; **capabilities compose into its field** (§19), never bundled into a bounded
"app". The demo grows along the §28.4 dimensions — never by rewrite (N-PLATFORM-1).

### §28.2. Ruling ledger (all landed in this spec)

Settled in the design dialogue. R2 and R3 edited the *framing* of frozen
invariants (§26); the rest are additive.

| # | Ruling | Landed in |
|---|---|---|
| **R1** | Agent = session-bound client/resolver; behind its handle a manager may orchestrate a **pool**, each pool agent with its **own attenuating sub-delegation** → `:actor` names the sub-agent; `revoke`/`why-allowed` per sub-agent; authority never multiplied. | §22.2 + §19 |
| **R2** | **Scale = per-aggregate streams within a XAP** — total order + hash chain **per stream**, parallel commit, explicit cross-stream coordination. Experiment-gated before trust. | §14/§14.2 + N-CORE-1 (§26) |
| **R3** | **Cross-XAP composition = federation at the experience layer** — independent sessions in N XAPs, **no XAP reads another's journal**, cross-XAP effects = delegated intents. Hard partition preserved. | §22.6/§22.6.1 + §26 |
| **R4** | **Hierarchy and mesh are one primitive** — XAP-as-panel-via-delegated-session, seen from two roots. No second mechanism. | §22.6.1 |
| **R5** | **Three-level partition** — tenant (authority) ⊃ XAP (data/bounded-context = one journal) ⊃ stream (aggregate). Separates two partitions the module had conflated. | §22.6 + §26 |
| **R-A1** | shell ≠ client ≠ renderer — all medium-specific, under the medium-agnostic surface. | §16 |
| **R-A2** | The **event-feed is a §16 client-consistency primitive, independent of working panels**; the in-process TUI may ride the `bus` directly (no SSE). | §16 |
| **R-A3** | **No anonymous XAP** — attach = authenticate → session; "no login" = a fixed pre-granted dev principal under `--role tooling`; auth seam = one `identity.cx` + role flag; SSO is the federation enabler. | §22.1 |
| **R6** | The **CX toolchain is itself XAP-shaped** — pure capabilities (`eval`/`parse`) + the stateful dev runtime (§14.1); CLI today, web/TUI tomorrow, same capabilities (N-CLIENT-1); the deepest dogfood. | §25 |
| **R7** | **The intent pipeline is a declared per-intent policy** — a fallback ladder (rule → statistical → inference) where (1) routing is declared CX data, (2) each tier emits a *candidate* `[do …]`, never an action, (3) every candidate passes the one PEP + ordered cascade (§2.1/§22.3), (4) the tier chosen is logged with `:reason` (§4.5). Generalizes the §19 resolver from surface-composition to **all** intent handling: deterministic governance over a bounded inference seam. | §19 + §4.5 → D0/D5 |
| **R8** | **Agent orchestration is a peer module on the shared substrate** (bus · journal · authz · session), **not folded into `xap`** — by **agent-parity** (§13.2): the orchestrator *is* the agent's client, symmetric to the human's browser/TUI, attaching via sessions and emitting `[do …]` through the **one PEP** like any client (so inference can never bypass authority — R7). `xap` holds only the resolver *interface* (the socket); everything behind the handle — pipeline (R7), pools (R1), tools, protocol adapters, DID/VC (R9) — is the orchestrator. The split is a **module/concern boundary, not a deployment mandate**: in-process & co-located by default (the `:scripted` resolver, §3.6; demo ladder D1–D4), split into its own process under load / cross-org (D1/D5) — same interface, no rewrite (N-PLATFORM-1). Folding it in would privilege the agent and break parity; its async fan-out also cannot live inside the synchronous serialized cascade (§14). | §22.2 + §3.6 + §13.2 → D5 |
| **R9** | **External agent protocols (MCP/A2A/ANP) integrate as edge adapters; the cascade stays CX-native.** Cross-trust-domain identity/capability provenance may be **DID-anchored**: a DID identifies a principal (§22.1), a verifiable credential is a **portable, signed, attenuating §22.2 delegation**. The PEP (§22.3) and N-TRUST-1 are **unchanged** — DID/VC is a *decentralized authority-basis transport*, not a new trust primitive. SSO (§22.1) is the *centralized* federation enabler; DID is the *decentralized* one for the cross-org agent mesh. | §22.1/§22.2/§22.6.1 (framing refined) + §27 |

> R7–R9 are additive except R9, which **refines the framing** of §22.1/§22.6.1
> (as R2/R3 refined §26): "SSO is the federation enabler" becomes "SSO is *one*
> (centralized) enabler; DID/VC is the decentralized enabler — both resolve to the
> same `(principal, delegation)` model the one per-runtime PEP gates."

### §28.3. Domain map — future partition targets

When the platform partitions (later — not now), these are the homes. **D0 is this
module; D1–D4 graduate as separate specs at that time.**

```
cx-xap (this spec)   D0  STAYS THIN — constructors · cascade · resolver · serve · init
        │
        ├─ D1 xap-operations    topology (§14.1) · reliability/recovery · the R2 scale model at scale
        ├─ D2 cx-as-IaC         CX as infrastructure-as-code · on-prem/cloud/hybrid/multi-cloud
        ├─ D3 xap-composition   federation/mesh (R3/R4/R5) · extends §19 · the EXPERIENCE axis
        ├─ D4 xap-fleet         meta-XAP managing many deployments · admin/support XAPs · the OPS axis
        └─ D5 xap-orchestration agent pipeline (R7) · pool management (R1) · protocol
                                adapters + DID/VC identity (R9) · the INFERENCE/INTEROP axis
```

- **D1 — operations.** Process-per-tenant, gateway, worker recycle,
  crash-recovery, durable timers (`sched` over `journal`); the R2 stream model
  operated at the hundreds-to-thousands-of-principals scale.
- **D2 — CX-as-IaC** (provisional `cx-stdlib/infra`). CX expresses its own
  infrastructure: topology/provisioning as CX data; on-prem · cloud · hybrid ·
  multi-cloud. Dogfood — an infra change is an **intent on a journal** (same
  hash-chained, attributed, replayable trail as application intents).
- **D3 — composition / federation.** The principal's experience as a composition
  of many XAPs (R3/R4/R5); the **experience** axis. Admin/support XAPs are
  over-the-shoulder mirrored attaches (§21) under the same dial/guardian.
- **D4 — fleet / meta-XAP.** A XAP that *operates* many deployments — admin
  principals + ops agents, the dial/guardian applied to operations (incapacity
  predicates like `region-unreachable` / `quorum-lost`, §22.5); the **ops** axis.
  Distinct from D3 (which federates running experiences); admin/support XAPs
  straddle D3↔D4. Closes the R6 loop: the toolchain is a XAP that builds XAPs.
- **D5 — orchestration / interop.** The **inference/interop** axis: the per-intent
  pipeline (R7), agent-pool management behind the resolver handle (R1), and the
  edge adapters + DID/VC authority-basis verifier for the cross-org agent mesh
  (R9). The substrate stays deterministic and CX-native; inference and foreign
  protocols are bounded, audited seams, never authority paths around the PEP.

### §28.4. Growth dimensions (no rewrite — N-PLATFORM-1)

| Dimension | Floor (the demo) | Ceiling | Future home |
|---|---|---|---|
| **Capabilities surfaced** | one (`greeting`) | a field composed per context (§19) | D0/D3 |
| **Agent involvement (the dial)** | floor — agent silent, principal-only (§21) | semi-/full-auto + guardian, sub-delegated pools (R1) | D0/D3 |
| **Media / clients** | CLI → web (htmx) → TUI | + voice/mobile/channels; same surfaces materialize (§13.2) | D0 |
| **Federation** | one XAP | hierarchy/mesh of XAPs (R3/R4) | D3 |
| **Scale** | one principal, no login | 100s–1000s of principals, per-aggregate streams (R2) | D1 |
| **Deployment** | local `--role tooling` worker | `--role app`, multi-cloud, IaC-provisioned | D1/D2 |
| **Identity** | fixed dev principal (R-A3) | SSO/IdP, N federated sessions → DID/VC across trust domains, no shared IdP (R9) | D0/D3/D5 |

### §28.5. Next

1. **R2 experiment** — run the **§14.3 validation battery** (designed this pass)
   across randomized seeds; green gates the §28.6 D1 operations work.
2. **Demo ladder (done):** the client-driven ladder is Appendix D (D1→D4: CLI →
   +TUI → +web → +agent). It doubles as the `xap`-module build order — **D1 (pure
   `component`/`surface`/`render` + a CLI renderer) is the first implementation
   slice**, needing no journal/bus/socket.
3. Partition the platform domains (§28.6) into their own specs **only when** the
   platform work warrants it — not before (one spec for now).

### §28.6. Domain charters (provisional — in-spec until partition)

One charter per future domain (§28.3). These are **scope statements, not full
specs**; they live here until the platform work warrants partitioning (§28.5).

**D1 — operations & scale.** *Owns:* the §14.1 topology operated at scale —
gateway/worker supervision, recycle, crash-recovery; durable timers (`sched` over
`journal`); the §14.2 stream model run at hundreds-to-thousands of principals
**after the §14.3 battery is green**. *Open decisions:* stream→worker placement &
rebalancing; per-stream back-pressure / admission control; snapshot & compaction of
long streams; the shared-worker tier's isolation guarantees. *Depends on:* §14.3
(blocking), `sched`, `journal`.

**D2 — CX-as-infrastructure-as-code.** *Owns:* a XAP's infrastructure expressed as
CX data — topology, provisioning, placement — across on-prem · cloud · hybrid ·
multi-cloud. *Principle:* an infra change is an **intent on a journal** → the same
hash-chained, attributed, replayable trail as application intents (the dogfood,
[[project_eat_our_own_dog_food]]). *Open decisions:* the provisioning capability
surface (provisional `cx-stdlib/infra`); declarative target model vs. imperative
drivers; drift detection as a fold; secret/credential handling. *Depends on:* D1
(what it provisions), `journal`, effect caps (`net`/`process`).

**D3 — composition / federation.** *Owns:* the **experience** axis — a principal's
surface as a composition of many XAPs (§22.6.1): the federation handshake
(SSO → N sessions), surface nesting across XAPs, the delegated-intent choreography
for cross-XAP effects, admin/support over-the-shoulder attach. *Open decisions:*
cross-XAP capability discovery (how a parent learns a child's `emits`); the
composed-surface conflict/precedence model; consistency/latency of a federated read
(each XAP's feed is independent); revocation propagation across the mesh; **cross-domain
identity** — whether federation requires a shared IdP (SSO, §22.1) or admits
**DID-anchored principals + VC delegations** (R9, D5) so the mesh federates without a
central IdP (the §22.1/§22.6.1 centralized-vs-decentralized seam).
*Depends on:* §22.6.1, §16, §22.2, SSO (§22.1), D5 (DID/VC).

**D4 — fleet / meta-XAP.** *Owns:* the **ops** axis — a XAP that operates many XAP
*deployments*: the fleet surface (admin principals + ops agents), the dial/guardian
applied to operations (incapacity predicates `region-unreachable` / `quorum-lost`,
§22.5), and the R6 loop (the toolchain is a XAP that builds XAPs). *Open decisions:*
the deployment/lifecycle intent vocabulary (`[do :deploy …]`, `[do :recycle …]`,
`[do :failover …]`); the guardian-gate library for ops actions; the D3↔D4 boundary
where admin/support XAPs straddle. *Depends on:* D1 (deploys), D2 (provisions),
D3 (admin XAPs compose), `authz` guardian (§22.4/§22.5).

**D5 — orchestration & interop.** *Owns:* the **inference/interop** axis — the
per-intent pipeline (R7: rule/statistical/inference routing as declared policy,
candidates through the one PEP, choices logged); agent-pool management behind the
resolver handle (R1); edge adapters for MCP/A2A/ANP and the DID/VC authority-basis
verifier (R9). *Principle:* the substrate stays deterministic and CX-native;
inference and foreign protocols are **bounded, audited seams** suspended inside it
— never authority paths around the PEP. *Open decisions:* the pipeline-policy
vocabulary (`[pipeline-policy for=… [tier … when=…]]`); the per-tier
confidence/abstention contract; the DID method(s) and VC schema accepted as
authority basis; **VC revocation vs. the local journal's `revoke` (§3.7)** — how a
credential revoked at its issuer propagates to N runtimes; trust-domain boundaries
(which DIDs a tenant will honor). *Depends on:* `authz` (§22.2/§22.3), the resolver
(§19), `crypto` (VC signatures), `net`/`http` (adapters).

---

## Appendix A — Rationale (non-normative)

### A.1 Why now
Three things that did not hold in the era of prior server-side component
frameworks now hold: (1) hypermedia thin clients have been re-legitimized;
(2) persistent connections removed the latency tax; (3) LLM-grade judgment can
finally perform the relevance/timing/composition role brittle rule engines could
not. The server-authoritative component model that lost to SPAs on *authoring
ergonomics* is rehabilitated because **the agent pays the authoring tax now, not
the human.**

### A.2 The terminal-paradigm claim (design intent)
XAP is *intended* as the terminal paradigm in the interface lineage (CLI → GUI →
TUI → API → … → XAP) — the fixed point beyond which improvement is *within* it
(better renderers, better resolver prediction, richer catalogs), not *of* it.
The argument: a paradigm shift can only change one of four axes, and XAP closes
all four — **Parties** (human + agent as peers; no third class of intent-holder),
**Substrate** (representation-agnostic semantic surface absorbs any future I/O
modality as a renderer), **Structure** (composition-per-context — no fixed "app"
structure left to improve), **Control** (the manual↔delegated↔guardian spectrum
spans the whole range, bounded by the bright line). Falsifiable by only two
things: a genuinely new *class of intent-holder*, or a demonstration that one
axis is incomplete. Stated as design intent supported by a completeness argument
— not a proof. The operational meaning of "terminal" is **not "finished" but
"complete at the invariant layer (§26), infinitely extensible below it."**

### A.3 Prior art
- **tmux** — server owns session state; clients attach/detach (§16, §21).
- **Hypermedia / HATEOAS thin clients** — the thin-client default (§15, §23).
- **Streaming + working panel libraries** (Hotwire/Turbo, Datastar) — candidates if the
  bridge needs native streaming/working panels (§23).
- **Delphi RAD** — the component property/event contract (§17); its mouse-only
  assembly is replaced by §18.2.
- **ZK** — server-side components (right architecture; died on authoring
  verbosity the agent now pays — §17/§18.2).
- **Elm / MVU** — `model = scan(msgStream)`; relocated server-side as event
  sourcing (§14), client-side MVU scoped inside working panels (§18).
- **SAE driving automation / aviation autopilot / Garmin Autoland** — the
  interaction spectrum and guardian takeover (§21).
- **Principal-agent theory; object-capability security** — the trust model
  (§22).

---

## Appendix B — Worked trace (non-normative, validating)

B2B order-fulfillment SaaS, tenant `acme`. Principals: **Dana** (ops manager,
human-in-command, browser), **Sam** (on-call escalation, away), **Ops-Agent**
(peer publisher, background). Guardian grant `g-pay-001` (§22.4) authored
earlier. A payment webhook starts erroring and double-charging.

1. **Context event** — error rate crosses threshold → `charge-error-spike`
   appended (E1). *(§14)*
2. **Resolver composes a surface** bound to `/orders[?[= @/charge-state
   "erroring"]]`, surfaced **peripheral** to Dana, with a recorded `:reason`
   (E2). *(§19, audit)*
3. **Content negotiation** — Dana's browser gets HTML; Ops-Agent gets the
   view-tree value, same `[do …]` controls. *(§15)*
4. **Working panel** — the surface includes a `retry-timeline` working panel bound to
   `/charges[…]`; the surrounding table is hypermedia-thin. *(§18)*
5. **Delegated auto** — Dana throttles *reconcile-duplicates* up → issues
   delegation `d-recon-77`; the agent auto-refunds clear dupes (E3, E4), each
   fanning out as OOB swap + working panel slice-event. *(§21, §22, bus seam)*
6. **Concurrent intents** — Dana `[do :hold [id 7]]` and Ops-Agent `[do
   :refund-duplicate [charge c7]]` (same order) both hit the bus; the log
   serializes them; hold commits first, refund commits as a rejection with an
   `[err]` the agent re-plans on (E6, E7). *(§14 synchronous cascade)*
7. **Guardian condition** — error rate 0.21, no ack from Sam in 10m →
   `g-pay-001`'s gate fires. Sam is **unreachable (cannot act)**, not declining.
   *(§21.2, §22.5)*
8. **Guardian takeover** — agent dry-runs to confirm minimality, then commits
   `[do :pause-payment-gateway]` under the grant, routes to humans, audited
   (E_g). Does not exceed the pinned `[action …]`. *(§21.2 guardian, §22.4)*
9. **Invariant** — had Sam replied "leave it running," the `no-ack-within` gate
   would be false → the agent is structurally barred from pausing. **Refusal
   blocks; only incapacity enables.** *(N-CONTROL-1, §22.5)*
10. **Handoff** — Sam reconnects; the surface presents a brief **replayed from
    the log slice** (what happened / did + why / state / recommendation); control
    returns to human-in-command. *(§21.1, map-mode)*
11. **Audit** — every step reconstructs from the hash-chained log. *(§22.6)*

**Verdict (held without special-casing):** the working panel↔page seam (dissolved by
the bus), concurrent human/agent intents (serialized log + `[err]`), guardian
within the bright line (typed gate), content negotiation + agent parity, and
multi-tenant scoping all held.

---

## Appendix C — A fully non-screen worked example: a blind sailor (non-normative)

This trace exists to **stress-test the lexicon** against a medium with no screen,
no pointer, real-time stakes, and a physical body in the loop. It is told using
*only* the terms of §13.1 — and not one of them assumes a display.

The sailor is the **principal**. Their **agent** (the **Radar**) reads
**context** — wind, heading, depth, GPS, AIS traffic, the race marks — and
**composes a surface** for sailing. There is no screen; the surface
**materializes** (§13.2) through the sailor's **medium**: spatial audio, speech,
and haptics, plus the boat's own hardware.

- **Views** (parts that *present*): a *wind view* materializes as a steady tone —
  pitch = angle, volume = strength — sitting in the **periphery** (§20); a *traffic
  view* materializes as spatialized pings (a vessel off the port bow pings from
  the left); a *course view* speaks on **summon**: "two miles to the mark, bearing
  040."
- **Working panels** (parts you *work in*, each with its own loop): a *trim panel*
  — as the sailor hauls the sheet it feeds back continuous tone/haptics on sail
  trim, reacting in real time; a *helm panel* — a tone centred when on course,
  sliding as they fall off. (The interactive 5 % of §18, materialized as sound and
  touch rather than a grid.)
- **Controls** (parts you *act through*; each fires an **intent**): the physical
  **tiller** and **winches** *are* controls — turning the tiller fires `[do
  :steer …]`; spoken controls too — "tack now" → `[do :tack]`, "reef" → `[do
  :reef]`. The medium's trigger differs (a hand, a word); the **intent is
  identical** — and it is the same intent the **agent** emits as data, so when the
  sailor turns **the dial** up on trim in a squall, the agent emits the very same
  trim intents itself. **Agent-parity, with no screen anywhere** (§15, §13.2).
- **The dial / delegation** (§21, §22): calm water → the dial is low (the sailor
  does everything; the agent only presents views). A tricky passage → the sailor
  turns the dial up *on trim only* — a scoped **delegation** lets the agent
  auto-trim while the sailor keeps the helm.
- **Guardian + the bright line** (§21.2, §22.4–§22.8): the boom knocks the sailor
  down — no response. A pre-authorized **guardian grant** whose gate ANDs an
  **incapacity predicate** (`operator-incapacitated`, attested by heel/heading
  sensors, plus `no-ack-within`) with a harm **state** predicate fires: the agent
  takes **minimal** protective action — heaves-to, depowers, holds off the rocks,
  radios for help — *only* because it was pre-authorized and *only* on genuine
  incapacity. The instant the sailor grabs the tiller, the predicate is
  **false-by-presence** (§22.8 invariant 4) and control returns, with a **handoff
  brief** (§21.1) materialized as speech: "you were down 90 seconds; I hove-to,
  holding 200 m off the rocks, engine ready — resume?" Had the sailor instead
  *said* "leave the sails up, I've got it," the agent is **structurally barred**
  from depowering — **refusal blocks; only incapacity enables** (N-CONTROL-1).
- **Log** (§22.6): afterward, "what happened while I was down?" is one query over
  the hash-chained **log**.

**Verdict:** every term earned its keep with no display in sight — **surface,
panel, view, working panel, control, intent, medium, materialize, periphery,
summon, the dial, delegation, guardian, incapacity, handoff brief, log**. The
lexicon is medium-agnostic, not screen-bound.

---

### Review questions — RESOLVED (user G3, 2026-06-07)

**Resolved (a):** the external-LLM resolver leg stays **abstract** here — `resolve` defines the *interface* (context-in, `[surface]`-or-absence-out, decision-event-with-`:reason`) and the trust/tier gates; the concrete LLM transport (local handle vs http endpoint vs `process` subprocess) is a separate resolver-impl decision, gated behind the §11 empirical accuracy gate, so the orchestrator spec stays thin and transport-agnostic. (Pinning a transport now would couple xap to a model API before the gate.) Detail below.


1. **Resolver-handle shape for the LLM leg.** §3.6 defines `:scripted` (default),
   a CX closure, and "an external LLM resolver handle." The **closure** and
   **scripted** legs are fully specified as CX data; the **external LLM handle**
   is named but its wire/transport shape (a local model handle vs. an http call to
   a model endpoint vs. a `process` subprocess) is **left to the resolver-impl
   spec**, gated behind the §11 empirical accuracy gate. **Recommendation: leave
   it abstract here (a)** — `resolve` defines the *interface* (context-in,
   `[surface]`-or-absence-out, decision-event-with-`:reason`) and the trust/tier
   gates; the concrete LLM transport is a separate impl decision once the accuracy
   gate is being run, so the orchestrator spec stays thin and transport-agnostic.
   (b) pin a transport now = premature + couples xap to a model API before the
   gate. This is the single genuinely-open design question; everything else is
   settled by Part II.

---

## Appendix D — Demos (the ladder; non-normative)

*Folded in from the former `xap_demos.md` (provisional co-location while XAP is prepped for implementation). Build-spec — non-normative for XAP itself; normative for these demos' shape. Diagram source: `xap_reference_demo.diagram.html`.*

- **Status:** Build spec — non-normative for XAP itself; normative for *these
  demos'* shape. Diagram source: `xap_reference_demo.diagram.html`.
- **Purpose:** two jobs — let someone **assess what XAP is** and **get started
  fast**. Not one reference app; a **ladder**. The Tier-0 ladder (**D1–D4**) is
  **client-driven**: one capability, each rung adds exactly one *client*, and the
  ladder doubles as the `xap`-module **implementation order** — each rung turns on
  one more subsystem, all of which (`bus`/`journal`/`authz`/`session`/`http`)
  already ship.

  | Tier | Demo | Job | Built as |
  |---|---|---|---|
  | **0** | **client ladder D1→D4** (CLI → +TUI → +web → +agent) | quick start + the impl order | in-repo `examples/`, scaffolded by `cx xap init` |
  | **1** | **boat / NMEA showcase** | assess — "worth building" | *its own project* — **deferred** |
  | **2** | **enterprise showcase** (scenario-composed SaaS) | depth — trust / guardian / multi-capability | §T2 below |

- **Build order = the ladder.** D1 needs **only the pure constructors**
  (`component`/`surface`/`render`, §3.2/§3.5) — no journal/bus/socket. D2 adds the
  **cascade** (`emit`/`on`/`state`) over `journal` + `bus` + the §16 in-process
  feed. D3 adds **`serve`** (http) + the `html` leg + the SSE/bridge feed. D4 adds
  the **resolver/agent** + the dial (`authz` delegation). The dial sits **at the
  floor** (agent silent) through D1–D3; D4 turns it up.

> Caveat: the CX below is **illustrative spec-level authoring** in the v0.8.0
> surface — `[$xap:…]` / `[$journal:…]` are the §25.1 module functions; the
> pure-constructor slice (D1) is the first to be implemented.

### Tier 0 — the client ladder (D1 → D4)

One running capability, surfaced through progressively more clients. Each rung
adds **one client** and turns on **one** new subsystem; nothing from a prior rung
is rewritten. The capability is `greeting` (pure, D1), then `guestbook`
(stateful, D2+).

> **Runnable versions.** Each rung is a complete, spec-conformant project under
> [`demos/`](demos/) — source + run command + expected output: D1 →
> [`demos/d1-greeting-cli/`](demos/d1-greeting-cli/), D2 →
> [`demos/d2-guestbook-cli-tui/`](demos/d2-guestbook-cli-tui/), D3 →
> [`demos/d3-guestbook-web/`](demos/d3-guestbook-web/), D4 →
> [`demos/d4-guestbook-agent/`](demos/d4-guestbook-agent/). The snippets below are
> illustrative excerpts; the `demos/` dirs are canonical and are the conformance
> targets at implementation time (§11).

#### D1 — `greeting`, one-shot CLI  *(pure; runs today — no journal, no socket)*

The minimal XAP: a **parameterized view** rendered by a one-shot CLI. No state, no
control, no journal, no server — only the **pure constructors**
(`component`/`surface`/`render`, §3.2/§3.5). It proves the foundational invariant:
*a surface is medium-agnostic data; a client is a renderer* (N-MEDIUM-1 /
N-CLIENT-1).

```cx
[$xap:component greeting
  {props {name ::string}}                              ; typed input — the triple's slice-in arm
  [view [?def [$p] [panel [text [$concat "Hello, " $p/name "."]]]]]]   ; pure projection

; one-shot CLI client: bind the prop, render the surface to the terminal, exit
[$print [$xap:render [surface [greeting {name "Ada"}]] {accept "application/cx"}]]
;        ^ the CLI renderer turns the view-tree value into terminal lines (no server, no feed)
```

**Demonstrates:** the component's `props` + `view` arms + surface composition + CLI
rendering — a real component, not a hardcoded string — with **zero runtime** (no
journal/bus/cascade). **Implements:** the pure `xap` constructors + a CLI renderer
— the first, lowest-risk module slice.

#### D2 — `guestbook`, CLI + TUI (live-synced)  *(adds state + the cascade + a 2nd client)*

Now the capability holds **state** and offers **one control**, and a **second
client** (a TUI) attaches to the *same* runtime. Sign the guestbook from either
client → the intent commits **once** to the journal → the §16 event-feed
re-materializes **both** clients. This is where server-authoritative state first
*earns its weight*: two peers, one truth (a single-client guestbook wouldn't need
any of it — §28.1).

```cx
[$xap:component guestbook
  [bind /guestbook]                                    ; the slice this panel reads (CXPath)
  [emits [[do :sign [name $_]]]]                        ; the one control
  [view [?def [$gs]
          [panel
            [list [?for [$g $gs] [item $g/name]]]
            [control :sign [label "Sign"] [input :name]]]]]]

[$xap:on [do :sign [name $n]]                            ; cascade: PEP → append → fold → re-render
  [$journal:append /guestbook {name $n}]]

[$xap:run {components [guestbook]}]                      ; one runtime; CLI + TUI attach as peers (§16)
```

**Demonstrates:** the full intent loop; **server-authoritative state as a journal
fold**; cross-client live sync — the §16 event-feed is a **client-consistency
primitive**, independent of any working panel (§18). **Transport:** both clients
ride the **in-process `bus`** feed — **no SSE, no socket** (TUI + a long-lived CLI
are co-located). **Implements:** the cascade (`emit`/`on`/`state`) wiring `journal`
+ `bus` (the `authz` PEP is trivial — one pre-granted dev principal, §22.1 / R-A3);
the TUI renderer + `run`.

#### D3 — + web client  *(adds `serve` + the html leg + the SSE/bridge feed)*

Attach a **third** client — a browser — to the *same* `guestbook` runtime. The
surface materializes as **HTML** (htmx); the web client's feed is **SSE** (or the
bridge until the streaming amendment lands, §24). Same capability, same intents, a
new medium.

```cx
[$xap:serve "https://localhost:8443" {surfaces [guestbook]}]   ; bootstraps [?http-service] / [$http:serve]
;  web client: htmx over the HTTP shell + SSE feed; CLI + TUI still on the in-process bus
```

**Demonstrates:** content-negotiated render (§5) — the *same* surface as HTML for
the browser, view-tree for an agent; **swappable transport** (§23) — web = SSE, TUI
= bus, identical CX core. **Implements:** `serve` (on `http` / `[?http-service]`) +
the `html` render leg + `session` attach (one fixed dev principal, no login yet —
the §22.1 / R-A3 seam).

#### D4 — + agent  *(adds the resolver/agent + the dial)*

Add an **agent** as a fourth peer alongside the three human clients (CLI, TUI,
web). It emits the **same** `[do :sign …]` intents (agent-parity, §15); the
**dial** (an `authz` delegation, §21) governs how much it does on its own. Raise
the dial off the floor and the agent curates within bounds.

```cx
; the agent attaches in its own session; the dial issues a scoped, attenuating delegation
[$xap:dial $rt [scope :guestbook] [setting :semi-auto]]   ; = [$authz:delegate …] (R1 sub-delegation)
```

**Demonstrates:** human + agent are **peers on one intent surface** (N-CLIENT-1);
the dial *is* delegation issuance (§21.3); per-pool **attenuating sub-delegation**
(R1) so the journal's `:actor` names the specific agent. **Implements:** the
resolver / agent hook (§20, scripted for the demo) + `authz` delegation (the dial).

> **…and it keeps growing the same way** (beyond D4, no rewrite): reach a new
> **medium** (voice, mobile) by changing nothing — the same surfaces materialize;
> promote the `guestbook` list to a **working panel** (the 5 %, §18) without
> touching the thin parts; **federate** a second XAP into one experience
> (§22.6.1); raise the dial toward **guardian** (§22.4) within the bright line.
> That trajectory is what Tier 1 (the boat) makes visceral.

---

### Tier 1 — boat / NMEA showcase  *(deferred — its own project)*

The flagship "now I get it" demo: a XAP bound to one or more **simulated NMEA
buses** (provided), surfacing boat **views** (instruments) + **controls**
(heading / waypoint / trim) + a chart **working panel**, with the **agent**
making recommendations and composing context-specific views — and the
guardian/bright-line beat from Appendix C (incapacitation → heave-to). It
is built as **its own project** (decision 3a) and doubles as the canonical
`cx xap init … from <git>` template. **Deferred** per current focus on Tier 0;
NMEA variant (2000 vs 0183) to be confirmed when it's picked up. Full spec will
live with that project.

---

### Tier 2 — Enterprise showcase (scenario-composed SaaS)

The depth demo: trust, guardian, and multi-capability mechanics on an abstract
B2B surface. Kept (decision 2b) alongside the boat; the matching *on-paper*
trust/guardian trace is Appendix B.

---

#### 1. The shape — a scenario-composed demo

Not one fixed script. A **catalog of scenarios** is composed into a personalized
"day" during a discovery conversation with a field worker (an "agent" in the
sales / insurance / support sense), then handed over for them to drive:

> Sit with the worker → "tell me about your day" → pick scenarios from the
> catalog (most-often / most-value / least-value …) as they talk → selected
> **names pin at the top** as the day's agenda → slide the laptop over → they run
> their own day.

This builder **is itself a XAP**: the catalog is a capability field (§19),
the conversation is context (§19), selection is composition, the assembled
day is a surface (§13.1). Building it dogfoods the paradigm.

---

#### 2. Architecture

The stack choice changes only the **shell** box; the CX core is identical either
way — committing to the bridge shell now costs nothing later (bridge-then-native,
§23/§24).

```
┌─ Clients — peers, attach/detach (tmux-style) ─────────────────────────┐
│  Human: browser · hypermedia · HTML + SSE                              │
│  Agent / Radar: application/cx · view-tree-as-data                     │
└───────────────┬───────────────────────────────────────────────────────┘
                │ intents in · surfaces out · SSE event-feed
┌─ HTTP + SSE shell — veb bridge now → [?http-service] later ───────────┐
│  /v1 endpoints                                                         │
└───────────────┬───────────────────────────────────────────────────────┘
┌─ XAP — thin CX stdlib modules (dogfood; §25) ──────────────────┐
│  bus      — pub/sub + synchronous-ordered dispatch                    │
│  journal  — append-only · hash-chained log + fold→state + projections │
│  authz    — PEP decision fn · delegations · guardian · incapacity     │
│  session  — (principal, tenant) sessions                              │
│  xap      — surfaces (panels: views + working panels) · resolver/Radar │
│             · the dial/RACI · content-negotiation · [$xap:serve]      │
└───────────────────────────────────────────────────────────────────────┘
┌─ Stubbed for the demo ────────────────────────────────────────────────┐
│  IdP → 2 principals · Email channel (v1, faked) · Billing (faked)      │
│  Controllable clock (fast-forward)                                     │
└───────────────────────────────────────────────────────────────────────┘
┌─ Demo harness (itself a XAP) ─────────────────────────────────────────┐
│  Scenario catalog (tagged: frequency / value / mechanic)              │
│  Day-composer (pick → pin names → ordered day)                        │
└───────────────────────────────────────────────────────────────────────┘
```

(Mermaid `flowchart` + `sequenceDiagram` source in
[`xap_reference_demo.diagram.html`](xap_reference_demo.diagram.html).)

**The loop:** intents (human *or* agent — same `[do …]`) → shell → `bus`
(`authz` PEP enforces authority) → appended to the `journal` (authority + audit) →
state fold → `xap` resolver composes a surface → rendered HTML (human) / view-tree-data
(agent) → back out via the shell, the SSE feed pushing live updates. Faked
billing emits the events; the clock fast-forwards to trigger the guardian beat;
the harness seeds a composed day.

---

#### 3. Components

### 3.1 Scenario model (CX data — composable, self-contained)

Each scenario is a CX value:

- `id`, `name` (the label that pins at the top);
- `tags`: **frequency** (most-often / occasional / rare) · **value** (high / low)
  · **role** · **mechanic** (radar / delegated-auto / guardian / quota-gate /
  handoff / working-panel / audit / agent-parity) · **est-duration**;
- `setup` (seed state + events it needs) · `beats` (scripted steps) ·
  `clock-needs` (e.g. guardian needs fast-forward).

Self-contained → orderable into a day; the engine runs any selected subset.

### 3.2 Scenario catalog (~10–15 starters)

Seed from an account-executive "morning" storyline: `new-lead-research`,
`delegated-email-batch`, `pipeline-panel`, `quota-gate`,
`guardian-billing-pause`, `handoff-brief`, `audit-query`, `agent-parity-toggle` —
plus a few tagged *least-value* / *rare* so the "most-often vs most-value vs
least-value" sorting in the discovery conversation is real.

### 3.3 Day-composer (a XAP itself)

During the discovery chat: pick scenarios (or the agent suggests from what the
worker says — "you chase renewals? → add `renewal-guardian`"); selected **names
pin at the top**; reorder/remove; output = an ordered, runnable day.

### 3.4 Runtime engine — mechanics real, integrations faked

| Real (the thin CX modules — dogfood) | Stubbed (skip the infra) |
|---|---|
| `journal` + `bus` (in-process, append-only CX values) — §14/§25.1 | IdP → 2 hardcoded principals (worker, manager) |
| `xap` surfaces = components (typed triple) → HTML via `html` — §17 | Channels → one fake "email" pane (no SMTP) — **email is the v1 channel** (§16) |
| `xap` resolver (seeded/scripted, repeatable — not LLM) — §19 | Services → fake billing emitting a scripted double-charge |
| `authz`: dial / delegated-auto / guardian / handoff / audit — §21/§22 | Agent → scripted/deterministic (LLM swappable later) |
| One working panel (pipeline kanban board) for the 5 % — §18 | Multi-tenant, CRDT, persistence cluster → none |

Two non-obvious must-haves:

1. **Controllable / fast-forward clock** — the **`sched` test clock**
   (`[$sched:test-clock-advance …]`) — so `no-ack-within "10m"` (§22.8)
   fires in *seconds* on stage; the guardian beat is undemoable without it.
2. **Single process, single tenant** — process-per-tenant (§22.7) is
   production-only; it adds nothing to the demo.

Front-end: the hypermedia bridge in a browser, plus an **agent-parity toggle** —
a pane that renders the same surface as `application/cx` and lets the scripted
agent emit the same `[do …]` intents (makes "human + agent are peers" visible —
§15).

### 3.5 Hand-off mode

Once composed, a "play" mode the worker drives solo — the next-step controls
*are* the XAP guiding them; no separate tutorial needed.

---

#### 4. The resolver is scripted, not LLM (for the demo)

XAP's resolver (the `xap` module, §19) is agent-driven and nondeterministic; **the
demo's resolver is seeded/scripted and repeatable**. This is deliberate:

- a scripted resolver makes the demo **deterministic and re-runnable** on stage;
- it isolates the mechanics (bus, log, surfaces, control, guardian) from the one
  *unproven* part (prediction accuracy) so the mechanics can be shown working
  with certainty;
- the LLM resolver is **swappable in later** behind the same interface — and
  *that* swap is where the empirical prediction-accuracy validation (§20)
  actually happens. The demo is the harness that validation runs in.

So: **the demo proves the mechanics; the LLM-resolver swap (later, same demo) is
what proves — or falsifies — the prediction-accuracy gate.**

---

#### 5. Build sequence (minimal-first)

- **Phase 0 — stack (resolved).** The native `[?http-service]` path needs
  real-socket + **streaming-response (SSE)** transport, which **http v1 does not
  yet provide** (§24; [`http.md`](../std-lib/http.md) §4.2). The
  picoev HTTP engine ([`http.md`](../std-lib/http.md) §9) supplies the
  fast real-socket floor; until its streaming surface lands, the demo runs on a
  thin **veb HTTP + SSE shell** with **all XAP logic in CX** (log / bus /
  surfaces / resolver / control). **SSE, not WebSocket** — one-way push covers
  the demo's live feed (radar / working panel / OOB); true WS is only collab-editing
  (out of scope). Migrate the shell to `[?http-service]` once its streaming
  transport lands — a swap that, by §23/§24, leaves the CX core untouched.
- **P1 — engine skeleton.** log + bus + one surface + hypermedia + clock; run
  *one* hardcoded scenario end-to-end.
- **P2 — scenario model + 3–4 catalog entries**, including `guardian-billing-pause`
  (to exercise the clock).
- **P3 — the day-composer** (select → pin names → ordered run).
- **P4 — fill out the catalog + agent-parity toggle + polish hand-off mode.**

---

#### 6. Validation

Per the project's spec-first discipline, the demo's behaviours are **conformance
fixtures**:

- the signature flow (§7 below) is a fixture: a fixed sequence of intents +
  faked events produces a fixed log + a fixed sequence of composed surfaces;
- the **guardian bright-line** case is a fixture in *both* directions
  (N-CONTROL-1): with `no-ack-within` satisfied → the pause commits; with
  Sam acking "leave it running" → the gate is false → the pause is **structurally
  barred** (the demo must show the agent *cannot* act on refusal);
- the authz dry-run cases (§22.10.4) — "could the agent ever act on
  refusal?", "could a rep exceed the quota?" — run against the real decision
  function and must return the safe answer every time.

---

#### 7. Signature flow (the demo's spine)

Normal intent loop → delegated-auto → guardian takeover → context-rehydrated
handoff. (Sequence-diagram source in the `.diagram.html`.)

1. **Billing** emits `charge-error-spike` → bus appends `E1`.
2. **Resolver** composes a surface (reason logged) → appends `E2` → SSE pushes it
   to **Maya** as a peripheral radar item.
3. **Maya** throttles `reconcile` to auto → the shell issues delegation
   `d-recon`; bus validates at the PEP and appends it. Now in **delegated-auto**.
4. **Agent** emits `[do :refund-duplicate …]`; PEP checks the delegation; appends
   `E3`; SSE pushes an OOB update; Maya's table updates.
5. **Maya steps away (unreachable).** Billing's double-charging worsens; bus
   appends.
6. `no-ack-within "10m"` fires (**incapacity**, fast-forwarded by the clock). The
   agent emits `[do :pause-payment-gateway]` under grant `g-pay`; the PEP checks
   *guardian grant + incapacity gate*; appends `E_g`; routes a page to the
   manager (and Maya).
7. **Maya returns.** The shell asks the resolver to build a **handoff brief**; the
   resolver replays the causal slice since Maya's last-in-command point and
   returns the brief (what happened / what the agent did + why / current state /
   resume?).
8. Maya emits `[do :resume-gateway]`; bus appends.
9. Later, "**why did this happen?**" = one query over the hash-chained log.

This flow exercises, in order: §14 (serialized log), §15 (content
negotiation), §18 (working panel), §19 (resolver), §21 (delegated-auto + handoff brief),
§21.2/§22.4 (guardian within the bright line), §22.3 (PEP), §22.6 (audit).

---

#### 8. Out of scope

Real integrations; multi-tenant; CRDT / collaborative editing; persistence
cluster; **LLM resolver** (scripted first, LLM swap is the *later* validation
step, §4); WebSocket (SSE-only, Phase 0).


---

## Appendix E — CLI XAP (🚧 UNDER CONSTRUCTION — not in the v1 implementation path)

> **🚧 Not buildable surface.** Spec'd **incrementally**; **excluded from the v1
> implementation path** and from the demo ladder (Appendix D). Nothing here is a
> commitment until it graduates out of this fence.

Distinct from D1's throwaway CLI *renderer*: the **CLI XAP** is a *first-class,
persistent CLI client / product surface* — the concrete form of the observation
that the CX toolchain is itself XAP-shaped (R6, §25/§28): a capability field
(`eval`/`parse`/`render`/`test`/…) surfaced through a CLI today, with web/TUI
clients affording the *same* capabilities later (N-CLIENT-1). It is **more than a
demo** — a real surface — so it is parked here to be fleshed out without blocking
the demo ladder or implying buildable scope.

*To be spec'd, incrementally:*

- the **persistent-CLI client contract** — intents-in from argv/stdin, surface-out
  as lines, and the §16 authoritative event-feed for a REPL / interactive mode;
- the **journal-the-dev-session** question (R6) — whether dev actions
  (eval/test/edit) are journaled for replayable, auditable sessions;
- the **boundary** between the *pure* capabilities (`eval`/`parse`/`render` — no
  session/journal) and the *stateful dev runtime* that is the actual XAP (§25);
- the relationship to the `--role tooling` daemon (§14.1) the toolchain already
  runs.
