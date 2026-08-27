# CX v0.17.0 — Release Notes

**Date:** 2026-08-27
**Tag:** `v0.17.0`

The **settlement** release. v0.16.0 stated what CX *is* — four rings with a
one-directional import contract. This release states what CX **means**: the
path/value model is now a total, measured, frozen matrix — every operand kind
× operation cell has ruled semantics and a conformance pin — and a refusal
can no longer leave a program as silent data at the effect boundary (the
sequence-content rule and `CXER0275`; an `[err]` inside a collection remains
an ordinary value in-process, by the frozen matrix, and program output may
carry it with exit 0 — the boundary, not the exit status, is the contract). Alongside the semantics, this
is the first release shaped by real downstream deployment feedback: every
reported defect was verified, ruled, and repaired, most of them deeper than
reported.

**Two classes of deliberate movement to know before upgrading:** the
sequence-content rule (a sequence value cannot be element content — adopt it
with `[?splice]`) and a set of named content-address movements repairing
canonicalization soundness. Both are listed under Migration.

## Headlines

- **The path/value model, settled and frozen.** The total operand-kind ×
  operation matrix is measured, ruled (R-A1…R-A8), pinned cell by cell, and
  frozen — changing a cell now requires a ruling naming the cell. The rule
  with reach: **a sequence value cannot be element content**; content adopts
  members through the syntactic carriers (`[?for]` contributes, `[?splice]`
  adopts, absence contributes nothing), and the loop protocol's positional
  carriers (`[break]`/`[continue]`) are exempt by design. The cutover moved
  ~150 sites in-tree, including the last unmigrated one hiding in the guide
  generator.

- **Refusals refuse at the effect boundary.** In-process, an `[err]` is a
  value like any other — collections carry it, channels transit it, pure
  functions format it. What it can no longer do is *leave* silently: a store
  document write or an http response containing an `[err]` at any depth
  refuses loudly (`CXER0275 E_ERR_AT_BOUNDARY`, naming the first err's code
  and path) unless the effect names the permission (`errs=:permit`). A bare
  `[err]` handler result — previously a silent 200 with the error rendered
  into the body — is now a loud 500. This closes the class where a generator
  reports success while its output carries refusals as data.

- **The vgc stop-the-world deadlock is closed.** Two modes, both from
  suspending threads at arbitrary points: the collector took the platform
  loader lock inside the STW window while a suspended thread held it
  mid-`fork`, and a child forked during a suspension window inherited a
  permanently-locked lock and hung before `exec`. The fix caches segment
  roots at init (the collector performs no loader call under STW on any
  platform) and brackets every fork against the collection cycle.
  In-process parallelism under the shipped memory model is unblocked;
  attribution measured (fix halves proven independently), burned in with a
  246,000-run supervise soak.

- **Stores written by v0.15 open again.** v0.16.0 changed a reserved pack
  slot's meaning and refused old stores on read — while its notes claimed
  stored formats were unchanged. Repaired without a migration verb: zero
  means the one hash algorithm v0.15 had, readers accept exactly that, and
  the first durable write stamps the slot forward in place (the slot is
  outside every integrity computation; each intermediate state is legal). A
  committed v0.15-shaped store fixture gates it forever, and the v0.16.0
  claim is corrected in the changelog.

