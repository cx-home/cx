# Remediation register — adversarial audit I0–I5 (companion to partition_audit_impl_I0_I5.md)

**Rules of this register.**
1. Every finding F-1..F-30 has exactly one row. No row closes without
   (a) an express owner ruling where the row poses a question, (b) the
   acceptance criterion met, and (c) independent adversarial
   re-verification recorded in the Evidence column (a fresh agent pass
   or a named gate — never the implementer's own claim).
2. Spec-text changes required by a row happen ONLY under the row's
   recorded ruling (the no-spec-edits-during-implementation rule stands;
   a ruling recorded here IS the express authorization for that row's
   named edit and nothing else).
3. Default posture where spec and implementation disagree: **make the
   implementation true to the spec.** A row proposing the opposite says
   so explicitly and why.
4. Remediation work follows fixture-before-fix. Nothing outside this
   register lands until the register closes and the owner rules on
   resumption (R-final).
5. Rulings are recorded in this file (RULED: <letter> <date>) BEFORE the
   work of that row begins.

**Status legend:** OPEN-Q (awaiting owner ruling) · AUTH-PENDING (batch
authorization question pending) · IN-WORK · VERIFYING · CLOSED.

## Rulings log (authoritative; a row's Status defers to this log)

**2026-08-07, owner:**
- R1.1 **(b)** — full pushdown in stream 4 ("was never a question").
- R1.2 **(a)** · R1.3 **(a)** · R1.4 **(a)** · R1.5 **(a)** — the four
  carriage/scheme/erasure adjudications: shipped text stands AS RULED
  TEXT with the probe evidence cited; ledger adjudication entries to be
  recorded under these rulings.
- R1.6 — owner challenged scope ("why do anything with CSRP — it's
  being ripped out?"); resolved 2026-08-07: the 0x01/0x02 doc-frames
  live in the CSRP wire codec + cxstore-remote-protocol.md §3.2, BOTH
  scheduled for deletion/archival at the W7 retirement. Row collapses
  to the record only: F-6 stays classified UNAUTHORIZED (concurrent
  self-authorization) in the audit; no content adjudication (moot at
  retirement); the fix stays in place interim (unwinding a
  scheduled-for-deletion artifact re-breaks binding clients for
  nothing). No spec/code action.
- R2.1 **(a)** — packet + independent scoped re-verification of the
  amended epoch families; sign-off rests on both.
- R2.2 **(a)** — I4 exit ratified + tracker issue + BLOCKING per-profile
  install-verification step in the release-cut process.
- R2.3 **(a)** — minor process-breach class acknowledged, no unwind;
  structural remedy = R4.1 + R4.2.
- R2.4 **(a)** — stream-20 routing confirmed + interim fail-loud guard
  R3.16.
- R2.5 **(a)** — G13 fixture families = W7 scope over the COMPLETE
  post-pushdown surface; §9/ledger overclaim corrected under this
  ruling; W5 exit conditional.
- R4.1 **(a)** — mechanical spec-freeze gate authorized.
- R4.5 **(a)** — push authorized (ruled 2026-08-07 second round).
- Part 3 batch **(a)** — all sixteen work rows (R3.1–R3.16) authorized
  for execution (ruled 2026-08-07 second round); each row still closes
  individually on its acceptance criterion + independent verification.

## Execution evidence log (rows move CLOSED only after the R4.3 pass re-verifies)

**2026-08-07:**
- R3.7 VERIFYING — cxer-registry-gate in TEST_TARGETS (commit 7af29685);
  green on tree, RED on synthetic unregistered CXER9871, green after
  removal.
- R3.9 VERIFYING — CX_BLESS=epoch disarmed (ce2bfc1e); verified three
  ways: disarmed+env rc=1 loud refusal, disarmed-no-env rc=0, armed
  (-d cx_epoch_bless)+env bless lane active.
- R3.13 VERIFYING — three dated corrections landed in place (commit
  after ce2bfc1e): I3 census 79, I2 proof-claim retracted, W5
  "standing" label corrected.
- R2.2 gate landed (f5cd18c3): blocking per-profile install
  verification in release.sh (platform/data/embed/cli extract +
  'profile  <name>' probe); published-asset end-to-end = issue #741;
  row closes at the next cut with the tag named.
- R4.1 VERIFYING — spec-freeze-gate (70f90258): TEST_TARGETS range
  mode (f964c16a..HEAD) + .githooks/pre-commit --staged; verified:
  range clean, --check-commit d7ca927b RED, impl-only green, staged
  synthetic mixed RED then green under CX_RULED.
- R2.1 re-verification lane GREEN (independent agent, build
  7af29685): all 24 aa2a24c2 enforced cases PASS by direct execution
  AND through the battery lane; all 12 d8d638b7 re-pinned V test files
  OK first-try. Noted: prof-018 is skip-gated pre-existing
  (CXER2103 unreachable from pure CX, documented in-file).
- R2.1 review packet DELIVERED —
  partition_epoch_amendment_packet.md (uncommitted, awaiting owner
  review): 20 restored-pre-epoch (byte-exact incl. the prof-014
  3→0→3 corruption reversal), 19 genuinely-new (epoch-tracking pins),
  7 input-re-spells. Owner-attention rows: the deliberate sha256:
  accepted→REJECTED contract reversal (#188 no-dual-accept flip) and
  the added math-116 pin. Awaiting owner sign-off per R2.1(a).
- R3.1 VERIFYING (26326815) — M3 wrong-carriage presentation now
  refuses CXER5021. Fixture-before-fix: serve lane G landed first,
  FAILED live (frame type 3, state=attached — audit F-20 confirmed
  behaving-wrong), green after sx_m3_vp_present + the refusal arm;
  full xsp serve battery OK.
- R3.8 VERIFYING — extraction-gate F-15 repairs, all three limbs:
  (1) case-count floor: probe + CLI gate take --min-cases; the Make
  recipe passes EXTRACTION_GATE_FLOOR=1564; vacuous pass DEMONSTRATED
  LIVE first (empty corpus → 1-byte transcripts → cmp rc=0), floor
  refusal verified red (rc=1, empty corpus at floor 1564). (2) the
  3 uncovered cases now compared through the ABI lane: ch-005 synth
  lane (deterministic table synthesis mirroring the conformance
  runner's HH3 rule; chunked encode + reader pass recorded as digests
  — groups=2 at the 2^20 boundary in-transcript), cmp-005 fd lane
  (col-spec + row-group via the in-memory reader, 101 groups through
  cx_table_writer_open_fd, file digest + fd read-back group count),
  sd-006 schema-pair lane (cx_hash on both schema texts + computed
  equality — the schema content hash IS the Tier-1 canonical hash);
  transcripts BYTE-IDENTICAL monolith vs core (4500316 bytes, 1564
  cases). (3) the 5 md ABI-lane exclusions: now MECHANICAL — a
  zero-record Ring-0 case must carry in_md (no md surface exists in
  the C ABI; CLI lane covers via --from=md) or the probe hard-fails
  listing it; red verified on a synthetic uncovered case.
- R3.8 DISCOVERY → #742 (bug/area:v-runtime/prio:high) — routing
  ch-005's 1M-row case through the ABI exposed that SHARED-LIBRARY
  builds ran with the vgc collector DISABLED (V emitted vgc_init()
  only in generated main() paths): unbounded embedder heap growth,
  ~75x slower large ABI parses (20k-row parse 15.0s dylib vs 0.19s
  binary), and — once enabled — a second latent defect
  (vgc_data_segments scanned only image 0, so V __globals in the
  dylib's own data segment were reclaimed → rand__deinit UAF at
  exit). Fixed in the V fork (cgen _vinit_caller/_vno_main_init_caller
  emit vgc_init; vgc_platform.h scans main image + the vgc-carrying
  image via dladdr marker). New abi-gc-gate in TEST_TARGETS pins the
  class: red before (no gc cycles; then rc=139 exit UAF), green after
  on BOTH artifacts (16 cycles each, clean exit). 20k-row dylib parse
  now 92ms. The v0.15.0 release artifacts carry the defect (genuine historical reference — version-literal-ok); #742 tracks
  the release-side verification. Fix class = V-runtime mem-mgmt
  (standing: V-only, upstreamable); no cx spec text touched.

---

- R3.2 VERIFYING — CXER5013/5016 wire lanes + a decoder crash fix the
  lane surfaced. New test_store_xsp_mount_and_body_faults: 5013 on a
  tenant-less M3 against a MULTI-mount daemon (ambiguous) and on a
  [tenant] naming an unmounted store, with a named-mount positive
  control; 5016 on a bodyless [put] and on a [body::bytes 0x…] whose
  bytes are not decodable ast_bin; a valid put after both refusals
  proves per-request fault isolation (sxt_boot_xsp gained a `stores`
  param for the multi-mount daemon). FIXTURE-BEFORE-FIX surfaced a
  REAL DEFECT: the 0xdeadbeef body (size 0xefbeadde, high bit set)
  CRASHED the daemon thread — bin_to_doc/node_from_bin compared
  `4 + int(size)` in signed 32-bit space, so a size ≥ 2^31 wrapped
  negative, slipped the bounds guard, and panicked in the payload
  slice: a hostile/corrupt framed body took the process down instead
  of surfacing CXER5016. First serve-test run FAILED (V panic: no
  reply on stream 32); fixed both header guards to u64 comparison,
  green after. Added test_ast_bin_rejects_high_bit_size_no_panic
  (unit-level, both entry points) so the crash class is pinned
  independent of the daemon. This is a decode-hardening fix on ABI /
  store entry points broadly, not just the xsp path — implementation
  conforms to the spec's loud-refusal contract (register rule 3); no
  spec text touched. CXER5015 internal-fault: NOT wire-constructible
  without mocks — every store-op failure reachable from a well-formed
  request surfaces as an err VALUE relayed verbatim (the 5015 arms
  catch V-level errors from store_stdlib_builtin_inner that a valid
  request cannot induce); recorded as an intentional coverage
  boundary per the R3.2 row's "if constructible" clause.

- R3.3 VERIFYING — authority presentation-fault lanes, all five over a
  real booted daemon through the profile listener
  (test_store_xsp_authority_presentation_faults): (1) floor session
  presents a well-formed vp → CXER5021 (§5.1 no principal to bind);
  (2) post-attach [vp] carrying no [vc] → CXER5021 (post-attach sibling
  of the R3.1 M3-carriage refusal); (3) chain rooted at an UNRECOGNIZED
  did → [presented compiled=0 inert=1] AND the session survives (a
  following verb still enforces PEP CXER4700, connection not torn) —
  decoded the data-bin reply to assert the attrs (compiled=0 inert=1),
  not a substring hack; (4) [tenant other] delegation → CXER4805
  (§5.3 fault, never inert); (5) [attenuates <parent-not-held>] →
  CXER4703 (§5.2 four-axis attenuation). Lanes are non-vacuous:
  first runs FAILED on the inert reply shape (data-bin, not text
  compiled=0) and on the survival probe (status needs admin) before
  the asserts were corrected to the true wire behavior — each lane
  demonstrably reaches the daemon and reads a real response. No code
  change: the behaviors were already spec-correct, only wire-unguarded
  (register rule 3 coverage row). Added sx_present_frame_vp (vp
  expression under test control) + sx_decode_reply (decode a binary
  reply's payload child to canonical for attr asserts). Note recorded:
  CXER4805 is registered to session.md's 4800–4849 band
  (E_SESSION_REBIND_REFUSED); the xsp cross-tenant fault reuses it by
  "CXER4805 semantics" — spec-explicit (xap_identity_model.md §, 
  xsp_store_profile.md §5.3), confirmed not a registry band-overlap by
  the cxer-registry-gate.

- R3.4 VERIFYING — the nine code-verified-but-regression-unguarded
  behaviors (audit F-26), each now pinned:
  (1) revocations-cursor resume — new peer-test lane: a fresh peer sub
  from pos=0 replays the durable pos=1 revoke (the peer worker's own
  resume path, on the wire). (2) feeds-die-with-connection — new
  wire-regression lane: a tail sub dropped WITHOUT a cancel is reaped
  on connection close and the daemon keeps serving (a fresh session
  gets its live insert). (3) deleted-replay body-absence — STRENGTHENED
  the existing resume assert: the retract under a bodies=true sub
  carries no [body::bytes]. (4) alias-retract shape — pinned IN-PROCESS
  (store_xsp_alias_retract_test.v): aliases-delete is not a wire verb,
  so a local delete → the §5.3 formatter renders
  [retract plane="aliases" name=… pos=…], distinct from advance;
  no-op delete appends no act. (5) open-posture CXER5022 — new lane: a
  pure-floor daemon (no grants) refuses a revocations feed with the
  peer-token code regardless of posture. (6) PEP-before-token-gate
  ordering — new peer-test lane: a session UNDER the enforcing posture
  lacking the peer cap is denied by the PEP (CXER4700), NOT the token
  gate (CXER5022); with the cap-holder/token-lacker lane (→5022) this
  pins PEP-first. (7) peer wrong-DID pin — new two-daemon test
  (test_store_xsp_peer_wrong_did_pin): B pins the WRONG did for origin
  A; B logs the pin refusal naming A's real identity vs the wrong pin
  and never folds — an impostor origin can inject no revocations
  surface. (8) origin-folds-own-journal — new peer-test lane: a fresh
  A-LOCAL session presenting the revoked credential is refused AT the
  origin (CXER5021 revoked), so A enforces its own journal, not only
  relays it. (9) rate retry-after ON THE XSP WIRE — new lane: a
  presented [bounds [rate 1 :per "1h"]] exhausts after one read →
  CXER4713 + retry-after (the profile-wire shape; the HTTP-429
  Retry-After stays covered by store_wire_wave4_test). Non-vacuous:
  several asserts failed on first run against the true wire shapes
  (data-bin reply, admin-gated status, out-of-scope hash5) before
  correction; the wrong-DID negative was rewritten from a
  non-existent-string check to naming both dids. No production code
  changed (behaviors were spec-correct, only unguarded); one V-test
  helper file added.

- R3.5 VERIFYING — feed shape-acceptance quirks (audit F-21), all
  three, fixture-before-fix. §5.2 fixes [planes …] as ONE
  space-separated scalar and CXER5019 already covers "malformed feed
  subscribe", so the spec is NOT silent — no letter needed; register
  rule 3 + no-dual-accept determine the answer. (1) multi-scalar
  [planes "docs" "refs"] silently kept the last scalar → now refuses
  CXER5019 (n_scalars > 1 guard); the single-scalar control still
  honored; test RED first ([feed-sub] returned), green after. (2)
  name= on a revocations cursor was accepted-and-ignored → now refuses
  CXER5019 (the revocations plane is a single stream; name= is a
  refs/aliases-only concept); test RED first, green after. (3) the
  stale serve.v comment claiming the PEP maps an UNKNOWN verb to
  `admin` corrected — unknown verbs are not in sx_verbs, so they skip
  the PEP block and refuse by name (CXER5012). Impl conformed to spec
  (register rule 3); no spec text changed.

- R3.6 VERIFYING — F3 direct advert push (audit F-22) MADE THE SPEC
  TRUE (register rule 3; never trued the spec down). §7a.1 mandates
  the reload verb pushes the advert directly AND the sweeper watches
  for other-listener reloads; only the sweeper was implemented. Added
  sx_readvertise_locked(mut srv) to the config-reload verb handler
  after the reply. Fixture-before-fix with a NON-TIMING discriminator:
  the direct push enqueues the advert inside the reload handler, so a
  ping sent right after the reload reply pongs AFTER the advert; a
  sweeper-only impl pongs FIRST. Test RED first (got ftype=6 pong on
  stream 201 before any advert), green after (advert stream-0
  generation=1, then the pong). sx_readvertise_locked is idempotent on
  srv.last_gen, so the direct push consumes the generation move and
  the sweeper no-ops — no double advert; the sweeper code is untouched
  and still covers CSRP/gRPC-listener reloads (existing F3 test still
  green).

- R3.10 VERIFYING — ring-gate C-edge widening (audit F-17). Rewrote
  scripts/ring_import_gate.sh: hits_sibling now catches EVERY spelling
  of a sibling reference — @VMODROOT/<sib>, @VMODROOT/../vcx/<sib>,
  relative ../<sib>, and ../../vcx/<sib> — and the scan now covers raw
  .c/.h sources (not just .v), closing the 3 audit probe bypasses. The
  regex_re2.v allowlist is narrowed from whole-sibling-dir to the exact
  edge PATHS (deps/re2_shim, target); arrow's own shim edge
  (target/libcx_arrow_shim.a) is the one added exact edge. New lanes:
  arrow + transport leaves (import cx only), and the platform-FREE
  cli/cmd_data lanes (no Ring-2 import — the data/cli profiles must not
  pull the daemon stack, §4). New scripts/ring_import_gate_selftest.sh
  proves RED on all 9 violation classes (the 3 bypasses + import edge +
  narrowed-allowlist + arrow-leaf + cli + cmd_data + code→platform),
  green on the clean tree; wired into ring-import-gate in TEST_TARGETS.
  Perf: the naive per-line×per-sibling×4-grep loop was 15.5s; a
  single fast-path grep per line (detailed check only on a hit) brought
  it to ~4.3s. Gate + selftest both green via `make ring-import-gate`.

- R3.12 VERIFYING — thrown-error auto-pass closed in ALL affected
  lanes (audit F-19, the inherited #404–#407 class), and the
  discriminator surfaced 23 LATENT FALSE-GREENS, every one triaged
  fixture-or-code:
  · The fix: thrown_matches_out_err — a thrown parse/eval error
  satisfies an out-err case only when its message carries the expected
  CXER code; wired into the 3 code_eval_fixtures_test.v lanes AND
  profile_gate.v (unit-pinned by
  test_r312_thrown_error_must_match_out_err; the pkg lane's parse arm
  was already strict; conformance_run.v already matched).
  cmodule_gate no longer discarded (per-module tier honored in the
  profile gate's code.cxd lane). Full battery + profile gate (cli AND
  embed) + gates-manifest + ring-tag gates GREEN after triage.
  · FIXTURE defects repaired (12): 8 map-syntax cases that never
  parsed ({k=v} / {"k" v} → the canonical {k: v}; ft-007/009/010/013,
  prof-004(+named opts per §12.2.4)/006/023/025); sched-033 surplus
  bracket; session-037 surplus bracket; test-003 $label= → label=;
  validate-023 [?io: → [$io: + the def declared impure so the §3.6
  gate (not the D11 def-checker) is what refuses.
  · IMPL conformed to spec'd error identities (register rule 3; each
  spec cite verified): [?map]/[?reduce] using-not-closure CXER0001 →
  CXER0106 (E_USING_NOT_CLOSURE, code.md registry); pfa hole-in-rest
  CXER0261 → CXER0102 and over-application CXER0001 → CXER0102
  (E_PARTIAL_APP §6.3a; 0261 was a mis-assignment into the
  cancellation band, used nowhere else); [?lib] parse-shape failures
  CXER0210 → CXER0212 (E_LIB_MALFORMED_DIRECTIVE) with the
  CXLIB_INSECURE_TRANSPORT parse class mapped to its spec'd CXER0208
  (the lib_parser-documented surface mapping, made true); unbound
  $_position/$_last outside a predicate CXER0001 → CXER0231
  (E_RESERVED_BINDING_USE).
  · NEW spec conformance implemented: validate.md §3.6 "validate-with
  MUST carry pure" — probed live: an impure-declared validator was
  ACCEPTED ([ok …]) and its side effects would run; added
  declared_impure to Closure (set from the [?def] purity annotation)
  and a pre-invocation CXER1603 refusal in validate-shape.
  · Lane-membership fix: sched-033 needs journal (Ring-2) — tagged
  ring=2 matching its durable siblings sched-022/023 (standalone the
  refusal is correct; in the ring≤1 cli composition journal is absent
  and durable: <err> degraded silently — the gate now skips it there).
  · Reachability records: validate-025 (CXER1605 validator depth >64)
  is UNREACHABLE from literal input — the PARSER caps element nesting
  at 64 first — skip-gated with the analysis in-file (the prof-018
  pattern). module-subpath-private's out-err corrected 0216 → 0213
  (its own tags said 0213; an unregistered subpath is an unknown
  module — 0216 is post-resolution privacy, now genuinely covered by
  program-def-visibility-private-unreachable REWORKED onto the
  registered ./mixed-module.cx priv-c member).
  · OWNER-ATTENTION (deferred-feature fixtures → gate=pending):
  module-https-fetch-sri-mismatch-CXER0209,
  module-https-fetch-unpinned-CXER0211,
  module-lockfile-integrity-mismatch-CXER0209 test the Phase-2.14
  HTTPS-fetch/SRI/lockfile-integrity surfaces whose emit-sites do NOT
  exist (module_loader returns fetch-deferred CXER0210; recorded
  pre-campaign). Marked gate=pending (never silent green). Options:
  (a) pending until the Phase-2.14 graft lands — recommended;
  (b) build the fetch/SRI surface now (out of R3.12 scope);
  (c) delete the fixtures (loses the spec-first worklist).

- R3.16 VERIFYING — interim erasure-carriage guard (rides R2.4(a)),
  fixture-before-fix. RED first, proving the audit's concern LIVE:
  store-migrate of a tombstone-bearing source returned
  [migration-report doc-count=1 …] and store-clone [clone-result …] —
  both silently DROPPED the E-record tombstones (lawful-erasure
  attribution lost at the destination; a re-put of shredded content at
  the copy would resurrect it with no record). New
  store_erasure_transfer_guard in both verbs: a source with
  src.erased.len > 0 refuses CXER1144
  E_STORE_ERASURE_CARRIAGE_UNSUPPORTED — the FIRST code of the
  1144–1149 store band RESERVED for the erasure/compliance surface
  (governance §9.6 store row; stream 20 owns the band and removes the
  guard when erased-map carriage lands — the guard comment names the
  symbol for stream 20's removal). Tombstone-free control migrate
  still succeeds; erase + porcelain batteries and the cxer-registry
  gate green.

- R3.14 VERIFYING — the three F-30 cosmetic spec/impl deltas conformed
  (register rule 3, impl → spec; no spec text touched):
  (1) [erase-result] extra request= attr DROPPED — the spec shape is
  hash= erased= deduped=? only; the request attribution rides the
  tombstone (get answers it) and the §5.3 feed act (both still
  asserted); the serve-test pin now asserts !contains('request=').
  (2) capabilities restates the advert's generation as the ATTR
  (generation=N on the [capabilities] root), the advert's own
  spelling — the former [generation N] child element is GONE (cutover,
  no dual shape); pin updated to assert the attr AND the child's
  absence. (3) G8 group-from refusal: NOT moved to the corpus — a
  dated correction in ledger entry 4 records why (the refusal is a
  live-listener, socket-bound behavior; xsp.cxd covers the
  codec/calculus-expressible G8 items; faking an in-process case for a
  wire behavior would be worse than the phrasing it fixes; the live
  pin at fabric_serve_test.v:1038 stays authoritative). Full xsp serve
  battery green after the conformances; no other lane emits either
  shape (grep-verified across profile_ops/client/service/csrp).

- R3.11 VERIFYING — the FULL graded corpus now runs through the
  PROFILE BINARIES (audit F-18): profile_gate's --bin drives every
  binary-expressible eval case through the real `cx <file>` run
  surface — program → tmp file, in-cx doc → --data=FILE (code.md
  §1.3), grants → --allow-<cap> / --allow-all / deny-by-default for
  CXER0271 cases. Counts: 2804 cases through the cli binary + 2226
  through embed; 16 binary-INEXPRESSIBLE cases counted AND reported in
  the gate line, never silent (test-registry modules like
  ./local-helpers.cx / github.com/example/* exist only in the
  in-process #701 registry; 3 strict-mode cases — no --strict run
  flag); 2 §1.3 data-fallback answers (a parse-error fixture whose
  in-code IS valid data legitimately echoes as data on the bare run
  surface — verified against the actual data conversion, and the
  parse-error expectation stays graded in-process). Comparator honors
  the documented #16 multi-form rendering (the run surface prints
  every top-level result; the fixture pins the final value → tail-line
  match, with the in-process lane still pinning the exact result).
  RUNTIME MEASURED: 4m28s for BOTH compositions including builds —
  affordable for TEST_TARGETS, so the full corpus stays in the gate
  (no letter needed). Red-on-synthetic: the lane against the
  data-profile binary fails rc=1 (thousands of [bin] failures + the
  refusal probes). THE LANE CAUGHT A REAL BINARY-SURFACE DEFECT on
  first run: a top-level [$unfold f seed] realized in-process but
  errored through `cx <file>` — eval_top_level_each (the #16
  multi-form path) lacked eval()'s generator finalize; conformed
  (realize_unfold / the infinite-iterate refusal now applied per
  top-level value position). code_eval battery green after.

- R3.15 VERIFYING — the two external-repo claims the auditor could
  not reach, now verified against the current remediation build
  (vcx/target/cx):
  · xap-store-console conform (tools/conform.sh, CX=<this build>):
  19 of 124 red — EXACTLY the recorded set (xap-store-console#6),
  same classes (static-daemon bearer 401 round-trip, fail-closed
  add-credential asserts, readout shapes); the §13b store-PROFILE
  data-plane lane (the W6 migration claim) is GREEN. No NEW failure
  from the remediation — the 19 are the console's own 0.13→0.15 idiom
  drift, already tracked.
  · xap-marine-htmx-web-client: `make validate` GREEN (client spec ⊢
  schema); the /3 handshake claim verified — the client's M1 builds
  [offer-profiles xap] INSIDE the signed hello transcript under the
  current toolchain (the calculus surface names shifted to
  challenge/confirm; the hand-rolled full 4-message replay needs the
  responder nonce, so the shipped in-process W6 proof stands). The
  cross-repo drift gate (`make check`) has 6 reds — feature-map +
  one nmea alias-prefix — ORTHOGONAL to /3 (commit 669f823 touched
  only tools/xap-auth.cx) and to the remediation; FILED as
  xap-marine-htmx-web-client#15. Both external claims hold; nothing
  the remediation touched regressed either repo.

- R2.5 VERIFYING — the W5 wave-gate overclaim corrected under the
  recorded ruling R2.5(a). Two edits, both carrying RULED: R2.5:
  (1) xsp_store_profile.md §9 heading "G8 + G13 discharged" → "G8
  discharged at W3; G13 scoped to the W7 parity gate", with the §9
  body + §10 letter-172 note rewritten to say the G13 fixture families
  are the W7 deliverable (built ONCE over the complete post-pushdown
  surface, R1.1(b)), NOT discharged at W5 — what W5 delivered is the
  revocation-convergence pair (test_store_xsp_peer), a live-socket
  behavior that never was a G13 corpus fixture. (2) the ledger W5
  done-when cell corrected from "G13 families green" to
  "revocation-convergence pair green", with a dated correction note;
  W5 exit stands CONDITIONAL on W7. The spec edit is authorized by
  R2.5(a) (rulings-before-edits) and rides a spec-ONLY commit, so the
  spec-freeze gate (which fires only on spec+impl together) does not
  trigger; the RULED: R2.5 token is carried regardless.

- WAVE-GATE NOTE (2026-08-08, full `make test` runs toward R4.3):
  three defects surfaced BY the wave runs, all triaged:
  (1) the R3.10 selftest raced parallel make (its synthetic probe
  files in the live vcx/cx were compiled by concurrent build jobs,
  failing cli-data-dev) — fixed: the selftest now probes an ISOLATED
  fake tree via RING_GATE_ROOT, live tree kept read-only; all 9
  classes still red-on-synthetic. (2) the R3.12 corpus repairs
  orphaned two co-located stdlib fn-doc examples quoting the OLD
  broken idioms (guide-check enforces example↔corpus backing) — docs
  aligned; guide-check green (45 modules). (3) DISCOVERY → **#743**
  (bug/area:v-runtime/prio:high): vgc's STW suspend signal is SIGURG —
  the Go runtime's preemption signal — so a Go host that dlopens a
  -gc e libcx can hang the collector's (deliberately unbounded)
  ack-wait when a collection triggers mid-run; reachable only since
  #742 enabled the dylib collector; observed flakily (1 of 3 full
  runs, the test-go lane). Fix directions (signal change / darwin
  mach-suspend path / build-time knob) + the documented interim
  (VGC_NEXT_GC_MB pin on the go lane if it recurs as a blocker) are
  in the issue; NOT improvised here — the STW machinery is
  soundness-proven and changes need the vgc battery re-run.
  Prose-gate hygiene from the same runs: version-literal-ok marker on
  the #742 historical note; the epoch packet's retired-record word
  genericized.

- R4.3 IN PROGRESS — wave-gate half MET: full `make test` rc=0 at
  9fb13cf3 (2026-08-08), zero 0x0acd hang spew; the single FAIL
  (fabric_nats_bridge, R=0.000ms) is the standing -usecache
  compile-artifact lane, green on its #572 cache-free retry ("every
  failed lane green on its classified retry"). The independent
  fresh-agent re-verification pass (agents that did NOT do the
  remediation) runs next over every VERIFYING row's evidence; rows
  move CLOSED only as that pass confirms each.

## Part 1 — Unauthorized spec edits: re-adjudication rows

These are NOT rubber-stamp ratifications. Each row is a fresh
adjudication: the evidence and the real alternatives are put before the
owner as if the question had been posed at the proper time. "Adjudicate
shipped" means: if ruled, the ledger records the ruling + evidence and
the shipped text stands AS RULED TEXT; if ruled otherwise, the shipped
text/implementation is unwound per the ruling.

| Row | Finding | Question (owner ruling required) | Acceptance criterion | Status |
|---|---|---|---|---|
| R1.1 | F-1 d7ca927b journal §6.1 | The substantive question never answered: (a) v1 = object-wire carriage stands; pushdown = future work behind its own spec pass at a stream the owner names; (b) pushdown implemented IN stream 4: spec-first letters on the two design points (fn-as-data carriage — probed against existing canonical/Tier-2 code-identity forms so the identity-adjacency question is answered with data; snapshot-key custody options) → owner rulings recorded → §6.1 restored to its full original contract under them → implementation with per-verb fixtures, lanes joining the W7 parity/exit gates; (c) revert §6.1 to unbuilt-pushdown text (violates seam rule — listed for completeness). RECOMMENDATION CORRECTED 2026-08-07 from (a) to (b) after owner challenge: deferral contradicts the campaign's purpose — the profile must be THE complete wire before CSRP retires, and the fn-as-data identity question MUST be answered inside the campaign's window (I1 epoch is closed; post-campaign discovery of an identity need would be blocked or catastrophic). The original (a) recommendation repeated the expedience bias under audit. **RULED: (b), owner, 2026-08-07 — "full pushdown implementation was never a question."** Consequence for scope: the W7 parity/error-identity fixture families (R2.5) are built ONCE against the COMPLETE post-pushdown verb surface. | Ruling recorded; §6.1 text conformed to the ruling under it; pushdown letters posed before any code. | RULED (b) — letters P1/P2 POSED (ledger §R1.1(b)), awaiting owner ruling |
| R1.2 | F-2 25d7c775 M1/M2/M4 single-scalar shapes | Alternatives, honestly: (i) single-scalar offer-*/confirmed-* fields (shipped) — minimal carriage that keeps transcript byte-stability; (ii) nested [offers] signed over exact-bytes-as-sent — abandons canonical-form signing discipline (signature no longer tied to canonical identity); (iii) nested [offers] + fix data-bin atomization of element children — touches the identity-adjacent data-bin lane, which is epoch-frozen post-I1 (would require a new epoch = ruled out by "I1 is the only epoch" unless the owner reopens it). Probe evidence: nested children do not atomize; the same offer landed at different byte positions across encode/decode → the signed transcript was unstable (recorded W2, xsp-auth-025..031 pin the downgrade family). | Ruling recorded with the probe evidence cited; ledger gains the adjudication entry; if not (i), the /3 handshake re-cut under its own plan. | VERIFYING |
| R1.3 | F-3 f61cb141 store.md §6.4 scheme + credential vocabulary | Design adjudication: (a) shipped design — bare cx-store:// = profile over TLS; cx-store+xsp:// = cleartext dev sibling, port explicit; identity via open-opts xsp-did + xsp-seed-env (seed ALWAYS an env-var name; URL userinfo refused at parse); (b) owner-directed alternative (e.g. different scheme names, config-file credential carriage, TLS-only with no cleartext sibling) — owner specifies, I spec-first it; (c) revert the scheme rows entirely (removes the shipped W6 client surface pending redesign). | Ruling recorded; §6.4 conformed under it; client behavior + tests conformed. | VERIFYING |
| R1.4 | F-4 8f6832dd vp single-scalar carriage | Same evidence class as R1.2: a [vc] crossing the data-bin lane re-canonicalizes and its SIGNATURE dies (probed: [delegation d-vc-1 …] re-parses with a trailing-space id → bad-signature); M3 is transcript-signed so nested children hit the same W2 trap. (a) adjudicate shipped single-scalar [vp "<canonical text>"]; (b) alternative carriage the owner names; (c) revert (breaks W4 authority on the wire pending redesign). | Ruling recorded w/ evidence; §6.1 conformed under it. | VERIFYING |
| R1.5 | F-5 40743e8e erased-marker-WINS | (a) adjudicate shipped rule (objects-get answers erased=true and never the bytes while the root awaits reclamation; objects-have keeps it missing — serving bytes would leak lawfully erased content); (b) strike the sharpening, restore prior §7b.1 (re-opens the leak window). | Ruling recorded; §7b.1 conformed under it. | VERIFYING |
| R1.6 | F-6 d8d638b7 CSRP doc-frame (disputed classification) | Owner classifies AND adjudicates: the concrete [u16 hash_algo_code BE][digest32] layout + fail-closed rules landed same-commit with self-recorded authorization, under partial predating cover (manifest row 3, crypto-agility, ruling 1a codes). (a) classify as covered-by-manifest, adjudicate shipped layout (it repaired silent zero-padded hashes to binding clients; digest bytes unchanged; test-pinned); (b) classify as unauthorized (authorization written concurrently = the breach pattern), AND adjudicate the shipped layout on its merits (keep the fix, record the breach honestly); (c) unwind the frame re-form (re-breaks the binding-client defect). RECOMMENDATION REVISED 2026-08-07 to (b): the record's honesty is itself a campaign deliverable — partial predating cover does not make concurrent self-authorization authorized, and softening the classification to keep the record clean is the same defect one layer down. | Classification + ruling recorded. | OPEN-Q |

## Part 2 — Process-breach rows

| Row | Finding | Question / action | Acceptance criterion | Status |
|---|---|---|---|---|
| R2.1 | F-7 epoch corpus amended post-approval | REVISED 2026-08-07 — the epoch is the identity bedrock; the strongest affordable evidence is both lanes: (a) review packet (the 22 outputs of aa2a24c2 + the 12 re-pins of d8d638b7, each with before/approved-degraded/after values) PLUS independent re-verification of the AMENDED families (agents that did not do the amendment re-derive expected outputs for math/random/prof), then owner sign-off rests on both — recommended; (b) full-corpus re-verification (costlier; marginal over (a) given the R4.3 re-audit re-runs every executable gate anyway). | Packet delivered; scoped re-verification recorded; ruling + sign-off recorded. | OPEN-Q |
| R2.2 | F-8 I4 installer exit-gate | (a) ratify the disclosed deferral AND make the closure MECHANICAL: I4 exit stands; tracker issue (sanitized, labeled) + the release-cut checklist/script gains a BLOCKING per-profile install-verification step (CX_PROFILE=<lean> must install from the cut artifacts or the release does not ship) — recommended (assets physically require a cut; a checklist gate is evidence, a tracker issue alone is intent); (b) reopen I4 exit until assets exist (blocks on a release cut by construction — performative). | Ruling recorded; issue filed; release gate step landed. | OPEN-Q |
| R2.3 | F-10 I0 premature done-claims; F-11 I3 deferral-before-ruling; F-12 I2 in-ledger self-ruling; F-13 W5 post-hoc deferral; F-14 I4 R2 riding amendment | Owner ruling on the CLASS: (a) acknowledge as recorded process defects, no unwind (each converged/was cured; all are now impossible under the rulings-before-edits protocol + the R4.1 gate); (b) owner names specific items from this set for individual unwind/re-posing. | Ruling recorded; any named items get their own rows. | OPEN-Q |
| R2.4 | F-13 specifically: migrate/clone erased-map → stream 20 | REVISED 2026-08-07: (a) confirm the stream-20 routing (it owns the SEK cut; stream 20 is INSIDE this campaign, so the campaign still delivers carriage) PLUS an interim fail-loud guard NOW (new row R3.16): migrate/clone of a store carrying erasure tombstones REFUSES loudly until stream-20 carriage lands — silent tombstone-dropping is the silent-partial anti-pattern and a lawful-erasure attribution loss — recommended; (b) pull full carriage into stream-4 remediation (duplicates stream-20's SEK design work). | Ruling recorded; R3.16 guard landed if (a). | OPEN-Q |
| R2.5 | F-25 W5 wave-gate validity ("G13 families green" vs missing G13 fixtures) | (a) rule the G13 fixture items (op-for-op parity table, error-identity table, cross-encoding parity) = W7 parity-gate scope; §9 "discharged" + the W5 done-when text corrected UNDER THIS RULING; W5 exit stands conditional on W7 delivering them; (b) reopen W5's gate now: build the G13 fixture families as remediation before any W7 work. | Ruling recorded; if (a): text corrected under ruling + W7 plan row amended; if (b): fixtures built + green. | VERIFYING |

## Part 3 — Defect and gap rows (spec already clear; authorization to execute)

Default direction per register rule 3: implementation conforms to spec.
One batch authorization question covers execution; every row still
closes individually with its own evidence.

| Row | Finding | Work (fixture-before-fix) | Acceptance criterion | Status |
|---|---|---|---|---|
| R3.1 | F-20 M3 malformed vp silently ignored | Fixture first: nested [vp] at M3 → expect CXER5021 loud refusal (spec §6.1 text is unambiguous). Then fix sx_m3_vp_text option-none path to refuse, matching the phase=present lane. | New test red→green; both M3 and phase=present lanes pinned. | VERIFYING |
| R3.2 | F-23 CXER5013/5016 (+5015) untested | Tests: attach to unknown/ambiguous mount → 5013; bad ::bytes image + ast_bin decode failure → 5016; an internal-fault lane for 5015 if constructible without mocks. | Each code has at least one wire-level test. | VERIFYING |
| R3.3 | F-24 authority presentation-fault lanes untested | Wire tests through the profile listener: floor-cannot-present 5021; malformed-vp 5021 (rides R3.1); inert-root [presented compiled=0 inert=K]; cross-tenant CXER4805; wire CXER4703 escalation. | Each lane pinned over a real daemon. | VERIFYING |
| R3.4 | F-26 code-verified, regression-unguarded behaviors | Tests: revocations-cursor resume; feeds-die-with-connection; deleted-replay body-absence (strengthen the weak assert); alias-retract shape; open-posture CXER5022; PEP-before-token-gate ordering; peer wrong-DID pin; origin-folds-own-journal; rate retry-after on the wire. | Each behavior pinned. | VERIFYING |
| R3.5 | F-21 feed shape-acceptance quirks | Cutover posture (no dual-accept): multi-scalar [planes] refused loudly (or all scalars honored — whichever §5.2 says; if §5.2 is silent, this row escalates to a letter before code); name= on revocations cursor refused; stale comment corrected. | Off-spec inputs refuse loudly; tests pin. | VERIFYING |
| R3.6 | F-22 F3 re-advert direct-push missing | MAKE THE SPEC TRUE (register rule 3): implement the direct advert push from the config-reload verb handler alongside the sweeper watch; test pins immediate re-advert on the reloading listener. (Reverse option — truing §7a.1 to sweeper-only — would be a spec edit to match a shortfall; not proposed.) | Direct push implemented + pinned; sweeper lane unchanged. | VERIFYING |
| R3.7 | F-9 G18 --strict unwired | Wire scripts/cxer_registry_report.sh --strict into TEST_TARGETS (exits 0 today). Synthetic-violation check: an unregistered CXER in a probe branch fails it. | Gate in TEST_TARGETS; red-on-synthetic verified. | VERIFYING |
| R3.8 | F-15 extraction-gate floor + 3 uncovered cases | Assert a case-count floor in the Make recipe (n_cases >= recorded); cover ch-005/cmp-005/sd-006 in a lane (probe sections or CLI); document the 5 md ABI-lane exclusions as intentional with the CLI-lane cross-reference. | Floor asserts; 3 cases compared somewhere; vacuous-pass probe fails. | VERIFYING |
| R3.9 | F-16 CX_BLESS=epoch armed | Disarm: epoch-bless paths refuse unless an explicit build-time flag (-d cx_epoch_bless) is set; normal builds cannot bulk-bless. | Env var alone no longer blesses; test pins refusal. | VERIFYING |
| R3.10 | F-17 ring-gate C-edge gaps | Widen the lane: relative ../<sibling> includes, @VMODROOT/../vcx/<sibling> forms, raw .c/.h scanning; narrow c_edge_allowed to the two exact known edges; add arrow/transport (and cmd_data/cli platform-free) lanes. Red-on-synthetic for each new class. | All probe bypasses from the audit now fail the gate. | VERIFYING |
| R3.11 | F-18 profile-binary corpus lanes | REVISED 2026-08-07: FULL graded corpus through the cli and embed BINARIES (the I2 data-profile precedent ran 8978 pairs through the binary — the sample idea was a scope reduction). If measured runtime is genuinely prohibitive for TEST_TARGETS, that measurement becomes a LETTER with numbers (options: full-in-CI / full-nightly+sample-in-gate), not a silently smaller lane. | Binary lanes graded on the full corpus (or an owner-ruled letter with measurements); synthetic probe proves failure possible. | VERIFYING |
| R3.12 | F-19 thrown-error auto-pass hole (inherited class) | Scope honestly: this is the historical #404-#407 class across THREE lanes now. Fixture-first repair in profile_gate.v + the two code_eval lanes: a thrown error only passes an out-err case when the code matches. Risk: may surface latent mismatches — each surfaced case triages as fixture-or-code under fixture-before-fix. Also: stop discarding cmodule_gate. | Thrown-vs-expected mismatch fails all three lanes; surfaced cases triaged. | VERIFYING |
| R3.13 | F-27 I3 census off-by-one; F-28 I2 proof-claim; F-29 "standing" label | Ledger corrections (process docs): each corrected in place with a dated correction note citing this register. | Corrections landed. | VERIFYING |
| R3.14 | F-30 cosmetic spec/impl deltas | Each is a spec-vs-impl divergence → per register rule 3 the default is conform-the-impl: drop the extra request= attr from [erase-result] (or owner rules to spec it); move the G8 group-from refusal pin into the corpus; emit generation= as the spec'd attr (keep child during migration? NO — cutover rule: attr only). Any row where the owner prefers the impl's shape escalates to a letter. | Impl matches spec text exactly; pins updated. | VERIFYING |
| R3.15 | I5-s4 auditor's unverifiable externals | Verification pass in the two external repos (console conform §13b, web-client /3 lane) — re-run their gates, record results here. | Results recorded (green or filed). | VERIFYING |
| R3.16 | R2.4 interim guard | Until stream-20 erased-map carriage lands: store-migrate/store-clone of a source carrying erasure tombstones (E-records) refuse loudly (CXER code per store.md's refusal conventions; fixture-before-fix). Removed by stream 20 when carriage lands. | Refusal pinned by test; stream-20 row references removal. | VERIFYING |

## Part 4 — Structural enforcement + resumption

| Row | Item | Question / action | Status |
|---|---|---|---|
| R4.1 | Mechanical spec-freeze gate | (a) repo gate (pre-commit + TEST_TARGETS lane): any commit touching normative spec paths (spec/03-approved/**, working feature specs) TOGETHER WITH implementation paths hard-fails unless the commit message carries a ruling token (RULED:<row/letter/date>) that matches a recorded ruling in the ledger/register; ledgers (spec/02-working/partition_*) exempt; (b) rules-only, no mechanical gate. | OPEN-Q |
| R4.2 | Rulings-before-edits protocol | Standing: every ruling is COMMITTED (ledger/register) before the work it authorizes begins; same-commit recording is a violation by definition. Already memorialized in standing memory; register rule 5 applies it here. | STANDING |
| R4.3 | Independent re-audit gate | After Parts 1–3 close: a fresh adversarial verification pass (same method as this audit — agents that did not do the remediation) over every CLOSED row's evidence + a full make test wave gate. Nothing resumes before it reports clean. | PENDING PARTS 1–3 |
| R4.4 | Resumption ruling (R-final) | Owner rules whether W7 resumes, and under what scope, ONLY after R4.3 reports. No pre-commitment. | PENDING R4.3 |
| R4.5 | Durability | Push impl/I5-stream4-xsp-store (audit + register commits) to origin so the record survives the machine. | OPEN-Q (owner: push now (a) / at next batch (b)) |

**Wave-gate note.** W2–W6 wave gates were claimed under the now-broken
process. The audit found their TECHNICAL claims sound where verifiable
(no weakened tests, epoch intact, gRPC byte-stability true) with the
exceptions carried in rows R2.5 (W5 done-when) and R3.x (coverage). The
R4.3 re-audit + full gate re-run is the compensating control: every wave
gate's executable portion re-runs before resumption.
