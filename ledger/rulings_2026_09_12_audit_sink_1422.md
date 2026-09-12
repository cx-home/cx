# RULED: 1422-a — the audit sink is a Ring 2 module `audit` over a reserved `journal` stream: a fixed, attributed, append-only record with a module-owned detail element; `emit` / `query` / `bind`; the boot refusal replaces the first-use one; and the `audit:` effects-trace prefix becomes the UNBOUND fallback only

Integrator, 2026-09-12, under the owner's delegation; pulled into v0.18 by **INT-2** (issue #1422).

## The gap this closes

`security.md` §2 is the capability **category** table. It names no audit channel. §4 says
*"Grants/denials are audit-events (see §5)"* and §5 says *"capability events appear in the
audit/trace"* — and there is no such sink anywhere in the tree. Three shipped specs cite that
absent channel by name:

- `smtp.md` §6.2 point 2 — the loud TLS opt-out "emits a startup audit event"; **RULED: 1085-c**
  put the event on the effects-trace witness channel under an `audit:` prefix *because* the named
  channel did not exist, and filed the sink proper as **#1422**.
- `imap.md` §6.2 point 2 — "it emits a startup audit event (`security.md` §2)", and §3.7's
  autologout leaves "one journal line on the `audit:` witness channel" (**RULED: 1085-c-2**).
- `authz.md` §2 — a guardian grant carries a mandatory `[audit :required]` clause with nothing
  behind it, and `xap.md` §22.4 carries the same clause.

And three more are queued behind it: `sso`'s break-glass ("every use audited and surfaced in the
operator view", 1394-b item 10/11), `session.md` §4.4's attach/detach events, and `mailbox.md`
§11's own row, which says in as many words that what #1422 still owes is *a cross-module query
verb and retention*.

The effects trace is process-global, ordered and observable — and it is **not durable, not
attributed, not queryable and not retained**. Every one of the six sentences above asks for a
record an operator can read next quarter. That is the gap.

## The decision

### 1. Placement, stated before any spec or code (OL-15)

