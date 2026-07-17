module cxstore

import cx

// cx_adapter — content-addresses a parsed CX document into the object graph
// (object_model.md §4 + §7). Each element becomes a Node object whose own data
// (name/attrs/meta, children stripped) is ast_bin-encoded, plus a seqtree spine
// over its content-addressed children. Scalars become Leaf objects. Because
// children are addressed through the seqtree and excluded from the parent's own
// bytes, editing one deep element rehashes only the path from that node to the
// document root — and every untouched subtree dedups across versions.

pub const obj_doc = u8(4)

// store_document content-addresses an entire parsed CX document and returns the
// document-root hash. All objects are written into `sink`. The doc object is
// [obj_doc][ver][prolog_seq_root:32][elements_seq_root:32].
pub fn store_document(mut sink ObjectSink, doc cx.Document, fanout int) []u8 {
	mut prolog_h := [][]u8{}
	for n in doc.prolog {
		prolog_h << store_item(mut sink, n, fanout)
	}
	prolog_root := build_seqtree(mut sink, prolog_h, fanout)
	mut elem_h := [][]u8{}
	for el in doc.elements {
		elem_h << store_item(mut sink, el, fanout)
	}
	elem_root := build_seqtree(mut sink, elem_h, fanout)
	mut payload := [obj_doc, u8(1)]
	payload << prolog_root
	payload << elem_root
	return sink.put(payload)
}

fn store_item(mut sink ObjectSink, n cx.Node, fanout int) []u8 {
	if n is cx.Element {
		return store_element(mut sink, n as cx.Element, fanout)
	}
	// leaf object: [obj_leaf][ver][framed ast_bin of the node]
	mut payload := [obj_leaf, u8(1)]
	payload << cx.emit_node_bin(n)
	return sink.put(payload)
}

fn store_element(mut sink ObjectSink, e cx.Element, fanout int) []u8 {
	// node object own-data = the element with its children stripped, so a child
	// edit never perturbs the parent's own bytes (only its child refs).
	shallow := cx.Element{
		...e
		items: []cx.Node{}
	}
	own := cx.emit_node_bin(shallow)
	if e.items.len <= fanout {
		// #129 D6: inline the child sequence — no seq-tree spine object, and small
		// leaves carried inline rather than as their own objects.
		mut body := []u8{}
		put_u16(mut body, u16(e.items.len))
		for item in e.items {
			if item is cx.Element {
				h := store_element(mut sink, item as cx.Element, fanout)
				body << child_tag_hash
				body << h[..32]
			} else {
				bin := cx.emit_node_bin(item)
				if bin.len <= leaf_inline_max {
					body << child_tag_leaf
					put_u16(mut body, u16(bin.len))
					body << bin
				} else {
					// large leaf stays a shared, dedup-bearing object
					mut lp := [obj_leaf, u8(1)]
					lp << bin
					h := sink.put(lp)
					body << child_tag_hash
					body << h[..32]
				}
			}
		}
		mut payload := [obj_node_inline, u8(1)]
		payload << body
		payload << own
		return sink.put(payload)
	}
	// large child list: keep the seq-tree (its O(log N) sharing earns its keep).
	mut child_hashes := [][]u8{}
	for item in e.items {
		child_hashes << store_item(mut sink, item, fanout)
	}
	seq_root := build_seqtree(mut sink, child_hashes, fanout)
	mut payload := [obj_node, u8(1)]
	payload << seq_root
	payload << own
	return sink.put(payload)
}

// ── load (object graph → cx.Document) ─────────────────────────────────

// load_document_from reconstructs a cx.Document from a doc-root hash using the
// given object getter (sink, pack, or store). Inverse of store_document.
pub fn load_document_from(get Getter, doc_root []u8) !cx.Document {
	payload := get(doc_root) or { return error('cxstore: doc root not found') }
	if payload.len < 66 || payload[0] != obj_doc {
		return error('cxstore: not a doc object')
	}
	prolog := load_seq(get, payload[2..34])!
	elements := load_seq(get, payload[34..66])!
	return cx.Document{
		prolog:   prolog
		elements: elements
	}
}

