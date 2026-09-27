#!/bin/sh
# scripts/deps_bootstrap_selftest.sh — fixture for CX_DEPS_TOKEN (SITE-1,
# ledger/rulings_2026_09_26_owner_decisions_l35_l39.md, RULED: SITE-1, D83a,
# RS-33). Invoked as `sh scripts/deps_bootstrap.sh --selftest` (its own
# `--selftest` case, precedent: check-public-history-replace/#1675) and by
# `make check-deps-bootstrap-token`.
#
# Fully offline and deterministic — no dependence on this box's own git
# config (dev2 rewrites https://github.com/ to SSH in ~/.gitconfig.local, so
# a LIVE fetch here would never reproduce the reported bug the way GitHub's
# runner does) and no dependence on network reachability either way. A spy
# `git` on PATH intercepts only the ONE fetch this fixture's row drives and
# answers deterministically, exactly the way the real transport does:
#
#   RED   — auth_cfg absent (CX_DEPS_TOKEN unset): the spy answers with the
#           EXACT text of the reported bug —
#           "fatal: could not read Username for 'https://github.com': terminal
#           prompts disabled" — and deps_bootstrap.sh (unset branch, no
#           stderr capture — byte-identical to before this change) relays it
#           straight through.
#
#   GREEN — auth_cfg present (CX_DEPS_TOKEN=dummy): the spy sees the `-c
#           url.https://x-access-token:dummy@github.com/.insteadOf=…` argument
#           on the SAME git invocation (proving the mechanism engaged) and
#           answers with GitHub's real shape for a bad credential
#           ("Invalid username or password" / "Authentication failed") —
#           a DIFFERENT failure from RED's prompt refusal — and
#           deps_bootstrap.sh's own (set) branch captures that text and never
#           relays it, printing only its own sanitized refusal line instead.
#
#   A second, real (non-github, non-spied) row — a local bare repo — proves
#   the ordinary fetch-and-checkout path is unaffected either way: same
#   sha checked out in deps/<repo> regardless of CX_DEPS_TOKEN.
#
#   NEVER — across every line either run PRINTS (deps_bootstrap.sh's own
#   captured stdout+stderr, `set -x` off throughout), the token string
#   appears nowhere — run with CX_DEPS_TOKEN=dummy per the brief's own test.
set -eu

SELF_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/deps_bootstrap_selftest.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

REAL_GIT="$(command -v git)"
export REAL_GIT

TOKEN="dummy"
GH_URL="https://github.com/cx-home/cx-private-selftest-does-not-exist.git"
NEEDLE_UNPROMPTED='could not read Username'
NEEDLE_AUTH_REJECTED='Authentication failed'

# -- the spy: intercepts ONLY the github-shaped row's fetch; every other git
# invocation (init, checkout, the local-repo row, deps_bootstrap.sh's own
# `git remote get-url origin`) passes straight through to the real binary.
SPYDIR="$WORK/spybin"
mkdir -p "$SPYDIR"
cat > "$SPYDIR/git" <<'SPY'
#!/bin/sh
args="$*"
case "$args" in
  *"fetch"*"cx-private-selftest-does-not-exist.git"*)
    case "$args" in
      *x-access-token*)
        echo "remote: Invalid username or password." >&2
        echo "fatal: Authentication failed for 'https://github.com/cx-home/cx-private-selftest-does-not-exist.git/'" >&2
        exit 1
        ;;
      *)
        echo "fatal: could not read Username for 'https://github.com': terminal prompts disabled" >&2
        exit 1
        ;;
    esac
    ;;
esac
exec "$REAL_GIT" "$@"
SPY
chmod +x "$SPYDIR/git"

# -- a real, local pin: proves the ordinary path still works end-to-end,
# untouched by CX_DEPS_TOKEN (its URL never matches the github.com prefix).
LOCAL_SRC="$WORK/local-src"
mkdir -p "$LOCAL_SRC"
git init -q "$LOCAL_SRC"
git -C "$LOCAL_SRC" -c user.email=selftest@example.invalid -c user.name=selftest \
  commit -q --allow-empty -m selftest
LOCAL_SHA="$(git -C "$LOCAL_SRC" rev-parse HEAD)"

CONSUMER="$WORK/consumer"
mkdir -p "$CONSUMER"
cat > "$CONSUMER/deps.cxd" <<EOF
[deps
  [dep repo=cx-selftest-local sha=$LOCAL_SHA module=cx-selftest-local url='file://$LOCAL_SRC']
  [dep repo=cx-selftest-pin sha=0000000000000000000000000000000000000000 module=cx-selftest-pin url='$GH_URL']
]
EOF
# Row order matters: the github row is EXPECTED to fail and deps_bootstrap.sh
# exits on the first row that fails, so the local (real, always-succeeds) row
# is listed first — it must be checked out before the github row aborts the
# script, in BOTH runs.

