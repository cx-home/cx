// map_churn_corpus.v — regression gate for the vgc tiny-allocator free bug
// (a map's `delete` frees a short string key's char buffer, which the tiny
// allocator had packed into a slot shared by other still-live keys; vgc_free
// reclaimed the whole slot -> live sibling keys clobbered -> map corruption).
//
// This corpus exercises HASH MAPS mutated during iteration under GC pressure —
// the exact gate gap that let the bug through: g_churn only ever allocated
// linked-list Nodes and never touched a hashmap, so the tiny-block free path
// was unexercised.
//
// CX-free. Pure V-runtime. Run identically under every -gc mode; stdout MUST be
// byte-identical (G-DIFF) and the process MUST exit 0:
//   v -gc none  -cc cc -o c_none map_churn_corpus.v && ./c_none
//   v -gc boehm -cc cc -o c_boehm map_churn_corpus.v && ./c_boehm
//   v -gc vgc   -cc cc -o c_vgc  map_churn_corpus.v && ./c_vgc
//   v -gc e     -cc cc -o c_e    map_churn_corpus.v && ./c_e
// Before the fix, -gc vgc / -gc e corrupt; -gc none / -gc boehm are correct.
module main

// delete every key while iterating; each delete frees that key's (tiny) char
// buffer. The forced compaction (deletes >= len/2) rehashes mid-iteration.
fn delete_in_for_in() int {
	mut m := map[string]string{}
	for i in 0 .. 1000 {
		m[i.str()] = i.str()
	}
	mut i := 0
	mut fails := 0
	for key, _ in m {
		if key != i.str() {
			fails++
		}
		m.delete(key)
		i++
	}
	if m.len != 0 {
		fails++
	}
	return fails
}

// delete then re-insert the same key while iterating: a delete frees a tiny key
// buffer that may share a slot with live keys; a wrong free corrupts the metas
// and the map miscounts (len drifts).
fn delete_and_set_in_for_in() int {
	mut m := map[string]string{}
	for i in 0 .. 1000 {
		m[i.str()] = i.str()
	}
	mut i := 0
	for key, _ in m {
		m.delete(key)
		m[key] = i.str()
		if i == 999 {
			break
		}
		i++
	}
	return if m.len == 1000 { 0 } else { 1 }
}

fn main() {
	mut total := 0
	for _ in 0 .. 25 {
		total += delete_in_for_in()
		total += delete_and_set_in_for_in()
	}
	if total == 0 {
		println('map_churn_corpus OK')
	} else {
		println('map_churn_corpus CORRUPT failures=${total}')
		exit(1)
	}
}
