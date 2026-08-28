# Rulings 2026-08-28 — row-set runtime performance campaign (#1080–#1083)

Owner directive (2026-08-28): profiling a CSV row-set workload exposed three
algorithmic defects plus one semantics bug; "open one GitHub issue per finding
with the evidence below, then fix them", with named acceptance criteria
(corpus green; bench/ regression guards for all three; post-fix targets:
re:replace per-call cost independent of match count, n=4000 single-key sort
well under 10 ms, n=2000 distinct-key group-by well under 10 ms). All four
findings were re-verified in source AND by re-running the supplied
micro-benchmarks on release/0.18 @ 6f0cc8a6d before filing.

Execution letters, recorded before the work (standing letter-acceptance
order applies):

## RP-1 — re compile reuse (#1080) (RULED: RP-1 = a)

- (a) **Two stages, both landed together.** Stage 1: hoist compilation out
  of the `re_collect_matches` loop and out of every per-call compile site
  (`re2_match_at`-style entry points gain compiled-handle variants); one
  compile per op call. Stage 2: a process-wide bounded LRU keyed on
  (pattern, effective flags) behind the re2 shim, so ops on a compiled
  `[regex …]` value reuse a live RE2 handle. The opaque value model is
  UNCHANGED (the element still carries pattern+flags only — the cache is an
  implementation detail behind the shim, which is exactly what re.md §3
  promises: "no internal compile cache" refers to compile-call memoization
  of the VALUE, and the fixed header comment in stdlib_re.v stops
  misquoting it). Thread-safety: RE2 match on a compiled object is const;
  the cache map is mutex-guarded and entries are REFCOUNTED — eviction
  destroys a handle only at refcount zero (a doomed flag defers destroy to
  the last release), so a reactor thread mid-match can never see a
  use-after-free. No spec edit.

## RP-2 — order-by sort (#1081) (RULED: RP-2 = a)

- (a) **Stable bottom-up merge sort** replacing the O(n²) insertion sort,
  plus the optional collapse: a run of CONSECUTIVE order-by clauses is
  evaluated as one multi-key stable sort with the LAST clause as primary —
  byte-equivalent to the sequential stable re-sorts it replaces (stable
  sorts compose right-to-left), preserving the emergent last-clause-wins
  semantic the owner named. Keys stay Schwartzian (evaluated once per
  frame per clause).

## RP-3 — group-by partition (#1082) (RULED: RP-3 = a)

- (a) **Hash-assisted partitioning that never substitutes for
  `nodes_equal`**: buckets are keyed by a discriminated canonical string,
  and members within a bucket are still confirmed with the same structural
  `nodes_equal` used today (#753) — the hash only prunes the candidate set,
  so grouping behavior is IDENTICAL by construction even where canonical
  strings and structural equality might disagree at the margins.
  First-appearance group order stays pinned (L94). The eager `$group`
  materialization is kept for this wave (the γ contract of code.md §7.2
  binds `$group` eagerly); lazification is follow-up material if ever
  needed — the acceptance targets are met without it.

## RP-4 — $group phantom member (#1083) (RULED: RP-4 = a)

- (a) **Fix, not document**: the group materialization omits the binder
  child when the bound value is ABSENT (the empty sequence), per the #584
  presence rule ("an absent item contributes no child") and the
  null-absence-conflation gate's spirit. `[$count $group/x]` becomes honest
  (phantoms gone); `[$sum $group/x]` is unchanged (the phantom contributed
  nothing). Conformance fixtures pin the corrected shape AND the unchanged
  M5 aggregate shape before the fix lands.

## RP-5 — [?match] wide-literal dispatch (#1094, owner-added mid-campaign) (RULED: RP-5 = a)

Owner directive (2026-08-28, verbatim): "we want match to be idiomatic cx
where its a good fit without a performance hit." Measured before work: the
#850 bridge retirement had already reduced the 2026-08-18 pathology
(20-45µs/arm, 500×) to ~0.55-0.65µs/arm — but a 40-arm literal match still
ran ~2.2-2.6× an equivalent [?if [=]] chain because match_arm_pattern paid
a FULL env clone (#871 rollback isolation) per arm attempt, matching or not.

- (a) **Bind-free arms skip the clone**: scalar-literal and wildcard `_`
  case arms are tested directly (the same scalar_literal_matches the
  pattern path bottoms out in) and evaluate :where/:yield in the parent
  env — exactly the envs :when/:else arms already use. Binding-capable
  patterns (element shapes, collections, $binds, path-cases) keep the
  clone unchanged. RECOMMENDED and taken: semantics identical by
  construction; measured at parity with the if-chain after (ratio ~0.96).

## RP-1 mechanism note (execution)

The RP-1 cache first landed thread-local (mutex-free); under -gc e the
collector does NOT scan thread-local globals and the cache was collected
under a live borrow (garbage handle panic in re2_match_at_handle). Final
mechanism = the ruled (a): REGULAR global (rooted), mutex-guarded,
refcounted borrows, eviction only at refs==0, compile outside the lock
with a lost-race destroy. Recorded here so the -gc e thread-local-roots
trap is in the ruling record, not just the code comment.

## Evidence base (measured 2026-08-28, this machine, under background load)

- re:replace per 2,320 calls: 29.7 ms (0 matches) / 179.2 ms (8) /
  3297.9 ms (200) — linear in match count.
- order-by n=500/1000/2000/4000: 3.3/5.1/17.2/65.4 ms — quadratic tail.
- group-by same n: 2.5/6.0/15.5/49.1 ms — quadratic with distinct keys.
- #1083: sum-direct=4, count-direct=3, count-per-item=2 on the 3-row repro.
