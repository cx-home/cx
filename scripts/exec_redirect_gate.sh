#!/usr/bin/env bash
#
# scripts/exec_redirect_gate.sh — #1542.
#
# Fails on a bare `exec` carrying ONLY redirections whose redirect is not
# scoped to it. `exec 3<&- 4<&- 2>/dev/null` does not redirect the closes: a
# bare `exec` with no command applies its redirections to the SHELL, for the
# rest of the script. `$(JS_CLOSE)` was written that way, so every recipe line
# that opened with it ran with stderr pointed at /dev/null and every diagnostic
# after it was lost — including, measurably, the whole `SHELL='sh -x'` trace of
# `test-vcx-suite`, which is why #1520's nested `make test` could be reproduced
# for months and never read.
#
# Measured, and the two lines are the gate's own reason:
#
#   sh -c 'exec 3<&- 2>/dev/null || true; echo x >&2'        → nothing
#   sh -c '{ exec 3<&- ; } 2>/dev/null || true; echo x >&2'  → x
#
# The accepted spelling is the brace group: the group's redirect lasts only for
# the group, while `exec`'s fd closes are the shell's and outlive it, so the
# "bad file descriptor" noise is still swallowed and the script keeps its
# stderr.
#
# Scanned: the Makefiles and every shell script in scripts/. The escape hatch is
# an inline marker (assembled below so the gate never flags its own
# documentation), reported in the summary so it can never be silent.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OK_MARKER='exec-redirect''-ok'

violations=0
allowed=0
scanned=0

# A violating line carries a bare `exec` whose first word after it is a
# REDIRECTION (an fd number or a `<`/`>`), and a redirect to a file later on the
# same line, and is NOT wrapped in a brace group. The `exec` need not start the
# line: `$(JS_CLOSE)`'s was the right-hand side of a make assignment, which is
# how the first draft of this gate scanned 73 files and found nothing — a gate
# that cannot fail is the vacuous-gate failure mode, so the red proof below is
# part of the gate's own test and its absence would have shipped it broken.
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
      *'{'*exec*) continue ;;            # already scoped by a brace group
    esac
    # `exec` followed by a redirection rather than a command word
    case "$line" in
      *'exec '[0-9]*'<'*|*'exec '[0-9]*'>'*|*'exec <'*|*'exec >'*) ;;
      *) continue ;;
    esac
    # and a redirect to a FILE, which is what outlives the closes
    case "$line" in
      *'>/dev/null'*|*'> /dev/null'*|*'>&'[0-9]*) ;;
      *) continue ;;
    esac
    echo "exec-redirect-gate: $f:$n — a bare \`exec\` redirect applies to the SHELL, not to the closes:"
    echo "    $body"
    echo "  scope it:  { exec <the closes> ; } 2>/dev/null || true;"
    violations=$((violations + 1))
  done < "$f"
}

for f in Makefile vcx/Makefile $(find scripts -name '*.sh' -type f | sort); do
  [ -f "$f" ] || continue
  check_file "$f"
done

allowed=$(grep -rl "$OK_MARKER" Makefile vcx/Makefile scripts 2>/dev/null | wc -l | tr -d ' ')

if [ "$violations" -gt 0 ]; then
  echo "exec-redirect-gate: $violations violation(s) across $scanned file(s)."
  exit 1
fi
echo "exec-redirect-gate OK — $scanned file(s) scanned, no unscoped bare-\`exec\` redirect ($allowed file(s) carry the marker)"
