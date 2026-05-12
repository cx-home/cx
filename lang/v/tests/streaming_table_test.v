module main

// Streaming Table + schema-driven + chunked-table V cffi tests
// (Phase 7.74b-cont-3). Mirrors the Swift / Python / Kotlin / Java /
// C# / Go / Rust / TypeScript suites: 4 streaming-Table cases
// (in-memory round-trip, fd round-trip, closed-handle, multi-row-group)
// + 1 schema-driven round-trip.
//
// V's lack of RAII / IDisposable means TableReader / TableWriter
// require explicit close() from callers — the tests reflect that.

import os
import cffi as cxlib

const small_table_cx = '[points :table[name:string score:i32]
  alice 91
  bob 88
  carol 73
  dave 95
  eve 84
  frank 60
]'

// reframe re-prepends the [u32 LE size] frame to UNFRAMED CXDB payload.
fn reframe(payload []u8) []u8 {
	mut out := []u8{len: 4 + payload.len}
	size := u32(payload.len)
	out[0] = u8(size & 0xff)
	out[1] = u8((size >> 8)  & 0xff)
	out[2] = u8((size >> 16) & 0xff)
	out[3] = u8((size >> 24) & 0xff)
	for i in 0 .. payload.len {
		out[4 + i] = payload[i]
	}
	return out
}

// ── 1. in-memory round-trip ──────────────────────────────────────────────────

fn test_streaming_table_in_memory_round_trip() {
	payload := cxlib.to_data_bin_chunked(small_table_cx) or {
		assert false, 'to_data_bin_chunked: ${err}'
		return
	}
	assert payload.len > 12, 'expected payload > 12 bytes, got ${payload.len}'
	framed := reframe(payload)

	mut reader := cxlib.new_table_reader(framed) or {
		assert false, 'new_table_reader: ${err}'
		return
	}
	schema := reader.schema() or {
		reader.close()
		assert false, 'schema(): ${err}'
		return
	}
	assert schema.len > 4, 'expected non-empty framed schema, got ${schema.len}'
	groups := reader.collect() or {
		reader.close()
		assert false, 'collect(): ${err}'
		return
	}
	reader.close()
	assert groups.len >= 1, 'expected at least one row group, got ${groups.len}'

	mut writer := cxlib.new_table_writer(schema) or {
		assert false, 'new_table_writer: ${err}'
		return
	}
	for g in groups {
		writer.emit(g) or {
			writer.close()
			assert false, 'emit: ${err}'
			return
		}
	}
	rebuilt := writer.close_get_bytes() or {
		assert false, 'close_get_bytes: ${err}'
		return
	}
	assert rebuilt.len > 4, 'rebuilt buffer too small: ${rebuilt.len}'

	// Replay through a fresh reader and verify schema + group count.
	mut reader2 := cxlib.new_table_reader(rebuilt) or {
		assert false, 'reopen: ${err}'
		return
	}
	schema2 := reader2.schema() or {
		reader2.close()
		assert false, 'schema2: ${err}'
		return
	}
	groups2 := reader2.collect() or {
		reader2.close()
		assert false, 'collect2: ${err}'
		return
	}
	reader2.close()
	assert schema2 == schema, 'schema drift after round-trip'
	assert groups2.len == groups.len,
	       'group-count drift ${groups2.len} vs ${groups.len}'
}

// ── 2. fd round-trip ─────────────────────────────────────────────────────────

fn test_streaming_table_fd_round_trip() {
	payload := cxlib.to_data_bin_chunked(small_table_cx) or {
		assert false, 'to_data_bin_chunked: ${err}'
		return
	}
	mut reader_in := cxlib.new_table_reader(reframe(payload)) or {
		assert false, 'new_table_reader: ${err}'
		return
	}
	schema := reader_in.schema() or {
		reader_in.close()
		assert false, 'schema(): ${err}'
		return
	}
	groups := reader_in.collect() or {
		reader_in.close()
		assert false, 'collect: ${err}'
		return
	}
	reader_in.close()

	tmp := os.join_path(os.temp_dir(), 'cx_v_cffi_streaming_${os.getpid()}.cxdb')
	defer { os.rm(tmp) or {} }

	mut wfile := os.open_file(tmp, 'w') or {
		assert false, 'open_file w: ${err}'
		return
	}
	mut writer := cxlib.new_table_writer_fd(schema, wfile.fd) or {
		wfile.close()
		assert false, 'new_table_writer_fd: ${err}'
		return
	}
	for g in groups {
		writer.emit(g) or {
			writer.close()
			wfile.close()
			assert false, 'emit: ${err}'
			return
		}
	}
	writer.close()
	wfile.close()

	mut rfile := os.open_file(tmp, 'r') or {
		assert false, 'open_file r: ${err}'
		return
	}
	mut reader_out := cxlib.new_table_reader_fd(rfile.fd) or {
		rfile.close()
		assert false, 'new_table_reader_fd: ${err}'
		return
	}
	schema_out := reader_out.schema() or {
		reader_out.close()
		rfile.close()
		assert false, 'schema_out: ${err}'
		return
	}
	groups_out := reader_out.collect() or {
		reader_out.close()
		rfile.close()
		assert false, 'collect: ${err}'
		return
	}
	reader_out.close()
	rfile.close()

	assert schema_out == schema, 'fd schema drift'
	assert groups_out.len == groups.len,
	       'fd group-count drift ${groups_out.len} vs ${groups.len}'
}

