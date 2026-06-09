// CX V binding — v0.8.0 Layer-1 code surface + canonical Doc/Node.
//
// Per `spec/bindings.md` §2.1, every binding exposes a 16-method
// Layer-1 surface (10 Doc + 6 Node methods) for parsing, hashing,
// evaluating, modifying, and navigating CX documents. This file
// implements that surface for the V native binding (Phase 3.2 of
// `spec/v0_8_0_status.md`).
//
// V is the native reference implementation per `spec/bindings.md`
// §3.4 — Layer 2 IS Layer 1 because CX vocabulary is already
// idiomatic V. The methods below ARE the V surface; no separate
// idiom pack is required. A handful of instance-method shortcuts
// (`Doc.diagram()` / `Doc.tree()` / `Doc.eval()` over the free-
// function forms) ship alongside as ergonomic sugar.
//
// Layer-1 free functions wired here (D2):
//   - cx_code_eval(source, program, output_target) → string
//   - cx_code_diagram(source) → string (Mermaid; wasm-safe)
//   - cx_code_tree(source) → string (JSON projection)
//
// The 16-method canonical surface (`Doc` + `Node` types below):
//   parse(bytes) → Doc
//   Doc.bytes()            → bytes   (canonical CX)
//   Doc.hash()             → string  (SHA-256 hex of canonical bytes)
//   Doc.equals(other)      → bool    (canonical-bytes equality)
//   Doc.eval(code)         → string  (wraps cx_code_eval)
//   Doc.select_all(cxpath) → []Node  (CXPath value form)
//   Doc.select(cxpath)     → ?Node   (first match)
// Doc.modify(focus, action) → Doc (pure-functional)
//   Doc.find_all(name)     → []Node  (depth-first name match)
//   Doc.root()             → ?Node   (root element)
//   Node.name()            → string
//   Node.attr(name)        → ?cx.ScalarValue
//   Node.attrs()           → map[string]cx.ScalarValue
//   Node.children()        → []Node
//   Node.body()            → string  (textual / scalar payload)
//   Node.kind()            → string
//
// Error handling: every method returns `!` on failure; messages are
// `cx-err:CXERnnnn:...` per spec/bindings.md §2.4. Tests assert on
// the wire prefix, not the message text.

module native

import cx
import code

// ── Layer-1 free functions: cx_code_* ────────────────────────────────────────

// cx_code_eval evaluates a CX program against an optional source
// document and renders the result per `output_target`. Identical
// semantics to the C ABI symbol `cx_code_eval_with_len`
// §D5); the wrapper here just adapts V strings to the native
// `code.eval_code` entry point in vcx/code/api.v.
//
// `output_target == ''` defaults to text. Returns the rendered
// output; raises `cx-err:CXERnnnn:msg` on parse / eval / render
// failure.
pub fn cx_code_eval(source string, program string, output_target string) !string {
	return code.eval_code(source, program, output_target)!
}

// cx_code_diagram renders a CX program / source to a Mermaid diagram
// (cap bit 31). Wasm-safe — SVG / PNG forms remain
// CLI-only because graphviz is not linked into the wasm build.
//
// Format must be 'mermaid' at v0.8.0; other values raise CXER0100.
pub fn cx_code_diagram(source string) !string {
	if source.len == 0 {
		return error('cx-err:CXER0100: cx_code_diagram: source must be non-empty')
	}
	return code.code_diagram(source)!
}

// cx_code_tree returns the JSON projection of the parsed source per
// (cap bit 32). Each emitted node carries
// `{kind, name?, value?, loc:{start,end}, children?}`; the `loc`
// byte offsets index into the original UTF-8 source and enable the
// playground's bidirectional selection bridge.
//
// Empty / whitespace-only sources return `{"kind":"element",
// "name":"root","loc":{"start":0,"end":0},"children":[]}` (per
// `vcx/cx/code_tree.v`). The wrapper here returns the JSON string
// verbatim — callers decode into a host map / json2.Any when
// they need structured access.
pub fn cx_code_tree(source string) !string {
	return cx.code_tree(source)!
}

// ── Layer-1 canonical types: Doc + Node ──────────────────────────────────────
//
// Doc wraps a parsed `cx.Document` plus the canonical CX bytes used
// for equality / hashing (`spec/abi.md §2.6`). All mutating methods
// return a NEW Doc — the receiver is unchanged (pure-functional
// contract). The wrapped `Document` is exposed
// read-only via `.document()` for callers that want the full V
// native API.
//
// Node is a thin façade over `cx.Element` exposing the 6-method
// canonical accessor surface. Non-element node kinds (Text, Scalar,
// CDATA, …) are NOT wrapped — Layer-1 navigation operates over the
// element spine, matching the Python / Go / Rust bindings.

