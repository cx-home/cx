module main

import os
import cx
import runtime

struct Test {
mut:
	name     string
	level    string
	tags     []string
	pending  string
	chunk_at int = 1 << 20  // strict-canonical default
	sections map[string]string
}

// strip_blank_edges reproduces the former flush() normalization: drop
// leading/trailing BLANK lines from a section body. Applied to the loader's
// byte-exact body so the sections fed to the runner are byte-identical to the
// old .txt path.
fn strip_blank_edges(s string) string {
	mut lines := s.split('\n')
	for lines.len > 0 && lines[0].trim_space() == '' { lines.delete(0) }
	for lines.len > 0 && lines[lines.len - 1].trim_space() == '' { lines.delete(lines.len - 1) }
	return lines.join('\n')
}

// parse_suite loads a .cxd conformance suite via the CX-native loader
// (cx.load_fixtures), replacing the bespoke `=== test:` / `--- key` scanner.
// level/tags come from the case attr / [tags] element; pending + chunk_at come
// from the [meta] block. The runner keys into t.sections[name] by presence
// exactly as before.
fn parse_suite(path string) []Test {
	mut tests := []Test{}
	for c in cx.load_fixtures(path) {
		mut t := Test{
			name:     c.name
			level:    c.level
			tags:     c.tags
			pending:  c.meta['pending'] or { '' }
			sections: map[string]string{}
		}
		if 'chunk_at' in c.meta {
			t.chunk_at = (c.meta['chunk_at'] or { '' }).int()
			if t.chunk_at <= 0 { t.chunk_at = 1 << 20 }
		}
		for k, v in c.sections {
			t.sections[k] = strip_blank_edges(v)
		}
		tests << t
	}
	return tests
}