- **Content addressing is sound per kind.** The canonicalization parser had
  its own operator alphabet: `>=`, `!=`, `~` failed to parse and `<=`, `%`
  silently canonicalized to strings — a demonstrated hash collision between
  `[<= 5 3]` and the string `'<= 5 3'`. One alphabet now (the evaluator's
  ruled 18 heads), with the operator forms taking new addresses and every
  string form keeping its own. Canonical serialization is ruled
  **bijective**: emitter images that lost a scalar kind through re-parse are
  repaired with every address movement named: float images are always the
  Ryū exponent form (`1.5e0` — the float/decimal address collision closed,
  with decimal unmoved), and date/datetime attribute values render bare.
  The identity lane (`cx hash`'s preimage) was measured faithful all along;
  the loss lived in the runtime value renderer, and the repair unifies the
  two canonical paths — which also moves float PROGRAM output to the
  exponent images (`[/ 7 2]` prints `3.5e0`), the widest visible effect.

- **A clean-state deployment can mint its own first principal.**
  `cx store-mint-principal` generates an identity offline — seed written
  0600 via temp+rename, DID derived locally, the exact `[grant …]` /
  `[identity …]` stanzas printed from the same constants the daemon's parser
  validates against. Canonical ids make the seed-env derivation injective
  (no two ids can ever share a variable), `--caps` is a required, stated
  authority, and `--for identity` makes the daemon's own row copy-paste.
  Retired verbs answer with their retirement and their replacement — in
  every profile — instead of "unknown subcommand" or a missing-file error.

- **Hosted XAPs reached parity with direct runs.** The host forwarded only
  tenant + grammar; a grammar with a derived noun could not boot at all.
  Derivers forward now, and the durable bindings — journal, sources,
  resolver, log-reduce — ride the deployment document's new `[runtime]`
  block (one vocabulary with the opts map, one validator), with deriver
  principals superseding opts by the composition spec's one-block rule.
  Boot ordering is normative: subscriptions open at run assembly, pumps
  consume only after the deployment's authority is wired — a refused boot
  leaves every pre-seeded entry redeliverable by construction.

- **The version headline is a provenance claim.** A binary reports the bare
  `cx vX.Y.Z` only when built from a clean checkout of the annotated release
  tag; every other build reports `vX.Y.Z-dev+<commit>`. The release lane
  itself was provenance-broken twice over — artifacts built before the tag
  existed, profile tarballs built at the merge commit — both fixed, and the
  release gate now demands the exact headline from every staged artifact.
  libcx carries the same stamp (commit deliberately unclaimed: the ABI has
  no provenance surface, and an untracked stamp would be unfalsifiable).

- **One numeric discipline, everywhere.** The exact family (decimal, bigint)
  now folds exactly on every arithmetic surface — `%`/`$mod`, `$div`/`$idiv`,
  and the whole aggregate family (`$sum`/`$min`/`$max`/`$avg` and the
  statistical verbs) join the lane the heads have carried since L44. Mixed
  decimal+float refuses everywhere instead of silently bridging through
  float (the `$math:` statistical verbs were silently *dropping* decimal
  items — `[$math:sum (19.99, 19.99)]` returned `0.0e0`); `[$avg]` over
  decimals yields a decimal; and a non-terminating exact division refuses by
  name, pointing at `$math:div-decimal` as the explicit precision context.
  `[cast]` remains the only decimal↔float bridge, and the deliberate cast
  asymmetry (float truncates, decimal refuses unless integral) is pinned as
  deliberate.

- **Child processes stop deadlocking, leaking, and lying.** The 64 KiB
  pipe-capacity deadlock class is closed across the surface — `run`'s stdin
  feed and capture drain, `spawn`'s per-stream dispositions, and the
  pipeline's inter-stage feed are all non-blocking and interleaved, so a
  large payload honors `$timeout-ms` and an early-closing child (`head`) no
  longer kills the interpreter with a silent SIGPIPE. Capture descriptors
  are released on every exit path (previously every capturing `run` leaked
  two fds for the life of the interpreter), a force-killed child is reaped
  and reports `128+signum` instead of a zombie with `exit-code=0`, and
  `$capture` speaks the full disposition vocabulary (`:pipe`, `:inherit`,
  `:discard`, file path — per stream) that `spawn` got, so bounded runs can
  write to files without going resident. Pipelines gained their whole ruled
  per-stage surface: `cwd`, `env-clear`, `search-path`, and `[env {…}]` —
  the POSIX `FOO=1 cmd1 | BAR=2 cmd2` shape — with everything a stage
  cannot coherently own refusing by name.

- **`[?bulkhead]` counts honestly under load.** The permit counter was a
  non-atomic read-modify-write in four places — measured losing up to 5% of
  permits under contention, permanently wedging the bulkhead's name — and
  the acquire path could admit over capacity from a stale read. Every
  permit decision is now one atomic section, proven with deterministic
  admission arithmetic rather than timing.

- **Format fidelity, both directions.** `$format:pretty` and
  `diff-friendly` are round-trip faithful — every string-carried kind
  (decimal, bigint, atom, temporals, `::T` annotations) kept its type
  through re-parse for the first time — and `cx fmt` is idempotent
  everywhere: the fail-closed lanes were growing one newline per pass on
  103 files in-tree; a mechanical fmt-twice check now runs per fixture.

- **Consumability, for people and for their LLMs.** The guide renders green
  again; the playground runs a CURRENT engine (the wasm bundle had been five
  releases stale — a two-signal freshness gate now makes that impossible),
  renders instances as entity tables with a control model in which nothing
  on screen is inapplicable, and every one of its 2,070 example diagrams is
  gate-verified to parse;
  the model-facing pack under `docs/llm/` is re-derived against this
  release's surface and gains the enterprise-XAP playbook — compose feature
  grammars, author the deployment document, bootstrap identity, host, and
  project the ux-web surface — 193 cited fixtures across 30 suites, all 27
  CLI verbs, with its real gaps named rather than papered.
  The playground's graph and tree stopped flattening structure: a nested
  element value draws nested tables capped by Detail, a single-child chain
  folds to its CX path, worker/channel programs classify as sequence
  diagrams again (a latent dispatch hole, not a port regression), computed
  `[?element]` bodies image structurally instead of as one opaque string,
  and the Tree pane honors Detail through the same projection the tables
  read. Three new browser-driven gates hold the line: every example
  evaluates in the READER's wasm engine (ten that cannot are marked with
  reason and remedy instead of failing raw), the Tree renders per rung
  against pinned expectations, and the code_tree walker's arity agrees with
  the parser on the repaired lanes — a prose run is one Text node, an
  apostrophe at token start doesn't unbalance a body, and top-level prose
  stopped splitting per token (the walker's remaining divergences — the
  comma lane, comment/raw-span awareness in its bracket scanner — are
  tracked, not claimed).
  The oriel flagship gains the field-
  registry desk (one form driving the live wire, drive-step pinned), and
  the storefront's language bar stops reporting the runtime as Verilog.

