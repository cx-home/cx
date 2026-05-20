# BaseX Function Module Wrap Roadmap

**Status:** Draft (2026-05-17, amended 2026-05-18). **v0.8.0 target** per
[ADR 0022 §D2 Amendment 2026-05-17 #3](decisions/0022-cx-is-one-language-v0_7_0-scope.md)
and the user-directed sequencing (2026-05-17): v0.8.0 ships the
BaseX-class function-module wrap as a single tag, mirroring v0.7.0's
single-cut discipline for the XQuery 4.0 expression-parity work.

**Amendment 2026-05-18 — registry framework lands at v0.7.0; `log:`
pulled forward to v0.7.0.**
[ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md)
pulls the function/module extension interface forward into v0.7.0
alongside the `cx:` self-host module. ADR 0023 Amendment #1
(2026-05-18) additionally pulls the **`log:` structured-logging
module** forward from v0.8.0 Tier B to v0.7.0 — operational pipelines
need structured logging from the format/API stability boundary
outward, and locking the namespace at v0.7.0 means the rest of the
modules below slot in around a settled logging surface. By v0.8.0,
the registry, the `[?cx use-module=...]` activation directive, the
per-module capability bits, the determinism classification (Pure /
ReadOnly / SideEffect), the `[?cx pure-only]` directive, the eval-
gate pattern (five mitigations per ADR 0023 §D6), the `log:` module,
and the evaluator-hook signature (per ADR 0023 §D11) all exist.
v0.8.0's job shrinks correspondingly: each remaining Tier-2 module
below is a registry registration + purity tag + capability bit +
per-binding wiring + conformance fixtures. The framework is no
longer co-designed with the modules. The `CXER-FOSE*` error namespace
(gate / purity violations) is already in place at v0.7.0; new module-
specific errors register under `CXER-FOFI*` (file), `CXER-FOHT*`
(http), etc., as each Tier-2 module lands.

**Purpose.** Cxl at v0.7.0 reaches XQuery 4.0 expression parity
(per [`xquery_40_parity.md`](xquery_40_parity.md)) — the *language*
ceiling matches. To be operationally useful for real-world data
processing systems comparable to those built on XQuery+BaseX, cxl
also needs a function-module ecosystem peer to BaseX's
([docs.basex.org/main/Functions](https://docs.basex.org/main/Functions)).

This document catalogs BaseX's function modules with cx mapping
intent, priority for cx wrapping, and rough sequencing.

**Scope decision.** Most BaseX modules are wrapped or implemented
in cx over v0.7.x and v0.8.0+. A small set has cx-native equivalents
already. A few are out-of-scope for cx (BaseX-storage-specific).
Cx-native database ability (parallel to BaseX as a database) is
**possible but not committed** and lives in a separate future
conversation.

**Status legend.**

| Symbol | Meaning |
|---|---|
| ✅ | already in cx (different surface, equivalent capability) |
| 🚧 | partially in cx; expand to full module parity |
| 📋 | planned for v0.7.x / v0.8.0+ |
| ⏭ | deferred — design not yet committed |
| ❌ | out of scope — BaseX-specific, no cx equivalent planned |

---

## Module catalog

### Tier 1 — XQuery 4.0 standard `fn:` namespace + tightly-coupled modules

These ship as part of v0.7.0 (per `xquery_40_parity.md`). XQuery
4.0 standardizes them, so they're language-level, not extensions.

| BaseX module | Cx target | Status |
|---|---|---|
| Standard `fn:` namespace (string, numeric, sequence, node, date/time, higher-order functions) | `cx:` namespace + filter directives | 📋 v0.7.0 |
| Array Module (`array:size`, `array:get`, `array:append`, etc.) | `array:` namespace | 📋 v0.7.0 |
| Map Module (`map:get`, `map:put`, `map:keys`, etc.) | `map:` namespace | 📋 v0.7.0 |
| HOF Module (`hof:fold-left`, `hof:until`, etc.) | merged with `fn:` higher-order helpers | 📋 v0.7.0 |
| Math Module (`math:pi`, `math:exp`, `math:log`, `math:sin`, etc.) | `math:` namespace | 📋 v0.7.0 (standard math fn:s) + v0.7.x (extended) |

### Tier 2 — Operational extensions (v0.8.0 single cut)

These are not XQuery-standard but are essential for real-world
data processing. BaseX defines them; cx wraps or implements
equivalents. **v0.8.0 ships the whole tier as a single tag**,
mirroring v0.7.0's single-cut discipline.

| BaseX module | Cx target | Status | Priority within v0.8.0 |
|---|---|---|---|
| File Module (`file:read`, `file:write`, `file:exists`, `file:list`, `file:create-dir`, etc.) | `file:` namespace | 📋 v0.8.0 | critical — essential for any I/O |
| HTTP Module (`http:send-request`) | `http:` namespace | 📋 v0.8.0 | critical — essential for HTTP-driven workflows including HTMX consumers |
| JSON Module (`json:parse`, `json:serialize`) | `json:` namespace (already partial via cx conversions) | 🚧 v0.8.0 — promote to module form | high |
| CSV Module (`csv:parse`, `csv:serialize`) | already in cx as delimited conversion (per ROADMAP) | ✅ — promote to module-namespaced surface | high |
| HTML Module (HTML input parsing) | `html:` namespace (cx already has HTML output via cxl) | 🚧 v0.8.0 — add input parsing | medium |
| Hash Module (`hash:md5`, `hash:sha1`, `hash:sha256`, `hash:sha512`, `hash:hash`) | `hash:` namespace | 📋 v0.8.0 | high — content-addressing, integrity checks |
| Crypto Module (`crypto:hmac`, `crypto:encrypt`, `crypto:decrypt`, `crypto:generate-signature`, etc.) | `crypto:` namespace | 📋 v0.8.0 | high — cryptographic operations |
| Random Module (`random:double`, `random:integer`, `random:gaussian`, `random:uuid`) | `random:` namespace | 📋 v0.8.0 | medium |
| ZIP Module (`zip:zip-file`, `zip:entries`, `zip:text-entry`, etc.) | `zip:` namespace | 📋 v0.8.0 | medium |
| Archive Module (`archive:create`, `archive:entries`, etc. — tar/zip generic) | `archive:` namespace | 📋 v0.8.0 | medium |
| Bin Module (binary data manipulation) | `bin:` namespace | 📋 v0.8.0 | medium — depends on bin features used downstream |
| Conversion Module (`convert:string-to-base64`, `convert:bytes-to-string`, etc.) | `convert:` namespace | 📋 v0.8.0 | medium |
| Validate Module (`validate:xsd`, `validate:dtd`, `validate:rng`) | `validate:` namespace (cx-native via cxs schemas) | 🚧 — cx has cxs validation; widen to module-form API at v0.8.0 | medium |
| Inspect Module (`inspect:function`, `inspect:type`, etc. — runtime introspection) | `inspect:` namespace | 📋 v0.8.0 | medium |
| Lazy Module (`lazy:cache`) | merged into cx evaluator (lazy iteration via XQuery 4.0 generators) | 📋 v0.8.0 | low (already partially covered by v0.7.0 generators) |
| Stream Module (lazy streaming primitives) | merged with cx streaming API (per `spec/streaming.md`) | 🚧 v0.8.0 | medium |
| Profiling Module (`prof:time`, `prof:mem`, `prof:track`) | `prof:` namespace | 📋 v0.8.0 | low — useful for perf work |
| (cx-native addition — no direct BaseX equivalent) `log:` structured logging | `log:` namespace | ✅ **v0.7.0** per ADR 0023 §D10 / Amendment #1 | pulled forward from this catalog — operationally load-bearing |
| Fetch Module (HTTP GET shortcut with content-type negotiation) | merged with `http:` module | 📋 v0.8.0 | low — redundant with full HTTP module |
| XSLT Module (apply XSLT transforms) | `xslt:` namespace via libxslt or pure cx | ⏭ v0.8.0+ | low — niche; cxl evaluation often replaces XSLT use cases |
| Output Module (output-method declarations: text, xml, json, ...) | already in cx via `[?cx output-target=...]` | ✅ — already covered | low |

### Tier 3 — Concurrency / processing primitives (post-v0.8.0)

XQuery extensions for parallelism and long-running work — the
specific area the user called out ("highly parallel data processing
systems"). Cx needs equivalents to claim industrial-grade capability.
**Separated from Tier 2 because concurrency needs its own ADR** —
evaluator-state isolation, result collection under parallelism,
error propagation, and byte-identity preservation are substantive
design questions distinct from the Tier 2 wrapping work.

| BaseX module | Cx target | Status | Priority |
|---|---|---|---|
| Jobs Module (`jobs:eval`, `jobs:wait`, `jobs:list`, `jobs:stop`) | `jobs:` namespace — async / background evaluation | ⏭ v0.9.0+ (separate ADR) | high — load-bearing for the "parallel data processing" pitch |
| Process Module (`proc:execute`, `proc:fork`) | `proc:` namespace — spawn subprocesses | ⏭ v0.9.0+ | medium |
| Client Module (BaseX-protocol client) | n/a — BaseX-specific | ❌ | — |

Implementing parallel evaluation in cx is a substantial design
project. Touches:
- Evaluator-state isolation (each parallel evaluation needs its
  own env)
- Result collection / streaming
- Error propagation across parallel branches
- Determinism (the byte-identical-output guarantee requires
  careful ordering of parallel results)

Likely its own ADR + multi-week implementation arc.

### Tier 4 — BaseX-storage-specific (mostly out of scope)

These modules are tightly coupled to BaseX's storage engine.
Cx without a database equivalent has no equivalent.

| BaseX module | Cx position | Status |
|---|---|---|
| Database Module (`db:open`, `db:create`, `db:add`, etc.) | requires cx-native DB layer | ⏭ v1.0+ (open question) |
| Index Module (`index:facets`, `index:texts`, etc.) | requires cx-native DB layer | ⏭ v1.0+ |
| Update Module (XQuery Update extension — node updates) | cx-native via CX diff/patch | 🚧 — cx has `cx diff`; widen to query-level update primitives | medium |
| User Module (BaseX user management) | n/a — BaseX-specific | ❌ |
| Repository Module (BaseX module repository) | n/a — BaseX-specific | ❌ |
| Full-Text Module (BaseX-specific full-text index) | requires cx-native indexing | ⏭ v1.0+ |
| SQL Module (BaseX→SQL bridge) | possible cx-native equivalent; design TBD | ⏭ |
| Web Module (BaseX RESTXQ — HTTP endpoints from XQuery) | possibly relevant for cx as HTTP server framework | ⏭ v0.8.0+ design |
| Admin Module (BaseX admin commands) | n/a — BaseX-specific | ❌ |

The "Database Module" line is where the user's open question lives
("we may or may not add cx database ability comparable to basex.org
at some point"). If cx grows a database layer, the DB Module's
analog falls out naturally; if not, that whole tier is out of scope.

---

## Sequencing recommendation

**v0.8.0 ships Tier 2 as a single cut** (per user direction
2026-05-17), mirroring v0.7.0's single-cut discipline for XQuery
4.0 expression parity.

**v0.7.0 (in flight)** — XQuery 4.0 expression parity + standard
`fn:` namespace + Array/Map/Math modules (Tier 1). Per
[`xquery_40_parity.md`](xquery_40_parity.md).

**v0.8.0 — Tier 2 single-cut release** (priority order within v0.8.0
implementation; all ship at the v0.8.0 tag):

1. `file:` — essential for any I/O
2. `http:` — essential for HTTP-driven workflows (including the
   HTMX consumer story per ADR 0022 §D3)
3. `json:` — promote existing conversion to module form
4. `hash:` — content addressing, integrity checks
5. `convert:` — base64, hex, byte/string conversions
6. `random:` — UUIDs, random numbers
7. `validate:` — wrap cxs validation in module-namespaced API
8. `crypto:` — encrypt/decrypt/sign/verify
9. `archive:` / `zip:` / `bin:` — file format and binary-data
   handling
10. `inspect:` — runtime introspection
11. `prof:` — profiling helpers
12. `html:` — input parsing (cx already emits HTML)
13. `xslt:` — possibly deferred to v0.9.0+ if no concrete consumer

**v0.9.0+ (separate ADR — concurrency):**
14. `jobs:` module — parallel/background evaluation. Substantive
    design — evaluator-state isolation, result collection,
    determinism under parallelism.
15. `proc:` module — subprocess spawning
16. Potentially a `web:` module if cx grows HTTP-server framework
    ambitions

**v1.0+ (open question per user):**
17. Database / Index / Full-text modules — only if cx grows a
    storage layer

## What this document is NOT

- **A v0.7.0 deliverable list.** v0.7.0 ships XQuery 4.0 expression
  parity (per `xquery_40_parity.md`) + standard `fn:` functions +
  Array/Map/Math (Tier 1). Tier 2 is v0.8.0 single-cut; Tier 3 is
  v0.9.0+ separate ADR; Tier 4 is v1.0+ open question.
- **A commitment to wrap every BaseX module.** Modules deemed
  out-of-scope (User, Repository, Admin, Client) stay out.
- **A spec.** Each prioritized module gets its own spec section
  (e.g., `spec/modules/file.md`) when work begins on it.
- **An ADR.** Major design decisions (concurrency model, DB
  ambition, web framework) need their own ADRs.

## What this document IS

A planning artifact that says: cx's long-term ambition is a
function-module ecosystem peer to BaseX's, and here's a coherent
ordering for getting there post-v0.7.0. The ordering can be
revised; the ambition (per ADR 0022 §D2 Amendment #3) is set.

## References

- [ADR 0022 — cx is one language; v0.7.0 scope](decisions/0022-cx-is-one-language-v0_7_0-scope.md)
  — particularly Amendment #3 setting the language-nature change
  and BaseX-class library trajectory
- [`spec/xquery_40_parity.md`](xquery_40_parity.md) — v0.7.0
  per-feature deliverable checklist
- [BaseX function module documentation](https://docs.basex.org/main/Functions)
  — reference source for the module catalog
- [BaseX project](https://basex.org/) — the operational system
  cxl-on-cx aspires to match in capability
