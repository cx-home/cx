module cxstore

// StorageBackend trait + capability interfaces (issue #76; object_model.md
// Appendix B). This is the forward-looking surface #75's architecture builds
// on: a universal content-addressed core (StorageBackend) plus declared
// capability traits a backend may additionally implement. The native engine
// (Repo) implements all of them. This is ADDITIVE — the legacy [$store]
// mem/file dispatch is unchanged; migrating it onto the trait is a follow-up.

// StorageBackend — the universal core: content-addressed put/get/has/list.
// Keys are store hashes (a put returns the key; identical content dedups).
pub interface StorageBackend {
	get(key string) ?string
	has(key string) bool
	list() []string
mut:
	put(text string) !string
}

// Indexed — a backend that can build structural secondary indexes (#85),
// mapping element/attribute/path keys to documents.
pub interface Indexed {
	build_index() SecondaryIndex
}

// Queryable — a backend that evaluates index-aware CXPath name-step queries
// (#87), pruning candidate documents via a secondary index.
pub interface Queryable {
	query(ix &SecondaryIndex, cxpath string) []string
}

// Transactional — a backend with a real, per-backend transaction (begin/
// commit/rollback). Cross-backend atomicity is saga/compensating, not 2PC
// (architecture.md §3); this trait is the single-backend ACID building block.
pub interface Transactional {
mut:
	begin() !
	commit() !
	rollback() !
}

// Capability negotiation helpers (degrade-with-visibility, never silently):
// callers test these to discover what a backend supports.
pub fn is_indexed(b StorageBackend) bool {
	return b is Indexed
}

pub fn is_queryable(b StorageBackend) bool {
	return b is Queryable
}

pub fn is_transactional(b StorageBackend) bool {
	return b is Transactional
}
