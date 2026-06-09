// Package cxlib — CX Document API: types, parse, query, mutation, CX emitter.
package cxlib

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// ── Node interface ────────────────────────────────────────────────────────────

// Node is the common interface for all AST node types.
type Node interface{ cxNode() }

// ── Attr ─────────────────────────────────────────────────────────────────────

// Attr represents an element attribute (name=value pair).
type Attr struct {
	Name     string
	Value    any    // string | int64 | float64 | bool | nil
	DataType string // "" means string (omitted in JSON)
	// v3.4: expanded-name fields populated by
	// resolveNamespaces(). Local is the part after the first ':' in
	// Name (or the whole name); NsURI is the resolved URI. Per XML
	// Namespaces 1.0 §6.2 the default namespace does not apply to
	// unprefixed attributes — NsURI stays empty for them.
	Local string
	NsURI string // "" when no binding is in scope and prefix is not reserved
	// v3.4: true when the source attribute value was a bare
	// `@id` reference token. Quoted strings starting with '@' have
	// IsRef = false. Round-trip preserves the bare form on emit.
	IsRef bool
	// BracketBody attribute value — `name=[BodyItem*]`.
	// When non-nil, Value is unused and the attribute's content is the
	// parsed body sequence. Used by code-evaluation directives like
	// `[?if [cond, then-body, else-body]]`. Round-trips as opaque
	// structure (R5).
	Body []Node
}

// LocalName returns the part of Name after the first ':' (or the whole
// name when no colon is present).
func (a Attr) LocalName() string { return a.Local }

// NamespaceURI returns the resolved namespace URI for prefixed
// attributes; empty string for unprefixed or unbound prefixes.
func (a Attr) NamespaceURI() string { return a.NsURI }

// ── Concrete node types ───────────────────────────────────────────────────────

// TextNode is an inline text node.
type TextNode struct{ Value string }

func (n *TextNode) cxNode() {}

// ScalarNode is a typed scalar value (int, float, bool, null, date, etc.).
type ScalarNode struct {
	DataType string
	Value    any // int64 | float64 | bool | nil | string
}

func (n *ScalarNode) cxNode() {}

// CommentNode is a CX comment `[- ... ]`.
type CommentNode struct{ Value string }

func (n *CommentNode) cxNode() {}

// RawTextNode is a raw text block `[# ... #]`.
type RawTextNode struct{ Value string }

func (n *RawTextNode) cxNode() {}

// EntityRefNode is `&name;`.
type EntityRefNode struct{ Name string }

func (n *EntityRefNode) cxNode() {}

// AliasNode is `[*name]`.
type AliasNode struct{ Name string }

func (n *AliasNode) cxNode() {}

// PINode is a processing instruction `[?target data]`.
type PINode struct {
	Target string
	Data   string
}

func (n *PINode) cxNode() {}

// XMLDeclNode is `[?xml version=... ]`.
type XMLDeclNode struct {
	Version    string
	Encoding   string
	Standalone string
}

func (n *XMLDeclNode) cxNode() {}

// CXDirectiveNode is `[?cx ...]`. v0.6.0 — directives may carry an
// `&anchor` and/or nested elements. Currently used by the standalone
// fragment form `[?cx frag &name [body :TYPE :flags]]` (spec
// schema.md §8). ast_bin format version 4 carries them; v1-3 decoders
// see attrs-only and leave Anchor/Items as nil/empty.
type CXDirectiveNode struct {
	Attrs  []Attr
	Anchor string // "" when none
	Items  []Node
}

func (n *CXDirectiveNode) cxNode() {}

// DoctypeDeclNode is `[!DOCTYPE ...]`.
type DoctypeDeclNode struct {
	Name       string
	ExternalID map[string]any
	IntSubset  []any
}

func (n *DoctypeDeclNode) cxNode() {}

// BlockContentNode is `[| ... |]`.
type BlockContentNode struct{ Items []Node }

func (n *BlockContentNode) cxNode() {}

// InterpolationNode is `[?=EXPR]`. EXPR is parsed as
// cxpath at evaluation time. ast_bin tag 0x0D.
type InterpolationNode struct{ Expr string }

func (n *InterpolationNode) cxNode() {}

// EvalDirectiveNode is `[?Name attrs body]`.
// Reserved EvalNames (if/for/with/cond/include/def/use/let/fn/match/try)
// parse into this node; the evaluator dispatches on Name. ast_bin
// tag 0x0E.
type EvalDirectiveNode struct {
	Name  string
	Attrs []Attr
	Items []Node
}

func (n *EvalDirectiveNode) cxNode() {}

// ── v0.8.0 collection value-kinds (ast_bin §4.3, tags 0x0F/0x10/0x11) ─────────
//
// Surface forms per CXDM §1.2 / canonical.md: SequenceNode `(a, b, c)` (flat),
// ArrayNode `[a, b, c]` (nested-preserving), MapNode `{k: v, k: v}`. These
// round-trip through the C ABI ast_bin wire format; the V encoder
// (vcx/cx/binary.v encode_node) emits them with tags 0x0F/0x10/0x11.

// SequenceNode is `(a, b, c)` — a flat sequence (ast_bin tag 0x0F).
type SequenceNode struct{ Items []Node }

func (n *SequenceNode) cxNode() {}

// ArrayNode is `[a, b, c]` — a nested-preserving array (ast_bin tag 0x10).
type ArrayNode struct{ Items []Node }

func (n *ArrayNode) cxNode() {}

// MapEntry is one `k: v` pair of a MapNode. Key is carried as a scalar
// type tag + canonical string per ast_bin §4.3.
type MapEntry struct {
	KeyType  string
	KeyValue any
	Value    Node
}

// MapNode is `{k: v, k: v}` — a map literal (ast_bin tag 0x11).
type MapNode struct{ Entries []MapEntry }

func (n *MapNode) cxNode() {}

// ── Element ───────────────────────────────────────────────────────────────────

