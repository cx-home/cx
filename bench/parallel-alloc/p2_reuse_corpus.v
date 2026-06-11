module main

fn map_prim() int {
	a := [1, 2, 3, 4, 5]
	b := a.map(it * 2)
	mut s := 0
	s += b.len
	return s
}

fn filter_strings() int {
	a := ['alpha', 'beta', 'gamma']
	b := a.filter(it.len > 4)
	mut s := 0
	s += b.len
	return s
}

fn main() {
	println(map_prim())
	println(filter_strings())
}
