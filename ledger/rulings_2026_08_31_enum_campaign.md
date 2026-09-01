# Rulings 2026-08-31 — EN enum campaign (the world-class enum story)

**Status: PROPOSED — EN-1..EN-5 recommendations recorded before code, awaiting
owner letters.** Umbrella/scoreboard **#1153**; members EN-1..EN-5 =
**#1154–#1158** (label `enum campaign`). Owner-accepted campaign 2026-08-31,
sequenced NEXT after #1144 closed and BEFORE #1119. Rulings recorded before
work per the #832 process rule; format mirrors
`ledger/rulings_2026_08_30_functional_ergonomics.md`.

**Origin.** The 2026-08-31 enum analysis (Fable session, probes on the shipped
`cx v0.17.0`) established the thesis on #1153: CX's enum is not a new
mechanism — it is the composition that already mostly ships (atom + tagged
element + schema `[enum]`/`[or]` with widen/narrow evolution + `[?match]`),
and its differentiator is that the closed set is declared in the artifact that
TRAVELS — the same enum enforced in the store, on the wire, in bindings, in
the validator, and in match. Rust's exhaustiveness dies at Rust's border;
protobuf's enum stops at deserialization; CX's can survive every boundary.
Every ruling below completes that composition without minting a second
mechanism: **schema remains the ONE closed-set mechanism**, and the packet
adds zero new sigils and zero new directives (it pays, explicitly, for one
match CLAUSE, one schema CONSTRAINT clause, and one stdlib verb).

**Non-interference.** No codec/format surface is touched; no cell of
`ledger/matrix_2026_08_30_format_surface.md` or
`ledger/matrix_2026_08_25_path_value_model.md` changes. Sequencing against
#1119 is addressed in its own section below, as the umbrella requires.

---

## Audit deltas (2026-08-31, probes on `cx v0.17.0`, repo @ 5d503f265)

The #1153 participation matrix is confirmed with the following deltas — the
first two are load-bearing for EN-1's scope:

- **D1 — the §5.4 schema-type guard is dead in the engine (grammar/spec ahead
  of engine, the FE pattern).** `code.md` §5.2 rule 4 / §5.4 and grammar
  [126b] admit `[:TypeName …]` element patterns testing an element's SCHEMA
  type, with "no schema in scope MUST raise `cx-err:CXER0100` at program load
  time". Measured: `[case [:Job $j] …]` with no schema in scope parses, runs,
  and silently falls through to `[else]` (RC=0) — no load-time refusal, no
  guard semantics. §5.4's spec text also carries a dangling reference
  ("`schema.md` §… type resolution", twice) — the resolution rules it defers
  to were never written.
- **D2 — programs have NO live schema-scope channel.** `[?cx schema=…]` at
  the top of a program module does not load a schema; it flows through the
  program reading **as a value and echoes into the result image**. schema.md
  §13 defines the directive for target documents (data reading) only; nothing
  defines schema-in-scope for the program reading. EN-1's machinery must be
  BUILT, not extended — and D1's truing rides the same machinery.
- **D3 — the atom-map-key refusal is two sites, and the literal site is not
  the named one.** The umbrella recorded "parser refuses `{:name: 1}` by
  name, CXERMAP-BADKEY". Measured: the literal form refuses at the key-token
  level with generic `CXER0100` "expected map key (string/ident/number/bool/
  date/datetime), got ':'" (`vcx/cx/program_parser.v:5685`); the named
  `CXERMAP-BADKEY` fires on the value-level key sites (`vcx/cx/parser.v:5670`
  and friends, `map.md` §put/entry). EN-4's rationale note cites the code
  that actually fires; a W1 rider names the literal site consistently.
- **D4 — S007 diagnostics strip the atom sigil.** An atom-enum violation
  reports `value 'gone' not in :enum [ok,err,pending]` — kind-ambiguous
  (`:gone` vs `"gone"` render identically in the message, though they are
  distinct values and only one is in the enum's kind). W1 rider: S007 (and
  sibling S-code) messages render values in canonical spelling.
