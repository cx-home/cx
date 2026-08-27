#!/usr/bin/env bash
# consolidate_tests.sh — the #700 test-binary consolidation DRIVER
# (owner ruling 1a, 2026-08-09; generator requirements recorded on #700).
#
# The heavy lifting (parse / merge / dedupe / refusals) lives in CX:
# scripts/consolidate_tests.cx (dog-food). This wrapper owns the
# orchestration and the INDEPENDENT equivalence gate:
#
#   gen <area>     generate the umbrella OUTSIDE the input directory
#                  (scratch), re-verify the test-fn count with grep
#                  (independent of the generator's own claim), and
#                  prove idempotency (second run byte-identical).
#   apply <area>   gen + move the umbrella into the lane directory +
#                  compile-and-run it green + `git rm` the originals.
#                  The caller reviews and commits — ONE COMMIT PER AREA.
#   verify <area>  the gen-time checks only (no move, no git).
#   audit <area>   the #1012 resurrection guards ONLY — no generation, no
#                  compile, no git mutation. `audit all` sweeps every
#                  manifest in scripts/consolidation/. This is the
#                  standing check: the guards below are invariants of the
#                  tree, not just of a regeneration.
#   absorb <area>  fold NEW inputs into an umbrella that ALREADY exists:
#                  the roster is the live umbrella (its generated header
#                  block stripped so it is not nested inside the new one)
#                  plus the manifest's PENDING rows. Same equivalence +
#                  idempotency + compile-green gates as `apply`; on
#                  success the absorbed rows are `git rm`'d and rewritten
#                  in the manifest as `#absorbed <path>`, so the manifest
#                  stays the full provenance record and a re-run cannot
#                  double-absorb. `apply` still refuses to overwrite a
#                  live umbrella — that guard is what makes `absorb` an
#                  explicit, separate act.
#
# Manifests: scripts/consolidation/<area>.files — explicit, committed,
# one input path per line (# comments allowed). Exclusions (serial-retry
# rosters, #737 name-excluded, env-gated files) are simply never listed.
# `#absorbed <path>` rows are history: the file is gone, the umbrella
# carries it. `#retired <path>` says the same for an area whose umbrella
# was itself retired — the row names where the tests went, nothing more.
#
# ── ABSORPTION IS ONE-WAY (#1012, ruled here) ─────────────────────────
# An absorbed original is REMOVED from the tree and the umbrella carries
# its bodies. Every edit made to the umbrella afterwards lives ONLY in
# the umbrella — #1004's migration of the LSP pins off the unbounded
# `lsp_session` probe is the worked example. So a "restore the original
# and regenerate" would re-derive that section from bytes that predate
# the fix and drop it with NO diagnostic. That is the whole of #1012, and
# the direction taken here is the issue's second option: absorption is
# one-way, the manifest is history, and the guards make it mechanical.
#
# Four guards, each refusing BY NAME, checked in every mode (see
# `guard_one_way` below):
#   R1  a live manifest row the umbrella ALREADY carries — the row is
#       history that was never marked; regenerating would fold a second,
#       older copy of a section the umbrella already owns.
#   R2  an `#absorbed`/`#retired` row whose file is BACK in the tree —
#       somebody restored an original that the umbrella carries.
#   R3  a path recorded `#absorbed`/`#retired` in the COMMITTED manifest
#       that is live again in the working copy — an un-absorb in progress.
#   R4  (apply) the umbrella is tracked by git but missing from the
#       worktree — deleting the umbrella to "regenerate it fresh" is the
#       same resurrection with an extra step.
#
# Every check failure is a hard exit; nothing is deleted before the
# umbrella has compiled and run green in place.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"
V_FLAGS=(-cc cc -gc e -d cx_db_sqlite -d cx_db_redis -usecache)

usage() { echo "usage: $0 {gen|verify|apply|absorb|audit} <area>   (manifest: scripts/consolidation/<area>.files; 'audit all' sweeps every area)"; exit 2; }

[ $# -eq 2 ] || usage
mode="$1"; area="$2"
case "$mode" in gen|verify|apply|absorb|audit) : ;; *) usage ;; esac

