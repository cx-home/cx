#!/bin/sh
# exit_status_probe_selftest.sh — #1570's gate, on PLANTED roots under mktemp.
#
# The gate is deny-on-match over a whole tree, and the failure mode of that
# shape is the vacuous gate: one scanned over 73 files and found nothing
# because its pattern could not match anything (#1542's note). So the red proof
# is part of the gate, not an afterthought.
#
#   A  the ad-hoc probe — `devbox run -- sh -c '<cmd>; echo $?'` — is REFUSED
#   B  a pipeline script's own `"$@" …; echo "EXIT=$?"` is ACCEPTED: devbox runs
#      that script as one unit and those statuses are real
#   C  `devbox run -- <cmd>; echo $?` (no inner sh -c) is ACCEPTED
#   D  the inline marker exempts a line, and the summary counts it
#   E  a root with nothing to scan REFUSES TO VOUCH rather than passing
set -u

GATE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/exit_status_probe_gate.sh"
[ -f "$GATE" ] || { echo "SELFTEST FAILED: no gate at $GATE" >&2; exit 1; }

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "exit-status-probe gate selftest (#1570):"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

plant() { # plant <case> <file-under-root> <content>
  mkdir -p "$T/$1/$(dirname "$2")"
  printf '%s\n' "$3" > "$T/$1/$2"
}

run_gate() { sh "$GATE" "$T/$1" 2>&1; }

# A — the probe that lies. Its three tokens are assembled rather than written
# out, so this file does not itself trip the gate it is testing.
Q='$'"?"
plant a scripts/probe.sh "devbox run -- sh -c \"vcx/target/cx p2.cx; echo $Q\""
out=$(run_gate a); rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"#1570"*) true ;; *) false ;; esac; then
  ok A "the devbox-wrapped \`sh -c\` probe is refused"
else
  bad A "the probe was not refused — exit $rc: $out"
fi

# B — a pipeline script's own capture, which is sound
plant b scripts/pipeline.sh 'run() { "$@" > log 2>&1; echo "EXIT=$?"; }'
out=$(run_gate b); rc=$?
if [ "$rc" -eq 0 ]; then
  ok B "a pipeline script's own \"\$@\"; echo EXIT=\$? is accepted"
else
  bad B "a sound in-script capture was refused — $out"
fi

# C — the direct read, which is the documented safe form
plant c scripts/direct.sh 'devbox run -- vcx/target/cx p2.cx; echo $?'
out=$(run_gate c); rc=$?
if [ "$rc" -eq 0 ]; then
  ok C "a direct read from devbox run's own command word, with no inner shell, is accepted"
else
  bad C "the direct read was refused — $out"
fi

# D — the escape hatch, counted in the summary so it can never be silent
plant d scripts/marked.sh 'devbox run -- sh -c "cmd; echo $?"   # exit-status-probe-ok'
out=$(run_gate d); rc=$?
if [ "$rc" -eq 0 ] && case "$out" in *"1 file(s) carry the marker"*) true ;; *) false ;; esac; then
  ok D "the inline marker exempts the line and the summary counts it"
else
  bad D "the marker did not exempt-and-report — exit $rc: $out"
fi

# E — nothing to scan is a refusal, never a pass
mkdir -p "$T/e"
out=$(run_gate e); rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"refusing to vouch"*) true ;; *) false ;; esac; then
  ok E "a root with no file refuses to vouch"
else
  bad E "an empty root passed — exit $rc: $out"
fi

if [ "$fails" -ne 0 ]; then
  echo "exit-status-probe gate selftest: $fails case(s) FAILED" >&2
  exit 1
fi
echo "exit-status-probe gate selftest: 5/5 (the probe refused; an in-script capture, a direct read and a marked line accepted; an empty root refuses to vouch)"