## Changed (behavioral)

- A sequence value in element-content position refuses (`CXER0100`, the
  `#847-1a` diagnostic) — adopt with `[?splice]`. Loop carriers exempt.
- Externalizing effects refuse documents containing `[err]` (`CXER0275`)
  unless `errs=:permit`; bare-err handler results are 500s, not 200s. The
  journal and fabric are ruled EXEMPT — an error event is a first-class
  record, so err-carrying events append and publish green (pinned).
- The store write verbs (`put-doc`, `put-doc-stream`, `put-doc-text`,
  `modify-doc`) grow an optional trailing opts map — backward-compatible.
- `[$eq]` is documented and pinned as VALUE equality (compare atomizes);
  strict-canonical (`cx eq`, `cx hash`) remains the type-faithful identity.
  The behavior did not change; the documentation claiming otherwise did.
- `$format:pretty`/`diff-friendly` no longer quote non-string scalars.
- Unknown verbs exit 2 naming themselves; retired verbs answer with their
  retirement; both only when no same-named file exists (files still win).
- `cx version` headlines carry release provenance (`-dev+<commit>` off-tag).
- Operator-headed forms (`>=`, `<=`, `!=`, `~`, `%`) parse under
  `cx canonical`/`cx hash` and take element addresses; float images move to
  exponent form everywhere (program output included), date/datetime
  attribute images to bare — each movement named with digest witnesses in
  the CO-12 record.
- Mixed decimal+float refuses on `%`, `$div`, `$idiv`, and every aggregate
  (was: silent float promotion, or silent decimal *drops* in `$math:`
  statistical verbs); `[$avg]` over decimals returns a decimal; exact
  division that cannot terminate refuses naming `$math:div-decimal`.
- The exact lane's integral narrowing is saturation-free: `$idiv`, `$floor`,
  `$ceiling`, `$round` answered a clamped `i64.max` for every result in
  `(i64.max, 2^64)` — the band now answers bigint. The int-only lane stays
  CHECKED: `$div`/`$idiv`/`$abs` cells whose result leaves i64 (`MIN ÷ -1`,
  `|MIN|`) refuse `CXER3000` like the checked heads (was: saturated or
  wrapped values, silently), and int ÷ int computes in i64, never through
  f64 (quotients past 2⁵³ were float-rounded to the wrong integer).
- A `--allow-read=`/`--allow-write=`/`--allow-env=` scope suffix — an
  authority the engine cannot enforce — refuses loudly at startup on every
  CLI parse site AND on the C-ABI grant spec (`cx_code_eval_caps`), instead
  of silently granting blanket authority; `--allow-net=host[:port]` remains
  the one enforced scope (real path/name scoping is #1061).
- `run`/`spawn`/`pipeline` honor `$encoding` (`"utf-8"` validates, `:bytes`
  returns bytes, anything else refuses — previously accepted and ignored);
  `run`'s `$capture` takes the full per-stream disposition vocabulary;
  pipeline stages take `[opts …]` with `cwd`/`env-clear`/`search-path`/
  `[env {…}]`, refusing every key a stage cannot coherently own.
- A force-killed child reports `exit-code = 128 + signum` (was a stale `0`);
  capture pipes are closed on every exit path.

## Migration

- **Sequence-into-content sites**: the refusal names the first member and
  the fix (`[?splice]`). The in-tree cutover moved ~150 sites; downstream
  programs hit the same loud diagnostic, never silent movement.
- **Content addresses**: documents carrying the five repaired operator heads
  and float-bearing / date-datetime-attribute documents take new addresses;
  string forms and every other document are unmoved. Re-derive stored
  addresses where you pinned them.
- **v0.15 stores**: no action — they open, and the first write stamps them
  current.
- **Pretty output assertions**: non-string scalars are no longer quoted;
  re-pin against the type-faithful images.

## Known state, stated honestly

- Gate 15 (`[?map]` ≥ 200 MB/s) remains an honest red with a dead-ends
  register; `[?for]` clears the floor.
- One linux/upstream item stands: signal-suspension under a signal-owning
  host in a shared library (structural, #834).
- The supervise deadline flake (#951) did not reproduce in 246,396
  instrumented runs on the fixed runtime, and the release gate closed green
  with zero serial retries fired; the transit-door probe ships
  compile-gated for any recurrence.
- `[?worker]`/`[?async]` are unavailable in the default single-threaded
  browser wasm build; the ten affected playground examples state the reason
  and remedy, and the capability itself is a named design item (#1042).
- External registrations (GitHub Linguist, nvim-treesitter/mason) have
  payloads prepared in-tree and await their owner-gated submissions.

## Toolchain

- V fork at `cf25c48308` (`cx-patches-0.5.2`), three commits: the vgc
  STW/fork fix (the collector never takes the loader lock; fork never
  overlaps a suspension window), per-stream child-stdio redirection in
  `os.Process`, and the removal of the unconditional `-z muldefs` link mask
  (#971 — a dev-cache duplicate-symbol class no longer hidden at link
  time). All V-only, upstreamable.
