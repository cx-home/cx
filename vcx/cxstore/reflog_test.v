module cxstore

import crypto.sha256
import os

fn h(s string) []u8 {
	return sha256.sum256(s.bytes())
}

fn tmp_reflog(name string) string {
	p := os.join_path(os.temp_dir(), name)
	os.rm(p) or {}
	return p
}

fn test_commit_and_current_root() {
	rl := open_reflog(tmp_reflog('cxstore_rl_basic.log'))
	r1 := h('root-1')
	r2 := h('root-2')
	e1 := rl.commit('main', r1, 'w0'.bytes()) or {
		assert false, 'commit1: ${err}'
		return
	}
	assert e1 == 1
	cur1 := rl.current_root('main') or {
		assert false, 'no current root after commit1'
		return
	}
	assert cur1 == r1
	e2 := rl.commit('main', r2, 'w0'.bytes()) or {
		assert false, 'commit2: ${err}'
		return
	}
	assert e2 == 2
	cur2 := rl.current_root('main') or {
		assert false, 'no current root after commit2'
		return
	}
	assert cur2 == r2 // highest epoch wins
	// a different ref is independent
	if _ := rl.current_root('other') {
		assert false, 'unexpected root for untouched ref'
	}
	os.rm(rl.path) or {}
}

// Highest epoch wins regardless of physical order in the file.
fn test_highest_epoch_wins_out_of_order() {
	path := tmp_reflog('cxstore_rl_order.log')
	ref := h('main')
	// write epoch 5 first, then epoch 3 (lower) afterwards
	rec5 := encode_ref_record(5, ref, h('root-5'), 'w'.bytes())
	rec3 := encode_ref_record(3, ref, h('root-3'), 'w'.bytes())
	mut f := os.create(path) or {
		assert false, 'create: ${err}'
		return
	}
	f.write(rec5) or {}
	f.write(rec3) or {}
	f.close()
	rl := open_reflog(path)
	cur := rl.current_root('main') or {
		assert false, 'no current root'
		return
	}
	assert cur == h('root-5') // epoch 5 beats epoch 3 despite later position
	os.rm(path) or {}
}

// A torn trailing record is ignored; the last full record stands.
fn test_torn_tail_ignored() {
	rl := open_reflog(tmp_reflog('cxstore_rl_torn.log'))
	good := h('root-good')
	rl.commit('main', good, 'w'.bytes()) or {
		assert false, 'commit: ${err}'
		return
	}
	// append a partial (torn) record: 40 bytes of a would-be 92-byte record
	partial := encode_ref_record(99, h('main'), h('root-torn'), 'w'.bytes())[..40].clone()
	mut f := os.open_append(rl.path) or {
		assert false, 'append: ${err}'
		return
	}
	f.write(partial) or {}
	f.close()
	cur := rl.current_root('main') or {
		assert false, 'no current root'
		return
	}
	assert cur == good // torn tail did not corrupt the read
	os.rm(rl.path) or {}
}

// commit_cas: linearizable ref advancement; stale expectation loses.
fn test_cas_advance_and_conflict() {
	rl := open_reflog(tmp_reflog('cxstore_rl_cas.log'))
	r1 := h('root-1')
	r2 := h('root-2')
	r3 := h('root-3')
	// first commit: expect absent
	ok0 := rl.commit_cas('main', []u8{}, r1, 'w'.bytes()) or {
		assert false, 'cas0: ${err}'
		return
	}
	assert ok0
	// expecting absent again must fail (already exists)
	ok_dup := rl.commit_cas('main', []u8{}, r2, 'w'.bytes()) or {
		assert false, 'cas_dup: ${err}'
		return
	}
	assert !ok_dup
	// advance from r1 → r2 succeeds
	ok1 := rl.commit_cas('main', r1, r2, 'w'.bytes()) or {
		assert false, 'cas1: ${err}'
		return
	}
	assert ok1
	// stale writer still expecting r1 loses (current is r2)
	ok_stale := rl.commit_cas('main', r1, r3, 'w'.bytes()) or {
		assert false, 'cas_stale: ${err}'
		return
	}
	assert !ok_stale
	cur := rl.current_root('main') or {
		assert false, 'no current root'
		return
	}
	assert cur == r2
	os.rm(rl.path) or {}
}

// current_root_verified skips a higher-epoch root that fails verification (A.4).
fn test_verified_skips_unverifiable_head() {
	path := tmp_reflog('cxstore_rl_verify.log')
	ref := h('main')
	good := h('root-good')
	bad := h('root-bad')
	mut f := os.create(path) or {
		assert false, 'create: ${err}'
		return
	}
	f.write(encode_ref_record(1, ref, good, 'w'.bytes())) or {}
	f.write(encode_ref_record(2, ref, bad, 'w'.bytes())) or {} // higher epoch, but "unverifiable"
	f.close()
	rl := open_reflog(path)
	// plain current_root returns the highest epoch (bad)
	plain := rl.current_root('main') or {
		assert false, 'no current'
		return
	}
	assert plain == bad
	// verified skips bad → returns good
	verify := fn [good] (root []u8) bool {
		return compare_bytes(root, good) == 0
	}
	v := rl.current_root_verified('main', verify) or {
		assert false, 'no verified root'
		return
	}
	assert v == good
	os.rm(path) or {}
}
