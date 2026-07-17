module cxstore

import os
import crypto.rand

// encryption_test.v — encryption-at-rest (#114): the AEAD envelope, the KMS
// seam, and the EncryptingObjectBackend. Proves real authenticated encryption
// (round-trip + tamper/wrong-key/wrong-aad rejection), that the object graph's
// content-address (plaintext hash) and dedup are preserved, that the at-rest
// bytes are NOT plaintext, and that a pinned master KEK makes objects portable
// across backend instances (the durability a real KMS provides).

fn test_aead_roundtrip() {
	key := rand.bytes(32) or { panic(err) }
	msg := 'the quick brown fox jumps over the lazy dog'.bytes()
	sealed := aead_seal(key, msg, 'aad'.bytes()) or { panic(err) }
	assert sealed != msg
	opened := aead_open(key, sealed, 'aad'.bytes()) or { panic('open failed: ${err}') }
	assert opened == msg
}

fn test_aead_empty_and_block_boundaries() {
	key := rand.bytes(32) or { panic(err) }
	// empty, exactly one block, one over a block — PKCS7 must handle all.
	for n in [0, 16, 17, 31, 32, 100] {
		msg := []u8{len: n, init: u8(index)}
		sealed := aead_seal(key, msg, []u8{}) or { panic(err) }
		opened := aead_open(key, sealed, []u8{}) or { panic('open n=${n}: ${err}') }
		assert opened == msg, 'roundtrip mismatch at n=${n}'
	}
}

fn test_aead_rejects_tamper() {
	key := rand.bytes(32) or { panic(err) }
	msg := 'secret payload'.bytes()
	mut sealed := aead_seal(key, msg, 'h'.bytes()) or { panic(err) }
	// flip a bit somewhere in the middle (ciphertext region)
	sealed[sealed.len / 2] ^= 0x01
	if _ := aead_open(key, sealed, 'h'.bytes()) {
		assert false, 'tampered ciphertext must NOT authenticate'
	}
}

fn test_aead_rejects_wrong_key() {
	k1 := rand.bytes(32) or { panic(err) }
	k2 := rand.bytes(32) or { panic(err) }
	sealed := aead_seal(k1, 'x'.bytes(), []u8{}) or { panic(err) }
	if _ := aead_open(k2, sealed, []u8{}) {
		assert false, 'wrong key must NOT authenticate'
	}
}

fn test_aead_rejects_wrong_aad() {
	key := rand.bytes(32) or { panic(err) }
	sealed := aead_seal(key, 'x'.bytes(), 'aad-A'.bytes()) or { panic(err) }
	if _ := aead_open(key, sealed, 'aad-B'.bytes()) {
		assert false, 'wrong aad must NOT authenticate'
	}
}

fn test_local_kms_wrap_unwrap() {
	mut kms := new_local_kms()
	dek, wrapped := kms.generate_data_key('tenant-1') or { panic(err) }
	assert dek.len == 32
	assert wrapped != dek
	unwrapped := kms.decrypt_data_key('tenant-1', wrapped) or { panic('unwrap: ${err}') }
	assert unwrapped == dek
}

fn test_encrypting_backend_roundtrip_and_dedup() {
	dir := os.join_path(os.temp_dir(), 'cx_enc_${rand_suffix()}')
	defer {
		os.rmdir_all(dir) or {}
	}
	mut kms := new_local_kms()
	mut b := new_encrypting_object_backend(dir, 'tenant-1', kms) or { panic(err) }
	payload := 'a content-addressed object body'.bytes()

	h1 := b.put_object(payload) or { panic('put: ${err}') }
	// external key is the PLAINTEXT hash → equals the bare object_name (dedup basis)
	assert compare_bytes(h1, object_name(payload)) == 0, 'key must be the plaintext hash'
	assert b.has_object(h1)

	got := b.get_object(h1) or { panic('get returned none') }
	assert got == payload, 'decrypted object must equal the original'

	// re-put identical payload → same hash, idempotent (no duplicate).
	h2 := b.put_object(payload) or { panic('re-put: ${err}') }
	assert compare_bytes(h1, h2) == 0

	// at-rest bytes must NOT be the plaintext.
	hex := h1.hex()
	at_rest := os.read_bytes(os.join_path(dir, hex[..2], hex)) or { panic('read at-rest: ${err}') }
	assert at_rest != payload, 'object must be encrypted at rest'
	assert !at_rest.bytestr().contains('content-addressed object body'), 'plaintext must not appear at rest'
}

