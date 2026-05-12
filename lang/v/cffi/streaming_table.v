module cffi

// Streaming Table reader / writer + schema-driven CXDB encoding +
// chunked-table one-shot for the V cffi binding.
//
// Per spec/abi.md §§2.10 / 2.12 (capability bits 21 / 24) and
// ADR 0015 D3 / D8. Phase 7.74b-cont-3.
//
// Wire conventions (mirroring the C ABI):
//   - `to_data_bin_chunked` returns UNFRAMED CXDB payload bytes,
//     matching the existing `xxx_to_data_bin` shape.
//   - `xxx_to_data_bin_schema_driven` returns UNFRAMED payload too.
//   - `from_data_bin_schema_driven` takes a FRAMED buffer.
//   - The streaming TableReader / TableWriter exchange FRAMED bytes
//     end-to-end (col-spec, row groups, output buffer) — this matches
//     the C ABI's pull/push shape and avoids re-framing on every step.
//   - fd variants of the streaming API operate on bare CXDB bytes.

// ── C declarations (21 symbols) ───────────────────────────────────────────────

fn C.cx_to_data_bin_chunked(input charptr, err_out &charptr) charptr

fn C.cx_table_reader_open(data_bin charptr, err_out &charptr) voidptr
fn C.cx_table_reader_open_fd(fd int, err_out &charptr) voidptr
fn C.cx_table_reader_schema(handle voidptr, err_out &charptr) charptr
fn C.cx_table_reader_next(handle voidptr, err_out &charptr) charptr
fn C.cx_table_reader_close(handle voidptr)

fn C.cx_table_writer_open(col_spec charptr, err_out &charptr) voidptr
fn C.cx_table_writer_open_fd(col_spec charptr, fd int, err_out &charptr) voidptr
fn C.cx_table_writer_emit_row_group(handle voidptr, row_group charptr, err_out &charptr) charptr
fn C.cx_table_writer_close_get_bytes(handle voidptr, err_out &charptr) charptr
fn C.cx_table_writer_close(handle voidptr)

