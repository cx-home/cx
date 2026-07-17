module cxstore

import os

fn tmp_pack(name string) string {
	return os.join_path(os.temp_dir(), name)
}

fn test_pack_roundtrip_and_dedup() {
	path := tmp_pack('cxstore_pack_rt.cxpack')
	os.rm(path) or {}
	payloads := [
		'hello'.bytes(),
		'world'.bytes(),
		'cx content-addressed object'.bytes(),
		'hello'.bytes(), // duplicate → logical dedup
	]
	write_pack(path, payloads) or {
		assert false, 'write_pack failed: ${err}'
		return
	}
	r := open_pack(path) or {
		assert false, 'open_pack failed: ${err}'
		return
	}
	// duplicate collapsed → 3 unique objects
	assert r.count == 3

	uniques := [
		'hello'.bytes(),
		'world'.bytes(),
		'cx content-addressed object'.bytes(),
	]
	for p in uniques {
		h := object_name(p)
		got := r.get(h) or {
			assert false, 'missing object ${p.bytestr()}'
			return
		}
		assert got == p
		assert r.has(h)
	}

	// unknown hash → none
	unknown := object_name('not stored'.bytes())
	if _ := r.get(unknown) {
		assert false, 'unexpected hit for absent hash'
	}
	assert !r.has(unknown)

	os.rm(path) or {}
}

fn test_object_name_is_stable_and_distinct() {
	a1 := object_name('payload-A'.bytes())
	a2 := object_name('payload-A'.bytes())
	b := object_name('payload-B'.bytes())
	assert a1.len == 32
	assert a1.hex() == a2.hex() // deterministic
	assert a1.hex() != b.hex() // collision-free for distinct content
}

fn test_corrupt_header_rejected() {
	path := tmp_pack('cxstore_pack_corrupt.cxpack')
	os.rm(path) or {}
	write_pack(path, ['x'.bytes()]) or {
		assert false, 'write_pack failed: ${err}'
		return
	}
	mut data := os.read_bytes(path) or {
		assert false, 'read failed'
		return
	}
	// flip a byte inside the header (version field) → header crc must fail
	data[8] = data[8] ^ 0xFF
	os.write_file_array(path, data) or {
		assert false, 'rewrite failed'
		return
	}
	if _ := open_pack(path) {
		assert false, 'corrupt header was not rejected'
	}
	os.rm(path) or {}
}

fn test_truncated_file_rejected() {
	path := tmp_pack('cxstore_pack_trunc.cxpack')
	os.rm(path) or {}
	write_pack(path, ['alpha'.bytes(), 'beta'.bytes()]) or {
		assert false, 'write_pack failed: ${err}'
		return
	}
	mut data := os.read_bytes(path) or {
		assert false, 'read failed'
		return
	}
	// drop the trailing footer-length suffix → must be rejected cleanly
	truncated := data[..data.len - 12].clone()
	os.write_file_array(path, truncated) or {
		assert false, 'rewrite failed'
		return
	}
	if _ := open_pack(path) {
		assert false, 'truncated pack was not rejected'
	}
	os.rm(path) or {}
}
