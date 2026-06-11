module main

// carried across iterations (defined outside) -> must NOT drop in body
fn carried() int {
	mut acc := []int{}
	for i in 0 .. 50 {
		acc << i
	}
	return acc.len
}

// loop-local map reuse, many iters -> drop+reuse each iteration, no UAF
fn local_reuse() int {
	mut total := 0
	for i in 0 .. 1000 {
		tmp := [i, i + 1, i + 2, i + 3]
		b := tmp.map(it * 2)
		total += b.len + b[0]
	}
	return total
}

// loop-local pointer stored into an OUTER cache each iter -> escapes -> must NOT drop
fn escape_to_outer() int {
	mut last := 0
	for i in 0 .. 20 {
		arr := [i, i * 2]
		cache := arr
		last = cache.len + arr.len
	}
	return last
}

// string elements in a loop-local filter -> elements alias -> must NOT reuse/early-free
fn loop_filter_strings() int {
	mut n := 0
	for i in 0 .. 30 {
		a := ['x', 'yy', 'zzz']
		b := a.filter(it.len > 1)
		n += b.len
	}
	return n
}

fn main() {
	println(carried())
	println(local_reuse())
	println(escape_to_outer())
	println(loop_filter_strings())
}
