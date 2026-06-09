// CX V binding — native variant.
//
// This module imports the V core (`cx` package, mirror of `vcx/cx/`)
// directly. No FFI on hot paths. This is the recommended V binding for
// V users; the fastest variant on the V VM.
//
// Per `spec/governance.md` §1, no public function in this module
// roundtrips through a sibling format converter and re-parses string
// output. Conversions go through the V core's `cx.convert` or the
// dedicated `cx.<x>_to_<y>` helpers, both of which build on the parsed
// AST directly. `loads` and `dumps` (in data.v) walk the AST natively
// without a JSON intermediate.

module native

import cx

// ── Types ─────────────────────────────────────────────────────────────────────
// Re-export the core types so callers can use `native.Document`,
// `native.Element`, etc. without a separate `import cx`. Type aliases
// preserve identity, so `native.Document` IS `cx.Document` (no
// conversion or copy needed when bridging).

pub type Document  = cx.Document
pub type Element   = cx.Element
pub type Attribute = cx.Attribute
pub type Format    = cx.Format

// ── Library version ──────────────────────────────────────────────────────────

// version returns the underlying CX library version string.
pub fn version() string {
	return '0.5.0'
}

// ── Parsing ──────────────────────────────────────────────────────────────────

// parse parses CX source into a Document. For multi-document input,
// use parse_stream.
pub fn parse(src string) !Document {
	return cx.parse(src)!
}

// parse_stream parses CX source containing one or more documents
// (separated by `---`) and returns the list.
//
// Type-alias quirk: V treats `pub type Document = cx.Document` as a
// distinct array element type, so `[]cx.Document` cannot directly
// satisfy `[]Document`. We rebuild the slice via explicit element
// casts — zero copy since the alias preserves identity, only the
// outer slice header is reallocated.
pub fn parse_stream(src string) ![]Document {
	docs := cx.parse_stream(src)!
	mut out := []Document{cap: docs.len}
	for d in docs {
		out << Document(d)
	}
	return out
}

// ── CX → other formats ───────────────────────────────────────────────────────

// to_cx normalizes CX source to canonical CX text.
pub fn to_cx(src string) !string { return cx.to_cx(src)! }

// to_cx_with_include_root normalizes CX source to canonical CX text
// with the spec/include.md §1-§8 resolver enabled (v0.7.0 GG3 / GG5).
// Empty `root` disables resolution (matches the no-include default
// of `to_cx`).
pub fn to_cx_with_include_root(src string, root string) !string {
	doc := cx.parse_with_include_root(src, root)!
	return cx.emit_cx(doc)
}

// to_cx_compact normalizes CX source to compact (single-line) CX text.
pub fn to_cx_compact(src string) !string { return cx.to_cx_compact(src)! }

// to_xml converts CX source to XML.
pub fn to_xml(src string) !string { return cx.to_xml(src)! }

// to_ast converts CX source to AST JSON (full parse-tree JSON).
pub fn to_ast(src string) !string { return cx.to_ast(src)! }

// to_json converts CX source to semantic JSON.
pub fn to_json(src string) !string { return cx.to_json(src)! }

// to_yaml converts CX source to YAML.
pub fn to_yaml(src string) !string { return cx.to_yaml(src)! }

// to_toml converts CX source to TOML.
pub fn to_toml(src string) !string { return cx.to_toml(src)! }

// ast_to_cx converts AST JSON back to canonical CX.
pub fn ast_to_cx(src string) !string { return cx.ast_to_cx(src)! }

// ast_from emits AST-JSON directly from a parsed ParseResult. The foreign
// format is parsed straight to the AST — NOT round-tripped through CX text.
// A CX-text round-trip (the old `cx.to_ast(cx.from_xml(src))` form) lossily
// reshapes the tree: XML mixed-content TextNodes re-parse as quoted string
// scalars and `cx:type` arrays re-parse as Array nodes. Mirrors the C ABI
// `cx_xml_to_ast` path (cabi.v).
fn ast_from(res cx.ParseResult) string {
	if res.is_multi {
		return cx.emit_ast_json_docs(res.multi or { [] })
	}
	return cx.emit_ast_json(res.single or { cx.Document{} })
}

// ── XML as input ─────────────────────────────────────────────────────────────

pub fn xml_to_cx(src string) !string { return cx.from_xml(src)! }
pub fn xml_to_xml(src string) !string { return cx.convert(src, .xml, .xml)! }
pub fn xml_to_ast(src string) !string { return ast_from(cx.parse_xml_cx(src)!) }
pub fn xml_to_json(src string) !string { return cx.convert(src, .xml, .json)! }
pub fn xml_to_yaml(src string) !string { return cx.convert(src, .xml, .yaml)! }
pub fn xml_to_toml(src string) !string { return cx.convert(src, .xml, .toml)! }

// ── JSON as input ────────────────────────────────────────────────────────────

pub fn json_to_cx(src string) !string { return cx.json_to_cx(src)! }
pub fn json_to_xml(src string) !string { return cx.convert(src, .json, .xml)! }
// json_to_ast — the element-synthesising `cx.parse_json_cx` was retired
// (conversions.md §4.1); JSON now parses via the lossless map-model codec
// (code-layer json_do_parse, installed as the `json` codec parser). Route
// through parse_to_doc, matching the C ABI's cx_json_to_ast.
pub fn json_to_ast(src string) !string { return cx.emit_ast_json(cx.parse_to_doc('json', src)!) }
pub fn json_to_json(src string) !string { return cx.convert(src, .json, .json)! }
pub fn json_to_yaml(src string) !string { return cx.convert(src, .json, .yaml)! }
pub fn json_to_toml(src string) !string { return cx.convert(src, .json, .toml)! }

// ── YAML as input ────────────────────────────────────────────────────────────

pub fn yaml_to_cx(src string) !string { return cx.yaml_to_cx(src)! }
pub fn yaml_to_xml(src string) !string { return cx.convert(src, .yaml, .xml)! }
pub fn yaml_to_ast(src string) !string { return ast_from(cx.parse_yaml_cx(src)!) }
pub fn yaml_to_json(src string) !string { return cx.convert(src, .yaml, .json)! }
pub fn yaml_to_yaml(src string) !string { return cx.convert(src, .yaml, .yaml)! }
pub fn yaml_to_toml(src string) !string { return cx.convert(src, .yaml, .toml)! }

// ── TOML as input ────────────────────────────────────────────────────────────

pub fn toml_to_cx(src string) !string { return cx.toml_to_cx(src)! }
pub fn toml_to_xml(src string) !string { return cx.convert(src, .toml, .xml)! }
pub fn toml_to_ast(src string) !string { return ast_from(cx.parse_toml_cx(src)!) }
pub fn toml_to_json(src string) !string { return cx.convert(src, .toml, .json)! }
pub fn toml_to_yaml(src string) !string { return cx.convert(src, .toml, .yaml)! }
pub fn toml_to_toml(src string) !string { return cx.convert(src, .toml, .toml)! }

// ── Generic converter ────────────────────────────────────────────────────────

// convert is a single entry point for any source/target format pair.
pub fn convert(src string, from Format, to Format) !string {
	return cx.convert(src, from, to)!
}
