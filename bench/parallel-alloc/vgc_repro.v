// Minimal reproducer for the `-gc vgc` multi-thread failure.
//
//   v -gc vgc -prod -o vgc_repro vgc_repro.v
//   ./vgc_repro 1     # OK
//   ./vgc_repro 4     # nondeterministic: `V panic: memory allocation failure`
//                     # OR a permanent hang (collector spins at ~200% CPU)
//
// Several allocating threads each churn transient heap objects (a scanned
// struct + a noscan buffer per iteration — the common interpreter/server
// pattern where the collector must actively reclaim). Single-threaded is fine;
// with ≥2 threads a GC cycle's stop-the-world never completes.
import sync
import os

@[heap]
struct Blob {
mut:
	data []u8
}

fn worker(id int, iters int, mut wg sync.WaitGroup) {
	mut last := &Blob{}
	for _ in 0 .. iters {
		mut b := &Blob{
			data: []u8{len: 64} // previous `last` is dropped → GC must reclaim
		}
		b.data[0] = u8(id)
		last = b
	}
	if last.data.len == 123456 {
		println('unreachable')
	}
	wg.done()
}

fn main() {
	nt := if os.args.len > 1 { os.args[1].int() } else { 1 }
	iters := if os.args.len > 2 { os.args[2].int() } else { 20_000_000 }
	mut wg := sync.new_waitgroup()
	wg.add(nt)
	for i in 0 .. nt {
		spawn worker(i, iters, mut wg)
	}
	wg.wait()
	println('ok: ${nt} threads x ${iters} allocs')
}
