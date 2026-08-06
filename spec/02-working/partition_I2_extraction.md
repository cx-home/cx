# I2 — Ring-0 extraction: working ledger

**Status: EXITED** (2026-08-06 — opened and closed the same day; the
byte-for-byte exit gate was met on the FIRST run of both lanes and held
through the prod-shape rerun and the full phase-close gate battery; see
work-log entry 8). Branch `impl/I2-ring0-extraction` off
`design/651-516-partition`, merged back at exit.
Phase row: `partition_impl_PLAN.md` Part B; this file is I2's working
ledger, the successor to `partition_I1_rebless.md`.

## The phase (plan row, verbatim contract)

`libcx-core` + `data`-profile `cx` built from `vcx/cx`. Cleanups ride
along: fixture_loader → test support, cx.dylib debris, dead
cxstore/cxsqlite, arrow_pub rename.

**Exit gate — BYTE-FOR-BYTE:** the extracted artifact matches the
monolith on the full Ring-0-tagged corpus — outputs, canonical bytes,
hashes, error codes identical. (The corpus query: `make ring-query`;
Ring-0 = 23 families / 543 extraction-gate cases at the I0 census, plus
the I1 additions — re-derive the census at branch cut, don't trust this
number.)

## Standing constraints carried in

- The strangler rule: the monolith keeps shipping unchanged until I2
  completes (plan Part B preamble).
- Import gates (I0) stay green throughout — `ring_import_gate.sh`'s
  Ring-0 sink invariant is the structural contract the extraction
  realizes physically.
- Any red is a plain regression (the I1 deliberate-red ledger is
  discharged and EMPTY).
- Entry-25 residual rides BEHIND I2: mode-in-identity must be resolved
  before I5's type-binding anchoring (owner ruling (a) 2026-08-06);
  the pinned test is `test_mode_does_not_survive_canonical_text_named_residual`.

## Dispositions into this phase

- **#707** (conformance front door + spec gates) — gates the
  extraction's corpus contract (plan: audit M24).

## Cleanup riders (plan row, itemized)

1. `vcx/cx/fixture_loader.v` (+ its test) → test-support home (it is
   corpus tooling, not Ring-0 runtime).
2. `vcx/cx/cx.dylib` build debris out of the source tree.
3. Dead `cxstore`/`cxsqlite` code paths dropped.
4. `vcx/cx/arrow_pub.v` rename.

## Work log

1. **Census re-derived at branch cut (2026-08-06).** `make ring-query`
   reports 25 Ring-0 suite lines / 1587 cases — but that count is
   SUITE-level; the Q2-normative per-case resolution (binding_api's 32
   ring-1 overrides ride above a ring-0 header) gives the true Ring-0
   doc lane: **25 families / 1555 cases** at the cut (1560 after the G7
   additions below). `code.cxd`'s 991 in-cx documents ride the doc lane
   as inert trees; its eval lane (eval-ring=1) is excluded by
   construction.
2. **Cleanup riders executed (commit 18633d6f).** fixture_loader →
   NEW test-support module `vcx/fixtures/` (out of shipped libcx; 8
   consumers re-pointed; lang mirror comments re-pointed); cx.dylib
   debris removed; dead `vcx/cxstore/cxsqlite/` deleted (zero importers;
   the live sqlite backend is `code/store_sqlite_d_cxstore_sqlite.v`);
   `arrow_pub.v` → `cxcol_pub.v`. RIDER FINDING: the five `vcx/cx`
   in-module tests ran in NO gate lane — NEW `test-vcx-cx` lane wired
   into `test-vcx`. Wiring it surfaced **#737**: `parser_multidoc_test.v`
   segfaults under `-gc e` (module-internal-test-only RC double-free of
   the option-unwrap multi-doc tree; external-linkage identical body
   green, production CLI green). Ruling under the standing acceptance:
   the lane lists the green files explicitly and names #737 beside the
   exclusion — fixing V-fork RC codegen mid-I2 would couple the
   extraction to a GC repair while production artifacts are proven
   unaffected; the V-only fix proceeds on the tracker.
