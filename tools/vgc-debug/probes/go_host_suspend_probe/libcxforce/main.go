// libcxforce — deterministic forcing repro for cx #743 against the REAL libcx.
//
// Shape: goroutine T1 locks its OS thread, makes ONE libcx call (registering
// its M with vgc), then runs Go code forever — a permanent vgc "straggler"
// that never reaches an alloc-path safepoint. The main goroutine (its own
// locked M) then drives N allocation-heavy libcx calls. With VGC_NEXT_GC_MB=1
// nearly every call triggers a collection, and every collection must suspend
// T1's M.
//
// Pre-fix (signal suspension, any signal number, Go >= 1.26): the suspend
// signal is consumed by the Go runtime's handler (never forwarded: SI_USER),
// the ack never arrives, and the run hangs in vgc's 0x0acd wait loop within
// the first few iterations.
// Post-fix (darwin mach suspension): all N iterations complete.
//
// Run:  cd libcxforce && go build -o force . && VGC_NEXT_GC_MB=1 timeout 120 ./force
// (VGC_NEXT_GC_MB must be in the EXEC environment: vgc_init reads it at dylib
// load, before main.)
package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"

	cxlib "github.com/cx-home/cx/lang/go"
)

var stop uint32

func main() {
	n := 200
	if v := os.Getenv("FORCE_N"); v != "" {
		if p, err := strconv.Atoi(v); err == nil {
			n = p
		}
	}

	// ~200 KB cx document; each conversion churns multiple MB through vgc.
	var b strings.Builder
	b.WriteString("[doc\n")
	for i := 0; i < 4000; i++ {
		fmt.Fprintf(&b, "  [row id=%d name=\"item-%d\" [vals 1 2 3 4 5 6 7 8]]\n", i, i)
	}
	b.WriteString("]\n")
	doc := b.String()

	// T1: register with vgc, then live in Go land forever (the straggler).
	ready := make(chan struct{})
	go func() {
		runtime.LockOSThread()
		if _, err := cxlib.ToCx("[a 1]"); err != nil {
			fmt.Println("T1 register call failed:", err)
			os.Exit(2)
		}
		close(ready)
		x := 0
		for atomic.LoadUint32(&stop) == 0 { // tight preemptible-only-by-signal loop
			x++
		}
		_ = x
	}()
	<-ready

	runtime.LockOSThread()
	for i := 0; i < n; i++ {
		if _, err := cxlib.ToCx(doc); err != nil {
			fmt.Printf("iter %d: %v\n", i, err)
			os.Exit(2)
		}
		if i%10 == 0 {
			fmt.Printf("iter %d ok\n", i)
		}
	}
	atomic.StoreUint32(&stop, 1)
	fmt.Printf("FORCE-OK n=%d\n", n)
}
