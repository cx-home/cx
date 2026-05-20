module arrow

import cx

// CXDB ↔ Arrow C-Data ABI round-trip tests — Phase 7.74c (ADR 0015 D9).
// Exercises the V-level export / import paths used by the 4 C ABI
// symbols. The C ABI itself is exercised indirectly: cabi.v's exports
// thunk into the same V helpers.

const four_col_table = '[points :table[name:string score:int ratio:float passed:bool]
  alice 91 0.91 +
  bob 88 0.88 +
  carol 73 0.73 -
  dave 95 0.95 +
]'

fn test_export_then_import_round_trip_four_col() {
	doc := cx.parse(four_col_table) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 2, compress: .never }
	cxdb_in := cx.emit_data_bin_chunked(doc, opts) or {
		panic('emit_data_bin_chunked failed: ${err}')
	}

	// Export: CXDB chunked-table → ArrowArrayStream.
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), cxdb_in) or {
		panic('export failed: ${err}')
	}
	assert stream.get_schema != unsafe { nil }, 'get_schema not populated'
	assert stream.get_next != unsafe { nil }, 'get_next not populated'
	assert stream.release != unsafe { nil }, 'release not populated'

	// Import: ArrowArrayStream → CXDB chunked-table.
	cxdb_out := import_drain_to_bytes(voidptr(stream)) or {
		panic('import failed: ${err}')
	}
	unsafe { free(voidptr(stream)) }

	// Structural equivalence: re-parse both through parse_data_bin
	// and emit back to CX. The chunked-streaming round-trip drops
	// the outer single-pair-map wrapper (writer doesn't preserve the
	// table's element name), so direct byte comparison is too strict.
	doc_in_again := cx.parse_data_bin(cxdb_in) or { panic('parse cxdb_in: ${err}') }
	doc_out := cx.parse_data_bin(cxdb_out) or { panic('parse cxdb_out: ${err}') }
	txt_in := cx.emit_cx(doc_in_again)
	txt_out := cx.emit_cx(doc_out)
	for needle in ['alice', 'bob', 'carol', 'dave', '91', '88', '73', '95',
		'0.91', '0.88', '0.73', '0.95'] {
		assert txt_in.contains(needle), 'txt_in missing ${needle}: ${txt_in}'
		assert txt_out.contains(needle), 'txt_out missing ${needle}: ${txt_out}'
	}
}

fn test_export_unsupported_type_errors() {
	// v0.7.0 extended the supported type set with decimal128 / timestamp
	// (parametric) / fixed-size-binary / dict-utf8 (W1). Truly unknown
	// types still error out — `struct` is one such (nested-type model
	// pending cx-table cell-model evolution).
	arrow_format_for_cxdb_type('struct') or {
		assert err.msg().contains('not yet supported in v0.7.0'),
			'expected deferred-type error, got: ${err.msg()}'
		return
	}
	assert false, 'expected error for unsupported column type'
}

// W1 v0.7.0: new scalar type-name additions resolve to their Arrow
// format strings.

fn test_w1_decimal128_format_default() {
	fmt := arrow_format_for_cxdb_type('decimal128') or { panic(err) }
	assert fmt == 'd:38,10', 'expected d:38,10, got: ${fmt}'
}

fn test_w1_decimal128_parametric_format() {
	fmt := arrow_format_for_cxdb_type('decimal128[18,4]') or { panic(err) }
	assert fmt == 'd:18,4', 'expected d:18,4, got: ${fmt}'
}

fn test_w1_timestamp_parametric_format() {
	fmt := arrow_format_for_cxdb_type('timestamp[us, America/New_York]') or { panic(err) }
	assert fmt == 'tsu:America/New_York', 'expected tsu:America/New_York, got: ${fmt}'
}

fn test_w1_fixed_size_binary_format() {
	fmt := arrow_format_for_cxdb_type('fixed-size-binary[16]') or { panic(err) }
	assert fmt == 'w:16', 'expected w:16, got: ${fmt}'
}