// Element is the main structural node in a CX document.
type Element struct {
	Name     string
	Anchor   string
	Merge    string
	DataType string // type annotation e.g. "int[]"
	Attrs    []Attr
	Items    []Node
	// v3.4: expanded-name fields populated by
	// resolveNamespaces(). See Attr.
	Local string
	NsURI string
	// v3.4: syntactic ID declaration ("" when none). Set when
	// the source has a `#name` token immediately after the element name.
	// Distinct from Anchor and from user-data attributes literally named
	// "id".
	Id string
	// v3.4: body-position reference ("" when none). Set when
	// the source had `[ref @<name>]` (an element named `ref` whose body is
	// a single `@name` token). Carries the bare-ref target id; Name is
	// fixed to "ref" and Attrs/Items are empty in that case. Round-trips
	// across the C ABI via ast_bin v3+ (Phase 7.70).
	BodyRef string
	// v0.7.0 Z2 (spec/i18n.md §1.3): in-scope BCP 47 language tag.
	// Populated by ResolveNamespaces(). LangResolvedSet distinguishes
	// "no cx:lang in scope" (false) from "explicit cx:lang='' shadow"
	// (true with LangResolved == "").
	LangResolved    string
	LangResolvedSet bool
}

func (e *Element) cxNode() {}

// Lang returns the BCP 47 language tag in scope at this Element per
// spec/i18n.md §1.3. Returns "" when no cx:lang is in scope or when
// an ancestor's declaration was shadowed by an explicit cx:lang="".
func (e *Element) Lang() string {
	return e.LangResolved
}

// LocalName returns the part of Name after the first ':' (or the whole
// name when no colon is present).
func (e *Element) LocalName() string { return e.Local }

// NamespaceURI returns the resolved namespace URI for this element;
// empty string when no binding is in scope and the prefix is not
// reserved.
func (e *Element) NamespaceURI() string { return e.NsURI }

// Attr returns the value of the named attribute, or nil if not found.
func (e *Element) Attr(name string) any {
	for _, a := range e.Attrs {
		if a.Name == name {
			return a.Value
		}
	}
	return nil
}

// Text returns the concatenated text and scalar content of the element.
func (e *Element) Text() string {
	var parts []string
	for _, item := range e.Items {
		switch n := item.(type) {
		case *TextNode:
			parts = append(parts, n.Value)
		case *ScalarNode:
			if n.Value == nil {
				parts = append(parts, "null")
			} else {
				parts = append(parts, fmt.Sprintf("%v", n.Value))
			}
		}
	}
	return strings.Join(parts, " ")
}

// Scalar returns the value of the first ScalarNode child, or nil.
func (e *Element) Scalar() any {
	for _, item := range e.Items {
		if s, ok := item.(*ScalarNode); ok {
			return s.Value
		}
	}
	return nil
}

// Children returns all direct child Element nodes.
func (e *Element) Children() []*Element {
	var result []*Element
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok {
			result = append(result, el)
		}
	}
	return result
}

// Get returns the first direct child Element with the given name, or nil.
func (e *Element) Get(name string) *Element {
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok && el.Name == name {
			return el
		}
	}
	return nil
}

// GetAll returns all direct child Elements with the given name.
func (e *Element) GetAll(name string) []*Element {
	var result []*Element
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok && el.Name == name {
			result = append(result, el)
		}
	}
	return result
}

// FindAll returns all descendant Elements with the given name (depth-first).
func (e *Element) FindAll(name string) []*Element {
	var result []*Element
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok {
			if el.Name == name {
				result = append(result, el)
			}
			result = append(result, el.FindAll(name)...)
		}
	}
	return result
}

// FindFirst returns the first descendant Element with the given name (depth-first).
func (e *Element) FindFirst(name string) *Element {
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok {
			if el.Name == name {
				return el
			}
			if found := el.FindFirst(name); found != nil {
				return found
			}
		}
	}
	return nil
}

// At navigates by slash-separated path (e.g. "server/host").
func (e *Element) At(path string) *Element {
	parts := splitPath(path)
	cur := e
	for _, part := range parts {
		if cur == nil {
			return nil
		}
		cur = cur.Get(part)
	}
	return cur
}

// SetAttr upserts an attribute value.
func (e *Element) SetAttr(name string, value any, dataType string) {
	for i := range e.Attrs {
		if e.Attrs[i].Name == name {
			e.Attrs[i].Value = value
			e.Attrs[i].DataType = dataType
			return
		}
	}
	e.Attrs = append(e.Attrs, Attr{Name: name, Value: value, DataType: dataType})
}

// RemoveAttr removes an attribute by name.
func (e *Element) RemoveAttr(name string) {
	filtered := e.Attrs[:0]
	for _, a := range e.Attrs {
		if a.Name != name {
			filtered = append(filtered, a)
		}
	}
	e.Attrs = filtered
}

// Append adds a child node to the end.
func (e *Element) Append(n Node) {
	e.Items = append(e.Items, n)
}

// Prepend adds a child node to the front.
func (e *Element) Prepend(n Node) {
	e.Items = append([]Node{n}, e.Items...)
}

// Insert inserts a child node at the given index.
func (e *Element) Insert(index int, n Node) {
	e.Items = append(e.Items, nil)
	copy(e.Items[index+1:], e.Items[index:])
	e.Items[index] = n
}

// Remove removes a child node by pointer identity.
func (e *Element) Remove(n Node) {
	filtered := e.Items[:0]
	for _, item := range e.Items {
		if item != n {
			filtered = append(filtered, item)
		}
	}
	e.Items = filtered
}

// RemoveChild removes all direct child Elements with the given name.
func (e *Element) RemoveChild(name string) {
	filtered := e.Items[:0]
	for _, item := range e.Items {
		if el, ok := item.(*Element); ok && el.Name == name {
			continue
		}
		filtered = append(filtered, item)
	}
	e.Items = filtered
}

