module cxstore

import os

// Build a sequence of n element objects into a fresh sink, with the element at
// `edit_at` given a distinct payload (or -1 for none); return (sink, root).
fn build_seq(n int, fanout int, edit_at int, edited_tag string) (ObjectSink, []u8) {
	mut sink := ObjectSink{}
	mut elems := [][]u8{}
	for i in 0 .. n {
		if i == edit_at {
			elems << sink.put('elem-${i}-${edited_tag}'.bytes())
		} else {
			elems << sink.put('elem-${i}'.bytes())
		}
	}
	root := build_seqtree(mut sink, elems, fanout)
	return sink, root
}

fn count_only_in(a &ObjectSink, b &ObjectSink) int {
	mut n := 0
	for k, _ in a.objects {
		if k !in b.objects {
			n++
		}
	}
	return n
}

// The headline #80 property: a single-element edit on a wide sequence rehashes
// only O(log_B n) objects, and the two versions share everything else.
fn test_single_edit_is_logarithmic_and_dedups() {
	fanout := 32
	n := 10000
	edit_idx := 5000

	mut sink1, root1 := build_seq(n, fanout, -1, '')
	mut sink2, root2 := build_seq(n, fanout, edit_idx, 'EDITED')

	// correctness: both trees encode their sequences in order
	got1 := collect_elements(sink1, root1)
	got2 := collect_elements(sink2, root2)
	assert got1.len == n
	assert got2.len == n
	assert root1 != root2
	assert got2[edit_idx] != got1[edit_idx] // the edit shows up
	assert got2[edit_idx - 1] == got1[edit_idx - 1] // neighbor unchanged
	assert got2[0] == got1[0]
	assert got2[n - 1] == got1[n - 1]

	depth := levels_for(n, fanout)

	// new objects in v2 = 1 changed element + one seq-node per level on the path
	new_objs := count_only_in(sink2, sink1)
	assert new_objs >= 2, 'expected ≥2 new objects, got ${new_objs}'
	assert new_objs <= depth + 1, 'edit not logarithmic: ${new_objs} new objects > ${depth + 1} (depth ${depth})'

	// dedup: nearly all of v1's objects are shared with v2
	dropped := count_only_in(sink1, sink2)
	assert dropped <= depth + 1
	shared_cnt := sink1.objects.len - dropped
	assert shared_cnt >= sink1.objects.len - (depth + 1)
	// sanity: the store really is fine-grained (thousands of shared objects)
	assert shared_cnt > n / 2
}

fn test_seqtree_boundaries() {
	fanout := 4
	for n in [0, 1, 3, 4, 5, 16, 17] {
		mut sink, root := build_seq(n, fanout, -1, '')
		got := collect_elements(sink, root)
		assert got.len == n, 'n=${n}: collected ${got.len}'
		// order preserved
		for i in 0 .. n {
			assert got[i] == object_name('elem-${i}'.bytes())
		}
	}
}

// Identical sequences must produce identical roots (deterministic, P2/P5).
fn test_seqtree_deterministic() {
	mut a, ra := build_seq(500, 16, -1, '')
	mut b, rb := build_seq(500, 16, -1, '')
	assert ra == rb
	assert a.objects.len == b.objects.len
}

// End-to-end: persist the object graph to a pack and reconstruct the sequence
// by walking from the root via the pack reader (in-memory ≡ on-disk model).
fn test_seqtree_persist_and_walk_from_pack() {
	fanout := 8
	n := 200
	mut sink, root := build_seq(n, fanout, -1, '')

	mut payloads := [][]u8{}
	for _, v in sink.objects {
		payloads << v
	}
	path := os.join_path(os.temp_dir(), 'cxstore_seqtree.cxpack')
	os.rm(path) or {}
	write_pack(path, payloads) or {
		assert false, 'write_pack: ${err}'
		return
	}
	r := open_pack(path) or {
		assert false, 'open_pack: ${err}'
		return
	}
	// root resolves from the pack and the full sequence reconstructs in order
	got := collect_elements_from_pack(r, root)
	assert got.len == n
	for i in 0 .. n {
		assert got[i] == object_name('elem-${i}'.bytes())
	}
	os.rm(path) or {}
}
