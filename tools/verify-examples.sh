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
# THIRD READING — examples/platform/ SCENARIOS.
#
# A platform example is not one file with one reading: it is a scenario —
# several documents plus the command line that drives them. Its unit is a
# DIRECTORY holding `run.sh` and `expected.txt`; the scenario passes when
# `run.sh` exits 0 from inside its own directory and its merged
# stdout+stderr equals `expected.txt` byte for byte.
#
# Two properties this buys that the per-file readings cannot:
#
#   * The per-file readings would pass a platform example VACUOUSLY. A flow
#     document is DATA, so `cx --from=cx --to=json checkout.flow.cx`
#     succeeds without ever running `cx flow validate`; an `--env` module is
#     a program whose value is `null`, so it succeeds too. Measured both.
#     So examples/platform/ is excluded from the file walk and graded only
#     by its scenarios — a green here means the commands ran.
#   * Nothing may sit in examples/platform/ unexercised. Every `.cx` under
#     it must live in a scenario directory, and a directory holding one of
#     `run.sh` / `expected.txt` without the other is a FAIL, not a skip.
#     That is the difference between an example and a stray.
#
# A scenario's `run.sh` gets `$CX` (the binary this script measured) and
# runs with its own directory as the working directory, so every path it
# writes is relative and its output carries no absolute path. It echoes each
# command's exit code into its own output, so `expected.txt` pins the exit
# codes too and a refusal is an ASSERTED answer rather than a silent skip.
#
# THE SECOND SCENARIO ROOT — the reference connectors (RULED: 1430-f;
# reference/connectors/README.md §5.1). Each reference connector is a package
# whose `scenario/` directory holds the same `run.sh` + `expected.txt` pair,
# and it is graded by the SAME check_scenario and the SAME stray audit: every
# `.cx` under the root must sit in a scenario directory or be named by one,
# and a half-built scenario is a FAIL. The packages live in
# cx-platform-connector's tree, so the root is that pin's checkout,
# deps/cx-platform-connector/reference/connectors/ (RULED: RS-12). A feature
# document is DATA — a per-file reading would pass a connector vacuously
# without anything opening a socket — so this root has no per-file reading at
# all. The examples/platform/ contract is unchanged.
#
# Usage:
#   tools/verify-examples.sh
#   tools/verify-examples.sh examples/comparisons/
#   tools/verify-examples.sh deps/cx-platform-connector/reference/connectors/

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CX="$ROOT/deps/cx-core-code/vcx/target/cx"

if [ ! -x "$CX" ]; then
	(cd "$ROOT" && make -s build-vcx) || { echo "FAIL: cx build failed"; exit 1; }
fi

