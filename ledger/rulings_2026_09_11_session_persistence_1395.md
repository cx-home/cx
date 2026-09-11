# RULED: 1395-a — the session registry becomes STORE-BACKED through `cfg.store` (url or handle, default `mem://`), carrying the pending-request table of 1394-a; client ids become CSPRNG; `session:reap` sweeps

**Fable, 2026-09-11 03:0xZ, under the owner's delegation of 2026-09-09 05:50 ET**; the owner
may override on #1354. Lane S item S6. Premises re-verified at `19af3b349`: `SessionRegistry`
(`vcx/platform/stdlib_session.v:118-130`) is five in-process maps plus a `counter` for client
ids, in `__global g_session_reg`, reset by `session_reset_state` at every program start;
`session.md` §3.1 has no store/backend/TTL key; §9's row says *"an in-process tenant-rooted map
keyed by session id"*; §4.3 reaping is lazy with "an optional impl background sweep" that does
not exist. `cx-stdlib/store` ships `mem://`, `file://`, `cx-store://` (§3), an alias surface
(`set-alias`/`get-alias`/`delete-alias`/`list-aliases`, LWW single-writer, §6.2), `delete-doc`,
and encryption-at-rest (§9). RULED 1271-b1 already widened `journal:open`'s store argument to
url-OR-handle; HC-1 puts a `[store <handle>]` in the XAP deployment context at every tier.

## The fork — RULED (a)

- **(a) the registry is a `store`-backed document table.** `cfg.store` names it — a store URL
  or a `[store]` handle (the 1271-b1 widening, one meaning: "where sessions live"); **default
  `mem://`**, which IS today's behaviour (per-process, reset per program) and keeps every
  existing fixture green. `file://` and `cx-store://` survive a restart and are shared by
  replicas — a cookie minted by one resolves at the other, which is the #1395 consequence
  closed. Records: `session/<tenant>/<id>` (the `[session]` document: binding, clients,
  established, `exp`, `leeway`, claims, CSRF secret); indexes as aliases
  `subject/<tenant>/<principal>` → id, `name/<tenant>/<principal>/<name>` → id,
  `client/<client-id>` → id, `token/<sha256-hex>` → id. **Tenant stays a structural
  partition**: every key is tenant-prefixed, and on `cx-store://` the XSP-AUTH tenant of the
  store connection scopes what a worker can read at all (§9's sentence stays true as a
  namespace, not a map). The **pending-request table** of RULED 1394-a lives here too:
  `pending/<state>` → the `[auth-request]` document, single-use (`take` deletes), TTL
  `cfg.pending-ttl` (default 10 min) checked against `now` on take. DELETES the sentence *"an
  in-process tenant-rooted map"* from §9's table (it becomes "a `store`-backed table, `mem://`
  by default").
- **(b) event-source sessions through `journal`** (attach/detach/touch events folded on boot).
  `journal` is already the AUDIT target (§4.4) and should stay one: `touch` on every heartbeat
  is churn, not history, and a fold over months of heartbeats to answer `of $req` is the
  wrong shape for a per-request read. Refused.
- **(c) stay in-process and document sticky sessions.** Leaves "a restart logs everyone out"
  as the product, on a lane whose bar is a client's IdP environment. Refused.

## Riders, load-bearing

1. **Client ids become CSPRNG** (same generator as the session id, §2.8), not a per-process
   counter: two replicas cannot share a counter, and a guessable client id is a weakness the
   in-process design merely never exposed. `by-client` is unchanged in meaning.
2. **`session:reap $cfg $now` → int** (impure): deletes every session document whose
   `exp + leeway < now` and every `pending/*` past its TTL, answering the count. §4.3's
   "optional background sweep" becomes a verb a deployment schedules (`sched`), and lazy
   expiry on access stays exactly as specified — the model is still correct with no sweep at
   all; the sweep bounds the store's growth.
3. **Secrets at rest.** The document carries the CSRF synchronizer secret and the bearer
   token's sha256 FINGERPRINT — never a bearer token, never an ID token. `session.md` §4.7
   states it and says a durable store for sessions SHOULD be an encrypted one (`store` §9);
   `mem://` has no at-rest bytes.
4. **Mirrored attach under two writers.** The alias surface is LWW single-writer (§6.2); two
   replicas attaching the same subject at the same instant can both mint. The session
   document write is `put-doc` (content-addressed, no conflict) and the `subject/…` alias is
   the race; RULED: the second writer re-reads the alias after its write and, if it lost,
   adopts the winner's session (mirrored attach's own rule — same subject, same session) and
   deletes its orphan. No new consistency machinery; the race resolves to the §2.7 invariant.
5. **Reads per request.** `of`/`by-id`/`valid` read the document through the store on every
   call; on `cx-store://` that is a network hop per request. Correct first; a read-through
   cache is an optimisation nobody has measured a need for and is NOT ruled here.

## Spec text (delegated G3, flagged; commits carry `RULED: 1395-a`)

`session.md` §3.1 (`store`: url or handle, default `mem://`; `pending-ttl`), §3.2 (`reap`),
§2.8/§2.7 (client id CSPRNG), §4.3 (reap as a verb; what `mem://` does not survive, plainly),
§4.7 (secrets at rest), §9 (the row). `oidc.md` :47's "persist `$req` in the session" → names the
pending table (the 1394-a edit — same commit family).

## Conformance

`session.cxd` (single-program, `mem://` default): everything green as today; `reap` answers
the count of expired sessions and the survivor still resolves; a `pending` put/take round
trip; a second take of the same `state` is absence; a take past `pending-ttl` is absence and
the row is gone. Cross-program (the property that matters, ungradable in one program): a V
umbrella test with a `file://` store in a scratch dir — program 1 attaches and prints the
cookie; program 2 `from-cookie`/`by-id` resolves the SAME `(principal, tenant)`; the same
pair over `mem://` does NOT resolve (pinning what the default does not survive). Tenant
partition: a store handle scoped to tenant A cannot `by-id` a tenant-B session.

Nothing deferred. The S7 deployment (#1394) mounts this; #1292 (sessions on the XAP bridge)
consumes the same store through the host's HC-1 `[store]` handle — that wiring is #1292's.
