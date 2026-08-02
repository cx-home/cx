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
	// segs — the live segment packs in ascending numeric order, each with its
	// object count. Drives the #603 size-tiered fold (merge a segment into its
	// predecessor when the predecessor is no larger AND the pair is within 2×
	// — see fold_plan), which keeps a store of N objects at ~log(N) segment
	// files with each object re-folded O(log N) times total. #617: folds run
	// OFF the flush turn (fold_plan/fold_perform/fold_commit below), so a fold
	// can commit AFTER newer segments were appended — segment indices may
	// carry gaps, hence explicit (idx, size) pairs instead of a positional
	// array.
	segs []SegInfo
	// next_seg — monotonic next segment-pack number; reset to 0 only by
	// compaction (never reused after a fold frees an index, so an in-flight
	// fold can never collide with a fresh segment file).
	next_seg int
	// gen — bumped on every whole-set reset (write_compacted*/load_objects).
	// A fold planned under an older generation abandons at commit: its source
	// segments no longer exist (or belong to a different loaded state).
	gen u64
}

// SegInfo — one live segment pack: its numeric file index and object count.
pub struct SegInfo {
pub:
	idx  int
	size int
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
// directory listing is also numeric order up to 9999 — the #603 size-tiered
// fold keeps the live count at ~log2(objects), far below that).
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

// segment_count — the number the NEXT segment pack will be written under
// (monotonic since the last compaction; NOT the live file count once folds
// have retired segments — see live_segments).
pub fn (b &PackObjectBackend) segment_count() int {
	return b.next_seg
}

// live_segments — how many segment packs currently exist on disk.
pub fn (b &PackObjectBackend) live_segments() int {
	return b.segs.len
}

// should_compact — true once enough segment packs have accrued to fold them
// back. With the #603 size-tiered segment fold keeping the live count at
// ~log2(objects), this fires only when tiering alone cannot contain growth —
// full compaction (an O(live) rewrite) is otherwise driven by the refs layer's
// garbage heuristic, never by routine appends. #617: never fires while folds
// are PENDING — a backlog from deferred (background) folding will shrink the
// count on its own; only a genuine 16-tier tower (invariant satisfied and
// still ≥ the threshold) compacts.
pub fn (b &PackObjectBackend) should_compact() bool {
	if b.fold_pending() {
		return false
	}
	return b.segs.len >= pack_compact_segments
}

// flush_segment writes everything staged since the last flush as one new segment
// pack and marks those objects durable. Written BEFORE the refs layer records
// them, so a crash between the two leaves unreferenced objects (reclaimed at
// compaction), never a dangling ref. No-op when nothing is staged.
//
// #617: flush_segment does NOT fold — the #603 size-tiered fold is amortization
// work, not durability, and folding a large tier inline put a 69–720ms tail on
// a live publisher's receipt. The CALLER drives folds after the flush: either
// synchronously via fold_drain (single-threaded stores) or asynchronously via
// fold_plan / fold_perform / fold_commit (perform runs with no store lock held).
pub fn (mut b PackObjectBackend) flush_segment() ! {
	if b.pending.len == 0 {
		return
	}
	os.mkdir_all(b.dir)!
	seg := os.join_path(b.dir, b.seg_name(b.next_seg))
	// #624: never expose a torn pack at a segment's final name — a kill
	// mid-write must leave either no segment or a whole one. Write to a temp
	// sibling (fsynced inside the pack writer) and install by atomic rename;
	// a stray .tmp from a crash is invisible to discovery (the name filter
	// requires the .cxpack suffix) and is overwritten by the next flush.
	tmp := seg + '.tmp'
	if b.keyed {
		write_pack_keyed(tmp, b.pending)!
	} else {
		write_pack(tmp, b.pending.map(it.blob))!
	}
	os.mv(tmp, seg) or {
		os.rm(tmp) or {}
		return error('cxstore: segment install rename failed: ${err.msg()}')
	}
	for p in b.pending {
		b.flushed[p.key.hex()] = true
	}
	b.segs << SegInfo{
		idx:  b.next_seg
		size: b.pending.len
	}
	b.next_seg++
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
}

// ── #603/#617 size-tiered segment folding ─────────────────────────────────────
//
// The fold merges two adjacent segment packs into one (at the lower index) — an
// OBJECT-layer fold: no reachability walk, no manifest rewrite, no main-pack
// touch; cost is O(the two segments), which the size-tier invariant keeps
// geometric. It is split into three primitives so the EXPENSIVE part (reading
// two packs, writing + fsyncing the merged one) can run without the store's
// op-lock held (#617 — off the publish turn), while the state transitions stay
// serialized:
//
//   fold_plan    (lock held)  — pick the pair, snapshot paths + generation
//   fold_perform (NO lock)    — pure file I/O; touches no backend state; the
//                               source segments are immutable once written and
//                               only ever removed under the lock
//   fold_commit  (lock held)  — install by atomic rename iff the generation
//                               still matches; otherwise abandon (a compaction
//                               or reload reset the segment set meanwhile)
//
// Crash-safe at every step: the merged pack lands at a temp sibling first, and
// a crash before the newer segment's removal leaves its objects present in
// BOTH packs — content-addressed load dedups them, and the next fold
// re-collapses the pair.

// FoldPlan — a scheduled merge of two adjacent segment packs, pinned to the
// backend generation it was planned under.
pub struct FoldPlan {
pub:
	gen     u64
	lo_idx  int
	hi_idx  int
	lo_path string
	hi_path string
	tmp     string
	keyed   bool
}

// fold_plan picks the next due fold: the SMALLEST pair of segments — any two,
// not necessarily neighbors; segments are content-addressed object sets with
// no ordering semantics — whose sizes are within a factor of two of each
// other, or none when every pair is more lopsided than that.
//
// The pairing rule is what keeps folding amortized regardless of arrival
// order (#617): every fold grows each copied object's segment by ≥1.5×
// (merged = a+b with a ≤ b ≤ 2a ⇒ merged ≥ 1.5b), so any object is copied
// O(log N) times total. Bare positional carry (`prev <= cur` on neighbors)
// broke both ways under deferred folding: it licensed O(big) rewrites for
// O(1) gains when a small segment sat below a huge newer merge (measured:
// ~10k-object folds absorbing ~65 each, every batch), and with a ratio guard
// alone the small tiers STRANDED behind big neighbors until the count hit the
// full-compaction backstop on a live flush turn. Size-sorted pairing lets the
// small tiers of a mixed flow (per-event flushes interleaved with batch
// segments) ladder up geometrically among themselves until they earn a merge
// with the big tier — the live count stays ~log(N) with no compaction debt.
pub fn (b &PackObjectBackend) fold_plan() ?FoldPlan {
	if b.segs.len < 2 {
		return none
	}
	mut by_size := b.segs.clone()
	by_size.sort(a.size < b.size)
	for j in 0 .. by_size.len - 1 {
		if by_size[j].size * 2 >= by_size[j + 1].size {
			mut lo := by_size[j].idx
			mut hi := by_size[j + 1].idx
			if lo > hi {
				lo, hi = hi, lo
			}
			lo_path := os.join_path(b.dir, b.seg_name(lo))
			return FoldPlan{
				gen:     b.gen
				lo_idx:  lo
				hi_idx:  hi
				lo_path: lo_path
				hi_path: os.join_path(b.dir, b.seg_name(hi))
				// distinct from flush_segment's '.tmp' — a fold must never
				// collide with a fresh segment landing at the same index
				// after a compaction reset abandons this plan.
				tmp:   lo_path + '.fold-tmp'
				keyed: b.keyed
			}
		}
	}
	return none
}

// fold_pending — true when at least one fold is due (the tier invariant is
// violated somewhere).
pub fn (b &PackObjectBackend) fold_pending() bool {
	if _ := b.fold_plan() {
		return true
	}
	return false
}

// generation — the backend's current segment-set generation (see FoldPlan.gen).
pub fn (b &PackObjectBackend) generation() u64 {
	return b.gen
}

// fold_perform executes a planned fold's file I/O: read both source packs,
// dedup by key, write the merged pack (fsynced) to the plan's temp path.
// Deliberately a FREE FUNCTION touching no backend state, so it is safe to run
// with no store lock held: the source segments are immutable once written and
// are only removed under the lock (by fold_commit or a compaction — after
// which fold_commit abandons this plan by generation). Returns the merged
// object count for fold_commit's bookkeeping.
pub fn fold_perform(plan FoldPlan) !int {
	mut entries := []KeyedPayload{}
	mut seen := map[string]bool{}
	for pp in [plan.lo_path, plan.hi_path] {
		reader := open_pack(pp) or {
			return error('cxpack segment ${pp} unreadable during fold: ${err.msg()}')
		}
		for h in reader.hashes() {
			hx := h.hex()
			if hx in seen {
				continue
			}
			payload := reader.get(h) or {
				reader.close()
				return error('cxpack ${pp}: object ${hx} unreadable during fold')
			}
			seen[hx] = true
			entries << KeyedPayload{
				key:  h.clone()
				blob: payload
			}
		}
		reader.close()
	}
	if plan.keyed {
		write_pack_keyed(plan.tmp, entries)!
	} else {
		write_pack(plan.tmp, entries.map(it.blob))!
	}
	return entries.len
}

// fold_commit installs a performed fold: atomic rename of the merged pack over
// the lower-indexed segment, removal of the higher one, and the segs
// bookkeeping. Returns false (abandoning the merged temp) when the plan's
// generation no longer matches — a compaction or reload replaced the whole
// segment set while the I/O ran, so the plan's sources are gone or belong to
// a different state. The both-present re-check is belt-and-braces: with one
// fold driver at a time and appends only ever appending, a same-generation
// plan's segments are still live.
pub fn (mut b PackObjectBackend) fold_commit(plan FoldPlan, merged int) !bool {
	if plan.gen != b.gen {
		os.rm(plan.tmp) or {}
		return false
	}
	mut lo_pos := -1
	mut hi_pos := -1
	for i, s in b.segs {
		if s.idx == plan.lo_idx {
			lo_pos = i
		} else if s.idx == plan.hi_idx {
			hi_pos = i
		}
	}
	if lo_pos < 0 || hi_pos < 0 {
		os.rm(plan.tmp) or {}
		return false
	}
	os.mv(plan.tmp, plan.lo_path) or {
		os.rm(plan.tmp) or {}
		return error('cxpack segment fold rename failed: ${err.msg()}')
	}
	os.rm(plan.hi_path) or {} // tolerated: duplicates dedup on load, next fold re-collapses
	b.segs[lo_pos] = SegInfo{
		idx:  plan.lo_idx
		size: merged
	}
	b.segs.delete(hi_pos)
	return true
}

// fold_drain runs every due fold to completion synchronously — the inline
// driver for single-threaded stores (no op-lock to coordinate a worker with),
// producing exactly the pre-#617 cascade.
pub fn (mut b PackObjectBackend) fold_drain() ! {
	for {
		plan := b.fold_plan() or { return }
		merged := fold_perform(plan)!
		b.fold_commit(plan, merged)!
	}
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
	for s in b.segs {
		os.rm(os.join_path(b.dir, b.seg_name(s.idx))) or {}
	}
	mut fl := map[string]bool{}
	for p in payloads {
		fl[object_name(p).hex()] = true
	}
	b.flushed = fl.move()
	b.segs = []
	b.next_seg = 0
	b.gen++ // segment set replaced — abandon any in-flight fold plan
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
	for s in b.segs {
		os.rm(os.join_path(b.dir, b.seg_name(s.idx))) or {}
	}
	mut fl := map[string]bool{}
	for e in entries {
		fl[e.key.hex()] = true
	}
	b.flushed = fl.move()
	b.segs = []
	b.next_seg = 0
	b.gen++ // segment set replaced — abandon any in-flight fold plan
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
	compacted := os.join_path(b.dir, pack_compacted_name)
	mut segs := []SegInfo{}
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
		mut n := 0
		for h in reader.hashes() {
			payload := reader.get(h) or {
				reader.close()
				return error('cxpack ${pp}: object ${h.hex()} unreadable')
			}
			hx := h.hex()
			out[hx] = payload
			fl[hx] = true
			n++
		}
		reader.close()
		if pp != compacted {
			segs << SegInfo{
				idx:  pack_seg_index(os.file_name(pp))
				size: n
			}
		}
	}
	b.flushed = fl.move()
	b.next_seg = max_seg + 1
	// #603: per-segment object counts feed the size-tiered fold. Discovery is
	// numeric-ordered, so `segs` is ascending by file index (gaps from #617
	// deferred folds included); duplicate objects across a crash-interrupted
	// fold pair are already deduped in `out`, and the next fold re-collapses.
	b.segs = segs
	b.gen++ // fresh segment set — abandon any in-flight fold plan
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
	return out
}

