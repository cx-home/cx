#!/usr/bin/env bash
# vcache_soundness_gate.sh — adversarial proof of the V module-cache key.
# #700 wave 2 part (i), under VC-23; audit: ledger/audit_2026_08_24_vcache_key_soundness.md
#
# The invariant under test: a `-usecache` build must behave EXACTLY like a
# cache-free build of the current sources under the current configuration —
# for every input that can change the bytes of a cached module object,
# mutating the input invalidates (or the build fails loudly); byte-identical
# re-runs hit. A cached object is never served without evidence it was built
# from the current inputs (provenance manifest, bound to the object bytes).
#
# Every probe is a behavioral EXPECTED/OBSERVED assertion: we run the built
# binary and compare its output against what the current sources say — a
# probe can only go green by the build being CORRECT, not by any particular
# internal mechanism. That keeps the gate red-capable against future
# regressions in the mechanism itself.
#
# Probes (H-numbers refer to the audit table):
#   hit-identity      warm identical rebuild must HIT (the cache must stay a cache)
#   src-invalidate    module source edit must rebuild + change behavior
#   H1  cc-identity   swapping the compiler BINARY behind an unchanged name must MISS
#   H2  define-value  -d name=VALUE change must invalidate ($d)
#   H3  cross-config  a second -d namespace must not serve objects from deleted source
#   H5  tmpl          $tmpl template content change must invalidate
#   H6  env           $env value change must invalidate
#   H7  c-header      local #include'd header content change must invalidate
#   H4  fail-closed   a failed module rebuild must never lead to a silently stale
#                     binary; after the cause is fixed the build converges
#   POISON            a planted valid-but-wrong .o at the cache path must be
#                     detected or bypassed — never linked
#   DUP (#572 class)  mixed-generation layers (stale layer w/ exported symbol +
#                     on-demand fresh layer) must produce the correct binary,
#                     never a duplicate-symbol link or a stale pick
#   KEY-CANON (H10)   one module must occupy ONE cache key regardless of path
#                     spelling (builtin rel/abs twin build)
#
# Red proof: run with --prove-red. It forges a provenance manifest (rewrites
# the recorded object hash to bless a planted wrong object — simulating an
# input the manifest fails to cover) and requires the POISON probe to go RED.
# The gate exits 0 in this mode only if the forgery IS caught by the gate
# (probe red), proving the gate detects exactly the class it exists for.
#
# Cadence: scripts/ gate, run via `make check-vcache-soundness` (devbox).
# Not in the default TEST_TARGETS ring: it proves the COMPILER's cache, so it
# belongs to fork-touching changes — run it whenever third_party/v changes
# (check-v-fork territory), before any release cut, and before widening
# -usecache to more lanes. Recorded in the audit file.
#
# Usage: bash scripts/vcache_soundness_gate.sh [--prove-red]
#        (devbox is NOT required since #1337 - see PORTABLE PRIMITIVES below.
#        It used to be, silently: outside the nix stdenv this script's GNU-only
#        in-place sed and `stat -c` failed, five mutation probes scored an
#        UNMUTATED fixture as RED, and hit-identity went vacuously GREEN. The
#        Makefile recipe runs it as a bare `bash`, so the invocation environment
#        decided the verdict. It no longer can: the primitives are portable and
#        every mutation asserts it applied.)
# Env:   CX_V=<path to fork v>   VCACHE_GATE_WORK=<workdir>

set -u
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$SCRIPT_DIR/.." && pwd)
V=${CX_V:-$REPO/third_party/v/v}
# The workdir must NOT sit under a v.mod ancestor (vcx/ has one): a v.mod
# root changes module identity — fixture symbols pick up path-derived module
# prefixes and $tmpl derives generated names from the v.mod-relative path —
# which breaks the fixtures in ways unrelated to the cache under test.
WORK=${VCACHE_GATE_WORK:-/tmp/cx-vcache-gate}
MODE=${1:-}

if [ ! -x "$V" ]; then
  echo "vcache-soundness: fork v not found at $V (build it first)"; exit 2
fi

rm -rf "$WORK"; mkdir -p "$WORK"
PASS=0; RED=0; T0=$SECONDS

note()    { echo "── $*"; }
verdict() { # $1 probe  $2 expected  $3 observed
  if [ "$2" = "$3" ]; then
    echo "PROBE $1: SOUND (expected='$2' observed='$3')"; PASS=$((PASS+1))
  else
    echo "PROBE $1: RED — expected='$2' observed='$3'"; RED=$((RED+1))
  fi
}

