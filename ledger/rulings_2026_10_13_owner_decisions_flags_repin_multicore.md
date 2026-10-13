# Owner decisions 2026-10-13 ~05:0xZ–07:0xZ — the product build flags, one binary shape for every bar, the red re-pin held, bounds checks kept, the Python baseline's patch level, the worker pool, ep-2's c10k rows, landing authority; and the morning's four: the evaluator's value representation into v0.18, the call-path cuts, the record-shape trigger fired, the multi-core epic

**Status: RULED (owner, 2026-10-13, in session on ep-2, on the numbered letters as posted; recorded by the session the same hour).** Issues: cx-home/cx-private#1928 (flags, hardening), #1922 (re-pin), #1923 (multi-core), #1924 (call path), #1925 (record shapes), #1926 (value representation), #1927 / cx-home/v#42 (pacer), cx-home/cx-examples#392 (Python baseline).

## The owner's words, verbatim

"2a" (the value representation into v0.18) — "3 seems we wait on this" — "4 do it v0.18" — "5 what? 'letter is due' is not our terms. Get this fixed! v0.18" — "we want go level or better performance with v2.0 or earlier" — "1a 2a 3a v0.18 4a 5a 6a 7a" — "a" (landing).

## FLAGS-1 — the product cx is compiled `-O2` with profile-guided optimization, in place of `-Os` (Letter 1 = (a); #1928)

`-Os` dates from an April "production-optimised builds — -Os + strip" commit with no ruling behind it. Measured on ep-2 at one sha (13b95ca04), `-Os` against `-O2`, interleaved, three rounds: csv-aggregate −11.8 %, json parse +13/+14 %, json emit +21/+26 %, sql insert +12.7 %, template-render +7.3 %, c128 +4.1 %; memory +1-3 % on the batch rows, −15.7 % at c10k; binary 19.2 → 23.3 MB. The owner's rule (#1884) holds on every row. PGO (an instrumented build, a training run over the conformance corpus and the workload shapes, a profile-use build) is the second step; a stale or missing profile fails the target, never falls back silently. Rejected: (b) `-O2` only (leaves the measured second step on the table); (c) keep `-Os` (a size choice on a binary whose size is not a bar).

## HARDEN-1 — the loop and CI build the product with the Nix hardening set off: one binary shape for every bar (Letter 2 = (a); #1928)

Under devbox the Nix clang wrapper adds `-fzero-call-used-regs=used-gpr`, `-fstrict-flex-arrays=1`, stack-clash protection and the rest of `NIX_HARDENING_ENABLE`; cx-private's Makefile stripped only `fortify fortify3` (ruling 1227). The ep-2 pin and the Linux release carry none of it, so dev2's perf-pair rows and the 10 % bars were measured on a hardened binary and the re-pin check and the ledgers on an unhardened one. The Makefile now exports an EMPTY `NIX_HARDENING_ENABLE` whenever the variable is defined (to the wrapper, empty means all hardening off). The soundness instruments are the oracle gate and the sanitizer builds (#1923), not hardening flags on the product. Rejected: (b) harden the pin and the release too (a slower product for a mitigation the sanitizer builds supersede); (c) leave the split.

## REPINHOLD-1 — cx-examples stays at 3fa0af357 until the 13b95ca04 regressions are fixed on a later head (Letter 3 = (a), v0.18; #1922)

The re-pin check on 13b95ca04 is RED: c10k p99 198 → 900 ms and rps −18.5 % side by side, template-render −11.5 %. No re-pin records a regression (#1884). Rejected: (b) re-pin and record.

## BOUNDS-1 — bounds checks stay on in the product (Letter 4 = (a))

V's `-no-bounds-checking` is not used; "sound" outranks the few percent.

## PYBASE-1 — the comparisons run Python on the PGO+LTO interpreter people install, pinned by cx-examples `baseline/python.cxd` and checked by `python-check`; the re-measure runs on the installed Homebrew 3.12.13 (owner (b) at 05:3xZ, then Letter 5 = (a); cx-examples#392, PR #393)

devbox's Nix 3.12.14 had no PGO (5-15 % slower on interpreter-bound work) and flattered cx against PARITY-1. Every ledger records `python-build`. No `brew upgrade` before the re-measure; the patch version is recorded, not pinned.

## POOL-1 — workers run on a bounded pool of OS threads with executors multiplexed over it, not one OS thread per `[?worker]` (Letter 6 = (a); #1923)

cx-core-code#122 (the 62nd live thread corrupts memory) is the pool's first row; the k=56 column of the scaling ledgers needs the pool. code.md §10.4.6's semantics are unchanged: a worker is a worker, the thread is the runtime's. Design ruled first on the long-term-best standard. Rejected: (b) keep thread-per-worker and fix #122 alone.

## ROWS-1 — ep-2 runs the c10k wrk rows on the head side by side with 3fa0af357 for plat, after the flags A/B (Letter 7 = (a); #1922)

dev2 cannot measure c10k (its loopback tail, plat 00:4xZ 10-13); ep-2 is the only box that can.

## LAND-1 — ep-2 opens the two PRs with their lanes green; the campaign's stream lands them through the build slot and the gate (landing = (a))

cx-core-code#136 (FLAGS-1) and the cx-private change (HARDEN-1 and this page). The pin bump rides the same landing.

## VALREP-1 — the evaluator's value representation is v0.18, its own issue, pulled from #1836 item 3 (Letter 2 = (a) at 06:2xZ; #1926, cx-core-code#135)

A slim tagged value (ints, bools, floats immediate; everything else by pointer) in place of the ~100-byte boxed `code__Value`; the loop fast paths that need the compiled evaluator stay with #1836 item 2. Bars: #1869's evaluator-bound rows at parity. Ordered after CALLP-1's cuts.

## CALLP-1 — the call-path cuts are v0.18 ("4 do it v0.18"; #1924)

The cgen initializer form for assigned struct temporaries, the zero-init flag taken whole, cut 2's assignment barriers, the dead-stack scrub — each with its measured cost as the bar.

## RECSHAPE-1 — RP-6's trigger fired: shape-shared record maps are v0.18 (RP-6 = (a) of 09-02 stands; this id is the v0.18 round) ("5 … Get this fixed! v0.18"; #1925, cx-core-data#46 reopened)

The 100 MB CSV (2,000,000 maps, 2.3 GB) is "the first record-feed consumer above ~100 MB". The bar: #1869's memory rows (csv, JSON 1 MB, SQL peak) at parity with Python.

## MCORE-1 — the multi-core epic (#1923): scaling ledgers to k=56 on dev2 with Python multiprocessing baselines, the stress corpus as a ledger, sanitizer and perturbation builds, a multi-core row in the loop's union; Go-level performance by v2.0 or earlier through #1836's items 2 and 4; v0.18 does not tune the tree walker further

The young generation waits ("3 seems we wait on this"; cx-home/v#15). The vgc pacer's wall-time judgment is v0.18 under the standing rule that every V GC issue is v0.18 (cx-home/v#42, #1927).
