# I2 — Ring-0 extraction: working ledger

**Status: OPEN** (2026-08-06, opened at the I1 exit — the identity epoch
closed at ef80e409 and merged back to the campaign line; this file is
I2's working ledger, the successor to `partition_I1_rebless.md`).
Phase row: `partition_impl_PLAN.md` Part B. Branch:
`impl/I2-ring0-extraction` off `design/651-516-partition`.

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

(entries begin at the branch cut)