- **Confirmed unchanged:** `::atom [enum :ok :err :pending]` validates with
  S007 and RC 0/1 (probe: good/bad docs); multi-arm `[?match]` without
  `[else]` falls through to the empty sequence at RC=0 (the behavior EN-1
  modifies ONLY under `[of]`); computed-key map lookup ships (#1138 closed:
  `[$map:get]` absence-on-miss + `$m.$k` fail-loud step) — EN-2's closed-key
  tables compose with it as-is; no `[keys]`-class constraint exists in the
  schema.md §7 catalog; grammar [157] KindName is a closed kind set with no
  schema-type channel.

---

## EN-1 — exhaustiveness: a `[?match]` over a schema-closed set knows when its arms cover it (#1154)

**Recommended: (a).**

- (a) **A match-time schema handle as a CLAUSE: `[of TypeName]`.** The
  multi-arm form gains one optional clause between scrutinee and arms —
  `[?match $x [of status] [case :ok …] [case :err …]]` — declaring that the
  scrutinee ranges over the named schema type. This is the scrutinee-position
  counterpart of the pattern-position `[:TypeName …]` guard ([126b]/§5.4):
  the SAME schema-scope resolution, defined once (see pin P1), truing D1/D2 in
  the same wave. Grounds: the eliminator is exactly where the closed set is
  consumed, so the declaration belongs on the eliminator; a clause joins the
  existing `[case]`/`[when]`/`[else]`/`[where]`/`[in]` clause family (no new
  sigil, no new directive — the packet pays for one clause keyword, reserved
  only inside the multi-arm match form where children are already
  arm-restricted, so no pattern-position collision exists); and it consumes
  schema rather than declaring anything, keeping schema the one closed-set
  mechanism. The exhaustiveness feedback derives from the RESOLVED schema
  (content-hash identity), so bindings inherit it and widen/narrow evolution
  composes: an enum widened upstream turns a previously exhaustive match into
  a named-gap report at next lint, and an out-of-set value arriving at a
  pinned-older match refuses loudly at the `[of]` boundary — the protobuf
  unknown-value story done right (loud and named at the eliminator, never a
  silent else-hole unless the author wrote `[else]`, which is their opt-out).
- (b) Attribute-modifier spelling `[?match $x of=status …]` — HELD as
  runner-up: same semantics, same resolution; rejected on surface grounds
  only (match structure is clause-shaped throughout; an attribute-modifier on
  `[?match]` would be the form's first, while `[of …]` reads in the family of
  `[in …]`/`[where …]`).
- (c) `::T` extended to schema-type references — REFUSED. Rule 14 draws the
  partition deliberately: double-colon `::T` is the VALUE-KIND channel over
  the closed [157] KindName set; single-colon `:TypeName` is the SCHEMA-TYPE
  channel. Opening KindName to schema names makes every `::` site
  registry-dependent (a pure kind test today, a fail-closed resolution hop
  tomorrow), collides lowercase schema-type names with kind names by
  construction, and blurs the one disambiguation the grammar documents at
  [140g]/[157] as position-dependent. UNIFORM defect by construction.
- (d) Bare scrutinee guard `[?match $x :Status …]` — REFUSED. `:Status` is a
  well-formed AtomLiteral, and in the single-arm form's pattern slot an atom
  is already a scalar-literal pattern ([140b], rule 8) — the spelling is
  ambiguous between "typed scrutinee" and "match against the atom `:Status`".
  A capitalization-based reading would make case semantically load-bearing in
  a value position (atoms admit capitals).
- (e) Lint-layer-only exhaustiveness (no surface, inference only) — REFUSED
  as the mechanism: without a declaration the checker can type almost no
  scrutinee (CX is schema-at-boundary, not flow-typed), so coverage would be
  silent, partial, and unexplainable. Lint remains the default REPORTING
  layer of (a) — the refused thing is inference as the entry channel.

**Semantics pins to record at impl (normative once ruled):**

