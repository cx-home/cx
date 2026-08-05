#!/usr/bin/env bash
# ring_import_gate.sh — the §3 import contract, enforced grep-level, zero-tolerance.
#
# Partition spec (spec/02-working/cx_partition.md §3): rings are pure import
# contracts. This gate lands at I0 BEFORE any code moves, so the seam can never
# regress silently — a synthetic violation MUST fail the lane.
#
# Ring membership AS OF I0 (no code moves yet; the Ring-1/2 split inside code/
# is drawn at I3, so only the structurally-clean Ring-0 sink is gated today):
#
#   Ring 0  = vcx/cx            — MUST import nothing internal (V stdlib only).
#   Ring 1+ = everything else   — may import Ring 0 (not gated here until I3).
#
# The one invariant this gate locks is the Ring-0 extraction precondition
# (spec §7 byte-for-byte gate): vcx/cx is a strict sink. The import-edge audit
# (partition_audit_vcx_imports.md) verified it holds today; this keeps it true.
#
# Exit: 0 = clean; 1 = a Ring-0 module imports an internal sibling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RING0_DIR="$ROOT/vcx/cx"

# Internal (non-Ring-0) module names — the sibling dirs under vcx/. Any `import`
# of one of these from inside vcx/cx is a ring violation. V stdlib imports
# (os, strings, strconv, math, encoding.*, crypto.*, sync, time, net, ...) are
# NOT in this set and are always allowed.
INTERNAL_MODULES="code cxstore arrow transport bench fuzz tools deps cmd"

fail=0
while IFS= read -r -d '' f; do
  # Match `import <mod>` and `import <mod> as ...`, first path segment only.
  while IFS= read -r line; do
    mod="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')"
    for internal in $INTERNAL_MODULES; do
      if [ "$mod" = "$internal" ]; then
        echo "RING-VIOLATION: Ring-0 module $(basename "$f") imports Ring-1+ module '$mod'"
        echo "  → $f: $line"
        fail=1
      fi
    done
  done < <(grep -hE "^[[:space:]]*import[[:space:]]+" "$f" 2>/dev/null || true)
done < <(find "$RING0_DIR" -name '*.v' -not -name '*_test.v' -print0)

if [ "$fail" -ne 0 ]; then
  echo "ring_import_gate: FAILED — Ring-0 (vcx/cx) is not a strict sink."
  exit 1
fi
echo "ring_import_gate: OK — Ring-0 (vcx/cx) imports nothing internal (strict sink)."
exit 0
