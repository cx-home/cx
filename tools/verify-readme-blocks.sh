#!/usr/bin/env bash
# tools/verify-readme-blocks.sh — README.md's runnable code blocks
# must actually run. Wraps verify-doc-blocks.sh for the root README.
#
# F6 from docs/EVALUATION_EXPERIENCE.md.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/verify-doc-blocks.sh" "$ROOT/README.md"
