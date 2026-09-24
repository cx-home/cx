#!/usr/bin/env bash
#
# CX v0.8.0 — Gates 28.6 + 28.9: Layer-1 binding-API parity.
#
# Drives every fixture in conformance/binding_api.txt through the
# Layer-1 surface of every active binding (V / Python / Go / Rust) and
# asserts byte-identical output across all four.
#
# Architecture:
#
#   1. scripts/compile_binding_api_fixtures.cx parses the fixture file
#      and emits a JSONL stream — one self-contained `{id, in_cx, ops,
#      ...}` per line.
#
#   2. For each fixture, the JSON record is piped on stdin to each
#      driver:
#        - lang/python/cmd/binding_api_driver.py
#        - lang/go/binding_api_driver/main.go         (compiled once)
#        - lang/v/binding_api_driver/main.v           (compiled once)
#        - lang/rust/cxlib/src/bin/binding_api_driver.rs (compiled once)
#
#   3. Driver outputs are diffed pairwise. Pass iff all four agree
#      byte-for-byte. Unparseable mini-syntax (spawn / lambda / `{...}`
#      / `==`) emits "UNSUPPORTED" uniformly across all four — that
#      still satisfies parity but is reported separately and treated
#      as failure for gate purposes (don't fake-pass per spec/v0_8_0_
#      status.md §11.6).
#
# Exit codes:
#   0 — all 4 bindings agree on every fixture (UNSUPPORTED count == 0)
#   1 — at least one fixture diverges OR mini-syntax unsupported
#   2 — invocation error (missing build, fixture file, etc.)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FIXTURES="$ROOT/conformance/binding_api.cxd"
COMPILER="$ROOT/scripts/compile_binding_api_fixtures.cx"
PY_DRIVER="$ROOT/lang/python/cmd/binding_api_driver.py"
GO_DRIVER_SRC="$ROOT/lang/go/binding_api_driver"
V_DRIVER_SRC="$ROOT/lang/v/binding_api_driver/main.v"
RUST_DRIVER_SRC="$ROOT/lang/rust/cxlib"

# Where compiled drivers land.
WORK="$(mktemp -d -t cx-binding-api-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

GO_DRIVER="$WORK/binding_api_driver_go"
V_DRIVER="$WORK/binding_api_driver_v"
RUST_DRIVER="$ROOT/lang/rust/cxlib/target/release/binding_api_driver"

# ── prerequisites ───────────────────────────────────────────────────────────

if [[ ! -f "$FIXTURES" ]]; then
    echo "error: fixture file not found at $FIXTURES" >&2
    exit 2
fi
if [[ ! -f "$COMPILER" ]]; then
    echo "error: compiler script not found at $COMPILER" >&2
    exit 2
fi

LIBCX="$ROOT/vcx/target/libcx.dylib"
if [[ ! -f "$LIBCX" ]]; then
    LIBCX="$ROOT/vcx/target/libcx.so"
fi
if [[ ! -f "$LIBCX" ]]; then
    echo "error: libcx not found at $ROOT/vcx/target/libcx.{dylib,so}" >&2
    echo "       Build with: devbox run -- make build" >&2
    exit 2
fi
export LIBCX_PATH="$LIBCX"

# The fixture compiler IS a CX program (#922 / PYE-5), so `cx` is now a hard
# prerequisite rather than a convenience for the drivers.
CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"
if [[ ! -x "$CX_BIN" ]]; then
    echo "error: cx binary missing at $CX_BIN — the fixture compiler needs it" >&2
    echo "       Build with: devbox run -- make build-vcx" >&2
    exit 2
fi

# ── build per-binding drivers ───────────────────────────────────────────────

echo "[binding-api] compiling drivers..."

# Go
echo "  go..."
(
    cd "$GO_DRIVER_SRC"
    if ! go build -o "$GO_DRIVER" . 2>"$WORK/go_build.err"; then
        echo "error: failed to build Go driver" >&2
        cat "$WORK/go_build.err" >&2
        exit 2
    fi
) || exit 2

