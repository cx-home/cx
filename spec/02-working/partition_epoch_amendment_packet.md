# I1 epoch-corpus amendment review packet (remediation R2.1 / finding F-7)

**Status: prepared for owner review — NOT yet ruled.** (S5 reconciliation
addendum with fresh re-verification at HEAD appended 2026-08-08 — see the
end of this packet; the F6(b) ruling folds this sign-off into the ONE
ratification pass over the corrected identity corpus, and that pass is now
ready.)

Scope: every conformance-output amendment in `aa2a24c2` (ledger entry 35,
22 "degraded bless adoptions repaired" + math-116 added) and every
re-pinned assertion in `d8d638b7` (ledger entry 36, "12 stale 64-hex pins
re-pinned tagged" + spelling/dual-accept flips). Both commits amended the
I1 identity-epoch corpus AFTER the owner approved the re-bless review at
`f294f9ec` (2026-08-06 01:15), without a fresh sign-off — that is the F-7
process breach this packet remediates.

Method: `git show` archaeology only. Every BEFORE/APPROVED/AFTER value
below was extracted from the commits named in the commit map and compared
byte-for-byte (full case blocks for the corpus files; full diffs for the
vcx test files). No repository file other than this packet was touched.

## Commit map

| Label | Commit | What it is |
|---|---|---|
| BEFORE (pre-re-bless) | `b04bd52c` (= `6f1e5cc8^`) | parent of the first epoch commit that touched math/prof/random corpora; holds the pre-epoch blessed values |
| epoch bless 1 | `6f1e5cc8` | "endgame part 1 — 128 adoptions"; **all 20 degraded outputs entered here** |
| epoch bless 2 (THE RE-BLESS) | `ef80e409` | corpus regenerated, registry re-sealed; kept the degraded adoptions |
| APPROVED-DEGRADED | `f294f9ec` | owner ruling "re-bless review APPROVED" (docs-only commit); corpus state verified byte-identical to `ef80e409` and to `aa2a24c2^` (`ba8a3076`) for all three files |
| AFTER (entry 35) | `aa2a24c2` | post-epoch adoption audit — the amendment under review |
| AFTER (entry 36) | `d8d638b7` | post-epoch code-lane discharge — the re-pin commit under review (parent `aa43c93b`) |

Verification anchors (all re-runnable):

- `git diff ef80e409 aa2a24c2^ -- conformance/stdlib/{math,prof,random}.cxd` → empty (approved state = pre-amendment state).
- `git show f294f9ec:conformance/stdlib/<f>.cxd` byte-identical to `ef80e409:` same paths (all three files).
- `git diff 6f1e5cc8^ d8d638b7^ -- <the 11 vcx test files of Part 2>` → empty: **none of the re-pinned test files was touched at any point during the epoch**, so for Part 2, BEFORE (pre-epoch) == APPROVED (f294f9ec) in every row.
- Per-case block comparison places every Part-1 degradation at `6f1e5cc8`, none at `ef80e409` (prof-016/017/018 were never changed by the epoch at all).

Classification key (per the R2.1 ruling):

- **restored-pre-epoch** — the AFTER blessed output equals the pre-epoch BEFORE output.
- **genuinely-new-value** — the AFTER value existed in neither BEFORE nor APPROVED; needs specific owner attention.
- **other** — neither (e.g. input-only re-spell with output unchanged across all three states).

One systemic note the owner needs for Part 1: every repaired case also had
its **input** re-spelled (bare float literals `2.0` → exponent form
`2.0e0`). This is not cosmetic — under the epoch's 2b literal flip, the
pre-epoch spelling `2.0` now denotes a **decimal**, which is exactly what
produced the degraded CXER3002/CXER0100/CXER3001/no-callable/blank
outputs. The pre-epoch input spelling no longer expresses the case's
float intent; the exponent re-spell is the minimal edit that does. So for
the 20 restorations, "restored-pre-epoch" is an **output-value** claim:
AFTER output == BEFORE output, while AFTER input ≠ BEFORE input (spelling
only, same intended float value).

---

## Part 1 — `aa2a24c2` (ledger entry 35): 23 amended cases + 1 added case

File paths: `conformance/stdlib/math.cxd`, `conformance/stdlib/prof.cxd`,
`conformance/stdlib/random.cxd`. Case blocks quoted from the three states
named in the commit map; `out-text`/`out-err` values verbatim.

### math.cxd — 11 amended + 1 added

**1. math-021-pow**
- Input: BEFORE `[$math:round-to [$math:pow 2.0 10.0] 0]` → AFTER `[$math:round-to [$math:pow 2.0e0 1.0e1] 0]`
- BEFORE (b04bd52c): `1024.0`
- APPROVED-DEGRADED (f294f9ec): `[err code=cx-err:CXER3002 message='pow: transcendental functions are not defined over the exact kinds (decimal/bigint) — [cast … :float] first (math.md §4.4)']`
- AFTER (aa2a24c2): `1024.0`
- Classification: **restored-pre-epoch** (output identical to BEFORE; input re-spelled for float intent).

**2. math-022-sqrt-perfect**
- Input: `[$math:sqrt 16.0]` → `[$math:sqrt 1.6e1]` (under round-to 0)
- BEFORE: `4.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='sqrt: …']` (same refusal text pattern as case 1, verb `sqrt`)
- AFTER: `4.0`
- Classification: **restored-pre-epoch**.

**3. math-023-sqrt-2-approx**
- Input: `[$math:sqrt 2.0]` → `[$math:sqrt 2.0e0]` (round-to 8)
- BEFORE: `1.41421356`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='sqrt: …']`
- AFTER: `1.41421356`
- Classification: **restored-pre-epoch**.

**4. math-024-cbrt**
- Input: `[$math:cbrt 27.0]` → `[$math:cbrt 2.7e1]` (round-to 0)
- BEFORE: `3.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='cbrt: …']`
- AFTER: `3.0`
- Classification: **restored-pre-epoch**.

**5. math-025-exp-zero**
- Input: `[$math:exp 0.0]` → `[$math:exp 0.0e0]` (round-to 0)
- BEFORE: `1.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='exp: …']`
- AFTER: `1.0`
- Classification: **restored-pre-epoch**.

**6. math-027-log2-1024**
- Input: `[$math:log2 1024.0]` → `[$math:log2 1.024e3]` (round-to 0)
- BEFORE: `10.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='log2: …']`
- AFTER: `10.0`
- Classification: **restored-pre-epoch**.

**7. math-028-log10-100**
- Input: `[$math:log10 100.0]` → `[$math:log10 1.0e2]` (round-to 0)
- BEFORE: `2.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='log10: …']`
- AFTER: `2.0`
- Classification: **restored-pre-epoch**.

**8. math-030-log-negative-is-nan**
- Input: `[$math:is-nan [$math:log -1.0]]` → `[$math:is-nan [$math:log -1.0e0]]`
- BEFORE: `true`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3002 message='log: …']`
- AFTER: `true`
- Classification: **restored-pre-epoch**.