fn run_test(t Test) []string {
	mut failures := []string{}

	// Decode-error fixtures: feed framed bytes through parse_data_bin
	// and assert the expected error message. Used by the chunked-table
	// negative tests in data_bin_compression.txt (cmp-003 / cmp-004).
	// Schema-driven decode-error fixtures supply `schema_cxs` and go
	// through the parse_data_bin_schema_driven path further below.
	if 'in_data_bin_hex' in t.sections && 'expected_decode_error' in t.sections
		&& 'schema_cxs' !in t.sections {
		hex := normalize_hex_text(t.sections['in_data_bin_hex'] or { '' })
		bytes := framed_bytes_from_hex(hex)
		expected_err := (t.sections['expected_decode_error'] or { '' }).trim_space()
		_ := cx.parse_data_bin(bytes) or {
			if expected_err != '' && err.msg().contains(expected_err) {
				return failures
			}
			failures << 'decode error: ${err} (expected: ${expected_err})'
			return failures
		}
		failures << 'decode: expected error containing "${expected_err}", but decode succeeded'
		return failures
	}

	// HH3: synthesized-table fixtures. `synth_table_rows: N`
	// + `synth_table_schema: [t [table[id::int v::string]]]` lets a
	// fixture declare a million-row corpus without authoring the
	// rows inline. The schema is parsed for its column declarations;
	// rows are generated deterministically (int columns get their
	// row index, string columns get "r_<i>", bool gets i % 2 == 0).
	// The resulting Document goes through the same chunked-emit /
	// hash / per-group-inspection assertions as in_cx-driven fixtures.
	if 'synth_table_rows' in t.sections {
		raw_n := (t.sections['synth_table_rows'] or { '0' }).trim_space()
		n_rows := raw_n.int()
		if n_rows <= 0 {
			failures << 'synth_table_rows: must be > 0, got "${raw_n}"'
			return failures
		}
		schema_cx := (t.sections['synth_table_schema'] or { '' }).trim_space()
		if schema_cx == '' {
			failures << 'synth_table_rows present but synth_table_schema missing'
			return failures
		}
		doc := synth_table_document(schema_cx, n_rows) or {
			failures << 'synth_table: ${err}'
			return failures
		}
		// HH4: RSS-bounded streaming-write test. The fixture
		// asserts the fd-streaming Table writer's process RSS stays
		// bounded as N row groups are emitted. The driver builds one
		// plain-body row-group payload once, opens the writer to
		// /dev/null, emits the payload `warmup_groups` times, snaps
		// RSS, emits `stress_groups` more, snaps RSS, asserts
		// (stress / baseline) < max_ratio. Baseline isn't taken at 0
		// emits because the col-spec / writer state hasn't reached
		// steady state — the first row group also exercises the GC's
		// initial-large-allocation pattern. Cap is 1.50× for
		// the CI scale-down; the cmp-005 spec target (100M rows) is
		// opt-in via BENCH_STRESS=1.
		if 'assert_streaming_write_bounded_memory' in t.sections {
			raw_bm := (t.sections['assert_streaming_write_bounded_memory'] or { '' }).trim_space()
			toks := raw_bm.split_any(' \t\r\n').filter(it.trim_space().len > 0)
			if toks.len != 4 {
				failures << 'assert_streaming_write_bounded_memory: needs 4 tokens "rows_per_group warmup_groups stress_groups max_ratio", got ${toks.len}: ${raw_bm}'
				return failures
			}
			rows_per_group := toks[0].int()
			warmup_groups := toks[1].int()
			stress_groups := toks[2].int()
			max_ratio := toks[3].f64()
			// Pull cols from the doc's single :table root.
			if doc.elements.len != 1 || doc.elements[0] !is cx.Element {
				failures << 'assert_streaming_write_bounded_memory: synth doc must have one Element root'
				return failures
			}
			el := doc.elements[0] as cx.Element
			td := el.table_opt() or {
				failures << 'assert_streaming_write_bounded_memory: synth doc root lacks :table'
				return failures
			}
			cols := td.cols
			col_spec := cx.col_spec_to_ast_bin_pub(cols)
			plain_body := cx.build_synthesized_plain_row_group(cols, rows_per_group) or {
				failures << 'assert_streaming_write_bounded_memory: build payload: ${err}'
				return failures
			}
			// /dev/null write-only fd (macOS + Linux both expose it).
			mut devnull := os.open_file('/dev/null', 'wb') or {
				failures << 'assert_streaming_write_bounded_memory: open /dev/null: ${err}'
				return failures
			}
			defer { devnull.close() }
			mut w := cx.new_table_writer_fd(col_spec, devnull.fd) or {
				failures << 'assert_streaming_write_bounded_memory: open writer: ${err}'
				return failures
			}
			for _ in 0 .. warmup_groups {
				w.emit_row_group_payload(plain_body) or {
					failures << 'assert_streaming_write_bounded_memory: emit (warmup): ${err}'
					return failures
				}
			}
			gc_collect()
			baseline := runtime.used_memory() or {
				failures << 'assert_streaming_write_bounded_memory: used_memory baseline: ${err}'
				return failures
			}
			for _ in 0 .. stress_groups {
				w.emit_row_group_payload(plain_body) or {
					failures << 'assert_streaming_write_bounded_memory: emit (stress): ${err}'
					return failures
				}
			}
			gc_collect()
			stress := runtime.used_memory() or {
				failures << 'assert_streaming_write_bounded_memory: used_memory stress: ${err}'
				return failures
			}
			ratio := if baseline > 0 {
				f64(stress) / f64(baseline)
			} else {
				1.0  // baseline unmeasurable; pass through
			}
			if ratio >= max_ratio {
				failures << 'assert_streaming_write_bounded_memory: ratio ${ratio:.3f} >= max ${max_ratio:.3f} (baseline=${baseline} bytes, stress=${stress} bytes after ${stress_groups} extra ${rows_per_group}-row groups)'
			}
			w.writer_close() or {
				failures << 'assert_streaming_write_bounded_memory: close: ${err}'
				return failures
			}
			return failures
		}

		// Per-group inspection assertions on the chunked encoding.
		if 'assert_group_count' in t.sections || 'assert_group_row_counts' in t.sections {
			opts := cx.ChunkedEmitOptions{ chunk_size: t.chunk_at, compress: .never }
			framed := cx.emit_data_bin_chunked(doc, opts) or {
				failures << 'synth_table: chunked emit: ${err}'
				return failures
			}
			counts := cx.chunked_group_row_counts(framed) or {
				failures << 'synth_table: chunked_group_row_counts: ${err}'
				return failures
			}
			if 'assert_group_count' in t.sections {
				want := (t.sections['assert_group_count'] or { '' }).trim_space().int()
				if counts.len != want {
					failures << 'assert_group_count: expected ${want}, got ${counts.len} (per-group: ${counts})'
				}
			}
			if 'assert_group_row_counts' in t.sections {
				raw_rc := t.sections['assert_group_row_counts'] or { '' }
				want_strs := raw_rc.split_any(' \t\r\n').filter(it.trim_space().len > 0)
				mut want := []int{}
				for s in want_strs {
					want << s.int()
				}
				if counts.len != want.len {
					failures << 'assert_group_row_counts: expected ${want.len} groups ${want}, got ${counts.len}: ${counts}'
				} else {
					for i in 0 .. want.len {
						if counts[i] != want[i] {
							failures << 'assert_group_row_counts: group ${i} expected ${want[i]} rows, got ${counts[i]}'
						}
					}
				}
			}
		}
		return failures
	}

	input_src, parse_fmt := if 'in_cx' in t.sections {
		t.sections['in_cx'] or { '' }, 'cx'
	} else if 'in_xml' in t.sections {
		t.sections['in_xml'] or { '' }, 'xml'
	} else if 'in_md' in t.sections {
		t.sections['in_md'] or { '' }, 'md'
	} else if 'in_csv' in t.sections {
		t.sections['in_csv'] or { '' }, 'csv'
	} else if 'in_tsv' in t.sections {
		t.sections['in_tsv'] or { '' }, 'tsv'
	} else if 'in_psv' in t.sections {
		t.sections['in_psv'] or { '' }, 'psv'
	} else if 'in_yaml' in t.sections {
		t.sections['in_yaml'] or { '' }, 'yaml'
	} else {
		return failures
	}

	// out_err fixtures (`[out-err [# CODE #]]`) assert the input is REJECTED:
	// parsing MUST fail with an error whose message contains the expected
	// code/substring. Capture the parse error instead of treating it as an
	// unconditional failure so these negative cases can pass.
	expected_parse_err := (t.sections['out_err'] or { '' }).trim_space()

	// Parse
	mut parse_err := ''
	result := if parse_fmt == 'xml' {
		cx.parse_xml_cx(input_src) or {
			parse_err = err.msg()
			cx.ParseResult{}
		}
	} else if parse_fmt == 'md' {
		cx.parse_md_cx(input_src) or {
			parse_err = err.msg()
			cx.ParseResult{}
		}
	} else if parse_fmt == 'csv' || parse_fmt == 'tsv' || parse_fmt == 'psv' {
		mut opts := cx.default_parse_options()
		opts.delimiter = match parse_fmt {
			'csv' { u8(`,`) }
			'tsv' { u8(`\t`) }
			'psv' { u8(`|`) }
			else { u8(`,`) }
		}
		doc := cx.parse_delimited(input_src, opts) or {
			parse_err = err.msg()
			cx.Document{}
		}
		cx.ParseResult{ is_multi: false, single: doc }
	} else if parse_fmt == 'yaml' {
		cx.parse_yaml_cx(input_src) or {
			parse_err = err.msg()
			cx.ParseResult{}
		}
	} else {
		cx.parse_cx(input_src) or {
			parse_err = err.msg()
			cx.ParseResult{}
		}
	}

	if expected_parse_err != '' {
		// Negative fixture: a matching parse error is the expected outcome.
		if parse_err == '' {
			failures << 'out_err: expected error containing "${expected_parse_err}", but parse succeeded'
		} else if !parse_err.contains(expected_parse_err) {
			failures << 'out_err: expected error containing "${expected_parse_err}", got: ${parse_err}'
		}
		return failures
	}
	if parse_err != '' {
		failures << 'parse error: ${parse_err}'
		return failures
	}

	// ── out_ast ───────────────────────────────────────────────────────────────
	if 'out_ast' in t.sections {
		expected_ast := t.sections['out_ast'] or { '' }
		got_json := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_ast_json_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_ast_json(doc)
		}
		if !json_equal(expected_ast, got_json) {
			failures << 'out_ast mismatch\n  expected: ${expected_ast}\n  got:      ${got_json}'
		}
	}

	// ── out_xml ───────────────────────────────────────────────────────────────
	if 'out_xml' in t.sections {
		expected_xml := t.sections['out_xml'] or { '' }
		got_xml := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_xml_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_xml(doc)
		}
		if expected_xml.trim_space() != got_xml.trim_space() {
			failures << 'out_xml mismatch\n  expected:\n${expected_xml}\n  got:\n${got_xml}'
		}
	}

	// ── out_json ──────────────────────────────────────────────────────────────
	if 'out_json' in t.sections {
		expected_json := t.sections['out_json'] or { '' }
		got_json := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_semantic_json_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_semantic_json(doc)
		}
		if !json_equal(expected_json, got_json) {
			failures << 'out_json mismatch\n  expected: ${expected_json}\n  got:      ${got_json}'
		}
	}

	// ── out_json_lossless (conversions.md §0.2 `cx:type` sidecar, #444) ───────
	if 'out_json_lossless' in t.sections {
		expected_json := t.sections['out_json_lossless'] or { '' }
		got_json := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_semantic_json_docs_lossless(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_semantic_json_lossless(doc)
		}
		if !json_equal(expected_json, got_json) {
			failures << 'out_json_lossless mismatch\n  expected: ${expected_json}\n  got:      ${got_json}'
		}
	}

	// ── out_yaml_lossless (conversions.md §0.2 `!!cx:T` tags, #444) ───────────
	if 'out_yaml_lossless' in t.sections {
		expected_yaml := t.sections['out_yaml_lossless'] or { '' }
		got_yaml := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_yaml_docs_lossless(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_yaml_lossless(doc)
		}
		if expected_yaml.trim_space() != got_yaml.trim_space() {
			failures << 'out_yaml_lossless mismatch\n  expected:\n${expected_yaml}\n  got:\n${got_yaml}'
		}
	}

	// ── out_yaml ──────────────────────────────────────────────────────────────
	if 'out_yaml' in t.sections {
		expected_yaml := t.sections['out_yaml'] or { '' }
		got_yaml := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_yaml_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_yaml(doc)
		}
		if expected_yaml.trim_space() != got_yaml.trim_space() {
			failures << 'out_yaml mismatch\n  expected:\n${expected_yaml}\n  got:\n${got_yaml}'
		}
	}

	// ── out_toml ──────────────────────────────────────────────────────────────
	if 'out_toml' in t.sections {
		expected_toml := t.sections['out_toml'] or { '' }
		got_toml := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_toml_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_toml(doc)
		}
		if expected_toml.trim_space() != got_toml.trim_space() {
			failures << 'out_toml mismatch\n  expected:\n${expected_toml}\n  got:\n${got_toml}'
		}
	}

	// ── out_cx ────────────────────────────────────────────────────────────────
	if 'out_cx' in t.sections {
		expected_cx := t.sections['out_cx'] or { '' }
		got_cx := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_cx_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_cx(doc)
		}
		if expected_cx.trim_space() != got_cx.trim_space() {
			failures << 'out_cx mismatch\n  expected:\n${expected_cx}\n  got:\n${got_cx}'
		}
	}

	// ── out_canonical ─────────────────────────────────────────────────────────
	// Strict-canonical text via cx_text_canonical (re-parse internally;
	// applies presentation strip + namespace prefix/declaration
	// canonicalization).
	if 'out_canonical' in t.sections {
		expected_canon := t.sections['out_canonical'] or { '' }
		got_canon := cx.cx_text_canonical(input_src) or {
			failures << 'out_canonical error: ${err}'
			''
		}
		if got_canon.len > 0 && expected_canon.trim_space() != got_canon.trim_space() {
			failures << 'out_canonical mismatch\n  expected:\n${expected_canon}\n  got:\n${got_canon}'
		}
	}

	// ── assert_ast_bin_roundtrip (#464) ───────────────────────────────────
	// Verifies emit_ast_bin → bin_to_doc is the identity on the parsed
	// input (compared on emit_cx text). Added for the Element table
	// record (ast-bin.md §4.8) — the pooled [table[…]] payload must
	// survive the binary AST wire — but the lane is general: any fixture
	// can pin the ast_bin round-trip with `[assert-ast-bin-roundtrip 1]`.
	if 'assert_ast_bin_roundtrip' in t.sections {
		flag := (t.sections['assert_ast_bin_roundtrip'] or { '0' }).trim_space()
		if flag == '1' {
			docs := if result.is_multi {
				result.multi or { [] }
			} else {
				[result.single or { cx.Document{} }]
			}
			for i, doc in docs {
				bytes := cx.emit_ast_bin(doc)
				doc2 := cx.bin_to_doc(bytes) or {
					failures << 'assert_ast_bin_roundtrip: doc ${i} decode error: ${err}'
					continue
				}
				want := cx.emit_cx(doc)
				got := cx.emit_cx(doc2)
				if want != got {
					failures << 'assert_ast_bin_roundtrip: doc ${i} not identity\n  before:\n${want}\n  after:\n${got}'
				}
			}
		}
	}

	// ── out_csv / out_tsv / out_psv (delimited) ───────────────────
	for fmt_key in ['out_csv', 'out_tsv', 'out_psv'] {
		if fmt_key !in t.sections { continue }
		expected := t.sections[fmt_key] or { '' }
		delim := match fmt_key {
			'out_csv' { u8(`,`) }
			'out_tsv' { u8(`\t`) }
			'out_psv' { u8(`|`) }
			else      { u8(`,`) }
		}
		doc := if result.is_multi {
			docs := result.multi or { [] }
			if docs.len > 0 { docs[0] } else { cx.Document{} }
		} else {
			result.single or { cx.Document{} }
		}
		mut opts := cx.default_emit_options()
		opts.delimiter = delim
		got := cx.emit_delimited(doc, opts) or {
			failures << '${fmt_key} emit error: ${err}'
			continue
		}
		// Expected text in the fixture is recorded with `\n` line
		// terminators (the fixture file is plain text); the emitter
		// produces `\r\n`. Normalize both sides on `\r\n` → `\n`
		// before comparing.
		exp_n := expected.replace('\r\n', '\n').trim_space()
		got_n := got.replace('\r\n', '\n').trim_space()
		if exp_n != got_n {
			failures << '${fmt_key} mismatch\n  expected:\n${exp_n}\n  got:\n${got_n}'
		}
	}

	// ── assert_chunked_distinct_from_plain (chunked-table canonicality) ───
	// Verifies that chunked (0x63) and non-chunked (0x60) encodings of the
	// same logical data produce DIFFERENT byte sequences, per
	// spec/core/data-bin.md §3.11.3. The chunk boundaries are part of the
	// canonical form. Used by ch-004 to property-check that chunked is
	// not a free abstraction over plain.
	if 'assert_chunked_distinct_from_plain' in t.sections {
		flag := (t.sections['assert_chunked_distinct_from_plain'] or { '0' }).trim_space()
		if flag == '1' {
			doc := if result.is_multi {
				docs := result.multi or { [] }
				if docs.len > 0 { docs[0] } else { cx.Document{} }
			} else {
				result.single or { cx.Document{} }
			}
			plain := cx.emit_data_bin(doc)
			opts := cx.ChunkedEmitOptions{ chunk_size: t.chunk_at, compress: .never }
			chunked := cx.emit_data_bin_chunked(doc, opts) or {
				failures << 'assert_chunked_distinct: chunked emit error: ${err}'
				return failures
			}
			if plain.len == chunked.len {
				mut all_eq := true
				for i in 0 .. plain.len {
					if plain[i] != chunked[i] { all_eq = false; break }
				}
				if all_eq {
					failures << 'assert_chunked_distinct_from_plain: chunked bytes match plain bytes (len=${plain.len})'
				}
			}
		}
	}

	// ── assert_hash_compression_invariance + assert_compressed_size_lt
	// (HH1) ────────────────────────────────────────────────────────────────
	// Encode the input in N modes and verify cx_data_bin_hash is invariant
	// across them. Spec: data-bin.md §3.12.2. Both section handlers live
	// together so the size-comparison branch can reuse the bytes computed
	// by the hash-invariance branch.
	//
	// assert_hash_compression_invariance value: whitespace-separated list of
	// encoding tokens:
	//   plain   → ChunkedEmitOptions{ compress: .never }
	//   auto    → ChunkedEmitOptions{ compress: .auto, compress_level: 3 }
	//   zstd1   → ChunkedEmitOptions{ compress: .always, compress_level: 1 }
	//   zstd3   → ChunkedEmitOptions{ compress: .always, compress_level: 3 }
	//   zstd19  → ChunkedEmitOptions{ compress: .always, compress_level: 19 }
	//
	// assert_compressed_size_lt value: two encoding tokens "smaller bigger"
	// — asserts sizeof(smaller) < sizeof(bigger). Both tokens must appear
	// in the assert_hash_compression_invariance encoding list above.
	if 'assert_hash_compression_invariance' in t.sections {
		raw := t.sections['assert_hash_compression_invariance'] or { '' }
		encs := raw.split_any(' \t\r\n').filter(it.trim_space().len > 0)
		if encs.len < 2 {
			failures << 'assert_hash_compression_invariance: needs >=2 encoding tokens, got ${encs.len}'
			return failures
		}
		doc := if result.is_multi {
			docs := result.multi or { [] }
			if docs.len > 0 { docs[0] } else { cx.Document{} }
		} else {
			result.single or { cx.Document{} }
		}
		mut size_by_enc := map[string]int{}
		mut hash_by_enc := map[string]string{}
		for enc in encs {
			opts := encoding_token_to_opts(enc, t.chunk_at) or {
				failures << 'assert_hash_compression_invariance: ${err}'
				return failures
			}
			bytes := cx.emit_data_bin_chunked(doc, opts) or {
				failures << 'assert_hash_compression_invariance: emit(${enc}) error: ${err}'
				return failures
			}
			h := cx.cx_data_bin_hash(bytes) or {
				failures << 'assert_hash_compression_invariance: hash(${enc}) error: ${err}'
				return failures
			}
			hash_by_enc[enc] = h
			size_by_enc[enc] = bytes.len
		}
		// All hashes must match the first.
		base_enc := encs[0]
		base_hash := hash_by_enc[base_enc] or { '' }
		for i in 1 .. encs.len {
			e := encs[i]
			h := hash_by_enc[e] or { '' }
			if h != base_hash {
				failures << 'assert_hash_compression_invariance: hash(${base_enc})=${base_hash} != hash(${e})=${h}'
			}
		}
		// Companion size-ordering check, if requested.
		if 'assert_compressed_size_lt' in t.sections {
			raw_sz := t.sections['assert_compressed_size_lt'] or { '' }
			toks := raw_sz.split_any(' \t\r\n').filter(it.trim_space().len > 0)
			if toks.len != 2 {
				failures << 'assert_compressed_size_lt: needs exactly 2 encoding tokens (smaller bigger), got ${toks.len}'
				return failures
			}
			smaller := toks[0]
			bigger := toks[1]
			sz_small := size_by_enc[smaller] or {
				failures << 'assert_compressed_size_lt: encoding "${smaller}" not in assert_hash_compression_invariance list'
				return failures
			}
			sz_big := size_by_enc[bigger] or {
				failures << 'assert_compressed_size_lt: encoding "${bigger}" not in assert_hash_compression_invariance list'
				return failures
			}
			if sz_small >= sz_big {
				failures << 'assert_compressed_size_lt: ${smaller}=${sz_small} bytes is NOT < ${bigger}=${sz_big} bytes'
			}
		}
	}

	// ── out_data_bin_hex (chunked-table;) ──────────────────────
	// Compares the bytes produced by emit_data_bin_chunked against the
	// fixture's expected hex (whitespace + ` # comment` non-significant).
	// The framing prefix `[u32 LE size]` is stripped before comparison
	// (the fixture records the CXCol header onward).
	if 'out_data_bin_hex' in t.sections {
		expected_hex := normalize_hex_text(t.sections['out_data_bin_hex'] or { '' })
		doc := if result.is_multi {
			docs := result.multi or { [] }
			if docs.len > 0 { docs[0] } else { cx.Document{} }
		} else {
			result.single or { cx.Document{} }
		}
		opts := cx.ChunkedEmitOptions{ chunk_size: t.chunk_at, compress: .never }
		got := cx.emit_data_bin_chunked(doc, opts) or {
			failures << 'out_data_bin_hex error: ${err}'
			return failures
		}
		got_hex := bytes_to_hex(got[4..]) // strip framing prefix
		if expected_hex != got_hex {
			failures << 'out_data_bin_hex mismatch\n  expected: ${expected_hex}\n  got:      ${got_hex}'
		}
	}

	// ── out_md ────────────────────────────────────────────────────────────────
	if 'out_md' in t.sections {
		expected_md := t.sections['out_md'] or { '' }
		got_md := if result.is_multi {
			docs := result.multi or { [] }
			cx.emit_md_docs(docs)
		} else {
			doc := result.single or { cx.Document{} }
			cx.emit_md(doc)
		}
		if expected_md.trim_space() != got_md.trim_space() {
			failures << 'out_md mismatch\n  expected:\n${expected_md}\n  got:\n${got_md}'
		}
	}

	// ── Schema-driven encoding ───────────────────
	// Three section types compose to verify schema-driven behavior:
	//
	//   schema_cxs              — schema source text (parsed as `.cxs`)
	//   sd_assert_round_trip    — opt-in flag: set to "1" to assert that
	//                             (encode → decode) preserves the input
	//                             at the data layer (ScalarValue level)
	//   sd_assert_flag_bit_1    — opt-in flag: set to "1" to assert that
	//                             encoded bytes have CXCol header flag bit
	//                             1 set
	//   sd_ref_form             — selects the schema-ref form: "hash" /
	//                             "inline" / "hash_with_name". Default
	//                             "hash".
	//   sd_assert_ref_tag       — expected first byte of the schema ref
	//                             ("0x10" / "0x11" / "0x12")
	//   sd_expected_emit_error  — expected substring of the encode error
	//                             (skips round-trip if the encoder must
	//                             reject — e.g., closed-mode rejection)
	//
	// schema_cxs_a / schema_cxs_b + sd_assert_hash_equal: hash-stability
	// assertion across two semantically-equivalent schemas.
	//
	// in_data_bin_hex + sd_expected_decode_error: feed concrete framed
	// bytes through the decoder and assert the error message.
	if 'sd_assert_hash_equal' in t.sections {
		schema_a := t.sections['schema_cxs_a'] or { '' }
		schema_b := t.sections['schema_cxs_b'] or { '' }
		ha := cx.schema_content_hash(schema_a) or {
			failures << 'sd_assert_hash_equal: hash A failed: ${err}'
			return failures
		}
		hb := cx.schema_content_hash(schema_b) or {
			failures << 'sd_assert_hash_equal: hash B failed: ${err}'
			return failures
		}
		if !slices_equal(ha, hb) {
			failures << 'sd_assert_hash_equal: hash A != hash B'
		}
	}
	has_sd := 'sd_assert_round_trip' in t.sections
		|| 'sd_assert_flag_bit_1' in t.sections
		|| 'sd_assert_ref_tag' in t.sections
		|| 'sd_ref_form' in t.sections
		|| 'sd_name_hint' in t.sections
		|| 'sd_expected_emit_error' in t.sections
		|| 'sd_expected_decoded_cx' in t.sections
		|| 'sd_decode_with_alt_schema' in t.sections
	if has_sd && 'schema_cxs' in t.sections {
		schema_text := t.sections['schema_cxs'] or { '' }
		ref_form := match (t.sections['sd_ref_form'] or { 'hash' }).trim_space() {
			'inline'         { cx.SchemaRefForm.inline_schema }
			'hash_with_name' { cx.SchemaRefForm.hash_with_name }
			else             { cx.SchemaRefForm.hash_only }
		}
		name_hint := (t.sections['sd_name_hint'] or { '' }).trim_space()
		doc := if result.is_multi {
			docs := result.multi or { [] }
			if docs.len > 0 { docs[0] } else { cx.Document{} }
		} else {
			result.single or { cx.Document{} }
		}
		bytes_or_err := cx.emit_data_bin_schema_driven(doc, schema_text: schema_text, ref_form: ref_form, name_hint: name_hint) or {
			expected_err := (t.sections['sd_expected_emit_error'] or { '' }).trim_space()
			if expected_err != '' && err.msg().contains(expected_err) {
				return failures  // expected emit-time rejection (e.g., closed mode)
			}
			failures << 'sd_emit error: ${err} (expected: ${expected_err})'
			return failures
		}
		// header is at offset 4 (after 4-byte framing prefix). The CXCol
		// header is magic(5) + version(1) + flags(1), so the flags byte
		// is payload offset 6, i.e., absolute offset 10. (Was offset 9
		// under the earlier 4-byte "CXDB" magic; commit 5cdc03cc grew
		// the magic to 5 bytes ("CXCol") and shifted flags by one.)
		flags_off := 4 + 5 + 1  // framing(4) + 5-byte magic + version(1) = 10
		if 'sd_assert_flag_bit_1' in t.sections {
			expected := (t.sections['sd_assert_flag_bit_1'] or { '0' }).trim_space()
			got_bit := bytes_or_err.len > flags_off && (bytes_or_err[flags_off] & 0x02) != 0
			want := expected == '1'
			if got_bit != want {
				failures << 'sd_assert_flag_bit_1: expected=${want} got=${got_bit} (flags byte=0x${bytes_or_err[flags_off]:02x})'
			}
		}
		if 'sd_assert_ref_tag' in t.sections {
			expected_tag := (t.sections['sd_assert_ref_tag'] or { '' }).trim_space()
			// schema ref starts at offset 16 (after 4-byte framing + 12-byte header)
			got_tag := if bytes_or_err.len > 16 { bytes_or_err[16] } else { u8(0) }
			want_tag := if expected_tag.starts_with('0x') {
				u8(parse_hex_byte(expected_tag[2..]))
			} else {
				u8(parse_hex_byte(expected_tag))
			}
			if got_tag != want_tag {
				failures << 'sd_assert_ref_tag: expected=0x${want_tag:02x} got=0x${got_tag:02x}'
			}
		}
		// HH5: content-store schema-mismatch test. Encode with
		// schema_cxs, then decode with a different schema text supplied
		// as the consumer's content-store response. The decoder must
		// reject with D002 (content-hash mismatch) because the embedded
		// reference hashes the original schema, not the alt.
		if 'sd_decode_with_alt_schema' in t.sections {
			alt := (t.sections['sd_decode_with_alt_schema'] or { '' }).trim_space()
			expected_err := (t.sections['sd_expected_decode_error'] or { '' }).trim_space()
			_ := cx.parse_data_bin_schema_driven(bytes_or_err, alt) or {
				if expected_err != '' && err.msg().contains(expected_err) {
					return failures
				}
				failures << 'sd_decode_with_alt_schema: ${err} (expected: ${expected_err})'
				return failures
			}
			if expected_err != '' {
				failures << 'sd_decode_with_alt_schema: expected error containing "${expected_err}", decode succeeded'
				return failures
			}
		}
		if (t.sections['sd_assert_round_trip'] or { '0' }).trim_space() == '1' {
			rec := cx.parse_data_bin_schema_driven(bytes_or_err, schema_text) or {
				failures << 'sd_round_trip decode error: ${err}'
				return failures
			}
			out := cx.emit_cx(rec)
			// Round-trip is data-equivalent, not byte-identical (type
			// annotations may be dropped on the way back through
			// DataVal). Compare against `sd_expected_decoded_cx` if the
			// fixture supplies it; otherwise just confirm decode
			// succeeded — the semantic compare is implicit in the
			// DataPairs round-trip.
			if 'sd_expected_decoded_cx' in t.sections {
				expected := t.sections['sd_expected_decoded_cx'] or { '' }
				if out.trim_space() != expected.trim_space() {
					failures << 'sd_round_trip mismatch\n  expected: ${expected}\n  got:      ${out}'
				}
			}
		}
	}
	if 'in_data_bin_hex' in t.sections {
		hex := normalize_hex_text(t.sections['in_data_bin_hex'] or { '' })
		bytes := framed_bytes_from_hex(hex)
		schema_hint := t.sections['schema_cxs'] or { '' }
		expected_err := (t.sections['sd_expected_decode_error'] or { '' }).trim_space()
		_ := cx.parse_data_bin_schema_driven(bytes, schema_hint) or {
			if expected_err != '' && err.msg().contains(expected_err) {
				return failures
			}
			failures << 'sd_decode error: ${err} (expected: ${expected_err})'
			return failures
		}
		if expected_err != '' {
			failures << 'sd_decode: expected error containing "${expected_err}", but decode succeeded'
		}
	}

	// ── Schema validator (Phase 7.74c-schema-validator-v-core) ─────────────
	// Section types driving the validator-fixture path:
	//
	//   schema_cxs                 — schema source (.cxs) (shared with sd_*)
	//   sv_assert_valid            — '1' to assert zero error diagnostics
	//                                (warnings / info do NOT invalidate)
	//   sv_expected_codes          — comma-separated error-severity codes
	//                                in document order, e.g. 'S002,S003'
	//   sv_expected_warn_codes     — comma-separated warn-severity codes
	//                                in document order (Phase 7.74d:
	//                                strict-mode S001/S012 etc.)
	//   sv_expected_info_codes     — comma-separated info-severity codes
	//                                in document order (reserved)
	//
	// The validator-only branch fires when any sv_* section is present
	// alongside schema_cxs. Other schema_cxs-using sections (sd_*) are
	// unaffected.
	has_sv := 'sv_assert_valid' in t.sections
		|| 'sv_expected_codes' in t.sections
		|| 'sv_expected_warn_codes' in t.sections
		|| 'sv_expected_info_codes' in t.sections
	if has_sv && 'schema_cxs' in t.sections {
		schema_text := t.sections['schema_cxs'] or { '' }
		doc := if result.is_multi {
			docs := result.multi or { [] }
			if docs.len > 0 { docs[0] } else { cx.Document{} }
		} else {
			result.single or { cx.Document{} }
		}
		report := cx.validate(doc, schema_text) or {
			failures << 'sv_validate error: ${err}'
			return failures
		}
		mut got_codes := []string{cap: report.diagnostics.len}
		mut got_warn_codes := []string{cap: report.diagnostics.len}
		mut got_info_codes := []string{cap: report.diagnostics.len}
		for d in report.diagnostics {
			match d.severity {
				.error_severity { got_codes << d.code }
				.warn           { got_warn_codes << d.code }
				.info           { got_info_codes << d.code }
			}
		}
		if 'sv_assert_valid' in t.sections {
			expected := (t.sections['sv_assert_valid'] or { '0' }).trim_space()
			if expected == '1' && got_codes.len > 0 {
				failures << 'sv_assert_valid: expected zero errors, got [${got_codes.join(",")}]'
			}
		}
		if 'sv_expected_codes' in t.sections {
			expected_str := (t.sections['sv_expected_codes'] or { '' }).trim_space()
			mut expected := []string{}
			for c in expected_str.split(',') {
				e := c.trim_space()
				if e != '' { expected << e }
			}
			if expected.join(',') != got_codes.join(',') {
				failures << 'sv_expected_codes mismatch\n  expected: [${expected.join(",")}]\n  got:      [${got_codes.join(",")}]'
			}
		}
		if 'sv_expected_warn_codes' in t.sections {
			expected_str := (t.sections['sv_expected_warn_codes'] or { '' }).trim_space()
			mut expected := []string{}
			for c in expected_str.split(',') {
				e := c.trim_space()
				if e != '' { expected << e }
			}
			if expected.join(',') != got_warn_codes.join(',') {
				failures << 'sv_expected_warn_codes mismatch\n  expected: [${expected.join(",")}]\n  got:      [${got_warn_codes.join(",")}]'
			}
		}
		if 'sv_expected_info_codes' in t.sections {
			expected_str := (t.sections['sv_expected_info_codes'] or { '' }).trim_space()
			mut expected := []string{}
			for c in expected_str.split(',') {
				e := c.trim_space()
				if e != '' { expected << e }
			}
			if expected.join(',') != got_info_codes.join(',') {
				failures << 'sv_expected_info_codes mismatch\n  expected: [${expected.join(",")}]\n  got:      [${got_info_codes.join(",")}]'
			}
		}
	}

	return failures
}

