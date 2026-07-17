module cxsqlite

import cx
import db.sqlite

// SqliteBackend — the first external cxstore engine (#77), per the #75
// architecture: an external URL-dispatched backend that stores CX documents as
// opaque blobs keyed by the Tier-1 content hash (the canonical-text hash). It
// satisfies cxstore.StorageBackend (KV put/get/has/list); it deliberately does
// NOT push CXPath/structural queries down into SQLite (the KV-works /
// no-CXPath-pushdown boundary). It lives in its own module so the core binary
// never links libsqlite3 unless this backend is imported (feature-gating by
// module boundary).
//
// Schema: objects(hash TEXT PRIMARY KEY, body TEXT, seq INTEGER) — `seq`
// preserves insertion order for list(); the PRIMARY KEY gives content dedup.

pub struct SqliteBackend {
mut:
	db sqlite.DB
}

// open connects to (creating if absent) a sqlite-backed store at `path`
// (':memory:' for an in-process DB).
pub fn open(path string) !SqliteBackend {
	mut d := sqlite.connect(path)!
	d.exec_none('CREATE TABLE IF NOT EXISTS objects (hash TEXT PRIMARY KEY, body TEXT NOT NULL, seq INTEGER)')
	return SqliteBackend{
		db: d
	}
}

pub fn (mut b SqliteBackend) close() {
	b.db.close() or {}
}

// put stores a document as its canonical text keyed by Tier-1 hash; identical
// content dedups (INSERT OR IGNORE). Returns the content key.
pub fn (mut b SqliteBackend) put(text string) !string {
	canon := cx.cx_text_canonical(text)!
	key := cx.cx_text_hash(text)!
	b.db.exec_param2('INSERT OR IGNORE INTO objects (hash, body, seq) VALUES (?, ?, (SELECT COALESCE(MAX(seq), 0) + 1 FROM objects))',
		key, canon)!
	return key
}

pub fn (b &SqliteBackend) get(key string) ?string {
	rows := b.db.exec_param('SELECT body FROM objects WHERE hash = ?', key) or { return none }
	if rows.len == 0 {
		return none
	}
	return rows[0].val(0)
}

pub fn (b &SqliteBackend) has(key string) bool {
	rows := b.db.exec_param('SELECT 1 FROM objects WHERE hash = ?', key) or { return false }
	return rows.len > 0
}

pub fn (b &SqliteBackend) list() []string {
	rows := b.db.exec('SELECT hash FROM objects ORDER BY seq') or { return []string{} }
	mut out := []string{cap: rows.len}
	for r in rows {
		out << r.val(0)
	}
	return out
}

// ── Transactional capability (cxstore.Transactional) ──────────────────

pub fn (mut b SqliteBackend) begin() ! {
	b.db.begin(sqlite.Sqlite3TransactionParam{})! // DEFERRED
}

pub fn (mut b SqliteBackend) commit() ! {
	b.db.commit()!
}

pub fn (mut b SqliteBackend) rollback() ! {
	b.db.rollback()!
}
