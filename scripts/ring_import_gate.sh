#!/usr/bin/env bash
# ring_import_gate.sh — the §3 import contract, enforced grep-level, zero-tolerance.
#
# Partition spec (spec/03-approved/core/cx_partition.md §3): rings are pure import
# contracts. This gate lands at I0 BEFORE any code moves, so the seam can never
# regress silently — a synthetic violation MUST fail the lane.
#
# Two rings, then groups (partition spec §2–§3, RULED: RS-1):
#   Ring 0  = vcx/cx        — imports nothing internal (V stdlib only).
#   Ring 1  = vcx/code      — MAY import Ring 0 (cx) only.
#   platform group = vcx/platform (the residue) and the V product modules
#                             split out of it (RS-24: each vcx/<vmodule>/
#                             registry/repos.cxd declares) — MAY import the
#                             rings (cx, code) and what its manifest declares:
#                             the leaf siblings the spec names for platform
#                             consumption (cxstore, arrow, transport) and one
#                             another. Nothing else.
#   leaves  = vcx/arrow, vcx/transport — consumed FROM the platform group;
#                             themselves import Ring 0 (cx) only (+ their own
#                             submodules).
#   engine  = vcx/cxstore   — Ring-0-only AND evaluator-free (spec §2).
#   cli lyr = vcx/cli, vcx/cmd_data — the data/cli-profile surface: MUST stay
#                             platform-FREE (no platform-group import), or the
#                             data/cli profiles would pull the daemon stack (§4).
#   grading = cx-core-data's corpus grading cores (RULED: D56a) — the document,
#                             diff, lint, fmt and streaming-write lanes and the
#                             `cx corpus` body both profiles run: MAY import cx
#                             and fixtures only (never code), so the data profile
#                             can link it; cmd_data may import it.
# The pin direction BETWEEN platform products is not this gate's: that is
# scripts/product_import_gate.cx (RULED: RS-24).
#
# Hardened per the adversarial audits:
#   M34  — deny-sets are DERIVED from the live sibling-dir set under vcx/, so a
#          future sibling can never escape by omission.
#   M35  — `import` is not the only edge: `#flag`/`#include` can link a ring's
#          objects against a sibling's C artifacts.
#   F-17 (R3.10) — the C-edge lane is widened to EVERY way a sibling path can
#          be named, and to the C sources themselves:
#            • `@VMODROOT/<sib>`                (V #flag/#include)
#            • `@VMODROOT/../vcx/<sib>`         (up-and-back-down escape)
#            • `../<sib>` and `../../vcx/<sib>` (relative includes, incl. .c/.h)
#          `.c`/`.h` files in a ring dir are scanned too (a raw C include of a
#          sibling header bypassed the .v-only scan). The regex_re2.v allowlist
#          is narrowed to the TWO EXACT edge PATHS (deps/re2_shim, target), not
#          the whole sibling dir. arrow/transport and the platform-free
#          cli/cmd_data lanes are added. Each new class is red-on-synthetic
#          (scripts/ring_import_gate_selftest.sh).
#
# Tests (*_test.v) may import anything — spec §3.
#
# Exit: 0 = clean; 1 = a ring module imports or links outside its contract.
set -euo pipefail

# RING_GATE_ROOT: the selftest points the gate at an ISOLATED fake tree —
# synthetic violation files must never touch the live vcx/ (a probe file in
# vcx/cx/ would be COMPILED by any concurrently-running build job; that race
# broke test-extraction-gate under parallel make, 2026-08-07).
ROOT="${RING_GATE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VCX="$ROOT/vcx"
# cx-core-data's modules (cx, cli, cmd_data, arrow, fixtures, grading) left vcx/ for its
# pinned checkout (RULED: RS-7, RS-12). They are still cx's rings and still
# scanned: ring_dir answers where a module lives, and a module in NEITHER place
# is a failure -- scan_ring skips a missing directory, and a ring the gate
# silently stopped reading would pass every tree.
PIN_V="${RING_GATE_PIN:-$ROOT/deps/cx-core-data/vcx}"
ring_dir() {
  if [ -d "$VCX/$1" ]; then printf '%s\n' "$VCX/$1"
  elif [ -d "$PIN_V/$1" ]; then printf '%s\n' "$PIN_V/$1"
  else printf '%s\n' "$VCX/$1"; fi
}

fail=0
for m in cx arrow cli cmd_data grading; do
  if [ ! -d "$VCX/$m" ] && [ ! -d "$PIN_V/$m" ]; then
    echo "ring_import_gate: FAILED -- module '$m' is neither $VCX/$m nor $PIN_V/$m (run \`make deps-sync\`)"
    fail=1
  fi
done

