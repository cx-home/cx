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
#   A  an agent/ux pin bump (deps.cxd)           the three steps that grade the
#                                                graduated modules against this
#                                                tree's binary
#   B  RETIRED (K7a): vcx/code/ left whole with cx-core-code
#   C  one scripts/ file                         the FULL union (build infra)
#   D  RETIRED (K7a): vcx/code/ left whole with cx-core-code
#   E  a vcx/tests/ shared helper                the WHOLE suite
#   F  an input path that is NOT ON DISK         still selects its step (the
#                                                deleted-input case: the rows
#                                                must not be pathname-expanded)
#   G  a TEST_TARGETS entry with no row          check-selection-manifest FAILS
#   J0 case J's wall-clock bound (#988's       the floor at idle, floor x a
#      shape, on fake clocks)                    same-process reference probe's
#                                                ratio under load, a fired bound
#                                                re-probed once before believed
#   M  a worktree whose third_party/* are        nothing is selected; a REAL
#      SYMLINKS, gitlink unchanged (#1599)       gitlink move still runs the
#                                                whole suite
#   N  a step runner under vcx/tests/runners/    the step that BUILDS it, and
#      (#1598)                                   not the whole suite
#   P  the shared grading core (vcx/corpus/,     the suite, the document step
#      #1634)                                    and the cmd step — every step
#                                                that runs it
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

# ── A — a pin bump of the graduated x/ modules ───────────────────────────────
# Until the x/ graduation left for cx-platform-agent and cx-platform-ux
# (RULED: RS-4, RS-1 — D45a; RS-12, #1591 item 12) this case was one x/ module
# source (x/ux-web.cx), the #1516 shape: an edit to it selected no fixture
# file at all. No x/ source is in this repository any more, so that change
# cannot happen here. Its successor is the PIN, as case O's is for sso:
# `deps.cxd` moving is a new agent or ux release meeting this tree's binary,
# and the three steps that grade those modules against it — the four
# real-socket programs, the tools-export golden and the ORIEL step — must each be
# selected by it. A false skip here is the #1516 defect one repository up.
run deps.cxd > "$T/a"
a_t=$(targets "$T/a")
a_miss=''
for s in test-agent-real tools-export-gate test-oriel; do
	printf '%s\n' $a_t | grep -q "^$s$" || a_miss="$a_miss $s"
done
if [ -z "$a_miss" ]; then
	ok A "an agent/ux pin bump (deps.cxd) selects test-agent-real, tools-export-gate and test-oriel"
else
	bad A "deps.cxd did not select:$a_miss — [$a_t]"
fi

# ── B — one engine file ─────────────────────────────────────────────────────
# RETIRED (K7a, RULED: RS-12): the only files this case could ever name lived
# in vcx/code/, which left whole with cx-core-code's extraction (RULED: D68a).
# suite_files()'s per-file narrowing (suite_graph/suite_closure) reads the
# CHANGED FILE'S OWN CONTENT from disk to place it in the dependency graph;
# there is no longer a vcx/code/*.v anywhere in this tree for that graph to
# hold, so the scenario this case checks (an engine-file edit widens the
# selection past a narrow shard) cannot be constructed here again — not
# loosened, retired the same way test-vcx-code itself was (its own step no
# longer exists either). The property lives on in cx-core-code's own gate.

# ── C — one scripts/ file ───────────────────────────────────────────────────
run scripts/some_gate.sh > "$T/c"
if grep -q 'running the FULL step union' "$T/c"; then
	ok C "build-infra change escalates to the full union"
else
	bad C "scripts/ change did not escalate to the union"
fi

