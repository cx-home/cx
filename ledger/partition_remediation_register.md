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

**2026-08-08, owner (post-R4.3 foundational rulings — supersede the P1
letter and the R4.4 W7-parity plan):**
- **F1 (a) — the one-object-kind principle + rename, RULED.** Documents
  are the ONLY object kind in CX: everything is stored, shipped,
  journaled, and signed as a document under its DOCUMENT IDENTITY
  (hash of canonical bytes). COMPUTATION IDENTITY (hash of the
  normalized program — "same function?") is a derived equivalence
  relation: an index or a verification claim, NEVER an address, NEVER
  a storage key of record, NEVER a wire carriage. The "Tier-1/Tier-2"
  names are RETIRED repo-wide → "document identity" / "computation
  identity" (prose-level rename; no wire, address, or epoch impact).
  Root cause this cures: the campaign froze the code: address space
  without a referent object form — because there never needed to BE
  one; treating computation identity as an object identity was the
  foundational wart (a special case for code, which is how
  homoiconicity dies).
- **F2 (a) — the spectrum audit, RULED.** Sweep every surface where
  computation identity acts like an address or code is treated as a
  special object kind (code: address surface, the code store keyed by
  computation identity, registry/packs, [?lib] resolution, bindings,
  the pushdown letters) → conforms/violates table to the owner BEFORE
  any fix lands; violations are ripped out, no grandfathering.
- **F3 (a) — pushdown re-posed, RULED (replaces letter P1 entirely).**
  Fold/replay functions cross the wire as the def DOCUMENT(S), by
  document address, over the existing object wire — plus a
  computation-identity CLAIM the daemon recomputes and refuses on
  mismatch. A dependency closure = more documents (a module IS one
  document). No special function carriage exists. P1's three carriage
  options are dead.
- **R4.4 (a-revised) — CSRP dies NOW, RULED.** No three-listener parity
  gate against the dead wire: the correctness oracle for the profile is
  the LOCAL EMBEDDED ENGINE (byte-identical addresses, already
  asserted) + the profile's own fixture families. The retirement
  enumeration executes immediately: CSRP routers/codec/client arms,
  store_authz.v, bearer surface, transitional cx-store+http(s) schemes,
  17xx band → Reserved. Rationale recorded: CX has no external users;
  every CSRP consumer was ours and migrated at W6; keeping a deprecated
  wire as an oracle was big-installed-base migration machinery applied
  against our own cutover-first standing rule.
- **F4 (a) — daemon compute budget, RULED.** Not a separate letter: a
  HARD REQUIREMENT of the pushdown build. Every daemon-side evaluation
  runs under an operator-configured step limit + memory ceiling;
  exceeding either is a loud TYPED refusal, never a daemon takedown.
  Per-principal delegable budgets (a bounds conjunct) are a later
  layer riding the existing authority model — not built now.
- **F5 (b) — snapshot signing, RULED.** Client-signs is the default
  semantic (the key NEVER travels; the daemon serves the state to
  sign). The APPOINTED-SIGNER capability is specced in the same pass:
  an org may delegate snapshot-signing to a designated signer
  principal (e.g. HSM-backed) through the existing credential model —
  one capability row, no new machinery; generalizes to threshold
  signers later. snapshot-verify (public-key check) is pushdown-safe.
  Daemon self-attestation: NOT specced; if ever wanted it is a
  distinct, explicitly-named attestation type.
- **F6 (b) — epoch ratification WAITS for the F2 rip-out.** Fix
  everything first, then baseline once: the corrected identity corpus
  is ratified in ONE pass after the F2 spectrum fixes land (undocumented
  drift remains mechanically blocked meanwhile). The
  partition_epoch_amendment_packet.md sign-off is deferred to that
  moment, folded into the same ratification.

**2026-08-08, owner (F2 spectrum-audit resolution — A1–A6):**
- **A1 (a) — claim spelling.** A computation-identity CLAIM is a distinct
  token the address parser REFUSES — never confusable with a document
  address (the confusability was the disease). `cx_parse_tagged_address`
  keeps rejecting `code:`; the claim rides as a distinct
  `[computation-id sha2-256:…]` element / `computes-as:` form, never a
  parseable address. `code:` is NOT resurrected as a claim prefix.
- **A5 (a) — idempotency key stays on computation identity.** "Same
  command" = same MEANING (alpha-equivalent command fns dedup); this is
  a legitimate index/dedup use of the relation (not trust, not an
  address), conforming to F1. Spelled as a claim, not an address.
- **A2 (a-rec) — replacement surface.** A pure `[$cx:computation-id
  <def>]` builtin returns the claim; store-code-003…010 re-express the
  relation's pair properties through it, every pinned truth value kept;
  case-ids renamed same commit (metadata, non-epoch per the I4
  precedent).
- **A3 (a-rec) — legacy on-disk `C` code records.** Dropped outright
  with a LOUD refusal on encountering one (no silent skip, no
  read-tolerance window; no users, cutover-first).
- **A4 (a-rec) — xap-dist `identity=` claim SURVIVES**, recomputed via
  the pure fn instead of the scratch-store put-def.
- **A6 (a-rec) — store feed.** No "code plane" owed; def documents ride
  the `docs` plane as ordinary documents.

**2026-08-18, owner — the pre-cut bug-sweep rulings ("1a 2a 3a 4 approved 5
approved 6 approved"). Ids R5.1–R5.6 are allocated HERE so the R4.1 token has
a recorded ruling to name.**

- **R5.1 (1a)** — #854 + #849: an **ADDITIVE presence predicate**. `[$count]` /
  `[$exists]` keep their ruled content-arity meaning; **#584 STANDS** (owner
  2026-07-23, "closed by design") and the `count_items` → `iterate()`
  unification is NOT re-landed — it was measured and fails 8 enforced fixtures.
  Authorized: a `code.md` §6.5 row for the new predicate (true for any node
  including a childless element; false only for `()` / an empty node-set) plus
  conformance cases. Nothing else in the sequence-builtin family changes.
- **R5.2 (2a)** — #853: a computed `[err]` **propagates from plain child
  position**. Authorized: `code.md` §6.4.1 / §9.2 text making element
  construction operand-consuming for propagation. MUST PRESERVE: a LITERAL
  `[err …]` in source stays DATA — the discriminator is POSITION, not value.
  MUST STATE the cost in the spec text: embedding a CAPTURED err stops working.
- **R5.3 (3a)** — #840: `[from 'feature/noun' …]` gets a minimal checkable
  syntax — one or more QUALIFIED NOUN REFERENCES, each required to resolve to a
  noun of the composed grammar. Join SEMANTICS stay unspecified and uncomputed,
  so no join algebra is committed. Authorized: the
  `xap_grammar_composition.md` W5 row + the `[from …]` grammar.
- **R5.4 (4 approved)** — #826 Acceptance 1: the docs-restructure proposal is
  approved AS A WHOLE; implementation unblocked. §7 was already ruled 1a/2a/3a
  @ 120bd33e. §6's two staleness items remain outstanding.
- **R5.5 (5 approved)** — #832: the spec-process audit and cure is AUTHORIZED,
  including editing the process artifacts themselves. Sequencing UNCHANGED:
  still the **LAST** issue before the v0.16.0 cut, after #845 and #741/#752.
