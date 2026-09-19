#!/bin/sh
# test_changed_selftest (#1516, RULED: RUN-1) — the detection power of the step
# and suite selection, proved case by case.
#
# HOW IT PROVES THINGS. `scripts/test_changed.sh --dry-run --changed-files <f>`
# takes the change set from a FILE and executes nothing, so every case below
# runs against the REAL Makefile, the REAL manifest rows, the REAL V import
# graph and the REAL shard manifest — the four things a synthetic two-commit
# repo could only imitate, and imitating them is how a selection selftest goes
# green over a manifest that is wrong. The one case that is about a tree rather
# than about this tree — a TEST_TARGETS entry with no row — gets a synthetic
# repo under mktemp, the shape scripts/head_is_docs_only_selftest.sh uses.
#
# THE CASES. The failure direction that matters is a FALSE SKIP, so each case
# names both what must be selected and what must not.
#
#   A  one x/ module source (x/ux-web.cx)        the shard that GRADES its
#                                                corpus, and no umbrella; the
#                                                boot-budget step is not in the
#                                                tail
#   B  one engine file (vcx/code/…)              the suite, per file, AND both
#                                                wall-clock tail steps
#   C  one scripts/ file                         the FULL union (build infra)
#   D  one module source (vcx/platform/          the shard grading its corpus +
#      stdlib_journal.v)                         every test that NAMES it, and
#                                                not the whole suite
#   E  a vcx/tests/ shared helper                the WHOLE suite
#   F  an input path that is NOT ON DISK         still selects its step (the
#                                                deleted-input case: the rows
#                                                must not be pathname-expanded)
#   G  a TEST_TARGETS entry with no row          check-selection-manifest FAILS
#
# Exit 0 and the count line only when every case matches.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TC="$ROOT/scripts/test_changed.sh"
CSM="$ROOT/scripts/check_selection_manifest.sh"
[ -f "$TC" ] || { echo "SELFTEST FAILED: no $TC" >&2; exit 1; }
[ -f "$CSM" ] || { echo "SELFTEST FAILED: no $CSM" >&2; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
cases=0

# run <path…> — the selection output for a synthetic change set.
run() {
	: > "$T/changed"
	for p in "$@"; do echo "$p" >> "$T/changed"; done
	( cd "$ROOT" && sh scripts/test_changed.sh HEAD --dry-run --changed-files "$T/changed" 2>&1 )
}

targets() { grep '^test-changed: RUN:' "$1" | sed 's/^test-changed: RUN: //'; }
suite_line() { grep '^test-changed: test-vcx-suite:' "$1"; }
suite_files_of() { suite_line "$1" | tr ' ' '\n' | grep '_test\.v$' || true; }
tail_of() { grep -- '--dry-run — serial tail:' "$1" | sed 's/.*serial tail: *//'; }

ok() { cases=$((cases + 1)); printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() {
	cases=$((cases + 1))
	fails=$((fails + 1))
	printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2
}

echo "test_changed selftest:"

# ── A — one x/ module source ────────────────────────────────────────────────
run x/ux-web.cx > "$T/a"
a_files=$(suite_files_of "$T/a")
a_n=$(printf '%s\n' "$a_files" | grep -c . || true)
a_t=$(targets "$T/a" | wc -w | tr -d ' ')
a_tail=$(tail_of "$T/a")
if [ "$a_n" -ge 1 ] && [ "$a_n" -le 3 ] \
	&& printf '%s\n' "$a_files" | grep -q 'code_eval_fixtures_shard_' \
	&& ! printf '%s\n' "$a_files" | grep -q 'umbrella' \
	&& [ "$a_t" -lt 30 ] \
	&& ! printf '%s' "$a_tail" | grep -q 'test-vcx-timing'; then
	ok A "$a_t targets, $a_n suite file(s) — its grading shard, no umbrella, no boot-budget step"
else
	bad A "x/ module source: $a_t targets, $a_n suite file(s), tail [$a_tail]"
fi

# ── B — one engine file ─────────────────────────────────────────────────────
run vcx/code/eval_core.v > "$T/b"
b_n=$(suite_files_of "$T/b" | grep -c . || true)
b_tail=$(tail_of "$T/b")
if [ "$b_n" -gt 20 ] \
	&& printf '%s' "$b_tail" | grep -q 'test-profile-gate' \
	&& printf '%s' "$b_tail" | grep -q 'test-vcx-timing'; then
	ok B "$b_n suite files and both wall-clock tail steps"
else
	bad B "engine file: $b_n suite files, tail [$b_tail]"
fi

# ── C — one scripts/ file ───────────────────────────────────────────────────
run scripts/some_gate.sh > "$T/c"
if grep -q 'running the FULL step union' "$T/c"; then
	ok C "build-infra change escalates to the full union"
else
	bad C "scripts/ change did not escalate to the union"
fi

# ── D — one module source ───────────────────────────────────────────────────
run vcx/platform/stdlib_journal.v > "$T/d"
d_files=$(suite_files_of "$T/d")
d_n=$(printf '%s\n' "$d_files" | grep -c . || true)
d_total=$(ls "$ROOT/vcx/tests"/*_test.v | wc -l | tr -d ' ')
d_named=1
for f in $d_files; do
	case "$f" in *code_eval_fixtures_shard_*) continue ;; esac
	grep -qF -- journal "$ROOT/$f" || d_named=0
done
if [ "$d_n" -ge 2 ] && [ "$d_n" -lt "$d_total" ] \
	&& printf '%s\n' "$d_files" | grep -q 'code_eval_fixtures_shard_' \
	&& [ "$d_named" -eq 1 ]; then
	ok D "$d_n of $d_total suite files — its grading shard plus every test that names it"
else
	bad D "module source: $d_n of $d_total suite files, named-check $d_named"
fi

# ── E — a vcx/tests/ shared helper ──────────────────────────────────────────
run vcx/tests/fixtures_grader/grade.v > "$T/e"
if suite_line "$T/e" | grep -q 'the WHOLE suite'; then
	ok E "a shared helper runs all $d_total files"
else
	bad E "shared helper did not escalate: [$(suite_line "$T/e")]"
fi

# ── F — an input that is not on disk ────────────────────────────────────────
# A DELETED file is in the diff and not in the tree. While the rows were
# pathname-expanded, `vcx/code/*` became the files that exist and a deleted one
# matched none of them, so its steps were SKIPPED — the false skip this manifest
# must never produce.
run vcx/code/a_file_that_was_deleted.v > "$T/f"
if targets "$T/f" | grep -q 'test-vcx-code'; then
	ok F "a deleted input still selects the step that reads it"
else
	bad F "a path not on disk selected nothing: [$(targets "$T/f")]"
fi

# ── G — a TEST_TARGETS entry with no row ────────────────────────────────────
# The only case that is about a TREE rather than about this tree, so it gets a
# synthetic one: the checker resolves the repo from its own path, which also
# proves it is relocatable.
mkdir -p "$T/repo/scripts"
cp "$CSM" "$T/repo/scripts/check_selection_manifest.sh"
cp "$TC" "$T/repo/scripts/test_changed.sh"
printf 'TEST_TARGETS := check-prod-build a-step-with-no-row\n' > "$T/repo/Makefile"
if ( cd "$T/repo" && sh scripts/check_selection_manifest.sh > "$T/g" 2>&1 ); then
	bad G "check-selection-manifest passed a TEST_TARGETS entry with no row"
elif grep -q 'a-step-with-no-row' "$T/g"; then
	ok G "check-selection-manifest names the rowless step and fails"
else
	bad G "check-selection-manifest failed without naming the rowless step"
fi

# ── H — an ESCALATED union is REFUSED under a pre-merge runner (#1489) ──────
# Case C proves the selection escalates; this proves the escalated selection is
# not EXECUTED on a shared box. It needs a non-dry run, and `--changed-files` is
# a dry-run-only flag by construction, so it gets a synthetic repo the way G
# does — with a TEST_TARGETS step that only touches a sentinel, so the arm that
# is NOT refused costs nothing and its sentinel is the proof it ran.
H="$T/h"
mkdir -p "$H/scripts"
cp "$TC" "$H/scripts/test_changed.sh"
cat > "$H/Makefile" <<'MK'
TEST_TARGETS := noop
build-vcx: ; @true
build-vcx-dev: ; @true
noop: ; @touch ran.sentinel
MK
: > "$H/scripts/some_gate.sh"
( cd "$H" && git init -q . && git add -A && git -c user.email=s@t -c user.name=s commit -qm base )
# A TRACKED build-infra path, modified: the change set comes from git, so an
# untracked file would not be in it and the case would prove nothing.
echo '# escalate' >> "$H/scripts/some_gate.sh"

h_run() { # $1 = the runner directory's basename
	rm -f "$H/ran.sentinel"
	( cd "$H" && env CX_BUILD_SLOT="$T/$1" sh scripts/test_changed.sh HEAD > "$T/h.log" 2>&1 ) || true
}

h_run .build-slot-impl2
if grep -q 'TEST-CHANGED: escalated → post-merge (INT-5)' "$T/h.log" && [ ! -f "$H/ran.sentinel" ]; then
	ok H1 "pre-merge runner: refused, nothing executed"
else
	bad H1 "pre-merge runner: no refusal line, or a step RAN (sentinel $( [ -f "$H/ran.sentinel" ] && echo present || echo absent ))"
fi

h_run .build-slot
if ! grep -q 'escalated → post-merge' "$T/h.log" && [ -f "$H/ran.sentinel" ]; then
	ok H2 "post-merge runner: not refused, the union ran"
else
	bad H2 "post-merge runner: refused, or the union did not run"
fi

rm -f "$H/ran.sentinel"
( cd "$H" && env CX_BUILD_SLOT="$T/.build-slot-impl2" TEST_CHANGED_FORCE_UNION=1 \
	sh scripts/test_changed.sh HEAD > "$T/h3.log" 2>&1 ) || true
if [ -f "$H/ran.sentinel" ]; then
	ok H3 "TEST_CHANGED_FORCE_UNION=1 overrides the refusal"
else
	bad H3 "TEST_CHANGED_FORCE_UNION=1 did not override the refusal"
fi

# ── I — NO LOOP IN THIS SCRIPT IS FED BY A HERE-DOCUMENT OR HERE-STRING ─────
# The post-merge run on baba91bbc stalled 38 MINUTES inside this script under
# the runner's nix bash 5.3: bash asleep at 0.01 s of CPU, no child, both ends
# of a self-pipe held by the same shell, the log ending at the change list.
# bash 5.1+ feeds a here-document through a PIPE rather than a temp file, and a
# command substitution in the loop's BODY forks a child that inherits that
# pipe's write end — so the reader never sees EOF while the writer, bash
# itself, is blocked on a full buffer.
#
# Measured under bash 5.3.9 while fixing it: the old shape with a forking body
# blocks from about 17 KB of content up (the real `suite_closure` content is
# 16,218 bytes against a 16,384-byte macOS pipe); process substitution runs
# 57 KB in seconds. This row is the SHAPE guard, because the shape is the
# defect — comments are stripped so the fix's own explanation cannot satisfy it.
hd=$(sed 's/#.*//' "$TC" | grep -cE 'done[[:space:]]*<[[:space:]]*<|done[[:space:]]*<<' || true)
if [ "$hd" = 0 ]; then
	ok I "no loop is fed by a here-document, a here-string or a process substitution — each reads a regular file"
else
	bad I "$hd loop(s) still read from a here-document, a here-string or a process substitution — the bash 5.3 self-pipe stall (and `< <(…)` is a syntax error under `sh`, which is how every pipeline invokes this file)"
fi

# ── J — a change set far larger than any pipe buffer runs to completion ─────
# The time bound is the regression guard the shape guard cannot be: it runs the
# REAL script, under the newest bash on this box, over a change set of ~200 KB.
BIG_BASH=$(command -v bash 2>/dev/null || echo /bin/bash)
for cand in /nix/store/*-bash-5*/bin/bash; do
	[ -x "$cand" ] && BIG_BASH=$cand && break
done
# ~70 KB in FEW lines: it is the BYTE SIZE that fills a pipe buffer, and the
# per-file work of the selection is linear in the LINE count, so a change set
# of 400 long paths exercises the hazard in seconds where 6,000 short ones
# spent seven minutes proving nothing extra (measured while writing this).
pad=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
pad="$pad$pad"
: > "$T/changed_big"
i=0
while [ "$i" -lt 400 ]; do
	printf 'vcx/code/%s_%04d.v\n' "$pad" "$i" >> "$T/changed_big"
	i=$((i + 1))
done
bsz=$(wc -c < "$T/changed_big" | tr -d ' ')
j0=$(date -u '+%s')
( cd "$ROOT" && "$BIG_BASH" scripts/test_changed.sh HEAD --dry-run --changed-files "$T/changed_big" ) > "$T/j.log" 2>&1
jrc=$?
jel=$(( $(date -u '+%s') - j0 ))
if [ "$jrc" -eq 0 ] && [ "$jel" -lt 30 ] && grep -q '^test-changed: RUN:' "$T/j.log"; then
	ok J "a ${bsz}-byte change set through $(basename "$(dirname "$(dirname "$BIG_BASH")")") completed in ${jel}s"
else
	bad J "a ${bsz}-byte change set: exit $jrc after ${jel}s (want 0 within 30s) — $BIG_BASH"
fi

# ── K — the parallel make of a SELECTED run keeps going (RULED: RUN-2) ──────
# `make test`'s storm carries `-k` so one failed run names every red step. A
# selected post-merge run is the common case now and it runs its parallel set
# from THIS script, so the same rule has to hold here or an escalated selection
# stops at its first red exactly as the union used to.
if grep -qE '^MAKEFLAGS_PAR="-k -j' "$TC"; then
	ok K "the parallel make of a selected run runs -k"
else
	bad K "MAKEFLAGS_PAR does not carry -k: $(grep -m1 '^MAKEFLAGS_PAR=' "$TC")"
fi

# ── L — the script parses under `sh`, which is how it is actually invoked ───
# The first fix for I used process substitution, `done < <(…)`. It keeps the
# loop in the shell and removes the pipe hazard, and it is a SYNTAX ERROR in
# POSIX mode — so `sh scripts/test_changed.sh`, which is what every pipeline,
# gate.sh and case H above use, died at line 532. `bash -n` was clean and the
# defect was still total. Both readings are asked for here.
if sh -n "$TC" 2>"$T/shn.err" && bash -n "$TC" 2>>"$T/shn.err"; then
	ok L "it parses under both sh and bash"
else
	bad L "it does not parse: $(tr '\n' ' ' < "$T/shn.err")"
fi

if [ "$fails" -ne 0 ]; then
	echo "test_changed selftest: $((cases - fails))/$cases — $fails case(s) FAILED" >&2
	exit 1
fi
echo "test_changed selftest: $cases/$cases (A x/ module; B engine; C scripts/ union; D module source; E shared helper; F deleted input; G rowless step; H escalated union refused under a pre-merge runner; I no here-document loop; J a 70 KB change set under bash 5.3; K the selected run keeps going; L it parses under sh)"