// RemoveAt removes the child node at the given index (no-op if out of bounds).
func (e *Element) RemoveAt(index int) {
	if index < 0 || index >= len(e.Items) {
		return
	}
	e.Items = append(e.Items[:index], e.Items[index+1:]...)
}

// Element.Select / Element.SelectAll were CXPath thunks retired at
// v0.7.6 (Phase 7). Equivalent: cxlib.EvalCode with a CXPath `//path`
// value or a `[?for [pattern $m] :yield $m]` comprehension
// — see lang/go/cxlib/README.md migration table.

// ── Document ──────────────────────────────────────────────────────────────────

// Document is the top-level CX document.
type Document struct {
	Elements []Node
	Prolog   []Node
	Doctype  *DoctypeDeclNode
}

// Root returns the first top-level Element.
func (d *Document) Root() *Element {
	for _, e := range d.Elements {
		if el, ok := e.(*Element); ok {
			return el
		}
	}
	return nil
}

// Get returns the first top-level Element with the given name.
func (d *Document) Get(name string) *Element {
	for _, e := range d.Elements {
		if el, ok := e.(*Element); ok && el.Name == name {
			return el
		}
	}
	return nil
}

// At navigates by slash-separated path from root.
func (d *Document) At(path string) *Element {
	parts := splitPath(path)
	if len(parts) == 0 {
		return d.Root()
	}
	cur := d.Get(parts[0])
	if cur == nil || len(parts) == 1 {
		return cur
	}
	return cur.At(strings.Join(parts[1:], "/"))
}

// FindAll returns all descendant Elements with the given name (depth-first).
func (d *Document) FindAll(name string) []*Element {
	var result []*Element
	for _, e := range d.Elements {
		if el, ok := e.(*Element); ok {
			if el.Name == name {
				result = append(result, el)
			}
			result = append(result, el.FindAll(name)...)
		}
	}
	return result
}

// FindFirst returns the first descendant Element with the given name.
func (d *Document) FindFirst(name string) *Element {
	for _, e := range d.Elements {
		if el, ok := e.(*Element); ok {
			if el.Name == name {
				return el
			}
			if found := el.FindFirst(name); found != nil {
				return found
			}
		}
	}
	return nil
}

// ResolveID returns the Element declaring `#id`, or nil if no such
// declaration exists in the document. v3.4.
func (d *Document) ResolveID(id string) *Element {
	if el := findElementByID(d.Elements, id); el != nil {
		return el
	}
	return findElementByID(d.Prolog, id)
}

// ResolveBodyRef returns the Element targeted by e.BodyRef in this
// document, or nil when BodyRef is empty or the target ID is
// undeclared. v0.7.0 (second bullet).
func (d *Document) ResolveBodyRef(e *Element) *Element {
	if e == nil || e.BodyRef == "" {
		return nil
	}
	return d.ResolveID(e.BodyRef)
}

// ElementsByID returns a map from id-string to the Element declaring it.
// v3.4.
func (d *Document) ElementsByID() map[string]*Element {
	out := map[string]*Element{}
	collectElementsByID(d.Elements, out)
	collectElementsByID(d.Prolog, out)
	return out
}

func findElementByID(nodes []Node, id string) *Element {
	for _, n := range nodes {
		if el, ok := n.(*Element); ok {
			if el.Id == id {
				return el
			}
			if found := findElementByID(el.Items, id); found != nil {
				return found
			}
		}
	}
	return nil
}

func collectElementsByID(nodes []Node, out map[string]*Element) {
	for _, n := range nodes {
		if el, ok := n.(*Element); ok {
			if el.Id != "" {
				out[el.Id] = el
			}
			collectElementsByID(el.Items, out)
		}
	}
}

// Document.Select / Document.SelectAll / Document.Transform /
// Document.TransformAll were CXPath thunks + path-driven mutation
// helpers retired at v0.7.6 (Phase 7). Equivalent surfaces:
// selection → cxlib.EvalCode with a CXPath `//path` value
//   transformation → cxlib.EvalCode with a `[?for]` over `//path`
// See spec/code.md §5 + §7 and lang/go/cxlib/README.md.

// Append adds a top-level node to the end.
func (d *Document) Append(n Node) {
	d.Elements = append(d.Elements, n)
}

// Prepend adds a top-level node to the front.
func (d *Document) Prepend(n Node) {
	d.Elements = append([]Node{n}, d.Elements...)
}

// ToCx emits the document as a CX string using the native emitter.
func (d *Document) ToCx() string {
	return emitDoc(d)
}

// ToAstBin serializes this Document to a FRAMED [u32 LE size][payload]
// binary AST buffer. Used internally by ToXml / ToJson / etc. (Phase 5
// CB-1) and exported for callers that want to pass the document
// directly to libcx without round-tripping through CX text.
func (d *Document) ToAstBin() []byte {
	return encodeAST(d)
}

// v3.4 (Phase 5 / CB-1): format methods now go through
// cx_ast_bin_to_<fmt>(d.ToAstBin()) directly, avoiding the prior
// emit-CX-and-reparse detour.

// ToXml converts the document to XML via the C library.
func (d *Document) ToXml() (string, error) {
	return astBinToXml(d.ToAstBin())
}

// ToJson converts the document to JSON via the C library.
func (d *Document) ToJson() (string, error) {
	return astBinToJson(d.ToAstBin())
}

// ToYaml converts the document to YAML via the C library.
func (d *Document) ToYaml() (string, error) {
	return astBinToYaml(d.ToAstBin())
}

// ToToml converts the document to TOML via the C library.
func (d *Document) ToToml() (string, error) {
	return astBinToToml(d.ToAstBin())
}

// ── JSON deserialization ──────────────────────────────────────────────────────