fn slices_equal(a []u8, b []u8) bool {
	if a.len != b.len { return false }
	for i in 0 .. a.len {
		if a[i] != b[i] { return false }
	}
	return true
}

// synth_table_document builds an N-row Document from a CX :table
// schema header. The schema_cx text declares one Element with a
// `[table[col::type, ...]]` body; rows are generated deterministically:
//   - int / i64 / i32 columns           → row index (i64)
//   - float / f64 columns               → row index as f64
//   - bool columns                      → i % 2 == 0
//   - string / unspecified columns      → "r_<i>"
//   - datetime columns                  → unix epoch + i seconds (i64 ns)
// HH3. Composes with assert_group_count + assert_group_row_counts
// for million-row corpus tests without inline row authoring.
fn synth_table_document(schema_cx string, n_rows int) !cx.Document {
	parsed := cx.parse(schema_cx)!
	if parsed.elements.len != 1 {
		return error('schema must declare exactly one Element, got ${parsed.elements.len}')
	}
	root := parsed.elements[0]
	if root !is cx.Element {
		return error('schema root must be Element')
	}
	el := root as cx.Element
	td := el.table_opt() or { return error('schema Element lacks :table body') }
	cols := td.cols
	if cols.len == 0 {
		return error('schema :table must declare at least one column')
	}
	mut rows := [][]cx.TableCellValue{cap: n_rows}
	for i in 0 .. n_rows {
		mut row := []cx.TableCellValue{cap: cols.len}
		for col in cols {
			t := col.type_name
			cell := if t == 'int' || t == 'i64' || t == 'i32' {
				cx.TableCellValue(i64(i))
			} else if t == 'float' || t == 'f64' || t == 'f32' {
				cx.TableCellValue(f64(i))
			} else if t == 'bool' {
				cx.TableCellValue(i % 2 == 0)
			} else {
				cx.TableCellValue('r_${i}')
			}
			row << cell
		}
		rows << row
	}
	synth_el := cx.Element{
		name:  el.name
		attrs: el.attrs
		table: &cx.TableData{ cols: cols, rows: rows, from_chunked: false }
	}
	return cx.Document{ elements: [cx.Node(synth_el)] }
}

