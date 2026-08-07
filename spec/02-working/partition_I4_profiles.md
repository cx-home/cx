# I4 — profiles & installer: working ledger

**Status: IN FLIGHT** (opened 2026-08-06). Branch
`impl/I4-profiles-installer` off `design/651-516-partition` @ 5c3b44dc
(the I3 exit-merge). Phase row: `partition_impl_PLAN.md` Part B; this
file is I4's working ledger, the successor to
`partition_I3_ring12_split.md`.

## The phase (plan row, verbatim contract)

Build matrix for data/embed/cli/platform; cxhome.org/install profile
wiring; per-ring gate lanes activate (#700's structural relief).

**Exit gate:** each profile builds + passes its ring-tagged corpus;
installer one-command per profile.

## Standing constraints carried in

- `make test-extraction-gate` (I2's byte-for-byte lane) and
  `make libcx-abi-gate` (I3's 713-symbol baseline) stay green
  throughout — I4 ADDS artifacts; the shipped monolith artifacts are
  untouched (strangler rule).
- Import gates (I0/I3) stay green across the full 0/1/2 frontier.
- Any red is a plain regression (deliberate-red ledger EMPTY at open).
- Fixture-before-fix; full `make test` + `test-binding-api-parity` at
  phase close; no pipes on gate runs (exit-code masking).
- A `-d` gate with no build that consumes it is a dead seam
  (no-stubs rule) — every pack gate named here ships WITH its live
  consumer in the same phase (the I3 entry-9 disposition).
- Entry-25 mode-in-identity residual still rides BEHIND, before I5.
- #737 exclusion (parser_multidoc_test.v out of test-vcx-cx BY NAME)
  and CODE_SERIAL_RETRY memberships carry forward unchanged.

## Dispositions into this phase

- **N4 (I3 ledger, census note):** artifact/ring reconciliation of the
  2 iowatch C-callback exports (`cx_iowatch_emit`,
  `cx_iowatch_publish_runloop` — Ring 2, shipped in libcx today).
  Ruled at entry 1 below.
- **Pack-gate table (I3 ledger entry 9):** Ring-1 local-effect pack
  `-d` gates get their live consumer at I4's build matrix (embed
  excludes local-effect packs; cli includes them + http client).
- **#700:** per-ring gate lanes are the structural lever that lands
  with the partition — activated here.

## Work log

1. **Phase open — the two rulings + the design (2026-08-06).**

   **Ruling R1 — N4 reconciliation: libcx keeps the full 0–2 surface
   through I4; the §5 rings-0–1 re-cut binds to I5 stream 4.** The
   shipped binding store clients (`cxlib.StoreClient`, python/rust/go)
   reach the store through `cx_code_eval_caps` evaluating
   `[$store:…]` — Ring-2 store verbs INSIDE libcx, net-cap-only,
   deliberately NOT a per-binding wire reimplementation ("the core is
   the single source of protocol truth", store.py docstring). §12.1's
   ruled replacement — Ring 2 "never an in-process binding — reached
   over the wire (XSP store profile, gRPC, HTTP)" — is exactly what
   I5 stream 4 delivers (CSRP data-plane retirement at the parity
   gate). Re-cutting libcx to Rings 0–1 at I4 would break shipped
   binding functionality with no replacement path for one phase, or
   force a throwaway CSRP reimplementation per binding: both fail the
   long-term-best bar. So: libcx (the default `make lib`, the ABI-gate
   subject, the platform/default-profile library) builds over
   `platform/` UNCHANGED — 713 symbols, iowatch exports riding, gate
   baseline untouched. The Rings-0–1 library the spec's §5 table
   names EXISTS at I4 as the **embed-shape libcx**
   (`target/profiles/embed/libcx.*`, built over `code/`): same
   `cx_*`/`cx_code_*` declared ABI families, no Ring-2 code in the
   artifact, its live consumer is the embed profile tarball + its
   corpus lane. At I5 stream 4 (binding store access moves to the
   wire) the DEFAULT libcx re-cuts to Rings 0–1 and the ABI baseline
   moves deliberately, once, with that cut. Posted for owner review
   under the standing letter-acceptance ruling.

   **Ruling R2 — the local-effect pack set is exactly the §4-named
   set.** Gated packs (each `-d cx_pack_<name>`): `io`, `env`,
   `process`, `time`, `random`, `log`, `term` + `http_client`
   (the §4 cli-profile enumeration). Residual capability-guarded
   surfaces that REMAIN in the embed artifact — prof (`clock` guard),
   uuid (entropy), crypto (entropy on keygen), testkit (one `read`
   guard), sched — stay runtime-capability-gated (deny-by-default,
   CXER0271) rather than build-gated: the §4 enumeration is the
   ruled composition line; per-builtin build gates inside otherwise
   pure packs would fragment packs below the shippable unit. Recorded
   as a documented residual; a future owner letter may extend the
   enumeration.

   **The build matrix (design).** ONE cmd module, profiles = build
   flags ("pack membership per profile is data, recorded in the
   build", §4):

   | Profile | cx binary | Library | Composition |
   |---|---|---|---|
   | `data` | `cmd_data/` → `target/profiles/data/cx` (I2, unchanged) | `libcx-core` (I2, unchanged) | Ring 0 only; cannot-execute by construction |
   | `embed` | `cmd/` built with NO pack flags, no `cx_platform` → `target/profiles/embed/cx` | embed-shape libcx over `code/`, no pack flags → `target/profiles/embed/libcx.*` | Rings 0–1 core; local-effect packs OUT of the artifact |
   | `cli` | `cmd/` built with ALL pack flags, no `cx_platform` → `target/profiles/cli/cx` | — (cx is the deliverable) | Rings 0–1 + local-effect packs + http client |
   | `platform` | `cmd/` with all packs + `-d cx_platform` = today's `target/cx` | libcx over `platform/` = today's, ABI 713 | Rings 0–2 (default profile; today's shipped shape) |

   Mechanics: pack files gain V file-suffix gates
   (`*_d_cx_pack_<name>.v` — compiled only under the flag); dispatch
   sites (`stdlib_dispatch.v` chain, walker registrations, directive
   hooks) wrap in `$if cx_pack_<name> ? { }`; an excluded pack's
   names fall through to the same not-in-subset refusal class as
   Ring-2 names in a platform-less artifact (§4 profile refusals by
   construction). `CX_PACKS ?= <full set>` in vcx/Makefile keeps
   every existing target byte-compatible; embed builds pass
   `CX_PACKS=''`. The cmd daemon-verb files (fabric_serve,
   store_serve, store_rotate, store_token — the `platform.*`
   consumers) gain `_d_cx_platform` suffixes and `import platform
   as _` moves into a `_d_cx_platform` file, so a flag-less `cmd/`
   build IS the cli/embed profile: no platform import → live-but-empty
   registries → Ring-2 verb-word refusals by name (the cmd_data #426
   pattern, extended). Profile identity stamps via
   `-d cx_profile=<name>`; `cx -v`/`cx version` reports it at every
   profile.

   **Corpus gates (design).** Per §7 a ring's artifact MUST pass
   every fixture at or below its ring; profile lanes grade the
   PROFILE BINARY against corpus expectations (the extraction-gate
   CLI-lane precedent, generalized): data = the I2 lane (exists);
   cli = ring≤1 doc+eval corpus green through `target/profiles/cli/cx`
   + Ring-2 verb-word/name refusals; embed = ring≤1 corpus minus the
   gated packs' suites (suite files = pack boundaries in
   `conformance/stdlib/`), minus ring≤1 cases whose `grant=` names a
   gated-pack capability, PLUS refusal checks that gated-pack names
   refuse not-in-subset; platform = the full existing battery (the
   monolith lanes ARE the platform profile). Per-ring lane GROUPS
   (`test-ring0/1/2`) land in the root Makefile as #700's structural
   relief.

   **Installer (design).** `scripts/public/site/install` gains
   `CX_PROFILE` (default `platform` — the bare
   `curl … | sh` command installs today's asset names, unchanged);
   non-default profiles resolve `cx-<profile>-<os>-<arch>.tar.gz`.
   `scripts/release.sh` packages the matrix per platform; SHA256SUMS
   covers every asset.

2. **Ring-1 local-effect pack gates LANDED (2026-08-06; commit
   2fe8ec03).** Mechanism refinement over entry 1: the file gates are
   **`_notd_cx_no_pack_<name>`** (exclusion flags), NOT opt-in `_d_`
   suffixes — the default compilation of every existing call site
   (runners, in-module tests, benches, ad-hoc `v run`) keeps the full
   Ring-1 composition with ZERO changes, and only embed builds pass
   the exclusion set; opt-in flags would have handed every bare
   `v test vcx/code` an embed-shaped engine (a standing silent-lean
   footgun). Verified V semantics: `$if !flag ? { }` compiles the
   block when the flag is absent; `_notd_<flag>.c.v` works
   (should_compile.v). Eleven files renamed (io, env, process +
   process_pty.c.v, time, random, log, term, http + net_core under
   ONE http_client flag, sched); the raw C (cx_pty.c / cx_term.c)
   rides `#include` inside gated `.c.v`/`.v` hosts.

   **Sched joins the gated set by dependency closure** (entry-1 R2
   amended): stdlib_sched.v has hard compile edges into the time pack
   (TDateTime, decode_datetime, time_stdlib_builtin) — a pack that
   composes a local-effect pack is local-effect. Embed excludes NINE
   packs; cli passes no exclusion flags (= today's full Ring-1
   surface, sched included).

   **Purity/data moved OUT of pack files (compile-driven, survey
   confirmed by the compiler):**
   - NEW `datetime_core.v` (478 lines): the pure proleptic-Gregorian
     core — TDateTime + civil/calendar math + ISO-8601 and duration
     parsing + canonical string forms + `decode_datetime` — because
     `eval_range_datetime` (code.md §6.3 datetime ranges) is
     EVALUATOR core, and crypto (JWT exp math)/similar (date
     distance) consume it. The clock stays in the pack.
   - `effect_alignment.v` now owns the cap-name const tables
     (io_read_caps/io_write_caps/env_uncapped_prims/time_clock_prims/
     random_entropy_prims): purity classification is PROFILE-
     INVARIANT — a name's impurity never varies with artifact
     composition; dispatchers read the same consts, so the
     drift-canary property is preserved.
   - `stdlib_bundle.v` owns the env/random/sched `$embed_file`
     sources (embeds are DATA — the seam-H ring-2 store/journal/xap/
     fabric embeds set the precedent; a pack-less artifact still
     serves the CX wrapper source, whose builtins refuse as
     undefined callables).
   - `random_crypto_bytes` (the OS-entropy primitive) → stdlib_crypto.v
     (crypto keygen/nonces survive `-d cx_no_pack_random`; one
     definition, same module).
   - `$if !cx_no_pack_* ?` guards: dispatch chain (9 entries), eval
     env-chains (log/sched ×2 sites), SSE-client walkers (×2),
     matcher sched_reset_state, codec g_http_pool init;
     crypto_jwks_fetch refuses by construction without http-client
     ($if/$else — V type-checks past a comptime return).

   **Verification:** full-shape `v -check -shared code/` green
   (renames drop nothing — every pack has non-gated referents);
   embed-shape builds as a real dylib: **the declared cx_*/cx_code_*
   ABI minus EXACTLY the two iowatch callbacks (164 vs 166), zero
   mbedtls** (no TLS in embed — the §6 wasm direction); platform
   libcx over the renamed tree: **ABI IDENTICAL, 713**; in-module
   test lane 82/82.

3. **The §4 build matrix LANDED (2026-08-06; commit fea22144).** ONE
   cmd module, profiles = build flags. Daemon/operator verbs
   (store-serve, fabric-serve, store-health, store-token,
   store-rotate-kek) + the blank-alias `import platform as _` moved
   to `_d_cx_platform`-gated files (platform_verbs_d_cx_platform.v
   carries the SubcommandSpec entries + the registration import; the
   registry builder appends them under `$if cx_platform ?`). Default
   `make cli` passes `-d cx_platform` (CX_PROFILE_PLATFORM) — today's
   shipped cx byte-compatible. A flag-less cmd/ build IS the cli
   profile: no Ring-2 code in the artifact, daemon verb WORDS refuse
   by name rc=2 (#426 pattern; never file-arg fall-through). Embed =
   + CX_PACKS_OFF. NEW vcx targets: cli-cli / cli-embed / lib-embed
   (+-dev) under target/profiles/{cli,embed}/ + build-profiles(-dev)
   aggregating I2's data targets. Profile identity DERIVES from the
   build gates (compiled_profile/excluded_packs — no free-text define
   to drift); `cx -v` prints `profile <name> (packs off: …)` at every
   profile. Smoke: platform opens mem:// store, env/time live; cli
   env/time live + store-open refuses undefined; embed refuses
   env/time/store; refusal rc=2 across profiles.

4. **Per-profile corpus gates + the mis-tags they caught (2026-08-06;
   commit 85166d66).** NEW `tests/runners/profile_gate/profile_gate.v`
   — deliberately does NOT import platform; compiled bare it IS the
   cli engine, with CX_PACKS_OFF the embed engine. Grades every
   ring≤1 eval fixture in-process (mirrors code_eval_fixtures_test.v
   semantics: three-way grant policy, CXER0291 is_fn_value boundary,
   clamp_section, gates.cxd advisory/pending policy, same_shape/
   same_multiset/tol), plus per-pack + ring-2 refusal probes
   (user-undefined class; a CXER0271 denial would mean the pack IS in
   the artifact — fails) plus binary probes (profile line, verb-word
   refusals, pure eval). `make test-profile-gate` in vcx + root
   TEST_TARGETS. Per-ring lanes `test-ring0/1/2` (superset chain)
   activate as #700's structural relief; the data profile's corpus
   clause remains the I2 extraction gate.

   **First catches (the gate proves ring tags against the artifact
   frontier — all fixture-data repairs, C8 gaps):**
   - code.cxd svc family (25 cases: [?http-service]/[?http-client]/
     [?test-service-client] = the platform services substrate) →
     NEW per-case `eval-ring=2` (fixtures.cxs attr + fixture_loader
     `eval_ring` + `case_eval_ring` resolution: case eval-ring >
     case ring > suite eval-ring > suite ring). Chosen over per-case
     `ring=2` DELIBERATELY: the doc lane — and the I2 Ring-0
     extraction corpus (1564, byte-identity-pinned) — stays
     untouched; one case, two lane memberships, the code.cxd
     mixed-suite mechanism at case granularity.
   - ft-026 (store-composing) + sched-022/023/025/026/027
     (journal-composing durable timers) → per-case `ring=2`.
   - NEW fixtures.cxs `packs=` attr — declared cross-pack program
     dependencies, discovered at the embed composition: crypto JWT
     ×17 + locale date-format ×10 → time; i18n-045 + test-031 → io
     (fixture staging); module-resolve-manifest-override →
     http-client; program-sap-revoke-01 → env. The profile gate
     skips packs=-excluded cases; the packs' absence is pinned by
     the refusal probes. DOCUMENTED RESIDUAL: crypto's JWT verify
     and locale's date formatting are unavailable in the embed
     profile (they compose the time pack).
   - ring_query.cx eval lane learns the per-case resolution (dogfood
     CX patch).

   **Census after retags:** doc R0=1564 (UNTOUCHED), R1=2006 (−6),
   R2=692 (+6); eval lane R1=966, R2=25 (was blanket 991). Gate
   green: cli 2833 graded / embed 2262 graded, 0 failures;
   ring-tag-gate green; main battery fixture lane green (with
   CX_ENGINES — the bare invocation lacking engine flags fails
   db.cxd, pre-existing behavior, not a regression).

5. **Installer + release packaging (2026-08-06).**
   `scripts/public/site/install` gains `CX_PROFILE=data|embed|cli|
   platform` (default platform — the bare `curl … | sh` command and
   the stable asset name `cx-<os>-<arch>.tar.gz` are UNCHANGED);
   leaner profiles resolve `cx-<profile>-<os>-<arch>.tar.gz`; the
   lib-copy pattern widened to `libcx*.*` so the data profile's
   libcx-core installs. `scripts/release.sh` phase 2 packages the
   profile tarballs per platform (`make -C vcx build-profiles` under
   devbox; data = cx+libcx-core+cx.h, embed = cx+embed-shape
   libcx+cx.h, cli = cx only; SHA256SUMS globs every asset);
   `scripts/release_linux.sh` builds the same matrix inside the
   ubuntu-22.04 container (PROFILES_TARGET, dev-shape aware).
   README quickstart + RELEASE_PROCESS.md updated.
