# `cx-stdlib/store` — content-addressed object store

```cx
[module-meta name=store tier=B status=current
  [standard ref='SHA-256' title='Content hash']
  [standard ref='RFC 959' title='FTP']
  [standard ref='RFC 4217' title='FTPS']]
```

**Status:** Current

Normative reference for the `cx-stdlib/store` sub-package.

---

## §1. Scope

`cx-stdlib/store` provides a **content-addressed object store** behind one
document API, realized over a family of **orthogonal axes** (§2) selected at
`open` time by a **canonical URI** (§3). Doc IDs are SHA-256 hashes of a
document's **strict canonical bytes** per [`spec/core/canonical.md §1.2`](../core/canonical.md)
and [`spec/core/canonical.md §4`](../core/canonical.md); Layer-1 `hash(node)`
([`spec/misc/bindings.md`](../misc/bindings.md)) wraps that hash. Doc identity is
**invariant** across every axis (§4), which is what makes migration and
cross-substrate transfer lossless.

The default storage model is a **content-addressed Merkle object graph** (§7):
documents are decomposed into shared subtree objects, so identical structure
deduplicates across documents and a one-field edit re-stores only the path from
the changed node to the root. A degenerate **document** model (one object per
doc) and a **columnar** at-rest encoding (§8) are peers selected on the same URI.

## §2. Faceted axes (the model is orthogonal to the substrate)

A store is described by **five orthogonal axes**. Earlier drafts collapsed these
into one flat backend list; they are independent and compose freely.

| Axis | Values | Meaning |
|---|---|---|
| **model** | `subtree` (default) · `document` | `subtree` = content-addressed Merkle object graph (§7); `document` = degenerate one-object-per-doc. Free on every substrate. |
| **substrate** | `mem` · `file` · `sqlite` · `s3` · `http(s)` · `ftp` · `sftp` · `ftps` | Where bytes live. Each carries a read/write **capability** orthogonal to all else: plain `http(s)`-GET is a read-only byte source; `file`/`sqlite`/`mem`/`s3`/`ftp`/`sftp` (+ HTTP-WebDAV) are read-write. |
| **deployment** | `embedded` · `service` | `embedded` names the substrate in the URI; `service` hides it inside a daemon. (`cluster` is a planned separate spec.) |
| **wire** (service only) | `csrp` (default, HTTP/1.1) · `grpc` | The full read-write API over the network, selected by the scheme token: `cx-store(+http\|+https)://` is CSRP, `cx-store+grpc(s)://` is gRPC ([`cxstore-grpc.md §6`](../misc/cxstore-grpc.md)). A bare `https://` is only a passive byte source; the active service API is `cx-store://` — the two HTTP roles are distinct. |
| **encoding** (derived from model×substrate; rarely set) | `pack` · `object-per-key` · `object-rows` · `flat` · `in-mem` · `parquet` · `arrow-ipc` | At-rest framing. Migration-transparent: the same objects, re-packed. `parquet`/`arrow-ipc` are the columnar encodings (§8). |

**Compatibility classes** (read off the model token — this is why model leads the
URI): see §4.

## §3. The canonical URI

```
[document+]<substrate>://<location>[?encoding=…&compression=…&read-only=…&cache=…&schema=…]
```

- **`subtree` is elided** (a bare URI is subtree); the **`document+` prefix is
  required** to select the document model. This is default-elision (like `https`
  defaulting to `:443`), not an alias; `subtree+` is never written.
- **One grammar everywhere.** `cx-store://host/name` is a *named reference* to a
  store defined by this same grammar on the server — the daemon's own substrate
  is its private config (it may re-tier `s3`→cluster with zero client-URI change).
  Embedded: you name the substrate. Service: you name a remote store.
- **Self-describing reopen** (friction reducer): a store records its model +
  encoding in its own header/magic, so on reopen those are **inferred**. State
  `document+` / `?encoding=` only at create or to *assert*; a stated value that
  contradicts the on-disk store is a hard error.
- **Named remotes** (git-style): `remote add origin <uri>` → `push`/`pull`/`clone
  origin`, so the canonical URI is typed once.
- **`?cache=`** composes a stacked caching layer (e.g.
  `https://h/p?cache=file:///var/cache/cx`): immutable objects (ETag = hash,
  `Cache-Control: immutable`) cache forever; only refs revalidate.

**Principle: specify only what departs from a default, and only at create time.**
The common case is `mem://` or `clone origin`; the fully-pinned
`document+sqlite://…?encoding=…&wire=…` form is only for asserting every axis.

