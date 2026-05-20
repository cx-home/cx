module arrow

import cx
import sync

#flag -I @VMODROOT/arrow
#include "arrow_c_abi.h"

// CXDB ↔ Apache Arrow C-Data ABI bridge per ADR 0015 D9.
//
// Wire reference: https://arrow.apache.org/docs/format/CDataInterface.html
//
// v0.6.0 supported column types (Phase 7.74c-cont-datetime-arrow):
//   int / i64    →  'l'      int64,    8 bytes/row
//   float / f64  →  'g'      float64,  8 bytes/row
//   bool         →  'b'      bool, bit-packed, ceil(N/8) bytes
//   string       →  'u'      utf8, i32 offsets + UTF-8 values
//   i8           →  'c'      int8,     1 byte/row
//   i16          →  's'      int16,    2 bytes/row (LE)
//   i32          →  'i'      int32,    4 bytes/row (LE)
//   date / d     →  'tdD'    date32, i32 days since 1970-01-01 (LE)
//   datetime     →  'tsn:UTC' timestamp[ns, UTC], i64 ns LE per row
//   bytes        →  'z'      binary, i32 offsets + raw bytes
//
// Deferred (surface a clear `not yet supported in v0.6.0` error):
//   decimal, dictionary columns.
//
// Memory ownership conventions:
//   - The producer (export) owns all buffers, child schemas, and
//     child arrays it hands to the consumer; releases them via the
//     struct's `release` callback.
//   - The consumer (import) drives the released-by-producer model on
//     incoming structs, and owns the outgoing CXDB buffer it returns.
//   - Validity bitmaps are NULL (null_count = 0). CXDB strict-spec
//     column-major encoding has no in-band null at v0.6.0.

// ── Function pointer type aliases ────────────────────────────────────

pub type ArrowSchemaReleaseFn = fn (&C.ArrowSchema)
pub type ArrowArrayReleaseFn  = fn (&C.ArrowArray)
pub type ArrowStreamReleaseFn = fn (&C.ArrowArrayStream)

pub type ArrowGetSchemaFn    = fn (&C.ArrowArrayStream, &C.ArrowSchema) int
pub type ArrowGetNextFn      = fn (&C.ArrowArrayStream, &C.ArrowArray) int
pub type ArrowGetLastErrorFn = fn (&C.ArrowArrayStream) &char

// ── Arrow C-Data ABI struct declarations ─────────────────────────────

pub struct C.ArrowSchema {
pub mut:
	format       &char
	name         &char
	metadata     &char
	flags        i64
	n_children   i64
	children     &voidptr             // ArrowSchema** (children[i] is &ArrowSchema)
	dictionary   &C.ArrowSchema
	release      ArrowSchemaReleaseFn
	private_data voidptr
}

pub struct C.ArrowArray {
pub mut:
	length        i64
	null_count    i64
	offset        i64
	n_buffers     i64
	n_children    i64
	buffers       &voidptr            // const void**
	children      &voidptr            // ArrowArray**
	dictionary    &C.ArrowArray
	release       ArrowArrayReleaseFn
	private_data  voidptr
}

pub struct C.ArrowArrayStream {
pub mut:
	get_schema     ArrowGetSchemaFn
	get_next       ArrowGetNextFn
	get_last_error ArrowGetLastErrorFn
	release        ArrowStreamReleaseFn
	private_data   voidptr
}

// ── Type mapping ─────────────────────────────────────────────────────

// arrow_format_for_cxdb_type returns the Arrow C-Data ABI format
// string for a CXDB column type name (as produced by
// cx.column_type_name_from_code).
//
// v0.7.0 W1 extensions: decimal128, timestamp parametric tz, fixed-
// size-binary, dictionary-encoded utf8. Errors for unsupported types.
//
// Parametric forms (case-insensitive on the prefix):
//   decimal128[P,S]       → 'd:P,S' (Arrow decimal128 with precision P, scale S)
//   timestamp[U, TZ]      → 'tsU:TZ' where U ∈ {s,m,u,n} → {s, ms, us, ns}
//   fixed-size-binary[N]  → 'w:N'   (Arrow fixed-size-binary N bytes)
//   dict-utf8             → 'u' (with dictionary field set in schema)
fn arrow_format_for_cxdb_type(type_name string) !string {
	// Parametric prefixes first.
	if type_name.starts_with('decimal128[') && type_name.ends_with(']') {
		body := type_name[11..type_name.len - 1]
		if !body.contains(',') {
			return error("decimal128 needs precision,scale: got '${type_name}'")
		}
		return 'd:${body}'
	}
	if type_name.starts_with('timestamp[') && type_name.ends_with(']') {
		body := type_name[10..type_name.len - 1]
		parts := body.split(',')
		if parts.len != 2 {
			return error("timestamp needs [unit, tz]: got '${type_name}'")
		}
		unit := parts[0].trim_space()
		tz := parts[1].trim_space()
		unit_code := match unit {
			's', 'sec', 'seconds'         { 's' }
			'ms', 'milli', 'milliseconds' { 'm' }
			'us', 'micro', 'microseconds' { 'u' }
			'ns', 'nano',  'nanoseconds'  { 'n' }
			else { return error("timestamp unit must be s|ms|us|ns: got '${unit}'") }
		}
		return 'ts${unit_code}:${tz}'
	}
	if type_name.starts_with('fixed-size-binary[') && type_name.ends_with(']') {
		body := type_name[18..type_name.len - 1]
		if body.int() <= 0 {
			return error("fixed-size-binary needs positive byte count: got '${type_name}'")
		}
		return 'w:${body}'
	}
	return match type_name {
		'int', 'i64'        { 'l' }     // int64
		'i8'                { 'c' }     // int8
		'i16'               { 's' }     // int16
		'i32'               { 'i' }     // int32
		'float', 'f64'      { 'g' }     // float64
		'bool'              { 'b' }     // bool (bit-packed)
		'string', 's', ''   { 'u' }     // utf8 (32-bit offsets)
		'dict-utf8'         { 'u' }     // dictionary-encoded utf8 — dict field set at schema time
		'date', 'd'         { 'tdD' }   // date32 (days since 1970-01-01)
		'datetime'          { 'tsn:UTC' } // timestamp[ns, UTC] (shorthand)
		'bytes'             { 'z' }     // binary (32-bit offsets)
		'decimal128'        { 'd:38,10' } // decimal128 default precision/scale
		else {
			error("column type '${type_name}' not yet supported in v0.7.0; "
				+ 'supported scalar set: int, i8, i16, i32, float, bool, string, date, '
				+ 'datetime, bytes, decimal128 (or decimal128[P,S]), '
				+ 'timestamp[unit, tz], fixed-size-binary[N], dict-utf8. '
				+ 'Nested types (struct, list, fixed-size-list) require cx-table '
				+ 'cell-model evolution to carry nested cells natively '
				+ '(tracked separately; depends on cx-table v0.8.0 schema work).')
		}
	}
}

