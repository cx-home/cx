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
a36244f40b17bc4726c4034685e13499b25f8411 #854+#849 — R6.2 batch (owner 2026-08-18 2a); express ruling R5.1 (register), recorded LATE per R5.0 — Class S, ledger/partition_832_process_audit.md Part 1
ab6a62e56530d2a0f1e8542238f843d114036824 #853 — R6.2 batch; express ruling R5.2 (register), recorded LATE per R5.0 — Class S
d3277277351de784e73ef9c482f56d881019233f #840 — R6.2 batch; express ruling R5.3 (register), recorded LATE per R5.0 — Class S
9a76fb184dcd79c575269eda727b8e27a6923db4 #808+#760+#833 — R6.2 batch; rulings 808-1a/760-1a/833-1a recorded BEFORE the work (exit packet §10); message wrote RULED without the colon — Class S
f62deb82c19060385cc87b4c9f88b49f04aa3e74 #823 — R6.2 batch; owner scope ruling recorded (exit packet: SCOPE IS THE WHOLE ISSUE); no token written — Class S
397cbfff151f21bc52286e34879b13d862962789 #819+#817+#778+#740 — R6.2 batch; #817 rides the batch_796 owner ruling (a file the old glob could not read); #819/#778/#740 unrecorded — Class U/M
c5019ca640a90913223216b6d34e9cc1c5784bf1 #844 — R6.2 batch; owner ruling 2a cited, ruled OUTCOME recorded in xap_grammar_composition.md (a working spec, not a store) — Class U
aef85bebbe2ec518625560ce442115e173ada40f #705 — R6.2 batch; media-type ruling recorded in grammar_lexicon_review.md (outside the old glob); rest is stale-citation cleanup — Class U/M
05e4e5d30ac9cadf2680c232031a2e6b93a0ba2f #837 — R6.2 batch; link-path typos + one stale example, no recorded ruling — Class M
efd780b17b6c5511f6a5d3fd16fee549a4fd614d #777-catch-up — R6.2 batch; illustrative enumeration completed, nothing behavioral; 777-1a covers the lane, arguably not this half — Class M
5a6ae8438b78782faa52f32c550b5ab5f16aaca6 #726-init — R6.2 batch; authoring-process §7 status row riding the feature commit, no recorded ruling — Class M
c6caa75609a7e12f0b7a4b60426032be4488fa62 #726-reference — R6.2 batch; spec pointers repointed at the landed app riding the app commit, no recorded ruling — Class M
c21515cb5766f09c1f48247e4e2c42bb4b5591fd #826-proposal — R6.2 batch; the proposal + its rendered demo, approval later given as R5.4 — Class M
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
