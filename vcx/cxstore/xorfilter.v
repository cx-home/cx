module cxstore

// XorFilter — an immutable xor8 membership filter (Graf & Lemire, "Xor Filters",
// 2019) over 32-byte content hashes. It holds ~1.23 bytes/key at a ≈0.4%
// false-positive rate — markedly smaller than the standard Bloom (bloom.v: 10
// bits/key ≈ 1.25 bytes at ~1% FPR) AND a lower FPR — with NO false negatives.
//
// An xor filter is built ONCE from the COMPLETE key set; unlike a Bloom it
// cannot accept incremental adds (the fingerprints are solved as a system over
// the whole set). That constraint is exactly why its home is the sealed,
// immutable pack footer (object_model.md §9, pack_format.md; issue #84) and NOT
// a mutable backend — a pack's object set is fixed the moment it is written.
//
// Construction is DETERMINISTIC: build seeds are tried 1, 2, 3, … until the
// 3-segment hypergraph peels cleanly, so a pack's filter is fully reproducible
// from its key set (no RNG → content-addressed packs stay bit-stable). Like the
// Bloom it is a derived accelerator only: "maybe present" is ALWAYS confirmed by
// the authoritative footer index, and the engine works correctly with the filter
// absent (maybe_has → true when empty).

pub struct XorFilter {
pub mut:
	seed         u64
	block_len    u32  // each of the 3 segments holds block_len fingerprints
	fingerprints []u8 // length = 3 * block_len
}

@[inline]
fn xor_rotl64(x u64, n int) u64 {
	return (x << u32(n)) | (x >> u32(64 - n))
}

// xor_mix folds a 32-byte content hash into one 64-bit word under `seed`. The
// keys are already uniform SHA-256 digests, so a SplitMix-style avalanche over
// three digest words yields independent slot placements as the seed varies.
@[inline]
fn xor_mix(hash []u8, seed u64) u64 {
	mut h := seed + 0x9E3779B97F4A7C15
	h ^= read_u64(hash, 0)
	h *= 0xBF58476D1CE4E5B9
	h ^= read_u64(hash, 8)
	h ^= h >> 31
	h *= 0x94D049BB133111EB
	h ^= read_u64(hash, 16) // SHA-256 is 32 bytes — offset 16 is in-bounds
	h ^= h >> 29
	return h
}

@[inline]
fn xor_reduce(x u32, n u32) u32 {
	// Lemire fast range-reduction: map x∈[0,2^32) into [0,n) without modulo.
	return u32((u64(x) * u64(n)) >> 32)
}

@[inline]
fn xor_fp(h u64) u8 {
	return u8(h ^ (h >> 8) ^ (h >> 16) ^ (h >> 24))
}

// xor_slots_of derives the three segment slots a folded hash maps to. Each slot
// lives in its own disjoint segment (so the three are always distinct).
@[inline]
fn xor_slots_of(h u64, block_len u32) (u32, u32, u32) {
	r0 := u32(h)
	r1 := u32(xor_rotl64(h, 21))
	r2 := u32(xor_rotl64(h, 42))
	s0 := xor_reduce(r0, block_len)
	s1 := xor_reduce(r1, block_len) + block_len
	s2 := xor_reduce(r2, block_len) + 2 * block_len
	return s0, s1, s2
}

// maybe_has returns false only if the key is DEFINITELY absent. With no filter
// loaded (fingerprints empty) it conservatively returns true (cannot rule out),
// exactly like Bloom.maybe_has — so a filter-less pack still works.
pub fn (f &XorFilter) maybe_has(hash []u8) bool {
	if f.fingerprints.len == 0 {
		return true
	}
	h := xor_mix(hash, f.seed)
	s0, s1, s2 := xor_slots_of(h, f.block_len)
	return (f.fingerprints[s0] ^ f.fingerprints[s1] ^ f.fingerprints[s2]) == xor_fp(h)
}

// build_xor_filter constructs a filter holding every key in `hashes`. It tries
// deterministic seeds until the mapping hypergraph peels cleanly (every key gets
// a slot referenced by it alone at peel time), then back-fills fingerprints so
// each key's three slots XOR to its fingerprint. An empty set yields an empty
// filter (maybe_has → true, harmless — callers confirm via the index).
fn build_xor_filter(hashes [][]u8) XorFilter {
	n := hashes.len
	if n == 0 {
		return XorFilter{}
	}
	// capacity ≈ 1.23·n + 32 (the +32 slack lets small sets peel), split into 3
	// equal segments.
	capacity := u32(1.23 * f64(n)) + 32
	mut block_len := capacity / 3
	if block_len < 1 {
		block_len = 1
	}
	size := int(block_len) * 3

	// Seed search. 1.23·n virtually always peels on the first seed; the loop is a
	// correctness backstop, not a hot path.
	for seed := u64(1); seed < 10000; seed++ {
		mut count := []u32{len: size}
		mut xorh := []u64{len: size}
		for i in 0 .. n {
			h := xor_mix(hashes[i], seed)
			s0, s1, s2 := xor_slots_of(h, block_len)
			count[s0]++
			xorh[s0] ^= h
			count[s1]++
			xorh[s1] ^= h
			count[s2]++
			xorh[s2] ^= h
		}
		// Peel: repeatedly take a slot referenced by exactly one (remaining) key,
		// record it, and remove that key from its other two slots.
		mut queue := []u32{}
		for i in 0 .. size {
			if count[i] == 1 {
				queue << u32(i)
			}
		}
		mut stack_slot := []u32{cap: n}
		mut stack_hash := []u64{cap: n}
		for queue.len > 0 {
			i := queue.last()
			queue.delete_last()
			if count[i] != 1 {
				continue // stale queue entry — the slot changed after enqueue
			}
			h := xorh[i]
			stack_slot << i
			stack_hash << h
			s0, s1, s2 := xor_slots_of(h, block_len)
			for s in [s0, s1, s2] {
				count[s]--
				xorh[s] ^= h
				if count[s] == 1 {
					queue << s
				}
			}
		}
		if stack_slot.len != n {
			continue // hypergraph had a 2-core — try the next seed
		}
		// Assign fingerprints in REVERSE peel order: when slot i is filled, the
		// other two slots of its key are already final, so their XOR is known.
		mut fps := []u8{len: size}
		for k := stack_slot.len - 1; k >= 0; k-- {
			i := stack_slot[k]
			h := stack_hash[k]
			s0, s1, s2 := xor_slots_of(h, block_len)
			mut val := xor_fp(h)
			if s0 != i {
				val ^= fps[s0]
			}
			if s1 != i {
				val ^= fps[s1]
			}
			if s2 != i {
				val ^= fps[s2]
			}
			fps[i] = val
		}
		return XorFilter{
			seed:         seed
			block_len:    block_len
			fingerprints: fps
		}
	}
	// Astronomically unlikely with 1.23·n+32 sizing; degrade to no filter (the
	// index remains authoritative) rather than ship a wrong one.
	return XorFilter{}
}
