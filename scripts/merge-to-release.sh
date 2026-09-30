#!/bin/sh
# scripts/merge-to-release.sh BRANCH "MERGE MESSAGE" — land a verified branch on
# release/0.18 WITHOUT touching the main checkout's working tree.
#
# Why: the post-merge runner runs `make test` in the main checkout (cx-private). A
# `git merge` performed there rewrites tracked files under a RUNNING gate, so
# the gate grades a mixed tree — measured 2026-09-09: the 16:06Z gate began at
# 2a0597d52 and stamped cx_commit=7aab1dd75 after an impl-branch merge landed
# mid-run. The main checkout is moved only by the gate loop, between gates
# (`git pull --ff-only` before each gate). Every other landing goes through
# here: a throwaway DETACHED worktree at origin/release/0.18, merge-tree gated,
# `--no-ff`, pushed as HEAD:release/0.18, worktree removed. Nothing shared is
# written; a conflict leaves nothing behind.
#
#   scripts/merge-to-release.sh impl/cx-A-1234 "merge(1234): … (RULED: 1234-a)"
# Exit 0 pushed (prints PUSHED=<sha>); 4 merge-tree conflict; 3 push refused
# (someone landed first — re-run, the merge is recomputed); 64 usage.
set -u
[ $# -eq 2 ] || { echo "usage: $0 BRANCH \"MESSAGE\"" >&2; exit 64; }
B=$1; MSG=$2
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
git -C "$ROOT" fetch -q origin release/0.18 "$B" 2>/dev/null || git -C "$ROOT" fetch -q origin release/0.18
git -C "$ROOT" rev-parse --verify -q "$B" >/dev/null || B="origin/$B"
T=$(mktemp -d "${TMPDIR:-/tmp}/cx-merge.XXXXXX")
cleanup() { git -C "$ROOT" worktree remove --force "$T/wt" >/dev/null 2>&1; rm -rf "$T"; }
trap cleanup EXIT
git -C "$ROOT" worktree add -q --detach "$T/wt" origin/release/0.18 || { echo "MERGE-EXIT=70 (worktree)"; exit 70; }
if ! git -C "$T/wt" merge-tree --write-tree origin/release/0.18 "$B" >/dev/null 2>&1; then
	echo "MERGE-TREE=conflict ($B vs $(git -C "$ROOT" rev-parse --short origin/release/0.18))"; echo "MERGE-EXIT=4"; exit 4
fi
git -C "$T/wt" merge --no-ff --no-edit -m "$MSG" "$B" >/dev/null 2>&1 || { echo "MERGE-EXIT=1"; exit 1; }
if git -C "$T/wt" push -q origin HEAD:release/0.18 2>/dev/null; then
	echo "PUSHED=$(git -C "$T/wt" rev-parse --short HEAD)"; echo "MERGE-EXIT=0"; exit 0
fi
echo "PUSH-EXIT=1 (release/0.18 moved — re-run)"; echo "MERGE-EXIT=3"; exit 3
