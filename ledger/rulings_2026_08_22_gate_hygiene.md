# Rulings 2026-08-22 — R2.2 contents + the SIGPIPE pipe class (#915, #916)

**Status:** AUTHORIZED by the owner ("get these fixed", 2026-08-22) against
the two issues filed out of the PGL-1/PGL-1a pass. Recorded BEFORE the work
per R6.1. Design calls are mine under the standing letter-recommendation
grant, reasoning stated so any one can be overturned alone.

## PGC-1 — the gate checks the payload a profile PROMISES (#915)

**The finding.** R2.2 asserts three things per staged tarball: it extracts,
it carries an executable `cx` at the tar root, and `cx -v` reports the
expected profile. It never checks the LIBRARY and HEADER the profile
exists to deliver. Combined with darwin's tolerant staging copies
(`cp … 2>/dev/null || true`, which exist because one host emits `.dylib`
and the other `.so`), a missing or misnamed lib stages a lib-less tarball,
the gate passes it, and the first person to find out is a user linking
against a library that is not there. The `data` and `embed` profiles ARE a
library surface — the one thing the gate did not look at.

**The rule.**
1. The gate asserts each profile's full expected payload after extraction:
   * `platform` — `cx`, `cx.h`, some `libcx.*`, `LICENSE-re2.txt`
   * `data`     — `cx`, `cx.h`, some `libcx-core.*`, `LICENSE-re2.txt`
   * `embed`    — `cx`, `cx.h`, some `libcx.*`, `LICENSE-re2.txt`
   * `cli`      — `cx`, `LICENSE-re2.txt`, and **nothing else**
2. Lib names are matched by GLOB on either extension (`libcx.*`,
   `libcx-core.*`), so ONE implementation serves both lanes. The globs are
   disjoint: `libcx.*` does not match `libcx-core.dylib`, because what
   follows `libcx` there is `-`, not `.`.
3. `cli` gets an EXCLUSION assertion, not merely an inclusion one: "the
   binary is the deliverable" is a claim about what is ABSENT, and a
   staging bug that accidentally bundles a lib into `cli` silently breaks
   the profile's whole reason to exist.
4. **The gate is the single enforcement point; staging stays tolerant.**
   The dual-extension reality has to be absorbed somewhere, and absorbing
   it in one strict gate beats duplicating per-host strictness into two
   staging paths. A missing lib now FAILS THE CUT loudly at the gate
   instead of shipping quietly — which is the outcome both options wanted.
   Rejected: making staging strict per-host-extension as well. That is
   double enforcement, and it puts the check in the lane (linux) that was
   never the problem while leaving the gate — the shared code — still blind.

## SPG-1 — the SIGPIPE pipe class becomes a gate (#916)

**The finding.** `external_command | grep -q PATTERN` inside a `pipefail`
script fires FALSE failures: `grep -q` exits on first match, the producer
takes SIGPIPE and exits 141, and pipefail promotes that to the pipeline's
status. Timing-dependent, so it hides while the producer is fast and
appears when it is slow. Two independent instances existed — one
documented in a comment in `scripts/test_playground_smoke.sh`, one sitting
inside the BLOCKING R2.2 release gate (PGL-1a). Tribal knowledge in one
file's comment did not stop the second.

**The rule.**
1. A gate, `check-pipefail-pipes`, joins the `check-*` family and
   TEST_TARGETS: in any shell script that sets `pipefail`, a pipeline whose
   right side is `grep -q`/`-qE`/`-qi` and whose left side is an EXTERNAL
   command is a failure. `echo`/`printf` producers pass — a builtin writing
   a small string completes before `grep` can exit, so nothing receives
   SIGPIPE. Comment lines are skipped; a `|` ending a line is followed to
   the continuation so a wrapped pipeline cannot hide.
2. The diagnostic NAMES THE TWO SAFE FORMS, because a gate that only says
   "no" teaches nothing: a here-string (`grep -q P <<< "$out"`, fed by the
   shell, no upstream process) or capture-once-then-match.
3. **Zero allowlist entries at landing.** The two real remaining sites are
   FIXED in the same landing, not annotated:
   `tools/verify-doc-blocks.sh` (`head -n 1 … | grep -q`) and
   `bench/xap/run.sh` (`curl -s … | grep -q` in a readiness probe, where a
   false miss makes the wait flaky). An escape annotation exists for a site
   that genuinely wants the pipe, but the gate lands green with none used —
   the same standard EDL-1a set for the examples gate.
4. Scope is repo-wide over `*.sh` excluding `third_party/`. The sweep that
   informed this ruling found 45 pipefail scripts, 4 matches, 2 of them
   comment lines and 2 real.