fn test_encrypting_backend_durable_master_portable() {
	dir := os.join_path(os.temp_dir(), 'cx_enc_dur_${rand_suffix()}')
	defer {
		os.rmdir_all(dir) or {}
	}
	master := rand.bytes(32) or { panic(err) }
	payload := 'portable across processes'.bytes()

	// write with one backend + KMS pinned to a durable master KEK
	mut kms_a := new_local_kms_with_master('tenant-X', master) or { panic(err) }
	mut wb := new_encrypting_object_backend(dir, 'tenant-X', kms_a) or { panic(err) }
	h := wb.put_object(payload) or { panic('put: ${err}') }

	// a FRESH backend + FRESH KMS with the SAME master must open it.
	mut kms_b := new_local_kms_with_master('tenant-X', master) or { panic(err) }
	mut rb := new_encrypting_object_backend(dir, 'tenant-X', kms_b) or { panic(err) }
	got := rb.get_object(h) or { panic('cross-instance get returned none') }
	assert got == payload

	// a backend with a DIFFERENT master must NOT decrypt.
	other := rand.bytes(32) or { panic(err) }
	mut kms_c := new_local_kms_with_master('tenant-X', other) or { panic(err) }
	mut xb := new_encrypting_object_backend(dir, 'tenant-X', kms_c) or { panic(err) }
	if _ := xb.get_object(h) {
		assert false, 'wrong master KEK must not decrypt'
	}
}

// ── #287 envelope v2 (recorded key-id) + KEK rotation kernel ──────────────────

fn test_envelope_records_key_id() {
	mut kms := new_local_kms()
	key := object_name('some payload'.bytes())
	blob := envelope_seal(mut kms, 'tenant-α', key, 'some payload'.bytes()) or { panic(err) }
	env := parse_envelope(blob) or { panic('parse: ${err}') }
	assert env.key_id == 'tenant-α', 'envelope must record its wrapping key-id'
	assert blob[0] == envelope_version
	got := envelope_open(mut kms, key, blob) or { panic('open: ${err}') }
	assert got == 'some payload'.bytes()
}

fn test_envelope_rejects_v1_era_blob() {
	// a pre-#287 envelope began with u16-be(wrapped_len) — first byte 0x00 —
	// and must fail parse with a version error, never be misread.
	mut v1 := []u8{}
	v1 << u8(0)
	v1 << u8(112)
	v1 << []u8{len: 200, init: u8(index)}
	if _ := parse_envelope(v1) {
		assert false, 'v1-era envelope must not parse as v2'
	}
	parse_envelope(v1) or {
		assert err.msg().contains('version'), 'error must name the version mismatch: ${err.msg()}'
	}
}

fn test_envelope_rejects_bad_key_id_len() {
	if _ := build_envelope('', 'w'.bytes(), 's'.bytes()) {
		assert false, 'empty key-id must be rejected'
	}
	long := 'x'.repeat(256)
	if _ := build_envelope(long, 'w'.bytes(), 's'.bytes()) {
		assert false, 'key-id > 255 bytes must be rejected'
	}
}

