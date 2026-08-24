# Erasure and compliance in the immutable substrate (stream 20)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (stream 20, issue #692 — the LAST stream spec). Right-to-be-forgotten vs content-addressed immutability + hash-chained journals, designed up front: crypto-shredding (per-subject destroyable keys), redactable journal entries (detached payloads — chains verify with payloads gone), tombstone semantics. Binding input: bitemporal L119 (VT shreddable with the payload; visible redaction counts; no fourth lane, no envelope ownership of domain data). Normative once approved; the detached-payload entry form joins the I1 identity epoch (now-or-never); everything else is additive.

**Worked example (M5):** an RTBF request for order `o-5521`'s customer —
recorded as an `erase-subject` command with declared authority
(idempotent: a resubmission returns `deduped=true`, never a second
destructive act); scope is a head-set across streams + a doc-address set
across stores; the subject key (SEK) is destroyed, shredding every
payload sealed under it with ZERO in-place writes; every surface reports
its redaction count visibly; `verify` stays `valid=true` with the
payloads gone (the chain covers the payload ADDRESS, not the bytes) and
the envelope attribution — who erased, under what authority, when —
stays intact and hashed; pre-shred snapshots go stale by fold-id and are
re-taken; `get-doc` on a shredded address returns an `[erased]` tombstone
value, never a 404 and never "corrupt."

## §1. Findings

1. **The shred substrate is half-built:** shipped envelope encryption is
   tenant-KEK → per-object-DEK, keyed by the PLAINTEXT hash (graph never
   sees ciphertext); `store-rotate-kek` already destroys a key
   deliberately and reports a balanced one-line account
   (`objects = rewrapped + already-current`). Crypto-shredding is the
   missing THIRD key tier — a per-subject SEK between KEK and DEK.
2. **The address covers PLAINTEXT, by deep design** (dedup,
   cross-substrate portability, integrity re-hash, E4's universal
   invariant, the whole rotation dividend all depend on it) — and the
   campaign already rejected hash-salting once, for the same
   existence-oracle reason, choosing per-tenant pool isolation instead.
