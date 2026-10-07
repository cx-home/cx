#!/bin/sh
# scripts/docs_tree_lock.sh <command…> — one writer of docs/guide/ and site/ per checkout.
#
# `make guide` removes and rewrites docs/guide/, and site_assemble.cx removes and
# copies site/. guide-render-gate, site-check, site-index-check (docs-check's
# prerequisite) and the site/guide renders each render the tree and then READ it.
# Inside one `make -j` the shared prerequisite runs once; the post-merge flow runs
# each step as its own make on its own runner (#1817), so on 73a02bbd4 three renders
# overlapped: guide-render-gate (19:13:12Z) found docs/guide/index.html gone after
# its own render exited 0 — site-check's render (19:13:17Z) had removed it.
#
# The lock itself is scripts/tree_lock.sh's (vcx/target/docs-tree.lock: a mkdir
# lock, stale on a dead pid, re-entrant, bounded wait exit 75).
[ $# -gt 0 ] || { echo "docs-tree-lock: usage: $0 <command…>" >&2; exit 64; }
TREE_LOCK_TIMEOUT=${DOCS_TREE_LOCK_TIMEOUT:-${TREE_LOCK_TIMEOUT:-3600}} \
  exec sh "$(dirname "$0")/tree_lock.sh" docs-tree "docs/guide/ and site/" "$@"
