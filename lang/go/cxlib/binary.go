package cxlib

import (
	"encoding/binary"
	"fmt"
)

// StreamEvent represents a single CX streaming event.
type StreamEvent struct {
	Type     string
	Name     string
	Anchor   *string
	DataType *string
	Merge    *string
	Attrs    []Attr
	Value    any
	Target   string
	Data     *string
	// Chunked-table fields (StartTable / RowGroup / EndTable per ADR 0015 D10).
	// ColSpec is the §1.1 events-layer encoding:
	// [u32 LE: count]([u32 LE: name_len]name [u8: col_type_code])*.
	// Payload is the §3.11.2 plain-body bytes uvarint(row_count) <col-payload>(col_count) —
	// already decompressed if the source row group used §3.12 zstd wrapping.
	ColSpec  []byte
	RowCount uint32
	Payload  []byte
}

// ── buffer reader ─────────────────────────────────────────────────────────────

type binBuf struct {
	data []byte
	pos  int
}

func (b *binBuf) u8() (uint8, error) {
	if b.pos >= len(b.data) {
		return 0, fmt.Errorf("binary decode: unexpected end of data reading u8")
	}
	v := b.data[b.pos]
	b.pos++
	return v, nil
}

func (b *binBuf) u16() (uint16, error) {
	if b.pos+2 > len(b.data) {
		return 0, fmt.Errorf("binary decode: unexpected end of data reading u16")
	}
	v := binary.LittleEndian.Uint16(b.data[b.pos:])
	b.pos += 2
	return v, nil
}

func (b *binBuf) u32() (uint32, error) {
	if b.pos+4 > len(b.data) {
		return 0, fmt.Errorf("binary decode: unexpected end of data reading u32")
	}
	v := binary.LittleEndian.Uint32(b.data[b.pos:])
	b.pos += 4
	return v, nil
}

func (b *binBuf) str() (string, error) {
	n, err := b.u32()
	if err != nil {
		return "", err
	}
	if b.pos+int(n) > len(b.data) {
		return "", fmt.Errorf("binary decode: unexpected end of data reading string of length %d", n)
	}
	s := string(b.data[b.pos : b.pos+int(n)])
	b.pos += int(n)
	return s, nil
}

func (b *binBuf) bytesN(n int) ([]byte, error) {
	if b.pos+n > len(b.data) {
		return nil, fmt.Errorf("binary decode: unexpected end of data reading %d bytes", n)
	}
	out := make([]byte, n)
	copy(out, b.data[b.pos:b.pos+n])
	b.pos += n
	return out, nil
}

