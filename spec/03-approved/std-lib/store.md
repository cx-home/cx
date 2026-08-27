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
| **wire** (service only) | `xsp` (the store profile — THE store wire, §6.4) · `grpc` (the integration edge) | The full read-write API over the network. `cx-store://` names the store served over the XSP store profile (§6.4) — the CX-to-CX wire; `cx-store+grpc(s)://` is the gRPC edge adapter ([`cxstore-grpc.md §6`](../misc/cxstore-grpc.md)) for gRPC-speaking environments, re-based onto the profile pipeline with per-call XSP-AUTH. The CSRP data plane and its `cx-store+http\|+https` scheme tokens are RETIRED (stream-4 S3): the tokens refuse at open with a pointer to the live wires, and the daemon's HTTP surface is bootstrap-only (health/ready/metrics/capabilities). A bare `https://` is only a passive byte source; the active service API is `cx-store://` — the two HTTP roles are distinct. |
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
- **Documents split by IDENTITY RULE (F1', ruled 2026-08-08).** A
  **structured** document (cx data) is keyed by the hash of its **strict
  canonical bytes** — normalization is meaningful and the canonicalized
  round-trip is the contract (`put-doc`/`put-doc-text`). An **opaque**
  document (CX code, images, plain text — anything whose bytes ARE the
  content) is keyed by the hash of its **raw bytes** and round-trips
  **byte-exact** (`put-blob`/`get-blob`); no canonicalization ever applies.
  Both identity rules are substrate/model/encoding-invariant. Every blob
  read re-verifies `key == hash(raw)` at the boundary — no storage path may
  skip verification. Persisted with a record-kind discriminator (`B`)
  selecting which hash rule verifies; the discriminator is part of the
  identity rule, and the key always remains the hash of the stored bytes.
  **The rules never leak into each other:** the structured verbs
  (`get-doc`/`get-doc-text`/`modify-doc`/`diff`) refuse an opaque key with
  one typed error (`CXER0100 E_OPERAND_KIND`, identical on every model —
  never model-divergent, never silent bytes); structured iteration
  (`iter-docs`) and `query`/`source` walk structured documents only, while
  `list-docs`/`exists`/`delete-doc`/erasure are kind-agnostic (one key
  inventory, one deletion/erasure funnel).
- **Computation identity is NOT a storage key** (F1'/A1, ruled 2026-08-08).
  CX code is an opaque document: stored by `put-blob` under its raw-byte
  hash. The "same function?" relation ([`code.md`](../core/code.md)) remains
  available as the pure `[$cx:computation-id]` claim
  (`computes-as:<algo>:<hex>` — a distinct token the address parser refuses),
  usable as an index or a recompute-and-compare check, never an address.
  The retired computation-identity-keyed record kind (`C`) refuses loudly
  at load on every substrate — no read path admits a key that is not the
  hash of the stored bytes.
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

**One writer per local root — ENFORCED at `open`.** On a substrate with a local
root (`file` in all three framings, `sqlite`, local-file `columnar`) the
supported concurrent shape is **ONE writable handle + N READ-ONLY handles**, and
this holds across processes as well as within one. Within a process, matching
writable opens of one root return handles over the **same live store** (the #628
same-root sharing rule; divergent at-rest options refuse `CXER1143`). Across
processes there is no live store to share, so a **second writable `open` is
REFUSED `CXER1143`**, naming the holder and the recovery path. Two independent
writers on one root are unsound — they collide on segment numbering, and a
columnar or flat-index writer discards the other's state wholesale — and the
damage is invisible until a later `open` refuses `CXER1120` with an object or
segment missing.

**Read-only opens are exempt**, in both directions: they never write, so any
number of them may coexist with the one writer, and they take nothing that
another opener must wait for.

The guard is an advisory lock on a sentinel at the root, held for the life of
the writable handle and **released by the operating system when its holder
exits** — including an abnormal exit. A crashed writer therefore never leaves a
root unopenable; the sentinel's contents name the holder for the refusal text
and are never the authority on whether the lock is held. A substrate that cannot
honor advisory locks (some network mounts) is **unguarded and says so** on the
first such open — never refused, which would make the root unusable for a
limitation of its filesystem. `mem://` has no at-rest bytes to protect, and a
`columnar` store over `s3` has no local root to key on (its sharing identity is
endpoint + bucket + object key) — object-store concurrency is that tier's own
contract.

### §5.1. Backend capabilities

| Capability | Semantics |
|---|---|
| `read` | `get-doc`, `list-docs`, `query`, `source`, `iter-docs`, `exists` |
| `write` | `put-doc`, `modify-doc`, `delete-doc`, alias + ref mutation |
| `list` | `list-docs` / `iter-docs` enumerate efficiently |

These backend **traits** (what a backend can structurally do) are distinct from the
host **capabilities** (`read`/`write`/`net`) that gate the OS effect at the effect
point (§15).

### §5.2. Consistency declarations — the handle floor (stream 7)

The declare-and-verify guarantee vocabulary
([`consistency_vocabulary.md`](../core/consistency_vocabulary.md))
attaches to the store surface at **open**: `open-opts` accepts a `consistency`
key (one atom or a `(…, …)` sequence of atoms from the closed vocabulary),
checked **once, at declaration time**, against the guarantee set this store
surface advertises:

- `:linearizable-ref` — the CAS ref vocabulary is real (branch's fast-forward
  guard, §6.3; the wire's `expect=` forms, §6.4). **Declaring it flips
  expect-less ref writes to errors on this handle (F5, #714 item 4):**
  `set-alias` (silent LWW under a second writer), `delete-alias` (no
  expect-bearing form exists), and `branch-force` (an unconditional advance)
  each refuse with `cx-err:CXER4990 E_CONSISTENCY_UNSATISFIABLE` naming the
  stage (`write`), the token, and the sanctioned forms — plain `branch` stays
  available (its fast-forward guard IS the CAS discipline). An undeclared
  handle keeps today's behavior exactly.
- `:monotonic-reads` — content-addressed reads cannot be stale by
  construction (§11); a read-only private view is frozen; a live handle's
  ref reads never rewind.
- `:read-your-writes` — over a **local** backing or a **service-tier**
  remote (every read routes to the daemon per op); a **byte-source** remote
  (s3/http/ftp/sftp) refuses it — a caching fetch layer cannot prove its own
  writes visible back. **Ref-caching layers are refused by rule (F4):** the
  model is immutable-objects-forever / refs-revalidate — a `?cache=` layer
  that caches REFS under a declared `:read-your-writes` or
  `:linearizable-ref` floor must refuse at open (today the `?cache=` URI
  parameter is already rejected as accepted-but-unimplemented, §3; this rule
  binds any future implementation).

Every other token refuses at the floor with the advert carried
(satisfy-or-reject; stream-shaped tokens belong to the journal/fabric/xsp
floors). The declared floor is echoed on the handle element
(`consistency=` attribute — inspection answers values); a token outside the
closed vocabulary is a typed error, never ignored; `:exactly-once` /
`:serializable` carry their standing teaching refusals. On the write-failure
edge the scope of `:read-your-writes` is **writer-scoped inside the
`CXER1116` self-heal window (F6)**: after a `CXER1116 E_STORE_WRITE_FAILED`
raise, the open handle's in-process state stays authoritative and the next
successful persist self-heals (§13) — the declaration covers THIS handle's
view, not the substrate's, until that persist lands.

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
[?def put-blob       scope=public impure [returns string] ($store::element $raw::string) ...]
[?def get-blob       scope=public impure [returns [or string [sequence string]]] ($store::element $hash::string) ...]
```
`put-*` return the SHA-256 store-key (64 hex); dedup is automatic. `put-doc-stream`
takes an already-canonical byte `source` and stores it through the same
hasher/writer, yielding the **identical content address** `put-doc` would (the
degenerate-but-correct as-built form). Chunked streaming through the
hasher/compressor for a large *external* byte source (bounded memory) is a tracked
refinement; the verb's contract — a canonical source in, the content-address out —
is stable regardless. `get-doc` answers the **three-way discriminator**
(stream 20, ruling L185/#720): decode/rehash failure → `CXER1120
E_STORE_INTEGRITY_MISMATCH`; never-existed → `CXER1121 E_STORE_NOT_FOUND`;
**lawfully erased → the attributed `[erased … at= authority= actor=
shred-request=]` tombstone on the VALUE channel** (§9.2 — server-asserted,
never a client-inferred miss; erased ≠ never-existed ≠ corrupt). `get-doc-text`
answers the same third way with the tombstone's canonical **text** verbatim.
`put-blob`/`get-blob` are the F1' OPAQUE-document pair (§4): the key is the
hash of the RAW bytes as given, the round-trip is byte-exact, and every read
re-verifies `key == hash(raw)`; absence raises `CXER1121`, a rehash mismatch
`CXER1120`. Writes to a read-only
Store raise `CXER1110 E_STORE_READ_ONLY`.

### §6.2. List / query / modify / delete / aliases / migrate / introspect

```
[?def list-docs   scope=public impure [returns [sequence string]]  ($store::element) ...]
[?def iter-docs   scope=public impure [returns [sequence element]] ($store::element) ...]
[?def query       scope=public impure [returns [sequence element]] ($store::element $q::[or path element] $opts={}) ...]
[?def source      scope=public impure [returns [sequence any]]     ($store::element $cxpath::path) ...]
[?def explain-query scope=public impure [returns element]          ($store::element $q::element) ...]
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
```
`query` evaluates the CXPath against every doc (§12), returning the
**flat provenance-bearing relation** (stream-2 ruling L97): one
`[result doc=$h source=$ref MATCH]` element **per match** — `doc` is the
containing document's content address, `source` is the source-reference
string `<store-url>#<cxpath>`, and the match itself (an element, or a
scalar for a trailing attribute-axis step) is the single child. A
document with N matches yields N `result` tuples (document order,
documents in insertion order); the former doc-keyed nesting
(`[result hash=… [sequence …]]`) is retired. `source` evaluates the
same CXPath and returns just the **matched values** — the tuples'
payloads in the same order, with no provenance wrapper. It is THE
store-side generator source form for planar comprehensions
([`code.md §7.8`](../core/code.md)):
`[?for [in $o [$store:source $s /orders]] …]` binds `$o` to each match,
and the comprehension's source set is nameable, versionable, and
authorizable from the text alone.

**Quoted planar queries (stream-2 ruling L99).** `query` also accepts a
**quoted planar comprehension** in the second position — an element value
(`[?quote [?for …]]`), never a string (a string is always a CXPath).
Entry is gated by the [`code.md §7.8`](../core/code.md) six-point
membership test: a non-member refuses the typed `cx-err:CXER0120
E_NOT_PLANAR` naming the violated point — never a silent fallback. The
executor is the **shipped sandboxed `[?eval]`** ([`code.md
§6.4.4`](../core/code.md)): the quoted tree lowers with no parse step and
evaluates in an **isolated context** under the **narrowed capability
set** — `write`/`env`/`clock`/`random`/`subprocess`/`eval`/
`secret-reveal` are denied for the query's dynamic extent (the pure
fragment needs none of them; `read`/`net` stay — they are what source
scans use). **Authorize-before-execute:** the source **slice set** is
extracted statically from the text on the one normative walk (ruling
L100 — every `[$store:source …]` / `[$journal:source …]` with its
literal path/stream; a non-literal path defeats static extraction and
refuses `CXER1709` — the slice set must be static). Source-ref handle
names in the quoted text are **formal parameters**: a quoted query is
portable text (plan-addressed, cacheable, wire-shippable — a quote
captures no environment), so at execution EVERY store-source handle
name binds to **the queried store**, identically local and remote (one
executor, one store — transparency by construction); a
`[$journal:source …]` inside a quoted STORE query refuses `CXER1709`
(journals have their own surfaces). Those handle bindings are the ONLY
names the sandbox receives — the §6.5.1 purity theorem guarantees the
query touches exactly its source set, and any other free name fails
loudly at evaluation. The **two authorization layers are distinct and
named**: the **host-capability layer** — the `eval` capability gates the
executor (quoted code is dynamic execution) and the handle-level
`read`/`net` grants gate the sources (§15) — and the **authz-slice
layer** — when `$opts` carries an `authz` handle (with `actor`, and
optionally `tenant` / `as-of`), the [`authz.md`](authz.md) `check` runs
per extracted slice (capability `read` × the slice path × the tenant)
**before anything executes**; any `[deny]` refuses
`cx-err:CXER4700 E_AUTHZ_UNAUTHORIZED` carrying the full `[deny]` value
as its cause, and nothing executes (fail-closed — a `[deny]` element
inside a result relation could be mistaken for data). The result is the
comprehension's **own relation** (its yield shape) — provenance rides
wherever the comprehension projects it. `explain-query` takes the same
quoted form and reports **without executing**:
`[query-plan plan= [slices [slice kind= handle= path=]…] [rewrites …]]`
— `plan=` is the [`code.md §7.9`](../core/code.md) plan address (equal
to `cx:plan-address` of the same source), `slices` the extracted source
set, and `rewrites` the applied/declined L96 execution equivalences
(the honest-reporting obligation: no silent rewrite, no silent
full-scan). On a **remote** handle the quoted form serializes to source
text and rides the wire query op's `comp=` attribute (`path=` and
`comp=` are mutually exclusive); the SERVER applies its own two layers
and binds the formal handle names to the served store — the same
contract as local execution, so the relation is identical by
construction.

`modify-doc` applies a Layer-1 action and
stores the result as a **new** doc (originals are immutable). The action
vocabulary is the full `[?modify]` set of [`code.md`](../core/code.md),
including `[using FN]` (computed replacement, kind-shift allowed); the FN is
always applied **client-side** — caller code never crosses the wire, so on a
remote-backed store `[using FN]` degrades to get → transform → put and yields
the identical content address a local store would. **`modify-doc` + a pure
`[using FN]` is THE stored-doc migration primitive**
([`schema_event_evolution.md`](../core/schema_event_evolution.md),
rulings L148/L152): stores migrate in **batch**, non-destructively by
construction — the old doc remains addressable, dedup makes unchanged docs
free, and migration provenance is a **Lane-2 claim value**
(`[migrated-from hash=<old-address> …]`, the journal's hash-linkage
discipline reused) — never store metadata, never a version field on the
value. Migration is the representational **fourth relation**: it never
enters the journal's correction taxonomy and never alters valid time
(conformance `store-mig-001` / `journal-125`). A read-time transform
without a put is projection, not migration — permitted, never the default. Aliases are the one
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
would lie.

**The `computation/` alias namespace (stream 5 — the deterministic result
cache; `computation_identity.md`).** `computation/<addr>` binds a
computation's result: `<addr>` is the plain Tier-1 address of a stored
`[computation]` record and the alias target is the result's address.
Results are ordinary stored values and the verbs are the ordinary alias
verbs — **no new store API, no `[?memo]`**: an explicit store-mediated
lookup (`get-alias` then `get-doc`) keeps the cache honest and visible.
What distinguishes the namespace is **fail-loud admission** on
`set-alias` (enforced in the LOCAL arm, which the daemon's alias-remoting
op also routes through — one authority on every surface):

- `CXER1117 E_STORE_COMPUTATION_RECORD_INVALID` — `<addr>` is not an
  address; no record is stored at `<addr>`; the stored value is not a
  well-shaped `[computation]` record (`computation` → `fn`/`inputs`/
  `env`/`caps`, `fn` → `code` + `source`); the `fn.code` Tier-2 claim
  does not recompute from `fn.source`; or the record text does not
  rehash to `<addr>` (recompute-and-refuse, never trust-the-name).
- `CXER1118 E_STORE_COMPUTATION_NOT_PURE` — `fn.source` does not resolve
  in this store, is not a single `[?def …]`, does not declare `pure`, or
  fails the static purity checker. The cache is **pure-only**: the
  `pure ⇒ deterministic` theorem ([`code.md §6.5.1`](../core/code.md))
  is what makes a cached result sound. Admission is a trust boundary —
  any checker refusal (including an unclassified head) refuses.
- `CXER1119 E_STORE_COMPUTATION_RESULT_NOT_CACHEABLE` — the target is an
  `[err]` value of a never-cached class: the `CXER0270–0279`
  runtime-environment band (budget exhaustion, stack/host limits) plus
  the host-tunable `CXER0153` par-width cap — host/state artifacts,
  never computation answers. Input-dependent `[err]`s (e.g.
  divide-by-zero) remain cacheable: they are deterministic per the
  theorem.

`migrate` copies every doc + alias
preserving content-hash IDs (lossless across any axes); a source reconstruct
failure is a hard `CXER1120`, never a silent skip. **The verb named `migrate`
is replication** — defined by its inability to change a byte (the
content-hash-preserving copy); the schema-migration transform primitive is
`modify-doc` + `[using FN]` above
([`schema_event_evolution.md`](../core/schema_event_evolution.md) §1). `capabilities` returns
`[read write list backend url compression encoding …]`; closed-Store ops raise
`CXER1130 E_STORE_CLOSED`.

### §6.3. Git porcelain over object plumbing (`subtree`)

Over the object plumbing `have`/`get`/`put`/`refs`, the sound porcelain set:

```
[?def clone        scope=public impure [returns element] ($src::element $dst::element) ...]
[?def push         scope=public impure [returns element] ($local::element $remote::element) ...]
[?def pull         scope=public impure [returns element] ($local::element $remote::element $opts::map {}) ...]
[?def pull-report  scope=public impure [returns element] ($local::element $remote::element $opts::map {}) ...]
[?def fetch        scope=public impure [returns element] ($local::element $remote::element) ...]
[?def status       scope=public impure [returns element] ($store::element $opts::map {}) ...]
[?def mounts       scope=public impure [returns element] ($store::element) ...]
[?def config-reload scope=public impure [returns element] ($store::element) ...]
[?def verify       scope=public impure [returns element] ($store::element) ...]
[?def log          scope=public impure [returns [sequence element]] ($store::element) ...]
[?def gc           scope=public impure [returns element] ($store::element) ...]
[?def prune        scope=public impure [returns element] ($store::element) ...]
[?def rotate-kek   scope=public impure [returns element] ($store::element $new-key-id::string) ...]
[?def diff         scope=public impure [returns element] ($store::element $a::string $b::string) ...]
[?def reconcile    scope=public impure [returns element] ($store::element $source::element) ...]
[?def reconcile-report scope=public impure [returns element] ($store::element $source::element) ...]
[?def branch       scope=public impure [returns element] ($store::element $name::string $target::string) ...]
[?def branch-force scope=public impure [returns element] ($store::element $name::string $target::string) ...]
```

- **`clone`/`push`/`fetch`** are one engine: copy the reachable objects +
  doc-refs. Doc-keys are content-addressed (immutable, conflict-free; no CAS).
  `clone` into a non-empty store raises `CXER1113 E_STORE_NOT_EMPTY`. Works
  embedded↔embedded and embedded↔daemon. Across the model boundary these degrade
  to the doc-level `migrate` fallback (object-identity is `subtree↔subtree` only).
  Results are **head-set-bearing reports** (stream 9, L176): each carries the
  destination's post-transfer `[heads …]` (the status shape — one vocabulary),
  never a bare counter. The alias plane deliberately does NOT ride these verbs
  (the asymmetry vs `migrate`, which copies aliases, is by design — #719 item
  5): branches are the divergence surface, and divergence is `pull`'s job.
- **`pull` = `fetch` + per-ref reconciliation** (the L176 split — the
  `pull ≡ fetch` debt discharged, #719 item 4): after the object transfer, the
  branch-class alias plane reconciles from the source (`reconcile` above —
  fast-forwards apply, divergence yields `[conflict]` values,
  `opts.resolutions` re-enter as the input table). `pull` is ENFORCING
  (raises `CXER5053` carrying every `[conflict]` iff the composed report says
  `ok=false` — the agreement law; the fetch half and clean fast-forwards have
  already landed, reported); `pull-report` is the never-raising twin. The
  peer may be LOCAL or a **service-tier (`cx-store+xsp://`) remote**: the
  wire reconciliation reads the peer's aliases and E3 lineage over the
  profile's `aliases`/`log` ops (ONE examination, two transports — the
  PeerView seam); a byte-source remote refuses loud (no lineage to ask), a
  remote DESTINATION refuses loud (reconciliation mutates ours locally),
  and pull never silently degrades to fetch. `status opts.peer` accepts the
  same peers. Conformance pin `store-pull-002`; the wire lane is V-tested
  against a live daemon.
- **`reconcile-report` / `reconcile`** (stream 9, #681 —
  [`distributed_store.md`](../std-lib/distributed_store.md) §4/§5):
  per-ref reconciliation of the ALIAS plane from a source store into this one
  — the mutable half the one-engine transfer verbs deliberately skip. Per
  branch-class alias (derived caches `computation/`/`cx-live/` excluded):
  identical / ours-ahead count visibly; theirs-ahead **fast-forwards**
  (target doc copied when absent, the ref advanced through the one
  live-mutation seam, durably recorded); both-moved-past-the-common-base
  applies **nothing** for that ref and reports the ONE Ring-0
  `[conflict subject= kind=:diverged-advance [base position= hash=]
  [ours … [diff …]] [theirs … [diff …]] [cas code=CXER1114 expect-pos=
  actual-pos=]]` value — the common base is NORMATIVE (the greatest position
  at which both lineages record the same target, from the E3 alias lineage),
  the diffs are navigable and patchable (`patch(base, ours-diff) ≡ ours`,
  the cx module's §5 law), and the CAS coordinates ride as data. Partial
  success is reported, never mixed silently. `reconcile-report` never
  raises; `reconcile` (the enforcing twin, the XAP compose/compose-report
  agreement-law pattern) raises `CXER5053 E_SYNC_DIVERGED` carrying every
  `[conflict]` **iff** the report says `ok=false`. Conformance pins
  `store-reconcile-001/-002`.
- **`diff`** is the showcase: read-only, no commit-graph needed. `diff(a,b)`
  hash-skips identical subtrees and descends only on difference → O(changed), not
  O(size). Output is a CX doc of `[diff [change path kind]]`, expressible as a
  `[?modify]` patch.
- **`status`** extends `StoreStats` (heads + object_count + dedup + unflushed +
  ahead/behind). The ahead/behind half (stream 9, L177 — #719 item 1
  complete): `opts.peer` engages the DRY reconcile classification against a
  peer handle — `[peer url= identical= ahead= behind= diverged= [stream
  name= state= ours-pos= theirs-pos=]…]`, per-stream
  `:identical`/`:ahead`/`:behind`/`:diverged` states (positions are each
  side's own dense E3 coordinates; the CLASSIFICATION is the cross-store
  fact — a staleness scalar is ruled insufficient). Conformance pin
  `store-status-003`. A handle opened with `replica: "true"` is a REPLICA
  surface (audit M8 — stream 7's replica declaration profile): its
  guarantee advert is `:prefix-consistent`/`:at-seq-pinned`/
  `:monotonic-reads`, so declaring `:read-your-writes` or
  `:linearizable-ref` refuses at open (CXER4990, wiring-time). Pin
  `store-replica-001`. **`log`** is the linear ref-log (epoch-ordered). **`gc`** =
  compaction + mark-live; **`prune`** reclaims the unreachable subset (a shared
  subtree survives another doc's delete).
- **`verify`** is the **whole-graph integrity pass**: every live doc must
  reconstruct from the object graph, or it raises `CXER1120` naming the first
  offending store-hash. It answers `[verification valid=true docs=N objects=M]`.
  A whole-doc subject object that fails to open **reconciles from evidence**
  exactly like a read (§9.2, stream 20): covered by a journaled erase record →
  a lawfully-shredded doc is a **FINDING counted visibly** (`redacted=K`,
  present when non-zero — the generalized visible-count rule,
  [`erasure_compliance.md`](../std-lib/erasure_compliance.md)), never a
  fault; uncovered → the typed unavailable/integrity error, fail-closed. The
  same reconciliation runs in the `eager="true"` load-time pass: a covered
  shredded doc never refuses the whole store (reads answer `CXER1145`), while
  an uncovered unopenable subject doc keeps the loud open refusal.
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
- **`merge`/`rebase`** are **not** in this set — amended to the narrower
  truth (stream 9, ruling L174): PARENTAGE exists (the E3 per-ref lineage IS
  a parent-linked chain); what the model declines to keep is a merge NODE.
  A reconciliation is an **ordinary ref advance whose recorded join** —
  both parent tips and the common base, as locator triples — rides a stored
  `[merge …]` record and the lineage itself (`reconcile` with a resolutions
  input, above; the commit-graph/DAG alternative is REFUSED on the record in
  [`distributed_store.md`](../std-lib/distributed_store.md) §3: it
  reopens compaction, retention, verify density, and the identity story for
  a structure the merge-entry makes unnecessary). The **common base rule is
  normative**: the greatest position at which both lineages record the same
  target. Semantic value merge is the cx module's `cx:merge`; `rebase`
  stays out.

### §6.4. The wire — the XSP store profile

The store's network API is the **XSP store profile** (stream 4, #676;
normative in the store profile spec — `spec/03-approved/xap/xsp_store_profile.md`
until promotion). **Client URLs:** `cx-store://host:port/store-name/` dials
the daemon's `[xsp]` listener over TLS; `cx-store+xsp://` is the cleartext
sibling (loopback/dev — the `+http` of the profile era). The port is
explicit (the profile has no registered default), the URL carries NO
userinfo (client identity rides open-opts `xsp-did` + `xsp-seed-env`; the
seed always names an env var, never a URL or literal — the bearer-in-URL
pattern retires with CSRP), and the store-name path segment is the
tenant the attach binds. Every data/admin op above becomes a payload VERB
(request→reply on a stream-id) over the generic XSP frame + session layer,
with `query`/`iter`/`list` as credit-governed `event` streams
(`cancel`+`eos`, never unbounded). Lanes are ruled by role: doc BODIES ride
`ast_bin` (content addresses stay byte-exact end-to-end); verb ENVELOPES
ride text-canonical CX; binary fields carry varint-multihash addresses with
the normative tagged-text bijection. Attach is XSP-AUTH (mutual,
channel-bound, transcript-signed — identity model §4, incl. the §4.4a
vocabulary negotiation); authority is VC-compiled capability values — ONE
authority model, no parallel provider stack. Errors are numeric and
registered (the profile's `CXER5000–5049` band). The profile also carries
the change feed (ref-advance + doc-put subscriptions, ∂ frames, HEAD-SET
resume cursors), the object wire (`objects-have/get/put/refs`,
generation-bound `[store-advert]`), erasure semantics (`[erased]`
tombstone ≠ not-found; shred propagation on the feed), and the `peer`
server↔server channel (revocation propagation as a subscription).
Locally, the SAME fixed `store:log` lineage (#708 — dense per-plane
positions: the docs plane plus one stream per named wire ref) is the
feed `cx-stdlib/live` reads: `[$live:changes-since]`/`observe` cursors
over store sources are head-sets on these streams (the live pack spec
`live.md` §4; live modes L136 — one log, so the local porcelain and
the wire subscription can never disagree).

**Retirement (EXECUTED, stream-4 S3 2026-08-08):** CSRP (the prior HTTP/1.1
wire) is RETIRED whole — routers, binary codec, client arms, the
`csrp-handle` def, and the `cx-store+http|+https` scheme tokens (which now
refuse at open); the `17xx` error band is reserved (governance §9.6). The
gRPC edge adapter stays, re-based onto the profile pipeline with per-call
XSP-AUTH ([`cxstore-grpc.md §4`](../misc/cxstore-grpc.md)). Legacy CSRP
§3.x references in this document (admin-plane ops above) name the
protocol-independent op contracts, served today by the profile verbs and
the gRPC edge.

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
   substrate). This is what makes object-identity transfer (§6.3) work, and it
   holds across the deployment tiers: a document stored embedded and the same
   document stored via the service tier resolve to the same object hashes —
   an embedded client and a server share **one object space**.
5. **Universal integrity** — every object read **self-verifies**
   (`name == hash(bytes)`) on every substrate and over the wire; a corrupt or
   missing object is a hard `CXER1120 E_STORE_INTEGRITY_MISMATCH`, never a
   silent doc drop. (The wire additionally refuses a mismatched `objects-put`
   with `CXER5017` — the server never trusts the label.)
6. **Model is invisible to the API** — the Layer-1 store API and doc identity
   are identical whether a store is `document` or `subtree`; the model is an
   `open`-time / at-rest property (§3), never an API distinction. The
   `document` model is the **degenerate** ObjectBackend — one object per
   document (the whole canonical blob) — so one code path serves both models.

The seam (`{hash → bytes}` sink + per-hash getter) is the single implementation
point: pack files, object-per-key directories, sqlite object rows, s3 keys, and
the object wire (the XSP store profile's `objects-have`/`objects-get`/
`objects-put`/`refs-set` family, with the gRPC edge at verb parity) are all the
same engine over different transports.

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
  subject-keyed=S subject-keys=J from=<old-ids> to=<new-key-id>]` —
  `objects = rewrapped + already-current + subject-keyed` always (the balanced
  account, extended by stream 20), so the operator's destroy-the-old-KEK
  decision reads off one line. `subject-keyed` counts envelopes wrapped under
  a subject key (§9.2) — **out of tenant-rotation scope by design**: their
  wrapping key is the SEK, and re-wrapping them under the tenant KEK would
  defeat crypto-shredding; a destroyed-SEK envelope carries verbatim (the
  shred survives any number of rotations). `subject-keys` counts SEK key
  blobs whose own KEK wrap moved (the custody layer's re-wrap — the same
  rewrap kernel over the key sidecar).
- **Key-ids name key material.** Rotation is a change of **key-id**; re-keying
  the *same* id in place is indistinguishable from corruption and is not a
  rotation (a KMS that rotates material *behind* one id — e.g. cloud KMS
  automatic rotation — is invisible here by design).
- **Future work** (explicitly out of scope): DEK rotation (re-encrypting
  payloads under fresh data keys) and cross-KMS migration (re-wrapping from one
  KMS provider into another) — both compose on the same recorded-key-id
  envelope this section pins.

### §9.2. Subject keys (SEK) — crypto-shredding (stream 20)

The destroyable middle tier of the three-tier hierarchy **KEK (tenant,
rotatable) → SEK (per subject, destroyable) → DEK (per payload)**
([`erasure_compliance.md`](../std-lib/erasure_compliance.md) §2,
rulings L181/L183; the keying-backend refactor audit M32 named):

- **A SEK is an ordinary named KMS key** whose id carries the reserved prefix
  `sek/` — `sek/<tenant>/<subject-token>`, the token an opaque 128-bit CSPRNG
  value (never the subject id, never derivable from it: the key **namespace**
  must not be a subject oracle). The shipped v2 envelope carries a SEK id in
  its recorded key-id field unchanged; reads stay key-blind.
- **Write path.** A doc whose root carries the reserved `subject=` attribute
  (with its mandatory `nonce=` — [`journal.md`](journal.md) §2.11; refusal
  `CXER4619`) is stored **WHOLE**: one sealed object holding the strict
  canonical bytes, never the decomposed subtree graph — structural sharing
  must never cross the shred boundary (a shared subtree under one subject's
  SEK would strand unrelated docs at shred, or leak subject bytes under the
  tenant key in the reverse insertion order). Dedup is correctly lost only
  for nonced records. The whole-doc object **self-identifies**: its object
  key IS the doc hash (same canonical bytes both ways) — no per-doc metadata,
  no manifest format change; the Tier-1 address is unmoved (address parity).
- **Custody, fail-closed (`CXER1144 E_STORE_SUBJECT_UNSUPPORTED`):** a
  plaintext store, a remote/wire handle, or a substrate with no key custody
  REFUSES a subject declaration it could never shred — never a warning, never
  a plaintext fallback. (Erasure over the wire — replicas included — is the
  stream-4/9 joint surface.) The reference provider persists SEKs as
  KEK-wrapped blobs in the store-root `keys/` sidecar (the same operator
  boundary the env KEKs live in), with the subject→key mapping beside them —
  OUT of the store's data plane; a production KMS holds subject keys
  host-independently through the same seam.
- **Destruction** is the provider's key-removal primitive; afterwards every
  envelope wrapped under that SEK fails closed with the **typed
  `unavailable` discrimination** (absent key — destroyed, misconfigured, or
  provider outage: one observable at the unwrap site, deliberately ambiguous
  without the journaled erasure record) — never conflated with an
  authentication failure (key present, bytes tampered). Classifying an
  absence as **lawful erasure** requires the attributed shred-request record
  (audit M33), never key absence alone.
- **Rotation interaction:** §9.1's balanced report — SEK-wrapped envelopes
  never move at tenant rotation; the SEK blobs re-wrap.
- **The shred walk (stream 20 W4 — the store half of the journal's
  `erase-subject` command, [`journal.md`](journal.md) §3.3):** per store, the
  walk resolves the subject's SEK **without minting**, enumerates the
  whole-doc set by recorded wrapping key-id (plus live seal-override routing
  for staged docs), tombstones each doc through the ONE §7b.1 funnel (T+E —
  attribution survives; the tombstone is the ruled `[erased … at= authority=
  actor= shred-request=]` shape, and it never names the subject),
  **destroys the SEK + removes the subject mapping**
  (post-shred the substrate names the subject only from the journaled
  record), sweeps the derived surfaces (`computation/` cache entries whose
  record references the scope — record + result docs erased, alias dropped;
  materialization **checkpoints** erased — derived-state posture, loss = full
  replay; `[live-materialization]` registration markers untouched), purges
  the **in-process plaintext** (the object sink's staged copies and the
  demand-paged read cache), and purges the **durable envelope residue** —
  pack: survivors fold into one compacted keyed pack (the rotation shape);
  cxobj: per-file unlink; sqlite: row DELETE; s3: keyed DELETE. The residue
  purge exists for **restart-safe supersede**: a doc re-landed at the same
  address must never content-dedup against a stale envelope sealed under the
  destroyed key. Each store's copies seal under that store's OWN sidecar SEK,
  so the walk destroys each store's key.
- **Read classification (`CXER1145 E_STORE_SHREDDED`, audit M29):** a
  whole-doc object that fails to open under an ABSENT `sek/` key classifies
  from EVIDENCE — covered by a journaled erase record (the `cx:erasure`
  entry pointers live beside the docs) → the typed shredded finding naming
  the `request=`; uncovered → the fail-closed unavailable (outage,
  misconfiguration, or unlawful destruction — never reported as lawful
  erasure). Never guessed from key absence alone.
- **Whole-store transfer:** `clone`/`migrate` carry BOTH subject custody
  (the destination mints its OWN SEK per subject and the copies seal under
  it; a plaintext destination refuses `CXER1144` — never a silent plaintext
  landing) and the **erased-map** (the attributed `[erased …]` tombstones
  ride the copy — E records at the destination; a columnar destination
  refuses, it persists no tombstones). `push` refuses subject-keyed sources
  (`CXER1144` — custody does not ride the wire verbs; the stream-4/9 joint
  surface).

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

- **Primary key = the self-describing tagged address**
  `<multiformats-name>:<lowercase hex>` (`sha2-256:` default — I1 stream 19,
  ONE registry; bare hex is rejected, `CXER0130`) over strict canonical
  bytes ([`core/canonical.md §§1.2, 4`](../core/canonical.md)).
- **Cross-axis portability** — same hash across every substrate/model/encoding.
- **Free dedup / free integrity** — storing twice writes once; `get-doc` rehashes
  after decode.
- **No latest pointers in the content store** — all docs immutable; "latest of X"
  is the alias/branch layer (§6.2, §6.3).
- **The `.cxpack` entry hash slot is self-describing** (I1 crypto-agility
  §4): the formerly-reserved entry u16 carries the multicodec code of the
  algorithm naming the 32-byte `doc_hash` (`sha2-256` = `0x0012`); readers
  FAIL CLOSED on any code they do not implement. All 1.0 algorithms are
  32-byte; a non-32-byte digest requires a pack format v3.
- **Journal payload docs** (I1 row 11): a journal entry's event payload is
  stored as its OWN content-addressed doc (the entry carries only the
  address — [`journal.md §2.2`](journal.md)); such docs are roots in their
  own right for compaction/GC purposes, and deleting one is the lawful-
  erasure primitive — the owning chain still verifies.

## §12. Query semantics

`query` evaluates a CXPath across the corpus and returns the flat
provenance-bearing relation (§6.2: one `[result doc= source= …]` tuple per
match); `source` is the same scan returning the matched payloads only.
With a **quoted planar comprehension** (§6.2, ruling L99) `query` returns
the comprehension's own relation instead — membership-gated, sandboxed,
authorize-before-execute; `explain-query` is its no-execution
introspection twin (plan address + slice set + rewrite report).

**Path anchoring is XPath-correct from the DOCUMENT node** (ruled 2026-08-10,
#768): `/x` selects the **root element** when it is named `x`; `//x` is
descendant-or-self — the root **included** — so a per-entity document (the
root IS the entity, e.g. an `[order …]` doc) is queryable by name with no
wrapping convention; a bare relative step ≡ the absolute child step. Multi-
segment paths walk stepwise (`/a/b` = `b` children of a root named `a`;
`//a/b` = `b` children of `a` elements at any depth).

Both the row-materializing executor and the columnar column-projection
executor **MUST emit the identical relation** — shape and content never
depend on the backend or on whether a pushdown ran (ruling L97; the
transparency contract, pinned by the #711 shape-parity fixtures). On a
**service** mount the query pushes down to the server
(`CXER`-on-unsupported, never a lying empty result). On a **columnar** store
a descendant-form column projection (`//field`, `//parent/child`) lowers to
a column-only scan **exactly when provably exact** (the occurs-only-
top-level + column-exactness preconditions — the columnar backend spec's Q6);
everything else materializes rows. The naive embedded scan is O(N corpus),
fanned out across a backend-aware worker pool; `iter-docs` keeps memory
bounded. For high-frequency / large-corpus queries use `cx-stdlib/ft` or an
indexed backend.

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
| `CXER1117` | `E_STORE_COMPUTATION_RECORD_INVALID` | `set-alias` into `computation/<addr>` where `<addr>` is not an address / holds no record / the record is mis-shaped / the `fn.code` claim does not recompute / the record does not rehash to `<addr>` (§6.2, stream 5) |
| `CXER1118` | `E_STORE_COMPUTATION_NOT_PURE` | `set-alias` into `computation/<addr>` where `fn.source` is unresolvable, not a single `[?def]`, not declared `pure`, or checker-refused — the cache is pure-only (§6.2, stream 5) |
| `CXER1119` | `E_STORE_COMPUTATION_RESULT_NOT_CACHEABLE` | `set-alias` into `computation/<addr>` whose target is an `[err]` of the never-cached class (`CXER0270–0279` band + `CXER0153`) (§6.2, stream 5) |
| `CXER1120` | `E_STORE_INTEGRITY_MISMATCH` | decoded bytes don't hash to the requested key |
| `CXER1121` | `E_STORE_NOT_FOUND` | `get`/`modify`/`delete`/`set-alias` on a missing key |
| `CXER1130` | `E_STORE_CLOSED` | any operation on a closed Store |
| `CXER1131` | `E_STORE_AUTH_FAILED` | backend rejects credentials |
| `CXER1132` | `E_STORE_RATE_LIMIT` | backend signals rate limiting (retryable) |
| `CXER1140` | `E_STORE_HANDLE_RACE` | concurrent access to one shared Store handle |
| `CXER1141` | `E_STORE_ROTATION_UNSUPPORTED` | `rotate-kek` on a plaintext store or a substrate that cannot seal (§9.1) |
| `CXER1142` | `E_STORE_ROTATION_FAILED` | rotation aborted fail-closed — unresolvable key-id or an envelope unwrapping under neither key (§9.1) |
| `CXER1143` | `E_STORE_OPEN_CONFLICT` | a WRITABLE `open` refused because the root is already open writable elsewhere (§5). **In-process:** with **different at-rest options** — close the live handle first or match its open options (same options → a second handle over the same live store, the #628 same-root sharing rule). **Cross-process:** any second writable open of a local root, whatever its options — the refusal names the holding process and the recovery path (close that handle / end that process, or open read-only). Read-only opens are exempt in both cases. Shipped and test-pinned before this row existed; registered 2026-08-05 (audit C5); cross-process arm added 2026-08-26 (#1005). |
| `CXER1144` | `E_STORE_SUBJECT_UNSUPPORTED` | a subject-bearing put (`subject=`, §9.2) on a store that cannot honor the crypto-shred contract — plaintext at rest, a remote/wire handle, or no subject-key custody — fail-closed, never a plaintext fallback (stream 20, ruling L183). Also raised by the whole-store transfer verbs when custody or erasure attribution cannot ride the copy (§9.2): clone/migrate to a destination that cannot seal (or, for migrate, a columnar destination that persists no tombstones), and push of a subject-keyed source |
| `CXER1145` | `E_STORE_SHREDDED` | a doc read whose whole-doc object is sealed under an ABSENT subject key AND covered by a journaled erase record (§9.2, audit M29) — the typed lawful-erasure finding, naming the shred-request; the same read WITHOUT a covering record stays the fail-closed unavailable/integrity error (never reported as lawful erasure; stream 20, ruling L181/L187) |

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
- **Opaque documents (F1')** — put-blob/get-blob byte-exact round-trip incl.
  CX code with string-literal bodies; dedup by raw-hash; verify-on-read;
  legacy code-record refusal at load.
- **Integrity / read-only / closed / handle-race** — `CXER1120` / `1110` / `1130` /
  `1140`.
- **Aliases** — round-trip, persistence across reopen, absence channel, alias does
  not own content.
- **Migration** — cross-axis lossless (every doc ID preserved; aliases copied).
- **Query relation (L97)** — flat provenance tuples (`[result doc= source= …]`,
  one per match; a multi-match document yields multiple tuples); columnar/row
  shape parity (the #711 transparency probe); `source` payloads ≡ the `query`
  tuples' children; planar generator fixtures over `[$store:source]`
  (`code.md` §7.8); document-node anchoring (#768) — per-entity roots matched
  by `//x` and `/x`, multi-segment stepwise walks, the root-anchored/
  descendant distinction pinned.
- **Quoted planar queries (L99)** — the quoted-comprehension happy path (the
  ruled M5 revenue example through the live verb); the corpus membership
  negatives AT THIS CONSUMER (ambient generator / impure predicate /
  `[?eval]` body → `CXER0120`); the authz-slice permit and deny lanes
  (`CXER4700` carrying the `[deny]`); the eval-capability deny lane
  (`CXER0271`); non-literal source path + unbound handle refusals;
  `explain-query` (plan address ≡ `cx:plan-address`, slices, rewrites);
  wire parity over the two listeners (XSP + gRPC) incl. the wire
  membership deny.
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
| `read` (file/local) | `get-doc`, `get-doc-text`, `get-blob`, `exists`, `iter-docs`, `list-docs`, `get-alias`, `list-aliases`, `query`, `source`, `explain-query`, `status`, `log`, `diff` |
| `eval` | `query` with a QUOTED planar comprehension (§6.2 L99 — quoted code is dynamic execution; the shipped `[?eval]` sandbox's own gate). `explain-query` does not execute and does not need it. |
| `write` (file/local) | `put-doc`, `put-doc-text`, `put-doc-stream`, `put-blob`, `delete-doc`, `modify-doc`, `set-alias`, `delete-alias`, `migrate`, `clone`, `push`, `pull`, `fetch`, `gc`, `prune`, `branch`, `branch-force` |
| `net` (remote / service) | all of the above when the Store targets a remote backend |

## §16. Cross-references

- [`spec/misc/bindings.md`](../misc/bindings.md) — Layer-1 API (`parse`, `bytes`, `hash`, `modify`).
- [`spec/core/cxdm.md`](../core/cxdm.md) — content-addressing hash policy.
- [`spec/core/canonical.md`](../core/canonical.md) — canonical form (hash preimage).
- [`spec/core/code.md`](../core/code.md) — computation identity (the pure relation behind [$cx:computation-id]); absence channel.
- [`spec/core/ast-bin.md`](../core/ast-bin.md) · [`spec/core/data-bin.md`](../core/data-bin.md) — binary + columnar (CXCol) wire encodings.
- [`spec/core/abi.md`](../core/abi.md) — Layer-1 capability bits.
- [`spec/misc/cxstore-remote-protocol.md`](../misc/cxstore-remote-protocol.md) — CSRP wire spec (RETIRED — historical; the live service wire is §6.4 the XSP store profile + [`cxstore-grpc.md`](../misc/cxstore-grpc.md)).
- [`spec/misc/parity-matrix.md`](../misc/parity-matrix.md) — Tier-1 binding parity.
