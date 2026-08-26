#!/usr/bin/env bash
#
# The #1015 no-CDN gate for the <cx-diagram> web component — the sibling of
# the playground's #1007 assertions in scripts/test_playground_smoke.sh, for
# the other surface that was still loading mermaid@10 from jsDelivr.
#
# What it asserts, and why each one is here:
#
#   1. tooling/web/cx-diagram.js carries NO off-origin URL of any kind. The
#      component's whole defect was a `https://cdn.jsdelivr.net/npm/mermaid@10`
#      default — a floating range (jsDelivr served whatever the newest 10.x was
#      that day), fetched at runtime, dead on a plane or behind a proxy. There
#      is no allowlist here: this file is 200 lines of component logic and has
#      no business naming a remote host at all.
#
#   2. demo.html loads no off-origin <script>, and no off-origin reference of
#      any kind. Executable third-party code is the class that BREAKS a feature
#      when the network is absent — it does not degrade, the pane just dies.
#      Checking every reference (not only scripts) means a NEW CDN of any shape
#      trips this on arrival, which is the #1007 rule.
#
#   3. The staged renderer is the ONE vendored bundle, byte-for-byte. This is
#      the assertion that keeps the repo from growing a SECOND mermaid pin that
#      drifts from the playground's — the exact failure #1007 closed when the
#      validity gate and the page turned out to resolve different copies. It is
#      compared against scripts/gen_guide/playground/vendor/mermaid.min.js by
#      hash, not merely by size, so a stale staged copy cannot pass.
#
#   4. That bundle is real (≥1 MB) and its MIT license travels with it — a
#      placeholder file that merely exists must not read as green.
#
# Deliberately dependency-free: shell + shasum only. No node, no npm, no
# http server, no emcc. The component is static files, so the gate that guards
# it should be runnable anywhere, including in a release checkout.
#
# Run via `make test-web-component-offline` (which stages the docroot first).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPONENT="tooling/web/cx-diagram.js"
DEMO="tooling/web/demo.html"
VENDOR_SRC="scripts/gen_guide/playground/vendor/mermaid.min.js"
VENDOR_LICENSE_SRC="scripts/gen_guide/playground/vendor/LICENSE-mermaid.txt"
STAGE="dist/web-component-preview"

fail() {
    echo "web-component offline gate FAIL — $1"
    exit 1
}

# ── 0. preconditions ─────────────────────────────────────────────────────────
# A missing input is a LOUD setup failure (exit 2), never a skip: a gate that
# quietly passes when its subject is absent is worse than no gate (#1007's
# "missing bundle is exit 2, never a fall back" rule).
for f in "$COMPONENT" "$DEMO" "$VENDOR_SRC" "$VENDOR_LICENSE_SRC"; do
    [[ -f "$f" ]] || { echo "web-component offline gate SETUP FAILURE — $f is missing"; exit 2; }
done
if [[ ! -d "$STAGE" ]]; then
    echo "web-component offline gate SETUP FAILURE — $STAGE not staged."
    echo "  Run: make stage-web-component"
    exit 2
fi

# ── 1. the component names no remote host ────────────────────────────────────
# `|| true` throughout: no match is the PASS case and grep exits 1 on it, which
# would otherwise kill the script under `set -e`/`pipefail`.
offsite_in_component="$(grep -nE 'https?://' "$COMPONENT" || true)"
if [[ -n "$offsite_in_component" ]]; then
    echo "web-component offline gate FAIL — $COMPONENT names off-origin URL(s) (#1015):"
    printf '    %s\n' "$offsite_in_component"
    echo "  The renderer is same-origin by design: the component resolves"
    echo "  ./vendor/mermaid.min.js against its own script URL, and"
    echo "  cxDiagramConfig.mermaidUrl is the documented injection point."
    echo "  A CDN URL here is the #1007 defect, one surface over."
    exit 1
fi

# ── 2. the demo page loads nothing off-origin ────────────────────────────────
demo_scripts="$(grep -oE '<script[^>]+src="https?://[^"]+"' "$DEMO" || true)"
if [[ -n "$demo_scripts" ]]; then
    echo "web-component offline gate FAIL — $DEMO loads script(s) from off-origin (#1015):"
    printf '    %s\n' "$demo_scripts"
    exit 1
fi
demo_offsite="$(grep -oE '(src|href)="https?://[^"]+"' "$DEMO" || true)"
if [[ -n "$demo_offsite" ]]; then
    echo "web-component offline gate FAIL — $DEMO carries off-origin reference(s) (#1015):"
    printf '    %s\n' "$demo_offsite"
    echo "  Stage the asset under $STAGE/vendor/ instead, or extend this gate"
    echo "  with the named reason it may stay remote (the #1007 allowlist rule)."
    exit 1
fi

# ── 3. the staged renderer IS the one vendored artifact ──────────────────────
staged_bundle="$STAGE/vendor/mermaid.min.js"
staged_license="$STAGE/vendor/LICENSE-mermaid.txt"
[[ -f "$staged_bundle" ]]  || fail "$staged_bundle not staged"
[[ -f "$staged_license" ]] || fail "$staged_license not staged (the MIT license travels with the bundle)"

src_hash="$(shasum -a 256 "$VENDOR_SRC"    | awk '{print $1}')"
stg_hash="$(shasum -a 256 "$staged_bundle" | awk '{print $1}')"
if [[ "$src_hash" != "$stg_hash" ]]; then
    echo "web-component offline gate FAIL — the staged renderer is NOT the vendored one (#1015):"
    echo "    $VENDOR_SRC     $src_hash"
    echo "    $staged_bundle  $stg_hash"
    echo "  Two mermaid copies that can drift apart is exactly what #1007 closed."
    echo "  Re-run: make stage-web-component"
    exit 1
fi

# ── 4. it is a real bundle, not a placeholder that merely exists ─────────────
bundle_bytes="$(wc -c < "$staged_bundle" | tr -d ' ')"
if (( bundle_bytes < 1000000 )); then
    fail "$staged_bundle is only $bundle_bytes bytes — not a mermaid bundle"
fi

# ── 5. the component still resolves the vendored path it stages ──────────────
# Cheap coupling check: if someone renames the staged directory or the default
# path, the two halves must not silently drift apart.
grep -q "vendor/mermaid.min.js" "$COMPONENT" \
    || fail "$COMPONENT no longer references ./vendor/mermaid.min.js — the staged layout and the component's default have diverged"

echo "web-component offline gate: OK"
echo "  - $COMPONENT names no off-origin URL"
echo "  - $DEMO loads no off-origin script and no off-origin reference"
echo "  - staged renderer matches the ONE vendored bundle (sha256 ${src_hash:0:16}…, $bundle_bytes bytes)"
echo "  - LICENSE-mermaid.txt staged beside it"
