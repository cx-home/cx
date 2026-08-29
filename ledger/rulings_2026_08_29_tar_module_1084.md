# Rulings — cx-stdlib/tar archive codec (#1084)

2026-08-29, release/0.18. Campaign umbrella #1097, workstream A. Recorded
BEFORE the work. #1078's zip lane is the porting template throughout, so
these letters mostly say where tar DIFFERS from zip and why.

## T-1 — module shape (RULED: T-1 = a)

- (a) **New pure module `cx-stdlib/tar`** — an archive codec over the
  `bytes` scalar, zero I/O, exactly the Z-1 shape. TAKEN.
- (b) Fold tar into `cx-stdlib/zip` — rejected: different container, and
  a module named for one format that decodes another is a lie in the
  catalog.

## T-2 — surface, and what does NOT get a verb (RULED: T-2 = a)

- (a) **Four verbs**: `pack` / `unpack` / `entries` / `extract`, mirroring
  zip. TAKEN.
- No `comment` verb: tar has no archive comment. The zip surface is a
  template, not a quota.
- **No `tar.gz` verbs.** `tar.gz` is `[$bytes:gzip-compress]` composed
  with `[$tar:pack]`, and the reverse on the way in. A `pack-gz`
  convenience would add surface without adding capability — the Z-7
  reasoning that refused a compression-level knob, and the codec /
  transport split `bytes` and `io` already draw.

`entries` is cheaper here than in zip and for the opposite reason: tar has
no central directory, so listing means walking the 512-byte headers and
SKIPPING each payload by its declared size. Still one pass, still no
decompression, still no payload materialized.

## T-3 — what pack EMITS (RULED: T-3 = a)

- (a) **ustar when every field fits; pax extended headers ONLY for a
  field that cannot be represented otherwise.** TAKEN. Maximally portable
  by default, correct for the cases ustar cannot express (names over 100
  bytes, sizes over 8 GiB), and still a pure function of the input — the
  same "smallest faithful representation wins" shape as zip's
  store/fixed/dynamic choice.
- (b) Always pax — rejected: pax records in every archive make the common
  case bigger and less portable for no gain.
- (c) Always ustar, refusing long names — rejected: paths over 100 bytes
  are ordinary, so this would make the module useless for real archives
  while looking principled.
- (d) GNU format — rejected for EMIT: pax is the standard, GNU is the
  dialect. Read is a different question (T-4).

Determinism (§4-equivalent) requires pax records be emitted in a FIXED
order with fixed content, so equal input still gives byte-identical
output. That constraint is part of this ruling, not an implementation
detail.

## T-4 — what unpack ACCEPTS (RULED: T-4 = a)

- (a) **ustar, pax, and GNU long-name / long-link on READ.** TAKEN. GNU
  `L`/`K` entries are everywhere in the wild — it was GNU tar's default
  for years — so refusing them would refuse a large share of real
  archives while claiming to be a tar reader.
- Refused loudly (valid archives this codec declines): **sparse files**
  (GNU `S` and pax `GNU.sparse.*`), **multi-volume**, and character
  device / block device / FIFO entries.

**This is where #1100's rule applies** (`ledger/rulings_2026_08_29_release_portability_*`):
the malformed / unsupported split tracks WHOSE FAULT it is. A device
entry is a perfectly valid tar record that we decline — **unsupported**.
A header whose checksum does not verify, or a payload that runs past the
end of the buffer, is a broken file — **malformed**. Every refusal in the
implementation must be classified by that test, not by feel.

## T-5 — entry model (RULED: T-5 = a)

Maps, as in zip (the csv row precedent), with tar's own structure made
explicit rather than smuggled into the name:

| Key | Kind | Meaning |
|---|---|---|
| `name` | string | entry path |
| `data` | bytes | payload (empty for non-files) |
| `mtime-unix` | int | modification time |
| `mode` | int | the unix mode WORD, verbatim — the Z-8.2 lesson |
| `type` | atom | `:file` (default) / `:directory` / `:symlink` / `:hardlink` |
| `link-target` | string | required for `:symlink` / `:hardlink`, absent otherwise |

zip modelled a directory as "a name ending in `/` with empty data" because
that is all the zip container says. **tar has a typeflag, so tar says it
outright.** Copying zip's vagueness where the format is precise would be
porting a limitation.

`mode` carries the Z-8.2 ruling forward unchanged: it is the mode WORD,
stored verbatim, file-type bits included. tar's typeflag and the mode's
type bits are two statements of the same fact; `pack` writes what it is
given and does not synthesize either from the other.

## T-6 — determinism (RULED: T-6 = a)

`pack` is byte-stable. Entry order preserved, never re-sorted. Defaults
that make an unspecified field a constant rather than an environment
read: `mtime-unix` 0 (the Unix epoch — tar's own zero, not zip's DOS
epoch), uid/gid 0, uname/gname empty, `mode` absent means 0.

**End-of-archive is exactly two 512-byte zero blocks, with no padding to
a 10240-byte record boundary.** GNU tar pads by default; the padding is
not required by the format, every reader accepts its absence, and a
smaller deterministic artifact is worth more here than matching one
implementation's default.

## T-7 — the header checksum (RULED: T-7 = a)

`unpack` / `extract` / `entries` VERIFY the header checksum — it is the
only integrity check tar has, and it is the analogue of zip's CRC-32,
which #1078 verified rather than trusted.

**Both the signed and unsigned historical interpretations are accepted**
on read. That is not laxity: implementations genuinely differ on whether
the checksum bytes are summed as signed chars, and archives from both
exist. Emit uses the unsigned sum, which is what every modern tar writes.

## T-8 — name hygiene (RULED: T-8 = a)

Z-5 carried over unchanged: `pack` refuses empty, absolute, `..`-bearing,
backslash-bearing, and duplicate names. `unpack` / `entries` report names
as stored — the codec is pure, so no traversal can occur here, and the
zip-slip hazard belongs to the io-layer consumer that writes entries out.

## T-9 — error band (RULED: T-9 = a)

**`CXER5500–5599` allocated to `cx-stdlib/tar`.** Not 5400–5499: that
block is already reserved by the recorded SAML ruling (#1091, S-7), and
allocating around a recorded reservation is cheaper than editing one.

## Execution order

Ruling (this file) → `spec/03-approved/std-lib/tar.md` → the fixture
corpus, INCLUDING the hostile-container cases before the decoder →
implementation → flip `status=current` WITH the module, never before, or
stdlib-catalog-gate goes red. Interop verified at landing against system
`tar` in both directions, the way #1078 verified against `unzip`.
