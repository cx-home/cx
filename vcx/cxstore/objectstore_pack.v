module cxstore

import os
import encoding.hex

// objectstore_pack.v — the PACK-backed ObjectBackend (#76 / #129 spec §2, §7.1).
//
// This is the durable, local-filesystem implementation of the universal object
// seam (ObjectBackend, objectstore.v) using the pack engine (pack.v) as the
// at-rest encoding. It is the point `local-fs × subtree × pack` — what the
// `cxpack://` store URL resolves to (spec §1: "cxpack is not a substrate; it is
// the point local-fs × subtree × pack").
//
// It owns ONLY the content-addressed object layer: put/get/has by content hash,
// segment-pack flushing, compaction, and pack discovery/load. The store-key →
// doc-root manifest (the REFS layer, spec §3) lives one level up in
// store_cxpack.v — objects are immutable and self-named; refs are the mutable
// surface. Keeping the two apart is what lets the same refs layer drive ANY
// ObjectBackend (mem / sqlite / object-per-key / s3 / wire) in later phases.
//
// PERSIST MODEL (incremental, #129-B): put_object stages an object in-memory;
// flush_segment writes everything staged-since-the-last-flush as one new segment
// pack `store-NNNN.cxpack`. So durable work per mutation is O(delta). When
// segments accumulate (should_compact), the refs layer calls write_compacted to
// fold every live object into a single `store.cxpack` and drop the segments.

const pack_compacted_name = 'store.cxpack' // the compacted single pack
const pack_seg_prefix = 'store-' // store-NNNN.cxpack incremental segments
const pack_seg_suffix = '.cxpack'

// pack_compact_segments — fold segments into one pack once this many accrue,
// bounding the open-pack count and the cross-pack index rebuild on load.
pub const pack_compact_segments = 16

// PackObjectBackend — an ObjectBackend whose at-rest encoding is the pack format
// on a local-filesystem directory. The durable watermark (`flushed`) plus the
// staged-but-unwritten buffer (`pending`) make put_object idempotent and flushes
// O(delta).
@[heap]
pub struct PackObjectBackend {
mut:
	dir string
	// keyed (#229): the backend's at-rest mode, fixed at open for the store's
	// whole life. false ⇒ v1 content-addressed packs (put_object, entries
	// self-verify). true ⇒ v2 KEYED packs (put_object_keyed: caller keys, e.g.
	// AEAD envelopes keyed by plaintext hash via EncryptingWrapper). The two
	// never mix within one store: each put surface guards against the other
	// mode, and load_objects hard-errors on a mode↔pack-version mismatch (an
	// encrypted store opened without its key must ERROR, never appear empty).
	keyed       bool
	flushed     map[string]bool // hex(key) of objects already durable in some pack
	pending     []KeyedPayload  // objects staged since the last flush_segment
	pending_set map[string]bool // hex(key) of staged objects (dedup within a flush)
	seg_count   int             // next segment-pack number; reset to 0 on compaction
}

// open_pack_object_backend opens a pack-backed object store rooted at `dir`. The
// directory is created lazily on the first durable write (flush_segment /
// write_compacted), so opening a read-only / not-yet-written store touches no
// filesystem state.
pub fn open_pack_object_backend(dir string) &PackObjectBackend {
	return &PackObjectBackend{
		dir: dir
	}
}

// open_pack_object_backend_keyed opens a pack backend in KEYED mode (#229):
// objects are staged via put_object_keyed and flushed as v2 keyed packs. The
// live consumer is the encrypted cxpack store (EncryptingWrapper over this).
pub fn open_pack_object_backend_keyed(dir string) &PackObjectBackend {
	return &PackObjectBackend{
		dir:   dir
		keyed: true
	}
}

// seg_name is the filename of segment N (zero-padded so a lexical sort of the
// directory listing is also numeric order up to 9999 — compaction at 16 keeps
// the live count far below that).
fn (b &PackObjectBackend) seg_name(n int) string {
	mut s := n.str()
	for s.len < 4 {
		s = '0' + s
	}
	return '${pack_seg_prefix}${s}${pack_seg_suffix}'
}

// pack_seg_index parses the numeric index out of a segment filename, or -1 if the
// name is not a segment pack.
fn pack_seg_index(name string) int {
	if !name.starts_with(pack_seg_prefix) || !name.ends_with(pack_seg_suffix) {
		return -1
	}
	mid := name[pack_seg_prefix.len..name.len - pack_seg_suffix.len]
	if mid == '' {
		return -1
	}
	for c in mid {
		if c < `0` || c > `9` {
			return -1
		}
	}
	return mid.int()
}

// discover_packs lists the store's pack files: the compacted `store.cxpack` (if
// present) first, then every `store-NNNN.cxpack` segment in numeric order.
// Returns the absolute paths plus the highest segment index seen (-1 if none).
pub fn (b &PackObjectBackend) discover_packs() ([]string, int) {
	mut paths := []string{}
	mut max_seg := -1
	if os.exists(os.join_path(b.dir, pack_compacted_name)) {
		paths << os.join_path(b.dir, pack_compacted_name)
	}
	entries := os.ls(b.dir) or { []string{} }
	mut segs := []int{}
	for e in entries {
		idx := pack_seg_index(e)
		if idx >= 0 {
			segs << idx
		}
	}
	segs.sort()
	for idx in segs {
		paths << os.join_path(b.dir, b.seg_name(idx))
		if idx > max_seg {
			max_seg = idx
		}
	}
	return paths, max_seg
}

