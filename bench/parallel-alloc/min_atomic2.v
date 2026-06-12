// Residual localizer: min_atomic (own atomic per-wave counter, NO WaitGroup) but
// with a STEADY background allocator thread cranking GC to g_churn levels (~100%
// repro regime). If the per-wave invariant (exactly 4 worker bodies ran, counter
// reaches exactly 4) EVER breaks here, the residual is worker-execution
// duplication (a spawn/thread-lifecycle bug). If it stays clean while min_wg
// fails at the same pressure, the residual is specific to sync.WaitGroup.
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

__global g_ran  = u64(0)
__global g_stop = u64(0)

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

// steady background allocator: drives GC hard, like g_churn's 2M-node churn thread
fn steady() {
	mut last := &Node{}
	for stdatomic.load_u64(&g_stop) == 0 {
		for _ in 0 .. 50_000 {
			last = &Node{
				id:  1
				pad: []u8{len: 256}
			}
		}
	}
	if last.id == 0xdeadbeef {
		println('x')
	}
}

fn main() {
	waves := if os.args.len > 1 { os.args[1].int() } else { 2000 }
	iters := if os.args.len > 2 { os.args[2].int() } else { 400 }
	eprintln('min_atomic2 waves=${waves} iters=${iters} (+steady GC driver)')
	spawn steady()
	spawn steady()
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
			if spins > 20_000_000_000 {
				eprintln('wave ${w}: TIMEOUT done=${stdatomic.load_u64(&c.done)}')
				bad++
				break
			}
		}
		final_done := stdatomic.load_u64(&c.done)
		ran_delta := stdatomic.load_u64(&g_ran) - before
		if final_done != 4 || ran_delta != 4 {
			eprintln('wave ${w}: done=${final_done} ran_delta=${ran_delta} (EXPECTED 4/4) <<< INVARIANT BROKEN')
			bad++
			if bad > 8 {
				break
			}
		}
	}
	stdatomic.store_u64(&g_stop, 1)
	if bad == 0 {
		println('MIN_ATOMIC2 PASS waves=${waves} (exactly 4 workers/wave under heavy GC)')
	} else {
		eprintln('MIN_ATOMIC2 FAIL bad=${bad}')
		exit(1)
	}
}