| | |
|---|---|
| Module | **`audit`**, Ring 2 (platform) |
| Namespace | `cx-stdlib/audit` today; **`cx-platform/audit`** after #1427 — the spec is written so the rename is the ONLY change (no sentence names the `cx-stdlib/` prefix except the `[?lib]` examples and §1's own placement note) |
| Spec | `spec/03-approved/std-lib/audit.md` |
| Code | `vcx/platform/stdlib_audit.v` |
| Source | `stdlib/audit.cx` |
| Corpus | `conformance/stdlib/audit.cxd`, `ring=2` |
| Band | **`CXER6200–6299`** — the next free hundred-block above `mailbox`'s `6100–6199` (#1413) and `sso`'s `6000–6099` (#1394-b). A band scan across every `spec/` tree on every local branch on 2026-09-12 returned `6000–6014`, `6099`, `6100–6126`, `6199` and nothing at or above `6200` |

### 2. The record

An audit record is a **structured, attributed, append-only event** — one element with a **fixed
core** and exactly one **module-owned detail element**:

```cx
[audit module=smtp action=:tls-policy actor="service:mta-1" authority="boot"
  subject="tcp://0.0.0.0:25" decision=:announced at="2026-09-12T04:10:00Z"
  [detail [tls-downgrade setting=:none bind="tcp://0.0.0.0:25"]]]
```

The core is **closed**: `module`, `action`, `actor`, `authority`, `subject`, `decision`, `at`.
The brief's five (`module` `actor` `subject` `decision` `at`) are the spine; `action` and
`authority` complete it, and neither is optional — a decision with no act recorded is a row an
operator cannot read, and `journal` refuses an unattributed append at all (`journal.md` §3.2), so
an `authority` is owed on every record whether or not a grant was involved (`"boot"` is the
spelling when the act had no grant basis).

`decision` is a **closed five**: `:permit`, `:deny` (an authority decision), `:applied`,
`:refused` (an effect that happened / was declined on policy), `:announced` (a posture or
configuration fact recorded once at start-up — smtp's and imap's opt-out). An unknown spelling is
refused, never recorded: a decision vocabulary invented per deployment is one a query cannot
name, which is the `E_CAP_UNKNOWN` posture (`security.md` §6 C2) applied to the record.

`[detail …]` is **exactly one child**, an element whose node name is the emitting module's own
vocabulary. `audit` never parses it — the `journal.md` §2.3 discipline: a thin module owns its
envelope, not its cargo.

### 3. The sink is a reserved journal stream, never a new store

`journal` is already the durable, attributed, bounded, hash-chained, queryable append-only log
this tree has. The sink is the reserved per-tenant stream **`cx:audit`** on a journal the
**deployment** names — the `cx:erasure` / `cx:legal-hold` precedent (`journal.md` §2.11, rulings
L187/L188) spent a third time. Retention, bounds, durability, tamper-evidence and erasure are
**the journal's**, unchanged and un-re-specified:

- retention is `journal:retain` behind a **signed** snapshot, so §4.9's cover rule makes
  "we pruned the audit log" structurally impossible without a signed artifact covering it;
- tamper-evidence is the per-stream hash chain (§4.2) plus the recorded `actor`/`authority`
  (§2.6) — `audit:verify` is `journal:verify` on the stream and answers a **finding**, never a
  fault;
- the record is **subject-free by construction**: a `[detail]` carrying journal's reserved
  erasure vocabulary (`subject=` / `nonce=`) is refused, because an audit record that can be
  crypto-shredded is not an audit record.

### 4. The three verbs, and the boot refusal

- **`bind`** — the deployment names the journal the sink writes to, once, at start-up.
- **`emit`** — validates the record, lifts `actor`/`authority` into the journal attribution, and
  appends to `cx:audit`.
- **`query`** — the fold: by actor, by subject, by module, by decision, over a **valid-time**
  window (`at=`) or a **transaction** window (the chain position), across `cx:audit` and any
  module stream the deployment names. Its order is a **total order over `(at, stream, seq)`** and
  is explicitly **not** a linearization — `journal.md` §2.1.1 says there is no global cross-stream
  `seq`, and claiming one would be claiming something the substrate does not give.

**A bound runtime without an audit binding, where a spec requires one, refuses at BOOT — not at
first use.** `audit:require` is called by the requiring module at `serve` / `listen` /
deployment start; unbound, it refuses. A deployment that discovers at 03:00 on the first
break-glass login that nothing was recording is a deployment that has already lost the record.

### 5. The `audit:` effects-trace prefix becomes the UNBOUND fallback only

With no sink bound, `emit` does not fail and does not go silent: it writes the record's canonical
one-line rendering to the effects-trace witness channel under the `audit:` prefix
(**RULED: 1085-c**) and returns a present `[audit-unbound …]` value naming the record and the
channel. So a unit test, a CLI one-shot and an unconfigured process still leave the one
observable record this tree has — and the caller can **see** that it was unbound. That channel is
from this decision forward the **fallback**, never the sink: not durable, not attributed, not
queryable, not retained, and the spec says all four in one sentence.

The consequence for shipped code is deliberate: smtp's and imap's three `effects_trace_note('audit', …)`
call sites become `audit:emit` calls whose **unbound path emits the same line**, so their
conformance pins do not move when the module lands.

### 6. Every "audit" sentence is re-pointed in the integration map

`security.md` §2/§4/§5, `smtp.md` §6.2, `imap.md` §6.2 and §3.7, `authz.md`'s PEP and its
`[audit :required]`, `xap.md` §22.4's approval acts, `session.md` §4.4, `sso`'s break-glass and
operator view, `scim`'s provisioning, `mailbox.md` §2.14 and #1414's delivery — each is one row
in `audit.md` §11 naming **what it emits, its detail element, whether it calls `require` at boot,
and which case grades the seam.** A sentence that says "audit" with no row is, from this decision
forward, a defect in that spec.

The **invariant** the module exists to hold: **no audit sentence in any specification is
unbacked.**

## Two phases

**Phase 1 — the spec, the corpus and this record. Then STOP and report.** The owner reads a new
module's spec before any code, and this spec re-points nine other documents, so the read is not
optional.

**Phase 2 — the code — is a separate brief written after that read**: `stdlib/audit.cx`,
`vcx/platform/stdlib_audit.v`, the `cx:audit` reservation in `journal`, the smtp/imap/session
call sites, the `gates.cxd` flip from `advisory` to `enforced`, the README count and the
`readiness-rubric.md` row.

## What was considered and refused

- **A new store.** Refused. The tree has a durable, attributed, bounded, hash-chained, queryable
  append-only log with retention, snapshots, signing and erasure already specified and shipped.
  A second one would be a second order over the same facts, and two orders over one estate is no
  order (`mailbox.md` §1.2 invariant 4, generalized).
- **A `log`-shaped sink (a formatter over a file or stderr).** Refused. `log` is diagnostics
  (`xap.md` §25.1 reserves the name for exactly that); it is unattributed, unordered across
  processes, and a file an operator can edit. An audit record whose integrity rests on file
  permissions is not evidence.
- **Leaving the `audit:` effects-trace prefix as the channel and adding retention to it.**
  Refused. It is process-global mutable state with no tenant, no attribution, no chain and no
  read surface; adding retention to it would be building the journal a second time, badly.
- **A per-module audit verb (each module folds its own stream and calls that audit).** Refused —
  it is what the tree has today, and it is the failure **RULED: 1413-b** named: *each module
  defers correctly, the sum is unowned.* "Which agent did what last Tuesday, under whose grant"
  must be **one** fold, not eleven.
- **Making `emit` refuse when unbound.** Refused. It would turn every unconfigured unit test and
  every CLI one-shot into a failure, and the pressure that creates is a developer deleting the
  emit call. The boot refusal (§4) puts the failure where a deployment can fix it, once.
- **Projecting `emit` as an agent tool.** Refused, and stated as an invariant: an agent never
  writes its own audit record. The module performing the act writes it.

## Open for the owner on reading

1. **Erasure reach.** An audit record names a *resource* as its subject and carries no subject
   content, so a lawful shred never reaches it — but an `actor` is an identifier, and in a
   `principal:` deployment it can be personal data. This decision declines to declare audit
   records erasable (§3): an erasure request that reaches actor identifiers is answered by the
   deployment's retention window, not by shredding the chain. The alternative — declaring the
   actor a data subject — makes the audit chain shreddable, which defeats the artifact.
2. **The `cx:audit` reservation in `journal`.** Enforcing "a hand-authored append to `cx:audit`
   refuses" the way `cx:erasure` does (`CXER4622`) is a `journal.md` §2.11 amendment and a
   journal code, and journal's band has no clean free slot (`4624–4639` are reserved to the
   erasure surface, `4645–4649` to stream 21). Until that amendment, `audit` **detects** rather
   than refuses: a `cx:audit` entry that is not a well-formed record is reported as a `[foreign]`
   row by `query` and named by `verify`, never dropped and never counted. This is the spec's one
   ⚠ checklist row.

