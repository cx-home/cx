#!/usr/bin/env bash
#
# scripts/exit_status_probe_gate.sh — #1570.
#
# Fails on an exit status read through `devbox run … sh -c '<cmd>; … $? …'`.
# That shape answers **0 — success — for a program that exited non-zero**.
#
# Measured on `5a897f485`, with `p2.cx` = `[?lib 'cx-stdlib/env' as=env]` +
# `[$env:exit 7]`:
#
#   ./vcx/target/cx p2.cx; echo $?                      → 7   ✓
#   sh -c 'vcx/target/cx p2.cx; echo $?'                → 7   ✓
#   devbox run -- vcx/target/cx p2.cx; echo $?          → 7   ✓
#   devbox run -- sh -c 'exit 7'; echo $?               → 7   ✓
#   devbox run -- sh -c 'vcx/target/cx p2.cx; echo $?'  → 0   ✗
#
# So it is neither `devbox run` alone nor the inner `sh -c` alone: it is the two
# together around a program that exits non-zero. `devbox run` executes its
# arguments through a generated `.devbox/gen/scripts/.cmd.sh`, and in that path
# the inner command's status is lost while a bare `exit N` in the same position
# survives.
#
# WHY IT EARNS A GATE. It is the shape reached for when probing one command's
# status through the shared runner, and it is QUIET: it reports success. On
# 2026-09-18 it cost a wrong prio:high issue (#1569, withdrawn) in which
# `[$env:exit N]` looked broken and a dozen TEST_TARGETS gates looked vacuous.
# Both were fine. A probe that cannot be trusted is worse than no probe.
#
# WHAT IS FINE, and the distinction is the point: a pipeline script that
# captures `"$@" > log 2>&1; echo "EXIT=$?"` INSIDE the script devbox runs is
# sound — devbox executes that script as one unit and those statuses are real.
# Only the ad-hoc probe, the status read from an `echo $?` inside a `sh -c`
# devbox wraps, lies. So the gate matches `devbox run` and `sh -c` and a `$?`
# on the SAME line, which is exactly the ad-hoc shape and never the script.
#
# Scanned: the Makefiles, every shell script in scripts/, and every
# `_gate_evidence/*/pipeline.sh` — the branch pipelines are where an agent
# writes this shape. The escape hatch is an inline marker (assembled below so
# the gate never flags its own documentation), reported in the summary so it can
# never be silent.
#
#   sh scripts/exit_status_probe_gate.sh            # the tree
#   sh scripts/exit_status_probe_gate.sh <root>     # a planted root (selftest)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAN_ROOT="${1:-$ROOT}"
cd "$SCAN_ROOT" || exit 1

OK_MARKER='exit-status-probe''-ok'

violations=0
allowed=0
scanned=0

# A violating line names `devbox run`, opens an inner `sh -c` (or `bash -c`),
# and reads `$?` on that same line. All three on one line is the ad-hoc probe;
# a pipeline script that devbox runs carries its `$?` in its own file, where
# there is no `devbox run` on the line, so it never matches.
check_file() {
  local f="$1"
  scanned=$((scanned + 1))
  local n=0
  while IFS= read -r line; do
    n=$((n + 1))
    local body="${line#"${line%%[![:space:]]*}"}"
    case "$body" in
      '#'*) continue ;;                  # a comment, in make and in sh alike
    esac
    case "$line" in
      *"$OK_MARKER"*) continue ;;
    esac
    case "$line" in
      *'devbox run'*) ;;
      *) continue ;;
    esac
    case "$line" in
      *'sh -c'*) ;;
      *) continue ;;
    esac
    case "$line" in
      *'$?'*) ;;
      *) continue ;;
    esac
    # The three diagnostic lines below are deliberately split so that no ONE of
    # them carries all three tokens this gate matches on — the sibling gates
    # assemble their marker for the same reason, and the standard they set is
    # that the gate never needs its own escape hatch (#1542, SPG-1).
    echo "exit-status-probe-gate: $f:$n — #1570: this line reads an exit status out of an inner"
    echo "  shell that \`devbox run\` wraps, and that shape reports 0 for a program that FAILED:"
    echo "    $body"
    echo "  Read the status DIRECTLY from devbox run's own command word, or from INSIDE the"
    echo "  script devbox runs — a pipeline that captures it in its own file is sound."
    violations=$((violations + 1))
  done < "$f"
}

files=$( { [ -f Makefile ] && echo Makefile
           [ -f vcx/Makefile ] && echo vcx/Makefile
           find scripts -name '*.sh' -type f 2>/dev/null
           find _gate_evidence -name 'pipeline*.sh' -type f 2>/dev/null
         } | sort -u )
for f in $files; do
  [ -f "$f" ] || continue
  check_file "$f"
done

if [ "$scanned" -eq 0 ]; then
  echo "exit-status-probe-gate: scanned NO file under $SCAN_ROOT — refusing to vouch" >&2
  exit 1
fi

allowed=$(grep -rl "$OK_MARKER" Makefile vcx/Makefile scripts _gate_evidence 2>/dev/null | wc -l | tr -d ' ')

if [ "$violations" -gt 0 ]; then
  echo "exit-status-probe-gate: $violations violation(s) across $scanned file(s)."
  exit 1
fi
echo "exit-status-probe-gate OK — $scanned file(s) scanned, no exit status read through a devbox-wrapped \`sh -c\` ($allowed file(s) carry the marker)"