# mkfix <dir>  — writes prog.v importing mymod; caller writes mymod/mymod.v.
mkfix() {
  rm -rf "$WORK/$1"; mkdir -p "$WORK/$1/mymod"
  printf 'import mymod\n\nfn main() {\n\tprintln(mymod.probe())\n}\n' > "$WORK/$1/prog.v"
}

# ── PORTABLE PRIMITIVES, AND WHY THEY ARE NOT OPTIONAL (#1337) ──────────────
# This gate was written with GNU-only spellings: in-place sed with no backup
# suffix, and `stat -c` piped through md5sum with `xargs -r`. macOS base
# userland has none of them. The Makefile recipe runs `bash scripts/...` with
# NO devbox wrapper (see check-vcache-soundness), so PATH decides which
# userland answers, and outside the nix stdenv this script degraded SILENTLY.
# A/B measured on this box, 2026-09-08, on the same one-line fixture:
#
#   bare shell   in-place sed -> rc=1, file UNCHANGED; stat -c -> rc=1,
#                "stat: illegal option -- c"; sed is /usr/bin/sed (BSD)
#   devbox run   rc=0, file changed to 'S2'; stat -c ok; sed is
#                /nix/store/...-gnused-4.9/bin/sed  (GNU sed 4.9)
#
# The five mutation probes then compared the PRE-mutation program against the
# post-mutation expectation and reported RED, and osnap collapsed to the
# digest of empty input so hit-identity compared two identical constants and
# went VACUOUSLY GREEN. That is the whole of the `sound=10 red=6` result that
# filed #1337 - five false reds and one false green, the cache never at fault.
# A prio:high landing was held for a full verification cycle over it.
#
# So the fix is not "require GNU". It is:
#   1. portable spellings, so the gate is correct in BOTH userlands, and
#   2. EVERY MUTATION ASSERTS IT APPLIED. A probe may never draw a conclusion
#      from a fixture it failed to mutate - that is a tooling fault, and it
#      exits 2 loudly rather than being scored as evidence about the cache.
# (2) is the load-bearing half: it holds against any future mutation-tool
# failure, not only against this one.

# stat_mtime FILE - seconds since epoch, GNU or BSD spelling. Resolved once.
if stat -c '%Y' "$SCRIPT_DIR" >/dev/null 2>&1; then
  stat_mtime() { stat -c '%Y' "$1"; }        # GNU coreutils
elif stat -f '%m' "$SCRIPT_DIR" >/dev/null 2>&1; then
  stat_mtime() { stat -f '%m' "$1"; }        # BSD / macOS base
else
  echo "vcache-soundness: FATAL - no usable stat(1): neither the GNU nor the"
  echo "  BSD mtime spelling works here. The gate cannot tell whether a cached"
  echo "  object was rewritten, so every HIT/MISS verdict would be unearned."
  exit 2
fi

# digest - a stable fingerprint of stdin. cksum is POSIX and always present;
# md5sum is not (macOS base ships md5, not md5sum).
digest() { cksum; }

# osnap - fingerprint of the MTIMES of every cached object.
#
# Mtime, deliberately, not content: the question these probes ask is "was this
# object REUSED or REWRITTEN". A cache MISS that happens to recompile
# byte-identical output is still a MISS, and a content digest would score it
# HIT - which would turn H1-cc-identity (expects MISS) into a false red and
# hit-identity into a vacuous pass. `xargs -r` is GNU-only; the read loop
# handles empty input by doing nothing, which is the same thing portably.
osnap() {
  find "$VCACHE" -name '*.o' 2>/dev/null | sort | while IFS= read -r f; do
    printf '%s %s\n' "$(stat_mtime "$f")" "$f"
  done | digest
}

# mutate FILE SED-EXPR - an in-place edit that PROVES it happened.
# Portable (plain sed to a temp, then mv - the backup-suffix idiom
# scripts/bump_version.sh:29 uses, one step further so no .bak is left beside
# a fixture the compiler then globs). A no-op edit is a TOOLING FAULT, never a
# probe result: exit 2, loudly, naming the remedy.
MUTATIONS=0
mutate() {
  _f=$1; _expr=$2
  [ -f "$_f" ] || { echo "vcache-soundness: FATAL - mutate: no such file: $_f"; exit 2; }
  _before=$(digest < "$_f")
  sed "$_expr" "$_f" > "$_f.mutating" || {
    echo "vcache-soundness: FATAL - mutate: sed failed on $_f (expr: $_expr)"; exit 2; }
  mv "$_f.mutating" "$_f"
  _after=$(digest < "$_f")
  if [ "$_before" = "$_after" ]; then
    echo "vcache-soundness: FATAL - the mutation did not change the fixture."
    echo "  file: $_f"
    echo "  expr: $_expr"
    echo "  This is a TOOLING fault, not a cache result. Every mutation probe"
    echo "  below would have compared the UNMUTATED program against the mutated"
    echo "  expectation and reported RED with the cache never at fault - which"
    echo "  is exactly what #1337 was: five false reds and one false green."
    echo "  Check sed(1) and this expression before reading any verdict."
    exit 2
  fi
  MUTATIONS=$((MUTATIONS+1))
}