- **R5.6 (6 approved)** — #812: **SPEC** `x/term`, do NOT retire — it has a
  working exercised `select` (#852 fixed @ 3843e6e5) and a live consumer. The
  spec gives #852's TLS caveat a documented home: for a secured stream,
  socket-readable is not frame-available, so a poll can miss a buffered record
  and a `timeout:` is what recovers it.

**R5.0 — recording is LATE, and that is the point of the row.** R4.2 requires a
ruling to be committed BEFORE the work it authorizes. These six were ruled and
executed on 2026-08-18 with the authorization cited in prose in each commit
message, but were not recorded in this register first, so the three commits
that touch normative spec AND implementation carry no `RULED:` token:

| commit | issue | ruling |
|---|---|---|
| `a36244f4` | #854 + #849 | R5.1 |
| `ab6a62e5` | #853 | R5.2 |
| `d3277277` | #840 | R5.3 |

(#812's spec, `abba2a0c`, is spec-only and is not an R4.1 violation — verified
against the gate.)

**RULED (a) BY OWNER 2026-08-18 on how to settle it:** record the rulings here
now — done by this entry, which makes `RULED: R5.1`/`R5.2`/`R5.3` citable for
any follow-on commit — and fold the standing violation set into **#832's**
audit rather than rewriting pushed shared history or self-adding
`ADJUDICATED_SHAS` rows (which the gate script reserves to owner authority).

**The finding #832 inherits, measured not assumed:** `make spec-freeze-gate`
reports **16 violations** over `f964c16a..HEAD`, of which **THIRTEEN pre-date
2026-08-18** (e.g. `c5019ca6` fix(#844)). The R4.1 token discipline has not been
followed on `release/0.16.0` for a long stretch; the 13:3 split is why this is
systemic process debt and not three careless commits. It went unseen because
`spec-freeze-gate` is in `TEST_TARGETS` (Makefile:429) but is **not** a
dependency of `test-vcx` (Makefile:1025), so a green full `make test-vcx` at
`40510b9b` never ran it — the same lane hole as #860
(`check-code-spec-consistency`, also red at that commit). Do not settle this by
loosening the gate.

**2026-08-18 (second round), owner — the pre-cut gate/spec dispositions
("1a 2a 3a 4a 5a 6a"). Ids R5.7–R5.11.**

- **R5.7 (1a)** — #860: the `vcx/code/diagram.v` anchor at `code.md:3893` is
  **ALLOWLISTED** in `IMPL_ANCHOR_ALLOWLIST`, not deleted from the spec. It
  meets the list's stated criterion — a pure pointer-to-realisation beside
  self-contained normative text — so it qualifies on the merits rather than as
  a convenience. Deleting it would have edited approved normative text to
  satisfy a gate, and set that precedent.
- **R5.8 (2a)** — #860: `check-code-spec-consistency` is **wired into
  `test-vcx`**, AFTER R5.7 makes it green. A gate in `TEST_TARGETS` but not in
  a lane that runs is indistinguishable from no gate; that hole is why it sat
  red from 2026-08-17 through a green full-suite run.
- **R5.9 (3a)** — #859: **§6.5.x gains a CARVE-OUT sentence** stating that it
  classifies the LANGUAGE, and that native primitives backing stdlib module
  bodies are classified implementation-side. Mirrors the precedent §6.5.x
  already sets for the `[?test-…]` harness directives. Chosen over
  enumerating the eight stdlib-backing natives (`sqrt` `cbrt` `exp` `log`
  `log2` `log10` `pow` `validate-item`) in the Numeric list, which would put
  non-language primitives in the language's closed list and need an edit per
  new native. **This is the NAMED spec authorization for the §6.5.x edit.**
- **R5.10 (4a)** — #840: `[from 'a/b' 'c/d']` (one reference per string) and
  `[constituents 'a/b c/d']` (space-separated) **KEEP their different shapes**,
  with the divergence documented in `xap_grammar_composition.md` §4.1. No
  defect sits behind converging them. Converging `[from]` onto the
  space-separated form is REFUSED — it would destroy fail-closedness, since a
  stray join sentence would split into plausible-looking names instead of being
  refused. Converging `[constituents]` the other way is the better end state
  and may be scheduled after the cut.
- **R5.11 (5a)** — #861: widening `x/term`'s `read-event` to forward the
  native's optional timeout gets **its own lane after the cut**, with fixtures
  for the `:rest` variadic path itself — `:rest` has no live consumer anywhere
  in `stdlib/`, `x/`, or the corpus, so the first one cannot ride a one-line
  fix. The doc now states the blocking behaviour and points at `select`.

Sequencing (6a): #741/#752 cut prep next; #832 stays LAST.

**Deferred to #832 by the same round:** `§6.5.x` is an anchor whose siblings
are `§6.5.0` and `§6.5.1`, so it reads as a placeholder that was never
numbered and then became load-bearing — cited 8× inside `code.md` and from
`computation_identity.md`, `security.md`, `modules/cx.md`,
`modules/tree-sitter.md`, `process/threat-model.md` and two ledgers.
Renumbering is a cross-spec rewrite for zero behavioural gain; #832 owns this
class of artifact.

**2026-08-18 (third round), owner — "1a 2a": the webhook adapter fails LOUDLY,
and it is fixed BEFORE the cut. Id R5.12.**

- **R5.12** — `tooling/cxfabric/webhook-adapter.cx` wired `[$fabric:observe]` /
  `[$fabric:subscribe]` in element CHILD position, so before #853 a failed lane
  was CONTAINED and the adapter went on to bind its HTTP port and serve with
  DEAD LANES. #853's propagation turned that into an early exit with no
  output — which broke `fabric_umbrella` and, more importantly, revealed that
  the old behaviour was hiding a real fault.
  **Ruled: fail fast and LOUDLY** — check each lane, exit with a diagnostic
  NAMING the stream that failed. Restoring containment was refused: it would
  deliberately re-bury a refusal in a document, which is the defect the #853
  ruling removed. Reverting #853 was refused: a ruled semantics is not
  discarded because one consumer relied on the bug.
  Ruled fixed before the cut (2a) — but **NOT YET DONE, and the causation claim
  behind it is WITHDRAWN.** Attempting it produced the evidence against it: with
  the broker unreachable the adapter HANGS inside `[$fabric:open]` (rc=124 under
  `timeout`, zero output) and never reaches the lane code at all, so the
  "adapter never came up" failure is not demonstrated to be #853's. A hardening
  edit was written and then REVERTED unverified — no diagnostic was ever
  observed, and shipping unverified code into shipped tooling is the mistake
  this session already made twice. `fabric_umbrella` remains RED with the cause
  UNESTABLISHED; it needs a bisect against the pre-session build, which is a
  rebuild.
  The hardening itself still stands as ruled and should land WITH a test that
  proves the diagnostic fires.

  **ATTRIBUTION SETTLED 2026-08-18 by the bisect (worktree build at
  `40510b9b` vs HEAD `61d0292c`). #853 IS the cause — of a DIFFERENT defect than
  the withdrawn hypothesis, and the withdrawal was correct: the lane wiring is
  not what fires.** The adapter comes up, binds its door and serves correctly;
  the empty `adapter.log` is simply a working adapter that prints nothing. What
  broke is `make-handler`'s REFUSAL RESPONSES. Every one built
  `[?element 'response' [?attr 'status' N] [?element 'body' [$format:canonical
  <err>]]]`, and an `err`-headed node is operand-consuming in BOTH positions
  used there — as the `$format:canonical` CALL OPERAND and as an element CHILD.
  Post-#853 the err propagates transitively and the whole envelope, status
  included, is discarded; `http:serve` then serves the bare err with its default
  **200**. The test's readiness probe accepts only 401 or 404, gets 200 for the
  full 10s loop, and reports "adapter never came up" — a misleading message for
  a door that is up and answering.
  Measured, pre-fix, on the live adapter: `GET /nope` no-auth → **200** with the
  correct `CXER0271` body; with bearer → **200** with the correct `CXER4926`
  body; the 200 receipt path was UNAFFECTED (its payload is not an err), which
  is exactly why only the refusal statuses moved.
  **A second fact the bisect turned up: `$format:canonical` was never actually
  running on these bodies in EITHER build.** Pre-#853 the same call was already
  short-circuited by the err operand and the err was ADOPTED as the body child,
  so the body was an err NODE rendered by the serve layer, not canonical text.
  #853 did not break a working path; it converted a containment into a
  propagation and thereby surfaced a fault that had been silent since P3.
  **Fixed** by `err-body` — a `[?def]` taking the code and message as SCALARS
  (the ruling's own "build a fresh element from `@code`/`@message`" remedy),
  so no err node sits in an operand position and `$format:canonical` still does
  the quoting. All four refusal sites (401/404 static, 400/502 dynamic) moved.
  `fabric_umbrella` GREEN, `FABRIC-RC=0`, verified twice.
  **`http_umbrella` is NOT a regression and never was.** Its union-run red is
  the #572 `-usecache` duplicate-symbol link artifact — `ld: 1 duplicate
  symbols`, 0.000 ms runtime, the lane never ran. Green cache-free at HEAD
  (`OK 30787 ms`). It has no retry class in `SUITE_SERIAL_RETRY`, so the lane
  classifier can only reach it through the `C compilation error` branch.

  **THE HARDENING ITSELF IS NOW LANDED, WITH THE TEST — and #853 turns out not
  to be involved in it at all.** Measured on the live adapter with the
  principal's `observe` grant removed: `[$fabric:observe]` returns
  `CXER4925 E_FABRIC_DENIED` correctly, but a `[?for]` yields that err as a
  SEQUENCE ITEM, and a sequence is not element construction — so the err was
  CONTAINED, never propagated. The adapter bound its door, answered 401s
  correctly, and pumped an SSE lane that had never joined, with both output
  streams empty, indefinitely. **The pre-session `rc=124` "hang with zero
  output" was a `timeout` killing a daemon that serves and never exits** — not
  a hang, and the reason the earlier attribution attempt went astray. #853's
  propagation never fired on this path in either direction.
  Fixed: each lane's join is inspected with `[?match]`; a refusal becomes a
  `[lane-failed kind=… stream=… code=… message=…]` diagnostic, and `$srv` is
  bound INSIDE the `[else]` branch of a `[$present …//lane-failed]` guard —
  because an err- or diagnostic-valued BINDING does not by itself stop the
  bindings after it in a flat `[?let]` (verified). Branch-local bindings are
  the sanctioned nesting, not a cascade.
  Observed diagnostic: `[adapter-refused-to-start reason=lane-join-failed
  ([lane-failed kind=sse stream=orders code=cx-err:CXER4925 message='…holds no
  observe grant on stream "orders"'])]`, adapter dead in ~1s, door never opened.
  Test `test_fabric_adapter_refuses_on_lane_join_failure` (9 asserts), and it is
  BROKEN THREE WAYS to earn its green: gate disabled → red naming the fault
  ("kept serving despite a failed lane, door answered 401"); stream name
  redacted → ONLY the naming assertion red (6 of 7 still pass, so that
  assertion is independently load-bearing); and the FIRST version of the test
  was itself defective — it waited on the adapter in the FOREGROUND, so the
  gate-disabled break HUNG the lane for 300s instead of failing it. Restructured
  to poll a background process. **A test whose failure mode is a hang reports
  nothing.**
  Full lane green: 16/16, 315 asserts, `FABRIC-RC=0`.
  **REMAINING SHORTFALL, named not papered over: the refusal exits 0.** CX has
  no exit and no raise directive, and a top-level result — err or otherwise — is
  printed and exited 0 (verified). So a supervisor cannot distinguish this
  refusal from a clean shutdown. Making it non-zero is a `cli.md` question about
  the run surface's exit mapping, i.e. normative spec, and is NOT taken here.
  **OWNER QUESTION, open.**

**This is the first live consumer to prove #853's value rather than only its
cost:** every other site that moved was a test or fixture LABELLING a refusal;
this one was a production path SERVING on top of one.

**2026-08-18 (fourth round), owner — "1a": a top-level err result EXITS
NON-ZERO. Id R5.13. This carries NAMED authorization to edit `cli.md`.**

- **R5.13** — R5.12's hardening landed its diagnostic half but could not be made
  loud, because **CX has no `exit` and no `raise` directive and the run surface
  prints a top-level `err` result to stdout and exits 0** (verified three ways).
  A supervisor therefore cannot distinguish an adapter that refused to start
  from a clean shutdown — the silent-success trap, in the one place that matters
  most. Options posed: **(a)** rule the mapping and land it — TAKEN; **(b)** fold
  it into #832, which leaves shipped tooling refusing with rc=0 through the cut;
  **(c)** accept rc=0 and treat the diagnostic as sufficient — recommended
  against, since it makes the failure undetectable by any supervisor.
  **AUTHORIZED:** `cli.md`'s run-surface exit mapping — a program whose RESULT is
  an err exits **1**. Plus the conformance/engine lanes that pin it.
  **THE DISCRIMINATOR FOLLOWS #853's, and is POSITION, not value** (the §6.4.1
  principle already ruled): a **computed / propagated** err result is a failure
  and exits 1; a **literal** `[err code=…]` written as the program's own
  top-level form is DATA and stays exit 0, exactly as it stays data in element
  child position. Any implementation that cannot tell these apart at the point
  it prints the result must be reported rather than approximated — collapsing
  them would make every `[err …]`-shaped DATA document a failing program.
  Scope note: this is the run surface only. `cx eq` / `cx diff` / `cx lint` /
  `cx validate` keep their own documented exit contracts (§3.4-§3.6), and an
  engine-RAISED error already exits 1 on stderr — unchanged.

## Execution evidence log (rows move CLOSED only after the R4.3 pass re-verifies)

**2026-08-18 (R5.13 execution):**
- R5.13 VERIFYING — `cli.md` §3.7.1 authored + the §5 exit matrix row amended
  (the ONE authorized spec edit); engine side is `note_top_level_result` in
  `code/api.v`, called at BOTH result boundaries — the single-form path and the
  multi-form loop. The multi-form path needed `eval_top_level_each` to return its
  FORMS alongside its results: results are **not** index-aligned with `items`,
  because declaration directives evaluate but contribute no output, so pairing by
  index misattributes every form after the first `[?lib]`/`[?def]`/`[?const]`.
  A test pins exactly that (a `[?lib]` before a literal-err form).
  The discriminator reuses `is_literal_err_head` from `dynamic_construction.v` —
  #853's own predicate, not a second copy that could drift from it.
  Six lanes in `cli_run_surface_test.v`; **break-tested by collapsing the
  discriminator to value-only** (`is_err_value(result)` alone): exactly the two
  DATA-side lanes go red — literal-is-data, and multi-form pairing — while the
  four failure-side lanes stay green. That is the split that matters, because
  value-only is the specific mistake the ruling warned against.
  `code_eval_fixtures` GATE-RC=0 (no fixture moved: the rule changes the exit
  status and no output bytes).
- **AND IT IMMEDIATELY EARNED ITS KEEP: `examples/code-tour.cx` was ALREADY
  BROKEN BY #853 and no gate could see it.** §14's `[?retry]` exhausts its budget
  on purpose — pedagogy — so its value is an err in element CHILD position, which
  since #853 propagates: out of `[section]`, then out of `[tour]`, so the flagship
  tour rendered as **nothing but that one err**, losing every section. The
  existing `test_flagship_tours_documented_run_lines_work` passed throughout,
  because it asserts only `exit_code == 0` (which held, pre-R5.13) and non-empty
  output (which held — the err is output). Fixed with the escape #853's own
  ruling documents, the same one `ab6a62e5` applied to its ten fixtures: the
  demonstration moves into a paren SEQUENCE, which is not element construction
  and therefore CONTAINS the refusal. Tour restored from 42 lines to 51 with all
  6 sections and the full cause chain intact; `rc=0`.
  **This is the eighth #853 consumer, and the first found by a gate rather than by
  reading.** It is also the answer to "what else did #853 quietly change" — the
  honest one is that a gate keyed on exit status finds these and a gate keyed on
  non-empty output cannot.
- **R5.13 IS NOT LANDED — it is PARKED IN A STASH, blocked, and the blocker is
  MINE.** `git stash` entry "R5.13 WIP" on `release/0.16.0` holds all of it:
  `cli.md` §3.7.1 + the §5 matrix row, the engine change, the six CLI lanes with
  their value-only break-test, the `code-tour` repair, and the four remediations.
  Every targeted lane is green — `cli_run_surface` 62/62, `code_eval_fixtures`
  GATE-RC=0, `async_conc_umbrella` and `xap_umbrella` green after remediation.
  **What blocks it: `vcx/code/code_module_umbrella_test.v` takes SIGNAL 11 under
  the 12-parallel-job `make test-vcx-code`, while passing 469/469 in isolation.**
  Attributed, not guessed: stashing the change makes that target green (26/26,
  rc=0) and restoring it makes it segfault again, reproducibly.
  Ruled OUT as the cause: the `__global` declaration style. Moving it from a
  top-level `__global x = false` into the block form this module already uses did
  NOT fix it.
  **Prime suspect, untested: the `eval_top_level_each` signature change** — it now
  returns `!([]cx.Node, []cx.ProgramNode)`, and `dynamic_construction.v`'s own
  header warns that V's cgen trips `type_default_impl` recursion on the recursive
  `cx.Node` sumtype in exactly this shape. The multi-form path needs the FORMS to
  pair results with their source spelling (results are not index-aligned with
  `items`), so if the tuple return is the cause, the fix is to carry the forms
  some other way — classify inside `eval_top_level_each`, or pass a `mut`
  out-param — NOT to drop the pairing, which would reintroduce the value-only bug
  the break-test exists to catch.
  A full `make test-vcx` has NOT passed with R5.13 in the tree. The row stays
  OPEN. Nothing was committed on a green-in-isolation reading.

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
  **RULED (b) BY OWNER 2026-08-09 (post-exit review "b) build these
  now") — the HTTPS-fetch/SRI/lockfile-integrity surface is built and
  the three fixtures flip gate=pending → enforced, green for real.
  Execution recorded in this session's commits under RULED: R3.12(b).
  EXECUTED + VERIFIED same day (73dc8cef; ledger entry 16): the graft
  landed (lockfile-pinned resolution, real SRI verify, cache, live
  TLS GET on the http-client pack), all three fixtures ENFORCED green,
  full `make test` GATE-RC=0 with propagated status.**

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

- R4.3 CLEAN (2026-08-08) — both halves of the compensating control met:
  · Wave gate: full `make test` rc=0 at 9fb13cf3, zero 0x0acd hang
  spew; the single FAIL (fabric_nats_bridge, R=0.000ms) is the standing
  -usecache compile-artifact lane, green on its #572 cache-free retry.
  · Independent fresh-agent re-verification (THREE agents that did NOT
  do the remediation, adversarial, re-running the live gates/tests):
  ALL rows CONFIRMED, NO refutations, NO SUSPECT rows, NO weakened
  assertions. Highlights of the independent proof: the ring-gate
  red-on-synthetic reproduced from a HAND-BUILT fake tree (not just the
  author's harness) + confirmed zero writes to the live vcx/; the
  spec-freeze gate RED on d7ca927b independently; abi-gc-gate live on
  both dylibs (16 cycles each); the R3.2 u64 decoder guard verified at
  BOTH bin_to_doc + node_from_bin entry points with the high-bit
  unit-proof green; every R3.12 impl error-identity conformance
  (CXER0106/0102/0231/1603) confirmed as LIVE code at the cited lines,
  not comments, with the discriminator tests confirmed non-vacuous
  (a mismatch produces a real failure, not a swallowed pass); every
  xsp wire lane asserting at least as strongly as claimed (R3.3's inert
  lane decodes the reply rather than substring-matching; R3.16's guard
  called from BOTH migrate + clone). Agent reports archived in the
  session record.
  **CONSEQUENCE:** every VERIFYING remediation row that R4.3 covers
  moves CLOSED. What remains OPEN is owner-gated only (below).

## Part 1 — Unauthorized spec edits: re-adjudication rows

These are NOT rubber-stamp ratifications. Each row is a fresh
adjudication: the evidence and the real alternatives are put before the
owner as if the question had been posed at the proper time. "Adjudicate
shipped" means: if ruled, the ledger records the ruling + evidence and
the shipped text stands AS RULED TEXT; if ruled otherwise, the shipped
text/implementation is unwound per the ruling.

| Row | Finding | Question (owner ruling required) | Acceptance criterion | Status |
|---|---|---|---|---|
| R1.1 | F-1 d7ca927b journal §6.1 | The substantive question never answered: (a) v1 = object-wire carriage stands; pushdown = future work behind its own spec pass at a stream the owner names; (b) pushdown implemented IN stream 4: spec-first letters on the two design points (fn-as-data carriage — probed against existing canonical/Tier-2 code-identity forms so the identity-adjacency question is answered with data; snapshot-key custody options) → owner rulings recorded → §6.1 restored to its full original contract under them → implementation with per-verb fixtures, lanes joining the W7 parity/exit gates; (c) revert §6.1 to unbuilt-pushdown text (violates seam rule — listed for completeness). RECOMMENDATION CORRECTED 2026-08-07 from (a) to (b) after owner challenge: deferral contradicts the campaign's purpose — the profile must be THE complete wire before CSRP retires, and the fn-as-data identity question MUST be answered inside the campaign's window (I1 epoch is closed; post-campaign discovery of an identity need would be blocked or catastrophic). The original (a) recommendation repeated the expedience bias under audit. **RULED: (b), owner, 2026-08-07 — "full pushdown implementation was never a question."** Consequence for scope: the W7 parity/error-identity fixture families (R2.5) are built ONCE against the COMPLETE post-pushdown verb surface. | Ruling recorded; §6.1 text conformed to the ruling under it; pushdown letters posed before any code. | CLOSED — RULED (b) 2026-08-07; P1/P2 subsequently RULED F3(a)/F5(b) (ledger S6 letters, 2026-08-08); §6.1 restored + the pushdown program DELIVERED S6.1–S6.5 (stream-4 exit, ledger entry 14; warm full gate rc=0) |
| R1.2 | F-2 25d7c775 M1/M2/M4 single-scalar shapes | Alternatives, honestly: (i) single-scalar offer-*/confirmed-* fields (shipped) — minimal carriage that keeps transcript byte-stability; (ii) nested [offers] signed over exact-bytes-as-sent — abandons canonical-form signing discipline (signature no longer tied to canonical identity); (iii) nested [offers] + fix data-bin atomization of element children — touches the identity-adjacent data-bin lane, which is epoch-frozen post-I1 (would require a new epoch = ruled out by "I1 is the only epoch" unless the owner reopens it). Probe evidence: nested children do not atomize; the same offer landed at different byte positions across encode/decode → the signed transcript was unstable (recorded W2, xsp-auth-025..031 pin the downgrade family). | Ruling recorded with the probe evidence cited; ledger gains the adjudication entry; if not (i), the /3 handshake re-cut under its own plan. | CLOSED |
| R1.3 | F-3 f61cb141 store.md §6.4 scheme + credential vocabulary | Design adjudication: (a) shipped design — bare cx-store:// = profile over TLS; cx-store+xsp:// = cleartext dev sibling, port explicit; identity via open-opts xsp-did + xsp-seed-env (seed ALWAYS an env-var name; URL userinfo refused at parse); (b) owner-directed alternative (e.g. different scheme names, config-file credential carriage, TLS-only with no cleartext sibling) — owner specifies, I spec-first it; (c) revert the scheme rows entirely (removes the shipped W6 client surface pending redesign). | Ruling recorded; §6.4 conformed under it; client behavior + tests conformed. | CLOSED |
| R1.4 | F-4 8f6832dd vp single-scalar carriage | Same evidence class as R1.2: a [vc] crossing the data-bin lane re-canonicalizes and its SIGNATURE dies (probed: [delegation d-vc-1 …] re-parses with a trailing-space id → bad-signature); M3 is transcript-signed so nested children hit the same W2 trap. (a) adjudicate shipped single-scalar [vp "<canonical text>"]; (b) alternative carriage the owner names; (c) revert (breaks W4 authority on the wire pending redesign). | Ruling recorded w/ evidence; §6.1 conformed under it. | CLOSED |
| R1.5 | F-5 40743e8e erased-marker-WINS | (a) adjudicate shipped rule (objects-get answers erased=true and never the bytes while the root awaits reclamation; objects-have keeps it missing — serving bytes would leak lawfully erased content); (b) strike the sharpening, restore prior §7b.1 (re-opens the leak window). | Ruling recorded; §7b.1 conformed under it. | CLOSED |
| R1.6 | F-6 d8d638b7 CSRP doc-frame (disputed classification) | Owner classifies AND adjudicates: the concrete [u16 hash_algo_code BE][digest32] layout + fail-closed rules landed same-commit with self-recorded authorization, under partial predating cover (manifest row 3, crypto-agility, ruling 1a codes). (a) classify as covered-by-manifest, adjudicate shipped layout (it repaired silent zero-padded hashes to binding clients; digest bytes unchanged; test-pinned); (b) classify as unauthorized (authorization written concurrently = the breach pattern), AND adjudicate the shipped layout on its merits (keep the fix, record the breach honestly); (c) unwind the frame re-form (re-breaks the binding-client defect). RECOMMENDATION REVISED 2026-08-07 to (b): the record's honesty is itself a campaign deliverable — partial predating cover does not make concurrent self-authorization authorized, and softening the classification to keep the record clean is the same defect one layer down. | Classification + ruling recorded. | CLOSED |

## Part 2 — Process-breach rows

| Row | Finding | Question / action | Acceptance criterion | Status |
|---|---|---|---|---|
| R2.1 | F-7 epoch corpus amended post-approval | REVISED 2026-08-07 — the epoch is the identity bedrock; the strongest affordable evidence is both lanes: (a) review packet (the 22 outputs of aa2a24c2 + the 12 re-pins of d8d638b7, each with before/approved-degraded/after values) PLUS independent re-verification of the AMENDED families (agents that did not do the amendment re-derive expected outputs for math/random/prof), then owner sign-off rests on both — recommended; (b) full-corpus re-verification (costlier; marginal over (a) given the R4.3 re-audit re-runs every executable gate anyway). | Packet delivered; scoped re-verification recorded; ruling + sign-off recorded. | CLOSED — RULED (a) 2026-08-08, owner: RATIFIED in the F6(b) one pass (packet S5 addendum = the evidence); I1 epoch corpus SEALED AS AMENDED |
| R2.2 | F-8 I4 installer exit-gate | (a) ratify the disclosed deferral AND make the closure MECHANICAL: I4 exit stands; tracker issue (sanitized, labeled) + the release-cut checklist/script gains a BLOCKING per-profile install-verification step (CX_PROFILE=<lean> must install from the cut artifacts or the release does not ship) — recommended (assets physically require a cut; a checklist gate is evidence, a tracker issue alone is intent); (b) reopen I4 exit until assets exist (blocks on a release cut by construction — performative). | Ruling recorded; issue filed; release gate step landed. | CLOSED — RULED (a) BY OWNER 2026-08-09 (post-exit review "1a"); ruling recorded f9e08765; tracking issue #752; the BLOCKING step live in BOTH lanes (release.sh phase 2 darwin — landed with the remediation wave, comment trued to the actual ruling date; release_linux.sh in-container — landed 2026-08-09, replacing advisory-only probes). #752 closes when the first cut publishes the assets |
| R2.3 | F-10 I0 premature done-claims; F-11 I3 deferral-before-ruling; F-12 I2 in-ledger self-ruling; F-13 W5 post-hoc deferral; F-14 I4 R2 riding amendment | Owner ruling on the CLASS: (a) acknowledge as recorded process defects, no unwind (each converged/was cured; all are now impossible under the rulings-before-edits protocol + the R4.1 gate); (b) owner names specific items from this set for individual unwind/re-posing. | Ruling recorded; any named items get their own rows. | CLOSED |
| R2.4 | F-13 specifically: migrate/clone erased-map → stream 20 | REVISED 2026-08-07: (a) confirm the stream-20 routing (it owns the SEK cut; stream 20 is INSIDE this campaign, so the campaign still delivers carriage) PLUS an interim fail-loud guard NOW (new row R3.16): migrate/clone of a store carrying erasure tombstones REFUSES loudly until stream-20 carriage lands — silent tombstone-dropping is the silent-partial anti-pattern and a lawful-erasure attribution loss — recommended; (b) pull full carriage into stream-4 remediation (duplicates stream-20's SEK design work). | Ruling recorded; R3.16 guard landed if (a). | CLOSED |
| R2.5 | F-25 W5 wave-gate validity ("G13 families green" vs missing G13 fixtures) | (a) rule the G13 fixture items (op-for-op parity table, error-identity table, cross-encoding parity) = W7 parity-gate scope; §9 "discharged" + the W5 done-when text corrected UNDER THIS RULING; W5 exit stands conditional on W7 delivering them; (b) reopen W5's gate now: build the G13 fixture families as remediation before any W7 work. | Ruling recorded; if (a): text corrected under ruling + W7 plan row amended; if (b): fixtures built + green. | CLOSED |

## Part 3 — Defect and gap rows (spec already clear; authorization to execute)

Default direction per register rule 3: implementation conforms to spec.
One batch authorization question covers execution; every row still
closes individually with its own evidence.

| Row | Finding | Work (fixture-before-fix) | Acceptance criterion | Status |
|---|---|---|---|---|
| R3.1 | F-20 M3 malformed vp silently ignored | Fixture first: nested [vp] at M3 → expect CXER5021 loud refusal (spec §6.1 text is unambiguous). Then fix sx_m3_vp_text option-none path to refuse, matching the phase=present lane. | New test red→green; both M3 and phase=present lanes pinned. | CLOSED |
| R3.2 | F-23 CXER5013/5016 (+5015) untested | Tests: attach to unknown/ambiguous mount → 5013; bad ::bytes image + ast_bin decode failure → 5016; an internal-fault lane for 5015 if constructible without mocks. | Each code has at least one wire-level test. | CLOSED |
| R3.3 | F-24 authority presentation-fault lanes untested | Wire tests through the profile listener: floor-cannot-present 5021; malformed-vp 5021 (rides R3.1); inert-root [presented compiled=0 inert=K]; cross-tenant CXER4805; wire CXER4703 escalation. | Each lane pinned over a real daemon. | CLOSED |
| R3.4 | F-26 code-verified, regression-unguarded behaviors | Tests: revocations-cursor resume; feeds-die-with-connection; deleted-replay body-absence (strengthen the weak assert); alias-retract shape; open-posture CXER5022; PEP-before-token-gate ordering; peer wrong-DID pin; origin-folds-own-journal; rate retry-after on the wire. | Each behavior pinned. | CLOSED |
| R3.5 | F-21 feed shape-acceptance quirks | Cutover posture (no dual-accept): multi-scalar [planes] refused loudly (or all scalars honored — whichever §5.2 says; if §5.2 is silent, this row escalates to a letter before code); name= on revocations cursor refused; stale comment corrected. | Off-spec inputs refuse loudly; tests pin. | CLOSED |
| R3.6 | F-22 F3 re-advert direct-push missing | MAKE THE SPEC TRUE (register rule 3): implement the direct advert push from the config-reload verb handler alongside the sweeper watch; test pins immediate re-advert on the reloading listener. (Reverse option — truing §7a.1 to sweeper-only — would be a spec edit to match a shortfall; not proposed.) | Direct push implemented + pinned; sweeper lane unchanged. | CLOSED |
| R3.7 | F-9 G18 --strict unwired | Wire scripts/cxer_registry_report.sh --strict into TEST_TARGETS (exits 0 today). Synthetic-violation check: an unregistered CXER in a probe branch fails it. | Gate in TEST_TARGETS; red-on-synthetic verified. | CLOSED |
| R3.8 | F-15 extraction-gate floor + 3 uncovered cases | Assert a case-count floor in the Make recipe (n_cases >= recorded); cover ch-005/cmp-005/sd-006 in a lane (probe sections or CLI); document the 5 md ABI-lane exclusions as intentional with the CLI-lane cross-reference. | Floor asserts; 3 cases compared somewhere; vacuous-pass probe fails. | CLOSED |
| R3.9 | F-16 CX_BLESS=epoch armed | Disarm: epoch-bless paths refuse unless an explicit build-time flag (-d cx_epoch_bless) is set; normal builds cannot bulk-bless. | Env var alone no longer blesses; test pins refusal. | CLOSED |
| R3.10 | F-17 ring-gate C-edge gaps | Widen the lane: relative ../<sibling> includes, @VMODROOT/../vcx/<sibling> forms, raw .c/.h scanning; narrow c_edge_allowed to the two exact known edges; add arrow/transport (and cmd_data/cli platform-free) lanes. Red-on-synthetic for each new class. | All probe bypasses from the audit now fail the gate. | CLOSED |
| R3.11 | F-18 profile-binary corpus lanes | REVISED 2026-08-07: FULL graded corpus through the cli and embed BINARIES (the I2 data-profile precedent ran 8978 pairs through the binary — the sample idea was a scope reduction). If measured runtime is genuinely prohibitive for TEST_TARGETS, that measurement becomes a LETTER with numbers (options: full-in-CI / full-nightly+sample-in-gate), not a silently smaller lane. | Binary lanes graded on the full corpus (or an owner-ruled letter with measurements); synthetic probe proves failure possible. | CLOSED |
| R3.12 | F-19 thrown-error auto-pass hole (inherited class) | Scope honestly: this is the historical #404-#407 class across THREE lanes now. Fixture-first repair in profile_gate.v + the two code_eval lanes: a thrown error only passes an out-err case when the code matches. Risk: may surface latent mismatches — each surfaced case triages as fixture-or-code under fixture-before-fix. Also: stop discarding cmodule_gate. | Thrown-vs-expected mismatch fails all three lanes; surfaced cases triaged. | CLOSED |
| R3.13 | F-27 I3 census off-by-one; F-28 I2 proof-claim; F-29 "standing" label | Ledger corrections (process docs): each corrected in place with a dated correction note citing this register. | Corrections landed. | CLOSED |
| R3.14 | F-30 cosmetic spec/impl deltas | Each is a spec-vs-impl divergence → per register rule 3 the default is conform-the-impl: drop the extra request= attr from [erase-result] (or owner rules to spec it); move the G8 group-from refusal pin into the corpus; emit generation= as the spec'd attr (keep child during migration? NO — cutover rule: attr only). Any row where the owner prefers the impl's shape escalates to a letter. | Impl matches spec text exactly; pins updated. | CLOSED |
| R3.15 | I5-s4 auditor's unverifiable externals | Verification pass in the two external repos (console conform §13b, web-client /3 lane) — re-run their gates, record results here. | Results recorded (green or filed). | CLOSED |
| R3.16 | R2.4 interim guard | Until stream-20 erased-map carriage lands: store-migrate/store-clone of a source carrying erasure tombstones (E-records) refuse loudly (CXER code per store.md's refusal conventions; fixture-before-fix). Removed by stream 20 when carriage lands. | Refusal pinned by test; stream-20 row references removal. | CLOSED |

## Part 4 — Structural enforcement + resumption

| Row | Item | Question / action | Status |
|---|---|---|---|
| R4.1 | Mechanical spec-freeze gate | (a) repo gate (pre-commit + TEST_TARGETS lane): any commit touching normative spec paths (spec/03-approved/**, working feature specs) TOGETHER WITH implementation paths hard-fails unless the commit message carries a ruling token (RULED:<row/letter/date>) that matches a recorded ruling in the ledger/register; ledgers (spec/02-working/partition_*) exempt; (b) rules-only, no mechanical gate. | CLOSED — RULED (a) BY OWNER 2026-08-09 (post-exit review "2a"; ruling f9e08765). The gate had landed with the remediation wave (scripts/spec_freeze_gate.sh, TEST_TARGETS `spec-freeze-gate`, epoch f964c16a) under the recommended option; hardened AT the ruling (851d2e52): the token must now name a RECORDED ruling (fragment match against the ledgers/register — unrecorded token = violation) + red-on-synthetic selftest (tokenless-mixed RED, unrecorded-token RED). Clean over f964c16a..HEAD |
| R4.2 | Rulings-before-edits protocol | Standing: every ruling is COMMITTED (ledger/register) before the work it authorizes begins; same-commit recording is a violation by definition. Already memorialized in standing memory; register rule 5 applies it here. | STANDING |
| R4.3 | Independent re-audit gate | After Parts 1–3 close: a fresh adversarial verification pass (same method as this audit — agents that did not do the remediation) over every CLOSED row's evidence + a full make test wave gate. Nothing resumes before it reports clean. | CLOSED — CLEAN 2026-08-08 (1f3330bd): 24 rows closed; full `make test` rc=0; THREE independent fresh-agent adversarial re-audits, zero refutations |
| R4.4 | Resumption ruling (R-final) | Owner rules whether W7 resumes, and under what scope, ONLY after R4.3 reports. No pre-commitment. | CLOSED — RULED (a-revised) 2026-08-08: two-listener parity (XSP profile + gRPC edge), local embedded engine = the oracle; DELIVERED at S6.3/S6.5 (G13 battery; stream-4 exit, ledger entry 14) |
| R4.5 | Durability | Push impl/I5-stream4-xsp-store (audit + register commits) to origin so the record survives the machine. | CLOSED — DONE/MOOT: pushed 2026-08-08 and continuously since (every wave; exit stack at ca379c02) |

**Wave-gate note.** W2–W6 wave gates were claimed under the now-broken
process. The audit found their TECHNICAL claims sound where verifiable
(no weakened tests, epoch intact, gRPC byte-stability true) with the
exceptions carried in rows R2.5 (W5 done-when) and R3.x (coverage). The
R4.3 re-audit + full gate re-run is the compensating control: every wave
gate's executable portion re-runs before resumption.

**2026-08-08, owner (second adversarial audit — the S2 premise failure; ruled (b)):**
- **AUDIT FINDING (self-audit, conducted at owner direction):** the S2
  rip-out was built on an UNVERIFIED empirical premise. F1's "code is a
  document, stored by document identity" was declared "empirically
  proven" from unrepresentative round-trips (defs simple enough to
  survive data-canonicalization); the F2 survey ASSERTED "the def's
  canonical byte form is the missing referent" without executing the
  round-trip; the shipped dir-sync example (a def with a string-literal
  body) mangles through put-doc-text — data canonicalization is correct
  for structured data and WRONG for code's concrete syntax. The old
  put-def was not code-special identity storage; it was the store's
  ONLY verbatim path, mis-keyed by computation identity. Same
  premature-done-claim class as the original I0-I5 audit; the freeze
  gate does not catch it (it gates authorization, not evidence).
- **RULED (b): REVERT AND RE-DERIVE CLEAN.** The uncommitted destructive
  rip-out discarded; the S2 additive commit 1b4fd26b REVERTED (b93c3cce)
  — its re-expressed store-code-001 embedded the same unrepresentative-
  test premise. Tree restored to S1 (ed2c7fa8 + revert).
- **PROCESS RULE (adopted with (b), standing):** any ruling resting on
  an empirical claim ("X holds") requires a COMMITTED test/probe proving
  X BEFORE the ruling is recorded — evidence-before-ruling, the
  empirical twin of rulings-before-edits. Applied immediately to the
  re-derivation below.
- **RE-DERIVATION PLAN (evidence first):** (1) committed probe battery:
  representative def/document classes (simple, string-literal body,
  comment-bearing, nested, module-of-defs) through every storage path
  (put-doc-text, the object layer, raw file) recording byte-exact vs
  normalized per path — the evidence table; (2) F1' letter POSED on that
  evidence: documents split by identity rule into STRUCTURED (identity =
  canonical bytes; normalization meaningful) and OPAQUE (identity = raw
  bytes; code, images, plain text — byte-exact round-trip); code is an
  OPAQUE document; the store needs a general verbatim surface (the
  capability the put-def wart was masking); (3) owner rules F1'; (4) F2
  re-run with executed checks; (5) the rip-out re-executed under the
  corrected premise.
- **F1' (a) — RULED (2026-08-08, on the committed evidence battery).**
  Documents split by IDENTITY RULE: STRUCTURED (identity = hash of
  canonical bytes; canonicalized round-trip is the contract) and OPAQUE
  (identity = hash of RAW bytes; byte-exact round-trip; code, images,
  plain text). Code is an OPAQUE document. The store gains the general
  verbatim surface put-blob/get-blob (the capability the put-def wart
  was masking); EVERY storage path verifies key == hash(raw bytes) on
  load — the skip-verify class cannot return. A persisted record-kind
  discriminator selecting WHICH hash rule verifies is principled under
  F1' (part of the identity rule, self-verifying) — unlike the retired
  'C' kind, whose key was not the hash of the stored bytes. Execution:
  the verbatim surface lands additively first (spec+impl+fixtures,
  RULED: F1'); the rip-out then re-executes (put-def/get-def retire,
  legacy 'C' refuses loudly per A3, [$cx:computation-id] per A2);
  dir-sync byte-exact round-trip is the acceptance fixture. Columnar
  (#744, uncompilable pre-existing) gains blob handling as part of
  that issue's fix, noted there.
- **F1' ADDITIVE SURFACE LANDED (2026-08-08, RULED: F1').** put-blob/
  get-blob across every live substrate: mem, pack manifest ('B' record),
  flat index ('B'), object-per-key/sqlite/s3 (graph manifest 'B' with
  rehash-verify at load), migrate carries blobs kind-preserving through
  the verifying channel. Evidence, all committed and green BEFORE this
  entry: conformance store-blob-001..004 (byte-exact greet-def round-trip
  — the F1' acceptance program — no-canonicalization, dedup, absent →
  CXER1121); store_blob_surface_test.v (pack + flat reopen persistence,
  migrate, and a corrupted-record read REFUSING CXER1120); sqlite reopen
  round-trip run live under -d cxstore_sqlite (whose build had been
  broken since W5 — dup helper, fixed ec55e624); guide-check backing the
  fn-docs; spec store.md §4 identity-rule split + verb/capability rows.
  The rip-out re-execution is next.
- **S2 RIP-OUT RE-EXECUTED (2026-08-08, RULED: F1'+A2+A3+A4).** In order:
  (B) [$cx:computation-id] + cx.md rows re-landed verbatim from the
  reverted 1b4fd26b (that portion was sound); store-code-001 re-derived
  under F1' — opaque carriage (put-blob), the string-literal-body
  representative, identity preserved because the bytes are; 002..010
  taken verbatim (pure pairs, truth values pinned). (C) put-def/get-def
  verbs, cx_code_store_put_def/get_def, store_put_raw, and every code:
  special-case removed; legacy records REFUSE LOUDLY on every substrate
  (flat D-with-code:-key at store_read_index, graph 'C' arm, cxpack
  manifest 'C' arm) — pinned by store_legacy_code_refusal_test.v (both
  persisted formats, crafted on disk); A4: xap-dist exports identity=
  recomputed via the pure relation, claim spelled computes-as: —
  pinned by xap_dist_exports_identity_test.v (match, alpha-variant
  match, mismatch refusal; the check previously had NO live consumer);
  dir-sync example + store_dir_sync_test.v carry the ruled acceptance
  fixture (restored greet.cx BYTE-IDENTICAL to source, sample re-pinned
  to the single-quoted mangling-prone spelling); store.md/cx.md/
  xap market spec/guide §18/store-embedded.md conformed;
  code_identity_store_test.v + store_code_persist_test.v deleted.
  Green: fixture battery, dir-sync acceptance, 7 store batteries,
  refusal + exports pins, guide-check, verify-doc-blocks,
  check-code-spec-consistency, -d cxstore_sqlite build.

**2026-08-08, owner (S3 premise correction — the gRPC edge's authentication; ruled G1/G2/G3):**
- **FINDING (surfaced mid-S3, evidence-first):** the demolition map's
  "store_authz.v: only non-test consumer is the HTTP bearer plane" was
  textually true but functionally wrong — the gRPC edge authenticates
  THROUGH that plane (store_grpc_serve.v feeds `authorization` metadata
  into svc_handle_request), and cxstore-grpc.md §4 pins it normatively
  ("the same authenticate → Principal → authorize path as CSRP").
  Deleting the plane as mapped would have left the gRPC edge
  unauthenticated. Work STOPPED for a ruling instead of silently
  weakening or silently keeping.
- **RULED (b): re-base the gRPC edge onto XSP-AUTH — ONE authority
  calculus, now.** The owner rejected the keep-bearer-for-grpc interim
  (expedience-bias class, same as the R1.1 correction): CX has no
  external users, so the cutover is free now and breaking later.
  Bearer/RBAC, store_authz.v, and the static/JWT/DID/OIDC provider
  matrix retire everywhere.
- **G1 (a) — per-call presentation.** The gRPC `authorization` metadata
  carries the PROFILE's credential form: the delegation chain + an
  ed25519 signature binding the presenting DID to THIS call (op, body
  hash, timestamp, nonce), verified by the same delegation-compile +
  capability-grammar + PEP path the profile uses (store_xsp_authority.v)
  — no session state on the edge, no second implementation. Freshness
  window + nonce replay cache bound re-execution.
- **G2 (a) — [xsp [grants]] is the ONLY grant table.** The `[auth …]`
  config block is a HARD config error naming the retirement
  (cutover-first, no dual-accept). Operator intent = delegations, one
  calculus (§6.1).
- **G3 (a) — bootstrap HTTP = health/ready/metrics/capabilities ONLY.**
  mounts/config-reload ride the profile admin ops; /metrics is
  unauthenticated operator-plane (bind address is the operator's
  control), posture stated in the spec. cxstore-grpc.md §4 rewritten
  under these rulings (RULED: G1+G2+G3).
- **S3 EXECUTED (2026-08-08, RULED: R4.4-a + G1a + G2a + G3a).** DELETED:
  store_csrp.v, store_csrp_wire.v, store_csrp_binary_route.v,
  store_csrp_client_bin.v, store_authz.v (bearer/RBAC + the
  static/JWT/DID/OIDC provider matrix), the csrp-handle verb + def +
  fn-doc + corpus case, `cx store-token`, and the CSRP-subject tests
  (csrp, csrp-conformance, csrp-wire-tagged, binary-wire, authz×2,
  keepalive, token, grpc-vs-csrp parity, discovery). RETIRED SCHEMES:
  cx-store+http(s) refuse at open naming the live wires; csrp_scheme →
  service_scheme (xsp+grpc only). REDUCED: store_service.v HTTP =
  bootstrap-only (health/ready/metrics/capabilities; data/admin 404
  CXER1709); [auth …] config = HARD error (G2a); data ops reach the
  daemon ONLY as the gRPC edge's pipeline="profile" synth; mounts/
  config-reload served under the edge gate; reload hot-sections drop
  'auth'. BUILT (G1a): per-call XSP-AUTH for the gRPC edge —
  store_grpc_call_auth.v (CxCall credential: ed25519 over the canonical
  call binding did/at/nonce/path/body-sha256; freshness window + nonce
  replay cache; optional [vp] chain compiled through sx_present_locked —
  the SAME profile code path; posture mirrors §6.1: grants ⇒
  deny-by-default, none ⇒ open with the admin mutual-gate analog);
  client half signs from open-opts identity (xsp-did/xsp-seed-env,
  shared with the profile client; grpc URL userinfo refused).
  RE-HOSTED ONTO THE WIRE (owner course-correction mid-stage: THE store
  wire is the XSP profile; gRPC is the integration edge — an earlier
  grpc-by-default re-host was reverted): fabric journal mounts,
  xap registry serve-real (§4.2 re-host now proven over cx-store+xsp),
  remote-alias family — all live green over the profile. gRPC keeps
  edge-subject tests only (call-auth battery: bind/replay/signer/
  posture pins; dispatch; client; e2e; admin-edge shapes). Specs
  conformed same-commit: cxstore-grpc.md §1/§2/§3/§4/§6 (per-call
  XSP-AUTH normative; bearer gone), store.md §2 wire row + §6.2/§6.4
  retirement note. Deferred to S4 as ruled: 17xx band renaming +
  cxstore-remote-protocol.md retirement + corpus/spec deprecation
  sweep (the 17xx codes remain live transport-independent op codes).
  New pins: store_grpc_call_auth_test.v, url-userinfo redaction unit,
  bootstrap-404, no-[auth]-advert, auth-section-rejected.
- **S3 BINDINGS CUTOVER (owner course-correction #2 — "why can't xsp
  speak s3?"):** the Go/Python/Rust StoreClient façades were already the
  one-implementation shape (CX programs through cx_code_eval_caps — the
  CORE client does the wire; no protocol re-implemented per language),
  so the earlier bindings-need-gRPC-clients framing was WRONG twice
  over: nothing needed a new wire client at all. Cut over in place:
  accepted schemes = cx-store:// + cx-store+xsp:// (retired tokens
  refuse with the live-wire pointer); bearer token param → XSP-AUTH
  identity (did + seed-env mapping onto the core's open-opts; the seed
  never rides a URL or a literal); explicit host:port demanded so the
  net grant is always exact. Tests re-hosted onto a real store-serve
  [xsp] daemon per language: CRUD+query+iter round trip, missing-hash,
  retired-scheme refusal, and the XSP-AUTH deny/admit lane (mutual
  daemon refuses anonymous; the granted DID round-trips) — 4/4 green in
  each of Python, Go, Rust. The client-server example rewritten onto
  store-serve + cx-store+xsp (runs green); guide §18 conformed (the
  "CSRP canonical, permanent" row was actively false). gRPC remains the
  integration edge for systems that cannot embed libcx.
- **S4 CLOSED (2026-08-08, RULED: R4.4-a) — deprecation sweep.** The
  false-normative-prose completions of the retirement: cxstore-remote-
  protocol.md flipped Current→RETIRED (historical banner pointing at the
  live wires; the "remains normative for the transitional listener"
  claim was false once the listener was deleted; the 742-line body
  preserved unedited as the removed-protocol record); governance
  CXER1700-1712 row → RESERVED (retired, never reused; the op contracts
  carried to the profile CXER50xx); store.md cross-ref marked retired;
  conformance store-022 re-pointed to cx-store+xsp (was a retired-scheme
  cap-deny); gates.cxd reason prose "loopback CSRP socket" →
  "XSP-profile socket". Green: fixture lane, spec-freeze,
  check-code-spec-consistency, cxer-registry, verify-doc-blocks.
  DEFERRED (tracked, not false-prose): the generated
  docs/guide/lib-store.html regen (a build artifact — `make docs` drops
  the stale csrp-handle section; the SOURCE guide §18 is conformed).
  S1-S4 COMPLETE; S5 (epoch ratification F6) + S6 (pushdown F3/F4/F5)
  remain, owner-sequenced.

**2026-08-08, S5 (epoch ratification prep — R2.1 + F6(b), evidence for the one-pass sign-off):**
- **Packet re-verified four ways at HEAD** (partition_epoch_amendment_
  packet.md S5 addendum): (1) all four commit-map anchors re-run
  verbatim, hold; (2) per-case archaeology — 24 Part-1 blocks × 3
  states re-extracted, 96/96 mechanical asserts (restorations
  byte-identical non-vacuously; math-116 absent/absent/present
  gate=enforced); (3) all 12 Part-2 re-pins + 2 conditions + the
  sha256: rejection reversal verified against d8d638b7's actual diff;
  (4) LIVE re-derivation — 23/23 executable amended cases reproduce
  their blessed outputs by direct `cx <file>` execution at HEAD
  (prof-018 gate=skip as documented).
- **Reconciliation recorded** (packet §C–§E): math/random byte-identical
  to AFTER; prof's one later amendment = R3.12 input-only re-spells on
  four disjoint cases; Part-2 subject disposition under the S3
  demolition (5 files deleted under RULED R4.4-a+G1a+G2a+G3a, survivors'
  pins live); the F6(b) fold enumerated — every post-seal conformance
  commit attributed to its recorded ruling/gate, the F1'/A-series
  identity-corpus correction itemized (store-code-001..010 bodies
  re-expressed, truth values kept; store-blob-001..008; the two
  retirement roster moves; A3/A4 V-battery pins).
- **Two defects the S5 gate re-run surfaced, both FIXED (352619d5):**
  (a) retry-classifier FALSE GREEN — a NUL-bearing failure dump turns
  the suite log binary and GNU grep silently drops lanes from the
  retry roster (observed live: store_xsp_serve_test's runtime failure
  dropped while the banner claimed every lane green). Fixed grep -a +
  a loud extracted-vs-summary count crosscheck in BOTH suite lanes;
  red-on-synthetic proven under the devbox grep (old: 0/2 extracted,
  crosscheck REFUSES; new: 2/2). (b) the R3.4 origin-fold lane pinned
  INSTANT refusal where §7.1's contract is bounded (feed-lag-ms=250,
  next-pep-check) — nondeterministic by tick phase (~2/6 green;
  diagnosed with timestamped pump/fold/present instrumentation,
  reverted); re-pinned poll-until-refusal within 2s, 5/5 green. The
  PRODUCT conforms to its spec — no product change (one stale
  "post-dispatch" comment conformed).
- **Full `make test` rc=0 @ 352619d5** (post-fix re-run): lone FAIL =
  the standing #572 -usecache flake, green on the classified retry
  with the crosscheck live; extraction gate 1564/1564 both ABI lanes
  byte-identical + 8978 CLI pairs; libcx-abi-gate 713/I3-baseline.
- **R2.1 status: packet + addendum POSTED; awaiting the owner's one-pass
  ratification (F6(b)). S6 (pushdown F3/F4/F5) does not start before it.**

**2026-08-08, owner — R2.1/F6(b) RULED (a): RATIFIED.** The epoch
amendment packet's two commits AND the corrected identity corpus
(packet addendum §E enumeration) are ratified in the one pass F6(b)
prescribed. The I1 epoch corpus is SEALED AS AMENDED. R2.1 CLOSED.
Consequence: S6 (the pushdown implementation phase) is UNBLOCKED under
the standing foundational rulings F3(a) (fold/replay fns cross as def
DOCUMENTS by document address + a computation-identity claim the
daemon recomputes and refuses on mismatch; dependency closure = more
documents; no special fn carriage), F4(a) (every daemon-side
evaluation under an operator-configured step limit + memory ceiling,
loud typed refusal, never a takedown; per-principal delegable budgets
= a LATER layer, not built now), F5(b) (client-signs default — the
key never travels; the APPOINTED-SIGNER capability specced in the
same pass through the existing credential model; snapshot-verify is
pushdown-safe; no daemon self-attestation), and R4.4(a-revised) (the
correctness oracle = the local embedded engine + the profile's own
fixture families; TWO listeners — XSP profile + gRPC edge).
