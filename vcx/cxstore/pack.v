module cxstore

// CXStore pack-file engine — writer + reader for the append-only,
// content-addressed pack format (docs-src/canonical/cxstore/pack_format.md,
// object_model.md Appendix A). Issue #83.
//
// This increment implements the on-disk pack atom: 64-byte header, an
// append-only entry stream of self-verifying (SHA-256-named) objects, and a
// footer index sorted by hash for O(log n) point lookup. Objects here carry
// opaque byte payloads; the cx ast_bin / B+tree subtree layer (A.2) lands on
// top of this in a later increment.
//
// CRC: uses hash.crc32 for header/footer integrity. pack_format.md targets
// CRC32C (hardware-accelerated) — switching is an isolated change once locked
// (pack_format open question #2). Bloom filter (#84) is written empty here;
// the reader falls through to index binary-search, so it is purely additive.

import crypto.sha256
import hash.crc32
import compress.zlib
import os

pub const pack_magic = [u8(`C`), `X`, `P`, `A`, `C`, `K`, 0, 0]
pub const pack_version = u16(1)
// pack_version_keyed — format v2 (#229): every entry is KEYED — its index key
// (the doc_hash slot) is a CALLER-SUPPLIED key rather than the SHA-256 of the
// stored bytes, so the stored bytes need not (and do not) hash to the key. The
// canonical use is encryption-at-rest: the key is the PLAINTEXT content hash and
// the stored bytes are an AEAD envelope (encryption.v layout). Readers of v1
// packs self-verify payloads against the key; v2 entries carry a CRC32 that is
// verified instead (bit-rot detection at the pack layer — end-to-end integrity
// moves to the layer that owns the key↔bytes relation, e.g. the AEAD tag + the
// post-decrypt plaintext-hash check in EncryptingWrapper). A v1-era reader
// REFUSES a v2 pack (unsupported version), never misreads it — that is the
// format-versioning: keyed packs are invisible to old binaries, not silently
// empty.
pub const pack_version_keyed = u16(2)
pub const header_size = 64

// entry_kind enum (pack_format.md)
pub const kind_document = u8(0)
pub const kind_tombstone = u8(1)
pub const kind_meta = u8(2)

// footer membership-filter kind (the formerly-reserved `bloom_seed` u32 slot).
// 0 = legacy Bloom (bloom.v); 1 = xor8 (xorfilter.v). The footer self-describes
// so a reader opens packs from either era — see write_pack_opts / parse_pack.
pub const pack_filter_kind_bloom = u32(0)
pub const pack_filter_kind_xor = u32(1)

// ── little-endian helpers ─────────────────────────────────────────────

fn put_u16(mut b []u8, v u16) {
	b << u8(v)
	b << u8(v >> 8)
}

fn put_u32(mut b []u8, v u32) {
	b << u8(v)
	b << u8(v >> 8)
	b << u8(v >> 16)
	b << u8(v >> 24)
}

fn put_u64(mut b []u8, v u64) {
	for i in 0 .. 8 {
		b << u8(v >> (u64(i) * 8))
	}
}

fn read_u16(b []u8, off int) u16 {
	return u16(b[off]) | (u16(b[off + 1]) << 8)
}

fn read_u32(b []u8, off int) u32 {
	return u32(b[off]) | (u32(b[off + 1]) << 8) | (u32(b[off + 2]) << 16) | (u32(b[off + 3]) << 24)
}

fn read_u64(b []u8, off int) u64 {
	mut v := u64(0)
	for i in 0 .. 8 {
		v |= u64(b[off + i]) << (u64(i) * 8)
	}
	return v
}

fn compare_bytes(a []u8, b []u8) int {
	n := if a.len < b.len { a.len } else { b.len }
	for i in 0 .. n {
		if a[i] != b[i] {
			return int(a[i]) - int(b[i])
		}
	}
	return a.len - b.len
}

// ── object naming ─────────────────────────────────────────────────────

