# Integrator decisions 2026-09-29 — Letters 111 to 114 and 117 to 118, taken as delegated: four spec-silent stdlib defects the Ring-1 batch left out by name, and the two xap sentences the feature-dispatch round flagged

**Status: RULED BY DELEGATION (the owner, 2026-09-29 ~03:5xZ, in session: "I will only review
doc/playground final output. you have your assignment." — every open letter outside the docs and
the playground is the integrator's to take at its recommendation; the six letters were posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 23:2xZ with their options and
consequences, beside Letters 115 and 116, which keep or change a ruled spec sentence and stay the
owner's; the owner may reverse any of them on reading). FIX-1, RS-38, CXF-8, THRU-4, the Ring-1
batch of 2026-09-29 (`_gate_evidence/pipeline_batch0929/RESULTS.md`).**

## The owner's words, verbatim

"I will only review doc/playground final output. you have your assignment."

## HTTPTO-1 — a non-duration `timeout=` is refused by name, and `duration_to_ns` is bounded for every caller (L111 = (a), delegated; #1702)

`http-client` panics on an int `timeout=` opt: `duration_to_ns` in the evaluator reads past the
digits of `"10"`, and http.md §3.1 does not say how a non-duration timeout is refused. Taken: a
`timeout=` that is not a duration is refused by name, CXER0100 — the core's refusal for an opt of
the wrong type — with the bound in `duration_to_ns` fixed for every caller that reads the same
code (`similar`, `sched`), a fixture-backed sentence in http.md §3.1 naming the case. The fix
touches the evaluator, so it lands after BARE-1 and LITER-1 merge. Rejected: reading an int as
milliseconds (two spellings of one thing, the int ambiguous on its face); reading it as
nanoseconds by time.md's "duration refines int" (a 10-nanosecond timeout by accident — the silent
wrong answer CXF-8 files).

## DURSC-1 — `time:parse-duration` and `time:duration-*` answer the duration scalar (L112 = (a), delegated; #1681)

They answer a plain int today, and time.md §1 ("`duration` refines `int`") and §3.11 do not say
which. Taken: they answer the typed duration, rendered as code.md R2 renders one (`100ms`), with a
fixture-backed sentence in time.md §3.11; arithmetic is unchanged because a duration refines int,
so every `[+ $d 1]` still works. Rejected: keeping the int and documenting it — `100ms` and
`[$time:duration-ms 100]` would print differently for one meaning, the two-conventions class
SINCE-1 (L90) refused.

## TMPDIR-1 — `system-temp-dir` honours `TMPDIR` (L113 = (a), delegated; #1649)

`io:temp-dir`, `temp-file` and `system-temp-dir` ignore `TMPDIR` on macOS because V hard-codes the
path, and io.md §3.8 says only that `system-temp-dir` "returns the OS temp path". Taken:
`system-temp-dir` honours `TMPDIR` when it is set and answers the platform default otherwise — the
runtime's own read, not a program effect, said so in io.md §3.8 with its fixture. This is the
POSIX convention, and it is what lets a runner give each run its own scratch root, so the leak
class of #1511 becomes containable. Rejected: keeping V's path and documenting it — every tool
that sets `TMPDIR` ignored in silence.

## SPAWNF-1 — an exec-time ENOENT is the same refusal a pre-spawn one is, as a round of its own (L114 = (a), delegated; #1630)

`process:run` and `process:spawn` answer `exit-code=1 stdout=''` when the executable does not
exist at exec time; process.md's reading of CXER4000 against CXER4001 for that case was not made
by D43a. Taken: an exec-time not-found is the refusal value CXER4000, the same word a pre-spawn
not-found already carries, fixture first; it is scheduled as a round of its own after the cut,
because the posix_spawn path with process groups and the §3.1.1/§3.2 fd dispositions is not an
hour's fix (FIX-1's small-defect clause does not reach it). Rejected: keeping the shell's
convention — a missing binary and a program that ran and failed would be one answer.

## PKGFL-1 — a package's module file is `<package-name>.cx`, in the spec and on the pages (L117 = (a), delegated)

distribution §1.2 and three documentation pages say the module file is `<feature-name>.cx`; the
host reads `<package-name>.cx`, and FDISP-1 — the feature→package map built at boot — makes the
two names differ for any package carrying more than one feature. Taken: the spec and the pages say
`<package-name>.cx`: the package is the unit the host loads and its features are the verbs it
dispatches, so one package is one file; one fixture-backed sentence in §1.2 and the three pages
regenerated, as a small xap round after FDISP-1 merges. Rejected: the code reading
`<feature-name>.cx`, one file per feature — a package's features split across files while the map
treats them as one package, so the boot refusal list and the market's package row would name a
file that is not there.

## PKGIMP-1 — a `pkg:` import exposes every feature of the package (L118 = (a), delegated)

A `pkg:` import of a package carrying several features exposes only its first feature, while the
host dispatches all of them. Taken: the import exposes every feature, its verbs named
`<feature>/<verb>` — the projection FDISP-1 already fixed for one feature — fixture first, in the
same small xap round as PKGFL-1. Rejected: first feature only, documented — a two-feature
package (KIT4-2's shape) importable by half.