fn test_w1_inverse_decimal128() {
	name := cxdb_type_name_from_arrow_format('d:18,4') or { panic(err) }
	assert name == 'decimal128[18,4]', 'expected decimal128[18,4], got: ${name}'
}

fn test_w1_inverse_timestamp_parametric() {
	name := cxdb_type_name_from_arrow_format('tsu:UTC') or { panic(err) }
	assert name == 'timestamp[us, UTC]', 'expected timestamp[us, UTC], got: ${name}'
}

fn test_w1_inverse_timestamp_datetime_shorthand_preserved() {
	// The v0.6.0 shorthand 'datetime' maps from ns:UTC for round-trip
	// stability with pre-W1 fixtures.
	name := cxdb_type_name_from_arrow_format('tsn:UTC') or { panic(err) }
	assert name == 'datetime', 'expected datetime, got: ${name}'
}

fn test_w1_inverse_fixed_size_binary() {
	name := cxdb_type_name_from_arrow_format('w:32') or { panic(err) }
	assert name == 'fixed-size-binary[32]', 'expected fixed-size-binary[32], got: ${name}'
}

fn test_export_then_import_round_trip_datetime() {
	src := '[evts :table[name:string when:datetime]
  launch 2024-01-15T12:34:56Z
  promo  2025-06-30T23:00:00+02:00
  epoch  1970-01-01T00:00:00Z
  past   1900-01-01T00:00:00Z
]'
	doc := cx.parse(src) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 2, compress: .never }
	cxdb_in := cx.emit_data_bin_chunked(doc, opts) or { panic('emit: ${err}') }
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), cxdb_in) or { panic('export: ${err}') }

	sch := alloc_zero_arrow_schema()
	rc := stream.get_schema(stream, sch)
	assert rc == 0, 'get_schema rc=${rc}'
	assert int(sch.n_children) == 2
	c1 := unsafe { &C.ArrowSchema((&voidptr(sch.children))[1]) }
	fmt := unsafe { cstring_to_vstring(c1.format) }
	assert fmt == 'tsn:UTC', "expected 'tsn:UTC'; got '${fmt}'"
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }

	cxdb_out := import_drain_to_bytes(voidptr(stream)) or { panic('import: ${err}') }
	unsafe { free(voidptr(stream)) }

	doc_out := cx.parse_data_bin(cxdb_out) or { panic('parse cxdb_out: ${err}') }
	txt_out := cx.emit_cx(doc_out)
	// UTC normalization: +02:00 offset normalized to Z on the wire.
	for needle in ['2024-01-15T12:34:56Z', '2025-06-30T21:00:00Z',
		'1970-01-01T00:00:00Z', '1900-01-01T00:00:00Z'] {
		assert txt_out.contains(needle), 'txt_out missing ${needle}: ${txt_out}'
	}
}

fn test_export_then_import_round_trip_int_widths() {
	src := '[stats :table[u8x:i8 u16x:i16 u32x:i32]
  -1 -1000 -1000000
  127 32767 2147483647
  0 0 0
  -128 -32768 -2147483648
]'
	doc := cx.parse(src) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 2, compress: .never }
	cxdb_in := cx.emit_data_bin_chunked(doc, opts) or { panic('emit: ${err}') }
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), cxdb_in) or { panic('export: ${err}') }

	// Schema check.
	sch := alloc_zero_arrow_schema()
	rc := stream.get_schema(stream, sch)
	assert rc == 0, 'get_schema rc=${rc}'
	assert int(sch.n_children) == 3
	expected_fmts := ['c', 's', 'i']
	for i in 0 .. 3 {
		child_ptr := unsafe { (&voidptr(sch.children))[i] }
		child := unsafe { &C.ArrowSchema(child_ptr) }
		fmt := unsafe { cstring_to_vstring(child.format) }
		assert fmt == expected_fmts[i], 'col ${i}: expected ${expected_fmts[i]}; got ${fmt}'
	}
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }

	cxdb_out := import_drain_to_bytes(voidptr(stream)) or { panic('import: ${err}') }
	unsafe { free(voidptr(stream)) }

	doc_in_again := cx.parse_data_bin(cxdb_in) or { panic('parse cxdb_in: ${err}') }
	doc_out := cx.parse_data_bin(cxdb_out) or { panic('parse cxdb_out: ${err}') }
	txt_in := cx.emit_cx(doc_in_again)
	txt_out := cx.emit_cx(doc_out)
	for needle in ['127', '-128', '32767', '-32768', '2147483647', '-2147483648'] {
		assert txt_in.contains(needle), 'txt_in missing ${needle}: ${txt_in}'
		assert txt_out.contains(needle), 'txt_out missing ${needle}: ${txt_out}'
	}
}

