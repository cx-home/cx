#!/usr/bin/env bash
# spec_freeze_gate_selftest — proves the gate's detection power on a
# SYNTHETIC repo (mktemp; never the live tree — the R3.10 gate-idempotency
# rule). Eight scenarios:
#   A  mixed spec+impl, no token                → MUST FAIL  (red proof)
#   B  mixed, token naming a RECORDED ruling    → must pass
#   C  mixed, token naming NO recorded ruling   → MUST FAIL  (match check)
#   D  spec-only, no token                      → must pass
#   E  impl-only, no token                      → must pass
#   F  mixed, PARENTHESIZED recorded token      → must pass  (the "(RULED: id)"
#      spelling; id carries a non-ASCII prime, the real 831-1a′ shape)
#   G  mixed, parenthesized token with an internal (…) qualifier → must pass
#   H  mixed, parenthesized BOGUS token         → MUST FAIL  (paren stripping
#      must not loosen the recorded-match check)
#   I  a file re-entering the LEGACY ledger namespace
#      (spec/02-working/partition_*) at HEAD    → MUST FAIL  (R6.1 tree check)
set -euo pipefail

GATE="$(cd "$(dirname "$0")" && pwd)/spec_freeze_gate.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

(
  cd "$T"
  git init -q .
  git config user.email t@t && git config user.name t
  mkdir -p spec/03-approved spec/02-working vcx ledger
  printf 'ledger\n\nRULED: TST-1 — recorded test ruling (a)\nRULED: TST-3′ — recorded, id ends in a prime\nRULED: TST-4 — recorded base id; commits may cite TST-4(a-revised)\n' > ledger/test_ledger.md
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

  # F — mixed, parenthesized recorded token with a prime → must pass
  f=$(sha_of_mixed "mixed change under an express ruling (RULED: TST-3′)")
  bash "$GATE" --check-commit "$f" || {
    echo "SELFTEST FAILED: scenario F (parenthesized recorded token) was refused" >&2; exit 1; }

  # G — mixed, parenthesized token carrying an internal qualifier → must pass
  g=$(sha_of_mixed "mixed change under an express ruling (RULED: TST-4(a-revised))")
  bash "$GATE" --check-commit "$g" || {
    echo "SELFTEST FAILED: scenario G (parenthesized qualified token) was refused" >&2; exit 1; }

  # H — mixed, parenthesized bogus token → gate must REFUSE
  h=$(sha_of_mixed "mixed change with a bogus token (RULED: NOPE-77)")
  if bash "$GATE" --check-commit "$h" 2>/dev/null; then
    echo "SELFTEST FAILED: scenario H (parenthesized unrecorded token) passed the gate" >&2; exit 1
  fi

  # I — a file re-entering the legacy ledger namespace at HEAD → default-mode
  # gate must REFUSE (R6.1 tree check; the per-commit classifier deliberately
  # treats the legacy spelling as ledger-class for history, so the tree check
  # is the only thing standing between the carve-out and a loophole)
  printf 'sneaky ledger\n' > spec/02-working/partition_sneaky.md
  git add -A && git commit -qm "re-enter the legacy namespace"
  if bash "$GATE" 2>/dev/null; then
    echo "SELFTEST FAILED: scenario I (legacy-namespace file at HEAD) passed the default-mode gate" >&2; exit 1
  fi
)

echo "spec-freeze-gate selftest: 9/9 (tokenless-mixed RED, unrecorded-token RED plain+parenthesized, recorded plain/parenthesized/qualified green, spec-only/impl-only green, legacy-namespace RED)"