fn test_rewrap_envelope_rotates_key_id_and_preserves_payload() {
	mut kms := new_local_kms() // ephemeral: mints per-id KEKs on demand
	payload := 'rotate me, not my payload'.bytes()
	key := object_name(payload)
	blob := envelope_seal(mut kms, 'tenant-a', key, payload) or { panic(err) }
	orig := parse_envelope(blob) or { panic(err) }

	nb, old_id, changed := rewrap_envelope(mut kms, blob, 'tenant-b') or { panic('rewrap: ${err}') }
	assert changed
	assert old_id == 'tenant-a'
	env := parse_envelope(nb) or { panic(err) }
	assert env.key_id == 'tenant-b'
	// the sealed payload is byte-identical — only the wrapped DEK changed.
	assert env.sealed == orig.sealed, 'rotation must not touch the sealed payload'
	assert env.wrapped != orig.wrapped, 'rotation must re-wrap the DEK'
	// opens under the new wrap (the DEK itself is unchanged).
	got := envelope_open(mut kms, key, nb) or { panic('open after rewrap: ${err}') }
	assert got == payload
	// and the OLD blob still opens too while the old KEK exists (mixed store).
	still := envelope_open(mut kms, key, blob) or { panic('open old after rewrap: ${err}') }
	assert still == payload
}

fn test_rewrap_envelope_already_current_is_noop() {
	mut kms := new_local_kms()
	payload := 'idempotent'.bytes()
	key := object_name(payload)
	blob := envelope_seal(mut kms, 'tenant-b', key, payload) or { panic(err) }
	nb, old_id, changed := rewrap_envelope(mut kms, blob, 'tenant-b') or { panic(err) }
	assert !changed, 'an envelope already under the target key-id must be a no-op'
	assert old_id == 'tenant-b'
	assert nb == blob, 'no-op rewrap must return the blob byte-identical'
}

fn test_rewrap_envelope_fails_closed_on_unknown_key_id() {
	master := rand.bytes(32) or { panic(err) }
	mut kms_a := new_local_kms_with_master('tenant-a', master) or { panic(err) }
	payload := 'orphaned'.bytes()
	key := object_name(payload)
	blob := envelope_seal(mut kms_a, 'tenant-a', key, payload) or { panic(err) }

	// a LOCKED provider knowing only tenant-b cannot unwrap tenant-a's DEK —
	// rotation must ERROR naming the id, never skip.
	other := rand.bytes(32) or { panic(err) }
	mut kms_b := new_local_kms_locked()
	kms_b.add_master('tenant-b', other) or { panic(err) }
	if _, _, _ := rewrap_envelope(mut kms_b, blob, 'tenant-b') {
		assert false, 'rewrap with an unresolvable recorded key-id must fail closed'
	}
	rewrap_envelope(mut kms_b, blob, 'tenant-b') or {
		assert err.msg().contains('tenant-a'), 'error must name the unresolvable key-id: ${err.msg()}'
	}
}

fn test_encrypting_backend_rotate_kek_walk() {
	dir := os.join_path(os.temp_dir(), 'cx_enc_rot_${rand_suffix()}')
	defer {
		os.rmdir_all(dir) or {}
	}
	ka := rand.bytes(32) or { panic(err) }
	kb := rand.bytes(32) or { panic(err) }
	mut kms := new_local_kms_with_master('tenant-a', ka) or { panic(err) }
	kms.add_master('tenant-b', kb) or { panic(err) }
	mut b := new_encrypting_object_backend(dir, 'tenant-a', kms) or { panic(err) }
	mut hashes := [][]u8{}
	mut payloads := [][]u8{}
	for i in 0 .. 5 {
		p := 'object number ${i} — sealed under tenant-a'.bytes()
		h := b.put_object(p) or { panic(err) }
		hashes << h
		payloads << p
	}

	rep := b.rotate_kek('tenant-b') or { panic('rotate: ${err}') }
	assert rep.objects == 5
	assert rep.rewrapped == 5
	assert rep.already_current == 0
	assert rep.from_ids == ['tenant-a']

	// every at-rest envelope now records tenant-b; content addresses unchanged.
	for i, h in hashes {
		hex := h.hex()
		at_rest := os.read_bytes(os.join_path(dir, hex[..2], hex)) or { panic(err) }
		env := parse_envelope(at_rest) or { panic(err) }
		assert env.key_id == 'tenant-b'
		got := b.get_object(h) or { panic('get after rotate returned none') }
		assert got == payloads[i]
	}

	// destroy KEK A: a FRESH backend + provider knowing ONLY tenant-b opens all.
	mut kms2 := new_local_kms_locked()
	kms2.add_master('tenant-b', kb) or { panic(err) }
	mut b2 := new_encrypting_object_backend(dir, 'tenant-b', kms2) or { panic(err) }
	for i, h in hashes {
		got := b2.get_object(h) or { panic('post-destroy get returned none') }
		assert got == payloads[i]
	}

	// re-run: resumable no-op (everything already current).
	rep2 := b2.rotate_kek('tenant-b') or { panic(err) }
	assert rep2.objects == 5
	assert rep2.rewrapped == 0
	assert rep2.already_current == 5

	// new writes on the rotated backend wrap under the new key.
	np := 'written after rotation'.bytes()
	nh := b2.put_object(np) or { panic(err) }
	nhex := nh.hex()
	nblob := os.read_bytes(os.join_path(dir, nhex[..2], nhex)) or { panic(err) }
	nenv := parse_envelope(nblob) or { panic(err) }
	assert nenv.key_id == 'tenant-b'
}

