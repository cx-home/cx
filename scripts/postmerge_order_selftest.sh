#!/bin/bash
# postmerge_order_selftest.sh (cx-private#1917) — scripts/postmerge_steps.cx's longest-first
# order, on planted previous runs: a step's seconds are the MEDIAN of its rows in the last
# five gate-prev logs (the upper middle of an even count), so a step the newest (selected) run
# did not run still starts early, and one loaded run does not reorder the pool.
# The 93fd77d2b tick: its previous run selected 94 of 144 steps, ledger-index-check (138 s)
# had no row, started 653 s in and held the parallel phase to 791 s. Exit 0 = the order holds.
set -u
CX=${CX_BIN:-$PWD/deps/cx-core-code/vcx/target/cx}
T=$(mktemp -d "${TMPDIR:-/tmp}/cx-order-selftest.XXXXXX"); trap 'rm -rf "$T"' EXIT
G="--allow-read --allow-write --allow-subprocess --allow-env --allow-clock"
fail=0; ok() { echo "  ok   $1"; }; bad() { echo "  FAIL $1"; fail=1; }
mkdir -p "$T/vcx/target"
row() { echo "STEP-END 2026-10-12T00:00:00Z $1 exit=0 seconds=$2"; }
# six runs, oldest first by name: the oldest (outside the five) is the only one with `old`;
# a full run, then a selected run (the newest) that ran only `short` and `swing`
{ row old 900; } > "$T/vcx/target/gate-prev-20261012-000000.log"
{ row ledger 138; row short 10; row swing 5; row mid 60; } > "$T/vcx/target/gate-prev-20261012-010000.log"
for h in 02 03 04; do { row mid 50; } > "$T/vcx/target/gate-prev-20261012-${h}0000.log"; done
{ row short 12; row swing 99; } > "$T/vcx/target/gate-prev-20261012-050000.log"
got=$("$CX" $G scripts/postmerge_steps.cx --checkout="$T" order short new1 ledger old swing mid new2 2>&1 | tr '\n' ' ')
want="ledger swing mid short new1 old new2 "
[ "$got" = "$want" ] && ok "A: the median of the last five runs (upper middle of an even count), unmeasured steps after in plan order ($got)" || bad "A: want '$want' got '$got'"
# C: one loaded run (x 900 s once, 100 s four times) does not put x ahead of y (300 s every run)
rm -f "$T"/vcx/target/gate-prev-*.log
for h in 01 02 03 04; do { row x 100; row y 300; } > "$T/vcx/target/gate-prev-20261012-${h}0000.log"; done
{ row x 900; row y 310; } > "$T/vcx/target/gate-prev-20261012-050000.log"
got=$("$CX" $G scripts/postmerge_steps.cx --checkout="$T" order x y 2>&1 | tr '\n' ' ')
[ "$got" = "y x " ] && ok "C: one loaded run does not reorder the pool (y x)" || bad "C: want 'y x ' got '$got'"
rm -f "$T"/vcx/target/gate-prev-*.log
got=$("$CX" $G scripts/postmerge_steps.cx --checkout="$T" order b a c 2>&1 | tr '\n' ' ')
[ "$got" = "b a c " ] && ok "B: no previous run keeps the plan order" || bad "B: want 'b a c ' got '$got'"
[ $fail -eq 0 ] && echo "postmerge-order-selftest OK" || echo "postmerge-order-selftest FAILED"
exit $fail
