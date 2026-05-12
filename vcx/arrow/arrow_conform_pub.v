module arrow

// Public surface used by the data_bin_arrow conformance runner
// (vcx/tests/runners/conformance/data_bin_arrow_run.v). The
// fixture-driven runner exercises round-trip identity through the
// Arrow C-Data ABI without binding-internal access; these helpers
// expose just enough to do that.

// round_trip_cxdb pushes a framed CXDB chunked-table payload through
// the Arrow C-Data ABI export path and pulls it back through the
// import path, returning the framed CXDB bytes the importer
// produces. The conformance runner asserts data equivalence between
// the input and the output (round-trip-only; no Arrow-byte
// assertions, since Arrow's binary form isn't stable across
// versions).
pub fn round_trip_cxdb(framed []u8) ![]u8 {
	stream := alloc_zero_arrow_stream()
	defer { unsafe { free(voidptr(stream)) } }
	export_populate_stream_bytes(voidptr(stream), framed)!
	return import_drain_to_bytes(voidptr(stream))
}

// schema_formats decodes the Arrow schema for a framed CXDB
// chunked-table payload and returns the per-column Arrow C-Data
// format strings (e.g., 'l', 'tdD', 'tsn:UTC'). Used by the
// conformance runner's `arrow_children_formats` assertion.
pub fn schema_formats(framed []u8) ![]string {
	stream := alloc_zero_arrow_stream()
	defer {
		if stream.release != unsafe { nil } {
			stream.release(stream)
		}
		unsafe { free(voidptr(stream)) }
	}
	export_populate_stream_bytes(voidptr(stream), framed)!

	sch := alloc_zero_arrow_schema()
	defer {
		if sch.release != unsafe { nil } {
			sch.release(sch)
		}
		unsafe { free(voidptr(sch)) }
	}
	rc := stream.get_schema(stream, sch)
	if rc != 0 {
		return error('get_schema returned ${rc}')
	}
	n := int(sch.n_children)
	mut out := []string{cap: n}
	for i in 0 .. n {
		child := unsafe { &C.ArrowSchema((&voidptr(sch.children))[i]) }
		fmt := unsafe { cstring_to_vstring(child.format) }
		out << fmt
	}
	return out
}

// chunk_lengths drains the stream and returns the row count of each
// emitted ArrowArray chunk. EOS (release == nil) terminates the
// list. Used by the runner's `arrow_chunk_lengths` assertion.
pub fn chunk_lengths(framed []u8) ![]int {
	stream := alloc_zero_arrow_stream()
	defer {
		if stream.release != unsafe { nil } {
			stream.release(stream)
		}
		unsafe { free(voidptr(stream)) }
	}
	export_populate_stream_bytes(voidptr(stream), framed)!

	// Pull and discard schema first (some implementations require it).
	sch := alloc_zero_arrow_schema()
	rc := stream.get_schema(stream, sch)
	if rc != 0 {
		unsafe { free(voidptr(sch)) }
		return error('get_schema returned ${rc}')
	}
	if sch.release != unsafe { nil } {
		sch.release(sch)
	}
	unsafe { free(voidptr(sch)) }

	mut lengths := []int{}
	for {
		arr := alloc_zero_arrow_array()
		rc2 := stream.get_next(stream, arr)
		if rc2 != 0 {
			unsafe { free(voidptr(arr)) }
			return error('get_next returned ${rc2}')
		}
		if arr.release == unsafe { nil } {
			unsafe { free(voidptr(arr)) }
			break
		}
		lengths << int(arr.length)
		arr.release(arr)
		unsafe { free(voidptr(arr)) }
	}
	return lengths
}