**9. math-034-tan-pi-over-4**
- Input: `[$math:tan [/ [$math:pi] 4.0]]` → `[… 4.0e0]]` (round-to 8)
- BEFORE: `1.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER0100 message='/: decimal/bigint arithmetic admits only int/bigint/decimal operands — [cast] is the only decimal↔float bridge (L44)']` (note: a DIFFERENT degradation class — the `/` mixed-kind refusal, not CXER3002)
- AFTER: `1.0`
- Classification: **restored-pre-epoch**.

**10. math-061-correlation-perfect**
- Input: ten-element float sequences re-spelled `1.0, … 10.0` → `1.0e0, … 1.0e1` (both argument sequences)
- BEFORE: `1.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3001 message='E_MATH_EMPTY_SEQUENCE: correlation of empty sequence']` (the float filter left an empty sequence — the degraded adoption silently converted a value case into an empty-sequence error case)
- AFTER: `1.0`
- Classification: **restored-pre-epoch**.

**11. math-062-covariance**
- Input: five-element sequences re-spelled to exponent form
- BEFORE: `5.0`
- APPROVED-DEGRADED: `[err code=cx-err:CXER3001 message='E_MATH_EMPTY_SEQUENCE: covariance of empty sequence']`
- AFTER: `5.0`
- Classification: **restored-pre-epoch**.

**12. math-116-transcendental-decimal-refuses — ADDED case (no BEFORE, no APPROVED)**
- AFTER (aa2a24c2), new block: `level=core gate=enforced`, input `[$math:sqrt 2.25]` (bare literal = decimal under the epoch), `out-err` = `cx-err:CXER3002`
- Classification: **genuinely-new-value** — a brand-new corpus pin that did not exist pre-epoch and was not in the approved diff. Its stated purpose (ledger entry 35): keep ONE deliberate pin of the stdlib transcendental-over-decimal CXER3002 refusal after the repairs removed the eleven accidental ones. **Needs owner attention** (flagged in the summary).

### prof.cxd — 5 amended

