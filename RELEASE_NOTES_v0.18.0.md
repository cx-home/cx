# CX v0.18.0 — Release Notes

**Date:** set when the tag is cut (RULED: FW-2 — the tag waits for the flow
waves below to close; see "Flow waves")
**Tag:** `v0.18.0`

The **split** release. CX stops being one repository and becomes a graph of
them: `cx` is the thin front door, `cx-core-data` and `cx-core-code` are the
two frozen rings underneath it, and every platform product, language
binding, and ecosystem piece (registry, decisions, tooling) is its own
repository, pinned by sha in `deps.cxd` (owner, 2026-09-21; design of record
[#1589](https://github.com/cx-home/cx-private/issues/1589), execution
tracked on [#1591](https://github.com/cx-home/cx-private/issues/1591), the
decisions RS-1…RS-32). Alongside the split, this release lands the
constraint grammar's four waves end to end — a feature's laws are now
declared *and evaluated*, not just documented — a SAML 2.0 service-provider
verify core, module-load purity checking, and a season of measured
memory/perf repairs.

**The split and the tag are deliberately decoupled (RULED: FW-2).** The split
lands on its own timeline; the `v0.18.0` tag additionally waits for eight
`prio:high` flow issues the owner ruled into this release, because the
ecosystem's own CI/CD runs on `cx flow` starting here (RULED: FW-1). See
"Flow waves" below for the list — none of it is landed on this head.

**One deliberate break to know before upgrading:** the feature runtime
contract's argument changed kind, not just shape (`$host` replaces the bare
store handle) — see Migration.

## Headlines

- **CX is now a graph of repositories, split by product (RS-1…RS-32).**
  There are exactly two rings — Ring 0, the data format (`cx-core-data`),
  and Ring 1, the language (`cx-core-code`) — frozen, each an import
  contract the build enforces (RS-1: Ring 0 cannot execute; Ring 1 cannot
  reach a socket, a store, or a protocol). Everything else is a **group**
  with a declared, acyclic import graph over the rings: the **platform**
  group ships one repository per product rather than per library (RS-2) —
  `cx-platform-net`, `-mail`, `-store`, `-db`, `-identity`, `-fabric`,
  `-xsp`, `-xap`, `-connector`, `-sso`, `-flow`, `-ux`, `-agent` — the
  **binding** group (`cx-binding-python`, `-go`, `-rust`, `-v` shipping;
  `-typescript`, `-java`, `-kotlin`, `-csharp`, `-swift`, `-ruby` archived),
  and the **ecosystem** group (`cx-registry`, `cx-decisions`, `cx-tooling`).
  `cx` itself pins the whole graph in `deps.cxd` (fifteen `[dep]` rows on
  this head) and is what a user installs; `cx-private` stays private as the
  orchestration repository — the ledger, the process specs, the runner
  configuration and boards (RS-11, amended by D59a: `cx` is *created* by the
  extraction recipe from the allocation's `repo=cx` paths, not `cx-private`
  renamed). `make deps-sync` fetches every pin and fails closed on a stale
  one or a drifted checkout — it never warns (RS-7: "a release cut ships
  whatever is pinned") — and every V product in the four `cx` profile
  builds (platform/data/embed/cli) compiles from its pinned checkout, not
  from a tree copy. Twenty-one of the platform/binding/ecosystem
  repositories are extracted as of this cut; `cx-core-code` and `cx` itself
  are the last two, built by the same recipe immediately ahead of the tag.
  The public mirror allowlist script (`scripts/publish.sh`, the old
  `cx-home/cx`-from-`cx-private` copy) retires with it — public or private
  is a setting per repository now, not a filtered copy of one (RS-11).

- **The constraint grammar is complete — a feature's laws are declared
  *and evaluated*, in one pass, end to end (#1301, #1302, #1303, #1304,
  #1305, #1306, #1307, #1193; RULED: 1308-CG-1…CG-7).** A `[rule]` used to
  carry a prose `[statement]` that nothing ran; enforcement depended on
  whichever module `apply` happened to check it, or on nobody. Four waves
  close that at the ONE pre-commit enforcement point (§4.9, after the PEP
  admits, before anything is appended): **wave A** puts a noun's `[field]`s,
  their resolved `type=` (the closed scalar set, a sibling noun, or a
  `[types]` declaration), and the bitemporal valid-time axis onto the
  composed grammar itself, so a served grammar is sufficient for a client
  without re-reading the source feature; **wave B** evaluates `[check]` as a
  pure predicate over the intent and the merged row (refusing
  `cx-err:CXER4865` on false), `kind=cardinality` over sibling-noun
  alternatives (`cx-err:CXER4866`), and `[transition]` as a real state
  machine on an enum field (`cx-err:CXER4868`, ordering derived rather than
  hand-written); **wave C** ships the bitemporal read,
  `[$xap:state RT PATH {at-seq: N, valid-at: T}]`, intersecting the journal
  axis and the valid-time axis exactly as `core/bitemporal.md` names it;
  **wave D** lets a `derived=true` noun carry its own `[fold]` — a planar
  `[?for]` comprehension over its declared `[from …]` sources, held pure and
  provenance-scoped by W13 — closing the `CXER4875` gap for a noun whose
  producer is a query rather than a bound component. All four waves are
  additive to a sealed contract except `type=`, which was free text and is
  now closed (see Migration).

- **A grammar's laws no longer follow their caller (RULED: GE-0…GE-3).** A
  rule's `[check]` and a derived noun's `[fold]` used to evaluate in the
  `cx:eval` sandbox, which installs the *caller's* `[?lib]` set — so the
  same law admitted or refused an identical intent depending on what the
  emitting program happened to import. The environment is now fixed by the
  grammar itself: the expression's own bindings, the built-in operators, and
  exactly `cx-stdlib/strings`, `cx-stdlib/math`, and `cx-stdlib/re`,
  pre-imported under canonical prefixes — a module joins that list only by
  ruling, with the case that motivated it, never because it happens to be
  pure. A call to any other module is now a compose-time conflict (W10/W13)
  rather than a runtime surprise.

- **The XAP feature runtime takes the deployment context, and the host
  journals the canonical act (#1210, #1260; RULED: HC-1, CA-1/CA-4).** A
  feature's `readout`/`apply`/`simulate` entry points now receive one
  `[host tenant=… [store …] [journal …]]` element in the position a bare
  store handle held — naming the tenant and, when the deployment declares
  one, the act chain the runtime itself commits through, so a feature folds
  and appends to its own tenant's journal without re-opening one from an
  environment variable. Symmetrically, the deployment host's `POST /intent`
  now journals the ACT itself (`[do 'ns/verb' [field value]…]`, bare or
  inside `[event actor=? focus=? [do …]]`) instead of a fields-stripped
  `[do 'ns/verb']` — a host-committed act can be replayed from the journal
  for the first time, and a claimed `actor=` that does not match a proven
  principal is refused. Both are cutover-first, no dual-accept — see
  Migration.

- **`cx-stdlib/saml` — a SAML 2.0 service-provider verify core (#1091;
  RULED: S-0…S-9).** `verify` takes raw XML octets and the IdP's public
  keys and returns the verified subtree itself, never a boolean beside a
  document, closing the class of signature-wrapping exploit that separates
  the "valid" answer from the node a caller reads; `assertion` selects the
  one covered `Assertion` under the `Response` envelope; `validate` checks
  `Issuer`, `Conditions`, and bearer `SubjectConfirmation`; `attributes` /
  `name-id` read every text node with comments elided. SHA-1 and every
  transform beyond enveloped-signature + exclusive C14N refuse by name;
  `KeyInfo` is never consulted. 81 cases (every XSW family, transform abuse,
  well-formedness) pinned against libxml2's canonical octets, `CXER5400`–
  `5411`.

- **A module's declared purity is checked where the risk actually is — at
  load (#1298, #1288).** The static purity check ran for program-level
  `[?def]`s only; `load_module` never called it, so a module (the larger
  surface — stdlib, every `[?lib]` import) could declare a default-pure def
  that calls an impure sibling, load clean, and hand every consumer relying
  on the label — a `journal fold`/`snapshot` reducer, `validate`,
  `simulate` — a claim the engine never checked. The loader now runs the
  checker after imports resolve, for both call spellings
  (`[$name …]`/bareword head), and refuses `cx-err:CXER0233` naming the def
  and the callee. No shipped stdlib module was carrying the defect.

- **The playground gate grades the answer, not just the run (#1170;
  RULED: 1170-a, 1170-b, 1170-c).** 182 examples used to be replayed and
  judged only on exit code, so a semantics change could retire an example's
  *meaning* — a bare-head construction change silently turned fourteen
  examples into data literals, teaching a builtin call that had stopped
  computing, for three release windows, undetected. The generator now pins
  every audited answer (`examples.out.cxd`, the same shape the conformance
  corpus uses) and `--check` diffs it; two structural lints (a bare head
  that came to rest as data, a `[?let]` cascaded inside another `[?let]`'s
  body) catch the classes by construction rather than by allow-list.
  Nineteen playground examples were repaired against the shipped binary as
  the first pass through the new gate (#1170 Part A) — the index-base
  drift, the retired bare spelling, and four `[?sleep :mock]` examples that
  had been demonstrating a parse error instead of the timing behavior they
  name.

- **Composition hygiene: names, keys, and declared surfaces (#1191, #1190,
  #1327, #1217, #1314, #1285; RULED: 1191-a, 1190-a/b, 1327-a, 1217-VF-1,
  789-WF-26a, 1314-c1…c4, VG-1).** A feature name is one segment — `/` is
  the qualification separator and now refuses at both authoring
  (`[pattern]`) and compose time, instead of silently working until an
  ordering rule needed to know which side of the slash owned it (#1191). A
  key registered exactly once is now a compose-report note
  (`:solitary-key`), the typo class `order-id`/`order_id` used to pass
  silently as two rulers (#1190). `cx-stdlib/flow` §3 carries a per-verb
  status table a gate holds against the module in both directions, closing
  a drift where the section named seventeen verbs and six existed (#1327).
  `[$ux:form]` now dispatches on what its source *is*, reaching both of
  CX's declaration systems — a `[?def]`/`[effects]` pair and a XAP feature
  grammar's `[verb]`/`[noun]` — instead of refusing every grammar-declared
  verb with a typo-shaped error (#1217). A flow `[step]` may declare
  `attempts=N`, gated on the resolved command's own `idempotent=true`
  disposition, never on the flow's say-so (#1314). A noun's `[views]`
  clause (`sort`/`facet`/`default-order`/`hidden`) is compose-checked and
  consumed by `cx-x/ux`'s table controls (#1285).

- **Two schema constraints close real authoring gaps (#1155; RULED: EN-2,
  EN-2 P16).** `[keys CLAUSE…]` closes a `[map K V]`'s *key* domain through
  the existing `§7` clause catalog — `[keys [enum plus minus times]]` — with
  `[req]` making the key set total (new code `S021`); a duplicate or empty
  `[enum]` member list, in value position or inside `[keys]`, is now a
  schema-load error (`S022`).

- **Measured memory and latency repairs across the engine.** `--from=json
  --to=json` on a 19 MB / 300k-record document: 1,181 MB → 685 MB peak RSS,
  by making the two post-parse JSON passes identity-preserving instead of
  rebuilding every node (#1226). The `cxel` live-memory lane: 15.507× →
  7.600×, by routing an autotyped attribute's type name through the
  56-byte inline field instead of pooling a 112-byte `AttributeMeta`
  (#1275; `bench/repr`'s `BOUND_cxel` re-pins 16.30 → 8.00). `cx fmt`'s
  worst-case outlier: 26 s / 3.3 GB → 0.60 s / 494 MB on the same 1.37 MB
  document, by replacing a full V debug-string render with a compact tagged
  fingerprint writer (#1281). A percentile bucketer that quoted its own
  sentinel (`p50 = p99 = 9999999`) for any rank between fixed ladder rungs
  now reads sorted samples at the 1-based rank and refuses itself if
  min ≤ p50 ≤ p99 ≤ max does not hold (#1279). Evaluator hot paths (map key
  lookup, `[$map:get]`/`contains`, operand classification in `+ - *`,
  parameter defaults, call-env aliasing, interned scalar images) gained
  2.6×–3.5× on their measured paths with byte-identical output (#1240,
  #1243, #1244, #1245, #1247); the CX/XML/Markdown emitters write into one
  `strings.Builder` instead of per-level `[]string` + `join`, −30 % wall /
  −50 % peak RSS on a 90-deep 4.5 MB corpus (#1242 B). A committed perf
  ratchet (`make perf-ratchet`) now aborts a cut on any benchmark more than
  10 % slower than the previous release's measurement (#1249).

## Flow waves — the tag's gate (RULED: FW-1, FW-2)

The repository split above lands on its own timeline; **the `v0.18.0` tag does
not** — it is decoupled from the split and waits for eight `prio:high` issues
the owner ruled into this release because the ecosystem's own CI/CD runs on
`cx flow` starting with this release (RULED: FW-1, FW-2). These are stated
here as the release's **scope**, not as landed: nothing below is shipped on
this head, `flow.md` §3 still carries each as "named landing — not yet
implemented", and the branch that closes the last of them appends the
measured landings above this section.

- **[cx-home/cx-platform-flow#3](https://github.com/cx-home/cx-platform-flow/issues/3) — the performer axis (W3, first in the ladder).** `by=:principal`/`:agent`/`:peer`, offers, ladders, `quorum=`, `[notify]`, `claim`/`release`/`reassign` (RULED: WF-4, WF-12, WF-21, WF-23, 1265-PW-1…3).
- **[cx-home/cx-platform-flow#4](https://github.com/cx-home/cx-platform-flow/issues/4) — `fleet` (W4).** The pure stall predicate (RULED: WF-7).
- **[cx-home/cx-platform-flow#5](https://github.com/cx-home/cx-platform-flow/issues/5) — `migrate` (W5).** The `[flow-lineage]` claim and the dry-run classification (RULED: WF-6).
- **[cx-home/cx-platform-flow#6](https://github.com/cx-home/cx-platform-flow/issues/6) — the cross-company profile (W6).** The signed `step-ack` and the XSP `flow` token (RULED: WF-8).
- **[cx-home/cx-platform-flow#7](https://github.com/cx-home/cx-platform-flow/issues/7) — the operator acts.** `cancel` / `pause` / `resume` / `skip` / `retry-now` and `resolve` (RULED: WF-19, WF-25, 1265-PB-8).
- **[cx-home/cx-platform-flow#8](https://github.com/cx-home/cx-platform-flow/issues/8) — vocabulary round 2.** The three words still refused by landing: `until`, `flow=`, `calendar=` (RULED: WF-18, WF-22, WF-24).
- **[cx-home/cx-platform-xap#1](https://github.com/cx-home/cx-platform-xap/issues/1) — the XAP host embeds the runner.** The `[on …]` row admitted into the deployment document, the host-side courier and `rearm` loop, byte-identical with `cx flow serve` (RULED: WF-28b, WF-29); the one item still waiting on its own ruling before code.
- **[cx-home/cx-private#1498](https://github.com/cx-home/cx-private/issues/1498) — end-user automation authoring.** "When X then Y" from the surface through the studio and `cx xap scaffold`, published as a versioned feature; reopened into v0.18, last in the recommended order.

Recommended landing order (integrator, under INT-17 — an order, never
membership): W3 → vocabulary round 2 → the operator acts → W4 → W5 → W6, the
XAP host issue on its own ruling, `#1498` last. Tracked on
[cx-home/cx-private#1354](https://github.com/cx-home/cx-private/issues/1354),
Lane 2.

## Changed (behavioral)

- The feature runtime contract's entry points take `[host tenant=… [store
  …] [journal …]]` in place of a bare store handle (#1210, RULED: HC-1) —
  a KIND change, not additive; see Migration.
- The XAP deployment host's `POST /intent` journals the canonical
  `[do …]` act; the old fields-stripped `[intent …]` body is retired,
  cutover-first — see Migration (#1260, RULED: CA-1/CA-4).
- `[check]`/`[fold]` expressions evaluate in the grammar-fixed environment
  (`strings`, `math`, `re`), never the caller's `[?lib]` set (RULED: GE-0…GE-3).
- A feature name containing `/` refuses at authoring and at compose
  (#1191, RULED: 1191-a).
- `type=` on a grammar-declared field resolves only to the closed scalar
  set, a sibling noun, or a `[types]` declaration — free text no longer
  composes (RULED: 1308-CG-7).
- A default-pure module `[?def]` calling a known-impure def or primitive
  refuses `CXER0233` at load, by either call spelling (#1298, #1288).
- `[keys …]` and `[enum]` payload rules join the schema clause catalog:
  `S021` (incomplete required key set), `S022` (duplicate/empty enum
  members) (RULED: EN-2, EN-2 P16).
- Diagnostics render an atom bare (`:gone`) and a string quoted (`'gone'`)
  rather than converging on one spelling for both.
- An unreachable journal store's open/attach/verify calls propagate the
  underlying store fault instead of reporting a chain-integrity finding
  about a store that was never reached (#1293).

## Migration

- **Feature packages must be republished.** The `readout`/`apply`/
  `simulate` argument that used to be a bare store handle is now a `$host`
  deployment-context element; a module built against the old contract has
  the same arity and fails at its first store call rather than at load.
  Republish against toolchain v0.18.0 or later; a package's `compatibility`
  floor states the toolchain it validates against.
- **Deployment hosts posting `[intent verb= field=…]` must move to the
  canonical act form**, `[do 'ns/verb' [field value]…]` (bare, or inside
  `[event actor=? focus=? [do …]]`); the old body now answers
  `ok=false reason=intent-form-retired`.
- **A grammar `[check]`/`[fold]` that called a module by relying on the
  caller's imports** now composes as a conflict; move the call to one of
  the three pre-imported modules or file the case for a new one to join by
  ruling.
- **A `type=` outside the three closed resolutions no longer composes.**
  Re-declare it as a `[types]` member (`core/schema.md` shape) or a sibling
  noun.
- **`cx-home/cx-v` retires at this cut** (RULED: D81a). The V fork a CX
  build patches is `cx-home/v`, branch `cx-patches-0.18`, pinned by every V
  repository's `deps.cxd` `v-fork=`; `cx-home/cx-v` is archived with a
  README pointing at `cx-home/v` and takes no further pushes. Anyone
  tracking `cx-home/cx-v` directly should switch to the pinned fork.
- **A downstream consumer of the old single-repository `cx-private`/
  `cx-home/cx` mirror now depends on a graph of repositories.** `cx` still
  pins and builds everything a user needs; a consumer building any one
  product or binding directly should pin the specific `cx-platform-*` /
  `cx-binding-*` / `cx-core-*` repository named in `deps.cxd` rather than a
  path inside the old monorepo.

## Known state, stated honestly

- The split is not fully closed at this tag: `cx-core-code` and `cx` itself
  are extracted last, immediately ahead of the release build, by the same
  recipe as every other repository (D79a, D59a); the six archived-binding
  repositories (`-typescript`, `-java`, `-kotlin`, `-csharp`, `-swift`,
  `-ruby`) are allocation rows, not yet materialized. `reference-apps`
  (D67a) is scheduled after this cut.
- The documentation restructure (one site in `cx`, thin per-repository
  READMEs, RS-28/RS-30) and the move to `cx flow` for CI/CD (RS-29) are
  both **scheduled after this cut**, deliberately — landing them first was
  weighed and refused (2–3 agent-days on the split's critical path).
- Every component repository flips public at this cut in one pass, each
  after its own `check-no-consumer-terms` run and a secrets scan over its
  tree (D59a); `cx-private` stays private, holding the ledger, the process
  specs, the runner configuration, and the boards.

## Toolchain

- V fork: `cx-home/v`, branch `cx-patches-0.18`, pinned at
  `501ce6e5f92643eb909adc3f7a7b4c2d1adaeeec` (every V-repository row in
  `deps.cxd` carries this `v-fork=` sha) — the fork itself is no longer
  mirrored to `cx-home/cx-v` (see Migration).
