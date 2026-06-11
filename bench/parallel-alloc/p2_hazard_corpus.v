module main

// HAZARD 1: a aliased by c -> not unique -> must NOT reuse (else freeing b UAFs c)
fn aliased_map() int {
	a := [1, 2, 3, 4, 5]
	c := a
	b := a.map(it * 2)
	mut s := 0
	s += b.len
	s += c.len
	return s
}

// HAZARD 2: a used after the map -> not dead -> must NOT reuse
fn used_after_map() int {
	a := [1, 2, 3, 4, 5]
	b := a.map(it * 2)
	mut s := 0
	s += b.len
	s += a.len
	return s
}

// HAZARD 3: element size changes ([]int -> []string) -> must NOT reuse
fn size_change() int {
	a := [1, 2, 3]
	b := a.map('v${it}')
	mut s := 0
	s += b.len
	return s
}

// SAFE: unique + dead + same size -> reuse
fn safe_reuse() int {
	a := [10, 20, 30]
	b := a.map(it + 1)
	mut s := 0
	s += b.len
	return s
}

fn main() {
	println(aliased_map())
	println(used_after_map())
	println(size_change())
	println(safe_reuse())
}
