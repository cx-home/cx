# Corpus audit — ring tagging, completeness, inherited deferrals (stream 14)

**Status:** working draft (stream 14 of the #651/#516 campaign, issue #686).
This stream runs continuously: its ring-tagging output is the input to the
partition's per-ring gate lanes and the Ring-0 extraction gate (partition
spec §7), and its inherited-deferral review must complete before
implementation begins. Normative language binds once approved. Evidence
basis: full corpus census 2026-08-05 (4127 cases), verified spot-checks on
every load-bearing claim.

Worked example: per the campaign ruling, all NEW fixtures mandated by this
audit use the M5 commerce/order-fulfillment domain (orders, line items,
inventory, shipments) as their document corpus, so gap-closure fixtures
double as M5 substrate.

## §1. Corpus census and the ring discriminator

The corpus lives at `conformance/`: 27 top-level suites (1634 cases),
53 stdlib suites under `conformance/stdlib/` (2522 cases), the fixture
schema `conformance/fixtures.cxs`, the gate-policy manifest
`conformance/gates.cxd` (zero cases — policy, not fixtures), and module
scaffolding under `conformance/fixtures/module/`. (Census figures
re-verified 2026-08-05 by three independent methods — text scan,
parsed-element count via `scripts/ring_query.cx`, per-file sum — after
the adversarial audit flagged drift in the suite counts; 4127 total
cases stood at the audit date; the G1/G4 gap-closure families landed
at I0 — `identity_hash.cxd` + `ast_bin.cxd` — and the pre-I1 pin batch
(`operator_heads.cxd` 7, the idh-026 hole/string pair, the cx-094
quote-hash E210 pin, the store-code-003…008 Tier-2 pairs, the
ch-008…011 data-bin goldens) brings the append-only total to 4167:
doc-lane R0=1532 / R1=1991 / R2=644.)

Ring tags are assigned by two independent, mechanical signals that agree:

1. **Runner import set.** `vcx/tests/runners/conformance/conformance_run.v`
   imports only `os`, `cx`, `runtime` — it provably cannot evaluate. Every
   family driven by it (and by `diff_lint_conform.v`) is Ring 0 by
   construction.
2. **Fixture vocabulary.** `in-cx` = document under test (3944 uses);
   `in-code` = program to evaluate (3511 uses — all in `code.cxd` and
   `conformance/stdlib/`).

## §2. Ring tagging (normative once approved)

### Ring 0 — 23 families, 526 cases + `binding_api.cxd`'s 17 Ring-0 cases (the extraction-gate corpus, 543 total; the `code.cxd` parse lane rides on top — see MIXED)

| Family | Exercises | Cases |
|---|---|---|
| `atoms.cxd` | atom kind, surface, canonical render, conversions | 27 |
| `core.cxd` | node kinds, AST JSON, XML emit, round-trip, canonical | 48 |
| `extended.cxd` | scalar/type-annotation/alias/anchor/merge/multi-doc | 68 |
| `xml.cxd` / `md.cxd` / `yaml.cxd` | format import + emit | 30/27/24 |
| `conversions.cxd` | cross-format matrix incl. lossless variants | 18 |
| `delimited.cxd` | CSV/TSV/PSV | 14 |
| `namespaces.cxd` | binding, XML round-trip, canonical | 16 |
| `identity.cxd` | ID/IDREF, `[#id]` predicate | 36 |
| `table.cxd` | table literal parse/emit/AST | 35 |
| `include.cxd` | `[?cx include]` (parse-time) | 3 |
| `schema_validate.cxd` | schema language + validation | 61 |
| `data_bin_chunked/_compression/_schema_driven.cxd` | data-bin codec (chunked +4 G5 freeze-pins, pre-I1) | 11/5/9 |
| `diff.cxd` | structural diff (two-operand `in-a`/`in-b` form) | 17 |
| `lint.cxd` | CX-L001/003/004/005 | 17 |
| `data_bin_arrow.cxd` | CXCol↔Arrow round-trip — see Q6 (runner imports `arrow`) | 14 |
| `identity_hash.cxd` | Tier-1 content hash: blessed digests + pair equality (G1 closure, landed I0; +idh-026 pre-I1) | 16 |
| `ast_bin.cxd` | binary-AST codec: golden bytes + round-trip (G4 closure, landed I0) | 6 |
| `operator_heads.cxd` | the seven operator heads, pre-I1 pins (manifest row 8: five stringify, two reject — all flip at the epoch) | 7 |
| `streaming_write.cxd` | streaming-write events, W001–W013 — see G12 (no V lane) | 17 |

