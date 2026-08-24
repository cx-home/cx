# CX value map — the top capabilities per ring, for business readers

**Status:** positioning document (NON-normative — the spec is the only
source of truth; every claim below carries a `Backing:` pointer to the
spec/gate that makes it defensible).
**Audience:** executives comparing this platform's value against other
investments. Written to be concise, plain, and trustworthy: each item
says what the capability is, why it matters, and the business value —
and carries an honest status tag.
**Status tags:** `SHIPPED` = implemented, conformance-gated, on the
integration line. `LANDING (#NNN)` = ruled and specified; the
implementation is scheduled at the named tracker landing.

The ring model in one line: **Ring 0** is the data layer (parses and
identifies data; embeds anywhere; cannot execute anything), **Ring 1**
adds execution (programs, queries, authority), **Ring 2** is the
operating platform (storage, history, wire, live data) — reached over
the network, never embedded, which keeps the layers below small and
auditable.

---

## Ring 0 — the data layer

1. **One universal address per value.** `SHIPPED`
   Every piece of data has a single cryptographic address computed
   from its content. Reconciliation — the largest hidden cost in every
   B2B integration — collapses to comparing two hashes. Fewer
   integration engineers per partner, fewer disputes, faster partner
   onboarding.
   *Backing:* `spec/core/canonical.md` §1.2/§1.4; `cx hash` /
   `cx:hash`; the `identity_hash` conformance family.