# Prove both primitives work BEFORE any probe runs, so a broken toolchain
# fails here - at the top, named - instead of as six mysterious probe reds.
_pf="$WORK/.preflight"
mkdir -p "$WORK"
printf "return 'S1'\n" > "$_pf"
mutate "$_pf" "s/'S1'/'S2'/"
if [ "$(cat "$_pf")" != "return 'S2'" ]; then
  echo "vcache-soundness: FATAL - preflight mutation produced [$(cat "$_pf")]"; exit 2
fi
stat_mtime "$_pf" >/dev/null 2>&1 || {
  echo "vcache-soundness: FATAL - preflight stat_mtime failed"; exit 2; }
rm -f "$_pf"
MUTATIONS=0
note "preflight OK - in-place mutation and mtime snapshots both work here"

# ── hit-identity + src-invalidate ────────────────────────────────────────────
note "hit-identity / src-invalidate"
mkfix base
cat > "$WORK/base/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'S1'
}
EOF
cd "$WORK/base"; export VCACHE="$WORK/base/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "base build1 FAILED"
s1=$(osnap)
"$V" -usecache -o p2 prog.v >/dev/null 2>&1 || echo "base build2 FAILED"
s2=$(osnap)
hit=$([ "$s1" = "$s2" ] && echo HIT || echo MISS)
verdict "hit-identity" "HIT" "$hit"
mutate mymod/mymod.v "s/'S1'/'S2'/"
"$V" -usecache -o p3 prog.v >/dev/null 2>&1 || echo "base build3 FAILED"
verdict "src-invalidate" "S2" "$(./p3 2>/dev/null || echo BUILD-FAILED)"

# ── H1 cc-identity ───────────────────────────────────────────────────────────
note "H1 cc-identity"
mkfix h1
cat > "$WORK/h1/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'S1'
}
EOF
mkdir -p "$WORK/h1/bin"
REALCC=$(command -v clang || command -v gcc)
printf '#!/bin/sh\nexec %s "$@"\n' "$REALCC" > "$WORK/h1/bin/mycc"
chmod +x "$WORK/h1/bin/mycc"
cd "$WORK/h1"; export VCACHE="$WORK/h1/.vcache"
"$V" -usecache -cc "$WORK/h1/bin/mycc" -o p1 prog.v >/dev/null 2>&1 || echo "h1 build1 FAILED"
s1=$(osnap)
sleep 1
printf '#!/bin/sh\n# generation 2 of the same-named compiler\nexec %s "$@"\n' "$REALCC" > "$WORK/h1/bin/mycc"
"$V" -usecache -cc "$WORK/h1/bin/mycc" -o p2 prog.v >/dev/null 2>&1 || echo "h1 build2 FAILED"
s2=$(osnap)
miss=$([ "$s1" = "$s2" ] && echo HIT || echo MISS)
verdict "H1-cc-identity" "MISS" "$miss"

# ── H2 define-value ──────────────────────────────────────────────────────────
note "H2 define-value"
mkfix h2
cat > "$WORK/h2/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return $d('lvl', 'zero')
}
EOF
cd "$WORK/h2"; export VCACHE="$WORK/h2/.vcache"
"$V" -usecache -d lvl=one -o p1 prog.v >/dev/null 2>&1 || echo "h2 build1 FAILED"
"$V" -usecache -d lvl=two -o p2 prog.v >/dev/null 2>&1 || echo "h2 build2 FAILED"
verdict "H2-define-value" "two" "$(./p2 2>/dev/null || echo BUILD-FAILED)"

