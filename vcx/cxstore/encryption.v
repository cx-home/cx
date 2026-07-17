module cxstore

import os
import crypto.aes
import crypto.cipher
import crypto.hmac
import crypto.sha256
import crypto.hkdf
import crypto.rand

// encryption.v — encryption-at-rest for the cxstore object graph (#114).
//
// Composes on the #129-E ObjectBackend seam: EncryptingObjectBackend is an
// at-rest-encrypted sibling of DirObjectBackend. Externally it is a normal
// content-addressed ObjectBackend keyed by the PLAINTEXT hash — so the object
// graph, structural sharing and dedup (object_model.md §4/§7) are UNCHANGED; the
// graph never sees ciphertext. At rest, each object's bytes are an envelope:
// a per-object data key (DEK) wrapped by a tenant key (KEK) via the Kms seam,
// plus the object's ciphertext under that DEK. Per-tenant = one key_id (hence
// one EncryptingObjectBackend) per tenant; per-object DEK = envelope encryption.
// Every envelope RECORDS the key-id that wraps its DEK (envelope format v2,
// store.md §9/§9.1), so readers unwrap with the envelope's own key-id and
// envelopes wrapped under different KEKs coexist in one store — the property
// KEK rotation (#287) is built on.
//
// ── crypto construction ─────────────────────────────────────────────
// V's vlib has no AEAD (no GCM / ChaCha20-Poly1305), so authenticated encryption
// is built as the standard AES-256-CBC-then-HMAC-SHA256 (encrypt-then-MAC), from
// audited vlib primitives — NOT a hand-rolled cipher:
//   - HKDF-SHA256 splits each key into independent AES (enc) and HMAC (mac) keys
//     (a key never drives both primitives);
//   - a fresh CSPRNG salt + IV per seal (semantic security; identical plaintext
//     still yields distinct ciphertext — the object key stays the plaintext hash
//     so dedup is unaffected);
//   - the tag authenticates aad‖salt‖iv‖ciphertext and is verified in
//     CONSTANT TIME (hmac.equal) BEFORE any decrypt/unpad — closing the CBC
//     padding-oracle.
// The `aad` for an object seal is its content hash, binding the ciphertext to
// the address it is stored under (a swapped envelope fails authentication).

const aead_key_len = 32 // AES-256 / HMAC-SHA256 key, and the DEK length
const aead_iv_len = 16 // AES block size
const aead_salt_len = 16
const aead_tag_len = 32 // HMAC-SHA256 output
const aead_block = 16 // AES block size

// sha256_sum_fn adapts sha256.sum to the `fn ([]u8) []u8` hmac.new expects.
fn sha256_sum_fn(b []u8) []u8 {
	return sha256.sum(b)
}

// aead_derive_keys HKDF-expands a 32-byte secret + salt into independent
// (enc_key, mac_key), each 32 bytes.
fn aead_derive_keys(secret []u8, salt []u8) !([]u8, []u8) {
	okm := hkdf.key(sha256.new, secret, salt, 'cxstore-aead-v1', aead_key_len * 2)!
	return okm[..aead_key_len], okm[aead_key_len..]
}

fn pkcs7_pad(data []u8) []u8 {
	pad := aead_block - (data.len % aead_block)
	mut out := data.clone()
	for _ in 0 .. pad {
		out << u8(pad)
	}
	return out
}

fn pkcs7_unpad(data []u8) ![]u8 {
	if data.len == 0 || data.len % aead_block != 0 {
		return error('pkcs7: invalid padded length')
	}
	pad := int(data[data.len - 1])
	if pad < 1 || pad > aead_block || pad > data.len {
		return error('pkcs7: invalid padding length')
	}
	mut bad := 0
	for i in 0 .. pad {
		if data[data.len - 1 - i] != u8(pad) {
			bad |= 1
		}
	}
	if bad != 0 {
		return error('pkcs7: corrupt padding')
	}
	return data[..data.len - pad].clone()
}

// aead_seal encrypts plaintext under `key` (32 bytes), authenticating `aad`.
// Output layout: salt(16) ‖ iv(16) ‖ ciphertext ‖ tag(32).
pub fn aead_seal(key []u8, plaintext []u8, aad []u8) ![]u8 {
	if key.len != aead_key_len {
		return error('aead_seal: key must be ${aead_key_len} bytes')
	}
	salt := rand.bytes(aead_salt_len)!
	iv := rand.bytes(aead_iv_len)!
	enc_key, mac_key := aead_derive_keys(key, salt)!
	padded := pkcs7_pad(plaintext)
	block := aes.new_cipher(enc_key)
	mut cbc := cipher.new_cbc(block, iv)
	mut ct := []u8{len: padded.len}
	cbc.encrypt_blocks(mut ct, padded)
	mut maced := []u8{cap: aad.len + salt.len + iv.len + ct.len}
	maced << aad
	maced << salt
	maced << iv
	maced << ct
	tag := hmac.new(mac_key, maced, sha256_sum_fn, sha256.block_size)
	mut out := []u8{cap: salt.len + iv.len + ct.len + tag.len}
	out << salt
	out << iv
	out << ct
	out << tag
	return out
}

