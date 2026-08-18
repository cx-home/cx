# Partition evidence — approved-spec inventory for the #651 §10 baseline

**Campaign:** #651/#516 (see `partition_campaign_PLAN.md`). **Date:** 2026-08-04.
**Method:** exhaustive sweep of `spec/03-approved` (normative), `spec/02-working`
+ `spec/01-new` (staged), per-topic, with explicit NOT-FOUND findings.
**Status:** evidence, not normative.

## Shipped and normative (the §10 foundation)

| Topic | Where | What |
|---|---|---|
| Value model | `core/cxdm.md` §1–§9 | 9 scalar kinds, 7 node kinds, containers, sequence-flat, equality/EBV/coercion. Storage refinements (`instant`, `duration`, `decimal`, …) encode to the nine — not new kinds. |
| Canonical form | `core/canonical.md` | Lossless vs strict canonical; §1.4 identity tiers; full text-emit rules; validity precondition (no canonical form for invalid docs). |
| Tier-1 data identity | `canonical.md` §1.2/§1.4, `abi.md` §2.6, `store.md` §4/§11 | SHA-256 of strict canonical bytes — universal, substrate/encoding/tier-invariant content address. |
| Tier-2 code identity | `core/code-identity.md` | Def-level: alpha-normalized (de Bruijn), name-excluded, deps resolved to callee hashes (Merkle DAG), SCC handling. Opt-in code namespace, never conflated with Tier-1. |
| Canonical binary | `core/data-bin.md`, `canonical.md` §4 | "Always strict canonical — no non-canonical binary form." Self-describing, hardened, versioned. NOT presentation-lossless by design. |
| Schema identity | `core/schema.md` §13.1 | Schema refs by content hash (`SHA-256(cx_to_data_bin(parse(schema), strict))`); readers MUST verify. Bundle/unbundle = hash-keyed schema store. |
| Canonical errors | `core/code.md` §9 | `[err]` value shape; **four outcome channels** (value/absence/failure/reported-problems, no conflation); CXER registry single-sourced in `governance.md` §9.6. Exceeds the doc's §Milestone-1 ask. |
| Authority as values | `std-lib/authz.md` §2, `core/security.md`, `xap.md` §22 | `[principal]`/`[capability]`/`[delegation]`/guardian — all homoiconic CX data; caps (effects) and authz (intents) AND-composed; slice-scoped, attenuating, time-bound. |
| Provenance | `xap_identity_model.md` §7; `journal.md` §2.2/§2.6 | One grammar: detached Ed25519 claim **about a Tier-1 hash** (`[provenance [subject hash=…] [signer] [claim] [at] [sig]]`); Tier-2 never a trust input. Journal entries carry actor/authority/ts/prev-hash/hash inside hashed bytes; "attribution recorded, never adjudicated." |
| Metadata side-band | `core/code.md` §4.2 | `[?meta {…} FORM]` inert annotations: ride with the value, reflectable via `meta-of`, **excluded from identity/equality**. Clojure-metadata model, stated. |
| Value-level confidentiality | `cxdm.md` §12 | Secrets: metadata on the value, redacted at every output boundary, declassify via `secret-reveal` capability. The ONE value-level authority-adjacent mark. |
| Expected-version machinery | `journal.md` §3.2; `store.md` §6.3; remote-protocol §3.14 | `expect-prev-seq` (CXER4604); fast-forward-only refs (CXER1114); alias CAS over the wire (CXER1704, validate-then-apply all-or-nothing). |
| Consistency (scoped) | `journal.md` §4.3/§4.4; `xap.md` §14/§16; `store.md` §6/§11 | Per-stream committed-prefix reads; seq (never ts) is the ordering authority; no cross-stream linearization claimed; linearizable ref advancement; immutable docs, no latest pointers; "one consistency contract" for clients. |
| Temporal (scoped) | `cxdm.md` §2.3; `journal.md` §3.5/§4.3; `authz.md` §3.4 | date/datetime kinds (+instant/duration refinements); `replay at-seq` time-travel; authz `as-of` decision instant. |

## Confirmed NOT FOUND (the genuine §10 gaps)

1. **Value-level type identity** — nothing like `commerce/Order` on a value.
   `::T` draws from a CLOSED TypeName set (unknown ⇒ CXER0107). A schema's
   "type name" is the element name, scoped to one schema document. Namespaces
   qualify element/attribute names only.
2. **Value-level version identity** — no version field/attr on values or
   stored docs, BY DESIGN (immutable store, no latest pointers; "latest" is
   the alias/ref layer). What exists is CAS at refs/journal (above).
3. **Expression identity** — Tier-2 covers `[?def]` only (§5 defers even a
   function index). No identity for an arbitrary expression/quoted tree,
   though strict-canonical hashing of any tree is mechanically available.
4. **Bitemporal semantics** — no valid-time vs transaction-time anywhere;
   journal `ts` is explicitly non-authoritative metadata.
5. **Isolation vocabulary** — "serializable", "snapshot isolation",
   "read-your-writes", "eventual" appear NOWHERE in the corpus. No
   multi-document/cross-stream transaction primitive.
6. **Store as-of reads** — no time- or seq-indexed store read surface.
7. **Per-document store metadata** — put-doc takes (handle, doc) → hash;
   opts are store-scoped. Doc metadata is out-of-band by convention.

## Staged items that bear on identity

- `01-new/cxstore_universal_object_model.md` — universal cross-document
  dedup/version-sharing/cross-tier object identity, proposed for store.md.
- `01-new/cxstore_set_identity_index.md` — **records the ruling that identity
  must depend on content only, never content+policy** (set-semantics stay out
  of the primary canonical; derived secondary index instead). Load-bearing
  precedent for the §10 envelope question.
- `02-working/xap_grammar_composition.md` — N-COMPOSE-0: verbs/nouns
  namespace-qualified per owning feature; frames/keys deliberately not.

## Note

XAP-tier symbolic error names (`:CXER-UNAUTHORIZED`, `CXER-XSP-*`) have no
numeric allocation in governance.md §9.6 — registry-hygiene follow-up
candidate, independent of this campaign.
