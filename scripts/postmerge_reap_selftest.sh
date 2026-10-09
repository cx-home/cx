#!/bin/bash
# postmerge_reap_selftest.sh (cx-private#1903) — scripts/postmerge_steps.cx's own-runner
# orphan reap, on a scratch runner: (A) run OUTSIDE the runner it reaps nothing;
# (B) run under the runner it kills each live own-runner holder — one leading its
# own process group, one sharing the caller's (it and its children) — and removes
# the runner directories. Exit 0 = both hold.
set -u
CX=${CX_BIN:-$PWD/deps/cx-core-code/vcx/target/cx}
T=$(mktemp -d "${TMPDIR:-/tmp}/cx-reap-selftest.XXXXXX"); trap 'rm -rf "$T"' EXIT
G="--allow-read --allow-write --allow-subprocess --allow-env --allow-clock"
fail=0; ok() { echo "  ok   $1"; }; bad() { echo "  FAIL $1"; fail=1; }
CX_BUILD_SLOT=$T/.slot-own2 perl -e 'setpgrp(0,0); exec @ARGV' sh scripts/build-slot.sh sleep 600 > "$T/o2.log" 2>&1 &
CX_BUILD_SLOT=$T/.slot-own4 sh scripts/build-slot.sh sleep 600 > "$T/o4.log" 2>&1 &
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$T/.slot-own2/pid" ] && [ -f "$T/.slot-own4/pid" ] && break; sleep 1; done
p2=$(cat "$T/.slot-own2/pid"); p4=$(cat "$T/.slot-own4/pid")
c4=$(ps -A -o pid=,ppid= | awk -v p="$p4" '$2==p {print $1}')
CX_BUILD_SLOT=$T/.slot "$CX" $G scripts/postmerge_steps.cx --checkout="$PWD" reap > "$T/a.out" 2>&1
if kill -0 "$p2" 2>/dev/null && kill -0 "$p4" 2>/dev/null && grep -q 'no own-runner reap' "$T/a.out"; then ok "A: outside the runner nothing is reaped"; else bad "A: $(cat "$T/a.out")"; fi
CX_BUILD_SLOT=$T/.slot BUILD_SLOT_TIMEOUT=5 sh scripts/build-slot.sh "$CX" $G scripts/postmerge_steps.cx --checkout="$PWD" reap > "$T/b.out" 2>&1
sleep 1
for p in $p2 $p4 $c4; do kill -0 "$p" 2>/dev/null && bad "B: pid $p alive after the reap"; done
[ "$(grep -c '^postmerge-steps: REAPED own' "$T/b.out")" = 2 ] && ok "B: two REAPED lines" || bad "B: $(cat "$T/b.out")"
[ ! -d "$T/.slot-own2" ] && [ ! -d "$T/.slot-own4" ] && ok "B: runner directories removed" || bad "B: a runner directory is left"
kill $p2 $p4 $c4 2>/dev/null
[ $fail -eq 0 ] && echo "postmerge-reap-selftest OK" || echo "postmerge-reap-selftest FAILED"
exit $fail