// aead_open authenticates then decrypts a sealed blob. The MAC is verified in
// constant time BEFORE decrypt (no padding oracle); a wrong key, wrong aad, or
// any tampered byte fails authentication.
pub fn aead_open(key []u8, sealed []u8, aad []u8) ![]u8 {
	if key.len != aead_key_len {
		return error('aead_open: key must be ${aead_key_len} bytes')
	}
	min_len := aead_salt_len + aead_iv_len + aead_block + aead_tag_len
	if sealed.len < min_len {
		return error('aead_open: sealed blob too short')
	}
	salt := sealed[..aead_salt_len]
	iv := sealed[aead_salt_len..aead_salt_len + aead_iv_len]
	ct := sealed[aead_salt_len + aead_iv_len..sealed.len - aead_tag_len]
	tag := sealed[sealed.len - aead_tag_len..]
	if ct.len == 0 || ct.len % aead_block != 0 {
		return error('aead_open: ciphertext not block-aligned')
	}
	enc_key, mac_key := aead_derive_keys(key, salt)!
	mut maced := []u8{cap: aad.len + salt.len + iv.len + ct.len}
	maced << aad
	maced << salt
	maced << iv
	maced << ct
	expected := hmac.new(mac_key, maced, sha256_sum_fn, sha256.block_size)
	if !hmac.equal(expected, tag) {
		return error('aead_open: authentication failed (wrong key, wrong aad, or tampered)')
	}
	block := aes.new_cipher(enc_key)
	mut cbc := cipher.new_cbc(block, iv)
	mut padded := []u8{len: ct.len}
	cbc.decrypt_blocks(mut padded, ct)
	return pkcs7_unpad(padded)
}

// ── KMS seam ──────────────────────────────────────────────────────────────────

// Kms is the key-management seam (#114). A provider turns a tenant key-id into
// data keys: generate_data_key mints a fresh plaintext DEK + its wrapped form
// (stored alongside the ciphertext); decrypt_data_key unwraps; encrypt_data_key
// re-wraps an EXISTING DEK under a (new) key-id — the KEK-rotation primitive
// (#287; AWS KMS `Encrypt`, Vault transit `rewrap` fill this slot). A production
// provider (AWS KMS, GCP KMS, Vault transit) implements this over the network
// and never exposes the KEK; LocalKms is the reference/dev provider, exactly as
// DirObjectBackend is the reference object backend.
pub interface Kms {
mut:
	generate_data_key(key_id string) !([]u8, []u8) // (plaintext_dek, wrapped_dek)
	decrypt_data_key(key_id string, wrapped []u8) ![]u8
	encrypt_data_key(key_id string, dek []u8) ![]u8 // wrap an existing DEK (rotation)
}

// LocalKms — reference provider. Holds a per-key-id master key (KEK) in memory
// and wraps DEKs with aead_seal under the KEK (aad = key_id). NOT for production
// (a real KMS keeps the KEK in an HSM and never returns it); it proves the seam
// + envelope offline. Construct with explicit master keys for durability across
// process restarts (the operator supplies them from a secret store); the
// zero-arg form mints ephemeral per-process KEKs (tests / throwaway stores).
pub struct LocalKms {
mut:
	keks      map[string][]u8
	ephemeral bool
}

pub fn new_local_kms() &LocalKms {
	return &LocalKms{
		keks:      map[string][]u8{}
		ephemeral: true
	}
}

// new_local_kms_locked constructs a DURABLE provider with no keys yet — every
// key-id must be pinned explicitly via add_master before use (an unknown id is
// an error, never a silently-minted ephemeral key). The base an env-resolving
// policy wrapper (EnvKms) composes on.
pub fn new_local_kms_locked() &LocalKms {
	return &LocalKms{
		keks:      map[string][]u8{}
		ephemeral: false
	}
}

// new_local_kms_with_master pins a durable KEK for key_id (must be 32 bytes), so
// objects sealed in one process can be opened in another.
pub fn new_local_kms_with_master(key_id string, kek []u8) !&LocalKms {
	if kek.len != aead_key_len {
		return error('LocalKms: master key for ${key_id} must be ${aead_key_len} bytes')
	}
	mut m := map[string][]u8{}
	m[key_id] = kek.clone()
	return &LocalKms{
		keks:      m
		ephemeral: false
	}
}

