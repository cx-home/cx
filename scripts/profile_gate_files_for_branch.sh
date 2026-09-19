#!/bin/sh
# profile_gate_files_for_branch.sh (#1560, RULED: VCOST-1) — the
# PROFILE-GATE-FILES selection a branch owes, derived from its own diff.
#
#     make test-profile-gate PROFILE_GATE_FILES="$(sh scripts/profile_gate_files_for_branch.sh origin/release/0.18)"
#
# `test-profile-gate` grades the whole ring≤1 corpus through TWO engine
# compositions and is an 11-18 minute serial tail on EVERY run whatever the
# branch touched (measured, VCOST-1's page). What a branch can actually move is
# a short list, and this prints it — the same shape, and the same fail-safe
# direction, as fixture_files_for_branch.sh (#1513).
#
# Prints, on one line:
#   * `ALL` — no selection is safe; grade everything. Every doubt resolves here;
#   * a space-separated list of corpus file BASENAMES (`code.cxd db.cxd`);
#   * nothing — the branch touches no corpus file and no engine source, so it
#     owes the step no selection.
#
# THE RULES, in the order they are applied.
#
#  (0) A base that is not a commit, or a git that refuses: ALL. The classifier's
#      value is that it SHRINKS a step, so every failure of it must grow one.
#
#  (1) ALL when the branch changes what GRADES rather than what is graded: the
#      runner itself, the fixtures library it loads the corpus with, the gate
#      policy (`conformance/gates.cxd`), or the ring tagging. A change there can
#      move any file's verdict.
#
#  (2) ALL when the branch changes the ENGINE the compositions are built from —
#      `vcx/cx/`, `vcx/code/`, `vcx/platform/`, `stdlib/`, `x/`, the V pin. This
#      is the rule VCOST-1 names explicitly: "a `vcx/cx` change selects
#      everything".
#
#  (3) Otherwise: the corpus files the branch touched, by basename. A
#      `conformance/**.cxd` edit selects that file and nothing else.
set -u
BASE=${1:-origin/release/0.18}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || { echo ALL; exit 0; }

git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null 2>&1 || { echo ALL; exit 0; }
CHANGED=$(git diff --name-only "$BASE"...HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
[ -z "$CHANGED" ] && { echo ""; exit 0; }

# (1) and (2): what grades, and what it grades WITH.
if printf '%s\n' "$CHANGED" | grep -qE '^(vcx/tests/runners/profile_gate/|vcx/tests/fixtures/|vcx/cx/|vcx/code/|vcx/platform/|stdlib/|x/|third_party/v|conformance/gates\.cxd|conformance/fixtures\.cxs)'; then
  echo ALL
  exit 0
fi

# (3) the corpus files themselves.
SEL=$(printf '%s\n' "$CHANGED" | grep -E '^conformance/.*\.cxd$' | sed 's|.*/||' | sort -u | tr '\n' ' ')
printf '%s\n' "$(echo "$SEL" | sed 's/ *$//')"
