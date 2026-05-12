module arrow

// libcx_arrow — separate optional library that bridges CXDB chunked
// tables ([`spec/data_bin.md §3.11`](../../spec/data_bin.md)) to the
// Apache Arrow C-Data ABI per ADR 0015 D9 / [`spec/abi.md §2.11`](../../spec/abi.md).
//
// Build target: `target/libcx_arrow.dylib` (macOS) / `.so` (Linux),
// produced by `make lib-arrow` in `vcx/Makefile`. The library
// statically pulls in the V `cx` module's chunked-table primitives;
// core libcx remains Arrow-free per the linkage plan in ADR 0015 D9.
//
// Capability bit 23 (`0x800000`) signals Arrow availability.
// Bindings dlopen `libcx_arrow` separately from `libcx`; on
// successful load, the binding sets bit 23 in its merged
// capability bitmask.
//
// v0.6.0 type set (Phase 7.74c-cont type-expansion): `int` / `i64`
// (Arrow `'l'`), `i8` (`'c'`), `i16` (`'s'`), `i32` (`'i'`), `float` /
// `f64` (`'g'`), `bool` (`'b'`, bit-packed), `string` (`'u'`, utf8
// with i32 offsets), `date` / `d` (`'tdD'`, days since 1970-01-01),
// `bytes` (`'z'`, binary with i32 offsets).
//
// Deferred — surface as `arrow: column type 'X' not yet supported in
// v0.6.0`: `datetime` (chunked-table strict-cell wire form pending),
// `decimal`, dictionary columns. Coverage tracked under
// Phase 7.74c-cont follow-ups.

// ── helpers (re-declared so libcx_arrow is independent of libcx's
// non-exported helpers) ──────────────────────────────────────────────

fn c_string(s string) &char {
	buf := unsafe { malloc(s.len + 1) }
	unsafe { vmemcpy(buf, s.str, s.len + 1) }
	return unsafe { &char(buf) }
}

fn c_err(msg string, err_out &&char) &char {
	if err_out != unsafe { nil } {
		unsafe { *err_out = c_string(msg) }
	}
	return unsafe { nil }
}

// ── memory ───────────────────────────────────────────────────────────

@[export: 'cx_arrow_free']
pub fn cx_arrow_free(s &char) {
	unsafe { free(voidptr(s)) }
}

// ── capability / version ─────────────────────────────────────────────

const cx_arrow_features_str = '0x800000'   // bit 23
const cx_arrow_version_str  = '0.6.0'

// cx_arrow_features returns the capability bitmask contributed by
// libcx_arrow as a NUL-terminated lowercase hex string. Bindings
// OR this into their merged-capability bitmask after a successful
// `dlopen(libcx_arrow)`. libcx itself does not advertise bit 23.
@[export: 'cx_arrow_features']
pub fn cx_arrow_features() &char {
	return c_string(cx_arrow_features_str)
}

// cx_arrow_version returns the libcx_arrow build version. Mirrors
// libcx's `cx_version` for a separate-library identity check.
@[export: 'cx_arrow_version']
pub fn cx_arrow_version() &char {
	return c_string(cx_arrow_version_str)
}

// ── 4 ADR-0015 D9 exports ────────────────────────────────────────────
//
// ABI shapes per spec/abi.md §2.11. `arrow_array_stream_*` parameters
// point at a caller-allocated `struct ArrowArrayStream` (Arrow C-Data
// ABI). On export, the function populates the struct with callback
// pointers + private_data; the consumer drains via get_next() and
// invokes release() when done. On import, the function consumes the
// stream (calling get_schema then get_next until exhaustion) and
// returns / writes the corresponding CXDB chunked-table.

// cx_arrow_export_open: framed-CXDB-bytes input → populated
// ArrowArrayStream.
//
// `data_bin` is a NUL-terminated C string carrying the framed
// `[u32 LE size][CXDB payload]` form. The CXDB payload MUST be a
// chunked-table (tag `0x63`, optionally wrapped in a single-pair
// map per emit_data_bin_chunked); other root tags surface an error.
//
// The function copies the input bytes into a heap buffer owned by
// the stream's private_data, so the caller may free `data_bin`
// immediately on return.
//
// Returns NULL on success (with arrow_array_stream_out populated)
// or NULL with err_out set on failure. The `success` indicator is
// the absence of err_out content; v0.6.0 follows libcx's
// "NULL = success or failure-distinguished-by-err_out" convention.
@[export: 'cx_arrow_export_open']
pub fn cx_arrow_export_open(data_bin &char, arrow_array_stream_out voidptr,
	err_out &&char) &char {
	if data_bin == unsafe { nil } {
		return c_err('cx_arrow_export_open: null data_bin', err_out)
	}
	if arrow_array_stream_out == unsafe { nil } {
		return c_err('cx_arrow_export_open: null arrow_array_stream_out', err_out)
	}
	bytes := framed_cstring_to_bytes(data_bin) or {
		return c_err('cx_arrow_export_open: ${err.msg()}', err_out)
	}
	export_populate_stream_bytes(arrow_array_stream_out, bytes) or {
		return c_err('cx_arrow_export_open: ${err.msg()}', err_out)
	}
	return unsafe { nil }
}

