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
#   I  an id-SHAPED token the id grammar does not parse (CAPADDR-1, seven
#      letters) → REFUSED, exit 1, the token and the subject quoted (IDSH-1, #1767)
#   J  the same for a lower-case token (zzqx-9)            (IDSH-1, #1767)
#   K  the owner-letter shape D<digits><letter>[<digit>] is PARSED: D99z9,
#      which no page carries, is refused as unresolved by name (IDSH-1, #1767)
#   L  ... and D59a, which pages declare, resolves (IDSH-1, #1767)
#   M  a subject dated before IDSH-1 (a `<epoch>\t` prefix, the shape `git log`
#      is read in) keeps its unparsed prose; the same subject dated after it is
#      refused (IDSH-1: the rule binds from the decision on; the history before
#      it carries 89 such tokens, T-1 and sect-6 and CAPADDR-1 among them)
#   N  under CX_LEDGER_SUBJECTS_FILE the refusal names that file, not
#      release/0.18 (#1767)
#   O  an id-shaped token behind a typographic dash or glued to a character
#      the grammar has no place for (CFG\u2013 1, CAPADDR\u2010 1, CAPADDR-1_, CX2-1)
#      is refused, never "0 subject ids" (REFUTE-1 l02 l03 l04 l11)
#   P  a parenthesis inside a new clause does not end it: (RULED: CFG-1 (see
#      note), CAPADDR-1) refuses CAPADDR-1 (REFUTE-1 l05)
#   Q  a token a ledger page records as `TOKEN` (unparsed, IDSH-1) is excused
#      (MYSQLCDC-1 -> MYCDC-1); an unrecorded one is still refused (I)
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

# I/J — id-shaped tokens the grammar does not parse (IDSH-1, #1767). Measured on
# 8b63de0c7: each answered "0 subject id(s) … all resolve", exit 0.
for tok in CAPADDR-1 zzqx-9; do
  case $tok in CAPADDR-1) c=I ;; *) c=J ;; esac
  printf '%s\n' "chore: x (RULED: $tok)" > "$T/shape.txt"
  out=$(check_with "$T/shape.txt"); rc=$?
  if [ "$rc" -eq 1 ] && case "$out" in *"$tok"*"chore: x (RULED: $tok)"*) true ;; *) false ;; esac; then
    ok $c "an id-shaped token the grammar does not parse ($tok) is refused, the token and the subject quoted"
  else
    bad $c "wanted exit 1 quoting $tok and its subject — exit $rc: $out"
  fi
done

# K/L — the owner-letter shape is parsed and resolved (IDSH-1)
printf '%s\n' 'chore: x (RULED: D99z9)' > "$T/dbad.txt"
out=$(check_with "$T/dbad.txt"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx '    d99z9'; then
  ok K "D99z9 parses as an owner-letter id and, declared by no page (the IDSH-1 page only quotes it), is refused by name"
else
  bad K "wanted exit 1 naming d99z9 as undeclared — exit $rc: $out"
fi
printf '%s\n' 'chore: x (RULED: D59a)' > "$T/dgood.txt"
out=$(check_with "$T/dgood.txt"); rc=$?
if [ "$rc" -eq 0 ] && case "$out" in *" 1 subject id(s)"*) true ;; *) false ;; esac; then
  ok L "D59a parses as an owner-letter id and resolves to the pages that declare it"
else
  bad L "wanted exit 0 with one subject id resolved — exit $rc: $out"
fi

# M — the rule binds from IDSH-1 on: a dated line before it keeps its prose
printf '%s\t%s\n' 1791000000 'chore: old prose (RULED: T-1/T-2, sect-6)' > "$T/old.txt"
printf '%s\t%s\n' 1791100000 'chore: new prose (RULED: T-1/T-2, sect-6)' > "$T/new.txt"
out1=$(check_with "$T/old.txt"); rc1=$?
out2=$(check_with "$T/new.txt"); rc2=$?
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 1 ] && case "$out2" in *T-1*sect-6*) true ;; *) false ;; esac; then
  ok M "a subject dated before IDSH-1 keeps its unparsed prose; the same subject dated after it is refused"
else
  bad M "wanted exit 0 then exit 1 naming T-1 and sect-6 — exit $rc1 / $rc2: $out1 / $out2"
fi

# N — the refusal names where the subjects came from
out=$(check_with "$T/unknown.txt"); rc=$?
if [ "$rc" -eq 1 ] && case "$out" in *"unknown.txt"*) true ;; *) false ;; esac \
   && ! case "$out" in *"on release/0.18"*) true ;; *) false ;; esac; then
  ok N "under CX_LEDGER_SUBJECTS_FILE the refusal names the file, not release/0.18"
else
  bad N "wanted the planted file named and no release/0.18 — exit $rc: $out"
fi

# O — typographic dashes and glued characters (REFUTE-1 l02 l03 l04 l11)
for tok in "CFG$(printf '\342\200\223')1" "CAPADDR$(printf '\342\200\220')1" "CAPADDR-1_" "CX2-1"; do
  printf '%s\n' "chore: x (RULED: $tok)" > "$T/glued.txt"
  out=$(check_with "$T/glued.txt"); rc=$?
  if [ "$rc" -eq 1 ] && case "$out" in *"id-shaped token"*) true ;; *) false ;; esac; then
    ok O "$tok is refused as an id-shaped token the grammar does not parse"
  else
    bad O "wanted exit 1 refusing $tok — exit $rc: $out"
  fi
done

# P — a parenthesis inside a new clause (REFUTE-1 l05)
printf '%s\n' 'chore: x (RULED: CFG-1 (see note), CAPADDR-1)' > "$T/paren.txt"
out=$(check_with "$T/paren.txt"); rc=$?
if [ "$rc" -eq 1 ] && case "$out" in *"CAPADDR-1 -- in:"*) true ;; *) false ;; esac; then
  ok P "a parenthesis inside a new RULED clause does not end it; CAPADDR-1 after it is refused"
else
  bad P "wanted exit 1 refusing CAPADDR-1 — exit $rc: $out"
fi

# Q — a token a ledger page records as `TOKEN` (unparsed, IDSH-1) beside its renamed id is excused
#     (MYSQLCDC-1 -> MYCDC-1, cited in 3f720d7bc); an unrecorded one (CAPADDR-1, case I) still is not
printf '%s\n' 'chore: x (RULED: STREAM-1, MYSQLCDC-1)' > "$T/alias.txt"
out=$(check_with "$T/alias.txt"); rc=$?
if [ "$rc" -eq 0 ]; then
  ok Q "MYSQLCDC-1, recorded by its ledger page as renamed MYCDC-1, is excused; unrecorded tokens stay refused (I)"
else
  bad Q "wanted exit 0 for the page-recorded MYSQLCDC-1 — exit $rc: $out"
fi

if [ "$fails" -ne 0 ]; then
  echo "ledger-subject-ids self-test: $fails case(s) FAILED" >&2
  exit 1
fi
echo "ledger-subject-ids self-test: 20/20 (a known id passes; an id with no page is refused by name; a prose clause passes; the live history resolves; a denied env or subprocess grant and an unreadable planted file are refused, never counted; unresolved ids print one per line; an id-shaped token the grammar does not parse is refused with its subject (IDSH-1); the owner-letter D-shape parses and resolves; the rule binds from IDSH-1 on; the refusal names its source; typographic dashes and glued characters are refused; a parenthesis inside a new clause does not end it; a token its ledger page records as renamed is excused)"
