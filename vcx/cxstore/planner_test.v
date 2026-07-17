module cxstore

import os

fn test_planner_prunes_and_matches_full_scan() {
	dir := os.join_path(os.temp_dir(), 'cxstore_planner_rt')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	ka := repo.put_text('[db [rec [id 1]]]') or {
		assert false, 'putA: ${err}'
		return
	}
	kb := repo.put_text('[db [rec [id 2]]]') or {
		assert false, 'putB: ${err}'
		return
	}
	kc := repo.put_text('[catalog [item [sku 9]]]') or {
		assert false, 'putC: ${err}'
		return
	}
	ix := repo.build_index()

	// plan //rec — indexable, candidates exclude the rec-free doc C
	plan := plan_query(ix, repo.list(), '//rec')
	assert plan.indexable
	assert ka in plan.candidates && kb in plan.candidates
	assert kc !in plan.candidates
	assert plan.candidates.len < repo.list().len // strictly fewer docs touched

	// planned query == full scan (same matching docs), and is correct
	planned := repo.query(ix, '//rec')
	full := repo.query_full('//rec')
	assert planned.sorted() == full.sorted()
	assert planned.sorted() == [ka, kb].sorted()

	// non-indexable query falls back to a full candidate set
	plan2 := plan_query(ix, repo.list(), '//rec[id]')
	assert !plan2.indexable
	assert plan2.candidates.len == repo.list().len
	// and still returns correct results via fallback parity
	assert repo.query(ix, '//item').sorted() == repo.query_full('//item').sorted()
	assert repo.query(ix, '//item') == [kc]

	os.rmdir_all(dir) or {}
}

// A query for an element no document contains yields an empty plan + result.
fn test_planner_absent_element() {
	dir := os.join_path(os.temp_dir(), 'cxstore_planner_absent')
	os.rmdir_all(dir) or {}
	mut repo := open_repo(dir) or {
		assert false, 'open: ${err}'
		return
	}
	repo.put_text('[db [rec [id 1]]]') or {
		assert false, 'put: ${err}'
		return
	}
	ix := repo.build_index()
	plan := plan_query(ix, repo.list(), '//ghost')
	assert plan.indexable
	assert plan.candidates.len == 0
	assert repo.query(ix, '//ghost') == []
	assert repo.query_full('//ghost') == []
	os.rmdir_all(dir) or {}
}
