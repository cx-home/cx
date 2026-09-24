#!/bin/sh
# fixture_files_for_branch_selftest — proves the #1513 selection's detection
# power on a SYNTHETIC repo (mktemp; never the live tree — the same rule
# head_is_docs_only_selftest.sh and the spec-freeze-gate selftest follow). One
# case per rule in the helper's own header, and the cases that matter most are
# the ones where it must NOT shrink the step:
#
#   A  a corpus file in the walk              → that file            (rule 2)
#   B  vcx/<product>/stdlib_<m>.v          → <m>.cxd              (rule 3)
#   C  vcx/<product>/stdlib_<m>_*.v        → <m>.cxd, by dropping the tail
#   D  vcx/code/stdlib_<m>.v                  → code.cxd AND <m>.cxd (3 + 4)
#   E  stdlib/<m>.cx                          → <m>.cxd              (rule 3)
#   F  vcx/cx/ only                           → code.cxd             (rule 4)
#   G  the grader itself                      → ALL                  (rule 1)
#   H  a shard test file                      → ALL                  (rule 1)
#   I  scripts/run_fixture_shards.sh          → ALL                  (rule 1)
#   J  the V pin third_party/v                → ALL                  (rule 1)
#   K  stdlib/<x>.cx with NO corpus file      → ALL   (shared by every module)
#   L  a conformance file OUTSIDE the walk    → empty + a stderr note (rule 2)
#   M  a base that is not a commit            → ALL                  (rule 0)
#   N  a module source with a FAMILY and no exact file (stdlib_xap.v) → the family
#   O  docs only                              → empty (the branch owes nothing)
#   P  two corpus files at once               → both, sorted, deduplicated
#
# Exit 0 and the count line only when every case matches.
set -u

