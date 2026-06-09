module main

// Regression test for the V `vmemcpy` low-address-guard bug under
// wasm32-emcc (v0.7.5 P1).
//
// The bug: V's `cfns_wrapper.c.v` skips memcpy when either pointer
// is `<= 0xFFFF`, treating sub-64KB addresses as a null page. Under
// wasm32-emcc, linear-memory stack temporaries land below 64KB —
// so legitimate copies into Option `.data[]` slots get dropped.
//
// Concrete repro: a struct that mirrors vcx/cx/parser.v's ParseResult
// (two Option fields + a bool tail), constructed via the Option-ok
// machinery and unwrapped via `or`. Under buggy V, the unwrapped
// Doc's `.name` reads as garbage. Under patched V (-d wasm32_emcc
// against third_party/v/), it reads as "hello".
//
// Build + run via scripts/wasm/build_repro.sh (or hand-run the
// V → C → emcc pipeline). The exported `probe_to_cx` should return
// "OK_single_hello"; any other answer means the guard is firing.

struct Doc {
pub mut:
	name string
}

pub struct PR {
pub mut:
	single   ?Doc
	multi    ?[]Doc
	is_multi bool
}

fn make_single() PR {
	d := Doc{ name: 'hello' }
	return PR{ single: d, is_multi: false }
}

@[export: 'probe_to_cx']
pub fn probe_to_cx() &char {
	res := make_single()
	if res.is_multi {
		_ := res.multi or { return c'ERR_no_multi' }
		return c'OK_multi'
	}
	d := res.single or { return c'ERR_no_single' }
	if d.name == 'hello' {
		return c'OK_single_hello'
	}
	return c'OK_single_other'
}

fn main() {}
