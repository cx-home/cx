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
- **present and not at `sha`** — a refusal (`checkout-drift`).

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
| `checkout-drift` | `deps/<repo>/` is not at `sha` |
| `missing-checkout` | under `--check`, `deps/<repo>/` is not there at all |

`fetch-failed` and `checkout-drift` are the two the union step exists for. #1589's "Risks"
records why they cannot be warnings: the previous stale-copy arrangement in this project rotted
within weeks because nothing failed when it did.

### 3.2 Verification without fetching

`--check` performs §3's comparison and none of its fetching: it refuses a malformed document, a
missing `deps/<repo>/`, and a checkout that is not at its pinned `sha`, and it touches no
network. It is what a build step runs when the fetch has already happened.

### 3.3 The V search path

`--vpath` prints the V `-path` value for the pin set and nothing else: `@vlib|@vmodules` followed
by `deps/<repo>` for every row carrying a `v-fork`. RS-7's "read by the V build via `-path`" is a
sentence about the build, so the transport answers it rather than leaving each repository's
Makefile to re-derive it from the same document.

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
build. The other half is the CX half, and it is the half that cannot be
answered by pointing the build somewhere else.

`cx` embeds every bundled CX module's bytes into the binary: one
`$embed_file('../../stdlib/<name>.cx')` per module in `vcx/code/stdlib_bundle.v`,
and the same shape for the `x/` estate. **An embed path is a compile-time
literal.** V has no variable form of it, and the three CLI profiles and the two
libraries all read the same literals. So when a module's source moves to its
own repository, the bytes have to BE at that path when V reads it. Putting them
there is composition, and `scripts/bundle_compose.cx` is the program that does
it (`make bundle-compose`; `make deps-sync` runs it after the fetch).

### 6.1 The three states and the four refusals

For each module `registry/modules.cxd` gives a bundled `source=` for, two facts
decide where its bytes come from: whether `registry/repos.cxd` allocates that
path to a repository `deps.cxd` pins, and whether the path is still a tracked
file of this repository.

| pinned | tracked | `deps/<owner>/<path>` | verdict |
|---|---|---|---|
| no | yes | — | `own` — the front door's own source, embedded from `<path>` |
| yes | no | present | `pinned` — composed into `<path>` from `deps/<owner>/<path>` |
| yes | yes | — | `migrating` — the pin is taken and the source has not left yet |
| yes | no | absent | **refused**: `missing-pinned-source` |
| no | no | — | **refused**: `missing-source` |

Two more refusals complete the set: `unowned`, a source no `[path]` rule
claims, and `self-pinned`, the front door pinning itself.

**`migrating` is a state and not a refusal** because an extraction is a copy and
then a delete, in two repositories, and between them the source exists in both.
The front door pins the new repository from the moment it releases — RS-7's
migration lane — while the delete lands with the extraction. Refusing the window
would mean no pin could be taken before the delete; ignoring it would mean
nobody could tell a finished extraction from an unfinished one. So it is named,
counted and printed on every run.

**`missing-pinned-source` is a refusal and not a fallback** because the failure
this table exists to prevent is a build that quietly produces a *smaller* binary
than the pins describe. A fallback to "embed whatever is at `<path>`" is that
failure. There is none: the composition refuses, and if it is bypassed the
absent path fails V's `$embed_file` by name. Loud twice, silent never.

### 6.2 Two refusals that need a tree

`--check` writes nothing and adds the two refusals a document cannot state:

| Kind | What it is |
|---|---|
| `composed-drift` | a composed `<path>` whose bytes are not the bytes of `deps/<owner>/<path>` — a private fork of another repository's source, the class RS-7 built the transport to avoid |
| `not-ignored` | a composed `<path>` git does not ignore. Once a module's source belongs to another repository its path here is a BUILD OUTPUT; the extraction commit that deletes the tracked source adds its path to `.gitignore`, and this refusal is what says so when it does not |

### 6.3 Conformance

The table, its three states and its four document-level refusals are pinned by
[`conformance/bundle_sources.cxd`](../../../conformance/bundle_sources.cxd),
graded by the `test-bundle-sources` step. `make deps-sync && make build-vcx`
therefore produces the same binary from a tree whose products live in `deps/`
as from a tree that still holds them, and no arrangement in between produces a
binary that is quietly missing a module.