// ── ObjectBackend surface ─────────────────────────────────────────────────────

// has_object — true iff the object is durable (flushed) or staged (pending).
pub fn (b &PackObjectBackend) has_object(hash []u8) bool {
	hx := hash.hex()
	return hx in b.flushed || hx in b.pending_set
}

// get_object resolves an object by content hash, self-verifying it against its
// address (a corrupt/substituted object is rejected as none, never handed back —
// spec §4 universal integrity). Staged objects answer from memory; durable ones
// are read from the packs on disk. This is the cold path for the pack backend:
// an open cxpack session keeps the live object graph in the in-memory sink, so
// get_object is exercised mainly by integrity checks and remote/other backends.
pub fn (b &PackObjectBackend) get_object(hash []u8) ?[]u8 {
	hx := hash.hex()
	if hx in b.pending_set {
		for p in b.pending {
			if compare_bytes(object_name(p.blob), hash) == 0 {
				return p.blob
			}
		}
	}
	paths, _ := b.discover_packs()
	for pp in paths {
		reader := open_pack(pp) or { continue }
		payload := reader.get(hash) or {
			reader.close()
			continue
		}
		reader.close()
		if compare_bytes(object_name(payload), hash) != 0 {
			return none
		}
		return payload
	}
	return none
}

// get_object_raw resolves the stored bytes under `key` WITHOUT self-verifying
// them against it (KeyedObjectBackend seam, #229) — on a keyed backend the bytes
// are envelopes that deliberately do not hash to the key. Staged objects answer
// from memory; durable ones from the packs (whose keyed entries are CRC-checked
// by the reader).
pub fn (b &PackObjectBackend) get_object_raw(key []u8) ?[]u8 {
	kx := key.hex()
	if kx in b.pending_set {
		for p in b.pending {
			if compare_bytes(p.key, key) == 0 {
				return p.blob
			}
		}
	}
	paths, _ := b.discover_packs()
	for pp in paths {
		reader := open_pack(pp) or { continue }
		payload := reader.get(key) or {
			reader.close()
			continue
		}
		reader.close()
		return payload
	}
	return none
}

// put_object stages a content-addressed object. Idempotent: an object already
// durable or already staged is a no-op (content-addressed dedup). The object is
// not durable until flush_segment.
pub fn (mut b PackObjectBackend) put_object(payload []u8) ![]u8 {
	if b.keyed {
		return error('keyed pack backend: use put_object_keyed (content-addressed put would mix modes)')
	}
	h := object_name(payload)
	hx := h.hex()
	if hx in b.flushed || hx in b.pending_set {
		return h
	}
	b.pending << KeyedPayload{
		key:  h
		blob: payload
	}
	b.pending_set[hx] = true
	return h
}

// put_object_keyed stages caller-keyed bytes (KeyedObjectBackend seam, #229).
// Idempotent per key. Only valid on a keyed backend — the modes never mix
// within one store.
pub fn (mut b PackObjectBackend) put_object_keyed(key []u8, blob []u8) ! {
	if !b.keyed {
		return error('non-keyed pack backend: use put_object (keyed put would mix modes)')
	}
	kx := key.hex()
	if kx in b.flushed || kx in b.pending_set {
		return
	}
	b.pending << KeyedPayload{
		key:  key.clone()
		blob: blob
	}
	b.pending_set[kx] = true
}

// object_count — distinct objects the backend holds (durable + staged).
pub fn (b &PackObjectBackend) object_count() int {
	return b.flushed.len + b.pending_set.len
}

// ── Pack-specific durability operations (driven by the refs layer) ────────────

// pending_count — staged-but-not-yet-flushed objects (for the refs layer to know
// whether a flush will write a segment).
pub fn (b &PackObjectBackend) pending_count() int {
	return b.pending.len
}

// segment_count — current next-segment number (= number of segment packs since
// the last compaction).
pub fn (b &PackObjectBackend) segment_count() int {
	return b.seg_count
}

// should_compact — true once enough segment packs have accrued to fold them back.
pub fn (b &PackObjectBackend) should_compact() bool {
	return b.seg_count >= pack_compact_segments
}

// flush_segment writes everything staged since the last flush as one new segment
// pack and marks those objects durable. Written BEFORE the refs layer records
// them, so a crash between the two leaves unreferenced objects (reclaimed at
// compaction), never a dangling ref. No-op when nothing is staged.
pub fn (mut b PackObjectBackend) flush_segment() ! {
	if b.pending.len == 0 {
		return
	}
	os.mkdir_all(b.dir)!
	seg := os.join_path(b.dir, b.seg_name(b.seg_count))
	if b.keyed {
		write_pack_keyed(seg, b.pending)!
	} else {
		write_pack(seg, b.pending.map(it.blob))!
	}
	for p in b.pending {
		b.flushed[p.key.hex()] = true
	}
	b.seg_count++
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
}