// object_name is the content address of a payload: SHA-256 of the bytes.
pub fn object_name(payload []u8) []u8 {
	return sha256.sum256(payload)
}

// ── header ────────────────────────────────────────────────────────────

fn build_header(created_at_ns u64, producer_cap u64, pack_id []u8, version u16) []u8 {
	mut h := []u8{cap: header_size}
	h << pack_magic // 8
	put_u16(mut h, version) // 2
	put_u16(mut h, u16(1)) // flags: bit0 = little-endian
	put_u64(mut h, created_at_ns) // 8
	put_u64(mut h, producer_cap) // 8
	mut id := pack_id.clone()
	for id.len < 16 {
		id << u8(0)
	}
	h << id[..16] // 16
	put_u64(mut h, 0) // reserved_0
	put_u64(mut h, 0) // reserved_1
	// h is now 60 bytes (offsets 0..60)
	put_u32(mut h, crc32.sum(h)) // header_crc32 over bytes 0..60
	return h
}

// ── entry ─────────────────────────────────────────────────────────────

fn build_entry(kind u8, hash []u8, payload []u8, with_crc bool, do_compress bool, keyed bool) []u8 {
	// doc_hash is always over the ORIGINAL payload (identity/dedup unchanged);
	// the stored bytes may be a zlib-compressed image, flagged in entry_flags.
	// keyed (v2, #229): `hash` is a caller-supplied key — the payload does NOT
	// hash to it, so the reader verifies the CRC instead of the hash.
	mut flags := if with_crc { u8(1) } else { u8(0) } // bit0 = crc present
	if keyed {
		flags |= u8(4) // bit2 = keyed (doc_hash is a caller key, not sha256(payload))
	}
	c := if do_compress { zlib.compress(payload) or { []u8{} } } else { []u8{} }
	use_comp := c.len > 0 && c.len < payload.len
	if use_comp {
		flags |= u8(2) // bit1 = payload compressed
	}
	plen := u32(if use_comp { c.len } else { payload.len })
	mut elen := u32(44) + plen
	if with_crc {
		elen += 4
	}
	mut e := []u8{cap: int(elen)}
	put_u32(mut e, elen) // entry_length (incl. this prefix)
	e << kind // entry_kind
	e << flags // entry_flags (bit0 crc, bit1 compressed)
	put_u16(mut e, 0) // reserved
	e << hash[..32] // doc_hash (of original payload)
	put_u32(mut e, plen) // payload_length (stored, possibly compressed)
	if use_comp {
		e << c
	} else {
		e << payload
	}
	if with_crc {
		put_u32(mut e, if use_comp { crc32.sum(c) } else { crc32.sum(payload) }) // crc over stored bytes
	}
	return e
}

// ── writer ────────────────────────────────────────────────────────────

struct IndexRecord {
	hash   []u8
	offset u64
	length u32
}

fn cmp_index(a &IndexRecord, b &IndexRecord) int {
	return compare_bytes(a.hash, b.hash)
}

// write_pack seals a new pack file containing the given payloads as Document
// entries. Identical payloads are deduplicated (logical dedup, §5). The file
// is immutable once written.
pub fn write_pack(path string, payloads [][]u8) ! {
	write_pack_opts(path, payloads, false)!
}

// write_pack_opts seals a pack, optionally zlib-compressing each entry payload
// (stored compressed only when it actually shrinks; the doc_hash stays over the
// original bytes, so identity and dedup are unaffected).
pub fn write_pack_opts(path string, payloads [][]u8, compress bool) ! {
	write_pack_kind(path, payloads, compress, pack_filter_kind_xor)!
}

// write_pack_kind is write_pack_opts parameterized by the footer membership-filter
// kind. Production always writes xor8 (pack_filter_kind_xor); the bloom path
// (pack_filter_kind_bloom) exists so the back-compat reader can be exercised
// against a genuine legacy footer in tests.
fn write_pack_kind(path string, payloads [][]u8, compress bool, filter_kind u32) ! {
	mut keys := [][]u8{cap: payloads.len}
	for p in payloads {
		keys << sha256.sum256(p)
	}
	write_pack_entries(path, keys, payloads, compress, filter_kind, false)!
}

