# CXStore — Pack File Format v1 (Draft)

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. SEE [`README.md`](README.md).**

**Status:** Draft. First sub-deliverable of Phase 1 in [`plan.md`](plan.md).
**Scope:** Binary layout of a single pack file. The indexed-perf storage atom within the Embedded tier; consumed unchanged by the Service tier when a Service node wraps a pack-backed local store.

---

## Design goals

1. **Append-only.** Writer streams entries; no rewrites.
2. **Self-describing.** Magic + version + producer cap-word in the header.
3. **Random read by hash.** Footer-at-end index allows O(log n) lookup.
4. **Mmap-friendly.** Fixed-width entry headers; no parser needed on read path.
5. **Integrity-checked.** Per-entry SHA-256 of payload; pack-wide footer checksum.
6. **Future-extensible.** Reserved bytes in header; entry-kind enum.
7. **Standard pattern.** Footer-at-end mirrors Parquet, ORC, Lucene segments — proven layout.

### Non-goals for v1

- In-place mutation. Use new packs + compaction.
- Cross-pack indexing. Master index lives outside the pack file (see [`plan.md`](plan.md)).
- Per-entry compression. Add in v2 via entry-flags bit if proven needed.

---

## File structure

```
+------------------------+   offset 0
| Header (64 bytes)      |   fixed
+------------------------+   offset 64
| Entry 1                |   variable
| Entry 2                |
| ...                    |
| Entry N                |
+------------------------+   offset = file_size - footer_length - 8
| Footer                 |   variable
+------------------------+   offset = file_size - 8
| Footer Length (8 bytes)|   fixed; LE u64
+------------------------+   end of file
```

All multi-byte integers are little-endian. All offsets are absolute byte offsets within the pack file.

---

## Header (64 bytes, fixed)

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0 | 8 | `magic` | ASCII `"CXPACK\x00\x00"` |
| 8 | 2 | `version` | u16. v1 = `0x0001` |
| 10 | 2 | `flags` | u16. bit 0 = endianness (1 = LE; always 1 in v1). bits 1–15 reserved |
| 12 | 8 | `created_at_ns` | u64. Unix epoch nanoseconds, UTC |
| 20 | 8 | `producer_cap_word` | u64. Cap bits the producer's CX runtime supported (per `spec/abi.md`) |
| 28 | 16 | `pack_id` | UUID v7 (time-ordered) or content-hash-prefix |
| 44 | 8 | `reserved_0` | zero in v1 |
| 52 | 8 | `reserved_1` | zero in v1 |
| 60 | 4 | `header_crc32` | CRC32C of bytes 0..60 |

Readers MUST verify `magic`, `version`, and `header_crc32` before trusting any other field.

---

