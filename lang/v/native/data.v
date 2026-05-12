// CX V binding — native data binding (`loads` / `dumps`).
//
// `loads` walks the parsed Document directly into json2.Any. It does
// not call `cx.to_json` and re-parse the result. This is the native
// implementation that closes audit finding CB-3 (the JSON-string
// detour) for the V binding.
//
// `dumps` builds a Document from json2.Any directly and emits it via
// `cx.emit_cx`. It does not call `cx.json_to_cx` with a serialized
// representation. Type fidelity is preserved: i64 stays i64, bool
// stays bool, etc.
//
// Semantic JSON projection rules mirror `cx.emit_semantic_json` (see
// `vcx/cx/emitter_semantic.v`). The two implementations produce
// equivalent results for the same input; this is enforced by
// conformance fixtures.

module native

import cx
import x.json2

// ── loads: CX → native V types ───────────────────────────────────────────────

// loads deserializes CX source into native V types (json2.Any:
// map / array / scalar). Type fidelity preserved per the source
// scalar types (int → i64, float → f64, bool → bool, null → json2.Null).
pub fn loads(src string) !json2.Any {
	doc := cx.parse(src)!
	return doc_to_any(doc)
}

fn doc_to_any(doc cx.Document) json2.Any {
	roots := doc.elements.filter(it is cx.Element)
	if roots.len == 0 {
		return json2.Null{}
	}
	mut obj := map[string]json2.Any{}
	for n in roots {
		if n is cx.Element {
			e := n as cx.Element
			push_keyed(mut obj, e.name, element_to_any(e))
		}
	}
	return obj
}

fn element_to_any(e cx.Element) json2.Any {
	content := e.items.filter(
		!(it is cx.CommentNode) && !(it is cx.PINode)
		&& !(it is cx.XMLDeclNode) && !(it is cx.CXDirectiveNode)
	)

	has_attrs    := e.attrs.len > 0
	has_elements := content.any(it is cx.Element)
	all_scalars  := content.len > 0 && content.all(it is cx.ScalarNode)
	has_text     := content.any(it is cx.TextNode || it is cx.RawTextNode
		|| it is cx.EntityRefNode || it is cx.BlockContentNode)

	// Pure scalar(s), no attrs.
	if !has_attrs && all_scalars {
		if content.len == 1 {
			return scalar_node_to_any(content[0] as cx.ScalarNode)
		}
		mut arr := []json2.Any{cap: content.len}
		for n in content {
			arr << scalar_node_to_any(n as cx.ScalarNode)
		}
		return arr
	}

	// Pure text, no attrs, no elements.
	if !has_attrs && !has_elements && has_text {
		return collect_text(content)
	}

	// Empty.
	if !has_attrs && content.len == 0 {
		return json2.Null{}
	}

	// Object form: attrs + nested elements / mixed.
	mut obj := map[string]json2.Any{}
	for attr in e.attrs {
		obj[attr.name] = scalar_value_to_any(attr.value)
	}

	if has_elements {
		for n in content {
			match n {
				cx.Element {
					push_keyed(mut obj, n.name, element_to_any(n))
				}
				cx.TextNode {
					if n.value.trim_space().len > 0 {
						push_text(mut obj, n.value)
					}
				}
				cx.RawTextNode {
					push_text(mut obj, n.value)
				}
				cx.EntityRefNode {
					push_text(mut obj, entity_ref_value(n.name))
				}
				cx.ScalarNode {
					push_keyed(mut obj, '_', scalar_node_to_any(n))
				}
				cx.BlockContentNode {
					for item in n.items {
						if item is cx.TextNode {
							t := item as cx.TextNode
							if t.value.trim_space().len > 0 {
								push_text(mut obj, t.value)
							}
						}
					}
				}
				else {}
			}
		}
	} else if has_attrs {
		if all_scalars && content.len == 1 {
			obj['_'] = scalar_node_to_any(content[0] as cx.ScalarNode)
		} else if has_text {
			obj['_'] = collect_text(content)
		}
	}

	return obj
}

fn push_keyed(mut obj map[string]json2.Any, key string, val json2.Any) {
	if key in obj {
		existing := obj[key] or { json2.Any(json2.Null{}) }
		if existing is []json2.Any {
			mut arr := existing as []json2.Any
			arr << val
			obj[key] = json2.Any(arr)
		} else {
			obj[key] = json2.Any([existing, val])
		}
	} else {
		obj[key] = val
	}
}

fn push_text(mut obj map[string]json2.Any, text string) {
	if '_' in obj {
		existing := obj['_'] or { json2.Any('') }
		if existing is string {
			obj['_'] = existing + text
		}
	} else {
		obj['_'] = text
	}
}

fn collect_text(nodes []cx.Node) json2.Any {
	mut parts := []string{}
	for n in nodes {
		match n {
			cx.TextNode      { parts << n.value }
			cx.RawTextNode   { parts << n.value }
			cx.EntityRefNode { parts << entity_ref_value(n.name) }
			cx.BlockContentNode {
				for item in n.items {
					if item is cx.TextNode {
						parts << (item as cx.TextNode).value
					}
				}
			}
			else {}
		}
	}
	return parts.join('')
}

fn scalar_value_to_any(v cx.ScalarValue) json2.Any {
	return match v {
		i64       { json2.Any(v) }
		f64       { json2.Any(v) }
		bool      { json2.Any(v) }
		cx.NullValue { json2.Any(json2.Null{}) }
		string    { json2.Any(v) }
	}
}

