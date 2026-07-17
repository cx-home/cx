module cxstore

import os

// The mmap reader must return byte-identical results to the read_bytes reader.
fn test_open_pack_mapped_matches_read_bytes() {
	$if linux || macos {
		path := os.join_path(os.temp_dir(), 'cxstore_mmap.cxpack')
		os.rm(path) or {}
		mut payloads := [][]u8{cap: 500}
		for i in 0 .. 500 {
			payloads << 'mm-doc-${i}'.bytes()
		}
		write_pack(path, payloads) or {
			assert false, 'write: ${err}'
			return
		}
		rb := open_pack(path) or {
			assert false, 'open_pack: ${err}'
			return
		}
		mm := open_pack_mapped(path) or {
			assert false, 'open_pack_mapped: ${err}'
			return
		}
		assert mm.map_len > 0 // actually mmap-backed, not the read_bytes fallback
		assert mm.count == rb.count

		for p in payloads {
			h := object_name(p)
			a := rb.get(h) or {
				assert false, 'read_bytes miss'
				return
			}
			b := mm.get(h) or {
				assert false, 'mmap miss'
				return
			}
			assert a == b
			assert b == p
		}
		// absent key rejected (bloom + index) on the mapped reader too
		assert mm.get(object_name('mm-absent'.bytes())) == none

		mm.close() // munmap
		os.rm(path) or {}
	}
}