pub struct Doc {
pub:
	source string // canonical CX bytes
	doc    cx.Document
}

pub struct Node {
pub:
	element cx.Element
}

// ── Method 1: parse(bytes) → Doc ─────────────────────────────────────────────

// parse_doc parses canonical CX bytes into a Doc value. Errors carry
// the `cx-err:CXER0100:` wire prefix on parse failure.
//
// Named `parse_doc` rather than `parse` because the existing
// `native.parse` (in native.v) returns a `cx.Document` directly; the
// Layer-1 Doc façade is a strictly additive surface.
pub fn parse_doc(source string) !Doc {
	doc := cx.parse(source) or {
		return error('cx-err:CXER0100: parse: ${err.msg()}')
	}
	return Doc{
		source: source
		doc:    doc
	}
}

// ── Method 2: Doc.bytes() → bytes (canonical CX) ─────────────────────────────

// bytes returns the strict-canonical CX bytes for this Doc per
// `spec/abi.md §2.6`. Two Docs that parse the same logical content
// produce byte-identical results; the value is what
// `spec/bindings.md §2.1` calls "the wire form".
pub fn (d Doc) bytes() string {
	return cx.cx_text_canonical(d.source) or {
		// Defensive fallback: if canonicalisation fails, emit the raw
		// emitter form. Should never happen for a Doc that already
		// parsed; kept here so `.bytes()` never raises.
		cx.emit_cx(d.doc)
	}
}

// ── Method 3: Doc.hash() → string (SHA-256 hex of canonical bytes) ───────────

// hash returns the SHA-256 hex digest of `d.bytes()` per
// `spec/abi.md §2.6`. Matches the C ABI `cx_hash` symbol byte-for-
// byte.
pub fn (d Doc) hash() !string {
	return cx.cx_text_hash(d.source)!
}

// ── Method 4: Doc.equals(other) → bool ───────────────────────────────────────

// equals compares two Docs by their canonical bytes. Equivalent to
// `d.bytes() == other.bytes()` but without allocating both sides.
pub fn (d Doc) equals(other Doc) !bool {
	return cx.cx_text_eq(d.source, other.source)!
}

// ── Method 5: Doc.eval(code) → Value ─────────────────────────────────────────

// eval evaluates a CX program against this Doc and returns the
// rendered output. Wraps `cx_code_eval` with `output_target='text'`;
// callers wanting a different render target use the free-function
// `cx_code_eval(source, program, target)`.
pub fn (d Doc) eval(program string) !string {
	return cx_code_eval(d.source, program, '')!
}

// eval_to renders the eval result via the given `output_target` per
// `spec/code.md §10.1`. Recognised targets include `'text'`, `'cx'`,
// `'json'`, `'xml'`, `'yaml'`, `'csv'`, `'tsv'`, `'mermaid'`.
pub fn (d Doc) eval_to(program string, output_target string) !string {
	return cx_code_eval(d.source, program, output_target)!
}

// ── Method 6: Doc.select_all(cxpath) → [Node] ────────────────────────────────

// select_all evaluates a CXPath value expression and
// returns the matching elements. Non-element results (scalars,
// attribute values, aggregates) raise CXER0100 — use `.eval()` for
// those shapes per `lang/python/cxlib/ast.py:select_all` parity.
pub fn (d Doc) select_all(cxpath string) ![]Node {
	out := cx_code_eval(d.source, cxpath, 'cx')!
	if out.trim_space().len == 0 {
		return []Node{}
	}
	result := cx.parse(out) or {
		return error('cx-err:CXER0100: select_all: result is not element-shaped (use eval for scalar / attribute / aggregate results): ${err.msg()}')
	}
	mut nodes := []Node{}
	for n in result.elements {
		if n is cx.Element {
			nodes << Node{element: n}
		}
	}
	return nodes
}

// ── Method 7: Doc.select(cxpath) → Node? ─────────────────────────────────────