fn test_export_then_import_round_trip_date() {
	src := '[evts :table[name:string when:date]
  launch 2026-05-09
  promo  2026-06-01
  epoch  1970-01-01
  past   1900-01-01
  future 9999-12-31
]'
	doc := cx.parse(src) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 3, compress: .never }
	cxdb_in := cx.emit_data_bin_chunked(doc, opts) or { panic('emit: ${err}') }
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), cxdb_in) or { panic('export: ${err}') }

	sch := alloc_zero_arrow_schema()
	rc := stream.get_schema(stream, sch)
	assert rc == 0
	assert int(sch.n_children) == 2
	c1 := unsafe { &C.ArrowSchema((&voidptr(sch.children))[1]) }
	fmt := unsafe { cstring_to_vstring(c1.format) }
	assert fmt == 'tdD', "expected 'tdD'; got '${fmt}'"
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }

	cxdb_out := import_drain_to_bytes(voidptr(stream)) or { panic('import: ${err}') }
	unsafe { free(voidptr(stream)) }

	doc_out := cx.parse_data_bin(cxdb_out) or { panic('parse cxdb_out: ${err}') }
	txt_out := cx.emit_cx(doc_out)
	for needle in ['2026-05-09', '2026-06-01', '1970-01-01', '1900-01-01', '9999-12-31'] {
		assert txt_out.contains(needle), 'txt_out missing ${needle}: ${txt_out}'
	}
}

fn test_export_then_import_round_trip_bytes() {
	// `bytes` columns store opaque byte sequences. The CX text form
	// is a parser-level convenience; we go via emit_data_bin_chunked
	// directly so the column actually carries `bytes` cell payloads.
	src := '[blobs :table[name:string blob:bytes]
  alpha "A1B2"
  beta  "FF00DE"
  empty ""
]'
	doc := cx.parse(src) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 2, compress: .never }
	cxdb_in := cx.emit_data_bin_chunked(doc, opts) or { panic('emit: ${err}') }
	stream := alloc_zero_arrow_stream()
	export_populate_stream_bytes(voidptr(stream), cxdb_in) or { panic('export: ${err}') }

	sch := alloc_zero_arrow_schema()
	rc := stream.get_schema(stream, sch)
	assert rc == 0
	c1 := unsafe { &C.ArrowSchema((&voidptr(sch.children))[1]) }
	fmt := unsafe { cstring_to_vstring(c1.format) }
	assert fmt == 'z', "expected 'z' (binary); got '${fmt}'"
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }

	cxdb_out := import_drain_to_bytes(voidptr(stream)) or { panic('import: ${err}') }
	unsafe { free(voidptr(stream)) }

	doc_out := cx.parse_data_bin(cxdb_out) or { panic('parse cxdb_out: ${err}') }
	txt_out := cx.emit_cx(doc_out)
	for needle in ['alpha', 'beta', 'empty'] {
		assert txt_out.contains(needle), 'txt_out missing ${needle}: ${txt_out}'
	}
}

