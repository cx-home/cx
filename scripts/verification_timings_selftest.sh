#!/bin/sh
# verification_timings_selftest.sh (issue 1583, RULED: RUN-5) — the WRITER of
# vcx/target/verification_timings.cxd, on planted files under mktemp.
#
# #1562's budget step shipped with no writer at all: every bound read NOT
# MEASURED, so the step judged nothing. These are the properties the two
# writers (the post-merge runner at RUN-EXIT, scripts/run_fixture_shards.sh on
# an unselected grader run) rest on.
#
#   A  an ABSENT file → the document is created with exactly the row asked for
#   B  a planted log with two other rows → a second write REPLACES only its own
#      row and keeps the others, unchanged and in place
#   C  a name that is not in the file yet is ADDED, replacing nothing
#   D  the document stays well formed — one [verification-timings … ] wrapper,
#      balanced brackets, every row one [timing name= seconds= load= at=]
#   E  sample_load_1m prints a bare number
#
# Everything is planted under mktemp: this selftest never writes the real
# timings path (issue 1582 is the same discipline one step out).
set -u

LIB="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/verification_timings_lib.sh"
[ -f "$LIB" ] || { echo "SELFTEST FAILED: no library at $LIB" >&2; exit 1; }
# shellcheck source=/dev/null
. "$LIB"

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "verification-timings writer selftest (issue 1583):"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
F=$T/nested/verification_timings.cxd

rows() { grep -oE '\[timing [^]]*\]' "$1" 2>/dev/null; }
row_of() { grep -oE "\[timing name=$2 [^]]*\]" "$1" 2>/dev/null; }

# ── A — an absent file (and an absent directory) ─────────────────────────────
write_timing_row "$F" union 5400 1.2 2026-09-19T04:01:51Z
want='[timing name=union seconds=5400 load=1.2 at=2026-09-19T04:01:51Z]'
got=$(rows "$F")
if [ "$got" = "$want" ]; then
	ok A "an absent file → the document is created with exactly that row"
else
	bad A "wanted one row '$want', got: $got"
fi

# ── B — a PLANTED log with two other rows: the named row JOINS its own name ──
# (cx-private#1903: five rows per name, the median check-verification-budget judges)
cat > "$F" <<'PLANTED'
[verification-timings
  [timing name=fixture-grader seconds=1384 load=0.9 at=2026-09-17T22:10:00Z]
  [timing name=union seconds=10440 load=7.1 at=2026-09-19T04:01:51Z]
  [timing name=selected-run seconds=900 load=0.4 at=2026-09-19T02:00:00Z]]
PLANTED
before_fg=$(row_of "$F" fixture-grader)
before_sr=$(row_of "$F" selected-run)
write_timing_row "$F" union 3210 1.1 2026-09-19T06:00:00Z
after_u=$(row_of "$F" union | tr '\n' ' ')
if [ "$after_u" = '[timing name=union seconds=10440 load=7.1 at=2026-09-19T04:01:51Z] [timing name=union seconds=3210 load=1.1 at=2026-09-19T06:00:00Z] ' ] \
   && [ "$(row_of "$F" fixture-grader)" = "$before_fg" ] \
   && [ "$(row_of "$F" selected-run)" = "$before_sr" ] \
   && [ "$(rows "$F" | wc -l | tr -d ' ')" = 4 ]; then
	ok B "a second write joined the union row, oldest first; the other two are untouched"
else
	bad B "the write disturbed the file: $(rows "$F" | tr '\n' ' ')"
fi

# ── C — a name not in the file yet is ADDED ──────────────────────────────────
write_timing_row "$F" grader-probe 61 0.2 2026-09-19T06:05:00Z
if [ "$(rows "$F" | wc -l | tr -d ' ')" = 5 ] \
   && [ "$(row_of "$F" grader-probe)" = '[timing name=grader-probe seconds=61 load=0.2 at=2026-09-19T06:05:00Z]' ]; then
	ok C "a new name is added, replacing nothing"
else
	bad C "a new name did not simply join the file: $(rows "$F" | tr '\n' ' ')"
fi

# ── D — the document is still well formed ────────────────────────────────────
opens=$(tr -cd '[' < "$F" | wc -c | tr -d ' ')
closes=$(tr -cd ']' < "$F" | wc -c | tr -d ' ')
head1=$(head -1 "$F")
malformed=$(grep -cE '^\s*\[timing ' "$F" | tr -d ' ')
if [ "$opens" = "$closes" ] && [ "$head1" = '[verification-timings' ] && [ "$malformed" = 5 ]; then
	ok D "balanced brackets, one wrapper, five well-formed rows"
else
	bad D "opens=$opens closes=$closes head='$head1' rows=$malformed"
fi

# ── F — the last FIVE of a name are kept, oldest dropped (cx-private#1903) ──
for i in 1 2 3 4 5 6; do write_timing_row "$F" union $((1000 + i)) 2.0 2026-09-20T0$i:00:00Z; done
kept=$(row_of "$F" union | sed -E 's/.*seconds=([0-9]+).*/\1/' | tr '\n' ' ')
if [ "$kept" = '1002 1003 1004 1005 1006 ' ] && [ "$(row_of "$F" grader-probe | wc -l | tr -d ' ')" = 1 ]; then
	ok F "seven union writes keep the last five, in order; other names untouched"
else
	bad F "kept union rows: '$kept'"
fi

# ── E — the load sample ──────────────────────────────────────────────────────
load=$(sample_load_1m)
case "$load" in
	''|*[!0-9.]*) bad E "sample_load_1m printed '$load', not a bare number" ;;
	*)            ok E "sample_load_1m printed $load" ;;
esac

if [ "$fails" -ne 0 ]; then
	echo "verification-timings writer selftest: $fails case(s) FAILED" >&2
	exit 1
fi
echo "verification-timings writer selftest: 6/6 (created; joins its own name; adds a new name; well formed; the load sample is a number; the last five per name)"