SEL="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/fixture_files_for_branch.sh"
[ -f "$SEL" ] || { echo "SELFTEST FAILED: no helper at $SEL" >&2; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# The helper resolves its repo from its OWN path ($0/..), so the synthetic repo
# gets a scripts/ directory holding a copy — which also proves it is
# relocatable, the way the pipelines invoke it from a worktree.
mkdir -p "$T/scripts"
cp "$SEL" "$T/scripts/fixture_files_for_branch.sh"
SEL="$T/scripts/fixture_files_for_branch.sh"

cd "$T" || exit 1
git init -q .
git config user.email t@t
git config user.name t

mkdir -p conformance/stdlib conformance/platform conformance/x conformance/xap \
	conformance/llm vcx/store vcx/xap vcx/code vcx/cx vcx/tests/fixtures_grader \
	stdlib third_party/v docs
# a synthetic corpus with the shapes the rules turn on: an exact name, the same
# name in two rings, a family with no exact file, and a file OUTSIDE the walk
for f in conformance/stdlib/saml.cxd conformance/stdlib/json.cxd \
	conformance/stdlib/term.cxd conformance/x/term.cxd \
	conformance/platform/connector.cxd conformance/platform/flow.cxd \
	conformance/platform/http.cxd conformance/xap/xap-on.cxd \
	conformance/xap/xap-compose.cxd conformance/xap/xap-dist.cxd \
	conformance/code.cxd conformance/core.cxd conformance/llm/prompts.cxd; do
	printf '[test-suite ring=1]\n' > "$f"
done
printf 'source\n' > vcx/store/stdlib_connector.v
printf 'source\n' > vcx/store/stdlib_saml_binding.v
printf 'source\n' > vcx/xap/stdlib_xap.v
printf 'source\n' > vcx/store/stdlib_iowatch.v
printf 'source\n' > vcx/code/stdlib_json.v
printf 'source\n' > vcx/cx/parser.v
printf 'source\n' > vcx/tests/fixtures_grader/grader.v
printf 'source\n' > vcx/tests/code_eval_fixtures_shard_2_test.v
printf 'wrapper\n' > scripts/run_fixture_shards.sh
printf 'pin\n' > third_party/v/keep
printf 'module source\n' > stdlib/flow.cx
printf 'module source\n' > stdlib/codec.cx
printf 'prose\n' > docs/index.html
git add -A && git commit -qm seed
BASE=$(git rev-parse --short HEAD)

# expect <name> <want-stdout> [<base>]
check() {
	name=$1
	want=$2
	base=${3:-$BASE}
	got=$(sh "$SEL" "$base" 2>/dev/null)
	if [ "$got" = "$want" ]; then
		printf '  %-3s ok   %s\n' "$name" "${got:-<empty>}"
	else
		printf '  %-3s SELFTEST FAILED: got [%s], wanted [%s]\n' "$name" "$got" "$want" >&2
		fails=$((fails + 1))
	fi
	git reset -q --hard "$BASE"
	git clean -qfd
}

echo "fixture_files_for_branch selftest:"

# A — a corpus file in the walk
printf 'a case\n' >> conformance/xap/xap-on.cxd
git add -A && git commit -qm A
check A "conformance/xap/xap-on.cxd"

# B — vcx/store/stdlib_<m>.v
printf 'a fn\n' >> vcx/store/stdlib_connector.v
git add -A && git commit -qm B
check B "conformance/platform/connector.cxd"

# C — vcx/store/stdlib_<m>_*.v: saml-binding has no corpus file, saml does
printf 'a fn\n' >> vcx/store/stdlib_saml_binding.v
git add -A && git commit -qm C
check C "conformance/stdlib/saml.cxd"

# D — vcx/code/stdlib_<m>.v is BOTH rules at once
printf 'a fn\n' >> vcx/code/stdlib_json.v
git add -A && git commit -qm D
check D "conformance/code.cxd conformance/stdlib/json.cxd"

# E — stdlib/<m>.cx
printf 'a verb\n' >> stdlib/flow.cx
git add -A && git commit -qm E
check E "conformance/platform/flow.cxd"

# F — vcx/cx/ alone
printf 'a fn\n' >> vcx/cx/parser.v
git add -A && git commit -qm F
check F "conformance/code.cxd"

# G — the grader itself
printf 'a fn\n' >> vcx/tests/fixtures_grader/grader.v
git add -A && git commit -qm G
check G "ALL"

# H — a shard test file
printf 'a fn\n' >> vcx/tests/code_eval_fixtures_shard_2_test.v
git add -A && git commit -qm H
check H "ALL"

# I — the wrapper
printf 'a line\n' >> scripts/run_fixture_shards.sh
git add -A && git commit -qm I
check I "ALL"

# J — the V pin
printf 'moved\n' >> third_party/v/keep
git add -A && git commit -qm J
check J "ALL"

# K — a stdlib/*.cx with no corpus file of its own name: shared by every module
printf 'a verb\n' >> stdlib/codec.cx
git add -A && git commit -qm K
check K "ALL"

# L — a conformance file the grader does not walk: left out, named on stderr
printf 'a case\n' >> conformance/core.cxd
git add -A && git commit -qm L
sh "$SEL" "$BASE" 2>"$T/err" >/dev/null
grep -q 'conformance/core.cxd' "$T/err" || {
	echo "  L   SELFTEST FAILED: core.cxd was dropped with no note on stderr" >&2
	fails=$((fails + 1))
}
check L ""

# M — a base that is not a commit
printf 'a case\n' >> conformance/xap/xap-on.cxd
git add -A && git commit -qm M
check M "ALL" deadbee

# N — a module source with a FAMILY and no exact file
printf 'a fn\n' >> vcx/xap/stdlib_xap.v
git add -A && git commit -qm N
check N "conformance/xap/xap-compose.cxd conformance/xap/xap-dist.cxd conformance/xap/xap-on.cxd"

# O — docs only: the branch owes this step no selection
printf '<p>more</p>\n' >> docs/index.html
git add -A && git commit -qm O
check O ""

# P — two corpus files at once, sorted and deduplicated (the same file named by
#     its own edit AND by its module source must appear once)
printf 'a case\n' >> conformance/platform/connector.cxd
printf 'a fn\n' >> vcx/store/stdlib_connector.v
printf 'a case\n' >> conformance/stdlib/saml.cxd
git add -A && git commit -qm P
check P "conformance/platform/connector.cxd conformance/stdlib/saml.cxd"

if [ "$fails" -ne 0 ]; then
	echo "fixture_files_for_branch selftest: $fails case(s) FAILED" >&2
	exit 1
fi
echo "fixture_files_for_branch selftest: 16/16 (ALL G/H/I/J/K/M; selections A/B/C/D/E/F/N/P; empty L/O)"
