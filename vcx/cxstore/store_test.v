module cxstore

import os

fn sp(name string) string {
	p := os.join_path(os.temp_dir(), name)
	os.rm(p) or {}
	return p
}

// Objects spread across two packs resolve through one logical store.
fn test_store_resolves_across_packs() {
	p1 := sp('cxstore_store_a.cxpack')
	p2 := sp('cxstore_store_b.cxpack')
	a := ['alpha'.bytes(), 'beta'.bytes()]
	b := ['gamma'.bytes(), 'delta'.bytes()]
	write_pack(p1, a) or { assert false, 'write a: ${err}'; return }
	write_pack(p2, b) or { assert false, 'write b: ${err}'; return }

	s := open_store([p1, p2]) or { assert false, 'open_store: ${err}'; return }
	assert s.pack_count() == 2
	assert s.object_count() == 4
	for payload in [a[0], a[1], b[0], b[1]] {
		got := s.get(object_name(payload)) or {
			assert false, 'missing ${payload.bytestr()}'
			return
		}
		assert got == payload
	}
	assert !s.has(object_name('absent'.bytes()))
	os.rm(p1) or {}
	os.rm(p2) or {}
}

// An object present in two packs counts once (cross-pack dedup view).
fn test_store_cross_pack_dedup_view() {
	p1 := sp('cxstore_store_dup_a.cxpack')
	p2 := sp('cxstore_store_dup_b.cxpack')
	shared_obj := 'shared-object'.bytes()
	write_pack(p1, [shared_obj, 'only-a'.bytes()]) or { assert false, 'write a: ${err}'; return }
	write_pack(p2, [shared_obj, 'only-b'.bytes()]) or { assert false, 'write b: ${err}'; return }

	s := open_store([p1, p2]) or { assert false, 'open_store: ${err}'; return }
	// 3 unique objects (shared counted once), though 4 physical entries exist
	assert s.object_count() == 3
	got := s.get(object_name(shared_obj)) or {
		assert false, 'shared not resolvable'
		return
	}
	assert got == shared_obj
	os.rm(p1) or {}
	os.rm(p2) or {}
}

// A seq-tree whose objects are split across two packs reconstructs in full.
fn test_store_walks_seqtree_across_packs() {
	fanout := 8
	n := 300
	mut sink := ObjectSink{}
	mut elems := [][]u8{}
	for i in 0 .. n {
		elems << sink.put('e-${i}'.bytes())
	}
	root := build_seqtree(mut sink, elems, fanout)

	// split all objects roughly in half across two packs
	mut all := [][]u8{}
	for _, v in sink.objects {
		all << v
	}
	half := all.len / 2
	p1 := sp('cxstore_store_tree_a.cxpack')
	p2 := sp('cxstore_store_tree_b.cxpack')
	write_pack(p1, all[..half]) or { assert false, 'write a: ${err}'; return }
	write_pack(p2, all[half..]) or { assert false, 'write b: ${err}'; return }

	s := open_store([p1, p2]) or { assert false, 'open_store: ${err}'; return }
	got := s.collect_elements(root)
	assert got.len == n, 'reconstructed ${got.len}, expected ${n}'
	for i in 0 .. n {
		assert got[i] == object_name('e-${i}'.bytes())
	}
	os.rm(p1) or {}
	os.rm(p2) or {}
}
