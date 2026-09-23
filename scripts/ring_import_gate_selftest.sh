#!/usr/bin/env bash
# ring_import_gate_selftest.sh — proves ring_import_gate.sh is RED on every
# violation class it claims to catch (audit F-17 / register R3.10).
#
# ISOLATION (hard requirement): probes are written into a FAKE vcx tree under
# mktemp and the gate is pointed at it via RING_GATE_ROOT — NEVER into the
# live vcx/. A synthetic .v file in the real vcx/cx/ gets COMPILED by any
# concurrently-running build job (parallel make), which is exactly how the
# first version of this selftest broke test-extraction-gate (the probe's
# `#include "../code/…"` failed the cli-data-dev build mid-flight).
#
# Exit: 0 = every probe went red AND the live tree is green;
#       1 = a probe did NOT fail (a live bypass) or the live tree is red.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/scripts/ring_import_gate.sh"
rc_ok=0

# live-tree baseline (read-only — no writes to the real vcx/)
if ! bash "$GATE" >/dev/null 2>&1; then
  echo "SELFTEST FAIL: the gate is RED on the live tree — fix that first."
  exit 1
fi

# fake tree: the sibling-dir set the deny-set derivation needs, empty.
FAKE="$(mktemp -d "${TMPDIR:-/tmp}/ring_gate_selftest.XXXXXX")"
trap 'rm -rf "$FAKE"' EXIT
for d in cx code platform cxstore arrow transport cli cmd_data deps target fixtures testenv; do
  mkdir -p "$FAKE/vcx/$d"
done
# RS-24: two declared V product modules -- a lower one (net) and xap, the one
# above the residue since xap's split -- so the product lanes are probed too.
mkdir -p "$FAKE/vcx/cxnet" "$FAKE/vcx/xap" "$FAKE/registry"
printf '%s\n' "[repo-allocation [repo name=cx-platform-net vmodule=cxnet] [repo name=cx-platform-xap vmodule=xap]]" > "$FAKE/registry/repos.cxd"

# probe <name> <relpath-under-fake-vcx> <content> — write into the FAKE tree,
# expect the gate RED there, remove, expect the fake tree green again.
probe() {
  local name="$1" rel="$2" content="$3"
  local path="$FAKE/vcx/$rel"
  printf '%s\n' "$content" > "$path"
  if RING_GATE_ROOT="$FAKE" bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [$name]: the gate did NOT flag $rel — this bypass is live."
    rm -f "$path"
    rc_ok=1
    return
  fi
  rm -f "$path"
  if ! RING_GATE_ROOT="$FAKE" bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [$name]: the fake tree is not clean after removing $rel."
    rc_ok=1
    return
  fi
  echo "  ok — $name (gate went red on the synthetic violation)"
}

echo "ring_import_gate selftest (isolated fake tree: $FAKE):"

# ── F-17 bypass #1: relative ../<sibling> C include from Ring 0 ──
probe "rel-dotdot-include" "cx/selftest_rel_probe.v" \
  'module cx
#include "../code/cx_stack_guard.h"'

# ── F-17 bypass #2: @VMODROOT/../vcx/<sibling> up-and-back-down escape ──
probe "vmodroot-updown" "cx/selftest_updown_probe.v" \
  'module cx
#flag -I @VMODROOT/../vcx/code'

# ── F-17 bypass #3: a RAW .c file in a ring dir including a sibling header ──
probe "raw-c-include" "cx/selftest_raw_probe.c" \
  '#include "../platform/whatever.h"
int selftest_raw(void){return 0;}'

# ── the classic V import edge (M34) still caught ──
probe "v-import" "cx/selftest_import_probe.v" \
  'module cx
import code'

# ── narrowed allowlist: regex_re2.v may NOT reach a DIFFERENT sibling via a
#    C edge just because it is the allowlisted file ──
probe "allowlist-not-blanket" "cx/selftest_re2_blanket.v" \
  'module cx
#flag -I @VMODROOT/deps/some_other_dir
#flag -L @VMODROOT/code'

# ── new lane: arrow (leaf) importing a non-cx sibling ──
probe "arrow-leaf" "arrow/selftest_arrow_probe.v" \
  'module arrow
import platform'

# ── new lane: cli must stay platform-free ──
probe "cli-platform-free" "cli/selftest_cli_probe.v" \
  'module cli
import platform'

# ── new lane: cmd_data must stay platform-free ──
probe "cmd_data-platform-free" "cmd_data/selftest_cmddata_probe.v" \
  'module main
import cxstore'

# ── Ring 1 (code) importing the platform group (platform) ──
probe "code-imports-platform" "code/selftest_code_probe.v" \
  'module code
import platform'

# ── RS-24: Ring 1 importing a split product module ──
probe "code-imports-product" "code/selftest_code_product_probe.v" \
  'module code
import cxnet'

# ── RS-24: a product module importing a non-platform sibling ──
probe "product-imports-cli" "cxnet/selftest_product_probe.v" \
  'module cxnet
import cli'

