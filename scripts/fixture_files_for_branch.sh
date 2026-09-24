#!/bin/sh
# fixture_files_for_branch.sh (#1513) — the FIXTURE_FILES selection a branch
# owes, derived from its own diff.
#
#     make fixtures FIXTURE_FILES="$(sh scripts/fixture_files_for_branch.sh origin/release/0.18)"
#
# `make fixtures` grades 91 module files and ~5,800 cases and took 15-35 minutes
# of every pre-merge run whatever the branch touched, one branch at a time on a
# shared runner. What a branch can actually move is a short list, and this
# prints it. The wrapper (scripts/run_fixture_shards.sh) then grades exactly
# those files, each through the shard that owns it, and REFUSES a name no shard
# owns — so an over-selection is a failure, never a silent skip.
#
# Prints, on one line:
#   * `ALL` — no selection is safe; grade everything (run `make fixtures` with
#     no FIXTURE_FILES). This is the fail-safe direction and every doubt
#     resolves to it;
#   * a space-separated list of `conformance/…` paths;
#   * nothing at all — the branch edits no corpus file and no module source, so
#     it owes this step no selection. An empty FIXTURE_FILES is an UNSELECTED
#     run, which is also the safe direction.
#
# THE RULES, in the order they are applied.
#
#  (0) A base that is not a commit, or a git that refuses: ALL. The classifier's
#      value is that it SHRINKS a step, so every failure of it must grow one
#      (the same fail-safe head_is_docs_only.sh takes).
#
#  (1) ALL when the branch changes what grades, rather than what is graded:
#      vcx/tests/fixtures_grader/**, vcx/tests/code_eval_fixtures*,
#      scripts/run_fixture_shards.sh, scripts/fixtures_census.sh, or the V pin
#      third_party/v, or deps.cxd (a moved pin moves the Ring 0 module every
#      case is parsed and evaluated through; RULED: RS-7, RS-12). A branch that
#      changes the grader must grade everything —
#      its own steps are the evidence the partition lost no case (INT-5,
#      INT-21).
#
#  (2) Every `conformance/**/*.cxd` the branch edits that this grader actually
#      walks: conformance/{stdlib,platform,x,xap}/*.cxd plus the two files that
#      belong to no ring directory, extended.cxd and xml_codec.cxd, plus
#      code.cxd (the driver's own corpus). A conformance file OUTSIDE that walk
#      — core.cxd, fmt.cxd, the llm/ suites — is graded by other steps and by
#      no shard; naming it would FAIL the wrapper, so it is left out and NAMED
#      ON STDERR instead. Left out silently it would look like a selection that
#      covered it.
#
#  (3) The module corpus file of every module source the branch edits:
#      vcx/platform/stdlib_<m>.v, vcx/platform/stdlib_<m>_*.v (and the same
#      under a split product's vcx/cxnet/, vcx/mail/, vcx/store/, vcx/xap/ -- RULED: RS-24),
#      vcx/code/stdlib_<m>.v and stdlib/<m>.cx (the x/ tier's sources left with
#      the agent and ux extractions, RS-12). `<m>` is the V spelling with
#      `_` read as `-`, resolved against the corpus BY NAME:
#        * an exact `conformance/<ring>/<m>.cxd` (in any ring, and all of them
#          when two rings carry the name — `term` is in stdlib/ and x/);
#        * else the family `conformance/<ring>/<m>-*.cxd` — `stdlib_xap.v` has
#          no xap.cxd and owns xap-compose / xap-dist / xap-on / xap-schema /
#          xap-serve;
#        * else the same two questions of `<m>` with its last `-segment`
#          dropped — `stdlib_saml_binding.v` resolves to saml.cxd and
#          `stdlib_http_serve.v` to http.cxd;
#        * else ALL. A module source that resolves to NO corpus file is shared
#          infrastructure (stdlib_iowatch.v, stdlib_codec.v, stdlib_caps.v),
#          and so is a stdlib/*.cx with no corpus file of its own name: what
#          every module sits on cannot be graded by one module's cases.
#
#  (4) conformance/code.cxd when anything under vcx/code/ or vcx/cx/ changed —
#      those are the parser and the evaluator the whole corpus runs through, and
#      code.cxd is the file that pins them.
#
#  (5) deps.cxd (#1641, RULED: RS-7, RS-12): a pinned repository's bundled
#      source comes from deps/<repo>/, so a pin bump changes a module every file
#      that imports it runs through, although no path under this tree moved.
#      The rows that differ between the base's deps.cxd and this one are read,
#      and every walked corpus file that imports a module one of them provides
#      (the row's `module=`, spelled `[?lib '<ns>/<name>' …]` in the file) is
#      selected. A doc-block-only change moves no row and selects nothing. A
#      changed row that names no `module=`, a V repository's row (`v-fork=`, or
#      a `module=` that is a repository name: what it provides is compiled into
#      the binary every case runs through), or a change set given by
#      --changed-files (no base to compare the rows with), is ALL. The rule is
#      applied before rule (1) in the loop, so deps.cxd is judged row by row.
#
# scripts/fixture_files_for_branch_selftest.sh proves one case per rule on
# synthetic repos.
set -u