// encoding_token_to_opts maps an HH1 encoding token to a
// ChunkedEmitOptions value. Unknown tokens return an error so typos
// in fixtures surface immediately. chunk_at carries the fixture's
// `chunk_at:` metadata; the canonical default (2^20 rows) applies
// when chunk_at is 0.
fn encoding_token_to_opts(token string, chunk_at int) !cx.ChunkedEmitOptions {
	chunk := if chunk_at > 0 { chunk_at } else { 1 << 20 }
	return match token {
		'plain'  { cx.ChunkedEmitOptions{ chunk_size: chunk, compress: .never } }
		'auto'   { cx.ChunkedEmitOptions{ chunk_size: chunk, compress: .auto,   compress_level: 3 } }
		'zstd1'  { cx.ChunkedEmitOptions{ chunk_size: chunk, compress: .always, compress_level: 1 } }
		'zstd3'  { cx.ChunkedEmitOptions{ chunk_size: chunk, compress: .always, compress_level: 3 } }
		'zstd19' { cx.ChunkedEmitOptions{ chunk_size: chunk, compress: .always, compress_level: 19 } }
		else     { error('unknown encoding token "${token}" — expected plain / auto / zstd1 / zstd3 / zstd19') }
	}
}

fn parse_hex_byte(s string) int {
	mut v := 0
	for c in s.bytes() {
		mut d := 0
		if c >= `0` && c <= `9` { d = int(c - `0`) }
		else if c >= `a` && c <= `f` { d = int(c - `a`) + 10 }
		else if c >= `A` && c <= `F` { d = int(c - `A`) + 10 }
		else { continue }
		v = (v << 4) | d
	}
	return v
}

