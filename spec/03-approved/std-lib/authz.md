# `cx-stdlib/authz` — trust model: principals, delegation, guardian grants, the PEP decision function

```cx
[module-meta name=authz tier=D status=current]
```

**Status:** Current

`cx-stdlib/authz` is built **on the existing `crypto` module** (hash, sign/verify)
for the T1/T2 assurance tiers ([`xap.md`](xap.md) §22.9) and the signed,
versioned incapacity-predicate library ([`xap.md`](xap.md) §22.8). It composes
with — and is the **single PEP decision function** for — the `bus` enforcement
point ([`xap.md`](xap.md) §22.3); `bus`/`journal`/`session`/`xap` are the sibling
XAP modules ([`xap.md`](xap.md) §25.1).

> **`authz` is NOT `caps`. Read this first.** CX already has a capability system —
> the deny-by-default **effect-permission** model of [`security.md`](../core/security.md)
> (`net` / `fs` / `subprocess` / `eval` …), narrowed by `[?with-caps]`, denied at
> every effect point with `cx-err:CXER0271 E_CAP_DENIED`. That is **`caps`**: *what
> a CX evaluation is allowed to touch in the world.* **`authz` is a different
> concept** — *which **principal** authorized which **agent** to emit which
> **intents** over which **state slice** in which **tenant**.* `caps` gates
> machine effects (this code may open a socket); `authz` gates **delegated
> authority** (Dana authorized ops-agent-1 to refund duplicates until 5pm). They
> **compose but never substitute**: a guardian action can be authz-permitted yet
> still `caps`-denied if the process lacks the `net` grant to actually pause the
> gateway, and vice versa. `authz` introduces **no new effect capability**; its
> only effects are reads/writes of the trust state held in `journal`/`store`
> (§5). Throughout this spec "capability" with no qualifier means an **authz
> capability** ([`xap.md`](xap.md) §22.2 — the right to emit certain intents / read
> certain slices), **not** a `caps` effect-permission; the rare references to the
> latter are written **`caps`-capability** in full.

## §0. Consistency with the in-review XAP model + amendments (normative dependency)

Authored to be consistent with the settled XAP normative model and the same
in-review amendments its siblings align to; on their approval the cited semantics
are load-bearing here. If any is rejected or changed at G3, the marked clauses are
revisited.

| Dependency | What authz relies on |
|---|---|
| [`xap.md`](xap.md) §22 + §14 — **the trust model itself** | every §4 guarantee restates a §10/§14 invariant (N-TRUST-1, N-CONTROL-1, N-CONTROL-2, guardian-gate well-formedness); this module **adds none** — it is the *surface* for the model |
| SAP §1 — **four-channel model** | an authorization **decision is a VALUE**, not a fault: a *permit* is a present `[permit …]` value, a *deny* is a present `[deny …]` value carrying `cx-err:CXER4700` as data — **both flow on the value channel** (§2.4). `[err]` is reserved for genuine faults (malformed grant, signature/library verification failure, store fault). An **absent** delegation (revoked / never issued) rides the **absence channel** (empty node-set), never `null` (no-conflation guard, §2.5). |
| SAP §2 — **`[?try]`/`[catch]`/`[on-error]` retirement** | authz faults are handled with `[?match]` / `[?else]` / `[?fallback]` only; this spec never uses `[?try]`. Canonical call form is `[$authz:check …]` (`[head …]`), never an infix form. |
| SAP §5.2 — **cancellation = `CXER0260`** + capability-revocation backstop | a long-running predicate evaluation (e.g. `unreachable :for "5m"`) cancelled by `[?timeout]`'s cooperative `[?cancel]` surfaces the core `CXER0260` (not an authz code). |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |
| [`security.md`](../core/security.md) — **`caps` effect-permissions** | distinct system (see the boxed note above); authz **composes** with it but does not re-specify or replace it. |

authz does **not** re-specify hashing, signing, or key management — those are
`crypto`'s — nor identity issuance (the external IdP, [`xap.md`](xap.md) §22.1,
surfaced through the `session` module), nor the synchronous serialized cascade or
the append-only log (those are `bus` + `journal`). authz **composes** them: it
verifies signatures via `crypto`, reads `(principal, tenant)` from a `session`,
records every grant/revocation/decision as an attributed event via `journal`, and
is *called by* `bus` at the single enforcement point.

---

## §1. Scope

`cx-stdlib/authz` provides the **XAP authority model as data + a single decision
function**:

- **represent** principals, authz capabilities, delegations, and guardian grants
  as homoiconic CX values (§2.2);
- **issue** a scoped, **attenuating, time-bounded, revocable** delegation
  (`delegate`), **revoke** it (`revoke`), and issue a **guardian grant** — a
  conditional pre-issued delegation behind an incapacity-typed `[gate …]`
  (`grant-guardian`) ([`xap.md`](xap.md) §22.2, §22.4);
- **decide** authority at the **single PEP** — `check` / `authorize`: actor ×
  capability × slice × tenant × unrevoked × required-assurance-tier → a `[permit]`
  or `[deny]` **value** ([`xap.md`](xap.md) §22.3, §22.10.3);
- compute the **effective envelope** — the §9.5 intersection `individual ∩
  ⋂(superior, managing-agent, collective gates)` (`effective`);
- expose the **signed, versioned incapacity-predicate library** — `name@version`
  lookup, the six initial predicates of §10.8, and the authoring-time
  well-formedness check that enforces the bright line (`predicate` / `predicates`
  / `gate-wellformed?`);
- **verify assurance tiers** T0/T1/T2 ([`xap.md`](xap.md) §22.9) before a grant
  arms or a decision commits (`verify-tier`);
- **explain** — the deterministic dry-run query *"why can / can't actor X do Y?"*
  over the live policy stack (`dry-run` / `explain`) ([`xap.md`](xap.md) §22.10.4).

**The bright line is a property of the surface, not a runtime check.** A guardian
`[gate …]` that branches on a principal's *choice* (`[declined …]`, `[refused …]`)
is **rejected at authoring** by `grant-guardian` / `gate-wellformed?` —
refusal-triggers are **unexpressible**, so the agent can never *hold* such a grant
([`xap.md`](xap.md) §22.5, §26). This is the most load-bearing thing the module
does and is specified as a **type constraint on the grant language** (§4.4), not a
policy toggle.

**Layering.** authz sits inside the XAP module set, above `crypto`, beside
`bus`/`journal`/`session`, below the `xap` orchestrator:

```
crypto (hash, sign/verify, JWT)                                  spec/std-lib/crypto.md
  → journal (hash-chained attributed log) · session ((principal,tenant))   xap §13.1
    → authz (this spec — principals, delegation, guardian, the PEP)        xap §10
      → bus (calls authz.check at the single PEP) · xap (orchestrator)     xap §10.3, §13.1
```

**Module vs. the directive layer — authz is the engine the bus enforces with.**

| Surface | Home | Role |
|---|---|---|
| **`cx-stdlib/authz` module** (this spec) | `[?lib 'cx-stdlib/authz']` | the **programmatic** trust model — functions returning `[delegation]` / `[permit]` / `[deny]` / `[explanation]` **values** |
| **the bus PEP** ([`xap.md`](xap.md) §22.3) | the `bus` module / the `xap` cascade | the **single enforcement point** — calls `[$authz:check …]` before committing every intent; never re-implements the decision |

