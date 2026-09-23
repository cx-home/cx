# Repository dependency pins — `deps.cxd` and `deps sync`

**Status:** New (owner, 2026-09-21; RULED: RS-7).

RS-7 rules the pin transport for the multi-repo shape:

> Each repository pins the releases it builds on (`deps.cxd`: repository, SHA or tag, module;
> the V-fork SHA for V repositories) and bumps them in its own PR. […] Pin transport is a CX
> lock document plus a CX-written `cx deps sync` (shallow fetch at SHA into an ignored
> `deps/`, read by the V build via `-path`); not submodules, not vpm.

This page is the row format of that document and the behaviour of that program. It adds no
policy: every sentence below either spells a shape RS-7 names or states a refusal that RS-7's
"consumers pull, producers never push" and #1591's "the union step FAILS on a stale pin, never
warns" already require. It supersedes nothing; the edit map on
[`ledger/rulings_2026_09_21_repo_split_1589.md`](../../../ledger/rulings_2026_09_21_repo_split_1589.md)
lists the sentences that move, and none of them is here.

The V submodule's own pin is a different subject and stays where it is —
[`v-dependency-management.md`](v-dependency-management.md) §4. `deps.cxd` carries the V-fork
SHA only as a **declaration** of the fork a V repository was built against, so that two
repositories compiled into one binary can be shown to have agreed.

---

## 1 — The document

A repository that builds on another repository's release carries one `deps.cxd` at its root.
It is an ordinary CX data document — the data grammar reads it, `cx canonical` is its identity,
and nothing about it needs a new lexer, parser or codec.

```
[deps
  [dep repo=<repo> sha=<sha> module=<module> tag=<tag>? url=<url>? v-fork=<sha>?]
  …
]
```

The root element is `[deps]`. Its children are `[dep]` rows and an optional `[doc]` block, and
nothing else. A repository that pins nothing carries `[deps]` with no rows; that is a legitimate
state, not a missing file, and it is the state of a repository before the first extraction lands.

**One row per pinned repository, not per module.** A consumer that uses four modules of one
repository pins that repository once and lists the four in `module`; a pin is a commit of a
repository, and two rows for one repository would be two answers to which commit that is. §3's
duplicate-repository refusal is that sentence, enforced.

## 2 — The row

