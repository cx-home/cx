module cxstore

import os

// Compression must shrink the pack on disk and round-trip byte-identically;
// the doc_hash (over the original payload) still verifies after decompression.
fn test_compression_shrinks_and_roundtrips() {
	dir := os.temp_dir()
	raw := os.join_path(dir, 'cxstore_comp_raw.cxpack')
	comp := os.join_path(dir, 'cxstore_comp_z.cxpack')
	os.rm(raw) or {}
	os.rm(comp) or {}

	mut payloads := [][]u8{cap: 200}
	for i in 0 .. 200 {
		// highly compressible: long run of repeated bytes
		payloads << ('record-${i}-' + 'x'.repeat(300)).bytes()
	}
	write_pack(raw, payloads) or {
		assert false, 'raw write: ${err}'
		return
	}
	write_pack_opts(comp, payloads, true) or {
		assert false, 'compressed write: ${err}'
		return
	}

	rsz := os.file_size(raw)
	csz := os.file_size(comp)
	assert csz < rsz, 'compressed (${csz}) not smaller than raw (${rsz})'

	// every object round-trips byte-identically out of the compressed pack
	r := open_pack(comp) or {
		assert false, 'open compressed: ${err}'
		return
	}
	for p in payloads {
		got := r.get(object_name(p)) or {
			assert false, 'compressed miss'
			return
		}
		assert got == p
	}
	os.rm(raw) or {}
	os.rm(comp) or {}
}

// Payloads that do not shrink are stored raw and still round-trip.
fn test_incompressible_payloads_roundtrip() {
	path := os.join_path(os.temp_dir(), 'cxstore_comp_small.cxpack')
	os.rm(path) or {}
	payloads := ['x'.bytes(), 'ab'.bytes(), 'hello world'.bytes()]
	write_pack_opts(path, payloads, true) or {
		assert false, 'write: ${err}'
		return
	}
	r := open_pack(path) or {
		assert false, 'open: ${err}'
		return
	}
	for p in payloads {
		got := r.get(object_name(p)) or {
			assert false, 'miss ${p.bytestr()}'
			return
		}
		assert got == p
	}
	os.rm(path) or {}
}

// Compression composes with mmap reads.
fn test_compression_via_mmap() {
	$if linux || macos {
		path := os.join_path(os.temp_dir(), 'cxstore_comp_mmap.cxpack')
		os.rm(path) or {}
		mut payloads := [][]u8{cap: 100}
		for i in 0 .. 100 {
			payloads << ('e-${i}-' + 'y'.repeat(250)).bytes()
		}
		write_pack_opts(path, payloads, true) or {
			assert false, 'write: ${err}'
			return
		}
		mm := open_pack_mapped(path) or {
			assert false, 'mmap open: ${err}'
			return
		}
		for p in payloads {
			got := mm.get(object_name(p)) or {
				assert false, 'mmap miss'
				return
			}
			assert got == p
		}
		mm.close()
		os.rm(path) or {}
	}
}
