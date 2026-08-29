# Rulings — release portability and gate honesty (#1102, #1089, #1100, #1101)

2026-08-29, release/0.18. Campaign umbrella #1097, workstream D + F.
Owner letters given in session; recorded here before the work.

## R-1102 — the macOS release linkage (RULED: R-1102 = a)

The shipped macOS artifacts carried an absolute load path into the BUILD
MACHINE's Nix store, with no LC_RPATH fallback, so they died in dyld
before `main` on any other machine. Both tarball artifacts AND the
installed binary; linux unaffected (soname). Demonstrated, not inferred.

- (a) **Rewrite install names + add a detection gate.** RECOMMENDED and
  taken.
- (b) Build the macOS release outside devbox — rejected for now: it moves
  the release off the pinned toolchain devbox exists to guarantee.
- (c) Static-link sqlite — rejected: size, plus owning sqlite's patch
  cadence.
- (d) Drop `-d cx_db_sqlite` — rejected: it removes the SQL surface from
  the shipped product, the opposite of what #1089 was checking for.

Two decisions inside (a) worth recording:

**The repair happens at LINK time, not at packaging time.** Packaging-time
repair would leave the tested artifact and the shipped artifact differing
in exactly the field that broke. Link-time means what we test is what we
ship.

**A path that cannot be repointed is REFUSED, never guessed.** Repointing
an arbitrary Nix path at `/usr/lib/<basename>` would ship a dangling
absolute path — the same defect relocated and harder to find. So the
repair carries an explicit list of libraries macOS itself provides, and
anything else fails the build. Adding an engine that links a library
macOS does not ship (libpq, libssh2) therefore fails at the link, which
is where it should fail.

**A second defect of the same family, found while fixing the first**: the
shipped `libcx.dylib` carried an absolute BUILD path as its own install
name, so every consumer linking against it would bake that in. Fixed to
`@rpath/<basename>`; verified against the consumers most at risk — the Go
and Rust binding lanes both stay green.

## R-1089 — the sqlite store backend (RULED: R-1089 = b)

The question asked was whether `-d cx_db_sqlite` reaches the release
binaries. **It does** — measured on the actual v0.17.0 tarball, which
reports `profile platform`, carries `sqlite3_open`, and answers
`[$sql-open "sqlite://…"]` with a live handle.

The measurement surfaced a second, unasked question: the `sqlite://`
STORE backend is a DIFFERENT flag (`-d cxstore_sqlite`) and appears in no
build or ship recipe at all.

- (a) Ship it — the cost argument for excluding it had evaporated
  (`libsqlite3` is already linked for the SQL surface, so it adds no new
  runtime dependency). Recommended at the time; NOT taken.
- (b) **Rule it out and document the refusal as intentional.** TAKEN by
  the owner: the shipped surface stays minimal on purpose. The loud
  `CXER1100` naming the flag is the correct posture, and store.md now
  says so, including that the cost was measured rather than assumed.

## R-1100 — the zip EOCD refusal code (RULED: R-1100 = a)

- (a) **Narrow the spec: a missing or out-of-window EOCD is `CXER5200`.**
  TAKEN — and on the merits, not on cost. The EOCD comment-length field
  is a `u16`, so its maximum is 65535; plus the 22-byte record that is
  exactly the 65557-byte scan window. A conformant archive therefore
  ALWAYS carries its EOCD inside the window, which makes "EOCD beyond the
  window" a state a conformant file cannot produce. It is malformed, not
  a capability the codec declines, and `CXER5201` would have the error
  model LIE — telling a caller to ask for a feature when what they hold
  is a broken file.
- (b) Scan the whole buffer to distinguish the cases — rejected: buys a
  distinction nobody needs, at the cost of false positives, since the
  4-byte EOCD signature occurs by chance inside compressed data.
- (c) Leave the drift — rejected.

**The general rule this establishes, which #1084 tar inherits: the
malformed / unsupported split tracks WHOSE FAULT it is.** Anything a
conformant file cannot produce is malformed; unsupported is reserved for
inputs that are valid and that the codec declines. That turns a judgement
call into a rule.

## R-1101 — the exit-gate hole (RULED: R-1101 = b)

`make test-vcx` is what handoff notes call the exit gate, but it is a
strict subset of `make test`. Two gates sat RED on release/0.18 and
survived a release-branch cut: guide-check (since #1078) and check-v-fork
(since the dynamic-Huffman fork commit).

- (a) Make the naming honest in AGENTS.md / CONTRIBUTING.md — not taken
  as a separate item; the reasoning now lives at the point of use, in the
  `test-vcx-gates` comment, which a reader hits while looking at the lane
  rather than in a document they must remember to read.
- (b) **Fold the cheap gates into `test-vcx`.** TAKEN. Six gates that
  cost seconds each next to the V compiles: check-v-fork,
  check-portable-links, guide-check, directive-docs-check,
  stdlib-catalog-gate, cxer-registry-gate. They run against the DEV
  binary the lane already built — depending on `build-vcx` would drag a
  prod relink into the fast lane, which is the cost that kept them out.
- (c) A CI job on release-branch pushes — not taken: it does nothing for
  a local session, which is where the work happens.

**`test-vcx` is a BETTER subset now, not the full matrix.** The expensive
gates stay in `make test` alone — test-profile-gate (which caught two of
the three defects in the #1090 lane), check-prod-build, docs-check, and
the language-binding lanes. A wave still exits on `make test`.
