// G-CHURN — thread-lifecycle adversarial GC battery (spec §7.1).
//
// Detects the vgc stop-the-world defect that the naive vgc_repro.v MISSES:
// the STW handshake counts every registered thread forever (no
// deregistration) and times out ("proceed with what we have"), so a botched
// collection silently frees LIVE data instead of hanging. A uniform-allocator
// repro passes while corrupting; this battery catches it.
//
// Method (differential oracle, not "did it run"):
//   * An ANCHOR thread builds a long-lived linked structure whose every node
//     carries a deterministic checksum, then walks it many rounds confirming
//     each checksum. If a botched GC sweeps any live node, the checksum
//     mismatches (or the walk segfaults) — corruption is observed.
//   * CHURN threads allocate-and-drop transient blobs to drive GC cycles past
//     the 256 MiB heap-goal floor.
//   * WAVES of short-lived allocating threads grow `ncaches` with dead caches,
//     forcing STW to wait on threads that will never reach a safepoint.
//   * A BLOCKED thread holds live data and sleeps across collections.
//
// Exit 0 + "G-CHURN PASS" only if every anchor checksum held. Nonzero / hang
// (caught by the harness wall-clock alarm) / panic = FAIL. Liveness rule:
// a stall is a failure, never a silent proceed.
//
//   v -gc vgc  -prod -o g_churn g_churn.v   # subject under test
//   v -gc none -prod -o g_churn g_churn.v   # oracle: must always PASS
//   ./g_churn [anchor_nodes] [churn_threads] [waves]
import sync
import time
import os

@[heap]
struct Node {
mut:
	next  &Node = unsafe { nil }
	id    u64
	check u64
	pad   []u8
}

struct Tally {
mut:
	corruptions u64
}

// deterministic checksum for node `i` — independent of run, so any deviation
// is corruption, not nondeterminism.
@[inline]
fn expected_check(i u64) u64 {
	mut h := u64(1469598103934665603) // FNV-1a offset
	mut x := i
	for _ in 0 .. 8 {
		h = (h ^ (x & 0xff)) * 1099511628211
		x >>= 8
	}
	return h
}

// ANCHOR: build a live list, then repeatedly verify it survives collections.
fn anchor(nodes int, verify_rounds int, shared t Tally, mut wg sync.WaitGroup) {
	mut head := &Node{}
	for i := nodes - 1; i >= 0; i-- {
		head = &Node{
			next:  head
			id:    u64(i)
			check: expected_check(u64(i))
			pad:   []u8{len: 48, init: u8(index & 0xff)}
		}
	}
	mut bad := u64(0)
	for _ in 0 .. verify_rounds {
		mut cur := head
		mut seen := 0
		for cur.next != unsafe { nil } {
			if cur.check != expected_check(cur.id) {
				bad++
			}
			if cur.pad.len != 48 {
				bad++
			}
			cur = cur.next
			seen++
		}
		if seen != nodes {
			bad++ // list truncated by a bad sweep
		}
		time.sleep(200 * time.microsecond)
	}
	lock t {
		t.corruptions += bad
	}
	wg.done()
}

// CHURN: pure garbage to drive GC pressure past the heap-goal floor.
fn churn(iters int, mut wg sync.WaitGroup) {
	mut last := &Node{}
	for i in 0 .. iters {
		b := &Node{
			id:  u64(i)
			pad: []u8{len: 256}
		}
		last = b
	}
	if last.id == 0xdeadbeef {
		println('unreachable')
	}
	wg.done()
}

// BLOCKED: hold live data, then block in a syscall across collections.
fn blocked(shared t Tally, mut wg sync.WaitGroup) {
	mut keep := []&Node{}
	for i in 0 .. 1000 {
		keep << &Node{
			id:    u64(i)
			check: expected_check(u64(i))
			pad:   []u8{len: 128}
		}
	}
	time.sleep(800 * time.millisecond) // blocked, not at a safepoint
	mut bad := u64(0)
	for n in keep {
		if n.check != expected_check(n.id) {
			bad++
		}
	}
	lock t {
		t.corruptions += bad
	}
	wg.done()
}

fn arg(i int, def int) int {
	return if os.args.len > i { os.args[i].int() } else { def }
}

fn main() {
	anchor_nodes := arg(1, 20_000)
	churn_threads := arg(2, 6)
	waves := arg(3, 40)

	shared t := Tally{}
	mut wg := sync.new_waitgroup()

	// long-lived anchor + blocked thread run for the whole test
	wg.add(2)
	spawn anchor(anchor_nodes, 4000, shared t, mut wg)
	spawn blocked(shared t, mut wg)

	// steady churn
	wg.add(churn_threads)
	for _ in 0 .. churn_threads {
		spawn churn(2_000_000, mut wg)
	}

	// WAVES of short-lived threads: each grows ncaches and dies, so later STW
	// attempts must wait on dead caches that never hit the alloc safepoint.
	for _ in 0 .. waves {
		mut ww := sync.new_waitgroup()
		ww.add(4)
		for _ in 0 .. 4 {
			spawn churn(120_000, mut ww)
		}
		ww.wait()
	}

	wg.wait()

	c := rlock t {
		t.corruptions
	}
	if c == 0 {
		println('G-CHURN PASS: anchor=${anchor_nodes} churn=${churn_threads} waves=${waves}, 0 corruptions')
	} else {
		eprintln('G-CHURN FAIL: ${c} corruption events (live data freed/clobbered by botched STW)')
		exit(1)
	}
}