# ── H3 cross-config staleness ────────────────────────────────────────────────
note "H3 cross-config"
mkfix h3
cat > "$WORK/h3/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'S1'
}
EOF
cd "$WORK/h3"; export VCACHE="$WORK/h3/.vcache"
"$V" -usecache -o pa prog.v >/dev/null 2>&1 || echo "h3 A1 FAILED"
"$V" -usecache -d cfgb -o pb prog.v >/dev/null 2>&1 || echo "h3 B1 FAILED"
mutate mymod/mymod.v "s/'S1'/'S2'/"
"$V" -usecache -o pa2 prog.v >/dev/null 2>&1 || echo "h3 A2 FAILED"
"$V" -usecache -d cfgb -o pb2 prog.v >/dev/null 2>&1 || echo "h3 B2 FAILED"
verdict "H3-configA" "S2" "$(./pa2 2>/dev/null || echo BUILD-FAILED)"
verdict "H3-configB" "S2" "$(./pb2 2>/dev/null || echo BUILD-FAILED)"

# ── H5 $tmpl ─────────────────────────────────────────────────────────────────
note "H5 tmpl"
mkfix h5
cat > "$WORK/h5/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	name := 'x'
	_ = name
	return $tmpl('probe.txt')
}
EOF
echo 'T1 @name' > "$WORK/h5/mymod/probe.txt"
cd "$WORK/h5"; export VCACHE="$WORK/h5/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "h5 build1 FAILED"
echo 'T2 @name' > "$WORK/h5/mymod/probe.txt"
"$V" -usecache -o p2 prog.v >/dev/null 2>&1 || echo "h5 build2 FAILED"
verdict "H5-tmpl" "T2" "$(./p2 2>/dev/null | head -1 | cut -d' ' -f1 || echo BUILD-FAILED)"

# ── H6 $env ──────────────────────────────────────────────────────────────────
note "H6 env"
mkfix h6
cat > "$WORK/h6/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return $env('VCACHE_GATE_PROBE_ENV')
}
EOF
cd "$WORK/h6"; export VCACHE="$WORK/h6/.vcache"
VCACHE_GATE_PROBE_ENV=alpha "$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "h6 build1 FAILED"
VCACHE_GATE_PROBE_ENV=beta "$V" -usecache -o p2 prog.v >/dev/null 2>&1 || echo "h6 build2 FAILED"
verdict "H6-env" "beta" "$(./p2 2>/dev/null || echo BUILD-FAILED)"

# ── H7 C header ──────────────────────────────────────────────────────────────
note "H7 c-header"
mkfix h7
cat > "$WORK/h7/mymod/extra.h" <<'EOF'
static inline int extra_val(void) { return 1; }
EOF
cat > "$WORK/h7/mymod/mymod.v" <<EOF
module mymod

#include "$WORK/h7/mymod/extra.h"

fn C.extra_val() int

pub fn probe() string {
	return C.extra_val().str()
}
EOF
cd "$WORK/h7"; export VCACHE="$WORK/h7/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "h7 build1 FAILED"
mutate "$WORK/h7/mymod/extra.h" 's/return 1;/return 2;/'
"$V" -usecache -o p2 prog.v >/dev/null 2>&1 || echo "h7 build2 FAILED"
verdict "H7-c-header" "2" "$(./p2 2>/dev/null || echo BUILD-FAILED)"

# ── H4 fail-closed on failed rebuild ─────────────────────────────────────────
note "H4 fail-closed"
mkfix h4
cat > "$WORK/h4/mymod/extra.h" <<'EOF'
static inline int extra_val(void) { return 1; }
EOF
cat > "$WORK/h4/mymod/mymod.v" <<EOF
module mymod

#include "$WORK/h4/mymod/extra.h"

fn C.extra_val() int

pub fn probe() string {
	return 'A' + C.extra_val().str()
}
EOF
cd "$WORK/h4"; export VCACHE="$WORK/h4/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "h4 build1 FAILED"
mv "$WORK/h4/mymod/extra.h" "$WORK/h4/extra.h.saved"
mutate mymod/mymod.v "s/'A'/'B'/"
"$V" -usecache -o p2 prog.v >/dev/null 2>&1
rc2=$?
o2=$([ -x ./p2 ] && ./p2 2>/dev/null || echo BUILD-FAILED)
# While the cause persists, silently-stale output is the one forbidden result:
if [ $rc2 -ne 0 ] || [ "$o2" = "B1" ]; then
  verdict "H4-during-failure" "loud-or-current" "loud-or-current"
else
  verdict "H4-during-failure" "loud-or-current" "silently-stale:$o2"
