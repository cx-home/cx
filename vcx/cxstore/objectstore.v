module cxstore

import os

// objectstore.v — the OBJECT-level storage seam (#76 / #129-E). The subtree
// object graph (object_model.md §4/§7) is content-addressed: every node, leaf and
// seq-node is one immutable object named by the SHA-256 of its bytes. Everything
// that consumes the graph — load_document_from, mark_live, object_graph_stats,
// collect_via — already does so through the abstract `Getter` (a `fn(hash) ?[]u8`),
// so READS are substrate-agnostic by construction. What was pack-only was the
// WRITE/RESOLVE pairing: objects were persisted with write_pack and resolved from
// a Store of local PackReaders.
//
// ObjectBackend closes that: a universal object-per-key surface (put/get/has by
// content hash) any substrate can implement — the local filesystem here
// (DirObjectBackend), an S3 bucket (key = hex(hash)), or a daemon serving one
// object per key. Because getter_of() adapts ANY ObjectBackend into the existing
// `Getter`, the full object-graph machinery (reconstruction, GC mark, dedup
// introspection) runs over a remote substrate UNCHANGED — the graph is no longer
// tied to local packs. The pack engine remains the local-batch optimization; this
// is the additive generalization, not a replacement.

// ObjectBackend — content-addressed object storage. The key of an object IS its
// content hash (object_name); identical payloads collapse to one object (dedup).
pub interface ObjectBackend {
	has_object(hash []u8) bool
	get_object(hash []u8) ?[]u8
	// object_count is the number of distinct objects the backend holds. Universal
	// across substrates (in-memory map size, on-disk object/row/key count), it is
	// the dedup observable the §129-D introspection and the per-substrate dedup
	// conformance gate (spec §6.2) read — a store of structurally-shared docs holds
	// strictly fewer objects than one of disjoint docs.
	object_count() int
mut:
	// put_object stores payload (a no-op if its hash is already present) and
	// returns its content hash. Errors only on a genuine substrate failure
	// (I/O / network), never on a logical duplicate.
	put_object(payload []u8) ![]u8
}

// KeyedObjectBackend — the RAW keyed storage seam (#229). Where ObjectBackend
// derives the key from the payload (content addressing + self-verification), a
// KeyedObjectBackend stores caller-keyed bytes verbatim: put_object_keyed writes
// `blob` under `key`, get_object_raw returns the stored bytes WITHOUT verifying
// they hash to the key. The key↔bytes relation is owned by the wrapping layer —
// the live consumer is EncryptingWrapper (encryption_wrapper.v), which keys AEAD
// envelopes by the PLAINTEXT content hash so the object graph, dedup and
// structural sharing are unchanged while the at-rest bytes are ciphertext.
// has_object/object_count keep their ObjectBackend meanings (keyed presence /
// distinct-key count), so a wrapper can satisfy ObjectBackend by delegation.
pub interface KeyedObjectBackend {
	has_object(hash []u8) bool
	object_count() int
	get_object_raw(key []u8) ?[]u8
mut:
	put_object_keyed(key []u8, blob []u8) !
}

// getter_of adapts any ObjectBackend into the `Getter` the graph readers take, so
// load_document_from / mark_live / object_graph_stats / collect_via all resolve
// objects from that backend with no change to their code.
pub fn getter_of(b ObjectBackend) Getter {
	return Getter(fn [b] (h []u8) ?[]u8 {
		return b.get_object(h)
	})
}

// persist_objects flushes every object of a built graph (an ObjectSink produced
// by store_document) into a backend. The unit that bridges the in-memory build
// buffer to any durable/remote substrate. Idempotent per object (content-address
// dedup), so re-persisting a doc that shares subtrees with an already-stored one
// uploads only the new objects.
pub fn persist_objects(mut b ObjectBackend, sink ObjectSink) ! {
	for _, payload in sink.objects {
		b.put_object(payload)!
	}
}

// ── ObjectSink as an in-memory ObjectBackend ──────────────────────────────────
// (so the in-process graph is just the in-memory backend; uniform with the rest.)

pub fn (s &ObjectSink) has_object(hash []u8) bool {
	return hash.hex() in s.objects
}

pub fn (s &ObjectSink) get_object(hash []u8) ?[]u8 {
	return s.get(hash)
}

pub fn (mut s ObjectSink) put_object(payload []u8) ![]u8 {
	return s.put(payload)
}

pub fn (s &ObjectSink) object_count() int {
	return s.objects.len
}

// ── DirObjectBackend — object-per-key on the local filesystem ─────────────────
//
// The reference object-per-key backend: each object is one file named by its hex
// hash, sharded by the first two hex chars (git-style) to keep directories small.
// Structurally identical to an S3/daemon backend (PUT key=hash, GET key=hash), so
// it proves the seam offline and is the template those remote backends mirror.

pub struct DirObjectBackend {
mut:
	dir string
}

// open_dir_object_backend opens (creating if absent) an object-per-key store.
pub fn open_dir_object_backend(dir string) !DirObjectBackend {
	os.mkdir_all(dir)!
	return DirObjectBackend{
		dir: dir
	}
}

fn (b &DirObjectBackend) obj_path(hash []u8) string {
	hx := hash.hex()
	return os.join_path(b.dir, hx[..2], hx)
}

pub fn (b &DirObjectBackend) has_object(hash []u8) bool {
	return os.exists(b.obj_path(hash))
}

// get_object reads an object and self-verifies it against its content address — a
// corrupted/substituted object on the substrate is rejected (none), never handed
// back as if valid (mirrors PackReader.entry_payload's self-verification).
pub fn (b &DirObjectBackend) get_object(hash []u8) ?[]u8 {
	p := b.obj_path(hash)
	if !os.exists(p) {
		return none
	}
	data := os.read_bytes(p) or { return none }
	if compare_bytes(object_name(data), hash) != 0 {
		return none
	}
	return data
}

pub fn (mut b DirObjectBackend) put_object(payload []u8) ![]u8 {
	h := object_name(payload)
	p := b.obj_path(h)
	if os.exists(p) {
		return h // content-addressed dedup: identical object already stored
	}
	os.mkdir_all(os.dir(p))!
	os.write_file_array(p, payload)!
	return h
}

// object_count is the number of distinct objects physically stored.
pub fn (b &DirObjectBackend) object_count() int {
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
