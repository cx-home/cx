#!/usr/bin/env bash
#
# Gate 17 helper — playground live-integration smoke test.
#
# Boots the static playground via Python's http.server, then issues a
# headless curl against the served playground.html to confirm:
#   - dist/wasm/libcx.{wasm,js} are reachable (HTTP 200, correct MIME)
#   - dist/wasm/cxlib.js is reachable
#   - playground.html loads without 404s on its asset references
#   - the wasm boots far enough to expose _cx_code_eval symbol
#
# Full live-integration testing (Mermaid render, interactive tree,
# bidirectional bridge) is browser-driven and lives in
# scripts/test_playground_browser.js (Phase 7 follow-up).
#
# Exit 0 on pass; 1 on any failure.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAYGROUND="$ROOT/dist/playground-preview"
PORT="${PORT:-18080}"

if [[ ! -d "$PLAYGROUND" ]]; then
    echo "Gate 17 FAIL — $PLAYGROUND not built. Run make build-playground first."
    exit 1
fi

if [[ ! -f "$PLAYGROUND/dist/wasm/libcx-async.js" ]]; then
    echo "Gate 17 FAIL — wasm artifacts missing under $PLAYGROUND."
    exit 1
fi

# Boot http.server in background
cd "$PLAYGROUND"
python3 -m http.server "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill -- -$SERVER_PID 2>/dev/null || true' EXIT
sleep 1

# Try a small number of times — http.server can be slow to bind
for try in 1 2 3 4 5; do
    if curl -sf -o /dev/null "http://localhost:$PORT/playground.html"; then break; fi
    sleep 1
done

fail() {
    echo "Gate 17 FAIL — $1"
    exit 1
}

# Probe each required asset
for asset in playground.html playground/playground.js playground/playground.css \
             playground/playground.examples.js \
             dist/wasm/libcx-async.js dist/wasm/cxlib.js; do
    if ! curl -sf -o /dev/null "http://localhost:$PORT/$asset"; then
        fail "$asset returned non-200"
    fi
done

# Symbol smoke check — grep the wasm-loader JS for the v0.8.0 export names.
# Use the pthreads variant: it is NOT SINGLE_FILE, so its emscripten loader JS
# references the export symbols as greppable text. The async variant is
# SINGLE_FILE (wasm inlined as base64 — symbols not greppable, and its ~16 MB
# size breaks the pipe). (Full boot test requires a real browser.)
# NOTE: use grep here-strings (`<<<`), not `echo "$js" | grep -q`. Under
# `set -o pipefail`, grep -q exits on the first match while echo is still
# writing the large (~250 KB) buffer → echo takes SIGPIPE (141) → pipefail
# propagates it → the `if !` fires a false failure. A here-string is fed by
# the shell, so there is no upstream process to receive SIGPIPE.
js="$(curl -sf "http://localhost:$PORT/dist/wasm/libcx-pthreads.js")"
if ! grep -q '_cx_code_eval' <<< "$js"; then
    fail "_cx_code_eval not present in libcx-pthreads.js — wasm not rebuilt against v0.8.0 ABI"
fi
if ! grep -q '_cx_code_diagram' <<< "$js"; then
    fail "_cx_code_diagram not present in libcx-pthreads.js — diagram export missing"
fi

# cxlib.js JS surface — check Layer-1 method names per spec/bindings.md
cxlib_js="$(curl -sf "http://localhost:$PORT/dist/wasm/cxlib.js")"
for method in eval selectAll modify findAll parse bytes hash equals; do
    if ! grep -q "\\b$method\\b" <<< "$cxlib_js"; then
        fail "cxlib.js missing Layer-1 method: $method"
    fi
done

echo "Gate 17 smoke: ✅"
echo "  - playground.html / playground.js / playground.css all 200"
echo "  - dist/wasm/libcx-pthreads.js exports _cx_code_eval + _cx_code_diagram"
echo "  - dist/wasm/cxlib.js has all 8 sampled Layer-1 methods"
echo
echo "Browser-level verification (Mermaid render, tree, bridge):"
echo "  - run scripts/test_playground_browser.js once authored (Phase 7)"

exit 0
