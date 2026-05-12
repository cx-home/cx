// V-cffi Public Table API tests (ADR 0018 D1).
module main

import cffi

fn test_from_cx_simple() {
	src := '[users :table[name age:int]
  alice 30
  bob 25
]'
	t := cffi.table_from_cx(src) or { panic(err) }
	assert t.row_count() == 2
	assert t.col_count() == 2
}

fn test_from_cx_no_table() {
	cffi.table_from_cx('[product name=alice]') or {
		assert err.msg().contains('no :table')
		return
	}
	assert false, 'expected error'
}

fn test_create_validates_len() {
	cffi.table_create(['a', 'b'], ['int'], [][]cffi.CellValue{}) or {
		assert err.msg().contains('len(cols)')
		return
	}
	assert false, 'expected error'
}

fn test_create_validates_unique() {
	cffi.table_create(['a', 'a'], ['int', 'int'], [][]cffi.CellValue{}) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false, 'expected error'
}

fn test_row_and_column() {
	t := cffi.table_create(
		['a', 'b'], ['int', 'string'],
		[
			[cffi.CellValue(i64(1)), cffi.CellValue('x')],
			[cffi.CellValue(i64(2)), cffi.CellValue('y')],
		]
	) or { panic(err) }
	row0 := t.row(0) or { panic(err) }
	a_val := row0['a'] or { panic('missing a') }
	b_val := row0['b'] or { panic('missing b') }
	assert a_val == cffi.CellValue(i64(1))
	assert b_val == cffi.CellValue('x')
	col_b := t.column('b') or { panic(err) }
	assert col_b.len == 2
	assert col_b[0] == cffi.CellValue('x')
}

fn test_slice_head_tail() {
	t := cffi.table_create(
		['v'], ['int'],
		[
			[cffi.CellValue(i64(1))], [cffi.CellValue(i64(2))],
			[cffi.CellValue(i64(3))], [cffi.CellValue(i64(4))],
			[cffi.CellValue(i64(5))],
		]
	) or { panic(err) }
	h := t.head(2) or { panic(err) }
	assert h.row_count() == 2
	tt := t.tail(2) or { panic(err) }
	assert tt.row_count() == 2
	s := t.slice(1, 4) or { panic(err) }
	assert s.row_count() == 3
}

fn test_select_cols_reorders() {
	t := cffi.table_create(
		['a', 'b', 'c'], ['int', 'int', 'int'],
		[[cffi.CellValue(i64(1)), cffi.CellValue(i64(2)), cffi.CellValue(i64(3))]]
	) or { panic(err) }
	sel := t.select_cols(['c', 'a']) or { panic(err) }
	assert sel.cols() == ['c', 'a']
}

fn test_iter_rows() {
	t := cffi.table_create(
		['a'], ['int'],
		[[cffi.CellValue(i64(1))], [cffi.CellValue(i64(2))]]
	) or { panic(err) }
	mut sum := i64(0)
	for row in t.iter_rows() {
		if v := row['a'] {
			if v is i64 { sum += v }
		}
	}
	assert sum == 3
}

fn test_to_cx() {
	t := cffi.table_create(
		['a'], ['int'], [[cffi.CellValue(i64(1))]]
	) or { panic(err) }
	out := t.to_cx()
	assert out.contains(':table[a:int]'), 'to_cx did not contain :table[a:int]: ${out}'
}

fn test_to_json() {
	t := cffi.table_create(
		['a'], ['int'], [[cffi.CellValue(i64(1))], [cffi.CellValue(i64(2))]]
	) or { panic(err) }
	js := t.to_json()
	assert js.contains('"a":1')
}

fn test_equals() {
	a := cffi.table_create(['a'], ['int'], [[cffi.CellValue(i64(1))]]) or { panic(err) }
	b := cffi.table_create(['a'], ['int'], [[cffi.CellValue(i64(1))]]) or { panic(err) }
	assert a.equals(b)
}

fn test_from_cx_collection_cells() {
	src := '[u :table[name tags]
  alice [admin, user,]
]'
	t := cffi.table_from_cx(src) or { panic(err) }
	row := t.row(0) or { panic(err) }
	tags := row['tags'] or { panic('missing tags') }
	assert tags is []cffi.CellValue, 'tags should be array, got: ${tags}'
}