The bus is the *only* place the decision is enforced ([`xap.md`](xap.md) §22.3,
§22.10.3); this module is the *only* place the decision is **computed**. One
function to test; every intent passes through it.

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| Identity issuance, OIDC/SAML, the external IdP, JWT/JWKS verify | external IdP, surfaced via `session` ([`xap.md`](xap.md) §22.1) + `crypto` JWT ([`xap.md`](xap.md) §25.1) |
| Hashing, signing keys, signature verification primitives | `crypto` (authz **calls** `[$crypto:verify]` / `[$crypto:sign]`, §2.7) |
| The append-only hash-chained **log** + `fold → state` + replay/dry-run substrate | `journal` ([`xap.md`](xap.md) §25.1) — authz **records** grants/decisions there; dry-run runs **over** it (§3.7) |
| pub/sub, the synchronous serialized cascade, the PEP *call site* | `bus` + the `xap` cascade ([`xap.md`](xap.md) §14, §22.3) |
| Effect-permissions (`net`/`fs`/`subprocess`/`eval`), `[?with-caps]`, `CXER0271` | **`caps`** ([`security.md`](../core/security.md)) — a **different system** (boxed note above) |
| The dial UI, RACI editing UI, agent-authored-policy ergonomics | `xap` orchestrator / resolver ([`xap.md`](xap.md) §21.4, §22.10.1) — authz supplies the *values*, not the UI |
| Tenancy process topology (process-per-tenant) | the runtime ([`xap.md`](xap.md) §14.1, §22.7) — authz only enforces the **partition predicate** (§4.6) |
| Anticipation trust ramp scoring (levels 0–3) | the resolver's deterministic fold over the log ([`xap.md`](xap.md) §20.1); a ramp grant **is** an authz delegation (§2.2) but the *scoring* is the resolver's |

`cx-stdlib/authz` is **Tier-B runtime**. Construction, decision, and explanation
over already-materialized values are **pure** (§3.4, §3.6, §3.7 — referentially
transparent, capability-free). The verbs that **persist** a grant/revocation, that
**verify a signature** against a key, or that **read live state** (the journal /
the predicate-library store / a session) are **impure** and require the **`store`**
`caps`-capability for the trust-state backend (§5) — authz introduces **no new
`caps`-capability**.

## §2. Conceptual model

### §2.1. The four authority artifacts (and their lifecycle)

authz models four kinds of value, all homoiconic CX data (built as literals, no
opaque handles):

```cx
[principal dana [tenant acme] [kind :human]]            # the authority origin (N-TRUST-1)
[capability refund-duplicate [reads /orders] [emits [do :refund-duplicate]]]
[delegation d-recon-77 …]                               # scoped/attenuating/time-bounded/revocable
[delegation g-pay-001 [mode :guardian] [gate …] …]      # a guardian grant = a gated delegation
```

- A **principal** is the authority origin — an authenticated subject, human or
  org/role, tenant-scoped ([`xap.md`](xap.md) §22.1). **Authority originates only
  from principals** (N-TRUST-1); everything below is delegation.
- A **capability** (authz capability) = the right to emit certain intents / read
  certain slices ([`xap.md`](xap.md) §22.2). It is **not** a `caps`-capability.
- A **delegation** is a grant from one party to another, **scoped** (a capability
  set + a CXPath slice), **attenuating** (cannot convey more than the issuer
  holds — no privilege escalation), **time-bounded** (`until`), and **revocable**
  ([`xap.md`](xap.md) §22.2). A *dial setting at any granularity is a delegation*
  ([`xap.md`](xap.md) §21.3) — issuing/adjusting/revoking the dial **is**
  `delegate`/`revoke`. authz adds no separate "dial" primitive.
- A **guardian grant** is a delegation with `[mode :guardian]` + a `[gate …]` of
  incapacity-typed predicates that is **dormant until the gate fires**
  ([`xap.md`](xap.md) §22.4). Authority still traces to the authoring principal —
  guardian = human control exercised **in advance** (N-CONTROL-2).

**Lifecycle** (all transitions are attributed `journal` events, §2.6): a
delegation is **issued** (`delegate` / `grant-guardian`) → **active** (or, for a
guardian grant, **dormant-until-gate**) → optionally **revoked** (`revoke`) or
**expired** (past `until`). A revoked or expired delegation is, for `check`,
**absent** (§2.5) — it cannot permit.

### §2.2. `[delegation …]` — the grant value (the §10.2 / §10.4 shapes, verbatim)

A standard scoped delegation reuses the [`xap.md`](xap.md) §22.2 shape exactly:

```cx
[delegation d-recon-77
  [tenant acme]
  [from [principal dana]] [to [agent ops-agent-1]]
  [capabilities [refund-duplicate]]
  [over /orders[= $_@charge-state "erroring"]]      # the CXPath slice it is scoped to
  [attenuates d-dana-ops] [until [+ $t0 1h]] [revocable true]
  [assurance :t1]                                     # signing tier (§2.7, §10.9); default :t1 for delegations
  [issued-as "throttle:reconcile→auto"]]              # the control dial issued this (§9.3)
```

A **guardian grant** reuses the [`xap.md`](xap.md) §22.4 shape exactly — a
delegation with `[mode :guardian]`, an incapacity-typed `[gate …]`, a **pinned**
minimal `[action …]`, a `[route …]`, mandatory `[audit :required]`, and
`[dormant-until-gate true]`:

```cx
[delegation g-pay-001
  [tenant acme] [mode :guardian]
  [from [principal acme-admin]] [to [agent ops-agent-1]]
  [capabilities [pause-payment-gateway]]
  [gate [all [incapacity [no-ack-within "10m" [of :escalation]]]   # ≥1 incapacity predicate (well-formedness)
             [state      [gt /metrics/charge-error-rate 0.15]]]]    # state predicate — only ANDed in
  [action [do :pause-payment-gateway]]                              # minimal, pinned
  [route [page sam dana]] [audit :required]
  [assurance :t1]                                                   # guardian = T1 minimum; T2 if irreversible (§2.7)
  [dormant-until-gate true]]
```

Both are the **same `[delegation]` tag**; `[mode :guardian]` + `[gate …]` +
`[action …]` are the guardian view. `[mode :delegated]` (the default, omittable)
is the ordinary delegation view. Field validity is checked by `delegate` /
`grant-guardian` (§3.2/§3.3) — a guardian shape passed to `delegate`, or a
`[gate …]` on a non-guardian delegation, → `cx-err:CXER4711 E_AUTHZ_ARG_INVALID`.

**The `[gate …]` predicate grammar — two predicate types only (§10.5).** A gate is
a boolean combinator (`all` / `any` / `not`) over leaves of exactly two types:

| Leaf | Form | Meaning |
|---|---|---|
| **`incapacity`** | `[incapacity [name@version …params]]` | the principal **cannot** act — references the signed library by `name@version` (§2.3, §3.5) |
| **`state`** | `[state [<op> /path value]]` | a harm/world threshold (CXPath predicate over journal-folded state) |

**No other leaf type exists**, and any leaf naming a principal's *choice*
(`declined` / `refused` / `consent` / `agrees` …) is **rejected at authoring**
(§4.4). This is the bright line as a type constraint: a refusal-triggered grant is
**not a value this language can produce.**

### §2.3. The incapacity-predicate library — `name@version`, signed + versioned

`incapacity` predicates are the **only** terms that can *enable* guardian action
([`xap.md`](xap.md) §22.5), so they are the module's most safety-critical trusted
surface. A gate references a predicate **by `name@version` from a signed,
versioned library** ([`xap.md`](xap.md) §22.8); **inline ad-hoc incapacity logic
is rejected at authoring** (§3.3/§3.5). The grant **binds the exact `name@version`**,
so a predicate cannot be silently redefined under existing grants.

The **initial library** ([`xap.md`](xap.md) §22.8), each entry will-independent,
observable, minimum-persistent, falsifiable-by-presence:

| Predicate | Meaning | Required params |
|---|---|---|
| `no-ack-within` | a request was issued; no ack in the window | `:duration`, `:of <prompt\|escalation>` |
| `unreachable` | all contact channels failed for a duration | `:principal`, `:via`, `:for` |
| `session-lost` | session dropped / no heartbeat | `:principal`, `:for` |
| `quorum-lost` | fewer than N of a role reachable | `:role`, `:need`, `:for` |
| `escalation-exhausted` | every tier tried, none acked | `:chain` |
| `operator-incapacitated` | attested sensor-derived incapacity | `:signal` (attested), `:for` |

Each library entry carries its **will-independence rationale**, its attested
signal sources (for physiological predicates), and a `signature` over the entry
([`xap.md`](xap.md) §22.8); the library is **versioned** as a whole and each
predicate as `name@version`. The five §10.8 invariants every entry MUST satisfy —
**will-independent, observable, minimum-persistence (a duration, no instantaneous
trigger), falsifiable-by-presence (acking/re-appearing makes it immediately
false), no-self-assertion (attested source for physiological/safety)** — are
guarantees (§4.5), verified by the two-validator model (§2.8).

