#!/bin/sh
# classify_v_build_failure.sh — does a failed V build's output carry a
# C-SYMBOL-LEVEL failure, i.e. one worth re-running with `-no-skip-unused`?
#
# WHY THIS EXISTS (#1337). A gate went red like this:
#
#   cc: /tmp/v_501/address_baseline.<id>.tmp.c:341652:19: error: call to
#       undeclared function 'string_runes'; ISO C99 and later do not support
#       implicit function declarations [-Wimplicit-function-declaration]
#   cc: /tmp/v_501/address_baseline.<id>.tmp.c:341652:14: error: initializing
#       'Array_rune' (aka 'struct array') with an expression of incompatible
#       type 'int'
#
# Those are ONE defect, not two: C99's implicit declaration gives the
# undeclared call type `int`, and the second line is that `int` meeting the
# real return type. The single defect is that `string_runes` was CALLED and
# never DECLARED in the generated translation unit.
#
# #1337 attributed it to the `-usecache` module cache. It cannot be that:
# `address-baseline-gate` runs `$(V) $(VFLAGS_VCX) run`, and
# `VFLAGS_VCX := -cc cc -path "$(V_MODULE_PATH)"` has carried NO `-usecache`
# since the single commit that ever wrote that line (1e144acff). The cache was
# off in the failing run AND in the "cache-free" re-run the issue reports as a
# discriminator — the same command twice, so its greenness is a NON-
# REPRODUCTION, not a discriminator.
#
# What IS on for every such build is `-skip-unused`: for the C backend and any
# build that is not `-build-module`, V sets `skip_unused = true`
# unconditionally (third_party/v/vlib/v/pref/pref.v:1477-1481). Pruning a
# symbol the translation unit still references is precisely this failure
# class, the fork already carries two patches in it —
#
#   5f6bc5ab07  markused: fix undeclared C identifier for alias array type (#27660)
#   third_party/v/vlib/v/markused/markused.v:286-302 (CX), whose own comment
#               reads "the wrapper references an undeclared function -> C error"
#
# — and NEITHER covers a cache-free program TU. So the honest re-run for a
# `$(V) ... run` gate is `-no-skip-unused`, which really does differ from the
# failing command. A cache-free re-run of one differs from it in nothing,
# which is why that option was rejected when ask 2 was taken (Makefile, the
# check-vcache-soundness comment): that reasoning was right about the cache
# and wrong about the remedy.
#
# CONTRACT
#   classify_v_build_failure.sh LOGFILE
#       exit 0  the log carries a C symbol-level failure -> re-run with
#               -no-skip-unused and classify; the caller's verdict stays RED
#               either way.
#       exit 1  it does not (an ordinary behavioral red: a moved address, a
#               failed assertion, a diverged transcript). No re-run: a
#               whole-graph rebuild on every legitimate red is pure cost.
#       exit 2  usage.
#
#   classify_v_build_failure.sh --self-test
#       Red-proofs the matcher from BOTH ends over canned logs, including the
#       verbatim #1337 text. A matcher that silently stops matching disables
#       the diagnosis while the gate looks unchanged — the vacuous-gate class
#       that check-serial-retry-rosters exists for.
#
# The matcher is deliberately narrow: only symbol-level C/link errors. Adding
# a generic 'error:' would make every red re-run the whole graph.

set -u

SIGNATURE='call to undeclared function|call to undeclared identifier|implicit-function-declaration|implicit declaration of function|use of undeclared identifier|Undefined symbols for architecture|undefined reference to|ld: symbol\(s\) not found'

classify() {
	log=$1
	[ -f "$log" ] || return 1
	grep -qE "$SIGNATURE" "$log" 2>/dev/null
}