3. **The journal hash covers the payload BYTES** — so a detached-payload
   entry form is not expressible without a hash-affecting change; but
   the whole journal fixture family already re-blesses at I1 (#712), so
   the marginal cost of joining is near zero and the cost of NOT joining
   is infinite.
4. Tombstones already ship in the store (T/X manifest records; the
   pack `kind_tombstone` slot); `secret` (cxdm §12) is an output-boundary
   mark, not at-rest erasure; the visible-count rule is already deferred
   to L119 by four other streams; `verify`-stays-syntactic is already
   ruled twice (streams 8, 21) — stream 20 makes three.

## §2. Crypto-shredding: the three-tier key hierarchy (L181)

**KEK (tenant, KMS-resident, rotatable in place) → SEK (per subject, the
destroyable tier) → DEK (per payload).** Destroying the SEK renders
every DEK under it unrecoverable, shredding those payloads with no write
to the sealed bytes. The envelope already records its wrapping key-id, so
a shredded envelope is self-identifying — and `envelope_open` gains a
**typed shredded-not-corrupt finding** (today it conflates shredded with
tampered). **Evidence basis (CORRECTED 2026-08-05, audit M33): the
finding CANNOT be derived from key absence** — destruction,
misconfiguration, and KMS outage are one observable at the unwrap
site. The typed finding is evidenced from the **journaled
shred-request** (the M29 reconciliation applied at read time): unwrap
fails + an attributed erasure record covers the address →
`shredded`; unwrap fails with NO covering record → `unavailable`
(fail-closed, ambiguous between outage/misconfig/tamper — never
reported as lawful erasure). KMS-side destroyed-key attestations
remain rejected (a provider dependency the spec avoids). The re-wrap primitive from rotation IS the SEK-rotation
primitive; destruction in the reference KMS = removing the key, after
which reads fail closed by construction. The shred emits the §9.1-shaped
balanced report.

## §3. The address covers plaintext; neutralize the oracle elsewhere (L182)

**Branch A stands: the Tier-1 address covers PLAINTEXT** — Branch B
(address-over-ciphertext) is REJECTED on the record: it kills dedup,
makes identity key-dependent (a Ring-2 concern deciding Ring-0
addresses — a ring inversion), destroys determinism and fixture
stability, and breaks `[supersedes]`/Lane-2/`pkg:`/the crypto-agility
program. The surviving-digest oracle against low-entropy PII is
neutralized at a different layer, ruled jointly: **(a) a per-record
`nonce=` inside the hashed payload** raises entropy above brute-force
while keeping `hash = f(content)` exactly (the nonce IS content; dedup is
correctly lost only for nonced records); **(c)** per-tenant pool isolation
bounds the cross-tenant probe surface (already ruled — note it targets
the cross-tenant adversary, not the surviving-chain reader; the nonce
in (a) is what defeats the latter). **(d) hash-salting stays REJECTED**
(cite, do not reopen).

**Nonce requirements (normative; audit C7 — without these the (a) leg
is inoperative: a counter or timestamp nonce is fully "per-record" and
restores the oracle completely):**

- The nonce MUST carry **at least 128 bits of CSPRNG entropy**
  (`cx-stdlib/random`'s CSPRNG surface or the platform equivalent). It
  MUST NOT be derived — in whole or in part — from journal coordinates
  (`seq`, `ts`, `stream`, `prev-hash`, tenant, actor), from the payload
  itself, or from any counter/clock: a derivable nonce is recomputable
  by the adversary the oracle defense exists to defeat.
- The nonce lives **inside the sealed payload and nowhere else** — it
  is covered by the payload address (the nonce IS content) and is
  destroyed by the same shred that destroys the payload. Persisting it
  outside the sealed payload (index, log, envelope, side table) defeats
  the defense and is non-conformant.
- `nonce=` is a **reserved payload attribute** (registered alongside
  `subject=` in §4's reserved set).
- A nonce is **MANDATORY on every payload carrying `subject=`** —
  writing a subject-bearing payload without one is a refusal
  (`CXER4619 E_ERASURE_NONCE_REQUIRED`, the first code of this
  stream's slice), never a warning. *(CODE CORRECTED 2026-08-12, W2:
  this spec's original `4617` premise went stale between ruling and
  implementation — `CXER4617 E_JOURNAL_RESUME_GAP` shipped with the U1
  delivery work (2026-08-11) and `CXER4618 E_JOURNAL_TEMPORAL_INVALID`
  with stream 8; journal.md §8 already records the corrected slice
  `4619–4639`. Shipped codes never renumber; the RULE is unchanged,
  the number moves — the registry-repair amend-in-place precedent.)*
- **Witness family:** the §9 witnesses MUST include a negative that
  FAILS on a low-entropy or derived nonce — at minimum: a fixture
  asserting refusal of a subject-bearing payload with no nonce, and a
  verification witness that rejects a nonce byte-equal to any journal
  coordinate or shorter than 16 bytes. The dedup/address-parity
  witnesses alone cannot fail on a weak nonce (they pass for
  `nonce=1`, which is the trap).
- **Unnonced legacy payloads (the RTBF-on-legacy-data case, §4):** a
  payload written before this rule — or without `subject=` — has no
  operative oracle defense; shredding it leaves a **confirmable
  digest** (an adversary holding a low-entropy candidate plaintext can
  confirm it against the surviving address). The operator remedy is
  stated, not implied: **re-write-with-nonce before shred** (a
  stream-8 supersedes-correction that re-lands the payload nonced,
  then shred both generations), or a **documented residual-risk
  acceptance** recorded with the shred-request. `verify` reports
  unnonced shredded payloads in its redaction accounting.

*(Non-normative routing note — audit M40: the former leg (b), a spec
assertion that a surviving digest of a shredded nonced payload "is not
recoverable personal data", is STRUCK as normative text — a compliance
deliverable cannot self-certify its own legal conclusion, and digests
of low-entropy identifiers are widely treated as pseudonymized personal
data. The technical posture is carried by legs (a)/(c)/(d) above; the
legal characterization question is routed to counsel and recorded as a
design-intent claim only.)*

## §4. Subject vocabulary (L183)

`subject=` is a **reserved payload attribute** (a DID or a
tenant-scoped subject-id), and `nonce=` is reserved alongside it (the
§3 oracle-defense nonce; mandatory whenever `subject=` is present) —
the stream-8 valid-time template exactly:
Lane 1 rejected (identity-excluded ⇒ forgeable, uncovered by the hash),
Lane 3 rejected (envelope ownership of domain data), **Lane 2 the
retroactive escape for already-stored values** (the RTBF-on-legacy-data
case). Consequence stated as design, not bug: since the declaration
lives in the shreddable payload, after shredding the substrate cannot
name the subject FROM the payload — it names it from the journaled
shred-request record (§7), which is why that record is mandatory.

## §5. Detached-payload journal entries (L184 — the I1 item)

The entry canonical form becomes
`seq+tenant+stream?+actor+authority+ts+prev-hash+PAYLOAD-ADDRESS`, the
payload stored separately (sealed under the subject key). (Reconciled
2026-08-05, audit C1: this is journal.md's now-normative
`entry-canonical` preimage — same wrapper element, same field order,
same non-default-only `stream` binding — with the payload body child
replaced by the payload ADDRESS; this spec previously stated the
`stream?` form while journal.md omitted it, and the wrapper name
appeared in no spec at all.) **`verify`'s
three checks all pass with payloads destroyed** — the chain covers the
address, which is intact — which is exactly the mandate. The
payload-address is an **envelope field** (a chain coordinate, not domain
data — so the closed-lane list is not violated; stated, as it is the
obvious objection). **One entry form, hash-affecting, joins the I1
manifest** — no dual-accept `entry-version=2` (the standing
cutover-first rule; and per-entry `verify` ambiguity is exactly what
§4.2 forbids). It rides the existing `stream`-omitted-when-`:default`
byte-identity trick so a non-shredded default-stream entry's bytes move
only as much as I1 already moves them.

## §6. Tombstones, verify, and the visible-count generalization (L185, L186)

- **The generalized rule, authored once here:** *every surface that
  omits data for erasure reasons reports the omission count and the
  omission's attribution, in the value, at the point of omission.*
  (CLAIM CORRECTED 2026-08-05, audit M7: the original sentence said
  streams 3/7/8/21 cross-reference this generalization — none did;
  each cites stream 8's L119 precedent, of which this rule is the
  generalization, and stream 7's F7 is a different phenomenon
  entirely. The reconciliation pass adds the real cross-references in
  streams 3 and 21; stream 8 is the precedent's home and needs none.)
- **The tombstone is a typed `[erased subject? at= authority= actor=
  shred-request=]` element** on the VALUE channel (SAP §1 — a lawful
  erasure is a finding, not a fault) — a deliberate divergence from cxdm
  §12.5's string marker (different job: §12.5 withholds bytes at emit
  while the type survives; a tombstone records at-rest destruction), so
  it takes a distinct name (`[erased]`, never `'‹redacted›'`).
  Attribution always survives (it lives in the never-shredded envelope)
  — the strongest sentence for a compliance reviewer.
- **`verify` stays syntactic (L186):** chain verify stays `valid=true`
  with payloads gone; **`:payload-missing` is NOT a chain-break reason**
  (else every shredded journal reports invalid forever, destroying the
  audit story); payload integrity is an ADDITIVE report axis
  (`redacted=N payloads-verified=M`). `snapshot-verify` is untouched.
  **Reconciliation (ADDED 2026-08-05, audit M29 — without it,
  unauthorized deletion is observationally identical to lawful shred
  and `redacted=N` delivers a count without the attribution §6's own
  generalized rule demands):** `verify` MUST reconcile every
  payload-missing entry against an ATTRIBUTED erasure record (the
  journaled shred-request whose scope covers it, or its tombstone);
  the report becomes `redacted=N unattributed-missing=K` — **any
  `K > 0` is a LOUD finding** (a payload gone with no lawful erasure
  record is evidence of tampering or key loss, never silently counted
  among the redactions). The corpus gains the negative fixture: a
  payload destroyed with no shred-request → `unattributed-missing=1`,
  loud.
- **`get-doc` gains the three-way answer:** never-existed (CXER1121) /
  unreconstructable (CXER1120) / **lawfully erased (`[erased]` value,
  value channel)**; erasure is server-asserted, never a client-inferred
  404 (the stream-4 wire coordination).

## §7. Derived-artifact reach (L187 — the hardest part)

Shredding MUST reach every derived surface that may hold the plaintext,
and the enumeration is normative: **snapshots, compacted segments,
rotation targets + segment index, archived predecessors, retention
`archive=` stores, registered materializations + `[?materialize]`
checkpoints, columnar `__cx_doc`, the stream-5 pure-computation visible
cache, stream-6 dedup records, replay tapes.** **Dedup-record
carve-out (ADDED 2026-08-05, audit M31 — a three-way conflict was
unruled: the `erase-subject` command's OWN dedup record is inside its
shred reach, destroying it re-arms a second destructive act on replay;
the record is subject-keyed, making it a digest oracle; and retaining
it collides with the retention-window rule):** the erase-subject
command's dedup record is **EXEMPT from its own shred reach** (the §7
shred-request carve-out extended — the records that prove an erasure
happened are not erasable by it), and it is **keyed on an opaque
CSPRNG token** (the §3 nonce discipline applied to the dedup key:
never the subject id, never derivable from it — so the surviving
record confirms nothing). **Precedence for every OTHER dedup record:
shred reach wins over the retention window** — a dedup record whose
command payload carried the subject is shredded with the payloads,
accepting the narrow consequence (a post-shred replay of THAT command
is no longer deduplicated) as strictly better than retaining
subject-keyed digests; the idempotent-replay guarantee is preserved
exactly where it matters by the exempt erase-subject record.** A
signed snapshot cannot
be edited, so the mechanism reuses **stream 21's fold-id**: a shred
advances a shred-generation in the ENV quadrant, every pre-shred
snapshot's fold-id goes stale, `fold-from` against it fails loud, and
re-snapshotting under the post-shred fold is forced — closing the
data-loss path with no new invalidation machinery. The shred-request is
itself a recorded command (stream 6: `[effects]` checked-and-enforced,
`[idempotent]` with `deduped=true` on replay, authority journaled); its
scope is a head-set. Missing any enumerated surface is a compliance
failure — the exhaustive list is a load-bearing deliverable.

## §8. Legal hold (L188)

A legal hold is a **signed Lane-2 `[legal-hold [subject|hash …] [signer
did:…] [at …] [sig alg=:ed25519 …]]` claim** (the retroactive,
independently-verifiable, identity-neutral shape Lane 2 exists for).
**Enforcement is a PRECONDITION on the `erase-subject` command, not
advisory** (the honest caveat: a detached claim can be ignored by a
shredder that does not consult it, so the check must be normative and
loud — the `[effects]` checked-and-enforced posture). Hold-beats-shred;
the refusal is a loud typed error naming the hold claim, holder, and
scope; never a partial shred. **The hold also blocks the forced
re-snapshot** (§7), or shredding happens by the fold-id back door — a
genuine interaction, ruled: a held subject suspends both the shred and
its derived-artifact regeneration.

**Serialization (ADDED 2026-08-05, audit M30 — hold-beats-shred was
unachievable for any hold landing after the precondition check, since
the KMS destroy is irreversible):** holds are JOURNALED to a per-tenant
**hold-stream**; a hold binds **from its journaled position onward** —
a hold not yet journaled does not bind (the honest rule; anything else
promises a race no substrate can win). The `erase-subject` command's
precondition **pins the hold-stream's head** (the M26 `[requires-at]`
pin, reused verbatim) and **re-checks it under the writing commit
lock** (a B3 admission read): a hold journaled between check and
commit moves the head, the pin goes stale, and the shred refuses. The
**KMS destroy executes strictly POST-COMMIT as the forward-only
pivot** (stream 10's erasure step-class): once the shred-request entry
commits with the pin satisfied, no later hold can bind that shred —
by position, visibly — and the destroy proceeds; a hold that lost the
race binds every FUTURE shred and is reported against the completed
one in the shred report.

## §9. Ring, bands, sequencing (L189)

Conflict/tombstone/hold **value shapes are Ring 0** (they appear in
canonical bytes; identity must be product-independent); the key
hierarchy, shred walk, detached-payload machinery, and `verify` axis are
**Ring 2**; the `erase-subject` command clause is Ring 1, its effect
point Ring 2; shred verbs are out of the Ring-0 `data` profile.
**Hash-affecting → I1:** ONLY the detached-payload entry form (§5).
**I5-STRUCTURAL (RE-LABELED 2026-08-05, audit M32 — previously
mis-claimed additive):** the SEK tier. The claim "the envelope already
carries variable-length key-ids" was true but not sufficient:
per-subject keys MULTIPLY the shipped one-backend-per-key_id
architecture (`encryption.v`'s registry maps each key-id to one
backend instance) — inserting the destroyable middle tier is a
**keying-backend refactor** (key-id → (KEK, SEK, DEK) resolution with
SEK-absence as the fail-closed shred signal), named here so I5 budgets
it as structure, not a field. **SEK custody, specified:** SEKs are
KMS-resident under the tenant KEK's custody domain (same KMS, same
operator boundary — never application-held); the reference KMS holds
them as named keys `sek/<tenant>/<subject-token>` where the subject
token is the §7 opaque dedup token, NOT the subject id (the key
NAMESPACE must not be a subject oracle either); destruction is the
KMS key-removal primitive, after which unwrap fails closed by
construction. **Additive (post-I1):** tombstone reads, the `verify`
axis, the visible-count rule, legal-hold claims, the shred report,
fold-id shred-generation. Replica shred-reach is FILED (stream 9 joint
requirement), not solved here — stated so nobody reads the reach list
as replica-inclusive. Bands (REPAIRED 2026-08-05, audit C5+M5; SLICE
RE-CORRECTED 2026-08-12, W2): journal `CXER4619–4639` reserved for this
stream — the original `4617–4649` claim overlapped stream 21's need for
new journal-band codes (sub-partitioned 2026-08-05), and the 2026-08-05
`4617–4639` slice itself went stale when `4617` (U1 delivery
resume-gap, 2026-08-11) and `4618` (stream 8 temporal-invalid) shipped
inside it; journal.md §8 records the operative slice (stream 20:
4619–4639; stream 21: 4640–4649), first code `CXER4619
E_ERASURE_NONCE_REQUIRED` executed at W2. Store surface: `CXER1144–1149` reserved in the extended
§9.6 store row — the original "`CXER1143+`" rested on the false premise
that store ships through 1142: shipped `CXER1143 E_STORE_OPEN_CONFLICT`
was test-pinned but unregistered, and is now registered in store.md §13
+ §9.6, with this stream's reservation starting at 1144. #720 filed.

## §10. Corpus handoff (stream 14; M5 substrate)

Subject-key hierarchy (SEK destroy → shredded finding, not
corrupt/not-found; KEK rotation over a store with shredded subjects
keeps the report balanced); **the headline: `verify valid=true` with
payloads destroyed**, `:payload-missing` never a chain break; the L119
visible-count fixture + its silent-under-report negative twin; the
tombstone three-way discriminator (never-existed / corrupt / erased);
snapshot reach (pre-shred fold-id goes stale → `fold-from` loud;
re-snapshot-then-prune positive vs prune-under-pre-shred-fold negative;
columnar `__cx_doc` + materialization-checkpoint shred); RTBF
end-to-end for `o-5521` (command w/ authority, idempotent replay,
head-set scope, chain green, attribution intact); legal hold
(blocks shred AND re-snapshot; released → proceeds; unsigned →
fail-closed); the oracle/entropy family (nonced-payload dedup;
plaintext-vs-encrypted address parity stays green; **plus the §3
weak-nonce negatives — audit C7: refusal of a subject-bearing payload
with no nonce (`CXER4619`), rejection of a derived/short nonce — the
dedup and parity witnesses alone pass for `nonce=1`, which is exactly
the trap**).

## §11. Cross-stream coordination

Stream 4: the tombstone is a distinct wire response (not not-found);
erasure never spec'd onto the retiring CSRP plane. Stream 9: destroying
a key locally does not reach replicas — a shred must propagate over the
same feed a revocation does (§7 of stream 4); filed as a joint
requirement. Stream 10: a cross-stream erasure IS a cross-stream atomic
operation — handed to stream 10's saga/escrow vocabulary. Stream 21:
fold-id reuse (§7); the shredded-payload fold outcome is a REDACTION
FINDING with a visible count, reconciled with stream 21's uncovered-
entry err (a missing upcaster is a fault; a lawfully-shredded payload is
a finding — the distinction stated). Stream 8: L119 discharged. Stream
19: all shred-related digests use multiformats-named tags; `genesis:`
sentinel.

## §12. Rulings ledger — RULED

Letters 181–189 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar): the three-tier
key hierarchy w/ typed shredded findings (181); address-covers-plaintext
+ the nonce/isolation/document-it oracle answer, ciphertext-address and
salting both rejected on the record (182); `subject=` as a reserved
payload attribute, Lane-2 retroactive escape (183); the detached-payload
entry form as the ONE I1 hash-affecting item, payload-address an
envelope field (184); the visible-count generalization + typed `[erased]`
tombstone on the value channel + the three-way `get-doc` (185, 186);
`verify` stays syntactic w/ an additive payload axis (186); exhaustive
derived-artifact reach via fold-id shred-generations (187); legal hold as
an enforced Lane-2 precondition blocking shred AND re-snapshot (188);
ring/band/sequencing + the registry repair #720 (189). Recorded in the
campaign decision log. Spec-edit map: store.md §9 (SEK tier, shred
verbs, get-doc tombstone), journal.md §2.2/§4.2 (detached entry form —
I1), §2.8/§4.9 (shred reach + fold-id), §3.6 (`verify` axis), cxdm §12
(tombstone-vs-secret distinction), authz/vc (legal-hold claim),
governance §9.6 (store band repair + new codes), cx_partition §8
(erasure as part of the archival/compatibility promise), streams
4/9/10/21 handoffs.
