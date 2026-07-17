# Setting up a registry — a git repo is a registry

Distribution introduces **no archive format, no transport, no trust primitive
of its own**: a package is a sealed store subtree, a registry is a CX store,
a version is an alias, trust is Tier-1 hash + publisher-DID signature.
Governing spec: the feature distribution & market spec
(`spec/03-approved/xap/xap_feature_distribution_market.md`).

## Stage 1: a store-layout git repo

A git repo containing a CX store **is a complete registry** — consumers reach
it as `file://` (clone/vendor) or `https://` (raw). Git adds exactly what an
internal registry wants: publish-by-PR (moving an alias is a reviewed commit),
history as audit, repo permissions as publish permissions. The live instance
is `xap-marine/registry/`:

```
registry/
  keys/xap-marine.cxd    # publisher identity (did:key + signing seed;
                         # committed by design at stage 1 — repo permission = publish permission)
  store/                 # the file:// CX store: sealed packages, manifests, alias index
  publish.cx  pin.cx  rehost.cx
```

Sign from day one, even internally: it costs nothing and makes every later
stage a re-host, never a re-package.

## The publish pipeline

`author → validate → seal → sign → publish`. The whole publisher side, on any
store (verified end-to-end):

```cx
[?lib 'cx-xap' :as xap]
[?lib 'cx-stdlib/store' :as store]
[?lib 'cx-stdlib/crypto' :as crypto]
[?lib 'cx-stdlib/did' :as did]
[?let [= $reg [$store:open "mem://"]]                       # any store: file://, s3://, …
 [= $kp [$crypto:ed25519-keypair]]                    # needs --allow-random
 [= $pub [$did:key-create $kp@public]]
 [= $tree [$xap:pkg-tree ([entry path='geo-utils.cx' '[?def id scope=public ($x) $x]'])]]
 [= $draft [?element "package"
                      [?attr "name" "geo-utils"] [?attr "version" "0.1.0"] [?attr "kind" "library"]
                  [?element "publisher" [?attr "did" $pub]]
                  [?element "exports" [?element "def" [?attr "name" "geo-utils/id"]]]]]
 [= $sealed [$xap:pkg-seal $reg $tree $draft]]
 [= $signed [$xap:pkg-sign [$store:get-doc $reg $sealed@manifest] $kp@private]]
 [= $mh [$store:put-doc $reg $signed]]
 [= $pubr [$xap:pkg-publish $reg "geo-utils" "0.1.0" $mh]]
 [= $v [$xap:pkg-verify $reg "geo-utils@0.1.0"]]
 ($pubr@alias, $v@status)]
# → ('geo-utils@0.1.0', 'ok')
```

Step by step:

- **`pkg-tree`** seals the directory as one canonical content document —
  entries sorted by path, byte-stable, so its store hash *is* the package's
  Tier-1 hash. Traversal/duplicate paths are rejected (`CXER4880`).
- **`pkg-seal`** validates the manifest draft kind-aware (a `needs` block on
  a library is rejected — libraries carry no authority), stores the tree,
  writes its hash into the manifest, stores the manifest **beside** the tree
  (the git tag-object pattern).
- **`pkg-sign`** fills the detached ed25519 signature over the Tier-1 hash.
  Signing is possession; verification is trust — the key↔DID binding is
  checked at verify time.
- **`pkg-publish`** sets the `name@version → manifest-hash` alias. **Released
  aliases are immutable**: re-pointing raises `CXER4887`; re-publishing the
  identical hash is idempotent.
- **`pkg-verify`** re-runs the full fail-closed chain (re-hash → signature →
  required VCs); nothing stages on failure.

## Manifests — hand-written vs projected

The draft `package.cxd` carries only what cannot be derived: `kind`,
`publisher`, `requires` (code plane), `compatibility`, `license-terms`, and
the `exports` contract surface. The grammar summary, the `needs` consent set,
and `uses` dependencies are **projected from the feature spec at publish and
re-verified at install** — never restated by hand. The working projection
program is `xap-marine/registry/publish.cx`; drive it via the make targets:

```sh
CX_FEATURE=own-ship make registry-publish     # one feature
make registry-publish-all                     # every feature in xap.cxd
CX_PKG_DIR=packages/marine-common CX_PKG_NAME=marine-common \
  CX_PKG_VERSION=0.2.0 make registry-publish-lib
make registry-rehost-nmea0183                 # carry a package verbatim from another registry
```

Re-hosting never re-packages: hashes and signatures are unchanged, and a
package keeps its original publisher's signature — trust is per-package,
never per-registry (`registry/rehost.cx`).

## Keys

Stage-1 keys are an ed25519 seed in `registry/keys/<publisher>.cxd`; the DID
is `did:key` (offline-verifiable, no resolver infrastructure). Key rotation
and compromise recovery are DID-document rotation per the did module spec,
with attestations re-anchoring trust for pre-rotation artifacts (the
retirement section of the distribution spec).

## Growth path

| Stage | What | Status |
|---|---|---|
| 0 monorepo | in-repo dirs, path refs | the floor |
| 1 internal git registry | sealed+signed packages, publish by PR | **implemented and live** (xap-marine + the cx-private `registry/`) |
| 2 served registry | the same store served over CSRP (`cx store-serve`); consumers switch the URI scheme | **implemented** (engine-tested wire re-host; `[$xap:pkg-catalog]` works locally and served) |
| 3 market | the market XAP wraps the registry | see [marketplace](marketplace.md) — model specified; entitlement machinery shipped |

Artifacts, hashes, and signatures never change across stages; graduating is
re-hosting and wrapping, never re-packaging.