fn scalar_node_to_any(s cx.ScalarNode) json2.Any {
	return scalar_value_to_any(s.value)
}

fn entity_ref_value(name string) string {
	return match name {
		'amp'  { '&' }
		'lt'   { '<' }
		'gt'   { '>' }
		'apos' { "'" }
		'quot' { '"' }
		else   { '&${name};' }
	}
}

// ── dumps: native V types → CX ───────────────────────────────────────────────

// dumps serializes native V types (json2.Any) to a CX string. Builds
// a cx.Document from the value tree and emits via cx.emit_cx — no
// JSON-string detour.
//
// Top-level shape: the input value MUST be a map. Each top-level key
// becomes a separate root Element. To dump a top-level array or
// scalar, wrap it in a map first (e.g., `{"items": [...]}`).
pub fn dumps(data json2.Any) !string {
	if data !is map[string]json2.Any {
		return error('dumps: top-level value must be a map; got ${type_label(data)}. ' +
			'Wrap arrays or scalars in a map before dumping.')
	}
	doc := any_to_doc(data as map[string]json2.Any)!
	return cx.emit_cx(doc)
}

fn any_to_doc(m map[string]json2.Any) !cx.Document {
	mut elements := []cx.Node{}
	for key, val in m {
		elements << cx.Node(any_to_root_element(key, val)!)
	}
	return cx.Document{
		elements: elements
	}
}

fn any_to_root_element(name string, val json2.Any) !cx.Element {
	return any_to_named_element(name, val)!
}

// any_to_named_element produces an Element with the given name whose
// content represents val.
fn any_to_named_element(name string, val json2.Any) !cx.Element {
	if val is map[string]json2.Any {
		return map_to_element(name, val as map[string]json2.Any)!
	}
	if val is []json2.Any {
		return array_to_element(name, val as []json2.Any)!
	}
	// Scalar — element body is the scalar.
	return cx.Element{
		name:  name
		items: [cx.Node(any_to_scalar_node(val))]
	}
}

fn map_to_element(name string, m map[string]json2.Any) !cx.Element {
	mut attrs := []cx.Attribute{}
	mut items := []cx.Node{}
	for k, v in m {
		if v is map[string]json2.Any {
			items << cx.Node(map_to_element(k, v as map[string]json2.Any)!)
		} else if v is []json2.Any {
			arr := v as []json2.Any
			if arr.len == 0 {
				items << cx.Node(cx.Element{ name: k })
			} else if arr_is_scalars(arr) {
				items << cx.Node(scalars_to_element(k, arr))
			} else {
				for item in arr {
					items << cx.Node(any_to_named_element(k, item)!)
				}
			}
		} else {
			attrs << cx.Attribute{
				name:      k
				value:     any_to_scalar_value(v)
				data_type: scalar_value_type(v)
			}
		}
	}
	return cx.Element{
		name:  name
		attrs: attrs
		items: items
	}
}

fn array_to_element(name string, arr []json2.Any) !cx.Element {
	if arr.len == 0 {
		return cx.Element{ name: name }
	}
	if arr_is_scalars(arr) {
		return scalars_to_element(name, arr)
	}
	// Mixed / nested: emit each as a child with synthesized name `item`.
	mut items := []cx.Node{}
	for v in arr {
		items << cx.Node(any_to_named_element('item', v)!)
	}
	return cx.Element{
		name:  name
		items: items
	}
}

fn arr_is_scalars(arr []json2.Any) bool {
	for v in arr {
		if v is map[string]json2.Any { return false }
		if v is []json2.Any { return false }
	}
	return true
}

fn scalars_to_element(name string, arr []json2.Any) cx.Element {
	mut items := []cx.Node{}
	for v in arr {
		items << cx.Node(any_to_scalar_node(v))
	}
	return cx.Element{
		name:  name
		items: items
	}
}

fn any_to_scalar_node(val json2.Any) cx.ScalarNode {
	t := scalar_value_type(val) or { cx.ScalarType.string_type }
	return cx.ScalarNode{
		data_type: t
		value:     any_to_scalar_value(val)
	}
}

fn any_to_scalar_value(val json2.Any) cx.ScalarValue {
	if val is i64    { return cx.ScalarValue(val as i64) }
	if val is f64    { return cx.ScalarValue(val as f64) }
	if val is bool   { return cx.ScalarValue(val as bool) }
	if val is string { return cx.ScalarValue(val as string) }
	if val is json2.Null { return cx.ScalarValue(cx.NullValue{}) }
	// Containers shouldn't reach here; treat as string via json2 string form
	// only as a defensive fallback.
	return cx.ScalarValue(val.str())
}

fn scalar_value_type(val json2.Any) ?cx.ScalarType {
	if val is i64    { return cx.ScalarType.int_type }
	if val is f64    { return cx.ScalarType.float_type }
	if val is bool   { return cx.ScalarType.bool_type }
	if val is string { return cx.ScalarType.string_type }
	if val is json2.Null { return cx.ScalarType.null_type }
	return none
}

fn type_label(v json2.Any) string {
	if v is map[string]json2.Any { return 'map' }
	if v is []json2.Any { return 'array' }
	if v is i64 { return 'int' }
	if v is f64 { return 'float' }
	if v is bool { return 'bool' }
	if v is string { return 'string' }
	if v is json2.Null { return 'null' }
	return 'unknown'
}
