# RULED: 1195-a — the §1.2 runtime contract is checked wherever a package is
# ASSEMBLED or ENABLED, not only where it is installed

Date: 2026-09-07. Issue: cx-home/cx-private#1195. Campaign: v0.18.0 close-out
(#1354), Lane 1. Ruled by the campaign worker under #1354 rule 7 (long-term-best
standard, recorded before implementing).

## What was measured at HEAD (c4a2d1326), before designing anything

The filed shape — a feature named `acme-party` whose module lives in `party.cx`,
manifest declaring `[exports [def name='acme-party/readout'] [def
name='acme-party/apply']]` — run through the whole publisher pipeline:

| stage | result at HEAD |
|---|---|
| `[$xap:pkg-seal …]` | **ok** — `[sealed hash=… manifest=…]` |
| `[$xap:pkg-publish …]` | **ok** — `[published alias='acme-party@1.0.0' …]` |
| `[$xap:pkg-verify …]` | **ok** |
| `[$xap:pkg-install …]` | **CXER4884** — "the manifest declares [exports] but the tree has no acme-party.cx code entry (§1.2)" |

So the check the issue asks for EXISTS and is correct. It is reachable from
exactly ONE of the three paths a package travels:

1. `registry/publish.cx` — `pkg-tree` → `pkg-seal` → `pkg-sign` → `pkg-publish`
   → `pkg-verify`. Never installs, so never gated. A publisher ships a package
   that no host can install and hears nothing.
2. `[$xap:pkg-install …]` — gated (`xap_pkg_gate_feature`, the §1.2 arm).
3. `[$xap:host …]` boot — its own acquisition loop
   (`stdlib_xap_host_notd_wasm32_emcc.v`): fetch by pinned hash → cross-check
   the row → full §3 verify chain → pull the spec layer → `has_code :=
   xap_pkg_has_entry(tree, '${name}.cx')`. When the basename differs `has_code`
   is **false**, the module-load loop's `if !f.has_code { continue }` skips the
   feature, `register_module_members` never runs, `env.closures['<f>:readout']`
   is absent, and `xap_host_readout` returns the bare `[readout feature=<f>]`
   wrapper. That is the reported empty readout, and it is silent for the life
   of the deployment. The host holds the manifest `m` at that exact point and
   never asks it whether it declared `[exports]`.

The manifest already carries the answer at every one of those points. Nothing
was missing but the question.

## The ruling

**1195-a.** The §1.2 runtime contract — a feature's `<name>.cx` code entry and
its `[exports]` listing imply each other, and every declared def must exist in
the packaged code — is a property of the PACKAGE, so it is checked at every
point that assembles or enables one, from ONE shared checker:

- **seal** (`xap_pkg_seal`) — the earliest moment the tree and the manifest are
  both in hand, and already the §2 kind-aware manifest-validity moment
  (`xap_pkg_validate_draft`, which refuses a library without `[exports]`, a
  library with `[needs]`). Extending it from *manifest alone* to *manifest
  against tree* changes no meaning: seal is where a manifest becomes a claim
  about a specific tree, so it is where a claim about a tree can first be false.
- **host boot** — beside the existing verify chain, on the manifest it already
  fetched, BEFORE `has_code` is consulted. A feature that cannot present its
  declared surface refuses the boot with a named error; it never enables into a
  deployment that will answer reads with an empty wrapper.
- **install** — unchanged. It stays, and is not made redundant by the two
  above: a manifest can be hand-assembled and put straight into a store, and an
  older toolchain's package can be installed by a newer one. Defense in depth
  is the point; the seal check is not a substitute for the gate.

The three call ONE function over (tree, manifest). No second scanner, matching
the discipline `xap_pkg_exports_check` already states for itself.

**Error code: `CXER4884` (`E_XAP_PKG_GATE_REJECTED`) at all three**, with the
same message text. The refusal is the same refusal; a reader should not have to
learn which stage produced it to recognise it, and the existing install-lane
fixtures 046/047 pin exactly that code.

### What this DELETES

Nothing is removed. The install-time arm stays where it is; `has_code` stays as
the spec-only-feature discriminator it is (a feature with no code entry AND no
`[exports]` is legitimate and still boots untouched). What is deleted is the
*reachable silence*: after this there is no path on which a basename mismatch
produces a successful publish or a booted deployment.

### The options refused, and why