- **P1 — schema scope for programs (trues D1/D2, fills §5.4's dangling
  reference).** Load-time resolution order for `[of TypeName]` and the §5.4
  `[:TypeName …]` guard alike: (1) the module's `[?cx schema=…]` directive —
  which becomes a real directive under the program reading (loaded at module
  load, never a value; D2's echo is abolished), same path rules as §13 —
  **or its inline twin `[?cx schema-inline …]` (§13.1), likewise admitted in
  the program reading, so a single-file program can declare its closed set
  inline with no external artifact** (this is what keeps R2's refusal of a
  nominal `[?enum]` honest: in-program closed-set declaration must not carry
  file-management friction); then (2) the module's `cx.lock` `[schemas]` pins
  (§13.3, name → hash → content, fail-closed). The RUNTIME registry (`register-schema`) is deliberately
  EXCLUDED from load-time scope — load-time meaning may not depend on
  runtime mutation order. Unresolvable type name, no schema in scope, or an
  ambiguous name across in-scope schemas → `cx-err:CXER0100` at program load,
  naming the candidates. §5.4's "MUST raise" becomes true, and its `§…`
  references are repaired to name this pin.
- **P2 — coverage domain.** Exhaustiveness is computed when the resolved
  type is finitely enumerable: an `[enum V…]` (any scalar kind), `bool`,
  `null`, or an `[or T…]` whose members are each finitely enumerable or
  element-variant `[ref …]`s. An unguarded `[case]` scalar-literal arm covers
  the equal member; an unguarded element pattern / `[:TypeName]` guard covers
  its variant; `[else]`, unguarded `_`, and unguarded bind-only `$x` are
  catch-alls satisfying coverage. Guarded arms (`[where …]`) and `[when …]`
  arms never contribute (a predicate can fail — coverage is structural).
  Non-enumerable types get coverage only via catch-all, and the finding says
  so.
- **P3 — the dual check.** Missing members are reported BY NAME; a `[case]`
  literal NOT in the resolved set is reported as unreachable/alien BY NAME
  (the misspelled-member class — `:not-fuond` is caught at lint, today it
  silently never matches). Default severity: lint finding (`cx lint` ID from
  the lint namespace, assigned at impl, fixture-pinned); under `--strict` the
  same finding is a load-time refusal. Exit behavior follows the existing
  `--fail-on` machinery (cli.md §3.5).
- **P4 — runtime membership, fail-loud.** At each execution, `[of]` validates
  the scrutinee against the resolved type via the ONE validator (S-code
  semantics — S007 for enum violations, S005 for kind mismatch), surfaced as
  a raised `cx-err` (code from the CXER01xx code band, assigned at impl,
  fixture-pinned) whose message carries the S-code and canonical-spelling
  value. This is what makes the static claim sound: no out-of-set value can
  thread the covered arms.
- **P5 — err capture precedes `[of]`.** The §8.2 scrutinee exemption wins: an
  `[err …]` scrutinee bypasses the membership test and dispatches to arms as
  today — `[?match]` stays the unified recovery point (§9.3). `[case [err …]]`
  arms are never REQUIRED for coverage; they are extra.
- **P6 — fall-through under `[of]` refuses.** A multi-arm `[of]` match with
  no `[else]` that no arm claims raises NO_MATCH-class refusal instead of the
  plain form's empty sequence — the declared-closed posture (P4 makes this
  reachable only for enumerable-but-uncovered and non-enumerable cases lint
  already flagged). The plain multi-arm form's empty-sequence fall-through is
  UNCHANGED.
- **P7 — multi-arm only, this revision.** The single-arm form takes no
  `[of]`: its pattern slot stays untouched (where `[of …]` would collide with
  an ordinary element pattern), and validate-then-destructure is one
  composition away. Reopen on corpus evidence of the composition as a
  measured repeated tax. `[of]` with no scrutinee (searched-CASE mode) is a
  parse error — there is nothing to type.
