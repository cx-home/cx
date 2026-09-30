#!/usr/bin/env bash
#
# scripts/lib/r22_profile_gate.sh — the R2.2 per-profile install
# verification and the asset staging it verifies, in ONE place.
#
# RULED: PGL-1 (#741, ledger/rulings_2026_08_22_profile_gate_lane.md).
# The gate loop below existed VERBATIM TWICE — scripts/release.sh phase 2
# (darwin) and the scripts/release_linux.sh in-container body — and ran
# ONLY inside a real cut: release.sh's copy sits in the `else` arm of the
# --dry-run test, so `release.sh --dry-run` printed a plan line and never
# executed a single assertion. A gate that exists twice can drift in one
# copy, and a gate whose first execution is the irreversible step is
# indistinguishable from an unmeasured one. Both callers now share this
# file, and scripts/release_profile_gate.sh runs it WITHOUT a cut.
#
# Source it, then call. Every function expects the CWD to be the repo root
# (the release flow runs from the root; the linux build runs from the container's
# /build copy, which carries scripts/ in its lean tar list).
#
#   r22_collect_platform_files <destdir>
#   r22_tar_platform           <srcdir> <pubdir_abs> <plat>
#   r22_stage_profiles         <pubdir> <plat>
#   r22_profile_gate           <pubdir> <plat> [label]
#   r22_profile_load           <dir> <prof> <vtar> [label] [build target dir]
#
# R22_EXPECT_HEADLINE (env, optional) — when set, r22_profile_gate additionally
# requires every staged binary's `cx -v` FIRST LINE to equal it exactly. A cut
# sets it to "cx vX.Y.Z" so an artifact built off the release tag cannot ship
# (#979, RULED: CO-4); the standalone pre-cut step leaves it unset, where the
# honest headline is the `-dev+` pre-release form.
#
# The staging keeps the tolerant `cp … 2>/dev/null || true` form it has
# always had for the dual .dylib/.so lib names: this landing changes NO
# caller's strictness. The linux build's own staging is deliberately NOT
# unified here (different make target, different lib set) — see PGL-1
# point 4 for why. The ruling's closing note named a lib-content hole that
# neither caller checked; r22_profile_load closes it (RULED: RLOAD-1, #1131).

# r22_vcx_target — where build-vcx actually lands its artifacts. RS-12's
# extraction moved vcx/ itself into the cx-core-code pin (deps/cx-core-code/vcx,
# populated by `make deps-sync`); this front door's own vcx/ stays only as an
# EXTRA V search-path entry (Makefile's CX_V_SEARCH). The release flow's staging
# had not been touched by the split (#1670 measurement) and copied from the
# pre-extraction path, so a real cut here found nothing to stage. Preferring
# the pinned location and falling back to the front-door path keeps this
# working before AND after any future de-extraction, without a second copy
# of the split's own migration logic.
r22_vcx_target() {
  if [ -d deps/cx-core-code/vcx/target ]; then
    echo deps/cx-core-code/vcx/target
  else
    echo vcx/target
  fi
}

# r22_include_dir — the same #1670 staleness, second instance: cx.h moved
# with vcx/ into the cx-core-code pin (deps/cx-core-code/include/cx.h).
r22_include_dir() {
  if [ -f deps/cx-core-code/include/cx.h ]; then
    echo deps/cx-core-code/include
  else
    echo include
  fi
}

# r22_collect_platform_files — the platform-profile payload: the binary,
# the shared lib under whichever extension this host produces, the public
# header, and the vendored re2 license (#573, statically linked).
r22_collect_platform_files() {
  local dest="$1" t
  t="$(r22_vcx_target)"
  cp "$t/cx" "$dest/"
  cp "$t/libcx.dylib" "$dest/" 2>/dev/null || true
  cp "$t/libcx.so"   "$dest/" 2>/dev/null || true
  cp "$(r22_include_dir)/cx.h" "$dest/"
  cp third_party/re2/LICENSE "$dest/LICENSE-re2.txt"
}

# r22_tar_platform — the FLAT, stable-named public artifact.
# releases/latest/download/<name> needs an exact version-LESS filename and
# the quickstart does `tar xz && mv cx`, so `cx` must sit at the tar ROOT,
# not under a <target>/ directory. pubdir must be ABSOLUTE: this subshell
# cds into srcdir first.
r22_tar_platform() {
  local srcdir="$1" pubdir="$2" plat="$3"
  ( cd "$srcdir" && tar czf "$pubdir/cx-${plat}.tar.gz" cx cx.h libcx.* LICENSE-re2.txt )
}