fn C.cx_to_data_bin_schema_driven    (input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_xml_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_json_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_yaml_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_toml_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_md_to_data_bin_schema_driven (input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_csv_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_tsv_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_psv_to_data_bin_schema_driven(input charptr, schema charptr, ref_form int, name_hint charptr, err_out &charptr) charptr
fn C.cx_from_data_bin_schema_driven  (data_bin charptr, schema_hint charptr, err_out &charptr) charptr

// ── helpers ───────────────────────────────────────────────────────────────────

// read_framed_at copies a libcx-owned [u32 LE size][payload] buffer at
// `ptr` into a V-owned []u8 with the frame preserved. Caller frees `ptr`.
fn read_framed_at(ptr charptr) []u8 {
	mut size := u32(0)
	unsafe {
		p := &u8(ptr)
		size = u32(p[0]) | (u32(p[1]) << 8) | (u32(p[2]) << 16) | (u32(p[3]) << 24)
	}
	n := int(size) + 4
	mut buf := []u8{len: n}
	unsafe {
		vmemcpy(voidptr(buf.data), voidptr(ptr), n)
	}
	return buf
}

// strip_frame copies the payload portion of a libcx-owned framed buffer
// (frame stripped) into a V-owned []u8. Caller frees `ptr`.
fn strip_frame(ptr charptr) []u8 {
	mut size := u32(0)
	unsafe {
		p := &u8(ptr)
		size = u32(p[0]) | (u32(p[1]) << 8) | (u32(p[2]) << 16) | (u32(p[3]) << 24)
	}
	n := int(size)
	mut buf := []u8{len: n}
	unsafe {
		bp := &u8(ptr)
		vmemcpy(voidptr(buf.data), voidptr(&bp[4]), n)
	}
	return buf
}

// err_msg drains the err-out pointer into a string and frees the C-owned
// buffer. Returns `fallback` when err is nil.
fn err_msg(err charptr, fallback string) string {
	if err == charptr(0) {
		return fallback
	}
	s := unsafe { cstring_to_vstring(err) }
	C.cx_free(err)
	return s
}

// ── one-shot: chunked-table encoder ───────────────────────────────────────────

// Encode CX text whose root is a single :table-bodied element to CXDB
// chunked-table form (`0x63`). Returns UNFRAMED CXDB PAYLOAD bytes
// (matching the existing `xxx_to_data_bin` shape; frame stripped).
pub fn to_data_bin_chunked(input string) ![]u8 {
	mut err := charptr(0)
	out := C.cx_to_data_bin_chunked(charptr(input.str), &err)
	if out == charptr(0) {
		return error(err_msg(err, 'cx_to_data_bin_chunked: unknown error'))
	}
	buf := strip_frame(out)
	C.cx_free(out)
	return buf
}

// ── schema-driven loaders / dumper ────────────────────────────────────────────

// Schema reference embedding form for the schema-driven loaders.
pub enum SchemaRefForm as int {
	content_hash        = 0 // default (§3.13.1 tag 0x10)
	inline_schema       = 1 // inline schema bytes (tag 0x11)
	hash_with_name_hint = 2 // hash + name hint (tag 0x12)
}

type SchemaDrivenLoaderFn = fn (charptr, charptr, int, charptr, &charptr) charptr

fn call_schema_driven_loader(fn_ptr SchemaDrivenLoaderFn, input string, schema string,
                             ref_form SchemaRefForm, name_hint string) ![]u8 {
	mut err := charptr(0)
	out := fn_ptr(charptr(input.str), charptr(schema.str), int(ref_form),
	              charptr(name_hint.str), &err)
	if out == charptr(0) {
		return error(err_msg(err, 'cx_*_to_data_bin_schema_driven: unknown error'))
	}
	buf := strip_frame(out)
	C.cx_free(out)
	return buf
}

pub fn to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn xml_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_xml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn json_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_json_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn yaml_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_yaml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn toml_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_toml_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn md_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_md_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn csv_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_csv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn tsv_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_tsv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

pub fn psv_to_data_bin_schema_driven(input string, schema string, ref_form SchemaRefForm, name_hint string) ![]u8 {
	return call_schema_driven_loader(C.cx_psv_to_data_bin_schema_driven, input, schema, ref_form, name_hint)!
}

// Decode a FRAMED schema-driven CXDB buffer to canonical CX text.
// `schema_hint` is consulted when the embedded reference is
// content-hash-only and not resolvable from a content-addressable
// store; pass `''` to rely on embedded resolution alone.
pub fn from_data_bin_schema_driven(framed []u8, schema_hint string) !string {
	if framed.len == 0 {
		return error('cx_from_data_bin_schema_driven: empty input')
	}
	mut err := charptr(0)
	out := C.cx_from_data_bin_schema_driven(charptr(framed.data), charptr(schema_hint.str), &err)
	if out == charptr(0) {
		return error(err_msg(err, 'cx_from_data_bin_schema_driven: unknown error'))
	}
	s := unsafe { cstring_to_vstring(out) }
	C.cx_free(out)
	return s
}

// ── TableReader ───────────────────────────────────────────────────────────────

// Streaming reader over a chunked-table CXDB buffer or fd. Iterating
// via `next_row_group()` yields each row group as FRAMED `[u32 LE size]
// [plain body]` bytes (compressed groups are decompressed by the V core
// before return). V has no RAII / IDisposable: callers must invoke
// `close()` explicitly.
pub struct TableReader {
mut:
	handle voidptr
	closed bool
}

// open a streaming reader over an in-memory FRAMED chunked-table buffer.
pub fn new_table_reader(data_bin []u8) !&TableReader {
	mut err := charptr(0)
	h := C.cx_table_reader_open(charptr(data_bin.data), &err)
	if h == voidptr(0) {
		return error(err_msg(err, 'cx_table_reader_open: unknown error'))
	}
	return &TableReader{ handle: h }
}

// open a streaming reader over a POSIX file descriptor; fd reads bare
// CXDB bytes (no size prefix).
pub fn new_table_reader_fd(fd int) !&TableReader {
	mut err := charptr(0)
	h := C.cx_table_reader_open_fd(fd, &err)
	if h == voidptr(0) {
		return error(err_msg(err, 'cx_table_reader_open_fd: unknown error'))
	}
	return &TableReader{ handle: h }
}

// schema returns the table's column spec as FRAMED ast_bin (root
// Element 'table' with one Attribute per column: name → type-name).
pub fn (mut r TableReader) schema() ![]u8 {
	if r.closed || r.handle == voidptr(0) {
		return error('TableReader: handle closed')
	}
	mut err := charptr(0)
	out := C.cx_table_reader_schema(r.handle, &err)
	if out == charptr(0) {
		return error(err_msg(err, 'cx_table_reader_schema: unknown error'))
	}
	buf := read_framed_at(out)
	C.cx_free(out)
	return buf
}

// next_row_group pulls the next row group as FRAMED bytes. Returns a
// zero-length []u8 at end-of-table (matching the V core convention);
// returns an error on decode error.
pub fn (mut r TableReader) next_row_group() ![]u8 {
	if r.closed || r.handle == voidptr(0) {
		return []u8{}
	}
	mut err := charptr(0)
	out := C.cx_table_reader_next(r.handle, &err)
	if out == charptr(0) {
		if err == charptr(0) {
			return []u8{} // EOF
		}
		return error(err_msg(err, 'cx_table_reader_next: unknown error'))
	}
	buf := read_framed_at(out)
	C.cx_free(out)
	return buf
}

// collect drains the reader and returns all row groups as FRAMED bytes.
pub fn (mut r TableReader) collect() ![][]u8 {
	mut groups := [][]u8{}
	for {
		g := r.next_row_group()!
		if g.len == 0 {
			break
		}
		groups << g
	}
	return groups
}

// close releases the reader handle. Safe to call multiple times.
pub fn (mut r TableReader) close() {
	if r.closed {
		return
	}
	r.closed = true
	if r.handle != voidptr(0) {
		C.cx_table_reader_close(r.handle)
		r.handle = voidptr(0)
	}
}

// ── TableWriter ───────────────────────────────────────────────────────────────

// Streaming writer for the chunked-table CXDB format. Use
// `new_table_writer` for in-memory output (`close_get_bytes` returns
// the framed buffer) or `new_table_writer_fd` for fd-streaming output.
// V has no RAII: callers must invoke `close()` (or `close_get_bytes()`
// for in-memory writers) explicitly.
pub struct TableWriter {
mut:
	handle voidptr
	closed bool
	is_fd  bool
}

pub fn new_table_writer(col_spec []u8) !&TableWriter {
	mut err := charptr(0)
	h := C.cx_table_writer_open(charptr(col_spec.data), &err)
	if h == voidptr(0) {
		return error(err_msg(err, 'cx_table_writer_open: unknown error'))
	}
	return &TableWriter{ handle: h, is_fd: false }
}

pub fn new_table_writer_fd(col_spec []u8, fd int) !&TableWriter {
	mut err := charptr(0)
	h := C.cx_table_writer_open_fd(charptr(col_spec.data), fd, &err)
	if h == voidptr(0) {
		return error(err_msg(err, 'cx_table_writer_open_fd: unknown error'))
	}
	return &TableWriter{ handle: h, is_fd: true }
}

// emit appends one row group. `row_group` is the FRAMED bytes yielded
// by `TableReader.next_row_group()`.
pub fn (mut w TableWriter) emit(row_group []u8) ! {
	if w.closed || w.handle == voidptr(0) {
		return error('TableWriter: handle closed')
	}
	mut err := charptr(0)
	C.cx_table_writer_emit_row_group(w.handle, charptr(row_group.data), &err)
	if err != charptr(0) {
		return error(err_msg(err, 'cx_table_writer_emit_row_group: unknown error'))
	}
}

// close_get_bytes (in-memory writers only) emits end-of-table and
// returns the FRAMED chunked-table buffer. The handle is consumed.
pub fn (mut w TableWriter) close_get_bytes() ![]u8 {
	if w.is_fd {
		return error('close_get_bytes is for in-memory writers; use close() for fd writers')
	}
	if w.closed || w.handle == voidptr(0) {
		return error('TableWriter: handle closed')
	}
	mut err := charptr(0)
	out := C.cx_table_writer_close_get_bytes(w.handle, &err)
	// V core releases the handle inside close_get_bytes; mark closed.
	w.handle = voidptr(0)
	w.closed = true
	if out == charptr(0) {
		return error(err_msg(err, 'cx_table_writer_close_get_bytes: unknown error'))
	}
	buf := read_framed_at(out)
	C.cx_free(out)
	return buf
}

// close releases the writer handle. For fd writers, flushes the
// end-of-table marker. Safe to call multiple times.
pub fn (mut w TableWriter) close() {
	if w.closed {
		return
	}
	w.closed = true
	if w.handle != voidptr(0) {
		C.cx_table_writer_close(w.handle)
		w.handle = voidptr(0)
	}
}
