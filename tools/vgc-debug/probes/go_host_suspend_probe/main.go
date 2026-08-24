// go_host_suspend_probe — does vgc's darwin signal-suspend machinery work when
// the host process is a Go runtime that owns the same signal? (cx #743)
//
// A locked-OS-thread goroutine registers with the vgc mimic (libvgcsim) and
// then runs a tight preemptible Go loop — the exact shape of a Go M that once
// called into libcx (registered with vgc) and has since returned to Go land.
// A second locked thread plays the collector: N signal-suspend/release cycles
// against the target's mach port, under background Go preemption + GC traffic.
//
// Modes (env):
//   PROBE_MODE=signal PROBE_SIG=urg|xcpu   — vgc's signal path with that signal
//   PROBE_MODE=mach                        — signal-free thread_suspend path
//   PROBE_N=<iterations>                   (default 100)
//
// Output: one line per failure with diagnostics, and a final tally:
//   RESULT mode=<m> sig=<s> n=<n> acked=<a> timeouts=<t> spurious=<sp> resignals=<r> handler_ours=<h>
package main

/*
#cgo LDFLAGS: -L${SRCDIR} -lvgcsim -Wl,-rpath,${SRCDIR}
#include <stdint.h>
void vgcsim_install(int sig);
unsigned int vgcsim_register(void);
int vgcsim_suspend_signal(unsigned int port, unsigned long long timeout_ns);
int vgcsim_suspend_mach(unsigned int port);
int vgcsim_cycle_signal(unsigned int port, unsigned long long timeout_ns, unsigned long long hold_us);
int vgcsim_cycle_mach(unsigned int port, unsigned long long hold_us);
void vgcsim_release(unsigned int port);
unsigned long long vgcsim_spurious(void);
unsigned long long vgcsim_resignals(void);
int vgcsim_handler_is_ours(void);
*/
import "C"

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"
)

const (
	sigURG  = 16 // darwin SIGURG
	sigXCPU = 24 // darwin SIGXCPU
)

var stop uint32

// tightLoop is the preemption bait: a non-allocating loop Go must async-preempt
// (SIGURG traffic) and vgc must be able to stop.
func tightLoop() {
	x := 0
	for atomic.LoadUint32(&stop) == 0 {
		x++
	}
	_ = x
}

func main() {
	mode := getenv("PROBE_MODE", "signal")
	sigName := getenv("PROBE_SIG", "urg")
	n, _ := strconv.Atoi(getenv("PROBE_N", "100"))

	sig := sigURG
	if sigName == "xcpu" {
		sig = sigXCPU
	}
	if os.Getenv("PROBE_CTOR") == "" && mode != "mach" {
		// install AFTER Go runtime init (vgc wins the handler; Go loses preemption)
		C.vgcsim_install(C.int(sig))
	} // else: the dylib constructor installed BEFORE Go init (real libcx order),
	// or mach mode (signal-free: installing a handler would collide by itself)

	// Background load: preemption bait on every P + periodic Go GCs, so the Go
	// runtime is actively sending its own SIGURGs while we probe.
	for i := 0; i < runtime.GOMAXPROCS(0); i++ {
		go tightLoop()
	}
	go func() {
		for atomic.LoadUint32(&stop) == 0 {
			runtime.GC()
			time.Sleep(2 * time.Millisecond)
		}
	}()

	// Target: locked M, registers (unblocks the signal, exposes its mach port),
	// then runs Go code forever — never reaches any vgc poll.
	portCh := make(chan uint32, 1)
	go func() {
		runtime.LockOSThread()
		portCh <- uint32(C.vgcsim_register())
		tightLoop()
	}()
	port := <-portCh

	// Collector: its own locked M (a Go M inside a cgo call, like a collection
	// triggering inside a libcx call).
	runtime.LockOSThread()
	acked, timeouts := 0, 0
	for i := 0; i < n; i++ {
		// One cgo call per cycle: suspend -> hold 100us -> release, all in C.
		// (Returning to Go mid-suspension parks this goroutine at a safepoint
		// while the target M is frozen -> deadlock vs Go's own STW; the real
		// vgc collector runs its whole STW inside one C call, so must we.)
		var r C.int
		if mode == "mach" {
			r = C.vgcsim_cycle_mach(C.uint(port), 100)
		} else {
			r = C.vgcsim_cycle_signal(C.uint(port), C.ulonglong(3*time.Second), 100)
		}
		switch r {
		case 1:
			acked++
		case 0:
			timeouts++
			fmt.Printf("TIMEOUT iter=%d handler_ours=%d spurious=%d resignals=%d\n",
				i, int(C.vgcsim_handler_is_ours()), uint64(C.vgcsim_spurious()), uint64(C.vgcsim_resignals()))
		default:
			fmt.Printf("ERROR iter=%d rc=%d\n", i, int(r))
		}
		time.Sleep(time.Millisecond)
	}
	atomic.StoreUint32(&stop, 1)
	fmt.Printf("RESULT mode=%s sig=%s n=%d acked=%d timeouts=%d spurious=%d resignals=%d handler_ours=%d\n",
		mode, sigName, n, acked, timeouts,
		uint64(C.vgcsim_spurious()), uint64(C.vgcsim_resignals()), int(C.vgcsim_handler_is_ours()))
	if timeouts > 0 {
		os.Exit(1)
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