// KeyedPayload — one keyed pack entry: a caller-supplied 32-byte key plus the
// bytes stored under it (v2 format, #229). For encryption-at-rest the key is the
// PLAINTEXT content hash and blob is the AEAD envelope.
pub struct KeyedPayload {
pub:
	key  []u8
	blob []u8
}

// write_pack_keyed seals a v2 KEYED pack: each entry is indexed by its
// caller-supplied key, and the stored bytes are NOT required to hash to it
// (integrity at this layer = per-entry CRC32; the key↔bytes relation is owned by
// the caller, e.g. EncryptingWrapper's AEAD tag + post-decrypt hash check).
// Entries with a duplicate key are deduplicated (first wins — keys are
// content-derived, so duplicates carry equivalent envelopes). No compression:
// the canonical payloads are ciphertext envelopes, which do not shrink.
pub fn write_pack_keyed(path string, entries []KeyedPayload) ! {
	mut keys := [][]u8{cap: entries.len}
	mut blobs := [][]u8{cap: entries.len}
	for e in entries {
		if e.key.len != 32 {
			return error('cxstore: keyed pack entry key must be 32 bytes (got ${e.key.len})')
		}
		keys << e.key
		blobs << e.blob
	}
	write_pack_entries(path, keys, blobs, false, pack_filter_kind_xor, true)!
}

// write_pack_entries is the shared writer core: parallel keys/blobs arrays, one
// entry per distinct key. keyed=false ⇒ v1 (keys are the payload hashes, entries
// self-verify); keyed=true ⇒ v2 (caller keys, flag bit2 on every entry).
fn write_pack_entries(path string, keys [][]u8, blobs [][]u8, compress bool, filter_kind u32, keyed bool) ! {
	version := if keyed { pack_version_keyed } else { pack_version }
	mut buf := build_header(0, 0, []u8{}, version)
	mut recs := []IndexRecord{}
	mut seen := map[string]bool{}
	for i, p in blobs {
		h := keys[i]
		hk := h.hex()
		if hk in seen {
			continue
		}
		seen[hk] = true
		off := u64(buf.len)
		e := build_entry(kind_document, h, p, true, compress, keyed)
		recs << IndexRecord{
			hash:   h
			offset: off
			length: u32(e.len)
		}
		buf << e
	}
	recs.sort_with_compare(cmp_index)
	mut footer := []u8{}
	put_u32(mut footer, u32(recs.len)) // index_count
	for r in recs {
		footer << r.hash[..32]
		put_u64(mut footer, r.offset)
		put_u32(mut footer, r.length)
	}
	// Membership filter (#84) — fast-negative accelerator built from the object
	// set. The footer self-describes which KIND via the formerly-reserved
	// `bloom_seed` field, now `filter_kind`: 0 = Bloom (legacy), 1 = xor8. New
	// packs write the xor8 filter (xorfilter.v) — ~1.23 B/key at a lower FPR than
	// the Bloom — reusing the exact footer slots (no layout change): the
	// fingerprint array goes in the bits blob, `bloom_k` is 0, `filter_kind` = 1,
	// and the deterministic build seed rides the `bloom_m_log2` slot. A reader
	// dispatches on filter_kind, so packs written by either era still open.
	hashes := recs.map(it.hash)
	if filter_kind == pack_filter_kind_xor {
		xf := build_xor_filter(hashes)
		put_u32(mut footer, u32(xf.fingerprints.len)) // filter_length
		footer << xf.fingerprints
		footer << u8(0) // bloom_k (unused for xor8)
		put_u32(mut footer, pack_filter_kind_xor) // filter_kind (was bloom_seed)
		put_u32(mut footer, u32(xf.seed)) // build seed (was bloom_m_log2)
	} else {
		bloom := build_bloom(hashes)
		put_u32(mut footer, u32(bloom.bits.len)) // filter_length
		footer << bloom.bits
		footer << bloom.k // bloom_k
		put_u32(mut footer, pack_filter_kind_bloom) // filter_kind
		put_u32(mut footer, bloom.m_log2) // bloom_m_log2
	}
	put_u32(mut footer, 0) // manifest_hash_count
	put_u32(mut footer, crc32.sum(footer)) // footer_crc32
	buf << footer
	put_u64(mut buf, u64(footer.len)) // 8-byte footer length at EOF

	mut f := os.create(path)!
	f.write(buf)!
	f.close()
}

