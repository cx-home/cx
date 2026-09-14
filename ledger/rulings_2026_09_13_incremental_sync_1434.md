# Ruling 2026-09-13 — #1434 (#728 component 3): incremental sync — placement, decided before the spec (1434-a)

Recorded by the integrator under the owner's standing delegation, **before** any line of
`spec/03-approved/std-lib/sync.md` or `conformance/stdlib/sync.cxd` existed, because OL-15 makes a
module's ring, spec directory, code directory and namespace a DECISION rather than something a
reader discovers from where the files landed. The token is **1434-a**; #1434 is #728 component 3,
filed as its own issue by the owner's letter of 2026-09-13 (2(a),
`ledger/rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md`) and sequenced after
#1430.

## Inputs read before the decision

- #1434 and #728 §3 — "Cursors, watermarks, and change capture so sources are synced incrementally
  rather than re-pulled"; **builds on** journal, store, `db_access` engines, sched; **exit shape**
  spec plus conformance for resume-after-crash, duplicate suppression, out-of-order arrival.
- `spec/03-approved/std-lib/connector.md` §1.4, §2.1, §2.2, §3.2, §6.5, §12, §13, §15 row 30 — the
  kit this module rides on. §6.5 already states that `sync`, `watermark` and `since` are
  deliberately absent from the kit "filed as its own issue and sequenced after this one", and §1.4
  consumer 2 names "a connector feature's ingest — the same engine on the host's or runner's
  cadence" as the caller this module serves.
- `ledger/rulings_2026_09_13_mail_hosting_deferred_connector_line_1085e.md` decision 2 — CX owns the
  protocols and the foundation, never a system connector.
- `ledger/rulings_2026_09_06_connector_is_a_feature_728.md` (CK-1 … CK-6) and
  `…_open_items_728.md` (CK-7 … CK-10).
- `spec/03-approved/std-lib/store.md` §6.1, §11 (content addressing, and "journal payload docs"),
  `journal.md` §2.1.1, §2.2, §3.2, §3.3, §3.4, §4.4, `sched.md` §2.2, §2.5, §3.1, §3.2,
  `audit.md` §2, §5, §11, `live.md` §8 (the adapter contract: the closed rung ladder, cursor mapping
  in two directions, and the ingest dedup key over the external record's identity tuple).
- `registry/modules.cxd` — the header's column contract and the `connector` row's shape.

## 1434-a — the module is `sync`, Ring 2, and where each of its four dimensions lives

| Dimension | Today | After #1427's cutover |
|---|---|---|
| ring | **2** | 2 (the ring is the decision; it never moves) |
| namespace | `cx-stdlib/sync` | `cx-platform/sync` |
| spec | `spec/03-approved/std-lib/sync.md` | `spec/03-approved/platform/sync.md` |
| corpus | `conformance/stdlib/sync.cxd` (`ring=2`) | `conformance/platform/sync.cxd` |
| source | `stdlib/sync.cx` — **owed**, not written on this branch | same |
| code | `vcx/platform/stdlib_sync.v` — **owed**, not written on this branch | same |
| error band | `CXER6400–CXER6499` | same |

**Ring 2, by the membership test** (`core/cx_partition.md` §10, carried from
`ledger/partition_I3_ring12_split.md`): a module that imports the store or a protocol module, or
that SERVES, is Ring 2. This one reaches `store` (the watermark and the dedup index are persisted
there), `journal` (captured changes land there), `sched` (the cadence) and the connector engine (the
walk that pages a source). It lives in the ring of its highest verb. Its pure half — every decision
it makes — is Ring 1 by purity and stays inside the Ring 2 module, exactly as `connector`'s twelve
pure verbs do; a Ring-1 CONSUMER of that half is the split trigger (1427-e) and none exists.

**The registry row is the placement**, not this prose: `status=current` with `owed='source code'`
and the `-to` columns, the shape `connector`'s row carries, so `make placement-gate` refuses a tree
where any of the four dimensions disagrees. `conformance/gates.cxd` carries the same advisory row
shape `connector`'s does, and flips to `enforced` in the commit that lands the code.

## The scope 1434-a fixes

Exactly #1434's "What CX owns", and nothing beyond it:

1. **The cursor/watermark contract** — per source, resumable across restarts, exactly-once-effective
   through content-address dedup; the watermark persisted in `store`, the captured changes landing
   in `journal`, the cadence taken from `sched`.
2. **Polling-diff capture** as the portable baseline every connector gets from the kit's engine:
   page → diff against the last watermark → emit the delta.
3. **Log-based capture** as a per-engine capability, where a `db_access` backend exposes one.
4. **The declaration vocabulary** a connector carries so the engine knows which of the three a
   source supports.

## What stays the consumer's — written as an INVARIANT, never as a deferral

A provider's own delta mechanism — a directory graph's delta links, a CRM's modification stamps, a
mailbox's `UIDVALIDITY`/`MODSEQ` — is the consumer's, and it is expressed **through** this contract
inside the consumer's own connector feature. That is decision 2 of 1085-e applied one component
along: CX owns the protocols and the foundation, not the system connectors.

The spec states this as a guarantee the contract owes — *what a consumer can express through the
contract with no CX code, no CX release and no CX permission* — and the completeness checklist is
the proof obligation for it. It is not a list CX declined to write, and the word "deferred" does not
appear against it.

## Why this decision, and not the alternatives

- **Not a section of `connector.md`.** The kit is the transport engine; a sync is a stateful,
  scheduled, store-backed and journal-backed loop AROUND it, and `connector.md` §6.5 already
  refused the verbs. Folding it back in would give the kit a store dependency it does not have and
  would make every connector pay for a cadence it may not run.
- **Not a section of `journal.md` or `live.md`.** `live.md` §8 owns the adapter contract's rung
  ladder and its ingest dedup key, and this module CONSUMES both rather than restating them; the
  journal owns durability and the chain, un-re-specified here.
- **Not Ring 1.** The watermark is durable state; a Ring-1 module cannot hold it.
- **Not `cdc`.** The issue's own title is incremental sync, the polling baseline is not change data
  capture, and naming the module after the mode it uses least would mis-sort every reader.

## Consequences filed with this decision

- The spec is written once, in the tree #1427 phase 1 left, with no normative sentence naming the
  `cx-stdlib/` prefix — the rename is then the only change #1427's cutover makes.
- The band `CXER6400–CXER6499` is registered in `governance.md` §9.6 **with the spec**, the `audit`
  (#1422) and `connector` (#1430) precedent, because every code is asserted by a conformance case
  that exists before the implementation.
- No module code lands on this branch. `owed='source code'` in the registry row is the declaration
  of that, and the advisory corpus is the implementation list.
