#!/bin/sh
# campaign-heartbeat.sh [interval-seconds] — one compact line per interval about
# the autonomous campaign, forever. Meant to run as a VISIBLE background task in
# the owner's session: if the lines stop, the watcher itself is dead; if the
# lines keep coming but say the same thing for 25+ minutes, the run is hung.
#
#   20:31  run ALIVE 2m | notes 1m "make test-changed #1190" | make test-changed 4m @cx-1190-solitary-note | gate FINISHED | #1354 3 comments
#
# Every field degrades to a plain word when its source is absent. Read-only.
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 1
every=${1:-60}
longest_proc() {
  for cl in $(ps -eo pid,command | awk '/claude-code\/[0-9.]+\/claude\.app\/Contents\/MacOS\/claude/ && !/awk/ {print $1}'); do
    for sh in $(ps -eo pid,ppid | awk -v p="$cl" '$2==p {print $1}'); do
      ps -eo pid,ppid,etime,command | awk -v s="$sh" '$2==s' | while read -r pid ppid et cmd; do
        case "$cmd" in /bin/zsh*|/bin/sh*|/bin/bash*|*"-c "*) continue;; esac
        case "$cmd" in *devbox*|*make*|*third_party/v/v*|*vcx/target/cx*|*gate.sh*|*"gh "*|*"git "*) ;; *) continue;; esac
        cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
        case "$cwd" in "$HOME"/git-repos/cx/*) ;; *) continue;; esac
        mins=$(echo "$et" | sed 's/-.*//' | awk -F: '{ if (NF==3) print $1*60+$2; else if (NF==2) print $1; else print 0 }')
        short=$(echo "$cmd" | sed 's#.*devbox run -- ##; s#^/Users/[^ ]*/##' | cut -c1-40)
        echo "$mins|$short|${cwd#$HOME/git-repos/cx/}"
      done
    done
  done | sort -t'|' -k1,1nr | head -1 | awk -F'|' 'NF==3 { flag=""; if ($1>=25 && $2 !~ /gate.sh|make test$/) flag=" HUNG?"; printf "%s %dm @%s%s", $2, $1, $3, flag }'
}
while true; do
  now=$(date +%s)
  # run liveness from the age-based lock
  if [ -f vcx/target/campaign.lock ]; then
    age=$(( (now - $(stat -f %m vcx/target/campaign.lock)) / 60 ))
    [ "$age" -lt 45 ] && run="run ALIVE ${age}m" || run="run STALE ${age}m"
  else run="run none"; fi
  # the run's own last note
  if [ -f vcx/target/campaign.status ]; then
    lastl=$(tail -1 vcx/target/campaign.status)
    lt=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$(echo "$lastl" | cut -c1-20)" +%s 2>/dev/null || echo "$now")
    note="notes $(( (now - lt) / 60 ))m \"$(echo "$lastl" | cut -c23-70)\""
  else note="notes -"; fi
  # the longest-running repo process under any Claude session (the thing that would be hung)
  proc=$(longest_proc)
  [ -z "$proc" ] && proc="idle"
  gate=$(sh scripts/gate-status.sh 2>/dev/null | awk '/^state/ {print $2; exit}'); [ -z "$gate" ] && gate="-"
  n=$(gh issue view 1354 -R cx-home/cx-private --json comments --jq '.comments|length' 2>/dev/null || echo '?')
  printf '%s  %s | %s | %s | gate %s | #1354 %s comments\n' "$(date +%H:%M)" "$run" "$note" "$proc" "$gate" "$n"
  sleep "$every"
done
