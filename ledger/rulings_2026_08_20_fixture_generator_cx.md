# Rulings 2026-08-20 — the #787 UX fixture generator moves to CX (#856)

## GEN-1 — option 1: rewrite in CX; the Python generator is DELETED in the same commit

**Status:** RULED (owner, 2026-08-20: *take option 1*).

### What #856 asked

Standing language policy is CX-first for tooling; anything non-CX needs a
why-not-CX issue. #856 is that issue for `design/787/tools/gen_ux_fixtures.py`
(1,263 lines), which generates the three `cx-x/ux` conformance suites by
running each snippet against the shipped binary and capturing what it
actually printed, rather than by hand-authoring goldens. The issue names two
options and states its preference:

> 1. **Rewrite in CX.** Preferred. Removes the exception and puts the
>    generator on the same footing as everything else it emits.
> 2. **Record why not.** If there is a real gap — subprocess capture, or
>    writing a file the run does not own — name it here and the exception
>    stands until that gap closes.

### The named gap is CLOSED

#856 named exactly one reason the generator was Python:

> It is Python for one reason: it shells out to `vcx/target/cx` per case and
> assembles `.cxd` text around the captured stdout.

Both halves are now first-class CX surface, so option 2's escape hatch no
longer has a gap to point at:

| Half of the gap | The CX surface that closes it | Grant |
|---|---|---|
| "shells out to `vcx/target/cx` per case" | `[$process:run $argv cwd= timeout-ms= capture=:both]` → `[proc-result stdout= stderr= exit-code= …]` (`stdlib/process.cx`, `spec/03-approved/std-lib/process.md` §2.3/§3.1). argv-array only; no shell string. | `subprocess` |
| "writing a file the run does not own" | `[$io:write-file $path $content]` (`stdlib/io.cx`) | `write` |

Reading the snippet corpus and writing the per-case scratch file are
`read` / `write`; resolving the repo root from the environment is `env`.
The generator therefore runs as

```
vcx/target/cx design/787/tools/gen_ux_fixtures.cx \
  --allow-read --allow-write --allow-subprocess --allow-env
```

and its own header states those four grants and why each is needed — the
same discipline every other CX tool in the tree carries.

### Cutover-first

Per the house rule (no dual-accept), the Python generator is **deleted in
the same commit** that lands the CX one. There is no period in which two
generators claim the same three fixtures.

### The acceptance test is byte-identity

The CX generator regenerates `conformance/stdlib/ux.cxd`,
`conformance/stdlib/ux-web.cxd` and `conformance/stdlib/ux-tui.cxd`, and
those files `diff` clean against the committed fixtures. A port that
"improves" a golden while claiming to be a port is how a suite quietly
stops pinning what it pinned. If the CX generator and the Python one
disagree, the disagreement is investigated and the wrong side is named —
never blessed by re-recording.

---

## GEN-1a — the Python generator was already STALE; the port RECOVERS the 14 orphaned cases

**Status:** RULED as a finding of fact, measured on this head before any
port work.

The committed fixtures carry **119** cases. The Python generator defines
**105**. The case-id sequences agree exactly for the first 105; the
difference is 14 cases APPENDED to the end of two suites and never
back-written into the generator:

| Suite | Generator | Committed | Orphaned (appended, generator-unknown) |
|---|---|---|---|
| `ux.cxd` | 66 | 76 | `ux-105-layout-move-untouched`, `ux-106-layout-address-miss`, `ux-107-layout-place-collision-and-unknown-component`, `ux-108-layout-remove-takes-its-subtree`, `ux-109-layout-lensed-editor`, `ux-110-layout-wrap-and-validity`, `ux-111-layout-inverse-pairs`, `ux-112-layout-set-hint-surface-level`, `ux-113-layout-batch-atomic`, `ux-114-set-param-content-surface` |
| `ux-web.cxd` | 20 | 24 | `web-021-edit-mode-stamps-the-placed-target`, `web-022-edit-mode-claim-stamp-and-normal-mode-absence`, `web-023-region-listens-and-refetches`, `web-024-arranged-region-and-spans` |
| `ux-tui.cxd` | 19 | 19 | — |

This is exactly the drift #856's "generated, not hand-authored" discipline
exists to prevent: running the *committed* Python generator today would
DELETE 14 live conformance cases from the suites. The generator had stopped
being the source of the fixtures.

**The ruling:** the CX port is the generator's source-of-truth restoration.
It carries all 119 cases — the 105 ported from the Python source, and the
14 recovered from the committed fixtures they were appended to (id, level,
tags, title, doc and in-code read back out of the fixture text they already
live in). Byte-identity is therefore measured against the full committed
suites, not against what the stale Python generator happens to emit.

Recovering an orphaned case is not authoring a golden: every `out-text` in
the regenerated suites — the recovered 14 included — is re-derived by
RUNNING the snippet against the shipped binary, which is the suite's own
rule and the only thing that makes these files goldens rather than
opinions.

---

## GEN-1b — the port must RE-CREATE the Python generator's fail-loud behavior

**Status:** RULED as a port requirement, measured.

Python's `subprocess.run` failing is an exception: the generator dies and the
committed fixtures are untouched. CX contains an err raised inside a `[?for]`
yield-body as a *value* (R5.13's SEQUENCE-items rule). The naive port therefore
does something Python could not:

```
$ cx design/787/tools/gen_ux_fixtures.cx --allow-read --allow-write --allow-env
wrote conformance/stdlib/ux.cxd (76 cases)          ← exit 0, and a LIE
wrote conformance/stdlib/ux-web.cxd (24 cases)
wrote conformance/stdlib/ux-tui.cxd (19 cases)
$ git diff --stat conformance/stdlib/
 3 files changed, 3104 deletions(-)                 ← all 119 cases GONE
```

Without `subprocess` every `[$process:run]` returns `CXER0271`, every
`[$strings:join]` over the resulting err sequence yields `""`, and the tool
cheerfully overwrites three good suites with three headers and a `]`. That is
the silent-acceptance class this corpus exists to catch, committed by the
corpus's own generator.

**The ruling:** the CX generator [?match]es EVERY effect point — the scratch
write, the spawn, the suite write — and routes any err to a `die` that prints
the effect, the code and the missing grant, then exits 3. A per-suite
postcondition (`blocks == cases`) closes anything the [?match]es miss, so a
suite is never written short. Measured, this head:

| Invocation | Result |
|---|---|
| all four grants | exit 0, three suites written, `git diff` clean |
| no `--allow-subprocess` | exit 3, names the oracle + `CXER0271` + the grant, fixtures untouched |
| no `--allow-write` | exit 3, fixtures untouched |
| no `--allow-env` / no `--allow-read` | `CXER0271` at the first effect, exit 1, fixtures untouched |
| `CX_BIN` missing | exit 2, "build it first", fixtures untouched |

This is not a behavior change to the emitted goldens — byte-identity holds
either way. It is the port preserving a property the source language gave for
free and the target language does not.

---

## GEN-1c — the acceptance, measured

The CX generator regenerated all three suites and `git diff` reported **zero
difference** across all 119 cases — under the `-gc e` dev binary AND under the
`-prod` binary the gate lane builds, and from a foreign cwd via
`CX_REPO_ROOT`. The Python generator was run first as a control on the same
head: it reproduced its 105 cases byte-for-byte (zero `<` lines in the diff)
and was missing exactly the 14 orphans of GEN-1a — which is what proved the
drift was the generator's and not the binary's.

---

## Scope

Tooling only. No `spec/03-approved` text is touched by this work, so no
spec token rides it; if that changes, the edit carries `RULED: GEN-1`.