// seed_index primes the backend's durability state from the pack INDEXES
// alone — the hash list of every pack, never a payload byte (#637). It is
// what a demand-paged open needs: `flushed` (so a put skips an object
// already durable), `next_seg` (so a new segment never overwrites one on
// disk), the per-segment counts the size-tiered fold reads, and the
// generation. Cost is O(objects) index entries rather than O(bytes), and
// nothing is materialized into memory.
//
// The same keyed↔plaintext mode check load_objects performs applies here: a
// mode mismatch is a HARD error at open, never a silently mixed store.
pub fn (mut b PackObjectBackend) seed_index() ! {
	// A background fold (#617) deletes segment packs AFTER writing the folded
	// pack, so a segment can legitimately vanish between discovery and open.
	// Re-discover once and rescan; a path still listed and still unreadable on
	// the second pass is genuine corruption and fails hard.
	b.seed_index_scan() or { return b.seed_index_scan() }
}

fn (mut b PackObjectBackend) seed_index_scan() ! {
	paths, max_seg := b.discover_packs()
	mut fl := map[string]bool{}
	compacted := os.join_path(b.dir, pack_compacted_name)
	mut segs := []SegInfo{}
	for pp in paths {
		reader := open_pack(pp) or { return error('cxpack pack ${pp} unreadable: ${err.msg()}') }
		if reader.keyed && !b.keyed {
			reader.close()
			return error('cxpack pack ${pp} is keyed (encrypted at rest) — reopen the store with its encrypt-key-id')
		}
		if !reader.keyed && b.keyed {
			reader.close()
			return error('cxpack pack ${pp} is not keyed (plaintext at rest) — encrypt-key-id was given for an unencrypted store; encryption cannot be enabled on existing data in place')
		}
		mut n := 0
		for h in reader.hashes() {
			fl[h.hex()] = true
			n++
		}
		reader.close()
		if pp != compacted {
			segs << SegInfo{
				idx:  pack_seg_index(os.file_name(pp))
				size: n
			}
		}
	}
	b.flushed = fl.move()
	b.next_seg = max_seg + 1
	b.segs = segs
	b.gen++
	b.pending = []KeyedPayload{}
	b.pending_set = map[string]bool{}
}
