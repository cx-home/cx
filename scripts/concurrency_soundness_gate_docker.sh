#!/usr/bin/env bash
# #145 Linux-Docker concurrency-soundness gate (production parity, the #63 path).
#
# Runs scripts/concurrency_soundness_gate.sh inside an arm64 Linux container on
# macOS. Builds the V compiler from the in-tree bootstrap (third_party/v/vc/v.c —
# NO network needed) to a CONTAINER-LOCAL path so the mounted macOS `third_party/v/v`
# binary is never clobbered, then builds the passive detector and runs the gate.
#
# Usage:
#   scripts/concurrency_soundness_gate_docker.sh                 # default (no fix)
#   GATE_DEFINES='-d vgc_cloneroots' scripts/...                 # with the fix
#   SOUNDNESS_N=24 SOUNDNESS_ROUNDS=15 scripts/...               # config passthrough
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${GATE_IMAGE:-gcc:latest}"            # arm64 gcc (debian) — present locally
NREACT="${SOUNDNESS_N:-24}"
ROUNDS="${SOUNDNESS_ROUNDS:-15}"
DEFINES="${GATE_DEFINES:-}"

echo "[docker-gate] image=$IMAGE N=$NREACT rounds=$ROUNDS defines='$DEFINES'"
docker run --rm \
  -v "$ROOT":/work \
  -e NREACT="$NREACT" -e ROUNDS="$ROUNDS" -e DEFINES="$DEFINES" \
  "$IMAGE" bash -euo pipefail -c '
    set -x
    export DEBIAN_FRONTEND=noninteractive
    # wrk (load generator) — required for the HTTP churn stressor. Try apt; fall back
    # to building from source is avoided (network) — apt over the container bridge.
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y -qq wrk netcat-openbsd procps zsh >/dev/null 2>&1 || \
      apt-get install -y -qq wrk netcat-traditional procps zsh >/dev/null 2>&1 || true
    command -v wrk >/dev/null 2>&1 || { echo "[docker-gate] ABORT: wrk unavailable"; exit 2; }
    command -v nc  >/dev/null 2>&1 || { echo "[docker-gate] ABORT: nc unavailable";  exit 2; }
    command -v zsh >/dev/null 2>&1 || { echo "[docker-gate] ABORT: zsh unavailable";  exit 2; }

    export TMPDIR=/tmp/vbuild ; mkdir -p "$TMPDIR"
    # Bootstrap a LINUX v from the in-tree vc/v.c (no git/network).
    cd /work/third_party/v
    cc -std=gnu11 -w -o /tmp/v1 vc/v.c -lm -lpthread
    /tmp/v1 -no-parallel -o /tmp/v_linux cmd/v
    echo "[docker-gate] linux v built: $(/tmp/v_linux version)"

    # Build the passive detector (+ optional fix defines) to a container-local path.
    cd /work/vcx
    /tmp/v_linux -n -w -cc cc -gc e -d vgc_passive -d vgc_nosweep '"$DEFINES"' \
      -o /tmp/cx_soundness_gate_linux cmd/
    test -x /tmp/cx_soundness_gate_linux

    # Run the existing gate against the prebuilt linux detector (zsh: the gate uses
    # ${0:A:h:h} for ROOT, so it must run from /work under zsh).
    cd /work
    CX_SOUNDNESS_BIN=/tmp/cx_soundness_gate_linux SOUNDNESS_N="$NREACT" \
      SOUNDNESS_ROUNDS="$ROUNDS" zsh /work/scripts/concurrency_soundness_gate.sh
  '