func (b *binBuf) optstr() (*string, error) {
	flag, err := b.u8()
	if err != nil {
		return nil, err
	}
	if flag == 0 {
		return nil, nil
	}
	s, err := b.str()
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// ── scalar coercion ───────────────────────────────────────────────────────────

func coerceAttrValue(typeStr, valueStr string) any {
	switch typeStr {
	case "int":
		var v int64
		fmt.Sscan(valueStr, &v)
		return v
	case "float":
		var v float64
		fmt.Sscan(valueStr, &v)
		return v
	case "bool":
		return valueStr == "true"
	case "null":
		return nil
	default:
		return valueStr
	}
}

// ── AST decoder ───────────────────────────────────────────────────────────────

func readAttr(b *binBuf, version uint8) (Attr, error) {
	name, err := b.str()
	if err != nil {
		return Attr{}, err
	}
	valueStr, err := b.str()
	if err != nil {
		return Attr{}, err
	}
	typeStr, err := b.str()
	if err != nil {
		return Attr{}, err
	}
	dt := typeStr
	if typeStr == "string" {
		dt = ""
	}
	a := Attr{
		Name:     name,
		Value:    coerceAttrValue(typeStr, valueStr),
		DataType: dt,
	}
	if version >= 2 {
		// v3.4 (ADR 0003): is_ref flag.
		flag, err := b.u8()
		if err != nil {
			return Attr{}, err
		}
		a.IsRef = flag == 1
	}
	if version >= 5 {
		// v3.5 (ADR 0016): BracketBody attribute body tail.
		bodyFlag, err := b.u8()
		if err != nil {
			return Attr{}, err
		}
		if bodyFlag == 1 {
			count, err := b.u16()
			if err != nil {
				return Attr{}, err
			}
			body := make([]Node, 0, count)
			for i := uint16(0); i < count; i++ {
				n, err := readNode(b, version)
				if err != nil {
					return Attr{}, err
				}
				body = append(body, n)
			}
			a.Body = body
		} else if bodyFlag != 0 {
			return Attr{}, fmt.Errorf("ast_bin: invalid attr body_flag %d", bodyFlag)
		}
	}
	return a, nil
}

func readNode(b *binBuf, version uint8) (Node, error) {
	tid, err := b.u8()
	if err != nil {
		return nil, err
	}
	switch tid {
	case 0x01: // Element
		name, err := b.str()
		if err != nil {
			return nil, err
		}
		anchor, err := b.optstr()
		if err != nil {
			return nil, err
		}
		dataType, err := b.optstr()
		if err != nil {
			return nil, err
		}
		merge, err := b.optstr()
		if err != nil {
			return nil, err
		}
		var elemId *string
		if version >= 2 {
			elemId, err = b.optstr()
			if err != nil {
				return nil, err
			}
		}
		var bodyRef *string
		if version >= 3 {
			// v3.4 (ADR 0003 D1): body-position reference.
			bodyRef, err = b.optstr()
			if err != nil {
				return nil, err
			}
		}
		attrCount, err := b.u16()
		if err != nil {
			return nil, err
		}
		attrs := make([]Attr, 0, attrCount)
		for i := uint16(0); i < attrCount; i++ {
			a, err := readAttr(b, version)
			if err != nil {
				return nil, err
			}
			attrs = append(attrs, a)
		}
		childCount, err := b.u16()
		if err != nil {
			return nil, err
		}
		items := make([]Node, 0, childCount)
		for i := uint16(0); i < childCount; i++ {
			child, err := readNode(b, version)
			if err != nil {
				return nil, err
			}
			items = append(items, child)
		}
		el := &Element{Name: name, Attrs: attrs, Items: items}
		if anchor != nil {
			el.Anchor = *anchor
		}
		if dataType != nil {
			el.DataType = *dataType
		}
		if merge != nil {
			el.Merge = *merge
		}
		if elemId != nil {
			el.Id = *elemId
		}
		if bodyRef != nil {
			el.BodyRef = *bodyRef
		}
		return el, nil

	case 0x02: // Text
		v, err := b.str()
		if err != nil {
			return nil, err
		}
		return &TextNode{Value: v}, nil

	case 0x03: // Scalar
		typeStr, err := b.str()
		if err != nil {
			return nil, err
		}
		valueStr, err := b.str()
		if err != nil {
			return nil, err
		}
		return &ScalarNode{DataType: typeStr, Value: coerceAttrValue(typeStr, valueStr)}, nil

	case 0x04: // Comment
		v, err := b.str()
		if err != nil {
			return nil, err
		}
		return &CommentNode{Value: v}, nil

	case 0x05: // RawText
		v, err := b.str()
		if err != nil {
			return nil, err
		}
		return &RawTextNode{Value: v}, nil

	case 0x06: // EntityRef
		name, err := b.str()
		if err != nil {
			return nil, err
		}
		return &EntityRefNode{Name: name}, nil

	case 0x07: // Alias
		name, err := b.str()
		if err != nil {
			return nil, err
		}
		return &AliasNode{Name: name}, nil

	case 0x08: // PI
		target, err := b.str()
		if err != nil {
			return nil, err
		}
		data, err := b.optstr()
		if err != nil {
			return nil, err
		}
		pi := &PINode{Target: target}
		if data != nil {
			pi.Data = *data
		}
		return pi, nil

	case 0x09: // XMLDecl
		version, err := b.str()
		if err != nil {
			return nil, err
		}
		encoding, err := b.optstr()
		if err != nil {
			return nil, err
		}
		standalone, err := b.optstr()
		if err != nil {
			return nil, err
		}
		node := &XMLDeclNode{Version: version}
		if encoding != nil {
			node.Encoding = *encoding
		}
		if standalone != nil {
			node.Standalone = *standalone
		}
		return node, nil

	case 0x0A: // CXDirective
		count, err := b.u16()
		if err != nil {
			return nil, err
		}
		attrs := make([]Attr, 0, count)
		for i := uint16(0); i < count; i++ {
			a, err := readAttr(b, version)
			if err != nil {
				return nil, err
			}
			attrs = append(attrs, a)
		}
		var anchor string
		var items []Node
		if version >= 4 {
			// v0.6.0 — directive `&anchor` + nested children.
			anc, err := b.optstr()
			if err != nil {
				return nil, err
			}
			if anc != nil {
				anchor = *anc
			}
			itemCount, err := b.u16()
			if err != nil {
				return nil, err
			}
			items = make([]Node, 0, itemCount)
			for i := uint16(0); i < itemCount; i++ {
				child, err := readNode(b, version)
				if err != nil {
					return nil, err
				}
				items = append(items, child)
			}
		}
		return &CXDirectiveNode{Attrs: attrs, Anchor: anchor, Items: items}, nil

	case 0x0C: // BlockContent
		count, err := b.u16()
		if err != nil {
			return nil, err
		}
		items := make([]Node, 0, count)
		for i := uint16(0); i < count; i++ {
			child, err := readNode(b, version)
			if err != nil {
				return nil, err
			}
			items = append(items, child)
		}
		return &BlockContentNode{Items: items}, nil

	case 0x0D: // Interpolation — v3.5 (ADR 0016) [58]
		expr, err := b.str()
		if err != nil {
			return nil, err
		}
		return &InterpolationNode{Expr: expr}, nil

	case 0x0E: // EvalDirective — v3.5 (ADR 0016) [59]
		name, err := b.str()
		if err != nil {
			return nil, err
		}
		attrCount, err := b.u16()
		if err != nil {
			return nil, err
		}
		attrs := make([]Attr, 0, attrCount)
		for i := uint16(0); i < attrCount; i++ {
			a, err := readAttr(b, version)
			if err != nil {
				return nil, err
			}
			attrs = append(attrs, a)
		}
		itemCount, err := b.u16()
		if err != nil {
			return nil, err
		}
		items := make([]Node, 0, itemCount)
		for i := uint16(0); i < itemCount; i++ {
			child, err := readNode(b, version)
			if err != nil {
				return nil, err
			}
			items = append(items, child)
		}
		return &EvalDirectiveNode{Name: name, Attrs: attrs, Items: items}, nil

	case 0xFF: // skip — no payload
		return &TextNode{Value: ""}, nil

	default:
		return &TextNode{Value: ""}, nil
	}
}

// decodeAST decodes a binary AST payload into a Document.
func decodeAST(data []byte) (*Document, error) {
	b := &binBuf{data: data}

	// version byte
	version, err := b.u8()
	if err != nil {
		return nil, err
	}

	prologCount, err := b.u16()
	if err != nil {
		return nil, err
	}
	prolog := make([]Node, 0, prologCount)
	for i := uint16(0); i < prologCount; i++ {
		node, err := readNode(b, version)
		if err != nil {
			return nil, err
		}
		prolog = append(prolog, node)
	}

	elemCount, err := b.u16()
	if err != nil {
		return nil, err
	}
	elements := make([]Node, 0, elemCount)
	for i := uint16(0); i < elemCount; i++ {
		node, err := readNode(b, version)
		if err != nil {
			return nil, err
		}
		elements = append(elements, node)
	}

	return &Document{Prolog: prolog, Elements: elements}, nil
}

// ── Events decoder ────────────────────────────────────────────────────────────

var evtTypeNames = map[uint8]string{
	0x01: "StartDoc",
	0x02: "EndDoc",
	0x03: "StartElement",
	0x04: "EndElement",
	0x05: "Text",
	0x06: "Scalar",
	0x07: "Comment",
	0x08: "PI",
	0x09: "EntityRef",
	0x0A: "RawText",
	0x0B: "Alias",
	0x0C: "StartTable",
	0x0D: "RowGroup",
	0x0E: "EndTable",
}

// decodeOneEvent reads a single event from the buffer at the current
// position. Used by both the whole-buffer decoder (decodeEvents) and
// the per-event handle path (Phase 5 / CB-4).
func decodeOneEvent(b *binBuf) (StreamEvent, error) {
	tid, err := b.u8()
	if err != nil {
		return StreamEvent{}, err
	}
	typeName, ok := evtTypeNames[tid]
	if !ok {
		typeName = "Unknown"
	}
	evt := StreamEvent{Type: typeName}

	switch tid {
	case 0x03: // StartElement
		name, err := b.str()
		if err != nil {
			return evt, err
		}
		anchor, err := b.optstr()
		if err != nil {
			return evt, err
		}
		dataType, err := b.optstr()
		if err != nil {
			return evt, err
		}
		merge, err := b.optstr()
		if err != nil {
			return evt, err
		}
		attrCount, err := b.u16()
		if err != nil {
			return evt, err
		}
		attrs := make([]Attr, 0, attrCount)
		for j := uint16(0); j < attrCount; j++ {
			attrName, err := b.str()
			if err != nil {
				return evt, err
			}
			valStr, err := b.str()
			if err != nil {
				return evt, err
			}
			typStr, err := b.str()
			if err != nil {
				return evt, err
			}
			dt := typStr
			if typStr == "string" {
				dt = ""
			}
			// v3.4 (ADR 0003): is_ref byte (events buffer follows
			// ast_bin v2 attr layout).
			refFlag, err := b.u8()
			if err != nil {
				return evt, err
			}
			// v3.5 (ADR 0016): BracketBody attr body tail (events
			// buffer follows ast_bin v5 attr layout). Body items
			// are read but discarded — events are a flattened view.
			bodyFlag, err := b.u8()
			if err != nil {
				return evt, err
			}
			if bodyFlag == 1 {
				count, err := b.u16()
				if err != nil {
					return evt, err
				}
				for i := uint16(0); i < count; i++ {
					if _, err := readNode(b, 5); err != nil {
						return evt, err
					}
				}
			}
			attrs = append(attrs, Attr{
				Name:     attrName,
				Value:    coerceAttrValue(typStr, valStr),
				DataType: dt,
				IsRef:    refFlag == 1,
			})
		}
		evt.Name = name
		evt.Anchor = anchor
		evt.DataType = dataType
		evt.Merge = merge
		evt.Attrs = attrs

	case 0x04: // EndElement
		name, err := b.str()
		if err != nil {
			return evt, err
		}
		evt.Name = name

	case 0x05, 0x07, 0x0A: // Text, Comment, RawText
		v, err := b.str()
		if err != nil {
			return evt, err
		}
		evt.Value = v

	case 0x06: // Scalar
		typeStr, err := b.str()
		if err != nil {
			return evt, err
		}
		valueStr, err := b.str()
		if err != nil {
			return evt, err
		}
		s := typeStr
		evt.DataType = &s
		evt.Value = coerceAttrValue(typeStr, valueStr)

	case 0x08: // PI
		target, err := b.str()
		if err != nil {
			return evt, err
		}
		data, err := b.optstr()
		if err != nil {
			return evt, err
		}
		evt.Target = target
		evt.Data = data

	case 0x09, 0x0B: // EntityRef, Alias
		v, err := b.str()
		if err != nil {
			return evt, err
		}
		evt.Value = v

	case 0x0C: // StartTable
		name, err := b.str()
		if err != nil {
			return evt, err
		}
		n, err := b.u32()
		if err != nil {
			return evt, err
		}
		cs, err := b.bytesN(int(n))
		if err != nil {
			return evt, err
		}
		evt.Name = name
		evt.ColSpec = cs

	case 0x0D: // RowGroup
		rc, err := b.u32()
		if err != nil {
			return evt, err
		}
		n, err := b.u32()
		if err != nil {
			return evt, err
		}
		pl, err := b.bytesN(int(n))
		if err != nil {
			return evt, err
		}
		evt.RowCount = rc
		evt.Payload = pl

	case 0x0E: // EndTable
		name, err := b.str()
		if err != nil {
			return evt, err
		}
		evt.Name = name

	// 0x01 StartDoc, 0x02 EndDoc: no payload
	}
	return evt, nil
}

// decodeEvents decodes a binary events payload (whole-buffer form,
// [u32 count][events...]) into a slice of StreamEvent.
func decodeEvents(data []byte) ([]StreamEvent, error) {
	b := &binBuf{data: data}
	count, err := b.u32()
	if err != nil {
		return nil, err
	}
	events := make([]StreamEvent, 0, count)
	for i := uint32(0); i < count; i++ {
		evt, err := decodeOneEvent(b)
		if err != nil {
			return nil, err
		}
		events = append(events, evt)
	}
	return events, nil
}

// ── Binary AST encoder (Phase 5 / CB-1) ──────────────────────────────────────
// Inverse of decodeAST. Produces a FRAMED [u32 LE size][payload] buffer that
// matches V's emit_ast_bin output. Used by Document.ToAstBin to feed
// cx_ast_bin_to_<format> directly without the ToCx round-trip.

type binWriter struct{ buf []byte }

func (w *binWriter) u8(v byte)  { w.buf = append(w.buf, v) }
func (w *binWriter) u16(v uint16) {
	var b [2]byte
	binary.LittleEndian.PutUint16(b[:], v)
	w.buf = append(w.buf, b[:]...)
}
func (w *binWriter) u32(v uint32) {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], v)
	w.buf = append(w.buf, b[:]...)
}
func (w *binWriter) str(s string) {
	w.u32(uint32(len(s)))
	w.buf = append(w.buf, s...)
}
func (w *binWriter) optstr(s string) {
	if s == "" {
		w.u8(0)
	} else {
		w.u8(1)
		w.str(s)
	}
}

