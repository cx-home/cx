#!/usr/bin/env bash
#
# Gate 17 helper — playground live-integration smoke test.
#
# Boots the static playground via scripts/serve_static.cx (pure CX on
# [?http-service] — RULED: PYE-5, #922; this replaced python3's
# http.server), then issues a headless curl against the served
# playground.html to confirm:
#   - dist/wasm/libcx-async.js, libcx-pthreads.js and cxlib.js are
#     reachable (HTTP 200)
#   - playground.html loads without 404s on its asset references
#   - the vendored diagram renderer (playground/vendor/mermaid.min.js) and
#     its MIT license are both served, and the bundle is real-sized
#   - playground.html loads NO off-origin <script>, and its only
#     off-origin references at all are the allowlisted Google Fonts
#     URLs — the assertion that keeps §8.11.3's offline promise honest
#     for the Graph pane as well as for evaluation (#1007)
#   - libcx-pthreads.js exposes the _cx_code_eval / _cx_code_diagram
#     export symbols (loader-JS grep; full boot needs a real browser)
#
# Port: honors PORT=<n> if set (fails loudly if that port is busy);
# otherwise picks a free port by try-binding candidates — the CX server
# exits rc 1 fast on a busy port, so the failed boot IS the busy check.
#
# Binary: CX_BIN overrides; default is the tree's vcx/target/cx. A
# missing binary is a loud failure, never a PATH fallback (#929).
#
# Full live-integration testing (Mermaid render, interactive tree,
# bidirectional bridge) is browser-driven and lives in
# scripts/test_playground_browser.js (Phase 7 follow-up).
#
# Exit 0 on pass; 1 on any failure. The server is killed on every exit
# path (pass, fail, signal) — no orphans.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAYGROUND="$ROOT/dist/playground-preview"
CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"

if [[ ! -x "$CX_BIN" ]]; then
    echo "Gate 17 FAIL — CX binary not found at $CX_BIN. Run make build-vcx first (or set CX_BIN)."
    exit 1
fi

if [[ ! -d "$PLAYGROUND" ]]; then
    echo "Gate 17 FAIL — $PLAYGROUND not built. Run make build-playground first."
    exit 1
fi

if [[ ! -f "$PLAYGROUND/dist/wasm/libcx-async.js" ]]; then
    echo "Gate 17 FAIL — wasm artifacts missing under $PLAYGROUND."
    exit 1
fi

SERVER_PID=""
cleanup() {
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
    [[ -n "$SERVER_PID" ]] && wait "$SERVER_PID" 2>/dev/null
}
trap cleanup EXIT

# boot_server PORT — start the CX static server on PORT and wait for
# readiness. Returns 0 once playground.html answers; 1 if the server
# process died (bind refused / busy port); 2 on a readiness timeout.
boot_server() {
    local port="$1"
    "$CX_BIN" --allow-read --allow-net --allow-clock \
        "$ROOT/scripts/serve_static.cx" --port "$port" --root "$PLAYGROUND" \
        >/dev/null 2>&1 &
    SERVER_PID=$!
    for try in 1 2 3 4 5; do
        if curl -sf -o /dev/null "http://127.0.0.1:$port/playground.html"; then
            return 0
        fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            SERVER_PID=""
            return 1
        fi
        sleep 1
    done
    return 2
}

if [[ -n "${PORT:-}" ]]; then
    boot_server "$PORT"
    rc=$?
    if [[ $rc -eq 1 ]]; then
        echo "Gate 17 FAIL — port $PORT busy (server bind refused); pass a free PORT=<n> or unset PORT to auto-pick."
        exit 1
    elif [[ $rc -ne 0 ]]; then
        echo "Gate 17 FAIL — playground.html not reachable on http://127.0.0.1:$PORT after 5 tries."
        exit 1
    fi
else
    booted=0
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        PORT=$(( (RANDOM % 30000) + 20000 ))
        boot_server "$PORT"
        rc=$?
        if [[ $rc -eq 0 ]]; then booted=1; break; fi
        if [[ $rc -eq 2 ]]; then
            echo "Gate 17 FAIL — server on port $PORT booted but playground.html not reachable after 5 tries."
            exit 1
        fi
        # rc 1: bind refused (busy candidate) — try the next port.
    done
    if [[ $booted -ne 1 ]]; then
        echo "Gate 17 FAIL — no free port found in 10 candidates (20000-49999)."
        exit 1
    fi