# V
echo "  v..."
# -path is test-v's V_MODULE_PATH, which the Makefile exports as CX_V_SEARCH
# (vcx/, the pinned V roots of deps.cxd, V's library; RULED: RS-12) -- a
# command-line -path REPLACES the exported VFLAGS one, so it must name the
# pinned roots itself or `import cx` finds nothing once vcx/cx has left. `native`
# resolves relative to the driver file, and ALSO listing $ROOT/lang/v
# double-registered the module trees — post-I1 vcx is big enough that
# the duplicate load overflows V's 65535-type table (new_type panic).
if ! v -path "${CX_V_SEARCH:-@vlib|@vmodules|$ROOT/vcx}" -o "$V_DRIVER" "$V_DRIVER_SRC" 2>"$WORK/v_build.err"; then
    echo "error: failed to build V driver" >&2
    cat "$WORK/v_build.err" >&2
    exit 2
fi

# Rust (release build, cached across runs)
echo "  rust..."
(
    cd "$RUST_DRIVER_SRC"
    if ! cargo build --release --bin binding_api_driver --quiet 2>"$WORK/rust_build.err"; then
        echo "error: failed to build Rust driver" >&2
        cat "$WORK/rust_build.err" >&2
        exit 2
    fi
) || exit 2

if [[ ! -x "$RUST_DRIVER" ]]; then
    echo "error: rust driver missing at $RUST_DRIVER after build" >&2
    exit 2
fi

# Python — no compile, just sanity-check importability.
echo "  python..."
if ! python3 -c "import sys; sys.path.insert(0, '$ROOT/lang/python'); import cxlib.code" 2>"$WORK/py_check.err"; then
    echo "error: Python cxlib.code import failed" >&2
    cat "$WORK/py_check.err" >&2
    exit 2
fi

# ── compile fixtures ────────────────────────────────────────────────────────

JSONL="$WORK/fixtures.jsonl"
# Flag-first invocation, fixture path positional (cli.md §3 / PYE-2).
if ! "$CX_BIN" --allow-read --allow-write "$COMPILER" "$FIXTURES" \
        > "$JSONL" 2>"$WORK/compile.err"; then
    echo "error: failed to compile fixtures" >&2
    cat "$WORK/compile.err" >&2
    exit 2
fi

# #1180: the compiled stream must be USABLE before parity means anything.
# This lane once reported 51/51 green on a compiler emitting `"ops": ,` —
# malformed JSON with zero operations. Every driver failed to parse it,
# exited 2 and printed nothing; four empty strings compare equal, so the
# comparison below scored every fixture a pass. The numbers were identical
# before and after the compiler was repaired. Parity of nothing is still
# parity, so the stream is validated first (RULED: PYE-6 — a run that
# proved nothing must not report success).
if ! "$CX_BIN" --allow-read --allow-write --allow-env \
        "$ROOT/scripts/check_binding_api_jsonl.cx" "$JSONL" "$FIXTURES"; then
    echo "error: the compiled fixture stream is unusable — see above" >&2
    exit 2
fi

TOTAL=$(wc -l < "$JSONL" | tr -d ' ')
if [[ "$TOTAL" -eq 0 ]]; then
    # Defence in depth: with TOTAL=0 the loop below never executes, so
    # PASS/FAIL/UNSUPPORTED all stay 0 and the script falls through to
    # "green". An empty run is a failure, never a pass.
    echo "error: no fixtures to run — an empty comparison is not parity" >&2
    exit 2
fi
echo "[binding-api] running $TOTAL fixtures × 4 bindings..."
echo

# ── run + diff each fixture ─────────────────────────────────────────────────

PASS=0
FAIL=0
UNSUPPORTED=0
FAIL_IDS=()
UNSUPPORTED_IDS=()

run_driver() {
    # $1 = label, $2 = command, stdin = fixture JSON
    # Captures stdout. Stderr passes through if the driver crashes
    # (exit 2).
    local label="$1"
    shift
    local out_file="$WORK/last_${label}.out"
    if ! "$@" > "$out_file" 2>"$WORK/last_${label}.err"; then
        echo "DRIVER-EXIT-$?" > "$out_file"
    fi
    cat "$out_file"
}