| Key | Required | What it is |
|---|---|---|
| `repo` | yes | the pinned repository's name, as `registry/repos.cxd` spells it |
| `sha` | yes | the full 40-character lowercase hexadecimal commit the pin resolves to |
| `module` | yes | the module namespaces this repository provides to the consumer, whitespace-separated (`cx-stdlib/<name>`, `cx-platform/<name>`, or the repository's own name where it provides no module namespace) |
| `tag` | no | the release tag the `sha` is, when the pin was taken from a release |
| `url` | no | the fetch URL, when it is not the default for `repo` |
| `v-fork` | no | the full 40-character V-fork commit the pinned repository was built against — carried by a V repository's row, absent from a package repository's |

No other key is permitted on a `[dep]`. An unknown key is a refusal and not a warning, for the
reason RS-7 gives the whole transport: a pin document that quietly ignores what it does not
understand is a pin document that can be wrong without anyone finding out.

### 2.1 Why `sha` is required when RS-7 says "SHA or tag"

RS-7 names both columns and this format carries both, but only one of them can be the pin. A
tag is a name a producer can move; a commit is not. So `sha` is the pin — the thing `deps sync`
fetches and the thing a stale-pin refusal compares against — and `tag` is the release name the
`sha` was taken from, recorded so a reader and a bump PR can say which release a row is. A row
with a `tag` and no `sha` is refused.

### 2.2 The fetch URL

When a row carries no `url`, the URL is the consumer's own `origin` with the final path segment
replaced by `repo`. A repository whose dependency lives somewhere else says so per row. Nothing
is inferred from a repository name beyond that substitution.

## 3 — `deps sync`

The program reads `deps.cxd`, refuses a document that does not conform to §1–§2, and then, for
each row, leaves `deps/<repo>/` a checkout of exactly `sha`:

- **absent** — a fresh shallow fetch: an empty repository at `deps/<repo>/`, `url` as its
  remote, `git fetch --depth 1 <url> <sha>`, then a checkout of the fetched commit.
- **present and at `sha`** — nothing is done.
- **present and not at `sha`** — when the checkout has no local changes, the same shallow
  fetch into it and a checkout of the fetched commit, so a pin moved in the consumer's own
  change is an ordinary sync (RS-7); when it has local changes, a refusal (`checkout-drift`),
  because the sync never discards an edit.

`deps/` is ignored by the consumer's `.gitignore` and is read by the V build through `-path`.
It is a build input, never a tracked one, and nothing in it is edited in place.

### 3.1 The refusals

Every one of these exits non-zero and names the row. None of them is a warning:

| Kind | What it is |
|---|---|
| `unknown-key` | a `[dep]` carries a key §2 does not list |
| `unknown-child` | `[deps]` carries a child that is not a `[dep]` |
| `missing-sha` | a row has no `sha` |
| `missing-repo` / `missing-module` | a row has no `repo` / no `module` |
| `malformed-sha` / `malformed-v-fork` | a value is not 40 lowercase hexadecimal characters |
| `duplicate-repo` | two rows pin the same repository |
| `fetch-failed` | the remote does not have `sha` — the pin is stale |
| `checkout-drift` | `deps/<repo>/` is not at `sha` and has local changes — `sync` moves a clean one to the pin and refuses this one; under `--check`, which moves nothing, any checkout not at `sha` |
| `missing-checkout` | under `--check`, `deps/<repo>/` is not there at all |

`fetch-failed` and `checkout-drift` are the two the union step exists for. #1589's "Risks"
records why they cannot be warnings: the previous stale-copy arrangement in this project rotted
within weeks because nothing failed when it did.

### 3.2 Verification without fetching

`--check` performs §3's comparison and none of its fetching: it refuses a malformed document, a
missing `deps/<repo>/`, and a checkout that is not at its pinned `sha`, and it touches no
network. It is what a build step runs when the fetch has already happened.

### 3.3 The V search path

`--vpath` prints the V `-path` value for the pin set and nothing else: `deps/<repo>/vcx` for every
row carrying a `v-fork`, in document order, followed by `@vmodules|@vlib`. RS-7's "read by the V
build via `-path`" is a sentence about the build, so the transport answers it rather than leaving
each repository's Makefile to re-derive it from the same document.

The root is the checkout's `vcx/` directory because a V repository is cut from this tree with its
paths kept, so its modules sit at `vcx/<module>/` there as they did here, and V resolves
`import <module>` as `<root>/<module>`. The pinned roots come first because V takes the first
directory on the path named like the import, and the V standard library carries module names a
pinned repository also uses (`cli`): with `@vlib` ahead, the library would be compiled in place
of the pinned module.

A build that must run with no `cx` present — a clean rebuild of the front door from its source
and its fetched `deps/` — may read the same value from the document itself; it then refuses to
build when a `cx` is present and `--vpath` answers differently, so the document has one reading.

### 3.4 Where the program lives

`cx` carries `scripts/deps_sync.cx` and `scripts/deps_pins.cx`. A component repository cannot
reach them through its own pins — it would need the sync to fetch the sync — so the repository
template copies both in at creation, under `tooling/`, and the bump job updates them with the
pins. That copy is the stale-copy class #1589's Risks names, taken deliberately and with its
cost stated: it is the price of the transport being a program rather than a verb of the binary,
and a verb removes it. Nothing else in a component repository is a copy.

## 4 — The union

The front-door repository's `make union` synchronises its pins and then runs its own test
union, in that order and in one step. A stale pin therefore fails the union before a single
test compiles, which is the property #1591 states and the reason the step is not two commands a
person is trusted to run in order.

## 5 — Conformance

The wire form, its canonical bytes and every refusal in §3.1 are pinned by
[`conformance/deps_pins.cxd`](../../../conformance/deps_pins.cxd), graded by the
`test-deps-pins` step. A refusal this page names and that corpus does not carry is a defect in
the corpus, not a discretionary omission.

## 6 — The bundled CX sources

RS-7's *"read by the V build via `-path`"* answers half of what a pin buys a
build. The other half is the bundled CX sources, and it cannot be answered by a
search path.

`cx` embeds every bundled CX module's bytes into the binary: one `$embed_file`
per module in `vcx/code/stdlib_bundle.v`. **An embed path is a compile-time
literal**, and the profile builds and the libraries all read the same literals.
So a module whose repository has left this tree is embedded **from the pinned
checkout itself**: its `registry/modules.cxd` row carries `repo=<repo>` and a
`source=` under `deps/<repo>/`, and its embed literal names that same path.
Nothing is copied into this repository's own tree — there is no composed file
that could drift from the pinned bytes, and none a `git add` could commit back.

### 6.1 The two states and the refusals

For each module `registry/modules.cxd` gives a bundled `source=` for, the row's
`repo=`, the pins, and the tree decide one verdict:

| `repo=` | pinned | tracked here | on disk | verdict |
|---|---|---|---|---|
| none | — | yes | — | `own` — the front door's own source |
| none | — | no | — | **refused**: `missing-source` |
| `cx` | — | — | — | **refused**: `self-pinned` |
| `<r>` | no | — | — | **refused**: `unpinned` — nothing fetches it |
| `<r>` | yes | yes | — | **refused**: `tracked-pin` — another repository's source committed here |
| `<r>` | yes | no | yes | `pinned` — embedded from `deps/<r>/` |
| `<r>` | yes | no | no | **refused**: `missing-pinned-source` |

Two rows naming one module are refused as `duplicate-module`.

**`missing-pinned-source` is a refusal and not a fallback** because the failure
this table exists to prevent is a build that quietly produces a *smaller*
binary than the pins describe — a `deps/<repo>` never fetched, or fetched at a
sha where the source is not where the row says. It is refused three times:
`make deps-sync` and `make deps-check` apply the table after the fetch or the
at-pin check; `make deps-present` states the build's precondition before V
starts, needing no cx; and a build that bypasses both fails V's `$embed_file`
on the absent path.

### 6.2 Conformance

The table and every refusal in it are pinned by
[`conformance/bundle_sources.cxd`](../../../conformance/bundle_sources.cxd),
graded by the `test-bundle-sources` step.
