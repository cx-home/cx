module main

import code
import platform as _
import os

// regen_stdlib_disk — rewrites the human-inspection on-disk
// `stdlib/<name>.cx` files from the canonical bundled-stdlib source
// strings in vcx/code/stdlib_bundle.v. The on-disk files MUST stay
// byte-identical to the bundle (v08_stdlib_skeleton_test asserts this);
// this tool is the regenerator that keeps them in sync after a bundle
// edit (e.g. the D014 colon-slot → spec-surface migration).
fn main() {
	out_dir := if os.args.len > 1 { os.args[1] } else { 'stdlib' }
	mut written := 0
	for name in code.bundled_stdlib_names() {
		src := code.bundled_stdlib_source(name) or { continue }
		// `cx-stdlib/strings` → `strings.cx`
		base := name.all_after_last('/')
		path := os.join_path(out_dir, '${base}.cx')
		// Match the test's trim_space tolerance by ensuring exactly one
		// trailing newline.
		os.write_file(path, src.trim_space() + '\n') or {
			eprintln('failed to write ${path}: ${err}')
			continue
		}
		written++
	}
	println('regen_stdlib_disk: wrote ${written} file(s) to ${out_dir}/')
}