**13. prof-013-histogram-observe-returns-null**
- Input: `[$prof:histogram-observe "prof-013-lat" 8.1]` → `… 8.1e0]`
- BEFORE: `null`
- APPROVED-DEGRADED: `[err code=user-undefined message='no callable "prof-histogram-observe"']`
- AFTER: `null`
- Classification: **restored-pre-epoch**.

**14. prof-014-histogram-stats-count**
- Input: three observes `1.0/2.0/3.0` → `1.0e0/2.0e0/3.0e0`, then `$s@count`
- BEFORE: `3`
- APPROVED-DEGRADED: `0` — **the one silent value corruption** (observes failed under the decimal misread, stats still answered; no error surfaced, the count simply went wrong)
- AFTER: `3`
- Classification: **restored-pre-epoch**.

**15. prof-016-histogram-reset-returns-null**
- Input: observe `5.0` → `5.0e0`
- BEFORE: `null`; APPROVED: `null`; AFTER: `null` (output identical in all three states; the epoch never touched this case)
- Classification: **other** — input-only float-intent re-spell, output unchanged.

**16. prof-017-histogram-reset-clears-count**
- Input: observes `5.0/6.0` → `5.0e0/6.0e0`
- BEFORE: `0`; APPROVED: `0`; AFTER: `0`
- Classification: **other** — input-only re-spell, output unchanged.

**17. prof-018-histogram-observe-non-finite** (`gate=skip`)
- Input: `[/ 1.0 0.0]` → `[/ 1.0e0 0.0e0]`
- BEFORE: `out-err cx-err:CXER2103`; APPROVED: same; AFTER: same
- Classification: **other** — input-only re-spell, output unchanged (case remains gate=skip).

### random.cxd — 7 amended

**18. random-026-gaussian-with-zero-stddev**
- Input: `gaussian-with … 3.0 0.0` → `3.0e0 0.0e0`
- BEFORE: `3.0`
- APPROVED-DEGRADED: *(blank out-text — `$r/value` empty; the constructor failed and the bless adopted the blank)*
- AFTER: `3.0`
- Classification: **restored-pre-epoch**.

**19. random-030-exponential-with-deterministic**
- Input: `1.0` → `1.0e0`
- BEFORE: `1.683650517646569`
- APPROVED-DEGRADED: *(blank)*
- AFTER: `1.683650517646569`
- Classification: **restored-pre-epoch** (golden value reproduces exactly).

**20. random-031-poisson-with-deterministic**
- Input: `4.0` → `4.0e0`
- BEFORE: `6`
- APPROVED-DEGRADED: *(blank)*
- AFTER: `6`
- Classification: **restored-pre-epoch**.

**21. random-032-choose-weighted-zero-weight-skipped**
- Input: weights `(0.0, 1.0)` → `(0.0e0, 1.0e0)`
- BEFORE: `'b'`
- APPROVED-DEGRADED: *(blank)*
- AFTER: `'b'`
- Classification: **restored-pre-epoch**.

**22. random-048-float-range-with-degenerate**
- Input: `2.5 2.5` → `2.5e0 2.5e0`
- BEFORE: `2.5`
- APPROVED-DEGRADED: *(blank)*
- AFTER: `2.5`
- Classification: **restored-pre-epoch**.

**23. random-070-gen-choose-weighted-zero-weight**
- Input: weights `(0.0, 1.0)` → `(0.0e0, 1.0e0)`
- BEFORE: `'b'`
- APPROVED-DEGRADED: `[err code=user-undefined message='no callable "random-gen-choose-weighted"']`
- AFTER: `'b'`
- Classification: **restored-pre-epoch**.

**24. random-071-gen-sample-weighted-zero**
- Input: weights `(1.0, 1.0)` → `(1.0e0, 1.0e0)`
- BEFORE: `()`
- APPROVED-DEGRADED: `[err code=user-undefined message='no callable "random-gen-sample-weighted"']`
- AFTER: `()`
- Classification: **restored-pre-epoch**.

### Part-1 count reconciliation

The commit message says "22 repaired (random x7, prof x4, math x11)". The
diff amends **23** existing cases. The arithmetic that fits: 22 = 11 math
+ 7 random + 4 prof (prof-013/014 output repairs + prof-016/017
re-spells), with prof-018 (gate=skip, output unchanged) as the 23rd
amended case outside the headline count. The ledger's own degraded-output
tell-tale list names only 20 cases (11 math + 7 random + prof-013/014) —
which matches this packet's classification exactly: 20 output
restorations, 3 input-only re-spells, 1 added case.

---

## Part 2 — `d8d638b7` (ledger entry 36): re-pinned assertions, code lane

