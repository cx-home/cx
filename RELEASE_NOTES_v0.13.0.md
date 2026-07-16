# CX v0.13.0 — Release Notes

**Date:** 2026-07-16
**Tag:** `v0.13.0`

The **platform + consumption** release. The cx store becomes a production
platform component — a content-addressed multimodel engine under a
single-node service tier with authN/authZ, observability, and deploy
artifacts — and XAP features become a full **distribution unit**: sealed,
signed, published, discovered, verified, installed, and entitled. Around
that core, this release makes CX radically easier to *consume* in all four
modes: as a **data format** (a lossless conversion contract that finally
keeps its promise), as **code** (a CLI whose help, flags, and errors cannot
drift from the implementation), as a **platform** (the store + XAP guides,
verified live), and in **operations** (a real process-model story, a hosted
installer, and a public mirror that builds from a clean clone).

Two breaking changes (store scheme cutover and strictly-scalar attributes)
— see **Migration**.

## Headlines

- **XAP feature distribution** — the compose→package→publish→verify→install→
  entitle staircase (`[$xap:compose]`, `pkg-*`, entitlement VCs,
  git-repo-as-registry), plus the deployment host: a XAP server is data
  plus adapters, zero bespoke server code.
- **cx store, production tier** — `cx store-serve` (CSRP + gRPC, static/
  JWT/DID/OIDC authN, RBAC, tenants, Prometheus/OTel, systemd/Docker
  artifacts), encryption-at-rest with KEK rotation, two-tier identity, and
  fifteen hardening waves over the serve plane.
- **The lossless contract, kept** — `--lossless` JSON and YAML now recover
  element documents **byte-identically** via the `$tag` envelope: structure,
  attributes, mixed-content order, metadata, and `[table]` payloads all
  survive. XML kept its exact lane; every lane now carries table images
  (`cx:cols`/`cx:row`, AST-JSON `cols`/`rows`, Markdown pipe tables,
  ast-bin v9 records).
- **A CLI that tells the truth** — one registry drives dispatch and help
  (20+ verbs, uniform `--help`); unknown flags are hard errors instead of
  silent no-ops; `cx select` ships; `cx FILE --data=INPUT` binds `$doc`;
  `cx demo` demonstrates a working product.
- **Consumable out of the box** — `curl -sSL https://cxhome.org/install | sh`
  (SHA-256-verified), editors that work on first open (Neovim fallback +
  tree-sitter repaired, VS Code extension actually activates), a 20-section
  guide whose every example executes against the live binary under a gate,
  and a public mirror that builds and tests from a fresh
  `git clone --recursive`.

## Changed (breaking)

- **Store scheme cutover** — `cxpack://` / `cxobj://` retired: `file://` is
  the universal subtree model, `document+<substrate>://` the document model,
  `?encoding=` selects framing; contradictions with the on-disk marker are a
  hard `CXER1120`.
- **Attributes are strictly scalar** (code.md §6.4.1 wins) — a non-scalar
  attr value raises `CXER0100` with a child-element hint; validate.md's
  vocabulary moves to child elements (`[enum v …]`, `[schema …]`,
  `[extends $Base]`), old attr spellings fail loud with migration hints
  (`CXER1603`).
- **CXPath predicate sublanguage retired** (from the 0.13 line's early
  waves; #110) — predicates are homoiconic prefix CX (`//user[= $_@id 991]`);
  `cx fmt --migrate-predicates -w` migrates fail-closed.

## Fail-loud hardening

The release closes a long tail of silent-wrong-answer classes: unknown CLI
flags, empty-attr writes, unbound-`$doc` queries, out-of-range ascriptions
(including the 8-byte-hex i64 clamp), element-valued attributes, comment
placement moving hashes, `[table[…]]` heads mis-parsing under attributes or
nesting, YAML block-sequence import losing rows, and `cx diff`'s table
blind spot. Where behavior is deliberately typed-lossy (Markdown tables,
CSV), the spec now says so and the flag surface rejects what it can't honor.

## Migration

- **Store URIs**: replace `cxpack://`/`cxobj://` per the table in store.md;
  stores reopen self-describing.
- **Collection-valued attributes**: move the value to a child element —
  `[e sel=$nodes]` → `[e [sel $nodes]]`; validate schemas: `enum=[a b]` →
  `[enum a b]`, `schema=[…]` → nested `[schema …]`, `extends=$B` →
  `[extends $B]`.
- **Predicates** (if arriving from 0.12): run
  `cx fmt --migrate-predicates -w` across your tree.
- **Hex under `::decimal`/`::bigint`**: write base-10.

## Toolchain & public build

The vendored V fork pins its complete bootstrap inputs (vc, tcc,
macports-legacy) — clean clones build offline-deterministically; public
`make test` runs under a real C compiler; the mirror's CI calls only
public targets. Release artifacts: `cx-darwin-arm64.tar.gz` (CLI +
`libcx.dylib` + `cx.h`) with `SHA256SUMS.txt`.

Full detail: `CHANGELOG.md` §0.13.0.
