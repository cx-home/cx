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
#   • PROGRAM tours (code-tour, cxpath-tour, …) — validated via the RUN
#     surface's documented line: `cx FILE [--data=FILE.input.cx]` (#415:
#     --data binds the companion as $doc).
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

	# A publishable example is valid under EITHER reading. `cx fmt` is NOT a
	# data/program discriminator — it succeeds for both (a valid program passes
	# through unchanged), so the old "fmt ok ⇒ data" branch wrongly routed PROGRAM
	# tours (cxpath/modify/match/code) through the data→JSON path, where program
	# surface (directives, [$call], node-valued attrs) fails E211/"expected name".
	#
	# Correct discriminator: try the DATA reading (lossless CX→JSON, the surface
	# the bindings expose) first; if the file is not valid data, fall back to the
	# PROGRAM reading and evaluate it (with a sibling <name>.input.cx as $doc when
	# present). Fail only when NEITHER reading works.
	if "$CX" --from=cx --to=json "$f" > /dev/null 2>&1; then
		PASS=$((PASS + 1))
		return
	fi
	# The PROGRAM reading runs the DOCUMENTED bare-surface line (#415):
	# `cx FILE [--data=FILE.input.cx]` — the same spelling the READMEs and
	# tour headers carry, so this checker exercises the real run surface
	# (including the --data $doc binding) rather than the `cx eval` alias.
	# Flag BEFORE file: the #926 argv cutover made everything after FILE a
	# PROGRAM argument (the ap-flags-after-file anti-pattern) — a trailing
	# --data= is handed to the program instead of binding $doc, and the tour
	# dies on CXER0001. This is also the spelling the tour headers document.
	local input="${f%.cx}.input.cx"
	if [ -f "$input" ]; then
		if ! "$CX" --data="$input" "$f" > /dev/null 2>&1; then
			FAIL=$((FAIL + 1))
			FAIL_DETAILS+=("$rel [neither data-JSON nor the documented run line (with $(basename "$input")) succeeded]")
			return
		fi
	else
		if ! "$CX" "$f" > /dev/null 2>&1; then
			FAIL=$((FAIL + 1))
			FAIL_DETAILS+=("$rel [neither data-JSON nor program run succeeded]")
			return
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