func attrFromMap(m map[string]json.RawMessage) (Attr, error) {
	var name string
	if err := json.Unmarshal(m["name"], &name); err != nil {
		return Attr{}, err
	}
	var dataType string
	if raw, ok := m["dataType"]; ok {
		_ = json.Unmarshal(raw, &dataType)
	}
	val, err := unmarshalValue(m["value"])
	if err != nil {
		return Attr{}, err
	}
	return Attr{Name: name, Value: val, DataType: dataType}, nil
}

// unmarshalValue decodes a JSON RawMessage into a Go native value.
// Numbers are decoded as int64 if they are integer-valued, else float64.
func unmarshalValue(raw json.RawMessage) (any, error) {
	if raw == nil {
		return nil, nil
	}
	var generic any
	if err := json.Unmarshal(raw, &generic); err != nil {
		return nil, err
	}
	if generic == nil {
		return nil, nil
	}
	// json.Unmarshal decodes numbers as float64 by default.
	// Promote to int64 if the number is integral.
	if f, ok := generic.(float64); ok {
		if f == float64(int64(f)) {
			// check if the original token has a decimal point or exponent
			s := strings.TrimSpace(string(raw))
			if !strings.ContainsAny(s, ".eE") {
				return int64(f), nil
			}
		}
		return f, nil
	}
	return generic, nil
}

func nodeFromJSON(raw json.RawMessage) (Node, error) {
	var m map[string]json.RawMessage
	if err := json.Unmarshal(raw, &m); err != nil {
		return &TextNode{Value: string(raw)}, nil
	}
	var typeName string
	if err := json.Unmarshal(m["type"], &typeName); err != nil {
		return &TextNode{Value: string(raw)}, nil
	}

	switch typeName {
	case "Element":
		return elementFromMap(m)

	case "Text":
		var v string
		json.Unmarshal(m["value"], &v)
		return &TextNode{Value: v}, nil

	case "Scalar":
		var dt string
		json.Unmarshal(m["dataType"], &dt)
		val, _ := unmarshalValue(m["value"])
		return &ScalarNode{DataType: dt, Value: val}, nil

	case "Comment":
		var v string
		json.Unmarshal(m["value"], &v)
		return &CommentNode{Value: v}, nil

	case "RawText":
		var v string
		json.Unmarshal(m["value"], &v)
		return &RawTextNode{Value: v}, nil

	case "EntityRef":
		var name string
		json.Unmarshal(m["name"], &name)
		return &EntityRefNode{Name: name}, nil

	case "Alias":
		var name string
		json.Unmarshal(m["name"], &name)
		return &AliasNode{Name: name}, nil

	case "PI":
		var target, data string
		json.Unmarshal(m["target"], &target)
		if d, ok := m["data"]; ok {
			json.Unmarshal(d, &data)
		}
		return &PINode{Target: target, Data: data}, nil

	case "XMLDecl":
		var version, encoding, standalone string
		version = "1.0"
		if v, ok := m["version"]; ok {
			json.Unmarshal(v, &version)
		}
		if v, ok := m["encoding"]; ok {
			json.Unmarshal(v, &encoding)
		}
		if v, ok := m["standalone"]; ok {
			json.Unmarshal(v, &standalone)
		}
		return &XMLDeclNode{Version: version, Encoding: encoding, Standalone: standalone}, nil

	case "CXDirective":
		node := &CXDirectiveNode{}
		if rawAttrs, ok := m["attrs"]; ok {
			var arrRaw []json.RawMessage
			json.Unmarshal(rawAttrs, &arrRaw)
			for _, ar := range arrRaw {
				var am map[string]json.RawMessage
				json.Unmarshal(ar, &am)
				a, _ := attrFromMap(am)
				node.Attrs = append(node.Attrs, a)
			}
		}
		return node, nil

	case "DoctypeDecl":
		var name string
		json.Unmarshal(m["name"], &name)
		node := &DoctypeDeclNode{Name: name}
		if v, ok := m["externalID"]; ok {
			var extID map[string]any
			json.Unmarshal(v, &extID)
			node.ExternalID = extID
		}
		if v, ok := m["intSubset"]; ok {
			var subset []any
			json.Unmarshal(v, &subset)
			node.IntSubset = subset
		}
		return node, nil

	case "BlockContent":
		node := &BlockContentNode{}
		if rawItems, ok := m["items"]; ok {
			var arrRaw []json.RawMessage
			json.Unmarshal(rawItems, &arrRaw)
			for _, ir := range arrRaw {
				child, _ := nodeFromJSON(ir)
				node.Items = append(node.Items, child)
			}
		}
		return node, nil

	default:
		return &TextNode{Value: string(raw)}, nil
	}
}

func elementFromMap(m map[string]json.RawMessage) (*Element, error) {
	el := &Element{}
	json.Unmarshal(m["name"], &el.Name)
	if v, ok := m["anchor"]; ok {
		json.Unmarshal(v, &el.Anchor)
	}
	if v, ok := m["merge"]; ok {
		json.Unmarshal(v, &el.Merge)
	}
	if v, ok := m["dataType"]; ok {
		json.Unmarshal(v, &el.DataType)
	}
	if rawAttrs, ok := m["attrs"]; ok {
		var arrRaw []json.RawMessage
		json.Unmarshal(rawAttrs, &arrRaw)
		for _, ar := range arrRaw {
			var am map[string]json.RawMessage
			json.Unmarshal(ar, &am)
			a, err := attrFromMap(am)
			if err == nil {
				el.Attrs = append(el.Attrs, a)
			}
		}
	}
	if rawItems, ok := m["items"]; ok {
		var arrRaw []json.RawMessage
		json.Unmarshal(rawItems, &arrRaw)
		for _, ir := range arrRaw {
			child, err := nodeFromJSON(ir)
			if err == nil {
				el.Items = append(el.Items, child)
			}
		}
	}
	return el, nil
}

