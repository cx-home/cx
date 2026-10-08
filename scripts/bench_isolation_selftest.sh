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
#   G  the peak-RSS reader (#1884) reads BSD `-l` (bytes) and GNU `-v`
#      (kbytes) /usr/bin/time reports, takes the largest of several, and
#      answers -1 — which refuses the run — when there is none
#   H  the paired judgement (#1884): time 17 % faster with peak RSS 17 %
#      higher (webhook-saga's trade, cx-private#1882) is a regression at the
#      strict 10 % — each twin is judged on its own, whatever the other did
#   I  under load the memory half is still judged (#1884): a loaded reading
#      with a clean peak-RSS row exits 3 (time unjudged), one whose peak-RSS
#      row grew 17 % exits 1, and a head recorded over the bound has its time
#      rows left unjudged even when the current reading is quiet, as is a
#      peak the runner marks load_sensitive
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

# ── G — every timed row's peak RSS twin is read, never dropped (#1884) ───────
out=$("$CX" --allow-read --allow-write --allow-subprocess --allow-clock --allow-env \
        scripts/run_bench_json.cx --rss-selftest 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok G "the peak-RSS reader reads BSD and GNU /usr/bin/time reports and refuses a missing one (#1884)"
else
  bad G "run_bench_json --rss-selftest — exit $rc: $out"
fi

# ── H — a time win never buys a memory loss (#1884) ─────────────────────────
pair() { # pair <file> <ms> <rss-mb>
  cat > "$1" <<JSON
{
  "schema_version": 1,
  "run_id": "2026-10-08T04:00:00Z",
  "cx_commit": "deadbee",
  "uname": "Darwin 25.6.0 arm64",
  "load_1m_start": 0.9,
  "load_1m_end": 1.0,
  "load_1m_bound": 8.0,
  "benchmarks": {
    "workload.saga_ms":          { "median": $2, "unit": "ms" },
    "workload.saga_peak_rss_mb": { "median": $3, "unit": "MB" }
  }
}
JSON
}
pair "$T/pair_base.json" 550.0 359.0
pair "$T/pair_trade.json" 456.0 421.0
out=$("$CX" --allow-read --allow-write --allow-env scripts/compare_bench.cx \
        "$T/pair_base.json" "$T/pair_trade.json" --strict 2>&1); rc=$?
if [ "$rc" -eq 1 ] && case "$out" in *"workload.saga_peak_rss_mb: baseline="*) true ;; *) false ;; esac; then
  ok H "17 % faster at 17 % more peak RSS (cx-private#1882) is refused on the memory row (#1884)"
else
  bad H "a time win hid a memory loss — exit $rc: $out"
fi

# ── I — the memory half is judged on a loaded box (#1884) ───────────────────
pairl() { # pairl <file> <load> <ms> <rss-mb>
  cat > "$1" <<JSON
{
  "schema_version": 1,
  "run_id": "2026-10-08T04:00:00Z",
  "cx_commit": "deadbee",
  "uname": "Darwin 25.6.0 arm64",
  "load_1m_start": $2,
  "load_1m_end": $2,
  "load_1m_bound": 8.0,
  "benchmarks": {
    "workload.saga_ms":          { "median": $3, "unit": "ms" },
    "workload.saga_peak_rss_mb": { "median": $4, "unit": "MB" }
  }
}
JSON
}
cmp2() { "$CX" --allow-read --allow-write --allow-env scripts/compare_bench.cx "$1" "$2" --strict 2>&1; }
pairl "$T/i_base.json" 0.9 550.0 359.0
pairl "$T/i_slow_clean.json" 40.0 900.0 360.0
pairl "$T/i_grown.json" 40.0 540.0 421.0
pairl "$T/i_head_loaded.json" 40.0 550.0 359.0
pairl "$T/i_quiet_slow.json" 0.9 900.0 359.0
o1=$(cmp2 "$T/i_base.json" "$T/i_slow_clean.json"); r1=$?
o2=$(cmp2 "$T/i_base.json" "$T/i_grown.json"); r2=$?
o3=$(cmp2 "$T/i_head_loaded.json" "$T/i_quiet_slow.json"); r3=$?
# a row the runner marks load_sensitive (bench-code-streaming's peak) is not
# judged on a loaded box: 817 -> 989 MB at one load was run-to-run noise
sed -e 's/"workload.saga_peak_rss_mb": { "median": 421.0, "unit": "MB" }/"workload.saga_peak_rss_mb": { "median": 421.0, "unit": "MB", "load_sensitive": true }/' \
  "$T/i_grown.json" > "$T/i_grown_sensitive.json"
o4=$(cmp2 "$T/i_base.json" "$T/i_grown_sensitive.json"); r4=$?
if [ "$r1" -eq 3 ] && case "$o1" in *"peak-RSS and arena rows are judged"*) true ;; *) false ;; esac \
   && [ "$r2" -eq 1 ] && case "$o2" in *"workload.saga_peak_rss_mb: baseline="*) true ;; *) false ;; esac \
   && [ "$r3" -eq 3 ] && [ "$r4" -eq 3 ] \
   && grep -q '"load_sensitive": true' "$T/i_grown_sensitive.json"; then
  ok I "under load the peak-RSS row is still judged (clean -> 3, +17 % -> 1); a loaded head's time rows and a load_sensitive peak are not (#1884)"
else
  bad I "loaded memory judgement — clean exit $r1, grown exit $r2, loaded-head exit $r3, load_sensitive exit $r4: $o1 / $o2 / $o3"
fi

if [ "$fails" -ne 0 ]; then
  echo "bench-isolation self-test: $fails case(s) FAILED" >&2
  exit 1
fi
echo "bench-isolation self-test: 10/10 (measure-side refusal; judge-side refusal; judged under the bound; a pre-#1450 artifact unchanged; a loaded regression refused and the same number on a quiet box still failing; the harness rows time the running cx, #1751; the peak-RSS reader, the paired judgement and the memory half under load, #1884)"