# r22_stage_profiles — the I4 (#651/#516, partition spec §4) lean profile
# tarballs, cx-<profile>-<plat>.tar.gz, which the installer resolves via
# CX_PROFILE=data|embed|cli. ONE binary name, profile-decided surface;
# the platform default above is what the bare install command fetches.
#   data  — cx (cannot-execute) + libcx-core + cx.h
#   embed — cx + the embed-shape libcx (Rings 0-1, no local-effect packs) + cx.h
#   cli   — cx only (the binary is the deliverable)
r22_stage_profiles() {
  local pubdir_rel="$1" plat="$2"
  local pubdir prof pdir t inc
  pubdir="$(cd "$pubdir_rel" && pwd)"
  t="$(r22_vcx_target)"; inc="$(r22_include_dir)"
  for prof in data embed cli; do
    pdir="$pubdir/_prof_$prof"; rm -rf "$pdir"; mkdir -p "$pdir"
    cp "$t/profiles/$prof/cx" "$pdir/"
    cp third_party/re2/LICENSE "$pdir/LICENSE-re2.txt"
    case "$prof" in
      data)
        cp "$inc/cx.h" "$pdir/"
        cp "$t/libcx-core.dylib" "$pdir/" 2>/dev/null || true
        cp "$t/libcx-core.so"   "$pdir/" 2>/dev/null || true ;;
      embed)
        cp "$inc/cx.h" "$pdir/"
        cp "$t/profiles/embed/libcx.dylib" "$pdir/" 2>/dev/null || true
        cp "$t/profiles/embed/libcx.so"   "$pdir/" 2>/dev/null || true ;;
    esac
    ( cd "$pdir" && tar czf "$pubdir/cx-${prof}-${plat}.tar.gz" ./* )
    rm -rf "$pdir"
  done
}

# r22_profile_payload — RULED: PGC-1 (#915). The gate used to assert only
# that a tarball extracts and that its `cx` reports the right profile. It
# never checked the LIBRARY and HEADER the profile exists to deliver, and
# the staging copies are deliberately tolerant (one host emits .dylib, the
# other .so), so a missing lib staged a lib-less tarball that the gate
# waved through — and the `data`/`embed` profiles ARE a library surface.
#
# Libs match by GLOB on either extension, so one implementation serves both
# callers. The globs are disjoint: `libcx.*` cannot match `libcx-core.dylib`,
# because what follows `libcx` there is `-`, not `.`.
#
# `cli` is checked by EXCLUSION as well as inclusion: "the binary is the
# deliverable" is a claim about what is ABSENT, and a staging bug that
# bundles a lib into `cli` breaks the profile's whole reason to exist.
r22_profile_payload() {
  local dir="$1" prof="$2" vtar="$3" label="${4:-}"
  local miss=() extra=()
  # PGC-1 AMENDED: glob presence WITHOUT compgen — devbox's nix bash is
  # built without programmable completion, so `compgen` is rc=127 there
  # and every payload entry reported MISSING while `ls` printed it two
  # lines below (found on this row's first full run under the runner's
  # own shell). Unquoted expansion + -e is portable: with no match the
  # pattern stays literal and -e fails.
  _r22_has() {
    local m
    for m in $dir/$1; do
      [ -e "$m" ] && return 0
    done
    return 1
  }
  _r22_need() { _r22_has "$1" || miss+=("$1"); }

  _r22_need 'cx'
  _r22_need 'LICENSE-re2.txt'
  case "$prof" in
    platform|embed) _r22_need 'cx.h'; _r22_need 'libcx.*' ;;
    data)           _r22_need 'cx.h'; _r22_need 'libcx-core.*' ;;
    cli)
      # nothing beyond cx + the license may be present
      local e
      for e in "$dir"/*; do
        case "$(basename "$e")" in
          cx|LICENSE-re2.txt) ;;
          *) extra+=("$(basename "$e")") ;;
        esac
      done ;;
  esac

  if [ ${#miss[@]} -ne 0 ] || [ ${#extra[@]} -ne 0 ]; then
    echo "RELEASE GATE FAILED (R2.2${label}): $vtar payload wrong for profile '$prof'" >&2
    [ ${#miss[@]}  -ne 0 ] && echo "  MISSING: ${miss[*]}" >&2
    [ ${#extra[@]} -ne 0 ] && echo "  UNEXPECTED (cli ships the binary only): ${extra[*]}" >&2
    echo "  tarball contains:" >&2
    ls -1 "$dir" | sed 's/^/    /' >&2
    exit 1
  fi
}

# r22_profile_load — RULED: RLOAD-1 (#1131; CR-3, CR-6). The payload check
# above proves a library is PRESENT; it never loaded one, so a libcx-core
# that could not parse json shipped green through this blocking gate (the
# #1126 class). Here every staged library is loaded through the extraction
# step's own probe (`extraction_gate_probe --artifact`), which answers the
# artifact's `cx_codec_inventory` and `cx_features` and verifies the mask
# against the export surface. The same probe binary then loads the build's
# own library — the one the staging copied: libcx for the platform tarball,
# libcx-core for data, profiles/embed/libcx for embed — and the two answers
# must be byte-identical. A library that cannot be loaded, a build library
# that is absent, a probe that is not built, or any difference refuses the
# cut, naming the file and the differing lines. `cli` ships no library.
#
# The probe is `R22_PROBE` when set, else <build target>/extraction_gate/probe
# (`make build-extraction-probe` builds it). The build target dir defaults to
# r22_vcx_target; the selftest (scripts/r22_profile_load_selftest.cx, run by
# `make release-flow-gate`) passes its own.
r22_profile_load() {
  local dir="$1" prof="$2" vtar="$3" label="${4:-}" t="${5:-}"
  [ -n "$t" ] || t="$(r22_vcx_target)"
  local probe="${R22_PROBE:-$t/extraction_gate/probe}"
  local pat sub lib base ref work rc n feat
  case "$prof" in
    platform) pat='libcx.*';      sub='' ;;
    embed)    pat='libcx.*';      sub='profiles/embed/' ;;
    data)     pat='libcx-core.*'; sub='' ;;
    *)        return 0 ;;
  esac
  if [ ! -x "$probe" ]; then
    echo "RELEASE GATE FAILED (R2.2${label}): the loading probe $probe is not built (make build-extraction-probe) — no staged library of $vtar was loaded" >&2
    exit 1
  fi
  work="$(mktemp -d)"
  for lib in $dir/$pat; do
    [ -e "$lib" ] || continue
    base="$(basename "$lib")"
    ref="$t/$sub$base"
    if [ ! -e "$ref" ]; then
      rm -rf "$work"
      echo "RELEASE GATE FAILED (R2.2${label}): $vtar stages $base but the build's own $ref is absent — nothing to compare it with" >&2
      exit 1
    fi
    rc=0; "$probe" --artifact "$lib" > "$work/staged" 2> "$work/staged.err" || rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "RELEASE GATE FAILED (R2.2${label}): $vtar — the probe refused the staged $base (exit $rc): it cannot be loaded, lacks an entry, or its cx_features disagrees with its own exports" >&2
      sed 's/^/    /' "$work/staged.err" >&2
      rm -rf "$work"
      exit 1
    fi
    rc=0; "$probe" --artifact "$ref" > "$work/build" 2> "$work/build.err" || rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "RELEASE GATE FAILED (R2.2${label}): the probe refused the build's own $ref (exit $rc): it cannot be loaded, lacks an entry, or its cx_features disagrees with its own exports" >&2
      sed 's/^/    /' "$work/build.err" >&2
      rm -rf "$work"
      exit 1
    fi
    if ! cmp -s "$work/build" "$work/staged"; then
      echo "RELEASE GATE FAILED (R2.2${label}): $vtar — the staged $base answers cx_codec_inventory / cx_features differently from the build's own $ref" >&2
      echo "  (< the build's own, > the staged library)" >&2
      # diff answers 1 for a difference; under a caller's pipefail + errexit
      # (release_profile_gate.sh) that status must not end the shell before
      # the scratch dir is removed and the refusal's own exit is taken.
      diff "$work/build" "$work/staged" | sed 's/^/    /' >&2 || true
      rm -rf "$work"
      exit 1
    fi
    n="$(sed -n '/#cx_codec_inventory$/,/^»»» /p' "$work/staged" | grep -c "$(printf '	')" || true)"
    feat="$(sed -n '/#cx_features$/{n;n;p;}' "$work/staged")"
    echo "   R2.2${label} load: $(basename "$vtar") $base — $n codecs, cx_features $feat — identical to the build's own $ref"
  done
  rm -rf "$work"
}

# r22_profile_gate — R2.2 (#651/#516 remediation register, ruled (a) BY
# OWNER 2026-08-09): BLOCKING per-profile install verification. The cut
# does not proceed unless EVERY staged tarball (default platform + the
# three lean profiles) extracts the way the installer will extract it,
# carries an executable `cx` at the tar root, and reports the expected
# profile line. This is the mechanical closure of the I4 exit-gate
# deferral (audit F-8): "assets ship at the next cut" enforced AT the cut.
#
# `label` suffixes the failure text so a caller names itself — "" for the
# darwin cut, "/linux" in the container, "/precut" for the standalone
# step. Failure calls `exit 1`, exactly as both original copies did: in
# the release flow's package act, aborting the cut before the phase-3 push, and in the
# container it fails the container, which fails release_linux.sh, which
# fails the release flow.
r22_profile_gate() {
  local pubdir="$1" plat="$2" label="${3:-}"
  local prof vtar vdir probe_rc probe_out probe_head
  for prof in platform data embed cli; do
    case "$prof" in
      platform) vtar="$pubdir/cx-${plat}.tar.gz" ;;
      *)        vtar="$pubdir/cx-${prof}-${plat}.tar.gz" ;;
    esac
    vdir="$(mktemp -d)"
    tar xzf "$vtar" -C "$vdir" || { echo "RELEASE GATE FAILED (R2.2${label}): $vtar does not extract" >&2; exit 1; }
    [ -x "$vdir/cx" ] || { echo "RELEASE GATE FAILED (R2.2${label}): $vtar carries no executable cx at the tar root" >&2; exit 1; }
    # AMENDED: PGL-1a — capture ONCE, then match the captured text.
    # The original probe was `cx -v | grep -q …` and, on failure, re-ran
    # `cx -v` to print diagnostics. That is undiagnosable by construction:
    # it discards the probe's exit status and stderr, and the second
    # invocation can succeed where the first failed, so a real failure
    # printed a "does not report" verdict directly above the very line it
    # claimed was missing. One exec, no pipeline, and the failure text
    # carries the rc and the actual bytes.
    probe_rc=0
    probe_out="$("$vdir/cx" -v 2>&1)" || probe_rc=$?
    case "$probe_out" in
      *"profile  $prof"*) ;;
      *)
        echo "RELEASE GATE FAILED (R2.2${label}): $vtar cx -v does not report 'profile  $prof'" >&2
        echo "  probe exit status: $probe_rc" >&2
        echo "  probe output (${#probe_out} bytes):" >&2
        printf '%s\n' "$probe_out" | sed 's/^/    /' >&2
        exit 1 ;;
    esac
    # Provenance headline (#979, RULED: CO-4). A cut sets R22_EXPECT_HEADLINE
    # to the release headline ("cx vX.Y.Z"); the standalone pre-cut step leaves
    # it unset, because outside a cut the honest headline IS the `-dev+` one
    # and demanding otherwise would make the step un-runnable.
    #
    # This is the assertion that catches a profile or platform artifact built
    # off the tag — the failure mode the phase ordering (#979) exists to
    # prevent, checked on the STAGED TARBALL rather than on the build inputs,
    # so it holds for the linux build's containers too.
    if [ -n "${R22_EXPECT_HEADLINE:-}" ]; then
      probe_head="$(printf '%s\n' "$probe_out" | head -1)"
      if [ "$probe_head" != "$R22_EXPECT_HEADLINE" ]; then
        echo "RELEASE GATE FAILED (R2.2${label}): $vtar provenance headline is wrong" >&2
        echo "  expected: $R22_EXPECT_HEADLINE" >&2
        echo "  got:      $probe_head" >&2
        echo "  A '-dev+' headline means this artifact was NOT built from a clean" >&2
        echo "  checkout of the annotated release tag (RULED: CO-4, #979)." >&2
        exit 1
      fi
    fi
    r22_profile_payload "$vdir" "$prof" "$vtar" "$label"
    r22_profile_load "$vdir" "$prof" "$vtar" "$label"
    rm -rf "$vdir"
  done
}
