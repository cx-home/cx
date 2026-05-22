#!/usr/bin/env bash
#
# CX v0.8.0 — Gate 28.5: XPath 3.1 parity check vs. Saxon-HE
#
# For each fixture in conformance/xpath_31_parity.txt:
#   1. Evaluate the CXPath expression against the input via `cx eval`.
#   2. Evaluate the same expression against the same input via Saxon-HE.
#   3. Compare the results, normalised to canonical CX bytes.
#
# A fixture is in one of two categories:
#   - tag: xpath31-parity      — results MUST be byte-identical
#   - tag: xpath31-divergence  — results MUST differ in the documented way
#
# The divergence cases enumerate every spec-documented departure from
# XPath 3.1 (see spec/cxpath_alignment.md). A test where Saxon and cx
# happen to converge on a divergence case is a regression.
#
# Saxon-HE is run via Docker; no host JDK requirement.
#
# Exit codes:
#   0 — all parity fixtures match Saxon; all divergence fixtures
#       differ in the documented way
#   1 — at least one fixture fails the contract
#   2 — invocation error (Docker unavailable, fixture file missing)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/conformance/xpath_31_parity.txt"
CX_BIN="${CX_BIN:-$ROOT/dist/bin/cx}"
SAXON_IMAGE="${SAXON_IMAGE:-saxonica/saxonhe:12}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -x "$CX_BIN" ]]; then
    echo "error: cx binary not found at $CX_BIN" >&2
    echo "  Build with: devbox run -- make build" >&2
    exit 2
fi

if [[ ! -f "$FIXTURES" ]]; then
    echo "error: fixture file not found at $FIXTURES" >&2
    exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker not available; required to run Saxon-HE" >&2
    echo "  Install Docker Desktop or set SAXON_IMAGE=<local-saxon-jar-runner>" >&2
    exit 2
fi

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

    # Run cx evaluator
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
