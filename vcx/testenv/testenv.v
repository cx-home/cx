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
// The ledger is vcx/target/test-skips.log, next to the built binary. It is
// resolved relative to THIS source file — never the invoking CWD — so lanes
// behave identically from any directory. `make test-vcx-suite` truncates it
// before the run and prints a skipped-with-reason digest after.

// vcx_target_dir resolves <repo>/vcx/target CWD-independently (@VMODROOT is
// the directory of vcx/v.mod, baked in at compile time).
fn vcx_target_dir() string {
	return os.join_path(@VMODROOT, 'target')
}

// skip_lane ends the CALLING LANE as skipped-with-a-named-reason: the reason
// is printed, appended to the ledger, and the whole test binary exits 0 —
// counted separately by the gate digest, never failing-as-regression (#318).
// Reserve it for absent environment prerequisites that invalidate the whole
// lane (a missing built binary, a required local service); per-case transient
// skips inside a lane stay the existing `eprintln('SKIP …'); return` idiom.
pub fn skip_lane(reason string) {
	lane := os.file_name(os.executable())
	line := 'SKIP ${lane}: ${reason}'
	eprintln(line)
	dir := vcx_target_dir()
	os.mkdir_all(dir) or {}
	mut f := os.open_append(os.join_path(dir, 'test-skips.log')) or { exit(0) }
	f.writeln(line) or {}
	f.close()
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
