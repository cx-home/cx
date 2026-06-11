module main

@[heap]
struct Node {
	val int
}

struct Box {
mut:
	p &Node = unsafe { nil }
}

// (1) UNIQUE: p never escapes -> safe to free at last use.
fn unique_ref() int {
	p := &Node{ val: 7 }
	mut n := 0
	n += p.val
	n += p.val
	return n
}

// (2) ALIASED: q := p aliases the pointer. Freeing p early would UAF q.val.
fn aliased_ref() int {
	p := &Node{ val: 11 }
	q := p
	a := p.val
	b := q.val
	return a + b
}

// (3) RETURNED: ownership leaves the function -> must NOT free.
fn returned_ref() &Node {
	p := &Node{ val: 13 }
	return p
}

// (4) FIELD-STORE: p stored into a struct field (pointer aliases, no clone).
fn field_store_ref() int {
	p := &Node{ val: 17 }
	mut b := Box{}
	b.p = p
	x := b.p.val
	y := p.val
	return x + y
}

// (5) CALL-ESCAPE: p passed to a fn that retains it (stores into a returned box).
fn keep(n &Node) &Node {
	return n
}
fn call_escape_ref() int {
	p := &Node{ val: 19 }
	r := keep(p)
	return r.val + p.val
}

fn main() {
	println(unique_ref())
	println(aliased_ref())
	println(returned_ref().val)
	println(field_store_ref())
	println(call_escape_ref())
}
