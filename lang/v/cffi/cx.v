module cffi

#flag -I @VMODROOT/../../include
#flag -L @VMODROOT/../../vcx/target
#flag -lcx
$if macos {
	#flag -rpath @VMODROOT/../../vcx/target
}
$if linux {
	#flag -Wl,-rpath,@VMODROOT/../../vcx/target
}

// ── C declarations ────────────────────────────────────────────────────────────

// Thread-init handshake (spec/abi.md §1.5.5, capability bit 26).
// Mandatory-for-all-bindings; called once at module-load time via
// `init()` below.
fn C.cx_init() int

fn C.cx_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_to_cx_compact(input charptr, err_out &charptr) charptr
fn C.cx_ast_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_to_json(input charptr, err_out &charptr) charptr
fn C.cx_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_to_toml(input charptr, err_out &charptr) charptr

fn C.cx_xml_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_json(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_toml(input charptr, err_out &charptr) charptr

fn C.cx_json_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_json_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_json_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_json_to_json(input charptr, err_out &charptr) charptr
fn C.cx_json_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_json_to_toml(input charptr, err_out &charptr) charptr

fn C.cx_yaml_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_json(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_toml(input charptr, err_out &charptr) charptr

fn C.cx_toml_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_json(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_toml(input charptr, err_out &charptr) charptr
fn C.cx_toml_to_md(input charptr, err_out &charptr) charptr

fn C.cx_to_md(input charptr, err_out &charptr) charptr
fn C.cx_xml_to_md(input charptr, err_out &charptr) charptr
fn C.cx_json_to_md(input charptr, err_out &charptr) charptr
fn C.cx_yaml_to_md(input charptr, err_out &charptr) charptr

fn C.cx_md_to_cx(input charptr, err_out &charptr) charptr
fn C.cx_md_to_xml(input charptr, err_out &charptr) charptr
fn C.cx_md_to_ast(input charptr, err_out &charptr) charptr
fn C.cx_md_to_json(input charptr, err_out &charptr) charptr
fn C.cx_md_to_yaml(input charptr, err_out &charptr) charptr
fn C.cx_md_to_toml(input charptr, err_out &charptr) charptr
fn C.cx_md_to_md(input charptr, err_out &charptr) charptr

fn C.cx_eval_cxl(cx_input charptr, cxl_program charptr, output_target charptr, err_out &charptr) charptr

fn C.cx_free(s charptr)
fn C.cx_version() charptr

// ── internal helper ───────────────────────────────────────────────────────────

fn unwrap(result charptr, err charptr) !string {
	if result == charptr(0) {
		msg := if err != charptr(0) {
			s := unsafe { cstring_to_vstring(err) }
			C.cx_free(err)
			s
		} else {
			'unknown error'
		}
		return error(msg)
	}
	s := unsafe { cstring_to_vstring(result) }
	C.cx_free(result)
	return s
}

// ── module init ───────────────────────────────────────────────────────────────

// init runs once when the module is imported; V's runtime invokes
// any `fn init()` at module load. This is the V-cffi binding's
// hook for the spec/abi.md §1.5.5 thread-init handshake.
fn init() {
	C.cx_init()
}

// ── version ───────────────────────────────────────────────────────────────────

pub fn version() string {
	ptr := C.cx_version()
	s := unsafe { cstring_to_vstring(ptr) }
	C.cx_free(ptr)
	return s
}

// ── CX input ──────────────────────────────────────────────────────────────────

pub fn to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_cx(charptr(src.str), &err), err)
}

pub fn to_cx_compact(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_cx_compact(charptr(src.str), &err), err)
}

pub fn ast_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_ast_to_cx(charptr(src.str), &err), err)
}

pub fn to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_xml(charptr(src.str), &err), err)
}

pub fn to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_ast(charptr(src.str), &err), err)
}

pub fn to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_json(charptr(src.str), &err), err)
}

pub fn to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_yaml(charptr(src.str), &err), err)
}

