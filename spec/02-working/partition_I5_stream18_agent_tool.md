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
- **L146 RULED (a) + [$cx:ast] SHIPPED (2026-08-14).** Owner ruled (a).
  Shipped: `[$cx:ast SOURCE]` (stdlib_cx.v cx_mod_ast — the module
  loader's scan_directives front half + the per-node JSON emitters
  assembled into the ast.md Program shape); def_node_to_json RISEN to
  spec (tag `DefNode`, params `kind` discriminator) + the [152d–h]
  command clauses emitted (effects on clause PRESENCE — empty array =
  zero-item clause = still a command; requires/preconditions/
  idempotent+window/compensates/requires_at); lib/const tags collapsed
  (`LibNode` + ast.md field spellings resolver/resolver_kind/as;
  `ConstNode`); LSP completion row. Probe-verified end-to-end on the
  real top-level module shape: structured params w/ types + default
  PRESENCE (`"default":"{}"` on $opts::map {}), effects items, requires
  cap refs, idempotent, returns — everything L142 needs. **Two design
  facts pinned:** (1) the C-ABI program_ast_json is the PLAYGROUND
  shape, NOT the ast.md encoding — the builtin emits the spec'd
  per-node encoding instead (correction to the option-(a) text,
  recorded in §9 L146); (2) string-only argument — a //effects/..
  def focus is REFUSED (CXER0100): canonical serialization QUOTES the
  def-head text run (not program-parseable), so the module-source lane
  is the projection lane and the data lane pairs by def name.
  Fixtures: code.cxd cxast-001..005 (structured projection; the
  effects-presence discriminator pair; empty Program; non-string
  refused; malformed CXER4100). Unit tests: node_units umbrella +4
  clause cases, 3/3 files green. Gate: test-vcx-resilience-matrix
  (code.cxd, no whitelist) GATE-RC=0, 2869 fixtures — log
  690_cxast_gate3.log (runs 1–2 red were the KNOWN engines gotcha:
  the target compiles without CX_ENGINES -d flags → 14 pre-existing
  db.cxd engine-fixture fails; passed with -d cx_db_sqlite -d
  cx_db_redis, mirroring test-vcx-code's own CX_ENGINES). Spec edits
  under the L146 authorization: modules/cx.md §2.2 (row + contract
  prose), ast.md DefNode (additive [152d–h] + purity +
  positional-default; gate-3 consistency repair). NEXT (W1
  continues): [param-doc] in stdlib_colocated_docs.md + x/tools.cx
  (the projection module: cx:ast lane + fn-doc data lane + jsonschema
  param mapping) + the refund-order golden descriptor +
  description-required fail-loud negative + [param-doc] fixtures.
- **W1 COMPLETE — the projection core SHIPPED (2026-08-14 @ afe7afae).**
  x/tools.cx (cx-x/tools registered: embed const + two registry rows in
  stdlib_bundle.v): descriptors-of = THE projection (module source →
  [tool …] descriptor sequence, derived at call time, L141), two lanes
  paired by def name (cx:ast structured defs; cx:parse fn-docs).
  Fail-loud L143 twice over: missing [summary] on ANY command refuses
  the WHOLE projection ([err code=missing-summary] naming every
  offender); malformed source propagates the cx:ast err (an early
  draft SWALLOWED it into () via [?else] — fixed with an [err @code]
  match guard; the discriminator also moved off [$exists] (false on an
  EMPTY array — the zero-item clause vanished) to the {effects: $e}
  map-key-presence pattern). L142 rows all live: carriers per
  stream-16; required = non-defaulted positionals; rest param → out of
  properties + additionalProperties true; hints incl. the empty-set ⊆
  read-only case; meta {Tier-1 source, Tier-2 code (computation-id),
  schema ids, requires}. **Schema-id basis (v1 decision, honest):
  sha2-256 of the schema's JSON EMISSION** (adapter-visible bytes,
  deterministic sorted keys) — NOT cx:hash of the CX map, which is
  #810-blocked: canonical emit of a SINGLETON sequence in map-value
  position drops string quoting and does not re-parse (serialize∘parse
  broken; cx:hash non-total — filed prio:high with repro; the
  emit-quoting owner-gate applies, so no in-line fix). Named-type
  [returns Order] E2 pins ride W3 (the registry seam arrives with
  tools/list; kind returns cover W1 — recorded, not silent).
  Fixtures: conformance/stdlib/tools.cxd 001–008 (golden refund-order
  M5 descriptor; fail-loud negative; pure-def exclusion; zero-item
  command; rest param; malformed-source propagation; requires+
  idempotent carriage; carrier spot-checks) — goldens BINARY-derived;
  suite picked up by the stdlib glob, default=enforced. Gates:
  resilience-matrix GATE-RC=0 @ 690_tools_gate.log;
  stdlib-catalog-gate OK (51, no orphans — x/ spec parity is W5's
  G15 pass, ruled sequencing; x/tools.md joins the FIVE → SIX);
  guide-check shows a PRE-EXISTING masked CXER3202 (err prints, RC=0)
  — out of this diff's scope (script guards stdlib/*.cx only), filed
  #811 (gate-truth class). CX-authoring gotchas pinned for W3/W4:
  missing map keys RAISE on dot-read ([?else $m.k ()] absorbs);
  [$exists] is false on empty arrays (use map-pattern key presence);
  [yield-array] body is an ARRAY-CONSTRUCTOR context (scalars via
  fp:map/filter); def rest-param surface is *$name; [?fallback] needs
  [recover-with …]. W2 NEXT: the commands_effects.md §5 amendment
  (Tier-1 binds trust — the RULED L139 token rides the spec+impl
  commit); approve/commit re-keyed to Tier-1 src_addr; the
  approval-binds-Tier-1 PAIR fixtures + tampered-args negative.