// cxdb_type_name_from_arrow_format is the inverse — used on import.
// v0.7.0 W1: handle parametric forms (d:P,S, tsU:TZ, w:N).
fn cxdb_type_name_from_arrow_format(fmt string) !string {
	if fmt.starts_with('d:') {
		return 'decimal128[${fmt[2..]}]'
	}
	if fmt.starts_with('ts') && fmt.len >= 4 && fmt[3] == `:` {
		unit_code := fmt[2]
		tz := fmt[4..]
		unit := match unit_code {
			`s` { 's' }
			`m` { 'ms' }
			`u` { 'us' }
			`n` { 'ns' }
			else { return error("Arrow timestamp unit code '${unit_code.ascii_str()}' unrecognised in '${fmt}'") }
		}
		// Preserve the v0.6.0 shorthand 'datetime' for ns:UTC inputs to
		// keep round-trip stable for the common case.
		if unit_code == `n` && tz == 'UTC' { return 'datetime' }
		return 'timestamp[${unit}, ${tz}]'
	}
	if fmt.starts_with('w:') {
		return 'fixed-size-binary[${fmt[2..]}]'
	}
	return match fmt {
		'l'           { 'int' }
		'c'           { 'i8' }
		's'           { 'i16' }
		'i'           { 'i32' }
		'g'           { 'float' }
		'b'           { 'bool' }
		'u'           { 'string' }
		'tdD'         { 'date' }
		'tsn:UTC'     { 'datetime' }
		'z'           { 'bytes' }
		else {
			error("Arrow format '${fmt}' not yet supported in v0.7.0; "
				+ "supported set: 'l' (int64), 'c' (int8), 's' (int16), 'i' (int32), "
				+ "'g' (float64), 'b' (bool), 'u' (utf8), 'tdD' (date32), "
				+ "'tsn:UTC' (timestamp[ns, UTC]), 'z' (binary), "
				+ "'d:P,S' (decimal128), 'tsU:TZ' (timestamp w/ tz), 'w:N' (fixed-size-binary)")
		}
	}
}

// ── Date conversions (Howard Hinnant proleptic Gregorian) ────────────
//
// CXDB date wire form (4 bytes): yLE i16 + month u8 + day u8.
// Arrow date32 wire form (4 bytes): i32 LE days since 1970-01-01.
// Range covered: roughly year [-5877641, +5879610]; both formats are
// proleptic Gregorian (no Julian-cutoff handling).