# ── audit all: the standing sweep ─────────────────────────────────────
# Every area's guards, no generation. Reports every offending area rather
# than stopping at the first, then exits non-zero if any refused.
if [ "$mode" = audit ] && [ "$area" = all ]; then
  rc=0
  for m in scripts/consolidation/*.files; do
    a="$(basename "$m" .files)"
    "$ROOT/scripts/consolidate_tests.sh" audit "$a" || rc=1
  done
  if [ "$rc" -eq 0 ]; then
    echo "── consolidate[audit]: all areas clean (#1012 one-way-absorption guards)"
  fi
  exit "$rc"
fi

manifest="scripts/consolidation/${area}.files"
[ -f "$manifest" ] || { echo "consolidate_tests: no manifest $manifest"; exit 2; }

# input roster (blank + # lines ignored). macOS bash 3.2: no mapfile.
pending=()
while IFS= read -r line; do
  pending+=("$line")
done < <(grep -vE '^[[:space:]]*(#|$)' "$manifest")

# history rows: `#absorbed <path>` / `#retired <path>`. These are the
# provenance record — the file is gone, the umbrella carries it (#1012).
history_rows=()
while IFS= read -r line; do
  history_rows+=("$line")
done < <(awk '$1 == "#absorbed" || $1 == "#retired" { print $2 }' "$manifest")

# The umbrella's home. Normally the lane every pending row shares; when an
# area has no pending rows left (fully absorbed) that is unavailable, so
# fall back to the three lane dirs the tree actually uses.
if [ "${#pending[@]}" -ge 1 ]; then
  lane_dir="$(dirname "${pending[0]}")"
  for f in "${pending[@]}"; do
    [ "$(dirname "$f")" = "$lane_dir" ] || { echo "consolidate_tests: inputs span directories ($lane_dir vs $(dirname "$f")) — one area, one lane dir"; exit 2; }
  done
  umbrella="${lane_dir}/${area}_umbrella_test.v"
else
  lane_dir=""
  umbrella=""
  for d in vcx/tests vcx/code vcx/platform; do
    cand="${d}/${area}_umbrella_test.v"
    # git as well as the filesystem: an umbrella DELETED from the worktree
    # is exactly the state R4 exists to catch, and a filesystem-only lookup
    # would lose the name it needs to refuse with.
    if [ -f "$cand" ] || git ls-files --error-unmatch -- "$cand" >/dev/null 2>&1; then
      lane_dir="$d"
      umbrella="$cand"
      break
    fi
  done
fi

# ── #1012: absorption is ONE-WAY ──────────────────────────────────────
# umbrella_sources — the source paths a live umbrella STAMPS on its
# sections (`// ── source: <path> ──`, written by consolidate_tests.cx).
# A section may carry a hand-added qualifier after the path
# ("… (re-authored W5) ──"); a hand-written banner that merely borrows the
# rule form and names no .v file is not a source stamp and is skipped.
umbrella_sources() {
  [ -n "$1" ] && [ -f "$1" ] || return 0
  awk '
    index($0, "// ── source: ") == 1 {
      s = substr($0, length("// ── source: ") + 1)
      sub(/ ──.*$/, "", s)
      sub(/ \(.*$/, "", s)
      if (s ~ /\.v$/) print s
    }' "$1"
}

guard_one_way() {
  local carried hit committed rc=0
  carried="$(umbrella_sources "$umbrella")"

  # R1 — a live row the umbrella already carries.
  hit=""
  if [ -n "$carried" ] && [ "${#pending[@]}" -ge 1 ]; then
    for f in "${pending[@]}"; do
      if grep -Fxq -- "$f" <<<"$carried"; then hit="${hit}    ${f}"$'\n'; fi
    done
  fi
  if [ -n "$hit" ]; then
    echo "consolidate_tests[$area]: REFUSED (#1012) — $umbrella ALREADY CARRIES these sources, so these manifest rows are history, not pending:"
    printf '%s' "$hit"
    echo "    Absorption is one-way. The umbrella's copy is the live one, and any fix made to it since it was absorbed exists ONLY there; regenerating from the row would fold an older second copy over it."
    echo "    Fix the MANIFEST, not the tree: rewrite each row above as '#absorbed <path>'."
    rc=1
  fi

  # R2 — a history row whose original is back in the tree.
  hit=""
  if [ "${#history_rows[@]}" -ge 1 ]; then
    for f in "${history_rows[@]}"; do
      if [ -e "$f" ]; then hit="${hit}    ${f}"$'\n'; fi
    done
  fi
  if [ -n "$hit" ]; then
    echo "consolidate_tests[$area]: REFUSED (#1012) — these originals were absorbed and REMOVED, but are back in the tree:"
    printf '%s' "$hit"
    echo "    A restored original is a resurrection: its bodies predate every edit made to ${umbrella:-the umbrella} since absorption, and a regeneration would reinstate them silently."
    echo "    Take the umbrella's bodies, not theirs: delete the restored file(s) again, or edit the umbrella directly."
    rc=1
  fi

  # R3 — a path the COMMITTED manifest records as history, live again here.
  committed="$(git show "HEAD:$manifest" 2>/dev/null | awk '$1 == "#absorbed" || $1 == "#retired" { print $2 }' || true)"
  hit=""
  if [ -n "$committed" ] && [ "${#pending[@]}" -ge 1 ]; then
    for f in "${pending[@]}"; do
      if grep -Fxq -- "$f" <<<"$committed"; then hit="${hit}    ${f}"$'\n'; fi
    done
  fi
  if [ -n "$hit" ]; then
    echo "consolidate_tests[$area]: REFUSED (#1012) — these rows are recorded as absorbed history in the COMMITTED $manifest but are live in the working copy:"
    printf '%s' "$hit"
    echo "    Un-absorbing is not a supported edit. The umbrella owns those bodies; re-deriving them from the originals drops whatever was fixed in the umbrella afterwards."
    rc=1
  fi

  # R4 — apply over an umbrella that was deleted to make room for it.
  if [ "$mode" = apply ] && [ -n "$umbrella" ] && [ ! -e "$umbrella" ]; then
    if git ls-files --error-unmatch -- "$umbrella" >/dev/null 2>&1; then
      echo "consolidate_tests[$area]: REFUSED (#1012) — $umbrella is tracked by git but missing from the worktree."
      echo "    Deleting a live umbrella so 'apply' can rebuild it from the originals is the same silent resurrection with an extra step. Restore it (git checkout -- $umbrella) and use 'absorb' to fold new inputs in."
      rc=1
    fi
  fi

  return "$rc"
}

guard_one_way || exit 2

if [ "$mode" = audit ]; then
  echo "── consolidate[$area]: audit OK (${#pending[@]} pending, ${#history_rows[@]} history row(s); umbrella: ${umbrella:-none})"
  exit 0
fi

# Only now do the rows have to name real files: R1/R3 above name a MISSING
# input better than "manifest names missing file" ever could.
[ "${#pending[@]}" -ge 1 ] || { echo "consolidate_tests: area '$area' has no pending inputs — nothing to merge"; exit 2; }
for f in "${pending[@]}"; do
  [ -f "$f" ] || { echo "consolidate_tests: manifest names missing file: $f"; exit 2; }
done

# ── pre-flight: the inputs must be COMMITTED ──────────────────────────
# apply/absorb end in `git rm`, which refuses a file carrying uncommitted
# changes — and it refuses AFTER the umbrella has compiled and run, i.e.
# after the only expensive step. Refuse up front instead, naming the
# files. This runs before absorb strips the live umbrella's header, so a
# refusal here leaves the tree exactly as it was.
if [ "$mode" = apply ] || [ "$mode" = absorb ]; then
  dirty=$(git status --porcelain -- "${pending[@]}" | awk 'NF { print "    " $NF }')
  if [ -n "$dirty" ]; then
    echo "consolidate_tests: these inputs have uncommitted changes — commit them first (the merge ends in \`git rm\`, which will not discard unsaved work):"
    echo "$dirty"
    exit 2
  fi
fi

# ── roster: absorb prepends the live umbrella, the other modes do not ──
if [ "$mode" = absorb ]; then
  [ -f "$umbrella" ] || { echo "consolidate_tests: absorb needs an existing $umbrella (use 'apply' to create one)"; exit 2; }
  # Strip the umbrella's own GENERATED header block in place, so it is not
  # nested inside the new one. In place (not a scratch copy) on purpose:
  # the generator stamps each section with its input PATH, and a mktemp
  # path would break the idempotency gate. Restored by `git checkout` on
  # any failure below.
  # Capture once, then match — never `head … | grep -q …` under pipefail:
  # grep -q exits on the first match, head takes SIGPIPE (141), and pipefail
  # promotes that to a false failure (RULED: SPG-1, #916).
  umbrella_head="$(head -1 "$umbrella")"
  case "$umbrella_head" in
  *"_umbrella_test.v -- GENERATED by"*)
    awk 'NR==1{s=1} s==1 && /^\/\//{next} s==1 && /^[[:space:]]*$/{s=0;next} {print}' \
      "$umbrella" > "${umbrella}.hdrstrip"
    mv "${umbrella}.hdrstrip" "$umbrella"
    umbrella_touched=1
    ;;
  esac
  inputs=("$umbrella" "${pending[@]}")
else
  [ "${#pending[@]}" -ge 2 ] || { echo "consolidate_tests: area '$area' has <2 inputs — nothing to merge"; exit 2; }
  inputs=("${pending[@]}")
fi
scratch="$(mktemp -d "${TMPDIR:-/tmp}/consolidate_${area}.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
out1="$scratch/${area}_umbrella_test.v"
out2="$scratch/${area}_umbrella_2_test.v"

# The generator is fed the RESOLVED roster (absorb prepends the umbrella
# and drops the `#absorbed` history rows), while MANIFEST_LABEL keeps the
# header pointing at the committed manifest — a scratch path in the
# header would break the idempotency gate.
roster="$scratch/roster.files"
printf '%s\n' "${inputs[@]}" > "$roster"

run_gen() { # $1 = out path
  MANIFEST="$roster" MANIFEST_LABEL="$manifest" OUT="$1" AREA="$area" \
    "$CX_BIN" --allow-read --allow-write --allow-env scripts/consolidate_tests.cx
}

# On any failure after the umbrella has been written: `apply` created it,
# so remove it; `absorb` REPLACED a committed file (and stripped its
# header before the run), so restore the committed bytes. Never leave a
# half-absorbed umbrella behind.
restore_umbrella() {
  [ "${umbrella_touched:-0}" = 1 ] || return 0
  if [ "$mode" = absorb ]; then
    git checkout -- "$umbrella"
  else
    rm -f "$umbrella"
  fi
}

echo "── consolidate[$area]: generate (${#inputs[@]} inputs → $out1)"
run_gen "$out1"

# ── independent equivalence gate ──────────────────────────────────────
tfns_in=$(cat "${inputs[@]}" | grep -c '^fn test_' || true)
tfns_out=$(grep -c '^fn test_' "$out1" || true)
if [ "$tfns_in" -ne "$tfns_out" ]; then
  echo "consolidate_tests: EQUIVALENCE FAIL — test fns in=$tfns_in out=$tfns_out"
  restore_umbrella
  exit 1
fi
echo "── consolidate[$area]: test-fn equivalence OK ($tfns_in == $tfns_out; grep, independent of the generator)"

run_gen "$out2" >/dev/null
if ! cmp -s "$out1" "$out2"; then
  echo "consolidate_tests: IDEMPOTENCY FAIL — two runs differ"
  restore_umbrella
  exit 1
fi
echo "── consolidate[$area]: idempotent (second run byte-identical)"

case "$mode" in
  gen|verify)
    echo "── consolidate[$area]: $mode complete (no move; umbrella at $out1)"
    exit 0 ;;
  apply|absorb) : ;;
esac

# ── apply/absorb: move in, prove green, then remove the originals ─────
if [ "$mode" = apply ]; then
  [ -e "$umbrella" ] && { echo "consolidate_tests: $umbrella already exists — regenerating over a live umbrella needs its originals; use 'absorb'"; exit 2; }
fi
cp "$out1" "$umbrella"
umbrella_touched=1
echo "── consolidate[$area]: umbrella in place ($umbrella); compile+run"
log="vcx/target/consolidate_${area}.log"
if ! v "${V_FLAGS[@]}" test "$umbrella" >"$log" 2>&1; then
  # #572 classified retry: a stale -usecache layer can inject a duplicate
  # or missing C symbol; a C compile/link failure gets ONE cache-free
  # retry (cache-free green proves the artifact). Anything else is real.
  if grep -aqE 'C compilation error|linker command failed|symbol\(s\) not found|duplicate symbol' "$log"; then
    echo "── consolidate[$area]: C compile/link failure — cache-free retry (#572 class)"
    nocache_flags=()
    for fl in "${V_FLAGS[@]}"; do [ "$fl" = "-usecache" ] || nocache_flags+=("$fl"); done
    if ! v "${nocache_flags[@]}" test "$umbrella" >"$log" 2>&1; then
      echo "consolidate_tests: umbrella RED (also cache-free) — originals untouched; log: $log"
      tail -20 "$log"
      restore_umbrella
      exit 1
    fi
  else
    echo "consolidate_tests: umbrella RED — originals untouched; log: $log"
    tail -20 "$log"
    restore_umbrella
    exit 1
  fi
fi
echo "── consolidate[$area]: umbrella GREEN ($(grep -c '^fn test_' "$umbrella") test fns); removing ${#pending[@]} absorbed original(s)"
git rm -q -- "${pending[@]}"
if [ "$mode" = absorb ]; then
  # The absorbed rows become history in the manifest: the file is gone,
  # the umbrella carries it. A second `absorb` then finds no pending row
  # and refuses instead of double-absorbing.
  # The list rides in as a FILE, never `awk -v`: a -v value carrying
  # embedded newlines is rejected outright by BSD awk ("newline in
  # string"), which is the awk macOS actually runs. That never showed up
  # because the only absorb since this was written folded ONE row (#996),
  # and a one-element list has no newline in it.
  printf '%s\n' "${pending[@]}" > "$scratch/absorbed.list"
  awk 'NR == FNR { m[$0] = 1; next }
       { if ($0 in m) print "#absorbed " $0; else print }' \
    "$scratch/absorbed.list" "$manifest" > "${manifest}.new"
  mv "${manifest}.new" "$manifest"
  echo "── consolidate[$area]: ${#pending[@]} manifest row(s) marked #absorbed"
fi
echo "── consolidate[$area]: done — review + commit (one commit per area). Log: $log"