# ── D — one module source ───────────────────────────────────────────────────
# vcx/identity/stdlib_authz_store.v RETIRED as this case's example (RULED:
# RS-12, RS-8; #1591 item K3): vcx/identity/ left with the extraction of
# cx-platform-identity. vcx/fabric/stdlib_fabric.v (vcx/platform/ until
# fabric's split, RS-24) replaced it there and was RETIRED in turn (RULED:
# RS-12, RS-8; #1591 item K3): vcx/fabric/ left with the extraction of
# cx-platform-fabric. vcx/xap/stdlib_xap.v (the composer, RS-24) replaced it
# and is now ITSELF RETIRED (RULED: RS-12, RS-8, RS-7, RS-20; #1591 item K3):
# vcx/xap/ left with the extraction of cx-platform-xap, and with it went
# every remaining platform PRODUCT directory (RULED: RS-12) -- vcx/ now
# carries only code/, the Ring-1 core, so a module source in it selects the
# generic core graders (code_eval_fixtures_test.v, code_parse_fixtures_test.v,
# cxparse_full_corpus_diff_test.v, reader_parity_test.v — every one of vcx/code/'s
# own files, not this module's), beside its own shard and its named umbrellas.
# vcx/code/stdlib_crypto.v: its shard is stdlib-4, and four umbrella tests name
# it literally outside that shard -- cli, identity, modules, stdlib. The
# named-check now reads only the `*_umbrella_test.v` files the selection
# carries (the literal-name promise this case is about), skipping the shard
# file and the generic whole-of-code graders every vcx/code/ change pulls in.
# RETIRED (K7a, RULED: RS-12): the same reason as case B -- vcx/code/ left
# whole, and with it the only files this case's per-shard, per-named-umbrella
# narrowing could ever be exercised against. cx-core-code's own gate is where
# that property lives now.

