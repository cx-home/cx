// CX V-cffi binding — Public Table API per ADR 0018 D1.
//
// 17-member canonical Table surface against the V core's :table blocks
// via the C ABI. Per ADR 0018 §D2: V uses snake_case methods matching
// the canonical surface (rename `select` → `select_cols`).
//
// Path:
//   cx text → cx_to_data_bin (C ABI) → CXDB v1 payload → decode walk
//   → Table value with rows as []map[string]CellValue.

module cffi

import strings
import json as v_json

// ── FFI declaration ──────────────────────────────────────────────────────────

fn C.cx_to_data_bin(input charptr, err_out &charptr) charptr

// to_data_bin: one-shot CX → CXDB v1 PAYLOAD (frame stripped).
pub fn to_data_bin(input string) ![]u8 {
	mut err := charptr(0)
	out := C.cx_to_data_bin(charptr(input.str), &err)
	if out == charptr(0) {
		return error(err_msg(err, 'cx_to_data_bin: unknown error'))
	}
	buf := strip_frame(out)
	C.cx_free(out)
	return buf
}

// ── CellValue sum type ───────────────────────────────────────────────────────

pub type CellValue = NullCell | bool | i64 | f64 | string | []CellValue | map[string]CellValue

pub struct NullCell {}

// ── Table ────────────────────────────────────────────────────────────────────

pub struct Table {
mut:
	cols_  []string
	types_ []string
	rows_  [][]CellValue
}

// ── Construction ─────────────────────────────────────────────────────────────

// from_cx parses CX source and returns the first :table block.
pub fn table_from_cx(src string) !Table {
	tables := table_from_cx_all(src)!
	if tables.len == 0 {
		return error('cxlib: no :table block found in source')
	}
	return tables[0]
}

// from_cx_all returns every :table block in the source (preorder).
pub fn table_from_cx_all(src string) ![]Table {
	payload := to_data_bin(src)!
	decoded := decode_data_bin(payload)!
	mut out := []Table{}
	collect_tables(decoded, mut out)
	return out
}

// create — direct construction with 4-invariant validation per ADR 0018 §D7.
pub fn table_create(cols []string, types []string, rows [][]CellValue) !Table {
	if cols.len != types.len {
		return error('cxlib: len(cols)=${cols.len} != len(types)=${types.len}')
	}
	mut seen := map[string]bool{}
	for c in cols {
		if c in seen {
			return error('cxlib: duplicate column name "${c}"')
		}
		seen[c] = true
	}
	for i, row in rows {
		if row.len != cols.len {
			return error('cxlib: row ${i} has ${row.len} cells; expected ${cols.len}')
		}
	}
	return Table{
		cols_:  cols.clone()
		types_: types.clone()
		rows_:  rows.clone()
	}
}

// ── Properties (4) ───────────────────────────────────────────────────────────

pub fn (t Table) cols() []string  { return t.cols_.clone() }
pub fn (t Table) types() []string { return t.types_.clone() }
pub fn (t Table) row_count() int  { return t.rows_.len }
pub fn (t Table) col_count() int  { return t.cols_.len }

// ── Access (9) ───────────────────────────────────────────────────────────────

pub fn (t Table) row(i int) !map[string]CellValue {
	if i < 0 || i >= t.rows_.len {
		return error('cxlib: row index ${i} out of bounds [0, ${t.rows_.len})')
	}
	mut out := map[string]CellValue{}
	for c, name in t.cols_ { out[name] = t.rows_[i][c] }
	return out
}

pub fn (t Table) column(name string) ![]CellValue {
	idx := t.cols_.index(name)
	if idx < 0 { return error('cxlib: unknown column "${name}"') }
	return t.col_at(idx)!
}

pub fn (t Table) col_at(i int) ![]CellValue {
	if i < 0 || i >= t.cols_.len {
		return error('cxlib: column index ${i} out of bounds [0, ${t.cols_.len})')
	}
	return t.rows_.map(it[i])
}

pub fn (t Table) cell(r int, c int) !CellValue {
	if r < 0 || r >= t.rows_.len {
		return error('cxlib: row index ${r} out of bounds [0, ${t.rows_.len})')
	}
	if c < 0 || c >= t.cols_.len {
		return error('cxlib: column index ${c} out of bounds [0, ${t.cols_.len})')
	}
	return t.rows_[r][c]
}

