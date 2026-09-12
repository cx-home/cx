#!/bin/sh
# campaign-heartbeat.sh [interval-seconds] — one compact line per interval about
# the autonomous campaign, forever. Meant to run as a VISIBLE background task in
# the owner's session: if the lines stop, the watcher itself is dead; if the
# lines keep coming but say the same thing for 25+ minutes, the run is hung.
#
#   20:31  run ALIVE 2m | notes 1m "make test-changed #1190" | make test-changed 4m @cx-1190-solitary-note | gate FINISHED | #1354 3 comments
#
# Every field degrades to a plain word when its source is absent. Read-only.
#
# Besides stdout, each tick APPENDS the line to vcx/target/campaign.heartbeat and
# rewrites vcx/target/campaign-status.html — a self-refreshing page (open it in
# the app's Browser pane via file://) that shows the last 40 lines newest-first
# and turns red if the writer itself has stopped. No model, no tokens: it is a
# detached shell loop. `cat vcx/target/campaign-heartbeat.pid` names it.
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 1
every=${1:-60}
write_html() {
  # The page is static; its script polls campaign.heartbeat over HTTP every 15 s
  # (same origin, cache-busted) and rebuilds itself — meta refresh is not
  # honoured by the app's Browser pane, and a data:/file: snapshot never
  # refreshes at all. Age comes from the file's Last-Modified header.
  {
    printf '<!doctype html><meta charset="utf-8"><title>cx campaign</title>\n'
    printf '<style>body{margin:0;padding:14px 18px;background:#111;color:#ddd;font:13px/1.5 ui-monospace,Menlo,monospace}'
    printf 'h1{font-size:15px;margin:0 0 10px;font-weight:600}.ok{color:#8fd18f}.bad{color:#ff7b72}.dead{color:#ff7b72;font-weight:700}'
    printf '.age{color:#888;font-weight:400}pre{margin:12px 0 0;color:#999;white-space:pre-wrap}</style>\n'
    printf '<h1 id="h" class="ok">loading… <span class="age" id="age"></span></h1>\n'
    printf '<div id="dead" class="dead" hidden>WATCHER STOPPED — no heartbeat for over %s s. The campaign run may still be alive; the feed is not.</div>\n' "$((every*3))"
    printf '<pre id="log"></pre>\n'
    printf '<script>var E=%s*1000,W=0;function esc(t){return t.replace(/&/g,"&amp;").replace(/</g,"&lt;")}\n' "$every"
    printf 'async function poll(){try{var r=await fetch("campaign.heartbeat?t="+Date.now(),{cache:"no-store"});var t=await r.text();var lm=r.headers.get("Last-Modified");W=lm?Date.parse(lm):Date.now();'
    printf 'var ls=t.trim().split("\\n");var cur=ls[ls.length-1]||"";var h=document.getElementById("h");h.innerHTML=esc(cur)+" <span class=age id=age></span>";h.className=/HUNG\\?|STALE/.test(cur)?"bad":"ok";'
    printf 'document.getElementById("log").textContent=ls.slice(-40).reverse().join("\\n")}catch(e){}tick()}\n'
    printf 'function tick(){var a=Date.now()-W;var el=document.getElementById("age");if(el)el.textContent=W?"written "+Math.round(a/1000)+"s ago":"";document.getElementById("dead").hidden=!W||a<3*E}\n'
    printf 'poll();setInterval(poll,15000);setInterval(tick,1000)</script>\n'
  } > vcx/target/campaign-status.html.tmp && mv vcx/target/campaign-status.html.tmp vcx/target/campaign-status.html
}
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
echo $$ > vcx/target/campaign-heartbeat.pid
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
  slotd=${CX_RUNNER:-${CX_BUILD_SLOT:-"$HOME/git-repos/cx/.build-slot"}}
  if [ -d "$slotd" ]; then
    st=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$(cat "$slotd/since" 2>/dev/null)" +%s 2>/dev/null || echo "$now")
    slot="slot $(cut -c1-30 "$slotd/cmd" 2>/dev/null) $(( (now - st) / 60 ))m @$(basename "$(cat "$slotd/cwd" 2>/dev/null)")"
  else slot="slot free"; fi
  gate=$(sh scripts/gate-status.sh 2>/dev/null | awk '/^state/ {print $2; exit}'); [ -z "$gate" ] && gate="-"
  n=$(gh issue view 1354 -R cx-home/cx-private --json comments --jq '.comments|length' 2>/dev/null || echo '?')
  line=$(printf '%s  %s | %s | %s | %s | gate %s | #1354 %s comments' "$(date +%H:%M)" "$run" "$note" "$proc" "$slot" "$gate" "$n")
  echo "$line"
  echo "$line" >> vcx/target/campaign.heartbeat
  write_html "$line" "$now"
  sleep "$every"
done