// write_compacted folds the given live objects into a single `store.cxpack`,
// deletes every accumulated segment pack, and resets the durable watermark to
// exactly `payloads`. The caller (refs layer) supplies the reachable object set
// (GC is a refs-level concern — it depends on the live roots, which objects do
// not know about). Resets seg_count to 0. The new pack is written to a temp
// sibling and installed by atomic rename (#302): the live `store.cxpack` is
// NEVER opened for write in place, so a crash (or any failure) mid-compaction
// leaves the previous pack whole — the segments are dropped only after the
// rename.
pub fn (mut b PackObjectBackend) write_compacted(payloads [][]u8) ! {
	if b.keyed {
		return error('keyed pack backend: use write_compacted_keyed')
	}
	os.mkdir_all(b.dir)!
	final := os.join_path(b.dir, pack_compacted_name)
	tmp := final + '.tmp'
	write_pack(tmp, payloads)!
	os.mv(tmp, final) or {
		os.rm(tmp) or {}
		return error('compacted pack rename failed: ${err.msg()}')
	}
	for n in 0 .. b.seg_count {
		os.rm(os.join_path(b.dir, b.seg_name(n))) or {}
	}
	mut fl := map[string]bool{}
	for p in payloads {
		fl[object_name(p).hex()] = true
	}
	b.flushed = fl.move()
	b.seg_count = 0
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
}

// durable_keys returns every key currently durable in some pack (the flushed
// watermark) — the enumeration surface the #287 KEK-rotation walk reads (staged
// pending objects are the caller's to flush first).
pub fn (b &PackObjectBackend) durable_keys() [][]u8 {
	mut out := [][]u8{cap: b.flushed.len}
	for hx, _ in b.flushed {
		key := hex.decode(hx) or { continue }
		out << key
	}
	return out
}

// write_compacted_keyed is the keyed-mode compaction (#229): folds the given
// live (key, envelope) entries into a single v2 `store.cxpack`, drops the
// segments, and resets the durable watermark to exactly those keys. The caller
// supplies envelopes it read back via get_object_raw (or freshly re-sealed), so
// compaction never decrypts. The new pack is written to a temp file and
// installed by atomic rename (a crash mid-write leaves the previous pack whole
// — the durability posture #287 rotation relies on; the segments are dropped
// only after the rename).
pub fn (mut b PackObjectBackend) write_compacted_keyed(entries []KeyedPayload) ! {
	if !b.keyed {
		return error('non-keyed pack backend: use write_compacted')
	}
	os.mkdir_all(b.dir)!
	final := os.join_path(b.dir, pack_compacted_name)
	tmp := final + '.tmp'
	write_pack_keyed(tmp, entries)!
	os.mv(tmp, final) or {
		os.rm(tmp) or {}
		return error('compacted pack rename failed: ${err.msg()}')
	}
	for n in 0 .. b.seg_count {
		os.rm(os.join_path(b.dir, b.seg_name(n))) or {}
	}
	mut fl := map[string]bool{}
	for e in entries {
		fl[e.key.hex()] = true
	}
	b.flushed = fl.move()
	b.seg_count = 0
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
}

// load_objects discovers every pack (compacted + all segments) and reads each
// object once, returning them as hex(hash) → payload for the caller to populate
// the in-memory graph. Records the durable watermark (flushed) and the next
// segment number so the following mutation appends only its own delta.
//
// INTEGRITY (#129-C / spec §4): an unreadable/unopenable pack or an unreadable
// object is a HARD error, never a silent skip — a dropped object is data loss
// masquerading as success.
pub fn (mut b PackObjectBackend) load_objects() !map[string][]u8 {
	paths, max_seg := b.discover_packs()
	mut out := map[string][]u8{}
	mut fl := map[string]bool{}
	for pp in paths {
		reader := open_pack(pp) or { return error('cxpack pack ${pp} unreadable: ${err.msg()}') }
		// #229 mode↔format check: a keyed (v2/encrypted) pack opened by a
		// non-keyed backend means the store is encrypted but no encrypt-key-id was
		// given; the reverse means a key was given for a plaintext store. Both are
		// HARD errors — never a silently-empty or mixed-mode store.
		if reader.keyed && !b.keyed {
			reader.close()
			return error('cxpack pack ${pp} is keyed (encrypted at rest) — reopen the store with its encrypt-key-id')
		}
		if !reader.keyed && b.keyed {
			reader.close()
			return error('cxpack pack ${pp} is not keyed (plaintext at rest) — encrypt-key-id was given for an unencrypted store; encryption cannot be enabled on existing data in place')
		}
		for h in reader.hashes() {
			payload := reader.get(h) or {
				reader.close()
				return error('cxpack ${pp}: object ${h.hex()} unreadable')
			}
			hx := h.hex()
			out[hx] = payload
			fl[hx] = true
		}
		reader.close()
	}
	b.flushed = fl.move()
	b.seg_count = max_seg + 1
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
	return out
}