## Entry (variable)

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0 | 4 | `entry_length` | u32. Total entry size in bytes, including this 4-byte prefix |
| 4 | 1 | `entry_kind` | u8. See enum below |
| 5 | 1 | `entry_flags` | u8. See bits below |
| 6 | 2 | `hash_code` | u16. Multicodec code of the algorithm naming `doc_hash` (sha2-256 = `0x0012`; I1 crypto-agility §4). Writers MUST emit `0x0012`. Readers MUST accept exactly `{0x0000, 0x0012}` and fail closed on every other code, including registered algorithms they do not implement. `0x0000` is the pre-I1 **reserved** value: packs written before the slot had a meaning carry a literal zero, and that era had only sha2-256, so zero names sha2-256 — read-compat only, never written (RULED: CO-1, #974). A reader that rewrites such a pack SHOULD stamp its zero slots to `0x0012` in place; the slot is covered by no CRC, digest, or signature, so the rewrite changes no other field. All 1.0 algorithms are 32-byte, and a non-32-byte digest requires a pack v3 |
| 8 | 32 | `doc_hash` | Digest of the canonical ast_bin payload under the `hash_code` algorithm (sha2-256 in every shipped pack) |
| 40 | 4 | `payload_length` | u32 |
| 44 | `payload_length` | `payload` | ast_bin bytes |
| 44 + `payload_length` | 0 or 4 | `payload_crc32` | optional CRC32C of payload; present iff `entry_flags` bit 0 set |

### `entry_kind` enum (u8)

| Value | Meaning |
|---|---|
| `0x00` | Document — `payload` is canonical ast_bin |
| `0x01` | Tombstone — `payload` is empty; `doc_hash` identifies the deleted doc |
| `0x02` | Meta-record — `payload` is a CX document describing pack-level metadata (schemas, lineage notes, etc.) |
| `0x03`–`0xFF` | reserved |

### `entry_flags` bits (u8)

| Bit | Meaning |
|---|---|
| 0 | `payload_crc32` present (4 trailing bytes) |
| 1 | `payload` compressed (compression scheme TBD in v2; MUST be 0 in v1) |
| 2–7 | reserved |

**Invariants:**
- `entry_length == 44 + payload_length + (4 if entry_flags.bit_0 else 0)`
- `payload_length` MUST be 0 for `entry_kind == 0x01` (tombstone).
- `doc_hash` MUST equal SHA-256 of `payload` for `entry_kind == 0x00`.
- For `entry_kind == 0x02`, `doc_hash` MAY be zero or a content hash; readers MUST NOT treat meta-records as documents.

---

## Footer (variable)

The footer is built at pack-seal time from accumulated entry metadata.

| Offset (relative to footer start) | Size | Field | Notes |
|---|---|---|---|
| 0 | 4 | `index_count` | u32. Number of index records below |
| 4 | `index_count × 44` | `index_records` | array of `(hash[32], offset_u64, length_u32)`, sorted by `hash` ascending |
| ... | 4 | `bloom_filter_length` | u32 |
| ... | `bloom_filter_length` | `bloom_filter` | raw bitset bytes |
| ... | 1 | `bloom_k` | u8. Number of hash functions used |
| ... | 4 | `bloom_seed` | u32. Seed for the hash family |
| ... | 4 | `bloom_m_log2` | u32. log2 of bloom filter bit count |
| ... | 4 | `manifest_hash_count` | u32. Reserved — references to companion manifest docs (0 in v1) |
| ... | 4 | `footer_crc32` | CRC32C of everything in the footer above this field |

### Index record

```
struct IndexRecord {
    u8   hash[32];       // SHA-256 of the entry's payload (matches entry's doc_hash)
    u64  offset;         // absolute byte offset of the entry within the pack
    u32  length;         // entry_length value (so reader can mmap the entry without re-parsing)
}
```

Sorted by `hash` to enable binary search.

### Bloom filter parameters

- Hash family: **xxHash3-64**, seeded with `bloom_seed`. Each of the `bloom_k` hash slots derives from `(seed + i)` for `i ∈ [0, bloom_k)`.
- For 1 M entries at 1% target FPR: `m ≈ 9.6 M bits ≈ 1.2 MB`; `k = 7`. Default sizing: `bloom_m_log2 = ceil(log2(entries × 10))`.

### Tombstone semantics

Tombstone entries (`entry_kind == 0x01`) are recorded in `index_records` exactly like document entries; readers filter them out when interpreting a hash lookup as "doc exists." Compaction reclaims tombstoned hashes by writing a new pack that omits them.

---

## Footer Length (8 bytes, fixed, at end of file)

| Offset (from EOF) | Size | Field |
|---|---|---|
| -8 | 8 | u64. Byte length of the footer immediately preceding |

A reader opens the file, reads the last 8 bytes, seeks to `file_size - 8 - footer_length`, and finds the footer. Everything between offset 64 (end of header) and that point is the entry stream.

---

## Reader path

```
1. Open file; mmap.
2. Validate header magic + version + header_crc32.
3. Read last 8 bytes → footer_length.
4. Seek to (file_size - 8 - footer_length) → footer_start.
5. Validate footer_crc32.
6. (Optional) Load bloom_filter into RAM, or use it in-place via mmap.
7. For point lookup by hash H:
   a. Test bloom_filter for H. If absent, return null.
   b. Binary search index_records by hash. If found, read (offset, length).
   c. Seek to offset; mmap entry; validate doc_hash matches H.
   d. Return payload (or zero-copy slice into the mmap).
8. For full scan: iterate entries from offset 64 by stepping entry_length each time.
```

## Writer path

```
1. Open file for create+write. Write header.
2. For each candidate document:
   a. Hash its canonical ast_bin → H.
   b. Check in-memory dedup set for H. If duplicate, skip.
   c. Append entry: { length, kind=0, flags, H, payload_length, payload, [crc32] }.
   d. Record (H, current_offset, entry_length) in writer state.
3. On seal:
   a. Sort writer state by H.
   b. Build bloom filter from the H set.
   c. Write footer: index records, bloom filter, parameters, footer_crc32.
   d. Write 8-byte footer length.
   e. Optionally fsync; close.
4. After seal, the file is immutable. Further writes go to a new pack.
```

---

## Seal & crash recovery

The footer + 8-byte footer-length suffix is the **commit point**: a pack with a valid `footer_crc32` and a resolvable footer-length is *sealed* and immutable. Recovery rules (normative; align with [`object_model.md`](object_model.md) §6 and Appendix A.7):

- **Torn footer / invalid footer-length:** the pack is treated as **unsealed**. A reader recovers it by scanning entries forward from offset 64, advancing by `entry_length`, stopping at the first entry whose `entry_length` overruns the file or whose `doc_hash` ≠ SHA-256(payload), and truncating there.
- **Unsealed packs remain usable:** every entry self-verifies via `doc_hash`, so all entries in the valid prefix stay addressable; they are merely absent from the (unbuilt) footer index until the pack is re-sealed or folded into a new pack by compaction.
- **Torn entry tail** is indistinguishable from "end of valid prefix" and handled by the same forward-scan truncation. A crash mid-append loses only the partial trailing entry, never earlier data.

This makes a torn pack no worse than a torn single entry, satisfying the append-only crash-safety floor.

---

## Sizing notes

| Quantity | Example |
|---|---|
| Header | 64 B fixed |
| Per-entry overhead | 44 B + optional 4 B CRC = 44–48 B |
| Index record | 44 B per entry |
| Bloom filter (1 M entries, 1% FPR) | ~1.2 MB |
| Footer overhead (1 M entry pack) | ~44 MB index + ~1.2 MB bloom + ~32 B params/crc ≈ ~45 MB |
| 1 GB pack at 1 KB avg payload | ~1 M entries; ~95% payload, ~5% overhead (header + per-entry + footer) |

## Compatibility & versioning

- Future versions bump `version` in the header. Readers reject unknown major versions; minor differences gated on reserved flag bits.
- Reserved fields MUST be zero in v1 and MUST be ignored by readers when subsequently used.
- Entry-kind values `0x03–0xFF` are reserved for future kinds; readers MUST skip-with-warning on unknown kinds (use `entry_length` to advance past them).

## Open questions

1. **Pack ID generation.** UUID v7 (time-ordered, randomness) vs. content-hash-prefix (deterministic, dedup-friendly). Current draft picks UUID v7. Revisit if dedup at the pack level becomes interesting (e.g., re-importing the same dataset).
2. **CRC choice.** CRC32C (Castagnoli, hardware-accelerated on x86_64 + aarch64) preferred over CRC32. Confirm before locking.
3. **Bloom filter scheme.** Standard Bloom is in this draft. Cuckoo or Xor filter give better lookup perf at ~similar storage but more implementation complexity. Defer until perf data justifies.
4. **Footer compression.** The index (~44 B × N entries) dominates footer size. Worth compressing? Probably not for v1; revisit if hot-path footers exceed memory budget.
5. **Encryption.** Not in v1. If added in v2, applies at the entry-payload level (per-entry encrypted ast_bin) with key reference in a meta-record. Pack header stays clear so the bloom/index remain queryable.

## Test surface (Phase 1)

Conformance fixtures to add under `conformance/pack_v1.txt` (file lives in `cx-home/private`; do **not** publish without scrubbing references to Service-tier commercial framing):

- Round-trip: write N docs → read by hash → read each entry → verify hash + payload byte-identical.
- Tombstone: write doc, write tombstone, read by hash → null with bloom miss-or-tombstone path.
- Corrupted header: bit-flip header, reader rejects with named error.
- Truncated file (mid-entry, mid-footer): reader rejects cleanly.
- Truncated footer-length suffix: reader rejects cleanly.
- 1 M entry pack: footer build < 2 s; point lookup < 50 µs after warm-up.
- Bloom FPR holds at design target across 1 M random probes.
- Append-after-seal: rejected (file marked sealed by footer presence).

## Next sub-deliverables in Phase 1 (after this format is locked)

1. V reference implementation of writer + reader.
2. Master hash→(pack, offset) index design (separate doc).
3. Element-name + attribute index design.
4. Path-summary index design.
5. Full-text index design (most likely vendor Tantivy via FFI; do not build native).
6. Query rewriter spec (when to use which index).
7. Layer-1 binding extensions (if any) for store operations beyond the 16 methods.
