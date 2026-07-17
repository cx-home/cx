module cxstore

import cx

// cx_diff — structural diff of two documents BY OBJECT HASH (#129 PR-B item 5, the
// showcase op). Because every subtree is content-addressed, two subtrees with the same
// hash are byte-identical and are skipped in O(1) without descent — so diff_docs costs
// O(changed), not O(document size) (object_model §2 "diff/sync by hash-skip"). It is
// read-only (no commit graph / strategy needed) and is the plumbing a future structural
// merge builds on (merge = diff-vs-common-ancestor + strategy).

// DiffEntry is one localized change: a CXPath-ish path (element names, positional index
// for unnamed/leaf items) and a kind.
pub struct DiffEntry {
pub:
	path string
	kind string // 'modified' | 'added' | 'removed'
}

// diff_docs walks two doc-roots in tandem, hash-skipping identical subtrees, and returns
// the changed paths. Equal roots → no entries.
pub fn diff_docs(get Getter, root_a []u8, root_b []u8) []DiffEntry {
	mut out := []DiffEntry{}
	if root_a.hex() == root_b.hex() {
		return out
	}
	pa := get(root_a) or { return out }
	pb := get(root_b) or { return out }
	// doc objects: [obj_doc][ver][prolog_root:32][elements_root:32]; diff the elements.
	if pa.len >= 66 && pa[0] == obj_doc && pb.len >= 66 && pb[0] == obj_doc {
		diff_seq(get, pa[34..66], pb[34..66], '', mut out)
		return out
	}
	// otherwise treat the roots as a single item pair (e.g. a node root directly).
	diff_item(get, root_a, root_b, '', 0, mut out)
	return out
}

// diff_seq compares two seqtree roots by pairing children positionally; identical child
// hashes are skipped. Extra children on one side are added/removed.
fn diff_seq(get Getter, sa []u8, sb []u8, path string, mut out []DiffEntry) {
	if sa.hex() == sb.hex() {
		return
	}
	mut ca := [][]u8{}
	mut cb := [][]u8{}
	collect_via(get, sa, mut ca)
	collect_via(get, sb, mut cb)
	mut i := 0
	for i < ca.len || i < cb.len {
		if i >= cb.len {
			out << DiffEntry{
				path: child_path(get, path, ca[i], i)
				kind: 'removed'
			}
		} else if i >= ca.len {
			out << DiffEntry{
				path: child_path(get, path, cb[i], i)
				kind: 'added'
			}
		} else if ca[i].hex() != cb[i].hex() {
			diff_item(get, ca[i], cb[i], path, i, mut out)
		}
		i++
	}
}

// ChildUnit is one positional child of a node — either a referenced object (hash,
// recurse by hash-skip) or a SMALL leaf carried inline in the node (#129 D6;
// compared by bytes, no object to descend into).
struct ChildUnit {
	is_hash bool
	hash    []u8
	leaf    []u8
}

// is_node reports whether a payload is an element node (either representation).
fn is_node(payload []u8) bool {
	return payload.len >= 2 && (payload[0] == obj_node || payload[0] == obj_node_inline)
}

// node_own returns a node object's own ast_bin (element with children stripped),
// uniformly across the seq-tree (obj_node) and inline (obj_node_inline) forms.
fn node_own(payload []u8) ?[]u8 {
	if payload.len < 2 {
		return none
	}
	if payload[0] == obj_node {
		if payload.len < 34 {
			return none
		}
		return payload[34..]
	}
	if payload[0] == obj_node_inline {
		off := inline_entries_end(payload) or { return none }
		return payload[off..]
	}
	return none
}

// inline_entries_end returns the offset just past an obj_node_inline's child
// entries (i.e. where the own ast_bin begins).
fn inline_entries_end(payload []u8) ?int {
	if payload.len < 4 {
		return none
	}
	count := int(read_u16(payload, 2))
	mut off := 4
	for _ in 0 .. count {
		if off >= payload.len {
			return none
		}
		tag := payload[off]
		off++
		if tag == child_tag_hash {
			off += 32
		} else if tag == child_tag_leaf {
			if off + 2 > payload.len {
				return none
			}
			off += 2 + int(read_u16(payload, off))
		} else {
			return none
		}
	}
	if off > payload.len {
		return none
	}
	return off
}

