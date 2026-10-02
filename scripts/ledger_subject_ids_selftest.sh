#!/bin/sh
# ledger_subject_ids_selftest.sh (#1447) — the SUBJECT rule of
# `ledger-index-check`, on planted subjects under mktemp.
#
# A `(RULED: <id>)` in a commit subject claims that a decision governs the
# change. #1438's part 5 found seven ids claimed that way with no page behind
# them; a re-measure over every subject on release/0.18 found eleven. This is
# the rule that stops the twelfth, and these are the properties it rests on.
#
#   A  a subject citing a KNOWN id                    → the check passes
#   B  a subject citing an id with no page            → REFUSED, and it names it
#   C  a `RULED:` clause that is free prose with no parsable id → passes, by
#      design: much of the history's clause is prose (`CR-1..CR-6 — #1126`,
#      `EN-4(i`, `1573 class D`) and refusing it would red the union on three
#      years of subjects rather than on the thing #1447 is about
#   D  the real history on release/0.18 resolves — the eleven are closed
#   E  --allow-env denied                          → REFUSED, exit 2, the flag named (#1738)
#   F  --allow-subprocess denied                   → REFUSED, exit 2, the flag named (#1738)
#   G  a planted subjects file that is not there   → REFUSED, exit 2, by name (#1738)
#   H  two unresolved ids                          → counted as two, one line each (#1738)
#
# Planted through CX_LEDGER_SUBJECTS_FILE, which is the only input this reader
# takes other than `git log`, so the rule is proven without a repository.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CX=${CX_BIN:-deps/cx-core-code/vcx/target/cx}
[ -x "$CX" ] || { echo "ledger-subject-ids self-test: no cx binary at $CX — build first"; exit 2; }

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "ledger-subject-ids self-test (#1447):"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

check_with() { # check_with <subjects-file>
  CX_LEDGER_SUBJECTS_FILE="$1" \
    "$CX" --allow-read --allow-write --allow-env --allow-subprocess \
    scripts/ledger_index.cx --check 2>&1
}

# A — a known id
printf '%s\n' 'fix(x): something real (RULED: CFG-1)' > "$T/known.txt"
out=$(check_with "$T/known.txt"); rc=$?
if [ "$rc" -eq 0 ]; then
  ok A "a subject citing a declared id passes"
else
  bad A "a known id was refused — exit $rc: $out"
fi

# B — an id with no page
printf '%s\n' 'fix(x): a token nobody ruled (RULED: 9999-z)' > "$T/unknown.txt"
out=$(check_with "$T/unknown.txt"); rc=$?
if [ "$rc" -eq 1 ] && case "$out" in *9999-z*) true ;; *) false ;; esac; then
  ok B "an id with no page is refused, and the refusal names it"
else
  bad B "wanted exit 1 naming 9999-z — exit $rc: $out"
fi

# C — free prose in the clause, which the rule deliberately does not police
printf '%s\n' 'fix(x): an old subject (RULED: 1573 class D)' > "$T/prose.txt"
out=$(check_with "$T/prose.txt"); rc=$?
if [ "$rc" -eq 0 ]; then
  ok C "a RULED clause carrying no parsable id passes, as documented"
else
  bad C "free prose was refused — exit $rc: $out"
fi

# D — the real history
out=$("$CX" --allow-read --allow-write --allow-env --allow-subprocess \
        scripts/ledger_index.cx --check 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok D "every id cited in a subject on release/0.18 resolves to a page"
else
  bad D "the live history does not resolve — exit $rc: $out"
fi


# E/F/G — a read that fails is REFUSED, never counted (#1738). Measured on
# 63299f88a: with --allow-env denied the denial reached the id list as one
# element ("1 decision id(s) … resolve to NO page" and no id line); with
# --allow-subprocess denied the empty history "all resolve(s)", exit 0.
check_grants() { # check_grants <grant…> — the check with only these grants
  "$CX" --allow-read --allow-write "$@" scripts/ledger_index.cx --check 2>&1
}
out=$(check_grants --allow-subprocess); rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *"--allow-env"*) true ;; *) false ;; esac \
   && ! case "$out" in *"resolve to NO page"*) true ;; *) false ;; esac; then
  ok E "a denied --allow-env is refused (exit 2) naming the flag, never counted as an id"
else
  bad E "wanted exit 2 naming --allow-env and no unresolved count — exit $rc: $out"
fi
out=$(check_grants --allow-env); rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *"--allow-subprocess"*) true ;; *) false ;; esac \
   && ! case "$out" in *"all resolve"*) true ;; *) false ;; esac; then
  ok F "a denied --allow-subprocess is refused (exit 2) naming the flag, never an empty history that resolves"
else
  bad F "wanted exit 2 naming --allow-subprocess and no pass — exit $rc: $out"
fi
out=$(CX_LEDGER_SUBJECTS_FILE="$T/no-such-subjects.txt" \
        "$CX" --allow-read --allow-write --allow-env --allow-subprocess scripts/ledger_index.cx --check 2>&1); rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *"no-such-subjects.txt"*) true ;; *) false ;; esac; then
  ok G "a planted subjects file that cannot be read is refused (exit 2) by name, never an empty pass"
else
  bad G "wanted exit 2 naming the missing file — exit $rc: $out"
fi

# H — the unresolved ids are printed one per line, as the message promises
printf '%s\n' 'fix(x): two tokens nobody ruled (RULED: 9999-z, 9998-y)' > "$T/two.txt"
out=$(check_with "$T/two.txt"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx '    9999-z' && printf '%s\n' "$out" | grep -qx '    9998-y' \
   && case "$out" in *"2 decision id(s)"*) true ;; *) false ;; esac; then
  ok H "two unresolved ids are counted as two and each printed on its own line"
else
  bad H "wanted exit 1, a count of 2 and one line per id — exit $rc: $out"
fi

if [ "$fails" -ne 0 ]; then
  echo "ledger-subject-ids self-test: $fails case(s) FAILED" >&2
  exit 1
fi
echo "ledger-subject-ids self-test: 8/8 (a known id passes; an id with no page is refused by name; a prose clause passes; the live history resolves; a denied env or subprocess grant and an unreadable planted file are refused, never counted; unresolved ids print one per line)"
