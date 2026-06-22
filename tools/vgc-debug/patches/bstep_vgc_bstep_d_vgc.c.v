// #63 B-STEP single-step root-coverage localizer (-d vgc_bstep, diagnostic only).
// Deterministically single-steps a watched MatchEnv.clone() bindings copy and, at
// each instruction, checks whether the SOURCE bindings keys-array is reachable from
// the roots vgc actually captures for a suspended thread (GP+NEON regs + [sp,
// stack_base]). The instruction window where it is NOT reachable from captured roots
// = the freeing-GC instant, observed deterministically with the holder still live.
// See scratchpad/issue63_B_plan.md. Per-step check is BOUNDED (hold #3): one
// keys-array object, captured roots only — NOT a full heap mark. Proof gate =
// >=1 unmarked-from-captured-roots window for a victim-shape clone (NOT crash-rate).
// Fork-only machinery; cx-private gets only gated begin/end CALL lines (matcher.v).
@[has_globals]
module builtin

fn C.vgc_bstep_init()
fn C.vgc_bstep_arm(th u32)
fn C.vgc_bstep_disarm(th u32)

const vgc_bstep_max_clones = u32(4) // step only the first few string-keyed clones

__global vgc_bstep_clones = u32(0)
__global vgc_bstep_keys = usize(0) // watched source keys-array base (0 = inactive)
__global vgc_bstep_keys_end = usize(0)
__global vgc_bstep_stack_base = usize(0)
__global vgc_bstep_steps = u64(0)
__global vgc_bstep_present = u64(0)
__global vgc_bstep_absent = u64(0)
__global vgc_bstep_windows = u32(0)

// vgc_bstep_begin: records the SOURCE keys-array object bounds + the worker's
// stack_base, then arms hardware single-step on self.
fn vgc_bstep_begin(keys usize, keys_end usize) {
	if vgc_bstep_clones >= vgc_bstep_max_clones || keys == 0 || keys_end <= keys {
		return
	}
	C.vgc_bstep_init()
	vgc_bstep_clones++
	vgc_bstep_keys = keys
	vgc_bstep_keys_end = keys_end
	idx := C.vgc_get_cache_idx()
	vgc_bstep_stack_base = if idx >= 0 { unsafe { vgc_heap.caches[idx].stack_base } } else { usize(0) }
	vgc_bstep_steps = 0
	vgc_bstep_present = 0
	vgc_bstep_absent = 0
	vgc_bstep_windows = 0
	C.vgc_say(0xb500, u64(keys))
	C.vgc_say(0xb501, u64(keys_end - keys))
	C.vgc_bstep_arm(C.vgc_thread_self_port())
}

// vgc_bstep_end: disarms SS and reports per-clone tallies.
fn vgc_bstep_end() {
	if vgc_bstep_keys == 0 {
		return
	}
	C.vgc_bstep_disarm(C.vgc_thread_self_port())
	C.vgc_say(0xb5ff, vgc_bstep_steps)
	C.vgc_say(0xb5fe, vgc_bstep_present)
	C.vgc_say(0xb5fd, vgc_bstep_absent)
	vgc_bstep_keys = 0
	vgc_bstep_keys_end = 0
}

// vgc_bstep_on_step: C callback, runs on the handler thread per instruction with the
// worker (stepped thread) halted. MUST NOT allocate. Checks: does any captured root
// (GP+NEON regs, or [sp, stack_base]) point into the watched keys-array object?
@[export: 'vgc_bstep_on_step']
@[markused]
fn vgc_bstep_on_step(thread_port u32) {
	if vgc_bstep_keys == 0 {
		return
	}
	vgc_bstep_steps++
	mut sp := usize(0)
	mut regs := [95]usize{}
	n := C.vgc_thread_regs(thread_port, &sp, &regs[0], 95)
	lo := vgc_bstep_keys
	hi := vgc_bstep_keys_end
	mut present := false
	for k in 0 .. n {
		w := regs[k]
		if w >= lo && w < hi {
			present = true
			break
		}
	}
	if !present && sp != 0 && vgc_bstep_stack_base > sp {
		mut a := sp
		for a + sizeof(usize) <= vgc_bstep_stack_base {
			w := unsafe { *(&usize(voidptr(a))) }
			if w >= lo && w < hi {
				present = true
				break
			}
			a += sizeof(usize)
		}
	}
	if present {
		vgc_bstep_present++
	} else {
		vgc_bstep_absent++
		if vgc_bstep_windows < 16 {
			vgc_bstep_windows++
			C.vgc_say(0xb5a0, vgc_bstep_steps) // WINDOW at step#
			C.vgc_say(0xb5a1, u64(sp))
			C.vgc_say(0xb5a2, u64(n))
		}
	}
}