### §2.4. A decision is a VALUE — `[permit]` / `[deny]`, not a fault (SAP §1)

`check` / `authorize` returns a **present value on the value channel**, never a
thrown fault, because *the request reached the PEP and got an answer* — exactly
analogous to a non-2xx HTTP status being a value, not an `[err]`
([`http.md`](http.md) §2.4):

```cx
[permit [delegation d-recon-77] [via [d-dana-ops d-recon-77]]   # the authority chain that granted it
  [tier :t1]]
[deny   [code cx-err:CXER4700]                                  # E_AUTHZ_UNAUTHORIZED — carried as DATA
  [reason :no-grant] [actor [agent x]] [capability refund-duplicate]
  [slice /orders/9] [tenant acme]]
```

A **deny is not an `[err]`** — it is the normal, expected outcome of a permission
check and **flows** so the bus can record it and the resolver can `explain` it. The
deny **carries `cx-err:CXER4700 E_AUTHZ_UNAUTHORIZED` as data** (its `[code …]`
child) so a caller that *wants* fail-closed escalation gets the canonical code; but
the value itself flows.

**Opt-in escalation (mirrors http `raise-for-status`).** `[$authz:authorize …]`
(the strict alias of `check`) takes `raise-on-deny=true` to turn a `[deny]` into a
**raised** `cx-err:CXER4700 E_AUTHZ_UNAUTHORIZED` at the call site, **carrying the
full `[deny]` value as a child** so diagnostics survive:
`[err code=cx-err:CXER4700 [deny …]]`. The **bus PEP uses the value form** and
records the deny — it does not raise ([`xap.md`](xap.md) §22.3). Off by default; the
value-channel posture is the norm.

`[err]` is reserved for **genuine faults** — the decision could not be computed:
malformed delegation/gate (`CXER4711`), bright-line violation at authoring
(`CXER4701`), signature/tier verification failure (`CXER4704`), unknown predicate
`name@version` (`CXER4706`), gate not well-formed (`CXER4702`), store/journal fault
on a persisting verb (`CXER4710`).

### §2.5. Absence vs present-deny — two distinct "no"s (SAP §1)

authz keeps two "no"s **structurally distinct**, the same no-conflation discipline
as net/http:

- **An absent delegation → the absence channel (empty node-set).** `find` (§3.4)
  for a delegation id that was never issued, or that is **revoked / expired**,
  returns the **empty node-set**, which flows inertly — *not* `null`, *not* a
  `[deny]`. Revocation/expiry is **absence**, not a recorded refusal: a revoked
  grant simply **isn't there** for `check`.
- **A present authorization "no" → a present `[deny …]` value (§2.4).** `check`
  is **total** — it always returns a present `[permit]` *or* `[deny]`; the deny is
  a present value carrying its reason, never absence and never `null`. So
  "no grant exists" (the absence input) is *resolved by `check` into* a present
  `[deny [reason :no-grant]]` (the value output) — the distinction the empty
  node-set alone cannot carry is recovered by the total decision function.

`null` is never produced by any authz verb.

### §2.6. Every authority transition is an attributed, hash-chained event (§10.6)

Issuing, revoking, arming-a-guardian-gate, and every **decision** are recorded as
events carrying `:actor` + `:authority` (basis) + `:tenant` via `journal`
([`xap.md`](xap.md) §22.6); the log is a hash chain → tamper-evident, and
audit + non-repudiation are free. authz **does not own** the log — the persisting
verbs (`delegate`/`revoke`/`grant-guardian`) call `[$journal:append …]`, and
`dry-run`/`explain` `fold`/query **over** it (§3.7). A `check` performed by the bus
is itself recorded by the bus at commit; a *pure* `check` the caller runs
standalone (§3.4) records nothing (it is referentially transparent — that is what
makes scenario dry-run deterministic and regression-gateable, §10.10.4).

### §2.7. Assurance / signing tiers T0 / T1 / T2 (§10.9) — bound on the grant, verified at the PEP

Two **orthogonal** integrity properties ([`xap.md`](xap.md) §22.9): *integrity of
history* (the `journal` hash chain — tamper-evident at every tier) and
*authorship non-repudiation* (how strongly an artifact binds to its author — what
the tiers govern). The `[assurance …]` field on a delegation declares the tier;
`verify-tier` (§3.5) checks it via `crypto`:

| Tier | Binding | Default use | authz verb |
|---|---|---|---|
| **T0 Session-attributed** | via the authenticated `session` TLS binding ([`xap.md`](xap.md) §22.1) | ordinary intents — don't tax every click | session presence (no signature) |
| **T1 Principal-signed** | `[$crypto:verify]` of the principal's signature over the grant | **delegations** and **guardian grants** | single-signature verify |
| **T2 Co-signed (M-of-N)** | `M` of `N` named principals must sign — a two-person rule | guardian grants for **irreversible / high-blast-radius** capabilities | M-of-N verify |

**Guardian grants are T1 minimum**, **T2 for irreversible capabilities**, and must
verify on **two axes before arming**: their own signature **and** the signed
predicate library they reference (§2.3) ([`xap.md`](xap.md) §22.9). The **PEP
verifies the required tier before permitting**; a tier/signature failure →
**a `[deny [reason :tier-unmet]]` value at the PEP**, or `cx-err:CXER4704
E_AUTHZ_VERIFY_FAILED` when called as a hard verification (`verify-tier`). Tier is a
policy knob bound on the grant, not a paradigm change.

### §2.8. Two-validator model — structural + semantic (§10.8)

Validation of a grant / gate / library entry uses the **two-validator model**
([`xap.md`](xap.md) §22.8): a **structural** validator (params present + correctly
typed; gate combinator well-formed; `name@version` resolvable) and a **semantic**
validator (will-independence + falsifiable-by-presence of every referenced
incapacity predicate; the ≥ 1-incapacity gate rule; the no-refusal-trigger
constraint). `gate-wellformed?` (§3.5) runs both and returns a `[valid]` /
`[invalid …]` **value**; `grant-guardian` runs both at authoring and **raises**
`CXER4701`/`CXER4702`/`CXER4706` on failure (a malformed grant must not become a
value, §4.4).

---

## §3. Public function surface

Signature notation matches [`cx-stdlib/io`](../std-lib/io.md) /
[`http.md`](http.md). `::duration` is a `cx-stdlib/time` duration;
`::element` is a `[principal]` / `[capability]` / `[delegation]` / `[permit]` /
`[deny]` / `[explanation]` value or an authority-store handle; `::map` is an options
record; `::path` is a CXPath. An optional read that may be absent is typed
`[returns element]` and yields the **absence channel** (empty) when nothing is
present (§2.5). A trailing `$opts::map {}` is a **defaulted positional parameter**
(`grammar.ebnf [153b]` — a bare space-separated VALUE after the type, as in
[`http.md`](http.md) §3.1), so it MAY be omitted.

### §3.1. Authority store construction (the trust-state backend)

```
[?def store    scope=public impure [returns element] ($opts::map {}) ...]
[?def close    scope=public impure [returns null]    ($handle::element) ...]
```

`store` opens an **authority store** — the impure handle over the
`journal`/`store`-backed trust state (issued/active/revoked delegations, the
predicate library, key material references) for one **tenant** (the tenant is a
hard partition, §4.6). It is the handle the persisting + live-read verbs take. No
network/identity access at construction; it carries the **`store`**
`caps`-capability requirement to its backend (§5). `close` is **idempotent** and
carries the closeable contract (`[?with-open]`-able, never raises `CXER0108`). `opts`:

