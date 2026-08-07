#!/usr/bin/env bash
# spec-freeze gate — remediation register R4.1 (#651/#516, ruled 2026-08-07).
#
# THE RULE (standing, absolute): no normative-spec change lands in the same
# commit as implementation without an EXPRESS recorded ruling. A ruling is
# referenced from the commit message with a token of the form
#     RULED: <row/letter id>          e.g.  RULED: R3.14   /  RULED: L184
# and must exist in the ledgers/register BEFORE the commit (rulings-before-
# edits, register R4.2 — the token is the machine-checkable half; the
# recorded ruling itself is reviewed by humans/audit).
#
# Path classes:
#   normative spec  = spec/** EXCEPT spec/02-working/partition_*.md
#                     (campaign ledgers/registers/audits are process records)
#   implementation  = everything else EXCEPT .claude/**, README*, CHANGELOG*,
#                     LICENSE*
# A commit touching BOTH classes with no RULED: token is a violation.
#
# Modes:
#   (default)             scan FREEZE_EPOCH..HEAD (every post-audit commit)
#   --check-commit <sha>  check one commit (used by the gate's own tests)
#   --staged              check the git index (pre-commit hook mode); the
#                         acknowledgment there is CX_RULED=<id> in the env,
#                         since the message does not exist yet — the range
#                         gate still enforces the message token afterward.
#
# FREEZE_EPOCH = the adversarial-audit commit that recorded the rule. History
# before it was adjudicated BY that audit; history after it is gated here.
set -euo pipefail

FREEZE_EPOCH=f964c16a

is_normative_spec() {
  case "$1" in
    spec/02-working/partition_*) return 1 ;;
    spec/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_impl() {
  case "$1" in
    spec/*|.claude/*|README*|CHANGELOG*|LICENSE*) return 1 ;;
    *) return 0 ;;
  esac
}

classify() { # reads paths on stdin -> "spec impl" flags
  local has_spec=0 has_impl=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_normative_spec "$f"; then has_spec=1; fi
    if is_impl "$f"; then has_impl=1; fi
  done
  echo "$has_spec $has_impl"
}

check_commit() {
  local sha="$1"
  local flags
  flags=$(git show --format="" --name-only "$sha" | classify)
  if [ "$flags" = "1 1" ]; then
    if ! git log -1 --format=%B "$sha" | grep -qE 'RULED:[[:space:]]*[A-Za-z0-9]'; then
      echo "SPEC-FREEZE VIOLATION: commit $sha touches normative spec AND implementation with no 'RULED: <id>' token (register R4.1)." >&2
      git show --format="  %h %s" --name-only "$sha" | head -20 >&2
      return 1
    fi
  fi
  return 0
}

case "${1:-}" in
  --check-commit)
    check_commit "$2"
    ;;
  --staged)
    flags=$(git diff --cached --name-only | classify)
    if [ "$flags" = "1 1" ] && [ -z "${CX_RULED:-}" ]; then
      echo "SPEC-FREEZE: the staged change touches normative spec AND implementation." >&2
      echo "Either split the commit, or — if an express ruling covers it — set CX_RULED=<row id>" >&2
      echo "and put 'RULED: <row id>' in the commit message (register R4.1/R4.2)." >&2
      exit 1
    fi
    ;;
  *)
    rc=0
    for sha in $(git rev-list --no-merges "${FREEZE_EPOCH}..HEAD" 2>/dev/null); do
      check_commit "$sha" || rc=1
    done
    if [ "$rc" -eq 0 ]; then
      echo "spec-freeze-gate: clean (${FREEZE_EPOCH}..HEAD)"
    fi
    exit "$rc"
    ;;
esac