> **Transition note (shipped-build status).** The canonical
> `[document+]<substrate>://` grammar is live: `mem://`, `file://`,
> `sqlite://`, `s3://`, `http(s)://`, `ftp://`, `sftp://`, and the service
> token `cx-store://` all dispatch. The pre-canonical tokens `cxpack://` and
> `cxobj://` are **retired** and raise `CXER1100` — their stores are exactly
> `file://…?encoding=pack` (the subtree default) and
> `file://…?encoding=object-per-key`. Self-describing reopen (§3) is live for
> `file://`: the on-disk marker determines model + framing on reopen, and a
> stated value that contradicts it is a hard error. Not yet applied:
> `?compression=` non-`none` values and `?cache=` (see §6.1/§10.2 notes).

## §4. Identity & compatibility classes

- **doc-identity = UNIVERSAL.** The store-key is the SHA-256 of a document's
  strict-canonical bytes — substrate/model/encoding/tier-invariant. A doc has the
  *same* store-key everywhere. `migrate` preserves keys across any pair of stores
  (re-decompose / re-encode on import). This is the only identity the `document`
  and `columnar` models expose.
- **object-identity = `subtree` ↔ `subtree` only.** Two subtree stores share one
  object space: identical object hashes across every substrate/encoding/tier, so
  transfer copies only missing objects (`clone`/`push`/`pull`, §6.3). Embedded and
  server subtree stores interoperate at the object level.