2. **Same meaning everywhere, guaranteed.** `SHIPPED` (contract
   document's formal graduation is owner-gated)
   A value is identical whether stored, sent, queried, rendered, or
   handled by an AI agent — contractually, not by convention.
   Eliminates the "it worked in system A but not system B" incident
   class: direct reduction in outage hours and on-call spend.
   *Backing:* the semantic value model contract
   (`spec/02-working/semantic_value_model.md` §5, the E4 invariant).

3. **Types without a registry.** `SHIPPED`
   Two companies agree on a data shape by exchanging one hash — no
   shared server, nothing to operate or trust. The data-contract
   infrastructure competitors must build, host, and secure is simply
   absent from the budget.
   *Backing:* `spec/core/schema.md` §13.1; `cx:type-binding` /
   `cx:type-binding-verify` (`spec/modules/cx.md` §2.1); fixtures
   cx-113…cx-116.

4. **Exact money math.** `SHIPPED`
   Decimals are exact and scale-preserving by design ($1.10 is never
   1.0999…, and 1.10 is not the same identity as 1.1). Removes a whole
   audit-finding category; finance-grade arithmetic is a checkbox for
   CFO sign-off in billing, ledger, and pricing products.
   *Backing:* the decimal/bigint kinds ruling
   (`spec/_archived/decimal_bigint_kinds.md`); `spec/core/cxdm.md`
   scalar kinds; identity fixtures idh-022/idh-023.

5. **A parser that cannot execute.** `SHIPPED`
   The data-only build contains no execution engine — verified at
   build time, byte for byte, by a standing gate. The security
   questionnaire answer that shortens enterprise procurement:
   "processing untrusted input can't run code" is structural, not
   policy.
   *Backing:* `spec/03-approved/core/cx_partition.md` §4 (profiles);
   the extraction + profile gates in the build (`extraction_gate_cli`,
   `profile_gate`).

6. **Every format, one model.** `SHIPPED`
   JSON, XML, YAML, TOML, CSV, and Arrow read and write faithfully
   through one core. One team maintains one pipeline instead of N
   format-specific ones; migrations between formats stop being
   projects.
   *Backing:* `spec/core/conversions.md` (the codec registry);
   the conversions conformance suite.

7. **Semantic diff and patch.** `SHIPPED`
   Differences are computed on meaning, not text lines. Change review
   over data (prices, configs, contracts) becomes precise — lower
   review labor, fewer bad changes shipped.
   *Backing:* `cx:diff` / `cx:patch` (`spec/modules/cx.md`); the diff
   conformance suite.

8. **Schemas that fail closed.** `SHIPPED`
   Validation with open/strict/closed modes; a typo can never silently
   weaken checking, and a schema's mode is part of its identity. Bad
   data is stopped at the door instead of discovered at quarter close.
   *Backing:* `spec/core/schema.md` §2/§9/§10 (the header element;
   unknown mode is a load error); schema_validate conformance suite.

9. **A fifty-year format.** `SHIPPED` (spec+corpus sufficiency is the
   ruled bar; graded continuously)
   The specification plus its test corpus is ruled sufficient for
   anyone to rebuild a conforming reader from scratch; canonical text
   is the eternal preservation form. No vendor lock — including on the
   reference implementation. An asset-longevity and exit-risk answer
   boards actually ask about.
   *Backing:* `spec/_archived/clean_room_implementability.md`;
   the governance clean-room clause; the archival-guarantee section of
   the partition spec.

10. **Fast bulk without a second system.** `SHIPPED`
    The columnar binary wire carries the same identities as the text
    form. Analytics-grade throughput without buying and reconciling a
    separate analytics representation.
    *Backing:* `spec/core/data-bin.md`; the data-bin conformance
    families (chunked/compressed/schema-driven/Arrow).

---

## Ring 1 — the execution layer

1. **Programs are data with addresses.** `SHIPPED`
   Code, queries, and config share the value model, so a program has a
   hash like any document. This is the enabler for everything below —
   you cannot approve, audit, or price "exactly this computation"
   unless computations are addressable things.
   *Backing:* `spec/core/code.md` §6.4.3 (quasiquotation + the
   expression-identity promise); `spec/core/canonical.md` §11.4
   (closure over lowered quote results); fixture cx-094.

2. **Reproducible computation, by construction.** `SHIPPED` (identity
   verb live; the visible result cache is `LANDING (#677)`)
   Pure computations are deterministic — a theorem of the model, not a
   team discipline — and each carries an identity of function +
   inputs + environment. "Show exactly what produced this number"
   becomes a lookup: audit and regulatory-replay costs drop from
   forensic projects to queries; identical work is never paid for
   twice.
   *Backing:* `spec/02-working/computation_identity.md` (pure ⇒
   deterministic); `cx:computation-id` (`spec/modules/cx.md`).

3. **Side effects are declared and enforced.** `LANDING (#678)`
   A command states what it touches; the runtime enforces the
   declaration — it is the discriminator between a command and a pure
   function. Blast radius is known before anything runs: incident
   prevention rather than incident response.
   *Backing:* `spec/02-working/commands_effects.md` (the `[effects]`
   clause, checked-and-enforced).

4. **Delegated authority with budgets.** `LANDING (#678)`
   Authority is granted explicitly, can only be narrowed, and carries
   metered bounds. The control that makes autonomous automation
   insurable — you can state, in writing, the maximum an agent or
   script can do or spend.
   *Backing:* `spec/02-working/commands_effects.md` (`[bounds]` on the
   delegation; commit-point debit; value-shaped exhaustion).

5. **Approve exactly the code that runs.** `LANDING (#678, #690)`
   Propose mode binds a human approval to the precise program text's
   address; anything else is refused at commit. A compliance-grade
   answer to "who approved this action?" — the AI-agent governance
   story enterprises are currently blocked on.
   *Backing:* `spec/02-working/commands_effects.md` (propose mode,
   address-bound approvals); `spec/03-approved/x/agent_tool_projection.md`
   (approvals bind the definition text's address).

6. **Double-execution protection built in.** `LANDING (#678)`
   Idempotency keys are first-class, derived from the request itself
   when not supplied. The double-refund / double-shipment class of
   financial defect is removed at the platform level, not per team.
   *Backing:* `spec/02-working/commands_effects.md` (idempotency:
   explicit-key-wins + normalized-argument derived key).

7. **One query tier that optimizes itself.** `SHIPPED`
   Queries have canonical plans with their own addresses; equivalent
   phrasings share one plan and one cache. Compute spend on repeated
   analytical work shrinks organization-wide without asking teams to
   coordinate.
   *Backing:* `spec/core/code.md` §7.8/§7.9 (membership + plan
   address); `spec/03-approved/core/planar_algebra.md`; fixtures
   cx-100/cx-101.

8. **Optimization never trades correctness.** `SHIPPED`
   Rewrites apply only where proven safe; anything unsafe stays exact
   and loud. Performance work stops producing subtly wrong numbers —
   protecting trust in every dashboard the business runs on.
   *Backing:* `spec/03-approved/core/planar_algebra.md` (the err-totality
   rule: pushdown only for established-total predicates).

9. **AI tools derived, not maintained.** `LANDING (#690)`
   Command definitions project automatically into agent tool schemas
   (MCP). The AI-integration backlog — hand-writing and drift-fixing
   tool wrappers — goes away; new capabilities are agent-ready the day
   they ship.
   *Backing:* `spec/03-approved/x/agent_tool_projection.md` (one
   descriptor model; the projection is pure and derived, never
   materialized).

10. **Run third-party logic safely.** `SHIPPED`
    Untrusted code executes in a sandbox that can only narrow the
    caller's authority — never widen it — with recursion and library
    ceilings enforced. Opens a partner/extension ecosystem (a revenue
    surface) without opening a security hole.
    *Backing:* `spec/modules/cx.md` (`cx:eval`: library-set narrowing,
    recursion ceiling); `spec/core/security.md`.

---

## Ring 2 — the operating platform

1. **A store that works like git for data.** `SHIPPED`
   Content-addressed documents, named refs with visible history
   (including forced moves), one conflict vocabulary with two
   expectation encodings. "Who changed what, when, and to what" is
   intrinsic — the audit-trail line item disappears from every
   application built on it.
   *Backing:* `spec/std-lib/store.md` §6; the E3 lineage rulings
   (`spec/02-working/semantic_value_model.md` §4); store conformance
   suite (store-log, branch CAS).

2. **A tamper-evident system of record.** `SHIPPED`
   Events are hash-chained; state is rebuilt by deterministic folds;
   verification is a built-in verb. Prove-the-ledger for regulators or
   counterparties on demand — trust as a product feature, sold rather
   than argued.
   *Backing:* `spec/std-lib/journal.md` (chained entries, folds,
   verify, signed snapshots); the journal conformance suite.

3. **Time travel on business data.** `LANDING (#680)`
   Both "what was true on March 3" and "what did we believe on
   March 3" are queryable — valid time and record time are separate,
   first-class axes. Back-dated corrections, disputes, and
   restatements become routine queries: materially cheaper closes and
   litigation responses.
   *Backing:* `spec/02-working/bitemporal.md` (valid-from/valid-to;
   the pure pre-fold projection; the correction taxonomy).

4. **Right-to-be-forgotten in an append-only world.** `LANDING (#692)`
   Cryptographic shredding erases personal data while every chain
   still verifies (typed erasure tombstones are already live in the
   store). GDPR compliance without giving up tamper-evident history —
   the combination regulated industries currently cannot buy; a
   market-entry key for health and finance.
   *Backing:* `spec/03-approved/std-lib/erasure_compliance.md` (key hierarchy,
   detached payloads, `[erased]` tombstones, legal hold); the
   detached-payload entry form and tombstone reads already shipped.

5. **One security model on one wire.** `SHIPPED`
   Identity and permissions are the same system across queries,
   events, and storage; even connection negotiation rides inside the
   signed transcript, so a downgrade cannot be stripped in transit.
   One security review instead of three; faster passage through
   customer security audits — time-to-revenue on enterprise deals.
   *Backing:* `spec/03-approved/xap/xsp_store_profile.md`; the store-wire
   parity gate (three listeners, identical error identity).

6. **Live and batch are the same question.** `SHIPPED`
   A query can run once, stay continuously maintained, or return
   changes-since — same text, guaranteed-identical answers. Real-time
   dashboards and pipelines without a second streaming stack: an
   entire product's worth of licenses, infrastructure, and specialist
   headcount not spent.
   *Backing:* `spec/std-lib/live.md` (the module verbs + the
   equivalence quartet); the live conformance suite.

7. **Offline and multi-site by design.** `LANDING (#681)`
   Replicas ingest locally with no central sequencer and merge with
   recorded lineage (the merge itself is an auditable entry). Field,
   branch, and edge scenarios work disconnected and reconcile
   honestly — availability revenue in markets where connectivity
   cannot be assumed.
   *Backing:* `spec/03-approved/std-lib/distributed_store.md`
   (replica-local-stream ingestion; merge-as-an-entry; the ONE
   `[conflict]` value).

8. **Cross-system workflows that fail safely.** `LANDING (#682)`
   Instead of fragile distributed transactions, compensating steps are
   first-class, recorded, and replayable. The worst outage class in
   distributed systems — the half-committed transaction — is designed
   out; what remains is visible and recoverable.
   *Backing:* `spec/_archived/cross_stream_coordination.md` (the
   derived rejection of cross-stream atomic commit; the saga/escrow
   vocabulary).

9. **Data that survives schema change.** `LANDING (#693)`
   Old events upgrade through declared converters at one seam; history
   remains replayable across decades of format evolution. The
   recurring "great migration" project — typically a quarter of
   engineering time per major change — becomes a declaration.
   *Backing:* `spec/02-working/schema_event_evolution.md` (upcasters,
   fold-identity snapshots, migration as the representational
   relation).

10. **Messaging without a broker stack.** `SHIPPED`
    Fan-out channels, one receive verb, dead-letter queues, and
    request-reply — on the same store and security model as everything
    else. One less vendor, one less cluster, one less pager rotation:
    consolidation savings with a stronger audit story than the broker
    it replaces.
    *Backing:* `spec/_archived/message_delivery_unification.md` +
    `spec/03-approved/core/delivery.md` (the unified delivery model);
    `spec/xap/fabric.md`.

---

*Maintenance rule: when a `LANDING (#NNN)` item ships, flip its tag in
the same change that closes the tracker item — this document must
never claim more than the gates prove.*