fi

fail() {
    echo "Gate 17 FAIL — $1"
    exit 1
}

# Probe each required asset
for asset in playground.html playground/playground.js playground/playground.css \
             playground/playground.examples.js \
             playground/vendor/mermaid.min.js playground/vendor/LICENSE-mermaid.txt \
             dist/wasm/libcx-async.js dist/wasm/cxlib.js; do
    if ! curl -sf -o /dev/null "http://127.0.0.1:$PORT/$asset"; then
        fail "$asset returned non-200"
    fi
done

# ── no-CDN assertion (#1007) ─────────────────────────────────────────────
# The playground's offline promise (§8.11.3) is only worth what the page's
# own <head> says. It used to load mermaid from jsDelivr, so evaluation was
# offline and the Graph pane silently was not; the renderer is vendored now,
# and this check is what stops the next one creeping back in.
#
# Two assertions, because they fail differently:
#
#   1. ZERO off-origin <script>. Executable third-party code is the class
#      that BREAKS a feature when the network is absent — no fallback, no
#      degradation, just a dead pane. Nothing may be off-origin here.
#
#   2. Every remaining off-origin reference of any kind is on a named
#      allowlist. Today that is Google Fonts and nothing else: a stylistic
#      fetch that degrades cleanly (playground.css carries a full local
#      mono fallback stack), site-wide rather than playground-specific, and
#      therefore a separate decision from the renderer. Allowlisting it by
#      name — instead of only checking scripts — means a NEW CDN of any
#      kind trips this gate on arrival.
html="$(curl -sf "http://127.0.0.1:$PORT/playground.html")" \
    || fail "could not re-fetch playground.html for the no-CDN assertion"

# grep -o over the served bytes; `|| true` because no match is the pass case
# and grep exits 1 on it (and this script runs under `set -o pipefail`).
offsite_scripts="$(grep -oE '<script[^>]+src="https?://[^"]+"' <<< "$html" || true)"
if [[ -n "$offsite_scripts" ]]; then
    echo "Gate 17 FAIL — playground.html loads script(s) from off-origin (#1007):"
    printf '    %s\n' "$offsite_scripts"
    echo "  The diagram renderer is vendored at scripts/gen_guide/playground/vendor/."
    echo "  A CDN <script> here means the page needs the network to work."
    exit 1
fi

ALLOWED_OFFSITE='^https://fonts\.(googleapis|gstatic)\.com'
unexpected=""
while read -r url; do
    [[ -z "$url" ]] && continue
    grep -qE "$ALLOWED_OFFSITE" <<< "$url" || unexpected+="    $url"$'\n'
done <<< "$(grep -oE '(src|href)="https?://[^"]+"' <<< "$html" \
            | sed -E 's/^(src|href)="//; s/"$//' | sort -u || true)"
if [[ -n "$unexpected" ]]; then
    echo "Gate 17 FAIL — playground.html carries off-origin reference(s) that are not"
    echo "  on the #1007 allowlist (Google Fonts only):"
    printf '%s' "$unexpected"
    echo "  Vendor the asset under scripts/gen_guide/playground/vendor/, or extend the"
    echo "  allowlist here with the reason it may stay remote."
    exit 1
fi

# The vendored bundle must be the real thing, not a placeholder that 200s.
mmd_bytes="$(curl -sf -o /dev/null -w '%{size_download}' \
             "http://127.0.0.1:$PORT/playground/vendor/mermaid.min.js")"
if [[ "$mmd_bytes" -lt 1000000 ]]; then
    fail "playground/vendor/mermaid.min.js served only $mmd_bytes bytes — not a mermaid bundle"
fi

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
echo "  - playground/vendor/mermaid.min.js 200 ($mmd_bytes bytes) + LICENSE-mermaid.txt 200"
echo "  - no off-origin <script> in playground.html; off-origin refs limited to Google Fonts"
echo "  - dist/wasm/libcx-pthreads.js exports _cx_code_eval + _cx_code_diagram"
echo "  - dist/wasm/cxlib.js has all 8 sampled Layer-1 methods"
echo
echo "Browser-level verification (Mermaid render, tree, bridge):"
echo "  - run scripts/test_playground_browser.js once authored (Phase 7)"

exit 0
