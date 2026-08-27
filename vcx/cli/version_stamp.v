module cli

import cx

// version_stamp.v — the `cx --version` HEADLINE, and only the headline.
//
// #979, RULED: CO-4. The first line of `cx --version` is the provenance claim
// downstream BOMs and installers read. It used to print `cx v<VERSION>`
// unconditionally, which made it a claim about the VERSION FILE, not about the
// artifact: the version file flips to the next version at the start of a
// line's development, so every build between two cuts wore the coming
// release's name and nothing in the headline said otherwise.
//
// Release-ness is now DERIVED from git state at build time — HEAD exactly at
// the annotated tag matching the repo-root VERSION *and* a clean tree — and
// handed to the binary as the `cx_release` build define (vcx/Makefile,
// CX_RELEASE). There is no second hand-maintained value; VERSION + git decide.
//
// Two states, two shapes:
//
//   release  →  cx vX.Y.Z
//   dev      →  cx vX.Y.Z-dev+3ed9ade5           (or …+3ed9ade5-dirty)
//
// `-dev+<commit>` is not decoration. It is a semver PRE-RELEASE of VERSION,
// which is precisely what unreleased source is, so it ORDERS BEFORE the
// release it will become and a comparison against a shipped version answers
// correctly. The build metadata carries the commit stamp verbatim — including
// #666's `-dirty` marker, since a stamp that names a commit which does not
// reproduce the artifact is unfalsifiable, and that is exactly as true in the
// headline as it is on the `commit` line.
//
// The remaining lines of `cx --version` (profile / commit / built / gc /
// V fork / engines / features) are unchanged and stay with their callers.
//
// This lives in `cli` (Ring 0) because BOTH binaries print the headline —
// vcx/cmd (the monolith) and vcx/cmd_data (the data profile) — and a
// provenance claim that two artifacts spell differently is not a claim.

// The `cx_release` value naming a build that IS the release its VERSION names —
// and the predicate over it — moved DOWN to Ring 0 with #984
// (`cx.release_state_release` / `cx.is_release_build`). The C ABI's
// `cx_version()` now asks the same question, and a predicate the library and
// the CLI could answer differently is not a predicate. `cli` kept no alias:
// one name, in the ring both surfaces can reach.

// version_headline renders the first line of `cx --version` / `cx version`.
//
// `version` is the repo-root VERSION (the `cx_version` define), `release_state`
// the `cx_release` define, `commit` the `cx_commit` define. Pure — no build
// gates, no environment — so both define values are directly testable.
//
// The semver half — bare `X.Y.Z` for a release, `X.Y.Z-dev` for everything
// else — is `cx.version_stamp`, shared with the C ABI (#984) so libcx and the
// cx binary cannot disagree about whether a build is the release its VERSION
// names. The headline adds the two things that are the CLI's alone: the `cx v`
// prefix, and the `+<commit>` build metadata, which the library does not carry
// (a docs-only commit must not change a libcx artifact's stamp; see
// cx.version_stamp).
pub fn version_headline(version string, release_state string, commit string) string {
	stamp := cx.version_stamp(version, release_state)
	if cx.is_release_build(release_state) {
		return 'cx v${stamp}'
	}
	c := if commit.trim_space() == '' { 'unknown' } else { commit }
	return 'cx v${stamp}+${c}'
}
