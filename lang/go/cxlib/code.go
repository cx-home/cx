// code.go — v0.8.0 Layer-1 CX code surface for the Go binding.
//
// Per `spec/bindings.md` §2.1 every binding exposes the canonical
// 16-method Layer-1 surface for parsing, hashing, evaluating, and
// modifying CX documents. The Go binding adapts the canonical names
// to PascalCase per Go's exported-identifier convention.
//
// This module wires the v0.8.0 additions to the existing `cxlib`
// foundation (`Parse` / `Document` / `EvalCode` from cxlib.go +
// ast.go):
//
//   * `CxCodeEval` — canonical PascalCase alias of `EvalCode` (the
// C ABI symbol is `cx_code_eval`). Identical
//     semantics; the name here mirrors the C ABI for Layer-1
//     conformance fixtures (`conformance/binding_api.txt`).
//   * `CxCodeDiagram(source, format) (string, error)` — wasm-safe
// Mermaid emit (cap bit 31). Only
//     `"mermaid"` is supported at v0.8.0; SVG / PNG are CLI-only.
//   * `CxCodeTree(source) (map[string]interface{}, error)` — JSON
// projection of the parsed source (cap bit 32).
//     Every node carries ``{kind, name?, value?, loc:{start,end},
//     children?}``; byte offsets enable the bidirectional selection
//     bridge. Phase 2.11 stub returns a minimal-shape root; the
//     wrapper is forward-compatible with the full walker.
//
// The Layer-1 `Doc` / `Node` façade lives below the C-ABI wrappers
// and wraps the existing `Document` + `Element` types.
//
// Per `spec/bindings.md` §2.1 the canonical 16 methods (PascalCase
// adapted) are:
//
//     Parse(bytes) -> Doc                  // module-level
//     Doc.Bytes() -> []byte
//     Doc.Hash() -> string
//     Doc.Equals(other) -> bool
//     Doc.Eval(code) -> string
//     Doc.SelectAll(cxpath) -> []Node
//     Doc.Select(cxpath) -> *Node          // nil when no match
//     Doc.Modify(focus, action) -> Doc
//     Doc.FindAll(name) -> []Node
//     Doc.Root() -> *Node
//     Node.Name() -> string
//     Node.Attr(name) -> any
//     Node.Attrs() -> map[string]any
//     Node.Children() -> []Node
//     Node.Body() -> any
//     Node.Kind() -> string
//
// Plus the three free-function atoms (`Atom`, `IsAtom`, `AtomName`)
// already shipped in `atom.go` — not part of the
// 16 Doc/Node methods.

package cxlib

/*
#include "cx.h"
#include <stdlib.h>
// cx_code_tree is exported from vcx/cx/cabi.v (Phase 2.11)
// but not yet declared in include/cx.h. Forward-declare here to keep
// the binding's Layer-1 surface in lockstep with the V-side export.
extern char* cx_code_tree(const char* source, size_t source_len, size_t* out_len);
*/
import "C"
import (
	"encoding/json"
	"fmt"
	"strings"
	"unsafe"
)

// ── Layer-1 free functions ──────────────────────────────────────────────────

// CxCodeEval evaluates a CX program against an optional input
// document per `spec/code.md` and returns the rendered output. It is
// a thin PascalCase alias for `EvalCode`; the underlying C ABI symbol
// is `cx_code_eval_with_len` (canonical name). The
// alias exists so Layer-1 conformance fixtures (which name methods
// after the C ABI symbols verbatim) bind through cleanly.
func CxCodeEval(source, program, outputTarget string) (string, error) {
	return EvalCode(source, program, outputTarget)
}

// CxCodeDiagram renders a CX program / source to a diagram
// representation. Wasm-safe Mermaid emit (cap
// bit 31). Only `"mermaid"` is supported at v0.8.0; SVG / PNG are
// CLI-only (graphviz shell-out, not exposed via libcx).
//
// Error wire format follows the in-band `CXERnnnn:msg` convention
// per `spec/abi.md §2.16.2`. The returned error contains the full
// prefixed message so callers can match on the wire code.
func CxCodeDiagram(source, format string) (string, error) {
	if format == "" {
		format = "mermaid"
	}
	srcLen := C.size_t(len(source))
	fmtLen := C.size_t(len(format))
	var csrc *C.char
	if len(source) > 0 {
		csrc = C.CString(source)
		defer C.free(unsafe.Pointer(csrc))
	}
	cfmt := C.CString(format)
	defer C.free(unsafe.Pointer(cfmt))

	raw := C.cx_code_diagram(csrc, srcLen, cfmt, fmtLen)
	if raw == nil {
		return "", fmt.Errorf("cx_code_diagram: null return (allocation failure)")
	}
	out := C.GoString(raw)
	C.cx_free(raw)
	if strings.HasPrefix(out, "CXER") && len(out) >= 9 && out[8] == ':' {
		return "", fmt.Errorf("%s", out)
	}
	return out, nil
}