### MIXED — split by lane, not by case

- **`code.cxd` (989 cases)** — every case carries both `in-cx` and
  `in-code`, and two gates consume it: `code_parse_fixtures_test.v`
  (parser only) and `code_eval_fixtures_test.v` (parse → eval, no
  whitelist). Per partition spec §2 the full grammar including program
  forms is Ring 0, so **the parse lane over all 989 cases is Ring-0 work;
  the eval lane is Ring 1** (Q1). Known pre-extraction seam violation,
  recorded not fixed here: the program parser lives in `vcx/code`
  (Ring-1 module) while the partition assigns it Ring 0 — this is the
  cxparse-unification dependency of migration phase 2. The parse lane's
  `expected_parse_failures` allowlist (11 grounded negatives) is inherited
  verbatim by the Ring-0 lane.
- **`binding_api.cxd` (49 cases)** — Layer-1 Document API parity.
  parse/emit/canonical/hash/diff/validate calls are Ring 0; CXPath
  select/modify calls are Ring 1. Split per-case on the `call` line.
  **Landed (I0):** 32 evaluation-dependent cases (eval / select /
  select-all / modify chains, incl. the `spawn`-wrapped select) carry
  `ring=1`; the remaining 17 (parse/bytes/hash/equals/find-all/
  accessor) inherit the suite's `ring=0`.

### Ring 1 — 1991 doc-lane cases (+ the 989-case `code.cxd` eval lane)

`xpath_31_parity.cxd` (23), `code_diagram.cxd` (51), `binding_api.cxd`'s
32 evaluation-dependent cases, and the pure/local stdlib families: bytes,
crypto, csv, cx, format, fp, ft, geo, hash, html, i18n, json, jsonrpc,
jsonschema, locale, log, math, mime, path, prof, random, re, sched,
similar, strings, test, time, url, uuid, validate, **plus the x-tier
Ring-1 packs run, mcp, a2a, llm (21 cases; RETAGGED 2026-08-05, audit
M2: the agent-tool-projection stream's x-tier ring placement — Ring-1
packs, mcp-server/a2a-xap staying Ring 2 — post-dates this audit's
original Ring-2 placement and applied the partition's §10 membership
test; its ruling wins and the four suite headers now carry `ring=1`)**. Q4/Q5 resolved and
landed: env, process, and io are Ring 1 (io's three watch cases
io-105/106/107 carry `ring=2` per the partition's watch→Ring-2
placement, cx_partition.md §2); the http CLIENT surface — 47 cases:
response/request accessors, client construction, one-shot verbs,
scheme/arg validation, `send`, and the SSE client (`sse-source` /
`sse-connect` / `sse-events`) — carries `ring=1`.

### Ring 2 — 644 doc-lane cases

a2a-xap, adjudicate, authz, bus, db, email, fabric, http (serve/
tooling surface: serve/listen/accept/exchange/respond/stop + the SSE
server side, the suite default), journal, mcp-server, net,
session, store, xap-compose, xap-dist, xsp-auth, plus io's three
watch cases. (a2a, llm, mcp, run moved to Ring 1 per audit M2 — see
above.)

### Tagging mechanics (Q2)

`ring=` becomes a fixture attribute on `[suite]`/`[module]`/`[case]`
(resolution order per-case → per-module → per-suite, the `gates.cxd`
precedent), admitted without schema break (`fixtures.cxs` is
`schema-mode open`). The Ring-N lane is then a corpus query, never a
maintained external list — the corpus is append-only (partition §8), so an
external list would drift by construction. MIXED families tag at case/lane
granularity: `binding_api.cxd` tags per-case; `code.cxd` tags `ring=0`
with `eval-ring=1` on the suite header — the machine-readable lane
discriminator, since the eval lane is defined by the CONSUMER (the two
gates), not by any per-case property. **The corpus query is
`scripts/ring_query.cx`** (env-var interface `RING`/`LANE`/`FORMAT`; run
from the repo root): it implements the resolution order and the
`eval-ring` lane semantics, and doubles as the tagging-completeness gate
— any suite header without `ring=` is a hard failure (exit 2).

