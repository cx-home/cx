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