Baseline fact for every row below: `git diff 6f1e5cc8^ d8d638b7^ -- <the
11 files>` is empty — the epoch never touched these files, so **BEFORE
(pre-epoch) == APPROVED-DEGRADED (f294f9ec) in every row**, and every
AFTER is a value that never existed pre-epoch. Nothing in Part 2 is a
restoration; every row is **genuinely-new-value** and therefore appears
in the AFTER ≠ BEFORE list. These pins conform the white-box lane to
behavior the epoch itself introduced (tagged content addresses, the
sha2-256: registry spelling, take-while); they are flagged because R2.1's
question is precisely whether such post-approval conformance edits were
legitimate.

### 2a. The "12 stale 64-hex pins" — assert statements re-pinned to the tagged address form

All follow one pattern — BEFORE/APPROVED asserted a bare 64-hex content
hash; AFTER asserts the I1 tagged form (`sha2-256:` prefix, total length
73). Format: file · test fn · BEFORE assert → AFTER assert.

1. `vcx/code/store_binary_wire_test.v` · `test_binary_put_get_roundtrip` · `hash.len == 64` → `hash.starts_with('sha2-256:') && hash.len == 73`
2. `vcx/code/store_binary_wire_test.v` · `test_frame_codec_roundtrip` · `fr[0].hash == 'ab'.repeat(32)` (bare 64-hex key) → `fr[0].hash == addr` where `addr = 'sha2-256:' + 'ab'.repeat(32)` (the doc-pair frame key it feeds `csrp_wire_docframe` is re-spelled the same way — this row rides the §3.2 wire re-form, see 2e)
3. `vcx/code/store_csrp_conformance_test.v` · `test_csrp_cross_encoding_parity` · `hash.len == 64` → `starts_with('sha2-256:') && len == 73`
4. `vcx/code/store_grpc_concurrency_test.v` · `test_grpc_multiplexed_streams_one_conn` · `h1.len == 64` → tagged/73
5. `vcx/code/store_grpc_concurrency_test.v` · same fn · `h3.len == 64` → tagged/73
6. `vcx/code/store_grpc_e2e_test.v` · `test_grpc_e2e_put_then_get` · `pr.hash.len == 64` → tagged/73
7. `vcx/code/store_grpc_live_test.v` · `test_grpc_live_put` · `put_hash.len == 64` → tagged/73
8. `vcx/code/store_grpc_parity_test.v` · `test_grpc_csrp_cross_transport_parity` · `csrp_hash.len == 64 && grpc_hash.len == 64` → both `starts_with('sha2-256:')`
9. `vcx/code/store_grpc_parity_test.v` · `test_grpc_csrp_query_iter_modify_parity` · `csrp_new.len == 64 && grpc_modr.new_hash.len == 64` → both `starts_with('sha2-256:')`
10. `vcx/code/store_grpc_serve_test.v` · `test_grpc_dispatch_put_get_list_delete` · `pr.hash.len == 64` → tagged/73
11. `vcx/code/store_grpc_serve_test.v` · `test_grpc_dispatch_iter_streams_one_doc_per_stored` · `d.hash.len == 64` → tagged/73
12. `vcx/code/store_grpc_serve_test.v` · `test_grpc_dispatch_modify_yields_new_content_address` · `mr.new_hash.len == 64` → tagged/73 (plus unchanged `!= src`)

Classification, all 12 rows: **genuinely-new-value** (AFTER ≠ BEFORE; BEFORE == APPROVED).

Two adjacent hash-form sites are conditions, not assert statements (the
commit's "12" excludes them; enumerated for completeness, same
classification):

- `vcx/code/store_grpc_concurrency_test.v` · helper `grpc_put_get_roundtrip` · guard `if rt.put_hash.len != 64 { return rt }` → `if !rt.put_hash.starts_with('sha2-256:')`
- `vcx/code/store_grpc_parity_test.v` · `test_grpc_csrp_delete_list_capabilities_parity` · list filter `if h.len == 64` → `if h.starts_with('sha2-256:')`

### 2b. The #188 secret-hash spelling flips (`sha256:` → `sha2-256:`) — including one contract REVERSAL