TARGET="${1:-$ROOT/examples}"
CONNECTORS="$ROOT/deps/cx-platform-connector/reference/connectors"
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
		# graded by check_scenario() below, never by a per-file reading
		examples/platform/*) return ;;
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

# ── the platform SCENARIO reading ────────────────────────────────────────
#
# One scenario = one directory carrying `run.sh` + `expected.txt`. The driver
# runs from inside that directory with $CX bound to the measured binary, and
# its merged output must equal expected.txt exactly.
SCEN_PASS=0
SCEN_FAIL=0

# load_1m — the one-minute load average, recorded beside a scenario's verdict
# so a row in the run log is classifiable afterwards (#1477).
load_1m() {
	local l
	if l="$(sysctl -n vm.loadavg 2>/dev/null)" && [ -n "$l" ]; then
		printf '%s\n' "$l" | awk '{ gsub(/[{}]/, ""); print $1 + 0 }'
		return 0
	fi
	[ -r /proc/loadavg ] && awk '{ print $1 + 0 }' /proc/loadavg && return 0
	printf '%s\n' unknown
}

# scenario_never_connected — the DAEMON-START-UNDER-LOAD signature (#1477):
# the scenario's server never answered, so either the readiness wait said so or
# every request it made came back `status=000` (curl never connected). Both are
# a statement about the box, not about the example — nineteen `status=000`
# lines diffed against expected.txt on the post-merge run of bc9bfd24c at a
# 15-minute load average of 69, and the same scenario had passed thirty minutes
# earlier. A scenario that answered ANY request is not in this class.
scenario_never_connected() {
	local out="$1"
	case "$out" in *scenario-wait-ready:*) return 0 ;; esac
	case "$out" in *status=000*) ;; *) return 1 ;; esac
	printf '%s\n' "$out" | grep -qE 'status=[0-9]{3}' || return 1
	printf '%s\n' "$out" | grep -E 'status=[0-9]{3}' | grep -qv 'status=000' && return 1
	return 0
}

check_scenario() {
	local dir="$1"
	local rel="${dir#$ROOT/}"
	local out rc load

	out="$(cd "$dir" && CX="$CX" sh ./run.sh 2>&1)"
	rc=$?
	# The classified retry the V suite's load classes already have (1431-a /
	# 1432-a), for the one class the platform scenarios can hit: the server
	# never came up inside the scenario's window. It is a RE-RUN of the whole
	# scenario, once, serially — not a loosened expectation and not a skip: the
	# second run still has to match expected.txt exactly.
	if scenario_never_connected "$out"; then
		load="$(load_1m)"
		echo "verify-examples: $rel — the server never answered (one-minute load $load); the #1477 daemon-start-under-load class. Re-running once, serially." >&2
		out="$(cd "$dir" && CX="$CX" sh ./run.sh 2>&1)"
		rc=$?
		if scenario_never_connected "$out"; then
			SCEN_FAIL=$((SCEN_FAIL + 1))
			FAIL_DETAILS+=("$rel [the server never answered on EITHER run (one-minute load $load, then $(load_1m)) — #1477's class, but twice is not a flake: read the scenario's own readiness diagnosis above]")
			return
		fi
		echo "verify-examples: $rel — passed the serial re-run (one-minute load $(load_1m))." >&2
	fi
	if [ "$rc" -ne 0 ]; then
		SCEN_FAIL=$((SCEN_FAIL + 1))
		FAIL_DETAILS+=("$rel/run.sh [driver exited $rc; a scenario driver must exit 0 and pin each command's own exit code in its output]")
		return
	fi
	if [ "$out" != "$(cat "$dir/expected.txt")" ]; then
		SCEN_FAIL=$((SCEN_FAIL + 1))
		FAIL_DETAILS+=("$rel [output DISAGREES with expected.txt — re-read the README's claim before re-recording:
$(diff -u "$dir/expected.txt" <(printf '%s\n' "$out") | sed -n '3,40p' | sed 's/^/      /')]")
		return
	fi
	SCEN_PASS=$((SCEN_PASS + 1))
}

# Every .cx under examples/platform/ must be REACHED by a scenario — either
# it sits in a scenario directory, or a scenario names it (a module two
# scenarios share, like the mock identity provider, lives beside them and is
# reached by [?lib]). A file nothing runs and nothing names is a stray, and
# this is where that is caught.
audit_platform_tree() {
	local root="$1"
	[ -d "$root" ] || return 0
	local f dir rel base
	while IFS= read -r f; do
		dir="$(dirname "$f")"
		rel="${f#$ROOT/}"
		base="$(basename "$f")"
		while [ "$dir" != "$root" ] && [ ! -f "$dir/run.sh" ]; do
			dir="$(dirname "$dir")"
		done
		if [ ! -f "$dir/run.sh" ]; then
			# not in a scenario directory: some scenario must NAME it
			if ! grep -rqF -- "$base" --include='run.sh' --include='*.cx' "$root" 2>/dev/null; then
				SCEN_FAIL=$((SCEN_FAIL + 1))
				FAIL_DETAILS+=("$rel [no scenario runs or names this file — every .cx under ${root#$ROOT/}/ must sit in a scenario directory or be reached from one]")
			fi
		fi
	done < <(find "$root" -name "*.cx" -not -path "*/node_modules/*")

	# a half-built scenario is a FAIL, never a skip
	while IFS= read -r dir; do
		if [ ! -f "$dir/expected.txt" ]; then
			SCEN_FAIL=$((SCEN_FAIL + 1))
			FAIL_DETAILS+=("${dir#$ROOT/} [run.sh with no expected.txt — a scenario that asserts nothing]")
		fi
	done < <(find "$root" -name run.sh -exec dirname {} \;)
	while IFS= read -r dir; do
		if [ ! -f "$dir/run.sh" ]; then
			SCEN_FAIL=$((SCEN_FAIL + 1))
			FAIL_DETAILS+=("${dir#$ROOT/} [expected.txt with no run.sh — nothing produces it]")
		fi
	done < <(find "$root" -name expected.txt -exec dirname {} \;)
}

# scenario_root — the stray audit, then every scenario under one root.
scenario_root() {
	local root="$1"
	[ -d "$root" ] || return 0
	audit_platform_tree "$root"
	while IFS= read -r dir; do check_scenario "$dir"; done < <(find "$root" -name run.sh -exec dirname {} \; | sort)
}

TARGET_ABS="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET")"
case "$TARGET_ABS/" in
	"$CONNECTORS"/*)
		# a reference connector, or the whole root: scenarios only
		scenario_root "$CONNECTORS"
		;;
	*)
		if [ -d "$TARGET" ]; then
			while IFS= read -r f; do check_file "$f"; done < <(find "$TARGET" -name "*.cx" -not -path "*/node_modules/*")
			PLATFORM="$TARGET/platform"
			case "$TARGET" in
				*/platform|*/platform/*) PLATFORM="$TARGET" ;;
			esac
			scenario_root "$PLATFORM"
		elif [ -f "$TARGET" ]; then
			check_file "$TARGET"
		fi
		# The default run grades the second root too; a pin with no
		# reference/connectors/ (a checkout that predates it) grades nothing
		# there, and deps-present is the step that says a pin is missing.
		[ $# -eq 0 ] && scenario_root "$CONNECTORS"
		;;
esac

echo "verify-examples: $PASS passed, $FAIL failed; platform scenarios: $SCEN_PASS passed, $SCEN_FAIL failed"
if [ $FAIL -ne 0 ] || [ $SCEN_FAIL -ne 0 ]; then
	echo ""
	echo "Broken examples:"
	for d in "${FAIL_DETAILS[@]}"; do echo "  $d"; done
	exit 1
fi
exit 0
