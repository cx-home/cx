#!/usr/bin/env bash
# tools/verify-examples.sh — every publishable .cx file in examples/ must
# round-trip through the cx toolchain.
#
# CX resources have two readings (spec/core/code.md §1.3):
#   • DATA documents (config, prose markup, tables) — validated via the
#     DATA path: `cx fmt` (parse + canonical re-emit) then
#     `cx --from=cx --to=json` (the lossless data conversion the library
#     bindings use). NOTE: `cx --json FILE` is the *eval* reading and is the
#     wrong tool for prose markup — its body parses as program expressions.
#   • PROGRAM tours (code-tour, cxpath-tour, …) — validated via the EVAL
#     reading: `cx eval FILE [--data=FILE.input.cx]`.
#
# A file passes if the reading that matches it succeeds. The category is
# auto-detected: if `cx fmt` parses it, it is data; otherwise it is treated
# as a program and evaluated (with its sibling `<name>.input.cx` as input
# when one exists).
#
# examples/htmx/ is excluded — those demos are parked (DO-NOT-PUBLISH.md)
# and intentionally retain pre-v0.8.0 syntax.
#
# Usage:
#   tools/verify-examples.sh
#   tools/verify-examples.sh examples/comparisons/

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/vcx/target/cx"

if [ ! -x "$CX" ]; then
	(cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

TARGET="${1:-$ROOT/examples}"
PASS=0
FAIL=0
FAIL_DETAILS=()

check_file() {
	local f="$1"
	local rel="${f#$ROOT/}"

	# examples/htmx/ is parked (DO-NOT-PUBLISH); skip entirely.
	# examples/cxstore/ is a Makefile-orchestrated client+server demo (server.cx
	# runs an accept loop that blocks; client.cx needs a live server) — exercised
	# via its own `make run`, not standalone eval, so this single-file checker
	# would hang on the server and fail the client.
	case "$rel" in
		examples/htmx/*) return ;;
		examples/cxstore/*) return ;;
	esac

	if "$CX" fmt "$f" > /dev/null 2>&1; then
		# DATA reading: parsed cleanly. Must also convert to JSON via the
		# lossless data path (the conversion the bindings expose).
		if ! "$CX" --from=cx --to=json "$f" > /dev/null 2>&1; then
			FAIL=$((FAIL + 1))
			FAIL_DETAILS+=("$rel [data JSON conversion failed]")
			return
		fi
	else
		# PROGRAM reading: not data — evaluate it. Pair with a sibling
		# <name>.input.cx as the eval input document when present.
		local input="${f%.cx}.input.cx"
		if [ -f "$input" ]; then
			if ! "$CX" eval "$f" --data="$input" > /dev/null 2>&1; then
				FAIL=$((FAIL + 1))
				FAIL_DETAILS+=("$rel [eval failed (with $(basename "$input"))]")
				return
			fi
		else
			if ! "$CX" eval "$f" > /dev/null 2>&1; then
				FAIL=$((FAIL + 1))
				FAIL_DETAILS+=("$rel [eval failed]")
				return
			fi
		fi
	fi

	PASS=$((PASS + 1))
}

if [ -d "$TARGET" ]; then
	while IFS= read -r f; do check_file "$f"; done < <(find "$TARGET" -name "*.cx" -not -path "*/node_modules/*")
elif [ -f "$TARGET" ]; then
	check_file "$TARGET"
fi

echo "verify-examples: $PASS passed, $FAIL failed"
if [ $FAIL -ne 0 ]; then
	echo ""
	echo "Broken examples:"
	for d in "${FAIL_DETAILS[@]}"; do echo "  $d"; done
	exit 1
fi
exit 0
