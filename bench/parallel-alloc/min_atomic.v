// Bug B instrument: replace sync.WaitGroup with our own atomic counter to
// distinguish (a) wrong number of workers actually running per wave [spawn/
// thread-lifecycle bug] from (b) corrupted counter memory.
import os
import sync.stdatomic

@[heap]
struct Counter {
mut:
	done u64
}

@[heap]
struct Node {
mut:
	next &Node = unsafe { nil }
	id   u64
	pad  []u8
}

__global g_ran = u64(0) // process-wide: total worker bodies that ran

fn worker(iters int, c &Counter) {
	mut last := &Node{}
	for i in 0 .. iters {
		last = &Node{
			id:  u64(i)
			pad: []u8{len: 256}
		}
	}
	if last.id == 0xdeadbeef {
		println('x')
	}
	stdatomic.add_u64(&g_ran, 1)
	stdatomic.add_u64(&c.done, 1)
}

fn main() {
	waves := if os.args.len > 1 { os.args[1].int() } else { 2000 }
	iters := if os.args.len > 2 { os.args[2].int() } else { 150 }
	eprintln('min_atomic waves=${waves} iters=${iters}')
	mut bad := 0
	for w in 0 .. waves {
		before := stdatomic.load_u64(&g_ran)
		mut c := &Counter{
			done: 0
		}
		for _ in 0 .. 4 {
			spawn worker(iters, c)
		}
		mut spins := i64(0)
		for stdatomic.load_u64(&c.done) < 4 {
			spins++
			if spins > 5_000_000_000 {
				eprintln('wave ${w}: TIMEOUT done=${stdatomic.load_u64(&c.done)}')
				bad++
				break
			}
		}
		final_done := stdatomic.load_u64(&c.done)
		ran_delta := stdatomic.load_u64(&g_ran) - before
		if final_done != 4 || ran_delta != 4 {
			eprintln('wave ${w}: done=${final_done} ran_delta=${ran_delta} (expected 4/4)')
			bad++
			if bad > 8 {
				break
			}
		}
	}
	if bad == 0 {
		println('MIN_ATOMIC PASS waves=${waves}')
	} else {
		eprintln('MIN_ATOMIC FAIL bad=${bad}')
		exit(1)
	}
}