func docFromMap(m map[string]json.RawMessage) (*Document, error) {
	doc := &Document{}
	if rawProlog, ok := m["prolog"]; ok {
		var arrRaw []json.RawMessage
		json.Unmarshal(rawProlog, &arrRaw)
		for _, ir := range arrRaw {
			n, _ := nodeFromJSON(ir)
			doc.Prolog = append(doc.Prolog, n)
		}
	}
	if rawDoctype, ok := m["doctype"]; ok {
		var dm map[string]json.RawMessage
		if json.Unmarshal(rawDoctype, &dm) == nil {
			var name string
			json.Unmarshal(dm["name"], &name)
			dt := &DoctypeDeclNode{Name: name}
			if v, ok := dm["externalID"]; ok {
				var extID map[string]any
				json.Unmarshal(v, &extID)
				dt.ExternalID = extID
			}
			doc.Doctype = dt
		}
	}
	if rawElems, ok := m["elements"]; ok {
		var arrRaw []json.RawMessage
		json.Unmarshal(rawElems, &arrRaw)
		for _, ir := range arrRaw {
			n, _ := nodeFromJSON(ir)
			doc.Elements = append(doc.Elements, n)
		}
	}
	return doc, nil
}

// ── Namespace resolution (spec/namespaces.md) ──────────────────────
//
// Mirrors V core's vcx/cx/namespaces.v. Walks a parsed Document,
// populating Element.{Local, NsURI} and Attr.{Local, NsURI} based on
// in-scope xmlns / xmlns: declarations. Called at the tail of every
// parse entry point so consumers see a uniform expanded-name view.
//
// Reserved prefixes:
//   - `xml`   → http://www.w3.org/XML/1998/namespace
//   - `cx`    → https://cx-home.org/ns/cx
//   - `xmlns` → declaration-only; never resolves as a name prefix

const (
	XMLNamespaceURI = "http://www.w3.org/XML/1998/namespace"
	CXNamespaceURI  = "https://cx-home.org/ns/cx"
)

func splitNsPrefix(name string) (string, string) {
	for i := 0; i < len(name); i++ {
		if name[i] == ':' {
			return name[:i], name[i+1:]
		}
	}
	return "", name
}

func lookupNs(prefix string, scope []map[string]string) string {
	switch prefix {
	case "xml":
		return XMLNamespaceURI
	case "cx":
		return CXNamespaceURI
	case "xmlns":
		return ""
	}
	for i := len(scope) - 1; i >= 0; i-- {
		if uri, ok := scope[i][prefix]; ok {
			return uri // empty URI undeclares; we propagate the empty
		}
	}
	return ""
}

func resolveElement(e *Element, scope *[]map[string]string) {
	frame := map[string]string{}
	for _, a := range e.Attrs {
		switch {
		case a.Name == "xmlns":
			frame[""] = stringifyAttrValue(a.Value)
		case strings.HasPrefix(a.Name, "xmlns:") && len(a.Name) > 6:
			frame[a.Name[6:]] = stringifyAttrValue(a.Value)
		}
	}
	pushed := len(frame) > 0
	if pushed {
		*scope = append(*scope, frame)
	}

	prefix, local := splitNsPrefix(e.Name)
	e.Local = local
	e.NsURI = lookupNs(prefix, *scope)

	for i := range e.Attrs {
		ap, al := splitNsPrefix(e.Attrs[i].Name)
		e.Attrs[i].Local = al
		if e.Attrs[i].Name == "xmlns" || ap == "xmlns" {
			e.Attrs[i].NsURI = ""
			continue
		}
		if ap == "" {
			// Default ns does not apply to unprefixed attributes.
			e.Attrs[i].NsURI = ""
			continue
		}
		e.Attrs[i].NsURI = lookupNs(ap, *scope)
	}

	for _, item := range e.Items {
		if child, ok := item.(*Element); ok {
			resolveElement(child, scope)
		}
	}

	if pushed {
		*scope = (*scope)[:len(*scope)-1]
	}
}

func stringifyAttrValue(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprintf("%v", v)
}

// ResolveNamespaces populates Element.{Local, NsURI} and
// Attr.{Local, NsURI} on every node in doc
// spec/namespaces.md. Also propagates cx:lang inherited scope per
// spec/i18n.md §1.3 — sets Element.LangResolved on every Element.
// Idempotent. Called automatically by Parse, ParseXml, ParseJson,
// ParseYaml, ParseToml.
func ResolveNamespaces(doc *Document) {
	scope := []map[string]string{}
	for _, n := range doc.Elements {
		if el, ok := n.(*Element); ok {
			resolveElement(el, &scope)
		}
	}
	var langStack []langFrame
	for _, n := range doc.Elements {
		if el, ok := n.(*Element); ok {
			resolveElementLang(el, &langStack)
		}
	}
}

type langFrame struct {
	tag string
	set bool
}

// resolveElementLang propagates cx:lang per spec/i18n.md §1.3.
// Mirrors V's vcx/cx/namespaces.v::resolve_element_lang.
func resolveElementLang(el *Element, stack *[]langFrame) {
	var (
		ownTag   string
		declared bool
	)
	for _, a := range el.Attrs {
		if a.Name == "cx:lang" {
			ownTag, _ = a.Value.(string)
			declared = true
			break
		}
	}
	var resolved langFrame
	if declared {
		resolved = langFrame{tag: ownTag, set: true}
	} else if n := len(*stack); n > 0 {
		resolved = (*stack)[n-1]
	}
	el.LangResolved = resolved.tag
	el.LangResolvedSet = resolved.set
	*stack = append(*stack, resolved)
	for _, item := range el.Items {
		if child, ok := item.(*Element); ok {
			resolveElementLang(child, stack)
		}
	}
	*stack = (*stack)[:len(*stack)-1]
}

// ── Public parse / loads / dumps ──────────────────────────────────────────────

