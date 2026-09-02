#!/usr/bin/env bash
# bench/repr — the CXDM live-memory multiplier guard (#1119 W1, RULED: RP-5).
#
# Asserts, per lane, that the LIVE representation of a parsed ~2 MB corpus
# stays within a pinned multiple of the corpus's own byte count. The bounds are
# a RATCHET: pinned here at W1 to today's measured multipliers with headroom, so
# any wave that makes the representation worse reds the gate; each later wave
# RE-PINS THEM DOWNWARD at its exit. They are never loosened without a ruling.
#
# The measured quantity is a RATIO, never a time and never an absolute byte
# count, so the verdict holds on a loaded machine and on other hardware
# (RP-5(a)(ii); an RSS-shaped bound was rejected as (c) for that reason).
# The corpora are a pure function of the record index, and the live-byte reads
# are all but exact run to run — see the ratchet block below for the measured
# reproducibility and for what the headroom actually covers.
#
# Usage:
#   ./run.sh                 # build if stale, generate corpora if absent, assert
#   CX_REPR_RECORDS=8000 ./run.sh
#   CX_REPR_KEEP=1 ./run.sh  # leave the generated corpora on disk for inspection
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$REPO/bench/repr"
BUILD="$HERE/.build"
CORPUS="$HERE/_corpus"
BIN="$BUILD/repr"
RECORDS="${CX_REPR_RECORDS:-32000}"

# ── the ratchet ─────────────────────────────────────────────────────────────
#
# live bytes (vgc `marked` after a forced collect, minus the input string and
# the runtime's own live set) ÷ input bytes. Pinned 2026-09-02 at W1 (RP-5).
#
#   lane   measured   bound   what the headroom buys
#   json   18.779     20.80   one input copy (+1.0) then +5%
#   xml    15.316     17.20   same
#   cx     10.348-10.352   12.00  same
#
# Measured on darwin-arm64 with the `-prod` driver at 32,000 records. Run-to-run
# the reading is all but exact: over six clean runs the json and xml lanes were
# byte-identical every time, and the cx lane alternated between two values
# 6,608 B apart (0.03% — one small transient retained or not); a run under eight
# saturating CPU burners reported the same numbers as an idle one, which is what
# a live-BYTES ratio buys over a timing gate. The headroom is not that jitter,
# then — it is the one class this instrument cannot rule out. vgc scans stacks
# and registers conservatively, so a dead slot may retain an input-sized parser
# transient depending on codegen and on the process's own history (README.md,
# "what the instrument can and cannot see"). +1.0 covers one such copy; the +5%
# covers a different compiler or platform.
#
# RE-PIN PROTOCOL (RP-5): a wave that improves a lane edits the bound in THIS
# BLOCK in the same commit that lands the improvement, and records the new
# measurement in README.md and in the #1119 wave row. A bound is never raised
# without a ruling — the ratchet is not loosened to accommodate a regression.
LANES=(json xml cx)
BOUND_json=20.80
BOUND_xml=17.20
BOUND_cx=12.00

# repin_slack — how far under its bound a lane may sit before the runner says
# so. Advisory, NOT a failure: an improvement must not red somebody else's
# `make test` before the campaign's own wave re-pins. RP-5 makes exceedance the
# failure and the downward re-pin a wave-exit obligation.
REPIN_SLACK=1.20

# ── the V pin ───────────────────────────────────────────────────────────────
# Same discipline as vcx/Makefile (#1063): the patched V in third_party/v is the
# compiler; a PATH-resolved `v` is accepted only under an explicit override,
# because the measurement depends on `-gc e` (vgc + Perceus), which is this
# fork's mode.
V="$REPO/third_party/v/v"
if [[ ! -x "$V" ]]; then
  if [[ "${CX_ALLOW_PATH_V:-0}" == "1" ]]; then
    V="$(command -v v || true)"
  fi
  if [[ -z "${V:-}" || ! -x "$V" ]]; then
    echo "bench/repr: FAIL — no V compiler at $REPO/third_party/v/v." >&2
    echo "bench/repr: build the pinned fork (git submodule update --init && make -C third_party/v)" >&2
    echo "bench/repr: or set CX_ALLOW_PATH_V=1 to accept a PATH-resolved \`v\` (the measurement needs -gc e)." >&2
    exit 2
  fi
fi

