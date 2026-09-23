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
#      `vcx/cx/`, the evaluator core under `vcx/code/`, `x/`, the V pin. This
#      is the rule VCOST-1 names explicitly: "a
#      `vcx/cx` change selects everything".
#
#  (2b) A BUNDLED MODULE's own source maps to that module's own corpus file
#      (#1587). `registry/modules.cxd` already carries the mapping, one row per
#      module, in its `source=` / `code=` / `half=` / `corpus=` columns, so this
#      reads the registry rather than guessing from a filename. It covers
#      `stdlib/<m>.cx`, `vcx/platform/stdlib_<m>.v`, `vcx/code/stdlib_<m>.v` and
#      every file a row's `half=` names.
#
#      Why it is owed: before it, EVERY branch that edited `stdlib/*.cx` — which
#      is most code branches — answered ALL, so #1560's selection never reached
#      one. Agent 1's c5 paid the unselected 70-100 minute profile gate for a
#      one-module change, and so did every stdlib branch of the campaign.
#
#      A source file NO row names is ALL, and so is a `vcx/code/` or
#      `vcx/platform/` file that is not some row's `code=` or `half=`: those are
#      the engine, and the doubt resolves upward as every other rule here does.
#      The unselected gate is unchanged — the post-merge union passes no
#      PROFILE_GATE_FILES at all and still grades everything.
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

# (1) and (2): what grades, and what it grades WITH. `conformance/code.cxd` is
# NOT here: #1560 already made it selectable by name through rule (3), that row
# is green in the self-test, and #1587 is the module map — not a re-reading of
# what the shared corpus is.
if printf '%s\n' "$CHANGED" | grep -qE '^(vcx/tests/runners/profile_gate/|vcx/tests/fixtures/|vcx/cx/|x/|third_party/v|conformance/gates\.cxd|conformance/fixtures\.cxs)'; then
  echo ALL
  exit 0
fi

# (2b) the module map (#1587). One pass over registry/modules.cxd: for each
# changed path under stdlib/, vcx/code/, vcx/platform/ or a split V product's
# directory (vcx/cxnet/, vcx/mail/, vcx/cxdb/ -- RULED: RS-24), find the row whose
# `source=`, `code=` or `half=` names it and take that row's `corpus=`
# basename. A path under those trees that no row names is the ENGINE, and the
# answer is ALL.
REG=registry/modules.cxd
MODSEL=''
CANDIDATES=$(printf '%s\n' "$CHANGED" | grep -E '^(stdlib/.*\.cx|vcx/code/.*\.v|vcx/platform/.*\.v|vcx/cxnet/.*\.v|vcx/mail/.*\.v|vcx/cxdb/.*\.v)$' || true)
if [ -n "$CANDIDATES" ]; then
  [ -r "$REG" ] || { echo ALL; exit 0; }
  for f in $CANDIDATES; do
    # the row that names this exact path in source= / code= / half=
    hit=$(awk -v want="$f" '
      /\[module / {
        corpus = ""; found = 0
        n = split($0, tok, /[ \t]+/)
        for (i = 1; i <= n; i++) {
          if (tok[i] ~ /^corpus=/) { corpus = substr(tok[i], 8) }
        }
        line = $0
        gsub(/'"'"'/, " ", line)
        m = split(line, w, /[ \t\]]+/)
        for (i = 1; i <= m; i++) {
          v = w[i]
          sub(/^source=/, "", v); sub(/^code=/, "", v); sub(/^half=/, "", v)
          if (v == want) { found = 1 }
        }
        if (found && corpus != "" && corpus != "none") { print corpus; exit }
      }' "$REG")
    if [ -z "$hit" ]; then
      echo ALL
      exit 0
    fi
    MODSEL="$MODSEL ${hit##*/}"
  done
fi

# (3) the corpus files themselves, plus the module map's answers.
SEL=$(printf '%s\n' "$CHANGED" | grep -E '^conformance/.*\.cxd$' | sed 's|.*/||' || true)
SEL=$(printf '%s\n%s\n' "$SEL" "$(printf '%s\n' $MODSEL)" | grep -v '^$' | sort -u | tr '\n' ' ')
printf '%s\n' "$(echo "$SEL" | sed 's/ *$//')"
