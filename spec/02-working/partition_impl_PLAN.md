# Partition implementation plan — spec waves, implementation phases, gates

**Status:** Phase-3 deliverable of the #651/#516 campaign. Gate G-C = owner
approval of this document. Nothing below the "Implementation phases" heading
begins until every spec wave is complete AND G-C has passed (campaign ground
rules 4–5). Companion: `cx_partition.md` (G-B approved 2026-08-05).

## Part A — spec authoring waves (inside the gate)

All 22 stream specs (#673–#694) are authored on `design/651-516-partition`
in dependency order. A wave starts when its dependencies are approved.
Stream 14 (#686, corpus audit) starts immediately and runs continuously —
its ring-tagging output feeds every later gate, and its inherited-deferral
review must complete before G-C.

| Wave | Streams | Why this order |
|---|---|---|
| **S0 — identity-critical foundations** | 12 canonical warts (#684) · 11 decimal/bigint (#683) · 19 crypto-agility (#691) · 15 namespace permanence (#687) · 13 lexicon review (#685) | Everything downstream hashes; these change what bytes mean. Nothing else can be finalized while these are open. |
| **S1 — core model** | 1 semantic value model E1–E4 (#673) · 17 runtime representation (#689) · 16 shape inference (#688) · 22 implementability (#694) | E1–E4 consume S0's address/canonical rulings; 17 constrains the ABI the partition freezes; 16 feeds typed queries. |
| **S2 — language & computation** | 2 planar algebra (#674) · 5 computation identity (#677) · 6 commands/effects (#678) · 8 bitemporal (#680) | 2 needs E1 + 16; 5 composes Tier-2 + Tier-1 + E1; 6 needs the value-model lanes. |
| **S3 — runtime & live** | 3 live modes (#675) · 7 consistency vocabulary (#679) · 21 schema/event evolution (#693) · 18 agent-tool projection (#690) | 3 needs 2's dependency extraction; 21 composes with 5; 18 projects 6. |
| **S4 — platform & distributed** | 4 XSP store profile (#676) · 9 distributed store (#681) · 10 cross-stream coordination (#682) · 20 erasure/compliance (#692) | 4 needs S0 addresses + the value model; 9/10/20 build on 4. |

Wave exit = every spec in the wave owner-approved (G3-style). The M5
commerce/order-fulfillment domain is the worked example in every spec.

## Part B — implementation phases (after ALL waves + G-C)

Each phase ends green on the full conformance corpus and the import gates.
No production consumers exist, so rollback for every phase is a branch
revert — but the strangler rule still holds: the monolith keeps shipping
unchanged until I2 completes.

| Phase | Work | Exit gate |
|---|---|---|
| **I0 — seams before moves** ✅ **EXITED 2026-08-05** (branch `impl/I0-import-gates-ring-tagging`, merged back at exit) | CI import gates (§3 of the partition spec) + corpus ring-tagging (from #686) land on the monolith. Zero code moves. **Done:** `scripts/ring_import_gate.sh` (Ring-0 sink invariant, deny-set derived live + the C-edge lane per audit M34/M35, wired into TEST_TARGETS, synthetic-violation-verified); `ring=N` on all suite headers per audit §2 WITH the audit C8 repairs (binding_api per-case, code.cxd `eval-ring=1`, io watch → 2, http client/serve split, x-tier → Ring 1) — verified runner-inert; `scripts/ring_query.cx` (the §2 corpus query + `ring-tag-gate`); the G1/G4 gap-closure families (`identity_hash.cxd`, `ast_bin.cxd`) with their runner lanes; G17 (`gates_manifest_gate.sh`, hardened per M36) + G18 (`cxer_registry_report.sh`, rebuilt per M38 w/ two-owner detection) validators; the runner's per-suite `default=` tier (M37); census + provenance repairs (n26/n27). **Remaining I0-adjacent, non-exit-blocking:** the G16 grammar-production→fixture traceability map (scoped, inputs inventoried). | Gates green on unmodified tree; a synthetic violation fails the lane. ✅ MET — audit §7 item 1 repairs all landed; the audit's own exit condition ("I0 may exit after the script/tag repairs") satisfied. |
| **I1 — identity epoch** ✅ **EXITED 2026-08-06** (branch `impl/I1-identity-epoch`, merged back at exit; THE RE-BLESS = ef80e409; owner APPROVED the mapping file + corpus diff and ruled entry-25 schema-mode (a) 2026-08-06 — mode-in-identity resolves BEFORE I5's type-binding anchoring, pinned by `test_mode_does_not_survive_canonical_text_named_residual`) | ALL hash-affecting changes land together in the monolith as ONE coordinated cutover: decimal/bigint kinds (11), canonical-wart fixes (12), self-describing addresses (19), any 13/15 canonical touches; **the journal entry + snapshot hash-preimage specifications (audit C1: `entry-canonical` / `snapshot-canonical` wrappers, field order, non-default-only `stream` binding, algo-tag composition — now normative in journal.md — plus the reserved `fold-id?` signed-preimage slot for stream 21, and #720's detached-payload entry form under the same wrapper)**; the journal ts-form (#712); **the FULL operator-head lexer surface (audit C4: all seven heads `+ - * / = < >` — five silently stringify today, two error; every stored operator-headed document changes meaning AND address, per-head fixture pairs pinned before the fix)**; the quote-hole authorable form with its MUST-not-collide-with-string rule + the `$x` vs `'$x'` pair; the three E1 totality refusals (closures normative, iterators refuse-not-materialize, `::secret` refuses — behavior fixes, no address moves). One corpus re-bless, one identity epoch — never a second one. | Full corpus re-blessed and green; old→new hash mapping recorded; spec/corpus/impl agree. |
| **I2 — Ring-0 extraction** ✅ **EXITED 2026-08-06** (branch `impl/I2-ring0-extraction`, merged back at exit; ledger = `partition_I2_extraction.md`) | `libcx-core` + `data`-profile `cx` built from `vcx/cx`. Cleanups ride along: fixture_loader → test support, cx.dylib debris, dead cxstore/cxsqlite, arrow_pub rename. **Done:** `vcx/cli` shared Ring-0 verb layer + `vcx/cmd_data` data-profile main (cannot-execute by construction; verb-word refusals); `lib-core`/`cli-data`/`build-data` targets (libcx-core = 155 cx_* exports, strict subset of libcx); all four riders + the NEW `test-vcx-cx` lane (#737 filed on the -gc e in-module-test RC double-free found wiring it); pre-I2 gaps G7 (TOML import, #738 filed on parser leniency)/G10 (`lockfile.cxd`)/G12 (streaming-write V lane) closed; #701 fixed+closed; #707 executed in full (EV-RESULT-IMAGE §11.1a, grant= policy, README rewrite, consistency tool repaired+wired w/ no-impl-anchor + no-dangling-decision, EV-ASYNC-SPAWN — open only for the I5 lazy-substrate residual). | **Byte-for-byte**: extracted artifact matches the monolith on the full Ring-0-tagged corpus — outputs, canonical bytes, hashes, error codes identical. ✅ MET — `make test-extraction-gate` (TEST_TARGETS): ABI transcripts byte-identical (1564 Ring-0 cases, prod shape) + CLI lane 8978 invocation pairs identical + 17 profile refusals; full `make test` + binding parity 51/51 green at close. |
| **I3 — Ring 1/2 split** ✅ **EXITED 2026-08-06** (branch `impl/I3-ring12-split`, merged back at exit; ledger = `partition_I3_ring12_split.md`, entries 1-9) | The `vcx/code` frontier: store verbs, protocols, xap/fabric/session/authz/did/vc, DB drivers, process/io → Ring-2 modules; evaluator + pure/local stdlib stays Ring 1. Pack gates named per the profile table. **Done:** G6 (fmt.cxd + mechanical §1-purity/§7-idempotence runner) + G14 (did/vc golden fixtures; #739/#740 filed); `make libcx-abi-gate` landed FIRST (713-symbol Darwin baseline); dispatch seams A-M registry-clean (`ring_registry.v` probes + `ring2_register.v`); seam H split http client (Ring 1, incl. SSE client + its walkers) / serve (Ring 2) and pulled `net_core.v` (handle table + SSRF + dial + buffered reads) into Ring 1; THE MOVE: NEW module `vcx/platform` (71 prod .v + 2 .c + 69 in-module tests; selective `import code {…}`; ~160 pub-ified internals; `platform_init.v` = seam G) — `vcx/code` compiles STANDALONE; libcx builds over platform/ with the surface bit-identical; pack gates named (module-import gate for Ring-2 packs; `-d` gates for drivers/backends; Ring-1 local-effect pack `-d` gates get their live consumer at I4's build matrix); `ring_import_gate.sh` extended to the full frontier (code→cx-only, platform→{cx,code,cxstore,arrow,transport}), synthetic-verified both lanes. | Full corpus green; import gates green; libcx ABI unchanged (symbol diff empty). ✅ MET — full `make test` rc=0 (only the two standing classified-retry lanes, both green on retry); extraction gate byte-identical both lanes; binding parity green. |
| **I4 — profiles & installer** ✅ **EXITED 2026-08-06** (branch `impl/I4-profiles-installer`, merged back at exit; ledger = `partition_I4_profiles.md`, entries 1-6) | Build matrix for data/embed/cli/platform; cxhome.org/install profile wiring; per-ring gate lanes activate (#700's structural relief). **Done:** ruling R1 = N4 reconciliation (libcx keeps the 0–2 surface + 713 ABI through I4 — binding StoreClient reaches the store via `cx_code_eval_caps` Ring-2 verbs; the §5 rings-0–1 re-cut BINDS TO I5 stream 4's CSRP retirement; the §5 artifact exists NOW as the embed-shape libcx: declared ABI minus exactly the 2 iowatch callbacks, zero mbedtls); nine `_notd_cx_no_pack_*` pack gates (§4 seven + http-client + sched by dependency closure; NEW pure `datetime_core.v`; purity/cap tables + source embeds made profile-invariant); ONE cmd module with `_d_cx_platform`-gated daemon verbs — default cx = platform profile byte-compatible, flag-less = cli, +CX_PACKS_OFF = embed (`build-profiles`; prod sizes 2.0/5.1/6.2 MB + libcx-core 2.9 MB); `test-profile-gate` in TEST_TARGETS grades BOTH profile engine compositions over the ring-tagged corpus + refusal/binary probes — its first run caught 31 corpus mis-tags, repaired as fixture data (NEW per-case `eval-ring=` + `packs=` attrs in fixtures.cxs; svc family eval-ring=2 keeps the Ring-0 extraction corpus untouched at 1564; census R1=2006 R2=692, eval R1=966 R2=25); `test-ring0/1/2` lanes activate (#700); installer `CX_PROFILE=data\|embed\|cli\|platform` + release.sh/release_linux.sh profile tarballs (assets publish with the next cut). | Each profile builds + passes its ring-tagged corpus; installer one-command per profile. ✅ MET — full `make test` rc=0 (only the two standing classified-retry lanes, green on retry); profile_gate cli 2833 / embed 2262 graded, 0 failures; extraction gate byte-identical both lanes; ABI 713 identical; binding parity 252/252. |
| **I5 — stream implementations** | #673–#694 implement in wave order against the partitioned tree, each on its own branch off the campaign branch, each gated by its approved spec + corpus additions. Early: 4 (store profile → CSRP data-plane retirement at parity gate), 2+3 (planar queries + live modes). Bindings v1 surface + auto-mirror lane (§12) ride the first cut after I4. | Per-stream: spec conformance fixtures green; **PLUS the I2 byte-identity clause on Tier-1/Tier-2 addresses over the full corpus for any stream that re-implements or retires an identity-bearing traversal or emitter (audit C9: stream 2's ONE-walk retirement includes the Tier-2 emitter's traversal — fixtures pin OUTPUTS, not addresses; W-22 is the standing proof that an emitter re-implementation can move every hash while staying green)**; for stream 4: gRPC-style parity suite passes over XSP store profile, then CSRP data plane removed, **and its transcript-covered negotiation lands as an `xsp-auth/2/` → `/3/` HKDF label bump (the label IS the version handle; what the transcript covers changes, so `/2/` transcripts must not be reusable), with #718's downgrade-strip security item verified in the same cut**. |
| **I6 — M5 proof** | Commerce/order-fulfillment showcase: native client + XAP UI + agent + REST/SQL adapters + offline replica against one model. | The demonstration itself — adapters project one model; campaign closes; #516 headline delivered. |

## Gates recap

- **G-A** (passed 2026-08-04/05): verdicts + streams filed + G-decisions.
- **G-B** (passed 2026-08-05): partition spec approved.
- **Wave exits:** per-spec owner approvals, S0→S4. **ALL FOUR WAVES
  EXITED 2026-08-05** — 22 stream specs finalized under the standing
  acceptance ruling (letters 1–189; decision log). Spec authoring
  (Part A) is COMPLETE. Defect issues #701–#720 filed along the way,
  each dispositioned to a phase (I0/I1/I2/I3/I5). **Implementation may
  begin at I0.**
- **G-C:** owner approval of this plan → implementation may begin at I0.
- **Phase exits:** as tabled; every phase green on full corpus + import
  gates before the next begins.

## The I1 manifest — itemized checklist (audit M20; the G-C-approved home)

The authoritative I1 change list, one row per change (audit n9's
two-class column: **MOVES** = existing digests/addresses change bytes;
**DEFINES** = a surface that had no address gains one; **PINS** = spec
catches up to shipped bytes, nothing moves; **BEHAVIOR** = output
changes, no identity involved). "Any 13/15 canonical touches" is now
enumerated — rows 11–12 — not a blanket clause. Every MOVES row lands
in the single epoch; the old→new mapping file covers exactly the MOVES
rows.

| # | Change | Class | Pinning fixtures (pre-fix) |
|---|---|---|---|
| 1 | Decimal/bigint semantic kinds (stream 11: scale-preserving identity, ascription, 9→11 kinds) | MOVES (decimal-bearing docs) + DEFINES (bigint/ascription spellings) | `extended.cxd` 016j; `identity_hash.cxd` idh-023 (the L40 flip case, blessed to pre-epoch truth) |
| 2 | Canonical-wart fixes (stream 12: trailing-LF-in-hash, §2.4 escapes, quote tiebreak, UTC-Z datetimes, redundant-annotation strip, dup attr/xmlns errors, PI strip, NFC names) | MOVES (potentially every stored doc) | `identity_hash.cxd` singles idh-001…005; `core.cxd`/`extended.cxd` canonical rows |
| 3 | Self-describing tagged addresses (stream 19: `sha2-256:<hex>` form, multihash wire tag) | MOVES (address REPRESENTATION everywhere; digest bytes unchanged) | every `out-hash` fixture re-blesses its spelling |
| 4 | Stream 13 lexicon repairs that touch canonical spellings (registry repair, [59a] deletion, r''' data-mode) | MOVES (affected spellings) | `lint.cxd`/`atoms.cxd` affected rows |
| 5 | Stream 15 namespace-permanence URI (`tag:cxhome.org,2026:ns/cx` in hashed positions) | MOVES (ns-bearing docs) | `namespaces.cxd` |
| 6 | E2 schema hash basis → canonical TEXT bytes (L82) | MOVES (`0x10`/`0x12` digests) + the shipped `schema_content_hash` 4-byte-frame divergence catalogued (audit M11/n17, #724) | schema fixtures + the E2 pair |
| 7 | Lane-1 `__cx_meta__` fix | MOVES (affected docs) | the #708 witnesses |
| 8 | Operator-head lexer surface — ALL SEVEN heads `+ - * / = < >` (audit C4: five stringify silently, two error today) | MOVES + meaning change for stored operator-headed docs | per-head pre-fix pairs (stringify/error behavior pinned) |
| 9 | Quoted-tree lowering + the authorable hole form with its MUST-not-collide-with-string rule (audit C4) | DEFINES (quotes have NO address today — E210) | the `$x` vs `'$x'` pair + E210 negatives |
| 10 | Journal ts-form (#712: deterministic UTC-Z synthesis) | MOVES (journal entry hashes) | journal fixtures pre-pin |
| 11 | Detached-payload entry form (#720, stream 20) | DEFINES (new entry form; existing chains untouched) | erasure witness family |
| 12 | Entry + snapshot preimage specifications incl. the reserved `fold-id?` signed slot (audit C1) | PINS (spec catches up to shipped bytes; fold-id omitted-while-unset) | `identity_hash.cxd` + journal verify fixtures |
| 13 | Tier-2 participating-field set (audit C2: named-param names, default values, returns-type source bytes, closed exclusion list) + persisted `code:` rehash with mapping | MOVES (`code:` addresses) | the §5 pair-fixture family (C2 rule 6) |
| 14 | E1 totality refusals (closures normative, iterators refuse-not-materialize, `::secret` refuses — audit C4) | BEHAVIOR | one refusal fixture per class |
| 15 | `CXER4604`/`1704` retirement (audit M21 — a declared public-surface compatibility event, dispositioned HERE so the fixture re-bless happens once, with the epoch; stream 10's stale-pin fixture moves to `CXER1114` in the wave-S4 reconciliation) | BEHAVIOR (error-code surface) | the retirement negatives |
| 16 | Data-bin scalar tags `0x18`/`0x28` (stream 11 wire) — **with the M23 advisory window declared:** stream 17's transparency fixture family CANNOT be green for decimal/bigint/atom columns between I1 and I5's column lattice; those fixtures run `advisory` in the window and flip `enforced` at I5, by design | MOVES (CXCol wire bytes for affected columns) | data-bin fixtures + the declared-advisory set |

**Re-bless discipline (audit M22 — the "one corpus re-bless" sentence,
split honestly):** there is ONE **identity epoch** — addresses and
canonical bytes move exactly once, at I1, covering every MOVES row
above. There are additionally **per-phase OUTPUT re-blesses** that move
no identity: stream 22's result-image re-spec (~3511 eval fixtures),
EV-* behavior changes, γ hash-partition, `[par]` ordering — each lands
with its owning phase and re-blesses outputs only. Claiming these ride
the I1 epoch would inflate it with non-identity churn; claiming they
don't exist was false.

**Defect dispositions (audit M24 — the three rows the plan claimed but
never had):** #707 (conformance front door + spec gates) → I2 (it
gates the extraction's corpus contract); #717 (registry) → landed
2026-08-05 (C5 repair; residual = the CXER0014 phantom hover fix, I0
follow-up on the impl branch); #718's security item (downgrade-strip)
→ I5 stream-4 cut, verified with the `/3/` label bump (audit C9).

**Identity-epoch-membership paragraphs (audit C9):** every stream spec
MUST carry an explicit paragraph declaring its identity-epoch
membership (hash-affecting: which manifest rows; or additive: claimed
loudly) before its I5 branch cuts. Streams 5/17/20/21 are the
template; the eight silent specs — streams 2, 3, 4, 7, 9, 10, 18, 22 —
gain theirs in the wave-S4 reconciliation pass; three of this audit's
CRITICALs lived in silent streams, which is the point.

## Standing constraints

Maintenance continues on `release/0.16.0` untouched; #700 (test relief)
proceeds there immediately, independent of these gates. The merge target for
the campaign branch is decided when the final gate passes — whichever
release line is current. Sanitization rules apply to every artifact of this
plan. No deferrals or scope cuts without express owner authorization.
