# Schema and event evolution (stream 21)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 21, issue #693). Versioned
folds/upcasting for journals (replay v1 entries under v2 vocabulary), the
value-migration story for stored docs, and the schema-evolution
compatibility machinery the §8 promise currently lacks. Composes with
stream 5 (migration-as-recorded-computation) and shares stream 8's
pre-fold seam. Normative once approved; **post-I1 and additive, with
ONE reserved I1 slot** (AMENDED 2026-08-05, audit C1 — the original
"wholly post-I1" claim was false as written: §3's fold-id-carrying
snapshots require a *trusted, fail-closed* mismatch check, and a
trusted check on an UNSIGNED field is forgeable, so the fold-id had to
join the snapshot's signed preimage — which would have been a second
signing epoch, the forbidden shape. The repair: journal.md §4.8 now
reserves `fold-id?` in the `snapshot-canonical` signed preimage AT I1,
omitted-while-unset so pre-stream-21 signatures are unchanged; this
stream fills the slot when it lands, with no new epoch. Everything
else here remains composition over existing hashed artifacts).

**Worked example (M5):** `Order` v1→v2. The additive case (add
`[attr channel::atom]`): v1 docs validate under open-mode v2; the new E2
pair re-pins in `cx.lock`; folds upcast v1 entries with a pure,
Tier-1-addressed upcaster. The hard case (SPLIT `address::string` into
`ship-to`/`bill-to`): the pure half (`total → subtotal + tax`, computable
in-document) is a recorded computation; the impure half (parsing free
text against an external service) is FORCED OUT into a stream-6 command
(`[effects]`, `[idempotent]`, dedup key) whose output a pure upcaster
then references — no network call ever hides inside a replay. Replaying
10k v1 order events under v2 folds: parallel upcasting preserves
determinism (`[par]` reassembles source order — the stream-5 theorem
paying off), snapshots carry their fold identity, and a v1-anchored
`fold-from` under the v2 fold is a LOUD error, never silently-stale
state. The headline, and the answer to tag-numbered fields: **nothing is
ever overwritten, so migration is always additive** — identity is
schema-independent (canonical bytes, stable regardless of schema), and
evolution never perturbs an address.

## §1. Findings

1. **The verb named `migrate` is replication** — defined by its
   inability to change a byte (content-hash-preserving copy). The real
   transform primitive is `modify-doc` + `[using FN]`, whose transform
   is pure and capability-free; only the put is an effect.
2. The append-only wall is fixture-pinned: batch-migrating journal
   entries is excluded by a shipped negative fixture; compaction is
   copy-forward-verbatim. **Upcasting is read-side, always.**
