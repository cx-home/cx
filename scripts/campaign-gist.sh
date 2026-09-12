#!/bin/sh
# scripts/campaign-gist.sh [GIST_ID] — render the v0.18.0 campaign status as
# markdown and publish it to a private GitHub gist (owner request 2026-09-09:
# status lives in a gist, not a local page). Without GIST_ID prints to stdout.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 1
git fetch -q origin release/0.18 2>/dev/null
tip=$(git rev-parse --short origin/release/0.18)
open=$(gh issue list --repo cx-home/cx-private --state open --limit 1000 --json number --jq length 2>/dev/null)
gated=$(grep -o 'cx_commit=[0-9a-f]*' vcx/target/gate.log 2>/dev/null | tail -1 | cut -d= -f2)
gexit=$(grep -E '^(RUN|GATE)-EXIT=' vcx/target/gate.log 2>/dev/null | tail -1)
gstate=$(sh scripts/gate-status.sh 2>/dev/null | awk '/^state/{print $2}')
slot=$(cat "$HOME/git-repos/cx/.build-slot/cmd" 2>/dev/null | grep -oE 'lane_[A-Za-z0-9_]+|gate\.sh' | head -1)
since=$(cat "$HOME/git-repos/cx/.build-slot/since" 2>/dev/null)
{
echo "# cx v0.18.0 close-out — status"
echo
echo "updated $(date -u +%FT%TZ) · tip \`$tip\` · **open issues: ${open:-?}**"
echo
echo "## post-merge run"
echo "last finished run: \`${gated:-none}\` ${gexit:-} · state: ${gstate:-?}"
echo "post-merge runner (last 5):"
echo '```'
tail -5 vcx/target/gate-loop.log 2>/dev/null || echo "(no gate-loop.log)"
echo '```'
echo
echo "## runners"
echo "default holder: ${slot:-idle} ${since:+(since $since)}"
for q in "$HOME/git-repos/cx/.build-slot.queue" "$HOME/git-repos/cx/.build-slot-impl.queue"; do
  n=$(ls "$q" 2>/dev/null | wc -l | tr -d ' ')
  echo "- $(basename "$q"): $n waiting"
  for t in $(ls "$q" 2>/dev/null | sort -t. -k1,1n -k2,2n); do p=${t##*.}; c=$(ps -o command= -p "$p" 2>/dev/null | grep -oE 'lane_[A-Za-z0-9_]+|gate\.sh|merge --no-ff [^ ]+' | head -1); [ -n "$c" ] && echo "    - $c ($(( ($(date +%s) - ${t%%.*}) / 60 ))m)"; done
done
echo
echo "## landed since the last passed run (b2c4d4f14), awaiting a pass"
git log --merges --format='- `%h` %s' b2c4d4f14..origin/release/0.18 | cut -c1-110
echo
echo "## open branches (ahead of tip)"
for b in $(git for-each-ref --format='%(refname:short)' refs/heads/impl/); do git merge-base --is-ancestor "$b" origin/release/0.18 2>/dev/null || echo "- $b \`$(git rev-parse --short "$b")\` +$(git rev-list --count origin/release/0.18.."$b")"; done
echo
echo "## worker (last 6 notes)"
echo '```'
tail -6 vcx/target/campaign.notes 2>/dev/null || sh scripts/campaign-status.sh 2>/dev/null | sed -n '3,9p'
echo '```'
} > vcx/target/campaign-status.md
if [ $# -ge 1 ]; then gh gist edit "$1" -f campaign-status.md vcx/target/campaign-status.md >/dev/null && echo "gist updated $(date -u +%T)"; else cat vcx/target/campaign-status.md; fi
