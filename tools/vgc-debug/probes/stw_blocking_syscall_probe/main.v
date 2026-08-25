module main

// Minimal repro: under `-gc e`, threads that block in a read() while ANOTHER
// thread triggers a collection deadlock. The collecting thread waits in
// vgc_mark_roots for every thread to reach a safepoint; a thread parked in a
// blocking syscall never reaches one.
//
// Each worker allocates (to provoke collections) and does blocking reads on a
// child's stdout (os.Process + stdout_slurp). Sequential runs are fine; the
// deadlock needs >1 worker.
//
//   v -gc e -o repro main.v && ./repro 1   # completes
//   v -gc e -o repro main.v && ./repro 8   # hangs
import os
import time

fn worker(id int, iters int, done chan int) {
	for _ in 0 .. iters {
		mut p := os.new_process('/bin/echo')
		p.set_args(['x'.repeat(4096)])
		p.set_redirect_stdio()
		p.run()
		os.fd_close(p.stdio_fd[0])
		out := p.stdout_slurp()
		_ := p.stderr_slurp()
		p.wait()
		// allocate, so this thread also asks the collector for memory
		mut acc := []string{}
		for k in 0 .. 64 {
			acc << '${id}-${k}-${out.len}'
		}
		if acc.len == 0 {
			println('unreachable')
		}
	}
	done <- id
}

fn main() {
	jobs := if os.args.len > 1 { os.args[1].int() } else { 8 }
	iters := if os.args.len > 2 { os.args[2].int() } else { 40 }
	println('vgc-stw-repro: jobs=${jobs} iters=${iters}')
	done := chan int{cap: jobs}
	t0 := time.ticks()
	mut ts := []thread{}
	for i in 0 .. jobs {
		ts << spawn worker(i, iters, done)
	}
	ts.wait()
	println('vgc-stw-repro: COMPLETED in ${time.ticks() - t0}ms (no deadlock)')
}
