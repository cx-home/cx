module cxstore

// CXStore master index — a read view over multiple sealed packs
// (object_model.md §6.2 + #83 "master hash→(pack,offset) index"). The store
// resolves an object by content hash across every open pack, giving a single
// logical content-addressed space over many physical packs. Identical objects
// in different packs collapse to one logical object (cross-pack dedup view);
// full physical convergence happens at compaction (§5).
//
// The union index here is a complete in-memory map (first-pack-wins). The
// bloom-accelerated "which pack might hold H" path is the #84 optimization;
// a complete map is correct and is the baseline it accelerates.

pub struct Store {
mut:
	packs    []PackReader
	location map[string]int // hex(hash) → index into packs (first pack that has it)
}

// open_store opens the given sealed packs and builds the cross-pack index.
pub fn open_store(pack_paths []string) !Store {
	mut s := Store{}
	for p in pack_paths {
		r := open_pack(p)!
		idx := s.packs.len
		s.packs << r
		for hh in r.hashes() {
			hk := hh.hex()
			if hk !in s.location {
				s.location[hk] = idx // first pack wins (dedup view)
			}
		}
	}
	return s
}

// add_pack opens an additional pack and folds it into the cross-pack index.
pub fn (mut s Store) add_pack(path string) ! {
	r := open_pack(path)!
	idx := s.packs.len
	s.packs << r
	for hh in r.hashes() {
		hk := hh.hex()
		if hk !in s.location {
			s.location[hk] = idx
		}
	}
}

// get resolves an object by content hash across all packs.
pub fn (s &Store) get(hash []u8) ?[]u8 {
	idx := s.location[hash.hex()] or { return none }
	return s.packs[idx].get(hash)
}

pub fn (s &Store) has(hash []u8) bool {
	return hash.hex() in s.location
}

// object_count is the number of unique objects across all packs (the dedup
// view — an object present in N packs counts once).
pub fn (s &Store) object_count() int {
	return s.location.len
}

pub fn (s &Store) pack_count() int {
	return s.packs.len
}

// collect_elements_from_store walks a seq-tree from root, resolving every
// seq-node and element across all packs — proving cross-pack subtree
// resolution.
pub fn (s &Store) collect_elements(root []u8) [][]u8 {
	mut out := [][]u8{}
	g := fn [s] (h []u8) ?[]u8 {
		return s.get(h)
	}
	collect_via(g, root, mut out)
	return out
}