- **(b) Fix it only at seal.** Cheapest, and the issue says item 1 alone closes
  it. Refused: it closes it for packages sealed by this toolchain and leaves the
  host's own acquisition path — a SECOND unchecked route, which the issue's
  own symptom actually travels — reporting success on an unserviceable feature.
  A gate that a hand-assembled or older package walks past is not the gate the
  §1.2 contract is written as.
- **(c) Fix it only at the host, as a read-time diagnostic** — have
  `xap_host_readout` say "no contract module" instead of serving the empty
  wrapper. Refused: it makes the failure *legible* but keeps it LATE. The
  deployment still enabled a feature it cannot serve, and every reader pays for
  the publisher's mistake. §1.2's own words are that behavior travels with the
  feature; a feature whose behavior did not travel has not met the contract and
  must not enable. Refusing at enable is the stricter order and the one the
  host already uses for every other acquisition failure.
- **(d) Make the basename non-load-bearing** — have the host accept any `*.cx`
  entry, or read the entry path out of `[exports]`. Refused: it is the larger
  change and the worse one. `<name>.cx` is load-bearing in FOUR independent
  places already (`xap_pkg_module_source`'s `pkg:` resolution, the install gate,
  the host's `has_code`, the §1 layout), a package may legitimately carry more
  than one `.cx` entry (a feature and its vendored helper), and "the entry point
  is whichever file happens to be there" is not a contract. The convention
  stays; it becomes ENFORCED and STATED instead of implicit.

## Scope of the landing

All three items the issue asks for, in one change:

1. seal verifies its own manifest against its own tree (issue item 1);
2. the host refuses at enable, not at read (issue item 2 — the hard half, not
   filed away);
3. the authoring guidance states that the module basename must equal the feature
   name and what happens when it does not (issue item 3).

Spec: §1.2 gains the enforcement-point sentence; the §11.16 lane row names all
three points; the `[$xap:pkg-seal …]` surface row states the cross-check.

## Out of scope, explicitly (not a silent drop)

**Libraries are NOT checked at seal.** §1.2 is the FEATURE runtime contract;
a library's module-surface check belongs to §2 and the install gate (fixture
017). Widening the seal arm to libraries was written, measured and REVERTED:
fixture 004 (`xap-dist-004-seal-pins-tree-hash`) seals a toy `kind=library`
whose single tree entry is the literal text `code` while its manifest exports
`toylib/id`, so a library exports check at seal reds it. That fixture is a
prior ruling about what seal IS — the tree-hash pin — and per the campaign's
corpus rule it outranks a widening #1195 never asked for. Recorded here rather
than filed as an issue because it is not a defect: a library with a bad
`[exports]` is already refused at install and at every `pkg:` load. If it is
ever wanted at seal it is a self-contained change plus fixture 004's tree; this
landing makes it no harder.

## The measurement that shaped the fixture work (do not lose this)

A refusal at seal does NOT surface as itself through the publisher chain the
existing install-lane fixtures are written as. Measured at HEAD with a draft
seal already refuses (a `kind=library` without `[exports]`, fixture 006's
shape) followed verbatim by 047's chain:

```
[err code=cx-err:CXER4886 message='E_XAP_PKG_NOT_FOUND: no published alias "door@1.0.0"' ...]
```

The seal error is swallowed: `$sealed@manifest` on an err yields nothing,
`get-doc`/`sign`/`put-doc` carry that along, and `pkg-publish` never sets the
alias, so `pkg-install` reports the MISSING ALIAS. So moving the check to seal
would silently flip fixtures **046**, **047** and **049** from `CXER4884` to
`CXER4886` — three of the four §11.16 lanes the spec's own coverage table claims are
enforced, turned into assertions about an alias lookup. That is the "gate still
green, coverage gone" failure this corpus exists to prevent. (Fixture **017**
seals a `kind=library` and is untouched, per the scope note above.)

Therefore those three fixtures are RE-CAST, not flipped: they assemble the
package **hand-sealed** — `[$store:put-doc $s $tree]` for the tree hash, pinned
on the draft as `hash=`, then sign → put-doc → publish — which is what
`pkg-seal` does mechanically, minus the new gate. Measured at HEAD, the
hand-sealed 047 shape reaches the install gate and yields the identical

```
[err code=cx-err:CXER4884 message='E_XAP_PKG_GATE_REJECTED: the manifest declares [exports] but the tree has no door.cx code entry (§1.2)' stage=exports]
```

so the install-lane assertion is preserved EXACTLY while the lane it tests is
reached by construction rather than by the absence of an earlier check. This
also demonstrates the defense-in-depth claim above rather than asserting it: a
package assembled without `pkg-seal` still meets the install gate.