pub fn (t Table) cell_by_name(r int, name string) !CellValue {
	idx := t.cols_.index(name)
	if idx < 0 { return error('cxlib: unknown column "${name}"') }
	return t.cell(r, idx)!
}

pub fn (t Table) slice(start int, end int) !Table {
	if start < 0 || start > t.rows_.len {
		return error('cxlib: slice start ${start} out of bounds')
	}
	if end < start || end > t.rows_.len {
		return error('cxlib: slice end ${end} out of bounds (start=${start})')
	}
	return Table{ cols_: t.cols_.clone(), types_: t.types_.clone(), rows_: t.rows_[start..end].clone() }
}

pub fn (t Table) head(n int) !Table {
	mut bound := if n < 0 { 0 } else { n }
	if bound > t.rows_.len { bound = t.rows_.len }
	return t.slice(0, bound)!
}

pub fn (t Table) tail(n int) !Table {
	mut start := t.rows_.len - n
	if start < 0 { start = 0 }
	return t.slice(start, t.rows_.len)!
}

// select_cols — renamed from canonical `select` (V uses snake_case).
pub fn (t Table) select_cols(names []string) !Table {
	mut indices := []int{}
	mut new_cols := []string{}
	mut new_types := []string{}
	for name in names {
		idx := t.cols_.index(name)
		if idx < 0 { return error('cxlib: unknown column "${name}"') }
		indices << idx
		new_cols << t.cols_[idx]
		new_types << t.types_[idx]
	}
	mut new_rows := [][]CellValue{cap: t.rows_.len}
	for row in t.rows_ {
		mut nr := []CellValue{cap: indices.len}
		for i in indices { nr << row[i] }
		new_rows << nr
	}
	return Table{ cols_: new_cols, types_: new_types, rows_: new_rows }
}

// ── Iteration (2) ────────────────────────────────────────────────────────────

// iter_rows — yields each row as a map; V doesn't have generators so this
// returns the list (callers `for row in t.iter_rows()`).
pub fn (t Table) iter_rows() []map[string]CellValue {
	mut out := []map[string]CellValue{cap: t.rows_.len}
	for i in 0 .. t.rows_.len {
		out << t.row(i) or { map[string]CellValue{} }
	}
	return out
}

pub struct ColumnView {
pub:
	name      string
	type_name string
	values    []CellValue
}

pub fn (t Table) iter_cols() []ColumnView {
	mut out := []ColumnView{cap: t.cols_.len}
	for i, name in t.cols_ {
		out << ColumnView{ name: name, type_name: t.types_[i], values: t.col_at(i) or { []CellValue{} } }
	}
	return out
}

// ── Conversion (5) ───────────────────────────────────────────────────────────

pub fn (t Table) to_cx() string {
	mut sb := strings.new_builder(128)
	sb.write_string('[_ :table[')
	for i, c in t.cols_ {
		if i > 0 { sb.write_string(' ') }
		sb.write_string(c)
		if t.types_[i] != '' { sb.write_string(':'); sb.write_string(t.types_[i]) }
	}
	sb.write_string(']\n')
	for row in t.rows_ {
		sb.write_string('  ')
		for i, v in row {
			if i > 0 { sb.write_string(' ') }
			sb.write_string(format_cx_cell(v))
		}
		sb.write_string('\n')
	}
	sb.write_string(']\n')
	return sb.str()
}

pub fn (t Table) to_csv(delim rune) !string {
	if delim < 0x20 || delim > 0x7E {
		return error('cxlib: to_csv delim must be printable ASCII')
	}
	mut sb := strings.new_builder(128)
	for i, c in t.cols_ {
		if i > 0 { sb.write_rune(delim) }
		sb.write_string(c)
	}
	sb.write_string('\r\n')
	for row in t.rows_ {
		for i, v in row {
			if i > 0 { sb.write_rune(delim) }
			sb.write_string(format_csv_cell(v, delim))
		}
		sb.write_string('\r\n')
	}
	return sb.str()
}

