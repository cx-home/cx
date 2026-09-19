#!/bin/sh
# profile_gate_selection_selftest.sh (#1560, RULED: VCOST-1) — the selection
# self-test VCOST-1 asks for: a touched file IS selected, an untouched one is
# NOT, and a `vcx/cx` change selects everything.
#
# It drives scripts/profile_gate_files_for_branch.sh with `git` shadowed by a
# stub that reports a planted change set, so each rule is exercised in a second
# rather than by making a commit. The same shim technique the nested-make probe
# uses (#1520); the stub answers only the two subcommands the helper calls and
# forwards nothing.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat > "$WORK/bin/git" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "rev-parse --verify") exit 0 ;;
esac
case "$1" in
  diff)      cat "$PLANTED" ;;
  "ls-files") : ;;
  *)         : ;;
esac
EOF
chmod +x "$WORK/bin/git"

fails=0
check() {
  want="$1"; shift
  name="$1"; shift
  printf '%s\n' "$@" > "$WORK/planted"
  got=$(PATH="$WORK/bin:$PATH" PLANTED="$WORK/planted" sh scripts/profile_gate_files_for_branch.sh origin/release/0.18 | tr -s ' ' | sed 's/ *$//')
  if [ "$got" = "$want" ]; then
    echo "  ok   $name → '$got'"
  else
    echo "  FAIL $name → '$got' (want '$want')"
    fails=$((fails + 1))
  fi
}

echo "profile-gate selection self-test (#1560):"
# A touched corpus file IS selected — and only it.
check "db.cxd" "one touched corpus file" "conformance/platform/db.cxd"
check "code.cxd db.cxd" "two touched corpus files" "conformance/platform/db.cxd" "conformance/code.cxd"
# An UNTOUCHED file is not: a docs-only change selects nothing at all.
check "" "a docs-only change selects nothing" "docs-src/llm/primer.md.tmpl"
# A `vcx/cx` change selects EVERYTHING — VCOST-1 names this rule.
check "ALL" "a vcx/cx change selects everything" "vcx/cx/program_lexer.v"
check "ALL" "an engine change selects everything" "vcx/code/eval.v"
check "ALL" "a stdlib change selects everything" "stdlib/map.cx"
# And so does a change to what GRADES, or to the gate policy.
check "ALL" "the runner itself selects everything" "vcx/tests/runners/profile_gate/profile_gate.v"
check "ALL" "the gate policy selects everything" "conformance/gates.cxd"
# A corpus file BESIDE an engine change is still ALL — the fail-safe direction.
check "ALL" "engine + corpus is ALL, not the corpus alone" "conformance/platform/db.cxd" "vcx/cx/program_lexer.v"

if [ "$fails" -gt 0 ]; then
  echo "profile-gate selection self-test: $fails failure(s)"
  exit 1
fi
echo "profile-gate selection self-test OK — 9 rules"
