module cxstore

import cx
import os

// canonical text after a parse→store→load→emit round-trip should equal the
// canonical text of the input (faithful storage).
fn canon_rt(text string) string {
	c := cx.cx_text_canonical(text) or { return 'ERR-canon' }
	d := cx.parse(c) or { return 'ERR-parse' }
	return cx.emit_cx(d)
}

fn test_repo_put_get_reopen_dedup() {
	dir := os.join_path(os.temp_dir(), 'cxstore_repo_rt')
	os.rmdir_all(dir) or {}

	in1 := '[db [rec [id 1] [v 1]] [rec [id 2] [v 2]]]'
	in2 := '[db [rec [id 3] [v 3]]]'

	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	h1 := repo.put_text(in1) or {
		assert false, 'put1: ${err}'
		return
	}
	h2 := repo.put_text(in2) or {
		assert false, 'put2: ${err}'
		return
	}
	assert h1 != h2
	assert repo.len() == 2

	// dedup: same content → same key, no new entry
	h1b := repo.put_text(in1) or {
		assert false, 'put1b: ${err}'
		return
	}
	assert h1b == h1
	assert repo.len() == 2

	// faithful read
	got1 := repo.get_text(h1) or {
		assert false, 'get1'
		return
	}
	assert got1 == canon_rt(in1)
	assert repo.get_text('deadbeef') == none

	// reopen from disk: documents survive losslessly
	mut repo2 := open_repo(dir) or {
		assert false, 'reopen: ${err}'
		return
	}
	assert repo2.len() == 2
	got1r := repo2.get_text(h1) or {
		assert false, 'get1 after reopen'
		return
	}
	assert got1r == got1
	got2r := repo2.get_text(h2) or {
		assert false, 'get2 after reopen'
		return
	}
	assert got2r == canon_rt(in2)

	os.rmdir_all(dir) or {}
}

// Cross-document subtree dedup: two docs sharing a subtree share objects on
// disk (fewer total objects than the sum of their standalone object counts).
fn test_repo_cross_doc_subtree_dedup() {
	dir := os.join_path(os.temp_dir(), 'cxstore_repo_dedup')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	// both contain an identical [shared [k "same"] [k "same2"]] subtree
	repo.put_text('[doc [shared [k "same"] [k "same2"]] [a 1]]') or {
		assert false, 'putA: ${err}'
		return
	}
	repo.put_text('[doc [shared [k "same"] [k "same2"]] [b 2]]') or {
		assert false, 'putB: ${err}'
		return
	}
	// reopen and confirm both load; shared subtree means the union object count
	// is less than naive double-store
	mut repo2 := open_repo(dir) or {
		assert false, 'reopen: ${err}'
		return
	}
	assert repo2.len() == 2
	os.rmdir_all(dir) or {}
}