- **P8 — representation firewall (see the #1119 section).** `[of]` is a
  DISCRETE pre-dispatch step calling the validator through the value-model
  contract; the W2/#1139 structural fast path lowers arms, never the `[of]`
  step. No interned-set or dispatch-table representation fast path lands in
  this campaign — that optimization is #1119's to design, named there.

## EN-2 — closed-key maps: the schema `[keys …]` constraint, the honest EnumMap (#1155)

**Recommended: (a).**

- (a) **`[keys CLAUSE…]` — a constraint WRAPPER that applies §7 clauses to
  the KEY domain of a map-shaped declaration.** Example:
  `[type optable::[map string int] [keys [enum plus minus times] [req]]]`.
  Every key must satisfy the wrapped clause set — `[enum …]` closes the key
  set (the TS-`Record`/EnumMap expectation), `[pattern …]`/`[len …]`/
  `[range …]` close it by predicate for string/numeric key domains. This is
  the principled answer from #1153: close the KEY SET, do not mint a key
  kind — closed-key tables arrive over the EXISTING seven key kinds
  (cxdm §2.6), with S-code violations and §16.5 evolution, and zero new
  mechanism beyond one clause keyword (paid for here). Grounds: it reuses the
  entire constraint catalog instead of an enum-only bolt-on (orthogonality),
  and it lands where closure already lives — the schema that travels.
- (b) Atom map keys / a keyed-enum map kind — REFUSED; cxdm §2.6 stands
  (grounds recorded in writing by EN-4's rationale note; register entry R3).
- (c) `[keys]` over string keys only — REFUSED: the key domain has seven
  legal kinds and the constraint catalog already partitions by kind
  applicability; a strings-only `[keys]` is an unjustified ❌ row (UNIFORM).
- (d) No schema change, lint-layer key checking — REFUSED: lint does not
  travel with the data; schema is the one closed-set mechanism.

**Semantics pins:**

- **P9 — placement and kind rules.** `[keys …]` attaches only to
  declarations whose shape is `[map K V]` (body/`[type]` positions — S024
  already bars container shapes from attributes); on any other shape it is a
  schema-load error. Wrapped clauses check under the declared K's kind with
  NO coercion (map-key equality rules, cxdm §2.6: `{1: …}` ≠ `{1.0: …}`);
  `[enum]` payload values must themselves be of kind K (schema-load error
  otherwise). Bareword enum payloads follow the map-literal key sugar:
  bareword = string.
- **P10 — codes.** A key failing a wrapped clause fires that clause's OWN
  S-code (S007 enum, S008 pattern, S006 range, S018 len) with the diagnostic
  locus naming the KEY position and the offending key in canonical spelling —
  zero new codes for the domain tests. Totality (`[req]` inside `[keys]`,
  legal only beside a `[keys]`-level `[enum]`): every enumerated key must be
  present; a missing key fires the reserved **S021** (map key-set totality
  violation — declared member absent), the one new code, naming the member.
  Without `[req]`, `[keys [enum …]]` is subset-closed (keys drawn from the
  set, absence permitted) — the `Partial<Record<…>>` reading.
- **P11 — evolution.** §16.5's change classes gain the `[keys]` rows: key
  `[enum]` superset / `[req]` removed / `[keys]` clause removed = `:widen`
  (derivable); key `[enum]` subset / `[req]` added / any `[keys]` clause
  added or tightened = `:narrow` (REFUSED with the named prompt), exactly the
  value-position table.
- **P12 — validation property, not a match mode.** MapPattern stays open
  (subset) per rule 11; `[$map:get]` miss stays the absence channel. Closure
  is enforced by the validator at boundaries, never by rewriting lookup or
  match semantics.

## EN-3 — member enumeration: the blessed idiom for "give me the declared set" (#1156)

**Recommended: (a).**

- (a) **One stdlib verb in the `validate` module: `enum-values`** —
  `($schema-ref::string $type-name::string) [returns sequence]`, beside
  `register-schema`/`validate-against` (validate.md §3). Returns the declared
  member values of the named type's `[enum …]` in DECLARED ORDER,
  kind-faithful (atoms come back as atoms). Resolution is `validate-against`'s
  own name → hash → content fail-closed walk (CXER1600 on any failing hop);
  a resolved type that carries no `[enum]` refuses with a code from the
  validate block (CXER1600–1605, assigned at impl, fixture-pinned) naming the
  type's actual shape — a category error, never an empty sequence (`[or]`
  types refuse likewise: their members are TYPES, not values, and the
  navigation story covers them). Grounds: the schema-as-data navigation path
  exists but runs through the `name::T` ascription surface, which is real
  friction for the one idiom every enum consumer wants; one verb riding the
  existing resolution meets the bar (exists, written down, round-trips
  declared order) at the cost this packet explicitly pays.
- (b) Documented-navigation-only — REFUSED as the sole answer (the ascription
  surface makes the naive path non-obvious; "the idiom" must have one obvious
  spelling). The schema-is-a-navigable-document capability itself is real and
  is documented in EN-4's one-pager as the general story.
- (c) Reflection on `[?match]` (the eliminator exposing its own coverage) —
  REFUSED: an eliminator is not a reflection API; the set's home is the
  schema.

## EN-4 — the one-page enum story: primer section + cxdm §2.6 rationale (#1157)

**Recommended: (a).**

- (a) As filed, with a wave split. **(i) The cxdm §2.6 rationale note** for
  the atom-key prohibition lands in W1 — it documents the status quo: the
  bareword key sugar is string-first for the data pivot (authored maps get
  enum-key ergonomics through that sugar); the one-colon adjacency hazard
  (`{:name: 1}`); the plain-projection collision (a JSON projection of atom
  keys would collide with string keys); closed dispatch is `[?match]`'s job;
  symbol↔key crossing is explicit `cast`; and EN-2's `[keys]` closure is
  the mechanism that delivers what atom keys were reaching for. It cites the
  refusal codes that actually fire (D3). **(ii) The "Enums in CX" primer
  section** lands in the closing wave, AFTER the features it teaches: atoms
  as symbols (cxdm D4) → `[enum]` closure + S007 → element variants + `[or]`
  → `[?match]` elimination + `[of]` exhaustiveness (EN-1) → the `cast`
  boundary → widen/narrow evolution (§16.5) → closed-key tables (EN-2) →
  `enum-values` (EN-3) → the schema-travels thesis. Fixture-backed per the
  docs discipline ({{EXAMPLE}} pins, never prose-only claims).
- (b) A standalone `enum.md` spec doc — REFUSED: the story is a COMPOSITION
  of existing normative surfaces; a new spec doc would become a second
  normative home for each of them — the two-producers pattern in
  documentation form. The primer teaches; the existing docs stay normative.

## EN-5 — the enum refusals register (#1158)

The FE discipline: anti-features refused BY NAME with grounds and reopen
triggers, so they stop being re-litigated. This section IS the deliverable;
#1158 closes when the packet is accepted and committed.

| # | Refused | Grounds | Reopen trigger |
|---|---|---|---|
| R1 | **Ordinals / int-backed enums** | Identity is the VALUE (semantic_value_model.md); an ordinal is a representation leaking into meaning — inserting a member renumbers the world (canonical identity + wire breakage by construction), and a wire int that means a name is the data-world poison the atom kind exists to end. Atoms deliberately carry no total order (cxdm D4). | None — posture. Ordering needs are explicit: an `int` field or an explicit order list in user space. |
| R2 | **Nominal program-layer `[?enum]` declaration** | A SECOND closed-set mechanism beside schema — the two-producers pattern two campaigns were spent killing — and it stops at the language border, negating the thesis (the set must travel with the data). EN-1's `[of]` gives the program layer the same authoring value by CONSUMING schema, and P1's inline form (`[?cx schema-inline …]` in the program reading) removes the file-management friction that would otherwise make this refusal a tax on single-file programs. | None foreseen; any future need routes through schema. |
| R3 | **Atom map keys** | cxdm §2.6 stands: one-colon adjacency hazard, plain-projection collision, bareword sugar is string-first (grounds written into cxdm by EN-4). Superseded by EN-2's `[keys]` closure — the actual need was a closed key SET, not a key kind. Refusal codes: token-level CXER0100 at the literal, CXERMAP-BADKEY at value-level sites (D3; W1 rider names both consistently). | None. |
| R4 | **`::T` → schema-type channel** (opening [157] KindName to schema names) | EN-1(c): the `::` kind-test / `:` schema-type partition is the load-bearing disambiguation ([140g]/[157]/[126b]); opening it makes every `::` site registry-dependent and collides the namespaces. | None — EN-1(a) is the channel. |
| R5 | **Member-order comparisons** (sortable atoms; `<` over enum members by declared position) | Declared order is DOCUMENT order — EN-3 round-trips it for enumeration — never a comparison order; positional comparison is R1's ordinal wearing a different coat. cxdm §5.5 stands (atoms unordered). | None. |
| R6 | **Implicit atom↔string bridging at enum boundaries** (`[case :ok]` matching `"ok"`, `[enum :ok]` admitting `"ok"`) | `:ok` ≠ `"ok"` is a kind boundary (cxdm §5.1, no coercion); `cast` is the ONE bridge (VC-16 lineage); rule 8 is type-strict by design. Bridging would make D4's diagnostic ambiguity (atom vs string spelling) a semantic hole instead of a message bug. | None. |

---

## Worked syntax (normative shapes once ruled; fixtures pin the exact spellings)

```cx
# ops.cx — a single-file program; the closed set declared inline (P1's
# schema-inline twin), no external artifact
[?cx schema-inline
  [?cx-schema of=job mode=strict]
  [type status::atom [enum :ok :err :pending]]]

[?def classify scope=public ($s::atom)
  [?match $s [of status]
    [case :ok      'done']
    [case :err     'failed']
    [case :pending 'waiting']]]
```

- Exhaustive as written: lint is silent. Remove the `:pending` arm →
  `cx lint`: *[?match] over [of status] misses :pending* (member BY NAME,
  schema named by content-hash). Under `--strict`: load-time refusal.
- Misspell an arm (`[case :not-fuond …]`) → the P3 dual check: *arm
  :not-fuond is not a member of status — unreachable*.
- Runtime out-of-set (`[classify :gone]`, e.g. a widened-upstream value
  against this pinned schema) → raised `cx-err` carrying S007 in canonical
  spelling: *[of status]: value :gone not in [enum :ok :err :pending]*.
- File-based twins: `[?cx schema=./types.cxs]`, or `cx lock --pin-schema
  jobtypes=./types.cxs` with no directive at all.

```cx
# EN-2 — schema side ([keys] is ordinary schema vocabulary, data reading)
[type optable::[map string int]
  [keys [enum plus minus times]]]            # subset-closed: keys ⊆ set

[type flags::[map string bool]
  [keys [enum read write exec] [req]]]       # total: the honest EnumMap

[type headers::[map string string]
  [keys [pattern '^x-'] [len 3 40]]]         # closure by predicate
```

- `{plus: 1, div: 9}` against `optable` → S007 at KEY `'div'` (the wrapped
  clause's own code, key locus). `{read: true}` against `flags` → S021
  naming the absent members `write`, `exec`.

```cx
# EN-3 — member enumeration, declared order
[?lib 'validate']
[enum-values 'jobtypes' 'status']            # → (:ok, :err, :pending)
```

## Ring placement (partition §2 conformance)

The partition charter already places the lint core and schema language +
validation in **Ring 0**; EN conforms rather than negotiates:

| Piece | Ring | Grounds / consequence |
|---|---|---|
| `[of]` parse, AST node, ast-bin tag, canonical render + `cx fmt` round-trip (P13) | **0** | code forms are data; canonical identity of code lives in Ring 0 |
| Exhaustiveness checker — the P2/P3 dual check | **0** (lint core) | a pure function of (parsed AST, resolved schema bytes); NO evaluator import. Consequence: the `data` profile gets exhaustiveness feedback with no evaluator — editors/CI on untrusted input included |
| `[keys]` schema vocabulary + validation, S021, §16.5 compat rows, export/infer projections (P14) | **0** | schema language + validation are Ring-0 by charter (`schema_validate.v` and siblings already live there) |
| P1 module-load schema resolution, registry binding, `--strict` refusal wiring | **1** | the module loader (code.md §12 lane); resolution I/O never enters Ring 0 — the checker takes resolved schema BYTES as input (P17) |
| P4 membership refusal, P5 err-capture ordering, P6 fall-through | **1** | evaluator. The VERDICT comes from the Ring-0 validator; the err VALUE is built in Ring 1 via mk_err — never construct err values in Ring 0 (the #1126 trap, on record) |
| `enum-values` (EN-3) | **1** | stdlib `validate` module over the Ring-0 schema reader |
| tree-sitter / LSP / vscode grammar sync; primer | tooling / docs | W4 |

## Cross-cutting pins (added on the owner's completeness pass, 2026-08-31)

- **P13 — the Tier-1 identity surface moves as one unit.** `[of]` is new
  program syntax: grammar [136] + the OfClause production, the AST node,
  an `ast-bin.md` tag, the canonical renderer, `cx fmt` round-trip
  (program-faithful, CR-9), and code-identity coverage land TOGETHER in W2
  with round-trip fixtures (parse → canonical → reparse → hash-stable).
  `[keys]` needs none of this — a schema is an ordinary data document; its
  vocabulary is elements, not syntax.
- **P14 — schema-tooling projections of `[keys]`.** `cx schema export` (and
  `jsonschema.md`'s mapping) projects `[keys [enum …]]` to JSON Schema
  `propertyNames`/`enum` and `[req]` totality to `required`; clauses with no
  faithful JSON Schema image refuse loudly at export naming the clause
  (never a silent drop). `cx schema infer` NEVER emits `[keys]` (inference
  stays conservative; closure is an authored claim). `compat` per P11.
- **P15 — program schema scope is resolution-only, and may be plural.** A
  program module may carry multiple `[?cx schema=…]` / `[?cx schema-inline]`
  directives; the in-scope set is their union plus lockfile pins, ambiguity
  fail-closed per P1. (The data-document single-directive rule S009 is
  unchanged — it governs the data reading.) Scope feeds TYPE RESOLUTION
  (`[of]`, the §5.4 guard) only: it never auto-validates `$doc`/data roots —
  validation stays an explicit act (`cx validate`, `validate-against`), and
  the `--schema` CLI flag remains a validate-surface flag with no effect on
  program scope.
- **P16 — `[enum]` payload hygiene.** Duplicate members and an empty member
  list in any `[enum …]` (value position or inside `[keys]`) are schema-load
  errors (S-code assigned at impl from the free span). The spec is silent on
  both today; W1 specifies and red-proves them.
- **P17 — lint degrades loudly offline.** The Ring-0 checker receives
  resolved schema bytes from the CLI/loader lane. When lint cannot resolve
  an `[of]` type (no file access, missing pin), the finding degrades to an
  info-level *unresolvable — exhaustiveness not checked* on that match,
  never silence; at RUN time the same condition is P1's hard load refusal.
- **Non-obligations, named:** `[of]` does not change `[?match]`'s §6.5.0
  purity classification (the membership test is a pure function of a
  load-resolved, hash-pinned schema) or its §7.8 planar membership;
  `[keys]` implies no wire/data-bin change (validation only — columnar
  dict-encoding exploitation of closed key sets is a future candidate,
  #1119-adjacent, not this campaign).

---

## Sequencing against #1119 (the umbrella's standing question, answered at ruling time)

Owner ordered EN before the #1119 representation campaign (2026-08-31). The
exposure is EN-1 only — EN-2/EN-3 live in the validator and stdlib behind the
value-model contract, EN-4/EN-5 are docs/process. Within EN-1:

- **Exhaustiveness is load-time and AST-level** — representation-free by
  construction.
- **The runtime membership test (P4) goes through the ONE validator via the
  value-model contract** — the same interface #1119 is bound to preserve
  (its invariants list: canonical identity, value-model contract, ABI,
  byte-identical gate, vgc soundness).
- **P8 is the firewall:** `[of]` is a discrete pre-dispatch step; the #1139
  lowered match path never absorbs it; and the tempting representation-level
  optimization (interned atom-set membership, jump-table dispatch over enum
  members) is explicitly NOT built in this campaign — it is named here as a
  #1119 candidate, to be designed against whatever representation that
  campaign chooses.

Under these pins, a plausible #1119 representation change carries EN-1
forward without rework; the single watch-item is that #1119's per-node cost
measurements should include a `[of]`-bearing match in the corpus so the
membership test's cost is measured, not assumed.

## Campaign plan

Waves (exit = full `make test`, per the standing exit-gate rule; Opus
implements per wave, Fable keeps STOP adjudications and exit verification;
scoreboard on #1153):

- **W1** (schema/validator lane, no evaluator): EN-2 `[keys]` (#1155 — P9–P12,
  fixtures positive/negative per clause kind incl. totality and evolution
  rows) + EN-4(i) cxdm §2.6 rationale note + the D3/D4 diagnostic riders
  (name the literal atom-key site CXERMAP-BADKEY; S-code messages render
  values in canonical spelling).
- **W2** (the machinery wave): EN-1 (#1154) — P1 schema-scope channel
  (program-reading `[?cx schema=…]` + `schema-inline` + lockfile pins, D2's
  value-echo abolished), the `[of]` clause with its FULL identity surface
  (P13: grammar/AST/ast-bin/canonical/fmt/code-identity as one unit), P4
  membership refusal, P2/P3 exhaustiveness in the Ring-0 lint core +
  `--strict` (P17 offline degrade), P6 fall-through, AND the §5.4
  `[:TypeName]` guard truing (D1) — the guard shares P1's machinery and
  leaving it dead beside a live `[of]` would be a partial impl. Red-proven
  fixtures per pin, both polarities. TRAP (from #1144): syntax expectations
  live in six places — fixtures, stdlib fn-docs, docs, V tests, and the
  python + rust binding tests; sweep all six.
- **W3** (stdlib): EN-3 `enum-values` (#1156) — declared-order round-trip
  fixture, resolution-failure and not-an-enum refusal fixtures.
- **W1 addendum** (P14/P16 riders in the same schema/validator lane):
  `[keys]` export/infer projections + `[enum]` payload hygiene.
- **W4** (delivery): EN-4(ii) primer one-pager (#1157 closes) +
  corpus/rosetta/antipatterns refresh to the post-campaign idiom + tooling
  grammar sync (tree-sitter-cx, LSP, vscode — `[of]`/`[keys]` highlighting
  and completions) + umbrella close.

Spec surfaces touched (each edit lands in its wave WITH the RULED token,
under the no-spec-edits-without-authorization rule — this packet is the
authorization once accepted): `code.md` §5.4 + §8.2 (+ a §6.5.0 purity note),
`grammar.ebnf` [136] + the OfClause production, `ast.md` + `ast-bin.md`
(OfClause node + tag, P13), `canonical.md`/`formatting.md` round-trip rows,
`schema.md` §7 catalog + §12 codes (S021 + P16 hygiene) + §14/§16 export-infer
projections + §16.5 rows, `cxdm.md` §2.6 note, `validate.md` §3 + §5,
`jsonschema.md` `[keys]` mapping (P14), `cli.md` §3.5 lint IDs, primer.

Evidence base: probe transcripts in the Audit-deltas section above and on
#1153; divergences verified against `cx v0.17.0` (shipped) at repo
@ 5d503f265.

---

## Owner letters

1. **EN-1 exhaustiveness — recommend (a)** (`[of TypeName]` match clause
   riding one schema-scope resolution, P1–P8): (a) as above; (b) attribute
   spelling `of=` — same semantics, weaker family fit; (c) `::T` schema
   channel — refused, partition-breaking; (d) bare `:Status` scrutinee guard
   — refused, atom-ambiguous; (e) lint-only inference — refused as
   mechanism. Reply `1a` accepts (a) with all pins.
2. **EN-2 closed-key maps — recommend (a)** (`[keys CLAUSE…]` wrapper,
   P9–P12, S021 for totality): (b) atom-key kind — refused; (c) strings-only
   — refused (UNIFORM); (d) lint-layer — refused. Reply `2a`.
3. **EN-3 member enumeration — recommend (a)** (`enum-values` in validate,
   declared order, fail-closed): (b) navigation-only — refused as sole
   answer; (c) match reflection — refused. Reply `3a`.
4. **EN-4 the one-page story — recommend (a)** (§2.6 rationale in W1, primer
   in W4, fixture-backed): (b) standalone enum.md — refused. Reply `4a`.
5. **EN-5 refusals register — recommend (a): adopt R1–R6 as written**
   (#1158 closes on the packet's acceptance); (b) trim to the three seeded
   entries (R1–R3) — keeps the register minimal but leaves R4–R6 to be
   re-litigated later, which is what the register exists to prevent.
   Reply `5a`.
