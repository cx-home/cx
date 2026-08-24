#!/usr/bin/env bash
#
# CX v0.8.0 — Gate 28.5: XPath 3.1 parity check vs. Saxon-HE
#
# ##############################################################
# ## THIS GATE IS BROKEN, NOT MERELY DORMANT. RETIREMENT OR A  ##
# ## REBUILD IS PROPOSED AND AWAITS AN OWNER RULING (#945).    ##
# ## Do not "fix the path and wire it" — read the findings.    ##
# ##############################################################
#
# The gate below is preserved unrun so the 23 fixtures' intent is not
# destroyed by a drive-by decision. Everything from `set -euo pipefail`
# down is the ORIGINAL body and has never executed a single case;
# _gate_evidence/VALIDATION_REPORT.md:101 records it as never run.
#
# WHAT IT WAS FOR. For each fixture in the parity corpus: evaluate the
# CXPath expression against the input with cx, evaluate the same
# expression with Saxon-HE, compare. `xpath31-parity` cases must agree
# byte-for-byte; `xpath31-divergence` cases must differ in the documented
# way, so an accidental convergence is a regression. It is the only
# implementation-vs-external compliance check in the tree, which is why
# its absence is a gap in the compliance story rather than a benign skip.
#
# SIX FINDINGS, all measured 2026-08-24 against the branch tip. The first
# is the filed one (#945); the rest were found while attempting the repair
# and each independently prevents a pass:
#
#  1. FIXTURE PATH DEAD. FIXTURES pointed at conformance/xpath_31_parity.txt;
#     the file on disk is conformance/xpath_31_parity.cxd (converted
#     2026-08-17). The script exits 2 at the existence check, before any
#     work — which is what has masked findings 2-6 for months.
#
#  2. FIXTURE FORMAT CHANGED. The awk parser below expects the old flat
#     `=== test:` / `--- section` envelope. The .cxd is a
#     [test-suite]/[case] document with [input-xml]/[path]/[out-text]/[tag]/
#     [expect-diff] bodies. A path fix alone yields zero parsed fixtures.
#
#  3. THE cx INVOCATION DOES NOT EXIST. L95 calls `cx eval --xpath PATH FILE`.
#     `cx eval` is the retired alias (AGENTS.md rule 4, standing rule), and
#     there is no --xpath flag: the CXPath surface is the `cx select`
#     subcommand — `cx select 'PATH' FILE`.
#
#  4. select TAKES A CX DOCUMENT, NOT XML. Measured: `cx select '//user'`
#     over an .xml file returns
#       cx select: cx-err:CXER0100: parse input: input document contains no element
#     The fixtures' inputs are XML, so a working runner needs a
#     `cx --from=xml --to=cx` conversion stage the original never had.
#
#  5. THE EXPECTED OUTPUTS ARE IN THE WRONG FRAME — the finding that makes
#     this a rebuild rather than a repair. [out-text] records XML
#     (`<user id="1"/>`), while cx emits canonical CX. Measured on
#     xpath31-001 through the full working pipeline:
#         cx select //user  ->  [user id=1]
#         fixture out-text  ->  <user id="1"/>
#     So even with findings 1-4 all fixed and Saxon present, EVERY parity
#     case would fail on the comparison frame. No environment could have
#     produced a green here. Repair means re-deriving 23 expected outputs
#     against a single oracle and deciding the comparison frame — fixture
#     authoring, not a path fix.
#
#  6. THE NORMATIVE REFERENCE DOES NOT EXIST. The fixture and the header
#     above both cite spec/cxpath_alignment.md as normative for the
#     divergences. `grep -rl cxpath_alignment spec/ docs/ conformance/`
#     matches ONLY conformance/xpath_31_parity.cxd itself. Without that
#     text the 5 divergence cases have no definition of "differ in the
#     DOCUMENTED way", so they cannot be re-derived at all — normative text
#     has to be written first.
#
# WHY IT IS NOT WIRED HERE. Two reasons, both recorded rather than assumed.
# (a) It cannot pass (findings 5 and 6), so wiring it would put a
# permanently-red row in TEST_TARGETS. (b) Even repaired, the Saxon half
# needs Docker + network + the third-party saxonica/saxonhe:12 image, which
# would make `make test` fail or hang on any host without them. If the
# rebuild happens, the CX-side assertions (23 cases, no Docker) and the
# Saxon cross-check should be SEPARATE rows — the CX side is genuinely
# uncovered today: xpath_31_parity.cxd has no entry in conformance/gates.cxd
# and no V lane reads it, so those 23 cases run nowhere.
#
# Exit codes (original contract, unreached):
#   0 — all parity fixtures match Saxon; all divergence fixtures differ
#   1 — at least one fixture fails the contract
#   2 — invocation error

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/conformance/xpath_31_parity.cxd"
CX_BIN="${CX_BIN:-$ROOT/vcx/target/cx}"
SAXON_IMAGE="${SAXON_IMAGE:-saxonica/saxonhe:12}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Pre-flight: report EVERY blocker in one run, then stop. The original died
# at the first check, which is precisely how findings 2-6 stayed hidden — a
# gate that reports one blocker at a time teaches its reader that the one
# blocker is the whole problem.
blockers=0
note() { echo "  - $1" >&2; blockers=$((blockers + 1)); }
echo "gate 28.5 (XPath 3.1 parity vs Saxon-HE): BLOCKED — pre-flight findings:" >&2
[[ -x "$CX_BIN" ]] || note "cx binary not found at $CX_BIN (build: devbox run -- make build-vcx)"
[[ -f "$FIXTURES" ]] || note "fixture not found at $FIXTURES"
command -v docker >/dev/null 2>&1 || note "docker not available; required to run Saxon-HE ($SAXON_IMAGE)"
grep -q '^=== test:' "$FIXTURES" 2>/dev/null || \
  note "FINDING 2: $FIXTURES is a [test-suite]/[case] .cxd document; the parser below expects the retired '=== test:' flat envelope, so it would parse ZERO fixtures"
