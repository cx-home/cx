module testenv

import os

// testenv — shared environment-prerequisite support for the vcx/tests lanes
// (#318). A bare out-of-tree checkout must never read as a wall of phantom
// regressions: a lane whose prerequisite is absent SELF-SKIPS with a named
// reason instead of failing, and every such skip lands in a ledger the make
// gate prints loudly after the run. The ledger exists because plain `v test`
// suppresses ALL output of a passing test binary — an eprintln alone is
// invisible there (`v -stats test` shows the SKIP lines inline).
//
// The ledger is the DIRECTORY vcx/target/test-skips.d, next to the built
// binary — one file per writing lane, named after that lane, which the make
// digest merges at read time (#1013). It was a single shared append-target
// file until a lost-update race showed up under `make -j`: the writers are
// independent processes and make targets, and the truncation that scoped the
// ledger to one run was inside ONE writer's recipe, so a skip line that landed
// before that truncation was erased from the digest. A writer that owns its
// own file and truncates only that file cannot lose another writer's line, and
// cannot be raced by one. The reset moved to the `skip-ledger-reset` target,
// which every writing lane names as a prerequisite so it is ordered before all
// of them by the dependency graph. See the CX_SKIP_DIR block in the top-level
// Makefile for the full argument.
//
// The directory is resolved relative to THIS source file — never the invoking
// CWD — so lanes behave identically from any directory.

// vcx_target_dir resolves <repo>/vcx/target CWD-independently (@VMODROOT is
// the directory of vcx/v.mod, baked in at compile time).
fn vcx_target_dir() string {
	return os.join_path(@VMODROOT, 'target')
}

// skip_ledger_dir resolves the per-lane skip-ledger directory. Kept in step
// with CX_SKIP_DIR in the top-level Makefile.
fn skip_ledger_dir() string {
	return os.join_path(vcx_target_dir(), 'test-skips.d')
}

// skip_lane ends the CALLING LANE as skipped-with-a-named-reason: the reason
// is printed, written to this lane's own ledger file, and the whole test
// binary exits 0 — counted separately by the gate digest, never
// failing-as-regression (#318).
// Reserve it for absent environment prerequisites that invalidate the whole
// lane (a missing built binary, a required local service); per-case transient
// skips inside a lane stay the existing `eprintln('SKIP …'); return` idiom.
//
// The write TRUNCATES this lane's file rather than appending (#1013). The file
// is named after the lane binary, so no other writer targets it and there is
// no interleaving to preserve; truncating also means a lane re-run by the
// gate's classified serial retry records its skip once instead of twice.
pub fn skip_lane(reason string) {
	lane := os.file_name(os.executable())
	line := 'SKIP ${lane}: ${reason}'
	eprintln(line)
	dir := skip_ledger_dir()
	os.mkdir_all(dir) or {}
	os.write_file(os.join_path(dir, lane), line + '\n') or { exit(0) }
	exit(0)
}

// cx_bin resolves the repo-built cx CLI (vcx/target/cx) relative to this
// source tree — never the CWD, which broke every out-of-tree invocation —
// and self-skips the calling lane with a named reason when the binary has
// not been built yet (the #318 bare-checkout prerequisite: 37 of the 45
// http/net lanes exec this binary and used to panic-fail without it).
pub fn cx_bin() string {
	abs := os.join_path(vcx_target_dir(), 'cx')
	if !os.is_file(abs) {
		skip_lane('missing prerequisite: vcx/target/cx not built — run `make build-vcx-dev` first (#318)')
	}
	return abs
}
