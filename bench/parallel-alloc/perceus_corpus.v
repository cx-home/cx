// Perceus emission gate corpus. Exercises the entry-block (straight-line)
// drop path plus the must-NOT-drop guards (returned / escaped / shared).
// Differential oracle: output under -autofree -d perceus must equal -autofree,
// -gc none and -gc boehm; ASan must be clean (no double-free / UAF).
module main

// straight-line heap locals, all dead before scope exit -> all droppable early
fn straight() int {
	a := [1, 2, 3, 4, 5]
	b := a.map(it * 2)
	c := 'hello ' + 'world'
	mut total := 0
	total += a.len
	total += b.len
	total += c.len
	return total
}

// returned array must NOT be dropped (ownership transfers to caller)
fn make_arr() []int {
	a := [10, 20, 30]
	return a
}

// escape via & must NOT be dropped while still read afterwards
fn escapes() int {
	a := [1, 2, 3]
	p := &a
	x := p.len + a.len
	return x
}

// map + string locals, straight-line (accumulate into scalar before return so
// autofree's scope-exit free does not race the return expression — keeps the
// ground-truth `-gc none` comparison meaningful)
fn mixed() int {
	m := {
		'one': 1
		'two': 2
	}
	s := 'abc' + 'def'
	mut n := 0
	n += m.len
	n += s.len
	return n
}

// a local consumed by an appended-to array (still read later) — conservative
fn keepalive() int {
	a := [1, 2, 3]
	mut b := []int{}
	b << a.len
	b << a[0]
	mut n := 0
	n += b.len
	return n
}

fn main() {
	println(straight())
	println(make_arr())
	println(escapes())
	println(mixed())
	println(keepalive())
}
