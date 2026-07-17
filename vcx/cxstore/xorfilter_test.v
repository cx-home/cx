module cxstore

import os

// The xor8 filter must never give a false negative (every key in the build set
// tests present), keep false positives well under the Bloom's, and be smaller.
fn test_xor_no_false_negatives_low_fpr_and_smaller() {
	n := 2000
	mut hashes := [][]u8{cap: n}
	for i in 0 .. n {
		hashes << object_name('xor-doc-${i}'.bytes())
	}
	f := build_xor_filter(hashes)
	assert f.fingerprints.len > 0, 'filter not built'
	assert f.fingerprints.len == int(f.block_len) * 3

	// no false negatives
	for h in hashes {
		assert f.maybe_has(h), 'false negative for a built key'
	}

	// false-positive rate on absent keys — design ≈0.4%, assert under 2%
	mut fp := 0
	trials := 20000
	for i in 0 .. trials {
		h := object_name('xor-absent-${i}'.bytes())
		if f.maybe_has(h) {
			fp++
		}
	}
	assert fp * 1000 / trials < 20, 'xor FPR too high: ${fp}/${trials}'

	// size win: xor8 ≈ 1.23 B/key beats the Bloom's 10 bits/key (≈1.25 B/key) AND
	// at a lower FPR. Compare the raw filter byte sizes for the same key set.
	b := build_bloom(hashes)
	assert f.fingerprints.len < b.bits.len, 'xor (${f.fingerprints.len} B) must be smaller than bloom (${b.bits.len} B)'
}

// Empty key set → empty filter that cannot rule anything out (the index stays
// authoritative), exactly like an absent Bloom.
fn test_xor_empty_is_conservative() {
	f := build_xor_filter([][]u8{})
	assert f.fingerprints.len == 0
	assert f.maybe_has(object_name('x'.bytes()))
}

// A freshly-written pack carries an xor8 footer (filter_kind == 1): the reader
// populates r.xor (not r.bloom), gives no false negatives, and never invents a
// hit — every resolution still goes through the authoritative index.
fn test_pack_writes_and_reads_xor_footer() {
	path := os.join_path(os.temp_dir(), 'cxstore_xor.cxpack')
	os.rm(path) or {}
	n := 1500
	mut payloads := [][]u8{cap: n}
	for i in 0 .. n {
		payloads << 'xor-pack-doc-${i}'.bytes()
	}
	write_pack(path, payloads) or {
		assert false, 'write: ${err}'
		return
	}
	r := open_pack(path) or {
		assert false, 'open: ${err}'
		return
	}
	defer {
		r.close()
		os.rm(path) or {}
	}
	assert r.xor.fingerprints.len > 0, 'footer must carry an xor filter'
	assert r.bloom.bits.len == 0, 'a kind-1 pack must not populate the bloom'

	for p in payloads {
		h := object_name(p)
		assert r.maybe_has(h), 'false negative for a stored key'
		assert r.get(h) != none, 'stored object must resolve'
	}
	for i in 0 .. 4000 {
		h := object_name('xor-pack-absent-${i}'.bytes())
		assert r.get(h) == none, 'the filter must not invent a hit'
	}
}

// Back-compat: a legacy bloom-footer pack (filter_kind == 0) still opens and
// resolves through the kind-dispatching reader — proving the old read path stays
// live, not dead code.
fn test_pack_reads_legacy_bloom_footer() {
	path := os.join_path(os.temp_dir(), 'cxstore_legacy_bloom.cxpack')
	os.rm(path) or {}
	n := 800
	mut payloads := [][]u8{cap: n}
	for i in 0 .. n {
		payloads << 'legacy-doc-${i}'.bytes()
	}
	write_pack_kind(path, payloads, false, pack_filter_kind_bloom) or {
		assert false, 'write legacy: ${err}'
		return
	}
	r := open_pack(path) or {
		assert false, 'open legacy: ${err}'
		return
	}
	defer {
		r.close()
		os.rm(path) or {}
	}
	assert r.bloom.bits.len > 0, 'legacy footer must populate the bloom'
	assert r.xor.fingerprints.len == 0, 'a kind-0 pack must not populate the xor'
	for p in payloads {
		h := object_name(p)
		assert r.maybe_has(h), 'false negative reading a legacy bloom pack'
		assert r.get(h) != none, 'legacy-stored object must resolve'
	}
	assert r.get(object_name('legacy-absent'.bytes())) == none
}