fi
mv "$WORK/h4/extra.h.saved" "$WORK/h4/mymod/extra.h"
"$V" -usecache -o p3 prog.v >/dev/null 2>&1 || echo "h4 build3 FAILED"
verdict "H4-recovery" "B1" "$(./p3 2>/dev/null || echo BUILD-FAILED)"

# ── POISON planted .o (and the --prove-red forgery) ─────────────────────────
note "POISON planted .o"
mkfix po
cat > "$WORK/po/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'GOOD'
}
EOF
mkfix po-evil
cat > "$WORK/po-evil/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'EVIL'
}
EOF
cd "$WORK/po-evil"; export VCACHE="$WORK/po-evil/.vcache"
"$V" -usecache -o pe prog.v >/dev/null 2>&1 || echo "po-evil build FAILED"
evil_o=$(find "$VCACHE" -name '*mymod.o' | head -1)
cd "$WORK/po"; export VCACHE="$WORK/po/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "po build1 FAILED"
good_o=$(find "$VCACHE" -name '*mymod.o' | head -1)
cp "$evil_o" "$good_o"
if [ "$MODE" = "--prove-red" ]; then
  # Forge the provenance manifest: bless the planted object's bytes by
  # splicing the evil build's own object-binding line into the good manifest,
  # keeping the good source rows — simulating an input the manifest fails to
  # cover. The probe below MUST then go red; that redness is this gate's
  # proof of life.
  good_m="${good_o%.o}.srcs.txt"
  evil_m="${evil_o%.o}.srcs.txt"
  if [ -f "$good_m" ] && [ -f "$evil_m" ]; then
    evil_oline=$(grep -m1 '^o:' "$evil_m")
    mutate "$good_m" "s|^o:.*|$evil_oline|"
    echo "prove-red: forged manifest $(basename "$good_m") with the planted object's binding"
  else
    echo "prove-red: no provenance manifest exists yet (pre-fix tree) — the plain plant below must already be red"
  fi
fi
rm -f ./p2
"$V" -usecache -o p2 prog.v >/dev/null 2>&1 || echo "po build2 FAILED (loud rejection is acceptable)"
po_obs=$([ -x ./p2 ] && ./p2 2>/dev/null || echo BUILD-REFUSED)
verdict "POISON" "GOOD" "$po_obs"

# ── DUP: #572 duplicate-symbol class ─────────────────────────────────────────
note "DUP #572 class"
D="$WORK/dup"; rm -rf "$D"; mkdir -p "$D/ma" "$D/mb"
printf 'import ma\nimport mb\n\nfn main() {\n\tprintln(ma.probe() + mb.probe())\n}\n' > "$D/prog.v"
cat > "$D/ma/ma.v" <<'EOF'
module ma

@[export: 'gate_shared_sym']
fn gate_shared() int {
	return 1
}

pub fn probe() string {
	return gate_shared().str()
}
EOF
cat > "$D/mb/mb.v" <<'EOF'
module mb

pub fn probe() string {
	return 'b'
}
EOF
cd "$D"; export VCACHE="$D/.vcache"
"$V" -usecache -o pa prog.v >/dev/null 2>&1 || echo "dup A(S1) FAILED"
"$V" -usecache -d cfgb -o pb prog.v >/dev/null 2>&1 || echo "dup B(S1) FAILED"
cat > "$D/ma/ma.v" <<'EOF'
module ma

pub fn probe() string {
	return 'a'
}
EOF
cat > "$D/mb/mb.v" <<'EOF'
module mb

@[export: 'gate_shared_sym']
fn gate_shared() int {
	return 2
}

pub fn probe() string {
	return gate_shared().str()
}
EOF
"$V" -usecache -o pa2 prog.v >/dev/null 2>&1 || echo "dup A(S2) FAILED"
find "$VCACHE" -name '*.mb.o' -delete   # force on-demand fresh mb next to whatever ma state survives
"$V" -usecache -d cfgb -o pb2 prog.v > "$D/b2.log" 2>&1
# S2 sources: ma.probe()='a', mb.probe()=gate_shared().str()='2'
verdict "DUP-572-class" "a2" "$([ -x ./pb2 ] && ./pb2 2>/dev/null || echo LINK-FAILED)"
grep -iE 'duplicate symbol' "$D/b2.log" | head -2 || true

# ── KEY-CANON: one module, one key ───────────────────────────────────────────
note "KEY-CANON builtin spelling twins"
mkfix kc
cat > "$WORK/kc/mymod/mymod.v" <<'EOF'
module mymod