# ── RS-24: a product module importing the residue above it ──
probe "product-imports-residue" "cxnet/selftest_residue_probe.v" \
  'module cxnet
import platform'

# ── RS-24, xap's split: a lower product or the residue importing xap ──
probe "product-imports-xap" "cxnet/selftest_xap_probe.v" \
  'module cxnet
import xap'
probe "residue-imports-xap" "platform/selftest_residue_xap_probe.v" \
  'module platform
import xap'

# ── ...and xap importing the residue and a lower product stays GREEN ──
printf '%s\n' 'module xap' 'import platform' 'import cxnet' > "$FAKE/vcx/xap/selftest_xap_down.v"
if RING_GATE_ROOT="$FAKE" bash "$GATE" >/dev/null 2>&1; then
  echo "  ok — xap-imports-residue (xap over the residue and a lower product is allowed)"
else
  echo "SELFTEST FAIL [xap-imports-residue]: the gate refused xap importing the residue it pins."
  rc_ok=1
fi
rm -f "$FAKE/vcx/xap/selftest_xap_down.v"

# ── RS-1: the platform GROUP imports the rings and what its manifest declares
#    (cxstore, arrow, transport) — nothing else. The profile-surface dirs are
#    not in its graph ──
probe "platform-group-undeclared" "platform/selftest_group_probe.v" \
  'module platform
import cli'

# ── RS-1: the words. Two rings, data and code, and the platform group above
#    them; "Ring 2" left the vocabulary, so a violation in vcx/platform is
#    reported as the platform group's, and neither the refusal nor the live
#    OK line names a Ring 2 ──
printf '%s\n' 'module platform' 'import cmd_data' > "$FAKE/vcx/platform/selftest_words_probe.v"
words_out="$(RING_GATE_ROOT="$FAKE" bash "$GATE" 2>&1 || true)"
rm -f "$FAKE/vcx/platform/selftest_words_probe.v"
live_out="$(bash "$GATE" 2>&1 || true)"
words_ok=0
case "$words_out" in
  *"platform group"*) : ;;
  *) echo "SELFTEST FAIL [group-words]: a vcx/platform violation is not reported as the platform group's (RULED: RS-1)"; words_ok=1 ;;
esac
case "$words_out$live_out" in
  *Ring-2*|*"Ring 2"*|*Ring-3*|*"Ring 3"*)
    echo "SELFTEST FAIL [ring-words]: the gate still names a Ring 2/Ring 3 — two rings, then groups (RULED: RS-1)"; words_ok=1 ;;
esac
if [ "$words_ok" -eq 0 ]; then
  echo "  ok — group-words (a vcx/platform refusal names the platform group; no Ring 2/3 in the gate's words)"
else
  rc_ok=1
fi


# ── the PINNED layout (RULED: RS-7, RS-12): cx-core-data's modules live in
#    deps/cx-core-data/vcx/, not vcx/. A second fake tree has them ONLY there:
#    it is green clean, red when the pinned Ring 0 imports a sibling (the gate
#    reads the pin, it does not skip a vcx/ directory that is no longer there),
#    and red when a pinned module is in neither place. ──
PFAKE="$(mktemp -d "${TMPDIR:-/tmp}/ring_gate_selftest_pin.XXXXXX")"
trap 'rm -rf "$FAKE" "$PFAKE"' EXIT
for d in code platform cxstore transport target testenv; do mkdir -p "$PFAKE/vcx/$d"; done
for d in cx arrow cli cmd_data deps fixtures; do mkdir -p "$PFAKE/deps/cx-core-data/vcx/$d"; done
if ! RING_GATE_ROOT="$PFAKE" bash "$GATE" >/dev/null 2>&1; then
  echo "SELFTEST FAIL [pinned-clean]: the pinned-layout fake tree is not green."
  rc_ok=1
else
  printf 'module cx\nimport code\n' > "$PFAKE/deps/cx-core-data/vcx/cx/selftest_pinned_probe.v"
  if RING_GATE_ROOT="$PFAKE" bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [pinned-ring0]: the gate did NOT flag a violation in the PINNED Ring 0 — it stopped reading cx."
    rc_ok=1
  else
    echo "  ok — pinned-ring0 (gate went red on a violation in deps/cx-core-data/vcx/cx)"
  fi
  rm -f "$PFAKE/deps/cx-core-data/vcx/cx/selftest_pinned_probe.v"
  rmdir "$PFAKE/deps/cx-core-data/vcx/cli"
  if RING_GATE_ROOT="$PFAKE" bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [pinned-absent]: a module in neither vcx/ nor the pin passed — a ring the gate cannot read must fail."
    rc_ok=1
  else
    echo "  ok — pinned-absent (gate went red on a module in neither vcx/ nor the pin)"
  fi
fi

if [ "$rc_ok" -ne 0 ]; then
  echo "ring_import_gate selftest: FAILED — see the live bypasses above."
  exit 1
fi
echo "ring_import_gate selftest: OK — every violation class goes red (isolated tree); live tree green."
exit 0