// ── reader ────────────────────────────────────────────────────────────

pub struct PackReader {
mut:
	data    []u8
	map_ptr voidptr // non-nil when `data` is an mmap view (see open_pack_mapped)
	map_len usize
pub:
	count     u32
	index_off int // byte offset of the first index record
	// keyed — true for a v2 pack (#229): entry keys are caller-supplied (not the
	// payload hash). A backend opened in the wrong mode rejects the pack rather
	// than misreading it (an encrypted store opened without its key must error,
	// never appear empty/corrupt).
	keyed bool
	// Exactly one membership filter is populated per the footer's filter_kind;
	// the other stays empty. r.maybe_has dispatches. Both empty (no/garbage
	// filter) → maybe_has conservatively true (the index stays authoritative).
	bloom Bloom      // populated for legacy (filter_kind == 0) packs
	xor   XorFilter  // populated for xor8 (filter_kind == 1) packs
}

// maybe_has returns false only if the object is DEFINITELY absent from this
// pack, dispatching to whichever membership filter the footer carried.
pub fn (r &PackReader) maybe_has(hash []u8) bool {
	if r.xor.fingerprints.len > 0 {
		return r.xor.maybe_has(hash)
	}
	return r.bloom.maybe_has(hash)
}

// open_pack mmaps-equivalently loads and validates a sealed pack.
pub fn open_pack(path string) !PackReader {
	data := os.read_bytes(path)!
	return parse_pack(data)!
}

// close releases an mmap-backed pack (no-op for read_bytes-backed packs). After
// close the reader's bytes are invalid and must not be used.
pub fn (r &PackReader) close() {
	$if linux || macos {
		r.unmap()
	}
}

// parse_pack validates a pack byte image (from read_bytes or an mmap view) and
// builds the reader (header/footer CRC, index offset, bloom).
fn parse_pack(data []u8) !PackReader {
	if data.len < header_size + 8 {
		return error('cxstore: pack too small')
	}
	for i in 0 .. 8 {
		if data[i] != pack_magic[i] {
			return error('cxstore: bad magic')
		}
	}
	ver := read_u16(data, 8)
	if ver != pack_version && ver != pack_version_keyed {
		return error('cxstore: unsupported version')
	}
	if crc32.sum(data[..60]) != read_u32(data, 60) {
		return error('cxstore: header crc mismatch')
	}
	flen := read_u64(data, data.len - 8)
	footer_start := data.len - 8 - int(flen)
	if footer_start < header_size || footer_start > data.len - 8 {
		return error('cxstore: bad footer length')
	}
	footer := data[footer_start..data.len - 8]
	if footer.len < 4 {
		return error('cxstore: footer too small')
	}
	if crc32.sum(footer[..footer.len - 4]) != read_u32(footer, footer.len - 4) {
		return error('cxstore: footer crc mismatch')
	}
	count := read_u32(footer, 0)
	// Parse the membership filter (sits after the index records in the footer).
	// `filter_kind` (the formerly-reserved bloom_seed slot) selects the kind: a
	// kind-0 pack carries a Bloom, kind-1 an xor8 — the bytes blob, the k slot,
	// and the seed/m_log2 slot are reinterpreted accordingly.
	mut bloom := Bloom{}
	mut xor := XorFilter{}
	mut boff := 4 + int(count) * 44
	if boff + 4 <= footer.len {
		filt_len := int(read_u32(footer, boff))
		boff += 4
		if filt_len > 0 && boff + filt_len + 9 <= footer.len {
			blob := footer[boff..boff + filt_len].clone()
			boff += filt_len
			fk := footer[boff] // bloom_k (unused for xor8)
			boff += 1
			kind := read_u32(footer, boff)
			boff += 4
			param := read_u32(footer, boff) // bloom_m_log2 | xor build seed
			if kind == pack_filter_kind_xor {
				xor = XorFilter{
					seed:         u64(param)
					block_len:    u32(blob.len) / 3
					fingerprints: blob
				}
			} else {
				bloom = Bloom{
					bits:   blob
					m_log2: param
					k:      fk
				}
			}
		}
	}
	return PackReader{
		data:      data
		count:     count
		index_off: footer_start + 4
		keyed:     ver == pack_version_keyed
		bloom:     bloom
		xor:       xor
	}
}