---

# ADDENDUM — RULED: 1422-b — the owner's two answers to the ⚠ rows, recorded before phase 2 touched a spec or a file

Owner, 2026-09-12, on reading `spec/03-approved/std-lib/audit.md`. The spec stands;
its two ⚠ checklist rows (§13 rows 9 and 21, cross-referenced from §2.5 and §3.5,
collected as §12.2 rows 8 and 7) are decided here. Phase 2 implements against this
table and cites `(RULED: 1422-a, 1422-b)`.

| Id | The question | The decision | Why | Normative at |
|---|---|---|---|---|
| **1422-b-1** | Is `cx:audit` reserved in `journal`, the way `cx:erasure` is? | **(a) Yes — amend `journal.md` §2.11 NOW, inside #1422.** A direct `append` to `cx:audit` refuses with a **new journal code**, exactly as a direct append to `cx:erasure` refuses `CXER4622`; `audit:emit` reaches the stream the way `erase-subject` reaches `cx:erasure` — the command's own internal append under the handle's `reserved_append_ok`, never the public verb. The code is allocated from the free slots of journal's own `CXER4600–4649` band, decided by the registry pre-flight (`make cxer-registry-gate`) and registered in `governance.md` §9.6 with the amendment | A hand-authored row on the sink forges the evidence basis, which is the identical failure `CXER4622` exists to refuse — and a sink that only *detects* forgeries has already accepted one. The reservation makes the forgery unrepresentable rather than reportable, from day one, so no deployment ever runs a window in which the sink is forgeable | `journal.md` §2.11, `audit.md` §2.5, §5.2, §8, §12.2 row 8, §13 row 9 |
| **1422-b-2** | Does the `[foreign …]` row survive that? | **Yes, demoted.** The §2.5 / §5.4 / §13 row 9 interim — "detect and report `[foreign]` rows" — is **no longer the primary behavior**. It is the **refusal's fallback**: the honest reading of entries the reservation does not cover — entries that **predate** it on a `cx:audit` stream written before this commit, and entries on a deployment-named alternate reserved stream (`opts.stream`, §5.1), which `journal` does not reserve by name. Every read still surfaces them, still never counts them as records, still names them in `verify` | Reserving the name closes the forward door; it cannot close a door already walked through. A chain written last quarter is immutable, so the read side must stay honest about what is on it — "a gap that is visible in every read is a gap that cannot be traded on", now applied to a bounded, historical set rather than to the live sink | `audit.md` §2.5, §5.3 (`include-foreign`), §5.4 |
| **1422-b-3** | Are audit records erasable? (the erasure residue) | **(a) The residue stands as written.** Audit records are **not** erasable; an erasure request that reaches `actor` identifiers is answered by the deployment's **retention window** on the journal, not by shredding the chain (§3.5). `§13` row 21 stops being a ⚠ blocker and becomes the recorded trade-off it already was | The alternative — declaring the `actor` a data subject — makes the audit chain shreddable, which destroys the artifact §3.2 and §3.3 exist to produce: a chain that can be shredded proves nothing about what was not shredded. A deployment whose regulator requires otherwise sets a shorter retention window, which is a **journal** setting and needs no verb here | `audit.md` §3.5, §12.2 row 7, §13 row 21 |

**What this closes.** `audit.md` §13 carries **no ⚠ row** after this addendum: row 9
becomes 🚧 (the reservation, specified in `journal.md` §2.11 and graded by the
corpus's reservation cases), row 21 becomes ❌ (a deliberate non-feature with its
rationale, the `readiness-rubric.md` convention). The two flags §12.2 raised for the
owner are answered in §12.2 itself, in place, citing this record.

**What this does not do.** It adds no verb, no capability and no member to the
record. The whole change to `audit`'s own surface is that `emit`'s append is the
privileged one and every other append to `cx:audit` is refused below it, by the
module that owns the stream namespace.