pub fn (t Table) to_json() string {
	mut parts := []string{}
	for i in 0 .. t.rows_.len {
		row := t.row(i) or { continue }
		mut kv := []string{}
		for k, v in row {
			kv << '"${escape_json_string(k)}":${cell_to_json(v)}'
		}
		parts << '{${kv.join(',')}}'
	}
	return '[${parts.join(',')}]'
}

pub fn (t Table) to_data_bin() ![]u8 { return to_data_bin(t.to_cx())! }

pub fn (t Table) to_dict_list() []map[string]CellValue { return t.iter_rows() }

// ── Equality ─────────────────────────────────────────────────────────────────

pub fn (a Table) equals(b Table) bool {
	if a.cols_ != b.cols_ { return false }
	if a.types_ != b.types_ { return false }
	if a.rows_.len != b.rows_.len { return false }
	for r in 0 .. a.rows_.len {
		if a.rows_[r].len != b.rows_[r].len { return false }
		for c in 0 .. a.rows_[r].len {
			if !cell_equals(a.rows_[r][c], b.rows_[r][c]) { return false }
		}
	}
	return true
}

// ── Internal: walk decoded data_bin to find tables ───────────────────────────

fn collect_tables(value CellValue, mut out []Table) {
	match value {
		[]CellValue {
			if looks_like_table(value) {
				first := value[0] as map[string]CellValue
				mut keys := first.keys().clone()
				keys.sort()
				types := []string{len: keys.len, init: ''}
				mut rows := [][]CellValue{cap: value.len}
				for item in value {
					d := item as map[string]CellValue
					mut row := []CellValue{cap: keys.len}
					for k in keys { row << (d[k] or { NullCell{} }) }
					rows << row
				}
				t := table_create(keys, types, rows) or { return }
				out << t
			} else {
				for child in value { collect_tables(child, mut out) }
			}
		}
		map[string]CellValue {
			for _, child in value { collect_tables(child, mut out) }
		}
		else {}
	}
}

fn looks_like_table(list []CellValue) bool {
	if list.len == 0 { return false }
	first := list[0]
	if first is map[string]CellValue {
		key_count := first.len
		if key_count == 0 { return false }
		for item in list {
			if item is map[string]CellValue {
				if item.len != key_count { return false }
				for k in item.keys() {
					if k !in first { return false }
				}
			} else {
				return false
			}
		}
		return true
	}
	return false
}

// ── Internal: cell formatters ────────────────────────────────────────────────

fn format_cx_cell(v CellValue) string {
	return match v {
		NullCell { 'null' }
		bool { if v { 'true' } else { 'false' } }
		i64 { v.str() }
		f64 { v.str() }
		[]CellValue {
			'[' + v.map(format_cx_cell(it)).join(', ') + ']'
		}
		map[string]CellValue {
			mut keys := v.keys()
			keys.sort()
			pairs := keys.map('${format_cx_key(it)}: ${format_cx_cell(v[it])}')
			'{' + pairs.join(', ') + '}'
		}
		string {
			if v == '' || needs_quote(v) {
				"'" + v.replace("'", "''") + "'"
			} else {
				v
			}
		}
	}
}

fn needs_quote(s string) bool {
	for c in s {
		if c == ` ` || c == `\t` || c == `\n` || c == `\r`
			|| c == `'` || c == `[` || c == `]`
			|| c == `(` || c == `)` || c == `{` || c == `}` || c == `,` {
			return true
		}
	}
	return false
}

fn format_cx_key(k string) string {
	if k.len == 0 { return "'" + k + "'" }
	for i, ch in k {
		ok := ch == `_`
			|| (ch >= `a` && ch <= `z`)
			|| (ch >= `A` && ch <= `Z`)
			|| (i > 0 && ch >= `0` && ch <= `9`)
		if !ok { return "'" + k.replace("'", "''") + "'" }
	}
	return k
}

fn format_csv_cell(v CellValue, delim rune) string {
	return match v {
		NullCell { '' }
		bool { if v { 'true' } else { 'false' } }
		i64 { v.str() }
		f64 { v.str() }
		string {
			if v.contains(delim.str()) || v.contains('"') || v.contains('\n') || v.contains('\r') {
				'"' + v.replace('"', '""') + '"'
			} else { v }
		}
		[]CellValue, map[string]CellValue {
			s := cell_to_json(v)
			'"' + s.replace('"', '""') + '"'
		}
	}
}

