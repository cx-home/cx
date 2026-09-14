#!/bin/sh
# head_is_docs_only_selftest — proves the INT-10 classifier's detection power on
# a SYNTHETIC repo (mktemp; never the live tree — the same rule the
# spec-freeze-gate selftest follows). The classifier's whole value is that it
# SKIPS a full post-merge run, so the cases that must be proved are the ones
# where it must NOT skip.
#
#   A  ledger/ + docs/ only                     → docs   (the case INT-10 exists for)
#   B  a file under spec/03-approved/           → FULL   (normative)
#   C  registry/modules.cxd                     → FULL   (rings are declared there)
#   D  root README.md + ledger/                 → docs
#   E  no last-passed head (empty base arg)     → FULL   (fail-safe)
#   F  a .md UNDER spec/03-approved/            → FULL   (markdown is not the test)
#   G  code + docs in the same head             → FULL   (one code path is enough)
#   H  registry/README.md                       → docs   (prose beside the registry)
#   I  a rename of a test file INTO docs/       → FULL   (--no-renames)
#   J  base == tip, empty diff (the re-run flag) → FULL   (never a vacuous doc run)
#   K  a base sha that is not a commit           → FULL   (fail-safe)
#
# Exit 0 and the count line only when every case matches.
set -u

CLS="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/head_is_docs_only.sh"
[ -f "$CLS" ] || { echo "SELFTEST FAILED: no classifier at $CLS" >&2; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# The classifier resolves its repo from its OWN path ($0/..), so the synthetic
# repo gets a scripts/ directory holding a copy. That also proves the script is
# relocatable — the post-merge runner invokes it from the main checkout.
mkdir -p "$T/scripts"
cp "$CLS" "$T/scripts/head_is_docs_only.sh"
CLS="$T/scripts/head_is_docs_only.sh"

cd "$T" || exit 1
git init -q .
git config user.email t@t
git config user.name t
mkdir -p ledger docs _gate_evidence spec/03-approved registry vcx/tests conformance
printf 'seed\n' > README.md
printf 'seed\n' > ledger/seed.md
# docs/ and _gate_evidence/ need a TRACKED file at the base: git does not track
# an empty directory, and case I's `git mv … docs/` failed silently-ish on the
# first cut because the directory did not exist after `git clean -fd`.
printf '<p>seed</p>\n' > docs/index.html
printf 'seed\n' > _gate_evidence/seed.log
printf 'seed\n' > spec/03-approved/thing.md
printf 'rows\n' > registry/modules.cxd
printf 'registry prose\n' > registry/README.md
printf 'code\n' > vcx/tests/thing_test.v
printf 'scripts\n' > scripts/keep.sh
git add -A && git commit -qm seed
BASE=$(git rev-parse --short HEAD)

# expect <name> <docs|full> <commit-command…>
check() {
	name=$1 want=$2 base=$3
	sh "$CLS" "$base" "$(git rev-parse --short HEAD)" >/dev/null 2>&1
	rc=$?
	case "$rc" in 0) got=docs ;; *) got=full ;; esac
	if [ "$got" = "$want" ]; then
		printf '  %-4s %-5s ok   (exit %s)\n' "$name" "$got" "$rc"
	else
		printf '  %-4s %-5s SELFTEST FAILED: wanted %s (exit %s)\n' "$name" "$got" "$want" "$rc" >&2
		fails=$((fails + 1))
	fi
	# every case starts from the same base commit
	git reset -q --hard "$BASE"
	git clean -qfd
}

echo "head_is_docs_only selftest:"

# A — ledger/ + docs/ only
printf 'a decision\n' >> ledger/seed.md
printf '<p>generated</p>\n' > docs/index.html
git add -A && git commit -qm "A"
check A docs "$BASE"

# B — an approved spec file (non-markdown spelling is impossible here; use the
#     directory itself, which is what the rule keys on)
mkdir -p spec/03-approved/process
printf 'normative\n' > spec/03-approved/process/thing.txt
git add -A && git commit -qm "B"
check B full "$BASE"

# C — registry/modules.cxd
printf 'a new row\n' >> registry/modules.cxd
git add -A && git commit -qm "C"
check C full "$BASE"

# D — root README.md + ledger/
printf 'prose\n' >> README.md
printf 'more\n' >> ledger/seed.md
git add -A && git commit -qm "D"
check D docs "$BASE"

# E — no last-passed head: the runner passes an empty base
printf 'prose\n' >> README.md
git add -A && git commit -qm "E"
check E full ""

# F — a .md UNDER spec/03-approved/
printf 'a normative clause\n' >> spec/03-approved/thing.md
git add -A && git commit -qm "F"
check F full "$BASE"

# G — code AND docs in one head
printf 'fn test_new() {}\n' >> vcx/tests/thing_test.v
printf 'and prose\n' >> ledger/seed.md
git add -A && git commit -qm "G"
check G full "$BASE"

# H — registry/README.md
printf 'more prose\n' >> registry/README.md
git add -A && git commit -qm "H"
check H docs "$BASE"

# I — a rename of a test file INTO docs/. Both sides must be judged, so the
# classifier runs `git diff --no-renames`; with rename detection on,
# `--name-only` prints only `docs/thing_test.v` and this head reads as docs.
git mv vcx/tests/thing_test.v docs/thing_test.v
git commit -qm "I" >/dev/null
[ -n "$(git diff --name-only "$BASE" HEAD)" ] || {
	echo "SELFTEST FAILED: case I built an empty diff" >&2; fails=$((fails + 1)); }
check I full "$BASE"

# J — base == tip (the re-run flag forces a re-grade of an unchanged tip)
check J full "$(git rev-parse --short HEAD)"

# K — a base sha that is not a commit in this repo
printf 'prose\n' >> ledger/seed.md
git add -A && git commit -qm "K"
check K full "deadbee"

if [ "$fails" -ne 0 ]; then
	echo "head_is_docs_only selftest: $fails case(s) FAILED" >&2
	exit 1
fi
echo "head_is_docs_only selftest: 11/11 (docs A/D/H; full B/C/E/F/G/I/J/K)"
