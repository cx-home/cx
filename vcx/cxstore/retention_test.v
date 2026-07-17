module cxstore

import cx
import os

// keep-last-N retention: GC keeps the last N roots per ref and drops objects
// only reachable from superseded versions; the kept version still loads.
fn test_retention_keep_last_n() {
	dir := os.join_path(os.temp_dir(), 'cxstore_retain')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or {
		assert false, 'mkdir: ${err}'
		return
	}
	rl := os.join_path(dir, 'refs.log')
	p1 := os.join_path(dir, 'v1.cxpack')
	p2 := os.join_path(dir, 'v2.cxpack')
	p3 := os.join_path(dir, 'v3.cxpack')

	mut store := open_store([]string{}) or {
		assert false, 'open: ${err}'
		return
	}
	d1 := cx.parse('[doc [v 1] [note "first"]]') or {
		assert false, 'p1'
		return
	}
	d2 := cx.parse('[doc [v 2] [note "second"]]') or {
		assert false, 'p2'
		return
	}
	d3 := cx.parse('[doc [v 3] [note "third"]]') or {
		assert false, 'p3'
		return
	}
	store.commit_document(d1, 'main', p1, rl) or {
		assert false, 'c1: ${err}'
		return
	}
	store.commit_document(d2, 'main', p2, rl) or {
		assert false, 'c2: ${err}'
		return
	}
	store.commit_document(d3, 'main', p3, rl) or {
		assert false, 'c3: ${err}'
		return
	}
	total := store.object_count()
	reflog := open_reflog(rl)

	// keep last 1 → only the latest version's objects survive
	comp1 := os.join_path(dir, 'comp1.cxpack')
	n1 := store.gc_retain(reflog, RetentionPolicy{ keep_versions: 1 }, comp1) or {
		assert false, 'gc1: ${err}'
		return
	}
	assert n1 < total, 'keep-1 kept everything (${n1}/${total})'
	store1 := open_store([comp1]) or {
		assert false, 'open comp1: ${err}'
		return
	}
	assert store1.object_count() == n1
	// the live version (ref head = v3) still reconstructs from the compacted pack
	got3 := store1.load_document('main', rl) or {
		assert false, 'load v3 from compacted: ${err}'
		return
	}
	assert cx.emit_ast_bin(got3) == cx.emit_ast_bin(d3)

	// keep last 3 → all three versions' objects are live
	comp3 := os.join_path(dir, 'comp3.cxpack')
	n3 := store.gc_retain(reflog, RetentionPolicy{ keep_versions: 3 }, comp3) or {
		assert false, 'gc3: ${err}'
		return
	}
	assert n3 == total, 'keep-3 dropped live objects (${n3}/${total})'

	os.rmdir_all(dir) or {}
}

// size trigger: needs_gc fires only when the store exceeds max_bytes.
fn test_retention_size_trigger() {
	dir := os.join_path(os.temp_dir(), 'cxstore_retain_sz')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or {
		assert false, 'mkdir'
		return
	}
	path := os.join_path(dir, 'p.cxpack')
	write_pack(path, ['alpha'.bytes(), 'beta'.bytes()]) or {
		assert false, 'write: ${err}'
		return
	}
	s := open_store([path]) or {
		assert false, 'open: ${err}'
		return
	}
	assert s.byte_size() > 0
	assert !s.needs_gc(RetentionPolicy{ max_bytes: 0 }) // disabled
	assert s.needs_gc(RetentionPolicy{ max_bytes: 1 }) // tiny threshold exceeded
	assert !s.needs_gc(RetentionPolicy{ max_bytes: 1_000_000_000 }) // ample headroom
	os.rmdir_all(dir) or {}
}
