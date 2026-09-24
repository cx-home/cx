module main

import code

// platform_verbs_d_cx_platform.v — the PLATFORM-profile verb surface (I4,
// #651/#516, spec §4): the store/fabric daemon + operator verbs, compiled
// ONLY into the platform-profile cx (-d cx_platform). The blank-alias
// xap import ALSO lives here: importing xap — the composer's module since
// xap's split (RULED: RS-24, D31a) — runs its init(), registering every
// Ring-2 pack into the Ring-1 registries — so
// a cx built WITHOUT -d cx_platform has no Ring-2 code in the artifact
// and every ring-2 name refuses as an undefined callable (the §4
// profile-by-construction rule).
//
// D73a (RULED: D73a, D71a, RS-18): a product's verbs reach this table through
// code's CLI verb registry (vcx/code/cli_verb_registry.v), registered from the
// product's own init() — cx-platform-store registers store-serve,
// store-health, store-rotate-kek and store-mint-principal, and
// cx-platform-fabric registers fabric-serve (K3's extraction moved
// fabric_serve_d_cx_platform.v through this same hook) — so this file names
// no product's function.
import xap as _

// platform_subcommands returns the platform-only SubcommandSpec entries,
// appended to the shared registry by build_subcommands (cmd/main.v), in the
// order of absent_platform_verbs — the one list of platform verb words, which
// a profile without the platform reads to refuse them by name — so the
// `cx --help` catalog does not follow registration order. A registered verb
// that list does not name is refused here, by name: in a profile without the
// platform its word would otherwise read as a FILE (the #426 lesson).
fn platform_subcommands() []SubcommandSpec {
	mut by_name := map[string]SubcommandSpec{}
	for v in code.cli_verbs() {
		if v.name !in absent_platform_verbs {
			panic('cx: verb `${v.name}` is registered but absent_platform_verbs does not name it — a profile without the platform would read the word as a file (RULED: D73a)')
		}
		if v.name in by_name {
			panic('cx: verb `${v.name}` is registered twice (RULED: D73a)')
		}
		by_name[v.name] = SubcommandSpec{
			name:    v.name
			summary: v.summary
			help:    v.help
			run:     v.run
		}
	}
	mut out := []SubcommandSpec{}
	for w in absent_platform_verbs {
		if s := by_name[w] {
			out << s
		}
	}
	return out
}
