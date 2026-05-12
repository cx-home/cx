import Foundation

/// Tree-mutation helpers used by `CXDocument.transform` /
/// `CXDocument.transformAll`.
///
/// The CXPath parser, lexer, predicate types, and evaluator that lived
/// here were deleted in Phase 4 (CB-5): expression evaluation now runs
/// in libcx via `cx_select_all_paths`, and bindings navigate the
/// returned structural paths against their in-memory tree. What
/// remains here is host-language tree manipulation — not duplication.

/// Return a new `Element` with independent attrs/items so a caller's
/// `f` cannot mutate the source. Element is a class (reference type)
/// so we have to allocate a fresh one; Attr is a struct so the array
/// copy is shallow-but-safe.
func elemDetached(_ e: Element) -> Element {
    let copy = Element(e.name, attrs: e.attrs, items: e.items)
    copy.anchor = e.anchor
    copy.merge = e.merge
    copy.dataType = e.dataType
    return copy
}

/// Functional replace of `d.elements[idx]`.
func docReplaceAt(_ d: CXDocument, _ idx: Int, _ el: Element) -> CXDocument {
    var newElements = d.elements
    newElements[idx] = .element(el)
    return CXDocument(elements: newElements, prolog: d.prolog)
}

/// Functional replace of `e.items[idx]`.
func elemReplaceItemAt(_ e: Element, _ idx: Int, _ child: Node) -> Element {
    var newItems = e.items
    newItems[idx] = child
    let copy = Element(e.name, attrs: e.attrs, items: newItems)
    copy.anchor = e.anchor
    copy.merge = e.merge
    copy.dataType = e.dataType
    return copy
}

/// Slash-path-style descent for `CXDocument.transform`.
func pathCopyElement(_ e: Element, _ parts: [String], _ f: (Element) -> Element) -> Element? {
    for (i, item) in e.items.enumerated() {
        if case .element(let child) = item, child.name == parts[0] {
            if parts.count == 1 {
                return elemReplaceItemAt(e, i, .element(f(elemDetached(child))))
            }
            if let updated = pathCopyElement(child, Array(parts.dropFirst()), f) {
                return elemReplaceItemAt(e, i, .element(updated))
            }
            return nil
        }
    }
    return nil
}

// ── Path-based navigation (CB-5 / Phase 4) ────────────────────────────────────

/// Walk `path` (indices into `Document.elements` then `Element.items`)
/// and return the live element reference at that position. Returns nil
/// if any step is out-of-bounds or hits a non-Element item.
func navigateDocPath(_ d: CXDocument, _ path: [Int]) -> Element? {
    if path.isEmpty || path[0] < 0 || path[0] >= d.elements.count { return nil }
    var node: Node = d.elements[path[0]]
    for i in 1 ..< path.count {
        guard case .element(let el) = node else { return nil }
        let k = path[i]
        if k < 0 || k >= el.items.count { return nil }
        node = el.items[k]
    }
    if case .element(let el) = node { return el }
    return nil
}

/// Return a new `CXDocument` with the element at `path` replaced by
/// `newElem`. Only the spine along `path` is rebuilt; the original
/// document is unchanged.
func replaceAtDocPath(_ d: CXDocument, _ path: [Int], _ newElem: Element) -> CXDocument {
    if path.isEmpty { return d }
    var newElements = d.elements
    if path.count == 1 {
        if path[0] >= 0 && path[0] < newElements.count {
            newElements[path[0]] = .element(newElem)
        }
    } else if case .element(let top) = newElements[path[0]] {
        let rest = Array(path.dropFirst())
        newElements[path[0]] = .element(replaceInElement(top, rest, newElem))
    }
    return CXDocument(elements: newElements, prolog: d.prolog)
}

private func replaceInElement(_ el: Element, _ path: [Int], _ newElem: Element) -> Element {
    if path.isEmpty { return newElem }
    var newItems = el.items
    if path.count == 1 {
        if path[0] >= 0 && path[0] < newItems.count {
            newItems[path[0]] = .element(newElem)
        }
    } else if case .element(let child) = newItems[path[0]] {
        let rest = Array(path.dropFirst())
        newItems[path[0]] = .element(replaceInElement(child, rest, newElem))
    }
    let copy = Element(el.name, attrs: el.attrs, items: newItems)
    copy.anchor = el.anchor
    copy.merge = el.merge
    copy.dataType = el.dataType
    return copy
}