usage() {
	echo "usage: sh scripts/fixture_files_for_branch.sh <base>   (e.g. origin/release/0.18)" >&2
	echo "       sh scripts/fixture_files_for_branch.sh --changed-files <file>" >&2
}

BASE=${1:-}
if [ -z "$BASE" ]; then
	usage
	# An absent base is rule (0): the caller gets the safe answer AND the usage.
	echo ALL
	exit 0
fi

# --changed-files <file> (#1516) — take the change set from a FILE of paths, one
# per line, instead of from git. Two callers need it: scripts/test_changed.sh,
# which has already computed the change set and must not pay for a second diff,
# and the selftests, which prove a rule over a change set no commit has to
# exist for. The rules below are identical either way; only where the list
# comes from moves.
CHANGED_SRC=""
if [ "$BASE" = "--changed-files" ]; then
	CHANGED_SRC=${2:-}
	if [ -z "$CHANGED_SRC" ] || [ ! -f "$CHANGED_SRC" ]; then
		usage
		echo ALL
		exit 0
	fi
	# Absolute, because the cd below moves out from under a relative path.
	case "$CHANGED_SRC" in
	/*) ;;
	*) CHANGED_SRC="$(CDPATH= cd -- "$(dirname -- "$CHANGED_SRC")" && pwd)/$(basename -- "$CHANGED_SRC")" ;;
	esac
fi

# Resolve the repo from this script's OWN path, so the helper is relocatable —
# the selftest copies it into a synthetic repo and the pipelines run it from a
# worktree.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" || { echo ALL; exit 0; }

if [ -n "$CHANGED_SRC" ]; then
	diff=$(cat "$CHANGED_SRC") || { echo ALL; exit 0; }
else
	# --no-renames: both sides of a rename are judged. With rename detection on, a
	# corpus file moved between rings prints only its new name and the shard that
	# owned the old one goes ungraded.
	diff=$(git diff --no-renames --name-only "${BASE}...HEAD" 2>/dev/null) || { echo ALL; exit 0; }
fi

# The corpus this grader walks — derived from the directories, never listed, the
# same way check_fixture_shard_manifest.sh derives it. A .cxd that lands in a
# ring directory is in the walk the moment it lands.
corpus=$(for d in stdlib platform x xap; do
	for f in conformance/$d/*.cxd; do [ -e "$f" ] && echo "$f"; done
done)

# in_walk <path> — is this conformance file one `make fixtures` grades?
in_walk() {
	case "$1" in
	conformance/stdlib/*.cxd | conformance/platform/*.cxd | conformance/x/*.cxd | conformance/xap/*.cxd) return 0 ;;
	conformance/extended.cxd | conformance/xml_codec.cxd | conformance/code.cxd) return 0 ;;
	esac
	return 1
}

# changed_dep_rows — the `[dep …]` rows that differ between the base's
# deps.cxd and this tree's, one per line (either side's spelling of a moved row).
changed_dep_rows() {
	old=$(git show "${BASE}:deps.cxd" 2>/dev/null | grep -E '^[[:space:]]*\[dep ' | sed 's/^[[:space:]]*//')
	new=$(grep -E '^[[:space:]]*\[dep ' deps.cxd 2>/dev/null | sed 's/^[[:space:]]*//')
	{
		printf '%s\n' "$old" | grep -vxF -e "$new" -e '' 2>/dev/null
		printf '%s\n' "$new" | grep -vxF -e "$old" -e '' 2>/dev/null
	} | sort -u
}

# importers_of <ns/name> — the walked corpus files (the ring directories plus
# the three files outside them) that import the module by that spelling.
importers_of() {
	spell=$1
	for f in $corpus conformance/extended.cxd conformance/xml_codec.cxd conformance/code.cxd; do
		[ -f "$f" ] || continue
		grep -qF "'$spell'" "$f" 2>/dev/null && echo "$f"
		grep -qF "\"$spell\"" "$f" 2>/dev/null && echo "$f"
	done
	return 0
}

