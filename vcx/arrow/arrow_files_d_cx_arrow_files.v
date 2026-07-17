module arrow

// Phase C — Parquet + Arrow IPC (Feather v2) file I/O. Gated `-d cx_arrow_files`,
// so the base Arrow C-Data ABI lib stays dependency-free; with the flag, this
// links libarrow / libparquet + the C++ shim (shim/cx_arrow_shim.cc → the
// Makefile builds target/libcx_arrow_shim.a). File I/O reuses the existing
// data_bin ↔ ArrowArrayStream bridge, so no columnar logic is duplicated:
//
//   write: data_bin → export_populate_stream_bytes → C-Data stream → shim → file
//   read:  file → shim → C-Data stream → import_drain_to_bytes → data_bin

#flag -I@VMODROOT/arrow/shim
#flag @VMODROOT/target/libcx_arrow_shim.a
#include "cx_arrow_shim.h"
$if $pkgconfig('arrow') {
	#pkgconfig --cflags --libs arrow
}
$if $pkgconfig('parquet') {
	#pkgconfig --cflags --libs parquet
}
#flag darwin -lc++
#flag linux -lstdc++

fn C.cx_pq_write_stream(stream_in voidptr, path &char, err_out &&char) int
fn C.cx_pq_read_stream(path &char, stream_out voidptr, err_out &&char) int
fn C.cx_ipc_write_stream(stream_in voidptr, path &char, err_out &&char) int
fn C.cx_ipc_read_stream(path &char, stream_out voidptr, err_out &&char) int

// ── C ABI for runtime dlopen (the Arrow-free cx CLI loads these) ──────

fn file_err_int(err_out &&char, msg string) int {
	if err_out != unsafe { nil } {
		unsafe {
			*err_out = c_string(msg)
		}
	}
	return 1
}

fn file_err_ptr(err_out &&char, msg string) &u8 {
	if err_out != unsafe { nil } {
		unsafe {
			*err_out = c_string(msg)
		}
	}
	return unsafe { nil }
}

// cx_arrow_write_table_file writes framed CXCol data_bin bytes to a Parquet
// ('parquet') or Arrow IPC ('arrow') file. 0 = ok; non-zero sets *err_out.
@[export: 'cx_arrow_write_table_file']
pub fn cx_arrow_write_table_file(fmt &char, data &u8, data_len int, path &char, err_out &&char) int {
	f := unsafe { cstring_to_vstring(fmt) }
	p := unsafe { cstring_to_vstring(path) }
	bytes := unsafe { data.vbytes(data_len) }
	match f {
		'parquet' { write_parquet_data_bin(bytes, p) or { return file_err_int(err_out, err.msg()) } }
		'arrow' { write_ipc_data_bin(bytes, p) or { return file_err_int(err_out, err.msg()) } }
		else { return file_err_int(err_out, 'unknown arrow file format: ${f}') }
	}
	return 0
}

// cx_arrow_read_table_file reads a Parquet/Arrow IPC file into framed CXCol
// data_bin bytes (malloc'd; caller frees via cx_arrow_free, length in *out_len).
// Returns NULL with *err_out set on failure.
@[export: 'cx_arrow_read_table_file']
pub fn cx_arrow_read_table_file(fmt &char, path &char, out_len &int, err_out &&char) &u8 {
	f := unsafe { cstring_to_vstring(fmt) }
	p := unsafe { cstring_to_vstring(path) }
	mut bytes := []u8{}
	match f {
		'parquet' { bytes = read_parquet_to_data_bin(p) or { return file_err_ptr(err_out, err.msg()) } }
		'arrow' { bytes = read_ipc_to_data_bin(p) or { return file_err_ptr(err_out, err.msg()) } }
		else { return file_err_ptr(err_out, 'unknown arrow file format: ${f}') }
	}
	buf := unsafe { malloc(bytes.len) }
	unsafe {
		vmemcpy(buf, bytes.data, bytes.len)
		*out_len = bytes.len
	}
	return unsafe { &u8(buf) }
}

fn shim_take_err(errp &char) string {
	if errp == unsafe { nil } {
		return 'unknown arrow file error'
	}
	msg := unsafe { cstring_to_vstring(errp) }
	unsafe { free(voidptr(errp)) }
	return msg
}

// write_parquet_data_bin writes framed CXCol data_bin bytes to a Parquet file.
pub fn write_parquet_data_bin(framed []u8, path string) ! {
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), framed)!
	mut errp := &char(unsafe { nil })
	rc := C.cx_pq_write_stream(voidptr(stream), &char(path.str), &errp)
	unsafe { free(voidptr(stream)) }
	if rc != 0 {
		return error(shim_take_err(errp))
	}
}

// read_parquet_to_data_bin reads a Parquet file into framed CXCol data_bin bytes.
pub fn read_parquet_to_data_bin(path string) ![]u8 {
	stream := alloc_zero_arrow_stream()
	mut errp := &char(unsafe { nil })
	rc := C.cx_pq_read_stream(&char(path.str), voidptr(stream), &errp)
	if rc != 0 {
		unsafe { free(voidptr(stream)) }
		return error(shim_take_err(errp))
	}
	out := import_drain_to_bytes(voidptr(stream)) or {
		unsafe { free(voidptr(stream)) }
		return err
	}
	unsafe { free(voidptr(stream)) }
	return out
}

// write_ipc_data_bin writes framed CXCol data_bin bytes to an Arrow IPC file.
pub fn write_ipc_data_bin(framed []u8, path string) ! {
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), framed)!
	mut errp := &char(unsafe { nil })
	rc := C.cx_ipc_write_stream(voidptr(stream), &char(path.str), &errp)
	unsafe { free(voidptr(stream)) }
	if rc != 0 {
		return error(shim_take_err(errp))
	}
}

// read_ipc_to_data_bin reads an Arrow IPC file into framed CXCol data_bin bytes.
pub fn read_ipc_to_data_bin(path string) ![]u8 {
	stream := alloc_zero_arrow_stream()
	mut errp := &char(unsafe { nil })
	rc := C.cx_ipc_read_stream(&char(path.str), voidptr(stream), &errp)
	if rc != 0 {
		unsafe { free(voidptr(stream)) }
		return error(shim_take_err(errp))
	}
	out := import_drain_to_bytes(voidptr(stream)) or {
		unsafe { free(voidptr(stream)) }
		return err
	}
	unsafe { free(voidptr(stream)) }
	return out
}