// Parse parses a CX string into a Document using the binary wire protocol.
func Parse(cxStr string, opts ...ParseOption) (*Document, error) {
	po := parseOptions{}
	for _, opt := range opts {
		opt(&po)
	}
	var data []byte
	var err error
	if po.includeRoot != "" {
		data, err = ToAstBinWithIncludeRoot(cxStr, po.includeRoot)
	} else {
		data, err = ToAstBin(cxStr)
	}
	if err != nil {
		return nil, err
	}
	doc, err := decodeAST(data)
	if err != nil {
		return nil, err
	}
	ResolveNamespaces(doc)
	return doc, nil
}

// ParseOption is a functional option for Parse.
type ParseOption func(*parseOptions)

type parseOptions struct {
	includeRoot string
}

// WithIncludeRoot opts into the spec/include.md §1-§8 ?include
// resolver (v0.7.0 GG4). The supplied path is the root directory
// against which every [?cx include=path] in the source is resolved;
// any escape past the root surfaces as cx-err:E902. Empty string is
// equivalent to omitting the option (no resolution).
func WithIncludeRoot(root string) ParseOption {
	return func(po *parseOptions) { po.includeRoot = root }
}

// v3.4 (Phase 5 / CB-2): parse_<format> goes through cx_<format>_to_ast_bin
// directly, avoiding the prior cx_<format>_to_ast → JSON.Unmarshal →
// walk-map pipeline. The cgo glue lives in cxlib.go (xmlToAstBin etc.)
// since cgo `C.` symbols are only visible there.

// ParseXml parses an XML string into a Document.
func ParseXml(xmlStr string) (*Document, error) {
	data, err := xmlToAstBin(xmlStr)
	if err != nil {
		return nil, err
	}
	doc, err := decodeAST(data)
	if err != nil {
		return nil, err
	}
	ResolveNamespaces(doc)
	return doc, nil
}

// ParseJson parses a JSON string into a Document.
func ParseJson(jsonStr string) (*Document, error) {
	data, err := jsonToAstBin(jsonStr)
	if err != nil {
		return nil, err
	}
	doc, err := decodeAST(data)
	if err != nil {
		return nil, err
	}
	ResolveNamespaces(doc)
	return doc, nil
}

// ParseYaml parses a YAML string into a Document.
func ParseYaml(yamlStr string) (*Document, error) {
	data, err := yamlToAstBin(yamlStr)
	if err != nil {
		return nil, err
	}
	doc, err := decodeAST(data)
	if err != nil {
		return nil, err
	}
	ResolveNamespaces(doc)
	return doc, nil
}

// ParseToml parses a TOML string into a Document.
func ParseToml(tomlStr string) (*Document, error) {
	data, err := tomlToAstBin(tomlStr)
	if err != nil {
		return nil, err
	}
	doc, err := decodeAST(data)
	if err != nil {
		return nil, err
	}
	ResolveNamespaces(doc)
	return doc, nil
}

// LoadsXml deserializes an XML string into native Go types (map/slice/scalar).
func LoadsXml(xmlStr string) (any, error) {
	jsonStr, err := XmlToJson(xmlStr)
	if err != nil {
		return nil, err
	}
	var result any
	if err := json.Unmarshal([]byte(jsonStr), &result); err != nil {
		return nil, fmt.Errorf("loads xml json unmarshal: %w", err)
	}
	return result, nil
}

// LoadsJson deserializes a JSON string into native Go types (map/slice/scalar).
func LoadsJson(jsonStr string) (any, error) {
	converted, err := JsonToJson(jsonStr)
	if err != nil {
		return nil, err
	}
	var result any
	if err := json.Unmarshal([]byte(converted), &result); err != nil {
		return nil, fmt.Errorf("loads json json unmarshal: %w", err)
	}
	return result, nil
}

// LoadsYaml deserializes a YAML string into native Go types (map/slice/scalar).
func LoadsYaml(yamlStr string) (any, error) {
	jsonStr, err := YamlToJson(yamlStr)
	if err != nil {
		return nil, err
	}
	var result any
	if err := json.Unmarshal([]byte(jsonStr), &result); err != nil {
		return nil, fmt.Errorf("loads yaml json unmarshal: %w", err)
	}
	return result, nil
}

// LoadsToml deserializes a TOML string into native Go types (map/slice/scalar).
func LoadsToml(tomlStr string) (any, error) {
	jsonStr, err := TomlToJson(tomlStr)
	if err != nil {
		return nil, err
	}
	var result any
	if err := json.Unmarshal([]byte(jsonStr), &result); err != nil {
		return nil, fmt.Errorf("loads toml json unmarshal: %w", err)
	}
	return result, nil
}

// Loads deserializes a CX string into native Go types (map/slice/scalar).
// Loads deserializes a CX string into native Go types.
//
// v3.4: parses through CXCol v1 (cx_to_data_bin) directly into Go
// types — no JSON-string detour. Type fidelity preserved: int stays
// int64, bool stays bool, dates round-trip via time.Time. Closes
// audit finding CB-3.
func Loads(cxStr string) (any, error) {
	bytes, err := ToDataBin(cxStr)
	if err != nil {
		return nil, err
	}
	return decodeDataBin(bytes)
}

// Dumps serializes native Go types to a CX string.
//
// v3.4: encodes Go value as CXCol v1 bytes directly, then calls
// cx_from_data_bin to produce canonical CX. No JSON-string detour.
// Closes audit finding CB-3.
func Dumps(data any) (string, error) {
	framed, err := encodeDataBin(data)
	if err != nil {
		return "", err
	}
	return FromDataBin(framed)
}

// ── CX emitter ────────────────────────────────────────────────────────────────