// get returns the payload for a content hash, or none if absent. The returned
// payload is verified against its hash before being handed back.
pub fn (r &PackReader) get(hash []u8) ?[]u8 {
	if !r.maybe_has(hash) {
		return none // fast negative — definitely not in this pack
	}
	mut lo := 0
	mut hi := int(r.count) - 1
	for lo <= hi {
		mid := (lo + hi) / 2
		rec_off := r.index_off + mid * 44
		c := compare_bytes(r.data[rec_off..rec_off + 32], hash)
		if c == 0 {
			offset := read_u64(r.data, rec_off + 32)
			return r.entry_payload(int(offset))
		} else if c < 0 {
			lo = mid + 1
		} else {
			hi = mid - 1
		}
	}
	return none
}

// has is a cheap existence check (bloom would accelerate negatives; #84).
pub fn (r &PackReader) has(hash []u8) bool {
	if _ := r.get(hash) {
		return true
	}
	return false
}

// hashes returns every object hash in the pack (the footer index keys), in
// sorted order. Used to build the cross-pack master index (Store).
pub fn (r &PackReader) hashes() [][]u8 {
	mut out := [][]u8{cap: int(r.count)}
	for i in 0 .. int(r.count) {
		rec_off := r.index_off + i * 44
		out << r.data[rec_off..rec_off + 32].clone()
	}
	return out
}

fn (r &PackReader) entry_payload(off int) ?[]u8 {
	flags := r.data[off + 5]
	plen := int(read_u32(r.data, off + 40))
	start := off + 44
	if start + plen > r.data.len {
		return none
	}
	stored := r.data[start..start + plen]
	if flags & 4 != 0 { // bit2 = keyed (v2, #229): key is caller-supplied
		// The stored bytes do NOT hash to the entry key (they are e.g. an AEAD
		// envelope keyed by the plaintext hash), so integrity here is the CRC over
		// the stored bytes; the key↔bytes relation is verified by the owning layer
		// (AEAD tag + post-decrypt hash in EncryptingWrapper).
		if flags & 1 != 0 { // bit0 = crc present
			if start + plen + 4 > r.data.len {
				return none
			}
			if crc32.sum(stored) != read_u32(r.data, start + plen) {
				return none
			}
		}
		if flags & 2 != 0 { // bit1 = compressed
			return zlib.decompress(stored) or { return none }
		}
		return stored.clone()
	}
	if flags & 2 != 0 { // bit1 = compressed
		payload := zlib.decompress(stored) or { return none }
		if compare_bytes(sha256.sum256(payload), r.data[off + 8..off + 40]) != 0 {
			return none
		}
		return payload // freshly allocated by decompress
	}
	// raw: self-verify the stored bytes hash to the entry's doc_hash
	if compare_bytes(sha256.sum256(stored), r.data[off + 8..off + 40]) != 0 {
		return none
	}
	return stored.clone()
}
