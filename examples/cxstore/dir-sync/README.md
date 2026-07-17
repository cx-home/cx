# Managing a directory tree with cx store

Two small cx recipes that load a directory tree of `.cxd` data files into a
content-addressed cx store and write it back out — so a tree of documents gains
content addressing, dedup, version history, and name-based lookup, with no engine
changes and no new CLI surface (everything composes from existing verbs).

This is the "ingest a directory" answer for cx-private#128. It is deliberately a
**recipe, not a `cx store-sync` subcommand**: customization (which extensions,
the alias/naming scheme, the substrate, per-file transforms) is editing cx, not
adding flags.

## Pieces

- **`ingest.cx`** — walks `sample/` (`[$io:walk]`), and for every `.cxd` file
  `put-doc-text`s it (→ content hash) and `set-alias`es it under its relative
  path. Idempotent: re-running re-puts identical bytes to the same hash and
  rewrites the same alias.
- **`materialize.cx`** — the reverse: walks the store's aliases and writes each
  doc back out under `./restored/`, recreating the named tree.
- **`watch.cx`** — keeps the store **live**: after an initial ingest it blocks on a
  real OS filesystem watch (`[$io:watch]` → inotify on Linux, FSEvents on macOS,
  recursive — *not* polling) and re-ingests each file the instant it changes,
  drops the alias of a deleted file, and does a full rescan if the OS reports an
  `overflow` (dropped events). This is the continuous-sync answer for
  cx-private#128-B.
- **`sample/`** — a small nested tree of `.cxd` docs.

## Run

```sh
make run          # clean → ingest → materialize
# or individually:
make ingest       # load sample/ into cxpack://./out-store
make materialize  # write the store back out to ./restored
make watch        # keep the store synced to sample/ as it changes (Ctrl-C to stop)
make clean        # remove out-store/ and restored/
```

With `make watch` running, edit, add, or delete a file under `sample/` in another
shell and the store tracks it immediately — `watch-next` blocks until the OS
reports the change, so there is no polling interval and no missed window.

## What to notice

- **Name-based lookup:** after ingest, `[$store:get-doc $c [$store:get-alias $c "sample/notes/hello.cxd"]]`
  returns the original doc. Aliases are the human-path → content-hash map.
- **Content addressing + dedup:** identical docs collapse to one hash; re-ingest
  of an unchanged tree is a no-op.
- **Canonical round-trip:** materialized files are byte-*canonical*, not
  byte-identical to the input (`id="x"` → `id=x`, strings single-quoted) — the
  store holds the canonical form and re-emits it. Semantically identical.
- **Substrate-agnostic:** change one URL in the recipes to target a different
  backend — `cxpack://` (local packed, shown here), `file://` (local flat), or a
  remote daemon (`cx-store+http://` / `cx-store+grpc://`).

## Data and code

The recipe ingests **both** kinds, routing by extension:

- **`.cxd` data documents** → `put-doc-text` (content hash; subtree-deduped on the
  `cxpack://` object graph).
- **`.cx` code files** → `put-def` (Tier-2 **code identity** — alpha- and
  comment-insensitive, dependency-resolved-by-hash, so semantically-equal
  definitions store once). Code is held verbatim (it does not data-parse) and
  read back with `get-def`.

Each is aliased by its relative path, so `get-alias` → hash → `get-doc` (data) or
`get-def` (code) round-trips by name. Try it: after `make ingest`, resolve the
sample def with
`[$store:get-def $c [$store:get-alias $c "sample/code/greet.cx"]]`.
