#!/bin/sh
# storm_keep_going_selftest.sh — the -j STORM of `make test` runs with `-k`
# (RULED: RUN-2).
#
# WHY. `make` stops at the first red step ("Waiting for unfinished jobs"), so a
# failed post-merge run named ONE class and the next run found the next one. On
# 2026-09-18 ten failed runs at about 1.5 h each found seventeen classes —
# under two per run — and the fix branch for a red head could only ever carry
# what the last log happened to name. With `-k` the storm runs every step it
# can, so ONE failed run names EVERY red step and the fix branch carries them
# all before the next tip.
#
# The three serial tail lines (test-profile-gate, test-vcx-timing,
# test-code-diagram) still run only after a GREEN storm: `-k` is on the storm's
# own sub-make, and the recipe line's non-zero status still stops `test:`.
#
# Two properties:
#
#   A  the SEMANTICS, on two tiny planted targets through a scratch makefile:
#      `make -k -j2` over a red target and two green ones runs BOTH greens and
#      still exits non-zero. The control — the same makefile WITHOUT `-k` —
#      leaves the second green unbuilt, so the fixture discriminates rather
#      than passing on any make at all.
#   B  the REAL recipe: `test:`'s storm line carries `-k`, and the three serial
#      tail lines are still separate recipe lines after it (so a red storm
#      still stops the gate before the tail).
#
#   sh scripts/storm_keep_going_selftest.sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAKEFILE=$ROOT/Makefile
MAKE=${MAKE:-make}

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "storm keep-going selftest (RULED: RUN-2):"

# ── A — the semantics, on planted targets ────────────────────────────────────
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# red fails IMMEDIATELY; g1 holds the second -j2 slot for a moment; g2 can only
# start once a slot frees, which is exactly the decision `-k` makes.
cat > "$T/Makefile" <<'PLANTED'
.PHONY: all red g1 g2
all: red g1 g2
red:
	@exit 1
g1:
	@sleep 2; : > g1.built
g2:
	@: > g2.built
PLANTED

run_planted() { # $1 = extra flags; prints the exit status, leaves the markers
	rm -f "$T/g1.built" "$T/g2.built"
	( cd "$T" && $MAKE $1 -j2 all ) > "$T/out.log" 2>&1
	echo $?
}

rc=$(run_planted -k)
if [ "$rc" -ne 0 ] && [ -f "$T/g1.built" ] && [ -f "$T/g2.built" ]; then
	ok A1 "-k -j2 ran BOTH green targets past the red one and still exited $rc"
else
	bad A1 "wanted a non-zero exit with g1.built and g2.built — exit $rc, g1=$([ -f "$T/g1.built" ] && echo yes || echo no) g2=$([ -f "$T/g2.built" ] && echo yes || echo no)"
fi

rc=$(run_planted '')
if [ "$rc" -ne 0 ] && [ ! -f "$T/g2.built" ]; then
	ok A2 "the control WITHOUT -k stopped before g2 (the fixture discriminates)"
else
	bad A2 "without -k the run should have left g2 unbuilt — exit $rc, g2=$([ -f "$T/g2.built" ] && echo yes || echo no)"
fi

# ── B — the real recipe ──────────────────────────────────────────────────────
[ -f "$MAKEFILE" ] || { echo "  B  SELFTEST FAILED: no Makefile at $MAKEFILE" >&2; exit 1; }

# The `test:` recipe — every TAB-indented line under the `test:` rule, to the
# first line that is not one of them.
recipe=$(awk '/^test:$/ { inr = 1; next }
              inr && !/^\t/ && NF { exit }
              inr { print }' "$MAKEFILE")
[ -n "$recipe" ] || { echo "  B  SELFTEST FAILED: could not read the test: recipe" >&2; exit 1; }

storm=$(printf '%s\n' "$recipe" | grep -F '$(MAKE) -k -j$(TEST_JOBS)')
if [ -n "$storm" ]; then
	ok B1 "the storm line runs -k"
else
	printf '%s\n' "$recipe" | grep -F '$(MAKE)' | grep -F -- '-j$(TEST_JOBS)' > "$T/storm.txt" 2>/dev/null || true
	bad B1 "the -j storm line does not carry -k: $(cat "$T/storm.txt")"
fi

# the serial tail is still three separate recipe lines AFTER the storm, so a red
# storm still stops `test:` before them.
tail_ok=1
for s in test-profile-gate test-vcx-timing test-code-diagram; do
	printf '%s\n' "$recipe" | grep -qF "\$(MAKE) $s" || tail_ok=0
done
storm_n=$(printf '%s\n' "$recipe" | grep -nF '$(MAKE) -k -j$(TEST_JOBS)' | head -1 | cut -d: -f1)
tail_n=$(printf '%s\n' "$recipe" | grep -nF '$(MAKE) test-profile-gate' | head -1 | cut -d: -f1)
if [ "$tail_ok" = 1 ] && [ -n "$storm_n" ] && [ -n "$tail_n" ] && [ "$tail_n" -gt "$storm_n" ]; then
	ok B2 "the three serial tail lines still follow the storm on their own lines"
else
	bad B2 "the serial tail (test-profile-gate, test-vcx-timing, test-code-diagram) is not three lines after the storm"
fi

if [ "$fails" -ne 0 ]; then
	echo "storm keep-going selftest: $fails case(s) FAILED" >&2
	exit 1
fi
echo "storm keep-going selftest: 4/4 (planted -k runs past a red target and exits non-zero; the control without -k does not; the storm line carries -k; the serial tail is unchanged)"
