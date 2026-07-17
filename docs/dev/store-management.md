# CX Store, management — introspection, recovery, migration

The git-style porcelain over the store's object plumbing: status, log, gc,
diff, branch, and the replication verbs that carry a store across substrates
and machines. Governing spec: the store spec — the git-porcelain and
identity/compatibility sections.

## Introspect and reclaim (verified)

```cx
[?lib 'cx-stdlib/store' :as store]
[?let [= $s [$store:open "mem://"]]
 [= $h1 [$store:put-doc $s [doc [v 1]]]]
 [= $h2 [$store:put-doc $s [doc [v 2]]]]
 [= $del [$store:delete-doc $s $h1]]
 [= $st [$store:status $s]]        # heads + object economy + dedup + unflushed
 [= $gcr [$store:gc $s]]          # reclaim unreachable + compact durable storage
 [= $br [$store:branch $s "main" $h2]]
 ($st@docs, $gcr@reclaimed, [$count [$store:log $s]])]
# → (1, 4, 1)
```

- `status` — docs (heads), distinct objects, dedup ratio, unflushed refs.
- `log` — the linear ref-log: each held doc-ref is one epoch, insertion-
  ordered; old roots persist as objects, so this is history without a commit
  DAG.
- `prune` reclaims objects no live doc-ref reaches; `gc` = prune + durable
  compaction. A shared subtree survives another doc's delete — an object
  stays live while ANY ref reaches it.
- `branch` points a mutable named ref at a doc, refusing a non-fast-forward
  move (`CXER1114`, CAS-safe); `branch-force` is the explicit `--force`.
- `merge`/`rebase` deliberately do not exist — the model keeps roots +
  epoch-ordered refs, not a parent-linked commit graph; `diff` founds them
  if one is ever added.

## Diff — O(changed), not O(size)

```cx
[$store:diff $s $a $b]
# → [diff [change path='/order/amt/[0]' kind=modified]]
```

Identical subtrees share a hash and are skipped; output is a CX doc,
expressible as a `[?modify]` patch. This is the structural-diff showcase of
the subtree model.

## Recovery & migration — the replication verbs

All verified; every verb works embedded↔embedded and embedded↔daemon:

```cx
[?let [= $local [$store:open "mem://"]]                 # any pair of stores
 [= $h [$store:put-doc $local [doc [item "hello"]]]]
 [= $remote [$store:open "mem://"]]
 [= $r [$store:push $local $remote]]            # have → put-missing → set-ref
 [$store:get-doc $remote $h]]                     # → [doc [item 'hello']]
```

| Verb | Use |
|---|---|
| `migrate from to` | copy every doc + alias, lossless across **any** axes (substrate/model/encoding); every content-hash ID preserved; a source reconstruct failure is a hard error, never a silent skip |
| `clone src dst` | object-identity copy into an **empty** destination (`CXER1113` otherwise); transfers only missing objects |
| `push` / `pull` / `fetch` | git-shaped incremental transfer; content-addressed, idempotent, conflict-free (no CAS needed on doc-keys) |

Recovery playbook:

- **Backup** = `clone` (or `push`) to a second substrate — e.g. nightly
  `file://` → `s3://`. Content addressing makes it incremental and
  verifiable by construction.
- **Restore** = `clone` back into a fresh store; every hash re-verifies on
  read.
- **Substrate move** (file → sqlite, dev mem → prod s3, embedded → daemon) =
  `migrate`; doc identity is universal, so nothing referencing hashes
  changes.
- Crash-safety inside one store is the engine's append-only ref-log recovery
  + per-op atomic-rename flush; a failed substrate persist raises
  `CXER1116` rather than acknowledging a phantom write, and the next
  successful persist self-heals (the store spec's error-codes section).

Object-identity transfer is `subtree ↔ subtree` only; across the model
boundary the verbs degrade to the doc-level `migrate`.

## Admin plane on a service handle

On a `cx-store://` handle, `status` and `gc` are the daemon's admin-plane ops
(RBAC `admin`, tenant-scoped, same names as the CX surface); `mounts`
enumerates the daemon's stores tenant-filtered; `config-reload` triggers the
validate-then-swap reload. All are daemon-level: on a local handle `mounts`/
`config-reload` raise `CXER1709` — a local handle IS its only store. Wire
details: the CSRP spec's admin-ops rows.

## The admin console

Fleet-facing management UI lives in its **own repo** (`xap-store-console`) —
itself a XAP built from feature packages, connecting over CSRP with
role-scoped credentials; it is never embedded in the daemon. Everything it
consumes is a public RBAC-gated CSRP op, so the console doubles as proof the
management API is complete. Free tier: connect/health/metrics/status/browse/
reload/maintain (gc). Contract: the store management console spec
(`spec/03-approved/misc/store_management_console.md`). Bootstrap credentials
with `cx store-token` (see [store: service](store-service.md)); the console's
own docs cover the rest — not duplicated here.
