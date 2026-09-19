#!/bin/sh
# scenario_wait_ready_selftest.sh — #1477's readiness wait, on planted servers.
#
# The defect was a readiness loop with NO FAILURE ARM: on the post-merge run of
# bc9bfd24c (15-minute load average 69) the deployment had not bound inside the
# loop's 20 s, the loop simply ended, and the scenario curled a socket nobody
# was listening on — `status=000` nineteen times and a "broken example" verdict
# for a wait that gave up in silence. These are the three arms that loop
# needed, and none of them needs a real server:
#
#   A  the url ANSWERS            → exit 0, promptly
#   B  the server is ALIVE but nothing answers within the bound → exit 1, and
#      the message names the url, the bound and the load
#   C  the server DIED at boot    → exit 1 at once (not after the bound), and
#      the server's own log is printed
#
# A `file://` url is what makes A free: curl answers it with no listener, so the
# success arm is exercised without binding a port inside a test.
set -u

W="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/scenario_wait_ready.sh"
[ -f "$W" ] || { echo "SELFTEST FAILED: no waiter at $W" >&2; exit 1; }

fails=0
ok()  { printf '  %-3s ok   %s\n' "$1" "$2"; }
bad() { printf '  %-3s SELFTEST FAILED: %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "scenario readiness-wait selftest (#1477):"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
printf 'hello\n' > "$T/served"
printf 'the server said this\n' > "$T/server.log"

# a live process that answers nothing
sleep 60 &
ALIVE=$!
# a process that is already gone
sleep 0 &
DEAD=$!
wait "$DEAD" 2>/dev/null

# the brace group's redirect scopes the shell's own "Terminated" job notice,
# which is written when the killed sleep is reaped (#1542's accepted spelling).
cleanup() { { kill "$ALIVE" 2>/dev/null; wait "$ALIVE"; } 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

# A — the url answers
t0=$(date -u '+%s')
out=$(sh "$W" "file://$T/served" "$ALIVE" 5 "$T/server.log" 2>&1); rc=$?
el=$(( $(date -u '+%s') - t0 ))
if [ "$rc" -eq 0 ] && [ "$el" -lt 5 ]; then
  ok A "a url that answers returns 0 in ${el}s"
else
  bad A "wanted a prompt 0 — exit $rc after ${el}s: $out"
fi

# B — alive, but nothing answers inside the bound
t0=$(date -u '+%s')
out=$(sh "$W" "file://$T/does-not-exist" "$ALIVE" 1 "$T/server.log" 2>&1); rc=$?
el=$(( $(date -u '+%s') - t0 ))
if [ "$rc" -eq 1 ] \
   && case "$out" in *"did not answer within 1s"*) true ;; *) false ;; esac \
   && case "$out" in *"load"*) true ;; *) false ;; esac \
   && case "$out" in *"the server said this"*) true ;; *) false ;; esac; then
  ok B "the bound passing FAILS (${el}s), names the bound and the load, and prints the server log"
else
  bad B "wanted exit 1 naming the bound, the load and the log — exit $rc after ${el}s: $out"
fi

# C — the server died at boot: answered at once, not after the bound
t0=$(date -u '+%s')
out=$(sh "$W" "file://$T/does-not-exist" "$DEAD" 60 "$T/server.log" 2>&1); rc=$?
el=$(( $(date -u '+%s') - t0 ))
if [ "$rc" -eq 1 ] && [ "$el" -lt 10 ] \
   && case "$out" in *"DIED at boot"*) true ;; *) false ;; esac; then
  ok C "a dead server is reported in ${el}s, not after the 60s bound"
else
  bad C "wanted a prompt exit 1 naming the dead server — exit $rc after ${el}s: $out"
fi

# D — the scenario that was bitten actually calls the waiter now
S=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/examples/platform/sso/deployment/run.sh
if [ -f "$S" ] && grep -q 'scenario_wait_ready.sh' "$S"; then
  ok D "examples/platform/sso/deployment/run.sh waits through the shared waiter"
else
  bad D "the sso deployment scenario still carries its own silent readiness loop"
fi

# ── E-H — the RETRY CLASSIFIER in tools/verify-examples.sh ───────────────────
# The second half of #1477: a scenario whose server never answered is re-run
# once, serially, with the load recorded. What must never happen is the
# classifier widening — a scenario that answered ANY request is a real failure
# and must not be retried into a pass.
VE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/verify-examples.sh"
if [ -f "$VE" ]; then
  eval "$(sed -n '/^load_1m()/,/^}/p; /^scenario_never_connected()/,/^}/p' "$VE")"

  if scenario_never_connected 'status=000
status=000'; then ok E "every request 000 → the retry class"; else bad E "an all-000 transcript was not classified"; fi

  if scenario_never_connected 'status=201
status=000'; then bad F "a MIXED transcript was classified — a real failure would be retried into a pass"; else ok F "a transcript with any non-000 status is NOT the class"; fi

  if scenario_never_connected 'scenario-wait-ready: http://x did not answer within 120s'; then ok G "the waiter's own failure is the class"; else bad G "the waiter's failure was not classified"; fi

  if scenario_never_connected 'status=201
status=200'; then bad H "a healthy transcript was classified"; else ok H "a healthy transcript is not the class"; fi
else
  bad E "no tools/verify-examples.sh to read the classifier from"
fi

if [ "$fails" -ne 0 ]; then
  echo "scenario readiness-wait selftest: $fails case(s) FAILED" >&2
  exit 1
fi
echo "scenario readiness-wait selftest: 8/8 (the wait answers promptly / fails loudly with the load and the log / is immediate on a dead server / is what the scenario calls; the retry classifier takes all-000 and the waiter's failure and refuses a mixed or healthy transcript)"