- `vcx/code/store_authz_wave2_test.v` · `test_secret_hash_sha256_prefix_accepted` RENAMED `test_secret_hash_registry_prefix_accepted` · BEFORE/APPROVED pinned `svc_normalize_secret_hash('sha256:<h>')` **accepted** (strips to bare digest) → AFTER pins `'sha2-256:<h>'` accepted. **genuinely-new-value.**
- `vcx/code/store_authz_wave2_test.v` · `test_secret_hash_bad_forms_rejected` · **NEW assertion** (no BEFORE counterpart): `svc_normalize_secret_hash('sha256:<valid 64-hex>')` must now **reject** — the legacy spelling flips from pinned-accepted to pinned-rejected (ledger entry 19, one registry, no dual-accept). **genuinely-new-value — this is a behavioral contract reversal of a pre-epoch accepted form; the single highest-attention row in Part 2.**
- Same fn · rejection-input re-spells, semantics unchanged (short digest / non-hex still reject): `'sha256:deadbeef'` → `'sha2-256:deadbeef'`; `'sha256:'+64×'z'` → `'sha2-256:'+…`. **other** (input re-spell; the pinned outcome — reject — is unchanged).
- `vcx/code/store_service_test.v` · `test_config_static_token_sha256_prefix` · config input `secret-hash="sha256:<b×64>"` → `"sha2-256:…"`; the assertion itself (parses to the bare digest) is unchanged. **genuinely-new-value** for the accepted spelling (the pre-epoch spelling would now fail this test). Comment-only update in `test_config_parses_static_tokens` (bare-hex lane unchanged).
- `vcx/code/store_config_reload_test.v` · `cr_config` fixture · two `secret-hash="sha256:…"` seeds (root + worker tokens) → `sha2-256:` — fixture inputs, no assertion text changed. **other** (fixture re-spell required for the harness to keep passing under the registry spelling).

### 2c. Retired-surface re-spell

- `vcx/code/worker_cancel_test.v` · `test_check_cancel_observes_worker_cancel` · eval input `[takewhile …]` → `[take-while …]` (+ matching comment); assertion values unchanged (ledger entry 22 spelling). **other** (input re-spell only).

### 2d. New test file (context, not a re-pin)

- `vcx/code/store_csrp_wire_tagged_test.v` — ADDED whole (69 lines): round-trip, multicodec byte, bare-hex refusal, unknown-code refusal, blake3 reconstruction. No BEFORE/APPROVED exists. **genuinely-new-value** by construction; it pins the §3.2 wire re-form of 2e.

### 2e. Non-assertion changes riding the same commit (for the owner's completeness; outside this packet's per-assertion scope)

`vcx/code/store_csrp_wire.v` (the real wire defect fix: doc-frame re-formed to `[u16 hash_algo_code BE][digest32]`, fail-closed both directions), `vcx/cx/hash_registry.v`, `spec/03-approved/misc/cxstore-remote-protocol.md` §3.2 re-specification, `Makefile` (store_lazy_load joins CODE_SERIAL_RETRY), and citation/version-literal hygiene edits (retired-record references genericized) in four working specs. The §3.2 spec edit is already adjudicated separately in the audit (spec-edit-during-implementation class); it is listed here only so this packet's coverage of d8d638b7 is total.

---

## Summary

### Counts per classification

| Classification | aa2a24c2 (entry 35) | d8d638b7 (entry 36) | Total |
|---|---|---|---|
| restored-pre-epoch (output == pre-epoch BEFORE) | 20 (math×11, random×7, prof-013/014) | 0 | 20 |
| genuinely-new-value | 1 (math-116, added) | 12 hash-pin asserts + 2 hash conditions + 3 sha2-256 accepted-form pins (authz accepted, service config, incl. the NEW sha256:-rejection assert) + 1 new test file | 19 |
| other (input/fixture re-spell, pinned outcome unchanged) | 3 (prof-016/017/018) | 4 (2 authz bad-form re-spells counted as one row each, cr_config fixture, worker_cancel take-while) | 7 |

Notes on arithmetic: entry 35's "22 repaired" = the 20 output
restorations + prof-016/017 re-spells (prof-018 amended but uncounted);
entry 36's "12 stale 64-hex pins" = rows 1–12 of §2a exactly (the guard
and the list filter are conditions, not asserts).

### Explicit list: every case where AFTER ≠ BEFORE (pre-epoch) — needs owner attention

Corpus (aa2a24c2):

1. **math-116-transcendental-decimal-refuses** — added; no pre-epoch value exists. Pins CXER3002 (sqrt over decimal) deliberately, `gate=enforced`. The only Part-1 row whose blessed OUTPUT is not the pre-epoch value.
2. *(input-spelling caveat, all 23 amended cases)* — every amended case's AFTER **input** differs from its pre-epoch input (bare float literals → exponent form). Outputs: equal to BEFORE for the 20 restorations; unchanged across all three states for prof-016/017/018. If the owner's AFTER≠BEFORE bar is the whole case block rather than the blessed output, all 23 rows land here; on the blessed-output bar, none of the 23 do.

