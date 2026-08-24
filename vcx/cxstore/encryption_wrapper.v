module cxstore

// encryption_wrapper.v — the GENERIC encryption-at-rest wrapper (#229).
//
// EncryptingWrapper turns any KeyedObjectBackend (raw keyed bytes: pack rows,
// sqlite rows, s3 keys) into a normal content-addressed ObjectBackend whose
// at-rest bytes are AEAD envelopes. It is the substrate-generic sibling of the
// object-per-key EncryptingObjectBackend (encryption.v, #114) — same envelope
// layout, same crypto (aead_seal/aead_open), same KMS seam — factored over the
// KeyedObjectBackend seam so the pack/sqlite/s3 substrates can seal at rest
// without hosting any crypto themselves.
//
// Externally the wrapper is keyed by the PLAINTEXT content hash, so the object
// graph, structural sharing and dedup are UNCHANGED (the graph never sees
// ciphertext). At rest each object is the v2 envelope (encryption.v):
//   0x02 ‖ u8(key_id_len) ‖ key_id ‖ u16-be(wrapped_dek_len) ‖ wrapped_dek
//        ‖ aead_seal(dek, plaintext, aad=hash)
// — a per-object data key (DEK) wrapped by the tenant key (KEK) via the Kms
// seam, with the wrapping key-id RECORDED so reads unwrap with the envelope's
// own key (KEK rotation, #287). The `aad` is the plaintext hash, binding the
// envelope to the address it is stored under (a swapped envelope fails
// authentication), and open_envelope re-verifies the decrypted bytes hash back
// to the key (defense-in-depth, mirroring EncryptingObjectBackend.get_object).

@[heap]
pub struct EncryptingWrapper {
mut:
	inner  KeyedObjectBackend
	key_id string
	kms    Kms
	// seal_overrides — object-key-hex → wrapping key-id (stream 20): a
	// subject-bearing payload's whole-doc object seals under its SEK instead
	// of the tenant write key. Consulted by seal_envelope (so both the stage
	// path and the compaction fresh-seal fallback honor it); content
	// addressing makes a stale entry harmless (an already-durable object
	// dedups before sealing).
	seal_overrides map[string]string
}

// set_seal_override pins an explicit wrapping key-id for one object key
// (stream 20: the subject path). See seal_overrides.
pub fn (mut b EncryptingWrapper) set_seal_override(key_hex string, key_id string) {
	b.seal_overrides[key_hex] = key_id
}

pub fn new_encrypting_wrapper(inner KeyedObjectBackend, key_id string, kms Kms) &EncryptingWrapper {
	return &EncryptingWrapper{
		inner:  inner
		key_id: key_id
		kms:    kms
	}
}

// seal_envelope builds the at-rest envelope for `payload` keyed by `key` (its
// plaintext content hash): a fresh DEK from the KMS, wrapped alongside the
// AEAD-sealed bytes (aad = key). Exposed so a substrate's compaction path can
// re-seal a payload whose envelope is not (yet) durable.
pub fn (mut b EncryptingWrapper) seal_envelope(key []u8, payload []u8) ![]u8 {
	// stream 20: a registered subject override wins over the tenant write key.
	if kid := b.seal_overrides[key.hex()] {
		return envelope_seal(mut b.kms, kid, key, payload)!
	}
	return envelope_seal(mut b.kms, b.key_id, key, payload)!
}

// open_envelope authenticates + decrypts an at-rest envelope stored under `key`
// and verifies the plaintext hashes back to it. The DEK unwraps under the
// key-id RECORDED IN THE ENVELOPE (not the wrapper's write key), so a store
// mid-rotation reads under whichever key each envelope names. Errors (never a
// silent wrong payload) on an unresolvable key-id, a wrong KEK, a
// tampered/corrupt envelope, or a key mismatch — exposed so a substrate's
// eager load path can decrypt-and-verify in bulk.
pub fn (b &EncryptingWrapper) open_envelope(key []u8, blob []u8) ![]u8 {
	mut kms := b.kms
	plaintext := envelope_open(mut kms, key, blob)!
	// Defense-in-depth: the decrypted bytes MUST hash back to the key.
	if compare_bytes(object_name(plaintext), key) != 0 {
		return error('encrypting wrapper: decrypted object does not hash to its key')
	}
	return plaintext
}

// ── stream 20 (#692): the SEK path — seal under an explicit key-id ───────────

