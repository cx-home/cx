module cxstore

import os
import crypto.rand

// encryption_wrapper_test.v — unit tests for the #229 generic encryption layer:
// the v2 KEYED pack format (write_pack_keyed / flag-bit2 entries / version gate),
// the KeyedObjectBackend surface on PackObjectBackend, and EncryptingWrapper
// over it (seal/open envelopes keyed by the plaintext hash). The live store
// integration (encrypted cxpack:// end-to-end) is vcx/code/store_pack_encryption_test.v.

fn test_keyed_pack_roundtrip_and_version_gate() {
	dir := os.join_path(os.temp_dir(), 'cxstore_keyed_pack_${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	defer {
		os.rmdir_all(dir) or {}
	}
	// Keys are caller-supplied; blobs deliberately do NOT hash to them.
	k1 := object_name('alpha'.bytes())
	k2 := object_name('beta'.bytes())
	b1 := 'envelope-one: definitely not hashing to k1'.bytes()
	b2 := 'envelope-two'.bytes()
	p := os.join_path(dir, 'keyed.cxpack')
	write_pack_keyed(p, [
		KeyedPayload{
			key:  k1
			blob: b1
		},
		KeyedPayload{
			key:  k2
			blob: b2
		},
		// duplicate key → deduplicated (first wins)
		KeyedPayload{
			key:  k1
			blob: b1
		},
	]) or { panic('write_pack_keyed: ${err.msg()}') }

	r := open_pack(p) or { panic('open_pack: ${err.msg()}') }
	assert r.keyed, 'v2 pack must read back as keyed'
	assert int(r.count) == 2, 'duplicate keys must dedup'
	got1 := r.get(k1) or { panic('k1 missing') }
	assert got1 == b1, 'keyed entry bytes must round-trip verbatim (no self-verify)'
	got2 := r.get(k2) or { panic('k2 missing') }
	assert got2 == b2
	assert r.get(object_name('gamma'.bytes())) or { []u8{} } == []u8{}, 'absent key must be none'
	r.close()

	// A v1 pack reads back as NOT keyed.
	p1 := os.join_path(dir, 'plain.cxpack')
	write_pack(p1, [b1, b2]) or { panic('write_pack: ${err.msg()}') }
	r1 := open_pack(p1) or { panic('open v1: ${err.msg()}') }
	assert !r1.keyed
	r1.close()

	// Corrupting a keyed entry's stored bytes must fail its CRC (none, never
	// corrupt bytes handed back).
	mut img := os.read_bytes(p) or { panic(err) }
	// entries start at header_size; corrupt one payload byte well inside entry 1
	img[header_size + 50] = img[header_size + 50] ^ 0xff
	pc := os.join_path(dir, 'corrupt.cxpack')
	os.write_file_array(pc, img) or { panic(err) }
	rc := open_pack(pc) or { panic('open corrupt: ${err.msg()}') }
	mut served := 0
	for h in rc.hashes() {
		if _ := rc.get(h) {
			served++
		}
	}
	assert served < 2, 'a corrupted keyed entry must be rejected by its CRC'
	rc.close()
}

fn test_pack_backend_mode_guards_and_mismatch() {
	dir := os.join_path(os.temp_dir(), 'cxstore_keyed_be_${os.getpid()}')
	os.rmdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	// keyed backend refuses content-addressed puts; non-keyed refuses keyed puts.
	mut kb := open_pack_object_backend_keyed(dir)
	if _ := kb.put_object('x'.bytes()) {
		panic('keyed backend must refuse put_object')
	}
	mut pb := open_pack_object_backend(dir)
	key := object_name('x'.bytes())
	if _ := pb.put_object_keyed(key, 'y'.bytes()) {
		panic('non-keyed backend must refuse put_object_keyed')
	} else {
		// expected
	}

	// Write a keyed store, then reopen it non-keyed → HARD error (encrypted
	// store opened without its key), and the reverse.
	kb.put_object_keyed(key, 'envelope-bytes'.bytes()) or { panic(err) }
	kb.flush_segment() or { panic(err) }
	mut back_plain := open_pack_object_backend(dir)
	if _ := back_plain.load_objects() {
		panic('non-keyed open of a keyed store must error')
	}
	dir2 := os.join_path(os.temp_dir(), 'cxstore_plain_be_${os.getpid()}')
	os.rmdir_all(dir2) or {}
	defer {
		os.rmdir_all(dir2) or {}
	}
	mut pb2 := open_pack_object_backend(dir2)
	pb2.put_object('plain payload'.bytes()) or { panic(err) }
	pb2.flush_segment() or { panic(err) }
	mut back_keyed := open_pack_object_backend_keyed(dir2)
	if _ := back_keyed.load_objects() {
		panic('keyed open of a plaintext store must error')
	}
}

