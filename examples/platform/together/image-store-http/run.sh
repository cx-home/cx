#!/bin/sh
# An upload's image derivatives, content-addressed in the store and served
# for a CDN (cx-home/cx-core-code#112). media.cx makes a 64-wide WebP avatar
# and an 8x8 JPEG thumbnail of an inline PNG with cx-stdlib/image, puts each
# in the store with $store:put-blob (the key is the SHA-256 of its bytes) and
# serves GET /media/<hash>.<ext> through [?http-service]'s [immutable-content
# prefix='/media' store=$store] (cx-platform-net#22, http.md §14.5): no handler.
#
# What the transcript asserts, and why each line is a property rather than a
# value: the keys and byte counts are the encoders' output, so they are not
# pinned here — the RELATION is. The ETag is the hash in the URL; the hash is the SHA-256
# of the bytes the server sent (so the URL names the content); every
# derivative carries Cache-Control: public, max-age=31536000, immutable (so a
# CDN may keep it for a year without revalidating); If-None-Match on the ETag
# is 304 with no body; an unknown key is 404.
set -u
CX="${CX:-cx}"
PORT="${CX_MEDIA_PORT:-8796}"
LOG="$(mktemp "${TMPDIR:-/tmp}/image-store-http.XXXXXX")"
BASE="http://127.0.0.1:$PORT"

"$CX" --allow-net="127.0.0.1:$PORT" media.cx --port "$PORT" > "$LOG" 2>&1 &
SRV=$!
trap 'kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; rm -f "$LOG"' EXIT

WAIT="$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)/tools/scenario_wait_ready.sh"
sh "$WAIT" "$BASE/health" "$SRV" "${CX_SCENARIO_READY_SECONDS:-120}" "$LOG" || exit 1

say() { printf '%s\n' "${1-}"; }
header() { tr -d '\r' | sed -n "s/^$1: //Ip" | head -1; }

say '$ curl /index                                 # what the upload handler hands back'
URLS=$(curl -s -m 5 "$BASE/index")
say "derivatives=$(printf '%s\n' "$URLS" | grep -c '^/media/[0-9a-f]\{64\}\.\(webp\|jpg\)$')"

for U in $URLS; do
  FILE=${U#/media/}; HASH=${FILE%.*}
  HEAD=$(curl -s -m 5 -D - -o "$LOG.body" "$BASE$U")
  say
  say "\$ curl /media/<hash>.${FILE##*.}"
  say "status=$(printf '%s\n' "$HEAD" | head -1 | tr -d '\r' | cut -d' ' -f2)"
  say "content-type=$(printf '%s\n' "$HEAD" | header Content-Type)"
  say "cache-control=$(printf '%s\n' "$HEAD" | header Cache-Control)"
  ETAG=$(printf '%s\n' "$HEAD" | header ETag)
  say "etag-is-the-hash=$([ "$ETAG" = "\"$HASH\"" ] && echo yes || echo no)"
  SUM=$(shasum -a 256 "$LOG.body" | cut -d' ' -f1)
  say "hash-is-sha256-of-the-body=$([ "$SUM" = "$HASH" ] && echo yes || echo no)"
  say '$ curl ... -H "If-None-Match: <etag>"   # a cache revalidating'
  say "status=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -H "If-None-Match: $ETAG" "$BASE$U") bytes=$(curl -s -m 5 -H "If-None-Match: $ETAG" "$BASE$U" | wc -c | tr -d ' ')"
  rm -f "$LOG.body"
done

say
say '$ curl /media/<a hash not stored>.webp'
say "status=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$BASE/media/0000000000000000000000000000000000000000000000000000000000000000.webp")"