// select returns the first match of `select_all(cxpath)`, or an
// error when the path matches nothing. Use `select_all(...).len`
// instead when an empty result is non-exceptional. The error wire
// prefix `CXER0103` signals "no match" per `spec/bindings.md §2.4`
// (Layer-1 errors are codes, not nil values — callers branch on
// the code).
pub fn (d Doc) select(cxpath string) !Node {
	matches := d.select_all(cxpath)!
	if matches.len == 0 {
		return error('cx-err:CXER0103: select: no match for "${cxpath}"')
	}
	return matches[0]
}

// ── Method 8: Doc.modify(focus, action) → Doc ────────────────────────────────

// modify applies a pure-functional update at `focus` (a CXPath
// expression) per `action` (the trailing modify-action clause, e.g.
// `'[delete]'`, `'[set "Alicia"]'`, `'[rename component]'`). Returns a
// NEW Doc; the receiver is unchanged (code.md §8.10).
//
// Routes through `[?modify $doc focus action]` mirroring the Python
// / Go / Rust bindings (spec/bindings.md §2.3).
pub fn (d Doc) modify(focus string, action string) !Doc {
	program := '[?modify $doc ${focus} ${action}]'
	out := cx_code_eval(d.source, program, 'cx')!
	return parse_doc(out)!
}

// ── Method 9: Doc.find_all(name) → [Node] ────────────────────────────────────

// find_all returns all descendant elements with the given name in
// depth-first order. Name-only convenience — no CXPath parse cost.
pub fn (d Doc) find_all(name string) []Node {
	mut result := []Node{}
	for n in d.doc.elements {
		if n is cx.Element {
			collect_by_name(n, name, mut result)
		}
	}
	return result
}

fn collect_by_name(e cx.Element, name string, mut result []Node) {
	if e.name == name {
		result << Node{element: e}
	}
	for item in e.items {
		if item is cx.Element {
			collect_by_name(item, name, mut result)
		}
	}
}

// ── Method 10: Doc.root() → Node? ────────────────────────────────────────────

// root returns the first top-level element, or none for an empty
// document.
pub fn (d Doc) root() ?Node {
	for n in d.doc.elements {
		if n is cx.Element {
			return Node{element: n}
		}
	}
	return none
}

// ── Layer-1 idiom shortcuts: diagram / tree on Doc ───────────────────────────
//
// V's Layer-2 IS Layer-1 (spec/bindings.md §3.4); these methods are
// the V-idiomatic counterparts to the `cx_code_*` free functions,
// kept on Doc for parity with `Doc.eval()`. The underlying call is
// identical — they pass `d.source` straight through.

// diagram returns the Mermaid diagram for this Doc's source per
pub fn (d Doc) diagram() !string {
	return cx_code_diagram(d.source)!
}

// tree returns the JSON tree projection for this Doc's source per
pub fn (d Doc) tree() !string {
	return cx_code_tree(d.source)!
}

// ── Node accessors (Methods 11..16) ──────────────────────────────────────────

// Method 11: Node.name() → string
pub fn (n Node) name() string {
	return n.element.name
}

// Method 12: Node.attr(name) → cx.ScalarValue?
pub fn (n Node) attr(name string) ?cx.ScalarValue {
	for a in n.element.attrs {
		if a.name == name {
			return a.value
		}
	}
	return none
}

// Method 13: Node.attrs() → map[string]cx.ScalarValue
pub fn (n Node) attrs() map[string]cx.ScalarValue {
	mut out := map[string]cx.ScalarValue{}
	for a in n.element.attrs {
		out[a.name] = a.value
	}
	return out
}

// Method 14: Node.children() → []Node (direct element children only)
pub fn (n Node) children() []Node {
	mut out := []Node{}
	for item in n.element.items {
		if item is cx.Element {
			out << Node{element: item}
		}
	}
	return out
}

// Method 15: Node.body() → string (concatenated text / scalar payload).
//
// The body of an element is the canonical surface text for its
// inline scalar / text content. Element children are skipped — use
// `.children()` to traverse the spine. Empty when the element
// carries only structural children.
pub fn (n Node) body() string {
	mut parts := []string{}
	for item in n.element.items {
		match item {
			cx.ScalarNode {
				parts << cx.scalar_value_str_public(item.value)
			}
			cx.TextNode {
				parts << item.value
			}
			else {}
		}
	}
	return parts.join('')
}

// Method 16: Node.kind() → string
//
// Returns "element" for all Node values (the Layer-1 wrapper only
// wraps cx.Element). Non-element node kinds are returned to callers
// via `.body()` as their string projection.
pub fn (n Node) kind() string {
	return 'element'
}