// scalarValueStr serializes a Scalar/Attr value to its canonical CX
// string form (matching V's scalar_value_str). Booleans first since
// Go's untyped bool isn't a numeric subclass.
func scalarValueStr(dt string, v any) string {
	if v == nil || dt == "null" {
		return "null"
	}
	if b, ok := v.(bool); ok {
		if b {
			return "true"
		}
		return "false"
	}
	switch x := v.(type) {
	case string:
		return x
	case int:
		return fmt.Sprintf("%d", x)
	case int64:
		return fmt.Sprintf("%d", x)
	case int32:
		return fmt.Sprintf("%d", x)
	case float64:
		return fmt.Sprintf("%v", x)
	case float32:
		return fmt.Sprintf("%v", x)
	}
	return fmt.Sprintf("%v", v)
}

func (w *binWriter) attr(a Attr) {
	w.str(a.Name)
	dt := a.DataType
	if dt == "" {
		dt = "string"
	}
	w.str(scalarValueStr(dt, a.Value))
	w.str(dt)
	// v3.4 (ADR 0003): is_ref flag — format version 2.
	if a.IsRef {
		w.u8(1)
	} else {
		w.u8(0)
	}
	// v3.5 (ADR 0016): BracketBody attribute body tail — format version 5.
	if a.Body == nil {
		w.u8(0)
	} else {
		w.u8(1)
		w.u16(uint16(len(a.Body)))
		for _, n := range a.Body {
			w.node(n)
		}
	}
}

