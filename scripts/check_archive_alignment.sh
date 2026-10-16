#!/bin/sh
# check_archive_alignment.sh ARCHIVE… — every object member of each ar archive
# must begin on an 8-byte boundary (#1370).
#
# Apple's ld refuses a 64-bit Mach-O archive member that does not:
#   ld: 64-bit mach-o member 'cx_re2_shim.o' not 8-byte aligned in 'libcx_re2_shim.a'
# The GNU-style `ar` that is first on PATH inside devbox pads members to 2
# bytes, so an archive it writes links under the devbox linker and fails
# under the Apple toolchain three steps later, in code the author never
# touched. This walks the `ar` headers and fails HERE, loudly, naming the
# member. Exit 0 = every archive aligned; 1 = a member is not (or a file is
# not an archive); 2 = usage.
#
# Layout walked: 8-byte magic `!<arch>\n`, then per member a 60-byte header
# (name 16 · mtime 12 · uid 6 · gid 6 · mode 8 · size 10 · fmag 2). A BSD
# long name `#1/N` puts the N-byte name FIRST in the data, so the object
# begins N bytes after the header; GNU `/N` names live in the `//` table and
# the object begins at the header's end. The symbol table (`__.SYMDEF…`,
# `/`) is data, not Mach-O, and is skipped. Members are padded to 2 bytes.
set -u
[ $# -ge 1 ] || { echo "usage: $0 ARCHIVE..." >&2; exit 2; }
rc=0
for a in "$@"; do
  if [ ! -f "$a" ]; then echo "check_archive_alignment: $a: no such file"; rc=1; continue; fi
  if [ "$(head -c 7 "$a")" != '!<arch>' ]; then echo "check_archive_alignment: $a: not an ar archive"; rc=1; continue; fi
  size=$(wc -c < "$a" | tr -d ' ')
  off=8
  members=0
  while [ "$off" -lt "$size" ]; do
    hdr=$(dd if="$a" bs=1 skip="$off" count=60 2>/dev/null)
    name=$(printf '%s' "$hdr" | cut -c1-16 | sed 's/ *$//')
    msize=$(printf '%s' "$hdr" | cut -c49-58 | tr -d ' ')
    case "$msize" in ''|*[!0-9]*) echo "check_archive_alignment: $a: malformed member header at offset $off"; rc=1; break;; esac
    data=$((off + 60))
    obj=$data
    real=$name
    case "$name" in
      '#1/'*) n=${name#\#1/}; obj=$((data + n)); real=$(dd if="$a" bs=1 skip="$data" count="$n" 2>/dev/null | tr -d '\000') ;;
    esac
    case "$real" in
      __.SYMDEF*|/|//|'') ;;
      *) members=$((members + 1))
         if [ $((obj % 8)) -ne 0 ]; then
           echo "check_archive_alignment: $a: member '$real' begins at byte $obj (mod 8 = $((obj % 8))) — Apple's ld refuses the archive"
           rc=1
         fi ;;
    esac
    off=$((data + msize))
    [ $((off % 2)) -eq 1 ] && off=$((off + 1))
  done
  [ "$members" -eq 0 ] && { echo "check_archive_alignment: $a: no object members"; rc=1; }
done
exit $rc