// framed_bytes_from_hex turns a hex string (header bytes onward, no
// framing prefix) into a framed [u32 LE size][payload] buffer ready to
// hand to the decoder. The fixture hex starts at the CXCol magic.
fn framed_bytes_from_hex(hex string) []u8 {
	mut payload := []u8{cap: hex.len / 2}
	mut i := 0
	for i + 1 < hex.len {
		hi := hex_digit(hex[i])
		lo := hex_digit(hex[i + 1])
		payload << u8((hi << 4) | lo)
		i += 2
	}
	mut framed := []u8{cap: 4 + payload.len}
	sz := u32(payload.len)
	framed << u8(sz & 0xFF)
	framed << u8((sz >> 8) & 0xFF)
	framed << u8((sz >> 16) & 0xFF)
	framed << u8((sz >> 24) & 0xFF)
	framed << payload
	return framed
}

fn hex_digit(b u8) int {
	if b >= `0` && b <= `9` { return int(b - `0`) }
	if b >= `a` && b <= `f` { return int(b - `a`) + 10 }
	if b >= `A` && b <= `F` { return int(b - `A`) + 10 }
	return 0
}

// ── Simple JSON value equality (parse and compare) ────────────────────────────

fn json_equal(a string, b string) bool {
	va := parse_json_val(a.trim_space())
	vb := parse_json_val(b.trim_space())
	return json_vals_equal(va, vb)
}

