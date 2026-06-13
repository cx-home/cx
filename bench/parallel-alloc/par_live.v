// CX-free repro of the cx #14 [par] anti-scaling under -gc e (B13), faithful version.
//
// The cx workload is `[?map (1..8) [reduce [$range 0 400000] +]]`. `[$range 0 N]`
// materializes a LARGE LIVE list of N boxed nodes that stays reachable for the
// whole reduce, and the reduce allocates a fresh accumulator node per step
// (transient garbage the tracing backstop reclaims).
//
// The asymmetry that drives the anti-scale: in SERIAL only ONE reduce is in
// flight, so at any GC the live set is ONE range-list (~N nodes). In PAR all 8
// reduces are in flight at once, so the live set is EIGHT range-lists (~8N nodes)
// -> every full-STW collection marks ~8x as much AND, because the live floor is
// 8x higher, the 256MB trigger leaves less headroom so collections also fire more
// often. GC total = freq x mark-cost both inflate -> par slower than its own
// serial. (Distinct from allocator cacheline contention, which R2 already fixed
// and which the flat par_reclaim.v shows already scales.)
//
//   v -gc e     -prod -cc cc -o par_live_e     par_live.v
//   v -gc boehm -prod -cc cc -o par_live_boehm par_live.v
//   ./par_live_e <serial|par> <jobs> [n_per_job]
import sync
import time
import os

@[heap]
struct Node {
mut:
	v   u64
	pad [256]u8 // bulk so a live range-list is ~100MB/job -> 8 concurrent jobs
	// exceed the 256MB trigger (cx.Node sum-types boxed via memdup are similarly
	// heavy); without this the compiled-V live set is too small to ever GC.
}

// one "reduce over a materialized range": build a live list of n boxed nodes,
// then fold it allocating a fresh accumulator node per step. Returns the sum so
// the result is observably correct (= n*(n-1)/2).
fn reduce_job(n int) u64 {
	mut live := []&Node{cap: n}
	for i in 0 .. n {
		live << &Node{
			v: u64(i)
		}
	}
	mut acc := &Node{
		v: 0
	}
	for i in 0 .. n {
		acc = &Node{
			v: acc.v + live[i].v
		}
	}
	// keep `live` reachable across the whole fold
	mut chk := u64(0)
	for i in 0 .. n {
		chk += live[i].v
	}
	if chk != acc.v {
		println('MISMATCH chk=${chk} acc=${acc.v}')
	}
	return acc.v
}

__global g_results = []u64{}

fn par_worker(j int, n int, mut wg sync.WaitGroup) {
	g_results[j] = reduce_job(n)
	wg.done()
}

fn arg_s(i int, def string) string {
	return if os.args.len > i { os.args[i] } else { def }
}

fn arg_i(i int, def int) int {
	return if os.args.len > i { os.args[i].int() } else { def }
}

fn main() {
	mode := arg_s(1, 'par')
	jobs := arg_i(2, 8)
	n := arg_i(3, 400000)

	g_results = []u64{len: jobs}
	sw := time.new_stopwatch()
	if mode == 'serial' {
		// one thread runs all jobs sequentially: at most ONE live list at a time
		for j in 0 .. jobs {
			g_results[j] = reduce_job(n)
		}
	} else {
		// jobs threads run concurrently: all `jobs` live lists coexist
		mut wg := sync.new_waitgroup()
		wg.add(jobs)
		for j in 0 .. jobs {
			spawn par_worker(j, n, mut wg)
		}
		wg.wait()
	}
	el := sw.elapsed().milliseconds()
	expect := u64(n) * u64(n - 1) / 2
	mut ok := true
	for j in 0 .. jobs {
		if g_results[j] != expect {
			ok = false
		}
	}
	println('mode=${mode} jobs=${jobs} n=${n} ms=${el} ok=${ok} (expect ${expect})')
}