pub fn to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_toml(charptr(src.str), &err), err)
}

// ── XML input ─────────────────────────────────────────────────────────────────

pub fn xml_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_cx(charptr(src.str), &err), err)
}

pub fn xml_to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_xml(charptr(src.str), &err), err)
}

pub fn xml_to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_ast(charptr(src.str), &err), err)
}

pub fn xml_to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_json(charptr(src.str), &err), err)
}

pub fn xml_to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_yaml(charptr(src.str), &err), err)
}

pub fn xml_to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_toml(charptr(src.str), &err), err)
}

// ── JSON input ────────────────────────────────────────────────────────────────

pub fn json_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_cx(charptr(src.str), &err), err)
}

pub fn json_to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_xml(charptr(src.str), &err), err)
}

pub fn json_to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_ast(charptr(src.str), &err), err)
}

pub fn json_to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_json(charptr(src.str), &err), err)
}

pub fn json_to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_yaml(charptr(src.str), &err), err)
}

pub fn json_to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_toml(charptr(src.str), &err), err)
}

// ── YAML input ────────────────────────────────────────────────────────────────

pub fn yaml_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_cx(charptr(src.str), &err), err)
}

pub fn yaml_to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_xml(charptr(src.str), &err), err)
}

pub fn yaml_to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_ast(charptr(src.str), &err), err)
}

pub fn yaml_to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_json(charptr(src.str), &err), err)
}

pub fn yaml_to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_yaml(charptr(src.str), &err), err)
}

pub fn yaml_to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_toml(charptr(src.str), &err), err)
}

// ── TOML input ────────────────────────────────────────────────────────────────

pub fn toml_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_cx(charptr(src.str), &err), err)
}

pub fn toml_to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_xml(charptr(src.str), &err), err)
}

pub fn toml_to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_ast(charptr(src.str), &err), err)
}

pub fn toml_to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_json(charptr(src.str), &err), err)
}

pub fn toml_to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_yaml(charptr(src.str), &err), err)
}

pub fn toml_to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_toml(charptr(src.str), &err), err)
}

pub fn toml_to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_toml_to_md(charptr(src.str), &err), err)
}

// ── CX → MD ───────────────────────────────────────────────────────────────────

pub fn to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_to_md(charptr(src.str), &err), err)
}

// ── Other → MD ───────────────────────────────────────────────────────────────

pub fn xml_to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_xml_to_md(charptr(src.str), &err), err)
}

pub fn json_to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_json_to_md(charptr(src.str), &err), err)
}

pub fn yaml_to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_yaml_to_md(charptr(src.str), &err), err)
}

// ── MD input ──────────────────────────────────────────────────────────────────

pub fn md_to_cx(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_cx(charptr(src.str), &err), err)
}

pub fn md_to_xml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_xml(charptr(src.str), &err), err)
}

pub fn md_to_ast(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_ast(charptr(src.str), &err), err)
}

pub fn md_to_json(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_json(charptr(src.str), &err), err)
}

pub fn md_to_yaml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_yaml(charptr(src.str), &err), err)
}

pub fn md_to_toml(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_toml(charptr(src.str), &err), err)
}

pub fn md_to_md(src string) !string {
	mut err := charptr(0)
	return unwrap(C.cx_md_to_md(charptr(src.str), &err), err)
}

// ── CXL evaluation (spec/cxl.md / ADR 0016, capability bit 28) ───────────────
//
// `output_target` may be '' (honour the program's `[?cx output-target=…]`
// directive, defaulting to `text`) or one of `text` / `cx` / `html` at
// CXL 1.0 (v0.6.0). Additional targets land at v0.7.0+.
pub fn eval_cxl(cx_input string, cxl_program string, output_target string) !string {
	mut err := charptr(0)
	target_ptr := if output_target == '' { charptr(0) } else { charptr(output_target.str) }
	return unwrap(C.cx_eval_cxl(charptr(cx_input.str), charptr(cxl_program.str), target_ptr, &err), err)
}
