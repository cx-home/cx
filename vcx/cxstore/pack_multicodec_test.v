module cxstore

import os
import cx

// I1 crypto-agility §4 (L34, row 3 binary slots): the formerly-reserved
// entry u16 (entry offset 6) is the multicodec code of the hash algorithm
// naming the 32-byte doc_hash slot. The engine implements sha2-256
// (multicodec 0x12 — the registry's required default); readers FAIL CLOSED
// on any other code, including the pre-epoch zero. All 1.0 algorithms are
// 32-byte; a non-32-byte digest requires pack v3.

fn mh_tmp_pack(name string) string {
	return os.join_path(os.temp_dir(), name)
}

// The pack-side constant must agree with THE ONE registry (cx.cx_hash_registry).
fn test_pack_hash_code_matches_the_one_registry() {
	a := cx.cx_hash_algo_by_name('sha2-256') or {
		assert false, 'sha2-256 missing from cx_hash_registry'
		return
	}
	assert u32(pack_hash_mh_code) == a.code
	assert a.dlen == 32
}

// walk_entry_codes reads the u16 multicodec slot of every indexed entry.
fn walk_entry_codes(data []u8) []u16 {
	flen := read_u64(data, data.len - 8)
	footer_start := data.len - 8 - int(flen)
	count := int(read_u32(data[footer_start..data.len - 8], 0))
	mut codes := []u16{cap: count}
	for i in 0 .. count {
		rec_off := footer_start + 4 + i * 44
		eoff := int(read_u64(data, rec_off + 32))
		codes << read_u16(data, eoff + 6)
	}
	return codes
}

fn test_entry_u16_carries_the_multicodec_code() {
	path := mh_tmp_pack('cxstore_pack_mh_code.cxpack')
	os.rm(path) or {}
	payloads := ['alpha'.bytes(), 'beta'.bytes(), 'gamma'.bytes()]
	write_pack(path, payloads) or {
		assert false, 'write_pack failed: ${err}'
		return
	}
	data := os.read_bytes(path) or {
		assert false, 'read failed: ${err}'
		return
	}
	codes := walk_entry_codes(data)
	assert codes.len == 3
	for c in codes {
		assert c == pack_hash_mh_code
	}
	// And the pack still opens + round-trips.
	r := open_pack(path) or {
		assert false, 'open_pack failed: ${err}'
		return
	}
	for p in payloads {
		got := r.get(object_name(p)) or {
			assert false, 'missing ${p.bytestr()}'
			return
		}
		assert got == p
	}
	os.rm(path) or {}
}

fn test_reader_fails_closed_on_unknown_code() {
	path := mh_tmp_pack('cxstore_pack_mh_badcode.cxpack')
	os.rm(path) or {}
	write_pack(path, ['payload'.bytes()]) or {
		assert false, 'write_pack failed: ${err}'
		return
	}
	mut data := os.read_bytes(path) or {
		assert false, 'read failed: ${err}'
		return
	}
	// Tamper the first entry's code slot to an unregistered value. The u16
	// is covered by no CRC (entry CRC covers stored payload bytes only), so
	// the reader's own validation is the only line of defense.
	data[header_size + 6] = 0x99
	data[header_size + 7] = 0x00
	os.write_file_array(path, data) or {
		assert false, 'rewrite failed: ${err}'
		return
	}
	if _ := open_pack(path) {
		assert false, 'open_pack accepted an unknown multicodec code'
	} else {
		assert err.msg().contains('unsupported hash multicodec'), 'wrong error: ${err.msg()}'
	}
	// The pre-epoch reserved zero is equally dead — fail loud, no dual-accept.
	data[header_size + 6] = 0x00
	os.write_file_array(path, data) or {
		assert false, 'rewrite failed: ${err}'
		return
	}
	if _ := open_pack(path) {
		assert false, 'open_pack accepted the pre-epoch zero code'
	} else {
		assert err.msg().contains('unsupported hash multicodec'), 'wrong error: ${err.msg()}'
	}
	os.rm(path) or {}
}

fn test_keyed_v2_pack_carries_the_code_and_fails_closed_the_same() {
	path := mh_tmp_pack('cxstore_pack_mh_keyed.cxpack')
	os.rm(path) or {}
	key := object_name('plaintext'.bytes()) // caller key = plaintext sha2-256 hash
	write_pack_keyed(path, [KeyedPayload{ key: key, blob: 'envelope-bytes'.bytes() }]) or {
		assert false, 'write_pack_keyed failed: ${err}'
		return
	}
	mut data := os.read_bytes(path) or {
		assert false, 'read failed: ${err}'
		return
	}
	codes := walk_entry_codes(data)
	assert codes.len == 1
	assert codes[0] == pack_hash_mh_code
	data[header_size + 6] = 0x1e // blake3: registered but unimplemented here
	os.write_file_array(path, data) or {
		assert false, 'rewrite failed: ${err}'
		return
	}
	if _ := open_pack(path) {
		assert false, 'open_pack accepted a code the engine does not implement'
	} else {
		assert err.msg().contains('unsupported hash multicodec'), 'wrong error: ${err.msg()}'
	}
	os.rm(path) or {}
}