// seal_envelope_under seals payload under an EXPLICIT key-id instead of the
// wrapper's tenant write key — the subject path: a subject-bearing payload
// seals under its SEK (`sek/…`), so destroying that one key shreds exactly
// that subject's payloads. Reads stay key-blind (the envelope records its
// wrapping key-id, same as mid-rotation coexistence).
pub fn (mut b EncryptingWrapper) seal_envelope_under(key_id string, key []u8, payload []u8) ![]u8 {
	return envelope_seal(mut b.kms, key_id, key, payload)!
}

// put_object_under is put_object sealing under an explicit key-id (see
// seal_envelope_under). Content-address dedup is unchanged: the object key is
// the plaintext hash either way.
pub fn (mut b EncryptingWrapper) put_object_under(key_id string, payload []u8) ![]u8 {
	hash := object_name(payload)
	if b.inner.has_object(hash) {
		return hash // content-address dedup: already stored
	}
	blob := b.seal_envelope_under(key_id, hash, payload)!
	b.inner.put_object_keyed(hash, blob)!
	return hash
}

// create_key / destroy_key / key_available expose the provider's named-key
// surface through the wrapper (SEK mint at first subject write; the
// erase-subject command's destroy; the unavailable-vs-tampered probe).
pub fn (mut b EncryptingWrapper) create_key(key_id string) ! {
	b.kms.create_key(key_id)!
}

pub fn (mut b EncryptingWrapper) destroy_key(key_id string) ! {
	b.kms.destroy_key(key_id)!
}

pub fn (mut b EncryptingWrapper) key_available(key_id string) bool {
	return b.kms.has_key(key_id)
}

// rewrap_envelope re-wraps one envelope's DEK under new_key_id through the
// wrapper's KMS (the #287 rotation kernel bound to this wrapper's provider);
// returns (new_blob, old_key_id, changed). See cxstore.rewrap_envelope.
pub fn (mut b EncryptingWrapper) rewrap_envelope(blob []u8, new_key_id string) !([]u8, string, bool) {
	return rewrap_envelope(mut b.kms, blob, new_key_id)!
}

// probe_key verifies key_id resolves to a working key on the wrapper's KMS
// (see kms_probe) — rotation's touch-nothing-until-the-new-key-works gate.
pub fn (mut b EncryptingWrapper) probe_key(key_id string) ! {
	kms_probe(mut b.kms, key_id)!
}

// set_key_id switches the wrapper's WRITE key: objects sealed after a completed
// KEK rotation wrap under the new tenant key. Reads are unaffected (they follow
// each envelope's recorded key-id).
pub fn (mut b EncryptingWrapper) set_key_id(new_key_id string) {
	b.key_id = new_key_id
}

// kms_instance exposes the wrapper's KMS (the interface value holds the
// provider by reference) — the platform layer reaches it for provider-level
// operations the object walk doesn't cover (stream 20: subject-key custody
// rotation).
pub fn (b &EncryptingWrapper) kms_instance() Kms {
	return b.kms
}

// inner_backend exposes the wrapped substrate backend. For substrate-specific
// side surfaces that live next to the object rows — e.g. the sqlite refs
// manifest rides the same connection the objects do, so the substrate layer
// reaches through the wrapper to it. The object DATA path never bypasses the
// wrapper.
pub fn (b &EncryptingWrapper) inner_backend() KeyedObjectBackend {
	return b.inner
}

// ── ObjectBackend surface (what the object graph sees: plaintext, content-keyed) ─

pub fn (b &EncryptingWrapper) has_object(hash []u8) bool {
	return b.inner.has_object(hash)
}

pub fn (b &EncryptingWrapper) object_count() int {
	return b.inner.object_count()
}

pub fn (b &EncryptingWrapper) get_object(hash []u8) ?[]u8 {
	raw := b.inner.get_object_raw(hash) or { return none }
	return b.open_envelope(hash, raw) or { none }
}

// get_object_raw exposes the at-rest envelope blob for `hash` without opening
// it (stream 20: the erase walk reads recorded wrapping key-ids; see
// EncryptingObjectBackend.get_object_raw).
pub fn (b &EncryptingWrapper) get_object_raw(hash []u8) ?[]u8 {
	return b.inner.get_object_raw(hash) or { return none }
}

// seal_override_for reports the registered explicit wrapping key-id for one
// object key, if any (stream 20: staged subject docs have no envelope yet).
pub fn (b &EncryptingWrapper) seal_override_for(key_hex string) ?string {
	return b.seal_overrides[key_hex] or { return none }
}

pub fn (mut b EncryptingWrapper) put_object(payload []u8) ![]u8 {
	hash := object_name(payload)
	if b.inner.has_object(hash) {
		return hash // content-address dedup: already stored
	}
	blob := b.seal_envelope(hash, payload)!
	b.inner.put_object_keyed(hash, blob)!
	return hash
}