// CxCodeTree returns the JSON projection of the parsed CX source per
// (cap bit 32). The returned map carries at minimum a
// top-level “{kind, name, loc:{start,end}}“ element; nested
// “children“ and per-node “value“ / “name“ fields appear as
// the walker materialises them. Byte offsets in “loc“ index into
// the original UTF-8 source.
//
// Phase 2.11 (`vcx/cx/cabi.v`) ships the real walker; empty / NULL
// input returns the minimal-root shape. The wrapper here is
// forward-compatible across the stub-vs-walker transition.
func CxCodeTree(source string) (map[string]any, error) {
	srcLen := C.size_t(len(source))
	var csrc *C.char
	if len(source) > 0 {
		csrc = C.CString(source)
		defer C.free(unsafe.Pointer(csrc))
	}
	var outLen C.size_t
	raw := C.cx_code_tree(csrc, srcLen, &outLen)
	if raw == nil {
		return nil, fmt.Errorf("cx_code_tree: NULL return (allocation failure)")
	}
	defer C.cx_free(raw)
	// out_len is the byte length of the JSON payload (NUL not
	// included), matching the v0.8.0 length-out-parameter convention.
	var text string
	if outLen > 0 {
		text = C.GoStringN(raw, C.int(outLen))
	} else {
		text = C.GoString(raw)
	}
	var result map[string]any
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		return nil, fmt.Errorf("cx_code_tree: payload is not valid JSON: %w", err)
	}
	return result, nil
}

// ── Layer-1 Doc / Node façades (spec/bindings.md §2.1) ──────────────────────
//
// Wrappers around the existing `cxlib.Document` + `Element` types
// that expose the canonical 16-method surface. These do NOT replace
// the dataclass-style AST API — they sit alongside it as a stable
// Layer-1 contract. Test-suite fixtures (`conformance/binding_api.txt`)
// bind against the names defined here.

// CodeNode is the Layer-1 wrapper around `*Element`.
//
// (The name `Node` is already taken by `cxlib.Node` — the marker
// interface for all AST node types. `CodeNode` is the Doc/Node façade
// node per spec/bindings.md §2.1; per the spec it would be called
// `Node`, but Go's single-namespace package rule forces the rename.
// Layer-2 idioms re-export it as `cxlib.idioms.Node` for clean usage.)
type CodeNode struct {
	el *Element
}

// Name — Layer-1 method 11. Element name.
func (n *CodeNode) Name() string {
	if n == nil || n.el == nil {
		return ""
	}
	return n.el.Name
}

// Attr — Layer-1 method 12. Attribute value, or nil when not found.
func (n *CodeNode) Attr(name string) any {
	if n == nil || n.el == nil {
		return nil
	}
	return n.el.Attr(name)
}

// Attrs — Layer-1 method 13. All attributes as a map.
func (n *CodeNode) Attrs() map[string]any {
	out := map[string]any{}
	if n == nil || n.el == nil {
		return out
	}
	for _, a := range n.el.Attrs {
		out[a.Name] = a.Value
	}
	return out
}

// Children — Layer-1 method 14. Direct child elements wrapped as
// CodeNodes (non-element items are skipped — see Body() for raw access).
func (n *CodeNode) Children() []CodeNode {
	if n == nil || n.el == nil {
		return nil
	}
	kids := n.el.Children()
	out := make([]CodeNode, len(kids))
	for i, c := range kids {
		out[i] = CodeNode{el: c}
	}
	return out
}

// Body — Layer-1 method 15. Element body value.
//
// Prefers the first scalar-typed value (preserves int / bool / atom
// round-trip); falls back to the concatenated text content; finally
// falls back to the raw items list when the element carries only
// structural children.
func (n *CodeNode) Body() any {
	if n == nil || n.el == nil {
		return nil
	}
	if s := n.el.Scalar(); s != nil {
		return s
	}
	if t := n.el.Text(); t != "" {
		return t
	}
	return n.el.Items
}