# ── E — a vcx/tests/ shared helper ──────────────────────────────────────────
run vcx/tests/fixtures_grader/grade.v > "$T/e"
e_total=$(ls "$ROOT/vcx/tests"/*_test.v 2>/dev/null | wc -l | tr -d ' ')
if suite_line "$T/e" | grep -q 'the WHOLE suite'; then
	ok E "a shared helper runs all $e_total files"
else
	bad E "shared helper did not escalate: [$(suite_line "$T/e")]"
fi

# ── F — an input that is not on disk ────────────────────────────────────────
# A DELETED file is in the diff and not in the tree. While the rows were
# pathname-expanded, `vcx/code/*` became the files that exist and a deleted one
# matched none of them, so its steps were SKIPPED — the false skip this manifest
# must never produce. Target step RETARGETED (K7a, RULED: RS-12) from
# test-vcx-code (retired: code's own in-module test now runs from the pin,
# same as every other extracted product's) to test-vcx-timing, whose row
# still names the literal `vcx/code/*` string (case matching, not real
# pathname expansion, so this proves the same property test-vcx-code did).
run vcx/code/a_file_that_was_deleted.v > "$T/f"
if targets "$T/f" | grep -q 'test-vcx-timing'; then
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

# ── the calibrated wall-clock bound case J runs under (J0 pins its shape) ───
# BIG_BASH is the newest bash on this box: case J runs the real script under
# it, and its $EPOCHREALTIME is the millisecond clock both J and its reference
# probe are timed with (a one-second `date +%s` reading cannot resolve a probe
# of a few seconds into a ratio; a bash without it falls back to that).
BIG_BASH=$(command -v bash 2>/dev/null || echo /bin/bash)
for cand in /nix/store/*-bash-5*/bin/bash; do
	[ -x "$cand" ] && BIG_BASH=$cand && break
done
now_ms() {
	"$BIG_BASH" -c 't=${EPOCHREALTIME:-}; if [ -n "$t" ]; then t=${t/[.,]/}; echo $((t / 1000)); else echo $(($(date +%s) * 1000)); fi'
}
# ms_s MS — a millisecond reading as seconds to one decimal, for the log line.
ms_s() { echo "$(($1 / 1000)).$((($1 % 1000) / 100))"; }
# J_FLOOR_MS is the IDLE bound — the 30 s case J always allowed. It is never
# loosened: on a machine whose reference probe reads at or under its idle cost
# the bound IS the floor, whatever the load average says.
# J_PROBE_IDLE_MS is the reference probe's cost on an idle dev2 — the probe is
# J's own work at one line instead of 400 (the same script, the same bash, a
# path of the same shape), so contention stretches both by the same factor.
# Measured 2026-09-23 on dev2: 2.67–2.75 s at load 12–15 (J 7.1–7.6 s beside
# it), 4.2–4.5 s at load ~20 (J 9.6 s), 5.3–7.5 s at load ~50 (J 12–13 s); the
# lowest reading is the reference, so an idle box keeps the floor and a
# faster one reads under it and keeps it too.
J_FLOOR_MS=30000
J_PROBE_IDLE_MS=2700
# j_bound PROBE_MS — the bound a probe reading earns: the floor stretched by
# the probe's ratio to its idle cost, never below the floor.
j_bound() {
	jb_b=$((J_FLOOR_MS * $1 / J_PROBE_IDLE_MS))
	[ "$jb_b" -lt "$J_FLOOR_MS" ] && jb_b=$J_FLOOR_MS
	echo "$jb_b"
}
# j_calibrated PROBE_FN WORK_FN — PROBE_FN prints the reference probe's
# elapsed ms; WORK_FN prints "<rc> <elapsed ms>" (rc 0: the work succeeded).
# Probe, derive the bound, run the work. A reading AT OR OVER its bound is
# not believed yet (#988): re-probe the machine once — a fresh reading carries
# whatever contention arrived mid-run — re-derive the bound and re-run the
# work once against it. Sets j_verdict (ok | starved | slow | failed),
# j_reprobes, and every reading: j_p1 j_b1 j_rc1 j_w1, j_p2 j_b2 j_rc2 j_w2.
j_calibrated() {
	j_reprobes=0 j_p2=- j_b2=- j_rc2=- j_w2=-
	j_p1=$("$1")
	j_b1=$(j_bound "$j_p1")
	j_out=$("$2")
	j_rc1=${j_out%% *} j_w1=${j_out##* }
	if [ "$j_rc1" -ne 0 ]; then j_verdict=failed; return 0; fi
	if [ "$j_w1" -lt "$j_b1" ]; then j_verdict=ok; return 0; fi
	j_reprobes=1
	j_p2=$("$1")
	j_b2=$(j_bound "$j_p2")
	j_out=$("$2")
	j_rc2=${j_out%% *} j_w2=${j_out##* }
	if [ "$j_rc2" -ne 0 ]; then
		j_verdict=failed
	elif [ "$j_w2" -lt "$j_b2" ]; then
		j_verdict=starved
	else
		j_verdict=slow
	fi
	return 0
}

# ── J0 — case J's wall-clock bound is CALIBRATED, never a bare constant ─────
# J reads a WALL CLOCK, and a wall clock is load-blind: the post-merge run on
# 684a12502 read J at 32 s against its 30 s bound at load ~50 while a dozen
# agents built, and the same case took 11 s alone minutes later — nothing was
# wrong with the selection. The tree already has the shape for a timing bound
# under contention (scripts/gen_guide/playground/gen_examples.cx, #988):
# measure the machine with a reference probe IN THE SAME PROCESS, derive the
# bound from it, and re-measure before believing a bound that fired. This case
# pins that shape on fake clocks, so it is exact and costs nothing:
#
#   j_bound P      = J_FLOOR_MS × P / J_PROBE_IDLE_MS, never below J_FLOOR_MS
#                    (the floor is the IDLE bound J always had — never loosened)
#   j_calibrated PROBE WORK
#                  probe, bound, work; a work reading at or over its bound is
#                  RE-PROBED ONCE and re-run once against the re-derived bound
#                  — starved (re-probe slow, retry within) passes and says so;
#                  slow (retry over its bound) fails; a failed work never
#                  re-probes.
j0_pop() {
	j0_v=$(sed -n '1p' "$1")
	sed '1d' "$1" > "$1.rest" && mv "$1.rest" "$1"
	echo "$j0_v"
}
j0_probe() { j0_pop "$T/j0_probe"; }
j0_work() { j0_pop "$T/j0_work"; }
# j0_case NAME PROBES WORKS WANT-VERDICT WANT-REPROBES — PROBES/WORKS are
# space-separated readings in call order; every one given must be consumed
# (a re-probe that did not happen leaves one behind).
j0_fails=""
j0_case() {
	printf '%s\n' $2 > "$T/j0_probe"
	: > "$T/j0_work"
	for j0_w in $3; do printf '%s\n' "$j0_w" | tr '/' ' ' >> "$T/j0_work"; done
	j_calibrated j0_probe j0_work
	j0_left=$(cat "$T/j0_probe" "$T/j0_work" | grep -c . || true)
	if [ "${j_verdict:-}" != "$4" ] || [ "${j_reprobes:-}" != "$5" ] || [ "$j0_left" != 0 ]; then
		j0_fails="$j0_fails [$1: verdict ${j_verdict:-none} reprobes ${j_reprobes:-none} unread $j0_left, want $4/$5/0]"
	fi
}
if ! command -v j_bound > /dev/null 2>&1 || ! command -v j_calibrated > /dev/null 2>&1; then
	bad J0 "no calibrated bound: j_bound / j_calibrated are not defined — case J reads a bare wall-clock constant"
else
	ji=$J_PROBE_IDLE_MS
	[ "$(j_bound "$ji")" = "$J_FLOOR_MS" ] || j0_fails="$j0_fails [idle probe: bound $(j_bound "$ji"), want the floor $J_FLOOR_MS]"
	[ "$(j_bound $((ji / 2)))" = "$J_FLOOR_MS" ] || j0_fails="$j0_fails [fast probe: bound $(j_bound $((ji / 2))), want the floor — never below it]"
	[ "$(j_bound $((ji * 3)))" = $((J_FLOOR_MS * 3)) ] || j0_fails="$j0_fails [3x probe: bound $(j_bound $((ji * 3))), want $((J_FLOOR_MS * 3))]"
	# readings: probe ms; work "rc/ms"
	j0_case idle-pass    "$ji"                 "0/$((J_FLOOR_MS / 3))"                            ok      0
	j0_case stretched    "$((ji * 2))"         "0/$((J_FLOOR_MS * 3 / 2))"                        ok      0
	j0_case starved      "$ji $((ji * 2))"     "0/$((J_FLOOR_MS * 4 / 3)) 0/$((J_FLOOR_MS * 4 / 3))" starved 1
	j0_case slow-at-idle "$ji $ji"             "0/$((J_FLOOR_MS * 4 / 3)) 0/$((J_FLOOR_MS * 4 / 3))" slow    1
	j0_case at-bound     "$ji $ji"             "0/$J_FLOOR_MS 0/$J_FLOOR_MS"                      slow    1
	j0_case failed       "$ji"                 "1/$((J_FLOOR_MS / 3))"                            failed  0
	if [ -z "$j0_fails" ]; then
		ok J0 "the bound is the floor at idle, floor x probe/idle under load, and a fired bound is re-probed once before it is believed"
	else
		bad J0 "the calibrated bound's shape:$j0_fails"
	fi
fi

# ── J — a change set far larger than any pipe buffer runs to completion ─────
# The time bound is the regression guard the shape guard cannot be: it runs the
# REAL script, under the newest bash on this box, over a change set of ~70 KB,
# against the CALIBRATED bound above (J0) — the 30 s floor at idle, stretched
# only by the reference probe measured here, in this process, beside it.
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
printf 'vcx/code/%s_probe.v\n' "$pad" > "$T/changed_probe"
bsz=$(wc -c < "$T/changed_big" | tr -d ' ')
j_probe_real() {
	jp_t0=$(now_ms)
	( cd "$ROOT" && "$BIG_BASH" scripts/test_changed.sh HEAD --dry-run --changed-files "$T/changed_probe" ) > "$T/jp.log" 2>&1
	echo $(($(now_ms) - jp_t0))
}
j_work_real() {
	jw_t0=$(now_ms)
	( cd "$ROOT" && "$BIG_BASH" scripts/test_changed.sh HEAD --dry-run --changed-files "$T/changed_big" ) > "$T/j.log" 2>&1
	jw_rc=$?
	jw_el=$(($(now_ms) - jw_t0))
	if [ "$jw_rc" -eq 0 ] && ! grep -q '^test-changed: RUN:' "$T/j.log"; then jw_rc=99; fi
	echo "$jw_rc $jw_el"
}
j_calibrated j_probe_real j_work_real
jbash=$(basename "$(dirname "$(dirname "$BIG_BASH")")")
jr1="$(ms_s "$j_w1")s against a $(ms_s "$j_b1")s bound (reference probe $(ms_s "$j_p1")s, idle $(ms_s "$J_PROBE_IDLE_MS")s)"
jr2="" jrc=$j_rc1
if [ "$j_reprobes" = 1 ]; then
	jrc=$j_rc2
	jr2="re-probed $(ms_s "$j_p2")s → bound $(ms_s "$j_b2")s, the retry took $(ms_s "$j_w2")s"
fi
case "$j_verdict" in
ok) ok J "a ${bsz}-byte change set through $jbash completed in $jr1" ;;
starved) ok J "a ${bsz}-byte change set through $jbash read $jr1 — the bound fired under contention; $jr2, within it" ;;
slow) bad J "a ${bsz}-byte change set: $jr1; $jr2 — want exit 0 within the calibrated bound (the $(ms_s "$J_FLOOR_MS")s floor at idle) — $BIG_BASH" ;;
*) bad J "a ${bsz}-byte change set: exit $jrc (want 0, with a RUN: line) after $jr1 $jr2 — $BIG_BASH" ;;
esac

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

