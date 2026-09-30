#!/bin/sh
# scripts/wave-worktree.sh NAME [BRANCH] — a worktree that can BUILD immediately.
#
# The point is pipelining: a wave's exit gate owns the main checkout for 35-120
# minutes, and the next wave should start NOW, not after it. A worktree has its
# own tree and its own vcx/target, so a build there cannot touch the artifacts
# the gate is testing — only CPU is shared.
#
# A bare `git worktree add` CANNOT build. Three prerequisites live outside
# git's view, and each one costs a failed build to discover (measured, in that
# order, 2026-09-07):
#
#   third_party/v              the pinned V compiler (submodule, uninitialised)
#   third_party/re2/obj/*.a    the re2 static lib (a BUILD ARTIFACT)
#   vcx/target/libcx_*_shim.a  the shims (build artifacts)
#   scripts/playground-gate/node_modules   the playground gate's dev deps
#
# They are LINKED from the main checkout, never copied: all three are inputs
# the wave does not modify, and copying a 6 MB static lib per wave is waste.
#
# TRAP this script exists to stop repeating: `ln -sfn SRC DIR` when DIR already
# exists as a directory creates DIR/SRC instead of replacing DIR — which is how
# I turned a worktree's `third_party` into a symlink and lost its ability to run
# `make`. Every link below removes the target first.
set -eu
NAME=${1:?usage: wave-worktree.sh NAME [BRANCH]}
BRANCH=${2:-impl/$NAME}
MAIN=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
W=$(dirname "$MAIN")/$NAME

[ -e "$W" ] && { echo "wave-worktree: $W already exists"; exit 1; }
git -C "$MAIN" worktree add -q -b "$BRANCH" "$W" HEAD

link() { rm -rf "$2"; mkdir -p "$(dirname "$2")"; ln -s "$1" "$2"; }
link "$MAIN/third_party/v" "$W/third_party/v"
link "$MAIN/third_party/re2" "$W/third_party/re2"
for a in libcx_re2_shim.a libcx_arrow_shim.a; do
	[ -f "$MAIN/vcx/target/$a" ] && link "$MAIN/vcx/target/$a" "$W/vcx/target/$a"
done

# The FOURTH prerequisite, found the way the first three were — by a failed
# step. `make test-playground-mermaid` in a fresh worktree builds the whole
# wasm bundle (minutes), reports `[wasm-fresh] OK`, and THEN refuses:
#
#   [playground-mermaid] SETUP FAILURE: the gate's dev dependencies are not installed.
#
# because `scripts/playground-gate/node_modules` is in `.git/info/exclude` and
# so exists only where someone ran `npm install` — the main checkout. Measured
# 2026-09-10 (worker A, #1373-b): the row cost a full wasm build before failing,
# which is the expensive way to discover a missing directory.
#
# It is LINKED, like the other three: it is an input no wave modifies, it is
# ~40 MB, and linking keeps every worktree on the same pinned dependency tree
# the main checkout resolved. Unlike third_party/v and third_party/re2 this
# path is UNTRACKED, so it needs no `--skip-worktree` guard — there is no
# gitlink for a `git add -A` to type-change.
[ -d "$MAIN/scripts/playground-gate/node_modules" ] && \
	link "$MAIN/scripts/playground-gate/node_modules" "$W/scripts/playground-gate/node_modules"

# The linked paths must never be committable. `git add -A` in a worktree
# captures whatever the tree contains, and these symlinks are part of it —
# committing them replaces the real submodule checkouts with self-referential
# links the moment the branch merges. That happened: a3fb74ef3 / ffc0a6072 took
# out third_party/v and third_party/re2 in the main checkout and broke every
# `v` on the box.
#
# `.git/info/exclude` CANNOT prevent it — that only governs UNTRACKED paths,
# and these are tracked gitlinks, so replacing one with a symlink is a TYPE
# CHANGE which `git add -A` stages as `T` regardless. Measured: with the paths
# excluded, `git add -A` still staged both. `--skip-worktree` is the mechanism
# that actually works: git stops looking at the working-tree version of the
# path, so no `add` can pick the symlink up.
git -C "$W" update-index --skip-worktree third_party/v third_party/re2 2>/dev/null || true

printf 'wave worktree ready: %s  (branch %s)\n' "$W" "$BRANCH"
printf 'build check:  cd %s && devbox run -- sh -c "cd vcx && v -cc cc -gc e test cx/atom_test.v"\n' "$W"
