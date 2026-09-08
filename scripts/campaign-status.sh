#!/bin/sh
# campaign-status.sh — what the autonomous v0.18.0 campaign is doing right now.
#
#   sh scripts/campaign-status.sh          # one snapshot
#   watch -n 30 sh scripts/campaign-status.sh
#
# Sections: run liveness (lock age), the run's own last status lines, every
# live build/test process under any Claude session with its age (a HUNG flag
# past 25 min on anything that is not a gate), the gate, dirty campaign
# worktrees, and the last #1354 comment. Read-only.
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1
now=$(date +%s)
line() { printf -- '-- %s ' "$1"; printf '%*s\n' $((56 - ${#1})) '' | tr ' ' '-'; }

line "run"
if [ -f vcx/target/campaign.lock ]; then
  age=$(( (now - $(stat -f %m vcx/target/campaign.lock)) / 60 ))
  if [ "$age" -lt 45 ]; then echo "lock     ALIVE   refreshed ${age}m ago (stale at 45m)"; else echo "lock     STALE   ${age}m old — no run, or the run died (usage cap?)"; fi
else
  echo "lock     none    no run in progress"
fi
if [ -f vcx/target/campaign.status ]; then
  last=$(tail -1 vcx/target/campaign.status | cut -c1-20)
  lt=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$last" +%s 2>/dev/null || echo "$now")
  echo "status   last note $(( (now - lt) / 60 ))m ago; last 5:"
  tail -5 vcx/target/campaign.status | sed 's/^/           /' | cut -c1-140
else
  echo "status   (no campaign.status yet — the run has not called scripts/campaign-note.sh)"
fi

line "executing under Claude sessions (repo processes only)"
hits=$(mktemp)
for cl in $(ps -eo pid,command | awk '/claude-code\/[0-9.]+\/claude\.app\/Contents\/MacOS\/claude/ && !/awk/ {print $1}'); do
  for sh in $(ps -eo pid,ppid | awk -v p="$cl" '$2==p {print $1}'); do
    ps -eo pid,ppid,etime,command | awk -v s="$sh" '$2==s' | while read -r pid ppid et cmd; do
      case "$cmd" in
        /bin/zsh*|/bin/sh*|/bin/bash*|*"-c "*) continue;;   # the tool's wrapper shell, not the work
      esac
      case "$cmd" in
        *devbox*|*make*|*third_party/v/v*|*vcx/target/cx*|*gate.sh*|*"gh "*|*"git "*|*"v test"*|*"v -"*)
          cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
          case "$cwd" in "$HOME"/git-repos/cx/*) ;; *) continue;; esac
          mins=$(echo "$et" | awk -F: '{ if (NF==3) print $1*60+$2; else if (NF==2) print $1; else print 0 }' | sed 's/-.*//')
          flag=""; case "$cmd" in *gate.sh*|*"make test"*) ;; *) [ "${mins:-0}" -ge 25 ] && flag="  <-- HUNG? ${mins}m";; esac
          printf '  %-8s %-9s %s\n         cwd %s%s\n' "$pid" "$et" "$(echo "$cmd" | cut -c1-90)" "${cwd#$HOME/git-repos/cx/}" "$flag"
          echo 1 >> "$hits";;
      esac
    done
  done
done
[ -s "$hits" ] || echo "  (nothing — the run is thinking, between tool calls, or not running)"
rm -f "$hits"

line "gate"
sh scripts/gate-status.sh 2>/dev/null | sed -n '2,4p' | sed 's/^/  /'

line "campaign worktrees (dirty = uncommitted work)"
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
  [ "$wt" = "$root" ] && continue
  n=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=$(git -C "$wt" rev-list --count release/0.18..HEAD 2>/dev/null || echo '?')
  [ "$n" -gt 0 ] || [ "$ahead" != 0 ] && printf '  %-42s dirty=%-3s ahead=%s\n' "${wt#$HOME/git-repos/cx/}" "$n" "$ahead"
done

line "#1354 last comment"
gh issue view 1354 -R cx-home/cx-private --json comments --jq '.comments[-1] | "  \(.createdAt)\n  \(.body[0:300])"' 2>/dev/null | cut -c1-140 || echo "  (gh unavailable)"