fn cell_to_json(v CellValue) string {
	return match v {
		NullCell { 'null' }
		bool { if v { 'true' } else { 'false' } }
		i64 { v.str() }
		f64 { v.str() }
		string { '"' + escape_json_string(v) + '"' }
		[]CellValue {
			'[' + v.map(cell_to_json(it)).join(',') + ']'
		}
		map[string]CellValue {
			mut parts := []string{}
			for k, vv in v {
				parts << '"${escape_json_string(k)}":${cell_to_json(vv)}'
			}
			'{' + parts.join(',') + '}'
		}
	}
}

fn escape_json_string(s string) string {
	return v_json.encode(s)[1 .. v_json.encode(s).len - 1]
}

fn cell_equals(a CellValue, b CellValue) bool {
	if a is NullCell && b is NullCell { return true }
	if a is bool && b is bool { return a == b }
	if a is i64 && b is i64 { return a == b }
	if a is f64 && b is f64 { return a == b }
	if a is string && b is string { return a == b }
	if a is []CellValue && b is []CellValue {
		la := a
		lb := b
		if la.len != lb.len { return false }
		for i in 0 .. la.len { if !cell_equals(la[i], lb[i]) { return false } }
		return true
	}
	if a is map[string]CellValue && b is map[string]CellValue {
		da := a.clone()
		db := b.clone()
		if da.len != db.len { return false }
		for k, va in da {
			vb := db[k] or { return false }
			if !cell_equals(va, vb) { return false }
		}
		return true
	}
	return false
}

// ── Internal: CXDB v1 PAYLOAD decoder (matches the C ABI's output) ───────────

const cxdb_version = u8(1)
const tag_null        = u8(0x00)
const tag_false       = u8(0x01)
const tag_true        = u8(0x02)
const tag_int8        = u8(0x10)
const tag_int16       = u8(0x11)
const tag_int32       = u8(0x12)
const tag_int64       = u8(0x13)
const tag_uint8       = u8(0x14)
const tag_uint16      = u8(0x15)
const tag_uint32      = u8(0x16)
const tag_uint64      = u8(0x17)
const tag_float64     = u8(0x20)
const tag_string      = u8(0x30)
const tag_array       = u8(0x40)
const tag_array_empty = u8(0x41)
const tag_map         = u8(0x50)
const tag_map_empty   = u8(0x51)
const tag_table       = u8(0x60)
const tag_table_empty = u8(0x61)

struct CxdbReader {
	buf []u8
mut:
	pos int
}

fn (mut r CxdbReader) need(n int) ! {
	if r.pos + n > r.buf.len {
		return error('cxdb: unexpected EOF (need ${n} at ${r.pos}, len=${r.buf.len})')
	}
}

fn (mut r CxdbReader) u8_() !u8 {
	r.need(1)!
	v := r.buf[r.pos]
	r.pos++
	return v
}

fn (mut r CxdbReader) i64_() !i64 {
	r.need(8)!
	mut v := i64(0)
	for i in 0 .. 8 {
		v |= i64(r.buf[r.pos + i]) << (8 * i)
	}
	r.pos += 8
	return v
}

fn (mut r CxdbReader) f64_() !f64 {
	bits := r.i64_()!
	return f64_from_bits(u64(bits))
}

fn f64_from_bits(b u64) f64 {
	unsafe {
		mut x := b
		return *(&f64(&x))
	}
}

fn (mut r CxdbReader) uvarint() !int {
	mut shift := u32(0)
	mut result := i64(0)
	for _ in 0 .. 10 {
		r.need(1)!
		b := r.buf[r.pos]
		r.pos++
		result |= i64(b & 0x7F) << shift
		if (b & 0x80) == 0 { return int(result) }
		shift += 7
	}
	return error('cxdb: uvarint too long')
}

fn (mut r CxdbReader) string_payload() !string {
	n := r.uvarint()!
	r.need(n)!
	s := r.buf[r.pos .. r.pos + n].bytestr()
	r.pos += n
	return s
}

