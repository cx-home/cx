module cxstore

import os

// mmap-backed pack reader (POSIX; issue #88). open_pack reads the whole file
// into RAM via read_bytes; open_pack_mapped maps it instead, so large packs are
// not fully resident. The mapped bytes are wrapped as a `.nofree` []u8 view (V
// must not free the mapping) and released by PackReader.close() → munmap. Any
// failure falls back to open_pack, so callers always get a working reader.

#include <sys/mman.h>

fn C.munmap(addr voidptr, length usize) int

pub fn open_pack_mapped(path string) !PackReader {
	mut f := os.open(path) or { return open_pack(path) }
	size := os.file_size(path)
	if size == 0 {
		f.close()
		return open_pack(path)
	}
	ptr := unsafe { C.mmap(voidptr(0), usize(size), C.PROT_READ, C.MAP_PRIVATE, i32(f.fd), 0) }
	f.close()
	if isnil(ptr) || ptr == voidptr(C.MAP_FAILED) {
		return open_pack(path)
	}
	mut data := []u8{}
	unsafe {
		data.data = ptr
		data.len = int(size)
		data.cap = int(size)
		data.flags = .nofree // V must not free the mapping; munmap owns it
	}
	mut r := parse_pack(data) or {
		unsafe { C.munmap(ptr, usize(size)) }
		return err
	}
	r.map_ptr = ptr
	r.map_len = usize(size)
	return r
}

fn (r &PackReader) unmap() {
	if r.map_len > 0 {
		unsafe { C.munmap(r.map_ptr, r.map_len) }
	}
}