| Key | Default | Meaning |
|---|---|---|
| `tenant` | — (required) | the tenant this store is partitioned to (§4.6) |
| `journal` | the tenant's journal | the `[$journal:…]` handle grants/decisions are appended to (§2.6) |
| `library` | the bundled signed library (§2.3) | the predicate library `name@version` resolves against |
| `keys` | session/IdP keyset | the `crypto` key material T1/T2 signatures verify against (§2.7) |
| `clock` | wall clock | time source for `until` / window predicates (the demo's controllable clock, [`xap.md`](xap.md) §25.1) |

### §3.2. Issue + revoke a delegation (the dial)

```
[?def delegate scope=public impure [returns element] ($store::element $delegation::element $opts::map {}) ...]
[?def revoke   scope=public impure [returns element] ($store::element $id $opts::map {}) ...]
```

- **`delegate`** validates and **issues** a `[delegation]` value (§2.2, ordinary
  `[mode :delegated]` form), appends an attributed issue-event to the journal
  (§2.6), and returns the **canonicalized, stored `[delegation]`** (with a resolved
  `until` instant and a content `id`/hash). It enforces **attenuation**: the issued
  grant's capabilities ∩ slice MUST be ⊆ the issuer's own currently-held authority
  (the `[attenuates …]` parent) — a request to convey **more** than the issuer
  holds → `cx-err:CXER4703 E_AUTHZ_ESCALATION` (privilege escalation is structurally
  impossible, §4.2). A guardian-shaped value here (it carries `[gate …]` /
  `[mode :guardian]`) → `CXER4711` (use `grant-guardian`). Sliding/adjusting the
  dial at any granularity ([`xap.md`](xap.md) §21.3) **is** a `delegate` call.
- **`revoke`** marks the delegation `id` revoked, appends an attributed
  revoke-event, and returns the **revoked** `[delegation]`. **Idempotent** —
  revoking an already-revoked/expired/absent id is a no-op that returns the
  absence channel (§2.5) (revocation is absence for `check`). `opts.cascade=true`
  also revokes everything that `[attenuates …]` this id (revoking an issuer's grant
  revokes what it sourced).

### §3.3. Issue a guardian grant (the §10.4 conditional pre-issued delegation)

```
[?def grant-guardian scope=public impure [returns element] ($store::element $grant::element $opts::map {}) ...]
```

`grant-guardian` issues a `[delegation [mode :guardian] [gate …] [action …] …]`
value (§2.2, §10.4). Before it stores anything it runs the **full two-validator
check** (§2.8) and **rejects at authoring** (it **raises**, never stores a bad
grant):

- the `[gate …]` must be **well-formed** — **≥ 1 `incapacity` predicate** (a gate
  of only `state` predicates could fire while the principal is present and
  declining → bright-line violation) — else `cx-err:CXER4702
  E_AUTHZ_GATE_ILLFORMED`;
- **no refusal-trigger** — any leaf branching on a principal's *choice* →
  `cx-err:CXER4701 E_AUTHZ_REFUSAL_TRIGGER` (the bright line, §4.4);
- every referenced incapacity predicate must **resolve by `name@version`** in the
  signed library and pass the **semantic** invariants (will-independence,
  falsifiable-by-presence) — an unknown/inline predicate → `cx-err:CXER4706
  E_AUTHZ_UNKNOWN_PREDICATE`, a predicate failing an invariant → `CXER4701`;
- the **signing tier** is verified per `[assurance …]` (T1 minimum for guardian;
  T2 required if any capability is marked irreversible) **on two axes** — the
  grant's own signature **and** the predicate library's signature (§2.7) — else
  `cx-err:CXER4704 E_AUTHZ_VERIFY_FAILED`;
- the `[action …]` must be **minimal/pinned** and within the grantor's authority
  (attenuation, §4.2) — over-broad → `CXER4703`.

On success it stores the grant **dormant** (`[dormant-until-gate true]`), appends
the issue-event, and returns the canonicalized `[delegation]`. The gate is **not
evaluated here** — it is evaluated at decision time by `check` (the bus PEP), and
a guardian grant permits **only while its gate holds** and **only the pinned
`[action …]`**.

### §3.4. The PEP decision function — `check` / `authorize` (pure; the single decision, §10.3/§10.10.3)

```
[?def check     scope=public pure [returns element] ($store::element $req::element $opts::map {}) ...]
[?def authorize scope=public pure [returns element] ($store::element $req::element $opts::map {}) ...]
[?def find      scope=public pure [returns element] ($store::element $id) ...]
[?def grants-of scope=public pure [returns [sequence element]] ($store::element $actor::element) ...]
```

**`check` is THE single decision function** ([`xap.md`](xap.md) §22.3, §22.10.3) —
one composition every intent passes through. It takes an **authorization request**:

```cx
[authz-request [actor [agent ops-agent-1]] [capability refund-duplicate]
  [slice /orders/9] [tenant acme] [as-of $now] [require-tier :t1]]
```

and returns a **`[permit]` or `[deny]` VALUE** (§2.4), computed as:

> permit **iff** the actor holds — through an **unbroken, unrevoked, unexpired,
> attenuating** delegation chain rooted at a principal (N-TRUST-1) — this
> **capability** over a slice that **covers** `slice`, in **this tenant** (the
> hard partition, §4.6), at the required **assurance tier** (§2.7), **and** (for a
> guardian grant) its **incapacity-typed gate holds as-of `as-of`** — clamped to
> the **effective envelope** (`effective`, §3.6).

It is **pure** over the materialized store snapshot (referentially transparent, no
journal write, capability-free) — which is exactly what makes scenario **dry-run**
deterministic and regression-gateable (§3.7, §10.10.4). The bus wraps `check` at
the live PEP and records the decision (§2.6); a standalone `check` records nothing.

- **`authorize`** is the **strict alias** of `check` — identical decision, but
  `opts.raise-on-deny=true` turns a `[deny]` into a raised `cx-err:CXER4700`
  carrying the `[deny]` (§2.4). `authorize` with the default `raise-on-deny=false`
  ≡ `check`.
- **`find`** — the delegation for `id`, or the **absence channel (empty)** if
  never-issued / revoked / expired (§2.5). Pure.
- **`grants-of`** — all currently-active (unrevoked, unexpired) delegations whose
  `[to …]` is `$actor`, in receive order. Pure.

`opts` for `check`/`authorize`: `as-of` (decision instant; default the store
clock), `require-tier` (`:t0`/`:t1`/`:t2`; default per the capability/grant),
`with-context` (a state snapshot for gate `state`-predicate evaluation; default the
journal-folded live slice), `raise-on-deny` (`authorize` only).

### §3.5. The incapacity-predicate library + gate well-formedness (the trusted surface)

```
[?def predicate        scope=public pure [returns element]            ($store::element $name-at-version::string) ...]
[?def predicates       scope=public pure [returns [sequence element]] ($store::element) ...]
[?def gate-wellformed? scope=public pure [returns element]            ($gate::element $opts::map {}) ...]
[?def verify-tier      scope=public impure [returns element]          ($store::element $grant::element $tier) ...]
```

- **`predicate`** — looks up a library predicate by **`name@version`** (§2.3),
  returning its `[predicate …]` value (params schema, will-independence rationale,
  attested signal sources, `signature`), or the **absence channel** if no such
  `name@version` (§2.5). An **inline / ad-hoc** predicate reference is never
  resolvable here — that is what makes inline incapacity logic unusable in a gate
  (§3.3).
- **`predicates`** — the whole signed library (all `name@version` entries).
- **`gate-wellformed?`** — runs the **two-validator** check (§2.8) over a `[gate …]`
  value **without** issuing anything (the authoring-time / dry-run check) and
  returns a **VALUE**: `[valid]`, or `[invalid [reason …] [code …]]` carrying the
  specific code (`CXER4701` refusal-trigger / `CXER4702` < 1 incapacity /
  `CXER4706` unknown predicate). Pure — this is the function `grant-guardian`
  delegates to, and the one a policy author / the resolver calls to check a gate
  before proposing it. `opts.library` overrides the library to validate against.
- **`verify-tier`** — verifies a grant's `[assurance …]` tier via `crypto` (T0
  session-presence / T1 single-signature / T2 M-of-N) on **both axes** for guardian
  grants (own signature + library signature, §2.7); returns `[verified [tier …]]`
  or **raises** `cx-err:CXER4704 E_AUTHZ_VERIFY_FAILED`. Impure (touches keys/store).

### §3.6. Effective envelope — the §9.5 intersection (pure)

```
[?def effective scope=public pure [returns element] ($store::element $actor::element $opts::map {}) ...]
```

`effective` computes the **effective allowed-set** for `$actor` in a context — the
[`xap.md`](xap.md) §21.5/§21.6 composition:

```
effective = individual-setting ∩ ⋂(superior, managing-agent, collective gates)
```

