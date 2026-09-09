# RULED: 1272-a1, 1272-a2 — the §1.2 feature runtime contract carries a revision

Issue: cx-home/cx-private#1272. Ruled by Fable + owner, 2026-09-08 16:25 ET, on
the letters drafted on the issue. Recorded here as ruled; implemented at
`aa8a81b31` / `7ff87f799` on `impl/cx-C-1272`.

## What was wrong

`package.cxd`'s `[compatibility]` block is specified in distribution §2 as "the
XAP spec revision + toolchain floor the package validates against". Nothing
wrote it and nothing read it: `pkg-seal` never touched it and `pkg-install`
verified the exports listing and the signature chain only. Verified again at
HEAD before implementing — `grep compatibility vcx/platform/stdlib_xap_dist.v`
was empty, and `contract-revision` / `spec-revision` appeared nowhere in `spec/`
or `vcx/`.

So when §1.2 changed under #1210 HC-1 — every entry point takes the deployment
context `$host` in its first position instead of a bare store handle — a feature
packaged against the old contract installed clean and failed at its **first
read**, inside the deployment, at runtime. There was no install-time refusal
because there was no identifier to refuse on.

## RULED: 1272-a1 — 1(a), the revision is declared in the spec and derived

`spec/03-approved/xap/xap_feature_distribution_market.md` declares
`contract-revision: N` beside §1.2, with a one-line reason under each bump —
**that history IS the compatibility log**. The bump rule is normative: **N
increments when a module built against N-1 would fail against this tree**
(#1210 is the archetype). A `scripts/check_*` gate in the repo's roster idiom
refuses a commit that changes §1.2's normative body without changing N, and is
in `TEST_TARGETS`. `pkg-seal` writes N and the toolchain `VERSION` into
`[compatibility]`; `pkg-install` refuses a package whose N is below the host's
with `CXER4884`, naming both revisions and the package; a manifest with NO
`[compatibility]` block refuses the same way — **absence is not a pass**.

Refused: **(b)** a content hash of §1.2's text — it cannot say "compatible", a
typo fix would refuse every package in the field, and the first editorial pass
would teach operators to route around the check; **(c)** the release version —
a contract change coincides with a release boundary only by luck, and every
release would claim a contract break.

## RULED: 1272-a2 — 2(a), the boot-side check stays

Install-time is the braces, boot is the belt. A module can reach a runtime
without passing `pkg-install` (a dev checkout, a hand-placed tree), and
"install succeeded, boot refused" is the shape that wakes people up at night —
which is exactly why it must not be the only line.

## How the ruling was implemented, and the three decisions inside it

**1. The gate cannot decide whether a §1.2 edit is breaking, so it refuses
silence instead.** `scripts/check_contract_revision.sh` pins a `body=sha2-256:`
fingerprint of §1.2's normative body beside the declaration. A moved body reds
until the author records which kind of move it was, and both records are visible
lines in a diff: **bump** N and add a history row, or **re-pin** at the same N
(editorial). The escape is required by the ruling's own reasoning — 1(a) refused
option (b) precisely because a typo fix must not refuse the field — and it is
`make contract-revision-repin`, a deliberate act, never a side effect of another
target. Both halves are red-proofed: an edited §1.2 sentence and a hand-edited
constant each exit 1, and the restored tree exits 0.

**2. The revision reaches the binary GENERATED, not through a build define.**
`vcx/platform/xap_contract_revision.v` is produced by
`scripts/gen_contract_revision.sh` from the declaration and committed, the same
shape as `docs/llm` and its drift gate. A `-d cx_contract_revision` define was
the obvious route and is wrong here: `VFLAGS_VCX` carries no version defines, so
every `v test` build would read the fallback while the shipped binary read the
real value — one manifest field with two values depending on who built the
reader, which is the vacuous-gate class. The toolchain half is generated for the
same reason.

**3. The floor is scoped to a CODE-CARRYING FEATURE, and that is load-bearing.**
`xap_pkg_contract_check` is reached only for `kind=feature` (seal, the per-kind
install gate, host boot), and the revision stage runs only when the tree carries
`<name>.cx`. §1.2 is the *feature runtime contract*; a package that implements
none of it cannot be measured against it. A blanket floor would refuse
`packages/gtin` — `kind=library`, `[compatibility toolchain=0.12.0]`, its
manifest baked into the committed immutable registry store that
`xap-dist-025-git-registry-consume` installs from and pins by hash — and could
not have been fixed by editing that manifest, because the alias is immutable
(`CXER4887`). That fixture is a prior ruling about what a library install is,
and it outranks a widening this issue never asked for.

## `CXER4884` is a REUSE, and the registry row now says so

The pkg sub-band `4880–4889` is effectively full (`CXER4889` allocated,
`CXER4885` deliberately reserved-unallocated for partial-consent semantics). The
ruling's `CXER4884` is a reuse of `E_XAP_PKG_GATE_REJECTED`, and it is coherent
because the refusal happens *at* the per-kind install gate: "the install gate
rejected this package" stays one meaning with one more condition under it, and
the `stage=` attribute distinguishes them (`stage=contract-revision` alongside
`stage=exports`, `stage=compose-gate`). The §9-style registry row in the
distribution spec carries the compatibility clause explicitly rather than
letting the code acquire a third meaning nobody wrote down.

This is the opposite call from #1268 the same afternoon, where reusing
`CXER4867` was refused — and the difference is the reason, not the mood: there,
a type failure and an arity failure are different classes evaluated at the same
point; here it is the same gate with one more condition.

## RULED: 1272-a3 — the ABOVE-host direction refuses too (owner + Fable, 19:35 ET)

Drafted here as "not ruled", raised on the issue, and ruled **(a)** the same
evening. `pkg-install` and the boot check refuse a package whose
`contract-revision` is **above** the host's exactly as they refuse one below —
same code, same `stage=`, message naming both revisions **and the direction**.
A host cannot run a contract it does not implement; accepting it would be the
silent-lie shape this issue was filed to end, with the arrow reversed.

So the comparison is **exact agreement**, not a floor, and the refusal carries
`direction=below|above` because the two cases call for opposite actions: below,
re-seal the package with this toolchain; above, upgrade the host (or seal
against its revision). Printing an inequality and leaving the reader to work
out which side is old is the thing this attribute exists to prevent.

Fixture `xap-dist-059` pins it with a revision literally one above the host's,
as the ruling describes — which means a future §1.2 bump turns that case into an
equal comparison and reds it. That is deliberate, and it is the same
acknowledgment `xap-dist-056` carries: a bump is a statement about packages in
the field, and the corpus is one of the places that has to say so out loud.

## Fixtures

`conformance/stdlib/xap-dist.cxd`:

* **056** — seal COMPUTES the block: a draft declaring
  `contract-revision=99 toolchain=9.9.9` seals to neither. The revision is
  pinned as a literal, so a future bump reds this case on purpose.
* **057** — a correctly signed package declaring `contract-revision=1` (what an
  older toolchain's seal produced) refuses `CXER4884` at the install gate.
* **058** — the same package with no `[compatibility]` block: absence refuses
  identically.
* **025** (existing) is the scoping negative — the released `gtin@0.1.0` library
  still installs from the immutable registry store.
