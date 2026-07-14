#!/usr/bin/env bash
#
# Gate 17 helper — playground live-integration smoke test.
#
# Boots the static playground via Python's http.server, then issues a
# headless curl against the served playground.html to confirm:
#   - dist/wasm/libcx-async.js, libcx-pthreads.js and cxlib.js are
#     reachable (HTTP 200)
#   - playground.html loads without 404s on its asset references
#   - libcx-pthreads.js exposes the _cx_code_eval / _cx_code_diagram
#     export symbols (loader-JS grep; full boot needs a real browser)
#
# Port: honors PORT=<n> if set (fails loudly if that port is busy);
# otherwise picks a free ephemeral port automatically.
#
# Full live-integration testing (Mermaid render, interactive tree,
# bidirectional bridge) is browser-driven and lives in
# scripts/test_playground_browser.js (Phase 7 follow-up).
#
# Exit 0 on pass; 1 on any failure. The http.server is killed on every
# exit path (pass, fail, signal) — no orphans.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAYGROUND="$ROOT/dist/playground-preview"

if [[ ! -d "$PLAYGROUND" ]]; then
    echo "Gate 17 FAIL — $PLAYGROUND not built. Run make build-playground first."
    exit 1
fi

if [[ ! -f "$PLAYGROUND/dist/wasm/libcx-async.js" ]]; then
    echo "Gate 17 FAIL — wasm artifacts missing under $PLAYGROUND."
    exit 1
fi

port_free() {
    # SO_REUSEADDR mirrors http.server's allow_reuse_address: lingering
    # TIME_WAIT sockets from a previous run must not read as "busy".
    python3 - "$1" <<'PY'
import socket, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

pick_free_port() {
    python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

if [[ -n "${PORT:-}" ]]; then
    if ! port_free "$PORT"; then
        echo "Gate 17 FAIL — port $PORT busy (something is already bound); pass a free PORT=<n> or unset PORT to auto-pick."
        exit 1
    fi
else
    PORT="$(pick_free_port)"
fi

# Boot http.server in background. It is a direct child of this shell, so a
# plain `kill $SERVER_PID` reaches it on every exit path (the previous
# `kill -- -$PID` addressed a process GROUP the server never led — without
# setsid that kill silently failed and the server leaked).
cd "$PLAYGROUND"
python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!
cleanup() {
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
}
trap cleanup EXIT

# Try a small number of times — http.server can be slow to bind
up=0
for try in 1 2 3 4 5; do
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/playground.html"; then up=1; break; fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Gate 17 FAIL — http.server on port $PORT died at startup (port busy or bind refused)."
        exit 1
    fi
    sleep 1
done
if [[ $up -ne 1 ]]; then
    echo "Gate 17 FAIL — playground.html not reachable on http://127.0.0.1:$PORT after 5 tries."
    exit 1
fi

fail() {
    echo "Gate 17 FAIL — $1"
    exit 1
}

# Probe each required asset
for asset in playground.html playground/playground.js playground/playground.css \
             playground/playground.examples.js \
             dist/wasm/libcx-async.js dist/wasm/cxlib.js; do
    if ! curl -sf -o /dev/null "http://127.0.0.1:$PORT/$asset"; then
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
js="$(curl -sf "http://127.0.0.1:$PORT/dist/wasm/libcx-pthreads.js")"
if ! grep -q '_cx_code_eval' <<< "$js"; then
    fail "_cx_code_eval not present in libcx-pthreads.js — wasm not rebuilt against v0.8.0 ABI"
fi
if ! grep -q '_cx_code_diagram' <<< "$js"; then
    fail "_cx_code_diagram not present in libcx-pthreads.js — diagram export missing"
fi

# cxlib.js JS surface — check Layer-1 method names per spec/bindings.md
cxlib_js="$(curl -sf "http://127.0.0.1:$PORT/dist/wasm/cxlib.js")"
for method in eval selectAll modify findAll parse bytes hash equals; do
    if ! grep -q "\\b$method\\b" <<< "$cxlib_js"; then
        fail "cxlib.js missing Layer-1 method: $method"
    fi
done

echo "Gate 17 smoke: ✅  (served on http://127.0.0.1:$PORT)"
echo "  - playground.html / playground.js / playground.css all 200"
echo "  - dist/wasm/libcx-pthreads.js exports _cx_code_eval + _cx_code_diagram"
echo "  - dist/wasm/cxlib.js has all 8 sampled Layer-1 methods"
echo
echo "Browser-level verification (Mermaid render, tree, bridge):"
echo "  - run scripts/test_playground_browser.js once authored (Phase 7)"

exit 0
