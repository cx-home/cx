# Ledger — #787 integration: the ONE rebase of impl/787-poc onto release/0.16.0

**Date:** 2026-08-19. **Session:** dedicated Fable 5 integration session, per the
owner's integration ruling (2026-08-19, "1a 2a", recorded in
design/787/audit2/AUDIT.md context and memory): ONE rebase, not a cherry-pick
trail; conflict/fixture adjudications are mini-rulings recorded here; the
`[$present]` rider rides this rebase per DP4 (i); #864 stays named
release-blocking; from the rebase onward only the merged release/0.16.0 tree
counts.

**Span:** merge-base e7816a77 → 78 commits (ours) replayed onto
origin/release/0.16.0 @ ac8c5661 (60 new upstream commits).

## Ruling citations consumed by replayed commit messages

The spec-freeze gate requires a `RULED:` token on any commit touching both
`spec/**` and implementation, resolvable in `ledger/**`. Two replayed commits
carry spec+impl by owner-ruled authorization recorded (before their work) in
`design/787/` — this file makes those ids resolvable in the store:

- **DP4-h** — DP4 letter (h), ruled as recommended by owner in
  design/787/dp4/DP4.md §9 (2026-08-18): fd=/handle= handle-shape unification;
  term.md §3.6 states it. Consumed by the W23 shell commit
  (spec/03-approved/std-lib/term.md + vcx).
- **DP1-4b** — DP1 ruling 4b (owner, 2026-08-17), provenance stated in
  spec/02-working/xap_grammar_composition.md §6.1: N-COMPOSE-7, the intent's
  parameter list. Consumed by the W7 commit
  (spec/02-working/xap_grammar_composition.md + impl).

Also resolvable from here: **DP4-i** (design/787/dp4/DP4.md §9, ruled as
recommended): the `[$present]` rewrite of `ux:found`/`ux:seq-child` lands at
this rebase (the rider below).

## Integration mini-rulings (IR)

