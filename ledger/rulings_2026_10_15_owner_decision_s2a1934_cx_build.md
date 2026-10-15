# Owner decision 2026-10-15: `cx build` ships as s2a, plus an internal testing build (CXBLD-1934)

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-15 12:10:25Z and 12:15:24Z; recorded by core from those RULING lines, quoted below).** It answers core's design call of window 27 on cx-home/cx-private#1934 (native IR, slice 2). The question was how `cx build` produces one executable now: (a) the cx binary with the program appended (s2a), with native code from cx's own IR to follow (s2b); or (b) the V-source route. Issues: cx-home/cx-private#1934; cx-home/cx-private#1354 (the path is handed there).

**The id (IDSH-1, #1767).** This decision was first recorded as S2A-1934, which carries a digit inside its letters and so is no id the grammar parses (2 to 6 capitals, a dash, digits). It is CXBLD-1934 from 2026-10-15T22:3xZ (integrator RULING to core, window 30). Four release/0.18 subjects cite the old token and cannot be rewritten (no force-push): 4b845faed, 132657bb3, eca8df2a9 and 1daef791e. scripts/ledger_index.cx exempts exactly those four commits by sha (IDSH-EXEMPT); every later subject cites CXBLD-1934. The quoted RULING lines below keep the token as the integrator wrote it.

## CXBLD-1934 — (a): `cx build PROG.cx -o OUT` ships now as the cx binary with the program and its build-time run flags appended; s2b adds C emitted from cx's IR and keeps the payload; never the V-source route

> RULING owner 2026-10-15T12:10:25Z (via integrator, S2A-1934 = (a), ids S2A-1934): `cx build PROG.cx -o OUT` ships now as the cx binary with the program source + build-time run flags appended (the CXBLD001 trailer; the walker/compiled tree runs it), with the CLI reference page, completions, primer and the startup + size row; s2b links C emitted from cx's own IR for the covered defs against a static libcx.a and KEEPS the payload (walker fallback, exact error positions) — never the V-source route (V's v2/native backends are opt-in and in development; cx's fork work lives in the old pipeline; re-evaluate only when v2 ships -prod with the fork's collector ported). core lands s2a after #142 lever 2 in the gate order.

The internal testing build that follows from it (REL-S2A, the same ruling's second line):

> RULING owner 2026-10-15T12:15:24Z (via integrator, REL-S2A: an internal testing release from `cx build`): core's FIRST item after #142 lever 2 at the relaunch = land s2a (S2A-1934 (a)) + a `make release-build-cli PROG=<path>` row in cx-private that runs `cx build` and writes dist/<prog>-v0.18-pre-<head sha>-macos-arm64 (ad-hoc signed; the sha in the name and in the trailer; `OUT --version` prints it), with a one-page dist/README-internal.md: same OS/arch only, files the program reads are not embedded, `xattr -d com.apple.quarantine` after a browser download, not the cut. Bar: OUT built from the landed head runs the program from a fresh directory on dev2 with no cx/V/C install on PATH, exit 0, output equal to `cx PROG.cx`; the startup + size row posted on #1934. The owner distributes the file; I hand the path on #1354 when it exists.

**Where it lands:**
- cx-core-code `vcx/cmd/build_verb.v` is the `build` verb and the CXBLD001 trailer. Its build record names the program and the cx version and commit, and `OUT --version` alone prints it. `vcx/cmd/main.v` runs a payload at start-up. `vcx/tests/cli_umbrella_test.v` holds the four cases.
- cx-tooling holds the completions.
- In cx-private:
  - `docs-src/canonical/sections/08-tooling.cxd` §8.1.4 and `docs-src/llm/reference-cli.md.tmpl` are the CLI reference.
  - `docs-src/llm/primer.md.tmpl` §1 is the primer.
  - `make release-build-cli PROG=<path>` plus `scripts/release_build_cli/README-internal.md.in` produce the internal build and its one-page README.

**The bar:** OUT, built from the landed head, runs the program from a fresh directory on dev2 with no cx, V or C install on PATH. It exits 0, and its output equals `cx PROG.cx`'s. The start-up and size row is posted on #1934.