# ── build (only when stale) ─────────────────────────────────────────────────
# `-prod` is load-bearing, for the reason gates 14/15/16 carry it (#835): the
# driver compiles the `cx` module as SOURCE, so without it the guard would be
# measuring a build CX does not ship. It is not a timing argument here — the
# quantity is bytes — but the -prod and dev builds DO disagree on the XML lane
# by exactly one retained copy of the input (README.md, "what the instrument
# can and cannot see"), and the shipped build is the one the campaign's RSS
# bar is measured on.
mkdir -p "$BUILD"
stale=0
if [[ ! -x "$BIN" ]]; then
  stale=1
else
  newer="$(find "$REPO/vcx/cx" -name '*.v' -newer "$BIN" -print -quit)"
  if [[ -n "$newer" || "$HERE/repr.v" -nt "$BIN" || "$V" -nt "$BIN" ]]; then
    stale=1
  fi
fi
if [[ "$stale" == "1" ]]; then
  echo "bench/repr: building the driver (v -gc e -prod over the cx module)…"
  "$V" -path "@vlib|@vmodules|$REPO/vcx" -gc e -enable-globals -prod -o "$BIN" "$HERE/repr.v"
fi

# ── measure ─────────────────────────────────────────────────────────────────
mkdir -p "$CORPUS"
fail=0
# Generated corpora are scratch — drop them on ANY exit, including an early one
# under `set -e`, unless the caller asked to keep them for inspection.
cleanup() { [[ "${CX_REPR_KEEP:-0}" == "1" ]] || rm -rf "$CORPUS"; }
trap cleanup EXIT
echo "bench/repr — CXDM live-memory multiplier (records=$RECORDS)"
echo "lane   input_bytes    live_bytes   ratio    bound   verdict"
for lane in "${LANES[@]}"; do
  corpus="$CORPUS/$lane-$RECORDS.corpus"
  bound_var="BOUND_$lane"
  bound="${!bound_var}"

  if [[ ! -f "$corpus" ]]; then
    "$BIN" gen "$lane" "$corpus" "$RECORDS"
  fi
  if ! out="$("$BIN" "$lane" "$corpus" "$RECORDS")"; then
    echo "bench/repr: FAIL — lane $lane driver exited non-zero; its diagnosis is above." >&2
    fail=1
    continue
  fi
  first="${out%%$'\n'*}"
  ratio="$(sed -n 's/.* ratio=\([0-9.]*\).*/\1/p' <<< "$first")"
  input="$(sed -n 's/.* input_bytes=\([0-9]*\).*/\1/p' <<< "$first")"
  live="$(sed -n 's/.* repr_bytes=\([0-9]*\).*/\1/p' <<< "$first")"

  if [[ -z "$ratio" || -z "$input" || -z "$live" ]]; then
    echo "bench/repr: FAIL — lane $lane produced no parsable measurement. Driver output:" >&2
    printf '%s\n' "$out" >&2
    fail=1
    continue
  fi

  over="$(awk -v r="$ratio" -v b="$bound" 'BEGIN{print (r > b) ? 1 : 0}')"
  slack="$(awk -v r="$ratio" -v b="$bound" -v s="$REPIN_SLACK" 'BEGIN{print (r * s < b) ? 1 : 0}')"
  verdict=PASS
  if [[ "$over" == "1" ]]; then
    verdict=FAIL
    fail=1
  fi
  printf '%-6s %12s %12s %8s %8s   %s\n' "$lane" "$input" "$live" "$ratio" "$bound" "$verdict"

  # The census and the struct sizes are the per-node accounting every later wave
  # reads to see WHICH allocation it removed. Printed always: a gate whose
  # evidence is only visible on failure teaches nothing on the way past.
  sed -e '1d' -e 's/^/       /' <<< "$out"

  if [[ "$over" == "1" ]]; then
    echo "bench/repr: FAIL — lane $lane live multiplier ${ratio}x exceeds the pinned bound ${bound}x." >&2
    echo "bench/repr:        The ratchet is not loosened to accommodate a regression (RULED: RP-5)." >&2
    echo "bench/repr:        ${live} live bytes for ${input} input bytes." >&2
  elif [[ "$slack" == "1" ]]; then
    echo "       NOTE: ${ratio}x sits well under the ${bound}x bound — if this is a wave's improvement,"
    echo "             RE-PIN the ratchet in run.sh (BOUND_${lane}) in the same commit (RP-5)."
  fi
done

if [[ "$fail" != "0" ]]; then
  echo "bench/repr: RED — at least one lane exceeded its pinned live-memory bound." >&2
  exit 1
fi
echo "bench/repr: GREEN — every lane within its pinned live-memory bound."
