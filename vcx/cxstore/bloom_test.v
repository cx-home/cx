module cxstore

// The Bloom data structure stays live as the reader for legacy (filter_kind == 0)
// packs; new packs write the xor8 filter (see xorfilter_test.v for the pack
// round-trip + back-compat). Bloom must never give a false negative (every added
// key tests present) and must keep false positives low.
fn test_bloom_no_false_negatives_and_low_fpr() {
	n := 2000
	mut hashes := [][]u8{cap: n}
	for i in 0 .. n {
		hashes << object_name('bloom-doc-${i}'.bytes())
	}
	b := build_bloom(hashes)
	assert b.bits.len > 0
	assert b.k == 7

	// no false negatives: every added key tests present
	for h in hashes {
		assert b.maybe_has(h), 'false negative for stored key'
	}

	// false-positive rate on absent keys
	mut fp := 0
	trials := 5000
	for i in 0 .. trials {
		h := object_name('bloom-absent-${i}'.bytes())
		if b.maybe_has(h) {
			fp++
		}
	}
	// design target ~1%; assert comfortably under 5%
	assert fp * 100 / trials < 5, 'FPR too high: ${fp}/${trials}'
}

// A pack with no bloom (or empty) must still resolve via the index (the bloom
// is only an accelerator) — exercised by an empty-payload edge.
fn test_bloom_absent_is_conservative() {
	mut b := Bloom{}
	// empty bloom (no bits) cannot rule anything out
	assert b.maybe_has(object_name('x'.bytes()))
}