fn (mut k LocalKms) kek_for(key_id string) ![]u8 {
	if key_id in k.keks {
		return k.keks[key_id]
	}
	if !k.ephemeral {
		return error('LocalKms: no master key configured for key_id ${key_id}')
	}
	kek := rand.bytes(aead_key_len)!
	k.keks[key_id] = kek
	return kek
}

pub fn (mut k LocalKms) generate_data_key(key_id string) !([]u8, []u8) {
	kek := k.kek_for(key_id)!
	dek := rand.bytes(aead_key_len)!
	wrapped := aead_seal(kek, dek, key_id.bytes())!
	return dek, wrapped
}

pub fn (mut k LocalKms) decrypt_data_key(key_id string, wrapped []u8) ![]u8 {
	kek := k.kek_for(key_id)!
	return aead_open(kek, wrapped, key_id.bytes())!
}

// encrypt_data_key wraps an EXISTING DEK under key_id (aad = key_id) — the
// rotation primitive: re-wrap a DEK unwrapped from an old envelope under the
// new tenant key without ever re-encrypting the payload it seals.
pub fn (mut k LocalKms) encrypt_data_key(key_id string, dek []u8) ![]u8 {
	if dek.len != aead_key_len {
		return error('LocalKms: DEK must be ${aead_key_len} bytes')
	}
	kek := k.kek_for(key_id)!
	return aead_seal(kek, dek, key_id.bytes())!
}

// has_master reports whether a KEK is pinned for key_id (EnvKms-style callers
// resolve-and-add lazily; fail-closed remains their policy, not LocalKms').
pub fn (k &LocalKms) has_master(key_id string) bool {
	return key_id in k.keks
}

// add_master pins an additional durable KEK (must be 32 bytes) — during a KEK
// rotation the old and the new key-id both resolve through one provider.
pub fn (mut k LocalKms) add_master(key_id string, kek []u8) ! {
	if kek.len != aead_key_len {
		return error('LocalKms: master key for ${key_id} must be ${aead_key_len} bytes')
	}
	k.keks[key_id] = kek.clone()
}

// ── the at-rest envelope (format v2 — records its wrapping key-id) ────────────
//
// Every sealed object is stored as ONE envelope blob:
//   0x02 ‖ u8(key_id_len) ‖ key_id ‖ u16-be(wrapped_dek_len) ‖ wrapped_dek
//        ‖ aead_seal(dek, plaintext, aad=key)
// The leading version byte pins the format; the recorded key_id names the KEK
// that wraps this envelope's DEK, so the reader unwraps with the ENVELOPE's
// key-id (not the handle's) and envelopes under different KEKs coexist in one
// store — the substrate for KEK rotation (#287, store.md §9.1). The key_id is
// not secret; its integrity rides the KMS wrap itself (LocalKms binds it as the
// wrap aad; a cloud KMS binds it as encryption context), so a tampered recorded
// key-id fails the unwrap — never a silent wrong-key decrypt.

// envelope_version — the at-rest envelope format byte. v1 (no version byte, no
// key-id) was never shipped to external users and is NOT dual-read (cutover);
// a v1-era blob fails parse_envelope with a version error, never a misread.
pub const envelope_version = u8(2)

// Envelope — one parsed at-rest envelope.
pub struct Envelope {
pub:
	key_id  string // the key-id whose KEK wraps `wrapped`
	wrapped []u8   // the wrapped (KEK-sealed) per-object DEK
	sealed  []u8   // aead_seal(dek, plaintext, aad=object key)
}

// build_envelope assembles the v2 at-rest envelope blob.
pub fn build_envelope(key_id string, wrapped []u8, sealed []u8) ![]u8 {
	if key_id.len == 0 || key_id.len > 255 {
		return error('envelope: key_id must be 1..255 bytes (got ${key_id.len})')
	}
	if wrapped.len > 0xffff {
		return error('envelope: wrapped DEK too large')
	}
	mut blob := []u8{cap: 2 + key_id.len + 2 + wrapped.len + sealed.len}
	blob << envelope_version
	blob << u8(key_id.len)
	blob << key_id.bytes()
	blob << u8(wrapped.len >> 8)
	blob << u8(wrapped.len & 0xff)
	blob << wrapped
	blob << sealed
	return blob
}

