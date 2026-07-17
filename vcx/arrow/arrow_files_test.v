module arrow

import cx
import os

// Phase C file I/O round-trips (Parquet + Arrow IPC). Active only under
// `-d cx_arrow_files`; a no-op otherwise (the file-I/O wrappers don't exist
// without the flag, and the comptime branch excludes their references).

const sample_table = '[points [table[name::string score::int ratio::float passed::bool]]
  alice 91 0.91 +
  bob 88 0.88 -
  carol 73 0.73 +
]'

fn sample_data_bin() []u8 {
	doc := cx.parse(sample_table) or { panic('parse failed: ${err}') }
	return cx.emit_data_bin_chunked(doc, cx.ChunkedEmitOptions{ chunk_size: 2, compress: .never }) or {
		panic('emit_data_bin_chunked failed: ${err}')
	}
}

fn assert_round_trip(back []u8) {
	doc := cx.parse_data_bin(back) or { panic('parse_data_bin failed: ${err}') }
	txt := cx.emit_cx(doc)
	for needle in ['alice', 'bob', 'carol', '91', '88', '73', '0.91', '0.88', '0.73'] {
		assert txt.contains(needle), 'round-trip missing ${needle}: ${txt}'
	}
}

fn test_parquet_round_trip() {
	$if cx_arrow_files ? {
		framed := sample_data_bin()
		path := os.join_path(os.temp_dir(), 'cx_arrow_files_parquet.parquet')
		write_parquet_data_bin(framed, path) or { panic('write_parquet: ${err}') }
		assert os.exists(path), 'parquet file not written'
		back := read_parquet_to_data_bin(path) or { panic('read_parquet: ${err}') }
		os.rm(path) or {}
		assert_round_trip(back)
	}
}

fn test_ipc_round_trip() {
	$if cx_arrow_files ? {
		framed := sample_data_bin()
		path := os.join_path(os.temp_dir(), 'cx_arrow_files_ipc.arrow')
		write_ipc_data_bin(framed, path) or { panic('write_ipc: ${err}') }
		assert os.exists(path), 'ipc file not written'
		back := read_ipc_to_data_bin(path) or { panic('read_ipc: ${err}') }
		os.rm(path) or {}
		assert_round_trip(back)
	}
}