var (
	_dateRE     = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	_datetimeRE = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}`)
	_hexRE      = regexp.MustCompile(`^0[xX][0-9a-fA-F]+$`)
)

func wouldAutotype(s string) bool {
	if strings.Contains(s, " ") {
		return false
	}
	if _hexRE.MatchString(s) {
		return true
	}
	if _, err := strconv.ParseInt(s, 10, 64); err == nil {
		return true
	}
	lower := strings.ToLower(s)
	if strings.Contains(s, ".") || strings.Contains(lower, "e") {
		if _, err := strconv.ParseFloat(s, 64); err == nil {
			return true
		}
	}
	if s == "true" || s == "false" || s == "null" {
		return true
	}
	if _datetimeRE.MatchString(s) {
		return true
	}
	if _dateRE.MatchString(s) {
		return true
	}
	return false
}

func cxChooseQuote(s string) string {
	if !strings.Contains(s, "'") {
		return "'" + s + "'"
	}
	if !strings.Contains(s, `"`) {
		return `"` + s + `"`
	}
	if !strings.Contains(s, "'''") {
		return "'''" + s + "'''"
	}
	return `"` + s + `"` // best effort
}

func cxQuoteText(s string) string {
	needs := strings.HasPrefix(s, " ") || strings.HasSuffix(s, " ") ||
		strings.Contains(s, "  ") || strings.Contains(s, "\n") ||
		strings.Contains(s, "\t") || strings.Contains(s, "[") ||
		strings.Contains(s, "]") || strings.Contains(s, "&") ||
		strings.HasPrefix(s, ":") || strings.HasPrefix(s, "'") ||
		strings.HasPrefix(s, `"`) || wouldAutotype(s)
	if needs {
		return cxChooseQuote(s)
	}
	return s
}

func cxQuoteAttr(s string) string {
	if s == "" || strings.Contains(s, " ") || strings.Contains(s, "'") || strings.Contains(s, `"`) {
		return "'" + s + "'"
	}
	return s
}

func emitScalar(s *ScalarNode) string {
	if s.Value == nil {
		return "null"
	}
	// atoms render as `:name` regardless of whether the
	// Value field carries a typed AtomValue (post-decode shape) or a
	// raw string (caller constructed ScalarNode by hand). The DataType
	// tag is the source of truth.
	if s.DataType == "atom" {
		if a, ok := s.Value.(AtomValue); ok {
			return ":" + a.Name
		}
		return ":" + fmt.Sprintf("%v", s.Value)
	}
	switch v := s.Value.(type) {
	case bool:
		if v {
			return "true"
		}
		return "false"
	case int64:
		return strconv.FormatInt(v, 10)
	case float64:
		f := strconv.FormatFloat(v, 'f', -1, 64)
		if !strings.Contains(f, ".") && !strings.Contains(strings.ToLower(f), "e") {
			f += ".0"
		}
		return f
	case AtomValue:
		// Defensive: caller passed AtomValue with empty/unset DataType.
		// Still emit canonical `:name`.
		return ":" + v.Name
	default:
		return fmt.Sprintf("%v", v)
	}
}

func emitAttr(a Attr) string {
	if a.IsRef {
		// bare `@id` round-trips verbatim.
		return fmt.Sprintf("%s=@%v", a.Name, a.Value)
	}
	switch a.DataType {
	case "int":
		switch v := a.Value.(type) {
		case int64:
			return fmt.Sprintf("%s=%d", a.Name, v)
		case float64:
			return fmt.Sprintf("%s=%d", a.Name, int64(v))
		default:
			return fmt.Sprintf("%s=%v", a.Name, a.Value)
		}
	case "float":
		var f float64
		switch v := a.Value.(type) {
		case float64:
			f = v
		case int64:
			f = float64(v)
		default:
			return fmt.Sprintf("%s=%v", a.Name, a.Value)
		}
		fs := strconv.FormatFloat(f, 'f', -1, 64)
		if !strings.Contains(fs, ".") && !strings.Contains(strings.ToLower(fs), "e") {
			fs += ".0"
		}
		return fmt.Sprintf("%s=%s", a.Name, fs)
	case "bool":
		if b, ok := a.Value.(bool); ok {
			if b {
				return a.Name + "=true"
			}
			return a.Name + "=false"
		}
		return fmt.Sprintf("%s=%v", a.Name, a.Value)
	case "null":
		return a.Name + "=null"
	case "atom":
		// atom attribute renders as `name=:NAME` (no quoting).
		// Accept either the typed AtomValue (post-decode) or a raw string
		// (caller-constructed). Either way the canonical form is `:NAME`.
		if av, ok := a.Value.(AtomValue); ok {
			return a.Name + "=:" + av.Name
		}
		return a.Name + "=:" + fmt.Sprintf("%v", a.Value)
	default:
		// string attr — quote if would autotype OR starts with '@' (else
		// would mis-parse as is_ref reference).
		s := fmt.Sprintf("%v", a.Value)
		var v string
		if wouldAutotype(s) || (len(s) > 0 && s[0] == '@') {
			v = cxChooseQuote(s)
		} else {
			v = cxQuoteAttr(s)
		}
		return a.Name + "=" + v
	}
}

func emitInline(node Node) string {
	switch n := node.(type) {
	case *TextNode:
		if strings.TrimSpace(n.Value) == "" {
			return ""
		}
		return cxQuoteText(n.Value)
	case *ScalarNode:
		return emitScalar(n)
	case *EntityRefNode:
		return "&" + n.Name + ";"
	case *RawTextNode:
		return "[#" + n.Value + "#]"
	case *Element:
		return strings.TrimRight(emitElement(n, 0), "\n")
	case *BlockContentNode:
		var sb strings.Builder
		for _, child := range n.Items {
			switch c := child.(type) {
			case *TextNode:
				sb.WriteString(c.Value)
			case *Element:
				sb.WriteString(strings.TrimRight(emitElement(c, 0), "\n"))
			}
		}
		return "[|" + sb.String() + "|]"
	}
	return ""
}

