module cxstore

import time
import os

// PL8 fanout benchmark (object_model.md §11). Measures the B tradeoff:
// edit-cost (new objects per single-element edit) vs object-count vs tree depth
// vs build/hash time, on a large sequence. Results are written to
// $TMPDIR/cxstore_pl8.tsv (V's test harness captures stdout/stderr). It also
// asserts edit-cost stays O(log_B n) (≤ depth+1) as a real test.

fn bench_build(n int, b int, edit_at int) (ObjectSink, i64) {
	mut sink := ObjectSink{}
	mut elems := [][]u8{cap: n}
	for i in 0 .. n {
		if i == edit_at {
			elems << sink.put('elem-${i}-EDIT'.bytes())
		} else {
			elems << sink.put('elem-${i}'.bytes())
		}
	}
	sw := time.new_stopwatch()
	build_seqtree(mut sink, elems, b)
	ms := sw.elapsed().milliseconds()
	return sink, ms
}

fn test_pl8_fanout_benchmark() {
	n := 100000
	mut lines := []string{}
	lines << '=== PL8 fanout benchmark — n=${n} elements ==='
	lines << 'B\tdepth\ttotal_objs\tseq_nodes\tedit_new\tbuild_ms'
	for b in [8, 16, 32, 64, 128] {
		mut s1, ms := bench_build(n, b, -1)
		mut s2, _ := bench_build(n, b, n / 2)
		mut edit_new := 0
		for k, _ in s2.objects {
			if k !in s1.objects {
				edit_new++
			}
		}
		depth := levels_for(n, b)
		seq_nodes := s1.objects.len - n
		lines << '${b}\t${depth}\t${s1.objects.len}\t${seq_nodes}\t${edit_new}\t${ms}'
		assert edit_new <= depth + 1
	}
	out := os.join_path(os.temp_dir(), 'cxstore_pl8.tsv')
	os.write_file(out, lines.join('\n') + '\n') or {}
}
