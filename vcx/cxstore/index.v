module cxstore

import cx
import os

// Structural secondary indexes (object_model.md §9, issue #85). Maps structural
// keys — element name, attribute name, and path-summary ("a/b/c" of element
// names from the document root) — to the store keys of documents that contain
// them. A derived accelerator (like the bloom and master index): fully
// rebuildable by walking the packs, persisted as a sidecar only for warm start.
// #87's CXPath planner consults these to prune candidate documents.

pub struct SecondaryIndex {
pub mut:
	by_element map[string][]string // element-name   → store keys
	by_attr    map[string][]string // attribute-name → store keys
	by_path    map[string][]string // "root/.../el"  → store keys
}

fn idx_add(mut m map[string][]string, k string, key string) {
	if k !in m {
		m[k] = []string{}
	}
	if key !in m[k] {
		m[k] << key
	}
}

fn (mut ix SecondaryIndex) index_doc(key string, doc cx.Document) {
	for el in doc.elements {
		ix.walk(key, el, '')
	}
}

fn (mut ix SecondaryIndex) walk(key string, n cx.Node, prefix string) {
	if n is cx.Element {
		path := if prefix == '' { n.name } else { '${prefix}/${n.name}' }
		idx_add(mut ix.by_element, n.name, key)
		idx_add(mut ix.by_path, path, key)
		for a in n.attrs {
			idx_add(mut ix.by_attr, a.name, key)
		}
		for child in n.items {
			ix.walk(key, child, path)
		}
	}
}

pub fn (ix &SecondaryIndex) docs_with_element(name string) []string {
	return ix.by_element[name] or { []string{} }
}

pub fn (ix &SecondaryIndex) docs_with_attr(name string) []string {
	return ix.by_attr[name] or { []string{} }
}

pub fn (ix &SecondaryIndex) docs_with_path(path string) []string {
	return ix.by_path[path] or { []string{} }
}

// ── sidecar persistence (derived; rebuildable if absent) ──────────────

fn idx_dump(kind u8, m map[string][]string, mut lines []string) {
	for k, keys in m {
		for key in keys {
			lines << '${kind:c}\t${k}\t${key}'
		}
	}
}

// save_to writes the index to a sidecar TSV.
pub fn (ix &SecondaryIndex) save_to(path string) ! {
	mut lines := []string{}
	idx_dump(`E`, ix.by_element, mut lines)
	idx_dump(`A`, ix.by_attr, mut lines)
	idx_dump(`P`, ix.by_path, mut lines)
	os.write_file(path, lines.join('\n') + '\n')!
}

// load_index reads a sidecar TSV written by save_to.
pub fn load_index(path string) !SecondaryIndex {
	mut ix := SecondaryIndex{}
	content := os.read_file(path)!
	for line in content.split_into_lines() {
		if line.trim_space() == '' {
			continue
		}
		parts := line.split('\t')
		if parts.len != 3 {
			continue
		}
		match parts[0] {
			'E' { idx_add(mut ix.by_element, parts[1], parts[2]) }
			'A' { idx_add(mut ix.by_attr, parts[1], parts[2]) }
			'P' { idx_add(mut ix.by_path, parts[1], parts[2]) }
			else {}
		}
	}
	return ix
}

// ── Repo integration ──────────────────────────────────────────────────

const repo_index_sidecar = '.cxindex'

// build_index (re)builds the secondary index by walking every stored document.
pub fn (r &Repo) build_index() SecondaryIndex {
	mut ix := SecondaryIndex{}
	s := r.store
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	for key in r.order {
		root := r.roots[key] or { continue }
		doc := load_document_from(g, root) or { continue }
		ix.index_doc(key, doc)
	}
	return ix
}

// index returns the secondary index, loading the sidecar if present else
// rebuilding from the packs and writing the sidecar.
pub fn (r &Repo) index() SecondaryIndex {
	sidecar := os.join_path(r.dir, repo_index_sidecar)
	if os.exists(sidecar) {
		if ix := load_index(sidecar) {
			return ix
		}
	}
	ix := r.build_index()
	ix.save_to(sidecar) or {}
	return ix
}
