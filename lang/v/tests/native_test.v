module main

import os
import x.json2
import native
import cffi

// Tests for the native V binding (lang/v/native/).
// Audit-fix verification: type fidelity preserved, no JSON detour,
// parity with cffi for the existing semantic-JSON projection.

const fixtures = os.join_path(os.dir(@FILE), '..', '..', '..', 'fixtures')

fn fx(name string) string {
	return os.read_file(os.join_path(fixtures, name)) or {
		panic('could not read fixture ${name}: ${err}')
	}
}

// ── Smoke ────────────────────────────────────────────────────────────────────

fn test_native_version_returns_string() {
	v := native.version()
	assert v.len > 0
}

fn test_native_parse_returns_document() {
	_ := native.parse(fx('api_config.cx')) or { assert false, err.msg(); return }
}

fn test_native_loads_returns_data() {
	data := native.loads(fx('api_config.cx')) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	assert 'config' in m
}

// ── Type fidelity (the audit-fix benefit) ────────────────────────────────────

fn test_native_loads_preserves_int() {
	src := '[count 42]'
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['count'] or { assert false, 'missing count'; return }
	assert v is i64, 'expected i64, got ${v.type_name()}'
	assert (v as i64) == 42
}

fn test_native_loads_preserves_float() {
	src := '[ratio 1.5]'
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['ratio'] or { assert false, 'missing ratio'; return }
	assert v is f64, 'expected f64, got ${v.type_name()}'
	assert (v as f64) == 1.5
}

fn test_native_loads_preserves_bool() {
	src := '[active true]'
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['active'] or { assert false, 'missing active'; return }
	assert v is bool, 'expected bool, got ${v.type_name()}'
	assert (v as bool) == true
}

fn test_native_loads_preserves_null() {
	src := '[empty null]'
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['empty'] or { assert false, 'missing empty'; return }
	assert v is json2.Null, 'expected json2.Null, got ${v.type_name()}'
}

fn test_native_loads_preserves_string() {
	src := "[name 'alice']"
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['name'] or { assert false, 'missing name'; return }
	assert v is string, 'expected string, got ${v.type_name()}'
	assert (v as string) == 'alice'
}

// ── Containers ───────────────────────────────────────────────────────────────

fn test_native_loads_array_of_ints() {
	src := '[ports 8080 8081 8082]'
	data := native.loads(src) or { assert false, err.msg(); return }
	m := data as map[string]json2.Any
	v := m['ports'] or { assert false, 'missing ports'; return }
	arr := v as []json2.Any
	assert arr.len == 3
	assert (arr[0] as i64) == 8080
	assert (arr[2] as i64) == 8082
}

fn test_native_loads_nested_map() {
	src := '[server [host=localhost port=8080]]'
	data := native.loads(src) or { assert false, err.msg(); return }
	outer := data as map[string]json2.Any
	server := outer['server'] or { assert false, 'missing server'; return }
	inner := server as map[string]json2.Any
	assert (inner['host'] as string) == 'localhost'
	assert (inner['port'] as i64) == 8080
}

// ── Round-trip ───────────────────────────────────────────────────────────────

fn test_native_dumps_round_trip() {
	src := '[server host=localhost port=8080 active=true]'
	data := native.loads(src) or { assert false, err.msg(); return }
	out := native.dumps(data) or { assert false, err.msg(); return }
	// Re-parse the dumped output and verify equivalent shape.
	data2 := native.loads(out) or { assert false, err.msg(); return }
	m2 := data2 as map[string]json2.Any
	assert 'server' in m2
	srv := m2['server'] or { assert false, 'lost server'; return }
	srv_map := srv as map[string]json2.Any
	assert (srv_map['host'] as string) == 'localhost'
	assert (srv_map['port'] as i64) == 8080
	assert (srv_map['active'] as bool) == true
}

fn test_native_dumps_rejects_top_level_array() {
	arr := json2.Any([json2.Any(i64(1)), json2.Any(i64(2))])
	if _ := native.dumps(arr) {
		assert false, 'expected error on top-level array'
	} else {
		assert err.msg().contains('map')
	}
}

// ── Parity vs cffi ────────────────────────────────────────────────────────────

fn test_native_parity_with_cffi_basic() {
	src := fx('api_config.cx')
	native_data := native.loads(src) or { assert false, err.msg(); return }
	cffi_data := cffi.loads(src) or { assert false, err.msg(); return }
	// Both should resolve to a top-level map containing 'config'.
	nm := native_data as map[string]json2.Any
	cm := cffi_data as map[string]json2.Any
	assert 'config' in nm
	assert 'config' in cm
}

fn test_native_parity_with_cffi_scalars() {
	src := fx('api_scalars.cx')
	native_data := native.loads(src) or { assert false, err.msg(); return }
	cffi_data := cffi.loads(src) or { assert false, err.msg(); return }
	// Both should produce maps with the same top-level keys.
	nm := native_data as map[string]json2.Any
	cm := cffi_data as map[string]json2.Any
	assert nm.keys().sorted() == cm.keys().sorted(),
		'top-level keys differ: native=${nm.keys()} cffi=${cm.keys()}'
}

// ── Format-conversion smoke ──────────────────────────────────────────────────

fn test_native_to_json_passthrough() {
	src := '[server host=localhost port=8080]'
	out := native.to_json(src) or { assert false, err.msg(); return }
	assert out.len > 0
	assert out.contains('localhost')
	assert out.contains('8080')
}

fn test_native_to_xml_passthrough() {
	src := '[server host=localhost]'
	out := native.to_xml(src) or { assert false, err.msg(); return }
	assert out.contains('<server')
	assert out.contains('localhost')
}

fn test_native_to_cx_normalization() {
	src := '[ a   b=1   c=2 ]'
	out := native.to_cx(src) or { assert false, err.msg(); return }
	// Should produce canonical CX. Exact form is tested by canonical
	// conformance fixtures elsewhere; here we just verify it returns
	// something non-empty and well-formed.
	assert out.contains('a')
	assert out.contains('b=1')
	assert out.contains('c=2')
}
