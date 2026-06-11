module main

fn work() int {
	mut acc := 0
	for _ in 0 .. 8000000 {
		a := [1, 2, 3, 4, 5, 6, 7, 8]
		b := a.map(it * 2)
		acc += b.len + b[0]
	}
	return acc
}

fn main() {
	println(work())
}