# ── M — a SYMLINKED third_party/ is not a pin move (#1599) ─────────────────
# Every impl worktree carries third_party/re2 and third_party/v as SYMLINKS to
# the main checkout's submodules (AGENT-STANDING-RULES.md §Git), and `git diff
# HEAD` reports each as a TYPECHANGE — gitlink (mode 160000) → symbolic link
# (120000). The worktree half of the change set folded those two paths in, so
# on EVERY symlinked worktree the V-pin rows fired and test-vcx-suite widened
# to all of its files whatever the branch touched: measured 2026-09-22 on
# impl/cx-F-1515, a branch of one corpus file that graded the whole suite.
#
# A pin MOVES when the gitlink sha differs between the base and HEAD — the
# COMMITTED diff — and nothing the working tree holds can say otherwise. Both
# directions are proved on synthetic repos, the shape G and H use: the change
# set comes from git here, so --changed-files cannot reach this rule at all.
m_repo() { # $1 = directory, $2 = the gitlink sha its base commit records
	mkdir -p "$1/scripts" "$1/vcx/tests" "$1/third_party" "$1/elsewhere"
	cp "$TC" "$1/scripts/test_changed.sh"
	printf 'TEST_TARGETS := test-vcx-suite\n' > "$1/Makefile"
	: > "$1/vcx/tests/synthetic_test.v"
	( cd "$1" \
		&& git init -q . \
		&& git add Makefile scripts vcx \
		&& git update-index --add --cacheinfo "160000,$2,third_party/v" \
		&& git -c user.email=s@t -c user.name=s commit -qm base ) >/dev/null 2>&1
	ln -s "$1/elsewhere" "$1/third_party/v"
}
PIN_A=1111111111111111111111111111111111111111
PIN_B=2222222222222222222222222222222222222222

