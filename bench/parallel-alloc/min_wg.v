// Minimal isolation for bug B (vgc WaitGroup corruption under wave churn).
// mode 0: heap WaitGroup per wave (g_churn pattern, `&WaitGroup`)
// mode 1: stack WaitGroup per wave (held on main's stack across wait())
import sync
import os

@[heap]
struct Node {
mut:
	next &Node = unsafe { nil }
	id   u64
	pad  []u8
}

// allocate to drive GC pressure past the 256MB heap goal, then done().
fn worker(iters int, wg &sync.WaitGroup) {
	mut last := &Node{}
	for i in 0 .. iters {
		last = &Node{
			id:  u64(i)
			pad: []u8{len: 256}
		}
	}
	if last.id == 0xdeadbeef {
		println('unreachable')
	}
	unsafe { wg.done() }
}

fn main() {
	mode := if os.args.len > 1 { os.args[1].int() } else { 0 }
	waves := if os.args.len > 2 { os.args[2].int() } else { 60 }
	iters := if os.args.len > 3 { os.args[3].int() } else { 120_000 }
	eprintln('min_wg mode=${mode} waves=${waves} iters=${iters}')
	for w in 0 .. waves {
		if mode == 0 {
			mut ww := sync.new_waitgroup() // heap &WaitGroup
			ww.add(4)
			for _ in 0 .. 4 {
				spawn worker(iters, ww)
			}
			ww.wait()
		} else {
			mut ww := sync.WaitGroup{} // stack WaitGroup
			ww.init()
			ww.add(4)
			for _ in 0 .. 4 {
				spawn worker(iters, &ww)
			}
			ww.wait()
		}
		if w % 20 == 0 {
			eprintln('wave ${w} ok')
		}
	}
	println('MIN_WG PASS mode=${mode} waves=${waves}')
}
