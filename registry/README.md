# Internal package registry — stage 1 (git-repo-as-registry)

This directory is a **complete CX package registry** per the distribution spec
(`spec/03-approved/xap/xap_feature_distribution_market.md` §4.1): a store layout in
a git repository. There is no service and none is needed at this stage —
consumers reach it as `file://` (clone/vendor); integrity is the Tier-1 hash +
publisher-DID signature of each package, never the transport or the repo host.

```
registry/
  store/        # a file:// CX store (subtree object model): package content
                # trees, sealed manifests, and version aliases
  keys/         # publisher identities (DID documents + INTERNAL signing seeds)
  publish.cx    # the publish program (pure CX — composes cx-xap pkg-* + store)
```

## Publishing (by PR — §4.1)

Publishing is a **reviewed commit**: run the publish program, commit the new
store objects + alias, open a PR. The review gate is the publish gate.

```sh
CX_PKG_DIR=packages/gtin CX_PKG_NAME=gtin CX_PKG_VERSION=0.1.0 \
  make registry-publish
```

The program seals the package directory (every file EXCEPT `package.cxd`,
which is the manifest that sits *beside* the hashed content tree — the git
tag-object pattern), signs the manifest over the Tier-1 hash with the
publisher key, publishes the `name@version → manifest-hash` alias, and
re-verifies the published artifact end-to-end before reporting. Released
aliases are immutable (`CXER4887`): a new artifact is a new version.

Everything published is **reproducible**: canonical content trees, a
deterministic manifest, and RFC-8032 ed25519 (deterministic signatures) mean
re-publishing identical sources yields byte-identical store objects.

## Consuming

```
[?let [= $reg [$store:open "file:///…/registry/store"]]
 [$xap:pkg-install $my-xap $reg "gtin@0.1.0"]]
```

Full §3 verification (hash + signature + attestation policy) runs on every
install, offline, with no service — vendoring is `store:clone`. The same
artifacts, hashes, and signatures carry unchanged into the later growth stages
(served CSRP registry, market) per §4.2.

## Serving (stage 2 — the same store, re-hosted)

```sh
make registry-serve      # CSRP daemon on 127.0.0.1:8460 over registry/store
```

Consumers open `cx-store+http://127.0.0.1:8460/registry/`. Discovery over the
wire is `[$xap:pkg-catalog]` (server-side CXPath query pushdown — no alias
verbs are needed on the wire); fetch/verify/install run by hash, the full §3
chain, bit-identical to the stage-1 artifacts (§4.2: a re-host, never a
re-package). The wire round trip is gated by
`vcx/tests/xap_registry_serve_real_test.v`.

## Keys (`keys/`)

The internal publisher identity is a committed `did:key` **including its
signing seed**: inside this repo's trust domain, repo permission IS publish
permission (§4.1 access control), so seed custody equals repo custody.
Graduating a publisher to market-grade custody means moving the seed out of
the repo (HSM/secret store) — the DID, and therefore every existing
signature, is unchanged (did:key: the key is the identity).