# hits_sibling <line> <sibling> — does this #flag/#include line reference the
# vcx sibling dir <sibling> by ANY spellable form? (F-17: the pre-repair gate
# matched only the bare @VMODROOT/<sib> form.)
hits_sibling() {
  local line="$1" sib="$2"
  printf '%s\n' "$line" | grep -qE "@VMODROOT/${sib}(/|[[:space:]]|\$)"          && return 0
  printf '%s\n' "$line" | grep -qE "@VMODROOT/\.\./vcx/${sib}(/|[[:space:]]|\$)" && return 0
  # relative forms (from a file inside vcx/<ring>/: ../<sib> reaches a sibling;
  # ../../vcx/<sib> is the up-two escape). Bounded on the left so ".../foo" and
  # "xdeps" do not match.
  printf '%s\n' "$line" | grep -qE "(^|[[:space:]=\"'/])\.\./${sib}(/|[[:space:]]|\"|\$)"           && return 0
  printf '%s\n' "$line" | grep -qE "(^|[[:space:]=\"'/])\.\./\.\./vcx/${sib}(/|[[:space:]]|\"|\$)"   && return 0
  return 1
}

# c_edge_allowed <basename> <sibling> <line> — the ONLY acknowledged C edges
# into a non-module dir, keyed to the EXACT path (F-17: narrowed from
# whole-sibling-dir to these paths). `deps/` is vendored C shim source and
# `target/` is the shared build-output dir where shim libs land — neither is a
# ring MODULE (nothing imports them), but a stray edge into any OTHER sibling
# via them must still fail, so they stay policed and only these exact edges pass:
#   cx/regex_re2.v  → deps/re2_shim (RE2 header), target (RE2 -L / shim lib)
#   arrow/*         → target/libcx_arrow_shim.a (the arrow native shim)
# spelled @VMODROOT/<sib> or, since the module compiles from a pinned checkout
# where @VMODROOT names nothing, @DIR/../<sib> (RULED: RS-7, RS-12).
# Anything else — a NEW edge, or an edge into a code/platform/… source — fails.
c_edge_allowed() {
  local base="$1" sib="$2" line="$3"
  case "$base" in
    regex_re2.v)
      case "$sib" in
        deps)   printf '%s\n' "$line" | grep -qE "(@VMODROOT|@DIR/\.\.)/deps/re2_shim(/|[[:space:]]|\$)" && return 0 ;;
        target) printf '%s\n' "$line" | grep -qE "(@VMODROOT|@DIR/\.\.)/target(/|[[:space:]]|'|\$)"        && return 0 ;;
      esac ;;
    arrow_files_d_cx_arrow_files.v)
      case "$sib" in
        target) printf '%s\n' "$line" | grep -qE "(@VMODROOT|@DIR/\.\.)/target/libcx_arrow_shim\.a(/|[[:space:]]|'|\$)" && return 0 ;;
      esac ;;
  esac
  return 1
}

# scan_ring <dir> <label> <allow-c-edges:0|1> <deny-sibling…>
# Fails the run (sets fail=1) on any import or C edge from <dir> into a denied
# sibling. Scans .v (import + C edges) and .c/.h (C edges only). *_test.v skip.
scan_ring() {
  local dir="$1" label="$2" allow_c="$3"; shift 3
  local deny=("$@")
  [ -d "$dir" ] || return 0
  local f base line internal
  # ── import edges (.v only) ──
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    while IFS= read -r line; do
      local mod
      mod="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')"
      for internal in "${deny[@]}"; do
        if [ "$mod" = "$internal" ]; then
          echo "RING-VIOLATION: ${label} module $base imports denied sibling '$mod'"
          echo "  → $f: $line"
          fail=1
        fi
      done
    done < <(grep -hE "^[[:space:]]*import[[:space:]]+" "$f" 2>/dev/null || true)
  done < <(find "$dir" -name '*.v' -not -name '*_test.v' -print0)
  # ── C edges (.v #flag/#include AND raw .c/.h #include/#flag) ──
  # Fast path: ONE grep per line decides whether the line names ANY denied
  # sibling by any form; the per-sibling + allowlist detail runs only on a hit
  # (re2/arrow shim edges, or a real violation) — orders of magnitude fewer
  # subprocesses than looping every sibling on every line.
  local deny_alt; deny_alt="$(printf '%s|' "${deny[@]}")"; deny_alt="${deny_alt%|}"
  local edge_re="(@VMODROOT/(\\.\\./vcx/)?|(^|[[:space:]=\"'/])\\.\\./(\\.\\./vcx/)?)(${deny_alt})(/|[[:space:]]|\"|\$)"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    while IFS= read -r line; do
      printf '%s\n' "$line" | grep -qE "$edge_re" || continue
      for internal in "${deny[@]}"; do
        if hits_sibling "$line" "$internal"; then
          if [ "$allow_c" = "1" ] && c_edge_allowed "$base" "$internal" "$line"; then
            continue
          fi
          echo "RING-VIOLATION: ${label} source $base carries a C edge into denied sibling '$internal'"
          echo "  → $f: $line"
          fail=1
        fi
      done
    done < <(grep -hE "^[[:space:]]*#(flag|include)" "$f" 2>/dev/null || true)
  done < <(find "$dir" \( -name '*.v' -o -name '*.c' -o -name '*.h' \) -not -name '*_test.v' -print0)
}