fn date_to_days(year i16, month u8, day u8) i32 {
	mut y := i32(year)
	if month <= 2 {
		y -= 1
	}
	era := if y >= 0 { y / 400 } else { (y - 399) / 400 }
	yoe := y - era * 400
	mm := i32(month)
	doy := (153 * (mm + if mm > 2 { i32(-3) } else { i32(9) }) + 2) / 5 + i32(day) - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

fn days_to_date(z i32) (i16, u8, u8) {
	zz := z + 719468
	era := if zz >= 0 { zz / 146097 } else { (zz - 146096) / 146097 }
	doe := zz - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	mut y := yoe + era * 400
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	d := doy - (153 * mp + 2) / 5 + 1
	m := mp + if mp < 10 { i32(3) } else { i32(-9) }
	if m <= 2 {
		y += 1
	}
	return i16(y), u8(m), u8(d)
}

// ── ExportState + LiveArrayBuffers + registry ────────────────────────
//
// The Arrow C-Data ABI passes V heap pointers via caller-allocated C
// structs that V's GC may not scan. To keep V references alive we
// route all state through a module-level registry keyed by u64 token;
// the token (cast to voidptr) lives in private_data fields. Release
// callbacks unregister the slot, allowing V GC to reclaim once any
// transitively-held V pointers go out of reach.

@[heap]
struct ExportState {
mut:
	reader      &cx.CxTableReader = unsafe { nil }
	col_codes   []u8
	col_names   []string
	col_formats []string
	last_err    string
}

@[heap]
struct LiveArrayBuffers {
mut:
	row_count    int
	// Per-column primary buffers in Arrow layout (already converted
	// from CXDB column-major). Numeric/bool: data buffer.
	// String: values (UTF-8) buffer.
	col_main_bufs [][]u8
	// Per-column auxiliary buffers. String: i32 offsets buffer.
	// Numeric/bool: empty.
	col_aux_bufs  [][]u8
	// Format string per column (kept for release-time bookkeeping).
	col_formats   []string
}

__global (
	g_export_states map[u64]&ExportState
	g_live_arrays   map[u64]&LiveArrayBuffers
	g_next_token    = u64(1)
	g_registry_mu   sync.Mutex
)

fn registry_register_export(s &ExportState) u64 {
	g_registry_mu.@lock()
	defer { g_registry_mu.unlock() }
	tok := g_next_token
	g_next_token++
	g_export_states[tok] = s
	return tok
}

fn registry_lookup_export(tok u64) ?&ExportState {
	g_registry_mu.@lock()
	defer { g_registry_mu.unlock() }
	state := g_export_states[tok] or { return none }
	return state
}

fn registry_unregister_export(tok u64) {
	g_registry_mu.@lock()
	defer { g_registry_mu.unlock() }
	g_export_states.delete(tok)
}

fn registry_register_live_array(la &LiveArrayBuffers) u64 {
	g_registry_mu.@lock()
	defer { g_registry_mu.unlock() }
	tok := g_next_token
	g_next_token++
	g_live_arrays[tok] = la
	return tok
}

fn registry_unregister_live_array(tok u64) {
	g_registry_mu.@lock()
	defer { g_registry_mu.unlock() }
	g_live_arrays.delete(tok)
}

// ── Export: CXDB chunked → ArrowArrayStream ──────────────────────────

fn export_populate_stream_bytes(stream_out voidptr, framed []u8) ! {
	r := cx.new_table_reader_bytes(framed)!
	export_populate_stream_with_reader(stream_out, r)!
}

fn export_populate_stream_fd(stream_out voidptr, fd int) ! {
	r := cx.new_table_reader_fd(fd)!
	export_populate_stream_with_reader(stream_out, r)!
}

fn export_populate_stream_with_reader(stream_out voidptr, r &cx.CxTableReader) ! {
	cols := r.cols_snapshot()
	mut codes := []u8{cap: cols.len}
	mut names := []string{cap: cols.len}
	mut formats := []string{cap: cols.len}
	for c in cols {
		f := arrow_format_for_cxdb_type(c.type_name)!
		codes << cxdb_code_for_type_name(c.type_name)
		names << c.name
		formats << f
	}
	mut state := &ExportState{
		reader:      unsafe { r }
		col_codes:   codes
		col_names:   names
		col_formats: formats
	}
	tok := registry_register_export(state)
	mut s := unsafe { &C.ArrowArrayStream(stream_out) }
	s.private_data   = voidptr(tok)
	s.get_schema     = arrow_export_get_schema
	s.get_next       = arrow_export_get_next
	s.get_last_error = arrow_export_get_last_error
	s.release        = arrow_export_release_stream
}

// CXDB column type-byte codes (mirrors vcx/cx/data_bin.v's tags).
// Values must match data_bin.v's `tag_*` constants exactly — the
// chunked-table column-major encoder/decoder dispatch on these.
const cxdb_tag_int8     = u8(0x10)
const cxdb_tag_int16    = u8(0x11)
const cxdb_tag_int32    = u8(0x12)
const cxdb_tag_int64    = u8(0x13)
const cxdb_tag_float64  = u8(0x20)
const cxdb_tag_string   = u8(0x30)
const cxdb_tag_date     = u8(0x31)
const cxdb_tag_datetime = u8(0x32)
const cxdb_tag_bytes    = u8(0x33)
// W1 v0.7.0 — new CXDB tags for parametric scalar types.
// Wire encoding: each cell is a fixed-width byte slab whose width
// is determined by the column's type_name parameters at decode time.
const cxdb_tag_decimal128 = u8(0x40)  // 16 bytes/cell
const cxdb_tag_timestamp  = u8(0x41)  // 8 bytes/cell (i64) — unit + tz in type_name
const cxdb_tag_fsb        = u8(0x42)  // fixed-size-binary, N bytes/cell from type_name[N]
const cxdb_tag_true     = u8(0x02)

fn cxdb_code_for_type_name(type_name string) u8 {
	if type_name.starts_with('decimal128')       { return cxdb_tag_decimal128 }
	if type_name.starts_with('timestamp[')       { return cxdb_tag_timestamp }
	if type_name.starts_with('fixed-size-binary[') { return cxdb_tag_fsb }
	return match type_name {
		'int', 'i64'      { cxdb_tag_int64 }
		'i8'              { cxdb_tag_int8 }
		'i16'             { cxdb_tag_int16 }
		'i32'             { cxdb_tag_int32 }
		'float', 'f64'    { cxdb_tag_float64 }
		'bool'            { cxdb_tag_true }
		'string', '', 's', 'dict-utf8' { cxdb_tag_string }
		'date', 'd'       { cxdb_tag_date }
		'datetime'        { cxdb_tag_datetime }
		'bytes'           { cxdb_tag_bytes }
		else              { cxdb_tag_string }
	}
}

// fsb_width_from_type_name extracts the byte width from a
// `fixed-size-binary[N]` type name. Used by decoders.
fn fsb_width_from_type_name(type_name string) !int {
	if !type_name.starts_with('fixed-size-binary[') || !type_name.ends_with(']') {
		return error('fsb width: not a fixed-size-binary type name: "${type_name}"')
	}
	body := type_name[18..type_name.len - 1]
	w := body.int()
	if w <= 0 { return error('fsb width must be > 0: "${type_name}"') }
	return w
}

// ── Stream callbacks ─────────────────────────────────────────────────

fn arrow_export_get_schema(stream &C.ArrowArrayStream, out &C.ArrowSchema) int {
	tok := u64(stream.private_data)
	mut state := registry_lookup_export(tok) or {
		return 1
	}
	populate_schema_struct(out, state.col_names, state.col_formats) or {
		state.last_err = err.msg()
		return 1
	}
	return 0
}

fn arrow_export_get_next(stream &C.ArrowArrayStream, out &C.ArrowArray) int {
	tok := u64(stream.private_data)
	mut state := registry_lookup_export(tok) or {
		return 1
	}
	mut reader := state.reader
	body := reader.next_row_group_framed() or {
		state.last_err = err.msg()
		return 1
	}
	if body.len == 0 {
		zero_out_array(out)
		return 0
	}
	if body.len < 4 {
		state.last_err = 'arrow: framed row-group too short'
		return 1
	}
	plain := body[4..body.len]
	la := decode_row_group_into_arrow(plain, state.col_codes, state.col_formats) or {
		state.last_err = err.msg()
		return 1
	}
	la_tok := registry_register_live_array(la)
	populate_array_struct(out, la, la_tok) or {
		state.last_err = err.msg()
		registry_unregister_live_array(la_tok)
		return 1
	}
	return 0
}

fn arrow_export_get_last_error(stream &C.ArrowArrayStream) &char {
	tok := u64(stream.private_data)
	state := registry_lookup_export(tok) or {
		return unsafe { nil }
	}
	if state.last_err == '' {
		return unsafe { nil }
	}
	return c_string(state.last_err)
}

fn arrow_export_release_stream(stream &C.ArrowArrayStream) {
	tok := u64(stream.private_data)
	registry_unregister_export(tok)
	mut s := unsafe { stream }
	s.private_data   = unsafe { nil }
	s.get_schema     = unsafe { nil }
	s.get_next       = unsafe { nil }
	s.get_last_error = unsafe { nil }
	s.release        = unsafe { nil }
}

// ── Schema population ────────────────────────────────────────────────

fn populate_schema_struct(out &C.ArrowSchema, col_names []string, col_formats []string) ! {
	// Top-level struct schema: format = "+s", one child per column.
	mut o := unsafe { out }
	o.format       = c_string('+s')
	o.name         = c_string('')
	o.metadata     = unsafe { nil }
	o.flags        = 0
	o.n_children   = i64(col_names.len)
	o.dictionary   = unsafe { nil }
	o.private_data = unsafe { nil }
	ptr_size := int(sizeof(voidptr))
	children_arr := unsafe { malloc(ptr_size * col_names.len) }
	for i in 0 .. col_names.len {
		child_struct_size := int(sizeof(C.ArrowSchema))
		cs_raw := unsafe { malloc(child_struct_size) }
		unsafe { vmemset(cs_raw, 0, child_struct_size) }
		mut cs := unsafe { &C.ArrowSchema(cs_raw) }
		cs.format       = c_string(col_formats[i])
		cs.name         = c_string(col_names[i])
		cs.metadata     = unsafe { nil }
		cs.flags        = 0
		cs.n_children   = 0
		cs.children     = unsafe { nil }
		cs.dictionary   = unsafe { nil }
		cs.release      = arrow_schema_release_child
		cs.private_data = unsafe { nil }
		unsafe { (&voidptr(children_arr))[i] = voidptr(cs_raw) }
	}
	o.children = unsafe { &voidptr(children_arr) }
	o.release  = arrow_schema_release_root
}

fn arrow_schema_release_root(sch &C.ArrowSchema) {
	mut s := unsafe { sch }
	if s.format != unsafe { nil } { unsafe { free(voidptr(s.format)) } }
	if s.name   != unsafe { nil } { unsafe { free(voidptr(s.name)) } }
	if s.children != unsafe { nil } {
		n := int(s.n_children)
		for i in 0 .. n {
			cp := unsafe { (&voidptr(s.children))[i] }
			if cp != unsafe { nil } {
				cs := unsafe { &C.ArrowSchema(cp) }
				if cs.release != unsafe { nil } {
					cs.release(cs)
				}
				unsafe { free(cp) }
			}
		}
		unsafe { free(voidptr(s.children)) }
	}
	s.release = unsafe { nil }
}

fn arrow_schema_release_child(sch &C.ArrowSchema) {
	mut s := unsafe { sch }
	if s.format != unsafe { nil } { unsafe { free(voidptr(s.format)) } }
	if s.name   != unsafe { nil } { unsafe { free(voidptr(s.name)) } }
	s.release = unsafe { nil }
}

// ── Array population (per row group) ─────────────────────────────────

fn decode_row_group_into_arrow(plain []u8, col_codes []u8, col_formats []string) !&LiveArrayBuffers {
	mut br := cx.new_bin_reader(plain)
	row_count_u64 := br.read_uvarint_pub()!
	row_count := int(row_count_u64)
	mut la := &LiveArrayBuffers{
		row_count:     row_count
		col_main_bufs: [][]u8{cap: col_codes.len}
		col_aux_bufs:  [][]u8{cap: col_codes.len}
		col_formats:   col_formats.clone()
	}
	for i, code in col_codes {
		fmt := col_formats[i]
		match fmt {
			'l' {
				if code != cxdb_tag_int64 {
					return error('arrow: format/code mismatch for col ${i} (expected int64)')
				}
				bytes := br.take_pub(row_count * 8)!
				la.col_main_bufs << bytes.clone()
				la.col_aux_bufs << []u8{}
			}
			'c' {
				if code != cxdb_tag_int8 {
					return error('arrow: format/code mismatch for col ${i} (expected int8)')
				}
				bytes := br.take_pub(row_count)!
				la.col_main_bufs << bytes.clone()
				la.col_aux_bufs << []u8{}
			}
			's' {
				if code != cxdb_tag_int16 {
					return error('arrow: format/code mismatch for col ${i} (expected int16)')
				}
				bytes := br.take_pub(row_count * 2)!
				la.col_main_bufs << bytes.clone()
				la.col_aux_bufs << []u8{}
			}
			'i' {
				if code != cxdb_tag_int32 {
					return error('arrow: format/code mismatch for col ${i} (expected int32)')
				}
				bytes := br.take_pub(row_count * 4)!
				la.col_main_bufs << bytes.clone()
				la.col_aux_bufs << []u8{}
			}
			'g' {
				if code != cxdb_tag_float64 {
					return error('arrow: format/code mismatch for col ${i} (expected float64)')
				}
				bytes := br.take_pub(row_count * 8)!
				la.col_main_bufs << bytes.clone()
				la.col_aux_bufs << []u8{}
			}
			'b' {
				if code != cxdb_tag_true {
					return error('arrow: format/code mismatch for col ${i} (expected bool)')
				}
				raw := br.take_pub(row_count)!
				packed_len := (row_count + 7) / 8
				mut packed := []u8{len: packed_len}
				for r in 0 .. row_count {
					if raw[r] != 0 {
						packed[r / 8] |= u8(1) << u32(r % 8)
					}
				}
				la.col_main_bufs << packed
				la.col_aux_bufs << []u8{}
			}
			'tdD' {
				if code != cxdb_tag_date {
					return error('arrow: format/code mismatch for col ${i} (expected date)')
				}
				cells := br.take_pub(row_count * 4)!
				mut days_buf := []u8{cap: row_count * 4}
				for r in 0 .. row_count {
					off := r * 4
					y := i16(u16(cells[off]) | (u16(cells[off + 1]) << 8))
					mo := cells[off + 2]
					dd := cells[off + 3]
					if mo == 0 || mo > 12 || dd == 0 || dd > 31 {
						return error('arrow: invalid CXDB date at row ${r} (y=${y} m=${mo} d=${dd})')
					}
					days := date_to_days(y, mo, dd)
					append_i32_le(mut days_buf, days)
				}
				la.col_main_bufs << days_buf
				la.col_aux_bufs << []u8{}
			}
			'tsn:UTC' {
				if code != cxdb_tag_datetime {
					return error('arrow: format/code mismatch for col ${i} (expected datetime)')
				}
				// CXDB strict-cell datetime = 12 bytes/row (i64 ns LE +
				// i16 offset LE + u16 reserved). Strict canonical pins
				// offset+reserved to zero, so the first 8 bytes already
				// match Arrow timestamp[ns, UTC]; the trailing 4 are
				// dropped.
				cells := br.take_pub(row_count * 12)!
				mut ns_buf := []u8{cap: row_count * 8}
				for r in 0 .. row_count {
					off := r * 12
					ns_buf << cells[off .. off + 8]
				}
				la.col_main_bufs << ns_buf
				la.col_aux_bufs << []u8{}
			}
			'u', 'z' {
				if fmt == 'u' && code != cxdb_tag_string {
					return error('arrow: format/code mismatch for col ${i} (expected string)')
				}
				if fmt == 'z' && code != cxdb_tag_bytes {
					return error('arrow: format/code mismatch for col ${i} (expected bytes)')
				}
				mut offsets := []u8{cap: (row_count + 1) * 4}
				mut values  := []u8{cap: row_count * 8}
				mut cur := u32(0)
				append_u32_le(mut offsets, cur)
				for _ in 0 .. row_count {
					slen := br.read_uvarint_pub()!
					if slen > 0 {
						bytes := br.take_pub(int(slen))!
						values << bytes
					}
					cur += u32(slen)
					append_u32_le(mut offsets, cur)
				}
				la.col_main_bufs << values
				la.col_aux_bufs << offsets
			}
			else {
				// W1 v0.7.0 parametric scalar dispatch.
				if fmt.starts_with('d:') {
					if code != cxdb_tag_decimal128 {
						return error('arrow: format/code mismatch for col ${i} (expected decimal128)')
					}
					// 16 bytes/cell for decimal128 (Arrow LE encoding).
					bytes := br.take_pub(row_count * 16)!
					la.col_main_bufs << bytes.clone()
					la.col_aux_bufs << []u8{}
				} else if fmt.starts_with('ts') && fmt.len >= 4 && fmt[3] == `:` {
					if code != cxdb_tag_timestamp && code != cxdb_tag_datetime {
						return error('arrow: format/code mismatch for col ${i} (expected timestamp)')
					}
					// 8 bytes/cell (i64) for parametric timestamps.
					bytes := br.take_pub(row_count * 8)!
					la.col_main_bufs << bytes.clone()
					la.col_aux_bufs << []u8{}
				} else if fmt.starts_with('w:') {
					if code != cxdb_tag_fsb {
						return error('arrow: format/code mismatch for col ${i} (expected fixed-size-binary)')
					}
					width := fmt[2..].int()
					if width <= 0 {
						return error('arrow: fixed-size-binary width must be > 0: "${fmt}"')
					}
					bytes := br.take_pub(row_count * width)!
					la.col_main_bufs << bytes.clone()
					la.col_aux_bufs << []u8{}
				} else {
					return error("arrow: format '${fmt}' not handled in decoder")
				}
			}
		}
	}
	return la
}

fn append_u32_le(mut buf []u8, v u32) {
	buf << u8(v & 0xFF)
	buf << u8((v >> 8) & 0xFF)
	buf << u8((v >> 16) & 0xFF)
	buf << u8((v >> 24) & 0xFF)
}

fn append_i32_le(mut buf []u8, v i32) {
	append_u32_le(mut buf, u32(v))
}

fn populate_array_struct(out &C.ArrowArray, la &LiveArrayBuffers, la_tok u64) ! {
	mut o := unsafe { out }
	o.length     = i64(la.row_count)
	o.null_count = 0
	o.offset     = 0
	o.n_buffers  = 1   // root struct array: 1 buffer slot for validity (NULL)
	o.n_children = i64(la.col_main_bufs.len)
	o.dictionary = unsafe { nil }
	ptr_size := int(sizeof(voidptr))
	root_bufs := unsafe { malloc(ptr_size) }
	unsafe { (&voidptr(root_bufs))[0] = nil }
	o.buffers = unsafe { &voidptr(root_bufs) }
	children_arr := unsafe { malloc(ptr_size * la.col_main_bufs.len) }
	for i in 0 .. la.col_main_bufs.len {
		ca_raw := unsafe { malloc(int(sizeof(C.ArrowArray))) }
		unsafe { vmemset(ca_raw, 0, int(sizeof(C.ArrowArray))) }
		mut ca := unsafe { &C.ArrowArray(ca_raw) }
		populate_child_array(mut ca, la, i)!
		unsafe { (&voidptr(children_arr))[i] = voidptr(ca_raw) }
	}
	o.children     = unsafe { &voidptr(children_arr) }
	o.release      = arrow_array_release_root
	o.private_data = voidptr(la_tok)
}

fn populate_child_array(mut ca C.ArrowArray, la &LiveArrayBuffers, col_idx int) ! {
	ca.length     = i64(la.row_count)
	ca.null_count = 0
	ca.offset     = 0
	ca.n_children = 0
	ca.children   = unsafe { nil }
	ca.dictionary = unsafe { nil }
	ca.release    = arrow_array_release_child
	ca.private_data = unsafe { nil }
	main_buf := la.col_main_bufs[col_idx]
	aux_buf  := la.col_aux_bufs[col_idx]
	ptr_size := int(sizeof(voidptr))
	if aux_buf.len > 0 {
		// String: 3 buffers (validity NULL, offsets, values).
		ca.n_buffers = 3
		bufs_arr := unsafe { malloc(ptr_size * 3) }
		unsafe { (&voidptr(bufs_arr))[0] = nil }
		offsets_buf := unsafe { malloc(aux_buf.len) }
		unsafe { vmemcpy(offsets_buf, aux_buf.data, aux_buf.len) }
		unsafe { (&voidptr(bufs_arr))[1] = offsets_buf }
		alloc_n := if main_buf.len > 0 { main_buf.len } else { 1 }
		vals_buf := unsafe { malloc(alloc_n) }
		if main_buf.len > 0 {
			unsafe { vmemcpy(vals_buf, main_buf.data, main_buf.len) }
		}
		unsafe { (&voidptr(bufs_arr))[2] = vals_buf }
		ca.buffers = unsafe { &voidptr(bufs_arr) }
	} else {
		// Numeric or bool: 2 buffers (validity NULL, data).
		ca.n_buffers = 2
		bufs_arr := unsafe { malloc(ptr_size * 2) }
		unsafe { (&voidptr(bufs_arr))[0] = nil }
		alloc_n := if main_buf.len > 0 { main_buf.len } else { 1 }
		data_buf := unsafe { malloc(alloc_n) }
		if main_buf.len > 0 {
			unsafe { vmemcpy(data_buf, main_buf.data, main_buf.len) }
		}
		unsafe { (&voidptr(bufs_arr))[1] = data_buf }
		ca.buffers = unsafe { &voidptr(bufs_arr) }
	}
}

fn arrow_array_release_root(arr &C.ArrowArray) {
	mut a := unsafe { arr }
	if a.children != unsafe { nil } {
		n := int(a.n_children)
		for i in 0 .. n {
			cp := unsafe { (&voidptr(a.children))[i] }
			if cp != unsafe { nil } {
				ca := unsafe { &C.ArrowArray(cp) }
				if ca.release != unsafe { nil } {
					ca.release(ca)
				}
				unsafe { free(cp) }
			}
		}
		unsafe { free(voidptr(a.children)) }
	}
	if a.buffers != unsafe { nil } {
		unsafe { free(voidptr(a.buffers)) }
	}
	tok := u64(a.private_data)
	if tok != 0 {
		registry_unregister_live_array(tok)
	}
	a.release = unsafe { nil }
}

fn arrow_array_release_child(arr &C.ArrowArray) {
	mut a := unsafe { arr }
	if a.buffers != unsafe { nil } {
		n := int(a.n_buffers)
		for i in 0 .. n {
			bp := unsafe { (&voidptr(a.buffers))[i] }
			if bp != unsafe { nil } {
				unsafe { free(bp) }
			}
		}
		unsafe { free(voidptr(a.buffers)) }
	}
	a.release = unsafe { nil }
}

fn zero_out_array(out &C.ArrowArray) {
	mut o := unsafe { out }
	o.length        = 0
	o.null_count    = 0
	o.offset        = 0
	o.n_buffers     = 0
	o.n_children    = 0
	o.buffers       = unsafe { nil }
	o.children      = unsafe { nil }
	o.dictionary    = unsafe { nil }
	o.release       = unsafe { nil }
	o.private_data  = unsafe { nil }
}

// ── Import: ArrowArrayStream → CXDB chunked-table ────────────────────

fn alloc_zero_arrow_array() &C.ArrowArray {
	sz := int(sizeof(C.ArrowArray))
	raw := unsafe { malloc(sz) }
	unsafe { vmemset(raw, 0, sz) }
	return unsafe { &C.ArrowArray(raw) }
}

fn alloc_zero_arrow_schema() &C.ArrowSchema {
	sz := int(sizeof(C.ArrowSchema))
	raw := unsafe { malloc(sz) }
	unsafe { vmemset(raw, 0, sz) }
	return unsafe { &C.ArrowSchema(raw) }
}

fn alloc_zero_arrow_stream() &C.ArrowArrayStream {
	sz := int(sizeof(C.ArrowArrayStream))
	raw := unsafe { malloc(sz) }
	unsafe { vmemset(raw, 0, sz) }
	return unsafe { &C.ArrowArrayStream(raw) }
}

fn import_drain_to_bytes(stream_in voidptr) ![]u8 {
	cols, col_formats := import_read_schema(stream_in)!
	col_spec_payload := cx.col_spec_to_ast_bin_pub(cols)
	mut writer := cx.new_table_writer_bytes(col_spec_payload)!
	for {
		arr := alloc_zero_arrow_array()
		eos := import_pull_next(stream_in, arr)!
		if eos {
			unsafe { free(voidptr(arr)) }
			break
		}
		body := encode_arrow_array_as_row_group(arr, cols, col_formats)!
		writer.emit_row_group_payload(body)!
		if arr.release != unsafe { nil } {
			arr.release(arr)
		}
		unsafe { free(voidptr(arr)) }
	}
	bytes := writer.close_get_bytes()!
	import_release_stream(stream_in)
	return bytes
}

fn import_drain_to_fd(stream_in voidptr, fd_out int) ! {
	cols, col_formats := import_read_schema(stream_in)!
	col_spec_payload := cx.col_spec_to_ast_bin_pub(cols)
	mut writer := cx.new_table_writer_fd(col_spec_payload, fd_out)!
	for {
		arr := alloc_zero_arrow_array()
		eos := import_pull_next(stream_in, arr)!
		if eos {
			unsafe { free(voidptr(arr)) }
			break
		}
		body := encode_arrow_array_as_row_group(arr, cols, col_formats)!
		writer.emit_row_group_payload(body)!
		if arr.release != unsafe { nil } {
			arr.release(arr)
		}
		unsafe { free(voidptr(arr)) }
	}
	writer.writer_close()!
	import_release_stream(stream_in)
}

fn import_read_schema(stream_in voidptr) !([]cx.TableColumn, []string) {
	mut s := unsafe { &C.ArrowArrayStream(stream_in) }
	if s.get_schema == unsafe { nil } {
		return error('arrow: stream get_schema is null')
	}
	sch := alloc_zero_arrow_schema()
	rc := s.get_schema(s, sch)
	if rc != 0 {
		unsafe { free(voidptr(sch)) }
		return error('arrow: get_schema returned ${rc}')
	}
	root_format := unsafe { cstring_to_vstring(sch.format) }
	if root_format != '+s' {
		if sch.release != unsafe { nil } { sch.release(sch) }
		unsafe { free(voidptr(sch)) }
		return error("arrow: root schema format must be '+s' (struct); got '${root_format}'")
	}
	n := int(sch.n_children)
	if n == 0 {
		if sch.release != unsafe { nil } { sch.release(sch) }
		unsafe { free(voidptr(sch)) }
		return error('arrow: empty schema (n_children = 0)')
	}
	mut cols := []cx.TableColumn{cap: n}
	mut formats := []string{cap: n}
	for i in 0 .. n {
		child_ptr := unsafe { (&voidptr(sch.children))[i] }
		child := unsafe { &C.ArrowSchema(child_ptr) }
		fmt := unsafe { cstring_to_vstring(child.format) }
		name := unsafe { cstring_to_vstring(child.name) }
		type_name := cxdb_type_name_from_arrow_format(fmt) or {
			if sch.release != unsafe { nil } { sch.release(sch) }
			unsafe { free(voidptr(sch)) }
			return err
		}
		cols << cx.TableColumn{ name: name, type_name: type_name }
		formats << fmt
	}
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }
	return cols, formats
}

