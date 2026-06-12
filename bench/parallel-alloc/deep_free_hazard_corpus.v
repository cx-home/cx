module main

// Deep-free soundness hazard corpus — LOOP form, so Perceus drops actually FIRE
// (per-iteration spine). If deep-free wrongly fired on an aliased/borrowed field,
// the alias would be a use-after-free under GC pressure -> garbage/crash. Output
// MUST be identical under `-gc none` and `-gc e`. High iteration counts force GC.

@[heap]
struct Box {
mut:
	tag int
	buf []int
}

// SAFE: buf fresh, never aliased out (only scalar tag read) -> deep-free SHOULD fire.
fn owned_loop(n int) i64 {
	mut acc := i64(0)
	for i in 0 .. n {
		b := &Box{ tag: i, buf: []int{len: 8, init: 1} }
		acc += b.tag
	}
	return acc
}

// HAZARD: heap field read-aliased into a local used in the same iteration. Deep-free
// of b.buf would UAF `k`.
fn aliased_loop(n int) i64 {
	mut acc := i64(0)
	for i in 0 .. n {
		b := &Box{ tag: i, buf: []int{len: 8, init: 3} }
		k := b.buf
		acc += i64(k[0]) + i64(k[7]) + i64(b.tag)
	}
	return acc
}

// HAZARD: non-fresh (borrowed) field init -> must not deep-free `ext`'s buffer.
fn borrowed_loop(n int, ext []int) i64 {
	mut acc := i64(0)
	for i in 0 .. n {
		b := &Box{ tag: i, buf: ext }
		acc += i64(b.buf[0])
	}
	return acc
}

fn main() {
	println(owned_loop(2_000_000))
	println(aliased_loop(2_000_000))
	ext := []int{len: 4, init: 9}
	println(borrowed_loop(2_000_000, ext))
	println(ext[0]) // ext must remain intact
}