# One minimal SAMPLE per alternative in SIGNATURE, `alternative<TAB>sample`.
# The self-test requires that EVERY alternative has a sample and that the
# sample matches — so removing an alternative reds (its sample stops
# matching) and ADDING one without a sample reds too. Without this, the
# positive cases over-covered: the verbatim #1337 log carries BOTH
# "call to undeclared function" and "implicit-function-declaration", so
# deleting either alternative left the suite green. Measured, not assumed.
signature_samples() {
	cat <<'SAMPLES'
call to undeclared function	cc: x.tmp.c:1:1: error: call to undeclared function 'string_runes'
call to undeclared identifier	cc: x.tmp.c:1:1: error: call to undeclared identifier 'Array_rune'
implicit-function-declaration	cc: x.tmp.c:1:1: error: something [-Wimplicit-function-declaration]
implicit declaration of function	x.tmp.c:1:1: warning: implicit declaration of function 'string_runes'
use of undeclared identifier	cc: x.tmp.c:1:1: error: use of undeclared identifier 'g_str_buf'
Undefined symbols for architecture	Undefined symbols for architecture arm64:
undefined reference to	/usr/bin/ld: x.o: undefined reference to `string_runes'
ld: symbol(s) not found	ld: symbol(s) not found for architecture arm64
SAMPLES
}

self_test() {
	tmp=${TMPDIR:-/tmp}/classify_v_build_failure.selftest.$$
	mkdir -p "$tmp" || return 1
	rc=0
	nalt=0
	nmatch=0

	# --- every alternative in SIGNATURE is load-bearing ----------------------
	# Split SIGNATURE on `|` OUTSIDE the escaped-paren group. `ld: symbol\(s\)`
	# carries no `|`, so a plain split on `|` is exact here; assert the count
	# instead of trusting it.
	old_ifs=$IFS
	IFS='|'
	for alt in $SIGNATURE; do
		nalt=$((nalt + 1))
		IFS=$old_ifs
		plain=$(printf '%s' "$alt" | sed 's/\\//g')
		sample=$(signature_samples | awk -F'\t' -v a="$plain" '$1 == a { print $2; found=1 } END { if (!found) exit 3 }')
		if [ -z "$sample" ]; then
			echo "  alternative [$plain]: NO SAMPLE <- FAIL (add one to signature_samples)"
			rc=1
			IFS='|'
			continue
		fi
		printf '%s\n' "$sample" > "$tmp/alt"
		if classify "$tmp/alt"; then
			nmatch=$((nmatch + 1))
		else
			echo "  alternative [$plain]: its own sample does NOT match <- FAIL"
			rc=1
		fi
		IFS='|'
	done
	IFS=$old_ifs
	if [ "$nalt" -lt 8 ]; then
		echo "  SIGNATURE holds $nalt alternatives, expected at least 8 <- FAIL"
		rc=1
	fi
	[ "$rc" -eq 0 ] && echo "  $nmatch/$nalt signature alternatives each matched by their own sample"

	# --- MUST MATCH: the real-world logs, verbatim --------------------------
	# The verbatim #1337 failure. Both lines are ONE defect: C99's implicit
	# declaration types the undeclared call `int`, and line 2 is that `int`
	# meeting the real return type.
	cat > "$tmp/m1" <<'EOF'
cc: /tmp/v_501/address_baseline.01M1VYKMFNW4NH0EBWXYK4MPR0.tmp.c:341652:19: error: call to undeclared function 'string_runes'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
cc: /tmp/v_501/address_baseline.01M1VYKMFNW4NH0EBWXYK4MPR0.tmp.c:341652:14: error: initializing 'Array_rune' (aka 'struct array') with an expression of incompatible type 'int'
EOF
	# The #700 wave-2 link failure that motivated the cache probes (H11).
	cat > "$tmp/m2" <<'EOF'
ld: symbol(s) not found for architecture arm64
  builtin__closure__closure_init
EOF

	# --- MUST NOT MATCH -----------------------------------------------------
	# The gate's OWN ordinary red: an address moved. A -no-skip-unused re-run
	# here would cost a whole-graph rebuild and classify nothing.
	cat > "$tmp/n1" <<'EOF'
address-baseline: FAILED — 2 Tier-2 addresses differ from the recorded baseline
  cx.data/parse            expected 0x4f2a... observed 0x91bc...
  no re-bless is available to this stream; see address-baseline-capture
EOF
	# An ordinary V type error — real, but not a pruning artifact.
	cat > "$tmp/n2" <<'EOF'
vcx/code/eval.v:120:5: error: expected `string`, not `int`
EOF
	# A green log.
	cat > "$tmp/n3" <<'EOF'
301 Tier-2 def addresses byte-identical to baseline
EOF
	# An absent log is not a match, and must not error.
	rm -f "$tmp/missing"

	for f in m1 m2; do
		if classify "$tmp/$f"; then
			echo "  real-world $f: MATCH (expected MATCH)"
		else
			echo "  real-world $f: NO MATCH (expected MATCH) <- FAIL"; rc=1
		fi
	done
	for f in n1 n2 n3 missing; do
		if classify "$tmp/$f"; then
			echo "  negative $f: MATCH (expected NO MATCH) <- FAIL"; rc=1
		else
			echo "  negative $f: NO MATCH (expected NO MATCH)"
		fi
	done

	rm -rf "$tmp"
	if [ "$rc" -eq 0 ]; then
		echo "classify_v_build_failure: self-test OK — $nalt alternatives each"
		echo "  load-bearing, 2 real-world logs match, 4 negatives do not."
	else
		echo "classify_v_build_failure: self-test FAILED — the matcher no longer"
		echo "  classifies the failures it was written for. A classifier that"
		echo "  stops matching hides the diagnosis while the gate looks unchanged."
	fi
	return $rc
}

case "${1:-}" in
	--self-test) self_test ;;
	'') echo "usage: $0 LOGFILE | --self-test" >&2; exit 2 ;;
	*) classify "$1" ;;
esac