// parse_envelope splits a v2 envelope blob. Fail-closed: a wrong version byte,
// a truncated header, or an empty key-id is a hard error, never a guess.
pub fn parse_envelope(blob []u8) !Envelope {
	if blob.len < 4 {
		return error('envelope: blob too short')
	}
	if blob[0] != envelope_version {
		return error('envelope: unsupported at-rest envelope version ${blob[0]} (expected ${envelope_version})')
	}
	klen := int(blob[1])
	if klen == 0 || blob.len < 2 + klen + 2 {
		return error('envelope: truncated key-id header')
	}
	key_id := blob[2..2 + klen].bytestr()
	woff := 2 + klen
	wlen := int((u32(blob[woff]) << 8) | u32(blob[woff + 1]))
	if blob.len < woff + 2 + wlen {
		return error('envelope: truncated wrapped DEK')
	}
	return Envelope{
		key_id:  key_id
		wrapped: blob[woff + 2..woff + 2 + wlen]
		sealed:  blob[woff + 2 + wlen..]
	}
}

// envelope_seal mints a fresh DEK under key_id and seals payload (aad = key)
// into a v2 envelope — the one write path both encrypting backends share.
pub fn envelope_seal(mut kms Kms, key_id string, key []u8, payload []u8) ![]u8 {
	dek, wrapped := kms.generate_data_key(key_id)!
	sealed := aead_seal(dek, payload, key)!
	return build_envelope(key_id, wrapped, sealed)!
}

// envelope_open authenticates + decrypts an envelope stored under `key`,
// unwrapping the DEK with the key-id RECORDED IN THE ENVELOPE — so a store
// mid-rotation (old- and new-wrapped envelopes mixed) reads under whichever
// key each envelope names. Fail-closed on an unresolvable key-id, a wrong KEK,
// or any tampered byte.
pub fn envelope_open(mut kms Kms, key []u8, blob []u8) ![]u8 {
	env := parse_envelope(blob)!
	dek := kms.decrypt_data_key(env.key_id, env.wrapped)!
	return aead_open(dek, env.sealed, key)!
}

// kms_probe verifies key_id resolves to a WORKING key on the provider — a
// generate + unwrap round-trip, result discarded. Rotation calls this BEFORE
// touching the first envelope, so a typo'd / unresolvable new key-id fails the
// whole operation with zero envelopes mutated.
pub fn kms_probe(mut kms Kms, key_id string) ! {
	dek, wrapped := kms.generate_data_key(key_id)!
	check := kms.decrypt_data_key(key_id, wrapped)!
	if compare_bytes(check, dek) != 0 {
		return error('kms: key ${key_id} failed its wrap/unwrap round-trip')
	}
}

// rewrap_envelope is the KEK-rotation kernel (#287): unwrap the envelope's DEK
// under its RECORDED key-id, re-wrap it under new_key_id, and re-assemble the
// envelope around the UNTOUCHED sealed payload. Returns (blob, old_key_id,
// changed): an envelope already under new_key_id comes back verbatim with
// changed=false (the resumability observable). Fail-closed: an unresolvable
// recorded key-id or a DEK that does not unwrap is an ERROR — a skipped
// envelope would surface as data loss only after the old KEK is destroyed.
// Defense-in-depth: the re-wrapped DEK is round-tripped through the new key
// before the new envelope is returned.
pub fn rewrap_envelope(mut kms Kms, blob []u8, new_key_id string) !([]u8, string, bool) {
	env := parse_envelope(blob)!
	if env.key_id == new_key_id {
		return blob, env.key_id, false
	}
	dek := kms.decrypt_data_key(env.key_id, env.wrapped) or {
		return error('rotation: DEK under key-id `${env.key_id}` failed to unwrap: ${err.msg()}')
	}
	rewrapped := kms.encrypt_data_key(new_key_id, dek)!
	check := kms.decrypt_data_key(new_key_id, rewrapped) or {
		return error('rotation: re-wrapped DEK failed verification under `${new_key_id}`: ${err.msg()}')
	}
	if compare_bytes(check, dek) != 0 {
		return error('rotation: re-wrapped DEK round-trip mismatch under `${new_key_id}`')
	}
	nb := build_envelope(new_key_id, rewrapped, env.sealed)!
	return nb, env.key_id, true
}

// ── EncryptingObjectBackend ─────────────────────────────────────────────────

// EncryptingObjectBackend is the encryption-at-rest object backend. On disk each
// object is one file named by the hex of its PLAINTEXT hash (git-style 2-char
// shard, identical to DirObjectBackend), whose contents are the v2 envelope
// (see above; aad = hash). The external key is the plaintext hash, so dedup and
// the object graph are unchanged; only the at-rest bytes are encrypted.
pub struct EncryptingObjectBackend {
mut:
	dir    string
	key_id string
	kms    Kms
}