type JVal = JNull | bool | f64 | string | []JVal | map[string]JVal

struct JNull {}

fn json_vals_equal(a JVal, b JVal) bool {
	return match a {
		JNull    { b is JNull }
		bool     { b is bool && (a as bool) == (b as bool) }
		f64      { b is f64 && (a as f64) == (b as f64) }
		string   { b is string && (a as string) == (b as string) }
		[]JVal   {
			if b !is []JVal { return false }
			ba := b as []JVal
			aa := a as []JVal
			if aa.len != ba.len { return false }
			for i in 0..aa.len {
				if !json_vals_equal(aa[i], ba[i]) { return false }
			}
			true
		}
		map[string]JVal {
			if b !is map[string]JVal { return false }
			am := a as map[string]JVal
			bm := b as map[string]JVal
			if am.len != bm.len { return false }
			for k, v in am {
				bv := bm[k] or { return false }
				if !json_vals_equal(v, bv) { return false }
			}
			true
		}
	}
}

struct JsonReader {
mut:
	src []u8
	pos int
}

fn parse_json_val(src string) JVal {
	mut r := JsonReader{ src: src.bytes(), pos: 0 }
	return r.read_val()
}

fn json_is_ws(b u8) bool {
	return b == ` ` || b == `\t` || b == `\n` || b == `\r`
}