fn load_seq(get Getter, seq_root []u8) ![]cx.Node {
	mut child_hashes := [][]u8{}
	collect_via(get, seq_root, mut child_hashes)
	mut out := []cx.Node{cap: child_hashes.len}
	for h in child_hashes {
		out << load_item(get, h)!
	}
	return out
}

fn load_item(get Getter, h []u8) !cx.Node {
	payload := get(h) or { return error('cxstore: object ${h.hex()} not found') }
	if payload.len < 2 {
		return error('cxstore: truncated object')
	}
	match payload[0] {
		obj_leaf {
			return cx.node_from_bin(payload[2..])!
		}
		obj_node {
			if payload.len < 34 {
				return error('cxstore: truncated node object')
			}
			seq_root := payload[2..34]
			own := cx.node_from_bin(payload[34..])!
			if own is cx.Element {
				mut el := own as cx.Element
				el.items = load_seq(get, seq_root)!
				return cx.Node(el)
			}
			return error('cxstore: node object own-data is not an Element')
		}
		obj_node_inline {
			// [obj_node_inline][ver][count:u16][entries…][own ast_bin]
			if payload.len < 4 {
				return error('cxstore: truncated inline node object')
			}
			count := int(read_u16(payload, 2))
			mut off := 4
			mut items := []cx.Node{cap: count}
			for _ in 0 .. count {
				if off >= payload.len {
					return error('cxstore: truncated inline node entries')
				}
				tag := payload[off]
				off++
				match tag {
					child_tag_hash {
						if off + 32 > payload.len {
							return error('cxstore: truncated inline child hash')
						}
						ch := payload[off..off + 32]
						off += 32
						items << load_item(get, ch)!
					}
					child_tag_leaf {
						if off + 2 > payload.len {
							return error('cxstore: truncated inline leaf length')
						}
						ln := int(read_u16(payload, off))
						off += 2
						if off + ln > payload.len {
							return error('cxstore: truncated inline leaf body')
						}
						items << cx.node_from_bin(payload[off..off + ln])!
						off += ln
					}
					else {
						return error('cxstore: unknown inline child tag ${tag}')
					}
				}
			}
			own := cx.node_from_bin(payload[off..])!
			if own is cx.Element {
				mut el := own as cx.Element
				el.items = items
				return cx.Node(el)
			}
			return error('cxstore: inline node object own-data is not an Element')
		}
		else {
			return error('cxstore: unexpected object kind ${payload[0]}')
		}
	}
}

// ── Store high-level document API ─────────────────────────────────────

// commit_document content-addresses a document into a fresh pack, registers the
// pack in the store, and advances ref_name to the new document root.
pub fn (mut s Store) commit_document(doc cx.Document, ref_name string, pack_path string, reflog_path string) ! {
	mut sink := ObjectSink{}
	root := store_document(mut sink, doc, default_fanout)
	mut payloads := [][]u8{cap: sink.objects.len}
	for _, v in sink.objects {
		payloads << v
	}
	write_pack(pack_path, payloads)!
	r := open_pack(pack_path)!
	idx := s.packs.len
	s.packs << r
	for hh in r.hashes() {
		hk := hh.hex()
		if hk !in s.location {
			s.location[hk] = idx
		}
	}
	rl := open_reflog(reflog_path)
	rl.commit(ref_name, root, 'cxstore'.bytes())!
}

// load_document resolves ref_name to its current root and reconstructs the doc.
pub fn (s &Store) load_document(ref_name string, reflog_path string) !cx.Document {
	rl := open_reflog(reflog_path)
	root := rl.current_root(ref_name) or { return error('cxstore: ref ${ref_name} not found') }
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	return load_document_from(g, root)!
}
