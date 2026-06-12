// Residual pinpointer: when a wave stalls (c.done < 4 while g_ran shows 4 workers
// ran), is it (A) 3 workers got a WRONG `c` pointer via the spawn arg [arg-field
// corruption], or (B) 3 workers died between two adjacent atomic adds [thread
// crash]? Instrument both:
//   g_ran      ++ at the very end of the worker (did the body run to completion?)
//   g_attempts ++ right BEFORE the c.done add (did we reach the per-wave add?)
//   g_wrong_c  ++ if the worker's received `c` != the wave's expected c (set by main)
//   g_bad_c    = a sample of the wrong pointer value seen
import os
import sync.stdatomic

fn C.builtin__vgc_is_allocated(ptr voidptr) u64
fn vgc_is_allocated(ptr voidptr) u64 {
	return C.builtin__vgc_is_allocated(ptr)
}

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

__global g_ran       = u64(0)
__global g_attempts  = u64(0)
__global g_wrong_c   = u64(0)
__global g_bad_c     = u64(0)
__global g_expected_c = u64(0)
__global g_stop      = u64(0)

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
	my_c := u64(usize(c))
	if my_c != stdatomic.load_u64(&g_expected_c) {
		stdatomic.add_u64(&g_wrong_c, 1)
		stdatomic.store_u64(&g_bad_c, my_c)
	}
	stdatomic.add_u64(&g_attempts, 1)
	stdatomic.add_u64(&c.done, 1)
}

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
	waves := if os.args.len > 1 { os.args[1].int() } else { 4000 }
	iters := if os.args.len > 2 { os.args[2].int() } else { 400 }
	eprintln('min_atomic3 waves=${waves} iters=${iters}')
	spawn steady()
	spawn steady()
	mut bad := 0
	for w in 0 .. waves {
		ran0 := stdatomic.load_u64(&g_ran)
		att0 := stdatomic.load_u64(&g_attempts)
		wrong0 := stdatomic.load_u64(&g_wrong_c)
		mut c := &Counter{
			done: 0
		}
		stdatomic.store_u64(&g_expected_c, u64(usize(c)))
		for _ in 0 .. 4 {
			spawn worker(iters, c)
		}
		mut spins := i64(0)
		for stdatomic.load_u64(&c.done) < 4 {
			spins++
			if spins > 1_500_000_000 {
				dn := stdatomic.load_u64(&c.done)
				rand := stdatomic.load_u64(&g_ran) - ran0
				attd := stdatomic.load_u64(&g_attempts) - att0
				wrongd := stdatomic.load_u64(&g_wrong_c) - wrong0
				st := vgc_is_allocated(c)
				eprintln('wave ${w} STALL: c.done=${dn} ran_delta=${rand} attempts_delta=${attd} wrong_c=${wrongd} c=0x${u64(usize(c)).hex()} alloc_status=${st} (bit0=allocbit bit1=in_use cnt=${st >> 8}) bad_c=0x${stdatomic.load_u64(&g_bad_c).hex()}')
				bad++
				break
			}
		}
		if bad > 0 {
			break
		}
	}
	stdatomic.store_u64(&g_stop, 1)
	if bad == 0 {
		println('MIN_ATOMIC3 PASS waves=${waves}')
	} else {
		eprintln('MIN_ATOMIC3 FAIL')
		exit(1)
	}
}
