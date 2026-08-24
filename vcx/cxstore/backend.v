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

// The former `Transactional` trait (begin/commit/rollback) is REMOVED
// (stream 7 L127, #714): no backend ever implemented it and nothing
// consumed it — a dead seam advertising transactionality the spec corpus
// never granted. Single-backend transactionality re-enters, if ever, as a
// declarable consistency token (consistency_vocabulary.md) when a spec'd
// backend actually advertises it.

// Capability negotiation helpers (degrade-with-visibility, never silently):
// callers test these to discover what a backend supports.
pub fn is_indexed(b StorageBackend) bool {
	return b is Indexed
}

pub fn is_queryable(b StorageBackend) bool {
	return b is Queryable
}

