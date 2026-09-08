#!/bin/sh
# campaign-note.sh "<what I am doing now>" — the autonomous campaign run calls
# this at every step. It appends a timestamped line to vcx/target/campaign.status
# and refreshes the age-based lock, so `scripts/campaign-status.sh` can show a
# human what the run is doing and how long since it last said anything.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$root/vcx/target"
printf '%s  %s\n' "$(date -u +%FT%TZ)" "$*" >> "$root/vcx/target/campaign.status"
date -u +%FT%TZ > "$root/vcx/target/campaign.lock"
