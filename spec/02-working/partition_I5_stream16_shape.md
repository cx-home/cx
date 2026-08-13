# I5 stream 16 — shape/type inference (implementation ledger)

**Branch** `impl/I5-stream16-shape` off `design/651-516-partition`
(opened 2026-08-13 @ eccb8022, the stream-10 exit merge). **Governing
spec** `shape_inference.md` (letters 62–69 ruled (a) 2026-08-05).
**Issues:** #688 (the stream), #706 (the type-language defect batch —
rides W1/W2). **Downstream dependency:** stream 18's MCP `inputSchema`
needs this stream's `cx schema export --to=json-schema` (§9).

## Shipped-state map (residual sweep 2026-08-13, at eccb8022)

Essentially NOTHING of the ruled surface ships: no `cx schema infer`,
no json-schema export, no `cx schema embed|extract|bundle` family
(spec-only, schema.md:730-732); `--strict` exists only on `cx table`;
`CX_STRICT_TYPES` has test callers only; the glued container spelling
(`arr[T]`/`seq[T]`/`map[K,V]`) is live in schema_validate.v (472, 822,
945) while the spec'd bracket-prefix forms validate nothing;
`[or]`/`[tuple]`/`[record]` fail open; CXER1600 is an unconditional
raise (stdlib_validate.v:755); TypeExpr flattens to a string before
evaluation and `value_matches_type` passes every bracketed/element-name/
temporal type. WHAT EXISTS to build on: the E2 primitives (schema
content-hash over strict-canonical bytes; wire forms 0x10/0x11/0x12 w/
mandatory hash verification); three disconnected inference sites
(columnar column-schema derivation, delimited import narrowing, `::[]`
array materialization); the dense declared surface (1081 [returns]
clauses); cx.lock (the integrity surface for pins); the [schema of=]
header form (stream 1).

## Wave plan

