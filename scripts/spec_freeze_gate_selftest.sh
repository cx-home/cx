#!/usr/bin/env bash
# spec_freeze_gate_selftest — proves the gate's detection power on a
# SYNTHETIC repo (mktemp; never the live tree — the R3.10 gate-idempotency
# rule). Five scenarios:
#   A  mixed spec+impl, no token                → MUST FAIL  (red proof)
#   B  mixed, token naming a RECORDED ruling    → must pass
#   C  mixed, token naming NO recorded ruling   → MUST FAIL  (match check)
#   D  spec-only, no token                      → must pass
#   E  impl-only, no token                      → must pass
set -euo pipefail

GATE="$(cd "$(dirname "$0")" && pwd)/spec_freeze_gate.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

(
  cd "$T"
  git init -q .
  git config user.email t@t && git config user.name t
  mkdir -p spec/03-approved spec/02-working vcx
  printf 'ledger\n\nRULED: TST-1 — recorded test ruling (a)\n' > spec/02-working/partition_test_ledger.md
  git add -A && git commit -qm "seed ledger"

  sha_of_mixed() { # $1 = message
    printf 'spec\n' >> spec/03-approved/thing.md
    printf 'impl\n' >> vcx/thing.v
    git add -A && git commit -qm "$1"
    git rev-parse HEAD
  }

  # A — mixed, no token → gate must REFUSE (detection power)
  a=$(sha_of_mixed "mixed change, no ruling token")
  if bash "$GATE" --check-commit "$a" 2>/dev/null; then
    echo "SELFTEST FAILED: scenario A (mixed, tokenless) passed the gate" >&2; exit 1
  fi

  # B — mixed, recorded token → must pass
  b=$(sha_of_mixed "mixed change under an express ruling — RULED: TST-1")
  bash "$GATE" --check-commit "$b" || {
    echo "SELFTEST FAILED: scenario B (recorded token) was refused" >&2; exit 1; }

  # C — mixed, unrecorded token → gate must REFUSE (recorded-match check)
  c=$(sha_of_mixed "mixed change with a bogus token — RULED: NOPE-99")
  if bash "$GATE" --check-commit "$c" 2>/dev/null; then
    echo "SELFTEST FAILED: scenario C (unrecorded token) passed the gate" >&2; exit 1
  fi

  # D — spec-only, no token → must pass
  printf 'spec only\n' >> spec/03-approved/thing.md
  git add -A && git commit -qm "spec-only change"
  bash "$GATE" --check-commit "$(git rev-parse HEAD)" || {
    echo "SELFTEST FAILED: scenario D (spec-only) was refused" >&2; exit 1; }

  # E — impl-only, no token → must pass
  printf 'impl only\n' >> vcx/thing.v
  git add -A && git commit -qm "impl-only change"
  bash "$GATE" --check-commit "$(git rev-parse HEAD)" || {
    echo "SELFTEST FAILED: scenario E (impl-only) was refused" >&2; exit 1; }
)

echo "spec-freeze-gate selftest: 5/5 (tokenless-mixed RED, unrecorded-token RED, recorded/spec-only/impl-only green)"