# deny_but <keep…> — every internal sibling under vcx/ EXCEPT the kept names.
deny_but() {
  local keep=" $* "
  { (cd "$VCX" && find . -maxdepth 1 -mindepth 1 -type d); [ -d "$PIN_V" ] && (cd "$PIN_V" && find . -maxdepth 1 -mindepth 1 -type d); } | sed 's|^\./||' | LC_ALL=C sort -u \
    | while IFS= read -r d; do case "$keep" in *" $d "*) : ;; *) printf '%s\n' "$d" ;; esac; done
}

# Ring 0 (vcx/cx): strict sink — imports/links nothing internal but cx, save
# the two acknowledged re2 C edges.
scan_ring "$(ring_dir cx)" "Ring-0 (cx)" 1 $(deny_but cx)

# Store engine (vcx/cxstore): Ring-0-only + evaluator-free (spec §2).
scan_ring "$VCX/cxstore" "store engine (cxstore)" 0 $(deny_but cx cxstore)

# Ring 1 (vcx/code): MAY import Ring 0 (cx) only.
scan_ring "$VCX/code" "Ring-1 (code)" 0 $(deny_but cx code)

# The V product modules (RULED: RS-24): vcx/platform split into one V module
# per V product, each in the vcx/<vmodule>/ registry/repos.cxd declares. They
# are the platform group exactly as vcx/platform is (RULED: RS-1), so the same
# contract holds for each: the rings (cx, code), cxstore/arrow/transport, plus
# one another -- WHICH product may import which is the pin graph, and
# scripts/product_import_gate.cx holds that; this lane only keeps every
# product off the non-platform siblings (cli, cmd, tests, ...) and off the
# residue above it. Read grep-level from the registry so a product split is
# gated the moment its row declares it; a tree with no registry (the
# selftest's fake one without it) has no products.
PRODUCTS=""
if [ -f "$ROOT/registry/repos.cxd" ]; then
  PRODUCTS="$( { grep -oE "vmodule=[a-z_][a-z0-9_]*" "$ROOT/registry/repos.cxd" || true; } | cut -d= -f2 | { grep -vx platform || true; } | LC_ALL=C sort -u | tr '
' ' ')"
fi

# xap is the one product ABOVE the residue (RS-24, D31a: once xap's split
# makes it vcx/xap/, what is left in vcx/platform is the products not yet
# split, every one of which xap pins). So xap may import the residue, and
# neither the residue nor any other product may import xap.
BELOW=""
for p in $PRODUCTS; do [ "$p" = xap ] || BELOW="$BELOW$p "; done

# The platform group's residue (vcx/platform): MAY import the rings (cx, code),
# its declared graph (cxstore, arrow, transport) and the product modules split
# out of it -- all but xap, above it — RULED: RS-1, RS-24.
scan_ring "$VCX/platform" "platform group (platform)" 0 $(deny_but cx code cxstore arrow transport platform $BELOW)
for p in $PRODUCTS; do
  if [ "$p" = xap ]; then
    scan_ring "$VCX/$p" "platform group product ($p)" 0 $(deny_but cx code cxstore arrow transport platform $PRODUCTS)
  else
    scan_ring "$VCX/$p" "platform group product ($p)" 0 $(deny_but cx code cxstore arrow transport $BELOW)
  fi
done

# Leaf siblings (vcx/arrow, vcx/transport): consumed FROM the platform group; import cx
# (Ring 0) only, plus their own submodules (self kept in the allow-set).
scan_ring "$(ring_dir arrow)" "leaf (arrow)" 1 $(deny_but cx arrow)
scan_ring "$VCX/transport" "leaf (transport)" 0 $(deny_but cx transport)

# Platform-free profile surface (vcx/cli, vcx/cmd_data): the data/cli profiles
# MUST NOT pull the platform group — no import of platform or its leaf/engine
# siblings. cli imports cx (+ code, allowed for the cli profile); cmd_data
# imports cli. Everything in the platform group is denied. (F-17: was manual,
# now gated.)
scan_ring "$(ring_dir cli)" "platform-free (cli)" 0 $(deny_but cx code cli cmd_data)
scan_ring "$(ring_dir cmd_data)" "platform-free (cmd_data)" 0 $(deny_but cx code cli cmd_data grading)

# The corpus grading cores (RULED: D56a): Ring 0, so the data profile links
# them -- cx and the fixture loader only, never the evaluator. The PROGRAM lane
# (vcx/corpus, which imports code) is the full cx's and is not this module.
scan_ring "$(ring_dir grading)" "Ring-0 grading (grading)" 0 $(deny_but cx fixtures grading)

if [ "$fail" -ne 0 ]; then
  echo "ring_import_gate: FAILED — a ring module violates its §3 import contract."
  exit 1
fi
echo "ring_import_gate: OK — Ring-0 strict sink; cxstore Ring-0-only+evaluator-free; code→cx only; platform group within the rings + cxstore/arrow/transport + the product modules below xap; each product (${PRODUCTS% }) within the rings + cxstore/arrow/transport + the products, xap alone also over the residue and none into xap; arrow/transport→cx only; cli/cmd_data platform-free; grading→cx+fixtures only"
exit 0
