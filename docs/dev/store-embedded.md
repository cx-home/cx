# CX Store, embedded — one API over every substrate

`cx-stdlib/store` is a **content-addressed object store** behind one document
API: doc IDs are the SHA-256 of a document's strict canonical bytes, so
identity is invariant across substrates, encodings, bindings, and wire — which
is what makes migration and replication lossless. Governing spec: the store
spec (`spec/03-approved/std-lib/store.md`).

## The axes (pick at open time, via URI)

```
[document+]<substrate>://<location>[?encoding=…&read-only=…&schema=…]
```

- **model** — `subtree` (default; a Merkle object graph: cross-document
  dedup, structural sharing, O(changed) diff) or `document+` (one object per
  doc; required prefix for the columnar encodings).
- **substrate** — `mem` · `file` · `sqlite` · `s3` · `http(s)` · `ftp` ·
  `sftp` · `ftps`; plus the service tier `cx-store://` (see
  [store: service](store-service.md)).
- Specify only what departs from a default, only at create; a `file://`
  store is self-describing on reopen.

Not yet applied in the shipped build (the store spec's transition note):
non-`none` `?compression=` values (rejected fail-closed, never
accept-and-ignore) and the `?cache=` stacked caching layer. The columnar
encodings (`document+…?encoding=parquet|arrow-ipc`) require the optional
Arrow build.

## Basics (verified)

```cx
[?lib 'cx-stdlib/store' :as store]
[?let [= $s [$store:open "mem://"]]
 [= $h [$store:put-doc $s [order [id 1] [amt 100]]]]      # → 64-hex store-key
 [= $doc [$store:get-doc $s $h]]                          # re-validates integrity
 [= $a [$store:set-alias $s "latest" $h]]                # the one mutable surface
 [= $back [$store:get-alias $s "latest"]]               # absence = (), never null
 [= $q [$count [$store:query $s "//amt"]]]             # CXPath across the corpus
 [= $h2 [$store:modify-doc $s $h [set-attr name=state value="paid"]]]
 ([= $back $h], $q, [= $h $h2])]                     # → (true, 1, false)
```

- `put-doc` twice writes once (free dedup); `get-doc` re-hashes after decode
  (`CXER1120` on mismatch, `CXER1121` on absence).
- `modify-doc` applies any `[?modify]` action — including `[using FN]`,
  applied client-side — and stores the result as a **new** doc; originals
  are immutable. "Latest of X" lives in the alias/branch layer, never in the
  content store.
- `put-blob`/`get-blob` store OPAQUE documents — CX code, images, plain
  text — under the hash of their **raw bytes**, byte-exact on the way back
  (F1' identity-rule split; code never passes through data canonicalization).
  The "same function?" relation is the pure `[$cx:computation-id]` claim
  (`computes-as:<algo>:<hex>`), an index — never a storage key.

## Durable substrates

Same program, different URI (verified — reopen returns the same doc):

```cx
[?let [= $s [$store:open "file:///var/data/notes-store"]]
 [$store:put-doc $s [note [text "durable"]]]]
```

```sh
cx --allow-read --allow-write program.cx
```

Substrates are capability-gated deny-by-default (the capabilities section of
the store spec): `file://` needs `read`/`write`, remote backends need `net`;
`mem://` is capability-free. An ungranted open fails with `CXER0271` naming
the exact flag (verified). Open read-only when read is all you need:
`[$store:open-opts URL [map read-only="true"]]` — writes then raise
`CXER1110`, and only `read` is required.

A Store handle is **single-owner**: sharing one across `[par]` workers raises
`CXER1140` — open a handle per worker.

## Object graph vs document model

The default subtree model decomposes every doc into shared content-addressed
objects: identical subtrees store once across documents; a one-field edit
re-stores only the path to the root; `diff` hash-skips identical subtrees —
O(changed), not O(size). Verified:

```cx
[?let [= $s [$store:open "mem://"]]
 [= $a [$store:put-doc $s [order [id 1] [amt 100]]]]
 [= $b [$store:put-doc $s [order [id 1] [amt 200]]]]
 [$store:diff $s $a $b]]
# → [diff [change path='/order/amt/[0]' kind=modified]]
```

Two subtree stores share one object space (identical object hashes on every
substrate), so `clone`/`push`/`pull` transfer only missing objects — see
[store: management](store-management.md). The `document+` model and the
columnar encodings expose doc-identity only; crossing the model boundary
degrades to the doc-level `migrate`.

## Streaming and scale

- `put-doc-stream` stores from a byte source; `iter-docs` yields lazily
  (bounded memory over any corpus size).
- `query` is O(corpus) embedded — fine for working sets; push down to the
  service tier or use `cx-stdlib/ft`/an indexed backend for hot paths (the
  query semantics section of the store spec).
- As of v0.13.0 the `file://` index replays and persists **streamed** — no
  whole-file buffers at open or checkpoint.

## Error model (the ones you'll meet first)

`CXER1100` unknown/unbuilt backend · `CXER1101` unreachable · `CXER1110`
read-only · `CXER1120` integrity mismatch · `CXER1121` not found · `CXER1130`
closed handle · `CXER1140` handle race. Full table: the store spec's
error-codes section.
