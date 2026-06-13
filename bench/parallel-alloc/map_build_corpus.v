// map_build_corpus.v — regression gate for the Perceus drop-before-use bug
// under -gc e (perceus.v AssignStmt liveness: a store target `m[key] = v` left
// the index/key identifiers out of the use-set, so Perceus dropped `key` at its
// declaration — freeing it before `map_set` cloned it -> corrupt/aliased stored
// keys, the map collapses).
//
// CX-free. Pure V-runtime. Build/run identically under every -gc mode; stdout
// MUST be byte-identical and the process MUST exit 0:
//   v -gc none  -cc cc -o b_none map_build_corpus.v && ./b_none
//   v -gc vgc   -cc cc -o b_vgc  map_build_corpus.v && ./b_vgc
//   v -gc e     -cc cc -o b_e    map_build_corpus.v && ./b_e
// Before the fix, -gc e collapses (len far below n, lookups miss); none/vgc are
// correct. The defining pattern is `key := <fresh string>; m[key] = v` in a loop
// (the freshly-built key is used ONLY as the index of a store).
module main

// fresh short string keys (also exercise the tiny allocator)
fn build_int_map(n int) int {
	mut m := map[string]int{}
	for i in 0 .. n {
		key := i.str()
		m[key] = i
	}
	mut bad := 0
	if m.len != n {
		bad++
	}
	for i in 0 .. n {
		if m[i.str()] != i {
			bad++
		}
	}
	return bad
}

// fresh string VALUES too (key + value both freshly built and used once)
fn build_str_map(n int) int {
	mut m := map[string]string{}
	for i in 0 .. n {
		key := 'k${i}'
		val := 'v${i}'
		m[key] = val
	}
	mut bad := 0
	if m.len != n {
		bad++
	}
	for i in 0 .. n {
		if m['k${i}'] != 'v${i}' {
			bad++
		}
	}
	return bad
}

fn main() {
	mut total := 0
	total += build_int_map(30000)
	total += build_str_map(20000)
	if total == 0 {
		println('map_build_corpus OK')
	} else {
		println('map_build_corpus CORRUPT failures=${total}')
		exit(1)
	}
}