fn test_encrypting_backend_rotate_kek_fails_closed_on_alien_envelope() {
	dir := os.join_path(os.temp_dir(), 'cx_enc_rot_alien_${rand_suffix()}')
	defer {
		os.rmdir_all(dir) or {}
	}
	ka := rand.bytes(32) or { panic(err) }
	kb := rand.bytes(32) or { panic(err) }
	kg := rand.bytes(32) or { panic(err) }
	mut kms := new_local_kms_with_master('tenant-a', ka) or { panic(err) }
	kms.add_master('tenant-b', kb) or { panic(err) }
	mut b := new_encrypting_object_backend(dir, 'tenant-a', kms) or { panic(err) }
	b.put_object('a normal object'.bytes()) or { panic(err) }

	// plant an envelope wrapped under a key-id THIS provider cannot resolve.
	mut kms_g := new_local_kms_with_master('tenant-ghost', kg) or { panic(err) }
	mut bg := new_encrypting_object_backend(dir, 'tenant-ghost', kms_g) or { panic(err) }
	bg.put_object('an orphaned object'.bytes()) or { panic(err) }

	if _ := b.rotate_kek('tenant-b') {
		assert false, 'rotation over an unresolvable envelope must fail closed, never skip'
	}
	b.rotate_kek('tenant-b') or {
		assert err.msg().contains('tenant-ghost'), 'error must name the unresolvable key-id: ${err.msg()}'
	}
}

fn test_encrypting_backend_rotate_kek_probes_new_key_first() {
	dir := os.join_path(os.temp_dir(), 'cx_enc_rot_probe_${rand_suffix()}')
	defer {
		os.rmdir_all(dir) or {}
	}
	ka := rand.bytes(32) or { panic(err) }
	mut kms := new_local_kms_locked()
	kms.add_master('tenant-a', ka) or { panic(err) }
	mut b := new_encrypting_object_backend(dir, 'tenant-a', kms) or { panic(err) }
	h := b.put_object('untouched'.bytes()) or { panic(err) }

	// the target key-id does not resolve → rotation fails BEFORE touching
	// anything; the store still opens under tenant-a.
	if _ := b.rotate_kek('tenant-typo') {
		assert false, 'rotation to an unresolvable key-id must fail'
	}
	hex := h.hex()
	blob := os.read_bytes(os.join_path(dir, hex[..2], hex)) or { panic(err) }
	env := parse_envelope(blob) or { panic(err) }
	assert env.key_id == 'tenant-a', 'a failed probe must leave every envelope untouched'
}

fn rand_suffix() string {
	b := rand.bytes(8) or { return 'fallback' }
	return b.hex()
}
