#!/bin/sh
# scripts/deps_bootstrap.sh — populate deps/ with NO cx (#1670).
#
# WHY THIS IS SHELL AND NOT CX (AGENTS.md rule 6): it exists ONLY to answer
# the question `make build-vcx` cannot answer on its own on a fresh clone --
# `deps-present` refuses because vcx/code/stdlib_bundle.v `$embed_file()`s
# stdlib sources straight out of `deps/<repo>/` at COMPILE time (every
# profile, not just the platform default: the embeds are unconditional
# consts), so there is no leaner build to bootstrap with -- and
# `make deps-sync` is itself a CX program (scripts/deps_sync.cx) that needs a
# cx to run. A tree with no deps/ and no cx cannot produce either by itself.
# `scripts/deps_cx_selftest.cx`/the Makefile's own DEPS_CX_FOUND already
# search a fresh worktree's SIBLINGS for a cx to borrow; the one case that
# borrows nothing is a fresh CI clone, which is exactly `.github/workflows/
# site.yml`'s case (#1670: "a bootstrap that does not depend on a release").
#
# WHAT IT DOES. Reads deps.cxd with the same grep this Makefile already uses
# (`deps-present`, `CX_DEPS_V_REPOS`) rather than a second parser, and does
# ONLY the "absent" case of scripts/deps_sync.cx's own documented state
# table (its header comment): a shallow fetch of each pinned repository at
# its pinned sha into deps/<repo>/. A fresh clone's deps/ is always absent
# (deps/ is gitignored) so no other case applies here — this is a bootstrap,
# not a second sync implementation; `make deps-sync` still runs afterwards,
# with the cx this unblocks building, and is what VERIFIES every pin (its
# bundle_check.cx half) and handles drift on every later run.
#
# The URL rule matches scripts/deps_pins.cx's `url-for` exactly: a row's own
# `url=` wins, otherwise this repository's own origin with its final path
# segment replaced by the pinned repo's name (spec §2.2) — so no row here
# needs one and nothing is inferred from a name beyond that substitution.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEPS_CXD="${1:-deps.cxd}"
DEPS_DIR="${2:-deps}"

origin="$(git remote get-url origin)"
bare="${origin%.git}"

mkdir -p "$DEPS_DIR"

# One [dep ...] row per line-ish extraction: repo=, sha=, and an optional
# url= — same three fields deps-present already greps out of this file.
grep -oE '\[dep [^]]*\]' "$DEPS_CXD" | while IFS= read -r row; do
  repo="$(printf '%s\n' "$row" | grep -oE 'repo=[^ ]+' | sed 's/^repo=//')"
  sha="$(printf '%s\n' "$row" | grep -oE 'sha=[0-9a-f]+' | sed 's/^sha=//')"
  own_url="$(printf '%s\n' "$row" | grep -oE "url='[^']*'|url=[^ ]+" | sed "s/^url=//; s/^'//; s/'\$//" || true)"

  [ -n "$repo" ] && [ -n "$sha" ] || { echo "deps_bootstrap: row with no repo= or sha= — $row" >&2; exit 2; }

  dest="$DEPS_DIR/$repo"
  if [ -d "$dest/.git" ]; then
    have="$(git -C "$dest" rev-parse HEAD 2>/dev/null || echo '')"
    if [ "$have" = "$sha" ]; then
      echo "deps_bootstrap: $repo already at $sha — skip"
      continue
    fi
  fi

  if [ -n "$own_url" ]; then
    url="$own_url"
  else
    url="$(printf '%s' "$bare" | sed -E "s#[^/]+\$#$repo#").git"
  fi

  echo "deps_bootstrap: fetching $repo @ $sha from $url"
  rm -rf "$dest"
  git init -q "$dest"
  git -C "$dest" fetch --depth 1 -q "$url" "$sha"
  git -C "$dest" checkout -q FETCH_HEAD
done

echo "deps_bootstrap: done — $DEPS_DIR/ seeded with no cx required."
