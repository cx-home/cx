# RULED: 1271-b1, 1271-b2 — a served-tier journal binding hands a fold-capable handle (Fable + owner, 2026-09-08 16:25 ET)

Issue: cx-home/cx-private#1271 — "xap host: a served-tier (xsp://) journal
binding exposes no journal handle — `$host/journal` is absent at that tier, so
a feature cannot own its fold on a served deployment".

Coupled: #1210 HC-1 (the deployment context this completes), #1293 (the same
seam from the other side — still owed, see the last section).

## What was measured at HEAD before the letters were drafted

- `jrn_open` (`vcx/platform/stdlib_journal.v:1906`) takes `(store-url, tenant)`
  **strings only**: `jrn_arg_str(args[0])` refuses anything that is not a
  string, and the store is opened inside (`store-open` / `store-open-opts`).
- `xap_open_journal_bind`'s served branch (`stdlib_xap.v`) opens the FABRIC and
  returns `has_jrn: false`; the embedded branch opens a journal and returns it.
- `xap_host_context` (`stdlib_xap_host_notd_wasm32_emcc.v:646`) therefore emits
  `[journal …]` only when `rt.has_journal_handle`, and prints a boot notice
  otherwise.
- `store_xsp_journal.v` already serves **eleven** journal verbs — including
  `journal-fold`, `journal-fold-slice`, `journal-since`, `journal-slice` —
  behind `cx-store+xsp://`, and a fold is compute-class and credit-governed
  there.
- HC-1 puts `[store <handle>]` in the deployment context at **every** tier,
  `OPTS.store` byte-for-byte — the one row of the tier table the issue's own
  diagnosis marks "identical".

## The ruling