3. **Snapshots are the hidden hazard:** a snapshot is v1-fold output
   frozen into a signed artifact; the `fold-from ≡ fold` equivalence
   fixture compares both paths under the SAME fn and cannot detect a
   vocabulary change; the retention cover rule as written admits
   pruning a prefix whose only surviving representation the v2 fold
   cannot interpret — a genuine data-loss path (#716).
4. The corpus's canonical evolution template is data-bin/ast-bin:
   new-reads-old by construction (zero-defaults), old-refuses-new
   loudly at the version check, **no silent-loss path in either
   direction**. The shipped upcaster exemplar is the predicate-migrate
   sweep: closed template set, loud residue, output oracle,
   fail-closed per file, never regex.
5. Two approved specs contradict on unknown vocabulary (market spec:
   downgraded features MUST skip newer event kinds — citing a §14.4
   fold rule that does not exist; identity model: unknown children MUST
   be rejected, "not silent tolerance"). The reconciling principle is
   XSP §5.0's: tolerate on discovery surfaces, reject on semantic
   surfaces, and tolerance is never the compatibility mechanism.
6. §8's "additive rules each spec already carries" has two EMPTY rows:
   schema additivity and event-vocabulary additivity have no rules to
   carry — this stream writes them. An adopter-facing comparison table
   already ships the undesigned claim (#716).

## §2. The journal seam (L146)

Upcasters are **pure entry→entry projections at stream 8's pre-fold
seam** — `[sequence entry] → [sequence entry]`, composed before
`fold-value`; the fold contract is untouched. **Version tags are PAYLOAD
vocabulary, never envelope** (the journal owns only the envelope; the
exact coin stream 8 spent for valid-time, spent the same way). The
upcaster registry is caller-supplied and Lane-2-attested — the journal
recognizes the seam, never the domain. **Order: upcast ∘ THEN the VT
projection** (an upcaster may synthesize the valid-time vocabulary for
v1 entries that predate it). `replay {at-seq}` uses TODAY'S upcaster —
which is precisely why the upcaster is identified (§3): a past-state
read is reproducible as a function of (entries, chain, fn, init), not
of a date.

## §3. Fold identity and the snapshot repair (L147)

- **Fold determinism widens from a triple to a quadruple:** same
  (entries, upcaster-chain, `$fn`, `$init`) → same result. The chain is
  itself a pure def — its **Tier-1 source address is the trust
  identity; Tier-2 rides for cache sharing** (the stream-5 dual form;
  no invented chain-hash — the `[$xap:compose]` precedent).
- **The chain identity lives in the ENV quadrant** of stream-5
  computation records: adding an upcaster changes every fold address
  exactly once, all caches go cold, none go wrong (the additivity
  contract doing exactly what it was designed for).
- **Snapshots CARRY their fold identity** (fn ⊕ chain ⊕ env, as a
  computation address) — **inside the signed preimage**: the fold-id
  fills journal.md §4.8's reserved `fold-id?` slot in
  `snapshot-canonical` (audit C1), so the check below is on a
  signature-covered field, never on forgeable envelope data.
  `fold-from` with a mismatched fold-id is a
  **loud typed error** (`CXER4640 E_JOURNAL_FOLD_ID_MISMATCH` — first
  code of this stream's `4640–4649` journal-band slice, sub-partitioned
  from stream 20's original `4617–4649` claim and registered in §9.6 on
  2026-08-05, audit C5+M5); the equivalence fixture becomes
  conditional-and-checkable. **The retention cover rule is read as
  covered-under-the-CURRENT-fold:** re-snapshotting under v2 is
  required before a v1-anchored prefix may be pruned — closing the
  data-loss path. Periodic re-snapshotting under the current fold is
  the NAMED maintenance discipline that bounds chain length.
- One journal, mixed payload vocabularies is legal and stated (the
  crypto one-algo-per-instance rule does not generalize: the algo is
  envelope, uniform by construction; vocabulary is payload,
  heterogeneous by construction).

## §4. Stored-doc migration (L148)

Migration = `get → pure transform → put → ref advance` — fully shipped
mechanics (immutable docs; E3 lineage; ONE CAS code). Rulings:
**`[migrated-from hash=<address>]` is a Lane-2 claim** (the
`[supersedes]` hash-linkage discipline reused — no second linkage
vocabulary); **migration is a FOURTH relation, representational** — it
never appears in the correction taxonomy and never alters valid time
(the fact did not change; the vocabulary did); no version fields on
values (E3 stands); per-doc migration provenance is Lane-2 or the
lineage entry, never store metadata. **Migration-as-recorded-
computation is a direct stream-5 instantiation:** a pure migration is a
computation record (addressable, cacheable — re-migrating an unchanged
doc is a hit; re-serialized-identical is free), and **an impure
migration is NOT a computation** — it is a stream-6 command with
`[effects]`/`[idempotent]`/a dedup key, loudly (the
enrich-during-migration line, drawn where it pays: no external call
ever hides inside a replay). Unforced-iterator batch runs force or
forfeit identity.

## §5. Schema lineage and the compat predicate (L149)

- `Order` v2 IS a different E2 type identity sharing an element name —
  nothing links them intrinsically (content-only identity stands).
  **The link is a Lane-2 `[schema-lineage [from sha2-256:…]
  [to sha2-256:…] [relation :additive|:narrowing|:split|:merge]
  [upcaster …]]` claim** (the type-binding shape, the provenance suite
  slot). The lineage graph must admit a UNIQUE path between any two
  endpoints — an ambiguous graph is rejected at registry load,
  fail-closed.
- **`compat?(v1, v2)` is a decidable Ring-0 pure predicate** over the
  declaration forms (modes, cardinality, `[req]`/`[opt]`/`[default]`,
  refinements, stream 16's join lattice), with the N-COMPOSE-1
  three-valued shape ruled normative: for every document valid under
  v1, validation under v2 yields **valid** or a **named diagnostic** —
  never silently-different meaning. `[req]` addition is BREAKING even
  in open mode (open waives undeclared content, not declared
  requirements — stated). Surfaced as `cx schema compat`.
  **Sequenced behind stream 16's L65/L66 validator repairs (I5)** —
  a checker over a fail-open validator would be theater; and for the
  stream-18 consumer the verdict is computed on the EXPORTED JSON
  Schema (the export is lossy; additive-in-cxs does not imply
  additive-in-export). A tool-schema evolution invalidates outstanding
  address-bound approvals BY CONSTRUCTION — correct, and stated so it
  reads as design, not bug.

## §6. Unknown vocabulary, reconciled (L150) + uncovered entries (L151)

- **The rule:** tolerate on discovery surfaces, reject on semantic
  surfaces; tolerance is never the compatibility mechanism (XSP §5.0
  ruled as THE principle; the identity model's reject-posture and the
  market spec's tolerance both survive, scoped). The market spec's
  downgrade-skip MUST survives as a **narrow, named, downgrade-only
  exception with VISIBLE skip counts** (the stream-8 redaction-count
  device reused — an instance of the erasure/compliance stream's
  generalized visible-count rule: count + attribution, in the value, at
  the point of omission; audit M7 cross-reference — never a silent
  path); its dangling §14.4 citation is
  repaired to point HERE (#716).
- **An entry no upcaster covers is a failure-channel `[err]` at fold
  time** — naming seq, hash, declared version, and the resolvable
  chain endpoints; never absence, never a skip. `verify` stays
  syntactic (coverage is a coherence question; the coherence verb
  reports findings). A **coverage pre-flight** — "would this fold
  cover all N entries?" — is a pure query over (declared versions ×
  lineage graph), converting mid-replay aborts into pre-execution
  diagnostics.

## §7. Migrate-on-read vs batch (L152) and sequencing (L153)

**Journals MUST migrate on read** (append-only; fixture-pinned);
**stores SHOULD migrate in batch** (new docs + ref advances;
non-destructive by construction — the old doc remains addressable;
dedup makes unchanged docs free; remote `[using FN]` already yields
location-independent addresses). Read-time doc migration without a put
is projection, not migration (a value whose address resolves nowhere —
E4 pressure), permitted but never the default. **Sequencing:** wholly
post-I1 additive; the campaign-plan row's inventory-#6 pointer is
corrected to items 2/7 (store as-of was ratified OUT by stream 8; the
value-migration phrase describes the version-identity and per-doc-
metadata gaps) — decision-log correction rides this ruling.

## §8. Corpus handoff (stream 14; M5 substrate)

The v1→v2 add-a-field family (open-mode validation; re-pin; upcaster
zero-default); the SPLIT family (pure split as computation; impure
split refused as computation + rerouted as command; totality residue =
loud per-entry err); the 10k-replay family (parallel upcast ≡
sequential; snapshot fold-id mismatch = loud; re-snapshot-then-prune
positive vs prune-under-old-fold negative); compat-predicate
three-valued fixtures incl. the `[req]`-in-open-mode breaking pair and
an export-lossiness pair; downgrade-skip WITH visible count vs
silent-skip negative; coverage pre-flight pair; lineage
ambiguous-graph rejection; `[migrated-from]` claim + the
migration-is-not-a-correction discriminator (folds unchanged by a
migration entry; changed by a correction).

## §9. Rulings ledger — RULED

Letters 146–154 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar): payload
version vocabulary + caller/Lane-2 upcasters at the shared pre-fold
seam, upcast-before-VT, today's-chain replay (146); the determinism
quadruple, chain-in-env, fold-id-carrying snapshots + the cover rule
read as current-fold (147); Lane-2 `[migrated-from]`, migration as the
representational fourth relation, pure-migration-as-computation with
impure migrations forced out to commands (148); `[schema-lineage]`
claims w/ unique-path enforcement + the three-valued Ring-0 compat
predicate sequenced behind the stream-16 repairs (149); the
discovery-vs-semantic tolerance rule + the visible-count downgrade
exception (150); failure-channel uncovered entries + the coverage
pre-flight (151); read-vs-batch asymmetry + the always-additive
headline (152); wholly-post-I1 + the plan-row pointer correction
(153); the hygiene batch (154, #716). Recorded in the campaign
decision log. Spec-edit map: journal.md (seam §, fold-id snapshots,
cover-rule reading, new CXER), store.md (migrate/modify-doc
cross-refs), schema.md (compat §, lineage cross-ref), cxdm/semantic
cross-refs, xap_feature_distribution_market.md (citation repair +
visible counts), xap_identity_model cross-ref, 13-comparison rewrite,
governance §9.1 (version-tooling promise honesty), stream-4 handoff
(vocabulary negotiation = the feature-token model, transcript-covered).
