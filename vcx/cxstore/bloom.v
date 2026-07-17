module cxstore

// Standard Bloom filter over 32-byte content hashes (object_model.md §9,
// pack_format.md footer; issue #84). Keys are already uniform (SHA-256
// digests), so bit positions come from Kirsch–Mitzenmacher double hashing over
// two 64-bit words of the digest — no separate hash family needed. The filter
// has NO false negatives (a stored key always tests present); false positives
// are bounded by m (bits) and k (probes). It is a derived accelerator only —
// the footer index remains authoritative; "maybe present" is always confirmed
// by a real lookup, and the engine works with the bloom absent.

pub struct Bloom {
pub mut:
	bits   []u8
	m_log2 u32 // bit count = 1 << m_log2 (power of two → mask, no modulo)
	k      u8
}

// bloom_for sizes a filter for n keys at ~1% target FPR (m ≈ 10n bits, k = 7).
fn bloom_for(n int) Bloom {
	bits_wanted := if n < 1 { 64 } else { n * 10 }
	mut log2 := u32(6) // floor: 64 bits
	for (u64(1) << log2) < u64(bits_wanted) {
		log2++
	}
	m := u64(1) << log2
	return Bloom{
		bits:   []u8{len: int(m / 8), init: 0}
		m_log2: log2
		k:      7
	}
}

@[inline]
fn bloom_pos(hash []u8, i int, m_log2 u32) u64 {
	mask := (u64(1) << m_log2) - 1
	h1 := read_u64(hash, 0)
	h2 := read_u64(hash, 8)
	return (h1 + u64(i) * h2) & mask
}

fn (mut b Bloom) add(hash []u8) {
	for i in 0 .. int(b.k) {
		pos := bloom_pos(hash, i, b.m_log2)
		b.bits[pos >> 3] |= u8(1) << (pos & 7)
	}
}

// maybe_has returns false only if the key is DEFINITELY absent. With no bloom
// loaded (bits empty) it conservatively returns true (cannot rule out).
pub fn (b &Bloom) maybe_has(hash []u8) bool {
	if b.bits.len == 0 {
		return true
	}
	for i in 0 .. int(b.k) {
		pos := bloom_pos(hash, i, b.m_log2)
		if (b.bits[pos >> 3] & (u8(1) << (pos & 7))) == 0 {
			return false
		}
	}
	return true
}

fn build_bloom(hashes [][]u8) Bloom {
	mut b := bloom_for(hashes.len)
	for h in hashes {
		b.add(h)
	}
	return b
}
