module cxstore

import os

// The native engine (Repo) must satisfy StorageBackend and the capability
// interfaces, and behave identically when driven through them.
fn test_repo_satisfies_storage_backend() {
	dir := os.join_path(os.temp_dir(), 'cxstore_backend')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}

	// drive the core surface through the interface
	mut b := StorageBackend(&repo)
	k := b.put('[doc [x 1]]') or {
		assert false, 'put: ${err}'
		return
	}
	assert b.has(k)
	assert !b.has('deadbeef')
	got := b.get(k) or {
		assert false, 'get'
		return
	}
	assert got.contains('x')
	assert b.list() == [k]

	// capability negotiation resolves
	assert is_indexed(b)
	assert is_queryable(b)
}

fn test_repo_capability_interfaces() {
	dir := os.join_path(os.temp_dir(), 'cxstore_backend_caps')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	k := repo.put('[db [rec [id 1]]]') or {
		assert false, 'put: ${err}'
		return
	}

	// Indexed capability through the interface
	ixb := Indexed(&repo)
	ix := ixb.build_index()
	assert ix.docs_with_element('rec') == [k]

	// Queryable capability through the interface
	qb := Queryable(&repo)
	assert qb.query(ix, '//rec') == [k]

	os.rmdir_all(dir) or {}
}