fn (mut r CxdbReader) read_signed(width int) !i64 {
	r.need(width)!
	mut v := i64(0)
	for i in 0 .. width {
		v |= i64(r.buf[r.pos + i]) << (8 * i)
	}
	// sign-extend
	high_bit := i64(1) << (8 * width - 1)
	if v & high_bit != 0 {
		v |= ~((i64(1) << (8 * width)) - 1)
	}
	r.pos += width
	return v
}

fn (mut r CxdbReader) read_unsigned(width int) !i64 {
	r.need(width)!
	mut v := i64(0)
	for i in 0 .. width {
		v |= i64(r.buf[r.pos + i]) << (8 * i)
	}
	r.pos += width
	return v
}

fn (mut r CxdbReader) value() !CellValue {
	tag := r.u8_()!
	if tag == tag_null  { return CellValue(NullCell{}) }
	if tag == tag_false { return CellValue(false) }
	if tag == tag_true  { return CellValue(true) }
	if tag == tag_int8  { return CellValue(r.read_signed(1)!) }
	if tag == tag_int16 { return CellValue(r.read_signed(2)!) }
	if tag == tag_int32 { return CellValue(r.read_signed(4)!) }
	if tag == tag_int64 { return CellValue(r.read_signed(8)!) }
	if tag == tag_uint8  { return CellValue(r.read_unsigned(1)!) }
	if tag == tag_uint16 { return CellValue(r.read_unsigned(2)!) }
	if tag == tag_uint32 { return CellValue(r.read_unsigned(4)!) }
	if tag == tag_uint64 { return CellValue(r.read_unsigned(8)!) }
	if tag == tag_float64 { return CellValue(r.f64_()!) }
	if tag == tag_string { return CellValue(r.string_payload()!) }
	if tag == tag_array {
		n := r.uvarint()!
		mut out := []CellValue{cap: n}
		for _ in 0 .. n { out << r.value()! }
		return CellValue(out)
	}
	if tag == tag_array_empty { return CellValue([]CellValue{}) }
	if tag == tag_map {
		n := r.uvarint()!
		mut m := map[string]CellValue{}
		for _ in 0 .. n {
			kt := r.u8_()!
			if kt != tag_string {
				return error('cxdb: map key must be string; got 0x${kt.hex()}')
			}
			k := r.string_payload()!
			m[k] = r.value()!
		}
		return CellValue(m)
	}
	if tag == tag_map_empty { return CellValue(map[string]CellValue{}) }
	if tag == tag_table || tag == tag_table_empty { return r.table_payload(tag)! }
	return error('cxdb: unknown tag 0x${tag.hex()} at ${r.pos - 1}')
}

fn (mut r CxdbReader) table_payload(tag u8) !CellValue {
	if tag == tag_table_empty { return CellValue([]CellValue{}) }
	col_count := r.uvarint()!
	mut cols := []string{cap: col_count}
	for _ in 0 .. col_count {
		kt := r.u8_()!
		if kt != tag_string {
			return error('cxdb: table column name must be string; got 0x${kt.hex()}')
		}
		cols << r.string_payload()!
		r.u8_()! // column type code (informational)
	}
	row_count := r.uvarint()!
	mut rows := []map[string]CellValue{len: row_count, init: map[string]CellValue{}}
	for c in 0 .. col_count {
		for ri in 0 .. row_count {
			rows[ri][cols[c]] = r.value()!
		}
	}
	mut as_cells := []CellValue{cap: row_count}
	for row in rows { as_cells << CellValue(row) }
	return CellValue(as_cells)
}

fn decode_data_bin(payload []u8) !CellValue {
	if payload.len < 12 { return error('cxdb: payload too short for 12-byte header') }
	if payload[0] != `C` || payload[1] != `X` || payload[2] != `D` || payload[3] != `B` {
		return error('cxdb: bad magic (expected "CXDB")')
	}
	if payload[4] != cxdb_version {
		return error('cxdb: unsupported version ${payload[4]}')
	}
	flags := payload[5]
	if (flags & 0xFE) != 0 { return error('cxdb: reserved flag bits set in header') }
	if (flags & 0x01) == 0 { return error('cxdb: only little-endian payloads supported in v1') }
	if payload[10] != 0 || payload[11] != 0 {
		return error('cxdb: reserved header bytes must be zero')
	}
	mut r := CxdbReader{ buf: payload[12..] }
	return r.value()!
}
