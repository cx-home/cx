# RULED: 1074-a — `run`/`spawn` file dispositions are charged to `write` (#1074)

**Date:** 2026-09-01
**Ruled by:** owner, letter **(a)**
**Status:** RULED, recorded BEFORE the work.

## The defect

`[$process:run … capture={stdout: "<path>"}]` opens the target
`O_CREAT|O_TRUNC` in the PARENT process, before the fork (§4.9). The open
is charged to no capability, so:

- `--allow-subprocess` ALONE creates and truncates an arbitrary path.
- The truncation happens even when the spawn subsequently fails, because
  the open precedes it. A bogus command still empties the file.
- It still happens inside `[?with-caps [deny write] …]`.

The control in the same runs: `[$io:write-file]` correctly raises
CXER0271 in both cases. So one line refuses and the line beside it
truncates, same file, same scope. `spawn`'s stdio disposition behaves
identically (pre-existing; #1023 widened the pre-existing `spawn`
behavior to `run` and HOLDS).

## The ruling

**(a) The parent-side disposition open is charged to the `write`
capability.** A denied write refuses PRE-SPAWN with CXER0271, in the same
position the existing CXER4001 unopenable-target refusal already occupies.
`capture={stdout: path}` therefore requires BOTH `subprocess` and `write`.

**(b) was refused**: spec that subprocess subsumes disposition writes, and
pin the `with-caps` behavior as deliberate.

## Why (a), against the mitigating argument

The argument for (b) is that a subprocess grant already implies arbitrary
writes BY PROXY — the child can write files — so the marginal authority is
small. That argument is about the CHILD's authority. The truncation here
is CX's own syscall, in CX's own process, on a path the CX program named,
and it destroys data whether or not the child ever runs.

Two further reasons, both about the long-term shape of the surface:

1. `[?with-caps [deny write] …]` must mean what it says. A sub-computation
   run with a reduced set that can still empty any reachable file defeats
   the construct's stated purpose.
2. Capability reasoning must stay LOCAL. If subprocess silently subsumes
   write, then answering "who can truncate a file?" requires transitively
   including every subprocess grant. One capability partially implying
   another is exactly the non-orthogonality that is expensive to undo, and
   orthogonality is a standing CX surface objective.

## Cost of (a), measured

Six call sites in the tree, ALL in `conformance/stdlib/process.cxd`
(lines 1171, 1185, 1213, 1255, 1325 plus the `:swallow` form at 1311,
which names no path and is unaffected). No program outside the fixture
corpus uses a file disposition. There are no external users to migrate.

## Execution constraints

1. The refusal is **pre-spawn**: the capability check precedes the open,
   so a denied run must leave the target UNTOUCHED. A test must prove the
   file is neither created nor truncated, not merely that the call failed.
2. The code is **CXER0271**, matching `io:write-file`, so the two paths
   are indistinguishable to a caller reasoning about write authority.
3. `capture={stdout: :swallow}` names no path and needs no write grant.
4. Both `run` AND `spawn` are covered — the split between them is what
   made this pre-existing and unnoticed.
5. Red-prove each fixture: with `--allow-subprocess` alone, and inside
   `[?with-caps [deny write]]`.
