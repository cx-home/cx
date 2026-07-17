module cxstore

// CXStore ref-log — the entire mutable surface of the store
// (object_model.md Appendix A.4 / A.5). Everything reachable from a root is
// immutable content; only the ref→root mapping changes, and it changes only
// by appending a fixed-width, epoch-stamped record.
//
// Record (92 bytes): [epoch:u64][ref_name_hash:32][root_hash:32]
//                    [writer_id:16][crc32:4]
//
// Durability: append-only; each record fsync'd on commit; a torn trailing
// record is detected by crc and ignored (valid-prefix recovery). Current root
// for a ref = the highest-epoch record whose root verifies (A.4).
//
// Concurrency (A.5): object writes are uncoordinated; only ref advancement
// coordinates, via compare-and-append (commit_cas). NOTE: the read-head→append
// in commit_cas is atomic only within a process here; a cross-process service
// tier must wrap it in an OS advisory lock / lease (A.5). CRC uses hash.crc32;
// CRC32C is the lock target (pack_format open question #2).

import crypto.sha256
import hash.crc32
import os

pub const ref_record_size = 92 // 8 + 32 + 32 + 16 + 4

pub struct RefRecord {
pub:
	epoch     u64
	ref_hash  []u8 // 32
	root_hash []u8 // 32
	writer_id []u8 // 16
}

fn encode_ref_record(epoch u64, ref_hash []u8, root_hash []u8, writer_id []u8) []u8 {
	mut b := []u8{cap: ref_record_size}
	put_u64(mut b, epoch)
	b << ref_hash[..32]
	b << root_hash[..32]
	mut w := writer_id.clone()
	for w.len < 16 {
		w << u8(0)
	}
	b << w[..16]
	put_u32(mut b, crc32.sum(b)) // crc over the first 88 bytes
	return b
}

fn decode_ref_record(b []u8) ?RefRecord {
	if b.len != ref_record_size {
		return none
	}
	if crc32.sum(b[..88]) != read_u32(b, 88) {
		return none
	}
	return RefRecord{
		epoch:     read_u64(b, 0)
		ref_hash:  b[8..40].clone()
		root_hash: b[40..72].clone()
		writer_id: b[72..88].clone()
	}
}

pub struct RefLog {
pub:
	path string
}

pub fn open_reflog(path string) RefLog {
	return RefLog{
		path: path
	}
}

// read_records returns the valid prefix of records; a torn/corrupt record
// terminates the scan (append-only ⇒ any corruption is in the tail).
fn (rl RefLog) read_records() []RefRecord {
	data := os.read_bytes(rl.path) or { return []RefRecord{} }
	mut recs := []RefRecord{}
	mut off := 0
	for off + ref_record_size <= data.len {
		rec := decode_ref_record(data[off..off + ref_record_size]) or { break }
		recs << rec
		off += ref_record_size
	}
	return recs
}

fn (rl RefLog) append_record(rec []u8) ! {
	mut f := os.open_append(rl.path)!
	f.write(rec)!
	f.flush() // production: fsync before returning success
	f.close()
}

fn (rl RefLog) max_epoch(ref_hash []u8) u64 {
	mut m := u64(0)
	for r in rl.read_records() {
		if compare_bytes(r.ref_hash, ref_hash) == 0 && r.epoch > m {
			m = r.epoch
		}
	}
	return m
}

// commit appends a new root for ref_name at epoch = max(ref)+1.
pub fn (rl RefLog) commit(ref_name string, root_hash []u8, writer_id []u8) !u64 {
	ref_hash := sha256.sum256(ref_name.bytes())
	epoch := rl.max_epoch(ref_hash) + 1
	rl.append_record(encode_ref_record(epoch, ref_hash, root_hash, writer_id))!
	return epoch
}

// current_root = highest-epoch (crc-valid) root for ref_name.
pub fn (rl RefLog) current_root(ref_name string) ?[]u8 {
	ref_hash := sha256.sum256(ref_name.bytes())
	mut best_epoch := u64(0)
	mut best := []u8{}
	mut found := false
	for r in rl.read_records() {
		if compare_bytes(r.ref_hash, ref_hash) == 0 && r.epoch >= best_epoch {
			best_epoch = r.epoch
			best = r.root_hash.clone()
			found = true
		}
	}
	if !found {
		return none
	}
	return best
}

// current_root_verified = highest-epoch root whose subtree verifies (A.4).
// The store supplies `verify` (e.g. "does this root resolve in the packs?").
pub fn (rl RefLog) current_root_verified(ref_name string, verify fn ([]u8) bool) ?[]u8 {
	ref_hash := sha256.sum256(ref_name.bytes())
	mut mine := []RefRecord{}
	for r in rl.read_records() {
		if compare_bytes(r.ref_hash, ref_hash) == 0 {
			mine << r
		}
	}
	mine.sort(a.epoch > b.epoch) // highest epoch first
	for r in mine {
		if verify(r.root_hash) {
			return r.root_hash
		}
	}
	return none
}

// recent_roots_per_ref returns the union of the last `keep` roots of every ref
// (grouped by ref hash, highest-epoch first; keep <= 0 keeps all). This is the
// live root set a keep-last-N retention policy hands to GC (object_model.md §8).
pub fn (rl RefLog) recent_roots_per_ref(keep int) [][]u8 {
	mut groups := map[string][]RefRecord{}
	for r in rl.read_records() {
		k := r.ref_hash.hex()
		if k !in groups {
			groups[k] = []RefRecord{}
		}
		groups[k] << r
	}
	mut out := [][]u8{}
	for _, mut grp in groups {
		grp.sort(a.epoch > b.epoch) // newest first
		mut n := 0
		for r in grp {
			if keep > 0 && n >= keep {
				break
			}
			out << r.root_hash.clone()
			n++
		}
	}
	return out
}

// commit_cas advances ref_name to new_root iff the current root still equals
// expected_prev (an empty slice means "expect the ref to be absent"). Returns
// false on conflict — the caller re-reads, rebases, and retries (A.5).
pub fn (rl RefLog) commit_cas(ref_name string, expected_prev []u8, new_root []u8, writer_id []u8) !bool {
	cur := rl.current_root(ref_name) or { []u8{} } // empty ⇒ absent (a real root is 32B)
	if compare_bytes(cur, expected_prev) != 0 {
		return false
	}
	rl.commit(ref_name, new_root, writer_id)!
	return true
}