// Kind — Layer-1 method 16. Returns "element" for the CodeNode façade
// (which only wraps Elements). Per spec/bindings.md the kind taxonomy
// is one of element / scalar / sequence / array / map / path; the
// Element wrapper is always "element".
func (n *CodeNode) Kind() string {
	if n == nil || n.el == nil {
		return ""
	}
	return "element"
}

// Element exposes the underlying `*Element` for Layer-2 callers that
// need the full Element API (FindAll, SetAttr, …). Not part of the
// 16-method Layer-1 surface.
func (n *CodeNode) Element() *Element {
	if n == nil {
		return nil
	}
	return n.el
}

// Doc is the Layer-1 Doc façade per `spec/bindings.md` §2.1.
//
// Holds the canonical CX bytes plus a parsed `*Document`. Methods
// that return a new Doc do NOT mutate the receiver (pure-functional
// contract).
type Doc struct {
	bytes []byte
	doc   *Document
}

// ParseDoc parses canonical CX bytes into a Doc value (Layer-1
// method 1). The function-level constructor mirrors the spec's
// `parse(bytes) -> Doc` signature; `DocParse` is also exposed as a
// shorter alias.
//
// Note: the existing `cxlib.Parse(string)` returns a `*Document`
// (the AST) and remains unchanged; ParseDoc is the Layer-1 façade
// constructor that wraps it.
func ParseDoc(source []byte) (Doc, error) {
	doc, err := Parse(string(source))
	if err != nil {
		// Wrap parser failures with the Layer-1 wire code per
		// spec/bindings.md §2.4 ("cx-err:CXER0100" — malformed input).
		// V's eval_code emits the same prefix via EvalError{code,
		// message}; this keeps Go's parse-error wire format identical.
		return Doc{}, &CxError{Code: "cx-err:CXER0100", Message: err.Error(), Wrapped: err}
	}
	return Doc{bytes: append([]byte(nil), source...), doc: doc}, nil
}

// CxError is the Layer-1 binding error type per spec/bindings.md §2.4.
// It carries the wire-format CX error code (`cx-err:CXERnnnn`) so
// every binding surfaces identical error tokens across hosts.
type CxError struct {
	Code    string
	Message string
	Wrapped error
}

func (e *CxError) Error() string {
	return e.Code + ": " + e.Message
}

func (e *CxError) Unwrap() error { return e.Wrapped }

// DocParse is a shorthand for ParseDoc — matches the Pythonic
// `Doc.parse(...)` classmethod entry point and keeps the
// Doc.<verb>() shape inside Layer-2 idioms.
func DocParse(source []byte) (Doc, error) { return ParseDoc(source) }

// Bytes — Layer-1 method 2. Serialize Doc to canonical CX bytes.
func (d Doc) Bytes() []byte {
	if d.doc == nil {
		return nil
	}
	return []byte(d.doc.ToCx())
}

// Hash — Layer-1 method 3. SHA-256 hex of the strict-canonical
// bytes (spec/abi.md §2.6). Routes through libcx's `cx_hash`.
func (d Doc) Hash() (string, error) {
	if d.doc == nil {
		return "", fmt.Errorf("Doc.Hash: empty document")
	}
	return Hash(d.doc.ToCx())
}

// Equals — Layer-1 method 4. Canonical-bytes equality. Two Docs
// compare equal iff `cx_canonical` yields the same bytes for both.
func (d Doc) Equals(other Doc) (bool, error) {
	if d.doc == nil || other.doc == nil {
		return d.doc == other.doc, nil
	}
	return Eq(d.doc.ToCx(), other.doc.ToCx())
}

// Eval — Layer-1 method 5. Evaluate a CX code program against this
// Doc; wraps `cx_code_eval`. The optional
// outputTarget defaults to "" (text) when omitted.
func (d Doc) Eval(code string, outputTarget ...string) (string, error) {
	target := ""
	if len(outputTarget) > 0 {
		target = outputTarget[0]
	}
	src := ""
	if d.doc != nil {
		src = d.doc.ToCx()
	}
	return EvalCode(src, code, target)
}

