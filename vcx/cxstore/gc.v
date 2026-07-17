module cxstore

// CXStore GC / compaction (object_model.md §8 + A.9). Reachability is the
// authority: mark every object reachable from the live roots (the reflog's
// current roots), then compact by writing a new pack containing only the live
// objects. Unreachable objects (e.g. those only reachable from a superseded
// root) are dropped. The mark is cycle-safe via a visited set; alias edges
// would be added to object_refs once anchors are stored as alias objects (#82).

// object_refs returns the outgoing object-hash edges of an object payload.
fn object_refs(payload []u8) [][]u8 {
	mut refs := [][]u8{}
	if payload.len < 1 {
		return refs
	}
	match payload[0] {
		obj_doc {
			// [kind][ver][prolog_root:32][elements_root:32]
			if payload.len >= 66 {
				refs << payload[2..34].clone()
				refs << payload[34..66].clone()
			}
		}
		obj_node {
			// [kind][ver][seq_root:32][own ast_bin…]
			if payload.len >= 34 {
				refs << payload[2..34].clone()
			}
		}
		obj_node_inline {
			// [kind][ver][count:u16][entries…] — outgoing edges are the tag-hash
			// children; inline-leaf children are part of THIS object (no edge).
			if payload.len >= 4 {
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
						refs << payload[off..off + 32].clone()
						off += 32
					} else if tag == child_tag_leaf {
						if off + 2 > payload.len {
							break
						}
						ln := int(read_u16(payload, off))
						off += 2 + ln
					} else {
						break
					}
				}
			}
		}
		obj_seqnode {
			// [kind][ver][level][count:u16][child:32 × count]
			if payload.len >= seqnode_header {
				count := int(read_u16(payload, 3))
				mut off := seqnode_header
				for _ in 0 .. count {
					if off + 32 > payload.len {
						break
					}
					refs << payload[off..off + 32].clone()
					off += 32
				}
			}
		}
		else {} // obj_leaf and unknown kinds have no outgoing object edges
	}
	return refs
}

// mark_live traverses the object graph from `roots` and returns the reachable
// objects keyed by hex(hash). Cycle-safe (visited set); missing objects are
// skipped rather than fatal.
pub fn mark_live(get Getter, roots [][]u8) map[string][]u8 {
	mut live := map[string][]u8{}
	mut stack := [][]u8{}
	for r in roots {
		stack << r.clone()
	}
	for stack.len > 0 {
		h := stack.pop()
		hk := h.hex()
		if hk in live {
			continue
		}
		payload := get(h) or { continue }
		live[hk] = payload.clone()
		for child in object_refs(payload) {
			if child.hex() !in live {
				stack << child
			}
		}
	}
	return live
}

// object_graph_stats walks every object reachable from `roots` and returns
// (logical, distinct): `distinct` is the number of UNIQUE objects (the actual
// stored footprint of these roots — content-addressing collapses shared
// subtrees to one object), while `logical` counts every traversal step (each
// shared subtree once per place it appears) — i.e. the object count these roots
// WOULD occupy with no subtree sharing at all. logical / distinct is therefore
// the dedup ratio the object model achieves (#129-D). It is bounded: a document
// graph's logical count equals its original (pre-sharing) node count, since
// sharing only collapses storage, never the logical tree. Missing objects are
// skipped (they cannot occur for an intact live graph). Cost is O(logical), so
// callers cache it against a mutation fingerprint rather than recomputing per
// scrape.
pub fn object_graph_stats(get Getter, roots [][]u8) (i64, int) {
	mut logical := i64(0)
	mut distinct := map[string]bool{}
	mut stack := [][]u8{}
	for r in roots {
		stack << r.clone()
	}
	for stack.len > 0 {
		h := stack.pop()
		payload := get(h) or { continue }
		logical++
		distinct[h.hex()] = true
		for child in object_refs(payload) {
			stack << child
		}
	}
	return logical, distinct.len
}

// compact_to_pack writes a new pack containing exactly the objects reachable
// from `roots`, and returns the number of live objects written.
pub fn compact_to_pack(get Getter, roots [][]u8, out_path string) !int {
	live := mark_live(get, roots)
	mut payloads := [][]u8{cap: live.len}
	for _, p in live {
		payloads << p
	}
	write_pack(out_path, payloads)!
	return payloads.len
}

// ── retention policy (object_model.md §8 / #81) ───────────────────────

// RetentionPolicy decides which versions survive GC. keep_versions = the last N
// roots per ref to retain (<= 0 keeps all). max_bytes (> 0) is a size trigger:
// needs_gc reports when the live store exceeds it, so a caller can schedule a
// retention pass. Policy is deliberately separate from the GC mechanism — what
// to keep is an ops decision; mark-sweep just traces whatever roots it is given.
pub struct RetentionPolicy {
pub:
	keep_versions int
	max_bytes     i64
}

// byte_size is the total resident size of the store's packs.
pub fn (s &Store) byte_size() i64 {
	mut total := i64(0)
	for r in s.packs {
		total += i64(r.data.len)
	}
	return total
}

// needs_gc reports whether the store has grown past the policy's size trigger.
pub fn (s &Store) needs_gc(policy RetentionPolicy) bool {
	return policy.max_bytes > 0 && s.byte_size() > policy.max_bytes
}

// gc_retain computes the live root set from the reflog per the policy
// (keep-last-N-per-ref) and compacts the store to a new pack of only the
// objects reachable from those roots. Returns the live object count.
pub fn (s &Store) gc_retain(rl &RefLog, policy RetentionPolicy, out_path string) !int {
	roots := rl.recent_roots_per_ref(policy.keep_versions)
	return s.compact(roots, out_path)
}

// ── Store GC helpers ──────────────────────────────────────────────────

// reachable returns the live object set across the store from the given roots.
pub fn (s &Store) reachable(roots [][]u8) map[string][]u8 {
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	return mark_live(g, roots)
}

// compact writes a new pack of just the objects reachable from `roots` and
// returns the live count. The store itself is unchanged; callers swap in the
// compacted pack (and drop superseded ones) as a retention step.
pub fn (s &Store) compact(roots [][]u8, out_path string) !int {
	g := Getter(fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	})
	return compact_to_pack(g, roots, out_path)
}
