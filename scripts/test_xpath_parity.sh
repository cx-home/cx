#!/usr/bin/env bash
#
# Gate 28.5b — the Saxon-HE cross-check for the CXPath / XPath 3.1 alignment
# corpus. MANUAL, by ruling. RULED: VC-7 (#945).
#
# ###########################################################################
# ## THIS IS NOT A LANE AND MUST NOT BECOME ONE WITHOUT A RULING.           ##
# ## It prints the operator recipe and its preconditions, then exits 2.     ##
# ## The CX side of the same corpus IS a lane: `make test-xpath-parity-cx`  ##
# ## (gate 28.5a), in TEST_TARGETS, no Docker.                              ##
# ###########################################################################
#
# WHY MANUAL. VC-7 split the old single gate 28.5 in two because its two
# halves have incompatible costs:
#
#   28.5a  CX side — needs only this tree's `cx`. Automated, in TEST_TARGETS,
#          runs on every `make test`. scripts/check_xpath_parity_fixtures.cx.
#   28.5b  Saxon side (this file) — needs Docker, network, and the
#          third-party `saxonica/saxonhe:12` image. Wiring that into
#          TEST_TARGETS makes `make test` FAIL or HANG on any host without
#          them, and this host is one: Docker pulls hang here under
#          credsStore=desktop. It is also the only implementation-vs-external
#          compliance check in the tree, which is why VC-7 kept it instead of
#          retiring it.
#
# It exits 2 rather than "skipping cleanly" on purpose. A clean skip is
# precisely what let the old gate read as a green row for months while never
# having run once (`_gate_evidence/VALIDATION_REPORT.md:101`).
#
# WHAT THIS ROW COVERS — and what it does NOT.
#
#   COVERS: for each `xpath31-parity` case, whether Saxon-HE 12 selects the
#   SAME NODE SET that `cx select` selects. For each `xpath31-divergence`
#   case, whether Saxon ACCEPTS the expression that CX refuses — an
#   accidental convergence (Saxon also refusing) means the divergence note is
#   stale and the case has stopped testing anything.
#
#   DOES NOT COVER: byte equality. `cx` emits canonical CX (`[user id=1]`)
#   and Saxon emits XML (`<user id="1"/>`). The comparison is on the node set,
#   never the bytes. The old runner compared bytes across those two frames,
#   which is why no environment could ever have produced a green from it (the
#   decisive finding of #945, measured 2026-08-24 end-to-end on xpath31-001).
#
#   The `[expect-saxon]` bodies in the fixture are HAND-AUTHORED and have
#   NEVER been verified against a running Saxon. Verifying them — and
#   recording the verdict in conformance/GATE_REGISTER.md row 28.5b — is this
#   row's first job, not an assumption it may rest on.
#
# HISTORY WORTH KEEPING. The original runner carried six independently fatal
# defects, all measured 2026-08-24 at the branch tip. #945's filed defect was
# only the outermost; the rest were masked because the runner died at the
# first check instead of reporting all of them:
#   1. read conformance/xpath_31_parity.txt; the file has been .cxd since
#      2026-08-17, so it exited 2 before doing any work;
#   2. its awk parser expected the retired `=== test:` flat envelope, not the
#      [test-suite]/[case] document — a path fix alone parses ZERO cases;
#   3. it called `cx eval --xpath`: not a live alias (AGENTS.md rule 4) and
#      not a live flag — the surface is `cx select PATH FILE`;
#   4. `cx select` reads a CX document, not XML — an xml->cx stage was missing;
#   5. `[out-text]` recorded XML while cx emits canonical CX (the frame bug
#      above);
#   6. `spec/cxpath_alignment.md`, cited as normative for the divergence
#      cases, did not exist in the tree.
# Findings 1-5 are fixed by the 28.5a lane and the re-derived fixture.
# Finding 6 is fixed by spec/02-working/cxpath_alignment.md (authored under
# VC-7; PROPOSED for graduation to spec/03-approved/, NOT graduated — G3 is
# owner-only).
#
# Exit codes:
#   2 — always. This file is a recipe, not a runner (see the banner).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/conformance/xpath_31_parity.cxd"
CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"
SAXON_IMAGE="${SAXON_IMAGE:-saxonica/saxonhe:12}"

# ── preconditions, reported all at once ──────────────────────────────────
echo "gate 28.5b — Saxon-HE cross-check (MANUAL, RULED: VC-7 / #945)" >&2
echo "" >&2
echo "preconditions on this host:" >&2
if [ -x "$CX_BIN" ]; then
  echo "  [ok]      cx binary: $CX_BIN" >&2
else
  echo "  [MISSING] cx binary at $CX_BIN — build: devbox run -- make build-vcx" >&2
fi
if [ -f "$FIXTURES" ]; then
  echo "  [ok]      corpus: $FIXTURES" >&2
else
  echo "  [MISSING] corpus at $FIXTURES" >&2
fi
if command -v docker >/dev/null 2>&1; then
  echo "  [ok]      docker on PATH" >&2
else
  echo "  [MISSING] docker — required to run Saxon-HE ($SAXON_IMAGE)" >&2
fi
echo "  [note]    $SAXON_IMAGE must be pullable; Docker pulls HANG on the" >&2
echo "            dev host under credsStore=desktop (known environment trap)" >&2

# ── the recipe ───────────────────────────────────────────────────────────
cat >&2 <<'RECIPE'

how to run this row by hand
───────────────────────────
For each [case] in conformance/xpath_31_parity.cxd:

  1. write the [input-xml] body to a file, say /tmp/p/$ID.xml

  2. CX side — the same two stages gate 28.5a uses:
       cx --from=xml --to=cx  < /tmp/p/$ID.xml  > /tmp/p/$ID.cx
       cx select "$PATH" /tmp/p/$ID.cx
     (`cx select` reads a CX document, never XML. Exit 0 = at least one
      match, 1 = empty match set, 2 = error — misc/cli.md.)

  3. Saxon side:
       docker run --rm -v /tmp/p:/work saxonica/saxonhe:12 \
         -s:/work/$ID.xml -xp:"$PATH" -qs:.

  4. Compare by NODE SET, not by bytes — the two engines serialize
     differently by design (see the banner). Then:

       tag = xpath31-parity      the sets must be equal, and each side must
                                 equal its own recorded body: [out-text] for
                                 CX (byte-exact, machine-checked by 28.5a),
                                 [expect-saxon] for Saxon (hand-authored,
                                 UNVERIFIED — verify it here).

       tag = xpath31-divergence  Saxon must ACCEPT and CX must REFUSE with
                                 the [out-err] code. Both refusing is a
                                 FAILURE of this row: the engines converged
                                 and [expect-diff] is stale.

  5. Record the verdict in conformance/GATE_REGISTER.md row 28.5b, with the
     date and the Saxon version actually used. A manual row whose verdict
     predates the current release is itself a red (the register's own
     freshness rule).

normative reference
───────────────────
spec/02-working/cxpath_alignment.md — what CXPath aligns with in XPath 3.1,
what it deliberately does not carry, and what each case pins. Read it before
adjudicating any disagreement: several disagreements with Saxon are the
SPECIFIED answer, not a defect.

RECIPE

echo "exit 2 — this row is operator-run. The CX side runs automatically:" >&2
echo "  devbox run -- make test-xpath-parity-cx    (gate 28.5a)" >&2
exit 2
