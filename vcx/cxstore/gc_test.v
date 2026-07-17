module cxstore

import cx
import os

// GC keeps everything reachable from the live root and drops objects only
// reachable from a superseded root; the live document still loads from the
// compacted pack alone.
fn test_gc_drops_dead_keeps_live() {
	dir := os.temp_dir()
	p1 := os.join_path(dir, 'cxstore_gc_v1.cxpack')
	p2 := os.join_path(dir, 'cxstore_gc_v2.cxpack')
	comp := os.join_path(dir, 'cxstore_gc_comp.cxpack')
	rl := os.join_path(dir, 'cxstore_gc.reflog')
	for p in [p1, p2, comp, rl] {
		os.rm(p) or {}
	}

	// two versions differing in one deep value
	d1 := cx.parse('[db [rec [id 1] [v 100]] [rec [id 2] [v 200]]]') or {
		assert false, 'parse1: ${err}'
		return
	}
	d2 := cx.parse('[db [rec [id 1] [v 100]] [rec [id 2] [v 999]]]') or {
		assert false, 'parse2: ${err}'
		return
	}
	mut store := open_store([]string{}) or {
		assert false, 'open: ${err}'
		return
	}
	store.commit_document(d1, 'main', p1, rl) or {
		assert false, 'commit1: ${err}'
		return
	}
	store.commit_document(d2, 'main', p2, rl) or {
		assert false, 'commit2: ${err}'
		return
	}

	total := store.object_count()
	reflog := open_reflog(rl)
	root := reflog.current_root('main') or {
		assert false, 'no current root'
		return
	}

	live := store.reachable([root])
	assert live.len > 0
	assert live.len < total, 'GC kept everything: live=${live.len} total=${total}'

	n := store.compact([root], comp) or {
		assert false, 'compact: ${err}'
		return
	}
	assert n == live.len

	// the compacted pack holds exactly the live objects …
	store2 := open_store([comp]) or {
		assert false, 'open2: ${err}'
		return
	}
	assert store2.object_count() == live.len
	// … and the live document still reconstructs from it
	doc := store2.load_document('main', rl) or {
		assert false, 'load from compacted: ${err}'
		return
	}
	assert cx.emit_ast_bin(doc) == cx.emit_ast_bin(d2)

	for p in [p1, p2, comp, rl] {
		os.rm(p) or {}
	}
}

// Compaction is idempotent: GC of an already-compacted store keeps everything.
fn test_gc_idempotent() {
	dir := os.temp_dir()
	p := os.join_path(dir, 'cxstore_gc_idem.cxpack')
	c := os.join_path(dir, 'cxstore_gc_idem_c.cxpack')
	rl := os.join_path(dir, 'cxstore_gc_idem.reflog')
	for f in [p, c, rl] {
		os.rm(f) or {}
	}
	d := cx.parse('[doc [a 1] [b 2] [c 3]]') or {
		assert false, 'parse: ${err}'
		return
	}
	mut store := open_store([]string{}) or {
		assert false, 'open: ${err}'
		return
	}
	store.commit_document(d, 'main', p, rl) or {
		assert false, 'commit: ${err}'
		return
	}
	root := open_reflog(rl).current_root('main') or {
		assert false, 'no root'
		return
	}
	before := store.object_count()
	n := store.compact([root], c) or {
		assert false, 'compact: ${err}'
		return
	}
	// single live version → nothing to drop
	assert n == before
	for f in [p, c, rl] {
		os.rm(f) or {}
	}
}