// ── 3. closed-handle errors ──────────────────────────────────────────────────

fn test_streaming_table_closed_handle_errors() {
	payload := cxlib.to_data_bin_chunked(small_table_cx) or {
		assert false, 'to_data_bin_chunked: ${err}'
		return
	}
	framed := reframe(payload)

	// Reader: schema() on closed handle errors.
	mut reader := cxlib.new_table_reader(framed) or {
		assert false, 'new_table_reader: ${err}'
		return
	}
	reader.close()
	// next_row_group() on a closed reader returns empty (EOF semantics).
	g := reader.next_row_group() or {
		assert false, 'next_row_group should not error on closed reader: ${err}'
		return
	}
	assert g.len == 0, 'next_row_group on closed reader should return empty'
	// schema() on closed handle errors.
	if _ := reader.schema() {
		assert false, 'expected error from schema() on closed reader'
	} else {
		assert err.msg().contains('closed'), "expected 'closed' in: ${err.msg()}"
	}

	// Writer: emit() after close_get_bytes errors.
	mut reader2 := cxlib.new_table_reader(framed) or {
		assert false, 'new_table_reader 2: ${err}'
		return
	}
	schema := reader2.schema() or {
		reader2.close()
		assert false, 'schema 2: ${err}'
		return
	}
	groups := reader2.collect() or {
		reader2.close()
		assert false, 'collect 2: ${err}'
		return
	}
	reader2.close()

	mut writer := cxlib.new_table_writer(schema) or {
		assert false, 'new_table_writer: ${err}'
		return
	}
	for grp in groups {
		writer.emit(grp) or {
			writer.close()
			assert false, 'emit: ${err}'
			return
		}
	}
	_ := writer.close_get_bytes() or {
		assert false, 'close_get_bytes: ${err}'
		return
	}
	mut got_err := false
	writer.emit(groups[0]) or {
		got_err = true
		assert err.msg().contains('closed'), "expected 'closed' in: ${err.msg()}"
	}
	assert got_err, 'expected error from emit() after close_get_bytes'
}

// ── 4. multi-row-group reuse via writer pipe ─────────────────────────────────

fn test_streaming_table_multi_row_group_merge() {
	cx1 := '[points :table[name:string score:i32] alice 91 bob 88]'
	cx2 := '[points :table[name:string score:i32] carol 73 dave 95 eve 84]'
	p1 := cxlib.to_data_bin_chunked(cx1) or {
		assert false, 'p1: ${err}'
		return
	}
	p2 := cxlib.to_data_bin_chunked(cx2) or {
		assert false, 'p2: ${err}'
		return
	}

	mut r1 := cxlib.new_table_reader(reframe(p1)) or {
		assert false, 'r1 open: ${err}'
		return
	}
	schema := r1.schema() or {
		r1.close()
		assert false, 'r1 schema: ${err}'
		return
	}
	g1 := r1.collect() or {
		r1.close()
		assert false, 'r1 collect: ${err}'
		return
	}
	r1.close()

	mut r2 := cxlib.new_table_reader(reframe(p2)) or {
		assert false, 'r2 open: ${err}'
		return
	}
	g2 := r2.collect() or {
		r2.close()
		assert false, 'r2 collect: ${err}'
		return
	}
	r2.close()

	assert g1.len >= 1 && g2.len >= 1

	mut writer := cxlib.new_table_writer(schema) or {
		assert false, 'writer open: ${err}'
		return
	}
	for g in g1 {
		writer.emit(g) or {
			writer.close()
			assert false, 'emit g1: ${err}'
			return
		}
	}
	for g in g2 {
		writer.emit(g) or {
			writer.close()
			assert false, 'emit g2: ${err}'
			return
		}
	}
	rebuilt := writer.close_get_bytes() or {
		assert false, 'close_get_bytes: ${err}'
		return
	}

	// Re-open and assert merged group count.
	mut r3 := cxlib.new_table_reader(rebuilt) or {
		assert false, 'reopen merged: ${err}'
		return
	}
	groups_out := r3.collect() or {
		r3.close()
		assert false, 'collect merged: ${err}'
		return
	}
	r3.close()
	assert groups_out.len == g1.len + g2.len,
	       'merged group count ${groups_out.len} vs ${g1.len + g2.len}'
}

// ── 5. schema-driven round-trip ──────────────────────────────────────────────

fn test_schema_driven_round_trip() {
	cx_text := '[server [host "localhost"] [port 8080]]'
	schema  := '[server [host :string] [port :int]]'
	payload := cxlib.to_data_bin_schema_driven(cx_text, schema, .content_hash, '') or {
		assert false, 'to_data_bin_schema_driven: ${err}'
		return
	}
	assert payload.len > 12, 'expected payload > 12 bytes, got ${payload.len}'

	framed := reframe(payload)
	out := cxlib.from_data_bin_schema_driven(framed, schema) or {
		assert false, 'from_data_bin_schema_driven: ${err}'
		return
	}
	assert out.contains('server'),    "expected 'server' in: ${out}"
	assert out.contains('localhost'), "expected 'localhost' in: ${out}"
	assert out.contains('8080'),      "expected '8080' in: ${out}"
}