// cx_arrow_export_open_fd: open fd input → populated ArrowArrayStream.
//
// The fd MUST be positioned at the CXDB magic (no framing prefix —
// fd I/O does not use the [u32 LE size] envelope). Stream callbacks
// pull lazily; the caller MUST keep the fd open until release().
@[export: 'cx_arrow_export_open_fd']
pub fn cx_arrow_export_open_fd(fd int, arrow_array_stream_out voidptr,
	err_out &&char) &char {
	if arrow_array_stream_out == unsafe { nil } {
		return c_err('cx_arrow_export_open_fd: null arrow_array_stream_out', err_out)
	}
	if fd < 0 {
		return c_err('cx_arrow_export_open_fd: invalid fd', err_out)
	}
	export_populate_stream_fd(arrow_array_stream_out, fd) or {
		return c_err('cx_arrow_export_open_fd: ${err.msg()}', err_out)
	}
	return unsafe { nil }
}

// cx_arrow_import_to_data_bin: drain ArrowArrayStream → in-memory
// framed CXDB chunked-table bytes.
//
// Returns a heap-allocated NUL-terminated C string carrying the
// framed CXDB bytes. The caller MUST release with cx_arrow_free
// (or cx_free; both call libc free). Returns NULL on failure with
// err_out set.
@[export: 'cx_arrow_import_to_data_bin']
pub fn cx_arrow_import_to_data_bin(arrow_array_stream_in voidptr, err_out &&char) &char {
	if arrow_array_stream_in == unsafe { nil } {
		return c_err('cx_arrow_import_to_data_bin: null arrow_array_stream_in', err_out)
	}
	bytes := import_drain_to_bytes(arrow_array_stream_in) or {
		return c_err('cx_arrow_import_to_data_bin: ${err.msg()}', err_out)
	}
	return bytes_to_c_string(bytes)
}

// cx_arrow_import_to_data_bin_fd: drain ArrowArrayStream → CXDB
// chunked-table written to fd_out.
//
// Output on the fd does not carry the [u32 LE size] framing prefix
// (matching the streaming Table writer's fd convention). The fd is
// not closed by this function.
//
// Returns NULL on success with err_out unset; NULL with err_out set
// on failure.
@[export: 'cx_arrow_import_to_data_bin_fd']
pub fn cx_arrow_import_to_data_bin_fd(arrow_array_stream_in voidptr, fd_out int,
	err_out &&char) &char {
	if arrow_array_stream_in == unsafe { nil } {
		return c_err('cx_arrow_import_to_data_bin_fd: null arrow_array_stream_in', err_out)
	}
	if fd_out < 0 {
		return c_err('cx_arrow_import_to_data_bin_fd: invalid fd_out', err_out)
	}
	import_drain_to_fd(arrow_array_stream_in, fd_out) or {
		return c_err('cx_arrow_import_to_data_bin_fd: ${err.msg()}', err_out)
	}
	return unsafe { nil }
}

// ── helpers shared with arrow.v ──────────────────────────────────────

// framed_cstring_to_bytes copies a C string treated as the framed
// `[u32 LE size][payload]` form into a V byte slice. The CXDB payload
// may contain NUL bytes; we read the u32 LE size first and use that
// length, ignoring strlen semantics.
fn framed_cstring_to_bytes(cstr &char) ![]u8 {
	if cstr == unsafe { nil } {
		return error('null framed input')
	}
	header_ptr := unsafe { &u8(cstr) }
	size := u32(unsafe { header_ptr[0] }) | (u32(unsafe { header_ptr[1] }) << 8)
		| (u32(unsafe { header_ptr[2] }) << 16) | (u32(unsafe { header_ptr[3] }) << 24)
	total := int(size) + 4
	mut buf := []u8{len: total}
	unsafe { vmemcpy(buf.data, voidptr(header_ptr), total) }
	return buf
}

// bytes_to_c_string copies a V byte slice into a heap-allocated
// NUL-terminated C buffer. The framed CXDB bytes already contain
// their own length header; the trailing NUL is for C-string
// compatibility (consumers may strlen, which would stop at the
// first interior NUL — bindings unpack the [u32 LE size] header
// to get the true length, matching the libcx data_bin convention).
fn bytes_to_c_string(b []u8) &char {
	buf := unsafe { malloc(b.len + 1) }
	unsafe {
		vmemcpy(buf, b.data, b.len)
		(&u8(buf))[b.len] = 0
	}
	return unsafe { &char(buf) }
}