- **IR-1 `third_party/v`.** The branch's machine-absolute symlink
  (worktree -prod workaround, W5 commit) does NOT survive integration; the
  submodule gitlink @ `b3d0da670d` (the #864 type-table-validation fix +
  #855) wins. A machine-local path is workstation state, not source; #864 is
  release-blocking and its pin is upstream's.
- **IR-2 `term:select` handle resolution.** Upstream #852's structure wins
  (`term_source_fd`: refuse-not-skip, registry ids resolved by element name —
  the fd= value is not a descriptor on net handles); our DP4 (h) `[file
  handle=N]` process-stream resolution joins it as an arm via
  `io_handle_raw_fd`. Per the landed term.md §3.6 sentence, a `[file …]`
  handle backed by a buffered os-level file is SKIPPED (not refused) — the
  spec text is the truth; every other unresolvable source refuses per #852.
- **IR-3 `services_listener` #838 double-fix.** Merged shape: upstream's body
  semantics win (empty body stays ABSENT — forwarding `''` would mint a
  `[body '']` vs `[body ()]` lane divergence, exactly the class #838 closes);
  our headers forwarding wins (wire headers reach `$request/headers`; §10.3.3
  states the field normatively and actor stamping needs the session cookie).
  Upstream's comment paragraph calling the headers absence deliberate is
  superseded by the ruled headers rationale.
- **IR-4 `xap_grammar_composition.md`.** Union: both summary-table row edits
  (V gains the parameter list §6.1; N gains the source list §4.1), upstream's
  §4.1 + W5 row (#840), ours' §6.1 + acceptance renumber (N-COMPOSE-7).
- **IR-5 auto-merges accepted.** `term.md` (disjoint hunks: upstream §1
  x/term.md pointer + TLS caveat; ours §3.6 sources), eval.v (our
  http_sse_receive arm alongside upstream #853/#847/#859 changes),
  delayed-shipment.feature.cxd (upstream #840 `[from …]` list; ours DP1-4b
  intent parameter lists). Verified by build + suites, not by eye alone.

## Rider landed with this integration

- **DP4 (i)**: `[$ux:found]` rewritten over upstream `[$present]` (#854) —
  recorded as ruled at DP4 §9, scheduled "at the release/0.16.0 rebase",
  i.e. here. The def stays as a thin delegation (its vocabulary name has
  ~55 call sites across all three faces and the harnesses); the workaround
  body retires.
- **IR-6 disposition on `[$ux:seq-child]`** (the letter names it too): the
  def is NOT a presence workaround — it discriminates sequence-vs-element
  by name-emptiness (its body never used `[$exists]`/`[$absent]`; W5
  history confirms it was name-based from birth), and `[$present]` cannot
  express it (`[$present ()]` is false where `seq-child` must answer true).
  A literal rewrite would break every walk on all three faces. It stands
  unchanged; the audit's T2 bundled it by adjacency, not by content.
  FLAGGED for owner review with this record.

- **IR-7 fixture-collision adjudication (the anticipated class).** Eight
  generated ux fixtures (tui-022, web-007/011/014/017/018, ux-102/103)
  bundled sub-results INCLUDING bare err values with `[list …]` — authored
  before R5.13 landed upstream. Under the ruled err-propagation position
  table (#853: call-operand errs PROPAGATE, sequence items are CONTAINED),
  a `[list …]` holding an err collapses to that err. The bundling moves to
  the sequence literal — the ruled contained position; the cases' subjects
  are untouched. Regenerated by design/787/tools/gen_ux_fixtures.py (the
  campaign's only golden channel); diff reviewed case-by-case: exactly the
  eight, plus singleton-sequence items flattening per the ruled #810
  singleton behavior. The regeneration also confirms the DP4 (i) rider
  moved ZERO goldens.

## Integration finds (fixed in-line, recorded)

- The intent wire fed `$request/body` straight to `[$url:query-parse]`;
  upstream's ruled absent-body shape (IR-3) reaches the directive lane now
  and the confirm forms legitimately post no fields — serve.cx folds
  absence to no-fields. Five drive steps (22/23/24/29/37) were red on
  exactly this; 38/38 after.
- keys.cx's send-q-then-wait quit protocol deadlocked once liveness became
  real (#852's fix means the shell truly hears its feed; a frame can exceed
  the pty buffer; a consumer that stops reading before wait() wedges the
  child in write()). quit-shell drains to EOF; only EOF or the round bound
  ends the drain.
- **Silent-gate sweep (ruled during the #868 review).** The guide-quickstart
  find (store/serve.cx logged the boot gate's refusal with the err as a bare
  call operand — under R5.13 the `$log:error` call PROPAGATES, the err
  dissolves in the `?let` binding, and a refused surface boots silently) is a
  CLASS, not a one-off. Swept the tree before the 0.16.0 cut: exactly three
  `[$ux:check-surface]` gate sites exist; the store one was fixed in-line,
  and the two earlier-wave demo servers (w1/serve.cx, w5/shop/serve.cx)
  carried the identical silent arm — both moved to the ruled contained
  position (`[$cx:canonical ($gate)]` inside `[$concat …]`). Every other err
  arm in design/, x/, scripts/, tooling/ uses destructured string attributes
  or returns literals — no bare err-value operands remain. Both demo servers
  boot with the agree line after; the w1 refusal arm was provoked live
  (route dropped from the accounted list) and logs
  `error ux/W1: surface refused — ([err code=ux-refused …ux-route-unserved path=/orders…]`.

## Exit gates (the ruling's own)

1. 787 suite on the rebased tree: drive/keys/voice/nokernel/diff green +
   `make test-vcx-suite` 68/68 GATE-RC=0 outright, twice.
2. Full `make test-vcx` GATE-RC=0 on the rebased result (spec-freeze gate in
   the lane).