3. **Ring-0 artifacts (commit 478dc787).** NEW `vcx/cli` module = the
   shared Ring-0 verb layer (canonical/hash/eq/diff/validate + the
   convert pipeline + lossless enforcement), moved verbatim from
   cmd/main.v with the monolith delegating (dispatch unchanged — the
   strangler rule holds at the behavior level). NEW `vcx/cmd_data` =
   the data-profile main: convert surface + data verbs, verb-word
   profile refusals (#426 discipline), run-surface flags refused by
   name; imports cx+cli only. Targets: `lib-core` (libcx-core =
   `-shared` over `cx/` alone — 155 cx_* exports, strict subset of
   libcx; the code-eval/iowatch/wasm-async families absent by
   construction), `cli-data` (→ `target/profiles/data/cx`),
   `build-data`. fmt/lint stay OUT of the data profile (spec §2 puts
   the verbs at Ring 1); the corpus lint/fmt surfaces are covered at
   the ABI lane.
4. **EXIT GATE BUILT AND GREEN (commit daf3f921; `make
   test-extraction-gate`, wired into TEST_TARGETS).** ABI lane: a probe
   dlopens ONE artifact, feeds every Ring-0 case input through the full
   C-ABI battery (conversion matrix, canonical/hash/fmt/lint,
   ast-bin/data-bin/events + decoder round-trips, diff/eq pairs, schema
   validate, the streaming-write event interpreter) and emits a
   deterministic transcript — errors are records too, so error-code
   identity is asserted. libcx vs libcx-core: **transcripts
   byte-identical on the first run** (1555 cases, 4.4 MB). CLI lane:
   monolith cx vs data-profile cx over the SHARED surface (verbs +
   explicit `--from=` convert; bare-FILE run-vs-data reading is the
   ruled §4 profile difference): **8954 invocation pairs
   stdout+stderr+rc identical + 17 profile refusals verified.**
5. **Pre-I2 corpus gaps closed (same commit).** G7: `in-toml` runner
   lane + conv-019..023 (TOML import pins; leniency finding filed
   **#738** — malformed TOML parses silently; positive lane pinned,
   strictness needs its own conversions.md ruling). G10: NEW
   `lockfile.cxd` (ring=0, 4 cases — wire-form canonical/hash pins,
   json image, canonical fixed point; `conform-lockfile`). G12: NEW V
   lane for streaming_write.cxd (drives the V-native CxEventsWriter
   with lang/python-parity grading; 17/17; `conform-streaming-write`).
6. **#701 fixed and CLOSED (same commit).** Fixture module sources no
   longer registered by the production constructor; the gate registers
   them explicitly per-env; pin = `module_loader_shadowing_test.v`
   (user file on disk WINS; missing file → MODULE_FILE_NOT_FOUND).
   `conformance/fixtures/module/` (stale, unreferenced, never-implemented
   runner contract) deleted.
7. **#707 executed — all seven items (commit a648ba17).**
   EV-RESULT-IMAGE normative (code.md §11.1a); grant= promoted into
   fixtures.cxs with the three-way policy written down; README rewritten
   to the .cxd reality; `check_code_spec_consistency.py` repaired
   (gate-3 formal-files path, gate-2 chain/while tombstones, gate-1 on
   the NEW code.md bounded-freedom register BF-1) + wired into
   TEST_TARGETS + NEW no-impl-anchor and no-dangling-decision checks;
   fp.md/jsonschema.md sentinel de-anchoring; 12 dangling D<N> sites
   repaired (remaining D-refs all resolve to the in-file §6.6 slicing
   register); EV-ASYNC-SPAWN normative in §10.5.1 + cli.md
   CX_WORKER_THREADS corrected. fixtures.cxs also formalizes
   ring=/eval-ring= and reserves the out-effects trace channel
   (stream 22). **#707 stays open for ONE residual:** the lazy
   `CX_WORKER_THREADS=0` substrate conforms-or-retires at I5 (ruled
   register row; strangler rule forbids the behavior change here).
8. **Phase close — EXIT GATE MET (2026-08-06).**
   - **Prod-shape extraction gate:** `-prod` libcx vs libcx-core ABI
     transcripts BYTE-IDENTICAL over 1564 Ring-0 cases (post-G7/G10
     census); CLI lane 8978 invocation pairs stdout+stderr+rc identical
     + 17 profile refusals. (Dev-shape gate identical earlier at 1555.)
   - **FULL `make test` GREEN** (exit 0, all TEST_TARGETS incl. the new
     test-extraction-gate + check-code-spec-consistency lanes) and
     **`test-binding-api-parity` GREEN 51/51** — the code lane the I1
     close missed is explicitly in this close.
   - Three reds surfaced and dispositioned on the way to green, none a
     regression: (a) cxparse differential baseline 725→729 — the
     designed deliberate-review path; lockfile.cxd's 4 data-only docs
     land in cx_only, divergences unchanged (commit 063ad9c2);
     (b) store_grpc_parity_test.v dial-failed under -j full-gate load,
     green in isolation → joins CODE_SERIAL_RETRY, the #648 class;
     (c) lang/v/conformance.v was the ONE fixture-loader consumer
     outside vcx/ the rider sweep missed → re-pointed, test-v green.
   - Strangler rule held: the monolith's dispatch and behavior are
     unchanged (CLI-lane identity is the proof); the ring_import_gate
     stayed green throughout (fixtures joined the derived deny-set).
   - Entry-25 mode-in-identity residual remains parked BEFORE I5, per
     the standing constraint — untouched here by design.