// node_children returns a node's positional child units. obj_node walks its
// seq-tree (every child is a hash); obj_node_inline parses its inline entries.
fn node_children(get Getter, payload []u8) []ChildUnit {
	mut out := []ChildUnit{}
	if payload.len < 2 {
		return out
	}
	if payload[0] == obj_node {
		if payload.len >= 34 {
			mut hs := [][]u8{}
			collect_via(get, payload[2..34], mut hs)
			for h in hs {
				out << ChildUnit{
					is_hash: true
					hash:    h
				}
			}
		}
		return out
	}
	if payload[0] == obj_node_inline {
		count := int(read_u16(payload, 2))
		mut off := 4
		for _ in 0 .. count {
			if off >= payload.len {
				break
			}
			tag := payload[off]
			off++
			if tag == child_tag_hash {
				if off + 32 > payload.len {
					break
				}
				out << ChildUnit{
					is_hash: true
					hash:    payload[off..off + 32].clone()
				}
				off += 32
			} else if tag == child_tag_leaf {
				if off + 2 > payload.len {
					break
				}
				ln := int(read_u16(payload, off))
				off += 2
				if off + ln > payload.len {
					break
				}
				out << ChildUnit{
					is_hash: false
					leaf:    payload[off..off + ln].clone()
				}
				off += ln
			} else {
				break
			}
		}
	}
	return out
}

// diff_item localizes a change between two child objects already known to differ. For two
// node objects it descends into their children (deeper localization) and flags this node
// `modified` only if its OWN data (name/attrs, children stripped) changed; for a leaf or a
// kind change it flags `modified` at this position.
fn diff_item(get Getter, ha []u8, hb []u8, path string, idx int, mut out []DiffEntry) {
	pa := get(ha) or { return }
	pb := get(hb) or { return }
	p := node_path(get, path, pa, idx)
	if is_node(pa) && is_node(pb) {
		// own-data changed (name/attrs) → this node itself is modified.
		oa := node_own(pa) or { []u8{} }
		ob := node_own(pb) or { []u8{} }
		if oa.hex() != ob.hex() {
			out << DiffEntry{
				path: p
				kind: 'modified'
			}
		}
		// descend into children (uniform over seq-tree + inline forms).
		diff_children(get, node_children(get, pa), node_children(get, pb), p, mut out)
		return
	}
	out << DiffEntry{
		path: p
		kind: 'modified'
	}
}

// diff_children pairs two child-unit lists positionally, hash-skipping identical
// referenced subtrees and comparing inline leaves by bytes.
fn diff_children(get Getter, ca []ChildUnit, cb []ChildUnit, path string, mut out []DiffEntry) {
	mut i := 0
	for i < ca.len || i < cb.len {
		if i >= cb.len {
			out << DiffEntry{
				path: child_unit_path(get, path, ca[i], i)
				kind: 'removed'
			}
		} else if i >= ca.len {
			out << DiffEntry{
				path: child_unit_path(get, path, cb[i], i)
				kind: 'added'
			}
		} else {
			a := ca[i]
			b := cb[i]
			if a.is_hash && b.is_hash {
				if a.hash.hex() != b.hash.hex() {
					diff_item(get, a.hash, b.hash, path, i, mut out)
				}
			} else if !a.is_hash && !b.is_hash {
				if a.leaf.hex() != b.leaf.hex() {
					out << DiffEntry{
						path: '${path}/[${i}]'
						kind: 'modified'
					}
				}
			} else {
				// one inline leaf, one referenced object at the same position → changed.
				out << DiffEntry{
					path: '${path}/[${i}]'
					kind: 'modified'
				}
			}
		}
		i++
	}
}

// child_unit_path builds the path for a child unit: a referenced node resolves to
// its element name; an inline leaf (or unnamed/leaf node) is positional.
fn child_unit_path(get Getter, parent string, u ChildUnit, idx int) string {
	if u.is_hash {
		return child_path(get, parent, u.hash, idx)
	}
	return '${parent}/[${idx}]'
}

// node_name returns a node object's element name (empty for a leaf / non-element),
// uniformly across the seq-tree and inline node forms.
fn node_name(payload []u8) string {
	own := node_own(payload) or { return '' }
	n := cx.node_from_bin(own) or { return '' }
	if n is cx.Element {
		return n.name
	}
	return ''
}

// node_path / child_path build the path segment for an object: its element name when it is
// a named node, else a positional `[idx]`.
fn node_path(get Getter, parent string, payload []u8, idx int) string {
	name := node_name(payload)
	if name != '' {
		return '${parent}/${name}'
	}
	return '${parent}/[${idx}]'
}

fn child_path(get Getter, parent string, h []u8, idx int) string {
	payload := get(h) or { return '${parent}/[${idx}]' }
	return node_path(get, parent, payload, idx)
}