- **W1 — the type-language repair (L65; #706 core):** TypeExpr parses
  the FULL grammar type language ([155]–[158]: any, number, iterator,
  document, node kinds, refinements); structural parse failures are
  LOUD diagnostics, never silent none; the STRUCTURAL form (not the
  flattened string) crosses into evaluation; `value_matches_type`
  completes — bracketed types structurally checked, temporals checked,
  element-name types head-matched (E2 enforcement joins at W5's strict
  dial). Fixture family first.
- **W2 — schema-validator completion (L66):** `[or]`/`[tuple]`/
  `[record]` validate per schema.md §4; the bracket-prefix container
  cutover (`[list T]`/`[map K V]` — the glued `arr[T]` forms RETIRE,
  no dual-accept; zero fixtures pin either, the cutover is free);
  diagnostics carry real source locations; the container/algebraic
  fixture family (positives + negatives — closing the zero-coverage
  hole).
- **W3 — Layer A, `cx schema infer` (L62A/L68):** the join lattice
  (identical→identical; int⊔float→float; decimal joins only decimal;
  else `[or …]` — NEVER widening to string; absence → `[or T null]` +
  `[card]` from observed counts); the determinism contract (same corpus
  → byte-identical canonical `.cxs` → same content-hash); open mode +
  full-corpus sampling default; the CLI verb in the data-profile
  family; the correctness fixture `validate(docs, infer(docs)) = clean`.
- **W4 — SchemaRef ≡ E2 + the registry re-rule (L63):**
  `validate-against` = name→hash→content resolution, fail-closed on
  hash mismatch (the 0x12 rule generalized; CXER1600 becomes a REAL
  resolution error); `register-schema`/`[?schema-register]` redefined
  as hint-bindings over the content-addressable store
  (CX_SCHEMA_STORE); module-level schema pins in cx.lock.
- **W5 — `--strict` made real + surfacing (L64):** the CLI flag on
  eval/run wiring env.state.strict; CX_STRICT_TYPES RETIRED into it;
  under strict, E2-pinned element-name types enforce (head match +
  schema validation); shape diagnostics in `cx lint` (warn default,
  --fail-on escalation); the Layer-B minimum: declared [returns]/::T
  flow across [?pipe] stages with pre-execution diagnostics (modular —
  inference stops at [?def] boundaries; general expression typing
  stays ruled out). LSP hover/inlay = the lint/LSP surface rows of the
  edit map (scoped to what the shipped LSP carries).
- **W6 — schema export (L69, the stream-18 handoff) + the ingest split
  (L67):** `cx schema export --to=json-schema` (.cxs → JSON Schema
  2020-12, a Ring-0 conversion; golden files); the conversion-lane vs
  csv-module auto-typing cross-references stated normatively in both
  specs.
- **W7 — hygiene + exit:** the §12 edit-map sweep (schema.md §4/§13 +
  new §infer; validate.md §3.2/§7; conversions/csv cross-refs; code.md
  §12.7 strict; grammar [152b] note; cx_partition §4 verb detail;
  lockfile.md pins); #706 + #688 closure evidence; exit audit + full
  gate → merge.

Named landings (ruled): the M5 corpus families = stream 14 (§11); XSD
export = #288's later mapping table; the #288 catalog distribution =
sealed packages over the schema store (no new machinery).

## Wave record

- **W1 EXECUTED 2026-08-13 — the type-language repair.** The full
  [155]–[158] kind set (15→32 names); the [iterator T] head (additive
  0x26 discriminator); loud def-time structural failures; the
  structural checker completed and wired (both runtime sequence
  representations handled — the __cx_seq__ marker duality found by the
  fixture); both enforcement sites stay strict-gated (default-mode
  behavior unchanged; every pre-existing fixture byte-stable). ONE
  named residual: 'path' accepts until the PathNode sum-type graft
  lands. Fixtures cmd-025/026; battery 2865; umbrellas green;
  guide-check OK 46. W1 gate next.
- **W2 EXECUTED 2026-08-13 — validator completion + the cutover.**
  [or] member-wise both positions (the attr fail-open retired; the
  text-body-as-string duality handled); [tuple] fixed-arity
  per-position; [ref] fail-closed named-type resolution (S025);
  [record]-in-[type] collects declarations; bracket-prefix
  parse_container_kind (nested recursion, real paths); glued forms
  retired cleanly (both suites green); S024 = container-in-attr
  unsatisfiable (the CXER1603-respecting rule — schema.md's own attr
  examples were unsatisfiable-by-construction). sv-068..074; suite
  77/77; battery 2867; guide-check OK 46. **Notes:** composite types
  spell via the ::[…] annotation on [attr]/[type] (data-mode token
  text); [ref X] works ONLY in annotation position (the reserved
  [ref @id] element rule) — [body [ref X]] children do not parse;
  W7's schema.md sweep states this. W2 gate next.
- **W2 gate record:** gate 1 `s16_w2_gate.log` RC=2 — three real
  finds: (1) the eval-semantics umbrella pinned the RETIRED glued
  family comprehensively (arr[T]/seq[T]/map[K,V] + a legacy :T[]
  body-desugar test — the "zero fixtures pin either" survey missed
  the V-file battery); (2) the corpus-diff baseline moved 772/607/20
  → 779/612/22 (+7 = sv-068..074; +2 diverge = the PRE-EXISTING
  quoted-string-in-collection cxparse rendering class exposed by
  sv-071/sv-073 — filed #790, the #473/#495 sibling lane); (3) the
  auto-updated evidence file. **W2.1** = the cutover of every pinned
  site + the natural `[body [list u16] …]` ELEMENT-CHILD spelling
  (schema_type_child_text renders the child back through the ONE
  annotation path; type-shaped leading child = list/seq/map/or/
  tuple/enum) + the apply path's seq→arr collapse split (seq bodies
  validate as :seq — found by the cutover fixtures) + the deliberate
  baseline bless w/ history note. Gate 3 `s16_w2_gate3.log`
  GATE-RC=0, PRE/POST HEAD = 4674fe6a, dirty=0 (fabric/http = the
  classified #572 cache-free pair, both green on retries; gate 2's
  RC=2 was a bad target name, not a lane). W3 next: `cx schema
  infer`.
- **W3 EXECUTED 2026-08-13 — `cx schema infer` (L62A/L68).** The §8
  join lattice exactly as ruled: identical→identical; int⊔float→float
  (the one collapse — the validator admits int where float declares);
  decimal joins only decimal; anything else → sorted `[or …]`, NEVER
  string; containers join ITEM-WISE (list⊔list joins items, never
  textual or-members). Attr [req]/[opt] from observed presence; child
  `[card "M..N"]` from per-occurrence counts (absence and late
  first-sight floor to 0); bodies [opt] when not always present;
  mixed-content bodies untyped (open mode covers). Determinism: all
  emission name-sorted (root type first), the CLI sorts its file list
  — same corpus → byte-identical .cxs → same schema_content_hash (E2).
  mode=open always; full-corpus default; `--sample=N` records
  `sample="N/TOTAL"` header provenance. ONE shared Ring-0
  implementation (vcx/cli/schema_verbs.v, os+cx only) dispatched by
  BOTH binaries; extraction gate 9631 pairs byte-identical. Validator
  find: probe_member_type carried the SAME seq→arr collapse as W2.1's
  apply-path — `[or …]` members validated seq bodies as :arr; split,
  pinned by the round-trip corpus row. Fixture family: lattice
  vectors, determinism+E2, cardinality, optionality, mixed-roots
  refusal, sampling, validate(docs,infer(docs))=clean over 6 corpus
  shapes, CLI end-to-end. **Gotchas:** plain `2.5` in CX data is
  DECIMAL (exact-by-default) — float spells `2.5e0`; -prod refuses
  unsafe-bracketed pointer-map reads the dev build accepts (or{}
  blocks required).
- **W3 gate record:** gate 1 `s16_w3_gate.log` RC=2 — completions
  drift (the lockstep contract: bash/zsh/fish lacked the new verb) →
  **W3.1** (verb + infer + flags in all three). Gate 2
  `s16_w3_gate2.log` RC=2 — the -prod lane refused schema_infer's
  unsafe pointer-map reads → **W3.2** (or{} blocks, behavior
  unchanged). Gate 3 `s16_w3_gate3.log` GATE-RC=0, PRE/POST HEAD =
  fab1fffe, dirty=0 (fabric/http = the classified #572 cache-free
  pair, green on retries). W4 next: SchemaRef ≡ E2 + the registry
  re-rule.
- **W4 EXECUTED 2026-08-13 — the registry re-rule (L63).** Names are
  hints, hashes are identity: register-schema binds name → E2
  content-hash (returns the hash receipt) + retains canonical text;
  validate-against resolves name → hash → content FAIL-CLOSED at
  every hop (CXER1600 = a real resolution error naming the hop; the
  0x12 rule generalized — CX_SCHEMA_STORE reads self-verify, a
  poisoned store never resolves). Resolution: bindings → cx.lock
  [schemas] pins; content: registry → store (cache-write
  silent-degrade, the module-cache posture). Content-language
  dispatch: [schema …] w/o of= = validate.md inline (custom
  validators; validate_shape_with_env factored); of=/.cxs = schema.md
  data validation, mapped onto the ONE [ok]/[invalid] vocabulary
  (values render via render_canonical first — runtime marker shapes
  ≠ parse shapes). cx.lock [schemas] block: reader + emitter + `cx
  lock --pin-schema NAME=FILE.cxs` (pins carry forward — authored
  state; modules-empty legal when pins exist). Purity: BOTH verbs
  impure by construction (a rebindable registry read must never be
  cacheable — stream-5 identity); the validate.md §3.2 `pure` marker
  amends at W7's sweep. **Design disposition (owner exit review):**
  the [?schema-register] DIRECTIVE spelling retired-before-birth —
  the closed §4.1 registry (grammar [127e], NOT on the ruled edit
  map) is one-form-per-act (the chain-alias precedent); registration
  is a stdlib act; the verb is THE spelling; W7's validate.md §7
  sweep states the discharge. Fixtures validate-041..045 +
  validate-032 re-authored; V tests: lock-pin end-to-end, poisoned
  store, cross-process store readback, --pin-schema round-trip.
  **Gotchas:** a .cxs HEADER is also [schema …] — of= is the language
  discriminator; [?do] does not yield its last value ([?let] in
  fixtures); runtime→parse validation needs render_canonical.
- **W4 gate record:** gate 1 `s16_w4_gate.log` GATE-RC=0 first run,
  PRE/POST HEAD = b88e7fd7, dirty=0 (fabric/http = the classified
  #572 cache-free pair, green on retries). W5 next: --strict real +
  CX_STRICT_TYPES retired + lint surfacing + the Layer-B minimum.
- **W5 EXECUTED 2026-08-13 — --strict real (L64 + L62B).** The flag
  on run + eval (help included); new_env seeds ProgramState.strict;
  CX_STRICT_TYPES RETIRED (pinned negative) + the declaration-
  PRESENCE validator retired (presence was never the contract).
  E2-pinned element-name types enforce by SCHEMA VALIDATION under
  strict (value_matches_type_env at both 0206/0207 sites; of= root
  subsumes head match; unpinned = W1 head-match; pinned-but-
  unavailable content fails CLOSED). Layer-B minimum:
  pipe_precheck_stage_flow PRE-EXECUTION under strict (adjacent
  declared no-hole [?def] boundaries; conservative composition:
  equal/any/int→float-number; undeclared silent — declarations are
  the contract). Adoption dial: lint CX-L008 (warn default,
  --fail-on/--disable honored). LSP: inlayHint real (declared «T»
  flow before pipe stages); the CXPath hover 'any' re-stated as the
  correct modular answer. **Registry carrier fix:** canonical text =
  HASH basis only, never content — canonical emission mangles
  ::T-annotated barewords ([attr sku::string] → [attr 'sku::string '],
  semantics erased); registry/store now store VERBATIM text, verify
  formatting-invariantly; #791 filed (the canonical-lane defect).
  Fixtures cmd-027/028; V tests: --strict end-to-end + retirement
  negative, L008 x4. **Gotchas:** a multi-statement program parses as
  ONE block ProgramLiteral (walkers must descend items); [?def]
  program directives carry their source in the raw-source slot.
- **W5 gate record:** `s16_w5_gate.log` GATE-RC=0 first run, PRE/POST
  HEAD = b2a3e985, dirty=0 (fabric/http = the classified #572 pair,
  green on retries). W6 next: schema export (json-schema, the
  stream-18 handoff) + the L67 ingest-split cross-refs.