pub fn probe() string {
	return 'S1'
}
EOF
cd "$WORK/kc"; export VCACHE="$WORK/kc/.vcache"
"$V" -usecache -o p1 prog.v >/dev/null 2>&1 || echo "kc build FAILED"
nb=$(find "$VCACHE" -name '*.module.*builtin.o' | grep -cv 'closure' || true)
verdict "KEY-CANON-builtin" "1" "$nb"

# ── H11 LINK-SET completeness (I7) ───────────────────────────────────────────
# The invariant the original audit did not state: every module whose symbols the
# generated code REFERENCES must be inside a linked object or linked itself. Key
# soundness (I1-I6) says a served object matches its inputs; it says nothing
# about an object that is never served at all.
#
# Found by rolling -usecache onto the first NON-TEST binary build (#700 wave 2
# part ii, 2026-08-25). builtin.closure was assumed to be inside builtin.o by
# THREE mechanisms at once — cgen emitted its bodies header-only
# (gen/c/fn.v "Builtin function bodies are defined in builtin.o"),
# util.module_is_builtin() reported it builtin, and handle_usecache skipped
# linking its object — while the bodies existed in NO object: builtin.o never
# contained them, and closure.o omitted them because closure_init/
# closure_try_destroy are module-PRIVATE compiler hooks that an isolated module
# build eliminates as unused. Result: `ld: symbol(s) not found` on any
# -usecache build using a closure.
#
# It hid for as long as it did because every -usecache consumer to date was a
# `v test` build, and fn.v's header-only path carries a `!g.pref.is_test`
# escape hatch. So this probe MUST build an ordinary binary, not a test.
# Behavioral, like every other probe here: the program is RUN and its output
# compared, so no particular mechanism can satisfy it — only correctness.
note "H11 link-set completeness (bundled builtin submodules)"
rm -rf "$WORK/h11"; mkdir -p "$WORK/h11"
cat > "$WORK/h11/prog.v" <<'EOF'
fn make_adder(n int) fn (int) int {
	return fn [n] (x int) int { return x + n }
}

fn main() {
	add5 := make_adder(5)
	println(add5(37))
}
EOF
cd "$WORK/h11"; export VCACHE="$WORK/h11/.vcache"
"$V" -usecache -o p1 prog.v > "$WORK/h11/build.log" 2>&1 || echo "h11 build FAILED"
verdict "H11-closure-link-set" "42" "$([ -x ./p1 ] && ./p1 2>/dev/null || echo LINK-FAILED)"
# and the opposite failure mode: bundling inline must not ALSO link the object.
ndef=$(nm ./p1 2>/dev/null | grep -cE ' T _?builtin__closure__closure_init$' || true)
verdict "H11-no-duplicate-defs" "1" "$ndef"

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
# `mutations=` is on this line ON PURPOSE (#1337). Five of the six probes
# that reported RED in the run that filed the issue had never mutated their
# fixture at all, and nothing in the output said so. The count makes a
# degraded run visible AT THE VERDICT.
#
# FOUR is the whole roster of a normal pass, counted at the call sites, not
# guessed: the base `src-invalidate` edit, the h3 edit (ONE mutation feeding
# BOTH H3-configA and H3-configB), the h7 C-header edit, and the h4
# `A`->`B` edit. The fifth `mutate` in this file is inside the
# `--prove-red` branch and does not run in a normal pass, which is why the
# floor is skipped in that mode. Those four edits are what the five
# sed-dependent reds of #1337 came from; the sixth red, H1-cc-identity, was
# the `stat` half, not the `sed` half.
echo "vcache-soundness: sound=$PASS red=$RED mutations=$MUTATIONS elapsed=$((SECONDS-T0))s"
if [ "$MODE" != "--prove-red" ] && [ "$MUTATIONS" -lt 4 ]; then
  echo "vcache-soundness: FATAL - only $MUTATIONS of the 4 fixture mutations ran."
  echo "  A mutation probe that never mutated its fixture compares the"
  echo "  UNMUTATED program against the mutated expectation. Those verdicts are"
  echo "  about the harness, not the cache. Do not read them. (#1337)"
  exit 2
fi
if [ "$MODE" = "--prove-red" ]; then
  if [ $RED -ge 1 ]; then
    echo "vcache-soundness --prove-red: gate went RED on the injected hole — red side PROVEN"
    exit 0
  else
    echo "vcache-soundness --prove-red: gate FAILED to detect the injected hole"
    exit 1
  fi
fi
[ $RED -eq 0 ] || exit 1
exit 0
