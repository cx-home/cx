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
# Hardened per the adversarial audit (#722, findings M34/M35):
#   M34 — the deny-set is DERIVED from the live sibling-dir set under vcx/
#         (everything but cx itself), so a future sibling module can never
#         escape by omission. The pre-repair static list already omitted two
#         siblings (testenv, tests).
#   M35 — `import` is not the only edge: `#flag` / `#include` lines can link
#         Ring-0 objects against sibling-dir C artifacts. Every
#         `@VMODROOT/<sibling>` reference in a #flag/#include is a violation,
#         except the two acknowledged load-bearing RE2 edges from
#         regex_re2.v (deps/re2_shim headers; the target/ shim lib), which
#         are allowlisted BY FILE + PATH, not by pattern.
#
# Tests (*_test.v) may import anything — spec §3; recorded compliant (n30).
#
# Exit: 0 = clean; 1 = a Ring-0 module imports or links a sibling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RING0_DIR="$ROOT/vcx/cx"

# M34: internal (non-Ring-0) module names, derived from the live tree — every
# sibling dir under vcx/ except cx itself. V stdlib imports (os, strings,
# strconv, math, encoding.*, crypto.*, sync, time, net, ...) are never in
# this set and are always allowed. `target` (build output) stays in the set:
# nothing may import or link it from Ring 0 outside the allowlisted edge.
INTERNAL_MODULES="$(cd "$ROOT/vcx" && find . -maxdepth 1 -mindepth 1 -type d ! -name cx | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ')"

# M35 allowlist: acknowledged load-bearing C edges, keyed "<file>:<sibling>".
# regex_re2.v links the RE2 shim: headers under deps/re2_shim, lib under
# target/. Anything else — including a NEW edge from regex_re2.v to another
# sibling — fails.
c_edge_allowed() { # $1=basename $2=sibling
  case "$1:$2" in
    regex_re2.v:deps|regex_re2.v:target) return 0 ;;
    *) return 1 ;;
  esac
}

fail=0

while IFS= read -r -d '' f; do
  base="$(basename "$f")"

  # ── Lane 1: V import edges ────────────────────────────────────────────────
  while IFS= read -r line; do
    mod="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')"
    for internal in $INTERNAL_MODULES; do
      if [ "$mod" = "$internal" ]; then
        echo "RING-VIOLATION: Ring-0 module $base imports Ring-1+ module '$mod'"
        echo "  → $f: $line"
        fail=1
      fi
    done
  done < <(grep -hE "^[[:space:]]*import[[:space:]]+" "$f" 2>/dev/null || true)

  # ── Lane 2 (M35): C-level edges — #flag / #include into a sibling dir ────
  while IFS= read -r line; do
    for internal in $INTERNAL_MODULES; do
      # @VMODROOT is vcx/ for modules under vcx; a reference into a sibling
      # is @VMODROOT/<sibling>/... or @VMODROOT/<sibling> exactly.
      if printf '%s\n' "$line" | grep -qE "@VMODROOT/${internal}(/|[[:space:]]|$)"; then
        if c_edge_allowed "$base" "$internal"; then
          continue
        fi
        echo "RING-VIOLATION: Ring-0 module $base carries a C edge into sibling '$internal'"
        echo "  → $f: $line"
        fail=1
      fi
    done
  done < <(grep -hE "^[[:space:]]*#(flag|include)" "$f" 2>/dev/null || true)
done < <(find "$RING0_DIR" -name '*.v' -not -name '*_test.v' -print0)

if [ "$fail" -ne 0 ]; then
  echo "ring_import_gate: FAILED — Ring-0 (vcx/cx) is not a strict sink."
  exit 1
fi

# ── I3 lane: the store ENGINE is evaluator-free (spec §2) ─────────────────────
# vcx/cxstore sits in Ring 2 but MUST import Ring 0 only — "imports Ring 0
# only, and MUST stay evaluator-free". The import-edge audit verified
# cxstore -> [cx]; this locks it: any import of a sibling module other than
# cx (code, arrow, transport, cli, platform, …) fails. V stdlib imports are
# never in the derived deny-set. Same M35 C-edge rule, no allowlisted edges
# (cxstore's sole C touch is <sys/mman.h>, not a sibling path).
CXSTORE_DIR="$ROOT/vcx/cxstore"
ENGINE_DENY="$(cd "$ROOT/vcx" && find . -maxdepth 1 -mindepth 1 -type d ! -name cx ! -name cxstore | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ')"
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  while IFS= read -r line; do
    mod="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')"
    for internal in $ENGINE_DENY; do
      if [ "$mod" = "$internal" ]; then
        echo "RING-VIOLATION: store engine (cxstore) module $base imports '$mod' — the engine is Ring-0-only + evaluator-free (spec §2)"
        echo "  → $f: $line"
        fail=1
      fi
    done
  done < <(grep -hE "^[[:space:]]*import[[:space:]]+" "$f" 2>/dev/null || true)
  while IFS= read -r line; do
    for internal in $ENGINE_DENY; do
      if printf '%s\n' "$line" | grep -qE "@VMODROOT/${internal}(/|[[:space:]]|$)"; then
        echo "RING-VIOLATION: store engine (cxstore) module $base carries a C edge into sibling '$internal'"
        echo "  → $f: $line"
        fail=1
      fi
    done
  done < <(grep -hE "^[[:space:]]*#(flag|include)" "$f" 2>/dev/null || true)
done < <(find "$CXSTORE_DIR" -name '*.v' -not -name '*_test.v' -print0)

if [ "$fail" -ne 0 ]; then
  echo "ring_import_gate: FAILED — see violations above."
  exit 1
fi
echo "ring_import_gate: OK — Ring-0 (vcx/cx) strict sink (deny-set: ${INTERNAL_MODULES% }); store engine (vcx/cxstore) Ring-0-only + evaluator-free (deny-set: ${ENGINE_DENY% })"
exit 0