- **W2 COMPLETE — approval binding VERIFIED Tier-1; the args-record
  seam repaired (2026-08-14 @ 3536af54).** Finding first: the shipped
  commit path ALREADY binds Tier-1 (stream 6 implemented after the
  2026-08-05 ruling — stdlib_cx.v:2014 `prop_tier1 != meta.src_addr` →
  version-mismatch; the commit error text carries the L139 token; the
  §5 amendment was pre-applied at design). So W2 = the ruled fixture
  pair + one REAL defect found in the same seam. The PAIR: registered
  test modules ./cmd-v1.cx / ./cmd-v2-widened.cx (same name/params/
  body ⇒ same Tier-2 by cmd-011's clause exclusion; [effects] vs
  [effects [net]] ⇒ different Tier-1 text) — authz-088 positive (the
  exact approved version commits, 42), authz-089 negative (the
  widened-effects version REFUSED CXER4714, "commit runs the EXACT
  approved version (L139)"). The tampered-args negative already
  shipped as authz-079. **THE DEFECT (found by the pair probe): the
  §5 args record could not bind non-defaulted POSITIONAL params** —
  build_param_call_env consults labels for NAMED specs only; every
  prior propose/commit fixture used $name=default (named) params so
  nobody hit it; the W1 projection names positionals as inputSchema
  properties and MCP arguments bind by name, so W3 would have hit it
  at the tool boundary. FIX: build_param_call_env_record (eval.v) —
  the record is NAME-KEYED over the WHOLE param list (positional and
  named alike; defaults evaluated ONCE; unknown keys refuse loud
  CXER0100→CXER4111; rest binds empty — a record has no positional
  overflow); cx_mod_propose + command_commit_execute both ride it
  (the two binding passes must agree — propose-predicts-commit);
  execute lays the record-resolved values out in spec order through
  invoke_closure_l (defaults never re-evaluated). The GENERAL call
  surface is deliberately untouched. Pinned: cmd-023 (typed
  non-defaulted positional binds by name; the [args] record shows the
  defaulted entry), cmd-024 (unknown key refused). §5 gains the
  record-binding sentence (within the ruled edit's scope). Gate:
  resilience-matrix FULL suite GATE-RC=0 @ 690_w2_gate.log (all
  existing propose/commit fixtures unregressed on the new builder).
  Probe gotcha pinned: [?fallback][recover-with] does NOT bind $_ to
  the caught err (an unbound-$_ probe artifact briefly masqueraded as
  the refusal code — derive negatives bare via out-err). W3 NEXT: MCP
  at 2025-06-18 (both pins), tools/list from the projection
  (tools-list-result's first callers), the tools/call propose-only
  boundary, named-type E2 pins via the registry seam, `cx tools
  export` offline lane gated by goldens.
- **W3 COMPLETE — MCP at 2025-06-18; tools/list from the projection;
  the propose-only boundary (2026-08-14 @ cd605fcc).** Both pins →
  2025-06-18 (client + server; goldens mcp-007 + mcp-server-001 —
  the ONLY prior pin sites, verified by repo-wide grep). mcp-server
  gains the MCP adapter: tool-json-of (ONE descriptor → the
  2025-06-18 entry: outputSchema, the four hints, _meta {source,
  code, schema ids, requires, returnsType}) + tools-for (module
  source → tools array at LIST time; tools-list-result's FIRST
  caller; projection failures PROPAGATE — mcp-server-007 THE
  refund-order golden, 008 the fail-loud negative). propose-call /
  propose-result: the tools/call boundary NEVER executes — the reply
  carries the proposal's CANONICAL CX text + Tier-1 address
  (structuredContent.address); mcp-server-009 golden + 010 the
  out-effects-EMPTY discriminator (a real [$time:now] body that
  never traced). `cx tools export` (vcx/cmd/tools_verb.v, verb
  registered in main.v): EVALUATES the same CX adapter via
  code.eval_code — raw module bytes ride base64 in (verbatim def
  text preserved — the Tier-1 basis is never re-serialized);
  refusal = exit 2 with the [err] on stderr; the golden gate
  tools-export-gate (conformance/tools-export/refund_order.{cx,
  tools.json}) wired into TEST_TARGETS + a GATE_REGISTER row.
  **Named-type [returns T] disposition (recorded, not silent):** the
  descriptor carries [meta][returns-type] and the MCP entry
  _meta.returnsType; resolving a NAME to its schema is store-backed +
  fail-closed by the L63 registry re-ruling (CX_SCHEMA_STORE +
  cx.lock pins) — inherently IMPURE, so it can never live in the
  Ring-0/1 pure projection; adapter-side resolution under grants is
  the named landing for W5's x/mcp-server.md spec (the returnsType
  carriage makes the unresolved case visible, never silent). Rider
  progress: the stale-#45 generic-registry claim in mcp-server.cx's
  header REPAIRED (1 of #715's four sites — W5 sweeps the rest).
  Gates: resilience-matrix FULL suite GATE-RC=0 @ 690_w3_gate.log;
  tools-export-gate OK byte-for-byte; mcp live round-trip tests 2/2
  (no version assertions there — verified). W4 NEXT: A2A thin —
  skills derived from the SAME projection (a2a.cx's hardcoded
  `skills: ()` dies), input-required as the durable pending-approval
  realization, a2a-xap DID/VC approval-substrate wiring.
- **W4 COMPLETE — A2A from the SAME projection; input-required = the
  durable pending-approval slot (2026-08-14 @ a6054289).** a2a.cx:
  skill-of (the SECOND lossy adapter — drops the JSON Schemas, keeps
  the true annotation hints as skill tags) + skills-for (source →
  skills; failures propagate); agent-card takes explicit $skills —
  the hardcoded `skills: ()` is DEAD (#715 rider #2 of the batch).
  a2a-xap.cx: task-event gains the additive address= attr;
  propose-task journals input-required CARRYING the proposal's Tier-1
  address (durable + replayable — a2a-xap-008 pins the lifecycle path
  AND address survival through replay); approval-credential issues a
  DID-signed VC whose delegation subject IS the proposal address (one
  delegation language with the PEP; grant-status verifies fail-closed
  — a2a-xap-009). Probe-proven end-to-end under --allow-random before
  fixturing. CX gotchas pinned: () is not a legal param DEFAULT
  (parse error — required params instead); literal paren-sequence
  POSITIONS keep () items (unlike [?for] yields — [$filter]+
  [?to-sequence] to drop them); [$filter] returns a LAZY iterator —
  json:emit refuses it (CXER3103), materialize with [?to-sequence].
  Gates: resilience-matrix FULL suite GATE-RC=0 @ 690_w4_gate.log;
  a2a live round-trip 1/1; goldens binary-derived (the [?str]
  non-scalar-hole refusal caught a guessed golden — sequences don't
  interpolate; element output instead). W5 NEXT: G15 spec-all-SIX
  (mcp rewrite at 2025-06-18; mcp-server +tools/list+propose shape;
  a2a thin — DERIVED skills ratified; a2a-xap; llm minimal; x/tools
  NEW), x-tier ring placement (cx_partition.md §4), gates.cxd rows,
  doc-freshness gate extension to x/, the #715 rider sweep
  (remaining stale-#45 sites ×3, dangling provenance refs ×5,
  x/term disposition issue).
