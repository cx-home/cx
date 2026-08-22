# Changelog

All notable changes to CX are recorded here. Per-release deep-dives
live in the top-level `RELEASE_NOTES_v*.md` files; migration
instructions live alongside each release-notes file (e.g.
[`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md)).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
plus the additional [`spec/governance.md §9` versioning rules](spec/03-approved/process/governance.md#9-versioning)
for the multi-axis CX project (language version, ABI version, format
version, library version).

## [Unreleased]

Nothing yet.

## [0.16.0] — 2026-08-20

The **partition** release. v0.13.0 made CX consumable and v0.14.0 made a
deployment survive its own success; this release states what CX *is* — four
rings with a one-directional import contract — and makes that structure
enforced, buildable, documented, and demonstrated by a reference application.

Nothing here is a breaking change to the public surface (§9 versioning
rules); the partition is a separation of what already existed, not a
redefinition of it.

### Added — at the cut (2026-08-20)

- **The map-syntax settlement (#917, RULED: MSS-1…MSS-6, 2026-08-22)**: map
  values are one expression-shaped item in BOTH readers (unquoted prose
  refuses with quote guidance — the silent slot absorption that read
  `{a: 1 b: 2}` as one junk-string entry at exit 0 is gone); entries
  separate by comma or whitespace ([L85] amended, ratifying the shipped
  form); every ascription coercion arm is checked and a bare `::`-carrying
  token either ascribes or refuses (`{x: prose ::bool}` invented `false`
  before; `5::bogus` silently stringified); the **declaration-only entry**
  `{k: ::T}` lands — declared kind (the [157] KindName vocabulary), value
  ABSENT (not null), carried by cx text, round-trip XML (`cx:decl-kind`)
  and ast_bin v10, refused loudly by every lossy target; double-quoted map
  keys and checked key ascription now behave identically in both readers.
  `verify-doc-blocks` returns green (the xap.md typed-props fences parse
  as written, respelled per MSS-5).

- **The studio (#884)**: the visual editor over surface documents — an edit
  mode of the real web face (capability-gated by a `ux:edit` claim), with
  the layout-command vocabulary completed by `[ux:place]` / `[ux:remove]`
  (ux.md P0-105…P0-110), emitter-stamped selection resolution, inverse-command
  undo, and propose/commit flow.
- **Durable feed lineage (#764)**: XSP store data-plane resume cursors now
  survive daemon restarts — a per-substrate lineage sidecar turns the boot
  token into a durable epoch token (zero wire change); `CXER5020` narrows to
  wrong-epoch / below-retention-floor / above-head.
- **Semantic projections (#877, ANC-1)**: every lossy projection
  (JSON/YAML/TOML/MD/CSV/TSV/PSV) and the `$doc` binding read the RESOLVED
  document — aliases expand, merges apply — matching strict canonical's
  identity; default CX, the XML `cx:*` carry, and `--lossless` preserve the
  authored sharing.
- **Parse limits (#876, LIM-1/LIM-2)**: `spec/core/limits.md`, the
  `ParseLimits.max_input_bytes` embedder guard, and the amplification gate
  (node growth bounded, hard-asserted).
- **Session guest attach (#857)** and **HTTP/2 on the serve path (#875)** —
  landed at the cut (see their issues for surface details).
- **One-command editor install (#874)**: `tooling/install/` — signed
  tree-sitter parser with a headless load-proof (#883), lazy.nvim `dir=`
  spec, VS Code VSIX.

### Added — the surface-completion wave (2026-08-21)

The owner's directive for this window: it is the last chance to change
surfaces across the rings before production clients, after which every
change carries per-engagement migration cost. These landed under that rule.

- **`cx-stdlib/supervise` (#765)** — restart policies over monitored
  workers: `:one-for-one` / `:one-for-all` / `:rest-for-one`, per-supervisor
  restart intensity, per-child exponential backoff with window reset,
  dynamic children, an observable event stream, and supervision trees by
  composition. Pure CX over the shipped worker/monitor/select/channel/timer
  primitives — no new engine primitive, no capability.
- **`cx-stdlib/diagram` (#758, #889)** — the `code.md` §10.1.2 reference
  renderer AND the control-flow / entity / sequence renderer both move from
  V to CX. `code_diagram.v` went 3,219 → 69 lines and `diagram.v` 1,661 →
  399; the only effect left is one `dot` invocation under `subprocess`.
  §10.1.1's own sentence — "the renderer is itself a CX program" — is true
  for the first time. New caller-facing entry `[$diagram:of-source]`.
- **Uniform postfix path steps (#886)** — every program-position bracketed
  form's closing bracket now takes the compact step postfix (directive
  results, operator forms, every literal), not just bindings and calls.
  One rule, no special cases, nothing to migrate later.
- **The universal store model** — content-addressed piece storage is
  available across every substrate (memory, pack, object-per-key, SQLite,
  S3) and the server tier, with whole-document mode as the compatibility
  option; the six guarantees (universal dedup, version sharing, cross-tier
  object identity, self-verifying integrity, canonical round-trip,
  model-invisible API) are now normative in `store.md`.
- **Durable feed lineage everywhere (#764, #885, #887)** — data-plane resume
  cursors survive daemon restarts on local substrates, s3-rooted stores and
  the columnar backend alike. Zero wire change.
- **One-command editor install (#874, in-repo half)** — `tooling/install/`
  with a signed, load-proofed tree-sitter parser and a lazy.nvim spec.
- The `[?cx]` fixture generator is now CX (#856), the store examples lead
  with TLS (#745), and `cx -v` reports the DB engines compiled in (#520).

### Fixed — the surface-completion wave (2026-08-21)

- **`[?try-send]` silently lost values sent to fan-out channels** — it
  answered `[ok]` while the value went to a queue no subscriber reads. Found
  by sweeping every channel-delivery path after the same class was fixed in
  the scheduler's timer ticks; both instances are now pinned by conformance
  cases.
- **The scheduler's timer ticks never reached fan-out channels** at all — a
  dead delivery path nothing had exercised until the supervisor did.
- **`cx diagram --format=svg` emitted malformed SVG** — the source carrier
  was spliced into the document prolog, so every SVG the tool ever produced
  was invalid. It now sits where SVG 1.1 puts metadata, and validity is a
  gate with a negative case pinning the old bytes as rejected.
- **The `svg`/`png` diagram formats now require an explicit `subprocess`
  grant** rather than granting themselves one, and a denial is reported
  rather than silently substituted with the graphviz-absent fallback.
- **The guide silently truncated nine pages** past ~195 code spans, shipping
  two ring arcs at roughly a third of their length; the builder now refuses
  to emit a partial page.
- **The DSN diagnostic told you to rebuild your binary when your URL was
  malformed** (#520), and `sqlite::memory:` did not parse at all.
- **The libcx ABI gate compared vendored C++ symbols** and would have gone
  red on any toolchain rebuild with no CX change (#888); it now pins the CX
  surface and additionally verifies that every entry point declared in the
  public header is exported.

### Fixed — at the cut (2026-08-20)

- **#883**: macOS killed Neovim (and its spawning TUI) on every parser
  reinstall — the universal build shipped an unsigned arm64 slice and the
  installer overwrote the old inode; every parser binary is now ad-hoc
  signed, installed to a fresh inode, and load-proofed at install time.
- **#879 (CXP-1)**: the `[?cx …]` pragma registry is CLOSED
  (`include|schema|version|lint-disable|lint-enable`); unknown keys —
  including the documented-but-inert `output-target` — now refuse at parse
  with a named message instead of being silently accepted.
- **#878 (ENT-1)**: XML emission of entity references at item boundaries no
  longer glues text (`Cheese &amp; Pepper` round-trips); attr-position
  entity text is carried verbatim by design.
- **#881 (BP-1)**: explicit `axis::` steps on binding paths refuse with a
  precise diagnostic naming the compact-step surface and the rooted-path
  alternative (was a bare `unexpected token '::'`).
- **#882 (ARR-1)**: the collection read/construct split is normative —
  readers (`count`, `first`, `nth`, …) destructure any collection kind;
  constructors (`concat`) keep strict container typing. The engine was
  already right; the docs taught otherwise.
- **#880**: silent-acceptance sweep — lint config attr typos, unknown bench
  flags, and a doubled `CXER0100` error prefix all refuse loudly now.
- The guide generator no longer silently truncates pages past ~195 code
  spans (two recursion-ceiling walkers made flat; the builder now REFUSES
  to emit a partial page).

### Added — the four-ring partition

- **Ring 0 Data · Ring 1 Code · Ring 2 Platform · Ring 3 Ecosystem**, with a
  **one-directional import contract**: a ring may depend only inward. Ring 0
  is the format (values, identity, surfaces, schema); Ring 1 is execution
  (programs, capabilities, computation identity); Ring 2 is the platform
  (store, history, wire, services, operations); Ring 3 is the ecosystem
  (distribution, registry, marketplace, bindings). The boundary readers most
  often get wrong is stated once and held to: **the XAP host is Ring 2, the
  XAP marketplace is Ring 3** — running a feature is platform, discovering
  and installing one is ecosystem.
- **The contract is gated, not asserted.** Ring membership carries a tag
  checked by a gate; imports are checked against the contract; and a
  per-profile **extraction gate** verifies the ring artifacts byte-for-byte
  against the monolith over the full tagged corpus, so "you may adopt Ring 0
  alone" is a tested claim rather than a diagram.
- **Build profiles** — per-ring build artifacts with installer assets
  verified at the cut, so a consumer takes only the ring they need.

### Added — seven concept specs graduated to approved

Each moved from working to approved status, and each is now a **taught guide
arc** rather than a spec link:

- **the semantic value model** — what a CX value is, independent of syntax;
- **computation identity** — when two computations are the same computation;
- **bitemporal time** — valid time and transaction time kept distinct;
- **commands and effects** — the effect signature and what it admits;
- **the consistency vocabulary** — the words the platform uses for what it
  guarantees, defined once;
- **schema and event evolution** — additive migration, identity unaffected;
- **runtime representation** — how a value is represented while running.

### Added — a reference application

- **`reference/shop`** — an in-family XAP that exercises the model end to
  end: a committed cascade (PEP, journal, state as a fold), a **composite
  feature** whose derived noun exists in neither base, real packaging through
  the distribution engine with the compose gate standing at install time, and
  a **separate web client** (hypermedia, htmx) that keeps agent parity. The
  specs stop pointing at the tracker for an example.
- **`cx xap init`** — scaffolds a project that already composes and passes
  W1–W6 unedited.

### Changed — streaming throughput

- **Lazy record nodes.** The streamed-input path stops materializing a
  document to walk it: certified top-level children are scanned rather than
  parsed, and a record that is only ever yielded is never materialized at
  all. `[?for]` over a streamed document moved **14.7 → ~200 MB/s**, and
  `[?map]` — which streamed its output but materialized its input —
  **12.7 → 129.2 MB/s**, with its monotonic in-process decay eliminated and
  the §11.4.4 jitter clamp now passing.
- **The §11.4.4 streaming gate is not green yet.** The remaining criterion is
  throughput on the `[?map]` shape; it is tracked, and the threshold has not
  been relaxed to meet the implementation.

### Added — language surface

- **`[$present]`** — a presence predicate that answers "is this here",
  true for any value including a childless element and false only for
  absence. `[$count]` / `[$exists]` keep their content-arity meaning; the
  new predicate exists because those two answer a different question and
  every "did this step match" test written with them was wrong on a leaf
  element.

### Changed — error propagation

- **Element construction is operand-consuming.** A computed `[err]` in a
  child position now **propagates** instead of being adopted as a child, and
  propagation is transitive, so a refusal cannot come to rest inside a
  document at any depth. Previously a refusal spliced into a document had
  stopped being a refusal: it no longer short-circuited and `[?match]` could
  not see it. A **source-literal** `[err …]` is still data — the
  discriminator is position, not value — so err-shaped documents remain
  expressible.
- **Migration:** embedding a *captured* err as data no longer works
  (`[?let [= $e …] [report $e]]` propagates). Rebuild from its parts
  (`[report [code $e@code] [message $e@message]]` — path navigation does not
  propagate), or collect outcomes in a paren **sequence**, which is not
  element construction.

### Changed — XAP grammar composition

- **`[from …]` is checked.** A derived noun's source list takes one or more
  qualified noun references (`[from 'orders/order' 'shipments/shipment']`),
  and W5 requires each to resolve in the composed grammar. It was previously
  unvalidated free text beside a strict `uses` and `constituents` — and the
  check immediately caught the `cx xap init` scaffold shipping a dangling
  reference. Join *semantics* remain deliberately unspecified and uncomputed;
  no join algebra is committed.

### Added — the composition track (features as building blocks, ruled end to end)

- **Derivation semantics — the deriver as actor.** A derived noun is
  computed by a **declared deriver**: a principal bound at run assembly
  that reads within the noun's `[from …]` envelope and emits the noun's
  events as `actor: deriver:<name>` through the ordinary append — the
  system's derived state is always attributable. Derived nouns are
  **deriver-reserved** (a grammar verb declaring `[writes]` on one is a
  new W7 compose conflict); a grammar whose derived noun has no bound
  producer refuses at run assembly, never serving a silently empty view.
  `[$xap:derive]` is the commit surface; no join algebra is committed —
  engine evaluation, if ever, is an optimization of this same contract.
- **Archetype instantiation and the refinement contract** — third-party
  feature catalogs without forks. An archetype is an immutable,
  content-addressed feature document; an instance is a tenant-owned
  binding pinning its exact address, admitted to **rename presentation,
  add, tighten, and select** — repurposing an inherited name and loosening
  an inherited rule/type/signature **refuse** (removal cannot even be
  spelled), which is what keeps N customers from becoming N forks.
  Archetype fixes propagate by **re-bless only** (one recorded act per
  instance; the whole contract re-checks against the new base).
  `[$xap:instantiate]` is pure; compose receives the result as an ordinary
  feature. The reference pair ships: one attestation archetype instantiated
  as a retail review flow and a marketplace endorsement flow, composing
  clean together.
- **Granularity stops being taste.** The feature's internal graph under a
  **declared-edge set** (verb reads/writes, ordering/dependency targets,
  checked rule noun-lists, sub-noun typing, `[from …]`; keys and frames
  are deliberately NOT edges) makes boundaries computable: a spanning rule
  means one feature (the floor), **two connected components are two
  features wearing one name** (the ceiling — `[$xap:cohesion]`,
  report-first, and the components it reports are the split it would
  accept), and a feature graduates to marketplace/archetype status only by
  surviving **two genuinely different compositions**. Validity rules gain
  `nouns=` — a checked declaration of the nouns their sentences span.

### Added — ORIEL, the reference storefront, promoted

- **`spec/03-approved/xap/demos/oriel/`** is now the reference XAP's home:
  1,004 products, six departments, facets, baskets, four-step checkout,
  subscriptions, returns, reviews — **in a browser, in a terminal, and in
  a serial voice-style renderer, from declarations, with zero view code**
  (`diff` computes that claim rather than asserting it). Its six
  instruments run as their own CI lane (`make test-oriel-lane`), and the
  developer guide (`docs/dev/oriel-guide.md`) teaches building a surface
  the same way. The estate measures **one component** under the cohesion
  gate — the granularity discipline's own flagship evidence.
- **`product.rating` is derived, live**: the catalogue seeds it and a
  declared rating deriver re-records the mean from approved reviews
  (`actor: deriver:rating`) — the second deriver exemplar, visible on any
  product page after a review lands.

### Added — the ux projection capability, specified

- **`spec/03-approved/xap/ux.md`** is the normative home of the third
  projection: the same command/query definitions that serve the wire and
  the agent-tools face project **forms, tables, and live regions** —
  derived at render time, no UI manifest to drift. The spec pins the four
  keying regimes, the closed 45-member semantic vocabulary (gate-enforced:
  unknown members and unknown attributes refuse), the emitter contract
  (sole attribute author, strict CSP, escaping by construction), the
  hypermedia obligations (every state a URL; degrade without the kernel),
  the one-evaluator authorization rule (what is shown is what is allowed),
  and the accessibility clauses — with the terminal face as the mechanical
  keyboard-reachability fixture. Implementation rides the x-tier
  (`cx-x/ux` core + web/terminal faces); the guide teaches it as a Ring 2
  arc.

### Added — prebuilt downloads and editor distribution

- **Per-profile darwin-arm64 tarballs publish with every release** —
  `platform` (default) / `cli` / `embed` / `data`, resolved by the hosted
  installer (`curl -sSL https://cxhome.org/install | sh`; `CX_PROFILE=`
  selects the lean builds), each gated by extract-and-probe before
  publish, all under one `SHA256SUMS.txt`. The guide gains a **Downloads
  page** presenting the profile matrix as the ring ladder.
- **Editor tooling joins the release motion.** `tooling/neovim/` is a
  real plugin root — lazy.nvim/LazyVim consume it directly
  (`{ dir = "…/cx/tooling/neovim" }`) on Neovim 0.11's native
  `vim.lsp.config`, no nvim-lspconfig dependency, copy-file install
  retired. The release script packages the VS Code extension and
  publishes to the Marketplace/Open VSX when publisher tokens are
  present.

### Fixed — two owner-felt platform defects, found and closed same-day

- **`[?match]` arm attempts stopped deep-copying the closure table** — a
  per-arm full environment clone made per-node dispatch scale with closure
  fatness; ORIEL category pages had reached ~3.6s. Renders returned to and
  beat the recorded baselines (category pages ~0.13s, the gate walks 80×
  faster); the whole fixture corpus's runtime halved. Gate 15's numbers
  are queued for re-measurement on the perf campaign.
- **SSE subscriber fds leaked on mid-dispatch disconnect** — a browser
  navigating ~1s/click made every page's feed FIN race its own dispatch;
  the leaked registry entries meant recycled fd numbers received **other
  visitors' frames** and swallowed their own requests ("pending" hangs).
  Close notification is now a fan-out with one purge point, invoked on
  every close path and defensively at accept.
- **A hidden page releases its feed's connection-pool slot** — browsers
  cap HTTP/1.1 at six connections per host and the liveness contract
  holds one SSE feed per page, so a handful of open tabs starved
  navigations. The web kernel now closes the feed while a page is hidden
  and reconnects on visibility; a background-opened tab takes no slot
  until first viewed. (The structural fix — HTTP/2 on the serve path,
  reusing the platform's existing RFC-7540 codec — is queued.)

### Fixed

- Roughly 150 tracker issues closed across the language core, standard
  library, V runtime, tooling and XAP — including a signal-free thread
  suspension for the darwin collector, and a sweep of correctness defects
  found by the partition's own gates.
- **Engine-side findings from the documentation audit**: the shipped
  `cxstore.service.cx` operator template could not boot the daemon it
  documents (retired `[auth]` block → the real `[xsp [grants …]]` shape);
  the LSP's semantic-token directive list carried only the pre-reshape 37
  names against the registry's 80; two binding manifests declared MIT
  against the repo's Apache-2.0 license.

### Documentation

- **The guide is restructured on the rings** — six navigation groups (the
  four rings plus orientation and reference), the standard-library pages
  indexed under the ring that owns each pack, and the seven graduated
  concept specs written as teaching arcs. A reader can answer "what is Ring
  N, what may it import, and what can I do with only that ring" from the
  guide alone.
- **The guide is designed** — a coherent visual system (drawing-office
  chrome with monograph body typography): a sheet frame and title block on
  every page, the ring model drawn as an annotated engineering figure on
  the landing, ink code panels with paper output prints, and the
  playground retinted to the same family. Inline emphasis in prose now
  renders (the corpus carried ~900 unrendered spans). Works served or
  double-clicked (`file://`).
- **The guide is trued** — a full verification audit tested every
  checkable claim against the live binary and corrected several hundred
  stale or fictional ones: invented CLI verbs and flags, a fictional
  limits/env-var surface, wrong error codes, an inverted canonicalization
  story, fabricated binding APIs and capability-bit tables, and stale
  perf numbers. Where the docs described a surface the engine should
  have, that became a tracked decision, never a doc claim.
- **`x/term` specced** rather than retired, and `ROADMAP.md` trued to this
  release line.

## [0.15.0] — 2026-08-03

The **toolchain** release: the vendored V compiler moves from the 0.5.1-era
base to **upstream V 0.5.2**, carrying the cx fork's full memory-management
series forward — plus two sharp fixes surfaced by the upgrade's own
validation battery. Thin by design and shipped fast: the upgrade is a
foundation change worth isolating from feature work. No breaking changes.

### Changed — V toolchain (V 0.5.2)

- **`third_party/v` → upstream tag 0.5.2** (#657): the 79-patch fork series
  rebased as 76 commits (evicted add-remove pairs flattened and proven
  byte-identical first; usecache interface-index hunks superseded by
  upstream's own fix). cx compiles with **zero source changes**. In-window
  upstream wins include cgen sumtype/generic correctness fixes, `-usecache`
  repairs, mbedtls TLS-handshake hardening, and array micro-perf.
- **NEW fork patch — the vgc conservative-retention contract**: two upstream
  array changes (delete-path zeroing of vacated slots; nil-data
  zero-capacity arrays) each independently caused sweep-while-live
  use-after-frees under the cx collector at high mutator counts — invisible
  under Boehm, found by the concurrency-soundness gate at N=24 (132 oracle
  catches + 13 crashes per 15 rounds pre-fix; zero after). Under `$if vgc`
  vacated slots keep their bytes and empty arrays keep a real buffer; all of
  upstream's perf work is kept. Upstream's closure-lifetime reclamation is
  **kept on** — exonerated by the same gate once the real culprits fell.
- The #613 uncollectable contract restored at upstream's relocated
  closure-ctx allocation site; C-error telemetry (new in 0.5.2, phones
  bugs.vlang.io) defaulted **off** — opt-in via `V_C_ERROR_BUG_REPORT=1`;
  vc bootstrap pin regenerated and verified by a fresh-clone `make`.
- Validation: soundness ladder N∈{1,4,8,16,24} on macOS + N=24 in the Linux
  container — zero catches, zero crashes; full test battery + conformance
  green; perf at parity. The soundness gates now take `VFORK_ROOT` /
  `VFORK_SRC` / `VFORK_V`, so a candidate fork tree is arbitrated **before**
  the pin moves.

### Fixed

- **Embedded journal-bound ingest restored to baseline** (#662): v0.14.0's
  demand-paged store load routed every first object touch through the pack
  backend's documented *cold* path — a directory scan plus a probe of every
  pack, per call — collapsing embedded ingest 2881 → 91 events/s. Fixed
  with an object-location index (hash → pack, filled where pack indexes
  are already read, lazily repaired after folds) plus an MRU pack reader.
  **91 → 2861 events/s**; remote path, commit latency, and checkpoint boot
  unchanged; structural regression guard added.
- **`[$http:sse-connect]` sends `opts.headers`** (#661): the subscription
  GET was the one request shape that dropped caller headers, so the XSP
  proof headers required by the identity model had nowhere to ride — a
  CX-native client could not subscribe to an auth-enabled host at all.
  Managed fields stay ignored-not-errored; CR/LF injection refused.

## [0.14.0] — 2026-08-02

The **eventing + endurance** release. v0.13.0 made CX consumable; v0.14.0
makes a CX deployment survive its own success. Two arcs dominate: **cx
fabric** graduates from a design note to a served platform tier — durable
and transient event planes over XSP, with DLQ, request–reply, consumer
groups, failover, and a NATS bridge — and the **journal + store grow a
lifecycle**: rotation, tiered retention, cold archive with chain anchors,
and demand-paged loading, so cost tracks the *working set* rather than
lifetime volume. Between them sits a sustained performance campaign that
moved remote ingest from ~16 events/s to ~660, and a fail-loud sweep that
closed a family of silent-wrong-answer defects in the evaluator.

No breaking changes.

### Added — cx fabric, the eventing platform

- **fabric v1** (#518, #531): durable + transient event planes over XSP —
  embedded core, served tier (`cx fabric-serve`), XAP coordination, and a
  webhook adapter. A durable fabric stream *is* a journal stream, so
  ordering, hashing, and verification come from the journal contract
  rather than a parallel implementation.
- **Delivery conventions** — DLQ + redelivery policy (#543), request–reply
  over XSP request/reply frames (#544), and a **NATS bridge** mapping
  subjects ↔ streams/channels for legacy seams (#547).
- **XSP §5 adopted** (#560, #519): heartbeat, credit-based flow control,
  and reconnect-resume; `xsp.md` graduated to `03-approved`.
- **Multi-event publish** (#607): one wire turn, one receipt per batch.
- **Journal rotation** (#640) — `journal-rotate` / `[rotate keep-n=N]`:
  seal every stream at its own boundary, move the hot window to a fresh
  store, and record each sealed predecessor in a walkable **segment
  index**. Copy-then-swap, so a crash mid-rotation leaves the live chain
  intact; the swap *is* the eviction.
- **Tiered retention** (#636) — `[retention sweep-ms=… [stream name=…
  hot=N archive=… hold=…]]`: per-stream hot windows swept automatically,
  sealed-segment cold archive, **chain anchors retained whether a segment
  is archived or dropped** (nothing is silently lost), and a legal hold
  that suspends archival and truncation.
- **Alias remoting over CSRP** (#645): `aliases` / `aliases-set` with
  explicit per-name presence — a miss is a *server-asserted* absence, not
  a guess — plus an optional compare-and-set for conflict-safe pointer
  advances. Byte-source remotes keep the honest refusal.
- **The journal rides a served store** (#644, #655): a fabric mount can
  point at `cx-store://`, completing the self-hosted topology.

### Added — XAP

- **Actor-aware feature readouts** (#647): `readout($store, $t, $actor)`
  receives the request's resolved principal, so a per-principal lens folds
  server-side instead of shipping a full read-model to every client.
- **Event-source binding + durable cascade commits** (#582, #583): a XAP
  runtime can drive folds from a fabric subscription or journal tail, and
  its acts are externally observable rather than in-process only.
- **Serve surface**: parameterized panel routes (#578), configurable mount
  and cascade routes (#567, #570), SSE **changed-panel** frames derived
  from commits (#609), and the §3.6 context→composition resolver entry
  (#535).
- **Surfacing-response recording** (#553) — the ramp fold's second input.

### Added — language & stdlib

- **`[?loop]` with `[break]` / `[continue]`, and `[?do]`** (#550): the
  condition-driven loop and evaluate-for-effect sequencing, with
  all-explicit exits (a branch that forgets its exit word is a
  diagnostic, never a silent wrong answer).
- **`%` as modulo** (#598), joining the arithmetic family.
- **Per-thread PRNG streams + instantiable generators** (#625) —
  `[$random:new]`, `gen-*`: `[?worker]` threads no longer race a
  process-global RNG.
- **`CX-L007`** (#610): aggregation over a simple field accessor now warns
  with the sanctioned idioms — the §6.2 count-composition trap,
  machine-caught.
- **`[$store:verify]`** (#637): the whole-graph integrity pass as an
  explicit, on-demand operation.
- **HTTP query strings** reach `GET` handlers (#627).

### Performance

- **Remote journal-bound ingest: ~16 → ~660 events/s.** The arc runs
  through pipelined batch appends (#593), coalesced SSE pushes + a render
  cache (#594), fold checkpoints with suffix replay (#595), server-side
  per-event write elimination (#614), receive/push cadence (#617), and
  finally the delivery pump leaving the sequencer lock (#642) — which
  lifted the publish leg to the receive ceiling (**663/s** measured at
  K=2000, ~1.9× the post-#617 steady state).
- **Journal appends are O(delta) in store size** (#603): delta-scan
  bookkeeping + size-tiered segment folds; the daemon no longer saturates
  at idle on routine deadline polls.
- **Fold-side compaction** (#606) and **checkpoint persist off the commit
  path** (#604) bound in-memory fold growth and remove the periodic
  O(state) latency spike.
- **Demand-paged store load** (#637): opening an object-graph store
  populates only the refs layer; objects page in on first touch through a
  self-verifying getter. Measured on a 40,000-doc store: **0 objects
  resident at open vs 200,001** eagerly.
- **`bench/xap`** (#608): a CX-native throughput harness (ingest rate,
  commit latency, render cost, boot replay) with a locked scenario ladder
  in `SIZING.md`, now carrying a `hot=` window column as the primary cost
  dial.

### Fixed — fail-loud (silent wrong answers)

- **Module-imported code evaluates identically to program-context code**
  (#646): derived evaluation frames (`[?let]` / `[?loop]` / `[?for]` /
  match backtracking) dropped the lexical-position fields, so a `[?fn]`
  created under one inside a module def captured the *importing program's*
  scope. Dollar-form sibling calls raised `no callable`, bare-form calls
  silently self-evaluated to data elements, and `[?str]` interpolations
  surfaced masked CXER0100 errors — all only under `[?lib]` import.
- **`$first` returned the whole collection** for `$filter` results (#529);
  **err values vanished** in unobserved `[?let]` bindings (#530);
  **absence in call position** misdiagnosed as `no callable` (#536);
  **`[?for] [where]` calls never matched** (#537); **`[?element]` as a
  call argument arrived as absence** (#540); **`[?async]` never ran
  without `[?await]`** despite §10.5.1 specifying eager spawn (#541).
- **`$cx:emit` emitted unescaped single quotes** inside single-quoted attr
  values, so output re-parsed wrong or not at all (#563); **CXPath over an
  `[err …]` yielded zero matches**, turning parse failures into silent
  empties (#565); a **parsed MapNode was unnavigable** (#618).
- **Store integrity**: `put-doc` of an element tree failed to round-trip
  (#564); collection kind flipped across put/get (#566); replayed record
  scalars lost string typing (#620).

### Fixed — durability & concurrency

- **Crash consistency** (#624): the journal store corrupted on unclean
  shutdown, then SIGBUS'd or refused on reopen. Two-pass replay with a
  structural torn-tail discard; 0/40 corrupt across a kill-at-any-point
  harness.
- **Shared same-root store handles** (#628): two writable in-process opens
  of one root collided on segment numbering — they now share the live
  handle or refuse loudly.
- **SEGFAULT in `store_cxpack_load`** when a source pump re-opened a
  `file://` journal already open in-process (#613, with the underlying
  fork-side GC fix).

### Fixed — toolchain, build, packaging

- **Public mirror builds from a clean clone** (#491, #504): the V
  bootstrap and fork makefiles no longer float on remote HEADs.
- **Self-contained darwin artifact** (#573): RE2 vendored and linked
  statically, dropping the Homebrew/abseil dylib chain.
- **WSL2 source build** (#643): root-caused to an uninitialized submodule
  plus a stale fork branch; the patch branch now tracks the pin.
- **Bindings**: the retired `:table[` opener purged from Go/Rust/Python
  (#509); Rust `arrow`/`parquet` features compile (#511); six Python test
  files wired into a Makefile lane (#512).
- **Test harness**: daemon-spawning tests tether their daemon's lifetime
  to the spawner (#648), and the in-module suite gained the same
  classified-retry contract as the black-box suite.

### Notes

- The **CX partition** (#516) — ring extraction per use case — remains the
  next release's headline and is unchanged, deliberately design-gated.
- The hosted `https://cxhome.org/install` one-liner is still blocked on
  GitHub Pages certificate issuance (#508); install from the release
  artifacts or from source.

## [0.13.0] — 2026-07-16

The **platform + consumption** release: the cx store grows a
content-addressed engine and a single-node production service tier, XAP gains
the full feature-distribution pipeline, build-gated database access to
external engines lands, and a deep reliability campaign hardens the whole
serve plane. One breaking change (store scheme cutover, under **Changed**).

### Added — CLI & consumption surface (the July release-readiness campaign)

- **`cx select 'PATH' [FILE]`** — first-class CXPath query verb: canonical-CX
  matches one per line in document order, attr-value unwrap, exit 0/1/2
  (owner decision on the former misc/cli.md phantom; the spec's `cx run` /
  `[?print]` / `[?return]` fictions are deleted) (#462).
- **`cx FILE --data=INPUT`** binds the companion document as `$doc`/`$input`
  on the run surface (caller input wins over in-document data roots), and
  **unknown flags are hard exit-2 errors** — the silent-swallow class that
  left four flagship tours running empty is gone (#415). All four tours run
  end-to-end as documented.
- **Registry-driven help** — one `SubcommandSpec` table drives dispatch and
  `--help` (all 20+ verbs listed, uniform per-subcommand `--help`, capability
  flags and conversion lanes derived from code, not prose) (#417); `cx demo`
  rewritten to current surface with fail-loud steps (#418); `cx version`
  verb (#426); shell completions rebuilt from the dispatch with a drift gate
  (#423).
- **Hosted install** — `curl -sSL https://cxhome.org/install | sh`:
  platform-detecting installer with SHA-256 verification, served from the
  Pages site bound to `cxhome.org`; `docs/dev` operations guides published to
  the public mirror (#426).
- **Public clean-clone integrity** — the V fork pins its `vc` / tcc /
  macports-legacy bootstrap inputs (deterministic offline builds), the
  public mirror ships the submodule + a curated CI that only calls public
  targets, and public `make test` runs under a real C compiler
  (#491 #504 #505).

### Added — lossless conversion contract

- **The `$tag` envelope**: `--lossless` JSON and YAML now recover element
  documents **byte-identically** (strict-canonical eq) — element-vs-map
  shape, attr-vs-child distinction, mixed-content run order, anchors/merges/
  ids, and `[table]` payloads all survive (owner decision 6b; conversions.md
  §2.2.1/§2.3.1) (#475).
- **Typed value carriers**: per-object `cx:type` sidecars (JSON) and
  `!!cx:T` tags (YAML) for atoms/decimal/bigint/dates/durations; per-item
  carriers in array positions; non-string map-key sidecars; bytes emit
  base64 per the spec table (#444 #458 #485).
- **Table images in every lane** — XML `cx:cols`/`cx:row` (lossless
  round-trip), AST-JSON `cols`/`rows` with import inverse, Markdown GFM pipe
  tables, ast-bin v9 table records, semantic-projection `_` convention for
  attrs+table (#413 #443 #464 #478).
- **YAML import correctness** — block sequences of mappings import complete
  (the silent data-loss class), flow collections (`[1, 2]` / `{k: v}`) parse
  as real containers, and the emitter stops over-quoting (#412 #440 #441).

### Added — documentation, guide & examples

- **Guide rebuilt and gate-protected**: fail-loud build (a failing section
  kills the render), a snippet gate that executes every taught example
  against the live binary, and a retired-surface scan that catches
  parseable-but-wrong forms; ~65 stale taught examples rewritten to current
  surface (#425).
- **Four new guide sections** — capabilities & permissions (`--allow-*`),
  operations (process model, env knobs, daemon smoke-tested), the store
  platform, and XAP feature distribution — every command verified live;
  the guide now renders 20 sections (#425 #450 #476).
- **Examples overhaul** — modern `[table[…]]` demos (typed columns, CSV
  lane, eq round-trip), a `.cxs` schema + `cx validate` walkthrough, a full
  README index, format companions regenerated by `make examples-regen` so
  they cannot drift, and the playground wasm/examples publish made
  structurally atomic (#424).

### Added — editor tooling

- **Neovim**: the vim-regex fallback is usable again (first `[; ]` comment
  no longer swallows the buffer; numbers, dotted atoms, CXPath axes, `#id` /
  `@ref` / `&anchor` all highlight), the tree-sitter grammar no longer
  corrupts on `#id`, a 17-case corpus suite guards it, the parser installs
  as a universal binary (Rosetta Neovims), and ftplugin/indent files ship
  (#420).
- **VS Code**: the packaged extension actually runs (esbuild-bundled LSP
  client — the old `.vsix` crashed on activation), the grammar catches up
  three surface cutovers (DC directives, nested-directive highlighting,
  prefix predicates, triple-quoted strings, lexicon-true numerics), snippets
  are all valid current surface, and packaging is reproducible (#422).
- **Shared**: LSP docs mirror the live `initialize` capabilities, the
  TextMate grammar is single-sourced with a byte-identity check, and the
  approved bracket de-emphasis scopes are implemented in both editors
  (#423).

### Added — cx store: content-addressed engine

- **Content-addressed multimodel store engine** (Phase 1; #75 #80–#89) — a
  universal subtree object model across substrates (mem / file / sqlite / s3)
  plus a document model, on one canonical URI surface (#129).
- **Incremental cxpack persistence** — segment packs, append-only manifest,
  compaction; xor8 membership filter; inline-node object format; object-graph
  introspection (object count + dedup ratio) on `/metrics` (#129).
- **Pluggable storage seams** — the storage-backend seam and the object-level
  `ObjectBackend` seam (#76); a columnar Parquet/Arrow document backend.
- **Networked backends + CSRP** — s3 / http / ftp / sftp substrates and the
  `cx-store://` remote protocol (#78 #90 #91 #100 #106); remote `store:query`
  pushes filters to the server instead of returning silently empty (#119).
- **Encryption-at-rest** on the pack, object-per-key, sqlite, and s3
  substrates — AEAD envelopes, KMS seam, fail-closed in both mode
  directions (#114 #229).
- **Two-tier identity** — Tier-1 lock-and-name + Tier-2 code identity
  (`put-def` / `get-def`) (#79 #82), with strict-canonical
  anchor/alias/merge expansion per canonical.md.
- **Directory tree ⇄ store ingest/sync** — dir-sync recipe (`.cx` code +
  `.cxd` data), continuous filesystem watch on real inotify/FSEvents, CX code
  storage (#128); `[$store:modify-doc]` completed: nested-target select,
  child remove, CXPath step predicates, and the `[using FN]` computed
  per-node replacement action (#134 #141).

### Added — cx store: production service tier (#105)

- **`cx store-serve`** — a multi-threaded CSRP daemon: static / JWT / DID /
  OIDC authN, RBAC + store-per-tenant isolation, Prometheus `/metrics` +
  OTel traces + structured logs, sd_notify health probe, systemd/Docker
  deploy artifacts.
- **gRPC interface** with normative CSRP parity — full op surface
  (iter/query/modify), concurrent multiplexing, and the `cx-store+grpc://`
  client transport; HTTP/2 hardening (CONTINUATION cap, RFC error codes,
  strict proto3 decoder) (#222 #223 #224).
- **Wire & lifecycle** — CSRP binary wire (cxbin bodies + length-prefixed
  frame stream) on client and server (#182 #196); HTTP/1.1 keep-alive and a
  client connection pool (#234); graceful drain with readiness-probe grace
  (#233); capability discovery at open.
- **Admin plane** — status / gc wire ops and tenant-filtered mounts
  enumeration, with gRPC parity and CX bindings (#248); **runtime config
  reload** — validate-then-swap engine, SIGHUP + config-reload op, live TLS
  cert rotation (#251).
- **Client libraries** — thin Python / Go / Rust clients driven through the
  one V protocol core, with query/iter and typed errors (#197).
- **Phase-2 hardening waves (W0–W15)** — data-loss closed (op-lock
  serialization, persist-error propagation, S3 auth honesty, wire CAS:
  #213 #217 #218 #220 #221); lifecycle (cxobj open, TLS bind, env-secrets,
  watchdog, bounded drain, framing: #180 #181 #183 #186 #187 #199 #211
  #219); silent-partial guards (#185 #192 #209); observability (child
  spans, context propagation, byte counters, async OTel export: #200 #202
  #207); fail-closed residuals (unknown-store CXER1710, subtree+/compression:
  #203 #204 #205); CSRP wire-conformance parity matrix (#208).
- **Store management console contract** locked in the approved spec, plus the
  `cx store-token` bootstrap helper (#249). The console itself ships from its
  own repo.

### Added — XAP feature distribution

- **The distribution staircase (M0–M6)** — the composition engine
  (`[$xap:compose]` / `compose-report` / `resolve` / `grammar-hash` as pure
  builtins, integrated compose→runtime); packaging (`pkg-tree` / `pkg-seal` /
  `pkg-sign` / `pkg-publish` / `pkg-fetch` / `pkg-verify` / `pkg-install` /
  `pkg-requires-closure` / `pkg-catalog`); entitlement VCs (`license-issue` /
  `license-verify`); git-repo-as-registry; the market dogfooded as a XAP.
- **The deployment host** — `[$xap:host]`: a XAP server is data plus
  adapters, zero bespoke server code; `pkg:` module loading + the feature
  runtime contract; host extend seams (adapter-first routing, prefix routes,
  host-push, apply-refusal).
- Specs: the grammar-composition algebra and the feature distribution &
  market spec (02-working); the market-as-a-product and payment rails remain
  specified, not implemented.

### Added — database access: external engines (build-gated)

- Engine-neutral SQL/K-V surface — `[$sql-open]` / `[$sql-exec]` /
  `[$sql-query]` / `[$sql-close]` and `[$redis-open]` / `[$redis-cmd]` /
  `[$redis-close]` — with per-engine builds: `-d cx_db_sqlite`, `-d cx_db_pg`,
  `-d cx_db_mysql`, `-d cx_db_redis`; Parquet / Arrow-IPC file I/O behind
  `-d cx_arrow_files` (also `cx table dump/load --to=parquet|arrow`). The
  default build links none of them and says so (CXER1100); opens are
  capability-guarded.

### Added — language & stdlib

- **Full lossless JSON / YAML lanes: the `$tag` structure envelope** (#475,
  folding in #485 item 2) — `cx --to=json|yaml --lossless` now emits element
  documents as a reserved `$tag` envelope (`$tag` / `$anchor` / `$merge` /
  `$id` / `$type` / `$ref` / `$attrs` + `$attr-types` / `$children` /
  `$cols`+`$rows`; multi-root under `$doc`), so a CX→json|yaml→CX round-trip
  recovers the document byte-identically (strict-canonical eq): element-vs-map
  shape, attr-vs-child distinction, mixed-content order, anchors/merges/ids,
  tables, and typed values all survive. Typed values gain position-independent
  carriers: the per-item `{"cx:T": …}` JSON carrier for array positions and
  the `cx:key-type` sidecar for non-string map keys (YAML rides its native
  tags). User keys that look reserved escape behind `cx:k:`. Import
  reconstruction is unconditional (reserved `cx:`/`$` protocol shapes), the
  default idiomatic lanes are untouched, and the whole `examples/*.cx` corpus
  round-trips through both lanes as a conformance matrix
  (conversions.md §2.2.1/§2.3.1).
- **Graded similarity: the `~` core operator + `cx-stdlib/similar`** (#108) —
  `[~ a b]` / `[~ a b $pred]` returns a `[similar score=… band=…]` element
  (truthy iff `band=:match`), defined once and applied uniformly: cxpath
  predicates (`//vendor[~ $_@name "x"]`), `[?match]` `when` arms, `[?if]`, and
  the collection verbs. New core verbs `join` (labeled linkage,
  `:greedy-best`/`:top-k`/`:all-above`/`:optimal` Hungarian selection),
  `sort` (ranking, `similarity-to` keys), vocabulary `validate`; `contains`
  gains sequence membership + graded best-match; `distinct`/`group-by` gain
  predicate-driven clustering (`:transitive-closure`/`:complete-linkage`/
  `:singletons` with cohesion). Module ships ten scorers (Jaro-Winkler,
  Levenshtein, true Damerau-Levenshtein, token-set/sort, Jaccard, cosine,
  Double Metaphone, numeric, temporal), ft-delegated normalizers, per-field
  weights, caller-supplied decision cuts (never baked in), and the
  known-verdicts resolutions tier for review-resume. Errors CXER4900/4901.
- **`cx-x/adjudicate`** (#376) — out-of-band agent adjudicator for the
  `similar` review band: consumes review-band `[pair …]` elements and
  produces the `[resolution verdict=… decided-by='agent:<model>' …]` records
  the known-verdicts tier consumes, composing `cx-x/llm:complete` under a
  scoped net grant. Runs *between* runs — each run stays deterministic;
  unparseable model replies default to `:review` (never silent promotion).
- `[?str]` interpolation holes accept full expressions (#66).
- Raw triple-quoted strings `r'''…'''`; `strings:replace-exactly` +
  `io:edit-file` surgical text edits (#93).
- `cx-x/term` — raw-mode terminal input + `term:select` multi-source
  wait (#30).
- One concurrency-degree spelling: `[par N]` / `[par max]` (#95); `[par]`
  redesigned to own its width — bounded pools, real for-par, HTTP fail-loud
  cap (#94).
- CX-L006 lint — flags pure single-binding `[?let]` staircases
  (detect-only) (#65).

### Reliability — concurrency & memory

- **The `#57/#58/#63/#145` GC sweep-while-live UAF lineage is root-caused and
  fixed** — the allocator fast paths were not atomic w.r.t. the async-signal
  stop-the-world: a mutator frozen mid-allocation could have its tiny-allocator
  cursor invalidated (→ near-NULL buffer handed out, the field `string_clone`
  SIGSEGV) or its in-flight slot claim swept out from under it (→ one slot,
  two owners). Concurrency-soundness gate green at every reactor/worker count
  on macOS and Linux, including under CPU-load amplification.
- **Concurrent `[?worker]` threads are the default** — `[?worker]` now runs
  its body on its own thread, matching the spec's "runs concurrently with
  siblings" semantics (§10.4.6). The interim synchronous run-to-completion
  default (kept while the UAF above was open) is retired;
  `CX_WORKER_THREADS=0` remains as a diagnostics-only escape hatch (#58).
- **The per-`[?let]`/`[?for]` full-environment clone is gone (#272)** — the
  evaluator no longer clones the whole environment per binding/iteration
  (loaded p99 latency 692 → 61 ms in the field case that surfaced it);
  the pacer livelock at the soft heap limit is fixed with it.
- **vgc adaptive pacer (#71)** — transient allocations are reclaimed by
  construction; the per-loop collect crutches are retired; a distinct
  thread-return-box UAF fixed.
- **Terminal heap exhaustion dies loudly (#277)** — an OOM panic with
  forensics (arena census, allocation site) instead of a SIGSEGV in the next
  array growth; `VGC_MAX_ARENAS` can lower the ceiling for testing.
- **Store `file://` persist and open are fully streamed (#283)** — the
  monolithic whole-index encode/decode buffers (a heap-staircase death
  trigger past 64 MB) are gone from both the snapshot and replay paths.
- Churn-paced reactor GC bounds `http:serve` RSS (#131); signal-suspend STW
  on macOS makes multi-reactor `http:serve` sound on macOS + Linux (#145).
- Deterministic worker cancellation — blocking channel send/receive are real
  §10.5.4 cancellation points.

### Reliability — serve plane & networking

- **Handlers run off the reactors** — reactors do I/O only; a bounded
  executor pool runs handlers and overflow answers 503, so a slow handler can
  no longer freeze the HTTP plane (#275).
- **SIGPIPE immunity + backpressure-correct fd writes** on the serve path —
  a peer RST no longer kills the process (#273 #276).
- The whole-request HTTP client timeout is enforced — CXER4534 (#275).
- Datagram sockets honor read deadlines — `recv` / `recv-from` raise
  CXER4507 instead of blocking forever (§3.7).
- SSE subscribe ack is atomic with topic registration — no missed-push
  window (#28 #124).

### Changed

- **Element-construction attributes are strictly scalar (breaking; owner
  ruling on the code.md §6.4.1 / validate.md §3.5 conflict)** — any
  non-scalar evaluated attr value raises `CXER0100` with a child-element
  hint; the canonical-stringify seam is removed. validate.md's structured
  vocabulary moves to child elements (`[enum v …]`, nested `[schema …]`,
  `[extends $Base]`); the retired attr spellings fail loud (`CXER1603`)
  with migration hints (#466).
- **Hex literals under `::decimal` / `::bigint` reject** with `CXER0109`
  (base-10 value types; previously stored `'0x2a'` verbatim). The whole
  ascription family coerces from the ORIGINAL source token in both engines —
  `[hash::bytes 0x3a7bd3e2]` no longer int-coerces (and 8-byte hex no longer
  silently clamps to i64-max) (#457 #466).
- **Program mode gains the `name::T=value` attribute-ascription production**
  (lexicon [L50] parity with the data reading); glued `name@attr` tails on
  rooted paths are a targeted parse error pointing at the spec'd `/@attr`
  spelling (#466 #472).
- **CXPath predicate sublanguage retired (breaking; #110)** — `~` means
  "approximately" everywhere and every construct has ONE spelling: the
  XPath-parity infix predicates (`[@a=v]`, `!=`/`<`/`<=`/`>`/`>=`), paren
  function calls (`count(*)`, `last()`, `position()`, `name(args)` and
  `$f(x)` anywhere), infix `and`/`or`, `instance of`/`cast as`, infix
  `union`/`intersect`/`except`, and `||` are parse errors with prefix
  rewrite hints. Predicates are homoiconic CX code with FUSED brackets
  (`//user[= $_@id 991]`, `//u[$flagged $_]`, `//u[?match $_ …]`); the
  operator-free notation atoms (`[N]`, `[@name]`, `[@!name]`, `[name]`)
  stay. Set operators became reserved prefix heads valid in every
  expression position (`[union a b]` / `[intersect a b]` / `[except a b]`).
  Missing-attribute reads yield absence per code.md §6.2 O4 (never crash;
  comparisons with absence are false; reads through `[err]` propagate the
  err). Migration: `cx fmt --migrate-predicates -w FILE...` (fail-closed,
  island-aware for `.cxd`/`.md`); the full repo was swept. The ft query
  model moved to a canonical `[query …]` element with `[$ft:parse-query]`
  as the only string-format consumer (#111).
- **Store scheme cutover (breaking)** — the non-canonical `cxpack://` /
  `cxobj://` scheme tokens are retired: bare `file://` is the universal
  subtree model, `document+<substrate>://` the document model, and
  `?encoding=pack|object-per-key` selects the framing. Stores reopen
  self-describing from the on-disk marker; a URI contradicting the on-disk
  form is a hard CXER1120 (#129).
- `CX_HTTP_WORKERS` → `CX_HTTP_N` (deprecated alias kept) (#97).
- Honest labels: `[?bulkhead]` is marked experimental; `[?timeout]` is
  documented as logical-clock (#96).
- xap.md state model resolved to snapshot-anchored event-sourcing
  (hybrid) (#35).
- Specs graduated to 03-approved: store.md (the faceted #129 surface), the
  gRPC interface, Tier-2 code identity, the store-management console; the
  Phase-2 wire canonical, CXER1709/1710, and capabilities scope
  reconciled (#182 #203 #204 #205 #214 #215 #216).

### Fixed

- Floats obey the numeric truthiness rule everywhere (cxdm.md §6 rule 2 —
  value ≠ 0): `[?if 0.98 …]` no longer silently takes the else branch. The
  shared `[?if]` / `[?match]`-guard / `[$not]`/`[$and]`/`[$or]` /
  filter-predicate EBV site treated every float as falsy (#382). The
  `not()` truthiness enumeration in code.md now names floats explicitly.
- CXPath predicates no longer keep elements whose tested attribute is
  ABSENT: `//pair[$_@score]` read the absence marker as a truthy named
  element instead of the empty sequence (#384).
- One EBV authority for every boolean position (#383, owner ruling: the
  cxdm.md EBV table wins wholesale over code.md's old not() prose row). A
  present named element is truthy by presence — `[?if [flag]]` and the
  `[?if //flag]` existence idiom hold for empty marker elements — and a
  singleton sequence wrapper recurses into its item, so `[?if (0)]` is
  falsy like `[?if 0]`. Bare `[not x]` and `[$not x]` (which disagreed on
  empty named elements) now share one EBV fn and agree by construction;
  containers keep the empty-is-falsy convention (`[]` / `{}`); truthiness
  now also reads through `[?meta]` in `$`-head/guard positions (D5).
- An Iterator in a boolean position raises a loud, catchable `CXER0100`
  instead of reading silently falsy (#388, owner ruling): EBV never forces
  a lazy stream — network-backed source kinds would block or perform I/O
  inside a condition — so `[?if [$range 1 *] …]` now errors with guidance
  to force explicitly (`[take]` / `[$count]` / a `[?for]` bound) and
  `[?fallback]` catches it. Finite `[$range lo hi]` stays an eager
  Sequence with ordinary sequence EBV. cxdm.md's EBV table and the
  code.md `not()` row both state the rule.
- A space-separated atom after a path step no longer folds into a phantom
  QName attribute name (`[= $e@kind :active]` misread as attribute
  `kind:active` → CXER0100): PROGRAM-mode QName folding now requires byte
  adjacency, matching DATA mode's in-name scan (grammar [131b], lexicon
  [L11]). Attribute reads and `@attr=$k` pattern captures yield the
  attribute's **typed** value per cxdm.md §2.4 — `kind=:active` reads back
  `:active`, never the string `'active'`.
- Deep NON-tail eval recursion never SIGSEGVs: a per-thread native-stack
  watermark raises the catchable `CXER0272 E_STACK_EXHAUSTED` with ~1 MiB of
  headroom left (worker threads guarded with their own bounds; tail calls
  stay trampolined), and the per-level C-stack footprint dropped ~16% (#319).
- The V fork's `return f()!` lowering forwards the callee's result directly
  when the result types match — the three dead `_result_T` stack temporaries
  plus payload-sized compound literal per call site are gone compiler-wide,
  making PR #325's hand-rewritten bare-return idiom unnecessary (#327); the
  eval dispatch/tail resolvers look up `env.closures` through the fork's new
  by-ref `unsafe { m.value_ptr(k) }` map get instead of copying the
  ~450-500 B Closure into an option temp per lookup — tail loop ~1.2% /
  dispatch ~0.7% faster, 15% less at the lookup seam itself (#342).
- `v test` works again inside the fork's `bench/parallel-alloc/` — the
  standalone RSS drivers moved into per-program subdirs so their module-main
  symbols no longer collide with the dir's test builds (#337).
- `cx fmt` no longer destroys program files on save (#118).
- Element-construction attribute values that cannot round-trip fail loud
  (CXER0100) instead of silently dropping; a bare URL attribute value in a
  program fails with a quote-the-value hint.
- Program-shaped resources fail loud on program-parse failure — no silent
  data echo.
- Verifiable credentials survive serialization round-trips — offline VC
  portability (verify + revocation checks) was broken.
- Store fail-open paths closed: CX-map open opts (e.g. `encrypt-key-id`) are
  honored instead of silently dropped, and the deployment host surfaces
  apply errors (#259); remote alias ops refuse with CXER1709 (#271).
- `cxstore file://` append-only index kills the O(n²) persist; a `[par]`
  shared store handle raises a clean error (#74).
- Nested user-def calls apply in argument position (#59); infix `=` in
  `[where]` fails loud — no silent data-fallback (#18).
- Playground examples run clean, enforced by a drift gate (#92).
- Deployment-host fixes surfaced by the first field consumer, including
  `pkg-install` enable merging into an existing same-name deployment row.

### Tooling & internal

- The vcx test gate builds with `-usecache` (~1.5× faster, 2.4× less
  compile), with deterministic `$embed_file` resolution and embedded-asset
  cache invalidation (#151).
- Release automation publishes the public binary release with a flat,
  stable-named asset; install docs point at the current repo home.

## [0.12.0] — 2026-06-22

The reliability release. Authoritative release-surface document:
[`RELEASE_NOTES_v0.12.0.md`](RELEASE_NOTES_v0.12.0.md). One breaking change
(block comments unified on `[; … ]`); everything else is backward-compatible.

### Reliability — concurrency & memory

- **Tail-call optimization** — trampolined tail self/closure calls run in O(1)
  native stack; loop-shaped recursion no longer SIGSEGVs (#60).
- **Cooperative-safepoint STW is the default `-gc e` collector** — multi-reactor
  HTTP (`CX_HTTP_WORKERS>1`) and concurrent `[?worker]` threads are sound by
  construction; revert with `-d vgc_legacy_stw` (#63 / #58).
- HTTP reactor heap bounded by a heap-growth collect (#57); HTTP serves
  multi-reactor by default (`min(4, cores)`), tunable via
  `CX_HTTP_WORKERS=N|max|1`.
- Streaming `data-bin` writes bounded under `-gc e` (#52); `[?for]` no longer
  deep-copies the shared closures table per item (#62).
- Concurrent `[?worker]` threads behind `CX_WORKER_THREADS` (#58).

### Changed

- **Block comments are `[; … ]` only** — `[- … -]` / `[-- … --]` retired as
  comments; `[- a b]` is always subtraction (breaking; migration in the
  release notes).
- `cx <file>` renders every top-level form, not just the last (#16).
- `--allow-net` no longer bypasses the §4.5 SSRF deny-set; only `--allow-all`
  does (#47).

### Added

- `cx-stdlib/strings` `to-number` / `to-int` / `to-float` — locale-free
  string→number parsing, absence `()` on non-numeric input (#54).
- Concurrent SSE push on the `serve` path — topic pub/sub (#28).
- `cx -` (stdin) and `cx -e EXPR` (inline) evaluation.
- `tools/vgc-debug/` precise-GC debugging toolkit (#70).

### Versioning (#67)

- `VERSION` is the enforced single source of truth: every surface derives or is
  stamped from it; `check-version-consistency` scans `vcx/`, `spec/`,
  `docs-src/`, `stdlib/`, `tooling/` and fails on a stray `vX.Y.Z`.

### Fixed

- Silent-wrong / data-loss: idiv/mod/div reject bigint+decimal (#38); JSON/YAML
  `:table` emit projects rows (#10); `[?for]` over a collection-valued map
  member iterates members (#21).
- Fail-loud: `[?def]` body errors surface (#46); set-deadline/set-opt reject
  std-streams (#29); accept-iter surfaces a non-responding handler (#23);
  read-all/read-line/line-iter honor the read-deadline (#56); zero-arg def is
  callable (#55); bareword recursive def dispatches (#53).
- Lossless YAML (#4) and TOML (#5) import.
- Pure-data resource self-evaluates (#11); HTTP waits for the full POST body
  (#48); `[?select]` diagram arrows (#27); `cx:parse` single-root navigable
  (#39); `[where]` infix error points at the prefix form (#18); `cx-v` package
  ships transport/+x/ and builds with clang (#15).

## [0.11.0] — 2026-06-18

The agentic-substrate release. Authoritative release-surface document:
[`RELEASE_NOTES_v0.11.0.md`](RELEASE_NOTES_v0.11.0.md). Backward-compatible.
(Changelog entries for 0.9.0–0.10.1 live in their `RELEASE_NOTES_v*.md`.)

### Added

- **`cx-x/` agentic tier** — the Runnable convention + combinators
  (`cx-x/run`), an LLM provider (`cx-x/llm`), MCP client + server
  (`cx-x/mcp`, `cx-x/mcp-server`), and A2A (`cx-x/a2a`, `cx-x/a2a-xap`:
  tasks→journal, messages→bus, DID/VC auth).
- **Stdlib modules** — `did` (`did:key` + `did:web`, base58btc), `vc`
  (verifiable credentials) + `session/attach-did`, `jsonrpc` (JSON-RPC 2.0),
  `jsonschema` (JSON Schema 2020-12, MCP subset).
- **XAP** — real authz-backed PEP; feature augmentation/overlay composition
  + coordination channel; XSP frame codec; DID/VC identity for all actors.

### Changed

- **Uniform lexical scoping (#19 / #22)** — callables resolve free names in
  their defining scope (imported module siblings call each other; `[?const]`
  in a `[?def]` body dereferences).
- **CX decoupled from the V fork** — transport vendored into `vcx/transport/`,
  dormant scope-region path retired; the patched-V fork is now CX-free
  (Bucket-1 only). No runtime-behavior change. See
  [`spec/03-approved/process/v-dependency-management.md`](spec/03-approved/process/v-dependency-management.md).

### Fixed

- **#45** — escaping/nested closures keep their environment (zero-arg def,
  module def, and re-capture cases).
- **#20** — module loader ignores `[?lib]`/`[?def]` inside `#` comments.
- **#42** — `cx fmt` accepts operator-head expressions.
- **#39** — namespaced `[$<codec>:parse]` / `:emit` accepted.
- **XAP** — `emit` routes by intent verb; `[?for]` view-closures survive loop scope.

## [0.8.0] — 2026-06-09

The "data + code" unification release. CXPath becomes a first-class
value kind; `[?match]` learns multi-arm dispatch; `[?modify]` introduces
pure-functional updates with structural sharing; a module system with
bundled stdlib lands; atom joins the scalar kinds. v0.7.6 was an
internal design pass (never released); its scope merged into v0.8.0.
Tier-1 bindings narrow to V / Python / Go / Rust under a two-layer
contract ([`spec/03-approved/misc/bindings.md`](spec/03-approved/misc/bindings.md)). Authoritative
release-surface document: [`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md).
Live gate state was tracked in `spec/v0_8_0_status.md` (retired with the spec-tree reorg).

### Added

- **CXPath as first-class value kind** — all 12 XPath 3.1 axes, `//` /
  `/` step prefixes, `@name` attribute selector, `[expr]` general
  predicates with `$_` / `$_position` / `$_last` context bindings,
  `:bind NAME` peer-modifier on path steps.
- **`[?match]` multi-arm dispatch** — heterogeneous arms (`:case` /
  `:when` / `:else`); first-match-wins; scalar literal + `_` wildcard
  patterns.
- **`[?modify]` pure-functional updates** — CXPath focus + 11-action
  vocabulary (`:set`, `:delete`, `:using`, `:rename`, `:set-attr`,
  `:delete-attr`, `:append`, `:prepend`, `:insert-before`,
  `:insert-after`, `:replace`); pipeline-composable via `|`; structural
  sharing (`< 1 KB` new heap per matched node on a 10 MB document).
- **Module system** — `[?def]` module-level functions (no closure / no
  overload / order-independent), `[?lib]` module loading (file /
  registered / HTTPS resolvers), `cx.lock` lockfile (SHA-384 / SHA-512
  SRI integrity, HTTPS-only transport), `[?const]` module-level
  constants, `:scope public` / `:scope private` visibility.
- **Bundled `cx-stdlib`** — 14 sub-packages: strings / json / http /
  re / time / math / io / bytes / format / path / log / hash / env /
  test. [`spec/03-approved/std-lib/`](spec/03-approved/std-lib/README.md).
- **Atom scalar kind** — `:NAME` literals with type-strict
  name-equality and a disjoint hash domain.
- **`[expr]` general predicate body** + `:pure` / `:impure` modifier
  algebra (sound-but-incomplete inference; closed-list builtin
  classification).
- **Playground Tree View + Graph View** — ERD for data sources, CFG
  for code sources; per-pane toggle; bidirectional selection bridge
  via byte-offset `loc`.
- **`cx_code_diagram`** (Mermaid emit, ERD-or-CFG auto-detect) +
  **`cx_code_tree`** (JSON with `loc` byte offsets) C ABI exports.
- **`cast()` generic builtin** + **`exists()`** in [`spec/03-approved/core/code.md` §6.5](spec/03-approved/core/code.md).
- **ast_bin v8 wire format** with PathNode kind discriminator `0x13`
  (cap bit 36).
- **42 §11.6 release gates** — 16 v0.7.6 carryover + 14 new for the
  CXPath / `[?match]` / `[?modify]` / module-system surface + 12 new
  for the playground views.

### Changed

- **Internal `programs` → `code` rename** — `spec/programs.md` →
  `spec/code.md`; `vcx/programs/` → `vcx/code/`; `cx_program_eval*` →
  `cx_code_eval*`; `_cx_program_*` wasm exports → `_cx_code_*`;
  `in_cxl:` fixture header → `in_code:`.
- **Tier-1 bindings narrowed** to V / Python / Go / Rust under a
  two-layer contract (Layer 1 canonical 16 methods; Layer 2 host
  idiom packs).
- **Cap bits 31 + 32 re-purposed** — gate-17-era framings never
  shipped per backlog `d-2026-05-22-04`; now `cx_code_diagram` + `cx_code_tree`
  for the playground views.

### Removed

- **`[?find]` directive** — replaced by `[?for]` (pattern-generator
  form) and CXPath value-kind `//path`.
- **v0.7.0-era CXL POC evaluator surface** — `cx:` module, `log:`
  module, `inspect:`, `[?cx use-module=...]`, `[?cx pure-only]`.
- **v0.7.0-era `cx_eval_cxl_*` C ABI symbols.**
- **Six archived bindings** — TypeScript / Java / C# / Ruby / Kotlin /
  Swift moved to `lang/_archived/`. Restoration is post-v0.8.0.

### Migration

See [`RELEASE_NOTES_v0.8.0.md`](RELEASE_NOTES_v0.8.0.md) for the
breaking-change table. The mechanical renames (`programs → code`,
`cxdb → cxcol`, `cx_program_* → cx_code_*`) were applied across the
codebase as part of this release.

## [0.7.6] — in development on `v0.7.6-dev` (CX code — the headline release)

As of 2026-05-20, v0.7.6 ships **CX code** — a unified
pattern/query/transform language with full integration capabilities
(visualization, resilience, services, concurrency, async). CX code
replaces cxpath and cxquery; both are removed from the codebase as
part of this release.

This supersedes the v0.7.0 "CX is one language" scope —
the full XQuery 4.0 evaluator surface and the "v0.7.0 ships the
complete evaluator" goal. The v0.7.0–v0.7.5 line is **frozen as
proof-of-concept** — see the marker at the top of [0.7.0] below. The
v0.7.0 cxpath/cxquery implementation was incomplete, with falsified
tests (passed by reduction) and partial specs. Users who need
production-ready query/transform begin at v0.7.6.

Authoritative design reference:
`spec/audits/code_design_v1.md` (audit doc, since retired)
(20 cxpath/cxquery → CX code side-by-side examples + complete §11
integration-capability specs). Normative spec
(`spec/code.md`) is in progress and is a §11.6 release gate.

### Added

**Core CX program surface** — patterns as literal CX with `$bindings`;
Scala-style for-yield comprehension; `[?find]` / `[?match]` /
`[?for]` / `[?if]` / `[?let]` / `[?fn]` / `[?def]` / `[?try]` /
`[?pipe]` directives; `|` pipe sugar; three path sigils `/` `@` `.`;
errors as `[err …]` CX values with `?` / `!` postfix; `:par` /
`[?par-map]` / `[?par-reduce]` parallelism.

**§11.1 Visualization commitment** — every directive renders to a
sequence/activity diagram per fixed rendering rules. `cx diagram`
CLI emits SVG/PNG/Mermaid; `<cx-diagram>` web component embeds in
docs/playgrounds; LSP CodeLens integration via the CX language
server.

**§11.2 Resilience directives** — `[?retry]` (with constant /
linear / exponential / fibonacci backoff and none / full / equal /
decorrelated jitter), `[?timeout]`, `[?circuit-breaker]`,
`[?fallback]`, `[?rate-limit]`, `[?bulkhead]`. Composable. Errors
in the `cx-err:CXER0140–CXER0159` range (error-namespace amendment
2026-05-21).

**§11.3 Services and clients** — `[?service :on http :port N]` with
`[resource :METHOD PATH]` children; `[?http-client :target URL]`
for outbound. Full HTTP/1.1 + HTTP/2 + TLS + streaming + multipart
+ WebSocket upgrade. Service / client error codes in the
`cx-err:CXER0160–CXER0199` range.

**§11.4 Concurrency** — `[?worker]`, `[?channel]`, `[?send]`,
`[?receive]`, `[?try-send]`, `[?try-receive]`, `[?close]`,
`[?select]`. CSP-style. FIFO per-pair ordering, locked close/drain
semantics. Channel / worker error codes in the
`cx-err:CXER0200–CXER0239` range.

**§11.5 Async / await** — `[?async]` returns `[future …]`;
`[?await]` / `[?await-all]` / `[?await-any]` / `[?await-race]`
barriers; `[?cancel]` with cooperative-cancellation contract;
`[?check-cancel]` for hot loops. Async error codes in the
`cx-err:CXER0240–CXER0279` range.

**Error code namespace expansion** — amended 2026-05-21
to reserve `cx-err:CXER0100–CXER0299` for Program runtime errors,
assigned by subsystem.

### Removed

- **cxpath** and **cxquery** implementations deleted from `vcx/`
  (replaced by CX code in `vcx/code/`).
- **XQuery 4.0 / XPath 4.0 parity scope** retired as part of the
  CX-code unification superseding the v0.7.0 scope.
- `spec/cxpath.md` and `spec/xquery_40_parity.md` retained as
  historical artifacts; `spec/code.md` is the normative spec going
  forward.

### Release gates

v0.7.6 cannot tag until all sixteen §11.6 conformance gates pass
across four categories (spec completeness, test coverage,
implementation completeness, performance floors). No exceptions, no
partial-ship fallback.

---

## [0.7.5] — 2026-05 (tagged, **proof-of-concept**)
## [0.7.0] — POC, superseded 2026-05-20

> **Status note (2026-05-20).** Everything in the [0.7.0] section
> below shipped through v0.7.5 as **proof-of-concept**. The CX code
> language work it describes (cxpath / cxquery / XQuery 4.0 parity)
> was structurally incomplete: specs carried TBD markers in
> normative positions, tests passed by reduction (covering only the
> implemented subset), and `cx:merge` shipped with material defects.
> With the CX-code unification, the entire query/transform surface is
> being replaced by CX code in
> v0.7.6. Users coming to CX for production query/transform begin
> there. Other v0.7.x deliverables (WASM build,
> `cx:`/`log:` modules) ship through their own
> trajectories and are not subject to the POC marker.

In the original v0.7.0 "CX is one language" framing,
v0.7.0 was the single-cut release that takes the
cx evaluator from the CX code 1.0 floor (v0.6.0) to **XQuery 4.0 /
XPath 4.0 parity**. That framing is now superseded.

### Added

**XQuery 4.0 expression surface (A row):**
- **`?let`** — let-binding directives in positional and labeled forms.
- **`?fn`** — inline function-value literals with closure capture.
- **`?focus`** — sugar for `[?fn :params [_] :body …]` (focus
  functions / XPath 4.0 §4.5.6.1).
- **`?match`** — pattern matching on value / type / wildcard.
- **`?try` with multi-catch** — `[?try [body, [pat1, h1], …]]` with
  literal / prefix-glob (`FOAR*`) / wildcard patterns; `err-code`,
  `err-description`, `err-value` bind in the matched handler.
- **`?fn-ref [name, arity]`** — named function references (XQuery
  3.0 §3.1.6).
- **`?partial [f, args…]`** — partial application supporting
  left-curry and middle-position `[?_]` placeholders.
- **`?str-template`** + **`?str`** — XPath 4.0 string templates and
  string constructor (directive forms).
- **FLWOR clauses on `?for`:** `:let`, `:where`, `:count`, `:while`,
  `:order-by`, `:group-by`. New `?for-tumbling` and `?for-sliding`
  windowing directives.
- **`?node-is` / `?node-before` / `?node-after`** — XPath 4.0
  §4.10.3 node comparisons.

**CXPath surface (B row):**
- **Full XPath 1.0 axis set** — `parent::`, `ancestor::`,
  `ancestor-or-self::`, `following-sibling::`, `preceding-sibling::`,
  `following::`, `preceding::`, `descendant-or-self::`, `self::`,
  plus the `..` abbreviated parent shortcut.

**Operator-token surface:**
- `xs |> f` (pipeline), `xs => f()` (arrow), `xs ! f` (simple-map),
  `'a' || 'b'` (string concat), `1 to N` (range).

**Standard fn library (C row):**
- 21 ISO-8601-backed date/time functions (current-date / time /
  dateTime, year/month/day/hours/minutes/seconds accessors,
  format-date / format-time / format-dateTime with a `YYYY MM DD
  HH mm ss` picture subset).
- Regex trio (`matches`, `tokenize`, `regex-replace`) routed through
  the libcx-vendored RE2 shim.
- Higher-order additions (`for-each-pair`, `scan-left`,
  `function-arity`, `function-name`, `function-lookup`,
  `function-identity`).
- SequenceType + casting (`instance-of`, `cast-as`, `castable-as`,
  `treat-as`, `intersect`, `except`, `otherwise`).
- JSON / XML serialize-parse (`parse-json`, `serialize-json`,
  `serialize-xml`, `parse-xml`).
- QName helpers (`prefix-from-QName`, `local-name-from-QName`,
  `namespace-uri-from-QName`).
- `doc` / `doc-available` I/O primitives.

**Map / Array runtime values (D row):**
- First-class `map:` / `array:` namespaces with the XPath 3.1
  function surface.

**Streaming evaluator (Y row):**
- `cx_eval_streaming` replaces the v0.6.0 W012 stub — pull-based
  incremental emit with a write-callback.
- Host-idiomatic streaming wrappers in Python, Go, Rust, and TypeScript.

**`cx:lang` formalization (Z row):**
- Inherited-scope resolution per `spec/i18n.md §1.3`. Every Element
  exposes the resolved BCP 47 tag via `.lang()` (V / Python / Go /
  Rust / TypeScript).

**HTMX examples (J row):**
- Five worked examples under `examples/htmx/` —
  click-to-edit, active-search, click-to-load, inline-validation,
  modal-dialog.

**Attribute-value interpolation (J0):**
- `attr=[?=expr]` parses as a single token; multiple interpolations
  per attribute are supported.

**Parquet (X row):**
- Read/write bridges in Python (`cxlib.parquet`), Go
  (`cxlib.ParquetWriteFile` / `ParquetReadFile`), and Rust
  (`cxlib::parquet::{write_file, read_file}`) per the
  no-Parquet-in-libcx policy.

**Conformance suite (L row):**
- `conformance/eval.txt` grows from 28 to 54 fixtures covering the
  v0.7.0 evaluator additions.
- Python / Go / Rust binding-side conformance runners consume the
  canonical `conformance/data_bin_arrow.txt` (14/14 each).

**Operational artifacts:**
- `scripts/reproduce_release.sh` + `docs/reproducible_builds.md`
  (BB row).
- `scripts/fuzz_cx.py` + `docs/fuzzing.md` (CC row).

### Changed

- **C ABI rename** (G row): `cx_eval_cxl` → `cx_eval`,
  `cx_eval_cxl_with_len` → `cx_eval_with_len`,
  `cx_eval_cxl_streaming` → `cx_eval_streaming`.
- **`cx-version` attribute** → **`cx-eval-version`** with the
  former accepted as a deprecated alias.
- **Spec / file renames** (F row): `spec/code.md` → `spec/eval.md`,
  `examples/cx/` → `examples/cx/`, `conformance/code.txt` →
  `conformance/eval.txt`.
- **CX-database direction record** renamed from
  `cxdb-as-database-direction` to `cx-database-direction`. The `cxdb` /
  `.cxdb` binary file format keeps its name; the deferred engine
  direction is now called "CX database".
- **Active-binding set** (D4 / H row): cut from 9 to 5 — V, Python,
  Go, Rust, TypeScript. The five frozen bindings live under
  `lang/<name>/frozen/`.
- **Strict xs: constructor parse** (U8): `xs:integer`,
  `xs:double`, `xs:decimal`, `xs:float`, `xs:nonNegativeInteger`,
  `xs:positiveInteger`, and `cast-as` now raise `cx-err:FORG0001`
  on unparseable string inputs. Pre-v0.7.0 they silently coerced
  to 0/0.0. Callers depending on the old fallback must add a
  `[?try]` wrapper or a `[?castable-as]` guard. Numeric-input
  truncation (`xs:integer(1.7) → 1`) is unchanged per
  XPath §19.1.2.

### Removed

- The W012 `cx_eval_streaming` stub is gone — replaced by the real
  streaming implementation.

### Documentation

- v0.7.0 status tracker (since deleted) — per-row tracker for
  the 22-row v0.7.0 scope (A through CC).
- `spec/xquery_40_parity.md` — per-feature inventory of the
  XQuery 4.0 surface vs cx's coverage.
- `spec/abi.md §2.11` — Arrow C Data Interface version-targeting
  policy (W8).
- `docs/reproducible_builds.md`, `docs/fuzzing.md`.

## [0.6.1] — in development

### Added
- **`cx_eval_cxl` wired into all 10 bindings** — Python, Go, Rust, Ruby, Java, Kotlin, C#, Swift gained idiomatic `eval_cxl` / `EvalCXL` wrappers (TypeScript and V already had it). program evaluation is now reachable from every binding.
- **CX code quickstart block** in all 9 per-binding READMEs — same fleet/svc example across languages.
- **`cx eval -e <expr> -d <data>`** — inline expression and inline data flags for one-liner program evaluation without files.

### Fixed
- **Parser preserves `#` line comments + block comments with commas/apostrophes** — array-literal misrouting at `[-` / `[!` / `[|` / `[#` brackets fixed; line-comment text now round-trips through `cx fmt`.
- **`tools/release-verify.sh`** — restored doc-presence checks for `RELEASE_PROCESS.md` / `EVALUATION_EXPERIENCE.md`, and fixed over-escaped `\.claude/`/`\.cache/` grep exclusions in working-tree-clean check.

## [0.6.0] — 2026-05 (planned)

The **API/format-stability boundary**. From 0.6.0 onward through
1.0, no breaking changes to the public surface (C ABI, binding APIs,
wire formats, spec-normative grammar).

### Added
- **17-member Public Table API** — shipping in all 10 bindings (V native, V-cffi, Python, Go, Rust, Java, TypeScript, C#, Kotlin, Swift, Ruby).
- **Collection literals** — first-class `seq[T]`, `arr[T]`, `map[K, V]` with cross-emitter parity.
- **`cx table` CLI subcommand** ( §D1) — `info` / `dump` / `load` verbs.
- **`cx demo` subcommand** — self-contained 60s-tier showcase per the evaluation-experience checklist.
- **`cx scaffold <kind>` subcommand** — typed, commented skeletons for config / data / doc / log / table.
- **CSV / TSV / PSV via `--csv` / `--tsv` / `--psv` CLI flags** — delimited conversion now CLI-accessible (was C-ABI-only).
- **Streaming-write event API** (capability bit 27) — Tier 1 + Tier 2 + CX/XML emits.
- **Schema validator** — 20/20 spec rules complete on Tier 1 (V core + Python + Go).
- **CX code 1.0 evaluator** (V reference; per-binding native rollout deferred to v0.7.0).
- **Parameterized templates** — `?def name :params [a b] :body ...`.
- **`the evaluation-experience checklist`** — friction-budget gate with 10 hard-fail conditions and 10 time-horizon checkpoints (10s → 1yr+).
- **CI matrix** (`.github/workflows/ci.yml`) — macOS-14 + ubuntu-22.04/24.04 × 10 bindings.
- **Release tooling** in `tools/` — bump-version, release-verify, smoke-eval, verify-* scripts.

### Changed
- **`columns` → `cols` rename** across the Table API surface.
- **`select` → `select_cols`** rename across bindings (avoids LINQ / Enumerable conflicts in .NET / Ruby; uniform for consistency).
- Migration docs restructured: per-version under `docs/migrations/` (tree since retired; migration notes live in the release-notes files) with an index README.
- Private docs (`CONTEXT.md`, `community/`) moved to [`docs/internal/`](docs/internal/); simplifies `.publishignore`.
- Internal grammar revisions during this cycle (v3.3 → v3.4 → v3.5 → v3.6) are now hidden from user-facing docs; users observe only the v0.5 → v0.6.0 transition.

### Fixed
- All five 2026-05 binding-audit findings (CB-1..CB-5) closed at V core and across all 9 FFI bindings; see the 2026-05 binding audit.
- Rust binding SIGABRT under Boehm GC threading — `cx_init` / `cx_thread_register` / `cx_thread_unregister` C ABI symbols added (cap bit 26).
- Parser quote+bracket fix — body-text tokenizer is now quote- and bracket-aware; closes the last two carried parser limits.

### Migration
- See the v0.5→v0.6 migration guide (since retired; see `RELEASE_NOTES_v0.6.0.md`) for the full upgrade guide.
- BREAKING: leading-zero integers are now strings (`02134` is a string, not int 2134).
- BREAKING: binding `loads()` / `dumps()` preserve integer/float distinction via CXDB v1 (was JSON-coerced in v0.5).

[Unreleased]: https://github.com/cx-home/cx/compare/v0.16.0...HEAD
[0.16.0]: https://github.com/cx-home/cx/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/cx-home/cx/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/cx-home/cx/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/cx-home/cx/compare/v0.12.0...v0.13.0
[0.6.0]: https://github.com/cx-home/cx/releases/tag/v0.6.0