run_bootstrap() {
  # $1 = CX_DEPS_TOKEN value ("" for unset), $2 = output capture file.
  # deps_bootstrap.sh always `cd`s to its OWN repo root (dirname "$0"/..) —
  # DEPS_CXD/DEPS_DIR are resolved from there, not from the caller's cwd, so
  # both are passed as absolute paths into the scratch consumer directory.
  rm -rf "$CONSUMER/deps"
  if [ -n "$1" ]; then
    ( PATH="$SPYDIR:$PATH" CX_DEPS_TOKEN="$1" GIT_TERMINAL_PROMPT=0 \
        sh "$SELF_ROOT/scripts/deps_bootstrap.sh" "$CONSUMER/deps.cxd" "$CONSUMER/deps" ) >"$2" 2>&1
  else
    ( PATH="$SPYDIR:$PATH"; unset CX_DEPS_TOKEN 2>/dev/null; GIT_TERMINAL_PROMPT=0 \
        sh "$SELF_ROOT/scripts/deps_bootstrap.sh" "$CONSUMER/deps.cxd" "$CONSUMER/deps" ) >"$2" 2>&1
  fi
}

RED_LOG="$WORK/red.log"
GREEN_LOG="$WORK/green.log"

set +e
run_bootstrap "" "$RED_LOG";         red_status=$?
run_bootstrap "$TOKEN" "$GREEN_LOG"; green_status=$?
set -e

fail=0

# RED: unset token reproduces the reported bug's exact refusal, relayed
# straight through (byte-identical to before this change).
if [ "$red_status" -eq 0 ]; then
  echo "deps_bootstrap_selftest: RED case unexpectedly succeeded — $RED_LOG" >&2
  fail=1
fi
if ! grep -qi "$NEEDLE_UNPROMPTED" "$RED_LOG"; then
  echo "deps_bootstrap_selftest: RED case did not reproduce '$NEEDLE_UNPROMPTED' — got:" >&2
  cat "$RED_LOG" >&2
  fail=1
fi

# GREEN: token set changes the failure mode (auth was attempted) and the
# script's OWN captured output never carries git's raw message.
if [ "$green_status" -eq 0 ]; then
  echo "deps_bootstrap_selftest: GREEN case unexpectedly succeeded — $GREEN_LOG" >&2
  fail=1
fi
if grep -qi "$NEEDLE_UNPROMPTED" "$GREEN_LOG"; then
  echo "deps_bootstrap_selftest: GREEN case still hit the unauthenticated prompt refusal — CX_DEPS_TOKEN was not honoured:" >&2
  cat "$GREEN_LOG" >&2
  fail=1
fi
if grep -qi "$NEEDLE_AUTH_REJECTED" "$GREEN_LOG"; then
  echo "deps_bootstrap_selftest: GREEN case relayed git's raw authentication-failure text instead of its own sanitized refusal:" >&2
  cat "$GREEN_LOG" >&2
  fail=1
fi
if ! grep -q "deps_bootstrap: fetch refused for cx-selftest-pin" "$GREEN_LOG"; then
  echo "deps_bootstrap_selftest: GREEN case did not print its own sanitized refusal line — got:" >&2
  cat "$GREEN_LOG" >&2
  fail=1
fi

# NEVER: the token string in no line either run printed.
if grep -q "$TOKEN" "$RED_LOG" "$GREEN_LOG"; then
  echo "deps_bootstrap_selftest: the token string leaked into captured output — never allowed:" >&2
  grep -n "$TOKEN" "$RED_LOG" "$GREEN_LOG" >&2
  fail=1
fi

# The local (non-github) row is unaffected: same sha, checked out by the
# GREEN run (the last one to populate $CONSUMER/deps) — proves the ordinary
# fetch-and-checkout path still works end-to-end with CX_DEPS_TOKEN set.
have="$(git -C "$CONSUMER/deps/cx-selftest-local" rev-parse HEAD 2>/dev/null || echo MISSING)"
if [ "$have" != "$LOCAL_SHA" ]; then
  echo "deps_bootstrap_selftest: the local (non-github) pin did not end up at its pinned sha ($have != $LOCAL_SHA) — the ordinary path regressed" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "deps_bootstrap_selftest: ok — unset reproduces the reported bug, set changes the failure mode and never leaks the token, the ordinary (non-github) fetch path is unchanged"