— **envelopes intersect, most-restrictive-wins**; constraints can only *restrict*,
never expand, never beyond the grantor's own authority (attenuation, §4.2). It
returns an `[envelope …]` value (an allowed-set of capabilities/slices/dial-modes,
e.g. a ceiling `≤ semi-auto`, a floor `≥ turn-by-turn`, a single mode, or a band).
`check` clamps every decision to this envelope (§3.4). Each envelope-setter must
hold a **legitimate, recorded authority relationship** (a supervisor/guardian over
a subordinate; a managing agent over a managed agent) — an envelope asserted
without a recorded relationship is **ignored** (it cannot bind, §4.3). Pure over
the store snapshot. `opts.context` supplies the contextual/collective state the
gates read (§9.5).

### §3.7. Dry-run / explain — "why can / can't X do Y?" (pure, deterministic, §10.10.4)

```
[?def dry-run scope=public pure [returns element]            ($store::element $req::element $opts::map {}) ...]
[?def explain scope=public pure [returns element]            ($decision::element) ...]
[?def trace   scope=public pure [returns [sequence element]] ($store::element $req::element $opts::map {}) ...]
```

The configuration-tractability answer ([`xap.md`](xap.md) §22.10.4): scenarios are
conformance fixtures validated by **dry-run** over the **real decision function**
(§3.4) — deterministic (the journal + policy stack are pure data), repeatable,
regression-gated.

- **`dry-run`** runs `check` over an explicit scenario (a supplied store snapshot /
  state slice in `opts.state`, an `as-of` instant) **without** any journal write,
  returning the same `[permit]`/`[deny]` value — so "Could a student ever go
  full-auto on a freeway?" / "Could an agent ever act on refusal?" are answered by
  *running it*, not arguing it.
- **`explain`** turns a `[permit]`/`[deny]` into a human-/agent-readable
  `[explanation …]` — the **authority chain** that granted it (or the **first
  failing link**: no grant / revoked / expired / out-of-slice / tenant-mismatch /
  tier-unmet / gate-not-holding / envelope-clamped), each step naming the
  delegation id + its basis. This is the value the §9.1 handoff brief and the
  resolver surface to the principal ("why is this here?").
- **`trace`** returns the **ordered policy-stack evaluation** (every envelope
  intersection + every gate-predicate truth value + the attenuation checks) for a
  request — the deep-debug view behind `explain`.

All three are **pure** and **deterministic** — identical inputs → identical output
— which is the property the §10.10.4 regression gate relies on.

---

## §4. Semantics & guarantees (soundness) — the §14 invariants, restated as module guarantees

Every guarantee here **is** a [`xap.md`](xap.md) §22/§26 invariant; this module
adds none — it makes them properties of the surface.

### §4.1. N-TRUST-1 — authority originates only from principals
Every permit `check` returns traces, through its `[via …]` chain, to a
`[principal …]` root ([`xap.md`](xap.md) §26, §22). A delegation with no
principal-rooted `[attenuates …]` ancestor cannot be issued (`delegate` →
`CXER4703`) and cannot permit. The agent **never holds un-granted authority**
(N-CONTROL-1).

### §4.2. Attenuation — privilege escalation is structurally impossible
A delegation's `(capabilities ∩ slice)` MUST be **⊆ the issuer's own held
authority**; `delegate`/`grant-guardian` reject any over-grant with `cx-err:CXER4703
E_AUTHZ_ESCALATION` ([`xap.md`](xap.md) §22.2, §21.5). Envelope composition is
**intersection only** (§3.6) — it can never expand authority. Grants are
**time-bounded + revocable → self-pruning** (default-deny object-capability,
[`xap.md`](xap.md) §22.10.2), which kills RBAC role-explosion at the root.

### §4.3. N-CONTROL-2 — ultimate Accountable is always a principal
A guardian action, though Agent-Responsible, keeps the **grantor Accountable**
([`xap.md`](xap.md) §21.4, §26); `explain` always resolves the Accountable party to
a principal. An envelope-setter (supervisor/guardian/managing-agent) must hold a
**recorded authority relationship**; an asserted-but-unrecorded relationship is
**ignored** (§3.6) — *a principal-over-principal envelope is legitimate by
relationship, never an agent overriding a human* ([`xap.md`](xap.md) §21.5).

### §4.4. N-CONTROL-1 — the bright line, made unforgeable (the most load-bearing guarantee)
> *The agent may act when the human **cannot**; it must **never** act when the
> human **will not**.* ([`xap.md`](xap.md) §21.2, §22.5, §26)

This is enforced as a **type constraint on the grant language**, at **authoring
time**, not as a runtime policy check:

1. The `[gate …]` grammar admits **only** `incapacity` and `state` leaves (§2.2).
   A leaf branching on a principal's *choice* (`declined`/`refused`/`consent`/…)
   is **not parseable as a gate leaf** and `grant-guardian`/`gate-wellformed?`
   reject it → `cx-err:CXER4701 E_AUTHZ_REFUSAL_TRIGGER`. **A refusal-triggered
   grant cannot be expressed**, so the agent cannot hold one.
2. A gate is **well-formed only with ≥ 1 `incapacity` predicate** (a state-only
   gate could fire while the principal is present and declining) → else
   `cx-err:CXER4702 E_AUTHZ_GATE_ILLFORMED` ([`xap.md`](xap.md) §22.8).
3. Every `incapacity` predicate is **will-independent + falsifiable-by-presence**
   (§4.5): *the moment the human can act, guardian authority evaporates*, and a
   returning human always reclaims control ([`xap.md`](xap.md) §21.2, §22.8
   invariant 4). `check` therefore returns `[deny]` for a guardian grant the
   instant the principal re-engages — without any explicit revocation.

