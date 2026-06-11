// Isolates the spawn-argument lifetime hypothesis: does V's `spawn` thread-arg
// struct survive GC pressure across the handoff? Workers do NO allocation and
// only verify their passed argument is intact; separate threads drive GC.
// If args corrupt under -gc vgc (but not boehm/none), spawn-arg lifetime is the bug.
import sync
import os

@[heap]
struct Blob {
mut:
	data []u8
}

fn pressure(mut wg sync.WaitGroup) {
	for _ in 0 .. 4_000_000 {
		mut b := &Blob{
			data: []u8{len: 128}
		}
		b.data[0] = 1
	}
	wg.done()
}

// Worker does NOT allocate. It only checks that the argument it received equals
// what main passed. A mismatch means the spawn-arg struct was corrupted (swept /
// reused) before the thread wrapper read it.
fn worker(id int, expected int, mut wg sync.WaitGroup) {
	if id != expected {
		eprintln('ARG CORRUPTED: id=${id} expected=${expected}')
		exit(3)
	}
	wg.done()
}

fn main() {
	mut pwg := sync.new_waitgroup()
	pwg.add(2)
	spawn pressure(mut pwg)
	spawn pressure(mut pwg)
	// waves of short-lived workers spawned continuously under GC pressure
	nwaves := if os.args.len > 1 { os.args[1].int() } else { 3000 }
	for _ in 0 .. nwaves {
		mut wg := sync.new_waitgroup()
		wg.add(4)
		for k in 0 .. 4 {
			spawn worker(k, k, mut wg)
		}
		wg.wait()
	}
	pwg.wait()
	println('spawn-arg test OK: all args intact')
}
