# Rulings 2026-08-28 — cx-stdlib/zip archive module (#1078)

Owner directive (2026-08-28, verbatim): "wow that's a big gap. file it. do the
spec work. create the tests. implement. I really need to get this to a
customer and I'm concerned about our ogre release process."

That directive authorizes the full chain for #1078 — issue, spec, conformance
fixtures, implementation — as one lane, opening the 0.18 cycle
(release/0.18). Scope letters below are recorded with recommendations and
proceed under the standing letter-acceptance order
(feedback_standing_letter_acceptance_partition: recommendations auto-accepted
when long-term-best; each verified against that bar here). Any owner override
reverses the letter, not the process.

## Z-1 — module shape (RULED: Z-1 = a)

- (a) **New pure module `cx-stdlib/zip`** — an archive codec over the `bytes`
  scalar kind, zero I/O; file/stream I/O composes via `cx-stdlib/io`. Same
  purity split the bytes module already draws ("All operations are pure with
  no I/O"). RECOMMENDED and taken: orthogonal (codec ⊥ transport), testable
  byte-exact, and consistent with csv/json (codec modules).
- (b) Extend `bytes` — rejected: an archive with named entries is a container
  model, not a byte-string op; bloats the bytes surface.
- (c) io-coupled file API (`zip-file`, extract-to-dir) — rejected for v1:
  drags path/zip-slip semantics into the codec; compose in user code.

## Z-2 — v1 function surface (RULED: Z-2 = a)

- (a) **Four verbs**: `pack(entries) → bytes`, `unpack(archive) → [sequence
  map]`, `entries(archive) → [sequence map]` (central-directory metadata
  only, payloads untouched), `extract(archive, name) → bytes`. Entry model =
  maps (the csv row precedent): pack accepts `{name, data}` plus optional
  `mtime-unix` (int, UTC) and `method` ('store'|'deflate'); unpack emits
  `{name, data, mtime-unix}`; entries emits `{name, size, compressed-size,
  method, crc32}`. RECOMMENDED and taken.
- (b) Also streaming/appender verbs — rejected for v1: no consumer yet
  (seam-needs-live-consumer), add when one exists.

## Z-3 — determinism (RULED: Z-3 = a)

- (a) **`pack` is byte-stable**: entry order preserved as given; default
  timestamp = DOS epoch 1980-01-01T00:00:00 (mtime-unix below the DOS floor
  clamps to it; DOS resolution is 2 s, stored as UTC-interpreted fields);
  UTF-8 name flag (bit 11) always set; version-made-by/needed fixed
  (20/2.0); no extra fields, no comments, no data descriptors (sizes/CRC in
  the local header). Two packs of equal input are byte-identical.
  RECOMMENDED and taken — determinism is a CX-wide invariant (golden lanes).

## Z-4 — scope refusals, loud (RULED: Z-4 = a)

- (a) **Refused with a typed err, never silently wrong**: zip64 (any 0xFFFFFFFF
  sentinel / zip64 EOCD required for correctness), encryption (general-purpose
  flag bit 0), compression methods other than 0 (store) and 8 (deflate),
  multi-disk archives, archive comments that displace EOCD discovery beyond
  the 64 KiB scan window → `CXER5201 E_ZIP_UNSUPPORTED`. Pack ceilings
  (entry count > 65535, any size/offset > 2^32-1, total or per-entry beyond
  the bytes 2^32-1 scalar ceiling) → `CXER5205 E_ZIP_LENGTH_EXCEEDED` before
  allocation. This is a ruled v1 boundary with spec'd loud behavior — not a
  partial implementation (feedback_no_stubs_no_partial_impl satisfied by the
  refusal being specified, tested behavior).
- (b) zip64 read support in v1 — rejected: doubles container-parse surface
  for no current consumer; the refusal is loud, so need will be visible.

## Z-5 — name hygiene (RULED: Z-5 = a)

- (a) **Pack strict, read permissive.** `pack` refuses entry names that are
  empty, absolute (`/…`), contain `..` segments, contain backslashes, or
  duplicate a prior name → `CXER5203 E_ZIP_ENTRY_INVALID` (safe-by-
  construction outputs). `unpack`/`entries` report names as stored (the
  module is pure; zip-slip is an io-consumer hazard the spec flags
  explicitly). RECOMMENDED and taken.

## Z-6 — error band (RULED: Z-6 = a)

- (a) **`CXER5200–5299` allocated to cx-stdlib/zip** (5200 malformed, 5201
  unsupported, 5202 entry-not-found, 5203 entry-invalid, 5204 crc-mismatch,
  5205 length-exceeded). Verified free: occupied hundred-blocks end at 51xx
  (plus 99xx synthetic). RECOMMENDED and taken.

## Z-7 — compression primitive (RULED: Z-7 = a)

- (a) **In-tree V `compress.deflate`** (`compress_raw` = RFC 1951
  fixed-Huffman emit; `inflate` for decode; `hash.crc32.sum`) — no new
  third-party dependency, no szip. Fixed-Huffman output is valid deflate
  every decoder accepts; compression ratio is the trade (no dynamic Huffman,
  no level knob — so v1 exposes NO `level` option rather than a fake one).
  RECOMMENDED and taken; a later upstreamable dynamic-Huffman improvement
  lifts ratio without surface change.
- (b) Vendor miniz/szip — rejected: new C dependency for ratio only.

## Z-8 — Python-parity wave (owner "1a", 2026-08-28) (RULED: Z-8 = a)

Owner directive: full parity review demanded ("don't cut corners and
partially implement"); the four NON-WORTHLESS gaps were lettered and the
owner ruled (a) = close all four this cycle:

- **Z-8.1 zip64 READ** (+ the write half that is reachable): EOCD64
  locator/record, 0xFFFF/0xFFFFFFFF sentinel resolution through the
  0x0001 extra field. Write side: the bytes-scalar 2^32-1 archive ceiling
  means sizes/offsets always fit zip32 — only the >65535 ENTRY-COUNT case
  is reachable, and it now emits EOCD64 instead of refusing (spec §6
  ceiling narrowed accordingly). A single entry whose payload exceeds the
  bytes ceiling still refuses CXER5205 at decode (cannot materialize).
- **Z-8.2 mode bits**: pack accepts optional `mode` (int, unix bits);
  when present, version-made-by = unix(3)/20 and external-attrs carry
  mode<<16; when ABSENT the emitted bytes are byte-identical to v1
  (golden pin survives — determinism §4 stays a pure function of input).
  unpack/entries report `mode` when a unix made-by carries nonzero bits.
- **Z-8.3 archive + member comment READ**: new pure verb `comment`
  (archive-level; '' when none); entries maps gain a `comment` key.
  Comments are advisory metadata — non-UTF-8 comment bytes decode
  LOSSILY (U+FFFD), never refuse an archive over a comment. Write side
  stays none (determinism; no consumer).
- **Z-8.4 dynamic-Huffman deflate emitter** — in the V fork's
  compress.deflate (V-only, upstreamable per standing rule), reusing the
  existing LZ77 tokenizer + canonical-Huffman builder; per-entry the
  emitter keeps store-wins semantics (smallest of store/fixed/dynamic),
  so §4 determinism and the store-wins fixture hold unchanged.

RULED WORTHLESS, permanently refused (recorded so the refusals are
decisions, not gaps): ZipCrypto read (cryptographically broken; loud
CXER5201 is the correct posture), bzip2/lzma entry methods (#1088's
decision space), append/streaming modes (no live consumer —
seam-needs-live-consumer), extractall-in-zip (the codec/transport split).

## Execution notes

- Spec lands at `spec/03-approved/std-lib/zip.md` + README index row, the
  csv/schema-export precedent for a ruled spec-first lane. G3 graduation
  remains owner-reviewable: an owner override letter here reverts placement.
- Fixture-first: `conformance/stdlib/zip.cxd` written before the primitives.
- Wiring roster (traced via csv): `stdlib/zip.cx`, `vcx/code/stdlib_zip.v`,
  `stdlib_dispatch.v` chain line, `stdlib_bundle.v` embed + match arm,
  `vcx/tests/stdlib_umbrella_test.v` module roster.
