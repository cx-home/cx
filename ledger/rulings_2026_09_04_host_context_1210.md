# Rulings 2026-09-04 — #1210 the host hands a feature its context: tenant, store AND journal (HC)

**Status: HC-1 RULED (a) 2026-09-04 under the owner's standing
letter-acceptance rule and the 2026-09-04 directive (run the campaign
through; best long-term decision) — re-verified against the bar: one
context value, extensible without signature churn, names the tenant,
re-opens nothing, mirrors the deployment document's own `[runtime …]`
shape. Proposed first (847115750), ruled in the following commit.**
Recorded BEFORE any spec text. WF-9 (owner, "all a") already chose the
DIRECTION: "#1210 option 1 — a journal handle beside the store — for W3+".
This record decides the SHAPE. Ruling ids `1210-HC-1`.

**Inputs read.** #1210 (the filing); `xap_feature_distribution_market.md`
§1.2 (`readout ($store $t)` · `readout ($store $t $actor)`, `apply ($verb
$intent $store)`, `simulate ($store $t $params)`), §6.3, §6.3.1 (`[runtime
[journal url= stream= …]]`, RULED CO-9); `stdlib_xap_host_notd_wasm32_emcc.v`
(`XapHost.store` = OPTS.store, the ONLY handle a feature receives; `$t` is a
FLOAT tick, `cx.mk_float(t)` — not the tenant); `stdlib_xap.v`
(`xap_open_journal_bind`: the runtime opens the bound journal ONCE at run,
under the deployment's tenant, and holds `rt.journal_fab` + `journal_stream`);
the five standard-feature modules in `cx-home/cx-standard-features`
(`readout ($st $t $actor)` / `apply ($verb $intent $st)` — every one reads
its read-model through `$store:get-alias`/`get-doc` over `$st`); the four
test modules in `xap_umbrella_test.v`; docs-src 19, `features-authoring.md`;
fixtures `xap-dist-048/049`.

## The finding the ruling rests on

A feature receives a store handle and a clock tick and NOTHING that names
the deployment: not the tenant, not the journal the cascade commits to. The
host knows both (OPTS `tenant`, the `[runtime [journal …]]` binding it
opened) and keeps them to itself. So a feature that owns its fold must open
a journal by an environment variable, re-stating the tenant with nothing
checking agreement (the filing's exact failure), and the W3 flow runner at
the XAP face — which appends run transitions to the tenant's journal — has
no sanctioned handle to append through.

## HC-1 — the shape of "a journal beside the store" — RECOMMENDED: (a)

- **(a) RECOMMENDED — the entry points receive ONE deployment-context
  element, `$host`, in the position the bare store handle held:**
  `readout ($host $t)` · `readout ($host $t $actor)` · `apply ($verb $intent
  $host)` · `simulate ($host $t $params)`, where
  `[host tenant="acme" [store <handle>] [journal <handle> stream="acts"]]`
  — `tenant=` is the deployment's tenant (item 3 of the filing: the tenant
  contract, NAMED in the value a feature holds); `[store …]` is exactly the
  capability-scoped handle passed today (`$host/store`); `[journal …]` is the
  deployment's BOUND journal, the one handle the host opened for
  `[runtime [journal …]]` under the deployment's identity and options, with
  the bound stream named — ABSENT (the `()` channel, never a foreign default)
  when the deployment declares no binding, so a feature that folds reads
  `$host/journal` and either folds the tenant's chain or sees absence as a
  value. The flow runner (W3) appends through the same `$host/journal`. The
  host builds `$host` once at boot and hands the SAME value to every call.
  **What it DELETES:** the bare `$store` argument (cutover-first, no
  dual-accept — arity stays, the ARGUMENT'S KIND changes): the five standard
  features republish as 0.2.0 reading `$host/store`; the four test modules
  and the docs-src 19 / `features-authoring.md` examples and `xap-dist-048/
  049`'s code strings flip; the host's `invoke_closure` call sites pass the
  context. **What it KEEPS:** arity (2/3 readout selection by arity is
  untouched), `$t`, `$actor`, the store handle byte-for-byte as a child,
  `[refused reason=]`, every capability treatment (the handles inside are
  the host's scoped handles, nothing is re-opened). **Strongest counter:**
  ten module edits across two repos for one added handle. **Answer:** the
  alternative shapes cost the same edits and grow worse: a per-resource
  argument list is arity churn at every new deployment resource (the next
  is `sched`), while ONE context element grows by a child with no signature
  change — this is the shape the runtime already uses for its own
  bindings (`[runtime [journal …] [sources …]]`), so the feature sees the
  deployment the way the deployment document states it.
- **(b) a fourth positional `$journal` (and `readout ($store $t $actor
  $journal)`).** Rejected: the tenant stays unnamed (item 3 unmet), the
  readout's arity-selected lens form collides with a fourth argument, and
  every future resource repeats the cutover.
- **(c) features are store-only by design (the filing's option 2); the
  fold is always a boundary worker's.** REFUSED: WF-9 (owner) chose option
  1 for the flow's sake, and a feature that cannot own its fold is not
  portable between deployments — the filing's central point.
- **(d) keep the shape; document the environment variable and add a tenant
  check.** Rejected: the filing already showed the variable is the wrong
  place (tenancy leaves the host's hands; the capability model is bypassed;
  the failure is silent).

## Edit map (ruling-gated; lands as its own change BEFORE #1265 W3, cutover-first)

| Where | Edit |
|---|---|
| `xap/xap_feature_distribution_market.md` §1.2 | the three signature rows take `$host`; a paragraph defines the `[host tenant= [store] [journal stream=]]` value and its absence rule; §6.3 step 4/5 name it |
| `stdlib_xap_host_notd_wasm32_emcc.v` | build the context at boot from OPTS.store, OPTS.tenant, the opened journal binding; pass it at every `invoke_closure` of readout/apply/simulate |
| `vcx/tests/xap_umbrella_test.v` (4 modules), `conformance/stdlib/xap-dist.cxd` 048/049, docs-src 19, `docs/dev/features-authoring.md` | `$store` → `$host`, reads through `$host/store` |
| `cx-home/cx-standard-features` — admin, identity, notify, ops, retention | 0.2.0: `($st …)` → `($host …)`, `load`/`save` helpers read `$host/store`; republish through the same machinery; REGISTER.md gains the line "the host context is the platform's" |
| fixtures | a feature reading `$host@tenant` and folding `$host/journal` (positive); a deployment with no journal binding — `$host/journal` is absence, the feature answers a value (negative); the old bare-store module refused at install/boot naming the contract change |

**Verified 2026-09-04 (probe against the release binary):** a `[host tenant="acme" [store $s] [journal $j stream="acts"]]` element carries the shipped store and journal handles as ordinary children; `[$first $host/store]` puts and gets a document, `[$first $host/journal]` appends (seq 1), `$host@tenant` reads `acme`, and `$host/sched` is absence (count 0). Nothing is re-opened inside the feature.
