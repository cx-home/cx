// Phase A toolchain probe — verifies that
// a V module compiled through V-emit-C → emcc can export a
// C-callable function that takes a UTF-8 string from JS linear
// memory, allocates a V string via prealloc, and returns a
// C-callable string pointer back.
//
// This file is intentionally minimal. It exercises the load-bearing
// surface only: pointer-in, pointer-out, V string interpolation,
// V strings.Builder. The full libcx surgery (Phase B onward) builds
// on the toolchain this file validates.

module main

@[export: 'cx_echo']
fn cx_echo(input &char) &char {
	v_str := unsafe { input.vstring() }
	out := 'echoed:${v_str}'
	return out.str
}

@[export: 'cx_input_len']
fn cx_input_len(input &char) int {
	mut len := 0
	unsafe {
		for input[len] != 0 {
			len++
		}
	}
	return len
}

fn main() {}
