module cxstore

import os

fn test_secondary_index_queries() {
	dir := os.join_path(os.temp_dir(), 'cxstore_index_rt')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	// doc A: [db [rec [id 1] [name "a"]]] ; doc B: [catalog [item [sku 9]]]
	ka := repo.put_text('[db [rec [id 1] [name "a"]]]') or {
		assert false, 'putA: ${err}'
		return
	}
	kb := repo.put_text('[catalog [item [sku 9]]]') or {
		assert false, 'putB: ${err}'
		return
	}

	ix := repo.build_index()

	// element-name index
	assert ix.docs_with_element('rec') == [ka]
	assert ix.docs_with_element('item') == [kb]
	assert ix.docs_with_element('id') == [ka]
	assert ix.docs_with_element('nope') == []

	// path-summary index (root-rooted element paths)
	assert ix.docs_with_path('db/rec/id') == [ka]
	assert ix.docs_with_path('catalog/item/sku') == [kb]
	assert ix.docs_with_path('db/rec') == [ka]
	assert ix.docs_with_path('db/item') == []

	os.rmdir_all(dir) or {}
}

// An element present in two documents indexes to both.
fn test_secondary_index_multi_doc() {
	dir := os.join_path(os.temp_dir(), 'cxstore_index_multi')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	k1 := repo.put_text('[log [entry [msg "x"]]]') or {
		assert false, 'put1: ${err}'
		return
	}
	k2 := repo.put_text('[log [entry [msg "y"]]]') or {
		assert false, 'put2: ${err}'
		return
	}
	ix := repo.build_index()
	hits := ix.docs_with_element('entry')
	assert hits.len == 2
	assert k1 in hits
	assert k2 in hits
	os.rmdir_all(dir) or {}
}

// The sidecar round-trips (rebuild → save → load equals rebuild).
fn test_secondary_index_sidecar_roundtrip() {
	dir := os.join_path(os.temp_dir(), 'cxstore_index_sidecar')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	repo.put_text('[db [rec [id 1]]]') or {
		assert false, 'put: ${err}'
		return
	}
	// first index() rebuilds and writes the sidecar
	ix1 := repo.index()
	assert os.exists(os.join_path(dir, repo_index_sidecar))
	// second index() loads the sidecar; same answers
	ix2 := repo.index()
	assert ix2.docs_with_element('rec') == ix1.docs_with_element('rec')
	assert ix2.docs_with_path('db/rec/id') == ix1.docs_with_path('db/rec/id')
	os.rmdir_all(dir) or {}
}