**`1271-b1` = letter 1(b).** `[$journal:open]`'s first argument widens to
**url-OR-handle** — one function, one meaning ("the store this journal lives
in"), named by a url or by a handle to the same thing. No dual-accept: it is a
widening, not a second surface. The handle form skips the internal
`store-open`; every existing url caller is untouched. The served-tier bind then
opens its journal over the store handle `$host` already carries, so
`[journal <handle>]` is present at **every** tier and a feature's fold is
portable across deployments — the property HC-1 was for.

Refused, with the ruling's own reasons:

- **(a) a second url on the binding** (`store:` beside the fabric url) — two
  urls that must stay in sync, two attaches, and the tenant restated at the
  second one, which is precisely consequence 2 of the issue's own filing
  ("tenant binding leaves the host's hands again"). It also asks the deployment
  author to know that the journal and the fabric live on different daemons — a
  split the host contract exists to hide.
- **(c) the fabric daemon grows the journal profile** — `store_xsp_journal.v`
  already serves those eleven verbs on the STORE daemon, so (c) means
  re-implementing or proxying a server that exists, to avoid naming a store the
  deployment has already named.

**`1271-b2` = letter 2(a).** The served-tier handle folds by **PUSHDOWN**
through `store_xsp_journal.v`'s existing verbs — never a client-side replay.
Anything else ships every event to the client to fold locally, which at the
served tier is the read-model the boundary worker already maintains, i.e. the
fallback this issue exists to remove: it would make `$host/journal` present and
useless.

## What this DELETES

Named by the ruling, and deleted in the implementing landing rather than left
as stale text:

1. the tier split in the host contract — the issue's whole point;
2. the else-branch boot notice in `xap_host_context`;
3. the tier-split paragraph in `xap_feature_distribution_market.md` (§1.2's
   `[journal …]` row, the "SERVED bindings expose no handle" half);
4. the `has_journal_handle` comment block in `stdlib_xap.v`, whose last two
   sentences say the served tier has no handle;
5. the need for any new binding key or second url — nothing is added to the
   deployment document by this ruling.

## IMPLEMENTATION STATUS: BLOCKED, and nothing is landed

Two findings from the implementation attempt, both MEASURED in the source, and
the second one blocks the ruled outcome itself. The code was written, read
against these facts, and **reverted** — nothing of #1271 is in the tree beyond
this record. The letters are on the issue.

**Finding 2 is the blocking one: nothing establishes that the deployment's
working store is the store holding the served act chain — and if they differ,
the ruled handle folds the WRONG chain.**

`fabric_service.v:441-455` parses the daemon's own mounts as
`[fabric name= store= tenant=]`, and `:684-688` opens the chain with
`journal-open <m.store_url> <m.tenant>` — a store url in the **DAEMON's**
config, typically a `file://` or `mem://` path local to that process (every
fixture in the tree spells it that way). A client holds only
`xsp://host:port`; the daemon's `store=` is not addressable from it and is
never sent.

`[$xap:host]`'s `store:` opt, meanwhile, is the deployment's **working**
store — whatever the deployment author passed. HC-1's tier table marks
`[store <handle>]` "identical across tiers", and that is true: it is the same
OPTS.store at every tier. But "the same opts value" is not "the store the
served chain lives in", and the ruling's reasoning — "the store is therefore
already open, already tenant-routed by the deployment" — silently reads the
first as the second.

So attaching a journal to the working store and handing it as
`$host/journal` yields, in the general case, a journal over the **working
store's** chain for that tenant — not the chain the runtime commits acts to.
A feature would fold it, get a coherent-looking answer, and be wrong. That is
strictly worse than the absence #1271 was filed about: absence is a value a
feature tests for, and a wrong chain is not.

A deployment *can* arrange agreement (point both at the same
`cx-store+xsp://`), but nothing states that requirement, nothing checks it,
and no fixture pins it. Which store holds the served chain, and how the host
comes to know it, is the question `1271-b1` has to answer before any handle is
handed out. Letters are drafted on the issue.

## Finding 1 — the mechanism half is superseded by a fact

**`[$journal:attach]` already exists and already IS "a journal over an
already-open `[store]` handle".** `spec/03-approved/std-lib/journal.md:583`
declares it beside `open`:

```
[?def open   scope=public impure [returns element] ($store-url::string $tenant::string $opts::map {}) ...]
[?def attach scope=public impure [returns element] ($store::element   $tenant::string $opts::map {}) ...]
```

and the paragraph under it says `attach` "binds a journal to an **already-open
`[store]` handle** (so a process can share one backend across tenants…)". It is
implemented at `vcx/platform/stdlib_journal.v:2093` (`jrn_attach`), registered
as `journal-attach` (`:1709`), takes `(store handle, tenant, opts)`, refuses a
non-handle on the argument channel, and `close`'s own contract already
distinguishes the two ("only the one `open` itself opened — an `attach`ed store
is the caller's to close").

The letters that produced `1271-b1` did not have this fact in their option set:
the drafted set was (a) a second url on the binding, (b) widen `open` to
url-or-handle, (c) grow the journal profile on the fabric daemon. The ruling's
own "checked at HEAD" line is accurate as far as it goes — `jrn_open` does take
strings only — but the conclusion drawn from it, that a handle form has to be
*created*, does not follow: it exists under another name.

**Widening `open` would therefore be a DUAL-ACCEPT** — two spellings for one
meaning — and no-dual-accept is a standing absolute in this repo, not a
preference. So:

- were the outcome implementable, the mechanism would be the existing
  `journal-attach` and `jrn_open`'s signature would not move at all;
- it is not implementable yet, for finding 2, so neither verb is called and
  nothing is landed.

`1271-b2` is unaffected by either finding and remains right: `store_xsp_journal.v`
serves the eleven verbs and a fold is compute-class there, so whatever store
turns out to hold the served chain, the fold is a PUSHDOWN and never a
client-side replay.

## Two things the ruling did not have to state, decided here as consequences

Both are moot under the substitution above and are recorded so the reasoning
is not re-derived if the widening is ever ratified after all: the at-rest
posture keys (#785) and `read-only` ride through to the *store open*, which for
a handle has already happened, so a widened `open` would have had to refuse the
at-rest keys (silently ignoring a sealing key is the one failure mode a
sealed-at-rest chain cannot afford) while letting `read-only` keep governing
the JOURNAL's own field. `attach` already faces the same question and answers
it the same way, which is one more reason the widening buys nothing.

## Fixtures, before the fix

Re-scoped to what is actually implemented:

1. `$host/journal` is **PRESENT** on a served-tier deployment — the issue's own
   symptom, inverted — and a feature's fold over it answers. This is the
   fixture the issue is for.
2. `[$journal:attach <store handle> tenant]` over a `cx-store+xsp://` store
   yields a journal whose `fold` answers, with the fold computed at the daemon
   (`1271-b2`'s pushdown, not a client replay).
3. the embedded tier is unchanged — `$host/journal` still hands the runtime's
   own handle, and no second journal is opened for it (#628/#993: two writers
   on one local root corrupt it).
4. a served binding whose store cannot answer for the chain is announced
   loudly and leaves the child absent — a mis-wiring is not a tier.

The two fixtures the widening would have needed (`open` over a handle; the url
form untouched) are **not** written, because the widening is not implemented.

## Still owed, and NOT closed by this record

**#1293** is the same seam from the other side: `[$journal:open]` over
`cx-store+xsp://` reports *"journal store rejected the open-time algo stamp"*
when no store daemon is listening, with the connection refusal as the **third**
nested cause. Under `1271-b1` the served-tier journal stops constructing that
url at all — it passes the handle — so this ruling removes one PRODUCER of the
misreport. The misreported cause itself is independent of #1271 and remains
open on #1293.

---

# SUPERSEDED IN MECHANISM, ANSWERED IN OUTCOME — RULED: 1271-c1, 1271-c2 (owner + Fable, 2026-09-08 18:00 ET)

The record above ends BLOCKED on two findings. Both are now answered, and the
answers supersede this record's mechanism while keeping its outcome.

## RULED: 1271-c1 — `attach`, not a widened `open`

Finding 1 of this record was right and is adopted: `[$journal:attach]` already
IS "a journal over an already-open `[store]` handle" (`journal.md` §3.1), so the
proposed widening of `jrn_open` was a **dual-accept of `attach`**. `jrn_open`'s
signature does not move. The served-tier bind calls the existing verb over the
deployment's own `[store]` handle — the one `$host` already carries, taken from
the deployment author's `store:` opt, byte-for-byte, nothing re-opened.

That this works over the wire is not new ground: `journal.md` §6.1 is already
normative that a journal attached to a `cx-store(+xsp)://` handle runs every §3
verb through the store's remote object model, with the per-stream head riding
the daemon's authoritative alias table. **1271-b2 stands** — folds push DOWN
through `store_xsp_journal.v`'s verbs and are never a client-side replay.

## RULED: 1271-c2 — the invariant is DECLARED and CHECKED, not assumed

Finding 2 was the blocker: nothing established that the deployment's working
store is the store holding its served act chain. The fabric daemon opens the
chain at its **own** configured `store=` (`fabric_service.v`), a url that never
travels on the wire, so an attach against the wrong store **still succeeds** and
answers a coherent-looking fold over a different chain — which this record
correctly called strictly worse than the absence it would replace, because
absence is a value a feature can test for.

The answer is not to infer the agreement but to **require** it and **check** it:

* **Declared** — one normative sentence in distribution §1.2: a served
  deployment's working store IS the store its act chain lives in, and that is
  what makes `$host/journal` fold-capable at that tier.
* **Checked** — at boot the host attaches, reads the head the store answers for
  the deployment's tenant and stream, compares it with the head the bound fabric
  reports for the same stream, and **REFUSES THE BOOT on disagreement, naming
  both heads**.

Why this and not the alternatives: the record is the state, so one store per
tenant deployment is one durability domain — backup, replication, retention.
Splitting the chain from the working data would create cross-store consistency
questions permanently; exposing the daemon's storage layout leaks it to every
client; and putting fold compute on the fabric daemon is a layering error.

## Three details the implementation had to get right

1. **The comparison is seq-only, and the hash rides the message.** The fabric
   reports a bare `head=N` integer (`[fabric-sub … head=N]`); only the journal
   side has a content hash. So equality is over seqs, and the refusal names the
   store's `seq` **and** `hash` beside the fabric's `seq` — "naming both heads"
   without inventing a hash the fabric never sent.
2. **`head == 0` is not a claim.** An empty stream and a daemon predating the
   `head=` attribute are indistinguishable at zero (`xap_replay_journal` says so
   in its own comment). The check never refuses on it.
3. **The check is scoped to `journal_remote`.** An embedded deployment may
   legitimately run a `mem://` working store against a `file://` journal binding
   — `test_xap_host_document_runtime_bindings` does exactly that and is green —
   because the embedded tier hands the runtime's own opened handle and the opt
   store never participates. Applying the served invariant there would red a
   passing test for the wrong reason.

## The three deletions stand

The tier-split paragraph in §1.2, the boot-notice `else` arm in
`xap_host_context`, and the `has_journal_handle` tier sentences are removed. A
fourth sentence saying the same retired thing — on `XapJournalBind.jrn` — was
found beside them and removed too; leaving it would be exactly the stale text
the other three deletions exist to clear.

## Cross-branch note for the landing

Distribution §1.2's body is fingerprinted by `check-contract-revision`
(#1272, unmerged at the time of writing). This change edits that body, so the
landing must run `make contract-revision-repin` and keep `contract-revision: 2`:
a module built against revision 2 still works, because this sentence constrains
the DEPLOYMENT's store, not any entry point's shape. It is the **editorial**
acknowledgment, never a bump — a bump is a statement that packages in the field
are refused, and nothing here refuses one.