fn test_encrypting_wrapper_over_pack_backend() {
	dir := os.join_path(os.temp_dir(), 'cxstore_encwrap_${os.getpid()}')
	os.rmdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	kek := rand.bytes(32) or { panic(err) }
	kms := new_local_kms_with_master('t1', kek) or { panic(err) }
	mut inner := open_pack_object_backend_keyed(dir)
	mut w := new_encrypting_wrapper(inner, 't1', Kms(kms))

	payload := '[secret [token "hunter2"]]'.bytes()
	h := w.put_object(payload) or { panic('put: ${err.msg()}') }
	assert compare_bytes(h, object_name(payload)) == 0, 'external key must be the PLAINTEXT hash'
	assert w.has_object(h)
	// dedup: identical payload is a no-op (same key, envelope already staged)
	w.put_object(payload) or { panic(err) }
	assert w.object_count() == 1, 'identical plaintext must dedup to one stored object'

	// staged raw bytes are the envelope, not the plaintext
	raw := inner.get_object_raw(h) or { panic('raw missing') }
	assert raw.bytestr().contains('hunter2') == false, 'staged bytes must be ciphertext'
	got := w.get_object(h) or { panic('get: none') }
	assert got == payload, 'decrypt must round-trip byte-identical'

	// durable: flush, reopen through a fresh backend+wrapper with the SAME KEK
	inner.flush_segment() or { panic(err) }
	mut inner2 := open_pack_object_backend_keyed(dir)
	inner2.load_objects() or { panic('reload: ${err.msg()}') }
	kms2 := new_local_kms_with_master('t1', kek) or { panic(err) }
	w2 := new_encrypting_wrapper(inner2, 't1', Kms(kms2))
	got2 := w2.get_object(h) or { panic('get after reopen: none') }
	assert got2 == payload

	// wrong KEK → open_envelope fails (authentication), get_object → none
	wrong := rand.bytes(32) or { panic(err) }
	kms3 := new_local_kms_with_master('t1', wrong) or { panic(err) }
	w3 := new_encrypting_wrapper(inner2, 't1', Kms(kms3))
	if _ := w3.get_object(h) {
		panic('wrong KEK must fail closed (none), never plaintext')
	}
	env := inner2.get_object_raw(h) or { panic('raw missing after reload') }
	if _ := w3.open_envelope(h, env) {
		panic('open_envelope under the wrong KEK must error')
	}

	// swapped envelope (stored under a different key) fails aad binding
	other := 'other payload'.bytes()
	h2 := w2_put(mut inner2, kek, other)
	env2 := inner2.get_object_raw(h2) or { panic('raw2 missing') }
	if _ := w2.open_envelope(h, env2) {
		panic('an envelope moved to a different key must fail authentication')
	}
}

// w2_put seals+stages `payload` through a fresh wrapper (helper: the test needs a
// second object staged under its own key to prove aad binding).
fn w2_put(mut inner PackObjectBackend, kek []u8, payload []u8) []u8 {
	kms := new_local_kms_with_master('t1', kek) or { panic(err) }
	mut w := new_encrypting_wrapper(inner, 't1', Kms(kms))
	return w.put_object(payload) or { panic(err) }
}
