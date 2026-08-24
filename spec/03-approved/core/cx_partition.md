# CX Partition Specification — rings, packs, profiles

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (Phase 2 of the #651/#516 campaign; Gate G-B = owner approval). Foundations: the #651 verdicts (all sections ruled), the import-edge audit (`partition_audit_vcx_imports.md`), the spec inventory (`partition_audit_spec_inventory.md`), and the campaign decision log (`partition_campaign_PLAN.md`). Normative language (MUST/MAY) binds once this spec is approved.

## §1. Purpose and product thesis

CX today ships as one monolith: every adopter carries TLS, six database
drivers, and a protocol stack to parse a config file. The partition breaks CX
into **rings** — capability tiers an adopter opts into — so the data format
alone is a small, safe, compelling artifact, and each ring above it is an
additive choice. The rings are simultaneously:

- **a product ladder** — data format → code → platform → ecosystem;
- **dependency contracts** — CI-enforced import rules that keep lower rings
  forever free of upper-ring weight;
- **a security statement** — the Ring-0 artifact cannot execute anything,
  by construction.

## §2. The rings

A ring answers exactly one question: **what may a module import**. Rings do
not decide what ships (§4 profiles do) and do not require stacking — a
component MAY depend on rings lower than its own (DAG, not strict stack).

### Ring 0 — data format (`vcx/cx`)

Parser (the FULL grammar, including program forms — the grammar is never
forked; cxparse unification is the partition's foundation), CXDM value model,
canonical forms and both identity tiers, data-bin codec, format emitters
(json/xml/yaml/toml/md), conversions, diff/eq/hash, schema language +
validation (re2 is a Ring-0 dependency: schema §7.1 makes RE2 normative for
cross-binding determinism).

Homoiconicity settles the classic objection: code forms are data. A Ring-0
consumer parses `[?for …]` as an inert element tree, the way an XML parser
parses XSLT. Canonical identity of code forms therefore lives in Ring 0 —
identity MUST be product-independent (a `[?def]` hashes identically
everywhere).

Ring 0 has **no evaluator**. Its import set is the V standard library only
(status quo, audited: `vcx/cx` is a strict sink).

Ring 0 carries one NAMED contract artifact (I5 stream 1, E4/L85): the
**semantic value model contract** (`semantic_value_model.md`) — *a CX
value has the same identity and meaning whether stored, transmitted,
queried, executed, replicated, rendered, or handled by an agent* —
binding canonical/cxdm/code-identity/schema §13 and the three
attachment lanes by reference. Every ring above inherits it as a
constraint.

### Ring 1 — code

Evaluator, CXPath evaluation, directives, quasiquotation, purity checking,
capability enforcement, fmt/lint, LSP, and every stdlib pack whose imports
stay within Rings 0–1. Ring 1 adds *execution*; it adds no servers, no
protocol stacks, no databases.

### Ring 2 — platform

The store (engine `vcx/cxstore` — which imports Ring 0 only, and MUST stay
evaluator-free — plus the store verb surface and journal), protocols (XSP
session layer and profiles, gRPC edge adapter, the HTTP tooling surface:
probes, metrics, pre-auth bootstrap), services (XAP host, fabric, http/net
serve, DB drivers, session/authz/did/vc, process/io watch).

### Ring 3 — ecosystem

Registries, marketplace, native clients, bindings packaging and
distribution. Mostly future; #696–#699 (consumability) land here.

## §3. Import contracts (normative once approved)

```
Ring 0  MUST import nothing internal.
Ring 1  MAY import Ring 0.
Ring 2  MAY import Rings 0–1.
Ring 3  MAY import Rings 0–2.
```

- Protocol modules live in Ring 2. Rings 0–1 MUST NOT import them.
- `arrow` and `transport/*` are leaf siblings consumed from Ring 2; optional
  native capability MAY be reached by dlopen (precedent: `cmd/table_arrow.v`).
- Tests and tooling may import anything; shipped artifacts are what the
  contracts protect.

**CI enforcement:** an import-gate check (grep-level, zero-tolerance) runs in
every gate lane: any `import` in a ring's modules naming a higher ring fails
the build. The gate is cheap (the module DAG is already clean) and MUST land
with the first extraction so the seam can never regress silently.

## §4. Packs and profiles

- **Pack** — the shippable unit inside a ring: a stdlib module or family
  declaring (ring, capability categories used, external dependencies). The
  mechanism exists today as `-d` build gates (`cx_db_*`, `cx_sftp`,
  `cxstore_columnar`); the partition names and generalizes it.
- **Profile** — a named artifact composition. Initial set:

| Profile | Contents | Adopter |
|---|---|---|
| `data` | Ring 0 only; data verb set | embed/parse/validate; untrusted input |
| `embed` | Rings 0–1 core; no local-effect packs | evaluator embedded in a host app |
| `cli` | Rings 0–1 + local-effect packs (io, env, process, time, random, log, term) + http client pack | developers, scripts |
| `platform` | Rings 0–2 | operators: store, fabric, XAP, daemons |

`cxhome.org/install` installs a profile, not a puzzle (one command,
unchanged). Pack membership per profile is data, recorded in the build, and
a profile's verb/builtin surface is derivable from it.

**The x/ tier's packs (stream 18, L144 — the §2 membership test applied):**
`run`, `mcp`, `a2a`, `llm`, `tools`, and `adjudicate` are **Ring 1 packs**
(pure CX composition over Ring-1 stdlib + the evaluator; their only effects
are client-side capability-gated calls). `mcp-server` and `a2a-xap` are
**Ring 2 packs** (they compose the platform substrate: the http server,
journal, bus, authz commit). The x/ tier rides the `cli` profile's Ring-1
surface for its Ring-1 packs; the Ring-2 pair ships with `platform`.
Experimental status (D3) is orthogonal to ring placement — the tier is
exempt from the frozen-stability promise, not from the import contracts.

**One binary name.** The `cx` CLI exists at every profile; the compiled
profile determines its verb set. A `data`-profile `cx` has
parse/emit/convert/canonical/hash/eq/diff/validate/schema — the
`schema` family carries `infer` (corpus → deterministic open-mode
`.cxs`; shape_inference.md §8) and `export` (`--to=json-schema`,
the lossless-projection JSON Schema; shape_inference.md §9), both
Ring 0 by construction; `embed|extract|bundle|unbundle` remain
spec-only (schema.md §13.2) — and **no run/eval
verb** (ruled: cannot-execute is the data product's security feature, a
property of the artifact, not a runtime refusal).

## §5. Artifacts and repo strategy

**Monorepo, multi-artifact (ruled).** One repository, one conformance corpus
as the shared contract, atomic cross-ring changes during the extraction era;
seams are enforced by §3 gates, not repo boundaries. Per-ring repo splits
remain possible later without re-ruling this spec.

Artifacts:

| Artifact | Rings | Notes |
|---|---|---|
| `libcx-core` | 0 | new; the C ABI subset covering Ring-0 surfaces |
| `libcx` | 0–1 | keeps today's name and ABI (cx_* + cx_code_* exports) |
| `cx` (per profile) | per §4 | one name, profile-determined surface |
| platform daemons | 0–2 | store-serve, fabric-serve, xap host — `platform` profile |
| bindings | wrap libcx-core / libcx | Ring 3 distribution (#699) |

The current Makefile builds libcx from `vcx/code` so both cabi layers ship
together; the partition replaces exactly that single-artifact decision.

### §5.1 Repo-split policy (ruled 2026-08-05)

- **Private:** the monorepo persists indefinitely. The split trigger is
  organizational, never technical — a second engineering organization with
  its own cadence or access needs for a ring. Import gates + per-ring
  artifacts + per-ring lanes deliver separation without cross-repo pin
  coordination.
- **Public:** repos multiply on exactly two triggers: (1) a package-manager
  convention requires one (Go tag mirror at C4); (2) a distinct adopter
  audience warrants its own front door — realistically a `libcx-core`
  mirror, decided at Ring-0 extraction time (migration phase 2), zero
  pre-commitment. All public repos are read-only generated projections of
  the release cut; issues/PRs funnel through `cx`; development never leaves
  the private monorepo.

## §6. Build, release, platform

- **Versioning (ruled P1a, 2026-08-05):** all artifacts version in lockstep
  from the repo-root `VERSION` (single source of truth, derived everywhere).
  Independent per-artifact semver is rejected for the extraction era —
  version skew is the #516-named risk, and lockstep is reversible later.
- **Release:** the existing release process gains per-artifact packaging
  steps; one cut, N artifacts, one changelog.
- **Platform matrix (ruled P2a, 2026-08-05):** macOS (darwin/arm64) and
  Linux (x86_64) are tier-1 gate platforms. **Windows is tier-2**: CI
  cross-build of the `data`/`cli` profiles, WSL2-documented as the supported
  path, native untested. Promotion to tier-1 is an owner decision with its
  own gate lane; the revisit trigger is real evaluator demand.
- **wasm:** Ring 0 compiles to wasm without the mbedtls blocker (no TLS in
  Ring 0) — the `data` profile is the playground target (#696).

## §7. The conformance corpus as the cross-ring contract

- Every fixture family is **ring-tagged** (stream 14, #686, produces the
  tagging). A ring's artifact MUST pass every fixture at or below its ring.
- **Ring-0 extraction gate:** the extracted Ring-0 artifact passes the full
  Ring-0-tagged corpus **byte-for-byte** against the monolith — outputs,
  canonical bytes, hashes, error codes identical. No behavioral drift,
  no re-blessing.
- Per-ring gates are also the structural answer to gate duration (#700): a
  Ring-0 change runs Ring-0 lanes.

## §8. Compatibility promise and archival guarantee

This spec carries the adopter-facing promise (authored here, kept forever):

**Permanence confirmations (L52, stream 15 — normative).** What MUST
remain domain-free forever: Tier-1/Tier-2 addresses (tagged
`sha2-256:`/`code:sha2-256:` forms, never URL-bearing); schema dialect
(bare semver) and schema identity (content hash); `pkg:` resolution
(bound registry + hash pin, no default host); publisher identity
(`did:key` default; `did:web` is per-adopter opt-in carrying its own
domain risk on the adopter); the conformance corpus (owns no
domain-bearing URIs). The CX namespace URI
(`tag:cxhome.org,2026:ns/cx`, RFC 4151) is normatively an IDENTIFIER,
not a locator — never dereferenced, valid independent of DNS;
`cxhome.org` is only the rotatable resolution/infrastructure host.

- **Frozen at 1.0:** the grammar (additive evolution only), CXDM semantics,
  strict-canonical bytes and both identity tiers (self-describing addresses
  per #691 land BEFORE the freeze), data-bin (versioned header, additive),
  the conformance corpus (append-only), the libcx-core C ABI (symbol-versioned).
- **Evolvable:** everything above Ring 0's contract, by the additive rules
  each spec already carries (negotiated protocol features, new packs, new
  verbs).
- **Archival guarantee:** canonical text CX is the eternal preservation
  format — any conforming reader, at any future version, reads any archived
  canonical document. Lossless canonical emit never expires.
- **Erasure inside the guarantee (stream 20, #692):** lawful deletion and
  the archival promise coexist by construction, not by exception.
  Crypto-shredding (per-subject keys, `std-lib/store.md`) and
  detached-payload journal entries (`std-lib/journal.md`) mean a
  right-to-be-forgotten erasure destroys exactly the subject's payload
  bytes while every hash chain still verifies (`valid=true` with payloads
  lawfully gone), and every omission stays **visible and attributed** — a
  typed `[erased …]` tombstone on the value channel, `redacted=` counts
  reconciled against journaled shred-requests, and any unattributed
  missing payload reported LOUD as evidence of tampering rather than
  counted among the redactions. An archived CX corpus is therefore never
  "cannot legally delete", and a legally compliant archive never reads as
  corrupt: unauthorized deletion and lawful shred are observationally
  distinct forever.

## §9. Foundations folded in (#37)

- **Runtime representation (ruled direction; spec = #689; L87 — the
  owner-corrected DUAL lean, not columnar-only):** nodes remain the
  logical/homoiconic surface; below that line BOTH halves apply — a fast
  general execution core (unboxing/specialization) for scalar / control /
  irregular work AND columnar/vectorized movement for bulk data,
  materializing to node form lazily when code or inspection touches it.
  Constrains Ring 1 internals and the C ABI; the partition's artifact
  boundaries are drawn so this lands without moving ring seams.
- **Typing (ruled lean; spec = #688):** dynamic core + schema/shape
  inference over pipelines at boundaries — never mandatory static typing.
  Ring 0 owns schema identity and validation; Ring 1 owns inference.
- **Memory/scaling doctrine (settled):** per-batch/per-request isolation +
  off-heap store as the scaling levers; concurrent-mark GC as backstop.

## §10. Migration map (current tree → target)

Phase ordering (detail in the Phase-3 plan; gates G-C before any of it):

1. **Gates first:** land the §3 import gates + §7 ring tagging on the
   monolith (no code moves; the seam becomes enforced before it is exercised).
2. **Ring-0 extraction:** build `libcx-core` + `data`-profile `cx` from
   `vcx/cx` as-is. Cleanups ride along: `fixture_loader.v` moves to test
   support (compiled into shipped libcx today, zero production consumers);
   `cx/cx.dylib` build debris removed; dead `cxstore/cxsqlite` module
   deleted; `arrow_pub.v` renamed (cosmetic, no dependency edge).
3. **Ring 1/2 split inside `vcx/code`:** the audited frontier. Membership
   test per module: imports cxstore/protocol modules or serves ⇒ Ring 2;
   otherwise Ring 1, pack-gated for weight. Store verb surface, protocols,
   xap/fabric/session/authz/did/vc, DB drivers, process/io → Ring-2 modules.
4. **Profiles:** wire §4 profiles into the build + installer.
5. Stream implementations (#673–#694) land against the partitioned tree,
   each after its spec, per the campaign gate.

Every phase ends green on the full corpus; phase 2's gate is §7's
byte-for-byte rule.

## §11. Security posture per ring

- Ring 0: no evaluator, no effects, no network — safe on untrusted input by
  construction; the only C-interop is re2 (pattern constraints) and the
  build-gated GC shims.
- Ring 1: deny-by-default capabilities (shipped); pure computation needs no
  grants; `embed` profile ships without local-effect packs entirely.
- Ring 2: one authority model — XSP-AUTH DID principals + attenuable
  capability values (per the CSRP-fold ruling, the store's parallel auth
  stack is eliminated); HTTP tooling surface stays unauthenticated ONLY for
  probes/metrics/version bootstrap.

## §12. Language bindings — part of the story, never on the critical path

Bindings (Python, Go, Rust per the approved two-layer bindings spec; V is
the native reference) are strategically required but currently unconsumed.
The partition resolves that tension structurally:

1. **The thin waist is the frozen ABI.** Bindings bind `libcx-core` /
   `libcx` C ABI — which §8 freezes and symbol-versions at 1.0. A binding
   tracks a frozen contract, not a moving target; mainline advances cannot
   break a published binding within an ABI major.
2. **Layer-1 Document API first.** Each binding's initial surface is the
   approved Layer-1 Document API: data operations (parse/emit/canonical/
   hash/diff/validate) PLUS CXPath select/modify — linked against `libcx`
   (Rings 0–1). CXPath queries are pure evaluation (no effects, no
   capabilities), so the security claim holds: **the binding can query
   anything and execute nothing** — the `cx_code_eval*` program-execution
   family is excluded from the initial surface. Program eval and Layer-2
   idiom packs are additive follow-ons, built when a real consumer asks.
3. **Monorepo is the source of truth; external repos are generated
   mirrors.** `lang/*` stays canonical; the release cut runs an automated
   mirror-publish lane (kills today's manual publishing cost). Mirrors are
   write-through artifacts, never edited directly.
4. **Non-blocking by policy:** bindings CI is an advisory lane — mainline
   merges never wait on it. At a release cut, **publish what's green**: a
   red binding skips that version (lockstep versioning makes a skip
   unambiguous — there is no partial-version skew), and its previously
   published version keeps working against the new core within the ABI
   major.
5. **Conformance = the shared corpus through the FFI.** A binding is
   conformant iff it passes the ring-tagged corpus at its ring via the
   parity-matrix gates — no per-language test invention, and binding
   conformance strengthens the corpus rather than forking it.
6. **De-friction direction:** the ABI/API surface is described as a
   machine-readable CX manifest from which Layer-1 scaffolds and mirror
   repos are generated (dogfooding; same projection philosophy as the
   agent-tool stream). Hand-written binding code trends toward Layer-2
   idioms only.

### §12.1 Availability matrix (ruled 2026-08-05)

| Surface | V | Python / Go / Rust |
|---|---|---|
| Everything, all rings | native (V is the implementation, not a binding) | — |
| Document API: parse/emit/convert/canonical/hash/eq/diff/schema/validate + CXPath select/modify | ✓ | **the v1 binding surface** |
| Program eval in-process (`cx_code_eval*`) | ✓ | later, on first consumer demand, capability-controlled |
| Store / journal / fabric / XAP (Ring 2) | ✓ (daemons) | **never an in-process binding** — reached over the wire (XSP store profile, gRPC, HTTP) |

The Ring-2 row is the structural rule that keeps bindings permanently
cheap: **bindings embed the engine (Rings 0–1); the platform is a service
you connect to.** The binding matrix never grows beyond Rings 0–1.

### §12.2 Repo topology and public surface (ruled 2026-08-05)

- **Source of truth: `lang/*` in the private monorepo** — all development,
  all CI, same commits as core.
- **Public: bindings ship inside the public `cx` mirror** (status quo).
  Per-binding public repos are generated ONLY when a package-manager
  convention demands one (Go: a read-only `cx-go` tag mirror at C4; PyPI
  and crates.io need no repo). Generated mirrors are read-only, issues
  disabled, README pointing at `cx`; the port-external-PRs-to-private flow
  remains the single contribution channel.
- **At C4 (#699):** `pip install cx` / `cargo add cx` / `go get …/cx-go`,
  published by an automated release-cut lane gated only on that binding's
  corpus-through-FFI lane; red binding ⇒ version skipped, previous
  artifacts stay valid under the frozen ABI. No manual publish steps.

## §13. Letters — all resolved

P1(a) lockstep versioning and P2(a) Windows tier-2 ruled 2026-08-05 and
folded into §6. No open letters remain in this spec; Gate G-B (owner
approval of this document) is the next campaign step.
