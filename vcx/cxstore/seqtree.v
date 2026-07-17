module cxstore

// CXStore sequence spine — bounded-fanout B+tree content-addressing for a
// node's child sequence (object_model.md §3 + Appendix A.2). This is the
// mechanism that removes the "wide-table cliff": a Node with N children does
// not reference all N child hashes directly; the children are addressed
// through a fixed-fanout B+tree so that
//   • editing one child rehashes only the root→leaf path  → O(log_B N)
//   • two versions sharing unchanged children share every untouched
//     seq-node and leaf  → fine-grained structural dedup.
//
// Object payload layout (A.1 [kind][version][body]):
//   seq-node: [obj_seqnode][ver=1][level:u8][count:u16][child_hash:32 × count]
//   level 0 = leaf (children are element refs); level > 0 = internal
//   (children are seq-node refs). count ≤ B.
//
// This layer is deliberately cx-agnostic: it addresses a sequence of already
// content-addressed object hashes. The cx.Node → object-graph adapter
// (emit_node_bin) layers on top.

// object kinds — the first payload byte (A.1). Distinct from pack entry_kind.
pub const obj_leaf = u8(0)
pub const obj_blob = u8(1)
pub const obj_node = u8(2)
pub const obj_seqnode = u8(3)
// obj_node_inline (#129 D6) — an element whose child sequence is stored INLINE
// rather than through a seq-tree spine, used when the element has ≤ fanout
// children (the overwhelming majority of elements). Each child entry is tagged:
//   [0x00][child_hash:32]            — a child stored as its own object
//   [0x01][len:u16][leaf ast_bin]    — a SMALL leaf inlined here (≤ leaf_inline_max)
// Layout: [obj_node_inline][ver][child_count:u16][entries…][own ast_bin].
// This elides (a) the seq-node object every small element used to allocate and
// (b) the separate leaf object for every tiny scalar — the dominant per-scalar
// object-count + byte overhead (D6 bench: ~−65% objects / ~−40% bytes on
// fine-grained data). Large child lists (> fanout) keep the seq-tree (obj_node),
// where its O(log N) structural sharing earns its keep. Reads stay back-compat:
// the reader dispatches on the kind byte, so packs written before D6 still open.
pub const obj_node_inline = u8(5)

// Inline a leaf child iff its ast_bin payload is ≤ this many bytes. The break-even
// is the content-address size: a scalar smaller than its own 32-byte hash (plus a
// ~44-byte footer index entry) costs MORE to reference than to inline, and below
// the hash size deduplicating it never recovers the per-occurrence reference cost
// (D6 analysis). 48 captures typical scalars (ints, dates, short strings) while
// leaving larger / repeated values as shared, dedup-bearing objects.
pub const leaf_inline_max = 48

// child entry tags for obj_node_inline.
pub const child_tag_hash = u8(0)
pub const child_tag_leaf = u8(1)

pub const seqnode_header = 5 // [kind][ver][level][count:u16]

// default fanout. The #129 D6 bench confirmed 32 is at the knee: f32→f128 saves
// <0.2% objects / <0.1% bytes (pure diminishing returns) while preserving
// excellent edit locality (a one-field change touches ~7 objects). It also
// doubles as the seqtree-elision threshold — an element with ≤ fanout children
// is stored inline (obj_node_inline) rather than via a one-node seq spine.
pub const default_fanout = 32

// ObjectSink accumulates content-addressed objects during a build. Identical
// payloads collapse to one entry (logical dedup, §5).
pub struct ObjectSink {
pub mut:
	objects map[string][]u8 // hex(hash) → payload
}

// put stores a payload and returns its content hash.
pub fn (mut s ObjectSink) put(payload []u8) []u8 {
	h := object_name(payload)
	s.objects[h.hex()] = payload.clone()
	return h
}

pub fn (s &ObjectSink) get(hash []u8) ?[]u8 {
	return s.objects[hash.hex()] or { return none }
}

fn encode_seqnode(level u8, children [][]u8) []u8 {
	mut b := []u8{cap: seqnode_header + children.len * 32}
	b << obj_seqnode
	b << u8(1) // version
	b << level
	put_u16(mut b, u16(children.len))
	for c in children {
		b << c[..32]
	}
	return b
}

// chunk_level groups child hashes into seq-nodes of ≤ b and returns the
// resulting node hashes (the next level up).
fn chunk_level(mut sink ObjectSink, child_hashes [][]u8, b int, level u8) [][]u8 {
	mut out := [][]u8{}
	mut i := 0
	for i < child_hashes.len {
		end := if i + b < child_hashes.len { i + b } else { child_hashes.len }
		out << sink.put(encode_seqnode(level, child_hashes[i..end]))
		i = end
	}
	return out
}

// build_seqtree builds a fixed-fanout B+tree over elem_hashes (the ordered
// child element refs) and returns the root seq-node hash. The element objects
// themselves are assumed already stored in the sink.
pub fn build_seqtree(mut sink ObjectSink, elem_hashes [][]u8, fanout int) []u8 {
	b := if fanout < 2 { 2 } else { fanout }
	if elem_hashes.len == 0 {
		return sink.put(encode_seqnode(0, [][]u8{})) // canonical empty leaf
	}
	mut level := chunk_level(mut sink, elem_hashes, b, 0)
	mut lvl := u8(1)
	for level.len > 1 {
		level = chunk_level(mut sink, level, b, lvl)
		lvl++
	}
	return level[0]
}

// levels_for returns the seq-node depth for n elements at fanout b.
pub fn levels_for(n int, b int) int {
	if n <= 0 {
		return 1
	}
	mut count := n
	mut levels := 0
	for {
		count = (count + b - 1) / b // ceil division
		levels++
		if count <= 1 {
			break
		}
	}
	return levels
}

// ── traversal (generic over any object getter) ────────────────────────

// Getter resolves an object by content hash (none if absent). It is the public
// read side of the object seam: getter_of() returns one, and load_document_from /
// mark_live / object_graph_stats take one, so any substrate's reader composes.
pub type Getter = fn (hash []u8) ?[]u8

fn collect_via(get Getter, node_hash []u8, mut out [][]u8) {
	payload := get(node_hash) or { return }
	if payload.len < seqnode_header || payload[0] != obj_seqnode {
		return
	}
	level := payload[2]
	count := int(read_u16(payload, 3))
	mut off := seqnode_header
	for _ in 0 .. count {
		if off + 32 > payload.len {
			return
		}
		child := payload[off..off + 32].clone()
		off += 32
		if level == 0 {
			out << child
		} else {
			collect_via(get, child, mut out)
		}
	}
}

// collect_elements walks the seq-tree from root and returns the element refs
// in sequence order, resolving objects from the sink.
pub fn collect_elements(sink &ObjectSink, root []u8) [][]u8 {
	mut out := [][]u8{}
	g := fn [sink] (h []u8) ?[]u8 {
		return sink.get(h)
	}
	collect_via(g, root, mut out)
	return out
}

// collect_elements_from_pack walks the seq-tree from root, resolving objects
// from a persisted pack — proving the in-memory and on-disk object graphs are
// the same model (object_model.md §7).
pub fn collect_elements_from_pack(r &PackReader, root []u8) [][]u8 {
	mut out := [][]u8{}
	g := fn [r] (h []u8) ?[]u8 {
		return r.get(h)
	}
	collect_via(g, root, mut out)
	return out
}
