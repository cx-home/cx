// Tree-mutation helpers for Document.Transform / TransformAll.
//
// The CXPath parser, lexer, predicate types, and evaluator that lived
// here were deleted in Phase 4 (CB-5): SelectAll / TransformAll now go
// through cx_select_all_paths (libcx evaluates the expression and
// returns structural paths). What remains in this file is host-side
// Go tree manipulation — not duplication.

package cxlib

/*
#include "cx.h"
#include <stdlib.h>
*/
import "C"

import (
	"encoding/binary"
	"fmt"
	"unsafe"
)

// ── Paths-blob FFI ───────────────────────────────────────────────────────────

// cxSelectAllPaths invokes cx_select_all_paths and decodes the framed
// [u32 LE size][payload] buffer into a slice of paths. Each path is a
// slice of 0-based indices into Document.Elements (depth 0) then
// Element.Items (deeper). Match order is preorder (same as cx_select_all).
func cxSelectAllPaths(input, expr string) ([][]int, error) {
	cInput := C.CString(input)
	defer C.free(unsafe.Pointer(cInput))
	cExpr := C.CString(expr)
	defer C.free(unsafe.Pointer(cExpr))
	var errPtr *C.char
	raw := unsafe.Pointer(C.cx_select_all_paths(cInput, cExpr, &errPtr))
	framed, err := extractBinPayload(raw, errPtr)
	if err != nil {
		return nil, err
	}
	if len(framed) < 4 {
		return nil, fmt.Errorf("cx_select_all_paths: payload too short")
	}
	nPaths := int(binary.LittleEndian.Uint32(framed[:4]))
	off := 4
	out := make([][]int, 0, nPaths)
	for i := 0; i < nPaths; i++ {
		if off+4 > len(framed) {
			return nil, fmt.Errorf("cx_select_all_paths: truncated path[%d] depth", i)
		}
		depth := int(binary.LittleEndian.Uint32(framed[off : off+4]))
		off += 4
		if off+4*depth > len(framed) {
			return nil, fmt.Errorf("cx_select_all_paths: truncated path[%d] indices", i)
		}
		path := make([]int, depth)
		for k := 0; k < depth; k++ {
			path[k] = int(binary.LittleEndian.Uint32(framed[off : off+4]))
			off += 4
		}
		out = append(out, path)
	}
	return out, nil
}

// ── Tree navigation by path ──────────────────────────────────────────────────

// navigateDocPath walks `path` and returns the element at that
// position. Returns nil if any step is out-of-bounds or hits a
// non-Element item.
func navigateDocPath(d *Document, path []int) *Element {
	if len(path) == 0 || path[0] < 0 || path[0] >= len(d.Elements) {
		return nil
	}
	var node Node = d.Elements[path[0]]
	for _, k := range path[1:] {
		el, ok := node.(*Element)
		if !ok || k < 0 || k >= len(el.Items) {
			return nil
		}
		node = el.Items[k]
	}
	if el, ok := node.(*Element); ok {
		return el
	}
	return nil
}

// replaceAtDocPath returns a new Document with the element at `path`
// replaced by `newElem`. The original Document is unchanged — only the
// spine along `path` is rebuilt.
func replaceAtDocPath(d *Document, path []int, newElem *Element) *Document {
	if len(path) == 0 {
		return d
	}
	newElements := make([]Node, len(d.Elements))
	copy(newElements, d.Elements)
	if len(path) == 1 {
		newElements[path[0]] = newElem
	} else {
		top, ok := newElements[path[0]].(*Element)
		if !ok {
			return d
		}
		newElements[path[0]] = replaceInElement(top, path[1:], newElem)
	}
	return &Document{Elements: newElements, Prolog: d.Prolog, Doctype: d.Doctype}
}

func replaceInElement(el *Element, path []int, newElem *Element) *Element {
	if len(path) == 0 {
		return newElem
	}
	newItems := make([]Node, len(el.Items))
	copy(newItems, el.Items)
	if len(path) == 1 {
		newItems[path[0]] = newElem
	} else {
		child, ok := newItems[path[0]].(*Element)
		if !ok {
			return el
		}
		newItems[path[0]] = replaceInElement(child, path[1:], newElem)
	}
	return &Element{
		Name:     el.Name,
		Anchor:   el.Anchor,
		Merge:    el.Merge,
		DataType: el.DataType,
		Attrs:    el.Attrs,
		Items:    newItems,
	}
}

// ── Transform helpers (used by Document.Transform's slash-path API) ──────────

// elemDetached returns a copy of e with independent attrs and items slices.
func elemDetached(e *Element) *Element {
	newAttrs := make([]Attr, len(e.Attrs))
	copy(newAttrs, e.Attrs)
	newItems := make([]Node, len(e.Items))
	copy(newItems, e.Items)
	return &Element{
		Name:     e.Name,
		Anchor:   e.Anchor,
		Merge:    e.Merge,
		DataType: e.DataType,
		Attrs:    newAttrs,
		Items:    newItems,
	}
}

// docReplaceAt returns a new Document with element at idx replaced by el.
func docReplaceAt(d *Document, idx int, el *Element) *Document {
	newElements := make([]Node, len(d.Elements))
	copy(newElements, d.Elements)
	newElements[idx] = el
	return &Document{Elements: newElements, Prolog: d.Prolog, Doctype: d.Doctype}
}

// elemReplaceItemAt returns a new Element with item at idx replaced by child.
func elemReplaceItemAt(e *Element, idx int, child Node) *Element {
	newItems := make([]Node, len(e.Items))
	copy(newItems, e.Items)
	newItems[idx] = child
	return &Element{
		Name:     e.Name,
		Anchor:   e.Anchor,
		Merge:    e.Merge,
		DataType: e.DataType,
		Attrs:    e.Attrs,
		Items:    newItems,
	}
}

// pathCopyElement returns a new Element with f applied at the path given by parts, or nil if not found.
func pathCopyElement(e *Element, parts []string, f func(*Element) *Element) *Element {
	for i, item := range e.Items {
		if el, ok := item.(*Element); ok && el.Name == parts[0] {
			if len(parts) == 1 {
				return elemReplaceItemAt(e, i, f(elemDetached(el)))
			}
			updated := pathCopyElement(el, parts[1:], f)
			if updated != nil {
				return elemReplaceItemAt(e, i, updated)
			}
			return nil
		}
	}
	return nil
}