Code lane (d8d638b7) — **every row**; none restores a pre-epoch value (BEFORE == APPROVED throughout, epoch-untouched files):

3. The 12 §2a assert pins (bare-64-hex → `sha2-256:`-tagged/73) + the 2 adjacent hash conditions.
4. `test_secret_hash_registry_prefix_accepted` — accepted secret-hash spelling `sha256:` → `sha2-256:`.
5. **`test_secret_hash_bad_forms_rejected` — the legacy `sha256:` spelling flips from pre-epoch pinned-ACCEPTED to pinned-REJECTED** (the #188 dual-accept retirement, entry 19). Highest-attention row: a reversal of a previously pinned acceptance, not a widening.
6. `test_config_static_token_sha256_prefix` — the accepted config spelling moves to `sha2-256:` (pre-epoch spelling now fails).
7. `store_csrp_wire_tagged_test.v` — new pins for the re-formed §3.2 doc-frame (rides the store_csrp_wire.v defect fix + post-approval spec edit, adjudicated separately).

### What the owner is being asked to rule (per R2.1)

Whether these post-approval amendments are ratified as (i) legitimate
discharge of the approved epoch's own intent — the Part-1 restorations
put back exactly the pre-epoch values the approved diff degraded by
accident, probe-verified per entry 35 — and (ii) legitimate conformance
of an epoch-untouched white-box lane to the epoch's landed behavior
(Part 2); or whether any row (math-116; the sha256: rejection reversal;
the §3.2-riding pins) requires re-review under the re-bless procedure
before the I1 corpus is considered sealed.

---

## S5 reconciliation + re-verification addendum (2026-08-08; F6(b) one-pass ratification readiness)

**Packet status unchanged: prepared for owner review — NOT yet ruled.**
The F6(b) ruling folded this packet's sign-off into ONE ratification pass
over the corrected identity corpus, taken after the F2 spectrum rip-out
landed. S1–S4 (the CSRP demolition + the F1' identity re-derivation) are
complete and pushed, so that pass is now ready. This addendum records the
fresh independent re-verification and reconciles the packet against the
post-S4 tree.

### A. Fresh independent re-verification (this session, re-runnable)

1. **Commit-map anchors re-run verbatim — all four hold.** Anchor 1
   (`git diff ef80e409 aa2a24c2^` over the three corpus files) → empty.
   Anchor 2: `f294f9ec` blobs byte-identical to `ef80e409` for all three
   files (math `263b1964…`, prof `7de73c41…`, random `048d5d6a…`).
   Anchor 3 (`git diff 6f1e5cc8^ d8d638b7^` over the 11 Part-2 files) →
   empty. Anchor 4: every Part-1 degradation entered at `6f1e5cc8`
   (verified per-case, below).
2. **Per-case archaeology, mechanical:** all 24 Part-1 case blocks were
   re-extracted from the three states (`b04bd52c` / `f294f9ec` /
   `aa2a24c2`) and asserted against this packet's tables — **96/96
   checks pass**: the 20 restorations' out-sections byte-identical
   BEFORE==AFTER (asserted non-vacuously — empty extractions refuse);
   the 3 input-only re-spells output-stable across all three states;
   math-116 absent at BEFORE and APPROVED, present at AFTER with
   `gate=enforced`.
3. **Part-2 re-pins verified against `d8d638b7`'s actual diff:** all 12
   §2a assert re-pins + the 2 adjacent conditions; the §2b spelling
   flips including the `sha256:` accepted→REJECTED contract reversal
   (the diff shows the new rejection assert verbatim); the §2c
   `take-while` re-spell; the §2d 69-line new test file.
4. **Live re-derivation at HEAD:** every amended Part-1 case's `in-code`
   executed DIRECTLY through the HEAD `cx` binary (no harness) —
   **23/23 executable cases reproduce their blessed outputs exactly**
   (including prof-014's restored count `3` — the one silent-corruption
   reversal — and the deterministic random goldens, e.g.
   `1.683650517646569`); prof-018 is `gate=skip` in the corpus (CXER2103
   unreachable from pure CX, documented in-file), reported SKIP exactly
   as the harness treats it.
5. **Full executable-gate battery:** see §B below — the first S5 run
   surfaced a gate defect that invalidated its own green verdict; the
   battery was re-run after the fix. Result recorded at the end of §B.

### B. Two defects the S5 gate re-run surfaced (both fixed, commit `352619d5`)

- **Retry-classifier false green (gate hole, the exact class this
  campaign's audits exist to kill):** `test-vcx-suite`/`test-vcx-code`
  extracted the failed-lane retry roster by grepping the raw suite log;
  a lane whose failure dump contains NUL bytes turns the log binary and
  the (GNU) grep suppresses line output — the lane silently drops from
  the roster, the "every failed lane green on its classified retry"
  banner lies, and the gate exits 0. Observed live in the first S5
  battery: `fabric_nats_bridge` (the standing #572 `-usecache` flake)
  was retried and green, while `store_xsp_serve_test`'s RUNTIME failure
  was dropped (its assert dump carries raw frame bytes — the NULs).
  Fixed: `grep -a` on the roster extraction and compile-error probe,
  plus a LOUD extracted-vs-summary count crosscheck (mismatch ⇒ exit 1,
  never a partial roster). Red-on-synthetic proven under the devbox GNU
  grep: old extraction 0/2 lanes ("binary file matches"), crosscheck
  REFUSES (want=2 have=0); new extraction 2/2, proceeds.
- **R3.4 origin-fold lane pinned stronger than its contract:** the
  `test_store_xsp_peer` origin lane asserted an INSTANT present-time
  CXER5021 refusal after the revoke event was observed, but the local
  fold rides the liveness sweeper tick and the profile's §7.1 contract
  is explicitly bounded (`[convergence feed-lag-ms=250
  enforcement="next-pep-check"]`). Diagnosed with timestamped
  pump/fold/present instrumentation (reverted): failing runs show
  `present revoked_len=0` with no fold yet; the green run shows the
  fold landing ~150ms after the pump, then the refusal. The lane was
  nondeterministic by exactly the tick phase (~2/6 green), explaining
  both its historical greens and this session's reds. Re-pinned as
  poll-until-refusal within a 2s deadline (8× the spec'd bound) — the
  actual contract property; 5/5 green after the fix. **The product
  conforms to its spec; no product behavior changed** (one stale
  "post-dispatch" comment conformed to reality).

Neither defect touches the epoch corpus or any Part-1/Part-2 value;
they are disclosed because the ratification's gate-evidence chain runs
through them.

**Battery result (the re-run at `352619d5`): full `make test` rc=0.**
All TEST_TARGETS green; the ONLY failed lane was the standing #572
`-usecache` compile-artifact flake (fabric_nats_bridge, R=0.000ms —
compile class), green on its sanctioned cache-free retry under the
FIXED classifier with the count crosscheck live (summary=1 failed,
extracted=1, retried=1). `store_xsp_serve_test` green in-battery.
Extraction gate: 1564 Ring-0 cases through BOTH libcx.dylib and
libcx-core.dylib (floor 1564), ABI transcripts byte-identical
(4500316 bytes); CLI lane 8978 invocation pairs byte-identical + 17
profile refusals verified. libcx-abi-gate: 713 symbols, I3 baseline.

### C. Part-1 subjects at HEAD

- `math.cxd`, `random.cxd`: byte-identical to AFTER (`aa2a24c2`) — no
  amendment since this packet's commit.
- `prof.cxd`: ONE later amendment, `e140357d` (RULED: R3.12, the
  thrown-error auto-pass remediation): four input-only map-literal
  re-spells (`{k="v"}` → `{k: "v"}`) in prof-004-time-fn-opts-cpu-cap-denied,
  prof-006-trace-cap-denied, prof-023-prof-configure-bad-sink,
  prof-025-trace-flush-file-unwritable — cap-denied/refusal cases
  DISJOINT from this packet's five prof subjects; every blessed output
  unchanged (this packet's "other" class).

### D. Part-2 subjects at HEAD (the S3 CSRP demolition, RULED R4.4-a+G1a+G2a+G3a)

The R2.1 question — were the post-approval amendments legitimate AT THE
TIME — is unchanged by later retirement. This table keeps the record
honest about what still exists at HEAD (the I3 module move `f037364c`
relocated `vcx/code/` tests to `vcx/platform/` in between; dispositions
are against final paths):

| Packet rows | Subject file | At HEAD |
|---|---|---|
| §2a 1–2 | store_binary_wire_test.v | DELETED at `abaea9b9` (CSRP binary wire retired) |
| §2a 3 | store_csrp_conformance_test.v | DELETED at `abaea9b9` |
| §2a 4–5 + guard | store_grpc_concurrency_test.v | survives (vcx/platform/), pins live |
| §2a 6 | store_grpc_e2e_test.v | survives, pin live |
| §2a 7 | store_grpc_live_test.v | survives, pin live |
| §2a 8–9 + filter | store_grpc_parity_test.v | DELETED at `abaea9b9` (CSRP-vs-gRPC parity moot with CSRP) |
| §2a 10–12 | store_grpc_serve_test.v | survives, pins live |
| §2b authz rows (incl. the reversal) | store_authz_wave2_test.v | DELETED at `abaea9b9` with store_authz.v (bearer/RBAC + svc_normalize_secret_hash retired) |
| §2b service config pin | store_service_test.v | survives; bearer lanes retired at S3, replaced by the INVERSE pins (`[auth …]` = hard config error G2a; advert carries no `[auth]`) |
| §2b cr_config seeds | store_config_reload_test.v | survives; auth seeds dropped with the G2a config |
| §2c | worker_cancel_test.v | survives (vcx/code/), take-while pin live |
| §2d | store_csrp_wire_tagged_test.v | DELETED at `abaea9b9` with the CSRP wire codec |
| §2e | store_csrp_wire.v / §3.2 | codec DELETED at `abaea9b9`; cxstore-remote-protocol.md → RETIRED/historical at `6f10e7e7` |

### E. The F6(b) fold — everything else the one-pass ratification covers

Complete enumeration of conformance-corpus change since the approved
seal (`f294f9ec` → HEAD), beyond this packet's two commits. Every item
landed under a recorded ruling or phase gate; `d8d638b7` (Part 2)
touched no conformance path.

Pre-I5 phase work (each rode its phase's exit gate; I1–I4 exits ratified
— R2.2/R2.3): `cdac43aa` (I1 L48 binding parity, binding_api.cxd),
`daf3f921` (I2 exit harness, conversions.cxd + module-fixture removals),
`a648ba17` (I2 front door), `0d9617d2` (I3 fmt/did/vc.cxd ADDED),
`0e4e8e96` (I3 http seam), `85166d66` (I4 ring-tag case ATTRS — the 31
mis-tags; metadata-only per the I4 precedent, R0 corpus untouched).

I5-stream-4 waves (each green on its wave gate; W2's xsp-auth amendments
adjudicated R1.2): `25d7c775` (W2 xsp-auth.cxd — cases 008/014 gain
well-formed offer fields, 025–031 added), `882d1b61`/`91836dbd`/
`ab57a9b0` (W3–W5 xsp.cxd), `46c3b64e` (W4 authz.cxd), `72909cdf` (W4
store-log-002/003 added).

Remediation: `e140357d` (R3.12 — five error-identity out-err
conformances + twelve input fixture repairs across code/ft/prof/sched/
session/test/validate; ruled, R4.3-re-audited).

**The corrected identity corpus (the F1'/A-series correction itself):**
- `store-code-001..010`: ids and pinned truth values KEPT; bodies
  re-expressed off the retired put-def/get-def surface onto put-blob +
  the pure `[$cx:computation-id]` claim (001 re-derived on the
  string-literal-body representative that MANGLES through the
  structured path — the evidence-first case). RULED: F1'+A2
  (`c42e8b15`/`ab463c35`, after the `1b4fd26b`→`67f0dcdb` revert pair
  from the corrected premise).
- `store-blob-001..008` ADDED: the byte-exact opaque surface
  (round-trip, no-canonicalization, dedup, absent) + the identity-rule
  separation pins (structured-read refuses, iter/query walk structured
  only, delete-then-reput, modify refuses). RULED: F1' (`a3e6588b`).
- `store-029-csrp-handle-cap-denied` DELETED with the csrp-handle verb;
  `store-022-open-csrp-cap-denied` → `store-022-open-service-cap-denied`
  (S3/S4, RULED: R4.4-a; `abaea9b9`/`6f10e7e7`); gates.cxd prose
  conformed (`7b328e7a`/`6f10e7e7`).
- V-battery pins riding the same correction: legacy `C`-record LOUD
  refusal (store_legacy_code_refusal_test.v, both persisted formats)
  and the xap-dist `computes-as:` claim recomputed via the pure
  relation (xap_dist_exports_identity_test.v). RULED: A3+A4.

### F. What the owner is asked to rule (the one pass, per F6(b))

Whether to RATIFY, in one pass: (i) this packet's two amendment commits
as legitimate discharge of the approved epoch's intent (Part 1) and
legitimate post-approval conformance of the epoch-untouched code lane
(Part 2) — every value now four-ways verified (archaeology anchors,
per-case extraction asserts, the actual diffs, live re-derivation at
HEAD); and (ii) the corrected identity corpus as enumerated in §E —
every item landed under its recorded ruling, with the F1'/A-series
correction evidence-first throughout. Ratification seals the I1 epoch
corpus as amended and unblocks S6 (pushdown) per the campaign sequence.
