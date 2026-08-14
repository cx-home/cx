# I5 stream 18 — agent-tool projection (implementation ledger)

**Branch** `impl/I5-stream18-agent-tool` off `design/651-516-partition`
(opened 2026-08-13 @ d375d342, the #805 gate-truth exit merge).
**Governing spec** `agent_tool_projection.md` (letters 138–145 ruled
(a) 2026-08-05: the 2025-06-18 MCP target; Tier-1 approval binding +
the commands_effects §5 amendment; out-of-band approvals w/
elicitation a non-goal; one descriptor model / two lossy adapters /
pure projection / derived-not-materialized; the field-mapping table +
the lossy-downward rule; [param-doc] + required summaries + the
extended doc gate; G15 spec-all-five + riders; the M5 corpus
program). **Issues:** #690 (the stream), #715 (the hygiene batch:
four stale-#45 doc sites, five dangling provenance refs, doc gate
skips x/, tools-list-result zero callers, a2a skills hardcoded empty,
x/term undispositioned). **Sequencing context:** owner ruled (a)
2026-08-13 — campaign completion first (s18 → s14), #804 follows as
its own arc.

## Shipped-state map (evidence sweep 2026-08-13, at d375d342)

The x tier = 8 modules, 808 lines total (mcp 112, mcp-server 111,
a2a 107, a2a-xap 126, llm 82, adjudicate 125, run 83, term 62).
Both MCP modules pin `protocolVersion: "2024-11-05"` (mcp.cx:33,
mcp-server.cx:51) — predating annotations/outputSchema/
structuredContent/_meta. a2a.cx:46 hardcodes `skills: ()`.
`tools-list-result` exists with zero callers (the advertisement half
of MCP unexercised). The projection's inputs all ship: the Runnable
convention (local fn ≡ MCP tool ≡ A2A skill ≡ pipeline step) is
spec'd + proven; `cx schema export --to=json-schema` (stream 16) is
the inputSchema/outputSchema engine (cli/schema_verbs.v); the
propose/approve/commit machinery + [requires-at] pins (streams 6/10)
carry cmd_meta{src_addr (Tier-1), requires_at_*} — command_pin_of /
command_pin_src_addr (eval.v) are the admission seam; [fn-doc] is
the description source ([summary] child; [param-doc] is NEW,
additive). The L139 divergence is LIVE in text: commands_effects.md
§5 still binds approvals to the Tier-2 `code:` address (the
amendment is this stream's ruled spec edit). The x tier has no ring/
pack placement in cx_partition.md and no gates.cxd rows; the
doc-freshness gate covers `stdlib/*.cx` only.

## Wave plan

- **W1 — the projection core (Ring 0/1 pure):** the one tool-
  descriptor model derived from command defs — parse the module tree,
  select defs with `[effects]` (THE discriminator), emit
  {name, description ← [fn-doc][summary] (REQUIRED — fail-loud,
  L143), inputSchema ← params via the stream-16 json-schema export
  (required = non-defaulted positionals), outputSchema ← [returns T]
  through the E2 pin, readOnly/idempotent/destructive/openWorld hints
  per the L142 table, _meta {source: Tier-1, code: Tier-2,
  schema-id pins, requires: cap: refs}}. [param-doc] additive child
  in [fn-doc] → JSON Schema per-property descriptions. Derived at
  list time — no materialized manifest. Fixture-first: the
  refund-order golden descriptor + the description-required negative
  + [param-doc] presence.
- **W2 — approval binding (L139):** commands_effects.md §5 AMENDED
  (Tier-1 binds trust; Tier-2 rides for cache/equivalence — RULED:
  L139 token on the spec+impl commit); the shipped approve/commit
  path re-keyed to the Tier-1 src address; fixtures: the
  approval-binds-Tier-1 PAIR (same Tier-2, widened [effects], old
  approval REFUSED) + tampered-args different-address negative.
- **W3 — MCP at 2025-06-18 (L138):** both pins updated, one target,
  no revision-conditional emission; mcp-server gains tools/list
  (derived from the loaded module tree; tools-list-result's FIRST
  callers) + the tools/call propose-only boundary (never executes;
  returns the proposal + its Tier-1 address); golden tools/list for
  refund-order; `cx tools export` offline lane gated by goldens.
- **W4 — A2A (thin, L141/L144):** skills derived from the SAME
  projection (the hardcoded `skills: ()` dies — #715);
  `input-required` as the durable pending-approval realization;
  a2a-xap = the DID/VC approval substrate wiring (the same delegation
  values the PEP consumes).
- **W5 — G15 spec-all-five + the x-tier placement (L144):** five
  x/*.md specs authored (mcp rewrite at 2025-06-18; mcp-server
  +tools/list+registry+propose shape; a2a thin — empty skills NOT
  ratified; a2a-xap; llm minimal); x-tier ring placement into
  cx_partition.md §4 (run/mcp/a2a/llm = Ring 1 packs;
  mcp-server/a2a-xap = Ring 2); gates.cxd rows for the x-tier
  suites; the doc-freshness gate extends to x/*.cx + command-bearing
  modules; the #715 rider sweep (stale-#45 sites ×4, dangling
  provenance refs ×5, x/term disposition → tracker issue).
- **W6 — hygiene + exit:** corpus handoff rows appended to the
  stream-14 register (§8's program); closure evidence (#690 + #715);
  exit audit; exit gate → merge.

Named landings (ruled): the full M5 witness families = stream 14
(§8); #804 = its own post-campaign arc (owner (a), 2026-08-13).

## Wave record

- **W1 OPENED — seams mapped + the first design finding (2026-08-13).**
  Proven seams: the extraction idiom (gen_stdlib_docs/probe.cx —
  [$cx:parse] + //fn-doc + [?match] children); [fn-doc] shape
  (stdlib/path.cx — [sig]/[summary]/[example]; [param-doc] is the
  additive newcomer); the command shape (`[?def NAME impure [effects
  [CAPS]] [returns T] (params) BODY` — cmd-001.. fixtures); the
  schema engine (cx.schema_export_json_schema, stream 16); the
  jsonschema stdlib module (the CONSUMING side; the projection BUILDS
  scalar param schemas directly); x-tier resolvers `cx-x/<name>`
  (stdlib_bundle.v — a new x/tools.cx needs the embed const + two
  registry rows). **DESIGN FINDING (probe-verified):** descendant
  CXPath reaches INSIDE [?def] ($t//effects, $t//returns count
  correctly — #436 transparency) but the CHILD axis SKIPS directive
  nodes ($t/* over a module wrapper yields only the plain [fn-doc]
  siblings, never the [?def]s) — so defs cannot be enumerated or
  per-def scoped by plain paths. W1's first decision: surface
  directive nodes for enumeration (the [?meta] reflection boundary
  (L88) vs a directive-kind child-axis surfacing vs pairing via
  fn-doc name= + per-def descendant scoping once selected). The
  projection module = x/tools.cx (CX code — the dogfood rule; the
  probe.cx idiom is the precedent), consumed by mcp-server (W3) and
  a2a (W4).
- **W1 probe program COMPLETE — enumeration solved on shipped surface;
  a structured-input gap found and pinned (2026-08-14, binary @
  b78a3b4c).** Probes at the scratchpad (enum_probe3..11), facts:
  (1) **Enumeration SOLVED**: `$t//effects/..` as ONE path yields the
  [?def] directive nodes themselves — the [effects] discriminator IS
  the enumerator (descendant walks THROUGH directives pushing them on
  the ancestors chain, eval.v collect_descendant_focus; the G2 parent
  axis pops the RAW EvalDirectiveNode). Per-def scoping from the
  recovered focus works ($d//idempotent, $d//returns, $d//effects
  count correctly per def); pure defs (no [effects]) are correctly
  absent; the parent step MUST ride the same path expression — a
  detached `$e/..` loses ancestry (doc-scan fallback, empty).
  (2) **Tier-1 address available**: [$cx:hash $d] on the recovered
  focus returns the def's sha2-256 — W2's approval-binding input works
  from the data lane. [$cx:serialize $d] round-trips faithfully.
  (3) **The structured-input GAP (stop-point (i))**: the def HEAD
  (name, scope=, purity) and PARAMS arrive at the data layer as raw
  TEXT runs — invisible to /* (elements only), [$text]/[$string]
  (empty), $d@scope (()); visible only inside [$cx:serialize] output.
  A structured default SPLITS the run (`' ($a::map' {} ') '` — mixed
  text-fragment + MapNode lanes), so CX-side string extraction =
  re-implementing the lexer (rejected: no-text-hacks rule). [$name $d]
  errors on a directive focus (ruled: a directive is not an element,
  eval.v:446). [?match] `[case [?def $x]]` does not match. No shipped
  reflection fills it: the cx: registry (serialize/canonical/hash/env/
  builtins/computation-id/plan-address/equal/type-binding*/diff/patch/
  merge/to-format/from-format/select/propose + parse/eval) has no AST
  or module-def surface. Kind tests (`node()`) do not parse in binding
  paths (two-args misparse in expr position; hard parse error in
  [in …]) — grammar [131b] remnant vs the paren-call retirement.
  (4) **The near-miss**: the program-AST-as-JSON projection ALREADY
  ships spec'd (ast.md; DefNode carries name + structured params) and
  is EXTERNALLY exposed via the C ABI (cabi.v program_ast_json) — but
  is not callable from CX. External ABI consumers can read the program
  AST; CX code cannot. STOPPED at stop-point (i): filling the gap
  needs new spec surface outside the §9 ruled edit map — lettered
  question set posed to owner (recommendation: expose the existing
  ast.md JSON-AST projection as a pure [$cx:ast] builtin; enumeration
  then rides the AST and the //effects/.. lane remains the
  fixture-pinned data-layer witness).