func emitElement(e *Element, depth int) string {
	ind := strings.Repeat("  ", depth)
	// v3.4: body-position reference shape `[ref @<id>]`.
	// No meta or attrs/items per parser contract — just the bare ref body.
	if e.BodyRef != "" {
		return ind + "[" + e.Name + " @" + e.BodyRef + "]\n"
	}
	hasChildElems := false
	hasText := false
	for _, item := range e.Items {
		switch item.(type) {
		case *Element:
			hasChildElems = true
		case *TextNode, *ScalarNode, *EntityRefNode, *RawTextNode:
			hasText = true
		}
	}
	isMultiline := hasChildElems && !hasText

	var metaParts []string
	if e.Anchor != "" {
		metaParts = append(metaParts, "&"+e.Anchor)
	}
	if e.Merge != "" {
		metaParts = append(metaParts, "*"+e.Merge)
	}
	if e.Id != "" {
		metaParts = append(metaParts, "#"+e.Id)
	}
	if e.DataType != "" {
		metaParts = append(metaParts, ":"+e.DataType)
	}
	for _, a := range e.Attrs {
		metaParts = append(metaParts, emitAttr(a))
	}
	meta := ""
	if len(metaParts) > 0 {
		meta = " " + strings.Join(metaParts, " ")
	}

	if isMultiline {
		var sb strings.Builder
		sb.WriteString(ind + "[" + e.Name + meta + "\n")
		for _, item := range e.Items {
			sb.WriteString(emitNode(item, depth+1))
		}
		sb.WriteString(ind + "]\n")
		return sb.String()
	}

	if len(e.Items) == 0 && meta == "" {
		return ind + "[" + e.Name + "]\n"
	}

	var bodyParts []string
	for _, item := range e.Items {
		p := emitInline(item)
		if p != "" {
			bodyParts = append(bodyParts, p)
		}
	}
	body := strings.Join(bodyParts, " ")
	sep := ""
	if body != "" {
		sep = " "
	}
	return ind + "[" + e.Name + meta + sep + body + "]\n"
}

func emitNode(node Node, depth int) string {
	ind := strings.Repeat("  ", depth)
	switch n := node.(type) {
	case *Element:
		return emitElement(n, depth)
	case *TextNode:
		return cxQuoteText(n.Value)
	case *ScalarNode:
		return emitScalar(n)
	case *CommentNode:
		return ind + "[-" + n.Value + "]\n"
	case *RawTextNode:
		return ind + "[#" + n.Value + "#]\n"
	case *EntityRefNode:
		return "&" + n.Name + ";"
	case *AliasNode:
		return ind + "[*" + n.Name + "]\n"
	case *BlockContentNode:
		var sb strings.Builder
		for _, item := range n.Items {
			sb.WriteString(emitNode(item, 0))
		}
		return ind + "[|" + sb.String() + "|]\n"
	case *PINode:
		data := ""
		if n.Data != "" {
			data = " " + n.Data
		}
		return ind + "[?" + n.Target + data + "]\n"
	case *XMLDeclNode:
		parts := []string{"version=" + n.Version}
		if n.Encoding != "" {
			parts = append(parts, "encoding="+n.Encoding)
		}
		if n.Standalone != "" {
			parts = append(parts, "standalone="+n.Standalone)
		}
		return "[?xml " + strings.Join(parts, " ") + "]\n"
	case *CXDirectiveNode:
		var attrParts []string
		for _, a := range n.Attrs {
			attrParts = append(attrParts, a.Name+"="+cxQuoteAttr(fmt.Sprintf("%v", a.Value)))
		}
		return "[?cx " + strings.Join(attrParts, " ") + "]\n"
	case *DoctypeDeclNode:
		ext := ""
		if n.ExternalID != nil {
			if pub, ok := n.ExternalID["public"]; ok {
				sys := ""
				if s, ok2 := n.ExternalID["system"]; ok2 {
					sys = fmt.Sprintf("%v", s)
				}
				ext = fmt.Sprintf(" PUBLIC '%v' '%s'", pub, sys)
			} else if sys, ok := n.ExternalID["system"]; ok {
				ext = fmt.Sprintf(" SYSTEM '%v'", sys)
			}
		}
		return "[!DOCTYPE " + n.Name + ext + "]\n"
	case *SequenceNode: // (a, b, c) — flat sequence (ast_bin 0x0F)
		return "(" + emitNodeList(n.Items, depth) + ")"
	case *ArrayNode: // [a, b, c] — nested-preserving array (ast_bin 0x10)
		return "[" + emitNodeList(n.Items, depth) + "]"
	case *MapNode: // {k: v, k: v} — map literal (ast_bin 0x11)
		var parts []string
		for _, e := range n.Entries {
			parts = append(parts, emitMapKey(e)+": "+emitNode(e.Value, depth))
		}
		return "{" + strings.Join(parts, ", ") + "}"
	}
	return ""
}

// emitNodeList renders comma-separated value nodes for sequence/array bodies.
func emitNodeList(items []Node, depth int) string {
	var parts []string
	for _, it := range items {
		parts = append(parts, emitNode(it, depth))
	}
	return strings.Join(parts, ", ")
}

// emitMapKey renders a MapEntry key: string keys as a bareword (quoted only
// when unsafe), other key types as their scalar form — matching cx emit_cx.
func emitMapKey(e MapEntry) string {
	if e.KeyType == "string" {
		if s, ok := e.KeyValue.(string); ok {
			return cxQuoteText(s)
		}
	}
	return fmt.Sprintf("%v", e.KeyValue)
}

func emitDoc(doc *Document) string {
	var parts []string
	for _, node := range doc.Prolog {
		parts = append(parts, emitNode(node, 0))
	}
	if doc.Doctype != nil {
		parts = append(parts, emitNode(doc.Doctype, 0))
	}
	for _, node := range doc.Elements {
		parts = append(parts, emitNode(node, 0))
	}
	result := strings.Join(parts, "")
	return strings.TrimRight(result, "\n")
}

// ── helpers ───────────────────────────────────────────────────────────────────

func splitPath(path string) []string {
	var parts []string
	for _, p := range strings.Split(path, "/") {
		if p != "" {
			parts = append(parts, p)
		}
	}
	return parts
}