fn (mut r JsonReader) skip_ws() {
	for r.pos < r.src.len && json_is_ws(r.src[r.pos]) { r.pos++ }
}

fn (mut r JsonReader) peek() u8 {
	if r.pos < r.src.len { return r.src[r.pos] }
	return 0
}

fn (mut r JsonReader) read_val() JVal {
	r.skip_ws()
	if r.pos >= r.src.len { return JVal(JNull{}) }
	b := r.peek()
	return match b {
		`"` { r.read_json_str() }
		`{` { r.read_json_obj() }
		`[` { r.read_json_arr() }
		`t` { r.pos += 4; JVal(true) }
		`f` { r.pos += 5; JVal(false) }
		`n` { r.pos += 4; JVal(JNull{}) }
		else { r.read_json_num() }
	}
}

fn (mut r JsonReader) read_json_str() JVal {
	r.pos++ // '"'
	mut s := []u8{}
	for r.pos < r.src.len {
		b := r.src[r.pos]
		if b == `"` { r.pos++; break }
		if b == `\\` {
			r.pos++
			if r.pos < r.src.len {
				esc := r.src[r.pos]
				r.pos++
				match esc {
					`n` { s << `\n` }
					`r` { s << `\r` }
					`t` { s << `\t` }
					`"` { s << `"` }
					`\\` { s << `\\` }
					else { s << `\\`; s << esc }
				}
			}
		} else {
			s << b
			r.pos++
		}
	}
	return JVal(s.bytestr())
}

