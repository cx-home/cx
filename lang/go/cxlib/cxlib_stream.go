// Streaming-callback dispatch for cgo. cx_code_eval_streaming
// takes a C function pointer (cx_code_write_cb); Go closures
// can't be passed directly. The pattern below registers each call's
// callback in a process-wide table keyed by a monotonic token; the
// C side calls the exported cxGoStreamTrampoline with the token
// through the user pointer, which looks up and dispatches the Go
// closure. Per spec/audits/code_abi_v1.md §3.3.

package cxlib

/*
#include <stddef.h>
#include "cx.h"
*/
import "C"

import (
	"sync"
	"unsafe"
)

type streamEntry struct {
	cb  func(chunk []byte) error
	err error
}

var streamMu sync.Mutex
var streamNext uint64
var streamTable = map[uint64]*streamEntry{}

func registerStreamCallback(cb func(chunk []byte) error) (uint64, func()) {
	streamMu.Lock()
	streamNext++
	token := streamNext
	streamTable[token] = &streamEntry{cb: cb}
	streamMu.Unlock()
	return token, func() {
		streamMu.Lock()
		delete(streamTable, token)
		streamMu.Unlock()
	}
}

func streamCallbackError(token uint64) error {
	streamMu.Lock()
	defer streamMu.Unlock()
	if e, ok := streamTable[token]; ok {
		return e.err
	}
	return nil
}

//export cxGoStreamTrampoline
func cxGoStreamTrampoline(bytes *C.char, n C.size_t, user unsafe.Pointer) C.int {
	token := uint64(uintptr(user))
	streamMu.Lock()
	entry, ok := streamTable[token]
	streamMu.Unlock()
	if !ok {
		return 1
	}
	chunk := C.GoBytes(unsafe.Pointer(bytes), C.int(n))
	if err := entry.cb(chunk); err != nil {
		streamMu.Lock()
		entry.err = err
		streamMu.Unlock()
		return 1
	}
	return 0
}
