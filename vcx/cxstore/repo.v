module cxstore

import cx
import os
import encoding.hex

// Repo — a multi-document content-addressed store: canonical CX text in, text
// out, keyed by store hash (cx_text_hash). Each document is content-addressed
// into the engine (subtree dedup applies across documents), persisted as a pack
// named by its document-root hash, with a small manifest mapping store-hash →
// root. Reopening reloads losslessly. This is the backend the [$store] cxpack://
// scheme delegates to (wiring in stdlib_store.v is the next step).

pub struct Repo {
mut:
	dir   string
	store Store
	roots map[string][]u8 // store-hash (hex) → document-root hash
	order []string         // insertion order of store-hashes
}

fn (r &Repo) manifest_path() string {
	return os.join_path(r.dir, 'manifest.tsv')
}

// open_repo opens (creating if absent) a Repo rooted at `dir`.
pub fn open_repo(dir string) !Repo {
	os.mkdir_all(dir)!
	mut repo := Repo{
		dir: dir
	}
	mut pack_paths := []string{}
	mp := os.join_path(dir, 'manifest.tsv')
	if os.exists(mp) {
		content := os.read_file(mp)!
		for line in content.split_into_lines() {
			if line.trim_space() == '' {
				continue
			}
			parts := line.split('\t')
			if parts.len != 2 {
				continue
			}
			repo.roots[parts[0]] = hex.decode(parts[1])!
			repo.order << parts[0]
			pp := os.join_path(dir, '${parts[1]}.cxpack')
			if pp !in pack_paths {
				pack_paths << pp
			}
		}
	}
	repo.store = open_store(pack_paths)!
	return repo
}

// put_text content-addresses a CX document and returns its store hash. Identical
// documents (by canonical text) dedup to the same key with no new storage.
pub fn (mut r Repo) put_text(text string) !string {
	canon := cx.cx_text_canonical(text)!
	key := cx.cx_text_hash(text)!
	if key in r.roots {
		return key // already stored (logical dedup)
	}
	doc := cx.parse(canon)!
	mut sink := ObjectSink{}
	root := store_document(mut sink, doc, default_fanout)
	pack_path := os.join_path(r.dir, '${root.hex()}.cxpack')
	if !os.exists(pack_path) {
		mut payloads := [][]u8{cap: sink.objects.len}
		for _, v in sink.objects {
			payloads << v
		}
		write_pack(pack_path, payloads)!
	}
	r.store.add_pack(pack_path)!
	r.roots[key] = root
	r.order << key
	r.persist_manifest()!
	return key
}

// get_text reconstructs a stored document as canonical CX text, or none.
pub fn (r &Repo) get_text(key string) ?string {
	root := r.roots[key] or { return none }
	s := r.store
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	doc := load_document_from(g, root) or { return none }
	return cx.emit_cx(doc)
}

// get_doc reconstructs a stored document as a cx.Document, or none.
pub fn (r &Repo) get_doc(key string) ?cx.Document {
	root := r.roots[key] or { return none }
	s := r.store
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	return load_document_from(g, root) or { return none }
}

// list returns the store hashes in insertion order.
pub fn (r &Repo) list() []string {
	return r.order.clone()
}

// ── StorageBackend trait surface (#76) — aliases over the Repo API ─────

// put stores a document and returns its content key (StorageBackend).
pub fn (mut r Repo) put(text string) !string {
	return r.put_text(text)!
}

// get returns a stored document by key, or none (StorageBackend).
pub fn (r &Repo) get(key string) ?string {
	return r.get_text(key)
}

// has reports whether a key is present (StorageBackend).
pub fn (r &Repo) has(key string) bool {
	r.get_text(key) or { return false }
	return true
}

// len is the number of distinct documents.
pub fn (r &Repo) len() int {
	return r.order.len
}

fn (r &Repo) persist_manifest() ! {
	mut sb := []string{}
	for k in r.order {
		root := r.roots[k] or { continue }
		sb << '${k}\t${root.hex()}'
	}
	os.write_file(r.manifest_path(), sb.join('\n') + '\n')!
}