fn (mut r JsonReader) read_json_obj() JVal {
	r.pos++ // '{'
	mut obj := map[string]JVal{}
	r.skip_ws()
	if r.pos < r.src.len && r.peek() == `}` { r.pos++; return JVal(obj) }
	for r.pos < r.src.len {
		r.skip_ws()
		key_val := r.read_val()
		key := if key_val is string { key_val as string } else { '' }
		r.skip_ws()
		if r.peek() == `:` { r.pos++ }
		val := r.read_val()
		obj[key] = val
		r.skip_ws()
		if r.peek() == `,` { r.pos++; continue }
		if r.peek() == `}` { r.pos++; break }
		break
	}
	return JVal(obj)
}

fn (mut r JsonReader) read_json_arr() JVal {
	r.pos++ // '['
	mut arr := []JVal{}
	r.skip_ws()
	if r.pos < r.src.len && r.peek() == `]` { r.pos++; return JVal(arr) }
	for r.pos < r.src.len {
		val := r.read_val()
		arr << val
		r.skip_ws()
		if r.peek() == `,` { r.pos++; continue }
		if r.peek() == `]` { r.pos++; break }
		break
	}
	return JVal(arr)
}

fn (mut r JsonReader) read_json_num() JVal {
	mut s := []u8{}
	for r.pos < r.src.len {
		b := r.src[r.pos]
		if b == `,` || b == `}` || b == `]` || json_is_ws(b) { break }
		s << b
		r.pos++
	}
	num_str := s.bytestr()
	if num_str == 'null' { return JVal(JNull{}) }
	if num_str == 'true' { return JVal(true) }
	if num_str == 'false' { return JVal(false) }
	// try as float
	fv := num_str.f64()
	if fv != 0.0 || num_str == '0' || num_str == '0.0' {
		return JVal(fv)
	}
	return JVal(f64(0))
}

// ── Hex helpers (out_data_bin_hex section type) ───────────────────────────────

// normalize_hex_text strips comments (` # ...`) and whitespace from a
// fixture's hex section, returning a lowercase contiguous hex string.
fn normalize_hex_text(s string) string {
	mut out := []u8{cap: s.len}
	for line in s.split_into_lines() {
		mut l := line
		// strip line-tail comments after a `#`
		if hash := l.index('#') {
			l = l[..hash]
		}
		for b in l.bytes() {
			if (b >= `0` && b <= `9`) || (b >= `a` && b <= `f`) {
				out << b
			} else if b >= `A` && b <= `F` {
				out << b + 32 // to lowercase
			}
		}
	}
	return out.bytestr()
}

fn bytes_to_hex(bytes []u8) string {
	hex_chars := '0123456789abcdef'.bytes()
	mut out := []u8{cap: bytes.len * 2}
	for b in bytes {
		out << hex_chars[(b >> 4) & 0x0F]
		out << hex_chars[b & 0x0F]
	}
	return out.bytestr()
}

// ── Test runner ───────────────────────────────────────────────────────────────

fn run_suite(path string) bool {
	tests := parse_suite(path)
	mut pass := 0
	mut fail := 0
	mut skip := 0

	for t in tests {
		if t.pending != '' {
			skip++
			println('SKIP ${t.name} (pending: ${t.pending})')
			continue
		}
		failures := run_test(t)
		if failures.len == 0 {
			pass++
			println('PASS ${t.name}')
		} else {
			fail++
			println('FAIL ${t.name}')
			for f in failures { println('     ${f}') }
		}
	}
	println('${path}: ${pass} passed, ${fail} failed, ${skip} skipped')
	return fail == 0
}

fn main() {
	args := os.args[1..]

	// Default: run all suites
	suites := if args.len > 0 {
		args
	} else {
		[
			'../conformance/core.cxd',
			'../conformance/extended.cxd',
			'../conformance/xml.cxd',
			'../conformance/md.cxd',
			'../conformance/namespaces.cxd',
		]
	}

	mut all_pass := true
	for suite in suites {
		if !run_suite(suite) { all_pass = false }
	}

	if !all_pass { exit(1) }
}