m_repo "$T/m1" "$PIN_A"
( cd "$T/m1" && sh scripts/test_changed.sh HEAD --dry-run ) > "$T/m1.log" 2>&1
if ! grep -q 'third_party/v' "$T/m1.log" && grep -q 'no changes vs HEAD' "$T/m1.log"; then
	ok M1 "a symlinked third_party/ over an unchanged gitlink is no change at all"
else
	bad M1 "the symlink was read as a pin move: [$(grep -m1 -e 'third_party/v' -e 'WHOLE suite' "$T/m1.log")]"
fi

m_repo "$T/m2" "$PIN_A"
( cd "$T/m2" \
	&& git update-index --add --cacheinfo "160000,$PIN_B,third_party/v" \
	&& git -c user.email=s@t -c user.name=s commit -qm 'pin bump' ) >/dev/null 2>&1
( cd "$T/m2" && sh scripts/test_changed.sh HEAD~1 --dry-run ) > "$T/m2.log" 2>&1
if grep -q '^  third_party/v$' "$T/m2.log" && suite_line "$T/m2.log" | grep -q 'the WHOLE suite'; then
	ok M2 "a REAL gitlink move is still a pin move, symlinked worktree and all"
else
	bad M2 "a moved pin did not run the whole suite: [$(suite_line "$T/m2.log")]"
fi

# ── N — a step runner under vcx/tests/runners/ (#1598) ─────────────────────
# `v test vcx/tests/` compiles no file under vcx/tests/runners/ — not one of
# them is a *_test.v — so a runner is not an input to test-vcx-suite at all.
# It was reaching the suite's fail-safe arm as an unclassified vcx/tests/ path
# and selecting all of its files: measured 2026-09-22 on impl/cx-F-1590, where
# the RUN-4 computed selection over a two-runner branch still asked for the
# whole suite. What a runner IS an input to is the step that BUILDS it, and
# each of the three below is named by its step's own manifest row.
n_case() { # $1 = case id, $2 = the changed runner file, $3… = the steps it must select
	n_id="$1"; n_path="$2"; n_miss=''
	shift 2
	n_want="$*"
	run "$n_path" > "$T/n_$n_id"
	for want in $n_want; do
		targets "$T/n_$n_id" | tr ' ' '\n' | grep -qx -- "$want" || n_miss="$n_miss $want"
	done
	if [ -z "$n_miss" ] && suite_line "$T/n_$n_id" | grep -q 'NO test file reads what changed'; then
		ok "$n_id" "${n_path#vcx/tests/runners/} selects $n_want and drops the suite"
	else
		bad "$n_id" "${n_path#vcx/tests/runners/}: unselected [${n_miss:- none}]; suite [$(suite_line "$T/n_$n_id")]"
	fi
}
n_case N1 vcx/tests/runners/extraction_gate/cli/extraction_gate_cli.v test-extraction-gate
n_case N2 vcx/tests/runners/profile_gate/profile_gate.v test-profile-gate check-profile-gate-selection
n_case N3 vcx/tests/runners/conformance/conformance_run.v test-vcx-conform check-conformance-coverage
# and the three do not select EACH OTHER's step: the row is the runner's own.
n_cross=0
for pair in "N1 test-profile-gate" "N1 test-vcx-conform" "N2 test-extraction-gate" \
	"N3 test-extraction-gate" "N3 test-profile-gate"; do
	set -- $pair
	if targets "$T/n_$1" | tr ' ' '\n' | grep -qx -- "$2"; then n_cross="$n_cross $pair,"; fi