fn import_pull_next(stream_in voidptr, arr &C.ArrowArray) !bool {
	mut s := unsafe { &C.ArrowArrayStream(stream_in) }
	if s.get_next == unsafe { nil } {
		return error('arrow: stream get_next is null')
	}
	rc := s.get_next(s, arr)
	if rc != 0 {
		return error('arrow: get_next returned ${rc}')
	}
	if arr.release == unsafe { nil } {
		return true // end of stream
	}
	return false
}

fn import_release_stream(stream_in voidptr) {
	s := unsafe { &C.ArrowArrayStream(stream_in) }
	if s.release != unsafe { nil } {
		s.release(s)
	}
}

fn encode_arrow_array_as_row_group(arr &C.ArrowArray, cols []cx.TableColumn,
	col_formats []string) ![]u8 {
	row_count := int(arr.length)
	if int(arr.n_children) != cols.len {
		return error('arrow: array n_children=${arr.n_children} != schema cols=${cols.len}')
	}
	mut body := []u8{cap: 64 + row_count * cols.len * 8}
	cx.encode_uvarint_pub(mut body, u64(row_count))
	for i in 0 .. cols.len {
		fmt := col_formats[i]
		child_ptr := unsafe { (&voidptr(arr.children))[i] }
		child := unsafe { &C.ArrowArray(child_ptr) }
		write_column_from_arrow(mut body, child, fmt, row_count)!
	}
	return body
}