// SelectAll — Layer-1 method 6. Evaluate a CXPath value expression
// and return the matching nodes.
//
// CXPath is a first-class value kind (`spec/code.md §5.5`):
// evaluating `//user` directly yields a sequence of matching nodes.
func (d Doc) SelectAll(cxpath string) ([]CodeNode, error) {
	if d.doc == nil {
		return nil, nil
	}
	out, err := EvalCode(d.doc.ToCx(), cxpath, "cx")
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(out) == "" {
		return nil, nil
	}
	// Wrap matches in a synthetic root so we can re-parse the
	// concatenated CX bytes into a Document and extract one Element
	// per top-level match. CXPath value evaluation newline-separates
	// matching nodes in the "cx" output target.
	wrapped := "[matches\n" + out + "]"
	parsed, err := Parse(wrapped)
	if err != nil {
		// Fall back: each line might be a bare scalar — return empty
		// rather than surface a confusing parse error from the wrap.
		return nil, nil
	}
	root := parsed.Root()
	if root == nil {
		return nil, nil
	}
	out2 := make([]CodeNode, 0, len(root.Items))
	for _, item := range root.Items {
		if el, ok := item.(*Element); ok {
			out2 = append(out2, CodeNode{el: el})
		}
	}
	return out2, nil
}

// Select — Layer-1 method 7. First match of SelectAll, or nil when
// the path matches nothing.
func (d Doc) Select(cxpath string) (*CodeNode, error) {
	matches, err := d.SelectAll(cxpath)
	if err != nil {
		return nil, err
	}
	if len(matches) == 0 {
		return nil, nil
	}
	first := matches[0]
	return &first, nil
}

// Modify — Layer-1 method 8. Pure-functional update.
// Returns a new Doc; the receiver is unchanged.
//
// `action` carries the trailing modify-action clause + args
// verbatim, e.g. “"[delete]"“, “"[set \"Alicia\"]"“,
// “"[rename component]"“. Layer-2 idioms supply higher-level
// constructors (`Set`, `Delete`, `Rename`, …).
func (d Doc) Modify(focus, action string) (Doc, error) {
	if d.doc == nil {
		return Doc{}, fmt.Errorf("Doc.Modify: empty document")
	}
	prog := fmt.Sprintf("[?modify $doc %s %s]", focus, action)
	out, err := EvalCode(d.doc.ToCx(), prog, "cx")
	if err != nil {
		return Doc{}, err
	}
	newDoc, err := Parse(out)
	if err != nil {
		return Doc{}, fmt.Errorf("Doc.Modify: re-parse failed: %w", err)
	}
	return Doc{bytes: []byte(out), doc: newDoc}, nil
}

// FindAll — Layer-1 method 9. Name-only convenience — no CXPath
// parse, depth-first walk through the document.
func (d Doc) FindAll(name string) []CodeNode {
	if d.doc == nil {
		return nil
	}
	hits := d.doc.FindAll(name)
	out := make([]CodeNode, len(hits))
	for i, e := range hits {
		out[i] = CodeNode{el: e}
	}
	return out
}

// Root — Layer-1 method 10. Root element of the document, or nil
// for an empty document.
func (d Doc) Root() *CodeNode {
	if d.doc == nil {
		return nil
	}
	r := d.doc.Root()
	if r == nil {
		return nil
	}
	return &CodeNode{el: r}
}

// ── Layer-1 code-projection helpers ──────────────────────────────
//
// Both pass the canonical CX bytes through `CxCodeDiagram` /
// `CxCodeTree`. Kept on Doc for ergonomic parity with `Eval()`.

// Diagram renders this Doc's source to a Mermaid diagram.
func (d Doc) Diagram(format ...string) (string, error) {
	target := "mermaid"
	if len(format) > 0 && format[0] != "" {
		target = format[0]
	}
	src := ""
	if d.doc != nil {
		src = d.doc.ToCx()
	}
	return CxCodeDiagram(src, target)
}

// Tree returns the JSON tree projection of this Doc's source
func (d Doc) Tree() (map[string]any, error) {
	src := ""
	if d.doc != nil {
		src = d.doc.ToCx()
	}
	return CxCodeTree(src)
}

// Document exposes the underlying `*Document` for callers that need
// the full Document API (ResolveID, ToXml, ToJson, …). Not part of
// the 16-method Layer-1 surface.
func (d Doc) Document() *Document { return d.doc }