done
if [ "$n_cross" = 0 ]; then
	ok N4 "no runner selects another runner's step"
else
	bad N4 "a runner selected a step it is not an input to:$n_cross"
fi

# ── O — a PIN BUMP selects the interop step ────────────────────────────────
# The interop step is the ONLY step that grades the networked half of the sso stack,
# and until 2026-09-22 its row named the transport modules but not the module
# itself: a change to exactly stdlib/sso.cx + conformance/platform/sso.cxd put
# the step in the SKIP list (#1591 item 11, flag F-6).
#
# Since the extraction (RULED: RS-12) the module is not in this repository and
# that shape of change cannot happen here. Its successor is the PIN: `deps.cxd`
# moving is a new sso release meeting this tree's oidc, saml, session and
# transport, which is the change most likely to break the step and the one a
# false skip would hide. Same defect, one repository up.
run deps.cxd > "$T/m"
if targets "$T/m" | tr " " "\n" | grep -q "^test-sso-interop$"; then
	ok O "an sso pin bump (deps.cxd) selects test-sso-interop"
else
	bad O "deps.cxd did not select test-sso-interop: [$(targets "$T/m")]"
fi

# ── Q — the LLM layer's readers are named where they ARE (PLAY-2, RS-8) ─────
# docs/llm/* is embedded in the binary and read by two CLI test files that
# left with cx-core-code's extraction (RULED: RS-12). The row named them under
# vcx/tests/, a path this tree no longer holds, and `v test` refused the
# selection (exit 2) — a false RED that the union never shows, because the
# union points at the whole pinned directory. Every suite file the row names
# must be on disk.
run docs/llm/primer.md > "$T/q"
q_bad=""
for f in $(suite_files_of "$T/q"); do
	[ -f "$ROOT/$f" ] || q_bad="$q_bad $f"
done
if [ -z "$q_bad" ] && suite_files_of "$T/q" | grep -q 'cli_umbrella_test\.v$'; then
	ok Q "docs/llm/* names the CLI readers at their pinned path: $(suite_files_of "$T/q" | tr '\n' ' ')"
else
	bad Q "docs/llm/* names a suite file that is not on disk:${q_bad:- (none named)} — [$(suite_line "$T/q")]"
fi

# ── P — the shipped grading core under vcx/corpus/ (#1634) ─────────────────
# RS-16 moved the module-corpus grading loop into vcx/corpus/, which the cx
# binary links for `cx corpus`, every fixtures shard calls, and (#1631) the
# document runner reaches for its document-reading core (the profile gate is not
# among them: profile_gate.v carries its own mirror and imports no corpus
# module). No ring row named the directory, so a change to exactly that loop
# SKIPPED every step that runs it — the false-skip direction this selftest
# exists for.
run vcx/corpus/grade.v > "$T/p"
p_miss=""
for st in test-vcx-suite test-vcx-conform test-vcx-cmd; do
	targets "$T/p" | tr " " "\n" | grep -qx -- "$st" || p_miss="$p_miss $st"
done
if [ -z "$p_miss" ]; then
	ok P "vcx/corpus/grade.v selects test-vcx-suite, test-vcx-conform and test-vcx-cmd"
else
	bad P "vcx/corpus/grade.v did not select:$p_miss"
fi

if [ "$fails" -ne 0 ]; then
	echo "test_changed selftest: $((cases - fails))/$cases — $fails case(s) FAILED" >&2
	exit 1
fi
echo "test_changed selftest: $cases/$cases (A an agent/ux pin bump; C scripts/ union; E shared helper; F deleted input; G rowless step; H escalated union refused under a pre-merge runner; I no here-document loop; J0 the calibrated wall-clock bound; J a 70 KB change set under bash 5.3; K the selected run keeps going; L it parses under sh; M a symlinked third_party/ is not a pin move; N a step runner selects its own step; O a module-only sso change selects the interop step; P the vcx/corpus grading core selects the steps that run it)"