- **Tier-2 code identity** ([`code.md`](../core/code.md), #79): `put-def` /
  `get-def` content-address CX *code* by its Tier-2 (alpha-equivalent) identity, so
  `[?def f ($x) $x]` and `[?def f ($y) $y]` share one key.
- Substrate and encoding are migration-**transparent** (same objects/blobs,
  re-packed). Crossing the model boundary degrades to the doc-level `migrate`
  fallback.

## §5. Conceptual model

A **Store** is an opaque element value returned by `open`, wrapping a backend, a
capability set (read / write / list), and per-store config (model, encoding,
compression, schema). Multiple Stores may coexist. A Store handle is
**single-owner**; sharing one handle across `[par]` workers raises
`CXER1140 E_STORE_HANDLE_RACE` (shard — open a handle per worker). The service
tier serializes its many workers on one handle internally.

CXStore is organised in two **deployment** tiers — **Embedded** (in client
process) and **Service** (server process). Both expose the same API and URI grammar;
the Service tier additionally offers server-side query pushdown and the object wire.

### §5.1. Backend capabilities

| Capability | Semantics |
|---|---|
| `read` | `get-doc`, `list-docs`, `query`, `iter-docs`, `exists` |
| `write` | `put-doc`, `modify-doc`, `delete-doc`, alias + ref mutation |
| `list` | `list-docs` / `iter-docs` enumerate efficiently |

These backend **traits** (what a backend can structurally do) are distinct from the
host **capabilities** (`read`/`write`/`net`) that gate the OS effect at the effect
point (§15).

## §6. Public function surface

The module's `[?def]` bodies forward to native primitives; signatures below match
`stdlib/store.cx` (each has a co-located `[fn-doc]` + `conformance/stdlib/store.cxd`
backing).

### §6.1. Open / store / retrieve

```
[?def open      scope=public impure [returns element] ($url::string) ...]
[?def open-opts scope=public impure [returns element] ($url::string $opts::map) ...]
```
`CXER1100 E_STORE_UNRESOLVED_BACKEND` on an unknown/unbuilt backend;
`CXER1101 E_STORE_BACKEND_UNREACHABLE` on connection failure.

| `opts` key | Default | Semantics |
|---|---|---|
| `compression` | `"zst"` (`"none"` for `mem://`) | `"gz"`, `"zst"`, `"none"`. A build whose compression path is absent MUST reject a non-`"none"` request fail-closed (`CXER1100`-class) — never accept-and-ignore. (Shipped build: path absent, default `"none"` — §3 transition note.) |
| `encoding` | model/substrate default | incl. `"parquet"` / `"arrow-ipc"` (§8) |
| `model` | `"subtree"` | `"document"` selects the degenerate model |
| `schema` | (none → inference) | columnar declared schema (§8) |
| `encrypt-key-id` | (none) | encryption-at-rest tenant key-id (§9) |
| `auth` | per-backend | userinfo / `key-path` / `known-hosts` / password / bearer / SDK chain |
| `read-only` | `false` | force read-only |
| `cache` | (none) | stacked caching layer (§3) |

```
[?def put-doc        scope=public impure [returns string] ($store::element $doc::any) ...]
[?def put-doc-text   scope=public impure [returns string] ($store::element $text::string) ...]
[?def put-doc-stream scope=public impure [returns string] ($store::element $source::element) ...]
[?def get-doc        scope=public impure [returns any]    ($store::element $hash::string) ...]
[?def get-doc-text   scope=public impure [returns [or string [sequence string]]] ($store::element $hash::string) ...]
[?def put-def        scope=public impure [returns string] ($store::element $source::string) ...]
[?def get-def        scope=public impure [returns [or string [sequence string]]] ($store::element $hash::string) ...]
```
`put-*` return the SHA-256 store-key (64 hex); dedup is automatic. `put-doc-stream`
takes an already-canonical byte `source` and stores it through the same
hasher/writer, yielding the **identical content address** `put-doc` would (the
degenerate-but-correct as-built form). Chunked streaming through the
hasher/compressor for a large *external* byte source (bounded memory) is a tracked
refinement; the verb's contract — a canonical source in, the content-address out —
is stable regardless. `get-doc` re-validates the hash after
decode → `CXER1120 E_STORE_INTEGRITY_MISMATCH`; absence → `CXER1121 E_STORE_NOT_FOUND`.
`put-def`/`get-def` address CX code by Tier-2 identity (§4). Writes to a read-only
Store raise `CXER1110 E_STORE_READ_ONLY`.

### §6.2. List / query / modify / delete / aliases / migrate / introspect

```
[?def list-docs   scope=public impure [returns [sequence string]]  ($store::element) ...]
[?def iter-docs   scope=public impure [returns [sequence element]] ($store::element) ...]
[?def query       scope=public impure [returns [sequence element]] ($store::element $cxpath::path) ...]
[?def modify-doc  scope=public impure [returns string]             ($store::element $hash::string $action::element) ...]
[?def delete-doc  scope=public impure [returns bool]               ($store::element $hash::string) ...]
[?def exists      scope=public impure [returns bool]               ($store::element $hash::string) ...]
[?def set-alias   scope=public impure [returns null]               ($store::element $name::string $hash::string) ...]
[?def get-alias   scope=public impure [returns [or string [sequence string]]] ($store::element $name::string) ...]
[?def list-aliases scope=public impure [returns [sequence element]] ($store::element) ...]
[?def delete-alias scope=public impure [returns bool]              ($store::element $name::string) ...]
[?def migrate     scope=public impure [returns element]            ($from::element $to::element) ...]
[?def capabilities scope=public impure [returns map]               ($store::element) ...]
[?def close        scope=public impure [returns null]              ($store::element) ...]
[?def csrp-handle  scope=public impure [returns any]               ($exchange::element $store::element) ...]
```
`query` evaluates the CXPath against every doc (§12), returning
`[result hash=$h matches [sequence …]]`; `modify-doc` applies a Layer-1 action and
stores the result as a **new** doc (originals are immutable). The action
vocabulary is the full `[?modify]` set of [`code.md`](../core/code.md),
including `[using FN]` (computed replacement, kind-shift allowed); the FN is
always applied **client-side** — caller code never crosses the wire, so on a
remote-backed store `[using FN]` degrades to get → transform → put and yields
the identical content address a local store would. Aliases are the one
mutable surface (last-write-wins, single-writer); `get-alias` returns the
**absence** channel (empty sequence `()`), never `null` (the no-conflation guard,
[`code.md §9.1.2.1`](../core/code.md)). On a `cx-store://` handle the alias
family resolves against the daemon's **authoritative** table over the wire
(the remote-protocol spec's alias-remoting ops): `get-alias`/`list-aliases`
carry explicit per-name presence — a miss is a *server-asserted* absence
`()`, never a client-side guess — and `set-alias` applies daemon-side with
the same target-must-exist `CXER1121` refusal as a local write.
`delete-alias` is not carried on the wire and refuses (`CXER1709`); on
byte-source remotes (`http(s)`/`ftp(s)`/`sftp`) every alias op refuses with
`CXER1709` — there is no service to ask, and a fabricated local answer
would lie. `migrate` copies every doc + alias
preserving content-hash IDs (lossless across any axes); a source reconstruct
failure is a hard `CXER1120`, never a silent skip. `capabilities` returns
`[read write list backend url compression encoding …]`; closed-Store ops raise
`CXER1130 E_STORE_CLOSED`.

### §6.3. Git porcelain over object plumbing (`subtree`)

Over the object plumbing `have`/`get`/`put`/`refs`, the sound porcelain set:

```
[?def clone        scope=public impure [returns element] ($src::element $dst::element) ...]
[?def push         scope=public impure [returns element] ($local::element $remote::element) ...]
[?def pull         scope=public impure [returns element] ($local::element $remote::element) ...]
[?def fetch        scope=public impure [returns element] ($local::element $remote::element) ...]
[?def status       scope=public impure [returns element] ($store::element) ...]
[?def mounts       scope=public impure [returns element] ($store::element) ...]
[?def config-reload scope=public impure [returns element] ($store::element) ...]
[?def verify       scope=public impure [returns element] ($store::element) ...]
[?def log          scope=public impure [returns [sequence element]] ($store::element) ...]
[?def gc           scope=public impure [returns element] ($store::element) ...]
[?def prune        scope=public impure [returns element] ($store::element) ...]
[?def rotate-kek   scope=public impure [returns element] ($store::element $new-key-id::string) ...]
[?def diff         scope=public impure [returns element] ($store::element $a::string $b::string) ...]
[?def branch       scope=public impure [returns element] ($store::element $name::string $target::string) ...]
[?def branch-force scope=public impure [returns element] ($store::element $name::string $target::string) ...]
```

- **`clone`/`push`/`pull`/`fetch`** are one engine: copy the reachable objects +
  doc-refs. Doc-keys are content-addressed (immutable, conflict-free; no CAS).
  `clone` into a non-empty store raises `CXER1113 E_STORE_NOT_EMPTY`. Works
  embedded↔embedded and embedded↔daemon. Across the model boundary these degrade
  to the doc-level `migrate` fallback (object-identity is `subtree↔subtree` only).
- **`diff`** is the showcase: read-only, no commit-graph needed. `diff(a,b)`
  hash-skips identical subtrees and descends only on difference → O(changed), not
  O(size). Output is a CX doc of `[diff [change path kind]]`, expressible as a
  `[?modify]` patch.
- **`status`** extends `StoreStats` (heads + object_count + dedup + unflushed +
  ahead/behind). **`log`** is the linear ref-log (epoch-ordered). **`gc`** =
  compaction + mark-live; **`prune`** reclaims the unreachable subset (a shared
  subtree survives another doc's delete).
- **`verify`** is the **whole-graph integrity pass**: every live doc must
  reconstruct from the object graph, or it raises `CXER1120` naming the first
  offending store-hash. It answers `[verification valid=true docs=N objects=M]`.
  This check used to run **inline on every open** of an object-graph store —
  `O(live set)` work that made boot scale with lifetime volume. Under
  demand-paged loading (below) it is available on demand or from a background
  task instead, and per-object integrity is unchanged: every paged read
  self-verifies its hash, so corruption refuses **loudly at first touch**,
  never as a silent wrong doc. On the flat document model it refuses
  (`CXER1709`) rather than answering a hollow `valid=true` — that model's
  per-read hash check *is* its verification.

**Demand-paged object load (the default).** Opening an object-graph store
populates only the **refs layer** — the manifest replay: doc-roots, the doc
order, and aliases — and objects resolve on **first touch** through the
composite getter (live sink → page cache → durable substrate), which caches
what it pages so a second touch is memory-speed. So open no longer reads the
whole live set, and resident memory tracks the **working set** rather than
lifetime volume. The page cache is deliberately separate from the write sink:
the sink's order is the flush watermark, so a paged-in read can never be
mistaken for a new object and re-persisted. `[opts eager="true"]` restores the
old behavior (whole-graph load + inline reconstruction) for a caller that
wants that check at open.
- **`rotate-kek`** re-wraps every at-rest envelope's data key under a new tenant
  KEK (§9, *KEK rotation*). Like `gc`/`prune` it is a maintenance verb on an open
  **local encrypted** handle only: encryption is a local at-rest concern and CSRP
  carries no key material, so on a service-tier handle it raises `CXER1709`
  (operators rotate on the daemon host, where the KEK env lives — the CLI verb
  `cx store-rotate-kek` exists for exactly that). On a plaintext or non-sealing
  store it raises `CXER1141 E_STORE_ROTATION_UNSUPPORTED`.
- **On a `cx-store://` service-tier handle**, `status` and `gc` are the
  server's **admin-plane** ops (CSRP §3.10/§3.11 — one name across the CX
  surface and the wire): the daemon reports/compacts its authoritative object
  economy, with `admin` RBAC + tenant scoping enforced server-side.
  **`mounts`** is the daemon-level enumeration (CSRP §3.12): the stores the
  daemon serves — name, backend, capability flags — **tenant-filtered**. It is
  inherently a service-tier op: on a local handle it raises `CXER1709` (a local
  handle IS its only store; there is no daemon to enumerate).
  **`config-reload`** triggers the daemon's runtime config reload (CSRP §3.13;
  service-tier §2.6): the daemon re-reads its own config source — nothing rides
  the wire — and answers `[config-reload applied=… generation=… changed=…]`, or
  refuses with `CXER1711`/`CXER1712` verbatim. Daemon-level like `mounts`
  (`CXER1709` on a local handle). **`branch`** is a mutable name→root ref
  (a git ref / alias); a non-fast-forward move raises `CXER1114
  E_STORE_REF_CONFLICT`; **`branch-force`** advances unconditionally
  (capability-gated).
- **`merge`/`rebase`** are **not** in this set: they need an additive
  parent-linked commit object the model does not keep (it keeps roots +
  epoch-ordered refs, linearizable ref advancement — not semantic merge). `diff`
  founds them when/if a commit-graph is added.

## §7. Subtree object model (the default)

A `subtree` store decomposes each document into a content-addressed Merkle graph
through the universal **ObjectBackend** seam:

- every element → a Node object (own name/attrs; children addressed through a
  B+tree seqtree spine, or **inlined** when ≤ fanout / a small leaf — the
  format-versioned `obj_node_inline` form);
- every scalar/text → a Leaf object; the document → a root object.

Normative properties:

1. **Cross-document subtree dedup** — an identical subtree in two documents is
   stored once.
2. **Version structural sharing** — a new version differing by one field
   re-stores only the objects on the path from the changed node to the root.
3. **Canonical round-trip** — a doc reloaded from the graph re-renders
   (`render_canonical`) to the bytes it was stored as, preserving its content
   hash; a present-but-unreconstructable object is a hard `CXER1120`, never a
   silent miss.
4. **Substrate-independence** — the *same* object hashes arise on `mem` / `file`
   (pack or object-per-key) / `sqlite` / `s3` / the object wire (model ⟂
   substrate). This is what makes object-identity transfer (§6.3) work.

The seam (`{hash → bytes}` sink + per-hash getter) is the single implementation
point: pack files, object-per-key directories, sqlite object rows, s3 keys, and
the CSRP/gRPC object wire are all the same engine over different transports.

## §8. Columnar encoding (`document` model)

`document+file://…?encoding=parquet` (or `arrow-ipc`, or `document+s3://…`) selects
a **columnar at-rest encoding** — a peer to the subtree model, doc-identity only.
A bare `…?encoding=parquet` without `document+` is a hard error (subtree + columnar
are incompatible). It is a **gated** substrate: it requires the optional Arrow
build; absent it, `open` returns an honest `CXER1100`-class error after the host
capability is checked.

- **Layout.** The live collection is one CXCol (`data-bin`) table written via the
  `vcx/arrow` bridge — the file **is** a standard Parquet / Arrow-IPC file. A
  reserved `__cx_key` column carries the store-key; a reserved `__cx_doc` column
  carries the canonical document text and is the **reconstruction + integrity
  anchor** (`get-doc` returns it; reopen re-hashes `__cx_doc == __cx_key`).
- **Schema (the value).** Top-level scalar fields are promoted to typed columns
  (union, nullable); a flat scalar sub-record is **flattened** to `parent.child`
  columns (one level). A field that is nested/irregular/mixed in any doc is *not*
  promoted (it rides losslessly in `__cx_doc`), so a column null ⟺ the path is
  absent and predicate pushdown stays exact. Promoted columns are a redundant
  projection — never the reconstruction source — so the encoding is total for any
  collection.
- **Declared schema.** `?schema=<ref>` pins the columns and validates every put via
  `cx-stdlib/validate`; a non-conforming doc is rejected with
  `CXER1115 E_STORE_SCHEMA_VIOLATION`. Inference is the default when absent.
- **Pushdown (§12).** A `//field` / `//parent/child` projection lowers to a
  column-only scan; other paths fall back to row materialization. The backend
  reports which path it took (no silent full-scan as pushdown).
- **Identity.** doc-identity universal (a columnar doc has the same store-key as on
  `mem://`); object-identity N/A — `clone`/`push`/`pull` against columnar degrade
  to `migrate`. Introspection reports its own observables (rows, row-groups,
  columns, codec, `columnar-pushdown`), not object_count/dedup.

## §9. Encryption-at-rest

An object substrate opened with `[opts encrypt-key-id=<id>]` seals each object at
rest. It is at-rest only and **invisible to the object graph**: objects are keyed
by the **plaintext** hash, so dedup, structural sharing, and refs are unchanged —
only the bytes on the substrate are ciphertext. Two implementations share one
envelope format and one crypto core: the **EncryptingObjectBackend** (the
object-per-key substrate, where each sealed object is one file) and the generic
**EncryptingWrapper** over the **keyed-object seam** (`put_object_keyed` /
`get_object_raw` — raw caller-keyed bytes with no self-verify), which seals the
pack, sqlite, and s3 substrates without any crypto in the substrate itself.

- **AEAD** = AES-256-CBC-then-HMAC-SHA256 (encrypt-then-MAC) from audited
  primitives; HKDF splits each key into independent enc/mac keys; fresh CSPRNG
  salt + IV per object; the tag (verified in constant time before decrypt) covers
  the object's content hash as additional data, binding ciphertext to address.
- **Envelope.** A per-object data key is wrapped by a tenant key (KEK) through a
  **KMS seam**; the reference provider resolves the KEK from the environment, and
  a production KMS (cloud / vault) implements the same seam. Every envelope
  **records the key-id that wraps its DEK** (a versioned envelope header:
  version byte, key-id, wrapped DEK, sealed payload), so the reader unwraps with
  the envelope's own key-id — not the handle's — and envelopes wrapped under
  different KEKs coexist in one store. That recorded key-id is what makes KEK
  rotation observable and resumable.
- **Sealing substrates.** `file://…` (pack, the default framing),
  `file://…?encoding=object-per-key`, `sqlite://…`, and `s3://…` all seal at
  rest. The content-addressed substrates store envelopes **keyed by the plaintext
  hash** under a **format-versioned at-rest mode**: pack writes version-2
  *keyed* packs (entries carry a caller key and a CRC instead of hash
  self-verification; a v1-era reader refuses a v2 pack rather than misreading
  it), sqlite declares the mode in its store-metadata table, and s3 in a marker
  key — end-to-end integrity moves to the AEAD tag plus a post-decrypt
  plaintext-hash check. The refs manifest is hash-only on every substrate and
  rides unencrypted; alias-**name** objects are sealed like any other object.
- **Mode is fixed at creation.** The at-rest mode is store-wide and declared
  durably before any data lands. A mode mismatch is a **hard error** in both
  directions: an encrypted store opened without its `encrypt-key-id` errors
  (never appears empty or corrupt), and `encrypt-key-id` on an existing
  plaintext store errors — encryption cannot be enabled in place on existing
  data (that would produce a mixed-mode store).
- **Fail-closed.** A missing or malformed key is a hard error — never a silent
  ephemeral key (which would make already-written objects unrecoverable). By the
  same principle, requesting `encrypt-key-id` on a substrate that **cannot seal**
  — `mem://` (no at-rest bytes), the document model (no object graph), columnar,
  or a remote byte-source — is a hard `CXER1100`-class error, never a silent
  plaintext write.

### §9.1. KEK rotation (`rotate-kek`)

A compromised or policy-expired KEK is retired **in place** by re-wrapping —
never by rebuilding the store. `[$store:rotate-kek $store <new-key-id>]` (CX
surface) and `cx store-rotate-kek --url <url> --encrypt-key-id <old> --new-key-id
<new>` (operator CLI) walk every at-rest envelope and re-wrap its **wrapped DEK**
from the envelope's recorded key-id to `<new-key-id>`. Because only the small
wrapped DEK changes, the contract is exactly the envelope design's dividend:

- **Payloads untouched.** Object payloads stay sealed by their unchanged DEKs and
  keys stay the plaintext content hashes — no data re-encryption, no address
  churn, dedup and structural sharing preserved bit-for-bit.
- **Atomic per object, resumable.** Each envelope is replaced atomically on its
  substrate (temp-file + rename per object file; one row / one object PUT; the
  pack substrate folds into a single new pack installed by atomic rename —
  at least per-object atomicity everywhere). An interrupted rotation leaves a
  mixed store that **still serves every read** (envelopes carry their key-id);
  re-running the rotation re-wraps only the envelopes not yet under the new
  key-id and reports them as `already-current`.
- **Serves throughout.** Reads and writes on the open handle keep working during
  rotation (ops are serialized per handle as usual); the reference KMS resolves
  any key-id recorded in an envelope from `CX_STORE_KEK_<id>` fail-closed, so a
  store mixing old- and new-wrapped envelopes opens and reads under either
  configured id while **both** env keys are present. After the walk, the handle's
  write key becomes `<new-key-id>` (new objects wrap under the new KEK), and once
  the report shows every object current, the old KEK can be destroyed.
- **Fail-closed.** The new key-id must resolve **before** the first envelope is
  touched. An envelope whose DEK unwraps under **neither** its recorded key nor
  the new key — or whose recorded key-id has no resolvable KEK — is a hard
  `CXER1142 E_STORE_ROTATION_FAILED` naming the object; rotation NEVER skips an
  envelope silently (a skipped object would surface as data loss only after the
  old KEK is destroyed). `rotate-kek` on a plaintext store, a non-sealing
  substrate, or a read-only handle is `CXER1141` / `CXER1110`; on a service-tier
  handle it is `CXER1709` (§6.3).
- **Report.** Returns `[rotation-report objects=N rewrapped=K already-current=M
  from=<old-ids> to=<new-key-id>]` — `objects = rewrapped + already-current`
  always, so the operator's destroy-the-old-KEK decision reads off one line.
- **Key-ids name key material.** Rotation is a change of **key-id**; re-keying
  the *same* id in place is indistinguishable from corruption and is not a
  rotation (a KMS that rotates material *behind* one id — e.g. cloud KMS
  automatic rotation — is invisible here by design).
- **Future work** (explicitly out of scope): DEK rotation (re-encrypting
  payloads under fresh data keys) and cross-KMS migration (re-wrapping from one
  KMS provider into another) — both compose on the same recorded-key-id
  envelope this section pins.

## §10. Storage layout, encoding, compression

### §10.1. Filesystem-style backends
```
{store_root}/
├── store.cxd               (Store metadata; readable CX)
├── aliases.cxd             (mutable name→hash alias map; §6.2)
├── <object/pack files>     (subtree: sharded object-per-key or pack segments)
```
Sharded object-per-key uses the 2-char hash prefix (git/Dir style); the pack
encoding stores segments + an incremental manifest (refs watermark). Both are the
same object graph (§7), re-packed.

### §10.2. Transport encoding & compression

| Encoding | Description | When |
|---|---|---|
| `cxbin` (default) | ast_bin per [`spec/core/ast-bin.md`](../core/ast-bin.md) — length-prefixed, mmap-friendly | production |
| `cxd` | UTF-8 canonical text per [`spec/core/canonical.md`](../core/canonical.md) | Git-backed / diff-friendly |
| `parquet` / `arrow-ipc` | columnar (§8) | analytics / interop |

**Hash invariance across encodings.** A doc stored as `.cxbin` and the same doc as
`.cxd` produce identical Layer-1 IDs — the hash is over canonical bytes, independent
of wire encoding. Compression (`zst` default, `gz` available; `none` for `mem://`)
is a filename suffix sniffed on read; a store may hold mixed encodings/compressions.
The `zst` at-rest default activates when the compression path lands (§3 transition
note); until then the shipped default is `none` and non-`none` requests are
rejected fail-closed (§6.1).

## §11. Content-addressing semantics

- **Primary key = `hash(node)`** = SHA-256 of strict canonical bytes (text default
  / `cx_to_data_bin` per [`core/canonical.md §§1.2, 4`](../core/canonical.md)).
- **Cross-axis portability** — same hash across every substrate/model/encoding.
- **Free dedup / free integrity** — storing twice writes once; `get-doc` rehashes
  after decode.
- **No latest pointers in the content store** — all docs immutable; "latest of X"
  is the alias/branch layer (§6.2, §6.3).

## §12. Query semantics

`query` evaluates a CXPath across the corpus. On a **service** mount it pushes down
to the server (`CXER`-on-unsupported, never a lying empty result). On a **columnar**
store a column-projecting path (`//field`, `//parent/child` over a promoted column)
lowers to a column-only scan; everything else materializes rows. The naive embedded
scan is O(N corpus), fanned out across a backend-aware worker pool; `iter-docs`
keeps memory bounded. For high-frequency / large-corpus queries use `cx-stdlib/ft`
or an indexed backend.

## §13. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1100` | `E_STORE_UNRESOLVED_BACKEND` | `open` on unknown/unbuilt backend |
| `CXER1101` | `E_STORE_BACKEND_UNREACHABLE` | `open` on connection failure |
| `CXER1110` | `E_STORE_READ_ONLY` | write/alias/ref mutation on a read-only Store |
| `CXER1113` | `E_STORE_NOT_EMPTY` | `clone` into a non-empty destination |
| `CXER1114` | `E_STORE_REF_CONFLICT` | non-fast-forward `branch` / ref advance (CAS) |
| `CXER1115` | `E_STORE_SCHEMA_VIOLATION` | columnar put violating a declared `?schema=` |
| `CXER1116` | `E_STORE_WRITE_FAILED` | a substrate write/persist failed after the in-memory op — the op raises instead of acknowledging a write that didn't land (never a phantom success); the open handle's in-process state stays authoritative and the next successful persist self-heals. Substrate auth rejection classifies as `CXER1131`, backend throttling as `CXER1132` |
| `CXER1120` | `E_STORE_INTEGRITY_MISMATCH` | decoded bytes don't hash to the requested key |
| `CXER1121` | `E_STORE_NOT_FOUND` | `get`/`modify`/`delete`/`set-alias` on a missing key |
| `CXER1130` | `E_STORE_CLOSED` | any operation on a closed Store |
| `CXER1131` | `E_STORE_AUTH_FAILED` | backend rejects credentials |
| `CXER1132` | `E_STORE_RATE_LIMIT` | backend signals rate limiting (retryable) |
| `CXER1140` | `E_STORE_HANDLE_RACE` | concurrent access to one shared Store handle |
| `CXER1141` | `E_STORE_ROTATION_UNSUPPORTED` | `rotate-kek` on a plaintext store or a substrate that cannot seal (§9.1) |
| `CXER1142` | `E_STORE_ROTATION_FAILED` | rotation aborted fail-closed — unresolvable key-id or an envelope unwrapping under neither key (§9.1) |

## §14. Conformance fixtures

Under `conformance/stdlib/store.cxd` (+ in-module behavioral suites
`vcx/code/store_*_test.v`, `vcx/cxstore/*_test.v`):

- **Round-trip / cross-substrate parity** — the same API sequence on
  mem/file/sqlite/s3/subtree yields byte-identical hashes.
- **Subtree object model** — cross-document dedup, version structural sharing,
  canonical round-trip across adversarial constructs.
- **Object-identity transfer** — `clone`/`push`/`pull`/`fetch` copy only missing
  objects; embedded↔daemon share one object space; `diff` is O(changed).
- **Document & columnar** — document-model API invisibility; columnar round-trip
  (file + s3), doc-identity universality, migrate, scalar + nested-flattened
  promotion with `pushdown=true`, irregular → blob fallback with
  `columnar-pushdown=false`, declared-schema accept/reject (`CXER1115`), Parquet
  interop, integrity (`CXER1120`).
- **Encryption-at-rest** — no plaintext at rest (object-per-key, pack, sqlite,
  s3); reopen+decrypt byte-identical; wrong/absent KEK fails closed; at-rest
  mode mismatch fails closed both directions; dedup preserved under encryption
  (parity with a plaintext store of the same corpus).
- **KEK rotation (§9.1)** — a store written under KEK A serves reads/writes
  while and after rotating to KEK B; mixed-key stores open under either id;
  re-run reports `already-current` (resumable); after completion the old KEK is
  destroyable (reopen with only the new env key succeeds, byte-identical);
  an envelope under an unresolvable key-id aborts `CXER1142` (never skipped);
  plaintext store → `CXER1141`; content addresses and object counts unchanged
  across rotation (dedup preserved).
- **Tier-2 code identity** — `put-def`/`get-def` alpha-dedup.
- **Integrity / read-only / closed / handle-race** — `CXER1120` / `1110` / `1130` /
  `1140`.
- **Aliases** — round-trip, persistence across reopen, absence channel, alias does
  not own content.
- **Migration** — cross-axis lossless (every doc ID preserved; aliases copied).
- **Cross-binding parity** — Python / Go / Rust produce byte-identical hashes.

## §15. Capabilities

Effectful functions run under deny-by-default capabilities
([`spec/core/security.md`](../core/security.md) §2); the effect point raises
`cx-err:CXER0271` (naming the missing capability + resource) when a grant is absent.
The required host capability depends on the substrate: a `file`/local backend needs
`read` (read path) / `write` (write path); a remote URL-dispatched backend
(HTTP/WebDAV, S3, FTP/SFTP, service tier) needs `net` for every operation. The
columnar gated substrate checks the host capability **first** (so an ungranted
caller learns nothing about whether the Arrow build is present).

The `mem://` Memory tier is **capability-free** — pure in-process state, neither a
file nor a network effect point — so it runs under any set including the empty one.
(Store-specific errors — read-only, not-found, closed, handle-race — still apply.)

| Capability | Functions |
|---|---|
| `read` (file/local) | `get-doc`, `get-doc-text`, `get-def`, `exists`, `iter-docs`, `list-docs`, `get-alias`, `list-aliases`, `query`, `status`, `log`, `diff` |
| `write` (file/local) | `put-doc`, `put-doc-text`, `put-doc-stream`, `put-def`, `delete-doc`, `modify-doc`, `set-alias`, `delete-alias`, `migrate`, `clone`, `push`, `pull`, `fetch`, `gc`, `prune`, `branch`, `branch-force` |
| `net` (remote / service) | all of the above when the Store targets a remote backend |

## §16. Cross-references

- [`spec/misc/bindings.md`](../misc/bindings.md) — Layer-1 API (`parse`, `bytes`, `hash`, `modify`).
- [`spec/core/cxdm.md`](../core/cxdm.md) — content-addressing hash policy.
- [`spec/core/canonical.md`](../core/canonical.md) — canonical form (hash preimage).
- [`spec/core/code.md`](../core/code.md) — Tier-2 code identity; absence channel.
- [`spec/core/ast-bin.md`](../core/ast-bin.md) · [`spec/core/data-bin.md`](../core/data-bin.md) — binary + columnar (CXCol) wire encodings.
- [`spec/core/abi.md`](../core/abi.md) — Layer-1 capability bits.
- [`spec/misc/cxstore-remote-protocol.md`](../misc/cxstore-remote-protocol.md) — CSRP wire spec (Service tier).
- [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md) — Tier-1 binding parity.