fn write_column_from_arrow(mut body []u8, child &C.ArrowArray, fmt string, row_count int) ! {
	match fmt {
		'l' {
			copy_fixed_width_data(mut body, child, row_count, 8, 'int64')!
		}
		'c' {
			copy_fixed_width_data(mut body, child, row_count, 1, 'int8')!
		}
		's' {
			copy_fixed_width_data(mut body, child, row_count, 2, 'int16')!
		}
		'i' {
			copy_fixed_width_data(mut body, child, row_count, 4, 'int32')!
		}
		'g' {
			copy_fixed_width_data(mut body, child, row_count, 8, 'float64')!
		}
		'b' {
			data_ptr := unsafe { (&voidptr(child.buffers))[1] }
			if data_ptr == unsafe { nil } {
				return error('arrow: bool column has NULL data buffer')
			}
			packed_len := (row_count + 7) / 8
			mut packed := []u8{len: packed_len}
			unsafe { vmemcpy(packed.data, data_ptr, packed_len) }
			for r in 0 .. row_count {
				bit := (packed[r / 8] >> u32(r % 8)) & 1
				body << bit
			}
		}
		'tdD' {
			data_ptr := unsafe { (&voidptr(child.buffers))[1] }
			if data_ptr == unsafe { nil } {
				return error('arrow: date32 column has NULL data buffer')
			}
			n_bytes := row_count * 4
			mut days_buf := []u8{len: n_bytes}
			unsafe { vmemcpy(days_buf.data, data_ptr, n_bytes) }
			for r in 0 .. row_count {
				days := i32(read_u32_le(days_buf, r * 4))
				y, mo, dd := days_to_date(days)
				yu := u16(u32(y))
				body << u8(yu & 0xFF)
				body << u8((yu >> 8) & 0xFF)
				body << mo
				body << dd
			}
		}
		'tsn:UTC' {
			data_ptr := unsafe { (&voidptr(child.buffers))[1] }
			if data_ptr == unsafe { nil } {
				return error('arrow: timestamp[ns, UTC] column has NULL data buffer')
			}
			// Arrow tsn:UTC = 8 bytes ns LE per row. CXDB strict-cell
			// datetime appends 2 zero offset bytes + 2 zero reserved
			// bytes to make 12 bytes/row.
			n_bytes := row_count * 8
			mut ns_buf := []u8{len: n_bytes}
			unsafe { vmemcpy(ns_buf.data, data_ptr, n_bytes) }
			for r in 0 .. row_count {
				off := r * 8
				body << ns_buf[off .. off + 8]
				body << u8(0)
				body << u8(0)
				body << u8(0)
				body << u8(0)
			}
		}
		'u', 'z' {
			offsets_ptr := unsafe { (&voidptr(child.buffers))[1] }
			values_ptr  := unsafe { (&voidptr(child.buffers))[2] }
			if offsets_ptr == unsafe { nil } {
				return error("arrow: '${fmt}' column has NULL offsets buffer")
			}
			offsets_byte_len := (row_count + 1) * 4
			mut offsets_buf := []u8{len: offsets_byte_len}
			unsafe { vmemcpy(offsets_buf.data, offsets_ptr, offsets_byte_len) }
			mut prev := u32(0)
			for r in 0 .. row_count {
				next := read_u32_le(offsets_buf, (r + 1) * 4)
				slen := next - prev
				cx.encode_uvarint_pub(mut body, u64(slen))
				if slen > 0 {
					if values_ptr == unsafe { nil } {
						return error("arrow: '${fmt}' column has NULL values buffer with non-empty cell")
					}
					mut tmp := []u8{len: int(slen)}
					unsafe { vmemcpy(tmp.data, voidptr(usize(values_ptr) + usize(prev)), int(slen)) }
					body << tmp
				}
				prev = next
			}
		}
		else {
			// W1 v0.7.0 parametric scalar dispatch.
			if fmt.starts_with('d:') {
				copy_fixed_width_data(mut body, child, row_count, 16, 'decimal128')!
			} else if fmt.starts_with('ts') && fmt.len >= 4 && fmt[3] == `:` {
				copy_fixed_width_data(mut body, child, row_count, 8, 'timestamp[parametric]')!
			} else if fmt.starts_with('w:') {
				width := fmt[2..].int()
				if width <= 0 {
					return error("arrow: fixed-size-binary width must be > 0: '${fmt}'")
				}
				copy_fixed_width_data(mut body, child, row_count, width, 'fixed-size-binary')!
			} else {
				return error("arrow: format '${fmt}' not handled in encoder")
			}
		}
	}
}

fn copy_fixed_width_data(mut body []u8, child &C.ArrowArray, row_count int, bytes_per_row int, label string) ! {
	data_ptr := unsafe { (&voidptr(child.buffers))[1] }
	if data_ptr == unsafe { nil } {
		return error('arrow: ${label} column has NULL data buffer')
	}
	n_bytes := row_count * bytes_per_row
	mut tmp := []u8{len: n_bytes}
	unsafe { vmemcpy(tmp.data, data_ptr, n_bytes) }
	body << tmp
}

fn read_u32_le(buf []u8, off int) u32 {
	return u32(buf[off]) | (u32(buf[off + 1]) << 8)
		| (u32(buf[off + 2]) << 16) | (u32(buf[off + 3]) << 24)
}