# resolve_module <hyphenated name> — prints the corpus path(s) it names, or
# nothing when the name is shared infrastructure.
resolve_module() {
	mm=$1
	while [ -n "$mm" ]; do
		hh=$(printf '%s\n' "$corpus" | awk -v m="$mm" -F/ '{ b = $NF; sub(/\.cxd$/, "", b); if (b == m) print }')
		[ -n "$hh" ] && { printf '%s\n' "$hh"; return 0; }
		hh=$(printf '%s\n' "$corpus" | awk -v p="$mm-" -F/ '{ b = $NF; sub(/\.cxd$/, "", b); if (index(b, p) == 1) print }')
		[ -n "$hh" ] && { printf '%s\n' "$hh"; return 0; }
		case "$mm" in
		*-*) mm=${mm%-*} ;;
		*) mm="" ;;
		esac
	done
	return 1
}

# module_token <path> — the hyphenated module name a source file carries, or
# nothing when the path is not a module source.
module_token() {
	case "$1" in
	stdlib/*.cx)
		b=${1#stdlib/}
		echo "${b%.cx}"
		;;
	vcx/platform/stdlib_*.v | vcx/cxnet/stdlib_*.v | vcx/mail/stdlib_*.v | vcx/store/stdlib_*.v | vcx/xap/stdlib_*.v | vcx/code/stdlib_*.v)
		b=${1##*/stdlib_}
		b=${b%.v}
		b=${b%.c} # stdlib_iowatch_darwin.c.v
		printf '%s\n' "$b" | tr '_' '-'
		;;
	esac
}

all=0
sel=""
outside=""

for f in $diff; do
	# (5) a pin — applied FIRST, before rule (1), so a deps.cxd change is judged
	# row by row whatever rule (1) lists: the modules a changed row provides,
	# and who imports them.
	if [ "$f" = "deps.cxd" ]; then
		if [ -n "$CHANGED_SRC" ] || ! git rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
			all=1
			continue
		fi
		rows=$(changed_dep_rows)
		# No changed row is a doc-block-only change: it selects nothing.
		if [ -n "$rows" ]; then
			mods=""
			nomod=0
			while IFS= read -r row; do
				[ -n "$row" ] || continue
				m=$(printf '%s\n' "$row" | sed -n "s/.*module='\([^']*\)'.*/\1/p")
				[ -n "$m" ] || m=$(printf '%s\n' "$row" | sed -n 's/.*module=\([^] ]*\).*/\1/p')
				# A V repository's row (v-fork=), or a module= that is not a
				# '<ns>/<name>' spelling, provides what the binary itself is built
				# from: every case runs through it, and no importer list covers it.
				case "$row" in *" v-fork="*) nomod=1 ;; esac
				case "$m" in */*) ;; *) nomod=1 ;; esac
				if [ -z "$m" ]; then nomod=1; else mods="$mods $m"; fi
			done <<ROWS
$rows
ROWS
			if [ "$nomod" -eq 1 ]; then
				all=1
				continue
			fi
			for m in $mods; do
				for h in $(importers_of "$m"); do sel="$sel $h"; done
			done
		fi
		continue
	fi

	# (1) what grades, rather than what is graded
	case "$f" in
	vcx/tests/fixtures_grader/* | vcx/tests/code_eval_fixtures* | scripts/run_fixture_shards.sh | scripts/fixtures_census.sh | third_party/v | third_party/v/* | deps.cxd)
		all=1
		continue
		;;
	esac

	# (2) the branch's own corpus files
	case "$f" in
	conformance/*.cxd)
		if in_walk "$f"; then
			sel="$sel $f"
		else
			outside="$outside $f"
		fi
		continue
		;;
	esac

	# (4) the parser and the evaluator the whole corpus runs through
	case "$f" in
	vcx/code/* | vcx/cx/*) sel="$sel conformance/code.cxd" ;;
	esac

	# (3) the module corpus file of an edited module source
	m=$(module_token "$f")
	[ -n "$m" ] || continue
	if hits=$(resolve_module "$m"); then
		for h in $hits; do sel="$sel $h"; done
	else
		all=1
	fi
done

if [ -n "$outside" ]; then
	echo "fixture-files: conformance file(s) this grader does not walk, left out of the selection —" >&2
	for f in $outside; do echo "    $f" >&2; done
	echo "  they are graded by their own steps (check-code-fixtures, the document" >&2
	echo "  lane, corpus-audit), not by make fixtures, and naming one would fail it." >&2
fi

if [ "$all" -eq 1 ]; then
	echo ALL
	exit 0
fi

if [ -z "${sel# }" ]; then
	echo
	exit 0
fi
printf '%s\n' $sel | sort -u | tr '\n' ' ' | sed 's/ $//'
echo