pub fn new_encrypting_object_backend(dir string, key_id string, kms Kms) !EncryptingObjectBackend {
	os.mkdir_all(dir)!
	return EncryptingObjectBackend{
		dir:    dir
		key_id: key_id
		kms:    kms
	}
}

fn (b &EncryptingObjectBackend) object_path(hash []u8) string {
	hex := hash.hex()
	return os.join_path(b.dir, hex[..2], hex)
}

pub fn (b &EncryptingObjectBackend) has_object(hash []u8) bool {
	return os.exists(b.object_path(hash))
}

// object_count is the number of distinct objects physically stored (the
// ObjectBackend dedup observable, #129-E). Counts the sharded on-disk files,
// identical to DirObjectBackend — the files are PLAINTEXT-hash-named envelopes,
// so dedup / structural-sharing metrics read the same numbers as on any other
// substrate (encryption is invisible to the object graph).
pub fn (b &EncryptingObjectBackend) object_count() int {
	mut n := 0
	shards := os.ls(b.dir) or { return 0 }
	for sh in shards {
		sub := os.join_path(b.dir, sh)
		if !os.is_dir(sub) {
			continue
		}
		entries := os.ls(sub) or { continue }
		n += entries.len
	}
	return n
}

pub fn (b &EncryptingObjectBackend) get_object(hash []u8) ?[]u8 {
	path := b.object_path(hash)
	blob := os.read_bytes(path) or { return none }
	mut kms := b.kms
	plaintext := envelope_open(mut kms, hash, blob) or { return none }
	// Defense-in-depth: the decrypted bytes MUST hash back to the key.
	if compare_bytes(object_name(plaintext), hash) != 0 {
		return none
	}
	return plaintext
}

pub fn (mut b EncryptingObjectBackend) put_object(payload []u8) ![]u8 {
	hash := object_name(payload)
	path := b.object_path(hash)
	if os.exists(path) {
		return hash // content-address dedup: already stored
	}
	blob := envelope_seal(mut b.kms, b.key_id, hash, payload)!
	os.mkdir_all(os.dir(path))!
	os.write_file_array(path, blob)!
	return hash
}

// ── KEK rotation (#287 / store.md §9.1) ──────────────────────────────────────

// KekRotation — one rotation walk's report: objects = rewrapped +
// already_current always; from_ids lists the distinct OLD key-ids observed.
pub struct KekRotation {
pub mut:
	objects         int
	rewrapped       int
	already_current int
	from_ids        []string
}

// rotate_kek re-wraps every on-disk envelope's DEK under new_key_id, atomically
// per object (temp file + same-directory rename), and switches the backend's
// write key to new_key_id. Payloads (sealed by unchanged DEKs) and file names
// (plaintext hashes) are untouched — no data re-encryption, no address churn.
// Resumable: an envelope already under new_key_id is counted already-current
// and left byte-identical. Fail-closed: any envelope that does not parse or
// whose DEK unwraps under neither key aborts with an error naming the object —
// never a silent skip.
pub fn (mut b EncryptingObjectBackend) rotate_kek(new_key_id string) !KekRotation {
	// The new key must WORK before the first envelope is touched.
	kms_probe(mut b.kms, new_key_id)!
	mut rep := KekRotation{}
	mut seen_from := map[string]bool{}
	shards := os.ls(b.dir) or { []string{} }
	for sh in shards {
		sub := os.join_path(b.dir, sh)
		if !os.is_dir(sub) {
			continue
		}
		entries := os.ls(sub) or { continue }
		for name in entries {
			path := os.join_path(sub, name)
			blob := os.read_bytes(path) or {
				return error('rotation: object ${name} unreadable: ${err.msg()}')
			}
			nb, old_id, changed := rewrap_envelope(mut b.kms, blob, new_key_id) or {
				return error('rotation: object ${name}: ${err.msg()}')
			}
			rep.objects++
			if !changed {
				rep.already_current++
				continue
			}
			if old_id !in seen_from {
				seen_from[old_id] = true
				rep.from_ids << old_id
			}
			// Atomic per object: temp file in the same shard dir + rename, so a
			// crash leaves either the old or the new envelope, whole.
			tmp := path + '.rot.tmp'
			os.write_file_array(tmp, nb) or {
				return error('rotation: object ${name}: temp write failed: ${err.msg()}')
			}
			os.mv(tmp, path) or {
				os.rm(tmp) or {}
				return error('rotation: object ${name}: rename failed: ${err.msg()}')
			}
			rep.rewrapped++
		}
	}
	b.key_id = new_key_id
	return rep
}
