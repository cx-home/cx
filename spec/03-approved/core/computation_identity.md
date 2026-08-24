# Computation identity and the deterministic result cache (stream 5)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 5, issue #677). Implements the §14 L7a
ruling: computation identity = hash(Tier-2 fn, Tier-1 inputs, environment,
capability-set); environment MINIMAL + ADDITIVE (runtime version,
builtin-set id, schema dialect) as a canonical CX value; host-dependence
is a conformance bug, never an identity axis. Normative once approved.

**Worked example (M5):** `price-order` (`code:sha2-256:813bea…`, pure) ×
order `sha2-256:4ea31c…` × env `(0.15.0, <builtins-hash>, 0.8)` × caps
`()` ⇒ one computation address. Node B, holding neither the source nor
the order, serves the cached total; the requester re-hashes to verify.
Negatives: a runtime patch bump ⇒ new address, cold cache, never a wrong
answer; a reformatted order ⇒ SAME address, cache hit; `[?meta]`
annotation ⇒ same address (fails today, #708, I1). The headline pricing
expression contains a `*`-head and is unhashable until I1's L80 fix — the
example is the acceptance probe for that manifest item.

## §1. Findings

1. **Purity, not the cap-set, is the determinism gate** — §6.5.1's
   effect-totality theorem makes a pure computation's result provably
   cap-set-invariant, while the same section DISCLAIMS determinism
   ("a separate property, not asserted here"). `pure ⇒ deterministic`
   is new normative work this spec owes.
2. **`[par]` breaks it today:** output order is unspecified without
   `[ordered]`, yet purity is "the parallelization license" — a pure,
   checker-accepted body can yield order-nondeterministic results.
3. **Tier-2 collides on arity/shape and is clean-room irreproducible**
   (stream 12 W-22/W-23, ruled L28 — this spec depends on that fix) and
   is **forbidden as a trust input** (identity-model rule) — a Tier-2
   fn key alone cannot carry the verifiable-claim use case.
4. **The environment quadrant is empty:** no in-language runtime-version
   surface; no builtin-set id under any name (`cx_features` tracks
   build-gated backends — exactly the host variance L7a forbids);
   schema dialect exists (bare semver).
5. **Cap-set-as-CX-value is ruled (security C4) and unimplemented** —
   the runtime form is a V struct with two fail-opens (unknown grant
   names silently ignored; per-resource scoping stubbed) — #713.
6. The shipped precedents: journal `snapshot`/`fold-from` IS incremental
   recompute for the linear case; `[$xap:compose]` ("pure,
   deterministic, env-free … cacheable and content-addressable by its
   Tier-1 hash") is the best in-tree worked example; store dedup +
   immutable-ETag caching are the storage half, already built.

## §2. The record (L102)

The `[computation …]` record is a canonical CX value whose field
containers are **maps** (self-canonicalizing under §2.11.1 key sort —
element attribute/child order is insertion-significant in both tiers, so
maps avoid pinning a bespoke field order):

```
{computation: {
  fn:     {code: "computes-as:sha2-256:<hex>", ; Tier-2 — the SEMANTIC key
           source: "sha2-256:<hex>"},          ; Tier-1 of def text — the TRUST key
  inputs: {1: "sha2-256:<hex>", region: "sha2-256:<hex>"},
  env:    {runtime: "0.15.0", builtins: "sha2-256:<hex>",
           schema-dialect: "0.8"},
  caps:   {read: true, net: ("api.example.com:443")}}}
```

> Spelling note (reconciled at implementation, I5 stream 5): the fn slot's
> Tier-2 key is the `computes-as:<algo>:<hex>` CLAIM token —
> `[$cx:computation-id]`'s result. The example originally showed the
> `code:` address form, which the LATER F1′/A1 remediation ruling
> (2026-08-08, `partition_remediation_register.md`) retired as confusable
> with document addresses: computation identity is a claim, never an
> object address. Same key, the ruled spelling.

**computation-id = plain Tier-1 of that value** (`sha2-256:<hex>` — the
E1/L81 precedent; no `computation:` prefix, no new registry row). The fn
slot carries BOTH addresses: Tier-2 for cache sharing across
alpha-equivalent code, Tier-1 source for trust decisions (the
Tier-1-only rule stands unmodified).

## §3. Environment semantics (L103)

- **runtime = the FULL semver.** A patch can fix a determinism bug, and
  a determinism fix MUST invalidate; correct-by-construction beats hit
  rate. The additivity contract is the escape hatch: a new env field
  appends, every address changes exactly once, the old cache is cold,
  never wrong, no negotiation.
- **builtin-set id = Tier-1 hash of a canonical CX value listing the
  two closed, governance-amended spec tables** — the §4.1 directive
  registry and the §6.5.x purity classification — host-independent by
  construction; NEVER `cx_features` or a binary hash. The honest
  residue (a behavioral change to a native primitive with no table
  change) is covered by the runtime-version field, stated normatively.
- **schema-dialect = the bare semver** (permanence-confirmed
  domain-free). A pure `cx:version` builtin is added so records are
  constructible in-language.

## §4. Capability set (L104)

The `caps` component is **in the hash** — with the normative note that
for pure computations it is provably result-invariant (§6.5.1) and is
included for record completeness and the forward extension to
witnessed/impure computations, not for correctness. The canonical form
is the C4 CX-value (implemented with this stream): grants as a map over
the closed nine-name list; scopes canonicalized (path roots normalized,
host globs lower-cased); `allow_all` NORMALIZES to the explicit full
set + a private-range-policy field (one canonical form, not two); the
ENTRY set is the basis (narrowing and cancellation-revocation are
interior). The two shipped fail-opens (unknown names ignored;
`cap:resource` token stub) fix loud — #713.

## §5. `pure ⇒ deterministic` (L105 — the new theorem)

Ruled normative over the closed lists, with its holes closed:

- **`[par]` reassembles source order ALWAYS.** Unordered output was
  unspecified, so no program can legitimately depend on it — the
  cutover is free; `[ordered]` becomes a documented no-op (tombstoned).
  Float aggregation order under `[par]` is therefore source order —
  no reassociation.
- **Locale audit mandated:** no pure builtin may be locale-sensitive
  (`upper`/`lower` use Unicode default casing, never host locale) —
  audited at finalization, each with a fixture; a locale-sensitive pure
  builtin is precisely L7a's "host-dependence is a conformance bug."
- **Map traversal pre-registered:** no map-traversal surface exists in
  the pure list today (latent, not live); any future one MUST iterate
  in canonical key order — closed before it can open.
- The theorem inherits stream 22's EV-* pins (arg order, let*,
  closure snapshots, pull counts) as prerequisites — grade-D areas are
  named blockers.

## §6. The cache (L106)

Pure-only, fail-loud: constructing a computation record for an impure
fn (checker-classified) is a typed error. Results are ordinary stored
values; the binding is an alias in the `computation/<addr>` namespace —
**no new store API, no `[?memo]` directive in v1** (an explicit
store-mediated lookup keeps the cache honest and visible, matching
fail-loud). Never cached: budget exhaustion, non-termination (nothing
to store), host-tunable-limit errors. **Unforced Iterator inputs make a
computation non-addressable** (fail-loud; force it first — EV-BUDGET's
floor bounds the cost). Table inputs address via canonical text (the
D22/L86 rule).

## §7. Tapes: the impure extension (L107)

A debug tape is the DUAL of a computation identity — it manufactures
determinism a posteriori by recording every nondeterministic boundary.
The extension is composition, not a new axis: a witnessed impure
computation is `hash(fn, inputs ∪ {tape}, env, caps)` — the tape is an
ordinary Tier-1-addressed input. The tape's recorded host environment
is DATA (an input), never an identity axis; stated normatively so the
two mechanisms read as complementary.

## §8. Sequencing (L108)

Computation addresses are **defined from I1 onward** — this stream adds
no hash-affecting change to existing artifacts (it is a new
composition) and sits after I1 without joining it; every pre-I1 address
is undefined, not migrated. Ring: identity composition + vocabulary =
Ring 0/1; result cache + namespace = Ring 2 store; import gates
unchanged. Fixtures build on stream 1's `identity_hash.cxd` and stream
12's Tier-2 pair-properties (both pre-I1 families).

## §9. Corpus handoff (stream 14)

The M5 pricing computation as the end-to-end fixture (same fn + same
order + same env ⇒ same address; reformat ⇒ hit; patch bump ⇒ miss;
meta ⇒ hit post-I1); record canonicalization pairs (field order
irrelevance via maps; allow_all ≡ explicit-full); `[par]` source-order
discriminator pairs (with float sums); locale probes per audited
builtin; impure-fn fail-loud negative; unforced-iterator negative;
tape-composed identity fixture.

## §10. Rulings ledger — RULED

Letters 102–108 **ruled (a) 2026-08-05 under the standing acceptance
ruling**: map-shaped record + plain Tier-1 id + dual fn addresses
(102); full-semver runtime + spec-table builtin-set id + `cx:version`
(103); caps in the hash w/ the invariance note + C4 canonical form +
fail-opens fixed (104); `pure ⇒ deterministic` w/ `[par]`→source-order
always and the locale/map-traversal closures (105); pure-only visible
cache, alias namespace, no new API (106); tapes as inputs (107);
post-I1 address epoch (108). Recorded in the campaign decision log.
Spec-edit map: code.md §6.5.1 (theorem + [par]), §7.3 ([ordered]
tombstone), security.md §2/C4 (caps value), modules/cx.md
(`cx:version`), new computation-identity section beside
code-identity.md, store.md (namespace note), debug.md §6a cross-ref.