fn test_date_helpers_round_trip() {
	// Anchor checks against pyarrow's date32 reference values.
	anchors := [
		[i32(1970), i32(1),  i32(1),  i32(0)],       // epoch
		[i32(2000), i32(1),  i32(1),  i32(10957)],   // 30y after epoch
		[i32(1900), i32(1),  i32(1),  i32(-25567)],  // pre-epoch
	]
	for c in anchors {
		y := i16(c[0])
		mo := u8(c[1])
		dd := u8(c[2])
		expected := c[3]
		got := date_to_days(y, mo, dd)
		assert got == expected, '${y}-${mo}-${dd}: expected ${expected} days; got ${got}'
	}
	// Round-trip property over a wide year range covering Arrow date32's
	// useful CXDB-mappable range (CXDB year is i16 so [-32768, 32767]).
	round_trip_cases := [
		[i32(2026), i32(5),  i32(9)],
		[i32(9999), i32(12), i32(31)],
		[i32(1),    i32(1),  i32(1)],
		[i32(-2000), i32(2), i32(29)], // BC 400-cycle leap year
		[i32(2400), i32(2),  i32(29)], // 400-cycle leap year
		[i32(2100), i32(2),  i32(28)], // 100-cycle non-leap
	]
	for c in round_trip_cases {
		y := i16(c[0])
		mo := u8(c[1])
		dd := u8(c[2])
		days := date_to_days(y, mo, dd)
		yy, mm, ddd := days_to_date(days)
		assert yy == y && mm == mo && ddd == dd,
			'round trip failed for ${y}-${mo}-${dd} → ${days} days → ${yy}-${mm}-${ddd}'
	}
}

fn test_export_empty_then_eos() {
	// Single small row group; verify the stream emits one ArrayChunk
	// then signals EOS.
	src := '[xs :table[i:int]
  1
  2
  3
]'
	doc := cx.parse(src) or { panic('parse failed: ${err}') }
	opts := cx.ChunkedEmitOptions{ chunk_size: 1024, compress: .never }
	cxdb := cx.emit_data_bin_chunked(doc, opts) or { panic('emit: ${err}') }

	stream := alloc_zero_arrow_stream()
	defer { unsafe { free(voidptr(stream)) } }
	export_populate_stream_bytes(voidptr(stream), cxdb) or { panic('export: ${err}') }

	// Pull schema.
	sch := alloc_zero_arrow_schema()
	rc1 := stream.get_schema(stream, sch)
	assert rc1 == 0, 'get_schema rc=${rc1}'
	assert int(sch.n_children) == 1, 'expected 1 column; got ${sch.n_children}'
	if sch.release != unsafe { nil } { sch.release(sch) }
	unsafe { free(voidptr(sch)) }

	// Pull row groups until EOS (release == nil).
	mut group_count := 0
	for {
		arr := alloc_zero_arrow_array()
		rc2 := stream.get_next(stream, arr)
		assert rc2 == 0, 'get_next rc=${rc2}'
		if arr.release == unsafe { nil } {
			unsafe { free(voidptr(arr)) }
			break
		}
		group_count++
		assert int(arr.length) == 3, 'expected length=3; got ${arr.length}'
		assert int(arr.n_children) == 1, 'expected n_children=1; got ${arr.n_children}'
		arr.release(arr)
		unsafe { free(voidptr(arr)) }
	}
	assert group_count == 1, 'expected 1 row group; got ${group_count}'
	if stream.release != unsafe { nil } {
		stream.release(stream)
	}
}

fn test_capability_string() {
	feats := unsafe { cstring_to_vstring(cx_arrow_features()) }
	assert feats == '0x800000', "expected '0x800000'; got '${feats}'"
}

fn test_version_string() {
	v := unsafe { cstring_to_vstring(cx_arrow_version()) }
	assert v == '0.6.0', "expected '0.6.0'; got '${v}'"
}