note "FINDING 3: the runner calls 'cx eval --xpath' — no such alias and no such flag; the CXPath surface is 'cx select PATH FILE'"
note "FINDING 4: 'cx select' reads a CX document, not XML; a 'cx --from=xml --to=cx' stage is missing"
note "FINDING 5: [out-text] records XML (<user id=\"1\"/>) while cx emits canonical CX ([user id=1]) — every parity case fails on frame, in every environment"
note "FINDING 6: spec/cxpath_alignment.md, cited as normative for the 5 divergence cases, does not exist in the tree"
echo "" >&2
echo "$blockers blocker(s). Findings 5 and 6 make this a REBUILD, not a repair:" >&2
echo "expected outputs must be re-derived against a single oracle, and the" >&2
echo "divergence contract needs normative text written first. Retirement or" >&2
echo "rebuild is an owner ruling — see #945 and the header above." >&2
exit 2

# ── Everything below is the original body, preserved unrun. ────────────────

# ─── Parse fixtures ─────────────────────────────────────────────────
# Fixture format (same envelope as conformance/code.txt):
#   === test: <id>
#   --- tag: xpath31-parity | xpath31-divergence
#   --- input_xml
#   <xml document the path is evaluated against>
#   --- path
#   <CXPath / XPath 3.1 expression>
#   --- out_text   (parity case — both engines produce this)
#   <expected canonical result>
#   --- expect_diff (divergence case — both must differ from each other)
#   <documented divergence note>

awk '
BEGIN { id=""; section=""; }
/^=== test:/ { if (id != "") { print "ENDFIXTURE" }
              id=$3; section=""; print "BEGINFIXTURE:" id; next }
/^--- / { section=substr($0, 5); print "SECTION:" section; next }
section != "" { print "DATA:" section ":" $0 }
END { if (id != "") print "ENDFIXTURE" }
' "$FIXTURES" > "$WORK/parsed.txt"

# ─── Run each fixture ───────────────────────────────────────────────
total=0
passed=0
failed_ids=()

current_id=""
declare -A buf

flush() {
    local id="$1"
    local tag="${buf[tag]:-}"
    local xml="${buf[input_xml]:-}"
    local path="${buf[path]:-}"
    local expect="${buf[out_text]:-}"

    [[ -z "$id" ]] && return
    total=$((total+1))

    local xml_file="$WORK/$id.xml"
    printf '%s' "$xml" > "$xml_file"

    # Run cx evaluator. FINDING 3/4: this line is UNREACHABLE (the pre-flight
    # above exits 2) and is wrong twice over — `cx eval --xpath` is neither a
    # live alias nor a live flag, and the real surface, `cx select PATH FILE`,
    # reads a CX document rather than the XML written to $xml_file. Left in
    # place rather than half-corrected: a rebuild has to decide the whole
    # pipeline (xml -> cx conversion, then select, then a comparison frame),
    # and a plausible-looking one-line edit here would hide that.
    local cx_out
    cx_out="$("$CX_BIN" eval --xpath "$path" "$xml_file" 2>/dev/null || true)"

    # Run Saxon-HE via Docker (mount tmpdir)
    local saxon_out
    saxon_out="$(docker run --rm -v "$WORK:/work" "$SAXON_IMAGE" \
        -xsl:/dev/null -s:"/work/$id.xml" -xp:"$path" 2>/dev/null || true)"

    case "$tag" in
        "xpath31-parity")
            if [[ "$cx_out" == "$saxon_out" && "$cx_out" == "$expect" ]]; then
                passed=$((passed+1))
                printf 'PASS  %-50s [parity]\n' "$id"
            else
                failed_ids+=("$id")
                printf 'FAIL  %-50s [parity]\n' "$id"
                printf '      cx:     %s\n' "$cx_out" | head -1
                printf '      saxon:  %s\n' "$saxon_out" | head -1
                printf '      want:   %s\n' "$expect" | head -1
            fi
            ;;
        "xpath31-divergence")
            if [[ "$cx_out" != "$saxon_out" ]]; then
                passed=$((passed+1))
                printf 'PASS  %-50s [divergence]\n' "$id"
            else
                failed_ids+=("$id")
                printf 'FAIL  %-50s [divergence — engines converged!]\n' "$id"
            fi
            ;;
        *)
            failed_ids+=("$id")
            printf 'FAIL  %-50s [unknown tag: %s]\n' "$id" "$tag"
            ;;
    esac
}

while IFS= read -r line; do
    case "$line" in
        BEGINFIXTURE:*)
            current_id="${line#BEGINFIXTURE:}"
            buf=()
            ;;
        ENDFIXTURE)
            flush "$current_id"
            current_id=""
            buf=()
            ;;
        SECTION:*)
            current_section="${line#SECTION:}"
            ;;
        DATA:*)
            data_section="${line#DATA:}"
            data_section="${data_section%%:*}"
            data_content="${line#DATA:*:}"
            buf[$data_section]="${buf[$data_section]:-}${data_content}"$'\n'
            ;;
    esac
done < "$WORK/parsed.txt"

echo
printf 'XPath 3.1 parity gate (28.5): %d / %d passed\n' "$passed" "$total"

if [[ ${#failed_ids[@]} -gt 0 ]]; then
    echo
    echo "Failed fixtures:"
    for id in "${failed_ids[@]}"; do
        echo "  - $id"
    done
    exit 1
fi

echo "Gate 28.5: ✅"
exit 0
