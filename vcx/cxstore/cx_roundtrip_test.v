module cxstore

import cx
import os

fn rt_src() string {
	return '[db [meta [version 1] [name "store"]]
  [rec [id 1] [name "alice"] [tags [t "a"] [t "b"]]]
  [rec [id 2] [name "bob"] [tags [t "c"]]]]'
}

// The capstone: parse a real CX doc → content-address (commit) → reconstruct
// (load) → the reconstructed document re-encodes byte-identically. Proves the
// full write+read path and that the object graph faithfully represents the doc.
fn test_document_roundtrip() {
	doc1 := cx.parse(rt_src()) or {
		assert false, 'parse: ${err}'
		return
	}
	pack := os.join_path(os.temp_dir(), 'cxstore_rt.cxpack')
	reflog := os.join_path(os.temp_dir(), 'cxstore_rt.reflog')
	os.rm(pack) or {}
	os.rm(reflog) or {}

	mut store := open_store([]string{}) or {
		assert false, 'open_store: ${err}'
		return
	}
	store.commit_document(doc1, 'main', pack, reflog) or {
		assert false, 'commit: ${err}'
		return
	}
	doc2 := store.load_document('main', reflog) or {
		assert false, 'load: ${err}'
		return
	}

	// faithful reconstruction: re-encoded ast_bin is byte-identical
	a := cx.emit_ast_bin(doc1)
	b := cx.emit_ast_bin(doc2)
	assert a == b, 'round-trip mismatch: ${a.len} vs ${b.len} bytes'

	os.rm(pack) or {}
	os.rm(reflog) or {}
}

// A second commit advances the ref; loading reflects the new content.
fn test_commit_advances_ref() {
	pack1 := os.join_path(os.temp_dir(), 'cxstore_rt_v1.cxpack')
	pack2 := os.join_path(os.temp_dir(), 'cxstore_rt_v2.cxpack')
	reflog := os.join_path(os.temp_dir(), 'cxstore_rt2.reflog')
	for p in [pack1, pack2, reflog] {
		os.rm(p) or {}
	}

	d1 := cx.parse('[doc [v 1]]') or {
		assert false, 'parse1: ${err}'
		return
	}
	d2 := cx.parse('[doc [v 2]]') or {
		assert false, 'parse2: ${err}'
		return
	}
	mut store := open_store([]string{}) or {
		assert false, 'open_store: ${err}'
		return
	}
	store.commit_document(d1, 'main', pack1, reflog) or {
		assert false, 'commit1: ${err}'
		return
	}
	store.commit_document(d2, 'main', pack2, reflog) or {
		assert false, 'commit2: ${err}'
		return
	}
	loaded := store.load_document('main', reflog) or {
		assert false, 'load: ${err}'
		return
	}
	// the current ref resolves to v2
	assert cx.emit_ast_bin(loaded) == cx.emit_ast_bin(d2)
	assert cx.emit_ast_bin(loaded) != cx.emit_ast_bin(d1)

	for p in [pack1, pack2, reflog] {
		os.rm(p) or {}
	}
}
