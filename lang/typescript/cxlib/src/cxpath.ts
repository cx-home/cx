/**
 * Tree-mutation helpers used by Document.transform / transformAll.
 *
 * The CXPath parser, lexer, predicate types, and evaluator that lived
 * here were deleted in Phase 4 (CB-5): expression evaluation now runs
 * in libcx via cx_select_all_paths, and bindings navigate the returned
 * structural paths against their in-memory tree. What remains here is
 * host-language tree manipulation — not duplication.
 */

import {
  Document, Element, Node,
} from './ast';

/** Return a copy of `e` with independent attrs/items arrays so a
 *  caller's `f` cannot mutate the source. */
export function elemDetached(e: Element): Element {
  return new Element({
    name: e.name,
    anchor: e.anchor,
    merge: e.merge,
    dataType: e.dataType,
    attrs: e.attrs.map(a => ({ name: a.name, value: a.value, dataType: a.dataType })),
    items: [...e.items],
  });
}

/** Functional replace of d.elements[idx]. */
export function docReplaceAt(d: Document, idx: number, el: Element): Document {
  const newElements = [...d.elements];
  newElements[idx] = el;
  return new Document({ elements: newElements, prolog: d.prolog, doctype: d.doctype });
}

/** Functional replace of e.items[idx]. */
export function elemReplaceItemAt(e: Element, idx: number, child: Node): Element {
  const newItems = [...e.items];
  newItems[idx] = child;
  return new Element({
    name: e.name,
    anchor: e.anchor,
    merge: e.merge,
    dataType: e.dataType,
    attrs: e.attrs,
    items: newItems,
  });
}

/** Slash-path-style descent for Document.transform. */
export function pathCopyElement(
  e: Element,
  parts: string[],
  f: (el: Element) => Element,
): Element | null {
  for (let i = 0; i < e.items.length; i++) {
    const item = e.items[i];
    if (item instanceof Element && item.name === parts[0]) {
      if (parts.length === 1) {
        return elemReplaceItemAt(e, i, f(elemDetached(item)));
      }
      const updated = pathCopyElement(item, parts.slice(1), f);
      if (updated !== null) {
        return elemReplaceItemAt(e, i, updated);
      }
      return null;
    }
  }
  return null;
}

// ── Path-based navigation (CB-5 / Phase 4) ──────────────────────────────────

/**
 * Walk `path` (indices into Document.elements then Element.items) and
 * return the live element reference at that position. Returns null if
 * any step is out-of-bounds or hits a non-Element item.
 */
export function navigateDocPath(d: Document, path: number[]): Element | null {
  if (path.length === 0 || path[0] < 0 || path[0] >= d.elements.length) return null;
  let node: Node = d.elements[path[0]];
  for (let i = 1; i < path.length; i++) {
    if (!(node instanceof Element)) return null;
    const k = path[i];
    if (k < 0 || k >= node.items.length) return null;
    node = node.items[k];
  }
  return node instanceof Element ? node : null;
}

/**
 * Return a new Document with the element at `path` replaced by
 * `newElem`. Only the spine along `path` is rebuilt; the original
 * Document is unchanged.
 */
export function replaceAtDocPath(d: Document, path: number[], newElem: Element): Document {
  if (path.length === 0) return d;
  const newElements = [...d.elements];
  if (path.length === 1) {
    newElements[path[0]] = newElem;
  } else {
    const top = newElements[path[0]];
    if (top instanceof Element) {
      newElements[path[0]] = replaceInElement(top, path.slice(1), newElem);
    }
  }
  return new Document({ elements: newElements, prolog: d.prolog, doctype: d.doctype });
}

function replaceInElement(el: Element, path: number[], newElem: Element): Element {
  if (path.length === 0) return newElem;
  const newItems = [...el.items];
  if (path.length === 1) {
    newItems[path[0]] = newElem;
  } else {
    const child = newItems[path[0]];
    if (child instanceof Element) {
      newItems[path[0]] = replaceInElement(child, path.slice(1), newElem);
    }
  }
  return new Element({
    name: el.name,
    anchor: el.anchor,
    merge: el.merge,
    dataType: el.dataType,
    attrs: el.attrs,
    items: newItems,
  });
}