func (w *binWriter) node(n Node) {
	switch x := n.(type) {
	case *Element:
		w.u8(0x01)
		w.str(x.Name)
		w.optstr(x.Anchor)
		w.optstr(x.DataType)
		w.optstr(x.Merge)
		// v3.4 (ADR 0003): syntactic ID declaration — format version 2.
		w.optstr(x.Id)
		// v3.4 (ADR 0003 D1): body-position reference — format version 3.
		w.optstr(x.BodyRef)
		w.u16(uint16(len(x.Attrs)))
		for _, a := range x.Attrs {
			w.attr(a)
		}
		w.u16(uint16(len(x.Items)))
		for _, c := range x.Items {
			w.node(c)
		}
	case *TextNode:
		w.u8(0x02); w.str(x.Value)
	case *ScalarNode:
		w.u8(0x03)
		w.str(x.DataType)
		w.str(scalarValueStr(x.DataType, x.Value))
	case *CommentNode:
		w.u8(0x04); w.str(x.Value)
	case *RawTextNode:
		w.u8(0x05); w.str(x.Value)
	case *EntityRefNode:
		w.u8(0x06); w.str(x.Name)
	case *AliasNode:
		w.u8(0x07); w.str(x.Name)
	case *PINode:
		w.u8(0x08)
		w.str(x.Target)
		w.optstr(x.Data)
	case *XMLDeclNode:
		w.u8(0x09)
		w.str(x.Version)
		w.optstr(x.Encoding)
		w.optstr(x.Standalone)
	case *CXDirectiveNode:
		w.u8(0x0A)
		w.u16(uint16(len(x.Attrs)))
		for _, a := range x.Attrs {
			w.attr(a)
		}
		// v0.6.0 (format version 4) — directive `&anchor` + nested children.
		w.optstr(x.Anchor)
		w.u16(uint16(len(x.Items)))
		for _, c := range x.Items {
			w.node(c)
		}
	case *BlockContentNode:
		w.u8(0x0C)
		w.u16(uint16(len(x.Items)))
		for _, it := range x.Items {
			w.node(it)
		}
	case *InterpolationNode:
		// v3.5 (ADR 0016) [58] — `[?=EXPR]`.
		w.u8(0x0D)
		w.str(x.Expr)
	case *EvalDirectiveNode:
		// v3.5 (ADR 0016) [59] — `[?Name attrs body]`.
		w.u8(0x0E)
		w.str(x.Name)
		w.u16(uint16(len(x.Attrs)))
		for _, a := range x.Attrs {
			w.attr(a)
		}
		w.u16(uint16(len(x.Items)))
		for _, it := range x.Items {
			w.node(it)
		}
	default:
		// DTD / unknown — emit 0xFF skip marker.
		w.u8(0xFF)
	}
}

// encodeAST encodes a Document to a FRAMED [u32 LE size][payload]
// binary AST buffer suitable for direct hand-off to cx_ast_bin_to_<format>.
func encodeAST(doc *Document) []byte {
	w := &binWriter{}
	w.u8(0x05) // version — bumped 4 → 5 for v0.6.0 grammar v3.5
	           //           (Interpolation/EvalDirective tags +
	           //            BracketBody attr body tail)
	w.u16(uint16(len(doc.Prolog)))
	for _, n := range doc.Prolog {
		w.node(n)
	}
	w.u16(uint16(len(doc.Elements)))
	for _, n := range doc.Elements {
		w.node(n)
	}
	out := make([]byte, 4+len(w.buf))
	binary.LittleEndian.PutUint32(out[:4], uint32(len(w.buf)))
	copy(out[4:], w.buf)
	return out
}
