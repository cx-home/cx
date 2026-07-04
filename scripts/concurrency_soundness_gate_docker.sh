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
IMAGE="${GATE_IMAGE:-arm64v8/gcc:latest}"    # NATIVE arm64 gcc (debian) — production parity
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
    # wrk/nc/zsh for the gate; libre2-dev/libssh2 + g++ for the cx native link deps
    # (cx/regex_re2.v -> -lre2 -lstdc++ + the re2 C++ shim; #pkgconfig libssh2).
    apt-get install -y -qq wrk netcat-openbsd procps zsh libre2-dev libssh2-1-dev pkg-config g++ >/dev/null 2>&1 || \
      apt-get install -y -qq wrk netcat-traditional procps zsh libre2-dev libssh2-1-dev pkg-config g++ >/dev/null 2>&1 || true
    command -v wrk >/dev/null 2>&1 || { echo "[docker-gate] ABORT: wrk unavailable"; exit 2; }
    command -v nc  >/dev/null 2>&1 || { echo "[docker-gate] ABORT: nc unavailable";  exit 2; }
    command -v zsh >/dev/null 2>&1 || { echo "[docker-gate] ABORT: zsh unavailable";  exit 2; }
    command -v c++ >/dev/null 2>&1 || { echo "[docker-gate] ABORT: c++ unavailable";  exit 2; }
    ls /usr/include/re2/re2.h >/dev/null 2>&1 || { echo "[docker-gate] ABORT: libre2-dev unavailable"; exit 2; }

    # Build the RE2 C++ shim archive for LINUX into vcx/target (where cx/regex_re2.v
    # links it via -L @VMODROOT/target -lcx_re2_shim). This OVERWRITES the macOS-arch
    # archive in the mounted tree; the caller rebuilds the macOS one after the run.
    cd /work/vcx
    mkdir -p target
    c++ -std=c++17 -O2 -fPIC -I/usr/include -Ideps/re2_shim -c deps/re2_shim/re2_shim.cc -o /tmp/cx_re2_shim.o
    ar rcs target/libcx_re2_shim.a /tmp/cx_re2_shim.o

    export TMPDIR=/tmp/vbuild ; mkdir -p "$TMPDIR"
    # Bootstrap a LINUX v from the in-tree vc/v.c (no git/network). V locates vlib
    # relative to the COMPILER EXECUTABLE dir, so the bootstrap (v_boot) and the
    # self-compiled compiler (v_lx) must live in the V root (/work/third_party/v)
    # next to vlib/ — NOT in /tmp. They are temp names (not the mounted macOS `v`)
    # and are removed at the end.
    cd /work/third_party/v
    rm -f ./v_boot ./v_lx
    cc -std=gnu11 -w -o ./v_boot vc/v.c -lm -lpthread
    ./v_boot -no-parallel -o ./v_lx cmd/v
    echo "[docker-gate] linux v built: $(./v_lx version)"

    # Build the passive detector (+ optional fix defines) to a container-local path.
    cd /work/vcx
    /work/third_party/v/v_lx -n -w -cc cc -gc e -d vgc_passive -d vgc_nosweep '"$DEFINES"' \
      -o /tmp/cx_soundness_gate_linux cmd/
    test -x /tmp/cx_soundness_gate_linux
    # Build the REAL-SWEEP crash binary too (the gate is two-build since the
    # 2026-07-01 hardening: bf1 oracle on the detector, crash counting on real
    # sweep). Without this the gate falls back to building it with the mounted
    # macOS `../third_party/v/v` -> "exec format error" and the docker gate dies.
    /work/third_party/v/v_lx -n -w -cc cc -gc e '"$DEFINES"' \
      -o /tmp/cx_crash_gate_linux cmd/
    test -x /tmp/cx_crash_gate_linux
    rm -f /work/third_party/v/v_boot /work/third_party/v/v_lx

    # Run the existing gate against the prebuilt linux binaries (zsh: the gate uses
    # ${0:A:h:h} for ROOT, so it must run from /work under zsh).
    cd /work
    CX_SOUNDNESS_BIN=/tmp/cx_soundness_gate_linux CX_CRASH_BIN=/tmp/cx_crash_gate_linux \
      SOUNDNESS_N="$NREACT" \
      SOUNDNESS_ROUNDS="$ROUNDS" zsh /work/scripts/concurrency_soundness_gate.sh
  '
