module cxsqlite

import cxstore
import os

fn test_sqlite_backend_roundtrip_and_persist() ! {
	path := os.join_path(os.temp_dir(), 'cxstore_sqlite_rt.db')
	os.rm(path) or {}

	mut b := open(path)!
	k1 := b.put('[doc [x 1]]')!
	k2 := b.put('[doc [y 2]]')!
	assert k1 != k2
	assert b.has(k1)
	assert !b.has('deadbeef')
	got := b.get(k1) or { return error('miss k1') }
	assert got.contains('x')
	assert b.list().len == 2

	// content dedup: same doc → same key, no new row
	k1b := b.put('[doc [x 1]]')!
	assert k1b == k1
	assert b.list().len == 2
	b.close()

	// persistence across reopen
	mut b2 := open(path)!
	assert b2.list().len == 2
	assert b2.has(k1)
	g2 := b2.get(k2) or { return error('miss k2 after reopen') }
	assert g2.contains('y')
	b2.close()

	os.rm(path) or {}
}

// SqliteBackend satisfies the cxstore.StorageBackend trait and works through it.
fn test_sqlite_satisfies_storage_backend() ! {
	mut b := open(':memory:')!
	mut sb := cxstore.StorageBackend(&b)
	k := sb.put('[rec [id 7]]')!
	assert sb.has(k)
	assert !sb.has('nope')
	got := sb.get(k) or { return error('miss via interface') }
	assert got.contains('id')
	assert sb.list() == [k]
	b.close()
}

// Transactional capability: rollback discards, commit persists.
fn test_sqlite_transactional() ! {
	mut b := open(':memory:')!
	assert cxstore.is_transactional(cxstore.StorageBackend(&b))

	// rolled-back put leaves nothing
	b.begin()!
	rk := b.put('[doc [rolled "back"]]')!
	assert b.has(rk)
	b.rollback()!
	assert !b.has(rk)
	assert b.list().len == 0

	// committed put persists
	b.begin()!
	ck := b.put('[doc [committed "yes"]]')!
	b.commit()!
	assert b.has(ck)
	assert b.list().len == 1
	b.close()
}
