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
#
# CX_DEPS_TOKEN (SITE-1, ledger/rulings_2026_09_26_owner_decisions_l35_l39.md,
# RULED: SITE-1, D83a, RS-33): the pinned component repositories are private,
# so a fresh clone on a runner with no SSH identity (cx-home/cx's Site
# workflow) cannot fetch them. When CX_DEPS_TOKEN is set and non-empty, every
# git invocation below that fetches or clones a pin is given
# `-c url."https://x-access-token:${CX_DEPS_TOKEN}@github.com/".insteadOf=https://github.com/`
# so github.com fetches are transparently rewritten to carry the token — the
# URL RULE above (spec §2.2) is unchanged, only the transport gains
# credentials for the one host that needs them. The token itself is never
# placed in a variable this script prints, echoes, or otherwise puts on a log
# line: `$auth_cfg` is passed straight as `git` arguments and never captured,
# `set -x` stays off, and every message this script emits below names the
# repo/sha/url as before — never the credentialed form. Unset (dev2, SSH),
# behaviour is byte-identical to before this change.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "${1:-}" = "--selftest" ]; then
  exec sh "$ROOT/scripts/deps_bootstrap_selftest.sh"
fi

DEPS_CXD="${1:-deps.cxd}"
DEPS_DIR="${2:-deps}"

origin="$(git remote get-url origin)"
bare="${origin%.git}"

# auth_cfg: the extra `git -c ...` argument, built once, used verbatim by every
# fetch/init below and by nothing that logs. Empty when CX_DEPS_TOKEN is unset
# or blank, so an unset token is a no-op — byte-identical to before this change.
auth_cfg=""
if [ -n "${CX_DEPS_TOKEN:-}" ]; then
  auth_cfg="url.https://x-access-token:${CX_DEPS_TOKEN}@github.com/.insteadOf=https://github.com/"
fi

mkdir -p "$DEPS_DIR"

# One [dep ...] row per line-ish extraction: repo=, sha=, and an optional
# url= — same three fields deps-present already greps out of this file.
grep -oE '\[dep [^]]*\]' "$DEPS_CXD" | while IFS= read -r row; do
  repo="$(printf '%s\n' "$row" | grep -oE 'repo=[^ ]+' | sed 's/^repo=//')"
  sha="$(printf '%s\n' "$row" | grep -oE 'sha=[0-9a-f]+' | sed 's/^sha=//')"
  # FIX (found while wiring CX_DEPS_TOKEN's own fixture, #1670 lineage, this
  # branch): the unquoted alternative was `url=[^ ]+`, which is POSIX
  # leftmost-LONGEST, not first-alternative-wins — for a quoted `url='…'`
  # immediately followed by the row's closing `]` (no space), it swallowed
  # the closing quote and the `]` into the match. Excluding `'` from the
  # unquoted alternative's char class removes the overlap: only the quoted
  # alternative can start on a quote.
  own_url="$(printf '%s\n' "$row" | grep -oE "url='[^']*'|url=[^ ']+" | sed "s/^url=//; s/^'//; s/'\$//" || true)"

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
  if [ -n "$auth_cfg" ]; then
    # A transport error here can otherwise name the insteadOf-rewritten URL
    # (credentials included) — the rule is that the token appears in NO log
    # line, so with auth_cfg set, git's own stderr is captured and never
    # relayed; a failure is reported as a plain repo/sha refusal instead.
    fetch_err="$DEPS_DIR/.bootstrap_fetch_err.$$"
    set +e
    git -c "$auth_cfg" init -q "$dest" 2>"$fetch_err" \
      && git -c "$auth_cfg" -C "$dest" fetch --depth 1 -q "$url" "$sha" 2>>"$fetch_err"
    fetch_status=$?
    set -e
    rm -f "$fetch_err"
    if [ "$fetch_status" -ne 0 ]; then
      echo "deps_bootstrap: fetch refused for $repo @ $sha" >&2
      exit "$fetch_status"
    fi
  else
    # No token: byte-identical to before this change — git's own stderr
    # flows straight through, uncaptured.
    git init -q "$dest"
    git -C "$dest" fetch --depth 1 -q "$url" "$sha"
  fi
  git -C "$dest" checkout -q FETCH_HEAD
done

echo "deps_bootstrap: done — $DEPS_DIR/ seeded with no cx required."