## §3. Coverage map — normative specs × corpus

Covered (headline): cxdm, ast, code (989 — deepest), schema, security
(~470 capability-denial cases), streaming (fixtures exist; lane gap G12),
abi, conversions (except TOML, G7), 41 of 49 std-lib specs, adjudicate,
run, fabric, xap_identity_model (§4 handshake + RFC 7748/8032 vectors),
xap_feature_distribution_market.

Uncovered or thin — the gap register below. Inverse gaps: `a2a`, `a2a-xap`,
`llm`, `mcp`, `mcp-server` have fixtures but **no approved spec** (pulled
toward stream 18); `db` → core/db_access.md; `xap-compose` → a working
spec, not approved.

## §4. Gap register (dispositions per Q7)

Ordered by extraction-gate risk. "Pre-I1" = must close before the identity
epoch (fixtures must exist BEFORE hash-affecting changes land, so the
epoch's one re-bless covers them — fixture-before-fix); "pre-I2" = before
Ring-0 extraction; "stream N" = closes with that stream's spec-mandated
corpus additions (sequencing behind a live consumer, not a scope cut).

| # | Gap | Evidence | Disposition (recommended) |
|---|---|---|---|
| G1 | **Tier-1 identity hash: ZERO corpus fixtures.** No `out-hash`/`expect-hash`/digest assertion in any of 4127 cases; §7's byte-for-byte gate names hashes but cannot be executed from the corpus. `data`-profile verbs `hash` and `eq` have no fixtures. (`stdlib/hash.cxd` is the Ring-1 `$hash:*` module, not this.) | census | **CLOSED at I0 (2026-08-05, C8 repair; promoted from pre-I1).** `identity_hash.cxd` landed: 5 blessed-digest singles + 10 pair cases (`out-hash-eq`), M5 commerce substrate; runner lanes `out_hash` + the pair form in `conformance_run.v`; wired as `conform-identity-hash` and into the runner's default set. The authoring pass surfaced and fixed a spec contradiction: `binding_api`-005/-101 asserted attr-order-insensitive equals/hash against canonical.md's never-normalize-attr-order rule. |
| G2 | **Tier-2 pair-properties live only in V tests** — code-identity.md §4 says the single-input corpus "cannot express" them; corpus reach is 2 store-routed cases a Ring-0 artifact can't run. | `identity_tier2_*_test.v` (19 tests), `store.cxd:470,484` | **Pre-I1** via Q3 pair-case form. |
| G3 | **`out-canonical` = 31 assertions** for the largest frozen surface (17 of them ID-adjacent in `identity.cxd`; general canonical-emit coverage ≈ 13). | census | **Pre-I1.** Canonical-emit family expansion authored WITH stream 12 (same rules, one pass): quote-shape selection, number forms, escaping, ordering, idiomatic-layer rules. |
| G4 | **ast-bin.md: zero fixtures** (V-tests only) — a Ring-0 codec not runnable as a cross-binding gate. | `ast_bin_test.v` | **CLOSED at I0 (2026-08-05, C8 repair; promoted from pre-I2).** `ast_bin.cxd` landed: 3 golden-bytes cases (v6 envelope, determinism asserted in-lane) + 3 round-trip cases incl. multi-doc and the v9 table envelope; runner lane `out_ast_bin_hex`; wired as `conform-ast-bin` and into the runner's default set. |
| G5 | **data-bin byte assertions = 5 emit + 3 decode** for a format frozen at 1.0 (arrow/schema-driven families are round-trip-only, by declared Arrow-instability design). | census | **Pre-I1 half LANDED 2026-08-05** (pre-I1 pin batch): ch-008…011 add golden wire bytes for the float64/bool/date/i64 column kinds the family missed — the scalar-tag surface the I1 epoch touches (0x18/0x28 join) now diffs explicitly against proven-untouched kinds. Decimal/bigint goldens land WITH the epoch (their tags do not exist yet). |
| G6 | **formatting.md: zero fixtures**; §1's normative purity invariant ("never changes the data") untested. | `fmt_lossless_test.v` only | **Pre-I3** (fmt is Ring 1; must be pinned before the Ring-1/2 split ships `cli`). |
| G7 | **TOML: 4 emit fixtures, no import fixtures.** VERIFIED 2026-08-05: TOML import IS a shipped surface (`parser_toml.v`, `--from=toml` works) — the import lane is fixtured pre-I2. | probe | **Pre-I2.** |
| G8 | **XSP: no corpus at all** (no `xsp.cxd`; both xsp specs uncovered; xsp-auth.cxd covers the identity handshake only). Frames, credit, resumption, transient-channel semantics unpinned. | census | **Stream 4** corpus additions (the store-profile spec mandates them; parity gate needs them anyway). |
| G9 | **debug.md: zero coverage anywhere**; the §6a tape is a versioned CX document — directly fixturable. | census | Ruled with deferral D-DBG (Q10). |
| G10 | **lockfile.md Ring-0 surface unfixtured** (2 Ring-1 eval cases only; the lockfile is a CX document). | `code.cxd:6521,6536` | **Pre-I2.** |
| G11 | **RESOLVED → #701.** Module fixture cases are green for the right reason: sources resolve from in-memory registration (`stdlib_bundle.v` `register_conformance_test_modules`, hermetic by design). But (1) that registration runs unconditionally in the production module-table constructor and `resolve_lib` gives it precedence over disk — fixture sources SHADOW user files in shipped binaries (fail-loud violated; filed #701, fix rides I2 with the fixture_loader.v cleanup); (2) `conformance/fixtures/module/` is an unreferenced on-disk duplicate — drift risk, disposition ruled in #701. | `module_loader.v:501`, `stdlib_bundle.v:401` | **#701; I2 ride-along.** |
| G12 | **`streaming_write.cxd` has no V lane** — driven only by python/go/rust harnesses; the reference implementation is untested against 17 fixtures incl. the W001–W013 negative contract. | `lang/*` drivers; no Makefile target | **Pre-I2:** wire a V runner lane. |
| G13 | **Store wire protocols: no corpus** (grpc, remote-protocol, columnar, networked backends, service tier). §12.1 makes the wire the ONLY binding-facing store contract. | V-tests only | **Stream 4** (protocol corpus lands with the XSP store profile; gRPC parity suite is the I5 gate). |
| G14 | **did.md / vc.md unfixtured** — pure crypto/document surfaces underpinning Ring 2's single authority model. (`sql`/`redis` corpus absence is defensible per `gates.cxd` — build-flag-conditional; `term` is interactive-surface.) | V-tests only | **Pre-I3.** |
| G15 | **Fixtures with no approved spec:** a2a (5), a2a-xap (7), llm (3), mcp (6), mcp-server (6). | census | **Stream 18** rules spec-or-retire for each. |
| G16 | **No grammar-production → fixture traceability map**; grammar freezes at 1.0. Seed exists: `vcx/tests/formal/witnesses.txt` + harness. | census | **Stream 14 continuous deliverable**, produced alongside stream 13's grammar review. |
| G17 | **`gates.cxd` is unvalidated policy** — nothing schema-checks it or verifies module entries name real suites; a stale entry silently downgrades a lane. | census | **I0** (lands with the import gates; cheap validator). |
| G18 | **CXER registry (governance.md §9.6):** 813 `out-err` + 36 `expect-codes` exercise codes, but nothing asserts registry completeness/non-collision. | census | **I0** (validator beside G17). |

Also recorded: `data_bin_arrow.cxd` fixtures are Ring-0 content whose lane
carries a Ring-2 optional native dependency (runner imports `arrow`) — Q6.

## §5. Inherited-deferral batch (express confirm-or-adopt — Q8–Q12)

| ID | Deferral | Source | Recommended ruling |
|---|---|---|---|
| D-C1 | Capability scoping coarse in v1 (host:port globs + path roots); finer per-URL/per-file "a future extension" | security.md §6 C1 | **Confirm coarse v1**, with a coherence mandate: the streams 4/6 budget/metering-attenuation spec (already ruled) MUST state how quantitative bounds compose with (and do not paper over) coarse spatial scope, and name the finer-scope extension as additive. |
| D-DBG | Time-travel v2 (reverse-step/jump/checkpoints) deferred; v1 = record + forward replay; spec's own invariant: an incomplete v1 tape "is the only thing that would force a v2 rework" | debug.md §6a, §7 G2 | **Confirm the v2 deferral, adopt the fixture:** tape-completeness + tape parse/canonical/round-trip conformance fixtures are mandated for v1 (closes G9). Deferring v2 without the completeness fixture defers the risk, not the work. |
| D-T2X | Tier-2 function-level index (find-by-hash, rename-refactor, incremental re-hash) "a later extension" | code-identity.md §5 | **Confirm the index deferral.** Address-format constraints are settled pre-freeze by stream 19 (self-describing addresses); pair-property corpus coverage lands via Q3, so the identity definition is fully pinned without the index. Spec-inventory note (no identity for arbitrary expressions beyond mechanical strict-canonical hashing) is re-examined in stream 1 (E1–E4 expression identity), not here. |
| D-XSP-a | Multiplexing beyond stream-id + per-stream credit (priority/weighted scheduling) | xsp.md §5.4 | **Confirm** — additive by construction (negotiated features). |
| D-XSP-b | WebSocket / WebTransport carriers | xsp.md §5.4, §4 | **Confirm** — same frames, carrier swap, no frame change. |
| D-XSP-c | **Cross-runtime VC revocation propagation** — "rides the same server↔server channel once defined," and no such channel is specified anywhere. A revoked credential stays honored on peer runtimes indefinitely. | xsp.md §5.4; vc.md §5 3b | **Adopt into stream 4:** the XSP store-profile spec MUST define the server↔server channel and the revocation-propagation profile over it. This is a security hole in Ring 2's single authority model, not a feature gap. |
| D-MOD | **Found by this audit** (not in the mandate list): live HTTPS module fetch + on-disk cache "deferred per §12.4.2" (`module_loader.v` returns `MODULE_HTTPS_FETCH_DEFERRED`; pkg-url fetch resolves only via registry). | modules spec §12.4.2 | **Confirm** — sequencing behind the Ring-3 distribution/registry consumer (C4, #699); resolver shapes + SRI verification are already spec'd and fixtured, so the deferral is additive. |
| D-ID | `identity.cxd` v0 self-deferrals: D6 cross-format ID round-trip, **D7 canonical-form ID renaming (canonical-bytes-affecting)**, D3 include-time ID merging, D1 `[ref @id]` body form. Provenance reference in the file is empty ("per )"). | identity.cxd:3–14 | **D7 adoption RETRACTED 2026-08-05 (audit M9):** the "adopt D7 into stream 12" instruction had no receiving content in the stream-12 spec and was already stale when written — D7 SHIPPED as canonical.md §2.7b (see the §5 batch-status staleness note below); a live adoption instruction pointing at nothing would have confused I1 execution. **Confirm D6/D3/D1** as post-partition tracker issues; provenance refs RECOVERED at I0 (n27 pass — identity/lint/include headers repaired on the impl branch). |

## §6. Structural rulings — RULED

Letters 1–13 **all ruled (a) by the owner 2026-08-05** ("all
recommendations accepted"): code.cxd splits by lane; `ring=` lives in the
fixture data; the pair-case form + digest assertions are adopted (the
code-identity.md §4 exception is retired); io/process/env are Ring-1
local-effect packs with watch/serve surfaces split to Ring 2 (partition
spec §2/§10 wording to be amended); http splits at its internal seam;
data_bin_arrow fixtures are Ring 0 with a dlopen-gated, visibly-skipping
lane; the §4 gap-disposition table is ratified as drafted; deferrals:
D-C1 confirmed w/ streams-4/6 coherence mandate, D-DBG confirmed w/ the
tape-completeness fixture mandate, D-T2X confirmed, D-XSP items 1–2
confirmed + item 3 ADOPTED into stream 4, D-ID: ~~D7 adopted into stream
12~~ (RETRACTED 2026-08-05, audit M9 — no receiving content; D7 already
shipped as canonical.md §2.7b, per item 3 of the batch status below)
+ D6/D3/D1 confirmed as post-partition tracker issues + provenance refs
recovered, D-MOD confirmed. Recorded in the campaign decision log.

## §7. Continuous-audit work queue (this stream, ongoing)

1. G11 module-scaffolding verification — **DONE** (resolved → #701).
2. G7 TOML-import surface verification — **DONE** (import is shipped;
   fixtures pre-I2).
3. Provenance-reference recovery (D-ID) — **RESEARCHED, filed #709**:
   the elided reference was a drained legacy record (removed by the
   spec-only-source-of-truth sanitization; #709 names it); only ONE
   elision site exists (identity.cxd:8); the
   block is also STALE — D7 is shipped (canonical.md §2.7b) and D1
   partially so. Recovery = repoint at cxdm.md §4 + reconcile claims;
   file edit applies at I0 with the ring-tagging pass (corpus files
   feed gate baselines).
4. G16 grammar-production traceability map — **SCOPED 2026-08-05 (I0).**
   Inputs inventoried: 310 production ids (265 grammar.ebnf + 45
   lexicon.ebnf) and 112 witness rows (`vcx/tests/formal/witnesses.txt`).
   **The map is NOT mechanically derivable today:** witness ids are
   symbolic rule FAMILIES (`LX-INT`, `GR-*`, `M-*`, `G-*`), not the
   bracketed production ids (`[L20]`, `[55]`) — the correspondence is
   judgment work, which is why it is authored WITH stream 13's grammar
   review (a prefix-match script would manufacture false coverage
   signal — declined per the honest-reporting posture). Stream 22 adds
   the eval-rule→witness second axis via `rule=` beside `ring=`. The
   G17 (`gates_manifest_gate.sh`) and G18 (`cxer_registry_report.sh`)
   validators from this queue ARE landed at I0.
5. Ring-tag application (`ring=` attributes) — lands at I0 with the gates.
6. Fixture families added by later streams are ring-tagged on entry
   (append-only corpus discipline).

## Stream-14 receiving register — the I5 handoff manifest (authored 2026-08-13, audit ruling Q6a)

Stream 14 (#686) is the corpus absorber and runs LAST. Every I5 stream
that deferred corpus families here is enumerated below with the pointer
to the owing ledger section — this register is the single place the
stream-14 implementer starts; the ledger sections hold the content.
(Authored by the I5 adversarial audit, which found the handoffs living
only in per-stream prose — partition_I5_audit.md AF-10.)

| owing stream | handoff | recorded at |
|---|---|---|
| s8 (#680) | the full four-quadrant/restatement M5 corpus family | partition_I5_stream8_bitemporal.md §wave-record (search "stream 14") |
| s9 (#681) | the full §7 corpus program of distributed_store.md | partition_I5_stream9_distributed.md (search "stream 14") |
| s10 (#682) | the entire §6 corpus handoff: both-ways serializable pair, replay-isolation family, compensation triple, idempotent-step pair, escrow pair, stale-pin negative, budget-boundary pair, head-set read, [conflict] fixture, anti-2PC negatives | cross_stream_coordination.md §6 |
| s16 (#688) | M5 corpus families per shape_inference §11 | partition_I5_stream16_shape.md (search "stream 14") |
| s17 (#689) | the FULL per-combinator pull matrix + M5 witness families (runtime_representation §9 + the stream-22 handoff) | partition_I5_stream17_runtime.md §named-landings |
| s20 (#692) | M5 corpus families per erasure_compliance §10 | partition_I5_stream20_erasure.md (search "stream 14") |
| s21 (#693) | 8 named families: add-a-field / SPLIT / 10k-replay / compat three-valued / downgrade-skip pair / pre-flight pair / ambiguous-graph / migrated-from discriminator; + the downgrade-replay visible-count fixture | partition_I5_stream21_schema.md §8 handoff row |
| s22 (#694) | M5 witness corpus families per clean_room_implementability §9 | partition_I5_stream22_cleanroom.md (search "stream 14") |

Audit-added corpus notes for stream 14 (partition_I5_audit.md AF-9):
the strict-mode fixture tag is honored only in the code.cxd runner lane
(stdlib/package lanes lack the handling — latent until a fixture uses
it); out-effects grading is skipped for thrown-error fixtures (latent);
the no-CXER-code out-err sweep (journal-057/058 class) rides the #796
batch but the corpus discipline (every out-err carries a code) belongs
here. New entries to this register are append-only; a stream that hands
off to stream 14 after this date adds its row here in the same commit.
