#!/usr/bin/env bash
# spec-freeze gate — remediation register R4.1 (#651/#516; RULED (a) BY OWNER
# 2026-08-09 at the post-exit review — the gate was landed with the
# remediation wave under the register's recommended option and the ruling
# followed; the recorded-ruling match below closed with the ruling).
#
# THE RULE (standing, absolute): no normative-spec change lands in the same
# commit as implementation without an EXPRESS recorded ruling. A ruling is
# referenced from the commit message with a token of the form
#     RULED: <row/letter id>          e.g.  RULED: R3.14   /  RULED: L184
# and must exist in the ledgers/register BEFORE the commit (rulings-before-
# edits, register R4.2). The token is machine-checked TWO ways: it must be
# present, and at least one of its id fragments must appear in a recorded
# ruling store (ledger/**/*.md — the ledgers/registers; recursive, so an
# archived ledger's rulings stay resolvable) — a token naming NO recorded
# ruling fails the gate. Semantic review of the ruling itself stays with
# humans/audit.
#
# Path classes (R6.1 — the store is a LOCATION, not a filename prefix):
#   ledger          = ledger/** (process records; neither spec nor impl)
#   normative spec  = spec/** — NO exceptions for new work. The LEGACY
#                     spellings spec/02-working/partition_* / batch_* keep
#                     their ledger classification so pre-move history
#                     classifies as it did when written; the tree check in
#                     default mode refuses any file re-entering that
#                     namespace, so the legacy carve-out is not a loophole.
#   implementation  = everything else EXCEPT .claude/**, README*, CHANGELOG*,
#                     LICENSE*
# A commit touching BOTH spec and impl with no RULED: token is a violation.
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

# Adjudicated commits: authored on a PARALLEL integration lineage where this
# gate did not run, carrying an express owner ruling recorded OUTSIDE the
# token spelling (rewriting pushed shared history to add the token would be
# worse than the miss). Each row exists ONLY under owner authority and names
# where the ruling is recorded; the skip is LOUD (no-silent-skip rider,
# GATE_REGISTER.md). Full 40-char shas only.
ADJUDICATED_SHAS="
550f8a1a272ad2e0217fccdb5f0ec44e7e453154 #727-destination-(a) — owner-directed, recorded in the commit message + issue #727; register row: partition_I5_exit_review_packet.md §9 (exit-4a execution record)
"

is_normative_spec() {
  case "$1" in
    spec/02-working/partition_*|spec/02-working/batch_*) return 1 ;; # legacy ledger spelling (pre-R6.1 history only; tree check refuses new files here)
    spec/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_impl() {
  case "$1" in
    spec/*|ledger/*|.claude/*|README*|CHANGELOG*|LICENSE*) return 1 ;;
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

# token_recorded: at least one id fragment of any RULED: token payload greps
# (fixed-string) in the ruling stores. Fragments split on + , / and spaces;
# each is tried whole and with a trailing (…) qualifier stripped, so
# "R4.4(a-revised)" matches a store that records either spelling. Fragments
# shorter than 2 chars are ignored (never let "a" match everything).
#
# A token written parenthesized — "(RULED: 828-1a)" — leaves the wrapping
# ")" glued to the last fragment; only UNBALANCED trailing parens are
# stripped, so a recorded "(…)" qualifier inside the id survives intact.

strip_unbalanced_parens() { # $1 = fragment -> stdout
  local f="$1" o c
  while [ "${f%)}" != "$f" ]; do
    o=${f//[^(]/}; c=${f//[^)]/}
    [ "${#c}" -gt "${#o}" ] || break
    f="${f%)}"
  done
  printf '%s' "$f"
}
token_recorded() { # $1 = full commit message
  local payload frag base
  while IFS= read -r payload; do
    payload="${payload#*RULED:}"
    for frag in $(printf '%s' "$payload" | tr '+,/' '   '); do
      frag="${frag%%;*}"; frag="${frag%%.}"
      frag=$(strip_unbalanced_parens "$frag")
      [ "${#frag}" -ge 2 ] || continue
      base="${frag%%(*}"
      if grep -qrF --include='*.md' -- "$frag" ledger/ 2>/dev/null; then
        return 0
      fi
      if [ "$base" != "$frag" ] && [ "${#base}" -ge 2 ] \
        && grep -qrF --include='*.md' -- "$base" ledger/ 2>/dev/null; then
        return 0
      fi
    done
  done < <(printf '%s\n' "$1" | grep -E 'RULED:[[:space:]]*[A-Za-z0-9]' || true)
  return 1
}

check_commit() {
  local sha="$1"
  local flags msg full row
  full=$(git rev-parse "$sha")
  row=$(printf '%s\n' "$ADJUDICATED_SHAS" | grep -F "$full" || true)
  if [ -n "$row" ]; then
    echo "spec-freeze-gate: $sha ADJUDICATED (${row#* })"
    return 0
  fi
  flags=$(git show --format="" --name-only "$sha" | classify)
  if [ "$flags" = "1 1" ]; then
    msg=$(git log -1 --format=%B "$sha")
    if ! printf '%s\n' "$msg" | grep -qE 'RULED:[[:space:]]*[A-Za-z0-9]'; then
      echo "SPEC-FREEZE VIOLATION: commit $sha touches normative spec AND implementation with no 'RULED: <id>' token (register R4.1)." >&2
      git show --format="  %h %s" --name-only "$sha" | head -20 >&2
      return 1
    fi
    if ! token_recorded "$msg"; then
      echo "SPEC-FREEZE VIOLATION: commit $sha carries a RULED: token that names NO recorded ruling in ledger/ (register R4.1 — rulings are recorded BEFORE the work they authorize, R4.2)." >&2
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
    # R6.1 tree check — the legacy ledger namespace is CLOSED. Ledgers live
    # in ledger/; a file matching the old spelling at HEAD would silently
    # re-enter the historical carve-out above, so its existence is a
    # violation in itself.
    legacy=$(ls spec/02-working/partition_* spec/02-working/batch_* 2>/dev/null || true)
    if [ -n "$legacy" ]; then
      echo "SPEC-FREEZE VIOLATION: the legacy ledger namespace is closed (R6.1) — these files must live in ledger/:" >&2
      printf '  %s\n' $legacy >&2
      rc=1
    fi
    for sha in $(git rev-list --no-merges "${FREEZE_EPOCH}..HEAD" 2>/dev/null); do
      check_commit "$sha" || rc=1
    done
    if [ "$rc" -eq 0 ]; then
      echo "spec-freeze-gate: clean (${FREEZE_EPOCH}..HEAD)"
    fi
    exit "$rc"
    ;;
esac
