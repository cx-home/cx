#!/usr/bin/env bash
# ring_import_gate_selftest.sh — proves ring_import_gate.sh is RED on every
# violation class it claims to catch (audit F-17 / register R3.10). Each probe
# writes a synthetic offending file into a ring dir, runs the gate, and asserts
# it FAILS (rc=1); the file is removed and the tree re-verified clean.
#
# Exit: 0 = every probe went red as required AND the clean tree is green;
#       1 = a probe did NOT fail (a bypass the gate misses) or clean-tree red.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/scripts/ring_import_gate.sh"
VCX="$ROOT/vcx"
rc_ok=0

# clean baseline
if ! bash "$GATE" >/dev/null 2>&1; then
  echo "SELFTEST FAIL: the gate is RED on the clean tree — fix that first."
  exit 1
fi

# probe <name> <file-path> <content> — write, expect RED, remove, expect green.
probe() {
  local name="$1" path="$2" content="$3"
  printf '%s\n' "$content" > "$path"
  if bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [$name]: the gate did NOT flag $path — this bypass is live."
    rm -f "$path"
    rc_ok=1
    return
  fi
  rm -f "$path"
  if ! bash "$GATE" >/dev/null 2>&1; then
    echo "SELFTEST FAIL [$name]: the tree is not clean after removing the probe $path."
    rc_ok=1
    return
  fi
  echo "  ok — $name (gate went red on the synthetic violation)"
}

echo "ring_import_gate selftest:"

# ── F-17 bypass #1: relative ../<sibling> C include from Ring 0 ──
probe "rel-dotdot-include" "$VCX/cx/_selftest_rel_probe.v" \
  'module cx
#include "../code/cx_stack_guard.h"'

# ── F-17 bypass #2: @VMODROOT/../vcx/<sibling> up-and-back-down escape ──
probe "vmodroot-updown" "$VCX/cx/_selftest_updown_probe.v" \
  'module cx
#flag -I @VMODROOT/../vcx/code'

# ── F-17 bypass #3: a RAW .c file in a ring dir including a sibling header ──
probe "raw-c-include" "$VCX/cx/_selftest_raw_probe.c" \
  '#include "../platform/whatever.h"
int _selftest_raw(void){return 0;}'

# ── the classic V import edge (M34) still caught ──
probe "v-import" "$VCX/cx/_selftest_import_probe.v" \
  'module cx
import code'

# ── narrowed allowlist: regex_re2.v may NOT reach a DIFFERENT sibling via a
#    C edge just because it is the allowlisted file ──
probe "allowlist-not-blanket" "$VCX/cx/_selftest_re2_blanket.v" \
  'module cx
#flag -I @VMODROOT/deps/some_other_dir
#flag -L @VMODROOT/code'

# ── new lane: arrow (leaf) importing a non-cx sibling ──
probe "arrow-leaf" "$VCX/arrow/_selftest_arrow_probe.v" \
  'module arrow
import platform'

# ── new lane: cli must stay platform-free ──
probe "cli-platform-free" "$VCX/cli/_selftest_cli_probe.v" \
  'module cli
import platform'

# ── new lane: cmd_data must stay platform-free ──
probe "cmd_data-platform-free" "$VCX/cmd_data/_selftest_cmddata_probe.v" \
  'module main
import cxstore'

# ── Ring 1 (code) importing Ring 2 (platform) ──
probe "code-imports-platform" "$VCX/code/_selftest_code_probe.v" \
  'module code
import platform'

if [ "$rc_ok" -ne 0 ]; then
  echo "ring_import_gate selftest: FAILED — see the live bypasses above."
  exit 1
fi
echo "ring_import_gate selftest: OK — every violation class goes red; clean tree green."
exit 0
