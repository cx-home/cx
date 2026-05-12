package cx

/**
 * Tree-mutation helpers used by [CXDocument.transform] /
 * [CXDocument.transformAll].
 *
 * The CXPath parser, lexer, predicate types, and evaluator that lived
 * here were deleted in Phase 4 (CB-5): expression evaluation now runs
 * in libcx via cx_select_all_paths, and bindings navigate the returned
 * structural paths against their in-memory tree. What remains here is
 * host-language tree manipulation — not duplication.
 */

/** Return a copy of [e] with independent attrs/items lists so a caller's
 *  `f` cannot mutate the source. Attr instances are deep-copied since
 *  Element.setAttr mutates the existing Attr's value field. */
fun elemDetached(e: Element): Element =
    Element(
        name = e.name,
        anchor = e.anchor,
        merge = e.merge,
        dataType = e.dataType,
        attrs = e.attrs.map { Attr(it.name, it.value, it.dataType) }.toMutableList(),
        items = e.items.toMutableList(),
    )

/** Functional replace of d.elements[idx]. */
fun docReplaceAt(d: CXDocument, idx: Int, el: Element): CXDocument {
    val newElements = d.elements.mapIndexed { i, n -> if (i == idx) el else n }.toMutableList()
    return CXDocument(newElements, d.prolog.toMutableList(), d.doctype)
}

/** Functional replace of e.items[idx]. */
fun elemReplaceItemAt(e: Element, idx: Int, child: Node): Element =
    Element(
        name = e.name,
        anchor = e.anchor,
        merge = e.merge,
        dataType = e.dataType,
        attrs = e.attrs,
        items = e.items.mapIndexed { i, n -> if (i == idx) child else n }.toMutableList(),
    )

/** Slash-path-style descent for [CXDocument.transform]. */
fun pathCopyElement(e: Element, parts: List<String>, f: (Element) -> Element): Element? {
    for ((i, item) in e.items.withIndex()) {
        if (item is Element && item.name == parts[0]) {
            return if (parts.size == 1) {
                elemReplaceItemAt(e, i, f(elemDetached(item)))
            } else {
                val updated = pathCopyElement(item, parts.drop(1), f)
                if (updated != null) elemReplaceItemAt(e, i, updated) else null
            }
        }
    }
    return null
}

// ── Path-based navigation (CB-5 / Phase 4) ────────────────────────────────────

/**
 * Walk [path] (indices into Document.elements then Element.items) and
 * return the live element reference at that position. Returns null if
 * any step is out-of-bounds or hits a non-Element item.
 */
fun navigateDocPath(d: CXDocument, path: IntArray): Element? {
    if (path.isEmpty() || path[0] < 0 || path[0] >= d.elements.size) return null
    var node: Node = d.elements[path[0]]
    for (i in 1 until path.size) {
        val el = node as? Element ?: return null
        val k = path[i]
        if (k < 0 || k >= el.items.size) return null
        node = el.items[k]
    }
    return node as? Element
}

/**
 * Return a new [CXDocument] with the element at [path] replaced by
 * [newElem]. Only the spine along [path] is rebuilt; the original
 * document is unchanged.
 */
fun replaceAtDocPath(d: CXDocument, path: IntArray, newElem: Element): CXDocument {
    if (path.isEmpty()) return d
    val newElements = d.elements.toMutableList()
    if (path.size == 1) {
        if (path[0] in newElements.indices) newElements[path[0]] = newElem
    } else {
        val top = newElements[path[0]] as? Element
        if (top != null) {
            newElements[path[0]] = replaceInElement(top, path.copyOfRange(1, path.size), newElem)
        }
    }
    return CXDocument(newElements, d.prolog.toMutableList(), d.doctype)
}

private fun replaceInElement(el: Element, path: IntArray, newElem: Element): Element {
    if (path.isEmpty()) return newElem
    val newItems = el.items.toMutableList()
    if (path.size == 1) {
        if (path[0] in newItems.indices) newItems[path[0]] = newElem
    } else {
        val child = newItems[path[0]] as? Element
        if (child != null) {
            newItems[path[0]] = replaceInElement(child, path.copyOfRange(1, path.size), newElem)
        }
    }
    return Element(
        name = el.name,
        anchor = el.anchor,
        merge = el.merge,
        dataType = el.dataType,
        attrs = el.attrs,
        items = newItems,
    )
}
