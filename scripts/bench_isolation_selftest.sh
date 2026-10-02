#!/bin/sh
# bench_isolation_selftest.sh — #1450's isolation guard, on planted artifacts
# under mktemp.
#
# WHY THE GUARD. Holding the runner is not enough: it serialises what goes
# through it, not the box. Measured on impl/cx-A-1433 (2026-09-14, run 4) with
# `.build-slot-impl` HELD and six pre-merge pipelines compiling beside it,
# `tooling.fmt_8k_ms` read 1902.1 ms against a hot 1304 and four unrelated rows
# regressed 36-457 %. The cut's own ratchet (RULED: 1249-Q1a) had no such guard,
# and INT-6's addendum already records one cut re-pinning to a cold-vs-hot
# difference.
#
#   A  run_bench_json REFUSES to measure over the bound — exit 3, and it
#      refuses BEFORE the first harness, so the refusal costs seconds
#   B  compare_bench REFUSES TO JUDGE a current reading taken over the bound
#   C  the same pair under the bound is judged normally
#   D  a pre-#1450 artifact (no load keys at all) is judged exactly as before
#   E  a loaded reading that WOULD have regressed is refused, not failed — the
#      direction that costs, because a false regression aborts a good cut and a
#      false pass re-pins the floor to a number that was never real
#   F  the fmt and convert rows time the cx RUNNING the script (#1751): its
#      `--harness-cx` resolution is that binary, and no harness spawn names the
#      retired `vcx/target/cx` (#1682) — absent in every worktree, where it
#      turned perf-ratchet's artifact into an err with no `benchmarks`, and a
#      stale different build in the main checkout
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CX=${CX_BIN:-deps/cx-core-code/vcx/target/cx}
[ -x "$CX" ] || { echo "bench-isolation self-test: no cx binary at $CX — build first"; exit 2; }
CX="$(cd "$(dirname "$CX")" && pwd)/$(basename "$CX")"

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "bench-isolation self-test (#1450):"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

artifact() { # artifact <file> <load-block> <fmt-median>
  cat > "$1" <<JSON
{
  "schema_version": 1,
  "run_id": "2026-09-14T04:00:00Z",
  "cx_commit": "deadbee",
  "uname": "Darwin 25.6.0 arm64",$2
  "benchmarks": {
    "tooling.fmt_8k_ms": { "median": $3, "unit": "ms" }
  }
}
JSON
}

BASE=$T/baseline.json
artifact "$BASE" '' 1304.0

compare() { # compare <current> — prints output, returns the step's exit
  "$CX" --allow-read --allow-write --allow-env scripts/compare_bench.cx "$BASE" "$1" --strict 2>&1
}

# ── A — the measure-side refusal ─────────────────────────────────────────────
# Guarded: with an unreadable load the runner measures anyway (by design), and
# this case would then run the whole bench suite instead of refusing in a
# second. On such a box the case is skipped rather than made slow.
if sysctl -n vm.loadavg > /dev/null 2>&1; then
  out=$(CX_BENCH_MAX_LOAD=0 "$CX" --allow-read --allow-write --allow-subprocess --allow-clock --allow-env \
          scripts/run_bench_json.cx -o "$T/never-written.json" 2>&1)
  rc=$?
  if [ "$rc" -eq 3 ] && [ ! -f "$T/never-written.json" ] \
     && case "$out" in *"REFUSING TO MEASURE"*) true ;; *) false ;; esac; then
    ok A "over the bound the runner refuses (exit 3) and writes no artifact"
  else
    bad A "wanted exit 3 and no artifact — exit $rc: $out"
  fi
else
  ok A "skipped — this box does not report vm.loadavg, where the guard measures by design"
fi

# ── B — the judge-side refusal ───────────────────────────────────────────────
artifact "$T/loaded.json" '
  "load_1m_start": 21.4,
  "load_1m_end": 18.9,
  "load_1m_bound": 8.0,' 1330.0
out=$(compare "$T/loaded.json"); rc=$?
if [ "$rc" -eq 3 ] && case "$out" in *"REFUSING TO JUDGE"*) true ;; *) false ;; esac; then
  ok B "a current reading taken at load 21.4 is refused, not judged"
else
  bad B "wanted exit 3 with a named refusal — exit $rc: $out"
fi

# ── C — under the bound, judged normally ─────────────────────────────────────
artifact "$T/quiet.json" '
  "load_1m_start": 0.8,
  "load_1m_end": 1.1,
  "load_1m_bound": 8.0,' 1330.0
out=$(compare "$T/quiet.json"); rc=$?
if [ "$rc" -eq 0 ] && case "$out" in *"load     0.8"*) true ;; *) false ;; esac; then
  ok C "under the bound the run is judged, with the load printed beside it"
else
  bad C "wanted exit 0 and the load on the header — exit $rc: $out"
fi

# ── D — a pre-#1450 artifact is judged exactly as before ─────────────────────
artifact "$T/legacy.json" '' 1330.0
out=$(compare "$T/legacy.json"); rc=$?
if [ "$rc" -eq 0 ] && case "$out" in *"not recorded"*) true ;; *) false ;; esac; then
  ok D "an artifact with no load recorded is judged as before, and says so"
else
  bad D "a pre-#1450 artifact changed behaviour — exit $rc: $out"
fi

# ── E — a loaded reading that WOULD regress is refused, never failed ─────────
artifact "$T/loaded_slow.json" '
  "load_1m_start": 21.4,
  "load_1m_end": 18.9,
  "load_1m_bound": 8.0,' 1902.1
out=$(compare "$T/loaded_slow.json"); rc=$?
if [ "$rc" -eq 3 ] && case "$out" in *"REFUSING TO JUDGE"*) true ;; *) false ;; esac; then
  ok E "the 1902 ms reading of run 4 is refused (3), not reported as a regression (1)"
else
  bad E "a loaded reading was judged as a regression — exit $rc: $out"
fi

# and the control: the SAME 1902.1 ms on a quiet box is a real regression
artifact "$T/quiet_slow.json" '
  "load_1m_start": 0.9,
  "load_1m_end": 1.0,
  "load_1m_bound": 8.0,' 1902.1
out=$(compare "$T/quiet_slow.json"); rc=$?
if [ "$rc" -eq 1 ]; then
  ok E2 "the same number on a QUIET box is still a regression (exit 1) — the guard classifies, it does not excuse"
else
  bad E2 "a real regression on a quiet box was not reported — exit $rc: $out"
fi

# ── F — the harness rows time the cx that runs the script (#1751) ───────────
out=$("$CX" --allow-read --allow-write --allow-subprocess --allow-clock --allow-env \
        scripts/run_bench_json.cx --harness-cx 2>&1); rc=$?
retired=$(grep -c "process:run ('vcx/target/cx'" scripts/run_bench_json.cx)
if [ "$rc" -eq 0 ] && [ "$out" = "$CX" ] && [ -x "$out" ] && [ "$retired" -eq 0 ]; then
  ok F "the fmt and convert rows time the cx running the script ($CX), never the retired vcx/target/cx"
else
  bad F "wanted --harness-cx = $CX (exit 0) and no vcx/target/cx spawn — exit $rc, printed '$out', $retired retired-path spawn(s)"
fi

if [ "$fails" -ne 0 ]; then
  echo "bench-isolation self-test: $fails case(s) FAILED" >&2
  exit 1
fi
echo "bench-isolation self-test: 7/7 (measure-side refusal; judge-side refusal; judged under the bound; a pre-#1450 artifact unchanged; a loaded regression refused and the same number on a quiet box still failing; the harness rows time the running cx, #1751)"