while IFS= read -r json_line; do
    # `id` is the first key of every record and fixture ids are bare
    # [a-z0-9-] — sed reads it without a JSON parser (and without Python).
    id=$(printf '%s' "$json_line" | sed -n 's/^{"id": "\([^"]*\)".*/\1/p')

    py_out=$(printf '%s' "$json_line" | python3 "$PY_DRIVER" 2>/dev/null); py_rc=$?
    go_out=$(printf '%s' "$json_line" | "$GO_DRIVER" 2>/dev/null);        go_rc=$?
    rs_out=$(printf '%s' "$json_line" | "$RUST_DRIVER" 2>/dev/null);      rs_rc=$?
    v_out=$(printf '%s' "$json_line" | "$V_DRIVER" 2>/dev/null);          v_rc=$?

    # #1180: a driver that FAILED has not agreed with anything — it has
    # merely printed nothing, and four silences compare equal. The exit
    # status used to be discarded here, which is what let a completely
    # broken compiler score full marks: every driver exited 2 on the
    # malformed stream and the harness read four empty strings as unanimity.
    #
    # The exit STATUS is the discriminator, not the empty output. An empty
    # stdout with exit 0 is a legitimate answer — `select-all-empty-result`
    # and `find-all-no-match` are fixtures whose correct result IS the empty
    # set, and rejecting empty output outright fails them.
    if [[ $py_rc -ne 0 || $go_rc -ne 0 || $rs_rc -ne 0 || $v_rc -ne 0 ]]; then
        FAIL=$((FAIL + 1))
        FAIL_IDS+=("$id")
        printf '  FAIL    %s  (driver exit: py=%d go=%d rs=%d v=%d)\n' \
               "$id" "$py_rc" "$go_rc" "$rs_rc" "$v_rc"
        continue
    fi

    # All four must agree byte-for-byte.
    if [[ "$py_out" == "$go_out" && "$go_out" == "$rs_out" && "$rs_out" == "$v_out" ]]; then
        if [[ "$py_out" == "UNSUPPORTED" ]]; then
            UNSUPPORTED=$((UNSUPPORTED + 1))
            UNSUPPORTED_IDS+=("$id")
            printf '  UNSUPP  %s\n' "$id"
        else
            PASS=$((PASS + 1))
            printf '  PASS    %s\n' "$id"
        fi
    else
        FAIL=$((FAIL + 1))
        FAIL_IDS+=("$id")
        printf '  FAIL    %s\n' "$id"
        printf '          py:   %q\n' "$(printf '%s' "$py_out" | head -3 | tr '\n' '|')"
        printf '          go:   %q\n' "$(printf '%s' "$go_out" | head -3 | tr '\n' '|')"
        printf '          rs:   %q\n' "$(printf '%s' "$rs_out" | head -3 | tr '\n' '|')"
        printf '          v:    %q\n' "$(printf '%s' "$v_out"  | head -3 | tr '\n' '|')"
    fi
done < "$JSONL"

# ── summary ────────────────────────────────────────────────────────────────

echo
echo "────────────────────────────────────────────────────────────────"
printf '  binding-api parity (gates 28.6 + 28.9)\n'
printf '  total:        %d\n' "$TOTAL"
printf '  parity-pass:  %d\n' "$PASS"
printf '  parity-fail:  %d\n' "$FAIL"
printf '  unsupported:  %d  (mini-syntax not parseable — driver gap)\n' "$UNSUPPORTED"
echo "────────────────────────────────────────────────────────────────"

if [[ $FAIL -gt 0 ]]; then
    echo
    echo "Divergent fixtures:"
    for id in "${FAIL_IDS[@]}"; do
        echo "  - $id"
    done
fi

if [[ $UNSUPPORTED -gt 0 ]]; then
    echo
    echo "Unsupported fixtures (mini-syntax extension needed):"
    for id in "${UNSUPPORTED_IDS[@]}"; do
        echo "  - $id"
    done
fi

if [[ $FAIL -gt 0 || $UNSUPPORTED -gt 0 ]]; then
    echo
    echo "Gates 28.6 + 28.9 NOT green."
    exit 1
fi

echo
echo "Gates 28.6 + 28.9: green."
exit 0