### §4.5. The incapacity-predicate library invariants (§10.8)
Every library predicate satisfies, and `gate-wellformed?`'s semantic validator
checks: **(1) will-independent** (truth independent of the principal's will);
**(2) observable** (only logged/attested signals, no opaque inference);
**(3) minimum-persistence** (a duration, no instantaneous trigger);
**(4) falsifiable-by-presence** (acking/re-appearing → immediately false);
**(5) no-self-assertion** (physiological/safety predicates require an **attested
independent signal source**, never the agent's own judgment)
([`xap.md`](xap.md) §22.8). Adding/changing a library predicate is a
**high-privilege, logged, attributed governance action** shipping with its
will-independence rationale + a conformance fixture proving it is true only under
genuine incapacity and **false the instant the principal re-engages**. The library
is **signed + versioned**; grants bind `name@version`, so a predicate cannot be
silently redefined under existing grants (§2.3).

### §4.6. Tenant is a hard partition (§10.6)
Every artifact carries `[tenant …]`; an authority store is opened **per tenant**
(§3.1); a `check` whose request tenant ≠ the store tenant → `[deny [reason
:tenant-mismatch]]`, and **cross-tenant delegation is unissuable** (`delegate`
across tenants → `CXER4711`). Slice namespaces are tenant-rooted; cross-tenant
access is **structurally impossible** ([`xap.md`](xap.md) §22.6, §26).

### §4.7. One enforcement point, one decision function (§10.3 / §10.10.3)
All authority resolves at the **bus PEP** through the single `check` composition
(§3.4); this module is the only place the decision is **computed**, the bus the
only place it is **enforced**. One function to test; every intent passes through
it. The structural invariants above **shrink the validation space** — the worst
cases (refusal-triggered grants, escalation, accountability leaving a principal)
are **simply not in the language** ([`xap.md`](xap.md) §22.10.5).

### §4.8. Decisions and absences never conflate; nothing is `null`
A permit/deny is a present value (§2.4); a revoked/expired/never-issued delegation
is absence (§2.5); the two are recovered by `check`'s totality. `null` is never
produced (§2.5).

## §5. Capability integration (`caps` — the DISTINCT system, §security.md)

> **Implementation tier (this revision).** The authority store is an
> **in-process, per-program** trust-state registry (minted by `store`, reset at
> program start — the same posture as the `cx-stdlib/session` registry), NOT yet
> a durable `journal`/`store`-backed backend. Two consequences are scoped to a
> later revision: (1) trust state does **not survive process restart** (a
> persisted-grant-then-reopen path is deferred); (2) the persisting/live-read
> verbs (`store`/`delegate`/`revoke`/`grant-guardian`/`verify-tier`) do **not
> yet** route through the `store` `caps`-capability, so `CXER0271`/`CXER4710`
> on a denied/faulted backend are declared but not raised here. The decision
> logic below (attenuation, time-bounding, revocation, gate well-formedness,
> the PEP) is fully implemented over the in-process snapshot; only the *durable
> backing* and its `caps`-gating are deferred. This is not claimed implemented.

> **Restating the boxed note in capability terms.** authz **introduces no new
> `caps`-capability** and gates **no machine effect** of its own. Its only effects
> are **reads/writes of trust state** through the `journal`/`store` backend, so
> those are gated by the **existing `store`** `caps`-capability
> ([`store.md`](../std-lib/store.md) §9, [`security.md`](../core/security.md)) —
> the same way `cx-stdlib/http` reuses `net` and introduces none of its own
> ([`http.md`](http.md) §5). **An authz *permit* is not a `caps`
> grant**: `check` returning `[permit [do :pause-payment-gateway]]` authorizes the
> *intent*; the process must **still** hold the `net` `caps`-capability for the
> effect that intent performs. The two gates are **AND-composed** — an action
> proceeds only if authz permits **and** `caps` allows. Conversely a `caps`-allowed
> effect with no authz delegation is still `[deny]`'d at the PEP.

| Operation | `caps`-capability | Resource matched |
|---|---|---|
| `store` / `close` | `store` | the trust-state backend URL (per `store.md` §9) |
| `delegate` / `revoke` / `grant-guardian` | `store` | the backend (writes the issue/revoke/arm event via `journal`) |
| `verify-tier` | `store` | reads keys/library from the backend (the `crypto` verify itself is pure compute) |
| `check` / `authorize` / `find` / `grants-of` / `effective` / `predicate` / `predicates` / `gate-wellformed?` / `dry-run` / `explain` / `trace` | — | **pure** over the materialized store snapshot (§3.4/§3.6/§3.7) |

A backend denial raises the **shared core** `cx-err:CXER0271 E_CAP_DENIED` naming
the missing `store` grant + resource (the standard effect-point code,
[`security.md`](../core/security.md) §4) — **not** an authz-band code.
`cx-err:CXER4700 E_AUTHZ_UNAUTHORIZED` (this module's band) is the **authorization**
"no" (a principal didn't delegate authority); `CXER0271` is the **effect-permission**
"no" (the process can't touch the resource). They are different denials and never
substitute (the §1 boxed note, made operational).

## §6. Composition with the integration layer

Canonical call form is `[$authz:VERB …]` (`[head …]`); this module uses no infix.

```cx
[?with-open [$authz:store {tenant: 'acme'}] $az
  [$authz:delegate $az
    [delegation d-recon-77 [tenant acme] [from [principal dana]] [to [agent ops-agent-1]]
      [capabilities [refund-duplicate]] [over /orders[= $_@charge-state "erroring"]]
      [attenuates d-dana-ops] [until [+ $t0 1h]] [revocable true]]]]
```

The **bus PEP** calls `check` before committing every intent ([`xap.md`](xap.md)
§22.3); the integration is "build the `[authz-request]` from the intent's
actor/capability/slice/tenant → `[$authz:check $az $req]` → permit ⇒ commit, deny ⇒
record the `[deny]` + route per `[err]`-as-value":

```cx
[?match [$authz:check $az [authz-request [actor $a] [capability $cap]
                            [slice $slice] [tenant acme]]]
  [case [permit @via=$v] [$bus:commit $intent]]                  # a VALUE — permit
  [case [deny @reason=:tier-unmet] [$session:step-up $a]]        # a VALUE — deny (step up)
  [case [deny $d] [$journal:append [audit-deny $d]]]             # a VALUE — deny (record)
  [case [err @code=$c] [err code=$c]]]                           # a genuine FAULT — re-raise
```

- **Decision handling is `[?match]` on shape**, never `[?try]` (SAP §2): a `[deny]`
  is a **value** (§2.4) handled in a `[case]`, not a caught exception; `[err]` is a
  genuine fault. `[?else [$authz:check …] [permit …]]` would default on **fault or
  absence**, *not* on a `[deny]` value (a deny flows through `[?else]`).
- **`bus` (the PEP)** — `bus` calls `check` and records the decision (§2.6); authz
  never re-implements the enforcement.
- **`journal`** — `delegate`/`revoke`/`grant-guardian` append attributed events
  (§2.6); `dry-run`/`explain`/`trace` fold/query over the journal (§3.7).
- **`session`** — supplies the `(principal, tenant)` for T0 attribution and the
  `as-of` actor identity ([`xap.md`](xap.md) §22.1, §25.1).
- **`crypto`** — `verify-tier` and the §3.3 arming check call `[$crypto:verify]` /
  M-of-N verify; the predicate library's `signature` is a `crypto` signature.
- **`xap` orchestrator / resolver** — proposes dial settings (= delegations) from
  observed behavior and authors/curates policy (XAP applied to itself,
  [`xap.md`](xap.md) §22.10.1); authz supplies the **values + the decision**, the
  resolver the **ergonomics**.
- **`[?with-open]`** ([`code.md`](../core/code.md) §8.10.7) auto-closes the store;
  idempotent with explicit `close`.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | ordinary delegation | guardian grant | a `[gate …]` value alone |
|---|:--:|:--:|:--:|
| `delegate` (issue) | ✅ | ❌ ¹ | — |
| `grant-guardian` (issue) | ❌ ² | ✅ | — |
| `revoke` | ✅ | ✅ | — |
| `check` / `authorize` | ✅ | ✅ ³ | — |
| `find` / `grants-of` | ✅ | ✅ | — |
| `effective` (envelope) | ✅ | ✅ | — |
| `gate-wellformed?` | — ⁴ | ✅ | ✅ |
| `verify-tier` | ✅ ⁵ | ✅ ⁵ | — |
| `dry-run` / `explain` / `trace` | ✅ | ✅ | — |

| Gate leaf type | in a guardian `[gate …]` |
|---|:--:|
| `incapacity` (signed-library `name@version`) | ✅ |
| `state` (CXPath harm/world threshold) | ✅ ⁶ |
| `incapacity` **inline / ad-hoc** (not in the library) | ❌ ⁷ |
| **refusal-trigger** (`declined`/`refused`/`consent`/choice) | ❌ ⁸ |

| Assurance tier | delegation | guardian grant |
|---|:--:|:--:|
| T0 session-attributed | ✅ | ❌ ⁹ |
| T1 principal-signed | ✅ | ✅ (minimum) |
| T2 co-signed M-of-N | ✅ | ✅ (required if irreversible) |

Footnotes: **1** a guardian-shaped value (carries `[mode :guardian]`/`[gate …]`)
passed to `delegate` → `CXER4711`; use `grant-guardian`. **2** an ordinary
delegation (no gate) passed to `grant-guardian` → `CXER4711`. **3** a guardian
grant permits **only while its gate holds** and **only its pinned `[action …]`**
(§3.3, §4.4); otherwise `[deny]`. **4** an ordinary delegation has no gate — there
is nothing to validate (use `gate-wellformed?` only on a `[gate …]`/guardian
grant). **5** T0 verification is session-presence (no signature); T1/T2 verify
signatures via `crypto`. **6** a `state` leaf is **only** valid **ANDed with** ≥ 1
`incapacity` (a state-only gate is ill-formed → `CXER4702`, §4.4); time
pressure / deadlines / harm thresholds are `state`, never `incapacity` (§10.8).
**7** inline incapacity logic is **rejected at authoring** — predicates resolve
only by signed-library `name@version` → `CXER4706` (§2.3, §3.5). **8** the bright
line: refusal-triggers are **unexpressible** → `CXER4701` (§4.4) — the single most
load-bearing ❌ in this matrix. **9** guardian grants are **T1 minimum** (they
authorize action while a human *cannot* intervene) — a T0 guardian grant is
rejected at authoring → `CXER4704` (§2.7, §10.9).

Cognate-coverage: every issuing verb pairs with `revoke`; the decision pair
(`check`/`authorize`) and the explain trio (`dry-run`/`explain`/`trace`) work on
both delegation kinds; every gate-leaf and every assurance tier has an explicit
✅/❌ with rationale. The intentional ❌s (refusal-triggers, inline predicates, T0
guardian) are the **bright-line guarantees**, pinned by negative fixtures (§10) —
each a **deliberate impossibility of the model**, not an open cell.

## §8. Error codes — `CXER4700–CXER4799` band (proposed allocation)

`CXER4700–CXER4799` is proposed for `cx-stdlib/authz` in the governance registry
([`governance.md`](../process/governance.md) §9.6), the next free **century block**
above `cx-stdlib/http`'s `CXER4525–4543` (and clear of `net`'s 4500-band). This
revision uses `CXER4700–4712`; the rest of the century is reserved for authz. All
values use `cx-err:` notation; symbolic↔wire is 1:1 (governance invariant).
**`CXER4700 E_AUTHZ_UNAUTHORIZED` is the CXER-UNAUTHORIZED-equivalent** — the
canonical authority-denied code ([`xap.md`](xap.md) §22.3 "`[err [code
:CXER-UNAUTHORIZED]]`"); it is carried **as data** in a `[deny]` value (§2.4) and
**raised** only under `authorize raise-on-deny=true`. **Cancellation is the core
`CXER0260`, not an authz code** (§0); the **`caps`** effect-denial is the core
`CXER0271`, **not** an authz code (§5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4700` | `E_AUTHZ_UNAUTHORIZED` | the canonical **authority-denied** code (the §10.3 `CXER-UNAUTHORIZED` equivalent): carried as data in every `[deny]` (§2.4); **raised** only under `authorize raise-on-deny=true`, carrying the full `[deny]` |
| `cx-err:CXER4701` | `E_AUTHZ_REFUSAL_TRIGGER` | a guardian `[gate …]` leaf branches on a principal's **choice** (`declined`/`refused`/`consent`/…) — the **bright line**, rejected at authoring (§4.4) |
| `cx-err:CXER4702` | `E_AUTHZ_GATE_ILLFORMED` | a guardian `[gate …]` has **< 1 `incapacity` predicate** (state-only gate), or a malformed combinator (§3.3, §4.4) |
| `cx-err:CXER4703` | `E_AUTHZ_ESCALATION` | a delegation/guardian `[action …]` would convey **more** than the issuer holds — attenuation violation (§3.2, §4.2) |
| `cx-err:CXER4704` | `E_AUTHZ_VERIFY_FAILED` | assurance-tier verification failed (bad/absent signature, M-of-N quorum unmet, library signature invalid, or a T0 guardian grant) (§2.7, §3.5) |
| `cx-err:CXER4705` | `E_AUTHZ_EXPIRED` | a grant past `until` was used where a hard (non-value) failure is required (e.g. `verify-tier`); in `check` this surfaces as `[deny [reason :expired]]` / absence (§2.5), not this code |
| `cx-err:CXER4706` | `E_AUTHZ_UNKNOWN_PREDICATE` | a gate references an incapacity predicate `name@version` **not in the signed library**, or inline ad-hoc incapacity logic (§2.3, §3.5) |
| `cx-err:CXER4707` | `E_AUTHZ_REVOKED` | a revoked grant used where a hard failure is required; in `check` revocation is **absence** (§2.5), not this code |
| `cx-err:CXER4708` | `E_AUTHZ_TENANT_MISMATCH` | a cross-tenant operation where a hard failure is required; in `check` a tenant mismatch is `[deny [reason :tenant-mismatch]]` (§4.6) |
| `cx-err:CXER4709` | `E_AUTHZ_NO_RELATIONSHIP` | an envelope-setter (supervisor/guardian/managing-agent) lacks a **recorded authority relationship** asserted as a hard failure; in `effective` an unrecorded relationship is **ignored** (§3.6, §4.3) |
| `cx-err:CXER4710` | `E_AUTHZ_STORE_FAULT` | the trust-state backend (journal/store) faulted on a persisting/live-read verb (distinct from the `caps` denial `CXER0271`, §5) |
| `cx-err:CXER4711` | `E_AUTHZ_ARG_INVALID` | malformed/mis-shaped artifact: guardian shape to `delegate` (or ordinary shape to `grant-guardian`), `[gate …]` on a non-guardian delegation, cross-tenant `delegate`, or a `check` request missing required fields (§2.2, §3.2, §4.6) |
| `cx-err:CXER4712` | `E_AUTHZ_HANDLE_CLOSED` | an op on a closed authority `store` handle |

**Shared/core codes authz surfaces (not in its band):** `cx-err:CXER0271`
(`caps` effect-denial on the `store` backend, §5); `cx-err:CXER0260` (cancellation,
§0); `cx-err:CXER0108` never raised (the store handle is closeable, §3.1).

**The bright-line codes are the band's spine.** `CXER4701` (refusal-trigger) and
`CXER4702` (gate ill-formed) are the **type-level enforcement of N-CONTROL-1** — a
malformed guardian grant **cannot become a value** (§4.4); `CXER4703` (escalation)
enforces attenuation (N-TRUST-1/§4.2); `CXER4700` is the runtime authority-denied
result. These four carry the §14 invariants.

## §9. Implementation notes (non-normative) — composing crypto + journal + store

| authz surface | Building block | Note |
|---|---|---|
| `store`/`close` | `journal` handle + `store` backend ([`store.md`](../std-lib/store.md)) | per-tenant partition (§4.6); closeable handle |
| `delegate`/`revoke`/`grant-guardian` | `[$journal:append …]` of an attributed issue/revoke/arm event | attenuation check ⊆ issuer authority before append (§4.2); guardian two-validator before append (§2.8) |
| `check`/`authorize` | pure fold over the store snapshot: chain-walk `[attenuates …]` to a principal root, slice-cover via CXPath, tenant equality, `until`/revoked filter, tier check, gate eval, envelope clamp | **pure** — no append (the bus records the decision); determinism is what makes dry-run a regression gate (§10.10.4) |
| `gate-wellformed?` | structural (params/combinator) + semantic (will-independence, falsifiable-by-presence, ≥1-incapacity, no-refusal-trigger) validators (§2.8) | returns a `[valid]`/`[invalid]` **value**; `grant-guardian` reuses it and raises |
| `predicate`/`predicates` | the signed, versioned library (bundled default; `opts.library` override) | `name@version` lookup; `[$crypto:verify]` of each entry's `signature` |
| `verify-tier` | `[$crypto:verify]` (T1) / M-of-N verify (T2) / session-presence (T0) | guardian = two-axis (own signature + library signature, §2.7) |
| `effective` | intersection of the actor's individual setting with superior/managing-agent/collective envelopes, gated by recorded relationships | most-restrictive-wins (§3.6, §4.3) |
| `dry-run`/`explain`/`trace` | `check` over an `opts.state` snapshot; chain/first-failing-link reconstruction; ordered policy-stack trace | all pure + deterministic (§10.10.4) |

Spec is implementation-agnostic; only surface + guarantees are normative. The
existing capability-enforcement plumbing (`CXER0271` at effect points,
[`security.md`](../core/security.md)) is **untouched** — authz is the *authority*
layer above it, never a reimplementation of `caps` (the §1/§5 distinction).

## §10. Conformance fixtures (to author on graduation)

Hermetic; an in-memory authority store seeded with principals + a stub signed
predicate library; deterministic clock. **Every matrix ✅ has ≥ 1 positive fixture;
every justified ❌ a negative fixture.**

Positives: issue an ordinary `delegate` (attenuation ⊆ issuer holds) → `check`
permits the in-scope intent and **`[deny]`s** an out-of-slice / out-of-tenant /
unheld-capability one (deny is a **VALUE**, not `[err]`, §2.4); `revoke` →
subsequent `check` `[deny]`s and `find` returns **absence** (§2.5); `revoke
cascade` revokes attenuated children; **time-bound** — `check as-of past until` →
`[deny [reason :expired]]`; `grant-guardian` with a well-formed gate (≥ 1
incapacity ANDed with a state predicate) stores dormant and `check` permits the
**pinned action only while the gate holds**; **falsifiable-by-presence** — the same
guardian `check` **flips to `[deny]` the instant the principal re-engages**
(invariant 4, no explicit revoke); `effective` intersection (individual ∩ superior
∩ managing-agent ∩ collective) → most-restrictive-wins, and an **unrecorded**
envelope relationship is **ignored**; T1 single-signature and T2 M-of-N
`verify-tier` succeed on valid signatures; `dry-run` reproduces a `check` decision
**deterministically** (same inputs → same `[permit]`/`[deny]`); `explain` yields the
principal-rooted authority chain on a permit and the first-failing-link on a deny;
`authorize raise-on-deny=true` raises **`CXER4700` carrying the `[deny]`**; the
`caps`/authz **composition** — an authz-permitted intent whose effect lacks the
`net` `caps`-grant still hits `CXER0271` (the two gates AND-compose, §5).

Negatives (the bright-line spine): a guardian `[gate …]` with a **refusal-trigger**
leaf (`[declined …]`) → `CXER4701` at authoring; a **state-only** gate (< 1
incapacity) → `CXER4702`; an **inline / non-library** incapacity predicate →
`CXER4706`; an **over-broad** delegation/guardian action (escalation) → `CXER4703`;
a **T0 guardian** grant → `CXER4704`; a guardian grant with a **bad/absent
signature** or **unmet M-of-N quorum** → `CXER4704`; a guardian referencing a
predicate `name@version` **absent from the signed library** → `CXER4706`; a
**guardian shape to `delegate`** / ordinary shape to `grant-guardian` / `[gate …]`
on a non-guardian / **cross-tenant `delegate`** → `CXER4711`; an op on a **closed
store** → `CXER4712`; a **store/journal backend fault** → `CXER4710`; the **`store`
`caps`-grant absent** → `CXER0271` (core, not the authz band). Each ❌ in §7 maps to
exactly one negative fixture above.

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      add `CXER4700–CXER4799 | cx-stdlib/authz | spec/std-lib/authz.md`; re-run the
      band scan (confirm no overlap with http's `CXER4525–4543`, net's `4500–4524`,
      fp's `4400–4409`).
- [ ] **Module index + count** ([`spec/std-lib/README.md`](../std-lib/README.md)
      §3, Tier-B): add an `authz` row and bump the sub-package count by **+1 on the
      then-current count** (order-independent with the other in-review XAP modules
      `bus`/`journal`/`session`/`xap`, each its own +1). Add the bundled name
      `'cx-stdlib/authz'` to `vcx/tests/stdlib_skeleton_test.v` and bump its
      asserted count.
- [ ] **The five XAP modules graduate as a coherent set** — `authz` depends on
      `journal` (the attributed log) + `crypto` (signing) and is **called by**
      `bus` (the PEP). Cross-reference the **sibling specs** once authored:
      `bus.md`, `journal.md`, `session.md`, `xap.md`
      (forthcoming under `spec/02-inprogress/xap/`).
- [ ] **`crypto` JWT/JWKS + sign/verify must be available** (hard dependency for
      T1/T2 and the signed predicate library, [`xap.md`](xap.md) §25.1); the
      `time` duration / **timer-event** enhancement is needed for the
      window-predicates (`no-ack-within "10m"`).
- [ ] Implement the §3 surface on `crypto` + `journal` + `store`: `store`/`close`;
      `delegate`/`revoke`/`grant-guardian`; `check`/`authorize`/`find`/`grants-of`;
      `predicate`/`predicates`/`gate-wellformed?`/`verify-tier`; `effective`;
      `dry-run`/`explain`/`trace`. **The bus PEP must call `check` and re-implement
      no decision** ([`xap.md`](xap.md) §22.3).
- [ ] **Author + sign the initial incapacity-predicate library** (the six §10.8
      predicates) with each entry's will-independence rationale, attested signal
      sources, and a conformance fixture proving falsifiable-by-presence
      ([`xap.md`](xap.md) §22.8); version it; bundle it as the `store` default.
- [ ] Confirm reliance on the §0 in-review amendments survived G3 (four-channel
      **decision-is-a-value**, `[?try]` retirement, `CXER0260` cancellation,
      orthogonality-guard home), and that the `caps`/authz distinction (§1/§5) is
      reflected wherever `code.md`/`security.md` describe the two systems.
- [ ] Author §10 fixtures (positive + the bright-line negative spine); wire into
      the gate. **The §10.10.4 scenario fixtures** ("Could a student go full-auto?"
      / "Could an agent act on refusal?") are `dry-run` regression fixtures.
- [ ] Validate repo-relative cross-references render.
- [ ] Move `spec/02-inprogress/xap/authz.md` → `spec/std-lib/authz.md`
      (user-only).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states how the count moves at graduation; per Rule G3 it makes **no
edits**.

**`authz` is a NEW bundled name (a genuine +1), not a reconciliation.** Unlike
`http` — which corrected the README to match an *already-bundled* name
([`http.md`](http.md) §12) — `cx-stdlib/authz` is **not yet
bundled**: it is absent from `vcx/tests/stdlib_skeleton_test.v`'s expected list.
So each of the five XAP modules (`bus`, `journal`, `authz`, `session`, `xap`) is a
genuine **+1** at its own graduation, applied to **whatever the current count is**
(order-independent, exactly as `net`/`fp` each +1 over the post-`http` baseline,
[`http.md`](http.md) §12). At `authz`'s graduation:

| Target (by section/symbol) | Change |
|---|---|
| `README.md` §3 intro + §3.2 frozen-surface sentence | count **+1** (current → current+1) |
| `README.md` §3 Tier-B table | add `\| authz \| XAP trust model — principals, delegation, guardian grants, the PEP decision function (built on crypto; distinct from caps) \| [authz.md](authz.md) \|` |
| `stdlib_skeleton_test.v` — `test_stdlib_surface_enumerates_bundled_subpackages` | add `'cx-stdlib/authz'` to `expected`; bump the asserted count **+1** |

**No edits are made by this draft** (G3) — the table above is for the graduation PR.

---

### Review questions — RESOLVED (user G3, 2026-06-07)

**All resolved as drafted:** (1) `check` returns a `[permit]`/`[deny]` **value** (SAP §1), with `authorize raise-on-deny=true` the fail-closed alias — value-by-default kept; (2) keep **both** named verbs (`check` pure-value + `authorize` strict alias) for bus call-site clarity; (3) keep the four hard-failure code duals (`CXER4705`/`4707`/`4708`/`4709`) for the verification verbs / `raise-on-deny` — in `check` these stay `[deny [reason …]]` values; (4) re-pin the `bus`/`journal`/`session`/`xap` cross-references to their actual surfaces at graduation (mechanical, no blocker). Rationale below.


1. **Decision-is-a-value vs. raise-by-default.** This draft makes `check` return a
   `[permit]`/`[deny]` **value** (SAP §1, mirroring http non-2xx-as-value), with
   `authorize raise-on-deny=true` as the opt-in fail-closed alias. Settled (a) in
   this draft; flag if you want the PEP-facing default to be **raise** instead.
2. **Two names — `check` (pure value) + `authorize` (strict alias).** Mirrors
   http's `get`/`raise-for-status` split as **one function + an opt**, but exposes
   it as **two named verbs** for call-site clarity at the bus. Confirm you want
   both names, or collapse to `check` + an opt only.
3. **`CXER4705`/`CXER4707`/`CXER4708`/`CXER4709` are "hard-failure" duals of
   value-channel deny reasons** (expired / revoked / tenant-mismatch /
   no-relationship). In `check` these are `[deny [reason …]]` **values** (or
   absence); the codes exist only for the *verification* verbs that must fail hard
   (`verify-tier`) or for `raise-on-deny`. Confirm you want the duals, or fold them
   all into `CXER4700`'s `[deny [reason …]]` and drop the four codes.
4. **Sibling-spec sequencing.** This is the first of the five XAP modules drafted.
   `authz` cross-references `bus`/`journal`/`session`/`xap` as **forthcoming**; once
   their specs land, the §6 composition examples and §11 dependencies should be
   re-pinned to their actual surfaces. (No blocker — `authz` stands on the settled
   [`xap.md`](xap.md) §22 model.)
